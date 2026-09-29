import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:zip_core/src/models/auth_failure.dart';
import 'package:zip_core/src/models/auth_provider_option.dart';
import 'package:zip_core/src/models/auth_state.dart';
import 'package:zip_core/src/services/auth/auth_service.dart';

/// GoTrue-backed [AuthService].
///
/// `supabase_flutter` already subscribes to `app_links` internally on every
/// non-web platform and calls `getSessionFromUrl` automatically
/// (`FlutterAuthClientOptions.detectSessionInUri`, default `true`, left at
/// its default) — that path is what actually completes a *successful*
/// sign-in via [authStateChanges].
///
/// It does **not**, however, surface *failures* that happen after the
/// browser opens (the user declining consent, a rejected PKCE exchange):
/// its internal handler catches those itself and only calls an
/// undocumented, non-public `notifyException`. To honor the approved
/// failure taxonomy (`sr-01-oauth-approach.md` Section 7), this class runs
/// its own [AppLinks] subscription in parallel, on non-web platforms only,
/// but only to inspect the callback's `error` query parameter — it never
/// calls `getSessionFromUrl` itself, so it never races the SDK's own
/// one-shot PKCE code consumption.
class SupabaseAuthService implements AuthService {
  /// Creates a [SupabaseAuthService] backed by [client], resolving provider
  /// ids against [providerConfig]. [desktopRedirectUri] must match the
  /// custom URL scheme registered at the platform level (SR-01 Section 3).
  SupabaseAuthService({
    required sb.SupabaseClient client,
    required AuthProviderConfig providerConfig,
    this.desktopRedirectUri = 'io.zipcaptions.broadcast://login-callback',
    AppLinks? appLinks,
  })  : _client = client,
        _providerConfig = providerConfig,
        _appLinks = appLinks ?? AppLinks() {
    _current = _computeInitialState();
    _authSub = _client.auth.onAuthStateChange.listen(_handleAuthChange);
    _linkSub =
        kIsWeb ? null : _appLinks.uriLinkStream.listen(_handleIncomingUri);
    _lifecycleListener = AppLifecycleListener(onResume: _handleResume);
  }

  /// The custom URL scheme registered on macOS/Windows/Linux for the OAuth
  /// callback (SR-01 Section 3). Unused on web.
  final String desktopRedirectUri;

  final sb.SupabaseClient _client;
  final AuthProviderConfig _providerConfig;
  final AppLinks _appLinks;
  final Logger _log = Logger('SupabaseAuthService');

  late final StreamSubscription<sb.AuthState> _authSub;
  late final StreamSubscription<Uri?>? _linkSub;
  late final AppLifecycleListener _lifecycleListener;

  /// Grace window after an app-foreground-resume with no completed callback,
  /// before treating a `signingIn` attempt as abandoned (NFR Design Q1).
  static const resumeGrace = Duration(seconds: 2);

  /// Hard backstop for an attempt that never resolves at all (NFR Design Q1).
  static const hardTimeout = Duration(minutes: 3);

  Timer? _hardTimeoutTimer;
  Timer? _resumeGraceTimer;

  late AuthState _current;
  final _stateController = StreamController<AuthState>.broadcast();

  // Stream.multi (not an async* generator) so the current value and the
  // underlying subscription attach synchronously on listen, with no
  // microtask gap a state change immediately after subscribing could fall
  // into and be missed (broadcast streams do not buffer for late
  // subscribers).
  @override
  Stream<AuthState> get authStateChanges => Stream<AuthState>.multi((
    controller,
  ) {
    controller.add(_current);
    final sub = _stateController.stream.listen(
      controller.add,
      onDone: controller.close,
    );
    controller.onCancel = sub.cancel;
  });

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  @override
  Future<void> signIn(String providerId) async {
    if (_current is SigningInState) return; // Rule 1
    final option = _providerConfig.providers.firstWhere(
      (candidate) => candidate.id == providerId,
      orElse: () =>
          throw ArgumentError('Unknown providerId for signIn: $providerId'),
    );
    _setState(AuthState.signingIn(providerId: providerId));
    _armResilience(providerId);
    try {
      await _client.auth.signInWithOAuth(
        option.provider,
        redirectTo: kIsWeb ? null : desktopRedirectUri,
        authScreenLaunchMode: kIsWeb
            ? sb.LaunchMode.platformDefault
            : sb.LaunchMode.externalApplication,
      );
    } on Object catch (error, stackTrace) {
      _disarmResilience();
      _setState(
        AuthState.authFailed(
          providerId: providerId,
          reason: _mapException(error, stackTrace),
        ),
      );
    }
  }

  @override
  Future<void> signOut() async {
    if (_current is SignedOutState) return; // Rule 8
    _disarmResilience();
    _setState(const AuthState.signedOut()); // Rule 2: local-first
    try {
      await _client.auth.signOut(scope: sb.SignOutScope.global);
    } on Object catch (error, stackTrace) {
      _log.warning(
        'signOut server-side revoke failed: ${error.runtimeType}',
        null,
        stackTrace,
      );
      // Local sign-out already applied; do not revert (Rule 2).
    }
  }

  /// Releases the auth-state, deep-link, and lifecycle subscriptions. Not
  /// part of [AuthService] — this instance is a `keepAlive` app-lifetime
  /// singleton in normal operation, but tests construct several.
  void dispose() {
    unawaited(_authSub.cancel());
    unawaited(_linkSub?.cancel());
    _lifecycleListener.dispose();
    _disarmResilience();
    unawaited(_stateController.close());
  }

  void _handleAuthChange(sb.AuthState authState) {
    switch (authState.event) {
      case sb.AuthChangeEvent.signedIn:
        final userId = authState.session?.user.id;
        if (userId == null) return;
        _disarmResilience();
        _setState(AuthState.signedIn(userId: userId));
      case sb.AuthChangeEvent.signedOut:
        // Every signedOut event routes to signedOut, never authFailed,
        // regardless of SignOutReason (Rule 3) — including a passive
        // background session loss (F-BA-7).
        _disarmResilience();
        _setState(const AuthState.signedOut());
      case _:
        break;
    }
  }

  void _handleIncomingUri(Uri? uri) {
    if (uri == null) return;
    final current = _current;
    if (current is! SigningInState) return; // nothing in flight
    final error = uri.queryParameters['error'];
    if (error == null) return; // no failure signal — let the SDK finish
    _disarmResilience();
    // `denied` is reserved for GoTrue/provider-configuration rejection
    // (surfaced via AuthException from _mapException, not this callback
    // param) — SR-01 §7. Any callback error other than the user declining
    // consent is an unrecognized outcome, mapped to the providerError
    // catch-all, not `denied`.
    final reason = error == 'access_denied'
        ? AuthFailure.cancelled
        : AuthFailure.providerError;
    _setState(
      AuthState.authFailed(providerId: current.providerId, reason: reason),
    );
  }

  void _handleResume() {
    final current = _current;
    if (current is! SigningInState) return;
    _resumeGraceTimer?.cancel();
    _resumeGraceTimer = Timer(
      resumeGrace,
      () => _resolveAbandoned(current.providerId),
    );
  }

  void _armResilience(String providerId) {
    _hardTimeoutTimer = Timer(
      hardTimeout,
      () => _resolveAbandoned(providerId),
    );
  }

  void _resolveAbandoned(String providerId) {
    final current = _current;
    if (current is! SigningInState || current.providerId != providerId) {
      return;
    }
    _disarmResilience();
    _setState(
      AuthState.authFailed(
        providerId: providerId,
        reason: AuthFailure.cancelled,
      ),
    );
  }

  void _disarmResilience() {
    _hardTimeoutTimer?.cancel();
    _resumeGraceTimer?.cancel();
    _hardTimeoutTimer = null;
    _resumeGraceTimer = null;
  }

  /// The single chokepoint mapping an OAuth-flow exception to an
  /// [AuthFailure] (SR-01 Section 7, `business-rules.md` Rule 4/9). Logs
  /// only the exception's type and stack trace — never its message, which
  /// could echo back query parameters or other incidental detail.
  AuthFailure _mapException(Object error, StackTrace stackTrace) {
    _log.warning(
      'OAuth attempt failed: ${error.runtimeType}',
      null,
      stackTrace,
    );
    if (error is sb.AuthRetryableFetchException) return AuthFailure.network;
    if (error is sb.AuthException) return AuthFailure.denied;
    return AuthFailure.providerError;
  }

  AuthState _computeInitialState() {
    final userId = _client.auth.currentUser?.id;
    return userId != null
        ? AuthState.signedIn(userId: userId)
        : const AuthState.signedOut();
  }

  void _setState(AuthState state) {
    _current = state;
    _stateController.add(state);
  }
}
