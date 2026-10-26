import 'dart:ui' show Color, Size;

import 'package:live_platform/live_platform.dart' show PlatformKind;
import 'package:live_shell/live_shell.dart';
import 'package:live_shell_desktop/src/displays.dart' show WindowOriginReader, centerOnWorkArea, defaultWindowSize;
import 'package:live_shell_desktop/src/window_material.dart';
import 'package:window_manager/window_manager.dart'
    show ColorToNative, OffsetToNative, SizeToNative, TitleBarStyle, WindowManager;

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
/// * **The caption style is dressed before anything moves the window.** The
///   hidden style hands the non-client area to the app's own strip while the
///   native frame — resize bands, snap, the DWM shadow — stays with the window,
///   so the plan that draws its own strip sets the style first and the geometry
///   after; the reverse order dresses a window that is already where it should
///   be with a caption it should not have.
/// * **The background colour is set when the effects are off**, so an opaque
///   window does not clear to a colour that shows through the corners as a black
///   square, which is the artefact the effects switch exists to escape. Only a
///   material that actually applied clears the surface, and it does so last.
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
  // A hot restart can leave the plugin's window registration a moment behind
  // the first boot task. Retry briefly instead of returning undressed: a
  // window that keeps its native caption while the shell believes it owns the
  // strip ends up with two title bars, and the title never reaches the taskbar.
  var window = WindowManager.instance.getCurrent();
  for (var attempt = 0; window == null && attempt < 20; attempt++) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    window = WindowManager.instance.getCurrent();
  }
  if (window == null) {
    // The runner always creates the current engine's window before Dart runs;
    // a null here means this engine owns no top-level window, and there is
    // nothing to dress.
    return;
  }
  // Who owns the non-client area is one question, and the plan answers it: the
  // shell draws the strip and takes the edges, or the operating system does.
  final takesFrameOver = plan.mode == ChromeMode.selfDrawn && plan.ownsResize;
  window
    ..title = title
    ..titleBarStyle = plan.mode == ChromeMode.nativeCaption ? TitleBarStyle.normal : TitleBarStyle.hidden
    ..minimumSize = minimumSize.toNative()
    ..setSize(initialSize.toNative(), false)
    ..isVisibleInTaskbar = role.showsInTaskbar
    // Always opaque at creation: on Windows 10 an unbacked transparent
    // surface shows the desktop through, because the compositor there has
    // no default backdrop to fall back on.
    ..backgroundColor = background.toNative();
  // The origin is ours to compute, not the plugin's: a placement nobody can
  // observe is a placement nobody can say is wrong. `placeWindow` is that
  // seam; a null answer means the display could not be read, and the window
  // keeps wherever the system put it.
  final origin = await placeWindow(initialSize);
  if (origin != null) {
    window.position = origin.toNative();
  }
  // The self-drawn plans answer the edge hit-test themselves: the window is
  // only draggable by its edges while it is resizable, so the flag is set
  // where the frame is ours, and left alone everywhere else — the system's
  // own caption already sizes the window.
  if (takesFrameOver) {
    window.isResizable = true;
  }
  // The material is applied last: on success the surface clears transparent
  // so the material shows; on refusal the opaque background set above stands
  // and nothing else changes.
  if (requestMaterial && !fallbacks.needsOpaqueSurface) {
    final applied = await (applyMaterial ?? applyWindowMaterial)(dark: materialDark);
    if (applied != AppliedWindowMaterial.none) {
      window.backgroundColor = const Color(0x00000000).toNative();
    }
  }
}

/// Re-applies the caption choice and title to the current window.
///
/// Called once after the first frame as a safety net for a boot that found no
/// window yet: geometry and minimum size already belong to the first pass, but
/// a window left with its native caption would show two title bars while the
/// shell draws its own strip.
Future<void> reapplyMainWindowChrome({required ChromePlan plan, required String title}) async {
  var window = WindowManager.instance.getCurrent();
  if (window == null) {
    for (var attempt = 0; attempt < 20; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      window = WindowManager.instance.getCurrent();
      if (window != null) break;
    }
  }
  if (window == null) return;
  window
    ..title = title
    ..titleBarStyle = plan.mode == ChromeMode.nativeCaption ? TitleBarStyle.normal : TitleBarStyle.hidden;
}

/// The plan for the platform's shipping arrangement.
///
/// Split out so a caller can ask "what will the window actually look like"
/// without duplicating the stage choice. Windows draws its own strip on every
/// build — 10 and 11 alike: the hidden caption keeps `WS_THICKFRAME`, so snap,
/// edge resize, the shadow and per-monitor DPI survive, and no build falls
/// back to the native caption. macOS stays at the first stage, where the
/// system's traffic lights sit inset in the app's own bar; Linux draws the
/// whole strip at either stage.
ChromePlan primaryChromePlan(PlatformKind platform) => ChromePlan.select(
  platform: platform,
  stage: platform == PlatformKind.macos ? ChromeStage.nativeFirst : ChromeStage.seamlessSelfDrawn,
);

/// Whether this platform has a tray at all.
///
/// Android and iOS have no notification area for an app to sit in, so a caller
/// building the shell on a phone must not construct a tray host and wait for it
/// to report failure — the failure is known before it starts.
bool supportsTray(PlatformKind platform) =>
    platform == PlatformKind.windows || platform == PlatformKind.linux || platform == PlatformKind.macos;
