/// Paints a `GradientBackground` using Flutter's shader-driven DecoratedBox.
library;

import 'package:flutter/widgets.dart';
import 'package:pure_uikit_background/src/models/background_config/background_config.dart';

/// Fills the available box with a linear gradient described by [config].
class GradientBackgroundView extends StatelessWidget {
  /// Renders [config].
  const new({required this.config, super.key});

  /// The gradient description to paint.
  final GradientBackground config;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: config.colors, stops: config.stops, begin: config.begin, end: config.end),
      ),
      child: const SizedBox.expand(),
    );
  }
}
