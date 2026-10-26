import 'dart:async' show StreamSubscription, unawaited;

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/widgets.dart' show Size;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_core/media_core.dart';
import 'package:media_core_fullscreen/media_core_fullscreen.dart';
import 'package:media_core_pip/media_core_pip.dart';
import 'package:pure_live/app/providers/player/player_providers.dart' show playerKernelProvider;
import 'package:pure_live/app/providers/window/multi_view_window_adapters.dart'
    show MultiViewFullscreenWindow, MultiViewPipWindow;
import 'package:pure_live/app/providers/window/pip_geometry.dart' show readPipSavedBounds, writePipSavedBounds;
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
    alwaysOnTop: () => ref.read(playbackSettingsProvider).windowsPipAlwaysOnTop,
    smallWindowSize: (aspectRatio) => windowsPipWindowSizeFor(ref.read(playbackSettingsProvider), aspectRatio),
    minWidth: () => ref.read(playbackSettingsProvider).windowsPipMinWidth,
    minHeight: () => ref.read(playbackSettingsProvider).windowsPipMinHeight,
    readSavedBounds: () {
      if (!ref.read(playbackSettingsProvider).rememberPipPosition) return null;
      return readPipSavedBounds(portrait: _pipShowsPortrait(ref));
    },
    writeSavedBounds: (size, position, displayId) =>
        writePipSavedBounds(portrait: _pipShowsPortrait(ref), size: size, position: position, displayId: displayId),
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

/// The app's picture-in-picture driver: media_core's own. On a desktop the
/// watched window becomes a compact always-shaped window; on a phone the
/// system's PiP window takes over through media_core_pip's mobile path.
final Provider<PipDriver> pipDriverProvider = Provider<PipDriver>(createPipDriver);

/// Builds one window's picture-in-picture driver.
PipDriver createPipDriver(Ref ref) {
  final driver = PipDriver(
    config: windowsPipConfigFor(ref.read(playbackSettingsProvider)),
    desktopWindow: ref.watch(windowsPipWindowProvider),
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

  /// Whether a small window can be opened on this host.
  bool get pipAvailable => ref.read(pipDriverProvider).platform != PipPlatform.unsupported;

  /// Leaves whatever mode is active, back to the page's own layout.
  Future<void> exit(PlayerId player) => _apply(player, PresentationMode.normal);

  /// The F key and the fullscreen button: enter the system fullscreen, or
  /// leave whichever variant is active.
  Future<void> toggleFullscreen(PlayerId player) async {
    if (state != PresentationMode.normal) {
      await exit(player);
    } else {
      await _apply(player, PresentationMode.fullscreen);
    }
  }

  /// The desktop variant: the picture fills the app window while the window
  /// stays a window.
  Future<void> toggleWindowFullscreen(PlayerId player) async {
    if (state != PresentationMode.normal) {
      await exit(player);
    } else {
      await _apply(player, PresentationMode.windowFullscreen);
    }
  }

  /// Enters or leaves picture-in-picture.
  Future<void> togglePip(PlayerId player) async {
    if (!pipAvailable) return;
    if (state == PresentationMode.pip) {
      await exit(player);
    } else {
      await _apply(player, PresentationMode.pip);
    }
  }

  Future<void> _apply(PlayerId player, PresentationMode mode) async {
    try {
      await ref.read(presentationDriverProvider).apply(player, PresentationRequest(mode: mode));
    } on Object {
      // A host without the capability (web, a desktop without a window
      // backend) refuses; the layout then simply stays inline.
    }
    _sync();
  }
}

/// The room's presentation mode.
final roomPresentationProvider = NotifierProvider<RoomPresentationController, PresentationMode>(
  RoomPresentationController.new,
);
