import 'package:flutter/services.dart';
import 'package:zip_core/zip_core.dart';

/// Asks the platform runners whether on-device speech recognition supports a
/// locale (Unit 10, Amendment 02 section 3.1).
///
/// The stock `speech_to_text` plugin does not expose this answer, so the app
/// asks its own runners over one method channel. This class is only the
/// transport: it does **not** swallow failures. [PlatformSttEngine] owns the
/// fail-closed rule (an exception, a missing plugin or a timeout is treated as
/// "unsupported" there, and logged by type), so an error raised here reaches
/// the engine intact instead of being reported as a silent `false`.
///
/// A reply that is not a boolean is a contract breach and throws a
/// [TypeError]; it must not be read as "unsupported".
class MethodChannelOnDeviceSupportChecker {
  /// Creates a checker over the app's own speech-support channel.
  const MethodChannelOnDeviceSupportChecker();

  /// The channel the iOS and Android runners answer on (BR-U10-32).
  static const channelName = 'app.zipcaptions/speech_support';

  /// The method name the runners implement.
  static const methodName = 'isOnDeviceSupported';

  static const _channel = MethodChannel(channelName);

  /// Answers whether on-device recognition supports [localeId] on this device.
  ///
  /// Satisfies [OnDeviceSupportChecker], so it can be passed straight to
  /// `createPlatformSttEngine`.
  Future<bool> call(String localeId) async {
    final reply = await _channel.invokeMethod<Object?>(
      methodName,
      localeId,
    );
    return reply! as bool;
  }
}
