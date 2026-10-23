import 'dart:ui' show Brightness;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart' show Color;

/// Builds the token set `DsTheme` hands to every `desen_ui` component.
///
/// One factory for both brightnesses, seeded from the resolved accent — the
/// machine's own on Windows, the factory default elsewhere until the viewer
/// picks one.
DsThemeData buildDsTheme({required Brightness brightness, required Color? accent}) {
  return DsThemeData(brightness: brightness, seed: accent == null ? DsSeed.blue : DsSeed.color(accent));
}
