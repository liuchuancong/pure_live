import 'dart:ui' show Color, Size;

import 'package:live_platform/live_platform.dart' show PlatformKind;
import 'package:live_shell/live_shell.dart';
import 'package:live_shell_desktop/src/displays.dart' show WindowOriginReader, centerOnWorkArea, defaultWindowSize;
import 'package:live_shell_desktop/src/window_material.dart';
import 'package:window_frame_kit/window_frame_kit.dart';

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
      // Always opaque at creation: on Windows 10 an unbacked transparent
      // surface shows the desktop through, because the compositor there has
      // no default backdrop to fall back on. Only a material that actually
      // applied clears the surface, and it does so after this call, below.
      backgroundColor: background,
      // macOS's `hidden` style keeps the traffic lights and the app draws beneath
      // them; a true inset — moving the buttons into a sidebar — needs a change in
      // macos/Runner/MainFlutterWindow.swift (titlebarAppearsTransparent plus the
      // standardWindowButton frames), because the window plugin exposes no offset.
      titleBarStyle: plan.mode == ChromeMode.nativeCaption ? TitleBarStyle.normal : TitleBarStyle.hidden,
      // `null` sends no channel call at all, so a plan that leaves the frame to
      // the system is untouched — the window keeps the caption it was created with.
      customFrame: takesFrameOver ? true : null,
      // From the role, not a literal: a floating video window and a corner toast
      // asked for by name must not clutter alt-tab, and hard-coding `false` here
      // is how that promise gets broken by the next caller.
      skipTaskbar: !role.showsInTaskbar,
    ),
  );
  // The origin is ours to compute, not the plugin's: `WindowOptions.center` and
  // `center()` both reach the display API through FFI handles, which a unit test has
  // no way to answer, and a placement nobody can observe is a placement nobody can
  // say is wrong. `placeWindow` is that seam; a null answer means the display could
  // not be read, and the window keeps wherever the system put it.
  final origin = await placeWindow(initialSize);
  if (origin != null) {
    await windowManager.setPosition(origin);
  }
  // The takeover's resize bands are gated on the window being resizable: a
  // custom frame that is told it is not says so by answering the hit-test with
  // no band at all, which leaves the window undraggable at every edge. So the
  // flag is set where the frame is ours, and left alone everywhere else — the
  // system's own caption already sizes the window.
  if (takesFrameOver) {
    await windowManager.setResizable(true);
  }
  // The window exists only after waitUntilReadyToShow, so the material is
  // applied here rather than before the options: on success the surface
  // clears transparent so the material shows; on refusal the opaque
  // background set above stands and nothing else changes.
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
