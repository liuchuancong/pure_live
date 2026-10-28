import 'dart:async' show StreamSubscription, unawaited;

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/widgets.dart' show Size;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_shell_desktop/live_shell_desktop.dart' show ScreenRetrieverDisplays, frameToRect;
import 'package:media_core/media_core.dart';
import 'package:media_core_fullscreen/media_core_fullscreen.dart';
import 'package:media_core_pip/media_core_pip.dart';
import 'package:pure_live/app/providers/player/player_providers.dart' show playerKernelProvider;
import 'package:pure_live/app/providers/window/multi_view_window_adapters.dart'
    show MultiViewFullscreenWindow, MultiViewPipWindow;
import 'package:pure_live/app/providers/window/pip_geometry.dart' show readPipSavedBounds, writePipSavedBounds;
import 'package:pure_live/app/providers/window/system_pip.dart' show exitSystemPip, isSystemPipHost;
import 'package:pure_live/app/windows/context/app_window_context.dart' show appWindowContextProvider;
import 'package:pure_live/features/settings/settings.dart';

/// The app's fullscreen driver: media_core's own, over the current view's
/// multiview window. The per-window scope supplies a fresh driver to every
/// window, so making one window fullscreen never touches another.
final Provider<FullscreenDriver> fullscreenDriverProvider = Provider<FullscreenDriver>(createFullscreenDriver);

/// Builds one window's fullscreen driver.
FullscreenDriver createFullscreenDriver(Ref ref) {
  final desktop =
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;
  final driver = FullscreenDriver(
    desktopWindow: desktop ? MultiViewFullscreenWindow(ref.watch(appWindowContextProvider).viewId) : null,
  );
  unawaited(driver.initialize());
  ref.onDispose(() => unawaited(driver.dispose()));
  return driver;
}

/// The compact window: the placement policy around the multiview backend, with
/// the z-order setting applied on every entry and live while compact.
final Provider<DisplayAwarePipWindow?> windowsPipWindowProvider = Provider<DisplayAwarePipWindow?>(
  createWindowsPipWindow,
);

/// Builds one window's compact-window policy.
DisplayAwarePipWindow? createWindowsPipWindow(Ref ref) {
  final desktop =
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;
  if (!desktop) return null;
  final viewId = ref.watch(appWindowContextProvider).viewId;
  return DisplayAwarePipWindow(
    windowBuilder: () => MultiViewPipWindow(viewId),
    // The placement policy works against real monitor work areas. Without
    // them it treats the app window's own bounds as the whole desktop, so the
    // compact window is confined to that rectangle — and every placement is
    // recorded against an empty display id, which the store refuses, so the
    // remembered position is never written at all.
    workAreasReader: () async {
      try {
        final displays = await const ScreenRetrieverDisplays().read();
        return [for (final display in displays) PipWorkArea(id: display.id, area: frameToRect(display.workArea))];
      } on Object {
        // No display server answer: the policy falls back to the window's own
        // bounds, which is still better than refusing to open the window.
        return const <PipWorkArea>[];
      }
    },
    alwaysOnTop: () => ref.read(playbackSettingsProvider).windowsPipAlwaysOnTop,
    smallWindowSize: (aspectRatio) => windowsPipWindowSizeFor(ref.read(playbackSettingsProvider), aspectRatio),
    minWidth: () => ref.read(playbackSettingsProvider).windowsPipMinWidth,
    minHeight: () => ref.read(playbackSettingsProvider).windowsPipMinHeight,
    readSavedBounds: () {
      if (!ref.read(playbackSettingsProvider).rememberPipPosition) return null;
      return readPipSavedBounds(portrait: _pipShowsPortrait(ref));
    },
    writeSavedBounds: (size, position, displayId) {
      // The policy writes on entry as well; with remembering off it must not
      // keep a placement the viewer never asked to keep.
      if (!ref.read(playbackSettingsProvider).rememberPipPosition) return;
      writePipSavedBounds(portrait: _pipShowsPortrait(ref), size: size, position: position, displayId: displayId);
    },
    // Re-apply the app's normal window floor when leaving the compact window.
    normalMinSize: const Size(400, 300),
  );
}

/// Whether the PiP driver currently holds a portrait video. The driver owns
/// the stream's real dimensions; an unknown size (before the first report)
/// keeps the landscape slot.
bool _pipShowsPortrait(Ref ref) {
  try {
    final driver = ref.read(pipDriverProvider);
    final width = driver.videoWidth;
    final height = driver.videoHeight;
    if (width <= 0 || height <= 0) return false;
    return height > width;
  } on Object {
    return false;
  }
}

/// The compact-window policy the current settings ask for. The base size is
/// the long side: the driver derives a portrait stream's height from it too.
PipConfig windowsPipConfigFor(PlaybackSettings settings) => PipConfig(
  width: settings.windowsPipBaseSize,
  height: settings.windowsPipBaseSize * 9 / 16,
  minWidth: settings.windowsPipMinWidth,
  minHeight: settings.windowsPipMinHeight,
  lockAspectRatio: !settings.windowsPipFreeAspect,
  title: 'PureLive',
);

/// The compact window's initial shape for [aspectRatio], from the viewer's
/// base long side and resize floors. The floors win when they exceed the
/// base: an aspect-exact floor is still the floor the viewer asked for.
Size windowsPipWindowSizeFor(PlaybackSettings settings, double aspectRatio) {
  final ratio = aspectRatio.isFinite && aspectRatio > 0 ? aspectRatio : 16 / 9;
  var width = ratio >= 1 ? settings.windowsPipBaseSize : settings.windowsPipBaseSize * ratio;
  var height = ratio >= 1 ? settings.windowsPipBaseSize / ratio : settings.windowsPipBaseSize;
  if (width < settings.windowsPipMinWidth) {
    width = settings.windowsPipMinWidth;
    height = width / ratio;
  }
  if (height < settings.windowsPipMinHeight) {
    height = settings.windowsPipMinHeight;
    width = height * ratio;
  }
  return Size(width, height);
}

/// The app's picture-in-picture driver: media_core's own, on a desktop and on
/// iOS.
///
/// The watched window becomes a compact, always-shaped window on a desktop.
/// On iOS the system's window lifts the AVPlayerLayer already on screen
/// (`pip_kit`), so the app's engine and player keep running untouched.
///
/// Android's 小窗 is not one of media_core's presentation modes: in the app it
/// is the room's floating player, and over the other apps it is
/// `FloatingOverlay` — both keep this engine and its player. media_core_pip's
/// Android backend (`flutter_overlay_window`) boots a second engine that
/// registers no plugins, so none of the video backends this app ships could
/// render there; it is not offered rather than entered and failed.
final Provider<PipDriver> pipDriverProvider = Provider<PipDriver>(createPipDriver);

/// Builds one window's picture-in-picture driver.
PipDriver createPipDriver(Ref ref) {
  final driver = PipDriver(
    config: windowsPipConfigFor(ref.read(playbackSettingsProvider)),
    desktopWindow: ref.watch(windowsPipWindowProvider),
    // The compact window is about to be restored: store where the viewer
    // actually left it. The placement policy records where it put the window
    // on entry, but a drag or resize after that is only known right here —
    // without this, "记住小窗位置" reopens at the auto-placed spot.
    lifecycleHooks: PresentationLifecycleHooks(
      beforeExit: (event) async {
        if (event.mode != PresentationMode.pip) return;
        await ref.read(windowsPipWindowProvider)?.captureGeometry();
      },
    ),
    // Android hands the stream to a second engine; only a plain HTTP(S)
    // address can be opened by it. A signed, loopback-proxied source
    // resolves to null and the driver refuses the entry instead of showing
    // an empty window.
    pipMediaResolver: (playerId) async {
      final handle = ref.read(playerKernelProvider).get(playerId);
      final uri = handle?.source?.uri;
      if (handle == null || uri == null) {
        return null;
      }
      if (uri.scheme != 'http' && uri.scheme != 'https') {
        return null;
      }
      // A live source has no resume point: the second engine must start at
      // the live edge, not seek to the elapsed time the first engine read.
      return SystemPipMedia(url: uri.toString());
    },
  );
  // The compact window's shape follows the viewer's settings live: a
  // changed base size, floor or aspect lock rewrites the driver's config in
  // place, so the next entry uses it without a restart. The placement
  // callbacks already read the settings at call time.
  ref.listen(
    playbackSettingsProvider.select(
      (settings) => (
        settings.windowsPipBaseSize,
        settings.windowsPipMinWidth,
        settings.windowsPipMinHeight,
        settings.windowsPipFreeAspect,
      ),
    ),
    (previous, next) {
      if (previous != next) driver.config = windowsPipConfigFor(ref.read(playbackSettingsProvider));
    },
  );
  unawaited(driver.initialize());
  ref.onDispose(() => unawaited(driver.dispose()));
  return driver;
}

/// The kernel's one presentation driver: the chain that routes each mode to
/// the feature driver that owns it. Disposing the chain disposes both.
final Provider<PresentationDriverChain> presentationDriverProvider = Provider<PresentationDriverChain>(
  createPresentationDriver,
);

/// Builds one window's presentation chain.
PresentationDriverChain createPresentationDriver(Ref ref) {
  final chain = PresentationDriverChain(
    bindings: [
      PresentationDriverBinding(
        modes: const {PresentationMode.fullscreen, PresentationMode.windowFullscreen},
        driver: ref.watch(fullscreenDriverProvider),
      ),
      PresentationDriverBinding(modes: const {PresentationMode.pip}, driver: ref.watch(pipDriverProvider)),
    ],
  );
  ref.onDispose(() => unawaited(chain.dispose()));
  return chain;
}

/// The room's presentation right now, mirrored from the drivers' own state
/// streams so a system-ended PiP or an ESC press is reflected without the
/// page's hand.
final class RoomPresentationController extends Notifier<PresentationMode> {
  StreamSubscription<bool>? _fullscreen;
  StreamSubscription<bool>? _pip;

  @override
  PresentationMode build() {
    final fullscreen = ref.watch(fullscreenDriverProvider);
    final pip = ref.watch(pipDriverProvider);
    _fullscreen ??= fullscreen.onFullscreenChanged.listen((_) => _sync());
    _pip ??= pip.onPipChanged.listen((_) => _sync());
    ref.onDispose(() {
      unawaited(_fullscreen?.cancel() ?? Future<void>.value());
      unawaited(_pip?.cancel() ?? Future<void>.value());
      _fullscreen = null;
      _pip = null;
    });
    return _currentMode();
  }

  /// The drivers' current answer.
  PresentationMode _currentMode() {
    final fullscreen = ref.read(fullscreenDriverProvider);
    final pip = ref.read(pipDriverProvider);
    if (pip.isPip) return PresentationMode.pip;
    if (fullscreen.isWindowFullscreen) return PresentationMode.windowFullscreen;
    if (fullscreen.isSystemFullscreen) return PresentationMode.fullscreen;
    return PresentationMode.normal;
  }

  /// Re-reads the drivers; the last transition wins.
  void _sync() {
    final next = _currentMode();
    if (state != next) state = next;
  }

  /// Whether this window offers the picture-in-picture button.
  ///
  /// Desktop lays out its own compact window; a phone enters the system's
  /// window over the app (iOS). Android's 小窗 is not a presentation mode: in
  /// the app it is the room's floating player (`floatPlay`), and over the
  /// other apps it is `FloatingOverlay` with the setting "离开应用时自动小窗" —
  /// both keep this engine, so neither goes through the drivers this
  /// controller toggles.
  bool get pipAvailable {
    final platform = ref.read(pipDriverProvider).platform;
    return platform == PipPlatform.desktop || (platform == PipPlatform.mobile && isSystemPipHost);
  }

  /// Whether the picture-in-picture picture lives in a window this app lays
  /// out — the desktop compact window. A phone's window is the system's, so
  /// the page behind it keeps the layout it had.
  bool get pipOwnsWindow => ref.read(pipDriverProvider).platform == PipPlatform.desktop;

  /// Whether [mode] takes the app's window instead of leaving the page its
  /// own layout. Every mode does, except the phone's system window.
  bool modeOwnsWindow(PresentationMode mode) =>
      mode != PresentationMode.normal && (mode != PresentationMode.pip || pipOwnsWindow);

  /// Leaves whatever mode is active, back to the page's own layout.
  Future<void> exit(PlayerId player) => _exitMode(player);

  /// The F key and the fullscreen button: enter the system fullscreen, or
  /// leave whichever variant is active.
  Future<void> toggleFullscreen(PlayerId player) async {
    if (state != PresentationMode.normal) {
      await _exitMode(player);
    } else {
      await _apply(player, PresentationMode.fullscreen);
    }
  }

  /// The desktop variant: the picture fills the app window while the window
  /// stays a window.
  Future<void> toggleWindowFullscreen(PlayerId player) async {
    if (state != PresentationMode.normal) {
      await _exitMode(player);
    } else {
      await _apply(player, PresentationMode.windowFullscreen);
    }
  }

  /// Enters or leaves picture-in-picture.
  ///
  /// Answers whether the mode is now what the caller asked for: iOS can
  /// refuse the system window (no on-screen player layer to lift, a device
  /// that cannot present it), and a page that offered the button has to say
  /// so instead of leaving a control that does nothing.
  Future<bool> togglePip(PlayerId player) {
    if (!pipAvailable) return Future<bool>.value(false);
    if (state == PresentationMode.pip) return _exitMode(player);
    return _apply(player, PresentationMode.pip);
  }

  /// Leaves the active mode. A phone's picture-in-picture window is the
  /// system's own: the app closes it through the system and the driver's
  /// state catches up from the status the system reports a moment later, so
  /// the answer here is "the request was accepted", not "the state already
  /// changed".
  Future<bool> _exitMode(PlayerId player) async {
    if (isSystemPipHost && state == PresentationMode.pip) {
      await exitSystemPip();
      return true;
    }
    return await _apply(player, PresentationMode.normal);
  }

  Future<bool> _apply(PlayerId player, PresentationMode mode) async {
    // Optimistic first: the page lays its immersive bare-player surface out
    // before the native window changes size, so the transition never paints
    // the inline layout squeezed into the new bounds. `_sync` corrects the
    // state when a host refuses the mode.
    if (state != mode) state = mode;
    try {
      await ref.read(presentationDriverProvider).apply(player, PresentationRequest(mode: mode));
    } on Object {
      // A host without the capability (web, a desktop without a window
      // backend, a phone whose system window refused) refuses; the layout
      // then simply stays inline.
    }
    _sync();
    return state == mode;
  }
}

/// The room's presentation mode.
final roomPresentationProvider = NotifierProvider<RoomPresentationController, PresentationMode>(
  RoomPresentationController.new,
);

/// Whether the room page is filling its window without a presentation mode.
///
/// The portrait full-screen surface is the page's own layout, not one of
/// media_core's drivers: nothing outside the page can see it, yet the window
/// strip has to give way to it exactly as it does for fullscreen. The page
/// publishes that fact here so the route's chrome can follow.
final class RoomImmersiveController extends Notifier<bool> {
  @override
  bool build() => false;

  /// Publishes whether the page fills the window.
  void set({required bool value}) {
    if (state != value) state = value;
  }
}

/// Whether the room page owns the whole window right now.
final roomImmersiveProvider = NotifierProvider<RoomImmersiveController, bool>(RoomImmersiveController.new);
