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
    final data = f2.FluentThemeData.from(
      brightness: token.isDark ? Brightness.dark : Brightness.light,
      brand: f2.FluentBrandRamp.fromKeyColor(token.color.primary),
    );
    final family = token.type.fontFamily;
    if (family == null) {
      return data;
    }
    // The library has no family knob and no copyWith: `FluentTypography` is
    // eighteen required roles, and `withColor` rebuilds all of them the same
    // way. This follows that shape — the platform's own ramp is what each role
    // is copied from, so only the family changes.
    final type = data.typography;
    return data.copyWith(
      typography: f2.FluentTypography(
        caption2: type.caption2.copyWith(fontFamily: family),
        caption2Strong: type.caption2Strong.copyWith(fontFamily: family),
        caption1: type.caption1.copyWith(fontFamily: family),
        caption1Strong: type.caption1Strong.copyWith(fontFamily: family),
        caption1Stronger: type.caption1Stronger.copyWith(fontFamily: family),
        body1: type.body1.copyWith(fontFamily: family),
        body1Strong: type.body1Strong.copyWith(fontFamily: family),
        body1Stronger: type.body1Stronger.copyWith(fontFamily: family),
        body2: type.body2.copyWith(fontFamily: family),
        body2Strong: type.body2Strong.copyWith(fontFamily: family),
        subtitle2: type.subtitle2.copyWith(fontFamily: family),
        subtitle2Stronger: type.subtitle2Stronger.copyWith(fontFamily: family),
        subtitle1: type.subtitle1.copyWith(fontFamily: family),
        title3: type.title3.copyWith(fontFamily: family),
        title2: type.title2.copyWith(fontFamily: family),
        title1: type.title1.copyWith(fontFamily: family),
        largeTitle: type.largeTitle.copyWith(fontFamily: family),
        display: type.display.copyWith(fontFamily: family),
      ),
    );
  }
}
