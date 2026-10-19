// PBT generator library (LC-01).
//
// Centralized Generator<T> instances for all domain types.
// Imported by PBT test files.

import 'dart:math';

import 'package:zip_core/src/models/audio_device.dart';
import 'package:zip_core/src/models/auth_failure.dart';
import 'package:zip_core/src/models/broadcast_id.dart';
import 'package:zip_core/src/models/broadcast_settings.dart';
import 'package:zip_core/src/models/caption_event.dart';
import 'package:zip_core/src/models/caption_wire_message.dart';
import 'package:zip_core/src/models/connect_failure.dart';
import 'package:zip_core/src/models/connection_status.dart';
import 'package:zip_core/src/models/display_settings.dart';
import 'package:zip_core/src/models/enums.dart';
import 'package:zip_core/src/models/recording_state.dart';
import 'package:zip_core/src/models/sherpa_model_catalog.dart';
import 'package:zip_core/src/models/sherpa_model_download_progress.dart';
import 'package:zip_core/src/models/sherpa_model_info.dart';
import 'package:zip_core/src/models/signaling_message.dart';
import 'package:zip_core/src/models/stt_result.dart';
import 'package:zip_core/src/models/transcript_search_result.dart';
import 'package:zip_core/src/models/transcript_segment.dart';
import 'package:zip_core/src/models/transcript_session.dart';
import 'package:zip_core/src/models/wake_lock_settings.dart';

import 'pbt.dart';
import 'prefs_helpers.dart';
import 'recording_state_model.dart';

// --- Enum generators ---

final Generator<ScrollDirection> arbitraryScrollDirection = any.choose(
  ScrollDirection.values,
);

final Generator<CaptionTextSize> arbitraryCaptionTextSize = any.choose(
  CaptionTextSize.values,
);

final Generator<CaptionFont> arbitraryCaptionFont = any.choose(
  CaptionFont.values,
);

final Generator<ThemeModeSetting> arbitraryThemeModeSetting = any.choose(
  ThemeModeSetting.values,
);

// --- Composed DisplaySettings generator ---

final Generator<DisplaySettings> arbitraryDisplaySettings = any.combine5(
  arbitraryScrollDirection,
  arbitraryCaptionTextSize,
  arbitraryCaptionFont,
  arbitraryThemeModeSetting,
  any.intInRange(0, 101),
  (scroll, textSize, font, theme, lines) => DisplaySettings(
    scrollDirection: scroll,
    captionTextSize: textSize,
    captionFont: font,
    themeModeSetting: theme,
    maxVisibleLines: lines,
  ),
);

// --- Command generators ---

final Generator<Command> arbitraryCommand = any.choose(Command.values);

final Generator<List<Command>> arbitraryCommandSequence = any
    .listWithLengthInRange(0, 50, arbitraryCommand);

// --- FieldState generator ---

final Generator<FieldState> arbitraryFieldState = any.choose(FieldState.values);

// --- Locale ID generator ---

/// Generates BCP-47-like locale ID strings:
/// language codes, language-region pairs, and edge cases.
final Generator<String> arbitraryLocaleId = any.choose([
  'en',
  'fr',
  'de',
  'es',
  'ja',
  'zh',
  'ko',
  'ar',
  'pt',
  'en-US',
  'en-GB',
  'fr-FR',
  'zh-CN',
  'zh-TW',
  'pt-BR',
  'es-MX',
  'EN',
  'en_US',
  'EN-us',
]);

// --- SttResult generator ---

/// Generates valid SttResult instances with randomized fields.
final Generator<SttResult> arbitrarySttResult = any.combine5(
  any.letterOrDigits, // text
  any.boolGen, // isFinal
  any.doubleInRange(0, 1), // confidence
  any.choose(['default', 'mic-1', 'mic-2', 'system-audio']), // sourceId
  any.choose([null, 'Speaker A', 'Speaker B']), // speakerTag
  (text, isFinal, confidence, sourceId, speakerTag) => SttResult(
    text: text.isEmpty && isFinal ? 'fallback' : text,
    isFinal: isFinal,
    confidence: confidence,
    timestamp: DateTime.utc(2026),
    sourceId: sourceId,
    speakerTag: speakerTag,
  ),
);

// --- CaptionEvent generator ---

/// Generates random [RecordingState] instances across all five variants.
final Generator<RecordingState> arbitraryRecordingState = any.combine3(
  any.intInRange(0, 5),
  any.letterOrDigits,
  any.letterOrDigits,
  (variant, sessionId, segment) {
    final sid = sessionId.isEmpty ? 'test-session' : sessionId;
    return switch (variant) {
      0 => const RecordingState.idle(),
      1 => RecordingState.recording(sessionId: sid, currentSegment: segment),
      2 => RecordingState.paused(sessionId: sid, currentSegment: segment),
      3 => RecordingState.reconnecting(sessionId: sid, currentSegment: segment),
      _ => RecordingState.stopped(sessionId: sid, currentSegment: segment),
    };
  },
);

/// Generates random CaptionEvent instances (either SttResultEvent or
/// SessionStateEvent with a varied [RecordingState]).
final Generator<CaptionEvent> arbitraryCaptionEvent = any.combine3(
  any.boolGen,
  arbitrarySttResult,
  arbitraryRecordingState,
  (useResult, result, state) =>
      useResult ? SttResultEvent(result) : SessionStateEvent(state),
);

// --- Registry operation generators ---

/// Operations that can be applied to SttEngineRegistry.
enum RegistryOp { register, unregister, get }

/// Returns a random [RegistryOp] value for property-based tests.
final Generator<RegistryOp> arbitraryRegistryOp = any.choose(RegistryOp.values);

/// Returns a random list of [RegistryOp] values with length 0–30.
final Generator<List<RegistryOp>> arbitraryRegistryOps = any
    .listWithLengthInRange(0, 30, arbitraryRegistryOp);

// --- Unit 2 domain generators ---

/// Generates [AudioDevice] instances with varied IDs and names.
final Generator<AudioDevice> arbitraryAudioDevice = any.combine3(
  any.letterOrDigits,
  any.letterOrDigits,
  any.boolGen,
  (id, name, isDefault) => AudioDevice(
    deviceId: id.isEmpty ? 'dev-0' : id,
    name: name.isEmpty ? 'Device' : name,
    isDefault: isDefault,
  ),
);

/// Generates [WakeLockSettings] with all boolean combinations.
final Generator<WakeLockSettings> arbitraryWakeLockSettings = any.combine2(
  any.boolGen,
  any.boolGen,
  (enabled, releaseOnPause) => WakeLockSettings(
    enabled: enabled,
    releaseOnPause: releaseOnPause,
  ),
);

/// Generates [SherpaModelCatalogEntry] instances.
final Generator<SherpaModelCatalogEntry> arbitrarySherpaModelCatalogEntry = any
    .combine4(
      any.letterOrDigits,
      arbitraryLocaleId,
      any.intInRange(1000, 500000000),
      any.letterOrDigits,
      (modelId, locale, sizeBytes, checksum) {
        final normalizedModelId = modelId.isEmpty ? 'model-0' : modelId;
        return SherpaModelCatalogEntry(
          modelId: normalizedModelId,
          displayName: 'Model $normalizedModelId',
          primaryLocaleId: locale,
          downloadSizeBytes: sizeBytes,
          downloadUrl: 'https://example.com/$normalizedModelId.tar.bz2',
          sha256Checksum: checksum.isEmpty ? '0' * 64 : checksum,
        );
      },
    );

/// Generates [SherpaModelInfo] instances.
final Generator<SherpaModelInfo> arbitrarySherpaModelInfo = any.combine2(
  arbitrarySherpaModelCatalogEntry,
  any.boolGen,
  (entry, isDownloaded) => SherpaModelInfo(
    catalogEntry: entry,
    isDownloaded: isDownloaded,
    localPath: isDownloaded ? '/models/${entry.modelId}' : null,
  ),
);

/// Generates [SherpaModelDownloadProgress] instances with valid invariants.
///
/// `downloadedBytes` is varied across 0%, partial, and 100% to cover all
/// progress edge cases.
final Generator<SherpaModelDownloadProgress>
arbitrarySherpaModelDownloadProgress = any.combine3(
  any.letterOrDigits,
  any.intInRange(1, 500000000),
  any.doubleInRange(0, 1),
  (modelId, totalBytes, fraction) => SherpaModelDownloadProgress(
    modelId: modelId.isEmpty ? 'model-0' : modelId,
    downloadedBytes: (totalBytes * fraction).round(),
    totalBytes: totalBytes,
  ),
);

// --- Unit 3 domain generators ---

/// Generates [TranscriptSession] instances with valid invariants.
final Generator<TranscriptSession> arbitraryTranscriptSession = any.combine5(
  any.letterOrDigits,
  any.intInRange(0, 100000000),
  any.choose([null, 'Short title', 'A longer session title']),
  any.intInRange(0, 3600000),
  any.intInRange(0, 10000),
  (id, epochMs, title, durationMs, segmentCount) => TranscriptSession(
    sessionId: id.isEmpty ? 'ses-0' : id,
    date: DateTime.fromMillisecondsSinceEpoch(epochMs, isUtc: true),
    durationMs: durationMs,
    segmentCount: segmentCount,
    title: title,
  ),
);

/// Generates [TranscriptSegment] instances with `endTimeMs >= startTimeMs`.
final Generator<TranscriptSegment> arbitraryTranscriptSegment = any.combine5(
  any.letterOrDigits,
  any.letterOrDigits,
  any.choose(['default', 'mic-1', 'mic-2', 'system-audio']),
  any.intInRange(0, 3600000),
  any.intInRange(0, 10000),
  (segId, sessionId, sourceId, startMs, durationMs) => TranscriptSegment(
    segmentId: segId.isEmpty ? 'seg-0' : segId,
    sessionId: sessionId.isEmpty ? 'ses-0' : sessionId,
    text: segId.isEmpty ? 'fallback text' : segId,
    sourceId: sourceId,
    startTimeMs: startMs,
    endTimeMs: startMs + durationMs,
  ),
);

/// Generates a list of 2–5 non-empty word strings for merge-window PBTs.
final Generator<List<String>> arbitraryNonEmptyWordList = any
    .listWithLengthInRange(
      2,
      6,
      any.choose([
        'hello',
        'world',
        'foo',
        'bar',
        'baz',
        'qux',
        'dart',
        'test',
      ]),
    );

/// Generates [TranscriptSearchResult] with 1–3 non-empty snippets.
final Generator<TranscriptSearchResult> arbitraryTranscriptSearchResult = any
    .combine3(
      arbitraryTranscriptSession,
      any.intInRange(1, 4),
      any.doubleInRange(-10, 0),
      (session, snippetCount, score) => TranscriptSearchResult(
        session: session,
        snippets: List.generate(snippetCount, (i) => '[match] snippet $i'),
        relevanceScore: score,
      ),
    );

// --- Auth domain generators ---

/// A command in a simulated AuthNotifier session, for the stateful PBT in
/// auth_state_machine_properties_test.dart (not yet written).
sealed class AuthCommand {
  const AuthCommand();
}

/// Attempt to sign in with [providerId]; the fake AuthService will resolve
/// this attempt with [outcome] (null = success, otherwise the AuthFailure
/// reason).
final class SignInCommand extends AuthCommand {
  const SignInCommand({required this.providerId, this.outcome});
  final String providerId;
  final AuthFailure? outcome;
}

/// Sign out.
final class SignOutCommand extends AuthCommand {
  const SignOutCommand();
}

/// Simulate a passive background session loss (e.g. refresh token
/// rejected) — the fake AuthService should emit a signedOut transition
/// without any preceding user-initiated signOut() call.
final class PassiveSessionLossCommand extends AuthCommand {
  const PassiveSessionLossCommand();
}

/// Realistic sign-in provider IDs, including a made-up one to exercise
/// mismatched-provider handling.
const List<String> _authProviderIds = [
  'google',
  'github',
  'unknown-provider',
];

/// Simulated sign-in outcome: mostly success (null), occasionally one of
/// the [AuthFailure] reasons (weighted list, PBT-07).
final Generator<AuthFailure?> _arbitrarySignInOutcome = any.choose([
  null,
  null,
  null,
  AuthFailure.cancelled,
  AuthFailure.denied,
  AuthFailure.network,
  AuthFailure.providerError,
  AuthFailure.sessionExpired,
]);

/// A [SignInCommand] with a realistic provider ID and outcome.
final Generator<SignInCommand> _arbitrarySignInCommand = any.combine2(
  any.choose(_authProviderIds),
  _arbitrarySignInOutcome,
  (providerId, outcome) => SignInCommand(
    providerId: providerId,
    outcome: outcome,
  ),
);

/// A single [AuthCommand] weighted toward realistic usage: sign-in (~55%),
/// sign-out (~30%), passive session loss (~15%).
AuthCommand _arbitraryAuthCommand(Random r) {
  final kind = r.nextInt(20);
  if (kind < 11) {
    return _arbitrarySignInCommand(r);
  }
  if (kind < 17) {
    return const SignOutCommand();
  }
  return const PassiveSessionLossCommand();
}

/// Weighted sequence of [AuthCommand]s for the stateful AuthNotifier PBT:
/// realistic flows (sign-in, sign-in then sign-out) are common, while
/// adversarial orderings (back-to-back sign-ins, sign-out before
/// resolution, session loss with no prior sign-in) and the empty sequence
/// remain reachable.
final Generator<List<AuthCommand>> arbitraryAuthCommandSequence = any
    .listWithLengthInRange(0, 20, _arbitraryAuthCommand);

// --- Broadcast identity + signaling domain generators (Unit 3) ---

const String _crockfordAlphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

/// Generates a valid 6-character Crockford-Base32 string, randomly
/// upper- or lower-cased, for exercising [BroadcastId]'s case-insensitive
/// parsing.
final Generator<String> arbitraryValidBroadcastIdString = any.combine2(
  any.listWithLengthInRange(6, 6, any.choose(_crockfordAlphabet.split(''))),
  any.boolGen,
  (chars, lower) {
    final s = chars.join();
    return lower ? s.toLowerCase() : s;
  },
);

/// Generates valid [BroadcastId] instances.
BroadcastId arbitraryBroadcastId(Random random) =>
    BroadcastId.parse(arbitraryValidBroadcastIdString(random));

/// Generates arbitrary strings for `BroadcastLink.parseInput`'s
/// never-throws property: empty, garbage ASCII, non-ASCII, very long, and
/// strings that look almost-but-not-quite like a valid link.
final Generator<String> arbitraryLinkInput = any.choose([
  '',
  ' ',
  'not a link at all',
  'https://',
  'https://zipcaptions.app/b/',
  'zipcaptions.app/b/',
  'zipcaptions.app/b/too-long-to-be-valid',
  'zipcaptions.app/b/k7m9x2/extra',
  'ftp://zipcaptions.app/b/k7m9x2',
  '💥💥💥💥💥💥',
  '日本語のコード',
  'a' * 10000,
  'K7M9X!',
  'K7M9XX2',
  'K7M9X',
]);

/// Realistic configured broadcast bases for PBT-02's "configured base" row
/// (`business-rules.md` Rule 11): the v1 apex default, the v2 subdomain a
/// release build would supply, and a local-dev host.
final Generator<String> arbitraryConfiguredBase = any.choose([
  'https://zipcaptions.app/b/',
  'https://v2.zipcaptions.app/b/',
  'http://localhost:8080/b/',
]);

/// Generates strings that can never parse as a `BroadcastId`: wrong
/// lengths, characters outside Crockford's alphabet, and non-`/b/` paths
/// whose last segment is not a valid code (PBT-02's invalid-input row).
final Generator<String> arbitraryInvalidLinkInput = any.combine3(
  any.choose([
    'https://zipcaptions.app/watch/',
    'zipcaptions.app/b/',
    'K7M9X!',
    'localhost:8080/b/',
  ]),
  any.choose(['', 'x', 'I', 'L', 'O', 'U', '!']),
  any.listWithLengthInRange(0, 10, any.choose('01AB!'.split(''))),
  (prefix, badChar, tail) => '$prefix$badChar${tail.join()}',
);

/// Realistic-looking peer id strings (short alphanumeric tokens, as a real
/// Realtime presence/channel peer id would be).
final Generator<String> arbitraryPeerId = any.combine2(
  any.letterOrDigits,
  any.letterOrDigits,
  (a, b) => 'peer-${a.isEmpty ? "x" : a}${b.isEmpty ? "y" : b}',
);

/// A realistic-looking SDP body placeholder (not a real SDP parser's worth
/// of structure — just non-empty, multi-line, SDP-shaped text).
final Generator<String> arbitrarySdp = any.choose([
  'v=0\r\no=- 1 1 IN IP4 127.0.0.1\r\ns=-\r\nt=0 0\r\n',
  'v=0\r\no=- 2 2 IN IP4 127.0.0.1\r\ns=-\r\nt=0 0\r\na=sendrecv\r\n',
]);

/// A realistic-looking ICE candidate line placeholder.
final Generator<String> arbitraryIceCandidateLine = any.choose([
  'candidate:1 1 UDP 2122260223 192.168.1.5 54400 typ host',
  'candidate:2 1 UDP 1685987071 203.0.113.5 54401 typ srflx',
]);

/// Generates a [JoinRequest] with `viewerIdentity` always `null` (Rule 7 —
/// inert in Phase 2).
JoinRequest arbitraryJoinRequest(Random random) =>
    JoinRequest(fromPeerId: arbitraryPeerId(random));

/// Generates a [JoinAccepted].
JoinAccepted arbitraryJoinAccepted(Random random) =>
    JoinAccepted(toPeerId: arbitraryPeerId(random));

/// Generates a [JoinRejected] across both [JoinRejection] reasons.
final Generator<JoinRejected> arbitraryJoinRejected = any.combine2(
  arbitraryPeerId,
  any.choose(JoinRejection.values),
  (toPeerId, reason) => JoinRejected(toPeerId: toPeerId, reason: reason),
);

/// Generates an [SdpOffer].
final Generator<SdpOffer> arbitrarySdpOffer = any.combine3(
  arbitraryPeerId,
  arbitraryPeerId,
  arbitrarySdp,
  (from, to, sdp) => SdpOffer(fromPeerId: from, toPeerId: to, sdp: sdp),
);

/// Generates an [SdpAnswer].
final Generator<SdpAnswer> arbitrarySdpAnswer = any.combine3(
  arbitraryPeerId,
  arbitraryPeerId,
  arbitrarySdp,
  (from, to, sdp) => SdpAnswer(fromPeerId: from, toPeerId: to, sdp: sdp),
);

/// Generates an [IceCandidate].
IceCandidate arbitraryIceCandidate(Random random) => IceCandidate(
  fromPeerId: arbitraryPeerId(random),
  toPeerId: arbitraryPeerId(random),
  candidate: arbitraryIceCandidateLine(random),
  sdpMid: any.choose(['0', '1', 'audio', 'video'])(random),
  sdpMLineIndex: any.intInRange(0, 3)(random),
);

/// Generates an [IceRestart].
final Generator<IceRestart> arbitraryIceRestart = any.combine2(
  arbitraryPeerId,
  arbitraryPeerId,
  (from, to) => IceRestart(fromPeerId: from, toPeerId: to),
);

/// Generates a [Leave].
Leave arbitraryLeave(Random random) =>
    Leave(fromPeerId: arbitraryPeerId(random));

/// Generates a [SignalingMessage] covering every one of the 9 sealed
/// variants (round-robin by random choice, not just one variant).
SignalingMessage arbitrarySignalingMessage(Random random) =>
    switch (random.nextInt(9)) {
      0 => arbitraryJoinRequest(random),
      1 => arbitraryJoinAccepted(random),
      2 => arbitraryJoinRejected(random),
      3 => arbitrarySdpOffer(random),
      4 => arbitrarySdpAnswer(random),
      5 => arbitraryIceCandidate(random),
      6 => arbitraryIceRestart(random),
      7 => arbitraryLeave(random),
      _ => const BroadcastEnded(),
    };

/// Generates deliberately malformed/adversarial JSON-shaped input for
/// `SignalingCodec.decode`'s never-throws property. A separate generator
/// from [arbitrarySignalingMessage] — this one targets broken shapes, not
/// valid messages.
Object? arbitraryMalformedSignalingJson(Random random) =>
    switch (random.nextInt(10)) {
      0 => null,
      1 => 'not a map',
      2 => 42,
      3 => <String, Object?>{},
      4 => <String, Object?>{'messageType': 'joinRequest'}, // missing version
      5 => <String, Object?>{'version': 1}, // missing messageType
      6 => <String, Object?>{'messageType': 42, 'version': 1}, // wrong type
      7 => <String, Object?>{
        'messageType': 'joinRequest',
        'version': 999, // unsupported version
        'fromPeerId': 'peer-1',
      },
      8 => <String, Object?>{
        'messageType': 'totallyUnknownType',
        'version': 1,
      },
      _ => <String, Object?>{
        'messageType': 'sdpOffer',
        'version': 1,
        'fromPeerId': 'peer-1',
        'toPeerId': 'peer-2',
        'sdp': 'x' * 20000, // oversized field
      },
    };

// --- Viewer admission (viewer capacity) domain generators ---

/// A command in a simulated ViewerAdmission session, for the stateful
/// cap-invariant PBT in viewer_admission_properties_test.dart.
sealed class AdmissionCommand {
  const AdmissionCommand();
}

/// Attempt to admit [peerId].
final class TryAdmitCommand extends AdmissionCommand {
  const TryAdmitCommand(this.peerId);
  final String peerId;
}

/// Release [peerId]'s slot (starts its reconnectWindow grace period).
final class ReleaseCommand extends AdmissionCommand {
  const ReleaseCommand(this.peerId);
  final String peerId;
}

/// Advance the injected clock by [duration] — this is what lets a
/// generated sequence cross a reconnectWindow boundary, sometimes just
/// short of it and sometimes just past it, so the sweep-at-expiry
/// behavior Rule 6 describes is actually exercised, not just the
/// immediate-reclaim path.
final class AdvanceClockCommand extends AdmissionCommand {
  const AdvanceClockCommand(this.duration);
  final Duration duration;
}

/// A small, fixed pool of candidate peer ids — deliberately small so that
/// collisions, reclaims, and repeated admit/release of the *same* peer id
/// actually occur in generated sequences (a fresh random peer id per
/// command would almost never exercise the reclaim path at all).
const List<String> _viewerPeerIds = [
  'peer-a',
  'peer-b',
  'peer-c',
];

/// A single [AdmissionCommand] with reasonable frequency for every kind:
/// try-admit (~40%), release (~30%), clock advance (~30%) — no kind below
/// ~15%, so the cap's interesting interactions (full + reserved + expiry)
/// are all reachable in one sequence.
AdmissionCommand _arbitraryAdmissionCommand(Random r) {
  final kind = r.nextInt(20);
  if (kind < 8) {
    return TryAdmitCommand(_viewerPeerIds[r.nextInt(_viewerPeerIds.length)]);
  }
  if (kind < 14) {
    return ReleaseCommand(_viewerPeerIds[r.nextInt(_viewerPeerIds.length)]);
  }
  // 0–200 seconds: spans both sides of the 120-second reconnectWindow so
  // the sweep boundary is crossed by the generator itself, not only by
  // hand-picked edge cases.
  return AdvanceClockCommand(Duration(seconds: any.intInRange(0, 201)(r)));
}

/// Sequence of up to 40 [AdmissionCommand]s for the stateful
/// ViewerAdmission PBT: admit/release/clock-advance interleavings where
/// the clock can race a reservation's expiry, with the empty sequence
/// reachable too.
final Generator<List<AdmissionCommand>> arbitraryAdmissionCommandSequence = any
    .listWithLengthInRange(0, 40, _arbitraryAdmissionCommand);

// --- Caption wire (remote output) domain generators ---

/// Generates a [Caption] message wrapping a randomized [SttResult].
Caption arbitraryCaption(Random random) =>
    Caption(result: arbitrarySttResult(random));

/// Generates a [CaptionActivityChanged] across all [CaptionActivity]
/// values.
CaptionActivityChanged arbitraryCaptionActivityChanged(Random random) =>
    CaptionActivityChanged(
      activity: any.choose(CaptionActivity.values)(random),
    );

/// Generates a [CaptionWireMessage] covering every one of the 3 sealed
/// variants (round-robin by random choice, not just one variant).
CaptionWireMessage arbitraryCaptionWireMessage(Random random) =>
    switch (random.nextInt(3)) {
      0 => arbitraryCaption(random),
      1 => arbitraryCaptionActivityChanged(random),
      _ => const Ended(),
    };

/// Generates deliberately malformed/adversarial JSON-shaped input for
/// `CaptionWireCodec.decode`'s never-throws property. A separate
/// generator from [arbitraryCaptionWireMessage] — this one targets
/// broken shapes, not valid messages.
Object? arbitraryMalformedCaptionWireJson(Random random) =>
    switch (random.nextInt(10)) {
      0 => null,
      1 => 'not a map',
      2 => 42,
      3 => <String, Object?>{},
      4 => <String, Object?>{'messageType': 'caption'}, // missing version
      5 => <String, Object?>{'version': 1}, // missing messageType
      6 => <String, Object?>{'messageType': 42, 'version': 1}, // wrong type
      7 => <String, Object?>{
        'messageType': 'caption',
        'version': 999, // unsupported version
        'text': 'hello world',
        'isFinal': true,
        'confidence': 1.0,
        'timestamp': '2026-01-01T00:00:00.000Z',
        'sourceId': 'default',
      },
      8 => <String, Object?>{
        'messageType': 'totallyUnknownType',
        'version': 1,
      },
      _ => <String, Object?>{
        'messageType': 'caption',
        'version': 1,
        'text': 'x' * 20000, // oversized field
        'isFinal': true,
        'confidence': 1.0,
        'timestamp': '2026-01-01T00:00:00.000Z',
        'sourceId': 'default',
      },
    };

// --- Broadcast session orchestration domain generators (Unit 6) ---

/// A single command in a `BroadcastSessionNotifier` stateful PBT sequence
/// (PBT-06). [GoLiveCommand]'s boolean flags simulate which `goLive()` step
/// fails (`business-rules.md` Rule 2) — the test driver realizes a `true`
/// flag by setting the corresponding fake collaborator's error field for
/// the duration of exactly that one call. Multiple flags may be `true`
/// simultaneously, deliberately — Rule 2's checks run in a fixed order
/// (sign-in, then identity, then ICE, then publish), so this also
/// exercises that priority ordering, not just each failure in isolation.
sealed class BroadcastSessionCommand {
  const BroadcastSessionCommand();
}

/// Attempt to go live.
final class GoLiveCommand extends BroadcastSessionCommand {
  /// Creates a [GoLiveCommand].
  const GoLiveCommand({
    this.signedOut = false,
    this.identityError = false,
    this.iceError = false,
    this.publishError = false,
  });

  /// Simulates `authNotifierProvider` reporting signed-out (F2-1).
  final bool signedOut;

  /// Simulates `BroadcastIdentityRepository.getOrCreateMine()` failing
  /// (F2-2).
  final bool identityError;

  /// Simulates `IceServerProvider.iceServersFor()` failing (F2-3).
  final bool iceError;

  /// Simulates `StatusChannel.publishLive()` failing (F2-7).
  final bool publishError;

  @override
  String toString() =>
      'GoLiveCommand(signedOut: $signedOut, identityError: $identityError, '
      'iceError: $iceError, publishError: $publishError)';
}

/// End the current broadcast.
final class EndBroadcastCommand extends BroadcastSessionCommand {
  const EndBroadcastCommand();

  @override
  String toString() => 'EndBroadcastCommand()';
}

/// A single [BroadcastSessionCommand] weighted toward realistic usage:
/// a clean `goLive()` (~55%), a `goLive()` failing at exactly one step
/// (~25%, evenly split across the four), and `endBroadcast()` (~20%).
BroadcastSessionCommand _arbitraryBroadcastSessionCommand(Random r) {
  final kind = r.nextInt(20);
  if (kind < 11) return const GoLiveCommand();
  if (kind < 14) return const GoLiveCommand(signedOut: true);
  if (kind < 15) return const GoLiveCommand(identityError: true);
  if (kind < 16) return const GoLiveCommand(iceError: true);
  if (kind < 17) return const GoLiveCommand(publishError: true);
  return const EndBroadcastCommand();
}

/// Weighted sequence of [BroadcastSessionCommand]s for the stateful
/// `BroadcastSessionNotifier` PBT (PBT-06): realistic flows (go live, end,
/// go live again) are common, while adversarial orderings (consecutive
/// `goLive()` calls, `endBroadcast()` with nothing live, repeated failures)
/// and the empty sequence remain reachable.
final Generator<List<BroadcastSessionCommand>>
arbitraryBroadcastSessionCommandSequence = any.listWithLengthInRange(
  0,
  20,
  _arbitraryBroadcastSessionCommand,
);

/// Generates a session name including deliberately adversarial inputs
/// (empty/whitespace-only, exactly-at-boundary length, embedded control
/// characters, Unicode) alongside normal ASCII strings — for
/// [BroadcastSettings.validateSessionName]'s invariant PBT (PBT-03, PBT-07).
Generator<String> get arbitraryBroadcastSessionNameInput => (r) {
  switch (r.nextInt(8)) {
    case 0:
      return '';
    case 1:
      return '   ';
    case 2:
      return 'a' * broadcastSessionNameMaxLength; // exactly at boundary
    case 3:
      return 'a' * (broadcastSessionNameMaxLength + 1); // one over
    case 4:
      // Embedded control character at a random position.
      final base = any.letterOrDigits(r);
      final controlChar = String.fromCharCode(r.nextInt(0x20));
      final pos = base.isEmpty ? 0 : r.nextInt(base.length + 1);
      return base.substring(0, pos) + controlChar + base.substring(pos);
    case 5:
      return 'héllo wörld 日本語'; // Unicode, otherwise valid
    default:
      return any.letterOrDigits(r);
  }
};

// --- Viewer session orchestration domain generators (Unit 7) ---

/// Generates every [ConnectionType] (`domain-entities.md`'s live-view
/// routing field).
final Generator<ConnectionType> arbitraryConnectionType = any.choose(
  ConnectionType.values,
);

/// Generates every [CaptionActivity] value.
final Generator<CaptionActivity> arbitraryCaptionActivity = any.choose(
  CaptionActivity.values,
);

/// Generates every [ConnectFailure] variant, including Unit 7's three
/// additive resolution-origin reasons (Rule 5's seven-row table).
final Generator<ConnectFailure> arbitraryConnectFailure = any.choose(
  const <ConnectFailure>[
    BroadcastFull(),
    IceFailed(),
    SignalingRejected(),
    Timeout(),
    RateLimited(),
    ResolutionFailed(),
    NotFound(),
  ],
);

/// A single command in a `ViewerSessionNotifier` stateful PBT sequence
/// (PBT-06). The booleans on [JoinCommand] and the sub-kinds of
/// [TransportStatusCommand] keep every reachable transition in scope while
/// the generator's weighting leans toward realistic viewing flows.
sealed class ViewerSessionCommand {
  const ViewerSessionCommand();
}

/// Attempt a join. [invalid] submits a string that fails parsing;
/// [differentBroadcast] joins a different valid code; [throwsOnConnect]
/// makes the fake transport's `connect()` throw.
final class JoinCommand extends ViewerSessionCommand {
  /// Creates a [JoinCommand].
  const JoinCommand({
    this.invalid = false,
    this.differentBroadcast = false,
    this.throwsOnConnect = false,
  });

  /// Whether the submitted input is invalid.
  final bool invalid;

  /// Whether the submitted input names a different broadcast.
  final bool differentBroadcast;

  /// Whether `transport.connect()` throws.
  final bool throwsOnConnect;

  @override
  String toString() =>
      'JoinCommand(invalid: $invalid, differentBroadcast: '
      '$differentBroadcast, throwsOnConnect: $throwsOnConnect)';
}

/// Emit a status-channel event (liveness authority, Rule 4).
final class StatusChannelEventCommand extends ViewerSessionCommand {
  /// Creates a [StatusChannelEventCommand].
  const StatusChannelEventCommand({required this.live});

  /// `true` for a live emission, `false` for offline.
  final bool live;

  @override
  String toString() => 'StatusChannelEventCommand(live: $live)';
}

/// Emit a transport status event.
final class TransportStatusCommand extends ViewerSessionCommand {
  /// Creates a [TransportStatusCommand] for [status].
  const TransportStatusCommand(this.status);

  /// The emitted status.
  final ConnectionStatus status;

  @override
  String toString() => 'TransportStatusCommand($status)';
}

/// Emit a caption-activity event.
final class ActivityCommand extends ViewerSessionCommand {
  /// Creates an [ActivityCommand].
  const ActivityCommand(this.activity);

  /// The emitted activity.
  final CaptionActivity activity;

  @override
  String toString() => 'ActivityCommand(${activity.name})';
}

/// Emit the broadcast-ended message.
final class EndedCommand extends ViewerSessionCommand {
  /// Creates an [EndedCommand].
  const EndedCommand();

  @override
  String toString() => 'EndedCommand()';
}

/// Advance the `fakeAsync` clock past the reconnect window.
final class WindowExpiryCommand extends ViewerSessionCommand {
  /// Creates a [WindowExpiryCommand].
  const WindowExpiryCommand();

  @override
  String toString() => 'WindowExpiryCommand()';
}

/// Call `leave()`.
final class LeaveCommand extends ViewerSessionCommand {
  /// Creates a [LeaveCommand].
  const LeaveCommand();

  @override
  String toString() => 'LeaveCommand()';
}

/// A single [ViewerSessionCommand], weighted so leave (~20%), join (~20%),
/// transport events (~25%), status events (~15%), expiry (~10%), and
/// activity/ended (~10%) are all reachable.
///
/// The range is 21 so every kind — including 20, the activity fallback —
/// can actually be drawn; with 20 the fallback was unreachable.
ViewerSessionCommand _arbitraryViewerSessionCommand(Random r) {
  final kind = r.nextInt(21);
  if (kind < 4) return const LeaveCommand();
  if (kind < 6) return const JoinCommand();
  if (kind < 7) return const JoinCommand(invalid: true);
  if (kind < 8) return const JoinCommand(differentBroadcast: true);
  if (kind < 9) return const JoinCommand(throwsOnConnect: true);
  if (kind < 14) {
    return TransportStatusCommand(
      switch (r.nextInt(4)) {
        0 => const Connecting(),
        1 => Connected(arbitraryConnectionType(r)),
        2 => const Interrupted(),
        _ => Failed(arbitraryConnectFailure(r)),
      },
    );
  }
  if (kind < 17) {
    return StatusChannelEventCommand(live: r.nextBool());
  }
  if (kind < 19) return const WindowExpiryCommand();
  if (kind == 19) return const EndedCommand();
  return ActivityCommand(arbitraryCaptionActivity(r));
}

/// Weighted sequence of [ViewerSessionCommand]s for the stateful
/// `ViewerSessionNotifier` PBT (PBT-06): realistic viewing flows are
/// common, adversarial orderings (joins during terminal states, expiry
/// without a window, repeated leaves) and the empty sequence are reachable.
final Generator<List<ViewerSessionCommand>>
arbitraryViewerSessionCommandSequence = any.listWithLengthInRange(
  0,
  20,
  _arbitraryViewerSessionCommand,
);
