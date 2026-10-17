import 'package:fluent_2/fluent_2.dart' as f2;
import 'package:flutter/material.dart' show Brightness;

import 'package:pure_uikit/src/styling/adapters/pure_theme_adapter.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

/// Maps the resolved theme onto Fluent's [f2.FluentThemeData]: the brand ramp
/// is generated from the accent with Fluent's own generator — this is the one
/// place a language may speak its native palette dialect (Material seeds a
/// colour scheme, Fluent grows a brand ramp, and that difference *is* each
/// design language), so an accent change re-brands the whole fluent subtree.
///
/// Mapping notes: Fluent carries no density or spacing slot; the control
/// grammar answers through the tokens the fluent Pure widgets read.
final class FluentThemeAdapter implements PureThemeAdapter<f2.FluentThemeData> {
  /// The Fluent adapter.
  const new();

  @override
  f2.FluentThemeData resolve(PureTheme theme) {
    final token = theme.token;
    return f2.FluentThemeData.from(
      brightness: token.isDark ? Brightness.dark : Brightness.light,
      brand: f2.FluentBrandRamp.fromKeyColor(token.color.primary),
    );
  }
}
