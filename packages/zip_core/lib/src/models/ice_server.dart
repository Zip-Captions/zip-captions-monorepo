import 'package:freezed_annotation/freezed_annotation.dart';

part 'ice_server.freezed.dart';

/// A single ICE server descriptor, matching the shape `flutter_webrtc`'s
/// `RTCIceServer` expects.
///
/// Shape fixed at NFR Design (Q2, Coturn Infrastructure Unit 4) — not
/// fixed by Application Design, which left [IceServer]'s fields open.
@immutable
@freezed
abstract class IceServer with _$IceServer {
  /// Creates an [IceServer].
  const factory IceServer({
    /// STUN/TURN URLs, e.g. `stun:localhost:3478`, `turn:localhost:3478`.
    required List<String> urls,

    /// TURN credential username. `null` for a STUN-only entry.
    String? username,

    /// TURN credential. `null` for a STUN-only entry.
    String? credential,
  }) = _IceServer;
}
