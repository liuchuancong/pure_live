import 'dart:ui' show Color, Size;

import 'package:live_platform/live_platform.dart' show PlatformKind;
import 'package:live_shell/live_shell.dart';
import 'package:live_shell_desktop/src/displays.dart' show WindowOriginReader, centerOnWorkArea, defaultWindowSize;
import 'package:live_shell_desktop/src/window_material.dart';
import 'package:window_manager/window_manager.dart';

/// Applies a [ChromePlan] and the rendering fallbacks to the window, before the
/// first frame is shown.
///
/// The whole point of this function is the order it forces:
///
/// * **`hardwareAcceleration` cannot be changed here.** It is an embedder switch
///   read when the window is created, so a settings change is a next-start
///   change, and the settings screen has to say so — a toggle that appears to do
///   nothing is worse than no toggle, because the viewer keeps reaching for it
///   while their screen is broken.
/// * **The frame takeover is asked for only when the plan says the shell owns
///   resize.** `WindowOptions.customFrame` is the plugin's own non-client-area
///   handler — the whole window becomes client area, all four edges and corners
///   resize through one hit-test, and maximising still fits the work area — so
///   a plan that draws its own strip *and* takes the edges is exactly what it is
///   for. Asking for it under a plan that does not own the edges, or leaving it
///   off under one that does, is how a window ends up with no resize band, or
///   with two components answering `WM_NCCALCSIZE` for the same window.
///   [ChromeStage.seamlessSelfDrawn]'s note about needing "a native helper that
///   keeps `WS_THICKFRAME`" is this option: the helper is in the same plugin now,
///   so there is one delegate and no second dependency.
/// * **The background colour is set when the effects are off**, so an opaque
///   window does not clear to a colour that shows through the corners as a black
///   square, which is the artefact the effects switch exists to escape.
///
/// The order is the plugin's, not a choice made here: `customFrame` is applied
/// after `titleBarStyle` and before any fullscreen/maximised state is restored,
/// so the native subclass is installed before anything moves the window.
Future<void> configureMainWindow({
  required WindowRole role,
  required ChromePlan plan,
  required RenderFallbacks fallbacks,
  required String title,
  required Color background,
  Size minimumSize = const Size(900, 600),
  Size initialSize = defaultWindowSize,
  WindowOriginReader placeWindow = centerOnWorkArea,
  bool requestMaterial = false,
  bool materialDark = false,
  WindowMaterialApplier? applyMaterial,
}) async {
  // Who owns the non-client area is one question, and the plan answers it: the
  // shell draws the strip and takes the edges, or the operating system does.
  final takesFrameOver = plan.mode == ChromeMode.selfDrawn && plan.ownsResize;
  await windowManager.ensureInitialized();
  // The plugin's ready-callback is a synchronous VoidCallback and nothing awaits
  // it, so the steps that matter are done after this call returns rather than
  // inside a closure whose completion nobody can observe.
  await windowManager.waitUntilReadyToShow(
    WindowOptions(
      title: title,
      size: initialSize,
      minimumSize: minimumSize,
      backgroundColor: background,
      titleBarStyle: plan.mode == ChromeMode.nativeCaption ? TitleBarStyle.normal : TitleBarStyle.hidden,
      skipTaskbar: !role.showsInTaskbar,
    ),
  );
  final origin = await placeWindow(initialSize);
  if (origin != null) {
    await windowManager.setPosition(origin);
  }
  if (takesFrameOver) {
    await windowManager.setResizable(true);
  }
  if (requestMaterial && !fallbacks.needsOpaqueSurface) {
    final applied = await (applyMaterial ?? applyWindowMaterial)(dark: materialDark);
    if (applied != AppliedWindowMaterial.none) {
      await windowManager.setBackgroundColor(const Color(0x00000000));
    }
  }
}

/// The plan for the platform's shipping arrangement, first stage.
///
/// Split out so a caller can ask "what will the window actually look like"
/// without duplicating the stage choice, which is what decides whether the
/// caption buttons are ours to draw or the system's.
ChromePlan primaryChromePlan(PlatformKind platform, {ChromeStage stage = ChromeStage.nativeFirst}) =>
    ChromePlan.select(platform: platform, stage: stage);

/// Whether this platform has a tray at all.
///
/// Android and iOS have no notification area for an app to sit in, so a caller
/// building the shell on a phone must not construct a tray host and wait for it
/// to report failure — the failure is known before it starts.
bool supportsTray(PlatformKind platform) =>
    platform == PlatformKind.windows || platform == PlatformKind.linux || platform == PlatformKind.macos;
