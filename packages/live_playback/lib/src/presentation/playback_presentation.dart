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
/// It is a thin business layer over media_core's presentation stack, and the
/// split is deliberate:
///
/// - `PresentationController` owns the state machine,
/// - `PresentationService` runs a request through the platform adapter and
///   settles the state when the platform comes back,
/// - the adapter (the host's, from `media_core_presentation` / `media_core_pip`
///   / `media_core_floating`) owns the mechanics,
/// - and *this* class owns policy: which modes the viewer's configuration and
///   the platform allow, how the picture is laid out on this kind of device,
///   and where the small windows open.
///
/// Keeping it thin is the point: a first version of this package re-implemented
/// PiP and floating windows here, which meant two window systems fighting over
/// the same player. There is one now, and it lives in the kernel.
final class PlaybackPresentation {
  /// Creates the presentation layer.
  new({required this.service, required this.preferences, this.config = PlaybackConfig.defaults}) {
    _modeSub = service.state.map((state) => state.mode).listen((mode) {
      if (_lastMode != mode) {
        _lastMode = mode;
        _modeSubject.add(mode);
      }
    });
  }

  /// The presentation stack: state machine plus the platform adapter behind it.
  final PresentationService service;

  /// Window geometry memory.
  final WindowPreferenceManager preferences;

  /// What the viewer has allowed and what device this is.
  final PlaybackConfig config;

  late final StreamSubscription<PresentationMode> _modeSub;

  final BehaviorSubject<PresentationMode> _modeSubject = BehaviorSubject<PresentationMode>.seeded(
    PresentationMode.normal,
  );

  PresentationMode _lastMode = PresentationMode.normal;

  /// The current presentation mode.
  PresentationMode get mode => service.current.mode;

  /// Stream of *changes* to the presentation mode.
  ValueStream<PresentationMode> get modeChanges => _modeSubject.stream;

  /// Whether a transition is in flight.
  bool get isTransitioning => service.current.transitioning;

  /// Whether the picture occupies the screen or the window.
  bool get isFullscreen => mode.isAnyFullscreen;

  /// Whether the picture is a system PiP window.
  bool get isPip => mode.isPip;

  /// Whether the picture is the in-app floating window.
  bool get isFloating => mode.isFloating;

  /// The device profile the layout decisions use.
  DeviceProfile get deviceProfile => config.deviceProfile;

  /// Whether the platform can do system PiP at all.
  ///
  /// This is the adapter's answer — the host reports what its drivers support —
  /// not a guess: a phone without the PiP permission and a desktop without an
  /// always-on-top window both say no here.
  bool get supportsPip => service.current.capabilities.canPip;

  /// Whether the platform can do the in-app floating window.
  bool get supportsFloating => service.current.capabilities.canFloating;

  /// Whether the viewer's configuration and the platform agree on PiP.
  bool get canEnterPip => config.allowPictureInPicture && supportsPip;

  /// Whether the viewer's configuration and the platform agree on floating.
  bool get canEnterFloating => config.allowFloatingWindow && supportsFloating;

  /// How a video surface should be laid out for [orientation].
  LayoutStrategy layoutStrategyFor(VideoOrientation orientation) {
    return LayoutStrategy.forProfile(deviceProfile, orientation, isOverlay: isPip || isFloating);
  }

  /// Tells the presentation stack the video turned; layout strategy follows.
  void updateOrientation(VideoOrientation orientation) => service.updateOrientation(orientation);

  // --- Transitions ---

  /// Requests [mode], refusing what the configuration disallows.
  ///
  /// Returns whether the request was made. A refused request is not an error:
  /// the button that asked should have been hidden, and a caller reacting to
  /// an OS event (a background push) simply learns nothing happened.
  ///
  /// Awaiting this means the *platform* reported the transition, not merely
  /// that the state machine accepted the intent.
  Future<bool> requestMode(PresentationMode mode) async {
    if (mode == PresentationMode.pip && !canEnterPip) {
      return false;
    }
    if (mode == PresentationMode.floating && !canEnterFloating) {
      return false;
    }

    await service.request(PresentationRequest(mode: mode));
    return true;
  }

  /// Enters fullscreen (system fullscreen where the platform has it).
  Future<void> enterFullscreen() => service.request(PresentationRequest.fullscreen());

  /// Enters window-level fullscreen (fills the app window, keeps it a window).
  Future<void> enterWindowFullscreen() => service.request(PresentationRequest.windowFullscreen());

  /// Leaves any fullscreen variant and any overlay.
  Future<void> exit() => service.request(PresentationRequest.normal());

  /// Enters system PiP, when allowed.
  Future<bool> enterPip() => requestMode(PresentationMode.pip);

  /// Enters the in-app floating window, when allowed.
  Future<bool> enterFloating() => requestMode(PresentationMode.floating);

  /// Returns the picture to the page.
  Future<void> exitOverlay() => exit();

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

  /// Releases the mode subscription. The stack is owned by the host.
  Future<void> dispose() async {
    await _modeSub.cancel();
    await _modeSubject.close();
  }
}
