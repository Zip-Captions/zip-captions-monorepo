import 'package:flutter/material.dart';

/// A non-interactive output-target card with a "Coming soon" badge.
///
/// ACC-U6.2: excluded from interactive semantics; screen readers announce
/// "{label} — Coming soon" as static text only.
class ComingSoonCard extends StatelessWidget {
  /// Creates a [ComingSoonCard].
  const ComingSoonCard({
    required this.label,
    required this.icon,
    this.subtitle,
    super.key,
  });

  /// Card title (e.g. "Remote Viewers").
  final String label;

  /// Icon for the target type.
  final IconData icon;

  /// Optional sub-label.
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label — Coming soon',
      excludeSemantics: true,
      child: Card(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: ListTile(
          enabled: false,
          leading: Icon(icon, color: Theme.of(context).disabledColor),
          title: Text(
            label,
            style: TextStyle(color: Theme.of(context).disabledColor),
          ),
          subtitle: subtitle != null
              ? Text(
                  subtitle!,
                  style: TextStyle(color: Theme.of(context).disabledColor),
                )
              : null,
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Coming soon',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
