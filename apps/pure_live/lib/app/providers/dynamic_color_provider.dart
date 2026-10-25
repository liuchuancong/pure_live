import 'dart:async' show unawaited;
import 'dart:ui' show Color;

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/app/theme/theme_persistence.dart';

/// Whether the platform's dynamic palette seeds the theme.
///
/// The palette itself comes from [dynamicColorSeedProvider]; off keeps the
/// viewer's own accent, and an unsupported platform never shows the switch.
final class DynamicColorController extends Notifier<bool> {
  @override
  bool build() => ThemePersistence.readDynamicColor();

  /// Whether dynamic colour is on.
  bool get enabled => state;

  /// Stores the choice; the root watches [state] for the theme.
  set enabled(bool value) {
    if (state == value) return;
    state = value;
    unawaited(ThemePersistence.storeDynamicColor(value: value));
  }
}

/// The dynamic-colour preference.
final dynamicColorProvider = NotifierProvider<DynamicColorController, bool>(DynamicColorController.new);

/// The primary colour of the platform's dynamic palette, or null where the
/// platform has no palette to offer.
///
/// Android 12+ answers with the wallpaper's Material You palette; Windows,
/// macOS and Linux answer with the system accent, which is the closest
/// equivalent those systems expose. iOS has no such palette, so its row stays
/// hidden instead of presenting a switch that cannot do anything. The design
/// system builds a full light/dark pair from one seed, so the palette's light
/// primary is the seed and its dark counterpart would be derived from it.
final dynamicColorSeedProvider = FutureProvider<Color?>((ref) async {
  if (kIsWeb) return null;
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      try {
        final palette = await DynamicColorPlugin.getCorePalette();
        return palette?.toColorScheme().primary;
      } on Object {
        return null;
      }
    case TargetPlatform.windows:
    case TargetPlatform.macOS:
    case TargetPlatform.linux:
      try {
        return await DynamicColorPlugin.getAccentColor();
      } on Object {
        return null;
      }
    case TargetPlatform.iOS:
    case TargetPlatform.fuchsia:
      return null;
  }
});
