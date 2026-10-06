import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pure_live/core/player/kernel/floating_handle_keeper.dart';
import 'package:pure_live/get/get.dart';
import 'package:media_core_floating/media_core_floating.dart';
import 'package:media_core/media_core.dart' show MediaPlayerView, PlayerId, PlayerKernel;

/// Host small-window surface for the kernel's shared [FloatingDriver].
///
/// The driver ships with a null presenter, so a `floating` request was silently
/// dropped; this installs the real surface: a [FloatingWindowOverlay] inserted
/// above the app's overlay that renders whichever player the driver names, by
/// looking its handle up on [kernel]. It stays generic over the player id so the
/// live room's own floating path (which never goes through the driver) is
/// untouched, and any host that calls `kernel.enterFloating(playerId)` — the
/// local video player today — gets a window for that exact handle.
final class KernelFloatingWindowPresenter implements FloatingWindowPresenter {
  KernelFloatingWindowPresenter({required this.kernel, required this.driver});

  final PlayerKernel kernel;
  final FloatingDriver driver;

  OverlayEntry? _entry;

  @override
  bool get isSupported => true;

  @override
  Future<void> show(FloatingWindowRequest request) async {
    if (_entry != null) return;
    final overlayContext = Get.overlayContext;
    if (overlayContext == null) return;
    final playerId = PlayerId(request.playerId);
    final entry = OverlayEntry(
      builder: (context) => FloatingWindowOverlay(
        visible: driver.onFloatingChanged,
        initiallyVisible: driver.isFloating,
        videoWidth: request.videoWidth == 0 ? null : request.videoWidth,
        videoHeight: request.videoHeight == 0 ? null : request.videoHeight,
        // Corner grip resizes; dragging the picture still moves the window. A
        // 160x90 library default is a thumbnail, not a watchable surface.
        placement: const FloatingWindowPlacement(
          config: FloatingPlacementConfig(
            width: 380,
            height: 214,
            minWidth: 200,
            minHeight: 112,
            resizableByDrag: true,
          ),
        ),
        // Leave the window: the driver goes back to normal (which hides this
        // entry) and the keeper releases the handle the page handed over, so a
        // feed that outlived its page is disposed exactly once, here. Expanding
        // asks the host for the full page back instead of only closing.
        onExpand: () async {
          await kernel.exitFloating(playerId);
          await FloatingHandleKeeper.instance.expand(playerId.value);
          await FloatingHandleKeeper.instance.release(playerId.value);
        },
        onClose: () async {
          await kernel.exitFloating(playerId);
          await FloatingHandleKeeper.instance.release(playerId.value);
        },
        child: _KernelFloatingSurface(kernel: kernel, playerId: playerId),
      ),
    );
    final overlay = Overlay.maybeOf(overlayContext, rootOverlay: true) ?? Overlay.of(overlayContext);
    overlay.insert(entry);
    _entry = entry;
  }

  @override
  Future<void> hide() async {
    final entry = _entry;
    _entry = null;
    if (entry != null && entry.mounted) {
      await Future<void>.delayed(Duration.zero);
      entry.remove();
    }
  }
}

/// Renders the video of [playerId] for as long as the kernel still holds it.
///
/// The local feed drives one stable handle and only re-opens its source between
/// items, so [MediaPlayerView] (which follows the handle's own source and
/// backend events) tracks the current video without this widget re-resolving.
/// A disposed handle collapses to black rather than touching a released adapter.
class _KernelFloatingSurface extends StatelessWidget {
  const _KernelFloatingSurface({required this.kernel, required this.playerId});

  final PlayerKernel kernel;
  final PlayerId playerId;

  @override
  Widget build(BuildContext context) {
    final handle = kernel.get(playerId);
    if (handle == null || handle.disposed) return const ColoredBox(color: Colors.black);
    return ColoredBox(
      color: Colors.black,
      child: MediaPlayerView(handle: handle, fit: BoxFit.contain),
    );
  }
}
