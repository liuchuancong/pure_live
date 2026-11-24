import 'dart:async' show StreamSubscription, Timer, unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart' show Scaffold;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_cache/live_cache.dart' show ImageCachePolicies;
import 'package:live_device/live_device.dart'
    show PlatformScreenAwakeService, PlatformScreenOrientationService, ScreenAwakeService, ScreenOrientationService;
import 'package:live_platform/live_platform.dart';
import 'package:live_vod/live_vod.dart';
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
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/huya/controller/huya_downloads.dart';
import 'package:pure_live/modules/huya/controller/huya_video.dart';
import 'package:pure_live/modules/huya/controller/huya_video_playback.dart';
import 'package:pure_live/modules/live/archive/archive_progress.dart';
import 'package:pure_live/modules/live/room/page/chat_splitter.dart' show ChatSplitter;
import 'package:pure_live/modules/live/room/player/sleep_timer.dart' show SleepTimerController, sleepTimerProvider;
import 'package:pure_live/modules/vod/widgets/vod_picture_gestures.dart' show VodPictureGestures, VodTapSide;
import 'package:pure_live/modules/vod/widgets/vod_player_chrome.dart' show VodGestureKind, VodGestureTip, VodSeekBar;
import 'package:pure_live/modules/vod/widgets/vod_widgets.dart'
    show VodFoldedText, VodVideoRow, vodDateText, vodDurationText;
import 'package:pure_live/shared/shared.dart';

/// One Huya video: the picture the station's own player would show, the
/// gestures a video is watched with, and beside it what the video is and what
/// the station puts next to it.
///
/// The player wears the room's presentation: the desktop's window fullscreen,
/// the system fullscreen and the picture-in-picture window all own the
/// surface, an overlay bar rides the picture on the station's own auto-hide
/// clock, and the stream's figures answer to I.
final class HuyaVideoPlayerPage extends ConsumerStatefulWidget {
  /// The page for [id].
  const HuyaVideoPlayerPage({required this.id, super.key});

  /// The station's video id.
  final String id;

  @override
  ConsumerState<HuyaVideoPlayerPage> createState() => _HuyaVideoPlayerPageState();
}

final class _HuyaVideoPlayerPageState extends ConsumerState<HuyaVideoPlayerPage> with WidgetsBindingObserver {
  PlayerHandle? _handle;
  PlayerKernel? _kernel;
  HuyaVideoPlaybackController? _controller;
  final GlobalKey _qualityAnchor = GlobalKey();
  final GlobalKey _speedAnchor = GlobalKey();
  final GlobalKey _listAnchor = GlobalKey();
  final GlobalKey _barAnchor = GlobalKey();

  /// The bar panel standing now (quality, speed, list); a tap anywhere else
  /// puts it away.
  String? _openPanel;

  /// The watching lock, the room's own rule: locked, the strip, the bar and
  /// the picture's gestures all stand down, and the unlock pill on the
  /// picture's right edge is the only thing left to press.
  bool _locked = false;
  bool _disposed = false;
  bool _startFailed = false;

  /// Whether the wide layout's information column stands; closing it hands
  /// the window to the picture, the room's cinema half, and the door at the
  /// edge brings it back.
  bool _columnOpen = true;

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

  /// The transport snapshot the bar and the hide clock read; the handle's
  /// stream feeds it, the way the other players' pages keep theirs.
  PlayerTransportState? _transport;
  StreamSubscription<PlayerTransportState>? _transportSub;
  StreamSubscription<GeometryState>? _geometrySub;

  /// The picture's own shape, from the engine's geometry: the fullscreen and
  /// compact-window drivers shape their surfaces from it.
  double _aspectRatio = 16 / 9;

  /// The overlay bar's idle clock: it reads the station's own
  /// controlsAutoHideSeconds, whose zero is 常显.
  bool _controlsVisible = false;
  Timer? _hideTimer;

  /// Holds the display awake exactly while the video plays and the
  /// preference allows it.
  bool _screenHeld = false;
  final ScreenAwakeService _screenAwake = const PlatformScreenAwakeService();
  final ScreenOrientationService _screenOrientation = const PlatformScreenOrientationService();

  /// The background's gate: a paused app pauses the video, unless the small
  /// window is what carries it.
  BackgroundPlaybackGate? _backgroundGate;
  PlayerId? _backgroundPausedHandleId;

  // Captured while the page is alive; `ref` is refused by the time dispose
  // runs, and the leaving page must still exit its presentation mode.
  late final RoomPresentationController _presentationNotifier;

  /// The sleep timer this page owns while it stands: its fire stops this
  /// video, and leaving disarms it.
  late final SleepTimerController _sleepTimerNotifier;

  /// The presentation mode, followed through a manual listener for the same
  /// reason: the leaving page reads its own field, not `ref`.
  PresentationMode _presentationMode = PresentationMode.normal;

  bool get _desktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  static final _Idle _idle = _Idle();

  /// The rate ladder the bar lists; the keyboard walks it step by step.
  static const _speedChoices = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    _presentationNotifier = ref.read(roomPresentationProvider.notifier);
    ref.listenManual(roomPresentationProvider, (_, next) => _presentationMode = next, fireImmediately: true);
    // The sleep timer must stop this video, not some global notion of one.
    _sleepTimerNotifier = ref.read(sleepTimerProvider.notifier);
    // A timer armed with no player alive (the settings' ASMR dialog) dies
    // here: this page owns the fire now and inherits no leftover.
    Timer.run(() => _sleepTimerNotifier.start(null));
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

  /// Attaches the kernel's handle, builds the video's controller over it and
  /// opens where the viewer last stopped.
  Future<void> _start() async {
    final kernel = _kernel;
    if (kernel == null || _disposed) return;
    setState(() => _startFailed = false);
    try {
      final detail = await ref.read(huyaVideoDetailProvider(widget.id).future);
      if (_disposed) return;
      final handle = await kernel.create(
        config: const PlayerConfig(name: 'huya'),
        preferredBackend: ref.read(playerKernelBackendProvider).id,
      );
      if (_disposed) {
        silencePlayer(handle);
        unawaited(kernel.release(handle.id));
        return;
      }
      _handle = handle;
      _holdSound();
      _controller = HuyaVideoPlaybackController(
        api: ref.read(huyaVideoApiProvider),
        session: handle,
        detail: detail,
        progress: ArchiveProgress(),
        // The module's own volume: what huya's player starts on, not what
        // the room or the channel left behind.
        initialVolume: ref.read(modulePlaybackSettingsProvider(PlayerModule.huya)).volume,
      );
      _bind(handle);
      // A playing mini window belongs to the video the viewer just left; a
      // new one here supersedes it (its close path checkpoints the old).
      FloatingVideoWindow.dismiss();
      setState(() {});
      await _controller!.open(widget.id);
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

  void _retry() {
    ref.invalidate(huyaVideoDetailProvider(widget.id));
    unawaited(_start());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _backgroundGate?.handleLifecycle(state);
  }

  /// The page's hold on the app's sound: playing a replay hushes a live
  /// window or the music the viewer left running.
  void _holdSound() {
    unawaited(
      ref
          .read(audioArbiterProvider.notifier)
          .claim(AudioOwner(AudioOwnerKind.vod, 'huya-video:${widget.id}'), () => Future<void>.value(_handle?.pause())),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    ref.read(audioArbiterProvider.notifier).release(AudioOwner(AudioOwnerKind.vod, 'huya-video:${widget.id}'));
    _tipTimer?.cancel();
    _hideTimer?.cancel();
    _keySeekTimer?.cancel();
    _sleepTimerNotifier.onFire_ = null;
    Timer.run(() => _sleepTimerNotifier.start(null));
    // A page leaving while a mode owns the window takes the mode with it;
    // the release's silence keeps the video from speaking over the page the
    // viewer returned to.
    final handle = _handle;
    if (handle != null && _presentationMode != PresentationMode.normal) {
      unawaited(_presentationNotifier.exit(handle.id));
    }
    final controller = _controller;
    final kernel = _kernel;
    var retirement = Future<void>.value();
    if (controller != null) {
      controller.dispose();
      retirement = controller.retirement;
    }
    if (handle != null && kernel != null) {
      silencePlayer(handle);
      retirement = Future.wait<void>([retirement, kernel.release(handle.id)]).then((_) {});
    }
    unawaited(retirement);
    unawaited(_transportSub?.cancel() ?? Future<void>.value());
    unawaited(_geometrySub?.cancel() ?? Future<void>.value());
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

  /// A related pick replaces the picture rather than stacking a second
  /// decoder over it.
  void _openRelated(String id) {
    if (id.isEmpty || id == widget.id) return;
    context.pushReplacement('/huya/$id');
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

  /// The keyboard's way through the seek: a held arrow keeps stepping.
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

  /// A horizontal drag walks the part: a full sweep is the whole length.
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
    _tip(VodGestureKind.speed, playerRateLabel(rate));
    await controller.setRate(rate);
  }

  void _openUploader(String uid) {
    if (uid.isEmpty) return;
    unawaited(context.push('/huya/u/$uid'));
  }

  /// The overlay bar's clock: a pointer awake or a paused video holds it, an
  /// idle one settles it after the station's own seconds, whose zero is 常显.
  void _wake() {
    // A hover landing after dispose says nothing to a dead state.
    if (!mounted) return;
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

  /// The watching lock: taking it puts the panels away first, and locked the
  /// strip, the bar and the gestures stand down until the unlock pill says
  /// otherwise — the room's and the channel's own rule.
  void _toggleLock() {
    if (!_locked && _openPanel != null) setState(() => _openPanel = null);
    setState(() => _locked = !_locked);
    if (_locked) {
      _hideTimer?.cancel();
      return;
    }
    _wake();
  }

  /// Whether this display is the TV form factor: its chrome never hides on
  /// idle, the room's keepControls rule — the remote's focus walk is the
  /// only way through the bar, and a bar that folds under a focused button
  /// strands the walk.
  bool get _isTv => ref.read(platformRuntimeProvider).environment.runtime.formFactor == FormFactor.tv;

  void _scheduleHide() {
    // The tracker still walks the regions a leaving page owned: its exit
    // lands here after dispose, and a dead state reads no store.
    if (!mounted) return;
    _hideTimer?.cancel();
    // The TV's chrome never hides on idle (see _isTv).
    if (_isTv) return;
    if (!(_transport?.isPlaying ?? false)) return;
    final seconds = ref.read(modulePlaybackSettingsProvider(PlayerModule.huya)).controlsAutoHideSeconds;
    // The setting's zero is 常显: the bar never hides on idle while the
    // video plays.
    if (seconds <= 0) return;
    _hideTimer = Timer(Duration(seconds: seconds), () {
      if (mounted && (_transport?.isPlaying ?? false)) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  /// Holds the display awake exactly while the video plays and the
  /// preference allows it.
  void _syncScreenWake(bool hold) {
    if (hold == _screenHeld) return;
    _screenHeld = hold;
    unawaited((hold ? _screenAwake.enable() : _screenAwake.disable()).catchError((Object _) {}));
  }

  /// The sleep timer's end: the video pauses where it stands, said with the
  /// room's own toast.
  void _onSleepFire() {
    unawaited(_handle?.pause() ?? Future<void>.value());
    if (mounted) showDsToast(context: context, title: context.t.player.sleepDone);
  }

  /// Keeps the frame the video is showing in the viewer's screenshot folder,
  /// and says how it went — a capture that fails silently reads as a dead
  /// button.
  Future<void> _screenshot() async {
    final handle = _handle;
    if (handle == null) return;
    final file = await capturePlayerFrame(handle, ref.read(appPathsProvider).screenshots, prefix: 'pure_live_huya');
    if (!mounted) return;
    final t = context.t;
    showDsToast(
      context: context,
      title: file == null ? t.player.screenshotFailed : t.player.screenshotSaved(name: file.uri.pathSegments.last),
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

  /// Whether the 小窗 verb may show: the handle carries a source to hand
  /// over, no window-owning mode stands, and no mini window is up yet.
  bool get _miniWindowReady {
    // The 小窗 overlay belongs to the primary window: its root navigator
    // is the only one registered as the app's, so a secondary's handoff
    // would land its picture on the primary's overlay. Secondary windows
    // keep their own picture instead.
    if (!ref.read(isPrimaryWindowProvider)) return false;
    final handle = _handle;
    return handle != null &&
        handle.source != null &&
        _presentationMode == PresentationMode.normal &&
        !FloatingVideoWindow.isShowing;
  }

  /// Hands the video to the floating mini window and leaves: the window
  /// opens its own handle from this one's source, resuming where it stopped,
  /// while the page pops back; the expand button re-opens this route, and
  /// the walk's own progress store resumes there.
  Future<void> _enterMiniWindow() async {
    final handle = _handle;
    final source = handle?.source;
    final detail = ref.read(huyaVideoDetailProvider(widget.id)).value;
    if (handle == null || source == null || detail == null) return;
    _wake();
    final backend = ref.read(playerKernelBackendProvider).id;
    final videoId = detail.video.id;
    final ok = await FloatingVideoWindow.show(
      FloatingVideoHandoff(
        title: detail.video.title,
        resume: handle.position,
        rate: handle.rate,
        muted: handle.muted,
        open: (kernel) async {
          final fresh = await kernel.create(
            config: const PlayerConfig(name: 'floating-video'),
            preferredBackend: backend,
          );
          await fresh.open(source, autoPlay: true);
          return fresh;
        },
        onClose: (position, {required reopen}) {
          // The page is gone by then, so the walk's own store takes the
          // position the same way the controller would have.
          unawaited(ArchiveProgress().save('huya-video:$videoId', position));
          if (reopen) {
            final root = rootNavigatorKey.currentContext;
            if (root != null && root.mounted) {
              unawaited(root.push('/huya/${Uri.encodeComponent(widget.id)}'));
            }
          }
        },
      ),
    );
    if (!ok || !mounted || _disposed) return;
    // The window now carries the sound: this page goes quiet before it pops.
    silencePlayer(handle);
    if (mounted && context.mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
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
    // The module remembers it: the next huya video opens here.
    unawaited(ref.read(modulePlaybackSettingsProvider(PlayerModule.huya).notifier).setVolume(value));
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(huyaVideoDetailProvider(widget.id));
    final failed = _startFailed || (detail.hasError && _controller == null);
    final video = detail.value?.video;
    // The fullscreen's orientation policy: the first time the room goes
    // system-fullscreen, the device turns with the picture's own shape.
    ref.listen<PresentationMode>(roomPresentationProvider, (previous, next) {
      if (next != PresentationMode.fullscreen || previous == PresentationMode.fullscreen) return;
      applyFullscreenOrientation(_screenOrientation, aspectRatio: _aspectRatio);
    });
    // A download that finishes while the viewer watches: the queue lives on
    // without a page, so the arrival is said here.
    ref.listen(huyaDownloadsProvider, (previous, next) {
      final before = huyaDownloadOf(previous ?? const [], widget.id);
      final after = huyaDownloadOf(next, widget.id);
      final wasActive = before?.phase == HuyaDownloadPhase.running || before?.phase == HuyaDownloadPhase.queued;
      if (wasActive && after?.phase == HuyaDownloadPhase.done) {
        showDsToast(
          context: context,
          title: context.t.player.downloadDone(name: after!.fileName),
          status: DsStatus.success,
        );
      }
    });
    final presentation = ref.watch(roomPresentationProvider);
    final presentationController = ref.read(roomPresentationProvider.notifier);
    final colors = DsTheme.colorsOf(context);
    // Only a mode that owns the app's window replaces this page's layout; a
    // phone's picture-in-picture window floats over it.
    final immersive = presentationController.modeOwnsWindow(presentation);
    // 矮窗（高 <480）横屏沉浸：满铺画面加覆盖条，页面内容退场——判定
    // 是窗口的形状，与平台无关（与直播间同一台排版机）。
    final windowSize = MediaQuery.sizeOf(context);
    final landscapeImmersive = PlaybackLayout.resolve(
      width: windowSize.width,
      height: windowSize.height,
    ).landscapeImmersive;
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
          child: Focus(autofocus: true, child: _surface(context, detail.value, immersive: true)),
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

    if (landscapeImmersive) {
      // The sideways window takes the stage alone: the picture fills it, the
      // strip's verbs stay over it, and the back pill leads out of the page —
      // the header and the information column stepped out with the chrome.
      return PlayerBarTier(
        tv: tv,
        child: Scaffold(backgroundColor: colors.canvas, body: _surface(context, detail.value, immersive: false)),
      );
    }
    return PlayerBarTier(
      tv: tv,
      child: CallbackShortcuts(
        bindings: {
          // A remote cannot tap the picture to raise the bar, so its transport
          // keys wake the chrome they drive.
          const SingleActivator(LogicalKeyboardKey.space): () {
            _wake();
            unawaited(_toggle());
          },
          const SingleActivator(LogicalKeyboardKey.keyF): () {
            _wake();
            unawaited(_toggleFullscreen());
          },
          // The window variant of the same verb, on the desktop's own chord.
          const SingleActivator(LogicalKeyboardKey.f11): () {
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
          body: SafeArea(
            bottom: false,
            child: failed && _controller == null && video == null
                ? _Failure(error: detail.error, onRetry: _retry)
                : _page(context, detail.value),
          ),
        ),
      ),
    );
  }

  Widget _page(BuildContext context, HuyaVideoDetail? detail) {
    final t = context.t;
    final related = ref.watch(huyaRelatedProvider(widget.id));
    final width = MediaQuery.sizeOf(context).width;
    final inset = LiveWindow.pageInset(width);
    final wide = width >= kPlaybackWideBreakpoint;
    final video = detail?.video;
    final info = _Info(
      video: video,
      detail: detail,
      onUploader: _openUploader,
      onDownload: video == null ? null : () => unawaited(_startDownload(video)),
    );
    final rail = _Related(
      videos: related.value ?? const <HuyaVideo>[],
      onOpen: _openRelated,
      loading: related.isLoading,
      compact: wide,
      failed: related.hasError,
      onRetry: () => ref.invalidate(huyaRelatedProvider(widget.id)),
    );
    if (!wide) {
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(inset, DsSpace.s8, inset, DsSpace.s24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s16,
          children: [
            AspectRatio(aspectRatio: 16 / 9, child: _surface(context, detail, immersive: false)),
            info,
            rail,
          ],
        ),
      );
    }
    // The wide page is the room's split, not a dashboard: the picture owns
    // one full-height stage, and the information column beside it drags on
    // the same seam the room's chat drags on, remembering its width, and
    // closes into a cinema the edge door reopens.
    final columnWidth = ref.watch(huyaVideoColumnWidthProvider);
    final columnMax = (width - kHuyaStageFloor).clamp(kHuyaVideoColumnMin, kHuyaVideoColumnMax);
    final tv = PlayerBarTier.tvOf(context);
    final column = SizedBox(
      width: columnWidth,
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s16, DsSpace.s12, DsSpace.s16, DsSpace.s24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: DsSpace.s20, children: [info, rail]),
      ),
    );
    final stage = Expanded(
      child: Stack(
        fit: StackFit.expand,
        children: [
          _surface(context, detail, immersive: false),
          if (!_columnOpen) _ColumnDoor(onOpen: () => setState(() => _columnOpen = true)),
        ],
      ),
    );
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(inset, DsSpace.s8, inset, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          stage,
          if (_columnOpen) ...[
            ChatSplitter(
              width: columnWidth.clamp(kHuyaVideoColumnMin, columnMax),
              minWidth: kHuyaVideoColumnMin,
              maxWidth: columnMax,
              onResize: ref.read(huyaVideoColumnWidthProvider.notifier).preview,
              onResizeEnd: (value) => unawaited(ref.read(huyaVideoColumnWidthProvider.notifier).set(value)),
              onReset: () => unawaited(ref.read(huyaVideoColumnWidthProvider.notifier).set(kHuyaVideoColumnDefault)),
              label: t.huya.infoColumn,
              keyboard: !tv,
            ),
            column,
          ],
        ],
      ),
    );
  }

  /// The picture and its chrome: the video the handle carries, the gestures
  /// it answers, the stream's figures, and the strip and bar that ride it on
  /// the auto-hide clock. In the owned modes the chrome answers the mode —
  /// the leading pill is the way out, and the small window's title drags.
  Widget _surface(BuildContext context, HuyaVideoDetail? detail, {required bool immersive}) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final controller = _controller;
    final handle = _handle;
    final playing = _transport?.isPlaying ?? false;
    _syncScreenWake(playing && ref.watch(keepScreenOnProvider));
    // Locked, nothing rides the picture: the unlock pill on the right edge
    // is the whole chrome, the room's own rule.
    final showBar = !_locked && (_controlsVisible || !playing);
    return ClipRRect(
      borderRadius: BorderRadius.circular(immersive ? 0 : theme.radii.overlay),
      child: ColoredBox(
        color: OnVideoColors.ground,
        child: MouseRegion(
          onHover: (_) => _wake(),
          onExit: (_) => _scheduleHide(),
          child: ListenableBuilder(
            listenable: controller ?? _idle,
            builder: (context, _) {
              final failed = _startFailed || controller?.error != null;
              return Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: OnVideoColors.ground),
                  if (handle != null) MediaPlayerView(handle: handle),
                  Positioned.fill(
                    child: VodPictureGestures(
                      enabled: controller != null && !_locked,
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
                  // The stream's own numbers, on the same session switch the
                  // room and the other players use.
                  if (handle case final player? when ref.watch(playerStatsVisibleProvider))
                    Positioned.fill(
                      child: IgnorePointer(child: PlayerStatsOverlay(handle: player)),
                    ),
                  if (_tipKind case final kind?) VodGestureTip(kind: kind, value: _tipValue, note: _tipNote),
                  if (controller != null && controller.busy)
                    const Center(child: DsSpinner())
                  else if (failed)
                    Center(
                      child: DsAlert(
                        status: DsStatus.danger,
                        title: Text(t.room.replayFailed),
                        description: controller?.error == null ? null : Text('${controller?.error}'),
                        action: DsButton(
                          variant: DsButtonVariant.secondary,
                          size: DsSize.sm,
                          onPressed: () {
                            final current = controller;
                            if (current != null) unawaited(current.open(widget.id));
                          },
                          child: Text(t.common.retry),
                        ),
                      ),
                    ),
                  if (showBar)
                    PositionedDirectional(
                      top: 0,
                      start: 0,
                      end: 0,
                      child: _strip(context, detail, immersive: immersive),
                    ),
                  // The picture's right edge, the room column's shape: the
                  // frame's copy above the download — the picture's own
                  // actions one thumb from the frame's side.
                  // The picture's right edge (the room's lock column): the
                  // frame copy above the lock. Locked, the unlock pill is
                  // the only thing drawn, whatever the page does next; the
                  // download lives in the more container now.
                  if (showBar || _locked)
                    PositionedDirectional(
                      end: DsSpace.s12,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          spacing: DsSpace.s8,
                          children: [
                            if (!_locked && (_handle?.canCaptureScreenshot ?? false))
                              PlayerGlassPill(
                                child: PlayerBarButton(
                                  icon: DsIcons.camera,
                                  label: context.t.player.screenshot,
                                  onPressed: () {
                                    _wake();
                                    unawaited(_screenshot());
                                  },
                                ),
                              ),
                            PlayerGlassPill(
                              child: PlayerBarButton(
                                icon: _locked ? DsIcons.unlock : DsIcons.lock,
                                label: _locked ? context.t.room.unlockControls : context.t.room.lockControls,
                                onPressed: _toggleLock,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (showBar)
                    PositionedDirectional(
                      bottom: 0,
                      start: 0,
                      end: 0,
                      // Resting on the bar keeps it; leaving it settles the
                      // bar the way an idle pointer does.
                      child: MouseRegion(
                        onEnter: (_) => _hideTimer?.cancel(),
                        onExit: (_) => _scheduleHide(),
                        child: _bar(context),
                      ),
                    ),
                  // The bar's pickers hang their cards over the picture: a
                  // tap anywhere else closes whichever one stands.
                  if (showBar && _openPanel != null)
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _openPanel = null),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  if (showBar && _openPanel == 'quality' && controller != null)
                    Positioned.fill(
                      child: PlayerPanelHost(
                        anchorKey: _qualityAnchor,
                        barKey: _barAnchor,
                        width: 220,
                        child: MouseRegion(
                          onEnter: (_) => _hideTimer?.cancel(),
                          onExit: (_) => _scheduleHide(),
                          child: PlayerOverlayPanel(
                            title: t.player.quality,
                            children: [
                              for (final quality in controller.qualities)
                                PlayerPanelOption(
                                  label: quality.label,
                                  selected: quality.id == controller.qualityId,
                                  onPressed: () {
                                    setState(() => _openPanel = null);
                                    unawaited(controller.selectQuality(quality.id));
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (showBar && _openPanel == 'speed' && controller != null)
                    Positioned.fill(
                      child: PlayerPanelHost(
                        anchorKey: _speedAnchor,
                        barKey: _barAnchor,
                        width: 220,
                        child: MouseRegion(
                          onEnter: (_) => _hideTimer?.cancel(),
                          onExit: (_) => _scheduleHide(),
                          child: PlayerOverlayPanel(
                            title: t.player.speed,
                            children: [
                              for (final rate in _speedChoices)
                                PlayerPanelOption(
                                  label: playerRateLabel(rate),
                                  selected: rate == controller.rate,
                                  onPressed: () {
                                    setState(() => _openPanel = null);
                                    unawaited(controller.setRate(rate));
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  // The related list's own panel: the bar's list chip hangs
                  // it over the picture, and a pick replaces the picture —
                  // the page's rail and this panel read one provider.
                  if (showBar && _openPanel == 'list')
                    Positioned.fill(
                      child: PlayerPanelHost(
                        anchorKey: _listAnchor,
                        barKey: _barAnchor,
                        width: 260,
                        child: MouseRegion(
                          onEnter: (_) => _hideTimer?.cancel(),
                          onExit: (_) => _scheduleHide(),
                          child: Builder(
                            builder: (context) {
                              final related = ref.watch(huyaRelatedProvider(widget.id));
                              final videos = related.value ?? const <HuyaVideo>[];
                              return PlayerOverlayPanel(
                                title: t.huya.related,
                                children: [
                                  if (related.hasError)
                                    PlayerPanelOption(
                                      label: t.huya.relatedEmpty,
                                      selected: false,
                                      onPressed: () => ref.invalidate(huyaRelatedProvider(widget.id)),
                                    )
                                  else if (videos.isEmpty)
                                    Padding(
                                      padding: const EdgeInsetsDirectional.symmetric(
                                        horizontal: DsSpace.s12,
                                        vertical: DsSpace.s6,
                                      ),
                                      child: Text(
                                        t.huya.relatedEmpty,
                                        style: DsTheme.of(
                                          context,
                                        ).typography.caption.copyWith(color: OnVideoColors.inkSubtle),
                                      ),
                                    )
                                  else
                                    for (final video in videos)
                                      PlayerPanelOption(
                                        label: video.title,
                                        detail: video.duration > Duration.zero ? vodDurationText(video.duration) : null,
                                        selected: video.id == widget.id,
                                        onPressed: () {
                                          setState(() => _openPanel = null);
                                          _openRelated(video.id);
                                        },
                                      ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Hands the video to the app's download queue — the rendition being
  /// watched is the one the task asks for, and the queue resolves its own
  /// fresh address when the task's turn comes, so a stale one never sticks.
  Future<void> _startDownload(HuyaVideo video) async {
    final t = context.t;
    final result = await ref
        .read(huyaDownloadsProvider.notifier)
        .download(videoId: widget.id, title: video.title, qualityId: _controller?.qualityId ?? '', cover: video.cover);
    if (!mounted) return;
    switch (result.outcome) {
      case HuyaDownloadEnqueue.queued:
        showDsToast(context: context, title: t.settings.downloadQueuedNotice, status: DsStatus.success);
      case HuyaDownloadEnqueue.duplicate:
        showDsToast(context: context, title: t.player.downloadDuplicate);
      case HuyaDownloadEnqueue.failed:
        showDsToast(
          context: context,
          title: t.settings.downloadStatusFailed,
          description: result.error,
          status: DsStatus.danger,
        );
    }
  }

  /// The queue's own word on this video, riding the picture above the bar:
  /// the moving bytes and their pause, the paused task and its resume, the
  /// failed one and its retry. A finished file says nothing — the arrival
  /// toast already did.
  Widget? _downloadPill() {
    final task = huyaDownloadOf(ref.watch(huyaDownloadsProvider), widget.id);
    if (task == null || task.phase == HuyaDownloadPhase.done) return null;
    final t = context.t;
    Widget caption;
    PlayerBarButton trailing;
    switch (task.phase) {
      case HuyaDownloadPhase.queued || HuyaDownloadPhase.running:
        caption = Text(switch (task.progress) {
          final progress? => t.settings.downloadPercent(percent: '${(progress * 100).round()}'),
          null => t.settings.downloadPercentUnknown,
        }, style: DsTheme.of(context).typography.small.copyWith(color: OnVideoColors.foreground));
        trailing = PlayerBarButton(
          icon: DsIcons.pause,
          label: t.player.downloadPause,
          onPressed: () => unawaited(ref.read(huyaDownloadsProvider.notifier).pause(widget.id)),
        );
      case HuyaDownloadPhase.paused:
        caption = Text(
          t.settings.downloadStatusPaused,
          style: DsTheme.of(context).typography.small.copyWith(color: OnVideoColors.foreground),
        );
        trailing = PlayerBarButton(
          icon: DsIcons.play,
          label: t.settings.downloadResume,
          onPressed: () => unawaited(ref.read(huyaDownloadsProvider.notifier).resume(widget.id)),
        );
      case HuyaDownloadPhase.failed:
        caption = Text(
          t.settings.downloadStatusFailed,
          style: DsTheme.of(context).typography.small.copyWith(color: OnVideoColors.foreground),
        );
        trailing = PlayerBarButton(
          icon: DsIcons.rotateCcw,
          label: t.common.downloadRetried,
          onPressed: () => unawaited(ref.read(huyaDownloadsProvider.notifier).resume(widget.id)),
        );
      case HuyaDownloadPhase.done:
        return null;
    }
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: DsSpace.s12, end: DsSpace.s12, bottom: DsSpace.s4),
      child: Align(
        alignment: AlignmentDirectional.centerEnd,
        child: PlayerGlassPill(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s12, DsSpace.s4, DsSpace.s4, DsSpace.s4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: DsSpace.s8,
              children: [
                if (task.phase == HuyaDownloadPhase.running || task.phase == HuyaDownloadPhase.queued)
                  const DsSpinner(style: DsSpinnerStyle(size: 14)),
                caption,
                trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The strip over the picture: the way back and the name always, the frame
  /// verbs and the small window once a player exists to act on. [immersive]
  /// swaps the back pill for the mode's way out and lets the small window's
  /// title drag the window.
  Widget _strip(BuildContext context, HuyaVideoDetail? detail, {required bool immersive}) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final presentation = ref.watch(roomPresentationProvider);
    final pipAvailable = _handle != null && ref.read(roomPresentationProvider.notifier).pipAvailable;
    // The cluster keeps the where-to verbs and the more door in one glass
    // pill — the room's own single form, never two pills drifting apart.
    // The frame's copy lives on the picture's right edge with the lock.
    final actions = <Widget>[
      // In the small window the leading pill is the way back, so the pill
      // here would be the same verb twice.
      if (pipAvailable && presentation != PresentationMode.pip)
        PlayerBarButton(
          icon: DsIcons.pictureInPicture,
          label: t.player.pipOn,
          onPressed: () {
            _wake();
            unawaited(_togglePip());
          },
        ),
      // The compact window is a settings-governed verb: off, the cluster
      // carries no 小窗 chip at all.
      if (_miniWindowReady && ref.watch(playbackSettingsProvider.select((settings) => settings.floatWindow)))
        PlayerBarButton(
          icon: DsIcons.appWindow,
          label: t.common.miniWindow,
          onPressed: () {
            _wake();
            unawaited(_enterMiniWindow());
          },
        ),
    ];
    final clusterPill = PlayerGlassPill(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: PlayerBarTier.tvOf(context) ? DsSpace.s8 : DsSpace.s4,
        children: [
          ...actions,
          PlayerBarButton(
            icon: DsIcons.ellipsisVertical,
            label: t.common.more,
            onPressed: () {
              _wake();
              unawaited(
                showPlayerMoreContainer(
                  context,
                  content: (context, {required labeled}) => _HuyaMoreContent(
                    labeled: labeled,
                    // The download's home since the lock took the edge:
                    // the rendition being watched is the one the task asks
                    // for.
                    onDownload: switch (detail?.video) {
                      final video? => () => unawaited(_startDownload(video)),
                      _ => null,
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
    if (!immersive) {
      return Container(
        padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s8, DsSpace.s8, DsSpace.s12, DsSpace.s20),
        decoration: BoxDecoration(gradient: OnVideoColors.shade(edge: VerticalDirection.up)),
        child: Row(
          spacing: DsSpace.s8,
          children: [
            PlayerCapsuleHead(
              title: detail?.video.title ?? t.common.moduleHuya,
              onBack: () {
                _wake();
                if (Navigator.of(context).canPop()) Navigator.of(context).pop();
              },
            ),
            const Spacer(),
            clusterPill,
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s8, DsSpace.s8, DsSpace.s12, DsSpace.s20),
      decoration: BoxDecoration(gradient: OnVideoColors.shade(edge: VerticalDirection.up)),
      child: Row(
        spacing: DsSpace.s8,
        children: [
          // The leading pill answers the mode this strip sits in: out of the
          // small window back to the page, or out of fullscreen.
          PlayerGlassPill(
            child: presentation == PresentationMode.pip
                ? PlayerBarButton(
                    icon: DsIcons.pictureInPicture2,
                    label: t.player.pipOff,
                    autofocus: true,
                    onPressed: () {
                      _wake();
                      unawaited(_togglePip());
                    },
                  )
                : PlayerBarButton(
                    icon: DsIcons.minimize,
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
                detail?.video.title ?? t.common.moduleHuya,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.bodyStrong.copyWith(color: OnVideoColors.foreground),
              ),
            ),
          ),
          clusterPill,
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

  /// The bar under the picture: the seek line over the transport row — play,
  /// the sound, the clock, the renditions and the speed, then the window
  /// verbs and the way out of the picture's box.
  Widget _bar(BuildContext context) {
    final t = context.t;
    final controller = _controller;
    final handle = _handle;
    if (controller == null || handle == null) return const SizedBox(height: 56);
    final tv = PlayerBarTier.tvOf(context);
    final presentation = ref.watch(roomPresentationProvider);
    final playing = _transport?.isPlaying ?? false;
    final position = _transport?.position ?? Duration.zero;
    final total = controller.duration > Duration.zero ? controller.duration : Duration.zero;
    // The bar's three groups under the shared rule: the transport with the
    // window verbs on one line, the catalogues folding to their own line
    // below — two rows at the narrow widths, never a horizontal scroll. The
    // bar's own width is the ladder's ruler, the one every surface reads:
    // the volume slider 96 px when the bar is roomy, 72 when it bends, and
    // gone under 480, where the mute and the wheel still carry the sound.
    final bar = LayoutBuilder(
      builder: (context, barConstraints) {
        final barWidth = barConstraints.maxWidth;
        final volumeWidth = barWidth >= 720 ? 96.0 : (barWidth >= 480 ? 72.0 : null);
        return PlayerBarRows(
      // Two rows at every width: the transport on the first, the catalogue
      // (quality, pace, the related list) along the bottom edge on the
      // second — the pace never hides at the wide row's right end.
      foldWidth: double.infinity,
      gap: tv ? DsSpace.s8 : DsSpace.s4,
      start: Row(
        spacing: tv ? DsSpace.s8 : DsSpace.s4,
        children: [
          PlayerBarButton(
            icon: playing ? DsIcons.pause : DsIcons.play,
            label: playing ? t.player.pause : t.player.play,
            onPressed: () {
              _wake();
              unawaited(controller.togglePlayPause());
            },
          ),
          // The bar owns the sound the way the live room's does: the mute
          // button and the slider beside it, the slider speaking past a mute.
          PlayerBarButton(
            label: _muted ? t.player.unmute : t.player.mute,
            icon: _muted ? DsIcons.volumeX : DsIcons.volume2,
            onPressed: () {
              _wake();
              unawaited(_toggleMute());
            },
          ),
          if (volumeWidth != null)
            SizedBox(
              width: volumeWidth,
              child: DsSlider(
                value: handle.volume,
                style: const DsSliderStyle(
                  height: 24,
                  trackHeight: 4,
                  trackColor: OnVideoColors.track,
                  fillColor: OnVideoColors.foreground,
                  thumbColor: OnVideoColors.foreground,
                  thumbSize: 12,
                ),
                onChanged: (value) {
                  _wake();
                  unawaited(_setVolume(value));
                },
                semanticLabel: t.player.volume,
              ),
            ),
        ],
      ),
      middle: Row(
        spacing: tv ? DsSpace.s8 : DsSpace.s4,
        children: [
          if (controller.qualities.length > 1)
            PlayerBarChoice(
              anchorKey: _qualityAnchor,
              label: t.player.quality,
              value:
                  controller.qualities.where((item) => item.id == controller.qualityId).firstOrNull?.label ??
                  t.player.quality,
              icon: DsIcons.gauge,
              selected: _openPanel == 'quality',
              onPressed: () {
                _wake();
                setState(() => _openPanel = _openPanel == 'quality' ? null : 'quality');
              },
            ),
          PlayerBarChoice(
            anchorKey: _speedAnchor,
            label: t.player.speed,
            value: playerRateLabel(controller.rate),
            icon: DsIcons.timer,
            selected: _openPanel == 'speed',
            onPressed: () {
              _wake();
              setState(() => _openPanel = _openPanel == 'speed' ? null : 'speed');
            },
          ),
          // The related list's chip: the same catalogue the page's rail
          // reads, hung off the bar so a change of video never leaves the
          // picture.
          PlayerBarChoice(
            anchorKey: _listAnchor,
            label: t.huya.related,
            value: controller.video.title.isEmpty ? t.huya.related : controller.video.title,
            icon: DsIcons.listVideo,
            selected: _openPanel == 'list',
            onPressed: () {
              _wake();
              setState(() => _openPanel = _openPanel == 'list' ? null : 'list');
            },
          ),
        ],
      ),
      end: Row(
        spacing: tv ? DsSpace.s8 : DsSpace.s4,
        children: [
          // The window verbs, then the way out of the picture's box — the room
          // bar's pair: the desktop's window-fullscreen first, then the system
          // fullscreen the phone turns for. The window's own shape with the
          // arrows that say which way it goes.
          if (_desktop && presentation != PresentationMode.pip)
            PlayerBarButton(
              icon: presentation == PresentationMode.windowFullscreen
                  ? DsIcons.squareShrinkUpLeftDownRight
                  : DsIcons.squareExpandUpRightDownLeft,
              label: presentation == PresentationMode.windowFullscreen
                  ? t.player.windowFullscreenOff
                  : t.player.windowFullscreenOn,
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
              selected: presentation == PresentationMode.fullscreen,
              onPressed: () {
                _wake();
                unawaited(_toggleFullscreen());
              },
            ),
        ],
        ),
        );
      },
    );
    return PlayerControlBar(
      key: _barAnchor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s4,
        mainAxisSize: MainAxisSize.min,
        children: [
          ?_downloadPill(),
          PlayerSeekLayer.replay(
            position: position,
            duration: total,
            seekBar: VodSeekBar(
              position: position,
              duration: total,
              buffered: _transport?.buffer.ranges ?? const [],
              coverUrl: controller.video.cover.isEmpty ? null : controller.video.cover,
              onSeek: (seconds) => unawaited(controller.seek(Duration(milliseconds: (seconds * 1000).round()))),
            ),
          ),
          bar,
        ],
      ),
    );
  }
}

/// The video's own block: what it is, who posted it, what it is about —
/// and the one verb the page itself carries (the download), so the viewer is
/// not sent back to a picture strip that may have settled away.
final class _Info extends StatefulWidget {
  const _Info({required this.video, required this.detail, required this.onUploader, this.onDownload});

  final HuyaVideo? video;
  final HuyaVideoDetail? detail;
  final ValueChanged<String> onUploader;
  final VoidCallback? onDownload;

  @override
  State<_Info> createState() => _InfoState();
}

final class _InfoState extends State<_Info> {
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final video = widget.video;
    if (video == null) return const _InfoSkeleton();
    final brief = widget.detail?.video.brief ?? video.brief;
    final tags = widget.detail?.tags ?? const <String>[];
    final lines = [
      if (video.playCount > 0) '${AudienceFormat.format(video.playCount)} ${t.huya.views}',
      if (video.publishedAt case final at?) vodDateText(at),
    ];
    final uploaderName = video.uploaderName.isEmpty ? t.common.moduleHuya : video.uploaderName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s12,
      children: [
        Text(video.title, style: theme.typography.title.copyWith(color: colors.text)),
        // The whole row opens the uploader, the way a card does — not just
        // the name's few points of text.
        GestureDetector(
          onTap: video.uploaderId.isEmpty ? null : () => widget.onUploader(video.uploaderId),
          child: Row(
            spacing: DsSpace.s8,
            children: [
              DsAvatar(
                initials: avatarInitials(video.uploaderName.isEmpty ? video.title : video.uploaderName),
                image: video.uploaderAvatar.isEmpty
                    ? null
                    : cachedImage(video.uploaderAvatar, policy: ImageCachePolicies.avatar),
                size: DsSize.md,
                semanticLabel: video.uploaderName,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: DsSpace.s3,
                  children: [
                    Text(
                      uploaderName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.bodyStrong.copyWith(
                        color: video.uploaderId.isEmpty ? colors.text : colors.indicator,
                      ),
                    ),
                    if (lines.isNotEmpty)
                      Text(
                        lines.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.caption.copyWith(color: colors.textMuted),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // The page's own verbs: the download the strip carries, kept here so
        // it survives the strip settling away.
        if (widget.onDownload != null)
          Wrap(
            spacing: DsSpace.s8,
            runSpacing: DsSpace.s8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DsButton(
                variant: DsButtonVariant.secondary,
                size: DsSize.sm,
                leading: const DsIcon(DsIcons.download, size: 14),
                onPressed: widget.onDownload,
                child: Text(t.player.download),
              ),
            ],
          ),
        if (brief.isNotEmpty) VodFoldedText(text: brief),
        if (tags.isNotEmpty)
          Wrap(
            spacing: DsSpace.s8,
            runSpacing: DsSpace.s4,
            children: [for (final tag in tags) DsBadge(label: Text('#$tag'), dot: false)],
          ),
      ],
    );
  }
}

/// What the station puts beside the video: one row each, the same shape the
/// station's own rail wears.
final class _Related extends StatelessWidget {
  const _Related({
    required this.videos,
    required this.onOpen,
    required this.loading,
    this.compact = false,
    this.failed = false,
    this.onRetry,
  });

  final List<HuyaVideo> videos;
  final ValueChanged<String> onOpen;
  final bool loading;

  /// The side column's cut of the rows: a narrower cover and one line of
  /// title, the shape a 320–520px column reads without squeezing.
  final bool compact;

  /// Whether the related read itself failed: a failed rail says so with its
  /// own retry instead of posing as an empty one.
  final bool failed;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s12,
      children: [
        SectionHeader(title: t.huya.related),
        if (videos.isEmpty && loading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: DsSpace.s4),
            child: _RelatedSkeleton(compact: compact),
          )
        else if (videos.isEmpty && failed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: DsSpace.s12),
            child: DsEmptyState(
              icon: const DsIcon(DsIcons.cloudOff),
              title: Text(t.common.loadFailed),
              actions: [
                DsButton(
                  variant: DsButtonVariant.ghost,
                  size: DsSize.sm,
                  onPressed: onRetry,
                  child: Text(t.common.retry),
                ),
              ],
            ),
          )
        else if (videos.isEmpty)
          // A quiet nothing beats an orphaned header: the section says there
          // is nothing beside it rather than trailing off.
          Padding(
            padding: const EdgeInsets.symmetric(vertical: DsSpace.s12),
            child: DsEmptyState(icon: const DsIcon(DsIcons.compass), title: Text(t.huya.relatedEmpty)),
          )
        else
          for (final video in videos)
            Padding(
              padding: const EdgeInsets.only(bottom: DsSpace.s8),
              child: VodVideoRow(video: video.asVideo(), compact: compact, onOpen: () => onOpen(video.id)),
            ),
      ],
    );
  }
}

/// The start's failure: the read that never answered, with its own retry.
final class _Failure extends StatelessWidget {
  const _Failure({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Center(
      child: DsEmptyState(
        icon: const DsIcon(DsIcons.film),
        title: Text(t.huya.errorTitle),
        description: Text(error?.toString() ?? t.huya.noResultsDescription),
        actions: [DsButton(variant: DsButtonVariant.secondary, onPressed: onRetry, child: Text(t.common.retry))],
      ),
    );
  }
}

/// The stand-in listenable the stage builds with before the controller
/// exists: never notifies, so the first frame is a dark stage and nothing
/// more.
final class _Idle extends ChangeNotifier {
  new();
}

/// The door a closed information column leaves at the stage's end edge: a
/// narrow upright tab, the room's immersive drawer door read on the video
/// page. The chevron points the way the column will come back from.
final class _ColumnDoor extends StatelessWidget {
  const _ColumnDoor({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return PositionedDirectional(
      top: 0,
      bottom: 0,
      end: 0,
      child: DsTooltip(
        message: t.huya.infoColumnShow,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onOpen,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: 0.92),
                border: BorderDirectional(start: BorderSide(color: colors.border)),
              ),
              child: SizedBox(
                width: 28,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: DsSpace.s8,
                  children: [
                    DsIcon(DsIcons.chevronLeft, size: theme.sizes.iconSm, color: colors.textMuted),
                    RotatedBox(
                      quarterTurns: 1,
                      child: Text(
                        t.huya.infoColumn,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.small.copyWith(color: colors.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The video's more container's content, in the room's own reading: the bar
/// keeps the verbs that live on it — download, screenshot, PiP, the pace and
/// the picture's fit — and the container carries what the bar has no room
/// for: the timer that ends a long video by itself and the auto-hide pace,
/// the setting the bar already obeys but no video surface could reach before.
final class _HuyaMoreContent extends ConsumerWidget {
  const _HuyaMoreContent({required this.labeled, this.onDownload});

  /// Whether the group labels show — the sheet keeps them on.
  final bool labeled;

  /// Hands the video to the download queue; null hides the row.
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    // The module's own settings: the pace and the timer this page reads and
    // writes are huya's, not the room's.
    final settings = ref.watch(modulePlaybackSettingsProvider(PlayerModule.huya));
    final sleepMinutes = ref.watch(sleepTimerProvider).minutes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (labeled) playerMoreSectionLabel(context, t.player.moreSettings),
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: DsSpace.s8, vertical: DsSpace.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s4,
            children: [
              // The download's home since the lock took the edge: the
              // rendition being watched is the one the task asks for.
              if (onDownload != null)
                PlayerMoreRow(
                  label: t.player.download,
                  leading: DsIcons.download,
                  value: null,
                  onTap: onDownload,
                ),
              // A long video ends itself: the choices stand in the row, the
              // room's own ASMR panel stays with the room.
              PlayerMoreRow(
                label: t.player.sleep,
                leading: DsIcons.timer,
                value: null,
                onTap: null,
                trailing: PlayerMoreSeg<int>(
                  values: const [0, 15, 30, 60, 90],
                  labels: [
                    t.player.sleepOff,
                    asmrSleepDurationLabel(15),
                    asmrSleepDurationLabel(30),
                    asmrSleepDurationLabel(60),
                    asmrSleepDurationLabel(90),
                  ],
                  current: sleepMinutes ?? 0,
                  onPick: (value) => ref.read(sleepTimerProvider.notifier).start(value == 0 ? null : value),
                ),
              ),
              // The auto-hide pace: the segments — 常显, then the four
              // delays — written to huya's own store, not the room's.
              PlayerMoreRow(
                label: t.settings.controlsAutoHide,
                leading: DsIcons.clock,
                value: null,
                onTap: null,
                trailing: PlayerMoreSeg(
                  values: const [0, 2, 4, 6, 10],
                  labels: [t.settings.controlsAutoHideAlways, '2s', '4s', '6s', '10s'],
                  current: settings.controlsAutoHideSeconds,
                  onPick: (value) => unawaited(
                    ref.read(modulePlaybackSettingsProvider(PlayerModule.huya).notifier).setControlsAutoHideSeconds(
                      value,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: DsSpace.s12),
      ],
    );
  }
}

/// The video block's loading shape: the title, the uploader row and the
/// brief as bars where their words will stand.
final class _InfoSkeleton extends StatelessWidget {
  const _InfoSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: DsSpace.s12,
      children: [
        DsSkeleton(width: double.infinity, height: 20, strong: true),
        Row(
          spacing: DsSpace.s8,
          children: [
            DsSkeleton.circle(size: 40),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: DsSpace.s6,
                children: [DsSkeleton(width: 140, height: 14), DsSkeleton(width: 96, height: 12)],
              ),
            ),
          ],
        ),
        Row(spacing: DsSpace.s8, children: [DsSkeleton(width: 88, height: 30)]),
        DsSkeleton.block(width: double.infinity, height: 64),
        Row(
          spacing: DsSpace.s8,
          children: [
            DsSkeleton(width: 64, height: 22),
            DsSkeleton(width: 72, height: 22),
            DsSkeleton(width: 56, height: 22),
          ],
        ),
      ],
    );
  }
}

/// The related rail's loading shape: three rows of cover block and words —
/// the rail cut's narrower cover when the rows land in the side column.
final class _RelatedSkeleton extends StatelessWidget {
  const _RelatedSkeleton({required this.compact});

  /// Whether the rows draw the side column's cut.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final coverWidth = compact ? 104.0 : 148.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: DsSpace.s8,
      children: [
        for (final _ in const [1, 2, 3])
          Row(
            spacing: DsSpace.s8,
            children: [
              DsSkeleton.block(width: coverWidth, height: coverWidth * 9 / 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: DsSpace.s6,
                  children: [
                    DsSkeleton(width: double.infinity, height: 14),
                    DsSkeleton(width: 120, height: 12),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }
}
