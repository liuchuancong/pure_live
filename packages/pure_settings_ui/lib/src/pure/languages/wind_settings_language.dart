import 'package:flutter/widgets.dart';
import 'package:pure_settings_ui/src/pure/pure_settings_palette.dart';
import 'package:pure_settings_ui/src/pure/pure_settings_style.dart';
import 'package:pure_settings_ui/src/vendor/utils/platform_utils.dart' show DevicePlatform;

/// Wind's settings theme.
///
/// `WCard` is structure only — a `w-full flex flex-col` container with header,
/// body and footer slots — and paints no surface at all. It is the one card in
/// this family that has to be told where it ends, so this is the theme that
/// turns the border on: without the token's stroke there is no group, only a run
/// of rows on the page.
///
/// The row is the other half of the picture. Wind's row is an interactive
/// `WAnchor` — the widget its own tabs, switch and checkbox are built on —
/// padded `px-4 py-3`, with a start-edge accent bar *reserved on every row* and
/// recoloured only on the chosen one. Selection is therefore already stated,
/// where this theme states it, so the card adds no fill of its own: a tinted
/// card under an accent bar is two answers to one question.
///
/// The hairline between rows is drawn by `PureListRow`, not by the fork. Wind
/// composes separators from its own border utilities and a lone row has no group
/// to borrow them from, which is the same reason the neumorphic row draws its
/// own — and the reason this theme keeps the line and that one does not.
const windSettingsLanguage = SettingsLanguage(
  platform: DevicePlatform.pure,
  style: PureSettingsStyle(
    palette: pureSettingsPalette,
    cardPadding: EdgeInsets.zero,
    cardBordered: true,
    rowDividers: true,
  ),
);
