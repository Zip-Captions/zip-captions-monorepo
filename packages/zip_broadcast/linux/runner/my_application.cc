#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include <desktop_multi_window/desktop_multi_window_plugin.h>

#include <map>

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

namespace {

// Sub-window ids by toplevel, filled by the `configure` handler and drained by
// the `"destroy"` hook (ID §4a, §4c).
std::map<GtkWindow*, int64_t>& WindowIds() {
  static std::map<GtkWindow*, int64_t> ids;
  return ids;
}

// The main engine's close channel (ID §4b). Owns a reference for the app's
// lifetime. The accessor hands out the storage itself so the registration site
// can assign to it.
FlMethodChannel*& SubWindowEventsRef() {
  static FlMethodChannel* channel = nullptr;
  return channel;
}

FlMethodChannel* SubWindowEvents() { return SubWindowEventsRef(); }

// Raises `subWindowClosed` for |window| if the runner recorded an id for it.
// Fire-and-forget: nothing on the close path waits for a Dart reply.
void EmitSubWindowClosed(GtkWindow* window) {
  auto& ids = WindowIds();
  auto it = ids.find(window);
  if (it == ids.end()) {
    return;
  }
  int64_t id = it->second;
  ids.erase(it);

  FlMethodChannel* channel = SubWindowEvents();
  if (!channel) {
    return;
  }
  g_autoptr(FlValue) args = fl_value_new_map();
  fl_value_set_string_take(args, "windowId", fl_value_new_int(id));
  fl_method_channel_invoke_method(channel, "subWindowClosed", args, nullptr,
                                  nullptr, nullptr);
}

// The sub-engine's `configure` handler (ID §4a). Validates by type and answers
// a fixed error on rejection; no field value is ever reflected back.
void OnConfigureMethodCall(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  FlView* view = FL_VIEW(user_data);
  g_autoptr(FlMethodResponse) response = nullptr;

  if (g_strcmp0(fl_method_call_get_name(method_call), "configure") != 0) {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
    fl_method_call_respond(method_call, response, nullptr);
    return;
  }

  FlValue* args = fl_method_call_get_args(method_call);
  if (fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    g_autoptr(FlMethodResponse) error = FL_METHOD_RESPONSE(
        fl_method_error_response_new("configure_invalid", nullptr, nullptr));
    fl_method_call_respond(method_call, error, nullptr);
    return;
  }

  FlValue* window_id_value = fl_value_lookup_string(args, "windowId");
  FlValue* floating_value = fl_value_lookup_string(args, "floating");
  FlValue* decorated_value = fl_value_lookup_string(args, "decorated");
  FlValue* min_width_value = fl_value_lookup_string(args, "minWidth");
  FlValue* min_height_value = fl_value_lookup_string(args, "minHeight");

  if (window_id_value == nullptr || floating_value == nullptr ||
      decorated_value == nullptr || min_width_value == nullptr ||
      min_height_value == nullptr ||
      fl_value_get_type(window_id_value) != FL_VALUE_TYPE_INT ||
      fl_value_get_type(floating_value) != FL_VALUE_TYPE_BOOL ||
      fl_value_get_type(decorated_value) != FL_VALUE_TYPE_BOOL ||
      fl_value_get_type(min_width_value) != FL_VALUE_TYPE_FLOAT ||
      fl_value_get_type(min_height_value) != FL_VALUE_TYPE_FLOAT ||
      fl_value_get_int(window_id_value) < 0 ||
      fl_value_get_float(min_width_value) < 0 ||
      fl_value_get_float(min_height_value) < 0) {
    g_autoptr(FlMethodResponse) error = FL_METHOD_RESPONSE(
        fl_method_error_response_new("configure_invalid", nullptr, nullptr));
    fl_method_call_respond(method_call, error, nullptr);
    return;
  }

  GtkWidget* toplevel = gtk_widget_get_toplevel(GTK_WIDGET(view));
  if (!GTK_IS_WINDOW(toplevel)) {
    g_autoptr(FlMethodResponse) error = FL_METHOD_RESPONSE(
        fl_method_error_response_new("configure_invalid", nullptr, nullptr));
    fl_method_call_respond(method_call, error, nullptr);
    return;
  }

  GtkWindow* window = GTK_WINDOW(toplevel);
  gboolean floating = fl_value_get_bool(floating_value);
  gboolean decorated = fl_value_get_bool(decorated_value);

  gtk_window_set_keep_above(window, floating);
  gtk_window_set_decorated(window, decorated);
  gtk_widget_set_size_request(toplevel,
                              static_cast<int>(fl_value_get_float(min_width_value)),
                              static_cast<int>(fl_value_get_float(min_height_value)));

  WindowIds()[window] = fl_value_get_int(window_id_value);

  response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  fl_method_call_respond(method_call, response, nullptr);
}

// The `"destroy"` hook: the only signal that runs on every close path
// (`delete-event` is aborted by the plugin's `TRUE`, ID §2.4).
void OnSubWindowDestroy(GtkWidget* widget, gpointer data) {
  if (!GTK_IS_WINDOW(widget)) {
    return;
  }
  EmitSubWindowClosed(GTK_WINDOW(widget));
}

}  // namespace

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "zip_broadcast");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "zip_broadcast");
  }

  gtk_window_set_default_size(window, 1280, 720);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  // Registered once, on the main engine, before any sub-window can exist.
  FlMethodChannel* sub_window_events = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)),
      "zip_core/overlay_sub_window_events",
      FL_METHOD_CODEC(fl_standard_method_codec_new()));
  // The one reference the process keeps for the main engine's lifetime, held
  // by the accessor and never released: the close path may run long after the
  // window teardown steps (review round 3, finding 5).
  SubWindowEventsRef() = sub_window_events;

  // Sub-windows are caption surfaces, not app windows. Unit 8 stripped their
  // decoration here unconditionally; this unit moves every styling decision
  // into the `configure` channel (BR-U8.1-04), so the external display still
  // arrives borderless and the pop-out asks for a floating decorated frame.
  // The runner is mode-blind: it applies what Dart sends.
  desktop_multi_window_plugin_set_window_created_callback(
      [](FlPluginRegistry* registry) {
        if (!registry) {
          return;
        }
        FlView* created_view = FL_VIEW(registry);

        // Deliberately leaked: the channel lives as long as its sub-window,
        // and the window's teardown is not a place to run plugin code. The
        // destroy hook below is the app's own, not this channel's, so nothing
        // here would unref it in time anyway (review round 3, finding 5).
        FlMethodChannel* configure = fl_method_channel_new(
            fl_engine_get_binary_messenger(fl_view_get_engine(created_view)),
            "zip_core/overlay_window_configure",
            FL_METHOD_CODEC(fl_standard_method_codec_new()));
        fl_method_channel_set_method_call_handler(
            configure, OnConfigureMethodCall, created_view, nullptr);

        GtkWidget* toplevel = gtk_widget_get_toplevel(GTK_WIDGET(created_view));
        if (GTK_IS_WINDOW(toplevel)) {
          g_signal_connect(toplevel, "destroy", G_CALLBACK(OnSubWindowDestroy),
                           nullptr);
        }
      });

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}