// Workaround: speech_to_text_windows-1.0.0+beta.8 uses the same include guard
// (FLUTTER_PLUGIN_LOCAL_AUTH_WINDOWS_PLUGIN_H_) as local_auth_windows. When
// both packages are present, the speech_to_text_windows header is silently
// skipped, leaving SpeechToTextWindowsRegisterWithRegistrar undeclared.
//
// This wrapper uses a distinct guard and re-declares the function. It takes
// precedence because windows/ is in the runner's include path before the
// pub-cache plugin headers.
#ifndef SPEECH_TO_TEXT_WINDOWS_SPEECH_TO_TEXT_WINDOWS_H_
#define SPEECH_TO_TEXT_WINDOWS_SPEECH_TO_TEXT_WINDOWS_H_

#include <flutter_plugin_registrar.h>

#if defined(__cplusplus)
extern "C" {
#endif

__declspec(dllimport) void SpeechToTextWindowsRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar);

#if defined(__cplusplus)
}
#endif

#endif  // SPEECH_TO_TEXT_WINDOWS_SPEECH_TO_TEXT_WINDOWS_H_
