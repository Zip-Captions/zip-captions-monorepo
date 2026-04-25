import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zip_broadcast/src/l10n/zip_broadcast_localizations.dart';
import 'package:zip_broadcast/src/models/obs_connection_status.dart';
import 'package:zip_broadcast/src/models/output_target_settings.dart';
import 'package:zip_broadcast/src/providers/broadcast_providers.dart';
import 'package:zip_broadcast/src/providers/obs_connection_notifier.dart';
import 'package:zip_broadcast/src/providers/settings_notifier.dart';
import 'package:zip_broadcast/src/widgets/coming_soon_card.dart';
import 'package:zip_core/zip_core.dart';

/// Settings screen with animated drill-down navigation (C6, F1–F7).
///
/// Uses an [AnimatedSwitcher] between the list view and detail views.
/// No Navigator push — back sets [_SettingsView] to [_SettingsView.list].
class SettingsScreen extends ConsumerStatefulWidget {
  /// Creates a [SettingsScreen].
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

enum _SettingsView {
  list,
  appearance,
  obs,
  outputTargets,
  audioInputs,
  transcripts,
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  _SettingsView _view = _SettingsView.list;

  void _goTo(_SettingsView view) => setState(() => _view = view);
  void _goBack() => setState(() => _view = _SettingsView.list);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _view == _SettingsView.list
          ? null
          : AppBar(
              leading: BackButton(onPressed: _goBack),
              title: Text(_viewTitle(context, _view)),
            ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _buildView(context),
      ),
    );
  }

  Widget _buildView(BuildContext context) {
    return switch (_view) {
      _SettingsView.list => _ListView(onTap: _goTo),
      _SettingsView.appearance => const _AppearanceDetail(),
      _SettingsView.obs => const _ObsDetail(),
      _SettingsView.outputTargets => const _OutputTargetsDetail(),
      _SettingsView.audioInputs => _AudioInputsDetail(
          onNavigate: () => context.go('/audio-inputs'),
        ),
      _SettingsView.transcripts => const _TranscriptsDetail(),
    };
  }

  String _viewTitle(BuildContext context, _SettingsView view) {
    final l10n = ZipBroadcastLocalizations.of(context)!;
    return switch (view) {
      _SettingsView.list => l10n.appTitleSettings,
      _SettingsView.appearance => l10n.settingsAppearance,
      _SettingsView.obs => l10n.settingsObs,
      _SettingsView.outputTargets => l10n.settingsOutputTargets,
      _SettingsView.audioInputs => l10n.settingsAudioInputs,
      _SettingsView.transcripts => l10n.settingsTranscripts,
    };
  }
}

String _obsStatusLabel(
  ZipBroadcastLocalizations l10n,
  ObsConnectionStatus status,
) {
  return switch (status) {
    ObsConnectionStatus.connected => l10n.obsStatusConnected,
    ObsConnectionStatus.connecting => l10n.obsStatusConnecting,
    ObsConnectionStatus.reconnecting => l10n.obsStatusReconnecting,
    ObsConnectionStatus.error => l10n.obsStatusError,
    ObsConnectionStatus.disconnected => l10n.obsStatusDisconnected,
  };
}

String _textSizeLabel(ZipBroadcastLocalizations l10n, CaptionTextSize size) {
  return switch (size) {
    CaptionTextSize.xs => l10n.appearanceTextSizeLabelXs,
    CaptionTextSize.sm => l10n.appearanceTextSizeLabelSm,
    CaptionTextSize.md => l10n.appearanceTextSizeLabelMd,
    CaptionTextSize.lg => l10n.appearanceTextSizeLabelLg,
    CaptionTextSize.xl => l10n.appearanceTextSizeLabelXl,
    CaptionTextSize.xxl => l10n.appearanceTextSizeLabelXxl,
  };
}

// ---------------------------------------------------------------------------
// List view
// ---------------------------------------------------------------------------

class _ListView extends ConsumerWidget {
  const _ListView({required this.onTap});

  final void Function(_SettingsView) onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outputSettings = ref.watch(outputTargetSettingsNotifierProvider);
    final obsStatus = ref.watch(obsConnectionNotifierProvider);
    final l10n = ZipBroadcastLocalizations.of(context)!;

    return ListView(
      key: const ValueKey('list'),
      children: [
        ListTile(
          leading: const Icon(Icons.format_size),
          title: Text(l10n.settingsAppearance),
          subtitle: Text(l10n.settingsAppearanceSubtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => onTap(_SettingsView.appearance),
        ),
        ListTile(
          leading: const Icon(Icons.cast),
          title: Text(l10n.settingsObs),
          subtitle: Text(
            _obsSubLabel(l10n, obsStatus, outputSettings.obsEnabled),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => onTap(_SettingsView.obs),
        ),
        ListTile(
          leading: const Icon(Icons.output),
          title: Text(l10n.settingsOutputTargets),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => onTap(_SettingsView.outputTargets),
        ),
        ListTile(
          leading: const Icon(Icons.mic),
          title: Text(l10n.settingsAudioInputs),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => onTap(_SettingsView.audioInputs),
        ),
        ListTile(
          leading: const Icon(Icons.article_outlined),
          title: Text(l10n.settingsTranscripts),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => onTap(_SettingsView.transcripts),
        ),
      ],
    );
  }

  static String _obsSubLabel(
    ZipBroadcastLocalizations l10n,
    ObsConnectionStatus status,
    bool enabled,
  ) {
    if (!enabled) return l10n.obsStatusDisabled;
    return _obsStatusLabel(l10n, status);
  }
}

// ---------------------------------------------------------------------------
// Appearance detail (F3)
// ---------------------------------------------------------------------------

class _AppearanceDetail extends ConsumerWidget {
  const _AppearanceDetail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(displaySettingsProvider);
    final notifier = ref.read(displaySettingsProvider.notifier);

    final l10n = ZipBroadcastLocalizations.of(context)!;
    return ListView(
      key: const ValueKey('appearance'),
      padding: const EdgeInsets.all(16),
      children: [
        Text(l10n.appearanceTextSize,
            style: Theme.of(context).textTheme.labelLarge),
        Wrap(
          spacing: 4,
          children: CaptionTextSize.values.map((size) {
            return ChoiceChip(
              label: Text(_textSizeLabel(l10n, size)),
              selected: settings.captionTextSize == size,
              onSelected: (_) =>
                  unawaited(notifier.setCaptionTextSize(size)),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Text(l10n.appearanceFont,
            style: Theme.of(context).textTheme.labelLarge),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: CaptionFont.values.map((font) {
            return ChoiceChip(
              label: Text(font.fontFamily),
              selected: settings.captionFont == font,
              onSelected: (_) => unawaited(notifier.setCaptionFont(font)),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.appearanceScrollDirection,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        Wrap(
          spacing: 4,
          children: [
            ChoiceChip(
              label: Text(l10n.appearanceNewAtBottom),
              selected:
                  settings.scrollDirection == ScrollDirection.bottomToTop,
              onSelected: (_) => unawaited(
                notifier.setScrollDirection(ScrollDirection.bottomToTop),
              ),
            ),
            ChoiceChip(
              label: Text(l10n.appearanceNewAtTop),
              selected:
                  settings.scrollDirection == ScrollDirection.topToBottom,
              onSelected: (_) => unawaited(
                notifier.setScrollDirection(ScrollDirection.topToBottom),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: Text(l10n.appearanceDarkTheme),
          value: settings.themeModeSetting == ThemeModeSetting.dark,
          onChanged: (v) => unawaited(
            notifier.setThemeModeSetting(
              v ? ThemeModeSetting.dark : ThemeModeSetting.system,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// OBS detail (F4)
// ---------------------------------------------------------------------------

class _ObsDetail extends ConsumerStatefulWidget {
  const _ObsDetail();

  @override
  ConsumerState<_ObsDetail> createState() => _ObsDetailState();
}

class _ObsDetailState extends ConsumerState<_ObsDetail> {
  late final TextEditingController _hostCtrl;
  late final TextEditingController _portCtrl;
  late final TextEditingController _passCtrl;
  Timer? _saveDebounce;

  // Prevents the async-load callback from overwriting user edits.
  bool _userEdited = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(obsSettingsNotifierProvider);
    _hostCtrl = TextEditingController(text: settings.host);
    _portCtrl = TextEditingController(text: settings.port.toString());
    _passCtrl = TextEditingController(text: settings.password);

    // If the provider's synchronous build returned defaults, re-seed once
    // the async SharedPreferences load completes (if user hasn't edited yet).
    ref.listenManual(obsSettingsNotifierProvider, (prev, next) {
      if (_userEdited) return;
      _hostCtrl.text = next.host;
      _portCtrl.text = next.port.toString();
      _passCtrl.text = next.password;
    });
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final outputSettings = ref.watch(outputTargetSettingsNotifierProvider);
    final obsStatus = ref.watch(obsConnectionNotifierProvider);

    final l10n = ZipBroadcastLocalizations.of(context)!;
    return ListView(
      key: const ValueKey('obs'),
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          title: Text(l10n.settingsObs),
          value: outputSettings.obsEnabled,
          onChanged: (v) => unawaited(
            ref
                .read(outputTargetSettingsNotifierProvider.notifier)
                .update(outputSettings.copyWith(obsEnabled: v)),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _hostCtrl,
          decoration: InputDecoration(labelText: l10n.settingsObsHost),
          onChanged: (_) => _save(),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _portCtrl,
          decoration: InputDecoration(labelText: l10n.settingsObsPort),
          keyboardType: TextInputType.number,
          onChanged: (_) => _save(),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _passCtrl,
          decoration: InputDecoration(labelText: l10n.settingsObsPassword),
          obscureText: true,
          onChanged: (_) => _save(),
        ),
        const SizedBox(height: 16),
        FilledButton.tonal(
          onPressed: _testConnection,
          child: Text(l10n.settingsObsTestConnection),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.settingsObsStatus(_obsStatusLabel(l10n, obsStatus)),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Future<void> _testConnection() async {
    final status = await ref
        .read(obsConnectionNotifierProvider.notifier)
        .testConnection();
    if (!mounted) return;
    final l10n = ZipBroadcastLocalizations.of(context)!;
    final label = status == ObsConnectionStatus.connected
        ? l10n.settingsObsConnectedSuccess
        : l10n.settingsObsConnectionFailed(_obsStatusLabel(l10n, status));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(label)));
  }

  void _save() {
    _userEdited = true;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 300), () {
      final port = int.tryParse(_portCtrl.text);
      unawaited(
        ref.read(obsSettingsNotifierProvider.notifier).update(
              host: _hostCtrl.text,
              port: port,
              password: _passCtrl.text,
            ),
      );
    });
  }
}

// ---------------------------------------------------------------------------
// Output targets detail (F5)
// ---------------------------------------------------------------------------

class _OutputTargetsDetail extends ConsumerWidget {
  const _OutputTargetsDetail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(outputTargetSettingsNotifierProvider);

    void update(OutputTargetSettings next) => unawaited(
          ref.read(outputTargetSettingsNotifierProvider.notifier).update(next),
        );

    final l10n = ZipBroadcastLocalizations.of(context)!;
    return ListView(
      key: const ValueKey('output-targets'),
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.monitor),
          title: Text(l10n.settingsOnScreenCaptions),
          value: settings.onScreenEnabled,
          onChanged: (v) =>
              update(settings.copyWith(onScreenEnabled: v)),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.cast),
          title: Text(l10n.settingsObs),
          value: settings.obsEnabled,
          onChanged: (v) => update(settings.copyWith(obsEnabled: v)),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.public),
          title: Text(l10n.settingsBrowserSource),
          value: settings.browserSourceEnabled,
          onChanged: (v) =>
              update(settings.copyWith(browserSourceEnabled: v)),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.picture_in_picture_alt),
          title: Text(l10n.settingsCaptionOverlay),
          value: settings.overlayEnabled,
          onChanged: (v) => update(settings.copyWith(overlayEnabled: v)),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.description_outlined),
          title: Text(l10n.settingsTranscriptsTarget),
          value: true,
          onChanged: null, // Always active.
        ),
        const ComingSoonCard(
          icon: Icons.people_outlined,
          label: 'Remote Viewers',
          subtitle: 'Phase 2',
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Audio inputs detail (F6)
// ---------------------------------------------------------------------------

class _AudioInputsDetail extends StatelessWidget {
  const _AudioInputsDetail({required this.onNavigate});

  final VoidCallback onNavigate;

  @override
  Widget build(BuildContext context) {
    final l10n = ZipBroadcastLocalizations.of(context)!;
    return ListView(
      key: const ValueKey('audio-inputs'),
      children: [
        ListTile(
          leading: const Icon(Icons.mic),
          title: Text(l10n.settingsManageAudioInputs),
          trailing: const Icon(Icons.open_in_new),
          onTap: onNavigate,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Transcripts & Behaviour detail (F7)
// ---------------------------------------------------------------------------

class _TranscriptsDetail extends ConsumerWidget {
  const _TranscriptsDetail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transcriptSettings =
        ref.watch(transcriptSettingsNotifierProvider);
    final wakeLock = ref.watch(wakeLockSettingsNotifierProvider);

    final l10n = ZipBroadcastLocalizations.of(context)!;
    return ListView(
      key: const ValueKey('transcripts'),
      children: [
        SwitchListTile(
          title: Text(l10n.settingsSaveTranscripts),
          value: transcriptSettings.captureEnabled,
          onChanged: (v) => unawaited(
            ref
                .read(transcriptSettingsNotifierProvider.notifier)
                .setCaptureEnabled(value: v),
          ),
        ),
        SwitchListTile(
          title: Text(l10n.settingsKeepScreenOn),
          value: wakeLock.enabled,
          onChanged: (v) => unawaited(
            ref
                .read(wakeLockSettingsNotifierProvider.notifier)
                .update(wakeLock.copyWith(enabled: v)),
          ),
        ),
        SwitchListTile(
          title: Text(l10n.settingsReleaseOnPause),
          value: wakeLock.releaseOnPause,
          onChanged: (v) => unawaited(
            ref
                .read(wakeLockSettingsNotifierProvider.notifier)
                .update(wakeLock.copyWith(releaseOnPause: v)),
          ),
        ),
      ],
    );
  }
}
