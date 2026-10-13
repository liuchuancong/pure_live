# live_playback example

A runnable tour of `live_playback`. Every scenario the package is responsible
for has a button here, and every button acts on a real service: the same
coordinator, the same orchestration, the same recovery ladder. Only the backend
is fake — the kernel runs media_core's `testing` adapter instead of a codec — so
the tour needs no stream URL, no network and no platform window system.

## Running

The example is a workspace member, so from the repo root:

```powershell
flutter pub get
cd packages/live_playback/example
flutter run -d <device>       # windows, linux, macos, chrome, android, ios, ...
```

Or as a normal Flutter app:

```powershell
cd packages/live_playback/example
flutter create .              # generates platform folders on demand
flutter run
```

## What to look for

Work down the page; the state bar at the top never scrolls away.

- **直播页** — `打开直播间 A`, then `打开录播`. The room is *parked*, not
  closed: the chip row still shows two sessions and the room's phase is paused.
  `返回直播` reopens the room's line, which is what re-syncs a live stream to the
  live edge; `关闭全部` clears everything.
- **音频归属** — opening a second window mutes the first. `静音/取消` is the
  global switch, `弹幕开关（全局）` reaches every window, and the chips show both
  what the picture does (`弹幕: 显示/隐藏`) and whether the switch is off.
- **小窗与画中画** — `交给小窗` floats the picture inside the app: drag the small
  window, let go, and the demo *remembers* the rect per room, per surface and per
  video orientation. Flip `竖屏视频`/`横屏视频` and watch the window change shape;
  flip back and the portrait layout returns. `交给画中画` is refused while the
  platform switch says `平台支持画中画: 无` — a host without `media_core_pip`
  wired gets a refusal, not a fake state.
- **后台策略** — `允许画中画` on the platform plus `模拟退到后台` enters PiP and
  hides chat; turn `允许画中画` off (or the platform switch off) and
  backgrounding keeps only the sound; turn `后台播放` off as well and it pauses.
  Minimise the window instead of pressing the button and the same policy runs
  from the real lifecycle.
- **列表 / 详情** — `预览模式` makes the tiles silent and *releases* the audio
  channel (a preview holds nothing); `进详情` makes the item on screen audible;
  `退出详情 → 小窗` leaves it in a small window and pins it, so scrolling the
  list no longer recycles it.
- **多画面** — `加 room-N` builds a grid; the first tile is the one you hear,
  `听 room-N` moves the sound without moving the layout, `全部暂停`/`全部播放`
  drive every tile, and chat stays off on tiles that were added with it off.
- **日志** — the lines are the *service's* own reports (`audio owner ->`, `overlay
  ->`, `presentation ->`), not button echoes, so the log shows what the system
  did rather than what was clicked.

## Notes

- The tour runs on the fake backend on purpose: the point is the orchestration,
  not the pixels. A real app registers `media_core_media_kit` or
  `media_core_better_player` at the same call site in `demo_runtime.dart`.
- `PresentationAdapter` is the host's seam. The demo's adapter reports
  `floating: true` (an in-app window is pure widget work) and `pip: false`
  (system PiP needs an OS window), and the two `平台支持…` buttons flip those
  capabilities live — which is how the background policy changes its answer.
- `test/demo_walkthrough_test.dart` walks the tour as a widget test. Two
  environment facts shape it, both documented there: the panels live in a
  `ListView` (so the test uses a tall surface), and a widget test's fake clock
  cannot drive the kernel's release path (so steps that stop a session are
  asserted by the package's own `test/playback_scenarios_test.dart`, which runs
  outside that clock).
