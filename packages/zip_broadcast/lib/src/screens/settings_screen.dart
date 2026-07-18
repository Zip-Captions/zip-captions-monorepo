import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zip_broadcast/src/l10n/zip_broadcast_localizations.dart';
import 'package:zip_broadcast/src/models/obs_connection_status.dart';
import 'package:zip_broadcast/src/providers/broadcast_providers.dart';
import 'package:zip_broadcast/src/providers/obs_connection_notifier.dart';
import 'package:zip_broadcast/src/providers/settings_notifier.dart';
import 'package:zip_broadcast/src/widgets/output_targets_panel.dart';
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
          onTap: () => context.push('/audio-inputs'),
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
        DropdownButtonFormField<CaptionTextSize>(
          decoration: InputDecoration(
            labelText: l10n.appearanceTextSize,
            border: const OutlineInputBorder(),
          ),
          initialValue: settings.captionTextSize,
          items: CaptionTextSize.values
              .map(
                (size) => DropdownMenuItem(
                  value: size,
                  child: Text(_textSizeLabel(l10n, size)),
                ),
              )
              .toList(),
          onChanged: (size) {
            if (size != null) unawaited(notifier.setCaptionTextSize(size));
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<CaptionFont>(
          decoration: InputDecoration(
            labelText: l10n.appearanceFont,
            border: const OutlineInputBorder(),
          ),
          initialValue: settings.captionFont,
          items: CaptionFont.values
              .map(
                (font) => DropdownMenuItem(
                  value: font,
                  child: Text(font.fontFamily),
                ),
              )
              .toList(),
          onChanged: (font) {
            if (font != null) unawaited(notifier.setCaptionFont(font));
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<ScrollDirection>(
          decoration: InputDecoration(
            labelText: l10n.appearanceScrollDirection,
            border: const OutlineInputBorder(),
          ),
          initialValue: settings.scrollDirection,
          items: [
            DropdownMenuItem(
              value: ScrollDirection.bottomToTop,
              child: Text(l10n.appearanceNewAtBottom),
            ),
            DropdownMenuItem(
              value: ScrollDirection.topToBottom,
              child: Text(l10n.appearanceNewAtTop),
            ),
          ],
          onChanged: (direction) {
            if (direction != null) {
              unawaited(notifier.setScrollDirection(direction));
            }
          },
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
    if (status == ObsConnectionStatus.connected) {
      unawaited(
        ref.read(obsSettingsNotifierProvider.notifier).markConnectionVerified(),
      );
    }
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

class _OutputTargetsDetail extends StatelessWidget {
  const _OutputTargetsDetail();

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('output-targets'),
      padding: const EdgeInsets.all(8),
      children: const [OutputTargetsPanel()],
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
