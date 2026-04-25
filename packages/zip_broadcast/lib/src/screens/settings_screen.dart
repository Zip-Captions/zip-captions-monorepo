import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
              title: Text(_viewTitle(_view)),
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

  static String _viewTitle(_SettingsView view) {
    return switch (view) {
      _SettingsView.list => 'Settings',
      _SettingsView.appearance => 'Appearance',
      _SettingsView.obs => 'OBS WebSocket',
      _SettingsView.outputTargets => 'Output Targets',
      _SettingsView.audioInputs => 'Audio Inputs',
      _SettingsView.transcripts => 'Transcripts & Behaviour',
    };
  }
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

    return ListView(
      key: const ValueKey('list'),
      children: [
        ListTile(
          leading: const Icon(Icons.format_size),
          title: const Text('Appearance'),
          subtitle: const Text('Text size, font, scroll direction'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => onTap(_SettingsView.appearance),
        ),
        ListTile(
          leading: const Icon(Icons.cast),
          title: const Text('OBS WebSocket'),
          subtitle: Text(_obsSubLabel(obsStatus, outputSettings.obsEnabled)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => onTap(_SettingsView.obs),
        ),
        ListTile(
          leading: const Icon(Icons.output),
          title: const Text('Output Targets'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => onTap(_SettingsView.outputTargets),
        ),
        ListTile(
          leading: const Icon(Icons.mic),
          title: const Text('Audio Inputs'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => onTap(_SettingsView.audioInputs),
        ),
        ListTile(
          leading: const Icon(Icons.article_outlined),
          title: const Text('Transcripts & Behaviour'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => onTap(_SettingsView.transcripts),
        ),
      ],
    );
  }

  static String _obsSubLabel(ObsConnectionStatus status, bool enabled) {
    if (!enabled) return 'Disabled';
    return switch (status) {
      ObsConnectionStatus.connected => 'Connected',
      ObsConnectionStatus.connecting => 'Connecting…',
      ObsConnectionStatus.reconnecting => 'Reconnecting…',
      ObsConnectionStatus.error => 'Error',
      ObsConnectionStatus.disconnected => 'Disconnected',
    };
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

    return ListView(
      key: const ValueKey('appearance'),
      padding: const EdgeInsets.all(16),
      children: [
        Text('Text size', style: Theme.of(context).textTheme.labelLarge),
        Wrap(
          spacing: 4,
          children: CaptionTextSize.values.map((size) {
            return ChoiceChip(
              label: Text(size.name.toUpperCase()),
              selected: settings.captionTextSize == size,
              onSelected: (_) =>
                  unawaited(notifier.setCaptionTextSize(size)),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Text('Font', style: Theme.of(context).textTheme.labelLarge),
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
          'Scroll direction',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        Wrap(
          spacing: 4,
          children: [
            ChoiceChip(
              label: const Text('↑ New at bottom'),
              selected:
                  settings.scrollDirection == ScrollDirection.bottomToTop,
              onSelected: (_) => unawaited(
                notifier.setScrollDirection(ScrollDirection.bottomToTop),
              ),
            ),
            ChoiceChip(
              label: const Text('↓ New at top'),
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
          title: const Text('Dark Theme'),
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

    return ListView(
      key: const ValueKey('obs'),
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          title: const Text('OBS WebSocket'),
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
          decoration: const InputDecoration(labelText: 'Host'),
          onChanged: (_) => _save(),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _portCtrl,
          decoration: const InputDecoration(labelText: 'Port'),
          keyboardType: TextInputType.number,
          onChanged: (_) => _save(),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _passCtrl,
          decoration: const InputDecoration(labelText: 'Password'),
          obscureText: true,
          onChanged: (_) => _save(),
        ),
        const SizedBox(height: 16),
        FilledButton.tonal(
          onPressed: _testConnection,
          child: const Text('Test Connection'),
        ),
        const SizedBox(height: 8),
        Text(
          'Status: ${obsStatus.name}',
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
    final label = status == ObsConnectionStatus.connected
        ? 'Connected successfully'
        : 'Connection failed (${status.name})';
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

    return ListView(
      key: const ValueKey('output-targets'),
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.monitor),
          title: const Text('On-Screen Captions'),
          value: settings.onScreenEnabled,
          onChanged: (v) =>
              update(settings.copyWith(onScreenEnabled: v)),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.cast),
          title: const Text('OBS WebSocket'),
          value: settings.obsEnabled,
          onChanged: (v) => update(settings.copyWith(obsEnabled: v)),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.public),
          title: const Text('Browser Source'),
          value: settings.browserSourceEnabled,
          onChanged: (v) =>
              update(settings.copyWith(browserSourceEnabled: v)),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.picture_in_picture_alt),
          title: const Text('Caption Overlay'),
          value: settings.overlayEnabled,
          onChanged: (v) => update(settings.copyWith(overlayEnabled: v)),
        ),
        const SwitchListTile(
          secondary: Icon(Icons.description_outlined),
          title: Text('Transcripts'),
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
    return ListView(
      key: const ValueKey('audio-inputs'),
      children: [
        ListTile(
          leading: const Icon(Icons.mic),
          title: const Text('Manage Audio Inputs'),
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

    return ListView(
      key: const ValueKey('transcripts'),
      children: [
        SwitchListTile(
          title: const Text('Save Transcripts'),
          value: transcriptSettings.captureEnabled,
          onChanged: (v) => unawaited(
            ref
                .read(transcriptSettingsNotifierProvider.notifier)
                .setCaptureEnabled(value: v),
          ),
        ),
        SwitchListTile(
          title: const Text('Keep Screen On'),
          value: wakeLock.enabled,
          onChanged: (v) => unawaited(
            ref
                .read(wakeLockSettingsNotifierProvider.notifier)
                .update(wakeLock.copyWith(enabled: v)),
          ),
        ),
        SwitchListTile(
          title: const Text('Release on Pause'),
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
