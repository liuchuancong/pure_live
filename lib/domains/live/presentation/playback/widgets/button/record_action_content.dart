import 'package:flutter/material.dart';

/// Compact and labelled recording indicator, independent of task storage.
class RecordActionContent extends StatelessWidget {
  const RecordActionContent({super.key, required this.compactHeader, required this.label, required this.icon});
  final bool compactHeader;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return compactHeader
        ? AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, animation) {
              return ScaleTransition(scale: animation, child: child);
            },
            child: Icon(icon, key: ValueKey(icon), size: 18),
          )
        : AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: Row(
              key: ValueKey(label),
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14),
                const SizedBox(width: 4),
                // AnimatedSwitcher also lays out the outgoing label under the
                // new compact width. Bound both current and outgoing text;
                // the parent Tooltip keeps the complete action accessible.
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ],
            ),
          );
  }
}
