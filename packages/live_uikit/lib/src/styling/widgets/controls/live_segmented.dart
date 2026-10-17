import 'package:flutter/widgets.dart';

import 'package:live_uikit/src/styling/contracts/live_ui_adapter.dart';
import 'package:live_uikit/src/styling/provider/live_config_provider.dart';

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
