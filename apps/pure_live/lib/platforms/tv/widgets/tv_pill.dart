import 'package:flutter/material.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// One focusable TV pill: scale + accent border on focus, accent fill when
/// selected. The TV pages use it for tabs, platforms and toolbar actions, so
/// every one of them answers a D-pad the same way.
final class TvPill extends StatefulWidget {
  /// A pill labelled [label].
  const new({required this.label, required this.onTap, this.selected = false, this.autofocus = false, super.key});

  /// The text.
  final String label;

  /// Runs on OK/Enter and on a tap.
  final VoidCallback onTap;

  /// Whether the pill shows its chosen state.
  final bool selected;

  /// Whether it takes the focus when the page shows.
  final bool autofocus;

  @override
  State<TvPill> createState() => _TvPillState();
}

final class _TvPillState extends State<TvPill> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (value) {
        if (value != _focused) {
          setState(() => _focused = value);
        }
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: widget.selected ? theme.colors.primaryBg : theme.colors.fillQuaternary,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _focused ? theme.colors.primary : Colors.transparent, width: 2),
          ),
          child: Text(
            widget.label,
            style: theme.text.body.copyWith(
              color: _focused || widget.selected ? theme.colors.primary : theme.colors.textSecondary,
              fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
