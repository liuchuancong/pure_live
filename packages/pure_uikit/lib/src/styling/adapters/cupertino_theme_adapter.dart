import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/material.dart' show Brightness;

import 'package:pure_uikit/src/styling/adapters/pure_theme_adapter.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

/// Maps the resolved theme onto Cupertino's [cupertino.CupertinoThemeData]:
/// brightness, the accent and its contrasting colour, the page surface, and the
/// viewer's chosen font family.
///
/// The family has to be spelled out role by role because Cupertino styles the text
/// its own widgets draw — tab labels, nav titles, pickers — from this text theme,
/// and a `Pure` widget that hands Cupertino a plain `Text` has no say in it.
/// Mapping only the colour slots leaves a chosen font inert across the whole iOS
/// surface.
///
/// The roles start from the text theme [cupertino.CupertinoThemeData] resolves
/// for this brightness rather than from a list written here, so Cupertino's own
/// sizes, weights and line heights — and the difference between its light and
/// dark sets — stay its own; this overwrites one field of each.
///
/// Mapping notes: Cupertino's theme capability is narrower than Material's —
/// there is no card colour, no radius scale and no density slot — so those
/// tokens answer through the Pure widgets themselves, not through this adapter.
final class CupertinoThemeAdapter implements PureThemeAdapter<cupertino.CupertinoThemeData> {
  /// The Cupertino adapter.
  const new();

  @override
  cupertino.CupertinoThemeData resolve(PureTheme theme) {
    final token = theme.token;
    final data = cupertino.CupertinoThemeData(
      brightness: token.isDark ? Brightness.dark : Brightness.light,
      primaryColor: token.color.primary,
      primaryContrastingColor: token.color.onPrimary,
      scaffoldBackgroundColor: token.color.surface,
    );
    final family = token.type.fontFamily;
    if (family == null) {
      // No choice made: every role comes back exactly as Cupertino would have
      // drawn it, its own platform-default family included.
      return data;
    }
    return data.copyWith(textTheme: _withFamily(data.textTheme, family));
  }

  static cupertino.CupertinoTextThemeData _withFamily(cupertino.CupertinoTextThemeData base, String family) =>
      base.copyWith(
        actionTextStyle: base.actionTextStyle.copyWith(fontFamily: family),
        tabLabelTextStyle: base.tabLabelTextStyle.copyWith(fontFamily: family),
        navTitleTextStyle: base.navTitleTextStyle.copyWith(fontFamily: family),
        navLargeTitleTextStyle: base.navLargeTitleTextStyle.copyWith(fontFamily: family),
        navActionTextStyle: base.navActionTextStyle.copyWith(fontFamily: family),
        pickerTextStyle: base.pickerTextStyle.copyWith(fontFamily: family),
        dateTimePickerTextStyle: base.dateTimePickerTextStyle.copyWith(fontFamily: family),
      );
}
