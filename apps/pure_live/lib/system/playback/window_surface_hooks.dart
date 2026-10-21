import 'dart:async';

/// The one seam between the window's shell and a room that is currently
/// wearing the window as a PiP/mini tile.
///
/// The shell owns the close button (its own close action runs hide, minimise
/// or quit); the room owns the playback. When "关闭小窗即暂停" is on and the
/// user closes the tile, the shell asks this hook to hand the stream back
/// first — restore the normal window and pause — so "closed" means stopped
/// rather than audio running behind a hidden window. A shell without a hook
/// installed (no tile open) closes exactly as the preference says.
abstract final class WindowSurfaceHooks {
  /// What a window close must run before its own disposition, if anything.
  /// The room sets it while its window is a tile and clears it on leaving
  /// the tile; identity is checked so one room never clears another's hook.
  static Future<void> Function()? onTileWindowClose;
}
