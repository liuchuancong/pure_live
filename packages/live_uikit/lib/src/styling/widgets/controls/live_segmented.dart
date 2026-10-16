import 'package:flutter/widgets.dart';

import 'package:live_uikit/src/styling/contracts/live_ui_adapter.dart';
import 'package:live_uikit/src/styling/provider/live_config_provider.dart';

/// The token-driven segmented control (a rounded track with one selectable
/// pill) — the base for languages that do not map it to their own widget.
class TokenSegmented extends StatelessWidget {
  /// A token segmented control built from [spec].
  const new({required this.spec, super.key});

  /// The segmented configuration.
  final LanguageSegmentedSpec spec;

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    final radius = theme.token.scale.radii.base;
    final track = Container(
      padding: EdgeInsets.all(theme.token.motion.lineWidth),
      decoration: BoxDecoration(
        color: theme.colors.fillQuaternary,
        borderRadius: BorderRadius.circular(radius + theme.token.motion.lineWidth),
      ),
      child: Row(
        // A flex child claims the whole remaining width even under
        // `MainAxisSize.min`, so `Expanded` is only applied when the control is
        // actually asked to share the full width; otherwise it hugs its labels.
        mainAxisSize: spec.expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          for (var i = 0; i < spec.labels.length; i++)
            _flexChild(
              spec.expand,
              _Segment(
                label: spec.labels[i],
                selected: i == spec.index,
                onTap: spec.enabled && spec.onChanged != null ? () => spec.onChanged!(i) : null,
              ),
            ),
        ],
      ),
    );
    return spec.expand ? SizedBox(width: double.infinity, child: track) : track;
  }
}

Widget _flexChild(bool expand, Widget segment) => expand ? Expanded(child: segment) : segment;

class _Segment extends StatelessWidget {
  const new({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    final radius = theme.token.scale.radii.base;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: theme.duration,
          padding: EdgeInsets.symmetric(horizontal: theme.tabs.horizontalPadding, vertical: theme.token.scale.sizes.xs),
          decoration: BoxDecoration(
            color: selected ? theme.colors.bgElevated : const Color(0x00000000),
            borderRadius: BorderRadius.circular(radius),
            boxShadow: selected ? theme.token.motion.boxShadowTertiary : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: theme.text.label.copyWith(color: selected ? theme.colors.text : theme.colors.textSecondary),
          ),
        ),
      ),
    );
  }
}

/// The public segmented control: a thin dispatcher to the active language
/// adapter, so switching `UiConfig.language` re-renders it with the real
/// library's control.
class LiveSegmented extends StatelessWidget {
  /// A segmented control over [labels].
  const new({
    required this.labels,
    required this.index,
    required this.onChanged,
    this.expand = false,
    this.enabled = true,
    super.key,
  });

  /// The segment labels, in order.
  final List<String> labels;

  /// The selected index.
  final int index;

  /// Called with a segment's index when chosen.
  final ValueChanged<int>? onChanged;

  /// Whether the segments share the full width.
  final bool expand;

  /// Whether the control responds to input.
  final bool enabled;

  @override
  Widget build(BuildContext context) => LiveTheme.of(context).adapter.segmented(
    context,
    LanguageSegmentedSpec(labels: labels, index: index, onChanged: onChanged, expand: expand, enabled: enabled),
  );
}
