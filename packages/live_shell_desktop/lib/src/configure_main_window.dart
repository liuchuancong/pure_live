import 'dart:ui' show Color, Size;

import 'package:live_platform/live_platform.dart' show PlatformKind;
import 'package:live_shell/live_shell.dart';
import 'package:live_shell_desktop/src/displays.dart' show defaultWindowSize;
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
/// * **Frameless is asked for only when the plan says the shell owns resize.**
///   Calling `setAsFrameless()` "to hide the title bar" while leaving
///   [ChromePlan.ownsResize] false is the trap on Windows: the buttons go, and
///   with them the snap layouts, the edge resize, `Win`+arrow, the shadow and the
///   taskbar-aware maximise — everything `WS_THICKFRAME` was doing for free.
/// * **The background colour is set when the effects are off**, so an opaque
///   window does not clear to a colour that shows through the corners as a black
///   square, which is the artefact the effects switch exists to escape.
///
/// [titleBarStyle] overrides the style the [plan]'s mode would pick. It exists
/// for the Windows arrangement where an external frame helper (the
/// `bitsdojo_window` fork's `BDW_CUSTOM_FRAME`) strips the caption itself and
/// answers `WM_NCCALCSIZE`: there the self-drawn mode must *not* also ask for
/// `TitleBarStyle.hidden`, or two components own the same non-client area and
/// every restore/maximise cycle re-fights over it. The helper-backed caller
/// passes [TitleBarStyle.normal] and keeps `mode: ChromeMode.selfDrawn` purely
/// as the record of who draws the buttons.
Future<void> configureMainWindow({
  required WindowRole role,
  required ChromePlan plan,
  required RenderFallbacks fallbacks,
  required String title,
  required Color background,
  Size minimumSize = const Size(900, 600),
  Size initialSize = defaultWindowSize,
  TitleBarStyle? titleBarStyle,
  bool requestMaterial = false,
  bool materialDark = false,
  WindowMaterialApplier? applyMaterial,
}) async {
  await windowManager.ensureInitialized();
  // The plugin's ready-callback is a synchronous VoidCallback and nothing awaits
  // it, so the steps that matter are done after this call returns rather than
  // inside a closure whose completion nobody can observe.
  await windowManager.waitUntilReadyToShow(
    WindowOptions(
      title: title,
      size: initialSize,
      minimumSize: minimumSize,
      center: true,
      // Always opaque at creation: on Windows 10 an unbacked transparent
      // surface shows the desktop through, because the compositor there has
      // no default backdrop to fall back on. Only a material that actually
      // applied clears the surface, and it does so after this call, below.
      backgroundColor: background,
      titleBarStyle:
          titleBarStyle ?? (plan.mode == ChromeMode.nativeCaption ? TitleBarStyle.normal : TitleBarStyle.hidden),
      // From the role, not a literal: a floating video window and a corner toast
      // asked for by name must not clutter alt-tab, and hard-coding `false` here
      // is how that promise gets broken by the next caller.
      skipTaskbar: !role.showsInTaskbar,
    ),
  );
  if (plan.mode == ChromeMode.selfDrawn && plan.ownsResize) {
    await windowManager.setAsFrameless();
  }
  // macOS's `hidden` style keeps the traffic lights and the app draws beneath
  // them; a true inset — moving the buttons into a sidebar — needs a change in
  // macos/Runner/MainFlutterWindow.swift (titlebarAppearsTransparent plus the
  // standardWindowButton frames), because window_manager exposes no offset.
  await windowManager.setResizable(!plan.ownsResize || plan.mode != ChromeMode.selfDrawn);
  // The window exists only after waitUntilReadyToShow, so the material is
  // applied here rather than before the options: on success the surface
  // clears transparent so the material shows; on refusal the opaque
  // background set above stands and nothing else changes.
  if (requestMaterial && !fallbacks.needsOpaqueSurface) {
    final applied = (applyMaterial ?? applyWindowMaterial)(dark: materialDark);
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
