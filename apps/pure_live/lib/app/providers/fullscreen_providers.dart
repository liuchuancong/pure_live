import 'dart:async' show StreamSubscription, unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_core_fullscreen/media_core_fullscreen.dart';

/// The app's fullscreen driver: media_core's own, over the Windows-native
/// window bridge, one instance for the process. The room page toggles it;
/// ESC anywhere may leave through it.
final fullscreenDriverProvider = Provider<FullscreenDriver>((ref) {
  final driver = FullscreenDriver(desktopWindow: Win32FullscreenWindow());
  unawaited(driver.initialize());
  ref.onDispose(() => unawaited(driver.dispose()));
  return driver;
});

/// Whether any fullscreen variant is active, mirrored from the driver's
/// own stream so the button and the layout follow the truth (an ESC press
/// leaves through the driver without this page's hand).
final class FullscreenStateController extends Notifier<bool> {
  StreamSubscription<bool>? _changes;

  @override
  bool build() {
    final driver = ref.read(fullscreenDriverProvider);
    _changes ??= driver.onFullscreenChanged.listen((active) {
      if (ref.mounted) state = driver.isAnyFullscreen;
    });
    ref.onDispose(() => unawaited(_changes?.cancel() ?? Future<void>.value()));
    return driver.isAnyFullscreen;
  }

  /// Enters system fullscreen when none is active, leaves otherwise.
  Future<void> toggle() => ref.read(fullscreenDriverProvider).toggleFullscreen();

  /// Leaves whatever fullscreen variant is active (the ESC path).
  Future<void> exit() => ref.read(fullscreenDriverProvider).exitFullscreen();
}

/// Whether any fullscreen variant is active.
final fullscreenStateProvider = NotifierProvider<FullscreenStateController, bool>(
  FullscreenStateController.new,
);
