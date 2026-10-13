# live_shell_desktop

The plugin-bound half of the desktop shell: implementations of the seams
`live_shell` declares, against `window_manager`, `tray_manager`,
`screen_retriever` and `desktop_multi_window`.

## Purpose

`live_shell` keeps its decisions free of plugins so they can be tested headless.
Something still has to talk to the operating system, and that is this package: it
owns every `MethodChannel`, FFI call and native quirk, and translates them into
the shell's vocabulary without smuggling decisions back in.

## Responsibilities

- `WindowManagerHost` — the primary window as a `WindowHost`: event stream, geometry,
  maximise toggle, close interception. Owns the listener registration pairing
  (`attach`/`dispose`) because a duplicate registration delivers every close twice.
- `TrayManagerHost` — a `TrayHost` over `tray_manager`, with idempotent menu rebuilds
  (re-setting a menu closes the one the viewer is pointing at) and label truncation
  that never cuts a status suffix. The icon artwork it shows is **injected** by the
  caller through `iconAssets`; this package names no file.
- `DesktopWindowLauncher` / `SecondaryWindow` — real OS-level secondary windows in
  their own isolates, addressed by id.
- `ScreenRetrieverDisplays`, `DisplayReader` — displays in logical pixels, and the
  frame→display resolution the geometry policy needs.
- `configureMainWindow` / `primaryChromePlan` / `supportsTray` — the fan-out where a
  `ChromePlan`, `RenderFallbacks` and a `WindowRole` become actual window calls.
- `system_idle.dart` — the machine's idle span over `user32` FFI on Windows, and
  `null` elsewhere rather than a number that would look right.

## Explicitly not owned

Policy. If a function here answers "what should happen", it belongs in `live_shell`.
This package answers "what did the platform say, and what do I send it".

Brand artwork. Which icon a product shows in the notification area is the
application's identity, not a shell concern, so it is not declared or bundled
here — the app passes its own asset paths into `TrayManagerHost.iconAssets`. A
reusable host that hard-coded a particular mark could never be used by a
differently-branded product without forking it.

## Public entry point

`package:live_shell_desktop/live_shell_desktop.dart`.

## Dependencies

`live_shell` (the seams), plus `window_manager`, `tray_manager`, `screen_retriever`,
`desktop_multi_window`, `ffi`, `flutter`.

### Platform requirements and known plugin limits

- `TitleBarStyle` is only `normal | hidden` — a macOS inset traffic-light layout
  needs a change in `macos/Runner/MainFlutterWindow.swift`.
- `desktop_multi_window`'s `WindowController` has no `close`/`destroy`: a secondary
  window that was created but failed to configure stays until the process exits.
- `show`/`hide` go to the native layer by window id; `send` crosses the engine-to-engine
  bus and only lands once the other isolate has registered its handler.
- `GetLastInputInfo` is per interactive session: a locked screen or a UAC prompt is
  not observable as "user is away".

## Testing

```powershell
flutter test
```

The hosts are driven against faked method channels
(`TestDefaultBinaryMessengerBinding…setMockMethodCallHandler`) with the real channel
names and payload shapes, so the transport rules are checked without a window
server. The FFI idle reader is exercised against `user32` when the host is Windows
and skips elsewhere.

`TrayManagerHost` is **not** covered: `tray_manager`'s legacy singleton has a private
constructor and no injectable seam, and its remaining logic is glue over
already-tested policy.
