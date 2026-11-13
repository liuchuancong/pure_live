import 'dart:async' show StreamSubscription, Timer, unawaited;
import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/services.dart' show KeyDownEvent, KeyEvent, LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_device/live_device.dart'
    show PlatformScreenAwakeService, PlatformScreenOrientationService, ScreenAwakeService, ScreenOrientationService;
import 'package:live_iptv/live_iptv.dart';
import 'package:live_platform/live_platform.dart' show FormFactor;
import 'package:live_sites/live_sites.dart'
    show LivePlayFormatSource, LivePlayLine, LiveStreamFormat, inferStreamFormat;
import 'package:media_core/media_core.dart';
import 'package:media_core_live/media_core_live.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/iptv/controllers/iptv_browse_settings.dart' show iptvBrowseSettingsProvider;
import 'package:pure_live/modules/iptv/controllers/iptv_controller.dart' show iptvLibraryProvider;
import 'package:pure_live/modules/iptv/controllers/iptv_now_playing.dart'
    show IptvNowPlayingController, iptvNowPlayingProvider;
import 'package:pure_live/modules/iptv/controllers/iptv_recent.dart' show iptvRecentProvider;
import 'package:pure_live/modules/iptv/controllers/iptv_reminders.dart' show IptvReminder, iptvRemindersProvider;
import 'package:pure_live/modules/iptv/controllers/iptv_user_agent.dart'
    show iptvHeadersWithUserAgent, iptvUserAgentProvider;
import 'package:pure_live/modules/iptv/views/iptv_guide_panel.dart' show catchupUrlOf, iptvClockLabel, showIptvGuide;
import 'package:pure_live/modules/iptv/views/iptv_zapper.dart' show IptvZapper;
import 'package:pure_live/modules/live/recorder/recorder.dart';
import 'package:pure_live/modules/live/room/panels/room_panel.dart' show showRoomSleepTimer;
import 'package:pure_live/modules/live/room/player/sleep_timer.dart' show SleepTimerController, sleepTimerProvider;
import 'package:pure_live/shared/shared.dart';

/// One IPTV channel on media_core's own player: the playlist entry's URL
/// and headers, the alternatives as the line menu, the guide's current
/// programme under the channel's name — no live-room machinery involved.
/// What a caller hands the player route: the channel it holds, and the past
/// programme to start on when the caller is the guide's replay row.
typedef IptvPlayLaunch = ({IptvChannel channel, EpgProgramme? catchupProgramme});

/// The picture's shape as the bar's menu cycles it — the reference's 画面比例
/// chip: the stream's own shape, a fixed 16:9 or 4:3 frame, or a picture
/// stretched or cropped to fill the window.
enum IptvAspectMode {
  /// The stream's own aspect, letterboxed by the playback fit setting.
  automatic,

  /// A 16:9 frame whatever the stream says.
  ratio16x9,

  /// A 4:3 frame.
  ratio4x3,

  /// Stretched to the window.
  fill,

  /// Cropped to the window.
  zoom,
}

/// The menu's name for one aspect mode.
String iptvAspectLabel(Translations t, IptvAspectMode mode) => switch (mode) {
  IptvAspectMode.automatic => t.iptv.aspectAuto,
  IptvAspectMode.ratio16x9 => t.iptv.aspect16x9,
  IptvAspectMode.ratio4x3 => t.iptv.aspect4x3,
  IptvAspectMode.fill => t.iptv.aspectFill,
  IptvAspectMode.zoom => t.iptv.aspectZoom,
};

/// The number keys a remote or a keyboard may send: the top row and the
/// numeric keypad, both bound to the same digit.
const List<(LogicalKeyboardKey, int)> _kDigitKeys = [
  (LogicalKeyboardKey.digit0, 0),
  (LogicalKeyboardKey.digit1, 1),
  (LogicalKeyboardKey.digit2, 2),
  (LogicalKeyboardKey.digit3, 3),
  (LogicalKeyboardKey.digit4, 4),
  (LogicalKeyboardKey.digit5, 5),
  (LogicalKeyboardKey.digit6, 6),
  (LogicalKeyboardKey.digit7, 7),
  (LogicalKeyboardKey.digit8, 8),
  (LogicalKeyboardKey.digit9, 9),
  (LogicalKeyboardKey.numpad0, 0),
  (LogicalKeyboardKey.numpad1, 1),
  (LogicalKeyboardKey.numpad2, 2),
  (LogicalKeyboardKey.numpad3, 3),
  (LogicalKeyboardKey.numpad4, 4),
  (LogicalKeyboardKey.numpad5, 5),
  (LogicalKeyboardKey.numpad6, 6),
  (LogicalKeyboardKey.numpad7, 7),
  (LogicalKeyboardKey.numpad8, 8),
  (LogicalKeyboardKey.numpad9, 9),
];

/// The auto-reconnect ladder after the controller has given up: the
/// reference retries a channel that was on air five more times, waiting
/// 1s then doubling, 8s at most, and forgets the count once the channel
/// held twenty steady seconds.
const int _kReconnectMaxAttempts = 5;
const Duration _kReconnectStableWindow = Duration(seconds: 20);

final class IptvPlayPage extends ConsumerStatefulWidget {
  /// Plays [channelId]; [channel] is the card's own object when it opened
  /// the page (a deep link resolves it from the library instead), and
  /// [catchupProgramme] starts the player on that past programme instead of
  /// the live stream — the programme guide's replay action names it.
  const IptvPlayPage({required this.channelId, this.channel, this.catchupProgramme, this.embedded = false, super.key});

  /// The library channel id.
  final String channelId;

  /// The channel, when the caller already held it.
  final IptvChannel? channel;

  /// The programme to replay on open, or null for the live stream.
  final EpgProgramme? catchupProgramme;

  /// Lives inside the module's three-pane browser: the page head folds away
  /// (the channel list beside it names the channel and carries the heart),
  /// the escape key does not leave the page, and a channel handed back by
  /// the list switches the picture in place instead of replacing the route.
  final bool embedded;

  /// The aspect last picked from the bar's menu.
  ///
  /// Zapping replaces the route and with it this page's state, and the
  /// reference keeps the picture as the viewer set it while the channel
  /// changes; the choice outlives one channel, not the app.
  static IptvAspectMode lastAspect = IptvAspectMode.automatic;

  @override
  ConsumerState<IptvPlayPage> createState() => _IptvPlayPageState();
}

final class _IptvPlayPageState extends ConsumerState<IptvPlayPage> with WidgetsBindingObserver {
  LivePlaybackController? _playback;
  StreamSubscription<PlayerHandle>? _handles;
  StreamSubscription<PlayerCoreState>? _states;
  StreamSubscription<PlayerFailure>? _failures;
  StreamSubscription<GeometryState>? _geometry;
  PlayerHandle? _handle;
  PlayerCoreState _playbackState = PlayerCoreState.idle;
  IptvChannel? _channel;
  String? _error;

  /// Captured while the page is alive; `ref` is refused by the time
  /// dispose runs.
  late final RoomPresentationController _presentationNotifier;

  /// The sleep timer this page owns while it stands: its fire stops this
  /// channel, and leaving disarms it.
  late final SleepTimerController _sleepTimerNotifier;

  /// The presentation mode, followed through a manual listener for the same
  /// reason: the leaving page reads its own field, not `ref`.
  PresentationMode _presentationMode = PresentationMode.normal;

  /// The picture's aspect as the engine last reported it: the fullscreen
  /// orientation policy and the compact window's shape read it.
  double _aspectRatio = 0;

  /// The phone's orientation lock (inert on a desktop).
  final ScreenOrientationService _screenOrientation = const PlatformScreenOrientationService();

  /// The player's identity across the page's layout branches: the compact
  /// window draws only the picture, and a keyed reparent keeps the surface
  /// (and the engine's view) instead of tearing it down for the move.
  final GlobalKey _playerKey = GlobalKey();

  /// The page's own mute and volume, the app-wide mute that overrides the
  /// former, and the platform default the page starts on.
  bool _muted = false;
  bool _globalMute = false;
  double _volume = 1;

  /// The volume a drag on the picture or a wheel is setting right now; null
  /// while no gesture shows it. The chip fades on its own, as the room's does.
  double? _volumeHud;
  Timer? _volumeHudTimer;
  double _dragVolume = 1;

  /// Sound only: the channel keeps playing and the picture is put away — a
  /// radio-shaped way to listen to a station while the desk work continues.
  bool _audioOnly = false;

  /// The Android background-playback gate and the channel it paused.
  BackgroundPlaybackGate? _backgroundGate;
  String? _backgroundPausedChannel;

  /// The programme being replayed, null while the live stream plays.
  EpgProgramme? _catchup;

  /// The digits typed for a channel number, and the timer that commits them
  /// after the reference's two seconds without another key.
  String _digits = '';
  Timer? _digitTimer;

  /// The picture's shape as the bar's menu last set it.
  late IptvAspectMode _aspect = IptvPlayPage.lastAspect;

  /// Whether the channel panel (groups, channels, guide) covers the picture.
  bool _zapperOpen = false;

  /// Whether the info strip along the picture's bottom edge is showing, and
  /// the timer that hides it — the reference shows it after a switch, not
  /// forever.
  bool _infoVisible = true;
  Timer? _infoTimer;

  /// The channel's favourite flag as this page last saw it: the library owns
  /// the fact, and this page's own channel snapshot does not refresh.
  bool _favourite = false;

  /// The module's on-air mark: the channel list beside the pane reads it to
  /// draw its tally. Captured while alive — dispose cannot read `ref`.
  late final IptvNowPlayingController _nowPlaying;

  /// Takes the keyboard back when the channel panel closes.
  final FocusNode _pageFocus = FocusNode(debugLabel: 'iptv-play');

  /// The module's reminders, followed while this page is on screen so one
  /// that comes due switches the picture to its channel.
  StreamSubscription<IptvReminder>? _reminders;

  /// The addresses behind the current play: the playlist's own first, then
  /// its alternatives (or the single catch-up address).
  List<String> _urls = const [];
  int _lineIndex = 0;

  /// Whether this channel was ever on air: the auto-reconnect only revives
  /// a stream that played — a channel that never opened has a dead address,
  /// and retrying it five times only delays the error.
  bool _hadPlayed = false;

  /// The auto-reconnect state: how many times in a row the controller has
  /// given up on this channel, the timer holding the next attempt, and the
  /// steady-playback window that clears the count.
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  Timer? _reconnectStableTimer;

  /// The pointer-idle rule: the cursor and the control bar leave the
  /// picture after a rest and any move brings them back.
  bool _cursorHidden = false;
  bool _barVisible = true;
  Timer? _cursorTimer;

  /// Keeps the on-air slot's clock moving while the page stays open.
  Timer? _tick;

  /// The display stays awake while the channel plays.
  final ScreenAwakeService _screenAwake = const PlatformScreenAwakeService();
  bool _screenHeld = false;

  @override
  void initState() {
    super.initState();
    // Riverpod refuses `ref` once the element is defunct, and dispose() runs
    // exactly there: the leaving page exits its presentation mode through a
    // notifier captured while it was alive.
    _presentationNotifier = ref.read(roomPresentationProvider.notifier);
    ref.listenManual(roomPresentationProvider, (_, next) => _presentationMode = next, fireImmediately: true);
    // The sleep timer must stop this channel, not some global notion of one.
    _sleepTimerNotifier = ref.read(sleepTimerProvider.notifier);
    _sleepTimerNotifier.onFire_ = _onSleepFire;
    WidgetsBinding.instance.addObserver(this);
    _globalMute = ref.read(playbackSettingsProvider).globalMute;
    _volume = ref.read(playbackSettingsProvider.notifier).volume;
    _backgroundGate = BackgroundPlaybackGate(
      backgroundEnabled: () => ref.read(playbackSettingsProvider).backgroundPlay,
      shouldPause: () {
        final presentation = ref.read(roomPresentationProvider);
        return _playbackState.playing &&
            presentation != PresentationMode.pip &&
            presentation != PresentationMode.floating;
      },
      pause: () async {
        _backgroundPausedChannel = _channel?.id;
        await _playback?.pause();
      },
      canResume: () =>
          _backgroundPausedChannel != null &&
          _playback != null &&
          !_playbackState.playing &&
          _channel?.id == _backgroundPausedChannel,
      resume: () async {
        _backgroundPausedChannel = null;
        await _playback?.resume();
      },
    );
    _nowPlaying = ref.read(iptvNowPlayingProvider.notifier);
    _channel = widget.channel ?? ref.read(iptvLibraryProvider).value?.channelById(widget.channelId);
    _favourite = _channel?.favorite ?? false;
    _reminders = ref.read(iptvRemindersProvider.notifier).fired.listen(_onReminder);
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _revealPointer();
        unawaited(_open());
      }
    });
  }

  @override
  void didUpdateWidget(IptvPlayPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The module's channel list drives the embedded pane: a newly selected
    // row is a switch, made in place — no route, no teardown of the pane.
    final next = widget.channel;
    if (next != null && next.id != oldWidget.channel?.id && next.id != _channel?.id) {
      _switchTo(next);
    }
  }

  @override
  void dispose() {
    _sleepTimerNotifier.onFire_ = null;
    Timer.run(() => _sleepTimerNotifier.start(null));
    WidgetsBinding.instance.removeObserver(this);
    _backgroundGate?.dispose();
    _backgroundGate = null;
    _tick?.cancel();
    _digitTimer?.cancel();
    _infoTimer?.cancel();
    _volumeHudTimer?.cancel();
    _reconnectTimer?.cancel();
    _reconnectStableTimer?.cancel();
    _cursorTimer?.cancel();
    _pageFocus.dispose();
    unawaited(_reminders?.cancel() ?? Future<void>.value());
    unawaited(_screenAwake.disable().catchError((Object _) {}));
    _nowPlaying.clear();
    final player = _handle?.id;
    if (player != null && _presentationMode != PresentationMode.normal) {
      unawaited(_presentationNotifier.exit(player));
    }
    unawaited(_handles?.cancel() ?? Future<void>.value());
    unawaited(_states?.cancel() ?? Future<void>.value());
    unawaited(_failures?.cancel() ?? Future<void>.value());
    unawaited(_geometry?.cancel() ?? Future<void>.value());
    _geometry = null;
    // The session's dispose is queued behind whatever the playback is doing
    // (an open still dialling a dead address takes its whole budget); mute
    // first — it lands at once — then pause, so the channel cannot sound over
    // the page the viewer returned to while that queue drains.
    final handle = _handle;
    if (handle != null) {
      unawaited(handle.setMute(muted: true).catchError((Object _) {}));
    }
    unawaited(_playback?.pause() ?? Future<void>.value());
    unawaited(_playback?.dispose() ?? Future<void>.value());
    super.dispose();
  }

  Future<void> _open() async {
    final channel = _channel;
    if (channel == null) {
      setState(() => _error = context.t.iptv.playerChannelMissing);
      return;
    }
    _favourite = channel.favorite;
    _nowPlaying.set(channel.id);
    _showInfo();
    // The module's own 最近观看: opening a channel is what the record follows,
    // whether it plays live or from the guide's catch-up.
    unawaited(ref.read(iptvRecentProvider.notifier).record(channel.id));
    // The programme guide can hand the player a past programme; its replay
    // address comes from the playlist's own catch-up attributes.
    final replay = widget.catchupProgramme;
    if (replay != null) {
      await _playCatchup(replay);
      return;
    }
    final urls = <String>{
      if (channel.entry.url.trim().isNotEmpty) channel.entry.url.trim(),
      for (final alternative in channel.entry.alternatives)
        if (alternative.trim().isNotEmpty) alternative.trim(),
    }.toList();
    if (urls.isEmpty) {
      setState(() => _error = context.t.iptv.playerNoStream);
      return;
    }
    setState(() {
      _catchup = null;
      _error = null;
    });
    await _play(urls, channel);
  }

  /// Replays [programme] from the provider's catch-up URL; a channel whose
  /// playlist cannot build one says why instead of opening the live stream
  /// under the programme's name.
  Future<void> _playCatchup(EpgProgramme programme) async {
    final channel = _channel;
    if (channel == null) return;
    final url = catchupUrlOf(channel, programme);
    if (url == null) {
      if (mounted) showDsToast(context: context, title: context.t.iptv.catchupFailed, status: DsStatus.danger);
      return;
    }
    setState(() {
      _catchup = programme;
      _error = null;
    });
    await _play([url], channel);
  }

  Future<void> _play(List<String> urls, IptvChannel channel) async {
    if (mounted) {
      setState(() {
        _urls = List.of(urls);
        _lineIndex = 0;
      });
    }
    // The playlist line's own User-Agent wins; otherwise the viewer's custom
    // one is sent, matching what the importer uses for downloads.
    final playbackHeaders = iptvHeadersWithUserAgent(channel.entry.headers.asMap(), ref.read(iptvUserAgentProvider));
    final headers = playbackHeaders.isEmpty ? null : SourceHeaders(playbackHeaders);
    final replay = _catchup;
    final idPrefix = replay == null
        ? 'iptv:${channel.id}'
        : 'iptv:${channel.id}:catchup:${replay.start.millisecondsSinceEpoch}';
    final sources = [
      for (final (index, url) in urls.indexed)
        PlayerSource.of(
          id: SourceId('$idPrefix:$index'),
          uri: Uri.parse(url),
          type: SourceType.live,
          protocol: SourceProtocol.fromScheme(Uri.parse(url).scheme),
          format: SourceFormat.fromUri(Uri.parse(url)),
          headers: headers,
          title: replay?.title ?? channel.entry.name,
        ),
    ];
    final playback = _playback ?? LivePlaybackController(ref.read(playerKernelProvider));
    _playback = playback;
    // A fresh play (a channel switch, a line pick, back to live) supersedes
    // whatever reconnect was waiting; the failure count restarts with it.
    _cancelReconnect();
    _reconnectStableTimer?.cancel();
    _reconnectAttempts = 0;
    _states ??= playback.onStateChanged.listen(_onPlaybackState);
    _handles ??= playback.onHandleChanged.listen((handle) {
      // The audio and engine options below read the stored settings off
      // `ref`; an event in flight past dispose must not reach them.
      if (!mounted) return;
      setState(() => _handle = handle);
      unawaited(_applyAudio(handle));
      unawaited(_applyEngineOptions(handle));
      _bindGeometry(handle);
    });
    _failures ??= playback.onError.listen(_onPlaybackFailure);
    await playback.play(
      LiveSourceRequest(
        sources: sources,
        title: replay?.title ?? channel.entry.name,
        allowEngineFallback: true,
        engineOptions: _storedEngineOptions(),
      ),
      preferredBackend: ref.read(playerKernelBackendProvider).id,
    );
  }

  Future<void> _retry() async {
    final playback = _playback;
    if (playback == null) {
      await _open();
      return;
    }
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectStableTimer?.cancel();
    _reconnectAttempts = 0;
    setState(() => _error = null);
    await playback.retry();
  }

  /// The state stream's page-side half: a channel that reached playing has
  /// proven its address, a pause is the viewer taking over, and an error the
  /// engine recovered from leaves by itself.
  void _onPlaybackState(PlayerCoreState state) {
    if (!mounted) return;
    final wasPlaying = _playbackState.playing;
    setState(() => _playbackState = state);
    if (state.playing && !wasPlaying) _onPlaying();
    if (!state.playing && (_cursorHidden || !_barVisible)) _revealPointer();
    if (state.paused) _cancelReconnect();
  }

  /// The channel is on air again: forget the pending attempt and start the
  /// steady window that clears the failure count — one clean twenty seconds
  /// and the next drop counts as a fresh trouble, not a fifth round.
  void _onPlaying() {
    _hadPlayed = true;
    _cancelReconnect();
    if (_error != null) setState(() => _error = null);
    _reconnectStableTimer?.cancel();
    _reconnectStableTimer = Timer(_kReconnectStableWindow, () => _reconnectAttempts = 0);
  }

  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  /// The controller's own ladder has run out — its sweep, its bounded retry
  /// rounds and the offline probe all failed — and the failure is final as
  /// far as it will go. The reference keeps trying a channel that was on
  /// air: five more attempts, one second then doubling, eight at most. A
  /// channel that never played fails for real here; retrying a dead address
  /// five times only delays the message.
  void _onPlaybackFailure(PlayerFailure failure) {
    if (!mounted) return;
    final message = failure.message ?? failure.code.name;
    if (!_hadPlayed || _reconnectAttempts >= _kReconnectMaxAttempts) {
      setState(() => _error = message);
      return;
    }
    _reconnectAttempts += 1;
    final attempt = _reconnectAttempts;
    final delay = Duration(seconds: attempt <= 3 ? 1 << (attempt - 1) : 8);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      if (!mounted) return;
      setState(() {});
      // The engine may have beaten the timer to a recovery; a stream that
      // is on its way again must not be torn down to repeat the attempt.
      if (_playbackState.playing || _playbackState.buffering || _playbackState.opening) return;
      unawaited(_playback?.retry() ?? Future<void>.value());
    });
    // The countdown strip replaces the card while an attempt waits; the
    // next failure, if it comes, re-enters here and counts again.
    setState(() => _error = null);
  }

  /// The pointer-idle rule: a rest takes the cursor and the control bar
  /// while the picture plays, any move gives both back — the reference's
  /// player, where a still hand leaves nothing between the viewer and the
  /// picture.
  void _revealPointer() {
    _cursorTimer?.cancel();
    if ((_cursorHidden || !_barVisible) && mounted) {
      setState(() {
        _cursorHidden = false;
        _barVisible = true;
      });
    }
    // The station's own seconds name the rest; zero is 常显 — the bar and
    // the cursor stay while the channel plays.
    final seconds = ref.read(playbackSettingsProvider).controlsAutoHideSeconds;
    if (seconds <= 0) return;
    _cursorTimer = Timer(Duration(seconds: seconds), () {
      if (!mounted || !_playbackState.playing) return;
      setState(() {
        _cursorHidden = true;
        _barVisible = false;
      });
    });
  }

  /// A desktop owns the window-fullscreen verb; a phone has no window to
  /// widen.
  bool get _desktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  /// The desktop's window-fullscreen: the app window goes full-bleed — the
  /// channel edge to edge without the system fullscreen's device turn.
  Future<void> _toggleWindowFullscreen() async {
    final handle = _handle;
    if (handle == null) return;
    await ref.read(roomPresentationProvider.notifier).toggleWindowFullscreen(handle.id);
  }

  /// The sleep timer's end: the channel pauses where it stands, said with
  /// the room's own toast.
  void _onSleepFire() {
    unawaited(_handle?.pause() ?? Future<void>.value());
    if (mounted) showDsToast(context: context, title: context.t.room.sleepDone);
  }

  /// The picture's double click: fullscreen in, fullscreen out — the
  /// keyboard twin already binds F.
  void _togglePictureFullscreen() {
    final handle = _handle;
    if (handle == null) return;
    final controller = ref.read(roomPresentationProvider.notifier);
    final current = ref.read(roomPresentationProvider);
    unawaited(current == PresentationMode.normal ? controller.toggleFullscreen(handle.id) : controller.exit(handle.id));
  }

  /// Moves to another address the playlist carries for this channel, without
  /// re-reading the list: the player switches source and keeps its session.
  Future<void> _selectLine(int index) async {
    if (index == _lineIndex || index < 0 || index >= _urls.length) return;
    setState(() {
      _lineIndex = index;
      _error = null;
    });
    await _playback?.switchLine(index);
  }

  /// Steps through the visible channels in zap order, wrapping at the ends;
  /// the page is replaced so the old engine is torn down by its own dispose.
  void _switchChannel(int delta) {
    final channel = _channel;
    final library = ref.read(iptvLibraryProvider).value;
    if (channel == null || library == null) return;
    // The viewer's reversal applies here too: the reference's up key walks
    // down the list when 换台反转 is on.
    final reverse = ref.read(iptvBrowseSettingsProvider).reverseChannels;
    final step = library.zapSequence(reverse: reverse).step(delta, fromId: channel.id);
    final next = step.channel;
    if (next == null || !step.needsLoad) return;
    _openChannel(next);
  }

  /// Switches the picture to [channel] by replacing this route, so the old
  /// engine is torn down by its own dispose and the new one starts clean.
  void _openChannel(IptvChannel channel) {
    if (!mounted || channel.id == _channel?.id) return;
    if (widget.embedded) {
      _switchTo(channel);
      return;
    }
    context.pushReplacement(RouteNames.iptvPlay.replaceFirst(':channelId', channel.id), extra: channel);
  }

  /// Shows [channel] in this very pane: the state's channel swaps and the
  /// play re-runs on it — the same sequence a route replacement ran, minus
  /// the route.
  void _switchTo(IptvChannel channel) {
    if (!mounted || channel.id == _channel?.id) return;
    setState(() => _channel = channel);
    unawaited(_open());
  }

  /// Types one digit of a channel number; the reference swaps channels after
  /// two seconds without another key, at four digits at most.
  void _typeDigit(int digit) {
    if (_channel == null) return;
    _digits = _digits.length >= 4 ? '$digit' : '$_digits$digit';
    _digitTimer?.cancel();
    _digitTimer = Timer(const Duration(seconds: 2), () => unawaited(_commitDigits()));
    setState(() {});
  }

  /// Looks the typed number up and switches to that channel, or says there is
  /// none — a typed number is a lookup, not a number of steps.
  Future<void> _commitDigits() async {
    _digitTimer?.cancel();
    _digitTimer = null;
    final typed = _digits;
    if (typed.isEmpty) return;
    final number = int.tryParse(typed);
    setState(() => _digits = '');
    if (number == null) return;
    final channel = ref.read(iptvLibraryProvider).value?.channelByNumber(number);
    if (channel == null) {
      if (mounted) {
        showDsToast(
          context: context,
          title: context.t.iptv.digitNoChannel(number: number),
          status: DsStatus.warning,
        );
      }
      return;
    }
    _openChannel(channel);
  }

  /// The channel the typed digits name so far, for the on-screen display.
  IptvChannel? get _digitPreview {
    final number = int.tryParse(_digits);
    return number == null ? null : ref.read(iptvLibraryProvider).value?.channelByNumber(number);
  }

  /// Shows the bottom info strip for the app's own pace (画面与浮窗): zero
  /// is 常显, the strip stays until the next channel change puts it away.
  void _showInfo() {
    _infoTimer?.cancel();
    final seconds = ref.read(playbackSettingsProvider).controlsAutoHideSeconds;
    if (seconds > 0) {
      _infoTimer = Timer(Duration(seconds: seconds), () {
        if (mounted) setState(() => _infoVisible = false);
      });
    }
    if (!_infoVisible && mounted) setState(() => _infoVisible = true);
  }

  /// The remote's OK key raises the info strip, the tap path's keyboard twin;
  /// a focused control keeps the key for its own activation.
  KeyEventResult _onPageKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (FocusManager.instance.primaryFocus != node) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.select && event.logicalKey != LogicalKeyboardKey.enter) {
      return KeyEventResult.ignored;
    }
    _showInfo();
    return KeyEventResult.handled;
  }

  void _openZapper() {
    if (_channel == null) return;
    setState(() => _zapperOpen = true);
  }

  void _closeZapper() {
    if (!_zapperOpen) return;
    setState(() => _zapperOpen = false);
    // The panel's focus node dies with it; the page takes the keys back.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _pageFocus.requestFocus();
    });
  }

  /// A reminder came due: when it names another channel, the picture follows
  /// it the way the reference's 预约 does. The toast is the controller's.
  void _onReminder(IptvReminder reminder) {
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    if (_channel?.id == reminder.channelId) return;
    final channel = ref.read(iptvLibraryProvider).value?.channelById(reminder.channelId);
    if (channel == null) return;
    _closeZapper();
    _openChannel(channel);
  }

  /// Replays [programme] on [channel]: on this page's own channel the player
  /// switches source, on another one the route is replaced with the programme
  /// to replay so the new channel opens on it.
  Future<void> _replayOn(IptvChannel channel, EpgProgramme programme) async {
    if (channel.id == _channel?.id) {
      await _playCatchup(programme);
      return;
    }
    if (!mounted) return;
    context.pushReplacement(
      RouteNames.iptvPlay.replaceFirst(':channelId', channel.id),
      extra: (channel: channel, catchupProgramme: programme),
    );
  }

  /// Toggles the channel's favourite flag, the same library fact the channel
  /// list's heart writes.
  Future<void> _toggleFavourite(IptvChannel channel) async {
    final library = ref.read(iptvLibraryProvider).value;
    if (library == null) return;
    final next = !_favourite;
    await library.toggleFavorite(channel.id);
    if (mounted) setState(() => _favourite = next);
  }

  /// Sends the address currently playing to a DLNA receiver.
  void _cast(IptvChannel channel) {
    final url = _lineIndex < _urls.length ? _urls[_lineIndex] : '';
    if (url.isEmpty) return;
    final line = LivePlayLine.of(
      url: url,
      format: inferStreamFormat(url) ?? LiveStreamFormat.other,
      formatSource: LivePlayFormatSource.inferred,
      headers: iptvHeadersWithUserAgent(channel.entry.headers.asMap(), ref.read(iptvUserAgentProvider)),
      lineLabel: channel.entry.name,
    );
    unawaited(showCastDialog(context, line: line, title: channel.entry.name));
  }

  /// The recording identity the recorder centre files this channel under —
  /// the `platform:roomId` shape every task carries.
  String get _recordingId => '$kIptvRecordingPlatform:${_channel?.id ?? ''}';

  /// Opens the shared preview page on this channel's take, with the other
  /// channels' takes beside it: IPTV records into the recording centre's own
  /// task library, so this is that list filtered to the platform rather than
  /// a second store of files. The files are walked here, on the press, and a
  /// take whose folder came up empty is said so instead of showing a
  /// neighbour from another channel.
  Future<void> _openRecordings() async {
    final channel = _channel;
    if (channel == null) return;
    final t = context.t;
    // Every take of this channel, read from the tree the recorder wrote. The
    // task store keys one row per channel, so a list built from it can only ever
    // show the last session — the second-to-last recording exists on disk and
    // would stay unreachable from here.
    final takes = [
      for (final take in ref.read(recordingLibraryProvider).value ?? const <RecordingTake>[])
        if (take.platformId == kIptvRecordingPlatform && take.roomId == channel.id && take.playable) take,
    ];
    final newest = takes.isEmpty ? null : takes.first;
    if (newest == null) {
      showDsToast(context: context, title: t.recorder.previewUnavailable, status: DsStatus.warning);
      return;
    }
    // The same door the module's recording page uses: the player's list groups
    // by day and channel, and a file deleted inside it marks its row.
    await playRecordingTake(context, ref, around: takes, take: newest, platformName: (_) => t.common.moduleIptv);
  }

  /// Starts or stops the channel's recording; answers the engine's reason
  /// when the action failed, null on success. A playlist address is static,
  /// so the capture needs no URL refresher, room or danmaku.
  Future<String?> _toggleRecording() async {
    final channel = _channel;
    if (channel == null) return 'no channel';
    final engine = ref.read(recorderEngineProvider);
    if (engine.isRecording(_recordingId)) return await engine.stop(_recordingId);
    final url = _lineIndex < _urls.length ? _urls[_lineIndex] : '';
    if (url.isEmpty) return 'no line to record';
    final line = LivePlayLine.of(
      url: url,
      format: inferStreamFormat(url) ?? LiveStreamFormat.other,
      formatSource: LivePlayFormatSource.inferred,
      headers: iptvHeadersWithUserAgent(channel.entry.headers.asMap(), ref.read(iptvUserAgentProvider)),
      lineLabel: channel.entry.name,
    );
    final task = RecordingTask(
      id: _recordingId,
      platform: kIptvRecordingPlatform,
      roomId: channel.id,
      roomTitle: channel.entry.name,
      state: RecordingTaskState.stopped,
      startedAt: DateTime.now().toUtc(),
    );
    return await engine.start(task, line);
  }

  /// The record verb's whole flow: flips the capture and answers with a
  /// toast. Shared by the route page's head and the embedded pane's bar.
  Future<void> _recordWithToast() async {
    final t = context.t;
    final channel = _channel;
    if (channel == null) return;
    final wasRecording = ref
        .read(recordingTasksProvider)
        .tasks
        .any((task) => task.id == 'iptv:${channel.id}' && task.state == RecordingTaskState.recording);
    final failure = await _toggleRecording();
    if (!mounted) return;
    showDsToast(
      context: context,
      title: failure == null ? (wasRecording ? t.room.recordStopped : t.room.recordStarted) : t.room.recordFailed,
      status: failure == null ? DsStatus.success : DsStatus.danger,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _backgroundGate?.handleLifecycle(state);
  }

  bool get _effectivelyMuted => _muted || _globalMute;

  /// Feeds the picture's real size to the presentation drivers and keeps it
  /// for the fullscreen orientation policy: the compact window locks to the
  /// stream's shape, and a landscape channel turns the phone sideways.
  void _bindGeometry(PlayerHandle handle) {
    unawaited(_geometry?.cancel() ?? Future<void>.value());
    _geometry = handle.geometryController.state.listen((state) {
      if (!mounted) return;
      final size = state.geometry.videoSize;
      if (size.width <= 0 || size.height <= 0) return;
      _aspectRatio = size.width / size.height;
      ref.read(fullscreenDriverProvider).onVideoSize(size.width, size.height);
      ref.read(pipDriverProvider).onVideoSize(size.width, size.height);
    });
  }

  /// Enters or leaves picture-in-picture; a host that refuses (iOS without
  /// an on-screen player layer, a device without the window) says so.
  Future<void> _togglePip(PlayerHandle handle) async {
    final accepted = await ref.read(roomPresentationProvider.notifier).togglePip(handle.id);
    if (accepted || !mounted) return;
    showDsToast(context: context, title: context.t.common.pipUnavailable);
  }

  /// Stops the channel from the compact window: stop the stream, then leave
  /// by the window's own close — the ✕ means "I am done watching", and a
  /// window that cannot close itself falls back to leaving the page.
  void _closeChannel() {
    final handle = _handle;
    unawaited(handle?.pause());
    final close = ref.read(roomLeaveProvider);
    if (close != null) {
      unawaited(close());
      return;
    }
    if (handle != null) unawaited(ref.read(roomPresentationProvider.notifier).exit(handle.id));
    context.pop();
  }

  Future<void> _applyAudio(PlayerHandle handle) async {
    try {
      await handle.setVolume(_volume);
      await handle.setMute(muted: _effectivelyMuted);
    } on Object {
      // A refused audio preference is not a playback failure.
    }
  }

  /// The engine options every IPTV channel keeps for its next line or
  /// recovery: hardware decoding and the player proxy.
  List<EngineOption> _storedEngineOptions() => playerStoredEngineOptions(
    hardwareDecoding: ref.read(playbackSettingsProvider).hardwareDecoding,
    tuning: ref.read(playerTuningProvider),
    proxy: ref.read(playerProxyProvider),
  );

  /// Routes and decodes this channel like every other live player; every
  /// handle gets the stored options, so a channel switch cannot keep an old
  /// decoder or route. [extra] carries the previous preset's key resets when
  /// a recipe change happens on the running channel.
  Future<void> _applyEngineOptions(PlayerHandle handle, {List<EngineOption> extra = const []}) async {
    try {
      await handle.applyEngineOptions(<EngineOption>[..._storedEngineOptions(), ...extra]);
    } on Object {
      // A refused engine option is not a playback failure.
    }
  }

  /// A custom-output or driver change applies to the running channel: the
  /// stored options feed the next line, the handle gets them now, and a
  /// changed video/audio output rebuilds the render context in place.
  Future<void> _applyTuning(PlayerTuning? previous, PlayerTuning next) async {
    final playback = _playback;
    if (playback != null) unawaited(playback.updateEngineOptions(_storedEngineOptions()));
    final handle = _handle;
    if (handle == null) return;
    await _applyEngineOptions(
      handle,
      extra: previous == null ? const <EngineOption>[] : playerPresetTransitionOptions(previous, next),
    );
    if (previous == null || !playerOutputChanged(previous, next)) return;
    try {
      await handle.rebuildEngine(reason: 'video output settings changed');
    } on Object {
      // A rebuild the engine refused must not fail the page.
    }
  }

  Future<void> _setVolume(double value) async {
    final clamped = value.clamp(0.0, 1.0);
    if (mounted) setState(() => _volume = clamped);
    final handle = _handle;
    if (handle == null) return;
    try {
      await handle.setVolume(clamped);
    } on Object {
      // Same as mute.
    }
  }

  /// The player bar's mute button. Unmuting while the app-wide mute is on
  /// clears that setting, so the button always does what its icon promises.
  Future<void> _toggleMute() async {
    final handle = _handle;
    if (handle == null) return;
    if (_globalMute && _effectivelyMuted) {
      _globalMute = false;
      _muted = false;
      unawaited(ref.read(playbackSettingsProvider.notifier).setGlobalMute(value: false));
    } else {
      _muted = !_effectivelyMuted;
    }
    if (mounted) setState(() {});
    await _applyAudio(handle);
  }

  /// Shows [value] on the picture's own volume chip, and lets it settle away a
  /// moment after the last move — the room's gesture, so a viewer learns it
  /// once and finds it on every player in the app.
  void _showVolumeHud(double value) {
    _volumeHudTimer?.cancel();
    setState(() => _volumeHud = value.clamp(0.0, 1.0));
    _volumeHudTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _volumeHud = null);
    });
  }

  void _beginVolumeDrag() {
    _dragVolume = _volume;
    _showVolumeHud(_dragVolume);
  }

  void _dragVolumeBy(double delta) {
    final next = (_dragVolume - delta / 220).clamp(0.0, 1.0);
    _dragVolume = next;
    _showVolumeHud(next);
    unawaited(_setVolume(next));
  }

  /// A wheel step takes the viewer's own share of the range (the 画质与音频
  /// setting), so a desktop mouse has a usable granularity without the slider.
  void _wheelVolume(double delta) {
    if (_handle == null) return;
    final step = ref.read(playbackSettingsProvider).volumeWheelStepPercent / 100;
    final next = (_volume + (delta > 0 ? -step : step)).clamp(0.0, 1.0);
    _showVolumeHud(next);
    unawaited(_setVolume(next));
  }

  /// 音频模式: keep the station's sound and put the picture away. A live TV
  /// stream has no seek, so this is the "listen while I work" mode rather than
  /// a battery saving.
  Future<void> _toggleAudioOnly() async {
    final handle = _handle;
    setState(() => _audioOnly = !_audioOnly);
    if (handle == null) return;
    try {
      await handle.setAudioOnly(audioOnly: _audioOnly);
    } on Object {
      // A kernel without the mode keeps the picture; the switch says what was
      // asked and the next channel gets the same try.
    }
  }

  /// Writes the frame the channel is showing into the viewer's screenshot
  /// folder, and says how it went.
  Future<void> _screenshot() async {
    final handle = _handle;
    if (handle == null) return;
    final file = await capturePlayerFrame(handle, ref.read(appPathsProvider).screenshots, prefix: 'pure_live_iptv');
    if (!mounted) return;
    final t = context.t;
    showDsToast(
      context: context,
      title: file == null ? t.room.screenshotFailed : t.room.screenshotSaved(name: file.uri.pathSegments.last),
      status: file == null ? DsStatus.danger : DsStatus.success,
    );
  }

  /// Holds the display awake exactly while the channel plays and the
  /// preference allows it.
  void _syncScreenWake(bool hold) {
    if (hold == _screenHeld) return;
    _screenHeld = hold;
    unawaited((hold ? _screenAwake.enable() : _screenAwake.disable()).catchError((Object _) {}));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    // The app-wide mute can change while this page is on screen; apply it
    // to the live handle without tearing the stream down.
    ref.listen(playbackSettingsProvider.select((settings) => settings.globalMute), (previous, next) {
      if (previous == next) return;
      if (mounted) setState(() => _globalMute = next);
      final current = _handle;
      if (current != null) unawaited(_applyAudio(current));
    });
    ref.listen(playerProxyProvider, (previous, next) {
      if (previous == next) return;
      final playback = _playback;
      if (playback != null) unawaited(playback.updateEngineOptions(_storedEngineOptions()));
    });
    ref.listen(playbackSettingsProvider.select((settings) => settings.hardwareDecoding), (previous, next) {
      if (previous == next) return;
      final playback = _playback;
      if (playback != null) unawaited(playback.updateEngineOptions(_storedEngineOptions()));
    });
    ref.listen(playerTuningProvider, (previous, next) {
      if (previous == next) return;
      unawaited(_applyTuning(previous, next));
    });
    // The room page's own rule, here too: a phone entering system fullscreen
    // asks the viewer's portrait policy which way it turns. The driver's exit
    // path puts the lock back.
    ref.listen(roomPresentationProvider, (previous, next) {
      if (next != PresentationMode.fullscreen || previous == PresentationMode.fullscreen) return;
      applyFullscreenOrientation(_screenOrientation, aspectRatio: _aspectRatio);
    });
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    // A full header outruns a narrow window: first the clock steps out, then
    // the channel verbs fold behind one entry — a title squeezed between ten
    // unlabelled glyphs stops naming the channel — while the arrow keys, the
    // zapper panel and the line menu keep doing the same work. The page fills
    // the window, so its width decides.
    final tv = ref.watch(platformRuntimeProvider).environment.runtime.formFactor == FormFactor.tv;
    final headerWidth = MediaQuery.sizeOf(context).width;
    final headerCompact = headerWidth < 560;
    final headerNarrow = headerWidth < 420;
    final channel = _channel;
    final handle = _handle;
    final muted = _effectivelyMuted;
    // The task store is the truth the record button follows, so a recording
    // started in an earlier visit still reads as running.
    final recordingTask = channel == null
        ? null
        : ref
              .watch(recordingTasksProvider)
              .tasks
              .where((task) => task.id == 'iptv:${channel.id}' && task.state == RecordingTaskState.recording)
              .firstOrNull;
    final recording = recordingTask != null;
    // The door stands where the store files a settled take under this channel.
    // Only the store's own facts are read here — this header redraws on the
    // minute tick, and a walk of the recordings folder would then run per
    // frame rather than per press.
    final hasTake =
        channel != null &&
        ref
            .watch(recordingTasksProvider)
            .tasks
            .any(
              (task) =>
                  task.id == 'iptv:${channel.id}' &&
                  task.state != RecordingTaskState.recording &&
                  !task.postProcessing &&
                  (task.filePath ?? '').trim().isNotEmpty,
            );
    final presentation = ref.watch(roomPresentationProvider);
    final presentationController = ref.read(roomPresentationProvider.notifier);
    // Fullscreen and the desktop compact window take the app's window; a
    // phone's picture-in-picture window floats over this page, which keeps
    // its layout.
    final ownsWindow = presentationController.modeOwnsWindow(presentation);
    final fullscreen = presentation != PresentationMode.normal;
    final playing = _playbackState.playing;
    _syncScreenWake(playing && ref.watch(keepScreenOnProvider));
    final library = ref.watch(iptvLibraryProvider).value;
    final browse = ref.watch(iptvBrowseSettingsProvider);
    final slot = channel == null ? null : library?.programmeSlot(channel);
    final canStep = channel != null && (library?.zapSequence(reverse: browse.reverseChannels).length ?? 0) > 1;
    final replay = _catchup;
    // The line under the title: a status pill (on air, upcoming, replaying)
    // followed by the programme's name — the reference's ON AIR tag inside a
    // muted facts line, not one flat string wearing the badge's colour. The
    // replay keeps its own accent pill whether or not the programme line is
    // being shown.
    final subtitle = replay != null
        ? (badge: t.iptv.playingCatchup, text: replay.title, accent: true)
        : !browse.showProgrammeLine
        ? null
        : switch (slot?.title) {
            final programme? => (
              badge: slot?.current != null ? t.iptv.onAir : t.iptv.upNext,
              text: programme,
              accent: slot?.current != null,
            ),
            _ => null,
          };
    // The header's verbs, spelled once: flat glyphs while the title has room,
    // and in the folded state the same list read as named rows — which is what
    // a menu is for, and what an icon-only header never said. The heart and the
    // recorder stay out of this list: their colour is the answer they carry,
    // and an entry that has to be opened to be read cannot report one.
    ({DsIconData icon, String label, VoidCallback onPressed, bool selected}) headerVerb(
      DsIconData icon,
      String label,
      VoidCallback onPressed, {
      bool selected = false,
    }) => (icon: icon, label: label, onPressed: onPressed, selected: selected);
    // The head's verbs, in the room top bar's two clusters: the picture's own
    // doors (the panel, the guide, the way back to live) first, the capture
    // cluster after — a hair line between them, the same grouping the bar
    // under the picture reads.
    final navVerbs = [
      if (channel != null) headerVerb(DsIcons.layoutGrid, t.iptv.zapperOpen, _openZapper, selected: _zapperOpen),
      if (channel != null)
        headerVerb(
          DsIcons.list,
          t.iptv.guideTitle,
          () => unawaited(
            showIptvGuide(context, channel: channel, catchup: _catchup, onCatchup: _playCatchup, onBackToLive: _open),
          ),
        ),
      if (replay != null) headerVerb(DsIcons.radio, t.iptv.backToLive, () => unawaited(_open())),
    ];
    final demoVerbs = [
      if (channel != null && !headerNarrow) headerVerb(DsIcons.cast, t.room.cast, () => _cast(channel)),
      // A channel ends itself when the viewer falls asleep: the timer's
      // panel reads the same choices the room's reads.
      if (channel != null) headerVerb(DsIcons.timer, t.room.sleep, () => unawaited(showRoomSleepTimer(context))),
      if (hasTake) headerVerb(DsIcons.listVideo, t.iptv.viewRecordings, () => unawaited(_openRecordings())),
    ];
    final verbs = [...navVerbs, ...demoVerbs];
    final headerActions = [
      if (headerCompact && verbs.isNotEmpty)
        DsMenuAnchor(
          semanticLabel: t.common.more,
          align: DsAlign.end,
          items: [
            for (final verb in verbs)
              DsMenuItem(
                leading: DsIcon(verb.icon),
                label: Text(verb.label),
                checked: verb.selected ? true : null,
                checkRole: DsMenuCheckRole.checkbox,
                onPressed: verb.onPressed,
              ),
          ],
          builder: (context, controller, _) =>
              _IconButton(semanticLabel: t.common.more, icon: DsIcons.ellipsisVertical, onPressed: controller.toggle),
        )
      else ...[
        for (final verb in navVerbs)
          _IconButton(semanticLabel: verb.label, icon: verb.icon, selected: verb.selected, onPressed: verb.onPressed),
        if (demoVerbs.isNotEmpty) ...[
          const _HeadDivider(),
          for (final verb in demoVerbs)
            _IconButton(semanticLabel: verb.label, icon: verb.icon, selected: verb.selected, onPressed: verb.onPressed),
        ],
      ],
    ];
    void leave() {
      if (ownsWindow && handle != null) {
        unawaited(presentationController.exit(handle.id));
      } else if (widget.embedded) {
        // The pane sits inside the module's page; its escape exits a
        // fullscreen it owns and otherwise stays put.
      } else {
        context.pop();
      }
    }

    // The compact window is the whole app window: the page's header and
    // control bar would be squeezed into it, so only the picture and a way
    // out are drawn. The window hides its own caption, so the strip below is
    // the only way back.
    if (presentation == PresentationMode.pip && presentationController.pipOwnsWindow) {
      // The small window keeps its page's keys: Escape is the way back to it,
      // I raises the stream's figures over the picture. The autofocus keeps
      // the bindings live with nothing else in the window to hold focus.
      return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () {
            if (handle != null) unawaited(presentationController.exit(handle.id));
          },
          if (!tv)
            const SingleActivator(LogicalKeyboardKey.keyI): () =>
                ref.read(playerStatsVisibleProvider.notifier).toggle(),
        },
        child: Focus(
          autofocus: true,
          child: ColoredBox(
            color: OnVideoColors.ground,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (handle != null)
                  MediaPlayerView(key: _playerKey, handle: handle, fit: ref.watch(playbackSettingsProvider).fit.boxFit),
                PositionedDirectional(
                  start: 0,
                  end: 0,
                  child: _PipStrip(
                    title: channel == null ? t.common.appTitle : channel.entry.name,
                    playing: playing,
                    muted: muted,
                    onDrag: () =>
                        unawaited(ref.read(windowsPipWindowProvider)?.startDragging() ?? Future<void>.value()),
                    onPlayPause: () => unawaited(_playback?.togglePlayPause() ?? Future<void>.value()),
                    onMute: handle == null ? null : () => unawaited(_toggleMute()),
                    onRestore: handle == null ? null : () => unawaited(presentationController.exit(handle.id)),
                    onClose: _closeChannel,
                  ),
                ),
                // The stream's own numbers, over the small window's picture.
                if (handle case final player? when ref.watch(playerStatsVisibleProvider))
                  Positioned.fill(
                    child: IgnorePointer(child: PlayerStatsOverlay(handle: player)),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return CallbackShortcuts(
      bindings: <SingleActivator, VoidCallback>{
        // A remote's up and down keys walk the channel list, as the
        // reference's zapping does; the bar's own buttons keep the rest.
        // Left opens the panel it walks: groups, channels and the guide.
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => _switchChannel(-1),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () => _switchChannel(1),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): _openZapper,
        const SingleActivator(LogicalKeyboardKey.escape): leave,
        // Space plays and pauses, the baseline the other players already bind.
        const SingleActivator(LogicalKeyboardKey.space): () =>
            unawaited(_playback?.togglePlayPause() ?? Future<void>.value()),
        // The stream's own figures: the key every player answers to.
        if (!tv)
          const SingleActivator(LogicalKeyboardKey.keyI): () => ref.read(playerStatsVisibleProvider.notifier).toggle(),
        // The reference's number keys: four digits at most, two seconds
        // between the last key and the switch.
        for (final (key, digit) in _kDigitKeys) SingleActivator(key): () => _typeDigit(digit),
        const SingleActivator(LogicalKeyboardKey.keyF): () {
          if (handle == null) return;
          final controller = ref.read(roomPresentationProvider.notifier);
          unawaited(
            presentation == PresentationMode.normal
                ? controller.toggleFullscreen(handle.id)
                : controller.exit(handle.id),
          );
        },
      },
      child: Focus(
        focusNode: _pageFocus,
        // The embedded pane sits beside the channel list: taking the page's
        // first focus would steal it from the search field the pane serves.
        autofocus: !widget.embedded,
        onKeyEvent: _onPageKey,
        child: MouseRegion(
          cursor: _cursorHidden ? SystemMouseCursors.none : MouseCursor.defer,
          onHover: (_) => _revealPointer(),
          child: ColoredBox(
            color: colors.overlay,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!widget.embedded)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(DsSpace.s8, DsSpace.s8, DsSpace.s16, DsSpace.s8),
                      child: Row(
                        spacing: DsSpace.s8,
                        children: [
                          _IconButton(
                            semanticLabel: t.common.close,
                            icon: DsIcons.chevronLeft,
                            onPressed: () => context.pop(),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: DsSpace.s3,
                              children: [
                                Text(
                                  channel == null
                                      ? t.iptv.playerOpening
                                      : [
                                          if (browse.showChannelNumber && channel.number != null) '${channel.number}',
                                          channel.entry.name,
                                        ].join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.typography.title.copyWith(color: colors.text),
                                ),
                                if (subtitle case final sub?)
                                  Row(
                                    spacing: DsSpace.s6,
                                    children: [
                                      _HeaderStatusBadge(label: sub.badge, accent: sub.accent),
                                      Flexible(
                                        child: Text(
                                          sub.text,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.typography.caption.copyWith(color: colors.textMuted),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                          // The reference's corner clock, on the viewer's switch:
                          // the page's minute tick already redraws it. The first
                          // decoration a narrow header drops.
                          if (browse.showClock && !headerCompact)
                            Text(
                              iptvClockLabel(DateTime.now()),
                              style: theme.typography.numeric(
                                theme.typography.caption.copyWith(color: colors.textMuted),
                              ),
                            ),
                          if (channel != null)
                            _IconButton(
                              semanticLabel: _favourite ? t.iptv.unfavouriteAction : t.iptv.favouriteAction,
                              icon: DsIcons.heart,
                              selected: _favourite,
                              onPressed: () => unawaited(_toggleFavourite(channel)),
                            ),
                          // The zap pair: these step channels, not the guide's
                          // days, so their names say 上一频道/下一频道 instead of
                          // borrowing the day stepper's words; the arrows match
                          // the up and down keys, which keep their own bindings.
                          if (channel != null && canStep && !headerNarrow) ...[
                            _IconButton(
                              semanticLabel: t.iptv.previousChannel,
                              icon: DsIcons.chevronUp,
                              onPressed: () => _switchChannel(-1),
                            ),
                            _IconButton(
                              semanticLabel: t.iptv.nextChannel,
                              icon: DsIcons.chevronDown,
                              onPressed: () => _switchChannel(1),
                            ),
                          ],
                          if (channel != null)
                            _IconButton(
                              semanticLabel: recording ? t.room.stopRecording : t.room.record,
                              icon: recording ? DsIcons.squareStop : DsIcons.disc,
                              selected: recording,
                              onPressed: () => unawaited(_recordWithToast()),
                            ),
                          ...headerActions,
                        ],
                      ),
                    ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // The picture's shape: the stream's own ratio by
                        // default, or the fixed frame / stretch / crop the bar's
                        // menu picked. The keyed view keeps the engine's surface
                        // whichever box it is told to fill.
                        final fit = switch (_aspect) {
                          IptvAspectMode.automatic => ref.watch(playbackSettingsProvider).fit.boxFit,
                          IptvAspectMode.ratio16x9 || IptvAspectMode.ratio4x3 || IptvAspectMode.fill => BoxFit.fill,
                          IptvAspectMode.zoom => BoxFit.cover,
                        };
                        Widget video() => MediaPlayerView(
                          key: _playerKey,
                          handle: handle!,
                          fit: fit,
                          backgroundColor: colors.overlay,
                        );
                        final programme = slot?.current;
                        // The reference's panel takes the left edge of the
                        // picture, not the whole window: what is playing stays
                        // visible behind the list being chosen from.
                        final zapperWidth = math.min<double>(720, constraints.maxWidth * .92);
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            if (handle != null)
                              Listener(
                                onPointerSignal: (signal) {
                                  if (signal is PointerScrollEvent) _wheelVolume(signal.scrollDelta.dy);
                                },
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: _showInfo,
                                  // A double click is the fullscreen toggle,
                                  // the reference's click on the picture; the
                                  // tap alone keeps naming the channel's info.
                                  onDoubleTap: _togglePictureFullscreen,
                                  // A vertical drag is the volume, the room's
                                  // rule.
                                  onVerticalDragStart: (_) => _beginVolumeDrag(),
                                  onVerticalDragUpdate: (move) => _dragVolumeBy(move.delta.dy),
                                  child: switch (_aspect) {
                                    IptvAspectMode.ratio16x9 => Center(
                                      child: AspectRatio(aspectRatio: 16 / 9, child: video()),
                                    ),
                                    IptvAspectMode.ratio4x3 => Center(
                                      child: AspectRatio(aspectRatio: 4 / 3, child: video()),
                                    ),
                                    _ => video(),
                                  },
                                ),
                              )
                            else
                              const Center(child: DsSpinner(style: DsSpinnerStyle(size: 28))),
                            // 音频模式 puts a quiet card over the station: the
                            // sound keeps running, the picture is deliberately
                            // gone, and the channel's name says what is playing.
                            if (_audioOnly && handle != null)
                              Positioned.fill(
                                child: ColoredBox(
                                  color: colors.overlay,
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      spacing: DsSpace.s8,
                                      children: [
                                        const DsIcon(DsIcons.headphones, size: 32, color: OnVideoColors.inkSubtle),
                                        Text(
                                          channel?.entry.name ?? '',
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.typography.title.copyWith(color: OnVideoColors.foreground),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            // The stream's own numbers, on the room's session
                            // switch: a viewer who turned them on to read a live
                            // bitrate gets them on a channel too.
                            if (handle case final player? when ref.watch(playerStatsVisibleProvider))
                              Positioned.fill(
                                child: IgnorePointer(child: PlayerStatsOverlay(handle: player)),
                              ),
                            // The capture's own mark: a breathing red point, the
                            // minutes it has run, and the tap that ends it — the
                            // live room's marker read on this page's own recording.
                            if (recordingTask != null && handle != null)
                              PositionedDirectional(
                                top: DsSpace.s12,
                                end: DsSpace.s12,
                                child: RecordingIndicator(
                                  startedAt: recordingTask.startedAt,
                                  label: t.room.stopRecording,
                                  onStop: () => unawaited(_recordWithToast()),
                                ),
                              ),
                            if (_volumeHud case final value?)
                              PositionedDirectional(
                                end: DsSpace.s20,
                                top: 0,
                                bottom: 0,
                                child: PlayerVolumeHud(value: value),
                              ),
                            // A scheduled reconnect waits here instead of the
                            // error card: the drop is being worked on, and the
                            // count says which attempt is coming.
                            if (_reconnectTimer != null)
                              ColoredBox(
                                color: OnVideoColors.scrim,
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    spacing: DsSpace.s12,
                                    children: [
                                      const DsSpinner(style: DsSpinnerStyle(size: 28)),
                                      Text(
                                        t.iptv.reconnectAttempt(
                                          attempt: _reconnectAttempts,
                                          total: _kReconnectMaxAttempts,
                                        ),
                                        style: theme.typography.body.copyWith(color: colors.text),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else if (_error != null)
                              ColoredBox(
                                color: OnVideoColors.scrim,
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    spacing: DsSpace.s12,
                                    children: [
                                      Text(
                                        t.iptv.playerOpenFailed,
                                        style: theme.typography.title.copyWith(color: colors.text),
                                      ),
                                      Text(
                                        _error!,
                                        textAlign: TextAlign.center,
                                        style: theme.typography.caption.copyWith(color: colors.textMuted),
                                      ),
                                      DsButton(onPressed: () => unawaited(_retry()), child: Text(t.common.retry)),
                                    ],
                                  ),
                                ),
                              ),
                            // The typed channel number, in the middle of the top
                            // edge where the reference draws it.
                            if (_digits.isNotEmpty)
                              PositionedDirectional(
                                start: 0,
                                end: 0,
                                top: DsSpace.s16,
                                child: Center(
                                  child: _DigitOsd(digits: _digits, channel: _digitPreview),
                                ),
                              ),
                            // The bottom strip: the channel, what is on and the
                            // line it plays from, for a few seconds.
                            if (_infoVisible && channel != null && _error == null)
                              PositionedDirectional(
                                start: 0,
                                end: 0,
                                bottom: 0,
                                child: IgnorePointer(
                                  child: _InfoBar(
                                    channel: channel,
                                    programme: programme,
                                    progress: slot?.progress,
                                    showNumber: browse.showChannelNumber,
                                    showProgramme: browse.showProgrammeLine,
                                    line: _urls.length > 1
                                        ? t.iptv.lineCount(current: _lineIndex + 1, total: _urls.length)
                                        : null,
                                  ),
                                ),
                              ),
                            if (_zapperOpen && channel != null)
                              PositionedDirectional(
                                start: 0,
                                top: 0,
                                bottom: 0,
                                width: zapperWidth,
                                child: Padding(
                                  padding: const EdgeInsets.all(DsSpace.s8),
                                  child: IptvZapper(
                                    channel: channel,
                                    onPlayChannel: (next) {
                                      _closeZapper();
                                      if (next.id == _channel?.id) {
                                        // The same channel: a replay goes back
                                        // to the live stream, live stays live.
                                        if (_catchup != null) unawaited(_open());
                                        return;
                                      }
                                      _openChannel(next);
                                    },
                                    onCatchup: (next, programme) async {
                                      _closeZapper();
                                      await _replayOn(next, programme);
                                    },
                                    onClose: _closeZapper,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                  // The bar rides the pointer-idle rule: a still hand during
                  // playback takes it away and the picture grows into its
                  // place, a move brings it back.
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    alignment: AlignmentDirectional.bottomCenter,
                    child: Builder(
                      builder: (context) {
                        if (!_barVisible) return const SizedBox(width: double.infinity);
                        // The room bar's own shade under the buttons, and the
                        // room bar's own tiers: the transport and its volume on
                        // the left, the picture's menus beside it, the capture
                        // and window verbs at the end - hair dividers between
                        // the clusters, and the low-frequency cluster folded
                        // away before the strip turns crowded.
                        return Container(
                          padding: EdgeInsets.fromLTRB(
                            PlayerBarTier.tvOf(context) ? DsSpace.s16 : DsSpace.s12,
                            PlayerBarTier.tvOf(context) ? DsSpace.s12 : DsSpace.s8,
                            PlayerBarTier.tvOf(context) ? DsSpace.s16 : DsSpace.s12,
                            PlayerBarTier.tvOf(context) ? DsSpace.s12 : DsSpace.s8,
                          ),
                          decoration: BoxDecoration(
                            gradient: OnVideoColors.shade(
                              edge: VerticalDirection.down,
                              strong: OnVideoColors.scrimDeep,
                            ),
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final tv = PlayerBarTier.tvOf(context);
                              final wide = constraints.maxWidth >= 720;
                              final crowded = constraints.maxWidth < 320;
                              return Row(
                                spacing: tv ? DsSpace.s8 : DsSpace.s4,
                                children: [
                                  PlayerBarButton(
                                    label: playing ? t.room.pause : t.room.play,
                                    iconAsset: playing ? 'assets/icons/pause.svg' : 'assets/icons/play.svg',
                                    onPressed: () => unawaited(_playback?.togglePlayPause() ?? Future<void>.value()),
                                  ),
                                  PlayerBarButton(
                                    label: muted ? t.room.unmute : t.room.mute,
                                    iconAsset: muted ? 'assets/icons/volume-muted.svg' : 'assets/icons/volume.svg',
                                    onPressed: handle == null ? null : () => unawaited(_toggleMute()),
                                  ),
                                  if (wide)
                                    SizedBox(
                                      width: 72,
                                      child: DsSlider(
                                        value: ((handle?.volume ?? _volume) * 100).clamp(0.0, 100.0),
                                        max: 100,
                                        onChanged: handle == null
                                            ? null
                                            : (value) => unawaited(_setVolume(value / 100)),
                                        semanticLabel: t.room.volume,
                                      ),
                                    ),
                                  const _BarDivider(),
                                  if (_urls.length > 1)
                                    DsMenuAnchor(
                                      semanticLabel: t.room.lineLabel,
                                      items: [
                                        for (final (index, _) in _urls.indexed)
                                          DsMenuItem(
                                            checked: index == _lineIndex,
                                            label: Text(t.room.line(n: '${index + 1}')),
                                            onPressed: () => unawaited(_selectLine(index)),
                                          ),
                                      ],
                                      builder: (context, controller, _) => PlayerBarButton(
                                        label: t.room.lineLabel,
                                        icon: DsIcons.route,
                                        onPressed: controller.toggle,
                                      ),
                                    ),
                                  DsMenuAnchor(
                                    semanticLabel: t.iptv.aspectLabel,
                                    items: [
                                      for (final mode in IptvAspectMode.values)
                                        DsMenuItem(
                                          checked: mode == _aspect,
                                          label: Text(iptvAspectLabel(t, mode)),
                                          onPressed: () => setState(() {
                                            _aspect = mode;
                                            IptvPlayPage.lastAspect = mode;
                                          }),
                                        ),
                                    ],
                                    builder: (context, controller, _) => PlayerBarButton(
                                      label: t.iptv.aspectLabel,
                                      icon: DsIcons.aspectRatio,
                                      onPressed: controller.toggle,
                                    ),
                                  ),
                                  if (widget.embedded && channel != null)
                                    PlayerBarButton(
                                      label: t.iptv.guideTitle,
                                      icon: DsIcons.calendarClock,
                                      onPressed: () => unawaited(
                                        showIptvGuide(
                                          context,
                                          channel: channel,
                                          catchup: _catchup,
                                          onCatchup: _playCatchup,
                                          onBackToLive: _open,
                                        ),
                                      ),
                                    ),
                                  if (widget.embedded && channel != null)
                                    PlayerBarButton(
                                      label: recording ? t.room.stopRecording : t.room.record,
                                      icon: recording ? DsIcons.squareStop : DsIcons.disc,
                                      selected: recording,
                                      onPressed: () => unawaited(_recordWithToast()),
                                    ),
                                  const Spacer(),
                                  const _BarDivider(),
                                  if (!crowded && (handle?.canCaptureScreenshot ?? false))
                                    PlayerBarButton(
                                      label: t.room.screenshot,
                                      icon: DsIcons.camera,
                                      onPressed: () => unawaited(_screenshot()),
                                    ),
                                  if (!crowded)
                                    PlayerBarButton(
                                      label: t.room.statsToggle,
                                      icon: DsIcons.activity,
                                      selected: ref.watch(playerStatsVisibleProvider),
                                      onPressed: handle == null
                                          ? null
                                          : () => ref.read(playerStatsVisibleProvider.notifier).toggle(),
                                    ),
                                  if (!crowded)
                                    PlayerBarButton(
                                      label: t.room.audioOnlyMode,
                                      icon: _audioOnly ? DsIcons.headphones : DsIcons.music2,
                                      selected: _audioOnly,
                                      onPressed: handle == null ? null : () => unawaited(_toggleAudioOnly()),
                                    ),
                                  if (handle != null && presentationController.pipAvailable)
                                    PlayerBarButton(
                                      label: presentation == PresentationMode.pip ? t.room.pipOff : t.room.pipOn,
                                      iconAsset: presentation == PresentationMode.pip
                                          ? 'assets/icons/pip-exit.svg'
                                          : 'assets/icons/pip.svg',
                                      onPressed: () => unawaited(_togglePip(handle)),
                                    ),
                                  // The window verbs, then the way out of the
                                  // picture's box: the desktop's
                                  // window-fullscreen first, then the system
                                  // fullscreen the phone turns for.
                                  if (_desktop && presentation != PresentationMode.pip)
                                    PlayerBarButton(
                                      label: presentation == PresentationMode.windowFullscreen
                                          ? t.room.windowFullscreenOff
                                          : t.room.windowFullscreenOn,
                                      icon: presentation == PresentationMode.windowFullscreen
                                          ? DsIcons.copy
                                          : DsIcons.square,
                                      selected: presentation == PresentationMode.windowFullscreen,
                                      onPressed: handle == null ? null : () => unawaited(_toggleWindowFullscreen()),
                                    ),
                                  PlayerBarButton(
                                    label: fullscreen ? t.room.fullscreenOff : t.room.fullscreenOn,
                                    icon: fullscreen ? DsIcons.minimize2 : DsIcons.fullscreen,
                                    onPressed: handle == null
                                        ? null
                                        : () => unawaited(
                                            fullscreen
                                                ? ref.read(roomPresentationProvider.notifier).exit(handle.id)
                                                : ref
                                                      .read(roomPresentationProvider.notifier)
                                                      .toggleFullscreen(handle.id),
                                          ),
                                  ),
                                ],
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small icon-only button on the player bar: the room page's bar pattern
/// without its menu machinery.
final class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.semanticLabel,
    required this.onPressed,
    this.icon,
    this.iconAsset,
    this.selected = false,
    this.onDark = false,
  }) : assert((icon == null) != (iconAsset == null), 'give exactly one glyph source: icon or iconAsset');

  final String semanticLabel;
  final DsIconData? icon;

  /// A bundled svg glyph drawn instead of [icon].
  final String? iconAsset;
  final VoidCallback? onPressed;

  /// Draws the glyph at full strength: a switch that is on.
  final bool selected;

  /// Draws the button for a strip over the picture, where the app's ink
  /// would be unreadable.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return MediaBarButton(
      icon: icon,
      iconAsset: iconAsset,
      label: semanticLabel,
      onPressed: onPressed,
      selected: selected,
      onDark: onDark,
      tooltip: false,
    );
  }
}

/// The status pill beside the channel's name in the header: the reference's
/// ON AIR tag — an outlined pill in the accent that says the programme is
/// on now (or being replayed), and the same outline in muted ink when the
/// named programme has yet to start.
final class _HeaderStatusBadge extends StatelessWidget {
  const _HeaderStatusBadge({required this.label, required this.accent});

  /// The words, e.g. 正在播出 or 正在回看.
  final String label;

  /// Draws the accent outline: the programme is on air or replaying. The
  /// upcoming state keeps the muted ink so a live channel still stands out.
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final ink = accent ? colors.accent : colors.textMuted;
    return DsBadge(
      dot: false,
      label: Text(label),
      style: DsBadgeStyle(
        height: 18,
        padding: const EdgeInsets.symmetric(horizontal: DsSpace.s6),
        background: const Color(0x00000000),
        foreground: ink,
        borderColor: ink,
        borderRadius: BorderRadius.circular(5),
        textStyle: theme.typography.caption.copyWith(fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// The channel number being typed, over the picture's top edge: the digits,
/// and the channel they name so far when the lookup already answers.
final class _DigitOsd extends StatelessWidget {
  const _DigitOsd({required this.digits, this.channel});

  final String digits;
  final IptvChannel? channel;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    return DsSurface(
      decoration: DsBoxDecoration(
        color: OnVideoColors.coverDimHeavy,
        borderRadius: BorderRadius.circular(DsRadii.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DsSpace.s20, vertical: DsSpace.s8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: DsSpace.s12,
          children: [
            Text(
              digits,
              style: theme.typography.numeric(
                theme.typography.heading.copyWith(color: const Color(0xFFFFFFFF), fontWeight: FontWeight.w600),
              ),
            ),
            Flexible(
              child: Text(
                channel?.entry.name ?? t.iptv.digitHint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.body.copyWith(color: channel == null ? const Color(0xB3FFFFFF) : colors.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The strip along the picture's bottom edge after an open or a switch: the
/// channel's number and name, what is on with its clock and progress, and the
/// line it plays from — the reference's info bar, on the viewer's switches.
final class _InfoBar extends StatelessWidget {
  const _InfoBar({
    required this.channel,
    required this.programme,
    required this.progress,
    required this.showNumber,
    required this.showProgramme,
    this.line,
  });

  final IptvChannel channel;
  final EpgProgramme? programme;
  final double? progress;
  final bool showNumber;
  final bool showProgramme;
  final String? line;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.bottomCenter,
          end: AlignmentDirectional.topCenter,
          colors: [OnVideoColors.scrim, Color(0x00000000)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s16, DsSpace.s40, DsSpace.s16, DsSpace.s12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          spacing: DsSpace.s12,
          children: [
            if (showNumber && channel.number != null)
              Text(
                '${channel.number}',
                style: theme.typography.numeric(
                  theme.typography.heading.copyWith(color: const Color(0xFFFFFFFF), fontWeight: FontWeight.w600),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: DsSpace.s4,
                children: [
                  Text(
                    channel.entry.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.title.copyWith(color: const Color(0xFFFFFFFF)),
                  ),
                  if (showProgramme && programme != null) ...[
                    Text(
                      '${iptvClockLabel(programme!.start)}–${iptvClockLabel(programme!.stop)}  '
                      '${programme!.title.isEmpty ? '—' : programme!.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.caption.copyWith(color: const Color(0xCCFFFFFF)),
                    ),
                    if (progress case final value?) DsProgressBar(value: value, semanticLabel: programme!.title),
                  ],
                ],
              ),
            ),
            if (line != null) Text(line!, style: theme.typography.caption.copyWith(color: const Color(0xCCFFFFFF))),
          ],
        ),
      ),
    );
  }
}

/// The compact window's own strip: the channel, the transport and the two
/// verbs. The window hides its own caption, so this is the only way back.
final class _PipStrip extends StatelessWidget {
  const _PipStrip({
    required this.title,
    required this.playing,
    required this.muted,
    required this.onDrag,
    required this.onPlayPause,
    required this.onMute,
    required this.onRestore,
    required this.onClose,
  });

  final String title;
  final bool playing;
  final bool muted;
  final VoidCallback onDrag;
  final VoidCallback onPlayPause;
  final VoidCallback? onMute;
  final VoidCallback? onRestore;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topCenter,
          end: AlignmentDirectional.bottomCenter,
          colors: [OnVideoColors.scrim, Color(0x00000000)],
        ),
      ),
      padding: const EdgeInsetsDirectional.only(start: DsSpace.s8),
      child: Row(
        spacing: DsSpace.s4,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (_) => onDrag(),
            onDoubleTap: onRestore,
            child: const SizedBox(
              width: 24,
              height: 32,
              child: Center(child: DsIcon(DsIcons.dragHandle, size: 14, color: OnVideoColors.inkSubtle)),
            ),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (_) => onDrag(),
              onDoubleTap: onRestore,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.caption.copyWith(color: const Color(0xCCFFFFFF)),
              ),
            ),
          ),
          _IconButton(
            semanticLabel: playing ? t.room.pause : t.room.play,
            iconAsset: playing ? 'assets/icons/pause.svg' : 'assets/icons/play.svg',
            onPressed: onPlayPause,
            onDark: true,
          ),
          _IconButton(
            semanticLabel: muted ? t.room.unmute : t.room.mute,
            iconAsset: muted ? 'assets/icons/volume-muted.svg' : 'assets/icons/volume.svg',
            onPressed: onMute,
            onDark: true,
          ),
          _IconButton(semanticLabel: t.room.pipOff, icon: DsIcons.expand, onPressed: onRestore, onDark: true),
          _IconButton(semanticLabel: t.common.close, icon: DsIcons.x, onPressed: onClose, onDark: true),
        ],
      ),
    );
  }
}

/// A hair divider between the bar's clusters: transport | picture menus |
/// capture and window verbs - the room bar's own separators.
final class _BarDivider extends StatelessWidget {
  const _BarDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 16,
      margin: const EdgeInsets.symmetric(horizontal: DsSpace.s4),
      color: OnVideoColors.inkHover,
    );
  }
}

/// A hair divider between the head's verb clusters, on the page's own ground
/// (the bar's divider over the picture uses the on-video ink instead).
final class _HeadDivider extends StatelessWidget {
  const _HeadDivider();

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    return Container(
      width: 1,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: DsSpace.s4),
      color: colors.border,
    );
  }
}
