import 'dart:ui' show Brightness, Color, PlatformDispatcher, Size;

import 'package:live_platform/live_platform.dart' show PlatformKind;
import 'package:live_shell/live_shell.dart';
import 'package:live_shell_desktop/live_shell_desktop.dart';

import 'package:pure_live/app/theme/app_theme.dart' show materialThemeSeed;
import 'package:pure_live/app/theme/appearance_preferences/appearance_preferences.dart';
import 'package:pure_live/app/theme/ui_configuration_mapper.dart' show uiConfigFromAppearance;
import 'package:pure_live/platforms/desktop/shell/shell_preferences.dart' show ShellWindowChrome;

/// Sets the desktop window up before the first frame: size, minimum size,
/// title, background, and who owns the top edge.
///
/// [chrome] picks the title-bar mode. [ShellWindowChrome.app] asks the window
/// plugin to take the frame over — `WindowOptions.customFrame`, applied by
/// [configureMainWindow] from the plan below — which strips the caption
/// natively, keeps `WS_THICKFRAME` so snap, `Win`+arrow and the shadow carry on
/// working, and answers the edge hit-test for all four sides. The plan therefore
/// declares the self-drawn mode with the edges taken; nothing else has to be
/// told, and there is no second component to hold back. A Windows below build
/// 22000 cannot carry the takeover, so there [chrome] folds to the system
/// caption whatever the caller passed — the same rule [resolveWindowChrome]
/// applies, repeated here because this function is the one that dresses the
/// window.
/// [ShellWindowChrome.system] keeps the stock caption. macOS and Linux take
/// [ChromeStage.nativeFirst] whatever the choice says: their runners never armed
/// a takeover, and macOS keeps its traffic lights.
///
/// [initialSize] is the window-size preference's stored answer, clamped to
/// the window's minimum; null keeps the launch default.
///
/// [opaqueSurface] withholds the material request, which is what clears the
/// window's surface: see [launchPinsOpaqueSurface].
Future<void> setUpDesktopWindow({
  required PlatformKind kind,
  required String title,
  ShellWindowChrome chrome = ShellWindowChrome.app,
  Size? initialSize,
  bool opaqueSurface = false,
}) {
  final isWindows = kind == PlatformKind.windows;
  const minimum = Size(900, 600);
  final size = initialSize == null
      ? defaultWindowSize
      : Size(initialSize.width.clamp(minimum.width, 3840.0), initialSize.height.clamp(minimum.height, 2160.0));
  final brightness = PlatformDispatcher.instance.platformBrightness;
  final plan = windowsCanTakeFrameOver(kind) && chrome == ShellWindowChrome.app
      ? ChromePlan.select(platform: kind, stage: ChromeStage.seamlessSelfDrawn)
      : ChromePlan.select(platform: kind, stage: ChromeStage.nativeFirst);
  return configureMainWindow(
    role: WindowRole.main,
    plan: plan,
    // `effects: false` is the existing seam for "no translucent material, keep a
    // solid surface" — it withholds the material request on its own.
    fallbacks: RenderFallbacks(effects: !opaqueSurface),
    title: title,
    background: _startBackground(brightness),
    // Windows is where the compositor offers a material and where a bare
    // transparent surface shows the desktop through; macOS and Linux keep
    // their own arrangement for now.
    requestMaterial: isWindows,
    materialDark: brightness == Brightness.dark,
    initialSize: size,
  );
}

/// Whether this launch pins the window to an opaque surface (`--opaque-surface`).
///
/// The one question it answers is where a paint artefact comes from. A taken-over
/// frame and a translucent material both live in the same band at the top of the
/// window, and the only way to tell them apart on a real machine is to take one
/// of them away — the material is what clears the surface, so refusing the request
/// leaves the frame untouched and the surface solid.
///
/// Development-only on purpose: it is not a preference, and a build that needs it
/// to look right has a bug to fix rather than a mode to ship.
bool launchPinsOpaqueSurface(List<String> args) => args.contains('--opaque-surface');

/// Whether this platform's Windows may wear the app-drawn frame at all.
///
/// Build 22000 is where the compositor draws a custom frame's edge and rounded
/// corners itself; below it a taken-over window is an edgeless rectangle, and
/// the themed caption flashes over the client on activation and drags — the
/// flicker a frame takeover reports on Windows 10. The gate is a rule, not a
/// default: the stored choice and the `--custom-frame` dev pin both fold to the
/// system caption through it, so no path can arm the takeover on Windows 10.
bool windowsCanTakeFrameOver(PlatformKind kind) => kind == PlatformKind.windows && windowsDrawsFrameEdgeItself();

/// The frame mode this process runs in.
///
/// Three steps, in this order, and both sides of the window's existence now read
/// the same list:
///
/// 1. `--native-frame` / `--custom-frame` on the command line (last one wins) —
///    a development pin, so a real-device check of one mode does not have to go
///    through the settings screen and a restart. The pin asks, the gate decides:
///    on a Windows that cannot carry the takeover `--custom-frame` answers the
///    system caption.
/// 2. The stored choice, which is what the settings screen writes.
/// 3. The operating system's default, from [windowsDrawsFrameEdgeItself].
///
/// Step 3 is why the stored value stays nullable: an upgrade from Windows 10 to
/// 11 has to pick up the strip without anyone changing a setting, and nothing
/// should have pinned the answer on the first start. On Windows 10 the answer
/// is `system` outright — step 2 never runs there, because the takeover is not
/// a mode that platform can ship.
///
/// This used to be a file in the user's profile, read by `wWinMain` before the
/// window existed, because the decision belonged to a native helper that had no
/// runtime toggle. The frame is now taken over through the same plugin call that
/// sets the title, so the preference store — which Dart can read before the
/// window is configured — is the only source, and the two implementations of one
/// precedence rule (a C++ copy that had to be mirrored by hand) are gone.
///
/// Call it once, at start-up, and keep the answer for the life of the process:
/// what the live window was dressed in does not change mid-run, so re-reading
/// mid-run can report a mode the window is not in.
ShellWindowChrome resolveWindowChrome({
  required PlatformKind kind,
  required List<String> args,
  ShellWindowChrome? stored,
}) {
  for (final argument in args.where((value) => value.startsWith('--')).toList(growable: false).reversed) {
    switch (argument) {
      case '--native-frame':
        return ShellWindowChrome.system;
      case '--custom-frame' when windowsCanTakeFrameOver(kind):
        return ShellWindowChrome.app;
    }
  }
  if (kind != PlatformKind.windows) {
    return stored ?? ShellWindowChrome.app;
  }
  if (!windowsCanTakeFrameOver(kind)) {
    return ShellWindowChrome.system;
  }
  return stored ?? ShellWindowChrome.app;
}

/// The clear colour of the window before Flutter paints, matched to the
/// surface the first frame will actually show.
///
/// The old constant (`0xFF141414`) predated the theme: on the app's light
/// default it flashed a dark rectangle for the first frames. The same seed
/// the app theme uses, against [brightness], is the colour the viewer was
/// going to see anyway.
Color _startBackground(Brightness brightness) {
  final config = uiConfigFromAppearance(const AppearancePreferences());
  return materialThemeSeed(config, brightness).scaffoldBackgroundColor;
}
