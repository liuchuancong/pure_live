import 'dart:io' show Platform;

import 'package:dynamic_color/dynamic_color.dart' show DynamicColorPlugin;
import 'package:flutter/widgets.dart' show Color;
import 'package:system_theme/system_theme.dart' show SystemTheme;

/// The machine's accent, however this platform expresses one, captured by
/// [preloadSystemAccent] and served synchronously afterwards.
///
/// Windows reads the accent the Settings app writes through the
/// `system_theme` plugin, the way the system's own Fluent apps do. Android
/// 12 and later answer through `dynamic_color` (the wallpaper's palette).
/// Every other platform — and any read that comes back null — leaves the
/// theme factory on its own seed.
Color? _accent;

/// Starts the accent round-trip so the first frame can already seed from
/// the machine's real colour; safe to call anywhere, a no-op where the
/// platform has no accent to give.
Future<void> preloadSystemAccent() async {
  if (Platform.isWindows) {
    await SystemTheme.accentColor.load();
    _accent = SystemTheme.accentColor.accent;
  } else if (Platform.isAndroid) {
    try {
      _accent = await DynamicColorPlugin.getAccentColor();
    } on Object {
      _accent = null;
    }
  }
}

/// The captured platform accent, or null before the preload ran and on
/// platforms with nothing to read.
Color? readSystemAccentColor() => _accent;
