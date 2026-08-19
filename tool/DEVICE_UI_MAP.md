# Android device UI map

`device_ui_map.json` is the durable, screenshot-free UI test map for PureLive.
`android_ui.ps1` selects a profile by the device's current resolution and
orientation, scales cached coordinates when appropriate, and drives ADB taps,
swipes and common multi-step flows.

## Recorded baseline

The repository currently contains measured OnePlus 13 / PJZ110 profiles for:

- portrait `1440 x 3168`: home, live/offline filters, visible platform tabs,
  room cards, drawer, the full settings list, live-room app bar, player controls,
  danmaku tabs, local danmaku send, bottom navigation and scrolling gestures;
- landscape `3168 x 1440`: live-room app bar, video area, audio/cast/PiP controls,
  quality/line controls and the complete right-side danmaku panel;
- stable screen catalogs for home, drawer, settings top/middle/bottom and the
  live-room base state.

Dynamic room titles and danmaku text are not treated as stable controls.

## Fast path and verification

Normal runs use the cached coordinates directly, so they do not take a
screenshot and do not run image recognition. The script brings PureLive to the
foreground and verifies `topResumedActivity` before every action. This prevents
a cached coordinate from being sent to another app if the user changes apps
during a test.

`-VerifySemantics` optionally resolves a stored accessibility label with
UIAutomator before tapping. This is slower, but remains screenshot-free and is
useful after a layout change. If the label is unavailable, the measured
coordinate remains the fallback.

Screenshots and UI XML are collected only when a command fails and
`-CaptureOnFailure` was explicitly supplied.

## Commands

```powershell
# Validate JSON references and list every known point/flow/snapshot
.\tool\android_ui.ps1 -Validate
.\tool\android_ui.ps1 -List

# Preview or execute a cached action flow
.\tool\android_ui.ps1 -Sequence toggle_audio -DryRun
.\tool\android_ui.ps1 -Sequence toggle_audio

# Open frequently tested settings pages from the home page
.\tool\android_ui.ps1 -Sequence open_pip_danmaku_settings
.\tool\android_ui.ps1 -Sequence open_local_interaction_settings
.\tool\android_ui.ps1 -Sequence open_general_settings

# Resolve one visible control from accessibility semantics, without a screenshot
.\tool\android_ui.ps1 -TapSemantic '关闭菜单'

# Recheck a cached control against the current semantic tree before tapping
.\tool\android_ui.ps1 -Tap live.audio_toggle -VerifySemantics

# Record/correct a coordinate once; future tests reuse it
.\tool\android_ui.ps1 -Record settings.example -X 1200 -Y 900 `
  -Label '设置：示例入口'

# Store all stable actionable controls on the current route
.\tool\android_ui.ps1 -Snapshot settings.example
.\tool\android_ui.ps1 -RemoveSnapshot settings.example

# Save screenshot/XML evidence only if the requested action fails
.\tool\android_ui.ps1 -Sequence toggle_audio -CaptureOnFailure
```

Controls that auto-hide use a cached two-step flow: tap
`live.show_controls`, wait 700 ms, then tap the target. A UI hierarchy dump is
deliberately skipped on this fast path because it can outlive the control layer.

## Maintenance rules

1. Keep separate profiles for portrait and landscape; never rotate portrait
   coordinates blindly.
2. Add a semantic label whenever Flutter exposes one, but retain a measured
   coordinate for fast execution.
3. Give scroll-dependent points a suffix such as `_after_scroll2` and encode
   the required swipes in a named sequence.
4. Refresh the affected screen snapshot after a layout change and run
   `-Validate` before device regression.
5. Verify player state through app logs/semantics after each action. A successful
   tap alone is not a playback result.
