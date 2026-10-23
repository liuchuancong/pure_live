import 'dart:io' show Platform;

import 'package:flutter/widgets.dart' show Color;
import 'package:system_theme/system_theme.dart' show SystemTheme;

/// The machine's own accent colour, or null when the platform has none to
/// give.
///
/// Windows reads the accent the Settings app writes through the `system_theme`
/// plugin, the way the system's own Fluent apps do; the answer before — or
/// without — a successful read is the plugin's fallback colour. Other
/// platforms have nothing to read here, and the theme factory keeps its own
/// seed.
Color? readSystemAccentColor() {
  if (!Platform.isWindows) {
    return null;
  }
  return SystemTheme.accentColor.accent;
}

/// Starts the accent round-trip so the first frame can already seed from the
/// machine's real colour; safe to call anywhere, a no-op off Windows.
Future<void> preloadSystemAccent() async {
  if (Platform.isWindows) {
    await SystemTheme.accentColor.load();
  }
}
