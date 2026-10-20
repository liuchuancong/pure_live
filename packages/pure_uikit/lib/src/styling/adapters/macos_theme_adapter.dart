import 'package:flutter/material.dart' show Brightness;
import 'package:macos_ui/macos_ui.dart' as macos;

import 'package:pure_uikit/src/styling/adapters/pure_theme_adapter.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

/// Maps the resolved theme onto macOS's [macos.MacosThemeData]: accent,
/// brightness, the window canvas and the viewer's chosen font family.
///
/// The family is laid over each of the library's text styles rather than set
/// once, because `macos_ui` draws its controls from [macos.MacosTypography]
/// roles — a button reads `body`, a sidebar row `callout` — and an adapter that
/// mapped only colours leaves a picked font inert across the whole macOS
/// surface. The roles start from the typography the theme resolved for this
/// brightness, so the sizes, weights and the light/dark differences stay the
/// library's own and one field is overwritten in each.
///
/// Mapping notes: window materials, the title bar, window buttons and the
/// window lifecycle are platform capabilities the adapter does not touch;
/// macOS's own defaults answer every token the library has no slot for.
final class MacosThemeAdapter implements PureThemeAdapter<macos.MacosThemeData> {
  /// The macOS adapter.
  const new();

  @override
  macos.MacosThemeData resolve(PureTheme theme) {
    final token = theme.token;
    final data = macos.MacosThemeData(
      brightness: token.isDark ? Brightness.dark : Brightness.light,
      primaryColor: token.color.primary,
      canvasColor: token.color.surface,
    );
    final family = token.type.fontFamily;
    if (family == null) {
      return data;
    }
    final type = data.typography;
    // `MacosTypography` is a factory that fills any role left out from the
    // brightness's defaults, so the resolved set is handed back in full with one
    // field changed in each — not rebuilt from literals.
    return data.copyWith(
      typography: macos.MacosTypography(
        color: type.body.color ?? token.color.text,
        largeTitle: type.largeTitle.copyWith(fontFamily: family),
        title1: type.title1.copyWith(fontFamily: family),
        title2: type.title2.copyWith(fontFamily: family),
        title3: type.title3.copyWith(fontFamily: family),
        headline: type.headline.copyWith(fontFamily: family),
        subheadline: type.subheadline.copyWith(fontFamily: family),
        body: type.body.copyWith(fontFamily: family),
        callout: type.callout.copyWith(fontFamily: family),
        footnote: type.footnote.copyWith(fontFamily: family),
        caption1: type.caption1.copyWith(fontFamily: family),
        caption2: type.caption2.copyWith(fontFamily: family),
      ),
    );
  }
}
