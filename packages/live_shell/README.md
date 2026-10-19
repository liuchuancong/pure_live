# live_shell

The desktop shell's **decisions**, with no plugins and no widget code in them.

## Purpose

A desktop window has to answer a stream of awkward questions: what does its close
button mean, where does it come back after a monitor is unplugged, what may the
caption claim to own, how does a second launch reach the first, and when may the
interface be destroyed to give memory back. Each answer depends on the platform
and on facts the running process can only learn by asking.

This package makes every one of those answers a **function of its inputs**, so
they can be tested without a display server, a tray, or a window manager.

## Responsibilities

- Close and quit semantics: `resolveCloseDisposition`, `shouldQuitOnAllWindowsClosed`,
  and `QuitLedger` (which records quit intent at the moment the primary window is
  destroyed, because a secondary window can keep `last-window-closed` from ever
  arriving).
- Geometry: logical-pixel `PixelRect`/`WindowGeometry`, `keepOnScreen`, and the rule
  that a maximised window's remembered frame is the restore size, not the maximised
  rectangle.
- Chrome: `ChromePlan` (what the caption claims to own) and `hitTestChrome`, which
  tests caption buttons before resize edges because the two failure modes are not
  equally bad.
- Single instance: `LaunchIntent` and `SocketInstanceChannel`, which forward a
  launch's arguments to the running instance over a loopback socket.
- Secondary windows: `WindowRole`, `SecondaryWindows` (which roles are singletons),
  and `LaunchRouter` for handing an incoming intent to the window that should take it.
- Idle reclaim: `IdleWatcher`, `shouldReclaimForIdle`, and `ReclaimCircuit`.
- Orchestration: `DesktopShell`, which sequences start-up, close, reveal, tray refresh
  and exit using the above.

## Explicitly not owned

- **No plugin calls.** `window_frame_kit`, `tray_manager` and `desktop_multi_window` are
  implemented against the seams declared here (`WindowHost`, `TrayHost`,
  `WindowLauncher`) by `live_shell_desktop`.
- No widgets, no painting, no theme. Caption *buttons* are `pure_uikit`'s; this
  package only decides where they are and what they mean.
- No storage. `DesktopShell` is handed `ShellSettings` by a callback and a save/load
  pair for geometry; it never opens a file or a box.
- No knowledge of the application's pages, routes, or rooms.

## Who may depend on it

`live_shell_desktop` (implements the seams), `live_preferences` (uses `CloseAction`
and receives `ShellSettings`), and the application's composition root. Business
packages have no reason to import it.

## Public entry point

`package:live_shell/live_shell.dart` — the only intended import. Implementation
lives under `lib/src/`, one concern per directory.

## Dependencies

`live_platform` (for `PlatformKind`, so platform identity has one owner) and `meta`.
Pure Dart: `dart test` runs the whole suite headless.

## Testing

```powershell
dart test
```

Behaviour is tested through the decision functions and through `DesktopShell` with
fake hosts; `test/desktop_shell_test.dart` drives the sequence (start, close,
reclaim, quit) rather than the plumbing.

## Known limitations

- The maximised state can only be *restored* correctly if the Windows runner shows its
  window with `SW_SHOW`; `SW_SHOWNORMAL` un-maximises it after this package has
  applied the remembered state. See `restoreGeometry`'s documentation.
- A secondary window that was created but failed to configure cannot be destroyed
  through these seams — `desktop_multi_window` exposes no close. See `SecondaryWindow.hide`.
- `WindowManagerHost` reports no first-frame signal, so a window that is alive but
  painting nothing is not detectable from here.
