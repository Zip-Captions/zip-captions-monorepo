import 'package:logging/logging.dart';
import 'package:zip_core/src/output/overlay/display_enumerator.dart';
import 'package:zip_core/src/output/overlay/screen_retriever_display_enumerator_stub.dart';

/// The web/mobile enumerator: no displays, no platform observer (ID-3).
DisplayEnumerator createScreenRetrieverDisplayEnumerator({Logger? log}) =>
    ScreenRetrieverDisplayEnumerator();
