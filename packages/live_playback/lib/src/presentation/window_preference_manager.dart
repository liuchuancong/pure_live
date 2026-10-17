import 'dart:ui';

import 'package:live_playback/src/config/window_preference_store.dart';
import 'package:live_playback/src/presentation/window_geometry.dart';
import 'package:live_playback/src/presentation/window_sizing_engine.dart';
import 'package:media_core/media_core.dart';

/// Answers "how big was this window last time" and remembers the answer.
///
/// The manager is the one place that ties the three parts of window geometry
/// together: the store (what the viewer chose), the engine (what fits) and the
/// video's shape (what the picture wants). A surface — the in-app small
/// window, the desktop PiP window — asks for a rect before showing, and
/// reports the settled rect back when the viewer lets go.
final class WindowPreferenceManager {
  /// Creates the manager.
  new({required this.store, this.sizingEngine = const WindowSizingEngine()});

  /// Where remembered rects live.
  final WindowPreferenceStore store;

  /// The geometry rules.
  final WindowSizingEngine sizingEngine;

  /// The rect to open a window with.
  ///
  /// A remembered rect wins, clamped into the *current* surface so a layout
  /// captured on a wider screen stays usable; otherwise the engine computes
  /// the natural size for the video's shape and parks it in the corner.
  Future<Rect> resolveRect({
    required WindowGeometryKey key,
    required Size area,
    required VideoGeometry geometry,
    WindowSizePolicy policy = WindowSizePolicy.primary,
    WindowClearance clearance = const WindowClearance(),
  }) async {
    final aspectRatio = _aspectRatioOf(geometry);
    final remembered = await store.readRect(sessionId: key.sessionId, slot: key.slot);

    if (remembered != null) {
      return sizingEngine.clampRect(
        rect: remembered,
        area: area,
        aspectRatio: aspectRatio,
        policy: policy,
        clearance: clearance,
      );
    }

    final window = sizingEngine.naturalSize(screen: area, geometry: geometry, policy: policy);
    return sizingEngine.defaultRect(area: area, window: window, policy: policy, clearance: clearance);
  }

  /// Remembers a rect the viewer settled on.
  ///
  /// Called from the surface's "the drag ended" callback, never from a frame
  /// callback: a hundred writes for one drag is a hundred chances to lose the
  /// last one.
  Future<void> rememberRect({required WindowGeometryKey key, required Rect rect}) {
    return store.writeRect(sessionId: key.sessionId, slot: key.slot, rect: rect);
  }

  /// Forgets a session's remembered layouts on every surface and orientation.
  Future<void> forgetSession(String sessionId) => store.clearSession(sessionId);

  /// Forgets every remembered layout.
  Future<void> forgetAll() => store.clearAll();

  double _aspectRatioOf(VideoGeometry geometry) {
    final size = geometry.videoSize;
    if (size.width <= 0 || size.height <= 0) {
      return 16 / 9;
    }
    return size.width / size.height;
  }
}
