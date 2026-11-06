import 'dart:async' show StreamSubscription, Timer, unawaited;
import 'dart:convert' show utf8;
import 'dart:io' show File;

import 'package:desen_ui/desen_ui.dart';
import 'package:flame_barrage/flame_barrage.dart' show BarrageController, BarrageItem, EmojiAtlas, FlameBarrageWidget;
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouter;
import 'package:live_cache/live_cache.dart' show ImageCachePolicies;
import 'package:live_device/live_device.dart' show PlatformScreenOrientationService, ScreenOrientationService;
import 'package:media_core/media_core.dart'
    show
        GeometryState,
        PlayerAdapterCompleted,
        PlayerAdapterEvent,
        PlayerHandle,
        PlayerHandleLifecycle,
        PlayerHandlePlayback,
        PlayerHandleRecovery,
        PlayerId,
        PlayerTransportState,
        PresentationMode;
import 'package:media_core_danmaku/media_core_danmaku.dart' show BarrageItemMapper, DanmakuPlayerBinding;
import 'package:open_file/open_file.dart' show OpenFile, ResultType;
import 'package:path/path.dart' as p;

import 'package:pure_live/app/app.dart'
    show
        RoomPresentationController,
        RouteCaptionTail,
        SettingsSectionRoute,
        appPathsProvider,
        fullscreenDriverProvider,
        pipDriverProvider,
        resolvedFontFamily,
        roomPresentationProvider,
        routeCaptionTitle;
import 'package:pure_live/features/media_preview/media_preview_item.dart';
import 'package:pure_live/features/settings/pages/wallpaper_download_manager.dart' show openDownloadedPath;
import 'package:pure_live/features/settings/pages/wallpaper_video_player.dart' show WallpaperVideoPlayer;
import 'package:pure_live/features/settings/settings.dart'
    show
        PlaybackFit,
        SettingsSection,
        danmakuEffectiveFpsProvider,
        danmakuStyleProvider,
        fitLabels,
        playbackSettingsProvider;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/shared.dart'
    show
        DanmakuFormat,
        LiveWindow,
        PlayerBarButton,
        PlayerGlassPill,
        PlayerStatsOverlay,
        PlayerVolumeHud,
        applyFullscreenOrientation,
        cachedImage,
        capturePlayerFrame,
        danmakuFileFor,
        playerBarrageConfig,
        playerInk,
        playerInkMuted,
        playerInkSubtle,
        playerStatsVisibleProvider,
        showCastUriDialog;

/// Opens the media preview over [items], on the entry at [initialIndex].
///
/// The page is the app's own player over a list: the stage on the left, the
/// entries on the right on a wide window and as a second view on a phone.
/// Modules hand it their finished files and nothing else — a recording centre,
/// a download manager and the local media page all get the same page. The stage
/// is a video stage: audio belongs to the music module's own player page, which
/// already carries the artwork, the lyric run and the transport.
///
/// [onDeleted] hears of a file the viewer deleted from the page, after it is
/// gone from disk: the list that owns the item (a recording task, a download
/// row) updates its own record, since the page only knows the file.
Future<void> openMediaPreview(
  BuildContext context, {
  required String title,
  required List<MediaPreviewItem> items,
  int initialIndex = 0,
  Future<void> Function(MediaPreviewItem item)? onDeleted,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    DsPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => MediaPreviewPage(title: title, items: items, initialIndex: initialIndex, onDeleted: onDeleted),
    ),
  );
}

/// The speeds a preview offers: the steps a viewer actually reaches for on a
/// long take, not a continuous dial. The same six the vod player's own
/// catalogue carries, written out here because this page is what the modules
/// open and must not reach back into one of them for a list.
const List<double> kPreviewRates = [0.5, 0.75, 1, 1.25, 1.5, 2];

/// The rate as the menu says it: `1×`, `1.5×`, `0.75×` — the number, never the
/// category's name beside a panel already titled 倍速.
String _rateLabel(double value) => '${value.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '')}×';

/// The preview page: one file playing, the rest of the list beside it, and
/// the entry's danmaku over the picture when it has a sidecar.
final class MediaPreviewPage extends ConsumerStatefulWidget {
  /// Shows [items] under [title].
  const MediaPreviewPage({required this.title, required this.items, this.initialIndex = 0, this.onDeleted, super.key});

  /// The page's own name ("录制预览", "下载预览").
  final String title;

  /// What the list offers; only finished, on-disk files belong here.
  final List<MediaPreviewItem> items;

  /// The entry to open on.
  final int initialIndex;

  /// Told of a file deleted from the page, once it is gone from disk.
  final Future<void> Function(MediaPreviewItem item)? onDeleted;

  @override
  ConsumerState<MediaPreviewPage> createState() => _MediaPreviewPageState();
}

final class _MediaPreviewPageState extends ConsumerState<MediaPreviewPage> {
  /// The stage is dark whatever the app's theme: a preview is a picture.
  static const Color _stage = Color(0xFF000000);

  /// Below this width the list becomes a second view instead of a column.
  static const double _inlineWidth = 900;

  static const double _listMin = 240;
  static const double _listMax = 420;
  static const double _listDefault = 320;

  /// The immersive drawer's two widths: the summoned column, and the tab
  /// that waits at the picture's end edge between visits.
  static const double _drawerWidth = 280;
  static const double _drawerTabWidth = 28;

  late int _index = widget.items.isEmpty ? 0 : widget.initialIndex.clamp(0, widget.items.length - 1);
  double _listWidth = _listDefault;

  /// On a narrow window: whether the list is the view in front.
  bool _listOpen = false;

  /// Whether the immersive layout's file drawer is slid out over the picture.
  bool _drawerOpen = false;

  /// Whether the player's own bar is on screen, as the player reports it. The
  /// page's top-right actions and the edge arrows follow it, so the whole
  /// chrome appears and settles together and a playing take is never under a
  /// cluster the viewer asked to hide.
  bool _chromeVisible = true;

  /// Whether the stage was dropped on purpose: the entry it played is being
  /// taken off the disk, and the engine has to let go of the file first.
  bool _stageCleared = false;

  /// The flying layer's engine, the bridge that keeps its clock on the
  /// picture's, and the position the last transport event reported.
  final BarrageController _barrage = BarrageController();
  DanmakuPlayerBinding? _binding;
  StreamSubscription<PlayerTransportState>? _transport;
  Duration _position = Duration.zero;

  /// The stage's player and the volume the engine last reported: the page
  /// drives the number, the bar's mute button stays the player's own.
  PlayerHandle? _handle;
  StreamSubscription<PlayerAdapterEvent>? _events;
  double _volume = 1;

  /// The speed and the sound-only mode the page promises the next entry: a
  /// viewer who chose 1.5× or 音频模式 does not choose it again for every file
  /// in the list. Both are this visit's, like the volume, not preferences.
  double _rate = 1;
  bool _audioOnly = false;

  /// Whether the current take starts over when it ends. Off, so a preview
  /// stops on its last frame and the list's own auto-next walk can go on; a
  /// viewer who wants one take over and over keeps the choice into the next
  /// entry like the rate.
  bool _loop = false;

  /// The theatre: the picture owns the body and the list floats over its end
  /// edge — the room's own arrangement, for the same reason a preview wants it
  /// (a take is wider than a column beside it leaves room for).
  bool _theater = false;

  /// The volume a drag on the frame or a mouse wheel is setting right now; null
  /// while no gesture is showing it. The chip fades on its own, as the room's
  /// does — a number that stayed would read as the picture's own.
  double? _volumeHud;
  Timer? _volumeHudTimer;
  double _dragVolume = 1;

  /// Whether the list moves on when a take ends. The page's own switch — it
  /// speaks about this visit, not about the app, so it stays out of the
  /// preferences.
  bool _autoNext = true;

  /// The current entry's decoded timeline; null while it has no sidecar or
  /// the file is still being read.
  List<BarrageItem>? _timeline;
  bool _danmakuLoading = false;

  /// A read may finish after the list moved on; only the latest one lands.
  int _danmakuToken = 0;
  bool _disposed = false;

  /// The window's presentation, kept outside `build` because the leaving page
  /// must still hand back the screen it took — `ref` is gone by the time
  /// `dispose` runs.
  late final RoomPresentationController _presentation;
  PresentationMode _presentationMode = PresentationMode.normal;
  PlayerId? _playerId;
  StreamSubscription<GeometryState>? _geometry;
  double _aspectRatio = 0;

  /// The phone's orientation lock, inert on a desktop.
  final ScreenOrientationService _screenOrientation = const PlatformScreenOrientationService();

  MediaPreviewItem? get _current => _stageCleared || widget.items.isEmpty ? null : widget.items[_index];

  bool get _hasDanmaku => _timeline?.isNotEmpty ?? false;

  @override
  void initState() {
    super.initState();
    _presentation = ref.read(roomPresentationProvider.notifier);
    unawaited(_loadDanmaku());
  }

  @override
  void dispose() {
    _disposed = true;
    _danmakuToken++;
    _volumeHudTimer?.cancel();
    // Cancelled here as well as in _detachPlayer so the subscription's owner
    // is the method the analyzer, and a reader, looks for it in.
    unawaited(_transport?.cancel() ?? Future<void>.value());
    unawaited(_events?.cancel() ?? Future<void>.value());
    unawaited(_geometry?.cancel() ?? Future<void>.value());
    final playerId = _playerId;
    if (playerId != null && _presentationMode != PresentationMode.normal) {
      unawaited(_presentation.exit(playerId));
    }
    _detachPlayer();
    _barrage.dispose();
    super.dispose();
  }

  /// Stops the timeline's clock before its player goes away: the binding
  /// listens to the handle that is being released, and the page is the only
  /// one that knows the two may now belong to different entries.
  void _detachPlayer() {
    _handle = null;
    final geometry = _geometry;
    _geometry = null;
    if (geometry != null) unawaited(geometry.cancel());
    final events = _events;
    _events = null;
    if (events != null) unawaited(events.cancel());
    final binding = _binding;
    _binding = null;
    if (binding != null) unawaited(binding.dispose());
    final transport = _transport;
    _transport = null;
    if (transport != null) unawaited(transport.cancel());
    _position = Duration.zero;
  }

  /// The stage's player built a handle: put the comment timeline on its clock
  /// and keep the latest position for a timeline that arrives later.
  void _onHandle(PlayerHandle handle) {
    if (_disposed) return;
    _detachPlayer();
    _handle = handle;
    _binding = DanmakuPlayerBinding.forHandle(controller: _barrage, handle: handle)..attach();
    _transport = handle.playbackStream.listen((state) {
      _position = state.position;
      final volume = state.volume;
      if (volume != _volume && mounted) setState(() => _volume = volume);
    });
    _events = handle.adapterEvents.listen(_onAdapterEvent);
    _playerId = handle.id;
    // The fullscreen and compact-window surfaces are shaped from the picture's
    // own ratio, and the phone's turn follows it; a page that feeds the
    // drivers nothing gets the config's 16:9 instead.
    _geometry = handle.geometryController.state.listen((state) {
      final size = state.geometry.videoSize;
      if (size.width <= 0 || size.height <= 0) return;
      _aspectRatio = size.width / size.height;
      ref.read(fullscreenDriverProvider).onVideoSize(size.width, size.height);
      ref.read(pipDriverProvider).onVideoSize(size.width, size.height);
    });
    // The number the slider shows is the page's promise: a new entry opens at
    // the volume it was set to, not back at full. The speed and the sound-only
    // mode are promised the same way.
    if (_volume != 1) unawaited(_applyVolume(handle, _volume));
    if (_rate != 1) unawaited(_applyRate(handle, _rate));
    if (_audioOnly) unawaited(_applyAudioOnly(handle, true));
    if (_loop) unawaited(_applyLoop(handle, true));
    _scheduleTimeline();
  }

  /// A take that ended walks the list while the page is told to; the last
  /// entry simply stops on its final frame. A looping take's completion is
  /// the engine's own rewind cue — the handle starts the same file over — so
  /// the list stands down rather than walking on top of the replay.
  void _onAdapterEvent(PlayerAdapterEvent event) {
    if (event is! PlayerAdapterCompleted) return;
    if (_loop) return;
    if (!_autoNext || _index + 1 >= widget.items.length) return;
    _select(_index + 1);
  }

  /// Moves the engine's volume. A handle already being released refuses; the
  /// slider then reads back whatever the engine reports next rather than
  /// pretending the number stuck.
  /// Takes the picture over the whole screen, or hands the window back; the
  /// same driver the room, the station's archive and hongguo use, so a
  /// preview's fullscreen is the app's fullscreen rather than a bigger box.
  Future<void> _toggleFullscreen() async {
    final handle = _handle;
    if (handle == null) return;
    await _presentation.toggleFullscreen(handle.id);
  }

  /// The desktop variant: the picture fills the app window while the window
  /// stays a window — the same toggle the room's bar carries, and a file
  /// watched beside other windows wants it as much as a stream does.
  Future<void> _toggleWindowFullscreen() async {
    final handle = _handle;
    if (handle == null) return;
    await _presentation.toggleWindowFullscreen(handle.id);
  }

  /// The desktop's compact window (the phone's system window on iOS). A host
  /// that refuses has to be told, or the button reads as broken.
  Future<void> _togglePip() async {
    final handle = _handle;
    if (handle == null) return;
    final accepted = await _presentation.togglePip(handle.id);
    if (accepted || !mounted) return;
    showDsToast(context: context, title: context.t.common.pipUnavailable);
  }

  /// Opens or closes the immersive layout's file drawer.
  void _setDrawerOpen(bool value) {
    if (_drawerOpen == value) return;
    setState(() => _drawerOpen = value);
  }

  /// The bar's way out of a mode that owns the window: the first press hands
  /// the screen back, the next one leaves the preview — the room's and the
  /// station's own rule, so a viewer is never trapped by a fullscreen.
  void _leave(BuildContext context, {required bool immersive, required bool narrow}) {
    if (immersive) {
      // The drawer gives way before the fullscreen does, as every panel in the
      // page does before the page itself does.
      if (_drawerOpen) {
        _setDrawerOpen(false);
        return;
      }
      unawaited(_toggleFullscreen());
      return;
    }
    // The arrangement gives way before the page does: a viewer pressing back in
    // the theatre wants the list column back, not the preview closed.
    if (_theater) {
      setState(() => _theater = false);
      return;
    }
    if (narrow && _listOpen) {
      setState(() => _listOpen = false);
      return;
    }
    Navigator.of(context).maybePop();
  }

  Future<void> _setVolume(double value) async {
    final handle = _handle;
    setState(() => _volume = value);
    if (handle == null) return;
    await _applyVolume(handle, value);
  }

  /// Writes [value] to [handle]; a handle already being released refuses, and
  /// the engine's own state wins rather than the slider's guess.
  Future<void> _applyVolume(PlayerHandle handle, double value) async {
    try {
      await handle.setVolume(value);
    } on Object {
      // The slider reads back what the next transport event reports.
    }
  }

  /// Shows [value] on the picture's own volume chip, and lets it settle away
  /// again a moment after the last move.
  void _showVolumeHud(double value) {
    _volumeHudTimer?.cancel();
    setState(() => _volumeHud = value.clamp(0.0, 1.0));
    _volumeHudTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _volumeHud = null);
    });
  }

  /// A vertical drag takes the volume from where it stands: up is louder, the
  /// whole picture is the track. The room's gesture, offered here so a viewer
  /// learns it once and finds it on every surface.
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
  /// setting), so a desktop mouse has a usable granularity without a slider.
  void _wheelVolume(double delta) {
    final handle = _handle;
    if (handle == null) return;
    final step = ref.read(playbackSettingsProvider).volumeWheelStepPercent / 100;
    final next = (_volume + (delta > 0 ? -step : step)).clamp(0.0, 1.0);
    _showVolumeHud(next);
    unawaited(_setVolume(next));
  }

  /// Plays at [value]'s multiple. The page keeps the number, so the next entry
  /// opens at the speed the viewer chose rather than back at 1×.
  Future<void> _setRate(double value) async {
    final handle = _handle;
    setState(() => _rate = value);
    if (handle == null) return;
    await _applyRate(handle, value);
  }

  Future<void> _applyRate(PlayerHandle handle, double value) async {
    try {
      await handle.setRate(value);
    } on Object {
      // A kernel that refuses the rate keeps playing at its own; the menu still
      // shows what was asked, because that is what the next entry will try.
    }
  }

  /// Starts the current take over when it ends. The handle carries the answer
  /// to the completion event — set it on the engine, and the next completion
  /// rewinds instead of stopping — so the switch is the engine's own; the page
  /// keeps the choice, and the next entry opens with it like the rate.
  Future<void> _setLoop(bool value) async {
    final handle = _handle;
    setState(() => _loop = value);
    if (handle == null) return;
    await _applyLoop(handle, value);
  }

  Future<void> _applyLoop(PlayerHandle handle, bool value) async {
    try {
      await handle.setLoop(loop: value);
    } on Object {
      // A handle already being released refuses; the next one gets the same
      // try, and the bar still says what was asked.
    }
  }

  /// Drops the picture and keeps the sound: the room's own 音频模式, for a take
  /// the viewer is only listening to (an overnight recording, a music video at
  /// a desk).
  Future<void> _setAudioOnly(bool value) async {
    final handle = _handle;
    setState(() => _audioOnly = value);
    if (handle == null) return;
    await _applyAudioOnly(handle, value);
  }

  Future<void> _applyAudioOnly(PlayerHandle handle, bool value) async {
    try {
      await handle.setAudioOnly(audioOnly: value);
    } on Object {
      // A kernel without the mode leaves the picture up; the button says what
      // was asked and the next handle gets the same try.
    }
  }

  /// Writes the frame the stage is showing into the viewer's screenshot folder
  /// and says how it went — a capture that fails silently reads as a dead
  /// button.
  Future<void> _screenshot() async {
    final handle = _handle;
    if (handle == null) return;
    final file = await capturePlayerFrame(handle, ref.read(appPathsProvider).screenshots, prefix: 'preview');
    if (!mounted) return;
    final t = context.t;
    showDsToast(
      context: context,
      title: file == null ? t.room.screenshotFailed : t.room.screenshotSaved(name: file.uri.pathSegments.last),
      status: file == null ? DsStatus.danger : DsStatus.success,
    );
  }

  /// Reads the current entry's sidecar — the module's own path, or the danmaku
  /// file beside the one that recordings and downloads write — and decodes it.
  Future<void> _loadDanmaku() async {
    final item = _current;
    final token = ++_danmakuToken;
    final sidecar = item == null ? null : _sidecarOf(item);
    final format = sidecar == null ? null : _formatOf(sidecar);
    _barrage.clear();
    if (!mounted) return;
    setState(() {
      _timeline = null;
      _danmakuLoading = sidecar != null && format != null;
    });
    if (sidecar == null || format == null) return;
    String source;
    try {
      source = utf8.decode(await File(sidecar).readAsBytes(), allowMalformed: true);
    } on Object {
      if (!mounted || token != _danmakuToken) return;
      setState(() => _danmakuLoading = false);
      return;
    }
    if (!mounted || token != _danmakuToken) return;
    final timeline = [
      for (final entry in format.decode(source)) BarrageItemMapper.toItem(entry.toMessage(), at: entry.time),
    ];
    setState(() {
      _timeline = timeline;
      _danmakuLoading = false;
    });
    _scheduleTimeline();
  }

  /// Puts the decoded timeline on the engine once the layer that owns it is
  /// in the frame; a layer that is hidden or gone has nowhere to put it.
  void _scheduleTimeline() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _disposed) return;
      final timeline = _timeline;
      if (timeline == null || timeline.isEmpty) return;
      if (!ref.read(playbackSettingsProvider).danmakuVisible) return;
      _barrage
        ..loadTimeline(timeline)
        ..seekTo(_position);
    });
  }

  /// The sidecar beside [item]'s file, or the module's own path when it named
  /// one. A missing file reads as no danmaku rather than a broken track.
  String? _sidecarOf(MediaPreviewItem item) {
    if (!item.exists) return null;
    final named = item.danmakuPath?.trim() ?? '';
    if (named.isNotEmpty) return File(named).existsSync() ? named : null;
    // XML is what the app writes by default; the viewer can save the same set
    // as JSON or TXT instead, and both say the same thing to this page.
    for (final format in _danmakuFormats) {
      final sidecar = danmakuFileFor(File(item.path), format);
      if (sidecar.existsSync()) return sidecar.path;
    }
    return null;
  }

  /// The readable sidecar formats, best first.
  static const List<DanmakuFormat> _danmakuFormats = [DanmakuFormat.xml, DanmakuFormat.json, DanmakuFormat.txt];

  /// The format a sidecar's name promises, or null when this page cannot read
  /// it back (an ASS or SRT save is for other players, not for the layer).
  DanmakuFormat? _formatOf(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0) return null;
    final format = DanmakuFormat.byId(path.substring(dot + 1).toLowerCase());
    return format != null && format.readable ? format : null;
  }

  void _select(int index) {
    if (index < 0 || index >= widget.items.length) return;
    if (index == _index) {
      if (_listOpen) setState(() => _listOpen = false);
      return;
    }
    setState(() {
      _index = index;
      _listOpen = false;
      _stageCleared = false;
      _timeline = null;
      _danmakuLoading = false;
    });
    _detachPlayer();
    unawaited(_loadDanmaku());
  }

  /// The danmaku's rules live in the settings' own section; the bar's gear
  /// pushes it over this page, the room's own door, so the take goes on
  /// playing underneath while the style is tuned.
  void _openDanmakuSettings() {
    unawaited(GoRouter.of(context).push(SettingsSectionRoute(section: SettingsSection.danmaku.name).location));
  }

  Future<void> _revealFolderOf(String path) => _revealFolder(File(path).parent.path);

  /// Shows [folder] in the system's file manager — the row's own folder, or the
  /// group header's room.
  Future<void> _revealFolder(String folder) async {
    try {
      final result = await OpenFile.open(folder);
      if (result.type == ResultType.done || !mounted) return;
    } on Object {
      // Fall through to the toast.
    }
    if (!mounted) return;
    showDsToast(context: context, title: context.t.common.previewOpenFolderFailed, status: DsStatus.danger);
  }

  /// The folder a listed entry lives in, reached from its own row.
  void _revealFolderAt(int index) {
    if (index < 0 || index >= widget.items.length) return;
    unawaited(_revealFolderOf(widget.items[index].path));
  }

  /// Takes one entry's file off the disk. The row stays in the list and greys
  /// itself — the module that queued it still speaks of the task until it is
  /// cleared there, and the preview page is not the place that decides what
  /// another module's list holds.
  Future<void> _deleteAt(int index) async {
    if (index < 0 || index >= widget.items.length) return;
    final t = context.t;
    final item = widget.items[index];
    final confirmed = await showDsConfirm(
      context: context,
      title: t.common.previewDeleteTitle,
      description: t.common.previewDeleteBody(name: item.title),
      confirmLabel: t.common.delete,
      cancelLabel: t.common.cancel,
      destructive: true,
      icon: const DsIcon(DsIcons.trash2),
    );
    if (!confirmed || !mounted) return;
    // The engine holds its own file open, so the take being played is stepped
    // past — or, when there is nothing to step to, the stage is dropped —
    // before the delete, rather than fighting the decoder for the handle.
    if (index == _index) {
      final next = index + 1 < widget.items.length ? index + 1 : index - 1;
      if (next >= 0 && next < widget.items.length) {
        _select(next);
      } else {
        _detachPlayer();
        _barrage.clear();
        setState(() {
          _stageCleared = true;
          _timeline = null;
          _danmakuLoading = false;
        });
      }
    }
    try {
      await File(item.path).delete();
    } on Object {
      if (mounted) showDsToast(context: context, title: t.common.previewDeleteFailed, status: DsStatus.danger);
      return;
    }
    // The row re-reads the disk and greys itself; the stage, if it was the one
    // dropped for the delete, comes back to say 文件不在了 rather than that the
    // preview has nothing to show.
    if (mounted) setState(() => _stageCleared = false);
    // The owner's record follows the file.
    await widget.onDeleted?.call(item);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final width = MediaQuery.sizeOf(context).width;
    final narrow = width < _inlineWidth;
    final presentation = ref.watch(roomPresentationProvider);
    // A mode that owns the window takes the whole screen: the header and the
    // list column step out and the bar carries what they held.
    final immersive = _presentation.modeOwnsWindow(presentation);
    // The desktop compact window is a picture too small to carry the page's
    // chrome: its own bar plays, and the overlays stay out of it.
    final pipOwned = presentation == PresentationMode.pip && _presentation.pipOwnsWindow;
    // Cached for `dispose`, where the provider scope may already be gone: the
    // leaving page hands back the screen it took from its own field, not from
    // `ref`.
    _presentationMode = presentation;
    ref.listen<PresentationMode>(roomPresentationProvider, (previous, next) {
      // A phone turns the way the picture is shaped, and only for the system
      // fullscreen; the driver's own exit path puts the lock back.
      if (next == PresentationMode.fullscreen && previous != PresentationMode.fullscreen) {
        applyFullscreenOrientation(_screenOrientation, aspectRatio: _aspectRatio);
      }
      // The chrome folds as a mode takes the window and unfolds as it hands
      // it back; a drawer left open across the switch would hang in a layout
      // that no longer has it.
      if (next == PresentationMode.normal) _setDrawerOpen(false);
    });
    // The layer comes back as a new engine; the timeline it had is gone with
    // the old one, so the page puts the decoded track back on it.
    ref.listen<bool>(playbackSettingsProvider.select((settings) => settings.danmakuVisible), (previous, next) {
      if (next) _scheduleTimeline();
    });
    return PopScope(
      canPop: !immersive && !_theater && !(narrow && _listOpen) && !_drawerOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (immersive) {
          if (_drawerOpen) {
            _setDrawerOpen(false);
            return;
          }
          unawaited(_toggleFullscreen());
          return;
        }
        setState(() {
          _theater = false;
          _listOpen = false;
        });
      },
      child: ColoredBox(
        // The page wears the theme; the picture's own box paints its dark
        // behind it (and the whole page while a mode owns the window).
        color: immersive ? _stage : DsTheme.colorsOf(context).canvas,
        child: immersive
            ? SafeArea(
                child: _immersiveStage(t, compact: LiveWindow.isCompact(width), pipOwned: pipOwned),
              )
            : SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(t, narrow: narrow),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final inline = constraints.maxWidth >= _inlineWidth;
                          final list = _previewList();
                          if (!inline) {
                            if (_listOpen) return list;
                            return _stageOf(t, compact: LiveWindow.isCompact(constraints.maxWidth));
                          }
                          // The bar's own room is what the stage got, not what the
                          // window has: the list column takes part of the width.
                          final stage = _stageOf(
                            t,
                            compact: LiveWindow.isCompact(constraints.maxWidth - _listWidth - 10),
                          );
                          if (_theater) {
                            // The theatre: the picture owns the body and the list
                            // floats over its end edge, on the theme's surface so
                            // it still reads against whatever is playing behind it.
                            final colors = DsTheme.colorsOf(context);
                            return Stack(
                              children: [
                                Positioned.fill(child: stage),
                                PositionedDirectional(
                                  top: DsSpace.s12,
                                  bottom: DsSpace.s12,
                                  end: DsSpace.s12,
                                  width: _listWidth,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(DsTheme.of(context).radii.card),
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: colors.surface.withValues(alpha: 0.94),
                                        border: Border.all(color: colors.border),
                                      ),
                                      child: list,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: stage),
                              _Splitter(
                                onDrag: (delta) =>
                                    setState(() => _listWidth = (_listWidth - delta).clamp(_listMin, _listMax)),
                                onReset: () => setState(() => _listWidth = _listDefault),
                              ),
                              SizedBox(
                                width: _listWidth,
                                child: DecoratedBox(
                                  // The column is chrome, not part of the
                                  // picture: it wears the theme's surface and
                                  // its own hairline rather than a white wash
                                  // that only reads on black.
                                  decoration: BoxDecoration(
                                    color: DsTheme.colorsOf(context).surface,
                                    border: BorderDirectional(
                                      start: BorderSide(color: DsTheme.colorsOf(context).border),
                                    ),
                                  ),
                                  child: list,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  /// The list, built once for every arrangement that shows it: the inline
  /// column, the theatre's float and the immersive drawer are three rooms for
  /// the same widget.
  Widget _previewList() => _PreviewList(
    items: widget.items,
    current: _index,
    onSelect: _select,
    onOpenFolder: _revealFolderAt,
    onDelete: _deleteAt,
    // The folder a group header names; no groups means no button on the list.
    onOpenGroup: widget.items.any((item) => item.groupPath.trim().isNotEmpty)
        ? (folder) => unawaited(_revealFolder(folder))
        : null,
    autoNext: _autoNext,
    onAutoNext: widget.items.length > 1 ? (value) => setState(() => _autoNext = value) : null,
  );

  /// The immersive layout, the room's own arrangement: the picture fills the
  /// window and the file list — which the inline layout keeps beside it —
  /// lives on a drawer at the picture's end edge. A 28px glass tab summons
  /// the 280px column, and the column closes again when the pointer leaves
  /// it, so a playing take is one hover away from being alone.
  Widget _immersiveStage(Translations t, {required bool compact, required bool pipOwned}) {
    final stage = _stageOf(t, compact: compact, immersive: true);
    if (pipOwned) return stage;
    final colors = DsTheme.colorsOf(context);
    return Stack(
      children: [
        Positioned.fill(child: stage),
        PositionedDirectional(
          top: 0,
          bottom: 0,
          end: 0,
          child: MouseRegion(
            onExit: _drawerOpen ? (_) => _setDrawerOpen(false) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: _drawerOpen ? _drawerWidth : _drawerTabWidth,
              child: _drawerOpen
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.surface.withValues(alpha: 0.94),
                        border: BorderDirectional(start: BorderSide(color: colors.border)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s8, DsSpace.s8, DsSpace.s4, 0),
                            child: Row(
                              children: [
                                const Spacer(),
                                DsButton.icon(
                                  variant: DsButtonVariant.ghost,
                                  size: DsSize.sm,
                                  onPressed: () => _setDrawerOpen(false),
                                  icon: const DsIcon(DsIcons.panelRightClose),
                                  semanticLabel: t.common.previewCollapseList,
                                ),
                              ],
                            ),
                          ),
                          Expanded(child: _previewList()),
                        ],
                      ),
                    )
                  : Center(
                      child: MouseRegion(
                        onEnter: (_) => _setDrawerOpen(true),
                        child: GestureDetector(
                          onTap: () => _setDrawerOpen(true),
                          child: _DrawerTab(label: t.common.previewDrawerLabel),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _header(Translations t, {required bool narrow}) {
    final item = _current;
    // The header and the list are the page's chrome, so they wear the theme's
    // ink; only the picture's own box stays dark whatever the theme is.
    final colors = DsTheme.colorsOf(context);
    // The header keeps only the file's own errands — walk the list, open what
    // is playing, take it off the disk. The verbs that act on the picture
    // itself (the frame copy, where it goes, its sound and its danmaku) live
    // over the picture, at its top-right corner and on the player's bar,
    // where the hand already is while watching.
    final size = narrow ? 30.0 : 36.0;
    Widget button(DsIconData icon, String semanticLabel, {VoidCallback? onPressed}) =>
        _HeaderButton(icon: icon, semanticLabel: semanticLabel, onPressed: onPressed, size: size);
    final actions = <Widget>[
      if (widget.items.length > 1 && !(narrow && _listOpen)) ...[
        button(DsIcons.chevronLeft, t.common.previewPrevious, onPressed: _index > 0 ? () => _select(_index - 1) : null),
        button(
          DsIcons.chevronRight,
          t.common.previewNext,
          onPressed: _index < widget.items.length - 1 ? () => _select(_index + 1) : null,
        ),
      ],
      if (narrow)
        button(
          _listOpen ? DsIcons.playCircle : DsIcons.listVideo,
          _listOpen ? t.common.previewBackToStage : t.common.previewListTitle,
          onPressed: () => setState(() => _listOpen = !_listOpen),
        ),
      if (item case final entry? when entry.exists) ...[
        // The file's own verbs on the bar that names it. Hiding them in the
        // list's row menu made the stage a viewer cannot act from: the
        // picture on it is what they came to look at, and the moment they
        // want another player or want it gone is here, not three taps away.
        button(
          DsIcons.externalLink,
          t.common.previewOpenFile,
          onPressed: () => unawaited(openDownloadedPath(context, entry.path)),
        ),
        button(DsIcons.folderOpen, t.common.previewOpenFolder, onPressed: () => unawaited(_revealFolderOf(entry.path))),
        button(DsIcons.trash2, t.common.previewDeleteFile, onPressed: () => unawaited(_deleteAt(_index))),
      ] else if (item != null)
        button(DsIcons.folderOpen, t.common.previewOpenFolder, onPressed: () => unawaited(_revealFolderOf(item.path))),
    ];
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s8, DsSpace.s8, DsSpace.s12, DsSpace.s8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Beside the title wherever the bar can hold both; on a phone the
          // same set folds onto a line of its own rather than falling off.
          final inline = constraints.maxWidth >= 720;
          final row = Row(
            spacing: DsSpace.s8,
            children: [
              DsButton.icon(
                variant: DsButtonVariant.ghost,
                size: DsSize.sm,
                semanticLabel: t.common.back,
                onPressed: () => _leave(context, immersive: false, narrow: narrow),
                icon: DsIcon(DsIcons.chevronLeft, color: colors.text),
              ),
              // The page covers the shell's strip, so this bar is the window's
              // caption: the title is the drag band, the three buttons end it.
              Expanded(
                child: routeCaptionTitle(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    spacing: DsSpace.s3,
                    children: [
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DsTheme.of(context).typography.title.copyWith(color: colors.text),
                      ),
                      if (item != null)
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DsTheme.of(context).typography.caption.copyWith(color: colors.textMuted),
                        ),
                    ],
                  ),
                ),
              ),
              if (inline)
                Wrap(
                  spacing: DsSpace.s4,
                  runSpacing: DsSpace.s4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: actions,
                ),
              RouteCaptionTail(ink: colors.text),
            ],
          );
          if (inline) return row;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s4,
            children: [
              row,
              Wrap(
                spacing: DsSpace.s4,
                runSpacing: DsSpace.s4,
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: actions,
              ),
            ],
          );
        },
      ),
    );
  }

  /// The picture's own ground: dark whatever the theme, because a frame is
  /// read against black and the overlay's ink is cut for it.
  Widget _stageBox(Widget child) => ColoredBox(color: _stage, child: child);

  /// The face of 音频模式: what is playing, said on the stage's own dark. It
  /// covers the frame, so the words are the overlay's ink rather than the
  /// theme's — the same rule the stage's other states follow.
  Widget _audioCover(MediaPreviewItem item) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      spacing: DsSpace.s12,
      children: [
        const DsIcon(DsIcons.headphones, size: 40, color: playerInkSubtle),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Text(
            item.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: DsTheme.of(context).typography.title.copyWith(color: playerInk),
          ),
        ),
        if (item.subtitle.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              item.subtitle,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: DsTheme.of(context).typography.caption.copyWith(color: playerInkMuted),
            ),
          ),
      ],
    ),
  );

  Widget _stageOf(Translations t, {required bool compact, bool immersive = false}) {
    final item = _current;
    if (item == null) {
      // The stage is a picture's black whatever the app's theme, so its words
      // are the overlay's ink rather than the theme's (a light theme's text
      // would be dark on dark).
      return _stageBox(
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: DsSpace.s8,
            children: [
              const DsIcon(DsIcons.playCircle, size: 32, color: playerInkSubtle),
              Text(t.common.previewEmpty, style: DsTheme.of(context).typography.title.copyWith(color: playerInk)),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Text(
                  t.common.previewEmptyDescription,
                  textAlign: TextAlign.center,
                  style: DsTheme.of(context).typography.caption.copyWith(color: playerInkMuted),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (!item.exists) {
      return _stageBox(
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: DsSpace.s8,
            children: [
              const DsIcon(DsIcons.fileX, size: 32, color: playerInkSubtle),
              Text(t.common.previewFileMissing, style: DsTheme.of(context).typography.title.copyWith(color: playerInk)),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Text(
                  t.common.previewFileMissingDescription,
                  textAlign: TextAlign.center,
                  style: DsTheme.of(context).typography.caption.copyWith(color: playerInkMuted),
                ),
              ),
              DsButton(
                variant: DsButtonVariant.secondary,
                size: DsSize.sm,
                leading: const DsIcon(DsIcons.folderOpen, size: 16),
                onPressed: () => unawaited(_revealFolderOf(item.path)),
                child: Text(t.common.previewOpenFolder),
              ),
            ],
          ),
        ),
      );
    }
    final style = ref.watch(danmakuStyleProvider);
    final fps = ref.watch(danmakuEffectiveFpsProvider);
    final visible = ref.watch(playbackSettingsProvider.select((settings) => settings.danmakuVisible));
    final showLayer = visible && _hasDanmaku;
    // The player owns its transport (play, mute, seek, clock); the page owns
    // which file it plays, adds its own verbs to the bar's end, and remounts
    // the picture when the list chooses another.
    // The picture is placed the way the room's is: the viewer's 画面适配 is one
    // rule for every surface in the app, not a choice a preview re-decides.
    final fit = ref.watch(playbackSettingsProvider.select((settings) => settings.fit));
    // The same numbers panel the room puts over a stream, on the same session
    // switch — a viewer who turned it on to read a live bitrate gets it here too.
    final stats = ref.watch(playerStatsVisibleProvider);
    final stage = _stageBox(
      WallpaperVideoPlayer(
        key: ValueKey(item.path),
        uri: File(item.path).uri,
        fit: fit.boxFit,
        // A preview of one take stops on its last frame; looping is the bar's
        // own switch, and the engine only honours it for the next completion.
        loop: false,
        // The bar settles away on the app's own clock while a take plays, and
        // stays up when it does not — the same delay every player here reads
        // from 画面与浮窗.
        barHideAfter: Duration(
          seconds: ref.watch(playbackSettingsProvider.select((settings) => settings.controlsAutoHideSeconds)),
        ),
        onHandle: _onHandle,
        onBarVisibleChanged: (value) {
          if (!mounted || _chromeVisible == value) return;
          setState(() => _chromeVisible = value);
        },
        overlay: _audioOnly
            // 音频模式 covers the picture rather than replacing the stage: the
            // engine keeps running behind it, which is the whole point — the
            // mode stops decoding video, not playing the file. The danmaku layer
            // stands down for the same reason it has nothing to fly over.
            ? _audioCover(item)
            : showLayer
            ? FlameBarrageWidget(
                key: const ValueKey('media-preview-danmaku'),
                config: playerBarrageConfig(style, fps, family: resolvedFontFamily(style.fontFamily)),
                emojiAtlas: EmojiAtlas.instance,
                controller: _barrage,
              )
            : null,
        // The bar carries the whole transport now — the page's own verbs ride
        // its right end at every width, so there is no dock under the picture
        // to keep in sync with it.
        barActions: _barActions(
          t,
          compact: compact,
          visible: visible,
          has: _hasDanmaku,
          loading: _danmakuLoading,
          immersive: immersive,
        ),
      ),
    );
    // The numbers sit over the picture, not in the bar: they are read against
    // the frame they describe, and the bar has no room for eight figures. The
    // volume chip is the picture's own answer to a drag or a wheel.
    final player = _handle;
    // The chrome over the picture follows the bar: a take that is playing and
    // alone has no pills over it and no arrows on its edges. The drawer's tab
    // claims the end edge in the immersive layout, so the next arrow steps
    // inboard of it.
    final chrome = _chromeVisible;
    final showArrows = chrome && widget.items.length > 1;
    final endInset = immersive && !(_presentationMode == PresentationMode.pip && _presentation.pipOwnsWindow)
        ? (_drawerOpen ? _drawerWidth : _drawerTabWidth) + DsSpace.s8
        : DsSpace.s8;
    final layers = <Widget>[
      stage,
      if (player != null && stats)
        Positioned.fill(
          child: IgnorePointer(child: PlayerStatsOverlay(handle: player)),
        ),
      if (_volumeHud case final value?)
        PositionedDirectional(
          end: DsSpace.s20,
          top: 0,
          bottom: 0,
          child: PlayerVolumeHud(value: value),
        ),
      if (chrome)
        PositionedDirectional(
          top: DsSpace.s12,
          end: DsSpace.s12,
          child: _topActions(t, immersive: immersive),
        ),
      // The neighbours, on the picture's own edges where a viewer's hand
      // already is: step past a take without aiming at a corner button.
      if (showArrows && _index > 0)
        PositionedDirectional(
          top: 0,
          bottom: 0,
          start: 0,
          width: 48,
          child: Center(child: _EdgeArrow(forward: false, onPressed: () => _select(_index - 1))),
        ),
      if (showArrows && _index < widget.items.length - 1)
        PositionedDirectional(
          top: 0,
          bottom: 0,
          end: endInset,
          width: 48,
          child: Center(child: _EdgeArrow(forward: true, onPressed: () => _select(_index + 1))),
        ),
    ];
    final stack = Listener(
      onPointerSignal: (signal) {
        if (signal is PointerScrollEvent) _wheelVolume(signal.scrollDelta.dy);
      },
      child: GestureDetector(
        // Translucent and without a tap handler: the picture keeps its own
        // tap-to-pause, and the drag claims only a gesture the frame is not
        // already using.
        behavior: HitTestBehavior.translucent,
        onVerticalDragStart: (_) => _beginVolumeDrag(),
        onVerticalDragUpdate: (move) => _dragVolumeBy(move.delta.dy),
        child: Stack(fit: StackFit.expand, children: layers),
      ),
    );
    // The bar carries every verb at every width now, so the stage is the
    // picture and its overlays, with nothing under it to keep in step.
    return stack;
  }

  /// The verbs that act on the picture itself, parked at its top-right corner
  /// in glass pills: the frame's copy, where the picture goes (投屏, the small
  /// window), and the ⋮ that holds the quieter ones. The page header keeps
  /// only the file's own errands, so a verb never moves between two bars
  /// depending on how the window is dressed.
  Widget _topActions(Translations t, {required bool immersive}) {
    final handle = _handle;
    final pip = ref.watch(roomPresentationProvider) == PresentationMode.pip;
    Widget pill(DsIconData icon, String label, {VoidCallback? onPressed}) => PlayerGlassPill(
      child: PlayerBarButton(icon: icon, label: label, onPressed: onPressed),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: DsSpace.s8,
      children: [
        // A kernel that cannot hand a frame back loses the pill rather than
        // offering one that only toasts a failure.
        if (handle?.canCaptureScreenshot ?? false)
          pill(DsIcons.camera, t.room.screenshot, onPressed: () => unawaited(_screenshot())),
        // 投屏 of the file itself. A renderer cannot read this disk, but the
        // DLNA backend serves the path over the LAN through its own media
        // server, so a finished take casts the way a stream does.
        if (_current case final entry? when entry.exists)
          pill(
            DsIcons.cast,
            t.room.cast,
            onPressed: () =>
                unawaited(showCastUriDialog(context, url: File(entry.path).uri.toString(), title: entry.title)),
          ),
        if (handle != null && _presentation.pipAvailable)
          pill(
            pip ? DsIcons.pictureInPictureExit : DsIcons.pictureInPicture,
            pip ? t.room.pipOff : t.vod.pip,
            onPressed: () => unawaited(_togglePip()),
          ),
        PlayerGlassPill(
          child: DsMenuAnchor(
            semanticLabel: t.common.more,
            align: DsAlign.end,
            items: [
              // The sound without the picture, the framing, the stream's own
              // numbers: the quieter verbs, said in the menu the header used
              // to spread across itself.
              DsMenuItem(
                leading: DsIcon(_audioOnly ? DsIcons.video : DsIcons.headphones),
                label: Text(_audioOnly ? t.room.restoreVideo : t.room.audioOnlyMode),
                checked: _audioOnly,
                onPressed: handle == null ? null : () => unawaited(_setAudioOnly(!_audioOnly)),
              ),
              for (final (index, option) in PlaybackFit.values.indexed)
                DsMenuItem(
                  label: Text(fitLabels(t)[index]),
                  checked: option == ref.watch(playbackSettingsProvider.select((settings) => settings.fit)),
                  onPressed: () => unawaited(ref.read(playbackSettingsProvider.notifier).setFit(option)),
                ),
              DsMenuItem(
                leading: const DsIcon(DsIcons.activity),
                label: Text(t.room.statsToggle),
                checked: ref.watch(playerStatsVisibleProvider),
                onPressed: handle == null ? null : () => ref.read(playerStatsVisibleProvider.notifier).toggle(),
              ),
              // The theatre needs the list column to float, which a narrow
              // window has no room for and a mode that owns the window does
              // not need. The pills row is only drawn in-page (the header's
              // layout is gone once a mode owns the window), so this is
              // where the verb is offered from.
              if (!immersive)
                DsMenuItem(
                  leading: const DsIcon(DsIcons.layoutHeaderSidebarRight),
                  label: Text(_theater ? t.room.theaterOff : t.room.theaterOn),
                  onPressed: () => setState(() => _theater = !_theater),
                ),
              DsMenuItem(
                leading: const DsIcon(DsIcons.slidersHorizontal),
                label: Text(t.common.previewDanmakuSettings),
                onPressed: _openDanmakuSettings,
              ),
            ],
            builder: (context, controller, _) =>
                PlayerBarButton(icon: DsIcons.ellipsisVertical, label: t.common.more, onPressed: controller.toggle),
          ),
        ),
      ],
    );
  }

  /// The bar's right end, the page's own verbs in the player's row: the
  /// volume the page drives (a drag or a wheel sets it too), the speed, the
  /// loop, the danmaku pair, and the two ways out of the box — the in-app
  /// fullscreen first, the system's behind it, the room bar's own order.
  ///
  /// A touch width has no room for a slider or the speed's number, so they
  /// fold: the volume leaves (mute is the player's button at any width) and
  /// the speed keeps its glyph.
  List<Widget> _barActions(
    Translations t, {
    required bool compact,
    required bool visible,
    required bool has,
    required bool loading,
    required bool immersive,
  }) {
    final handle = _handle;
    final presentation = ref.watch(roomPresentationProvider);
    final windowFullscreen = presentation == PresentationMode.windowFullscreen;
    return [
      if (!compact)
        SizedBox(
          width: 96,
          child: DsSlider(
            value: _volume,
            semanticLabel: t.room.volume,
            onChanged: handle == null ? null : (value) => unawaited(_setVolume(value)),
          ),
        ),
      // The speed as a chip that says what it would set — a number a viewer
      // chose is a state worth reading, not only a menu to open.
      DsMenuAnchor(
        semanticLabel: t.common.previewSpeed,
        align: DsAlign.end,
        items: [
          for (final value in kPreviewRates)
            DsMenuItem(
              label: Text(_rateLabel(value)),
              checked: value == _rate,
              onPressed: () => unawaited(_setRate(value)),
            ),
        ],
        builder: (context, controller, _) => compact
            ? PlayerBarButton(
                icon: DsIcons.gauge,
                label: t.common.previewSpeed,
                selected: _rate != 1,
                onPressed: handle == null ? null : controller.toggle,
              )
            : PlayerGlassPill(
                child: DsPressable(
                  semanticLabel: t.common.previewSpeed,
                  onPressed: handle == null ? null : controller.toggle,
                  builder: (context, states, _) {
                    final lit = states.contains(WidgetState.hovered) || states.contains(WidgetState.pressed);
                    return Container(
                      height: DsTheme.of(context).sizes.sm,
                      padding: const EdgeInsetsDirectional.symmetric(horizontal: DsSpace.s8),
                      color: lit ? const Color(0x24FFFFFF) : null,
                      child: Center(
                        child: Text(
                          _rateLabel(_rate),
                          style: DsTheme.of(context).typography.numeric(
                            DsTheme.of(context).typography.caption
                                .copyWith(color: _rate == 1 ? const Color(0xCCFFFFFF) : playerInk),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
      // The take again from its top when it ends: the engine's own switch, so
      // a press only has to reach the handle.
      PlayerBarButton(
        icon: DsIcons.repeat,
        label: t.common.previewLoop,
        selected: _loop,
        onPressed: () => unawaited(_setLoop(!_loop)),
      ),
      // The flying danmaku's switch beside the gear that opens its settings —
      // the pair the room's bar draws at the reading end. Without a sidecar
      // the switch stays in place but out of reach, and says why.
      _DanmakuToggle(
        on: has && visible,
        label: loading
            ? t.common.previewDanmakuLoading
            : has
            ? (visible ? t.vod.danmakuOff : t.vod.danmakuOn)
            : t.common.previewDanmakuOff,
        onPressed: has
            ? () => unawaited(ref.read(playbackSettingsProvider.notifier).setDanmakuVisible(value: !visible))
            : null,
      ),
      PlayerBarButton(
        icon: DsIcons.slidersHorizontal,
        label: t.common.previewDanmakuSettings,
        onPressed: _openDanmakuSettings,
      ),
      // The window's own verbs: the in-app fullscreen where a desktop can
      // fill its window, and the system fullscreen whose button doubles as
      // the way back out of whichever mode is active.
      if (_desktop)
        PlayerBarButton(
          icon: windowFullscreen ? DsIcons.shrink : DsIcons.expand,
          label: windowFullscreen ? t.room.windowFullscreenOff : t.room.windowFullscreenOn,
          selected: windowFullscreen,
          onPressed: handle == null ? null : () => unawaited(_toggleWindowFullscreen()),
        ),
      PlayerBarButton(
        icon: immersive ? DsIcons.minimize : DsIcons.maximize,
        label: immersive ? t.room.fullscreenOff : t.room.fullscreenOn,
        selected: immersive,
        onPressed: handle == null ? null : () => unawaited(_toggleFullscreen()),
      ),
    ];
  }

  /// Whether this host offers the in-app window-fullscreen button: a desktop
  /// can fill its own window, a phone has nothing to fill.
  bool get _desktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);
}

/// The list itself: what the page can play, current entry first-class.
final class _PreviewList extends StatelessWidget {
  const _PreviewList({
    required this.items,
    required this.current,
    required this.onSelect,
    required this.onOpenFolder,
    required this.onDelete,
    this.onOpenGroup,
    this.autoNext = false,
    this.onAutoNext,
  });

  final List<MediaPreviewItem> items;
  final int current;
  final ValueChanged<int> onSelect;

  /// The row's own file verbs: where the entry sits, and taking it away.
  final ValueChanged<int> onOpenFolder;
  final ValueChanged<int> onDelete;

  /// A group header's folder: the room whose takes are listed under it. Null
  /// when the caller has no groups, which is the flat list every other module
  /// hands the page.
  final ValueChanged<String>? onOpenGroup;

  /// Whether a finished entry leads to the next one, and the switch that sets
  /// it — the switch only exists once the list has a next to lead to.
  final bool autoNext;
  final ValueChanged<bool>? onAutoNext;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    if (items.isEmpty) {
      return Center(
        child: Text(t.common.previewEmpty, style: theme.typography.caption.copyWith(color: colors.textSubtle)),
      );
    }
    // The run reads as the tree that filed it: a header names the room whose
    // takes follow it. Items that carry no group — a download queue, a loose
    // clip — stay the plain numbered list they always were.
    final lines = <_PreviewLine>[];
    String? seen;
    for (var index = 0; index < items.length; index++) {
      final group = items[index].groupLabel.trim();
      if (group.isNotEmpty && group != seen) {
        final under = items.where((item) => item.groupLabel.trim() == group).toList();
        lines.add(
          _PreviewLine.header(
            group,
            under.length,
            items[index].groupPath,
            // The group's own picture, said once over the rows that repeat the
            // same series title thirty times. A task queued before the queue
            // kept covers has none, so the first one the group holds wins.
            under.map((item) => item.cover.trim()).firstWhere((cover) => cover.isNotEmpty, orElse: () => ''),
          ),
        );
        seen = group;
      }
      lines.add(_PreviewLine.item(index));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s16, DsSpace.s12, DsSpace.s16, DsSpace.s8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s6,
            children: [
              Text(
                t.common.previewCount(count: items.length),
                style: theme.typography.overline.copyWith(color: colors.textMuted),
              ),
              // The walk-on rule belongs with the list it moves through, not
              // on the picture: it is a fact about the queue, not the frame.
              if (onAutoNext case final setAutoNext?)
                Row(
                  spacing: DsSpace.s8,
                  children: [
                    Expanded(
                      child: Text(
                        t.common.previewAutoNext,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.caption.copyWith(color: colors.textMuted),
                      ),
                    ),
                    DsSwitch(value: autoNext, onChanged: setAutoNext),
                  ],
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: DsSpace.s12),
            itemCount: lines.length,
            itemBuilder: (context, position) {
              final header = lines[position].group;
              if (header != null) {
                return _PreviewHeader(
                  label: header,
                  count: lines[position].count,
                  folder: lines[position].folder,
                  cover: lines[position].cover,
                  onOpen: onOpenGroup,
                );
              }
              final index = lines[position].index;
              final item = items[index];
              final selected = index == current;
              final exists = item.exists;
              return DsPressable(
                semanticLabel: item.title,
                onPressed: () => onSelect(index),
                builder: (context, states, _) {
                  final hovered = states.contains(WidgetState.hovered);
                  return Container(
                    padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s12, DsSpace.s8, DsSpace.s12, DsSpace.s8),
                    decoration: BoxDecoration(
                      color: selected
                          ? colors.accent.withValues(alpha: 0.22)
                          : hovered
                          ? colors.hover
                          : null,
                      border: BorderDirectional(
                        start: BorderSide(color: selected ? colors.accent : const Color(0x00000000), width: 2),
                      ),
                    ),
                    child: Row(
                      spacing: DsSpace.s8,
                      children: [
                        SizedBox(
                          width: 20,
                          child: Text(
                            '${index + 1}',
                            textAlign: TextAlign.end,
                            style: theme.typography.numeric(
                              theme.typography.caption.copyWith(color: selected ? colors.accent : colors.textSubtle),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            spacing: DsSpace.s3,
                            children: [
                              Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.typography.body.copyWith(
                                  color: exists ? colors.text : colors.textSubtle,
                                  fontWeight: selected ? FontWeight.w600 : null,
                                ),
                              ),
                              if (item.subtitle.isNotEmpty)
                                Text(
                                  item.subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.typography.caption.copyWith(color: colors.textMuted),
                                ),
                            ],
                          ),
                        ),
                        if (!exists) DsIcon(DsIcons.fileX, size: 14, color: colors.danger.fill),
                        // The file's own verbs, on the row that names it: a
                        // gone file has neither to offer.
                        if (exists)
                          DsMenuAnchor(
                            semanticLabel: t.common.more,
                            align: DsAlign.end,
                            builder: (context, controller, child) => DsPressable(
                              semanticLabel: t.common.more,
                              onPressed: controller.toggle,
                              builder: (context, states, _) {
                                final hovered = states.contains(WidgetState.hovered);
                                return Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: hovered ? colors.hover : null,
                                  ),
                                  child: Center(
                                    child: DsIcon(
                                      DsIcons.ellipsisVertical,
                                      size: 14,
                                      color: hovered ? colors.text : colors.textSubtle,
                                    ),
                                  ),
                                );
                              },
                            ),
                            items: [
                              DsMenuItem(
                                leading: const DsIcon(DsIcons.folderOpen),
                                label: Text(t.common.previewOpenFolder),
                                onPressed: () => onOpenFolder(index),
                              ),
                              DsMenuItem(
                                leading: const DsIcon(DsIcons.trash2),
                                label: Text(t.common.previewDeleteFile),
                                destructive: true,
                                onPressed: () => onDelete(index),
                              ),
                            ],
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// The draggable line between the picture and the list.
final class _Splitter extends StatelessWidget {
  const _Splitter({required this.onDrag, required this.onReset});

  /// How far the pointer moved; the page turns it into a width.
  final ValueChanged<double> onDrag;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
        // A double press is the way back to the width the page starts with.
        onDoubleTap: onReset,
        child: const SizedBox(
          width: 10,
          child: Center(
            child: SizedBox(width: 1, height: 48, child: ColoredBox(color: Color(0x33FFFFFF))),
          ),
        ),
      ),
    );
  }
}

/// One icon in the preview's header.
final class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.icon, required this.semanticLabel, this.onPressed, this.size = 36});

  final DsIconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;

  /// The button's square; a phone's folded line uses a tighter one so the set
  /// still fits a thumb-wide bar.
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    return DsPressable(
      semanticLabel: semanticLabel,
      onPressed: onPressed,
      builder: (context, states, _) {
        final hovered = states.contains(WidgetState.hovered);
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: hovered ? colors.hover : null),
          child: Center(
            child: DsIcon(
              icon,
              size: size / 2,
              color: onPressed == null
                  ? colors.textSubtle
                  : hovered
                  ? colors.text
                  : colors.textMuted,
            ),
          ),
        );
      },
    );
  }
}

/// The glass tab that waits at the immersive picture's end edge: a chevron
/// and the drawer's name written down the strip — the room's chat drawer's
/// own tab, saying 列表 instead of 弹幕列. A hover summons the column; a tap
/// does the same where there is no pointer.
final class _DrawerTab extends StatelessWidget {
  const _DrawerTab({required this.label});

  /// The drawer's name, written one rune per line.
  final String label;

  @override
  Widget build(BuildContext context) {
    // The tab sits on the picture's dark glass, so its letters take the
    // overlay's ink rather than the theme's — a light skin's text would turn
    // dark-on-dark exactly as it would on a video frame.
    return PlayerGlassPill(
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(vertical: DsSpace.s8, horizontal: DsSpace.s4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DsIcon(DsIcons.chevronLeft, size: 14, color: playerInkMuted),
            for (final rune in label.runes)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Text(
                  String.fromCharCode(rune),
                  style: DsTheme.of(context).typography.caption.copyWith(color: playerInk),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The flying danmaku's round 「弹」 switch, the room bar's own control: a
/// circle that fills with the accent while the lines are on, beside the gear
/// that opens their settings. Over the picture's dark bar it takes the
/// overlay's ink rather than the theme's, like every button beside it.
final class _DanmakuToggle extends StatelessWidget {
  const _DanmakuToggle({required this.on, required this.label, this.onPressed});

  /// Whether the lines are flying.
  final bool on;

  /// What the switch says to a screen reader and the tooltip.
  final String label;

  /// Fired on tap; null draws the switch out of reach.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final side = theme.sizes.sm;
    return DsTooltip(
      message: label,
      child: DsPressable(
        semanticLabel: label,
        onPressed: onPressed,
        builder: (context, states, _) {
          return Container(
            width: side,
            height: side,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: on ? theme.colors.accent : const Color(0x00000000),
              border: on ? null : Border.all(color: const Color(0x59FFFFFF)),
            ),
            child: Text(
              context.t.room.danmakuMark,
              style: theme.typography.caption.copyWith(
                color: on ? theme.colors.onAccent : playerInkMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The neighbour step on the picture's own edge: a glass tile at the vertical
/// middle, going to the previous or the next entry. A take is switched where
/// the hand already is, and the arrow that has no neighbour to offer hides
/// rather than sitting there dead.
final class _EdgeArrow extends StatelessWidget {
  const _EdgeArrow({required this.forward, required this.onPressed});

  /// Whether the arrow leads to the next entry (the end edge) rather than to
  /// the previous one (the start edge).
  final bool forward;

  /// What stepping does.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return PlayerGlassPill(
      child: PlayerBarButton(
        icon: forward ? DsIcons.chevronRight : DsIcons.chevronLeft,
        label: forward ? t.common.previewNext : t.common.previewPrevious,
        onPressed: onPressed,
      ),
    );
  }
}

/// The folder a preview's file lives in, for a caller that wants it.
String previewFolderOf(MediaPreviewItem item) => p.dirname(item.path);

/// One line of the preview list: an entry, or the header naming the folder the
/// entries under it came from.
final class _PreviewLine {
  const _PreviewLine.item(this.index) : group = null, count = 0, folder = '', cover = '';
  const _PreviewLine.header(this.group, this.count, this.folder, this.cover) : index = -1;

  final int index;
  final String? group;
  final int count;

  /// The folder the header names, which is what its button opens — the label is
  /// the room's title, not a path anyone can show in a file manager.
  final String folder;

  /// The group's picture, empty when none of its entries carries one.
  final String cover;
}

/// The group's own line: what it is, how many it holds, and the one verb a
/// folder answers to on its own — showing it in the file manager. Its picture
/// sits here rather than on every row under it, because thirty episodes of one
/// series share it.
final class _PreviewHeader extends StatelessWidget {
  const _PreviewHeader({required this.label, required this.count, required this.folder, this.cover = '', this.onOpen});

  final String label;
  final int count;
  final String folder;

  /// The series' or room's picture; empty leaves the line as the text it was.
  final String cover;

  /// Null leaves the header as plain text, which is all a list without folders
  /// can offer.
  final ValueChanged<String>? onOpen;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s12, 10, DsSpace.s8, DsSpace.s4),
      child: Row(
        spacing: DsSpace.s6,
        children: [
          if (cover.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(theme.radii.control(28)),
              child: SizedBox(
                width: 28,
                height: 28,
                child: DsImage(
                  image: cachedImage(cover, policy: ImageCachePolicies.videoCover),
                  aspectRatio: 1,
                  semanticLabel: label,
                  fallback: ColoredBox(color: colors.control),
                ),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: DsSpace.s3,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.caption.copyWith(color: colors.text, fontWeight: FontWeight.w600),
                ),
                Text(
                  t.common.previewCount(count: count),
                  style: theme.typography.caption.copyWith(color: colors.textSubtle),
                ),
              ],
            ),
          ),
          if (onOpen case final open?)
            DsButton.icon(
              variant: DsButtonVariant.ghost,
              size: DsSize.xs,
              onPressed: folder.trim().isEmpty ? null : () => open(folder),
              icon: const DsIcon(DsIcons.folderOpen, size: 14),
              semanticLabel: t.common.previewOpenFolder,
            ),
        ],
      ),
    );
  }
}
