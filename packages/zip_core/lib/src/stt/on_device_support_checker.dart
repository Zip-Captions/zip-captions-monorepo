/// Answers whether on-device speech recognition is supported for [localeId]
/// right now.
///
/// Supplied by the app (a method channel into the platform runner) because
/// the `speech_to_text` plugin does not expose the answer. `PlatformSttEngine`
/// calls it before **every** `listen()` and never caches the result; an
/// exception, a missing plugin or a timeout counts as `false` (fail closed).
/// See Unit 10 Amendment 02.
typedef OnDeviceSupportChecker = Future<bool> Function(String localeId);
