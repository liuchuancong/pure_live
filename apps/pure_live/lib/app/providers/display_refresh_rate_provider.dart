import 'dart:async' show StreamSubscription, Timer, unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_device/live_device.dart'
    show
        DisplayPlaybackRefreshMode,
        DisplayRefreshRate,
        DisplayRefreshRateCapabilities,
        DisplayRefreshRateException,
        DisplayRefreshRatePreference,
        DisplayRefreshRateService,
        PlatformDisplayRefreshRateService,
        normalizePlaybackFrameRate,
        playbackRefreshRateForDisplay;
import 'package:live_storage/live_storage.dart' show StoragePrefs;

/// How the app asks the display to pace itself.
///
/// The reference offers these three names; the requests they map to are
/// capabilities of the active backend (see [DisplayRefreshRateCapabilities]).
/// Android keeps the reference's adaptive policy: power saving and balanced
/// release the app's high-rate request, balanced raises it only while a
/// pointer or scroll is active, and performance holds it while foregrounded.
/// Elsewhere power saving pins 60 Hz where content matching exists, balanced
/// releases the app's preference, and performance asks for the highest rate.
/// A platform without a request path shows the rates read-only instead of a
/// dead selector.
enum RefreshRateMode {
  /// Release to the system on Android; 60 Hz where exact content matching is
  /// available elsewhere.
  powerSaving,

  /// The system panel policy (adaptive on phones, the panel default on
  /// desktop).
  balanced,

  /// The highest rate the display reports.
  performance;

  /// The persisted name.
  String get storageValue => name;

  /// Parses a stored name; an unknown or missing value falls back to
  /// [RefreshRateMode.powerSaving] as the reference's fresh-install default.
  static RefreshRateMode parse(String? value) {
    for (final mode in values) {
      if (mode.name == value) return mode;
    }
    return RefreshRateMode.powerSaving;
  }
}

/// The display's rate snapshot plus what this backend lets the app ask for.
final class DisplayRefreshRateState {
  /// Creates a state.
  const DisplayRefreshRateState({
    this.snapshot,
    this.capabilities,
    this.mode = RefreshRateMode.powerSaving,
    this.loading = false,
    this.error = '',
    this.lastOutcome,
  });

  /// The current/max/supported rates, or null before the first read.
  final DisplayRefreshRate? snapshot;

  /// The request/query surface of this backend.
  final DisplayRefreshRateCapabilities? capabilities;

  /// The viewer's choice.
  final RefreshRateMode mode;

  /// A read is in flight.
  final bool loading;

  /// The last read/request failure, for the pane; empty when none.
  final String error;

  /// The last request outcome; null before a request.
  final DisplayRefreshRatePreference? lastOutcome;

  /// The modes this backend can actually carry out, in display order.
  ///
  /// On Android power saving and balanced both use the preferred-rate release
  /// path; elsewhere power saving needs exact content matching. Balanced and
  /// performance always need the preferred-rate path. A backend with none
  /// returns an empty list and the pane stays read-only.
  List<RefreshRateMode> get modes => _availableModes(capabilities);

  /// A copy with selected fields replaced.
  DisplayRefreshRateState copyWith({
    DisplayRefreshRate? snapshot,
    DisplayRefreshRateCapabilities? capabilities,
    RefreshRateMode? mode,
    bool? loading,
    String? error,
    DisplayRefreshRatePreference? lastOutcome,
    bool clearLastOutcome = false,
  }) => DisplayRefreshRateState(
    snapshot: snapshot ?? this.snapshot,
    capabilities: capabilities ?? this.capabilities,
    mode: mode ?? this.mode,
    loading: loading ?? this.loading,
    error: error ?? this.error,
    lastOutcome: clearLastOutcome ? null : lastOutcome ?? this.lastOutcome,
  );
}

/// Owns the display-rate setting: reads the snapshot once at start, watches
/// the display while the app runs, applies the stored mode, and writes a new
/// choice through the live_device service.
///
/// All platform work stays in live_device (`DisplayRefreshRateService`); this
/// controller only owns the app policy and its persisted choice.
final class DisplayRefreshRateController extends Notifier<DisplayRefreshRateState> {
  /// The persisted key.
  static const String prefsKey = 'display.refreshRateMode';

  /// The reference keeps one interaction burst on a stable mode because an
  /// Android mode transition can itself drop a frame.
  static const Duration interactionSettleDelay = Duration(milliseconds: 1500);

  static const DisplayRefreshRateService _service = PlatformDisplayRefreshRateService();

  StreamSubscription<DisplayRefreshRate>? _watch;
  bool _started = false;

  Timer? _settleTimer;
  int _activePointers = 0;
  bool _foreground = true;

  /// The last high/low request the backend accepted; null forces a fresh
  /// request (selection, capability refresh).
  bool? _highApplied;

  /// The latest target while a request is in flight; the loop in [_setHigh]
  /// always converges on this value.
  bool _highTarget = false;
  bool _applyingHigh = false;

  /// The live room's declared video rate while it plays; null when nothing
  /// should be matched. The room coordinator writes it from the playing
  /// line's geometry, so no rate is invented when a platform declares none.
  double? _playbackFrameRate;

  /// The rate last declared to the display while a video played; null when
  /// the last request was a release.
  double? _playbackAppliedHz;
  bool _playbackReleased = false;

  @override
  DisplayRefreshRateState build() {
    ref.onDispose(() {
      _settleTimer?.cancel();
      _settleTimer = null;
      unawaited(_watch?.cancel());
      _watch = null;
    });
    return DisplayRefreshRateState(mode: _readStoredMode());
  }

  static RefreshRateMode _readStoredMode() {
    try {
      return RefreshRateMode.parse(StoragePrefs.getString(prefsKey));
    } on Object {
      return RefreshRateMode.powerSaving;
    }
  }

  /// Reads capabilities and rates and applies the stored mode. Called once
  /// per process after the first frame; watching the provider later does not
  /// repeat the native requests.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    await refresh();
  }

  /// Re-reads the display; the settings refresh button uses this.
  Future<void> refresh({bool applyMode = true}) async {
    state = state.copyWith(loading: true, error: '');
    try {
      final capabilities = await _service.getCapabilities();
      final snapshot = capabilities.canQuery ? await _service.read() : null;
      if (!ref.mounted) return;
      final previousMode = state.mode;
      final mode = _normalizeMode(previousMode, capabilities);
      state = state.copyWith(capabilities: capabilities, snapshot: snapshot, mode: mode, loading: false, error: '');
      if (mode != previousMode) unawaited(StoragePrefs.setString(prefsKey, mode.storageValue));
      _listen(capabilities);
      if (applyMode) await _apply(mode);
    } on DisplayRefreshRateException catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(loading: false, error: error.message);
    } on Object catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(loading: false, error: '$error');
    }
  }

  /// Stores [mode] and asks the display backend for it.
  Future<void> select(RefreshRateMode mode) async {
    if (!state.modes.contains(mode)) return;
    state = state.copyWith(mode: mode, error: '');
    unawaited(StoragePrefs.setString(prefsKey, mode.storageValue));
    await _apply(mode);
  }

  /// Declares the rate of the video the live room plays, or null when
  /// nothing should be matched (paused, background, audio only, the setting
  /// off or the room left).
  ///
  /// Only a backend that can match content carries this; elsewhere the
  /// stored rate is inert and the selected mode keeps its normal policy.
  Future<void> setPlaybackFrameRate(double? frameRate) async {
    final next = frameRate != null && frameRate.isFinite && frameRate > 0
        ? normalizePlaybackFrameRate(frameRate)
        : null;
    if (next == _playbackFrameRate) return;
    _playbackFrameRate = next;
    _playbackAppliedHz = null;
    _playbackReleased = false;
    _highApplied = null;
    final caps = state.capabilities;
    if (caps != null && _usesAdaptivePolicy(caps)) await _setHigh(_highTarget);
  }

  Future<void> _apply(RefreshRateMode mode) async {
    final caps = state.capabilities;
    if (caps == null) return;
    DisplayRefreshRatePreference outcome;
    if (_usesAdaptivePolicy(caps)) {
      // Android follows the reference's coordinator: balanced and power
      // saving start released; interaction (or foreground performance) raises
      // the request through [_setHigh]. Selecting a mode ends any burst so a
      // stale pointer cannot keep the previous policy alive.
      _settleTimer?.cancel();
      _activePointers = 0;
      _highApplied = null;
      _playbackAppliedHz = null;
      _playbackReleased = false;
      outcome = await _setHigh(mode == RefreshRateMode.performance && _foreground);
    } else {
      try {
        outcome = switch (mode) {
          RefreshRateMode.powerSaving when caps.canMatchContent => await _service.matchContent(hz: 60),
          RefreshRateMode.balanced when caps.canRequestPreferredRates => await _service.preferDefault(),
          RefreshRateMode.performance when caps.canRequestPreferredRates => await _service.preferMaximum(),
          _ => DisplayRefreshRatePreference.unsupported,
        };
      } on DisplayRefreshRateException {
        outcome = DisplayRefreshRatePreference.failed;
      } on Object {
        outcome = DisplayRefreshRatePreference.failed;
      }
    }
    if (!ref.mounted) return;
    state = state.copyWith(lastOutcome: outcome);
    if (outcome == DisplayRefreshRatePreference.submitted) {
      // The platform may apply the mode a moment later; one more read makes
      // the pane's "current" line honest without polling.
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!ref.mounted) return;
      try {
        final snapshot = await _service.read();
        if (!ref.mounted) return;
        state = state.copyWith(snapshot: snapshot);
      } on Object {
        // The request was accepted; a failed follow-up read leaves the
        // existing snapshot in place.
      }
    }
  }

  /// Whether the selected mode is currently raising the rate for an active
  /// pointer/scroll burst. The interaction scope uses this to skip work.
  bool get handlesInteraction => _usesAdaptivePolicy(state.capabilities) && state.mode == RefreshRateMode.balanced;

  /// A pointer went down over the app.
  void beginInteraction() {
    if (!handlesInteraction || !_foreground) return;
    _activePointers++;
    _settleTimer?.cancel();
    _requestHigh(true);
  }

  /// A pointer moved, or a scroll is progressing.
  void keepInteraction() {
    if (!handlesInteraction || !_foreground) return;
    _requestHigh(true);
    if (_activePointers == 0) _scheduleSettle();
  }

  /// A pointer was released, or a scroll ended.
  void endInteraction() {
    if (_activePointers > 0) _activePointers--;
    if (handlesInteraction && _foreground && _activePointers == 0) _scheduleSettle();
  }

  /// The app came back to the foreground (or into Android PiP, which the
  /// reference treats as visible).
  void noteAppResumed() {
    _foreground = true;
    _activePointers = 0;
    _settleTimer?.cancel();
    _requestPolicyRate();
  }

  /// The app left the foreground; release the high-rate request.
  void noteAppPaused() {
    _foreground = false;
    _activePointers = 0;
    _settleTimer?.cancel();
    if (_usesAdaptivePolicy(state.capabilities)) unawaited(_setHigh(false));
  }

  void _requestPolicyRate() {
    if (!_usesAdaptivePolicy(state.capabilities)) return;
    _requestHigh(false);
  }

  void _requestHigh(bool interacting) {
    if (!_usesAdaptivePolicy(state.capabilities)) return;
    final high =
        _foreground &&
        (state.mode == RefreshRateMode.performance || (state.mode == RefreshRateMode.balanced && interacting));
    unawaited(_setHigh(high));
  }

  void _scheduleSettle() {
    _settleTimer?.cancel();
    _settleTimer = Timer(interactionSettleDelay, () {
      _settleTimer = null;
      if (_foreground && state.mode == RefreshRateMode.balanced) unawaited(_setHigh(false));
    });
  }

  /// Applies the latest high/low or playback target; a target that arrives
  /// mid-flight is not dropped. Only a successfully submitted request is
  /// remembered, so a backend failure is retried by the next interaction.
  Future<DisplayRefreshRatePreference> _setHigh(bool high) async {
    _highTarget = high;
    if (_applyingHigh) return DisplayRefreshRatePreference.submitted;
    _applyingHigh = true;
    var outcome = DisplayRefreshRatePreference.submitted;
    try {
      while (true) {
        final frameRate = _playbackFrameRate;
        if (frameRate != null && _supportsPlaybackRate(state.capabilities)) {
          final target = _playbackTargetHz(frameRate);
          if (target == null) {
            if (_playbackReleased) break;
            outcome = await _submit(_service.preferDefault);
            if (outcome != DisplayRefreshRatePreference.submitted) {
              _playbackReleased = false;
              _playbackAppliedHz = null;
              break;
            }
            _playbackReleased = true;
            _playbackAppliedHz = null;
          } else {
            if (!_playbackReleased && _playbackAppliedHz == target) break;
            outcome = await _submit(() => _service.matchContent(hz: target));
            if (outcome != DisplayRefreshRatePreference.submitted) {
              _playbackReleased = false;
              _playbackAppliedHz = null;
              break;
            }
            _playbackAppliedHz = target;
            _playbackReleased = false;
          }
        } else {
          if (_highApplied == _highTarget) break;
          final target = _highTarget;
          outcome = await _submit(target ? _service.preferMaximum : _service.preferDefault);
          if (outcome != DisplayRefreshRatePreference.submitted) {
            _highApplied = null;
            break;
          }
          _highApplied = target;
        }
      }
    } finally {
      _applyingHigh = false;
    }
    return outcome;
  }

  Future<DisplayRefreshRatePreference> _submit(Future<DisplayRefreshRatePreference> Function() request) async {
    try {
      return await request();
    } on DisplayRefreshRateException {
      return DisplayRefreshRatePreference.failed;
    } on Object {
      return DisplayRefreshRatePreference.failed;
    }
  }

  /// The rate to declare on the surface while [frameRate] plays; null while
  /// the app is backgrounded, where the request is released.
  double? _playbackTargetHz(double frameRate) {
    if (!_foreground) return null;
    return playbackRefreshRateForDisplay(
      frameRate: frameRate,
      mode: switch (state.mode) {
        RefreshRateMode.powerSaving => DisplayPlaybackRefreshMode.powerSaving,
        RefreshRateMode.balanced => DisplayPlaybackRefreshMode.balanced,
        RefreshRateMode.performance => DisplayPlaybackRefreshMode.performance,
      },
      high: _highTarget,
      supportedHz: state.snapshot?.supportedHz ?? const <double>[],
    );
  }

  /// Content matching is the reference's Android surface declaration path;
  /// other backends keep their selected mode untouched.
  static bool _supportsPlaybackRate(DisplayRefreshRateCapabilities? caps) =>
      caps != null && caps.platformName == 'android' && caps.canMatchContent;

  /// Keeps the snapshot live when the display/monitor changes; the stream is
  /// shared by the backend and only opened when it can observe.
  void _listen(DisplayRefreshRateCapabilities capabilities) {
    if (_watch != null || !capabilities.canObserve) return;
    try {
      _watch = _service.watch().listen(
        (snapshot) {
          if (!ref.mounted) return;
          state = state.copyWith(snapshot: snapshot);
        },
        onError: (Object _) {
          // A display change we could not read leaves the last snapshot;
          // the next explicit refresh can recover.
        },
      );
    } on Object {
      // Observation is optional; the read path still works.
    }
  }

  /// A stored mode the backend cannot carry is replaced by the first mode it
  /// can, so the pane never holds a value missing from its own options.
  static RefreshRateMode _normalizeMode(RefreshRateMode mode, DisplayRefreshRateCapabilities caps) {
    final available = _availableModes(caps);
    if (available.contains(mode)) return mode;
    return available.firstOrNull ?? mode;
  }
}

/// The modes a backend can carry. Android's power saving uses the same
/// release path as balanced (the reference leaves rate choice to Android);
/// other platforms use exact content matching where it exists.
List<RefreshRateMode> _availableModes(DisplayRefreshRateCapabilities? caps) {
  if (caps == null) return const [];
  final androidPowerSaving = caps.platformName == 'android' && caps.canRequestPreferredRates;
  return [
    if (androidPowerSaving || caps.canMatchContent) RefreshRateMode.powerSaving,
    if (caps.canRequestPreferredRates) ...const [RefreshRateMode.balanced, RefreshRateMode.performance],
  ];
}

/// Android is the only platform the reference drives adaptively; its
/// interaction coordinator needs the preferred-rate request path.
bool _usesAdaptivePolicy(DisplayRefreshRateCapabilities? caps) =>
    caps != null && caps.platformName == 'android' && caps.canRequestPreferredRates;

/// The display-rate setting.
final displayRefreshRateProvider = NotifierProvider<DisplayRefreshRateController, DisplayRefreshRateState>(
  DisplayRefreshRateController.new,
);

/// Whether a playing live room declares its video frame rate to the display
/// (the reference's `matchVideoFrameRate`, default on).
///
/// The room coordinator feeds the playing line's declared rate to
/// [DisplayRefreshRateController.setPlaybackFrameRate] only while this is on;
/// a platform that declares no frame rate leaves the selected mode alone
/// instead of inventing a rate.
final class MatchVideoFrameRateController extends Notifier<bool> {
  /// The persisted key.
  static const String prefsKey = 'display.matchVideoFrameRate';

  @override
  bool build() {
    try {
      return StoragePrefs.getBool(prefsKey) ?? true;
    } on Object {
      return true;
    }
  }

  /// Stores the choice; a room already playing reads it through its
  /// coordinator and applies or releases the declaration immediately.
  Future<void> setEnabled({required bool value}) async {
    if (state == value) return;
    state = value;
    await StoragePrefs.setBool(prefsKey, value);
  }
}

/// The match-video-frame-rate setting.
final matchVideoFrameRateProvider = NotifierProvider<MatchVideoFrameRateController, bool>(
  MatchVideoFrameRateController.new,
);
