import 'package:flutter/foundation.dart';

/// The ICE transport policy a peer connection is created with.
///
/// Added by Unit 9 (B3/B4) to prove EC3b — "the app actually falls back to
/// TURN when direct P2P fails". Without a way to force relay, that path can
/// only be observed on a network where direct genuinely fails, which is not
/// reproducible on demand.
///
/// **Why this is a compile-time constant, not a call-site option.** A
/// relay-only switch has exactly one legitimate use: verification. Written
/// as a `PeerConnectionFactory` parameter, or as a method argument on
/// `PeerConnectionHandle`, it would be new public API that any future caller
/// could pass in production, and the `very_good_analysis` lint set cannot
/// police intent. A `const` resolved from `kDebugMode` and a dart-define
/// cannot be reached from release builds at all: in a release build
/// [relayOnlyIceEnabled] is `false` by construction, because the
/// `bool.fromEnvironment` read is guarded by `kDebugMode`, which the compiler
/// folds to `false`.
///
/// Usage (debug builds only):
/// ```sh
/// flutter run -d macos --dart-define=ZIP_CAPTIONS_RELAY_ONLY_ICE=true
/// ```
const String relayOnlyIceDefine = 'ZIP_CAPTIONS_RELAY_ONLY_ICE';

/// Whether every peer connection should be created relay-only.
///
/// `false` in profile and release builds regardless of the dart-define.
///
/// Declared `const`, not a getter, so the claim above is a property of the
/// program rather than an observation about it: a getter is evaluated at
/// runtime on every read, and only a `const` is guaranteed to be folded and
/// tree-shaken. Both operands — `kDebugMode` and `bool.fromEnvironment` —
/// are themselves `const`, which is what makes this legal.
const bool relayOnlyIceEnabled =
    kDebugMode && bool.fromEnvironment(relayOnlyIceDefine);

/// The `iceTransportPolicy` value to pass in the WebRTC configuration map,
/// or `null` to leave the plugin's default (`'all'`) in place.
///
/// `'relay'` is the value both native layers parse: macOS
/// `FlutterWebRTCPlugin.m` (`iceTransportPolicy` to
/// `RTCIceTransportPolicyRelay`) and the Windows/Linux
/// `flutter_webrtc_base.cc` config reader. The Dart side is untyped
/// (`RTCConfiguration` is entirely commented out in `webrtc_interface`
/// 1.5.1), so the string is passed through the configuration map rather than
/// through a typed field.
const String? iceTransportPolicyOverride =
    relayOnlyIceEnabled ? 'relay' : null;
