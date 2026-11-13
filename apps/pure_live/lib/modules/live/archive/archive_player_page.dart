import 'dart:async' show Future, StreamSubscription, Timer, unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flame_barrage/flame_barrage.dart' show BarrageController, BarrageItem, EmojiAtlas, FlameBarrageWidget;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_device/live_device.dart'
    show PlatformScreenAwakeService, PlatformScreenOrientationService, ScreenAwakeService, ScreenOrientationService;
import 'package:live_net/live_net.dart' show ClientProfile;
import 'package:live_platform/live_platform.dart' show FormFactor;
import 'package:live_sites/live_sites.dart' show LiveMessage, LiveMessageQuery, LiveRetraction, SiteIds;
import 'package:live_vod/live_vod.dart' show DouyuVodVideo, SoopArchivePart;
import 'package:media_core/media_core.dart'
    show
        GeometryState,
        MediaPlayerView,
        PlayerConfig,
        PlayerHandle,
        PlayerHandleLifecycle,
        PlayerHandlePlayback,
        PlayerId,
        PlayerKernel,
        PlayerTransportState,
        PresentationMode;
import 'package:media_core_danmaku/media_core_danmaku.dart' show DanmakuPlayerBinding;

import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/account/account.dart' show accountsProvider;
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/archive/archive_navigation.dart';
import 'package:pure_live/modules/live/archive/archive_playback.dart';
import 'package:pure_live/modules/live/archive/archive_progress.dart';
import 'package:pure_live/modules/live/archive/douyu_archive_controller.dart';
import 'package:pure_live/modules/live/archive/huya_archive_controller.dart';
import 'package:pure_live/modules/live/archive/soop_archive_controller.dart';
import 'package:pure_live/modules/live/room/panels/room_panel.dart' show showRoomSleepTimer;
import 'package:pure_live/modules/live/room/player/sleep_timer.dart' show SleepTimerController, sleepTimerProvider;
import 'package:pure_live/modules/vod/widgets/vod_picture_gestures.dart' show VodPictureGestures, VodTapSide;
import 'package:pure_live/modules/vod/widgets/vod_player_chrome.dart' show VodGestureKind, VodGestureTip, VodSeekBar;
import 'package:pure_live/modules/vod/widgets/vod_widgets.dart' show vodDurationText;
import 'package:pure_live/shared/shared.dart';

/// A recording's player: the kernel's own handle over the archive
/// controller, the picture with its busy and failure overlays, and the
/// chrome the other players wear — the strip and the overlay bar on the
/// station's auto-hide clock, the presentation modes, the stream's figures,
/// and the parts when the broadcast spans more than one.
final class ArchivePlayerPage extends ConsumerStatefulWidget {
  /// Builds the page for [request]; null renders the failure the walk
  /// without a seed deserves.
  const ArchivePlayerPage({this.request, super.key});

  /// The recording and the invoking room's callbacks.
  final ArchivePlayerRequest? request;

  @override
  ConsumerState<ArchivePlayerPage> createState() => _ArchivePlayerPageState();
}

final class _ArchivePlayerPageState extends ConsumerState<ArchivePlayerPage> with WidgetsBindingObserver {
  PlayerHandle? _handle;
  ArchivePlaybackController? _controller;
  bool _disposed = false;
  bool _startFailed = false;

  /// The flying layer's engine, carried pause and seek by the binding: a
  /// recording's comments follow its own timeline, unlike a live room's.
  final BarrageController _barrage = BarrageController();
  DanmakuPlayerBinding? _danmakuBinding;
  StreamSubscription<LiveMessage>? _messagesSub;
  StreamSubscription<LiveRetraction>? _retractionsSub;

  static final ChangeTracker _idle = ChangeTracker();

  /// The kernel, read once the state exists: the dispose path needs it and
  /// a provider read there throws.
  PlayerKernel? _kernel;

  /// The transport snapshot the bar and the hide clock read; the handle's
  /// stream feeds it, the way the other players' pages keep theirs.
  PlayerTransportState? _transport;
  StreamSubscription<PlayerTransportState>? _transportSub;
  StreamSubscription<GeometryState>? _geometrySub;

  /// The picture's own shape, from the engine's geometry: the fullscreen and
  /// compact-window drivers shape their surfaces from it.
  double _aspectRatio = 16 / 9;

  /// The overlay chrome's idle clock: it reads the station's own
  /// controlsAutoHideSeconds, whose zero is 常显.
  bool _controlsVisible = false;
  Timer? _hideTimer;

  /// The immersive parts catalogue: the chip it hangs from, the bar it
  /// floats above, and whether it stands open.
  final GlobalKey _partsAnchor = GlobalKey();
  final GlobalKey _barAnchor = GlobalKey();
  bool _partsOpen = false;

  /// The page's own mute, the bar button's state; the slider speaks past it.
  bool _muted = false;

  /// What the last gesture did, in the chip over the picture.
  VodGestureKind? _tipKind;
  String _tipValue = '';
  String? _tipNote;
  Timer? _tipTimer;

  /// The volume and position a gesture started from, so it moves from where
  /// the viewer was.
  double _volumeFrom = 1;
  Duration _scrubFrom = Duration.zero;
  double _scrubShare = 0;
  bool _scrubbing = false;

  /// Holds the display awake exactly while the recording plays and the
  /// preference allows it.
  bool _screenHeld = false;
  final ScreenAwakeService _screenAwake = const PlatformScreenAwakeService();
  final ScreenOrientationService _screenOrientation = const PlatformScreenOrientationService();

  /// The background's gate: a paused app pauses the recording, unless the
  /// small window is what carries it.
  BackgroundPlaybackGate? _backgroundGate;
  PlayerId? _backgroundPausedHandleId;

  // Captured while the page is alive; `ref` is refused by the time dispose
  // runs, and the leaving page must still exit its presentation mode.
  late final RoomPresentationController _presentationNotifier;

  /// The sleep timer this page owns while it stands: its fire stops this
  /// recording, and leaving disarms it.
  late final SleepTimerController _sleepTimerNotifier;

  /// The presentation mode, followed through a manual listener for the same
  /// reason: the leaving page reads its own field, not `ref`.
  PresentationMode _presentationMode = PresentationMode.normal;

  bool get _desktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  /// The rate ladder the bar lists; the keyboard walks it step by step.
  static const _speedChoices = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    _presentationNotifier = ref.read(roomPresentationProvider.notifier);
    ref.listenManual(roomPresentationProvider, (_, next) => _presentationMode = next, fireImmediately: true);
    // The sleep timer must stop this recording, not some global notion of one.
    _sleepTimerNotifier = ref.read(sleepTimerProvider.notifier);
    _sleepTimerNotifier.onFire_ = _onSleepFire;
    _kernel = ref.read(playerKernelProvider);
    WidgetsBinding.instance.addObserver(this);
    _backgroundGate = BackgroundPlaybackGate(
      backgroundEnabled: () => ref.read(playbackSettingsProvider).backgroundPlay,
      shouldPause: () {
        final presentation = ref.read(roomPresentationProvider);
        return (_transport?.isPlaying ?? false) &&
            presentation != PresentationMode.pip &&
            presentation != PresentationMode.floating;
      },
      pause: () async {
        _backgroundPausedHandleId = _handle?.id;
        await _handle?.pause();
      },
      canResume: () =>
          _backgroundPausedHandleId != null &&
          _handle != null &&
          _handle?.id == _backgroundPausedHandleId &&
          !(_transport?.isPlaying ?? false),
      resume: () async {
        _backgroundPausedHandleId = null;
        await _handle?.play();
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_start());
    });
  }

  /// Attaches the kernel's handle, builds the recording's own controller
  /// over it, and opens where the viewer last walked.
  Future<void> _start() async {
    final request = widget.request;
    final kernel = _kernel;
    if (request == null || kernel == null || _disposed) return;
    try {
      final handle = await kernel.create(
        config: const PlayerConfig(name: 'archive'),
        preferredBackend: ref.read(playerKernelBackendProvider).id,
      );
      if (_disposed) {
        silencePlayer(handle);
        unawaited(kernel.release(handle.id));
        return;
      }
      _handle = handle;
      final http = ref.read(networkFactoryProvider).create(profile: ClientProfile.api);
      final soop = request.soop;
      final huya = request.huya;
      final douyu = request.douyu;
      if (soop != null) {
        _controller = SoopArchiveController(
          http: http,
          session: handle,
          recording: soop,
          progress: ArchiveProgress(),
          cookie: _soopCookie(),
          ownsSession: false,
        );
      } else if (huya != null) {
        _controller = HuyaArchiveController(http: http, session: handle, video: huya, progress: ArchiveProgress());
      } else if (douyu != null) {
        _controller = DouyuArchiveController(
          http: http,
          session: handle,
          video: douyu,
          progress: ArchiveProgress(),
          cookie: _douyuCookie(),
        );
      }
      if (_controller == null) return;
      _wireDanmaku(_controller!, handle);
      _bind(handle);
      setState(() {});
      final recordingId = request.soop?.id ?? request.huya?.id ?? request.douyu?.id;
      if (recordingId != null) await _controller!.open(recordingId);
    } on Object {
      if (!_disposed) setState(() => _startFailed = true);
    }
  }

  /// Subscribes the handle's streams the other players' pages keep: the
  /// transport the bar and the hide clock read, and the geometry the
  /// fullscreen and small-window drivers shape their surfaces from.
  void _bind(PlayerHandle handle) {
    _transportSub = handle.playbackStream.listen((state) {
      if (!mounted) return;
      setState(() => _transport = state);
      if (state.isPlaying) _scheduleHide();
    });
    _geometrySub = handle.geometryController.state.listen((state) {
      if (!mounted) return;
      final size = state.geometry.videoSize;
      if (size.width <= 0 || size.height <= 0) return;
      _aspectRatio = size.width / size.height;
      ref.read(fullscreenDriverProvider).onVideoSize(size.width, size.height);
      ref.read(pipDriverProvider).onVideoSize(size.width, size.height);
    });
  }

  /// Feeds the flying layer from the recording's own comment timeline: the
  /// controller's messages arrive already gated by the clock, the binding
  /// carries the transport's pause, seek and speed into the engine, and a
  /// retraction empties the frame a seek just left.
  void _wireDanmaku(ArchivePlaybackController controller, PlayerHandle handle) {
    unawaited(_messagesSub?.cancel() ?? Future<void>.value());
    unawaited(_retractionsSub?.cancel() ?? Future<void>.value());
    unawaited(_danmakuBinding?.dispose() ?? Future<void>.value());
    _barrage.clear();
    _danmakuBinding = DanmakuPlayerBinding.forHandle(controller: _barrage, handle: handle)..attach();
    _messagesSub = controller.messages.listen((message) {
      if (_disposed || message.text.isEmpty) return;
      final color = message.effectiveColor;
      _barrage.send(
        BarrageItem(
          content: message.text,
          id: message.messageId.isEmpty ? null : message.messageId,
          textColor: Color.fromARGB(255, color.r, color.g, color.b),
        ),
      );
    });
    _retractionsSub = controller.retractions.listen((_) {
      if (!_disposed) _barrage.retractWhere((_) => true);
    });
  }

  /// The viewer's SOOP login, the same credential the live site uses.
  String _soopCookie() {
    try {
      final credential = ref.read(accountsProvider).credentials[SiteIds.soop];
      if (credential == null) return '';
      return credential.cookies.entries.map((entry) => '${entry.key}=${entry.value}').join('; ');
    } on Object {
      return '';
    }
  }

  /// The viewer's Douyu login, the credential the replay's permission
  /// tiers read.
  String _douyuCookie() {
    try {
      final credential = ref.read(accountsProvider).credentials[SiteIds.douyu];
      if (credential == null) return '';
      return credential.cookies.entries.map((entry) => '${entry.key}=${entry.value}').join('; ');
    } on Object {
      return '';
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _backgroundGate?.handleLifecycle(state);
  }

  @override
  void dispose() {
    _disposed = true;
    _tipTimer?.cancel();
    _hideTimer?.cancel();
    _sleepTimerNotifier.onFire_ = null;
    Timer.run(() => _sleepTimerNotifier.start(null));
    // A page leaving while a mode owns the window takes the mode with it.
    final handle = _handle;
    if (handle != null && _presentationMode != PresentationMode.normal) {
      unawaited(_presentationNotifier.exit(handle.id));
    }
    unawaited(_messagesSub?.cancel() ?? Future<void>.value());
    unawaited(_retractionsSub?.cancel() ?? Future<void>.value());
    unawaited(_danmakuBinding?.dispose() ?? Future<void>.value());
    unawaited(_transportSub?.cancel() ?? Future<void>.value());
    unawaited(_geometrySub?.cancel() ?? Future<void>.value());
    _barrage.dispose();
    final controller = _controller;
    final kernel = _kernel;
    // The walk reports its own retirement: the progress save and the
    // native release together, because the invoking room may only resume
    // once the decoder is really gone.
    var retirement = Future<void>.value();
    if (controller != null) {
      controller.dispose();
      retirement = controller.retirement;
    }
    if (handle != null && kernel != null) {
      silencePlayer(handle);
      retirement = Future.wait<void>([retirement, kernel.release(handle.id)]).then((_) {});
    }
    widget.request?.arguments.onRetire?.call(retirement);
    WidgetsBinding.instance.removeObserver(this);
    _backgroundGate?.dispose();
    _backgroundGate = null;
    super.dispose();
  }

  /// Shows [kind]'s answer over the picture for a moment.
  void _tip(VodGestureKind kind, String value, {String? note}) {
    _tipTimer?.cancel();
    setState(() {
      _tipKind = kind;
      _tipValue = value;
      _tipNote = note;
    });
    _tipTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _tipKind = null);
    });
  }

  /// Shows an answer that lasts until the gesture lets go.
  void _holdTip(VodGestureKind kind, String value, {String? note}) {
    _tipTimer?.cancel();
    setState(() {
      _tipKind = kind;
      _tipValue = value;
      _tipNote = note;
    });
  }

  void _clearTip() {
    _tipTimer?.cancel();
    if (_tipKind != null) setState(() => _tipKind = null);
  }

  Future<void> _toggle() async {
    await _controller?.togglePlayPause();
  }

  Future<void> _step(int seconds) async {
    final controller = _controller;
    if (controller == null) return;
    final target = controller.position + Duration(seconds: seconds);
    await controller.seek(target);
    _tip(
      seconds < 0 ? VodGestureKind.seekBack : VodGestureKind.seekForward,
      vodDurationText(target.isNegative ? Duration.zero : target),
      note: seconds > 0 ? '+$seconds' : '$seconds',
    );
  }

  /// The keyboard's way through the seek: a held arrow keeps stepping, and
  /// each step in a row is bigger.
  void _keySeek(int direction) {
    final count = _keySeekSteps + 1;
    _keySeekSteps = count;
    _keySeekTimer?.cancel();
    _keySeekTimer = Timer(const Duration(milliseconds: 400), () {
      _keySeekSteps = 0;
    });
    unawaited(_step(direction * 5 * count));
  }

  int _keySeekSteps = 0;
  Timer? _keySeekTimer;

  void _onDoubleTap(VodTapSide side) {
    switch (side) {
      case VodTapSide.left:
        unawaited(_step(-10));
      case VodTapSide.right:
        unawaited(_step(10));
      case VodTapSide.middle:
        unawaited(_toggle());
    }
  }

  /// A horizontal drag walks the recording: a full sweep is the whole length.
  void _onScrub(double delta, double width) {
    final controller = _controller;
    if (controller == null || width <= 0) return;
    if (!_scrubbing) {
      _scrubbing = true;
      _scrubFrom = controller.position;
      _scrubShare = 0;
    }
    _scrubShare += delta / width;
    final target = _scrubFrom + controller.duration * _scrubShare;
    _holdTip(
      VodGestureKind.seek,
      vodDurationText(target.isNegative ? Duration.zero : target),
      note: '${(_scrubShare * 100).round()}%',
    );
  }

  void _onScrubEnd(bool committed) {
    final controller = _controller;
    if (_scrubbing && committed && controller != null) {
      final target = _scrubFrom + controller.duration * _scrubShare;
      unawaited(controller.seek(target.isNegative ? Duration.zero : target));
    }
    _scrubbing = false;
    _clearTip();
  }

  /// A vertical drag on the picture owns the sound: a desktop has no display
  /// brightness to write on this half.
  void _onAdjustStart(double share) {
    _volumeFrom = _handle?.playbackStream.value.volume ?? 1;
  }

  void _onAdjust(double delta) {
    final handle = _handle;
    if (handle == null) return;
    final next = (_volumeFrom - delta / 240).clamp(0.0, 1.0);
    _volumeFrom = next;
    unawaited(handle.setVolume(next));
    _holdTip(VodGestureKind.volume, '${(next * 100).round()}%');
  }

  void _onWheel(double delta) {
    final handle = _handle;
    if (handle == null) return;
    final next = (handle.playbackStream.value.volume - delta.sign * 0.05).clamp(0.0, 1.0);
    unawaited(handle.setVolume(next));
    _tip(VodGestureKind.volume, '${(next * 100).round()}%');
  }

  /// A hold runs the picture faster until the finger lifts.
  void _onHold(bool down) {
    final handle = _handle;
    final controller = _controller;
    if (handle == null || controller == null) return;
    if (down) {
      unawaited(handle.setRate(3));
      _holdTip(VodGestureKind.speed, '3.0x');
    } else {
      unawaited(handle.setRate(controller.rate));
      _clearTip();
    }
  }

  /// One step along the bar's rate ladder, the keyboard's way through it.
  Future<void> _stepSpeed(int direction) async {
    final controller = _controller;
    if (controller == null) return;
    const choices = _speedChoices;
    var nearest = 0;
    for (var i = 1; i < choices.length; i++) {
      if ((choices[i] - controller.rate).abs() < (choices[nearest] - controller.rate).abs()) nearest = i;
    }
    final next = (nearest + (direction > 0 ? 1 : -1)).clamp(0, choices.length - 1);
    if (choices[next] == controller.rate) return;
    final rate = choices[next];
    _tip(VodGestureKind.speed, '${rate}x');
    await controller.setRate(rate);
  }

  /// The overlay chrome's clock: a pointer awake or a paused recording holds
  /// it, an idle one settles it after the station's own seconds, whose zero
  /// is 常显.
  void _wake() {
    _hideTimer?.cancel();
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _scheduleHide();
  }

  void _toggleControls() {
    if (_controlsVisible) {
      _hideTimer?.cancel();
      setState(() => _controlsVisible = false);
    } else {
      _wake();
    }
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (_partsOpen || !(_transport?.isPlaying ?? false)) return;
    final seconds = ref.read(playbackSettingsProvider).controlsAutoHideSeconds;
    // The setting's zero is 常显: the chrome never hides on idle while the
    // recording plays.
    if (seconds <= 0) return;
    _hideTimer = Timer(Duration(seconds: seconds), () {
      if (mounted && (_transport?.isPlaying ?? false)) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  /// Holds the display awake exactly while the recording plays and the
  /// preference allows it.
  void _syncScreenWake(bool hold) {
    if (hold == _screenHeld) return;
    _screenHeld = hold;
    unawaited((hold ? _screenAwake.enable() : _screenAwake.disable()).catchError((Object _) {}));
  }

  /// The sleep timer's end: the recording pauses where it stands, said with
  /// the room's own toast.
  void _onSleepFire() {
    unawaited(_handle?.pause() ?? Future<void>.value());
    if (mounted) showDsToast(context: context, title: context.t.room.sleepDone);
  }

  /// Keeps the frame the recording is showing in the viewer's screenshot
  /// folder, and says how it went — a capture that fails silently reads as a
  /// dead button.
  Future<void> _screenshot() async {
    final handle = _handle;
    if (handle == null) return;
    final file = await capturePlayerFrame(handle, ref.read(appPathsProvider).screenshots, prefix: 'pure_live_archive');
    if (!mounted) return;
    final t = context.t;
    showDsToast(
      context: context,
      title: file == null ? t.room.screenshotFailed : t.room.screenshotSaved(name: file.uri.pathSegments.last),
      status: file == null ? DsStatus.danger : DsStatus.success,
    );
  }

  Future<void> _toggleFullscreen() async {
    final handle = _handle;
    if (handle == null) return;
    await ref.read(roomPresentationProvider.notifier).toggleFullscreen(handle.id);
  }

  Future<void> _toggleWindowFullscreen() async {
    final handle = _handle;
    if (handle == null) return;
    await ref.read(roomPresentationProvider.notifier).toggleWindowFullscreen(handle.id);
  }

  Future<void> _togglePip() async {
    final handle = _handle;
    if (handle == null) return;
    final accepted = await ref.read(roomPresentationProvider.notifier).togglePip(handle.id);
    if (accepted || !mounted) return;
    showDsToast(context: context, title: context.t.common.pipUnavailable);
  }

  void _leave() {
    final handle = _handle;
    // A phone's picture-in-picture window floats over the page; leaving the
    // page is the way out of it (the system owns its own close).
    if (handle != null &&
        ref.read(roomPresentationProvider.notifier).modeOwnsWindow(ref.read(roomPresentationProvider))) {
      unawaited(ref.read(roomPresentationProvider.notifier).exit(handle.id));
      return;
    }
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  /// The page's own mute; the slider un-mutes by speaking.
  Future<void> _toggleMute() async {
    final handle = _handle;
    if (handle == null) return;
    final next = !_muted;
    setState(() => _muted = next);
    await handle.setMute(muted: next);
  }

  Future<void> _setVolume(double value) async {
    final handle = _handle;
    if (handle == null) return;
    if (_muted) setState(() => _muted = false);
    await handle.setVolume(value);
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final t = context.t;
    if (request == null) {
      return PageSurface(
        child: Scaffold(
          body: Center(
            child: DsAlert(status: DsStatus.danger, title: Text(t.room.replayFailed)),
          ),
        ),
      );
    }
    final name = request.title;
    // The fullscreen's orientation policy: the first time the room goes
    // system-fullscreen, the device turns with the picture's own shape.
    ref.listen<PresentationMode>(roomPresentationProvider, (previous, next) {
      if (next != PresentationMode.fullscreen || previous == PresentationMode.fullscreen) return;
      applyFullscreenOrientation(_screenOrientation, aspectRatio: _aspectRatio);
    });
    final presentation = ref.watch(roomPresentationProvider);
    final presentationController = ref.read(roomPresentationProvider.notifier);
    final colors = DsTheme.colorsOf(context);
    // Only a mode that owns the app's window replaces this page's layout; a
    // phone's picture-in-picture window floats over it.
    final immersive = presentationController.modeOwnsWindow(presentation);
    // A TV sits far from the screen: the bar's controls grow, its buttons
    // draw the focus ring a remote needs, and the space key reaches the
    // transport without the pointer the page otherwise assumes.
    final tv = ref.watch(platformRuntimeProvider).environment.runtime.formFactor == FormFactor.tv;
    if (immersive) {
      // The owned window keeps the keyboard its page had: Escape backs out of
      // the mode it sits in (the small window back to the page, fullscreen
      // back to the layout), I raises the stream's figures.
      return Scaffold(
        backgroundColor: colors.canvas,
        body: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): _leave,
            if (!tv)
              const SingleActivator(LogicalKeyboardKey.keyI): () =>
                  ref.read(playerStatsVisibleProvider.notifier).toggle(),
          },
          child: Focus(autofocus: true, child: _surface(context, name, immersive: true)),
        ),
      );
    }
    final volumeStep = ref.watch(playbackSettingsProvider.select((settings) => settings.volumeWheelStepPercent)) / 100;
    void nudgeVolume(double delta) {
      final handle = _handle;
      if (handle == null) return;
      _wake();
      final next = (handle.volume + delta).clamp(0.0, 1.0);
      _tip(VodGestureKind.volume, '${(next * 100).round()}%');
      unawaited(_setVolume(next));
    }

    return PageSurface(
      child: PlayerBarTier(
        tv: tv,
        child: CallbackShortcuts(
          bindings: {
            // A remote cannot tap the picture to raise the chrome, so its
            // transport keys wake the chrome they drive.
            const SingleActivator(LogicalKeyboardKey.space): () {
              _wake();
              unawaited(_toggle());
            },
            const SingleActivator(LogicalKeyboardKey.keyF): () {
              _wake();
              unawaited(_toggleFullscreen());
            },
            // The stream's own figures: the key every player answers to.
            if (!tv)
              const SingleActivator(LogicalKeyboardKey.keyI): () =>
                  ref.read(playerStatsVisibleProvider.notifier).toggle(),
            const SingleActivator(LogicalKeyboardKey.escape): _leave,
            // While the bar is down a TV's arrows and OK have nothing to move
            // through, so they raise it; while it is up they stay with focus.
            if (tv && !_controlsVisible) ...{
              const SingleActivator(LogicalKeyboardKey.arrowUp): _wake,
              const SingleActivator(LogicalKeyboardKey.arrowDown): _wake,
              const SingleActivator(LogicalKeyboardKey.arrowLeft): _wake,
              const SingleActivator(LogicalKeyboardKey.arrowRight): _wake,
              const SingleActivator(LogicalKeyboardKey.select): _wake,
            },
            if (!tv) const SingleActivator(LogicalKeyboardKey.arrowUp): () => nudgeVolume(volumeStep),
            if (!tv) const SingleActivator(LogicalKeyboardKey.arrowDown): () => nudgeVolume(-volumeStep),
            // A held arrow keeps stepping, and each step in a row is bigger.
            if (!tv)
              const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
                _wake();
                _keySeek(-1);
              },
            if (!tv)
              const SingleActivator(LogicalKeyboardKey.arrowRight): () {
                _wake();
                _keySeek(1);
              },
            if (!tv)
              const SingleActivator(LogicalKeyboardKey.comma): () {
                _wake();
                unawaited(_stepSpeed(-1));
              },
            if (!tv)
              const SingleActivator(LogicalKeyboardKey.period): () {
                _wake();
                unawaited(_stepSpeed(1));
              },
            if (!tv)
              const SingleActivator(LogicalKeyboardKey.keyM): () {
                _wake();
                unawaited(_toggleMute());
              },
          },
          child: Scaffold(
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _surface(context, name, immersive: false)),
                if (_controller case final controller?) ...[
                  if (controller.segments.length > 1) _parts(context, controller),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The picture and its chrome: the recording the handle carries, its own
  /// comments flying on the binding's clock, the stream's figures, and the
  /// strip and bar that ride it on the auto-hide clock. In the owned modes
  /// the chrome answers the mode — the leading pill is the way out, and the
  /// small window's title drags.
  Widget _surface(BuildContext context, String name, {required bool immersive}) {
    final controller = _controller;
    final handle = _handle;
    final danmakuStyle = ref.watch(danmakuStyleProvider);
    final danmakuFps = ref.watch(danmakuEffectiveFpsProvider);
    final playing = _transport?.isPlaying ?? false;
    _syncScreenWake(playing && ref.watch(keepScreenOnProvider));
    final showBar = _controlsVisible || !playing;
    return MouseRegion(
      onHover: (_) => _wake(),
      onExit: (_) => _scheduleHide(),
      child: ListenableBuilder(
        listenable: controller ?? _idle,
        builder: (context, _) {
          final failed = controller == null || _startFailed || controller.error != null;
          return Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Color(0xFF000000)),
              if (handle != null) MediaPlayerView(handle: handle),
              // The recording's own comments, on a clock the binding keeps
              // equal to the picture's; hidden while the layer is switched
              // off or the recording carries none.
              if (handle != null && controller?.supportsDanmaku == true && controller!.danmakuVisible)
                Positioned.fill(
                  child: IgnorePointer(
                    child: FlameBarrageWidget(
                      config: playerBarrageConfig(
                        danmakuStyle,
                        danmakuFps,
                        family: resolvedFontFamily(danmakuStyle.fontFamily),
                      ),
                      emojiAtlas: EmojiAtlas.instance,
                      controller: _barrage,
                    ),
                  ),
                ),
              // The stream's own numbers, on the same session switch the
              // room and the other players use.
              if (handle case final player? when ref.watch(playerStatsVisibleProvider))
                Positioned.fill(
                  child: IgnorePointer(child: PlayerStatsOverlay(handle: player)),
                ),
              if (_tipKind case final kind?) VodGestureTip(kind: kind, value: _tipValue, note: _tipNote),
              // The picture's own vocabulary, measured against this surface
              // and answered by the methods below.
              if (controller != null)
                Positioned.fill(
                  child: VodPictureGestures(
                    enabled: handle != null,
                    onTap: _toggleControls,
                    onDoubleTap: _onDoubleTap,
                    onScrub: _onScrub,
                    onScrubEnd: _onScrubEnd,
                    onAdjustStart: _onAdjustStart,
                    onAdjust: _onAdjust,
                    onWheel: _onWheel,
                    onHold: _onHold,
                    child: const SizedBox.expand(),
                  ),
                ),
              if (controller != null && controller.busy)
                const Center(child: DsSpinner())
              else if (failed)
                Center(
                  child: DsAlert(
                    status: DsStatus.danger,
                    title: Text(context.t.room.replayFailed),
                    description: controller?.error == null ? null : Text('${controller?.error}'),
                    action: DsButton(
                      variant: DsButtonVariant.secondary,
                      size: DsSize.sm,
                      onPressed: () {
                        final seed = widget.request;
                        final id = seed?.soop?.id ?? seed?.huya?.id ?? seed?.douyu?.id;
                        if (id != null) unawaited(controller?.open(id));
                      },
                      child: Text(context.t.common.retry),
                    ),
                  ),
                ),
              if (showBar)
                PositionedDirectional(top: 0, start: 0, end: 0, child: _strip(context, name, immersive: immersive)),
              if (showBar)
                PositionedDirectional(
                  bottom: 0,
                  start: 0,
                  end: 0,
                  // Resting on the bar keeps it; leaving it settles the bar
                  // the way an idle pointer does.
                  child: MouseRegion(
                    onEnter: (_) => _hideTimer?.cancel(),
                    onExit: (_) => _scheduleHide(),
                    child: _bar(context, immersive: immersive),
                  ),
                ),
              // The immersive parts catalogue floats over the bar, centred
              // on its chip — the players' one popup language.
              if (showBar && _partsOpen && controller != null)
                Positioned.fill(
                  child: PlayerPanelHost(
                    anchorKey: _partsAnchor,
                    barKey: _barAnchor,
                    width: 220,
                    child: MouseRegion(
                      onEnter: (_) => _hideTimer?.cancel(),
                      onExit: (_) => _scheduleHide(),
                      child: PlayerOverlayPanel(title: context.t.room.replayParts, children: _partOptions(controller)),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// The strip over the picture: the way back and the name always, the frame
  /// verbs and the small window once a player exists to act on. [immersive]
  /// swaps the back pill for the mode's way out and lets the small window's
  /// title drag the window.
  Widget _strip(BuildContext context, String name, {required bool immersive}) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final presentation = ref.watch(roomPresentationProvider);
    final pipAvailable = _handle != null && ref.read(roomPresentationProvider.notifier).pipAvailable;
    final actions = <Widget>[
      if (_handle?.canCaptureScreenshot ?? false)
        PlayerBarButton(
          icon: DsIcons.camera,
          label: t.room.screenshot,
          onPressed: () {
            _wake();
            unawaited(_screenshot());
          },
        ),
      // In the small window the leading pill is the way back, so the pill
      // here would be the same verb twice.
      if (pipAvailable && presentation != PresentationMode.pip)
        PlayerBarButton(
          iconAsset: 'assets/icons/pip.svg',
          label: t.vod.pip,
          onPressed: () {
            _wake();
            unawaited(_togglePip());
          },
        ),
    ];
    final actionPill = actions.isEmpty
        ? const SizedBox.shrink()
        : PlayerGlassPill(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: PlayerBarTier.tvOf(context) ? DsSpace.s8 : DsSpace.s4,
              children: actions,
            ),
          );
    final morePill = PlayerGlassPill(
      child: DsMenuAnchor(
        semanticLabel: t.common.more,
        align: DsAlign.end,
        items: [
          // A long recording ends itself: the timer's panel reads the same
          // choices the room's reads, and its fire pauses the walk where it
          // stands.
          DsMenuItem(
            leading: const DsIcon(DsIcons.timer),
            label: Text(t.room.sleep),
            onPressed: () => unawaited(showRoomSleepTimer(context)),
          ),
        ],
        builder: (context, controller, _) => PlayerBarButton(
          icon: DsIcons.ellipsisVertical,
          label: t.common.more,
          onPressed: () {
            _wake();
            controller.toggle();
          },
        ),
      ),
    );
    final titleText = Flexible(
      child: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.typography.bodyStrong.copyWith(color: OnVideoColors.foreground),
      ),
    );
    if (!immersive) {
      final backPill = PlayerGlassPill(
        child: PlayerBarButton(
          icon: DsIcons.arrowLeft,
          label: t.common.back,
          onPressed: () {
            _wake();
            if (Navigator.of(context).canPop()) Navigator.of(context).pop();
          },
        ),
      );
      return Container(
        padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s8, DsSpace.s8, DsSpace.s12, DsSpace.s20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: AlignmentDirectional.topCenter,
            end: AlignmentDirectional.bottomCenter,
            colors: [Color(0xB3000000), Color(0x00000000)],
          ),
        ),
        child: Row(spacing: DsSpace.s8, children: [backPill, titleText, const Spacer(), actionPill, morePill]),
      );
    }
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s8, DsSpace.s8, DsSpace.s12, DsSpace.s20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topCenter,
          end: AlignmentDirectional.bottomCenter,
          colors: [Color(0xB3000000), Color(0x00000000)],
        ),
      ),
      child: Row(
        spacing: DsSpace.s8,
        children: [
          // The leading pill answers the mode this strip sits in: out of the
          // small window back to the page, or out of fullscreen.
          PlayerGlassPill(
            child: presentation == PresentationMode.pip
                ? PlayerBarButton(
                    iconAsset: 'assets/icons/pip-exit.svg',
                    label: t.room.pipOff,
                    autofocus: true,
                    onPressed: () {
                      _wake();
                      unawaited(_togglePip());
                    },
                  )
                : PlayerBarButton(
                    icon: DsIcons.minimize2,
                    label: t.room.fullscreenOff,
                    autofocus: true,
                    onPressed: () => unawaited(_toggleFullscreen()),
                  ),
          ),
          Expanded(
            // The small window moves by its title: a grab on the words drags
            // the window, a double press restores the page. A fullscreen
            // strip stays inert.
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: presentation == PresentationMode.pip
                  ? (_) {
                      final window = ref.read(windowsPipWindowProvider);
                      if (window != null) unawaited(window.startDragging());
                    }
                  : null,
              onDoubleTap: presentation == PresentationMode.pip
                  ? () {
                      _wake();
                      unawaited(_togglePip());
                    }
                  : null,
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.bodyStrong.copyWith(color: OnVideoColors.foreground),
              ),
            ),
          ),
          actionPill,
          morePill,
          // The small window's own close: done watching here means the window
          // goes, and the page stays where its host left it. A window that
          // cannot close carries no verb.
          if (presentation == PresentationMode.pip)
            PlayerGlassPill(
              child: PlayerBarButton(
                icon: DsIcons.x,
                label: t.common.close,
                onPressed: () {
                  final close = ref.read(roomLeaveProvider);
                  if (close == null) return;
                  _wake();
                  unawaited(_handle?.pause());
                  unawaited(close());
                },
              ),
            ),
        ],
      ),
    );
  }

  /// The recording's bar over the picture: the seek line over the transport
  /// row — play, the sound, the clock, the comments' switch, the renditions
  /// and the speed — then the window verbs and the way out of the box.
  Widget _bar(BuildContext context, {required bool immersive}) {
    final t = context.t;
    final controller = _controller;
    final handle = _handle;
    if (controller == null || handle == null) return const SizedBox(height: 56);
    final tv = PlayerBarTier.tvOf(context);
    final compact = !tv && !LiveWindow.isExpanded(MediaQuery.sizeOf(context).width);
    final presentation = ref.watch(roomPresentationProvider);
    final playing = _transport?.isPlaying ?? false;
    final position = _transport?.position ?? Duration.zero;
    final total = controller.duration > Duration.zero ? controller.duration : Duration.zero;
    final bar = Row(
      spacing: tv ? DsSpace.s8 : DsSpace.s4,
      children: [
        // The bar's first control and a TV's landing focus: the remote
        // reaches play before anything else.
        PlayerBarButton(
          icon: playing ? DsIcons.pause : DsIcons.play,
          label: playing ? t.room.pause : t.room.play,
          autofocus: tv,
          onPressed: () {
            _wake();
            unawaited(controller.togglePlayPause());
          },
        ),
        // The bar owns the sound the way the live room's does: the mute
        // button and the slider beside it, the slider speaking past a mute.
        PlayerBarButton(
          label: _muted ? t.room.unmute : t.room.mute,
          iconAsset: _muted ? 'assets/icons/volume-muted.svg' : 'assets/icons/volume.svg',
          onPressed: () {
            _wake();
            unawaited(_toggleMute());
          },
        ),
        SizedBox(
          width: compact ? 72 : 96,
          child: DsSlider(
            value: handle.volume,
            onChanged: (value) {
              _wake();
              unawaited(_setVolume(value));
            },
            semanticLabel: t.room.volume,
          ),
        ),
        if (!compact) const Spacer(),
        Text(
          '${vodDurationText(position)} / ${vodDurationText(total)}',
          style: DsTheme.of(context).typography.numeric(DsTheme.of(context).typography.caption),
        ),
        if (!compact) const Spacer(),
        if (controller.supportsDanmaku)
          PlayerBarButton(
            iconAsset: 'assets/icons/danmaku.svg',
            label: controller.danmakuVisible ? t.room.danmakuOff : t.room.danmakuOn,
            selected: controller.danmakuVisible,
            onPressed: () {
              _wake();
              controller.toggleDanmaku();
            },
          ),
        if (controller.qualities.length > 1)
          DsMenuAnchor(
            semanticLabel: t.room.replayQuality,
            align: DsAlign.end,
            items: [
              for (final quality in controller.qualities)
                DsMenuItem(
                  label: Text(quality.label),
                  onPressed: () => unawaited(controller.selectQuality(quality.id)),
                ),
            ],
            builder: (context, menu, _) => PlayerBarButton(
              label:
                  controller.qualities.where((item) => item.id == controller.qualityId).firstOrNull?.label ??
                  t.room.replayQuality,
              onPressed: () {
                _wake();
                menu.toggle();
              },
            ),
          ),
        DsMenuAnchor(
          semanticLabel: t.room.replayRate,
          align: DsAlign.end,
          items: [
            for (final rate in _speedChoices)
              DsMenuItem(label: Text('${rate}x'), onPressed: () => unawaited(controller.setRate(rate))),
          ],
          builder: (context, menu, _) => PlayerBarButton(
            label: '${controller.rate}x',
            onPressed: () {
              _wake();
              menu.toggle();
            },
          ),
        ),
        // The immersive surface has no parts row under the picture — the
        // catalogue on the bar is the only way to another part there.
        if (immersive && controller.segments.length > 1)
          KeyedSubtree(
            key: _partsAnchor,
            child: PlayerBarButton(
              icon: DsIcons.listVideo,
              label: _currentPartLabel(controller),
              selected: _partsOpen,
              onPressed: () {
                _wake();
                setState(() => _partsOpen = !_partsOpen);
              },
            ),
          ),
        // The window verbs, then the way out of the picture's box — the room
        // bar's pair: the desktop's window-fullscreen first, then the system
        // fullscreen the phone turns for.
        if (_desktop && presentation != PresentationMode.pip)
          PlayerBarButton(
            icon: presentation == PresentationMode.windowFullscreen ? DsIcons.copy : DsIcons.square,
            label: presentation == PresentationMode.windowFullscreen
                ? t.room.windowFullscreenOff
                : t.room.windowFullscreenOn,
            selected: presentation == PresentationMode.windowFullscreen,
            onPressed: () {
              _wake();
              unawaited(_toggleWindowFullscreen());
            },
          ),
        if (presentation != PresentationMode.pip)
          PlayerBarButton(
            icon: presentation == PresentationMode.fullscreen ? DsIcons.minimize : DsIcons.maximize,
            label: presentation == PresentationMode.fullscreen ? t.room.fullscreenOff : t.room.fullscreenOn,
            onPressed: () {
              _wake();
              unawaited(_toggleFullscreen());
            },
          ),
      ],
    );
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s12, DsSpace.s4, DsSpace.s12, DsSpace.s12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.bottomCenter,
          end: AlignmentDirectional.topCenter,
          colors: [Color(0xB3000000), Color(0x00000000)],
        ),
      ),
      child: Column(
        key: _barAnchor,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s4,
        mainAxisSize: MainAxisSize.min,
        children: [
          VodSeekBar(
            position: position,
            duration: total,
            onSeek: (seconds) => unawaited(controller.seek(Duration(milliseconds: (seconds * 1000).round()))),
          ),
          if (compact) SingleChildScrollView(scrollDirection: Axis.horizontal, child: bar) else bar,
        ],
      ),
    );
  }

  /// The on-screen part's name, as the parts row names it; a recording
  /// whose part the controller has not named yet reads as the catalogue's
  /// own word.
  String _currentPartLabel(ArchivePlaybackController controller) {
    final current = controller.video?.id;
    for (final part in controller.segments.whereType<SoopArchivePart>()) {
      if (part.id == current) return 'P${part.order}';
    }
    for (final (index, part) in controller.segments.whereType<DouyuVodVideo>().indexed) {
      if (part.id == current) return 'P${index + 1}';
    }
    return context.t.room.replayParts;
  }

  /// The parts catalogue's rows, one per file of the broadcast.
  List<Widget> _partOptions(ArchivePlaybackController controller) {
    final current = controller.video?.id;
    return [
      for (final part in controller.segments.whereType<SoopArchivePart>())
        PlayerPanelOption(label: 'P${part.order}', selected: part.id == current, onPressed: () => _pickPart(part.id)),
      for (final (index, part) in controller.segments.whereType<DouyuVodVideo>().indexed)
        PlayerPanelOption(label: 'P${index + 1}', selected: part.id == current, onPressed: () => _pickPart(part.id)),
    ];
  }

  /// Another part of the broadcast: the catalogue folds first, the walk
  /// follows — the panel never hangs over a picture it no longer names.
  void _pickPart(String id) {
    setState(() => _partsOpen = false);
    unawaited(_controller?.open(id));
  }

  /// The recording's parts, when the broadcast spans more than one file:
  /// one chip each, the on-screen part filled. SOOP names its parts by
  /// order; Douyu's session segments sit in the platform's own order.
  Widget _parts(BuildContext context, ArchivePlaybackController controller) {
    final t = context.t;
    final current = controller.video?.id;
    final soopParts = controller.segments.whereType<SoopArchivePart>().toList();
    final douyuParts = controller.segments.whereType<DouyuVodVideo>().toList();
    final size = PlayerBarTier.tvOf(context) ? DsSize.lg : DsSize.sm;
    return SizedBox(
      height: PlayerBarTier.tvOf(context) ? 64 : 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: DsSpace.s12),
        children: [
          for (final part in soopParts)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: DsSpace.s8),
              child: DsButton(
                variant: part.id == current ? DsButtonVariant.primary : DsButtonVariant.secondary,
                size: size,
                semanticLabel: '${t.room.replayParts} ${part.order}',
                onPressed: part.id == current ? null : () => unawaited(controller.open(part.id)),
                child: Text('P${part.order}'),
              ),
            ),
          for (final (index, part) in douyuParts.indexed)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: DsSpace.s8),
              child: DsButton(
                variant: part.id == current ? DsButtonVariant.primary : DsButtonVariant.secondary,
                size: size,
                semanticLabel: '${t.room.replayParts} ${index + 1}',
                onPressed: part.id == current ? null : () => unawaited(controller.open(part.id)),
                child: Text('P${index + 1}'),
              ),
            ),
        ],
      ),
    );
  }
}

/// The stand-in listenable the stage builds with before the controller
/// exists: never notifies, so the first frame is a dark stage with a way
/// back and nothing more.
final class ChangeTracker extends ChangeNotifier {
  new();
}
