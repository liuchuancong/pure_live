import 'package:flutter/widgets.dart';
import 'package:pure_settings_ui/src/pure/pure_settings_style.dart';
import 'package:pure_settings_ui/src/pure/styles/pure_settings_base_style.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// Wind's settings style.
///
/// `WCard` is structure only — a `w-full flex flex-col` container with header,
/// body and footer slots — and paints no surface at all. It is the one card in
/// this family that has to be told where it ends, so this is the style that
/// turns the border on: without the token's stroke there is no group, only a
/// run of rows on the page.
///
/// The row is the other half of the picture. Wind's row is an interactive
/// `WAnchor` — the same widget its own tabs, switch and checkbox are built on —
/// padded `px-4 py-3`, with a start-edge accent bar *reserved on every row* and
/// recoloured only on the chosen one. Selection is therefore already stated, at
/// the place a chosen row states it in this theme, so the card adds no fill of
/// its own; a tinted card over an accent bar would be two answers to one
/// question.
///
/// The hairline between rows is drawn by `PureListRow`, not by the fork: wind
/// composes separators from its own border utilities, and a lone row has no
/// group to borrow them from.
const PureSettingsStyle windSettingsStyle = PureSettingsStyle(
  name: 'wind',
  palette: pureSettingsTokenPalette,
  cardPadding: EdgeInsets.zero,
  cardBordered: true,
  rowDividers: true,
  tintsSelectedCard: false,
);
