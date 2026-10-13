# Changelog

## Unreleased

### Added

- `DesktopPreferences` — the desktop shell group: close action, tray icon,
  remember-window-bounds, launch at sign-in, start hidden, idle reclaim with its
  threshold, the two rendering escape hatches, and system notifications.
- `DesktopPreferencesAsShell` — projection into `live_shell`'s `ShellSettings` and
  `RenderFallbacks`, so the mapping is testable instead of hand-written at the call
  site, and `desktopFieldConsumers`, the table naming the consumer of every field.
- Tests pinning the persisted document shape and the consumer table.

### Changed

- `closeAction` is the shell's `CloseAction` rather than a second copy of the same
  three values, so a new case cannot drift between the two declarations.
- An unrecognised or mistyped `closeAction` resets to the default instead of
  throwing: the generated enum decoder throws on unknown values, which would have
  turned a rolled-back install reading a newer document into an app that cannot
  start.

### Breaking Changes

- Initial development release; no stability commitment yet.
