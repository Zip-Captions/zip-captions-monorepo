import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_captions/src/l10n/zc_strings.dart';
import 'package:zip_core/zip_core.dart';

/// Shows the iOS speech explainer once, before the first call to `start()`
/// (Unit 10, Amendment 02 section 6.1; BR-U10-33).
///
/// On iOS, Apple's own microphone and speech-recognition prompts mention that
/// speech is sent to Apple, which reads as a contradiction of Zip Captions'
/// on-device stance. This gate explains the difference first. The ordering
/// guarantee is the whole point: [builder] (which leads to `start()`) is not
/// built at all until the explainer has been acknowledged (TP-19).
///
/// Android, macOS, Windows, Linux and web have no explainer; that prompt text
/// is not shown there.
///
/// "Continue" records [seenKey] and proceeds. "Not now" records nothing,
/// requests nothing, and returns to Home. The flag is a non-sensitive
/// convenience, so it lives in [SharedPreferences] rather than secure storage:
/// if it is cleared, the explainer simply appears again.
class SpeechExplainerGate extends ConsumerWidget {
  /// Creates the gate.
  const SpeechExplainerGate({
    required this.platform,
    required this.strings,
    required this.onStart,
    required this.onBackToHome,
    required this.builder,
    super.key,
  });

  /// The preference key that records an acknowledged explainer.
  static const seenKey = 'onboarding.speechExplainerSeen';

  /// The platform to decide for. Passed in so a widget test can pin it.
  final TargetPlatform platform;

  /// The localised explainer copy.
  final ZcStrings strings;

  /// Runs the screen's start sequence once the gate has been passed.
  final Future<void> Function() onStart;

  /// Leaves for Home when the user declines.
  final VoidCallback onBackToHome;

  /// Builds the gated screen.
  final WidgetBuilder builder;

  /// Whether the explainer is needed for [platform] (iOS only).
  static bool isRequiredFor(TargetPlatform platform) =>
      platform == TargetPlatform.iOS;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _GateBody(
      platform: platform,
      strings: strings,
      onStart: onStart,
      onBackToHome: onBackToHome,
      builder: builder,
      prefs: ref.read(sharedPreferencesProvider),
    );
  }
}

class _GateBody extends StatefulWidget {
  const _GateBody({
    required this.platform,
    required this.strings,
    required this.onStart,
    required this.onBackToHome,
    required this.builder,
    required this.prefs,
  });

  final TargetPlatform platform;
  final ZcStrings strings;
  final Future<void> Function() onStart;
  final VoidCallback onBackToHome;
  final WidgetBuilder builder;
  final SharedPreferences prefs;

  @override
  State<_GateBody> createState() => _GateBodyState();
}

class _GateBodyState extends State<_GateBody> {
  bool _passed = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    final required = SpeechExplainerGate.isRequiredFor(widget.platform);
    final seen = widget.prefs.getBool(SpeechExplainerGate.seenKey) ?? false;
    _passed = !required || seen;
    if (_passed) {
      // `onStart` reaches notifiers and `setState`, which a build (and so
      // `initState`) must not do. Let the first frame land first.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_startOnce());
      });
    }
  }

  Future<void> _startOnce() async {
    if (_started) return;
    _started = true;
    await widget.onStart();
  }

  /// Whether Continue's write of the flag is in flight. Both buttons are
  /// disabled meanwhile, so a second tap cannot write twice and "Not now"
  /// cannot leave Home-bound while the flag is being recorded.
  bool _continuing = false;

  Future<void> _continue() async {
    if (_continuing) return;
    setState(() => _continuing = true);
    try {
      await widget.prefs.setBool(SpeechExplainerGate.seenKey, true);
    } on Object {
      // A failed write leaves the explainer up with its buttons usable
      // again, so the user can tap Continue once more. Nothing is logged: the
      // flag is a convenience and the failure carries nothing to act on.
      if (mounted) setState(() => _continuing = false);
      return;
    }
    if (!mounted) return;
    _continuing = false;
    setState(() => _passed = true);
    await _startOnce();
  }

  @override
  Widget build(BuildContext context) {
    if (!_passed) {
      return Scaffold(
        body: _ExplainerView(
          strings: widget.strings,
          onContinue: _continuing ? null : _continue,
          onNotNow: _continuing ? null : widget.onBackToHome,
        ),
      );
    }
    return widget.builder(context);
  }
}

class _ExplainerView extends StatelessWidget {
  const _ExplainerView({
    required this.strings,
    required this.onContinue,
    required this.onNotNow,
  });

  final ZcStrings strings;

  /// `null` while Continue's write is pending (the button is disabled).
  final Future<void> Function()? onContinue;

  /// `null` while Continue's write is pending (the button is disabled).
  final VoidCallback? onNotNow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                strings.speechExplainerTitle,
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                strings.speechExplainerBody,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onContinue == null
                    ? null
                    : () => unawaited(onContinue!()),
                child: Text(strings.speechExplainerContinue),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: onNotNow,
                child: Text(strings.speechExplainerNotNow),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
