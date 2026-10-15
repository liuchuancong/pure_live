# Changelog

## Unreleased

### Added

- Plugin-bound hosts for the shell seams: `WindowManagerHost`, `TrayManagerHost`,
  `DesktopWindowLauncher`/`SecondaryWindow`, `ScreenRetrieverDisplays`.
- `configureMainWindow`, which turns a `ChromePlan`, `RenderFallbacks` and a
  `WindowRole` into the window calls that actually reach the platform.
- `configureMainWindow` takes an optional `titleBarStyle` override, for the
  arrangement where an external frame helper (the `bitsdojo_window` fork's
  `BDW_CUSTOM_FRAME`) strips the caption itself and the self-drawn mode must
  not also ask for `TitleBarStyle.hidden`.
- `TrayManagerHost.createError`: the reason the last failed `create` failed.
  The bool outcome was always the close policy's business; the cause was
  dying in the catch, which is how a missing icon stays a mystery for weeks.
- `system_idle.dart`: the machine's idle span over `user32` FFI on Windows, absent
  on other platforms rather than guessed.

### Removed

- `tray_assets.dart` and the bundled `assets/tray/` artwork. A product's tray mark
  is brand identity, not a shell concern, so it is no longer declared or shipped by
  this package; the application supplies its own asset paths through
  `TrayManagerHost.iconAssets` (the seam already existed).

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

- `windowsTrayIcon`, `macOSMenuIcon`, `macOSMenuIconRetina` and `defaultTrayIcons`
  are no longer exported. Callers that built a `TrayManagerHost` now pass their own
  icon-asset map, so the mark travels with the app that owns the brand.
- Initial development release; no stability commitment yet.
