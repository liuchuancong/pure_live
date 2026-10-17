/// Paints a `SolidBackground` as a bare, non-interactive fill.
library;

import 'package:flutter/widgets.dart';
import 'package:pure_uikit_background/src/models/background_config/background_config.dart';

/// Fills the available box with [config]'s color.
class SolidBackgroundView extends StatelessWidget {
  /// Renders [config].
  const new({required this.config, super.key});

  /// The solid description to paint.
  final SolidBackground config;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: config.color);
  }
}
