import 'package:flutter/material.dart';

import 'package:live_uikit/src/styling/contracts/live_ui_adapter.dart';
import 'package:live_uikit/src/styling/provider/live_config_provider.dart';

/// The token-driven linear progress renderer (track + fractional fill, optional
/// percentage) — the base for languages that do not map a progress bar to their
/// own widget.
class TokenProgress extends StatelessWidget {
  /// A token progress bar built from [spec].
  const new({required this.spec, super.key});

  /// The progress configuration.
  final LanguageProgressSpec spec;

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    final fraction = spec.value == null ? 1.0 : spec.value!.clamp(0.0, 1.0);
    final radius = BorderRadius.circular(spec.height);

    final bar = Container(
      height: spec.height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: theme.colors.fillSecondary, borderRadius: radius),
      child: spec.value == null
          ? const LinearIndeterminate()
          : FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fraction,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(color: spec.barColor ?? theme.colors.primary, borderRadius: radius),
              ),
            ),
    );

    if (!spec.showLabel || spec.value == null) {
      return bar;
    }
    return Row(
      children: [
        Expanded(child: bar),
        SizedBox(width: theme.token.scale.sizes.sm),
        Text('${(fraction * 100).round()}%', style: theme.text.caption.copyWith(color: theme.colors.textSecondary)),
      ],
    );
  }
}

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
