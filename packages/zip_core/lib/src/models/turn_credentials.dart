import 'package:freezed_annotation/freezed_annotation.dart';

part 'turn_credentials.freezed.dart';

/// A short-term TURN credential issued by `get_turn_credentials()`
/// (Coturn Infrastructure, Unit 4).
///
/// Shape fixed at Application Design (`phase2-component-methods.md`) for
/// `TurnCredentialService.fetch`.
@immutable
@freezed
abstract class TurnCredentials with _$TurnCredentials {
  /// Creates a [TurnCredentials].
  const factory TurnCredentials({
    /// TURN REST username — the credential's unix-timestamp expiry, per
    /// the TURN REST API shared-secret scheme.
    required String username,

    /// base64(HMAC-SHA1(sharedSecret, username)), computed server-side.
    required String credential,

    /// When this credential stops being valid (NFR Requirements Q5: 1
    /// hour TTL). Proactive renewal before this is a hard Unit 5
    /// requirement.
    required DateTime expiresAt,

    /// STUN/TURN server URLs this credential is valid for.
    required List<String> urls,
  }) = _TurnCredentials;
}
