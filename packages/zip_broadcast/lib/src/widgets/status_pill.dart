import 'package:flutter/material.dart';

/// A small pill widget: coloured dot + label text.
///
/// Used in RecordingScreen to surface OBS, browser source, and overlay status
/// (E5). Semantic annotation announces label + status as a single group.
class StatusPill extends StatelessWidget {
  /// Creates a [StatusPill].
  const StatusPill({
    required this.label,
    required this.color,
    this.onTap,
    super.key,
  });

  /// Display label (e.g. "OBS", "Browser Source").
  final String label;

  /// Dot colour representing the current status.
  final Color color;

  /// Optional tap callback — scrolls to the relevant settings card (E5).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pill = Semantics(
      label: label,
      button: onTap != null,
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
    return pill;
  }
}
