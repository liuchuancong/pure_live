import 'dart:async' show StreamSubscription, Timer, unawaited;
import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_device/live_device.dart'
    show PlatformScreenAwakeService, PlatformScreenOrientationService, ScreenAwakeService, ScreenOrientationService;
import 'package:live_iptv/live_iptv.dart';
import 'package:live_sites/live_sites.dart'
    show LivePlayFormatSource, LivePlayLine, LiveStreamFormat, inferStreamFormat;
import 'package:media_core/media_core.dart';
import 'package:media_core_live/media_core_live.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/iptv/controllers/iptv_browse_settings.dart' show iptvBrowseSettingsProvider;
import 'package:pure_live/modules/iptv/controllers/iptv_controller.dart' show iptvLibraryProvider;
import 'package:pure_live/modules/iptv/controllers/iptv_recent.dart' show iptvRecentProvider;
import 'package:pure_live/modules/iptv/controllers/iptv_reminders.dart' show IptvReminder, iptvRemindersProvider;
import 'package:pure_live/modules/iptv/controllers/iptv_user_agent.dart'
    show iptvHeadersWithUserAgent, iptvUserAgentProvider;
import 'package:pure_live/modules/iptv/views/iptv_guide_panel.dart' show catchupUrlOf, iptvClockLabel, showIptvGuide;
import 'package:pure_live/modules/iptv/views/iptv_zapper.dart' show IptvZapper;
import 'package:pure_live/modules/live/room/room.dart';
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

final class IptvPlayPage extends ConsumerStatefulWidget {
  /// Plays [channelId]; [channel] is the card's own object when it opened
  /// the page (a deep link resolves it from the library instead), and
  /// [catchupProgramme] starts the player on that past programme instead of
  /// the live stream — the programme guide's replay action names it.
  const IptvPlayPage({required this.channelId, this.channel, this.catchupProgramme, super.key});

  /// The library channel id.
  final String channelId;

  /// The channel, when the caller already held it.
  final IptvChannel? channel;

  /// The programme to replay on open, or null for the live stream.
  final EpgProgramme? catchupProgramme;

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

  /// Takes the keyboard back when the channel panel closes.
  final FocusNode _pageFocus = FocusNode(debugLabel: 'iptv-play');

  /// The module's reminders, followed while this page is on screen so one
  /// that comes due switches the picture to its channel.
  StreamSubscription<IptvReminder>? _reminders;

  /// The addresses behind the current play: the playlist's own first, then
  /// its alternatives (or the single catch-up address).
  List<String> _urls = const [];
  int _lineIndex = 0;

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
    _channel = widget.channel ?? ref.read(iptvLibraryProvider).value?.channelById(widget.channelId);
    _favourite = _channel?.favorite ?? false;
    _reminders = ref.read(iptvRemindersProvider.notifier).fired.listen(_onReminder);
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_open());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _backgroundGate?.dispose();
    _backgroundGate = null;
    _tick?.cancel();
    _digitTimer?.cancel();
    _infoTimer?.cancel();
    _pageFocus.dispose();
    unawaited(_reminders?.cancel() ?? Future<void>.value());
    unawaited(_screenAwake.disable().catchError((Object _) {}));
    final player = _handle?.id;
    if (player != null && _presentationMode != PresentationMode.normal) {
      unawaited(_presentationNotifier.exit(player));
    }
    unawaited(_handles?.cancel() ?? Future<void>.value());
    unawaited(_states?.cancel() ?? Future<void>.value());
    unawaited(_failures?.cancel() ?? Future<void>.value());
    unawaited(_geometry?.cancel() ?? Future<void>.value());
    _geometry = null;
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
      if (mounted) showDsToast(context: context, title: context.t.iptv.catchupFailed);
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
    _states ??= playback.onStateChanged.listen((state) {
      if (mounted) setState(() => _playbackState = state);
    });
    _handles ??= playback.onHandleChanged.listen((handle) {
      if (mounted) setState(() => _handle = handle);
      unawaited(_applyAudio(handle));
      unawaited(_applyEngineOptions(handle));
      _bindGeometry(handle);
    });
    _failures ??= playback.onError.listen((failure) {
      if (mounted) setState(() => _error = failure.message ?? failure.code.name);
    });
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
    setState(() => _error = null);
    await playback.retry();
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
    context.pushReplacement(RouteNames.iptvPlay.replaceFirst(':channelId', channel.id), extra: channel);
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

  /// Shows the bottom info strip for the reference's few seconds.
  void _showInfo() {
    _infoTimer?.cancel();
    _infoTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => _infoVisible = false);
    });
    if (!_infoVisible && mounted) setState(() => _infoVisible = true);
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

  /// Stops the channel from the compact window: leave the mode, stop the
  /// stream, leave the page. The window's ✕ means "I am done watching".
  void _closeChannel() {
    final handle = _handle;
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
    final channel = _channel;
    final handle = _handle;
    final muted = _effectivelyMuted;
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
    final subtitle = replay != null
        ? '${t.iptv.playingCatchup} · ${replay.title}'
        : !browse.showProgrammeLine
        ? null
        : switch (slot?.title) {
            final programme? => '${slot!.current != null ? t.iptv.onAir : t.iptv.upNext} · $programme',
            _ => null,
          };
    void leave() {
      if (ownsWindow && handle != null) {
        unawaited(presentationController.exit(handle.id));
      } else {
        context.pop();
      }
    }

    // The compact window is the whole app window: the page's header and
    // control bar would be squeezed into it, so only the picture and a way
    // out are drawn. The window hides its own caption, so the strip below is
    // the only way back.
    if (presentation == PresentationMode.pip && presentationController.pipOwnsWindow) {
      return ColoredBox(
        color: const Color(0xFF000000),
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
                onDrag: () => unawaited(ref.read(windowsPipWindowProvider)?.startDragging() ?? Future<void>.value()),
                onPlayPause: () => unawaited(_playback?.togglePlayPause() ?? Future<void>.value()),
                onMute: handle == null ? null : () => unawaited(_toggleMute()),
                onRestore: handle == null ? null : () => unawaited(presentationController.exit(handle.id)),
                onClose: _closeChannel,
              ),
            ),
          ],
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
        autofocus: true,
        child: ColoredBox(
          color: colors.overlay,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                          spacing: 2,
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
                            if (subtitle != null)
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.typography.caption.copyWith(
                                  color: replay != null ? colors.accent : colors.textMuted,
                                ),
                              ),
                          ],
                        ),
                      ),
                      // The reference's corner clock, on the viewer's switch:
                      // the page's minute tick already redraws it.
                      if (browse.showClock)
                        Text(
                          iptvClockLabel(DateTime.now()),
                          style: theme.typography.numeric(theme.typography.caption.copyWith(color: colors.textMuted)),
                        ),
                      if (channel != null)
                        _IconButton(
                          semanticLabel: _favourite ? t.iptv.unfavouriteAction : t.iptv.favouriteAction,
                          icon: DsIcons.heart,
                          selected: _favourite,
                          onPressed: () => unawaited(_toggleFavourite(channel)),
                        ),
                      if (channel != null && canStep) ...[
                        _IconButton(
                          semanticLabel: t.iptv.previousDay,
                          icon: DsIcons.chevronUp,
                          onPressed: () => _switchChannel(-1),
                        ),
                        _IconButton(
                          semanticLabel: t.iptv.nextDay,
                          icon: DsIcons.chevronDown,
                          onPressed: () => _switchChannel(1),
                        ),
                      ],
                      if (channel != null && _urls.length > 1)
                        DsMenuAnchor(
                          semanticLabel: t.room.lineLabel,
                          items: [
                            for (final (index, _) in _urls.indexed)
                              DsMenuItem(
                                leading: DsIcon(index == _lineIndex ? DsIcons.check : DsIcons.gitBranch),
                                label: Text(t.room.line(n: '${index + 1}')),
                                onPressed: () => unawaited(_selectLine(index)),
                              ),
                          ],
                          builder: (context, controller, _) => _IconButton(
                            semanticLabel: t.room.lineLabel,
                            icon: DsIcons.gitBranch,
                            onPressed: controller.toggle,
                          ),
                        ),
                      if (channel != null)
                        _IconButton(semanticLabel: t.room.cast, icon: DsIcons.cast, onPressed: () => _cast(channel)),
                      if (channel != null)
                        _IconButton(
                          semanticLabel: t.iptv.zapperOpen,
                          icon: DsIcons.layoutGrid,
                          selected: _zapperOpen,
                          onPressed: _openZapper,
                        ),
                      if (channel != null)
                        _IconButton(
                          semanticLabel: t.iptv.guideTitle,
                          icon: DsIcons.list,
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
                      if (replay != null)
                        _IconButton(
                          semanticLabel: t.iptv.backToLive,
                          icon: DsIcons.radio,
                          onPressed: () => unawaited(_open()),
                        ),
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
                      Widget video() =>
                          MediaPlayerView(key: _playerKey, handle: handle!, fit: fit, backgroundColor: colors.overlay);
                      final programme = slot?.current;
                      // The reference's panel takes the left edge of the
                      // picture, not the whole window: what is playing stays
                      // visible behind the list being chosen from.
                      final zapperWidth = math.min<double>(720, constraints.maxWidth * .92);
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          if (handle != null)
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _showInfo,
                              child: switch (_aspect) {
                                IptvAspectMode.ratio16x9 => Center(
                                  child: AspectRatio(aspectRatio: 16 / 9, child: video()),
                                ),
                                IptvAspectMode.ratio4x3 => Center(
                                  child: AspectRatio(aspectRatio: 4 / 3, child: video()),
                                ),
                                _ => video(),
                              },
                            )
                          else
                            const Center(child: DsSpinner(style: DsSpinnerStyle(size: 28))),
                          if (_error != null)
                            ColoredBox(
                              color: const Color(0xB3000000),
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(DsSpace.s16, DsSpace.s8, DsSpace.s16, DsSpace.s12),
                  child: Row(
                    spacing: DsSpace.s8,
                    children: [
                      _IconButton(
                        semanticLabel: playing ? t.room.pause : t.room.play,
                        icon: playing ? DsIcons.pause : DsIcons.play,
                        onPressed: () => unawaited(_playback?.togglePlayPause() ?? Future<void>.value()),
                      ),
                      _IconButton(
                        semanticLabel: muted ? t.room.unmute : t.room.mute,
                        icon: muted ? DsIcons.volumeOff : DsIcons.volume,
                        onPressed: handle == null ? null : () => unawaited(_toggleMute()),
                      ),
                      Expanded(
                        child: DsSlider(
                          value: handle?.volume ?? _volume,
                          onChanged: handle == null ? null : (value) => unawaited(_setVolume(value)),
                          semanticLabel: t.room.volume,
                        ),
                      ),
                      // The reference's 画面比例 chip, as a menu: the stream's
                      // own shape or a frame the viewer picked.
                      DsMenuAnchor(
                        semanticLabel: t.iptv.aspectLabel,
                        items: [
                          for (final mode in IptvAspectMode.values)
                            DsMenuItem(
                              leading: DsIcon(mode == _aspect ? DsIcons.check : DsIcons.aspectRatio),
                              label: Text(iptvAspectLabel(t, mode)),
                              onPressed: () => setState(() {
                                _aspect = mode;
                                IptvPlayPage.lastAspect = mode;
                              }),
                            ),
                        ],
                        builder: (context, controller, _) => _IconButton(
                          semanticLabel: t.iptv.aspectLabel,
                          icon: DsIcons.aspectRatio,
                          onPressed: controller.toggle,
                        ),
                      ),
                      if (handle != null && presentationController.pipAvailable)
                        _IconButton(
                          semanticLabel: presentation == PresentationMode.pip ? t.room.pipOff : t.room.pipOn,
                          icon: presentation == PresentationMode.pip
                              ? DsIcons.pictureInPictureExit
                              : DsIcons.pictureInPicture,
                          onPressed: () => unawaited(_togglePip(handle)),
                        ),
                      _IconButton(
                        semanticLabel: fullscreen ? t.room.fullscreenOff : t.room.fullscreenOn,
                        icon: fullscreen ? DsIcons.minimize2 : DsIcons.fullscreen,
                        onPressed: handle == null
                            ? null
                            : () => unawaited(
                                fullscreen
                                    ? ref.read(roomPresentationProvider.notifier).exit(handle.id)
                                    : ref.read(roomPresentationProvider.notifier).toggleFullscreen(handle.id),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
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
    required this.icon,
    required this.onPressed,
    this.selected = false,
    this.onDark = false,
  });

  final String semanticLabel;
  final DsIconData icon;
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
      label: semanticLabel,
      onPressed: onPressed,
      selected: selected,
      onDark: onDark,
      tooltip: false,
      zoomsOnTv: false,
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
      decoration: DsBoxDecoration(color: const Color(0xE6000000), borderRadius: BorderRadius.circular(DsRadii.pill)),
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
          colors: [Color(0xB3000000), Color(0x00000000)],
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
                      '${iptvClockLabel(programme!.start)} - ${iptvClockLabel(programme!.stop)}  '
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
          colors: [Color(0xB3000000), Color(0x00000000)],
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
              child: Center(child: DsIcon(DsIcons.dragHandle, size: 14, color: Color(0x99FFFFFF))),
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
            icon: playing ? DsIcons.pause : DsIcons.play,
            onPressed: onPlayPause,
            onDark: true,
          ),
          _IconButton(
            semanticLabel: muted ? t.room.unmute : t.room.mute,
            icon: muted ? DsIcons.volumeOff : DsIcons.volume,
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
