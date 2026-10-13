# Changelog

## Unreleased

### Added

- Plugin-bound hosts for the shell seams: `WindowManagerHost`, `TrayManagerHost`,
  `DesktopWindowLauncher`/`SecondaryWindow`, `ScreenRetrieverDisplays`.
- `configureMainWindow`, which turns a `ChromePlan`, `RenderFallbacks` and a
  `WindowRole` into the window calls that actually reach the platform.
- `system_idle.dart`: the machine's idle span over `user32` FFI on Windows, absent
  on other platforms rather than guessed.
- `assets/tray/` with a five-size `.ico` and macOS menu-bar PNGs, plus the bundle-key
  constants for reaching package assets from a plugin that resolves by file path.

### Changed

- `WindowManagerHost` forwards both the in-progress and the settled move/resize
  events; `WindowListener`'s defaults are no-ops, so a missing override silently
  stops the window's place from ever being remembered.
- `geometry()` reads `isMaximized()` from the window manager instead of tracking the
  last event.
- `show()` applies the role's focus rule itself, so a popup can no longer be raised
  onto the keyboard by a caller that forgot to pass `inactive: true`.
- Displays reach the host through a `DisplayReader` seam, which is what makes the
  geometry path testable without a display server.

### Breaking Changes

- Initial development release; no stability commitment yet.
