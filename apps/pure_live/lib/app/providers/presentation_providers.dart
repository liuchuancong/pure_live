import 'dart:async' show StreamSubscription, unawaited;

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_core/media_core.dart';
import 'package:media_core_fullscreen/media_core_fullscreen.dart';
import 'package:media_core_pip/media_core_pip.dart';
import 'package:pure_live/app/providers/player_providers.dart' show playerKernelProvider;
import 'package:pure_live/app/providers/window_providers.dart'
    show isPrimaryWindowProvider, presentationWindowHandleProvider;

/// The window a Windows presentation backend drives: null makes it resolve
/// the primary's runner window, a handle (including zero, for a clone whose
/// handle could not be read) pins it. A clone must never fall back to the
/// process lookup, which always finds the primary first.
int? _desktopWindowHandle(Ref ref) {
  if (ref.watch(isPrimaryWindowProvider)) return null;
  return ref.watch(presentationWindowHandleProvider) ?? 0;
}

/// The app's fullscreen driver: media_core's own, over the Windows-native
/// window bridge, one instance for the process. It owns both fullscreen
/// variants — the system one and the app-window one — so the two can hand
/// over to each other inside the driver that knows both.
final Provider<FullscreenDriver> fullscreenDriverProvider = Provider<FullscreenDriver>((ref) {
  final windows = defaultTargetPlatform == TargetPlatform.windows;
  // A clone pins its own top-level window: the backend's process-wide
  // lookup finds the primary, and the clone would take that window
  // fullscreen instead of itself. The primary's handle is null and keeps
  // the lookup. A hidden-caption Windows window needs the direct user32
  // bridge; the window_manager fast path silently skips its style updates.
  // Other desktops take the driver's own platform backend.
  final driver = FullscreenDriver(
    desktopWindow: windows ? Win32FullscreenWindow(windowHandle: _desktopWindowHandle(ref)) : null,
  );
  unawaited(driver.initialize());
  return driver;
});

/// The app's picture-in-picture driver: media_core's own. On a desktop the
/// watched window becomes a compact always-shaped window; on a phone the
/// system's PiP window takes over through media_core_pip's mobile path.
final Provider<PipDriver> pipDriverProvider = Provider<PipDriver>((ref) {
  final windows = defaultTargetPlatform == TargetPlatform.windows;
  final driver = PipDriver(
    // A clone pins its own window for the same reason as fullscreen: the
    // compact window must be this one, never the primary.
    desktopWindow: windows ? Win32PipWindow(windowHandle: _desktopWindowHandle(ref)) : null,
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
  return driver;
});

/// The kernel's one presentation driver: the chain that routes each mode to
/// the feature driver that owns it. Disposing the chain disposes both.
final Provider<PresentationDriverChain> presentationDriverProvider = Provider<PresentationDriverChain>((ref) {
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
});

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
