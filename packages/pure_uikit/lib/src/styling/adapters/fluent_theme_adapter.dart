import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart' show Brightness, Color, Colors;

import 'package:pure_uikit/src/styling/adapters/pure_theme_adapter.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

/// Maps the resolved theme onto fluent_ui's [fluent.FluentThemeData].
///
/// The mapping scope is the three slots a host needs to read as Pure: the
/// brightness picks the palette ramp, the token's primary colour is grown
/// into Fluent's own seven-step accent ramp (the hover and active steps seed
/// the dark half — this is the one place a language may speak its native
/// palette dialect, so an accent change re-brands the whole fluent subtree),
/// and the chosen font family rides `FluentThemeData`'s own typography
/// `apply`. Fluent carries no density or spacing slot; the control grammar
/// answers through the tokens the fluent Pure widgets read.
final class FluentThemeAdapter implements PureThemeAdapter<fluent.FluentThemeData> {
  /// The Fluent adapter.
  const new();

  @override
  fluent.FluentThemeData resolve(PureTheme theme) {
    final token = theme.token;
    final primary = token.color.primary;
    final hover = token.color.primaryHover;
    final active = token.color.primaryActive;
    return fluent.FluentThemeData(
      brightness: token.isDark ? Brightness.dark : Brightness.light,
      accentColor: fluent.AccentColor.swatch(<String, Color>{
        'darkest': Color.lerp(active, Colors.black, 0.25)!,
        'darker': Color.lerp(active, Colors.black, 0.10)!,
        'dark': active,
        'normal': primary,
        'light': hover,
        'lighter': Color.lerp(primary, Colors.white, 0.30)!,
        'lightest': Color.lerp(primary, Colors.white, 0.40)!,
      }),
      fontFamily: token.type.fontFamily,
    );
  }
}
