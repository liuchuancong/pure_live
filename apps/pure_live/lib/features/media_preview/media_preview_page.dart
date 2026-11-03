import 'dart:async' show StreamSubscription, Timer, unawaited;
import 'dart:convert' show utf8;
import 'dart:io' show File;

import 'package:desen_ui/desen_ui.dart';
import 'package:flame_barrage/flame_barrage.dart' show BarrageController, BarrageItem, EmojiAtlas, FlameBarrageWidget;
import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouter;
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
import 'package:pure_live/features/media_preview/media_preview_danmaku.dart' show MediaPreviewDanmakuPanel;
import 'package:pure_live/features/media_preview/media_preview_item.dart';
import 'package:pure_live/features/settings/pages/wallpaper_download_manager.dart' show openDownloadedPath;
import 'package:pure_live/features/settings/pages/wallpaper_video_player.dart' show WallpaperVideoPlayer;
import 'package:pure_live/features/settings/settings.dart'
    show
        PlaybackFit,
        SettingsPreviewCircleButton,
        SettingsSection,
        danmakuEffectiveFpsProvider,
        danmakuStyleProvider,
        fitLabels,
        openSettingsSection,
        playbackSettingsProvider;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/shared.dart'
    show
        DanmakuFormat,
        LiveWindow,
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
        playerStatsVisibleProvider;

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

  late int _index = widget.items.isEmpty ? 0 : widget.initialIndex.clamp(0, widget.items.length - 1);
  double _listWidth = _listDefault;

  /// On a narrow window: whether the list is the view in front.
  bool _listOpen = false;

  /// Whether the danmaku panel covers the list.
  bool _panelOpen = false;

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
    _scheduleTimeline();
  }

  /// A take that ended walks the list while the page is told to; the last
  /// entry simply stops on its final frame.
  void _onAdapterEvent(PlayerAdapterEvent event) {
    if (event is! PlayerAdapterCompleted) return;
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

  /// The desktop's compact window (the phone's system window on iOS). A host
  /// that refuses has to be told, or the button reads as broken.
  Future<void> _togglePip() async {
    final handle = _handle;
    if (handle == null) return;
    final accepted = await _presentation.togglePip(handle.id);
    if (accepted || !mounted) return;
    showDsToast(context: context, title: context.t.common.pipUnavailable);
  }

  /// The bar's way out of a mode that owns the window: the first press hands
  /// the screen back, the next one leaves the preview — the room's and the
  /// station's own rule, so a viewer is never trapped by a fullscreen.
  void _leave(BuildContext context, {required bool immersive, required bool narrow}) {
    if (immersive) {
      unawaited(_toggleFullscreen());
      return;
    }
    if (_panelOpen) {
      setState(() => _panelOpen = false);
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

  /// The shield rules live in Settings; the preview steps aside so the
  /// viewer lands on the page the row promises, the same pushed section the
  /// module pages open from their own doors.
  void _openShieldRules() {
    openSettingsSection(ref, SettingsSection.shield);
    final router = GoRouter.of(context);
    Navigator.of(context).maybePop();
    unawaited(router.push(SettingsSectionRoute(section: SettingsSection.shield.name).location));
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
    });
    // The layer comes back as a new engine; the timeline it had is gone with
    // the old one, so the page puts the decoded track back on it.
    ref.listen<bool>(playbackSettingsProvider.select((settings) => settings.danmakuVisible), (previous, next) {
      if (next) _scheduleTimeline();
    });
    return PopScope(
      canPop: !immersive && !_panelOpen && !_theater && !(narrow && _listOpen),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (immersive) {
          unawaited(_toggleFullscreen());
          return;
        }
        setState(() {
          _panelOpen = false;
          _theater = false;
          _listOpen = false;
        });
      },
      child: ColoredBox(
        // The page wears the theme; the picture's own box paints its dark
        // behind it (and the whole page while a mode owns the window).
        color: immersive ? _stage : DsTheme.colorsOf(context).canvas,
        child: immersive
            ? SafeArea(child: _stageOf(t, compact: LiveWindow.isCompact(width), immersive: true))
            : SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(t, narrow: narrow),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final inline = constraints.maxWidth >= _inlineWidth;
                          final list = _PreviewList(
                            items: widget.items,
                            current: _index,
                            onSelect: _select,
                            onOpenFolder: _revealFolderAt,
                            onDelete: _deleteAt,
                            // The folder a group header names; no groups means
                            // no button on the list.
                            onOpenGroup: widget.items.any((item) => item.groupPath.trim().isNotEmpty)
                                ? (folder) => unawaited(_revealFolder(folder))
                                : null,
                            autoNext: _autoNext,
                            onAutoNext: widget.items.length > 1 ? (value) => setState(() => _autoNext = value) : null,
                          );
                          if (!inline) {
                            if (_panelOpen) return _panelView();
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
                                      child: _panelOpen ? _panelView() : list,
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
                                  child: _panelOpen ? _panelView() : list,
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

  /// The danmaku controls: the panel takes the list's place, so the picture
  /// stays while a knob is moved.
  Widget _panelView() {
    return ColoredBox(
      color: DsTheme.colorsOf(context).canvas,
      child: MediaPreviewDanmakuPanel(
        hasDanmaku: _hasDanmaku,
        onClose: () => setState(() => _panelOpen = false),
        onOpenRules: _openShieldRules,
      ),
    );
  }

  Widget _header(Translations t, {required bool narrow}) {
    final item = _current;
    // The header and the list are the page's chrome, so they wear the theme's
    // ink; only the picture's own box stays dark whatever the theme is.
    final colors = DsTheme.colorsOf(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s8, DsSpace.s8, DsSpace.s12, DsSpace.s8),
      child: Row(
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
          if (widget.items.length > 1 && !(narrow && (_listOpen || _panelOpen))) ...[
            _HeaderButton(
              icon: DsIcons.chevronLeft,
              semanticLabel: t.common.previewPrevious,
              onPressed: _index > 0 ? () => _select(_index - 1) : null,
            ),
            _HeaderButton(
              icon: DsIcons.chevronRight,
              semanticLabel: t.common.previewNext,
              onPressed: _index < widget.items.length - 1 ? () => _select(_index + 1) : null,
            ),
          ],
          if (narrow && !_panelOpen)
            _HeaderButton(
              icon: _listOpen ? DsIcons.playCircle : DsIcons.listVideo,
              semanticLabel: _listOpen ? t.common.previewBackToStage : t.common.previewListTitle,
              onPressed: () => setState(() => _listOpen = !_listOpen),
            ),
          if (item case final entry? when entry.exists) ...[
            // The file's own verbs on the bar that names it. Hiding them in the
            // list's row menu made the stage a viewer cannot act from: the
            // picture on it is what they came to look at, and the moment they
            // want another player or want it gone is here, not three taps away.
            _HeaderButton(
              icon: DsIcons.externalLink,
              semanticLabel: t.common.previewOpenFile,
              onPressed: () => unawaited(openDownloadedPath(context, entry.path)),
            ),
            _HeaderButton(
              icon: DsIcons.folderOpen,
              semanticLabel: t.common.previewOpenFolder,
              onPressed: () => unawaited(_revealFolderOf(entry.path)),
            ),
            _HeaderButton(
              icon: DsIcons.trash2,
              semanticLabel: t.common.previewDeleteFile,
              onPressed: () => unawaited(_deleteAt(_index)),
            ),
          ] else if (item != null)
            _HeaderButton(
              icon: DsIcons.folderOpen,
              semanticLabel: t.common.previewOpenFolder,
              onPressed: () => unawaited(_revealFolderOf(item.path)),
            ),
          RouteCaptionTail(ink: colors.text),
        ],
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
        // A preview of one take stops on its last frame; looping would put the
        // comment clock back to the start without the picture.
        loop: false,
        onHandle: _onHandle,
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
        barLeading: _barLeading(t, immersive: immersive),
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
    ];
    return Listener(
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
  }

  /// The page's verbs in the picture's bar: the engine's volume, the danmaku
  /// switch and the way into its settings. Without a sidecar the switch stays
  /// in place but out of reach, and says why in the words a screen reader and
  /// the tooltip carry — the settings panel repeats it where a touch device
  /// has no tooltip.
  ///
  /// A bar on a touch width has no room for a slider beside the seek, so the
  /// volume stays on the wider windows, as the station's own bar does; mute is
  /// the player's button at any width.
  List<Widget> _barActions(
    Translations t, {
    required bool compact,
    required bool visible,
    required bool has,
    required bool loading,
    required bool immersive,
  }) {
    final handle = _handle;
    final fit = ref.watch(playbackSettingsProvider.select((settings) => settings.fit));
    final pip = ref.watch(roomPresentationProvider) == PresentationMode.pip;
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
      SettingsPreviewCircleButton(
        icon: has && visible ? DsIcons.captions : DsIcons.captionsOff,
        semanticLabel: loading
            ? t.common.previewDanmakuLoading
            : has
            ? (visible ? t.vod.danmakuOff : t.vod.danmakuOn)
            : t.common.previewDanmakuOff,
        selected: has && visible,
        onPressed: has
            ? () => unawaited(ref.read(playbackSettingsProvider.notifier).setDanmakuVisible(value: !visible))
            : null,
      ),
      // The panel takes the list's place; once the picture owns the window
      // there is no list to take, so the button steps out rather than opening
      // something nothing can show.
      if (!immersive)
        SettingsPreviewCircleButton(
          icon: DsIcons.settings,
          semanticLabel: t.common.previewDanmakuSettings,
          selected: _panelOpen,
          onPressed: () => setState(() => _panelOpen = !_panelOpen),
        ),
      // The engine's own verbs, at the bar's end the room's bar puts them. Each
      // is the page's for this visit: a viewer who chose 1.5× or 音频模式 keeps it
      // into the next entry rather than re-choosing it for every file.
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
        builder: (context, controller, _) => SettingsPreviewCircleButton(
          icon: DsIcons.gauge,
          semanticLabel: t.common.previewSpeed,
          selected: _rate != 1,
          onPressed: handle == null ? null : controller.toggle,
        ),
      ),
      SettingsPreviewCircleButton(
        icon: _audioOnly ? DsIcons.headphones : DsIcons.music2,
        semanticLabel: t.room.audioOnlyMode,
        selected: _audioOnly,
        onPressed: handle == null ? null : () => unawaited(_setAudioOnly(!_audioOnly)),
      ),
      // A kernel that cannot hand a frame back loses the button rather than
      // offering one that only toasts a failure.
      if (handle?.canCaptureScreenshot ?? false)
        SettingsPreviewCircleButton(
          icon: DsIcons.camera,
          semanticLabel: t.room.screenshot,
          onPressed: () => unawaited(_screenshot()),
        ),
      DsMenuAnchor(
        semanticLabel: t.room.fitShort,
        align: DsAlign.end,
        items: [
          for (final (index, option) in PlaybackFit.values.indexed)
            DsMenuItem(
              label: Text(fitLabels(t)[index]),
              checked: option == fit,
              onPressed: () => unawaited(ref.read(playbackSettingsProvider.notifier).setFit(option)),
            ),
        ],
        builder: (context, controller, _) => SettingsPreviewCircleButton(
          icon: DsIcons.aspectRatio,
          semanticLabel: t.room.fitShort,
          onPressed: controller.toggle,
        ),
      ),
      SettingsPreviewCircleButton(
        icon: DsIcons.activity,
        semanticLabel: t.room.statsToggle,
        selected: ref.watch(playerStatsVisibleProvider),
        onPressed: handle == null ? null : () => ref.read(playerStatsVisibleProvider.notifier).toggle(),
      ),
      // The theatre is this page's own arrangement, so the page decides where it
      // exists: it needs the list column to float, which a narrow window has no
      // room for and a window the picture already owns does not need.
      if (!compact && !immersive)
        SettingsPreviewCircleButton(
          icon: DsIcons.layoutHeaderSidebarRight,
          semanticLabel: _theater ? t.room.theaterOff : t.room.theaterOn,
          selected: _theater,
          onPressed: () => setState(() => _theater = !_theater),
        ),
      // The window's own verbs, at the bar's end the room's bar puts them:
      // the compact window only where the platform offers one, and the
      // fullscreen button doubles as the way back out.
      if (handle != null && _presentation.pipAvailable)
        SettingsPreviewCircleButton(
          icon: pip ? DsIcons.pictureInPictureExit : DsIcons.pictureInPicture,
          semanticLabel: pip ? t.room.pipOff : t.vod.pip,
          selected: pip,
          onPressed: () => unawaited(_togglePip()),
        ),
      SettingsPreviewCircleButton(
        icon: immersive ? DsIcons.minimize2 : DsIcons.fullscreen,
        semanticLabel: immersive ? t.vod.exitFullscreen : t.vod.fullscreen,
        selected: immersive,
        onPressed: handle == null ? null : () => unawaited(_toggleFullscreen()),
      ),
    ];
  }

  /// The entry's neighbours on the bar's left, where a player keeps them: the
  /// header that usually carries them is gone while the picture owns the
  /// window, and a fullscreen viewer still needs 上一项/下一项.
  List<Widget> _barLeading(Translations t, {required bool immersive}) => [
    if (immersive && widget.items.length > 1) ...[
      SettingsPreviewCircleButton(
        icon: DsIcons.chevronLeft,
        semanticLabel: t.common.previewPrevious,
        onPressed: _index > 0 ? () => _select(_index - 1) : null,
      ),
      SettingsPreviewCircleButton(
        icon: DsIcons.chevronRight,
        semanticLabel: t.common.previewNext,
        onPressed: _index < widget.items.length - 1 ? () => _select(_index + 1) : null,
      ),
    ],
  ];
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
  const _HeaderButton({required this.icon, required this.semanticLabel, this.onPressed});

  final DsIconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    return DsPressable(
      semanticLabel: semanticLabel,
      onPressed: onPressed,
      builder: (context, states, _) {
        final hovered = states.contains(WidgetState.hovered);
        return Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(shape: BoxShape.circle, color: hovered ? colors.hover : null),
          child: Center(
            child: DsIcon(
              icon,
              size: 18,
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
                  image: cachedImage(cover),
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
