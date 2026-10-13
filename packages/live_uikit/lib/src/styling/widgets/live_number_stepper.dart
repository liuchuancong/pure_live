import 'package:flutter/material.dart';

import 'package:live_uikit/src/styling/recipe.dart';
import 'package:live_uikit/src/styling/root/live_config_provider.dart';
import 'package:live_uikit/src/styling/widgets/live_button.dart';

/// A numeric stepper — Ant's `InputNumber` controls: a decrement button, the
/// current value, and an increment button. The buttons are the token-driven
/// [LiveButton]; the value clamps to [min] / [max] and steps by [step].
class LiveNumberStepper extends StatelessWidget {
  /// A stepper bound to [value].
  const new({
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = double.infinity,
    this.step = 1,
    this.decimals = 0,
    this.enabled = true,
    super.key,
  });

  /// The current value.
  final double value;

  /// Called with the next value.
  final ValueChanged<double>? onChanged;

  /// The lower bound.
  final double min;

  /// The upper bound.
  final double max;

  /// The increment / decrement amount.
  final double step;

  /// How many decimal places to display.
  final int decimals;

  /// Whether the control responds.
  final bool enabled;

  bool get _interactive => enabled && onChanged != null;

  void _apply(double delta) {
    final next = (value + delta).clamp(min, max);
    onChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    final canDecrement = _interactive && value > min;
    final canIncrement = _interactive && value < max;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        LiveButton(
          label: '',
          icon: Icons.remove,
          variant: ButtonVariant.secondary,
          onPressed: canDecrement ? () => _apply(-step) : null,
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 56),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: theme.token.scale.sizes.sm),
            child: Text(
              value.toStringAsFixed(decimals),
              textAlign: TextAlign.center,
              style: theme.text.body.copyWith(color: theme.colors.text),
            ),
          ),
        ),
        LiveButton(
          label: '',
          icon: Icons.add,
          variant: ButtonVariant.secondary,
          onPressed: canIncrement ? () => _apply(step) : null,
        ),
      ],
    );
  }
}
