import 'package:live_shell/live_shell.dart' show ChromeMode;

/// Who owns the running window's title bar.
///
/// The caption style is dressed when the window is created, and every desktop
/// window is dressed to draw its own strip: the system's caption cannot carry
/// the app's chrome. The mode the boot's plan produced is recorded here so the
/// layouts can decide who draws the strip and its buttons — macOS keeps the
/// system's traffic lights inset in that strip, Windows and Linux draw the
/// buttons too.
abstract final class WindowChromeState {
  /// The mode the window was dressed in.
  static ChromeMode mode = ChromeMode.nativeCaption;

  /// Whether the shell draws its own strip for this window.
  static bool get drawsStrip => mode != ChromeMode.nativeCaption;

  /// Whether the strip also draws minimise, maximise and close. macOS keeps
  /// its own traffic lights inset in the app's bar, so the app does not add
  /// a second set.
  static bool get drawsCaptionControls => mode == ChromeMode.selfDrawn;
}
