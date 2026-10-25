import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:live_shell/live_shell.dart' show ChromeMode;
import 'package:live_storage/live_storage.dart' show StoragePrefs;

/// Who owns the window's title bar: the operating system's caption, or the
/// app's own strip.
enum WindowChrome {
  /// The system draws and handles the caption.
  system,

  /// The app draws the strip (the seamless self-drawn stage).
  custom,
}

/// The window chrome this process booted with.
///
/// The caption style is dressed when the window is created — the window plugin
/// arms its frame takeover then — so the choice is read at boot and a change
/// takes effect on the next start. The layouts ask [drawsStrip]: with a native
/// caption the shell must NOT draw its own strip as well (that is two title
/// bars), and with the self-drawn stage it must.
///
/// The choice exists on Windows only: macOS keeps the system's traffic lights
/// inset in the app's bar (still the system buttons), Linux draws its own strip
/// either way.
abstract final class WindowChromeState {
  /// Where the choice persists.
  static const String key = 'window.chrome';

  /// The chrome this process booted with.
  static WindowChrome chrome = WindowChrome.system;

  /// The mode the window was dressed in.
  static ChromeMode mode = ChromeMode.nativeCaption;

  /// Whether the shell draws its own strip for this window.
  static bool get drawsStrip => mode != ChromeMode.nativeCaption;

  /// Whether the strip also draws minimise, maximise and close. macOS keeps
  /// its own traffic lights inset in the app's bar, so the app does not add
  /// a second set.
  static bool get drawsCaptionControls => mode == ChromeMode.selfDrawn;

  /// Whether the settings surface offers the choice.
  static bool get configurable => !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  /// The stored choice; the native caption when nothing was chosen (the
  /// reference's restraint: the system keeps the frame it already knows).
  static WindowChrome readStored() {
    try {
      return StoragePrefs.getString(key) == WindowChrome.custom.name ? WindowChrome.custom : WindowChrome.system;
    } on Object {
      return WindowChrome.system;
    }
  }

  /// Stores [chrome].
  static Future<void> store(WindowChrome chrome) async {
    try {
      await StoragePrefs.setString(key, chrome.name);
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}
