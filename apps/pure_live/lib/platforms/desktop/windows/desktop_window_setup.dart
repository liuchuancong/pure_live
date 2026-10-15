import 'dart:ui' show Color, PlatformDispatcher;

import 'package:live_platform/live_platform.dart' show PlatformKind;
import 'package:live_shell/live_shell.dart';
import 'package:live_shell_desktop/live_shell_desktop.dart';

import 'package:pure_live/app/theme/app_theme.dart' show materialThemeSeed;
import 'package:pure_live/app/theme/appearance_preferences/appearance_preferences.dart';
import 'package:pure_live/app/theme/ui_configuration_mapper.dart' show uiConfigFromAppearance;
import 'package:pure_live/platforms/desktop/shell/shell_preferences.dart' show ShellWindowChrome;
import 'package:window_manager/window_manager.dart' show TitleBarStyle;

/// Sets the desktop window up before the first frame: size, minimum size,
/// title, background, and who owns the top edge.
///
/// [chrome] picks the title-bar mode. [ShellWindowChrome.app] (the default)
/// takes the frame over with the `bitsdojo_window` fork — `BDW_CUSTOM_FRAME`
/// in `windows/runner/main.cpp` strips the caption natively and answers
/// `WM_NCHITTEST`, so the plan below declares the self-drawn mode with
/// `ownsResize: false` (the helper sizes the window) and window_manager is
/// explicitly held at [TitleBarStyle.normal] so the two never fight over the
/// non-client area. [ShellWindowChrome.system] keeps the stock caption. The
/// choice is read once per start — the native helper has no runtime toggle —
/// and macOS/Linux always take [ChromeStage.nativeFirst]: their runners never
/// install the helper, and macOS keeps its traffic lights.
Future<void> setUpDesktopWindow({
  required PlatformKind kind,
  required String title,
  ShellWindowChrome chrome = ShellWindowChrome.app,
}) {
  final isWindows = kind == PlatformKind.windows;
  final plan = isWindows && chrome == ShellWindowChrome.app
      ? const ChromePlan(
          // The helper owns the frame; this plan records who draws the
          // buttons and keeps the strip's geometry from one source.
          mode: ChromeMode.selfDrawn,
          metrics: ChromeMetrics.windows(),
          ownsResize: false,
          ownsSnap: false,
          workAreaClampNeeded: false,
        )
      : ChromePlan.select(platform: kind, stage: ChromeStage.nativeFirst);
  return configureMainWindow(
    role: WindowRole.main,
    plan: plan,
    fallbacks: const RenderFallbacks(),
    title: title,
    background: _startBackground(),
    // Only meaningful in the helper-backed mode: `TitleBarStyle.hidden` would
    // be the plan-derived default, and two frame takeovers is one too many.
    titleBarStyle: plan.mode == ChromeMode.selfDrawn ? TitleBarStyle.normal : null,
  );
}

/// The clear colour of the window before Flutter paints, matched to the
/// surface the first frame will actually show.
///
/// The old constant (`0xFF141414`) predated the theme: on the app's light
/// default it flashed a dark rectangle for the first frames. The same seed
/// the app theme uses, against the platform's current brightness, is the
/// colour the viewer was going to see anyway.
Color _startBackground() {
  final config = uiConfigFromAppearance(const AppearancePreferences());
  final brightness = PlatformDispatcher.instance.platformBrightness;
  return materialThemeSeed(config, brightness).scaffoldBackgroundColor;
}
