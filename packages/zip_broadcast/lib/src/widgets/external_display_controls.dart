import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zip_broadcast/src/l10n/zip_broadcast_localizations.dart';
import 'package:zip_broadcast/src/models/output_target_settings.dart';
import 'package:zip_broadcast/src/providers/broadcast_providers.dart';
import 'package:zip_broadcast/src/providers/overlay_window_controller_provider.dart';
import 'package:zip_core/overlay.dart';

/// The external display section of the output targets panel (F20).
///
/// It renders from the controller's status and the connected displays, and
/// every interaction writes through the settings notifier or goes to the
/// controller. Selection is made only by explicit user action, never by
/// rendering, so a reconnect never silently moves the broadcast to another
/// screen (BR-U8-07).
class ExternalDisplayControls extends ConsumerWidget {
  /// Creates an [ExternalDisplayControls].
  const ExternalDisplayControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(externalDisplayStatusProvider).valueOrNull;
    // The capability gate comes first: nothing is offered at all when the
    // platform cannot host a second window (BR-U8-11).
    if (status == null || status is Unsupported) {
      return const SizedBox.shrink();
    }

    final displays = ref.watch(displayListProvider).valueOrNull ?? const [];
    final settings = ref.watch(outputTargetSettingsNotifierProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ZipBroadcastLocalizations.of(context)!.externalDisplay,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          if (status is NoDisplays)
            _Body(
              text: ZipBroadcastLocalizations.of(context)!.externalDisplayNoDisplays,
            )
          else ...[
            _DisplayList(
              status: status,
              displays: displays,
              settings: settings,
            ),
            if (status is WaitingForDisplay) _WaitingBanner(status: status),
            if (status is Failed) _FailedBanner(),
            const SizedBox(height: 12),
            _PositionSelector(settings: settings),
          ],
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.bodyMedium);
}

class _DisplayList extends ConsumerWidget {
  const _DisplayList({
    required this.status,
    required this.displays,
    required this.settings,
  });

  final ExternalDisplayStatus status;
  final List<DisplayInfo> displays;
  final OutputTargetSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ZipBroadcastLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.externalDisplayAvailableDisplays,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        for (var i = 0; i < displays.length; i++)
          _DisplayRow(
            display: displays[i],
            index: i,
            status: status,
            settings: settings,
          ),
      ],
    );
  }
}

class _DisplayRow extends ConsumerWidget {
  const _DisplayRow({
    required this.display,
    required this.index,
    required this.status,
    required this.settings,
  });

  final DisplayInfo display;
  final int index;
  final ExternalDisplayStatus status;
  final OutputTargetSettings settings;

  bool get _isSelected {
    if (status case WaitingForDisplay(:final displayId)) {
      return display.id == displayId;
    }
    if (status case Open(:final displayId)) {
      return display.id == displayId;
    }
    final saved = settings.externalDisplayId;
    return saved == null ? display.isPrimary : display.id == saved;
  }

  bool get _isActive => status is Open;
  bool get _isOpening => status is Opening;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ZipBroadcastLocalizations.of(context)!;
    final theme = Theme.of(context);
    final label = display.label.isEmpty
        ? l10n.externalDisplayDisplayFallback(index + 1)
        : display.label;
    final meta = <String>[
      '${display.bounds.width.round()} x ${display.bounds.height.round()}',
      if (display.isPrimary) l10n.externalDisplayPrimaryMarker,
      if (status is WaitingForDisplay && _isSelected)
        l10n.externalDisplayDisconnectedMarker
      else if (_isActive && _isSelected)
        l10n.externalDisplayConnectedMarker
      else if (_isSelected)
        l10n.externalDisplaySelectedMarker,
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            Icons.monitor,
            color: _isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(label)),
                    if (_isActive && _isSelected) ...[
                      const SizedBox(width: 8),
                      _Pill(text: l10n.externalDisplayActivePill),
                    ],
                  ],
                ),
                Text(meta.join(' \u00b7 '), style: theme.textTheme.bodySmall),
                if (_isOpening && _isSelected)
                  Text(
                    l10n.externalDisplayOpening,
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          Switch(
            value: _isSelected && (status is Open || status is Opening),
            onChanged: (next) => _onToggle(ref, next),
          ),
        ],
      ),
    );
  }

  void _onToggle(WidgetRef ref, bool next) {
    final notifier = ref.read(outputTargetSettingsNotifierProvider.notifier);
    if (next) {
      // One write: the chosen id and the switch, so the open that follows
      // already knows which display it was asked for.
      unawaited(
        notifier.update(
          settings.copyWith(
            externalDisplayId: display.id,
            overlayEnabled: true,
          ),
        ),
      );
    } else {
      unawaited(notifier.update(settings.copyWith(overlayEnabled: false)));
    }
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _WaitingBanner extends ConsumerWidget {
  const _WaitingBanner({required this.status});

  final WaitingForDisplay status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ZipBroadcastLocalizations.of(context)!;
    final displays = ref.watch(displayListProvider).valueOrNull ?? const [];
    // The display that disconnected is by definition absent from the connected
    // list, so the name comes from the controller's capture at loss time, with
    // the list as a fallback for the brief window before the removal lands.
    final label = status.label ??
        displays
            .where((display) => display.id == status.displayId)
            .map((display) => display.label)
            .where((label) => label.isNotEmpty)
            .firstOrNull ??
        l10n.externalDisplaySelectedDisplay;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.externalDisplayDisconnectedBanner(label)),
        Text(
          l10n.externalDisplayWaitingForDisplay,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        TextButton(
          onPressed: () => unawaited(
            ref
                .read(outputTargetSettingsNotifierProvider.notifier)
                .update(
                  ref
                      .read(outputTargetSettingsNotifierProvider)
                      .copyWith(overlayEnabled: false),
                ),
          ),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}

class _FailedBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = ZipBroadcastLocalizations.of(context)!;
    return Text(
      l10n.externalDisplayFailedCreate,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.error,
          ),
    );
  }
}

class _PositionSelector extends ConsumerWidget {
  const _PositionSelector({required this.settings});

  final OutputTargetSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ZipBroadcastLocalizations.of(context)!;
    void write(CaptionPosition position) {
      unawaited(
        ref
            .read(outputTargetSettingsNotifierProvider.notifier)
            .update(settings.copyWith(externalDisplayCaptionPosition: position)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.externalDisplayCaptionPosition,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            _PositionButton(
              label: l10n.externalDisplayPositionBottom,
              selected:
                  settings.externalDisplayCaptionPosition ==
                      CaptionPosition.bottom,
              onPressed: () => write(CaptionPosition.bottom),
            ),
            const SizedBox(width: 8),
            _PositionButton(
              label: l10n.externalDisplayPositionTop,
              selected:
                  settings.externalDisplayCaptionPosition ==
                      CaptionPosition.top,
              onPressed: () => write(CaptionPosition.top),
            ),
          ],
        ),
      ],
    );
  }
}

class _PositionButton extends StatelessWidget {
  const _PositionButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return selected
        ? FilledButton(onPressed: onPressed, child: Text(label))
        : OutlinedButton(onPressed: onPressed, child: Text(label));
  }
}
