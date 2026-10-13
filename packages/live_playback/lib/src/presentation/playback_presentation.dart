import 'dart:async';
import 'dart:ui' show Rect, Size;

import 'package:live_playback/src/config/playback_config.dart';
import 'package:live_playback/src/model/layout_strategy.dart';
import 'package:live_playback/src/presentation/window_geometry.dart';
import 'package:live_playback/src/presentation/window_preference_manager.dart';
import 'package:live_playback/src/presentation/window_sizing_engine.dart';
import 'package:media_core/media_core.dart';
import 'package:rxdart/rxdart.dart';

/// How the picture is presented, and what the device wants it to look like.
///
/// It is a thin business layer over media_core's [PresentationManager]: the
/// manager owns the state machine and the platform drivers own the mechanics,
/// while this class owns the *policy* — which modes the viewer's configuration
/// allows, how the picture should be laid out on this kind of device, and
/// where the small windows open.
///
/// Keeping it thin is the point: a first version of this package re-implemented
/// PiP and floating windows here, which meant two window systems fighting over
/// the same player. There is one now, and it lives in the kernel.
final class PlaybackPresentation {
  /// Creates the presentation layer.
  new({required this.manager, required this.preferences, this.config = PlaybackConfig.defaults}) {
    _modeSub = manager.state.listen((state) {
      if (_lastMode != state.mode) {
        _lastMode = state.mode;
        _modeSubject.add(state.mode);
      }
    });
  }

  /// The kernel-side presentation manager (state machine + drivers).
  final PresentationManager manager;

  /// Window geometry memory.
  final WindowPreferenceManager preferences;

  /// What the viewer has allowed and what device this is.
  final PlaybackConfig config;

  late final StreamSubscription<PresentationState> _modeSub;

  final BehaviorSubject<PresentationMode> _modeSubject = BehaviorSubject<PresentationMode>.seeded(
    PresentationMode.normal,
  );

  PresentationMode _lastMode = PresentationMode.normal;

  /// The current presentation mode.
  PresentationMode get mode => manager.mode;

  /// Stream of *changes* to the presentation mode.
  ValueStream<PresentationMode> get modeChanges => _modeSubject.stream;

  /// Whether a transition is in flight.
  bool get isTransitioning => manager.isTransitioning;

  /// Whether the picture occupies the screen or the window.
  bool get isFullscreen => manager.isAnyFullscreen;

  /// Whether the picture is a system PiP window.
  bool get isPip => manager.isPip;

  /// Whether the picture is the in-app floating window.
  bool get isFloating => manager.isFloating;

  /// The device profile the layout decisions use.
  DeviceProfile get deviceProfile => manager.deviceProfile;

  /// Whether the platform can do system PiP at all.
  bool get supportsPip => manager.snapshot.capabilities.canPip;

  /// Whether the platform can do the in-app floating window.
  bool get supportsFloating => manager.snapshot.capabilities.canFloating;

  /// Whether the viewer's configuration and the platform agree on PiP.
  bool get canEnterPip => config.allowPictureInPicture && supportsPip;

  /// Whether the viewer's configuration and the platform agree on floating.
  bool get canEnterFloating => config.allowFloatingWindow && supportsFloating;

  /// How a video surface should be laid out for [orientation].
  LayoutStrategy layoutStrategyFor(VideoOrientation orientation) {
    return LayoutStrategy.forProfile(deviceProfile, orientation, isOverlay: manager.isPip || manager.isFloating);
  }

  /// Tells the manager the video turned; layout strategy follows from it.
  void updateOrientation(VideoOrientation orientation) => manager.updateOrientation(orientation);

  // --- Transitions ---

  /// Requests [mode], refusing what the configuration disallows.
  ///
  /// Returns whether the request was made. A refused request is not an error:
  /// the button that asked should have been hidden, and a caller reacting to
  /// an OS event (a background push) simply learns nothing happened.
  Future<bool> requestMode(PresentationMode mode) async {
    if (mode == PresentationMode.pip && !canEnterPip) {
      return false;
    }
    if (mode == PresentationMode.floating && !canEnterFloating) {
      return false;
    }
    await manager.setMode(mode);
    return true;
  }

  /// Enters fullscreen (system fullscreen where the platform has it).
  Future<void> enterFullscreen() => manager.enterFullscreen();

  /// Enters window-level fullscreen (fills the app window, keeps it a window).
  Future<void> enterWindowFullscreen() => manager.enterWindowFullscreen();

  /// Leaves any fullscreen variant.
  Future<void> exitFullscreen() => manager.exit();

  /// Enters system PiP, when allowed.
  Future<bool> enterPip() => requestMode(PresentationMode.pip);

  /// Enters the in-app floating window, when allowed.
  Future<bool> enterFloating() => requestMode(PresentationMode.floating);

  /// Returns the picture to the page.
  Future<void> exitOverlay() => manager.exit();

  // --- Window geometry ---

  /// The rect to open a small window with, for the given [surface].
  Future<Rect> resolveWindowRect({
    required String sessionId,
    required WindowSurface surface,
    required Size area,
    required VideoGeometry geometry,
    WindowSizePolicy policy = WindowSizePolicy.primary,
    WindowClearance clearance = const WindowClearance(),
  }) {
    return preferences.resolveRect(
      key: WindowGeometryKey(
        sessionId: sessionId,
        surface: surface,
        orientation: geometry.orientation.effectiveOrientation,
      ),
      area: area,
      geometry: geometry,
      policy: policy,
      clearance: clearance,
    );
  }

  /// Remembers the rect a viewer left a small window at.
  Future<void> rememberWindowRect({
    required String sessionId,
    required WindowSurface surface,
    required VideoOrientation orientation,
    required Rect rect,
  }) {
    return preferences.rememberRect(
      key: WindowGeometryKey(sessionId: sessionId, surface: surface, orientation: orientation),
      rect: rect,
    );
  }

  /// Releases the mode subscription. The manager is owned by the host.
  Future<void> dispose() async {
    await _modeSub.cancel();
    await _modeSubject.close();
  }
}
