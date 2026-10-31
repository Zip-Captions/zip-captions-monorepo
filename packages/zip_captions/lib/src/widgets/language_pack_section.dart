import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:zip_captions/src/l10n/zc_strings.dart';
import 'package:zip_captions/src/providers/language_pack_providers.dart';
import 'package:zip_captions/src/widgets/language_pack_action.dart';
import 'package:zip_core/zip_core.dart';

/// How often the status is re-checked while a download reports no percent.
const Duration kLanguagePackRecheckInterval = Duration(seconds: 5);

/// How long the re-check goes on before the download counts as failed.
const Duration kLanguagePackRecheckLimit = Duration(minutes: 5);

/// How long a status request may take before the section gives up on it
/// (BR-U10-64 (a)).
const Duration kLanguagePackStatusTimeout = Duration(seconds: 5);

enum _Phase { checking, idle, downloading, scheduled, ready, failed }

/// The part of the on-device-unavailable panel that deals with a missing
/// language (Amendment 04, BR-U10-46 to 48).
///
/// On mount it asks the [LanguagePackService] for the status of [localeId]
/// and shows what [languagePackActionFor] says. **It never starts a download
/// by itself** (BR-U10-48): only a tap on "Download" does, and only one
/// download is in flight at a time. **It never starts captioning either**:
/// "Try again" stays the panel's only path back to `start()`.
///
/// A download the platform deferred (a `scheduled` event, or a first status
/// of `downloading`, which on Android is "pending") shows the scheduled
/// state: not a failure, no time limit and no re-check (BR-U10-47a). After a
/// tap that produces no event at all (Android 13 fires and forgets), the
/// status is re-checked every [kLanguagePackRecheckInterval] for at most
/// [kLanguagePackRecheckLimit], then the download counts as failed; on
/// Android a re-check that finds `downloading` means the platform has only
/// queued it, so it shows the scheduled state instead (BR-U10-64 (c)). A
/// progress event with a percent ends that polling: the platform is then
/// telling us how it is going, and if no further event arrives within
/// [kLanguagePackRecheckLimit] the download counts as failed (BR-U10-64 (b)).
/// A status request that gets no reply within [kLanguagePackStatusTimeout]
/// shows the failed state too (BR-U10-64 (a)).
///
/// **Security (SECURITY-03)**: logs carry exception type names only; never the
/// locale, the display name or an exception message.
class LanguagePackSection extends ConsumerStatefulWidget {
  /// Creates the section for [localeId].
  const LanguagePackSection({
    required this.localeId,
    required this.strings,
    required this.platform,
    super.key,
  });

  /// The session's resolved locale tag.
  final String localeId;

  /// The localised copy.
  final ZcStrings strings;

  /// The platform to decide for.
  final TargetPlatform platform;

  @override
  ConsumerState<LanguagePackSection> createState() =>
      _LanguagePackSectionState();
}

class _LanguagePackSectionState extends ConsumerState<LanguagePackSection> {
  static final _log = Logger('zip_captions.LanguagePackSection');

  LanguagePackService? _service;
  StreamSubscription<LanguagePackEvent>? _subscription;
  Timer? _timer;

  /// Fails the download when no progress event follows the last one within
  /// [kLanguagePackRecheckLimit] (BR-U10-64 (b)).
  Timer? _stallTimer;
  Duration _polled = Duration.zero;

  _Phase _phase = _Phase.checking;
  LanguagePackInfo? _info;
  int? _percent;

  String get _language => _info?.displayName ?? widget.localeId;

  @override
  void initState() {
    super.initState();
    try {
      _service = ref.read(languagePackServiceProvider);
    } on Object catch (e) {
      _log.warning('Language-pack service unavailable: ${e.runtimeType}');
    }
    _subscription = _service?.events.listen(
      _onEvent,
      onError: (Object e) =>
          _log.warning('Language-pack event error: ${e.runtimeType}'),
    );
    unawaited(_loadStatus());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stallTimer?.cancel();
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  /// Tags compare ignoring case and with '-' and '_' the same.
  static String _canonical(String tag) =>
      tag.toLowerCase().replaceAll('_', '-');

  bool _isMine(LanguagePackEvent event) =>
      _canonical(event.localeId) == _canonical(widget.localeId);

  /// Asks for the status, bounded by [kLanguagePackStatusTimeout]. A failure
  /// is `unknown`; a request with no reply in time is `null`.
  Future<LanguagePackInfo?> _fetch() async {
    try {
      return await _service!
          .status(widget.localeId)
          .timeout(kLanguagePackStatusTimeout);
    } on TimeoutException {
      _log.warning('Language-pack status timed out');
      return null;
    } on Object catch (e) {
      _log.warning('Language-pack status failed: ${e.runtimeType}');
      return LanguagePackInfo(
        status: LanguagePackStatus.unknown,
        displayName: widget.localeId,
      );
    }
  }

  Future<void> _loadStatus() async {
    final fetched = _service == null
        ? LanguagePackInfo(
            status: LanguagePackStatus.unknown,
            displayName: widget.localeId,
          )
        : await _fetch();
    if (!mounted) return;
    if (fetched == null) {
      // BR-U10-64 (a): no reply is a failure the user can see, not a panel
      // that sits empty. The tag stands in for the display name.
      setState(() {
        _info = LanguagePackInfo(
          status: LanguagePackStatus.unknown,
          displayName: widget.localeId,
        );
        _phase = _Phase.failed;
      });
      return;
    }
    final info = fetched;
    setState(() {
      _info = info;
      // BR-U10-47a: pending at the first check is a deferred download, not
      // one in flight: no timer, no limit.
      _phase = info.status == LanguagePackStatus.downloading
          ? _Phase.scheduled
          : _Phase.idle;
    });
  }

  void _onEvent(LanguagePackEvent event) {
    if (!mounted || !_isMine(event)) return;
    switch (event) {
      case LanguagePackProgress(:final percent):
        if (_phase != _Phase.downloading) return;
        setState(() => _percent = percent?.clamp(0, 100));
        // The platform reports a percentage: no polling needed, but the
        // platform must keep reporting (BR-U10-64 (b)).
        if (percent != null) {
          _stopPolling();
          _armStallTimer();
        }
      case LanguagePackScheduled():
        if (_phase == _Phase.downloading) _finish(_Phase.scheduled);
      case LanguagePackDone():
        if (_phase == _Phase.downloading || _phase == _Phase.scheduled) {
          _finish(_Phase.ready);
        }
      case LanguagePackFailed():
        if (_phase == _Phase.downloading) _finish(_Phase.failed);
    }
  }

  void _finish(_Phase phase) {
    _stopPolling();
    _stallTimer?.cancel();
    _stallTimer = null;
    if (!mounted) return;
    setState(() => _phase = phase);
  }

  Future<void> _onDownloadTapped() async {
    // At most one download in flight (TP-29).
    if (_phase != _Phase.idle) return;
    final service = _service;
    if (service == null) return;
    setState(() {
      _phase = _Phase.downloading;
      _percent = null;
    });
    _startPolling();
    try {
      await service.download(widget.localeId);
    } on Object catch (e) {
      _log.warning('Language-pack download failed: ${e.runtimeType}');
      _finish(_Phase.failed);
    }
  }

  void _startPolling() {
    _timer?.cancel();
    _polled = Duration.zero;
    _timer = Timer.periodic(kLanguagePackRecheckInterval, (_) {
      unawaited(_recheck());
    });
  }

  void _stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  /// (Re)starts the stall limit: a progress event arrived, so the next one is
  /// due within [kLanguagePackRecheckLimit] or the download counts as failed.
  void _armStallTimer() {
    _stallTimer?.cancel();
    _stallTimer = Timer(kLanguagePackRecheckLimit, () {
      _stallTimer = null;
      if (mounted && _phase == _Phase.downloading) _finish(_Phase.failed);
    });
  }

  Future<void> _recheck() async {
    _polled += kLanguagePackRecheckInterval;
    final info = await _fetch();
    if (!mounted || _phase != _Phase.downloading || _timer == null) return;
    if (info?.status == LanguagePackStatus.installed) {
      _finish(_Phase.ready);
    } else if (info?.status == LanguagePackStatus.downloading &&
        widget.platform == TargetPlatform.android) {
      // BR-U10-64 (c): on Android `downloading` is "pending", the platform has
      // queued the download (as at the first check, BR-U10-47a). On iOS it is
      // a real transfer, so that path is unchanged.
      _finish(_Phase.scheduled);
    } else if (_polled >= kLanguagePackRecheckLimit) {
      _finish(_Phase.failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    final theme = Theme.of(context);
    final info = _info;
    if (info == null) return const SizedBox.shrink();

    Widget text(String value) => Semantics(
      liveRegion: true,
      child: Text(
        value,
        style: theme.textTheme.bodyMedium,
        textAlign: TextAlign.center,
      ),
    );

    switch (_phase) {
      case _Phase.checking:
        return const SizedBox.shrink();
      case _Phase.scheduled:
        return text(strings.languagePackScheduled(_language));
      case _Phase.ready:
        return text(strings.languagePackReady(_language));
      case _Phase.failed:
        return text(strings.languagePackFailed(_language));
      case _Phase.downloading:
        final percent = _percent;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            text(
              percent == null
                  ? strings.languagePackDownloading(_language)
                  : strings.languagePackDownloadingPercent(_language, percent),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: percent == null ? null : percent / 100,
            ),
          ],
        );
      case _Phase.idle:
        final action = languagePackActionFor(
          platform: widget.platform,
          osVersion: ref.watch(languagePackOsVersionProvider),
          status: info.status,
        );
        return switch (action) {
          LanguagePackAction.download => FilledButton.tonal(
            onPressed: () => unawaited(_onDownloadTapped()),
            child: Text(strings.languagePackDownload(_language)),
          ),
          LanguagePackAction.instructions => text(
            strings.languagePackIosInstructions(_language),
          ),
          // `scheduled` is entered through the scheduled phase, never here:
          // a status of downloading sets that phase directly.
          LanguagePackAction.scheduled ||
          LanguagePackAction.none => const SizedBox.shrink(),
        };
    }
  }
}
