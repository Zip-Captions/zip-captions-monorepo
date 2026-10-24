import 'package:logging/logging.dart';
import 'package:zip_core/src/output/overlay/display_enumerator.dart';
import 'package:zip_core/src/output/overlay/screen_retriever_display_enumerator_io.dart';

/// The platform's real display observer (ID-3).
///
/// Lives in an `_io` file so only the platform build names
/// `screen_retriever`; the host imports this factory, not the adapter.
DisplayEnumerator createScreenRetrieverDisplayEnumerator({Logger? log}) =>
    ScreenRetrieverDisplayEnumerator(
      logWarning: log == null ? null : (message) => log.warning(message),
    );
