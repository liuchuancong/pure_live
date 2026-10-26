import 'dart:ui' show Color;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart' show Brightness;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart';

/// The viewer's "pure black background" choice (the reference's
/// `pureBlackTheme`, A11.2 C-4): off by default; on, the dark palette's
/// grounds fall to black so an OLED screen powers off those pixels. Light
/// mode is untouched — the reference's row says it plainly.
final class PureBlackThemeController extends Notifier<bool> {
  static const String _key = 'theme.pureBlack';

  @override
  bool build() {
    try {
      return StoragePrefs.getBool(_key) ?? false;
    } on Object {
      return false;
    }
  }

  /// Stores the choice; the root's theme applies at once.
  Future<void> set({required bool value}) async {
    state = value;
    try {
      await StoragePrefs.setBool(_key, value);
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// The pure-black preference.
final pureBlackThemeProvider = NotifierProvider<PureBlackThemeController, bool>(PureBlackThemeController.new);

/// The reference's `LivePureBlack` grounds, mapped onto the design system's
/// dark palette: the picture's canvas and the sidebar go to true black, the
/// cards keep one step of lift (#0E0E10), the raised sheets and fields the
/// next (#161618), and the controls the third (#1E1E21), so the layering
/// survives even though the base is off. Light palettes pass through — the
/// reference's row is dark-mode-only and says so where it cannot apply.
DsColors dsPureBlackColors(DsColors colors, Brightness brightness) {
  if (brightness != Brightness.dark) return colors;
  return colors.copyWith(
    canvas: const Color(0xFF000000),
    sidebar: const Color(0xFF000000),
    surface: const Color(0xFF0E0E10),
    overlay: const Color(0xFF161618),
    field: const Color(0xFF161618),
    control: const Color(0xFF1E1E21),
  );
}
