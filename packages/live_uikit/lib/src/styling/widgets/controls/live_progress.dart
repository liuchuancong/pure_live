import 'package:flutter/material.dart';

import 'package:live_uikit/src/styling/contracts/live_ui_adapter.dart';
import 'package:live_uikit/src/styling/provider/live_config_provider.dart';

/// A tiny marquee for an indeterminate value (null [LanguageProgressSpec.value]).
class LinearIndeterminate extends StatelessWidget {
  /// An indeterminate bar.
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    return SizedBox.expand(
      child: LinearProgressIndicator(
        backgroundColor: Colors.transparent,
        color: theme.colors.primary,
        minHeight: theme.token.scale.sizes.xs,
      ),
    );
  }
}

/// The public progress bar: a thin dispatcher to the active language adapter.
class LiveProgress extends StatelessWidget {
  /// A progress bar at [value] (0..1).
  const new({required this.value, this.height = 8, this.showLabel = false, this.barColor, super.key});

  /// The completion fraction, or null for indeterminate.
  final double? value;

  /// The track thickness.
  final double height;

  /// Whether to show the trailing percentage.
  final bool showLabel;

  /// An optional fill colour override.
  final Color? barColor;

  @override
  Widget build(BuildContext context) => LiveTheme.of(context).adapter
      .progress(context, LanguageProgressSpec(value: value, height: height, showLabel: showLabel, barColor: barColor));
}
