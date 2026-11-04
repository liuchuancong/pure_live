import 'dart:async' show StreamSubscription, unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/material.dart' show AppBar, Scaffold;
import 'package:flutter/services.dart' show FilteringTextInputFormatter, LogicalKeyboardKey, TextInputType;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_vod/live_vod.dart';
import 'package:media_core/media_core.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/vod/controller/vod_controller.dart' show vodClientProvider;
import 'package:pure_live/modules/vod/controller/vod_downloads.dart';
import 'package:pure_live/modules/vod/controller/vod_pgc.dart';
import 'package:pure_live/modules/vod/controller/vod_playback_settings.dart' show vodPlaybackSettingsProvider;
import 'package:pure_live/modules/vod/controller/vod_settings.dart' show vodQualityProvider;
import 'package:pure_live/modules/vod/widgets/vod_media_source.dart' show vodDashSourceOf;
import 'package:pure_live/modules/vod/widgets/vod_widgets.dart' show VodSeasonHead, vodDurationText;
import 'package:pure_live/shared/shared.dart' show LiveWindow, silencePlayer;

/// One cinema title's page: the player over media_core, the season's blurb,
/// and its episodes — the reference's PgcFeatureScreen, with the station's own
/// player chrome.
///
/// The first episode opens with the page; picking another switches the same
/// handle to it. Episodes are addressed by `ep_id` through the signed PGC
/// play endpoint, which is what the login-gated renditions need.
final class VodSeasonPage extends ConsumerStatefulWidget {
  /// The season behind [seasonId].
  const VodSeasonPage({required this.seasonId, super.key});

  /// The season's id (`ss` number).
  final int seasonId;

  @override
  ConsumerState<VodSeasonPage> createState() => _VodSeasonPageState();
}

final class _VodSeasonPageState extends ConsumerState<VodSeasonPage> with RouteAware {
  /// The cinema player's default qn (1080P); the source may serve lower.
  static const int _defaultQn = 80;

  VodEpisode? _episode;
  VodPlayInfo? _play;
  int _qn = _defaultQn;
  PlayerHandle? _handle;
  PlayerId? _boundPlayer;
  StreamSubscription<PlayerTransportState>? _transportSub;
  PlayerTransportState? _transport;
  String? _error;
  bool _opening = false;
  bool _silent = false;
  bool _disposed = false;
  bool _autoOpened = false;
  double? _dragSeconds;

  /// The window's observer, kept for `dispose` where the provider scope may
  /// already be gone.
  RouteObserver<ModalRoute<void>>? _routeObserver;

  // Captured while the page is alive; `ref` is refused by the time dispose
  // runs, and the leaving page must still exit its presentation mode and
  // release its handle.
  late final RoomPresentationController _presentationNotifier;
  late final PlayerKernel _kernel;

  /// The presentation mode, followed through a manual listener for the same
  /// reason: the leaving page reads its own field, not `ref`.
  PresentationMode _presentationMode = PresentationMode.normal;

  bool get _immersive => ref.read(roomPresentationProvider.notifier).modeOwnsWindow(ref.read(roomPresentationProvider));

  @override
  void initState() {
    super.initState();
    _presentationNotifier = ref.read(roomPresentationProvider.notifier);
    _kernel = ref.read(playerKernelProvider);
    ref.listenManual(roomPresentationProvider, (_, next) => _presentationMode = next, fireImmediately: true);
    // The station's opening quality, with the cinema's own floor: 720P is the
    // progressive endpoint's ceiling, not a PGC rendition's.
    final setting = ref.read(vodQualityProvider).qn;
    _qn = setting < _defaultQn ? _defaultQn : setting;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is ModalRoute<void>) {
      // The field is not promoted by flow analysis, so name the type.
      // ignore: omit_local_variable_types
      final RouteObserver<ModalRoute<void>> observer = _routeObserver ?? ref.read(routeObserverProvider);
      _routeObserver = observer;
      observer.subscribe(this, route);
    }
  }

  /// Another page covers this one (a related title, a menu route): the picture
  /// pauses rather than playing under it — the archive page's own rule.
  @override
  void didPushNext() {
    final handle = _handle;
    if (handle != null && (_transport?.isPlaying ?? false)) {
      unawaited(handle.pause().catchError((Object _) {}));
    }
  }

  @override
  void dispose() {
    _disposed = true;
    // The player goes quiet before anything else: the route's leave animation
    // runs while the release's queue drains, and the episode must not be heard
    // over the page the viewer returned to. Everything the leaving page needs
    // was captured while it was alive: a `ref` read here throws, and a page
    // that throws on its way out never releases the handle — the picture keeps
    // sounding with nothing left on screen to stop it.
    final handle = _handle;
    if (handle != null) {
      if (_presentationNotifier.modeOwnsWindow(_presentationMode)) {
        unawaited(_presentationNotifier.exit(handle.id));
      }
      silencePlayer(handle);
      unawaited(_kernel.release(handle.id));
    }
    _routeObserver?.unsubscribe(this);
    _routeObserver = null;
    unawaited(_transportSub?.cancel() ?? Future<void>.value());
    super.dispose();
  }

  Future<void> _openEpisode(VodEpisode episode, {int? qn}) async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _episode = episode;
      _play = null;
      _silent = false;
      _transport = null;
      _dragSeconds = null;
      _error = null;
    });
    final previous = _handle;
    if (previous != null) {
      try {
        await previous.pause();
      } on Object {
        // The switch itself reports a player that will not answer.
      }
    }
    try {
      var info = await ref
          .read(vodClientProvider)
          .pgcPlay(episodeId: episode.id, cid: episode.cid, aid: episode.aid, qn: qn ?? _qn);
      if (!mounted || _disposed) return;
      final kernel = ref.read(playerKernelProvider);
      final handle =
          previous ??
          await kernel.create(
            config: const PlayerConfig(name: 'vod-pgc'),
            preferredBackend: ref.read(playerKernelBackendProvider).id,
          );
      if (!mounted || _disposed) {
        if (previous == null) unawaited(kernel.release(handle.id));
        return;
      }
      _handle = handle;
      _bind(handle);
      final dash = vodDashSourceOf(info, maxQuality: qn ?? _qn);
      if (dash != null) {
        try {
          await handle.openMedia(dash, autoPlay: true);
        // media_core signals "this engine cannot join two essences" as an
        // UnsupportedError; the muxed request below is its handler.
        // ignore: avoid_catching_errors
        } on UnsupportedError {
          // A single-URL engine: ask the muxed answer, whose sound is inside
          // the file.
          info = await ref
              .read(vodClientProvider)
              .pgcPlay(episodeId: episode.id, cid: episode.cid, aid: episode.aid, qn: qn ?? _qn, dash: false);
          if (!mounted || _disposed) return;
          await handle.open(_episodeSource(info, episode), autoPlay: true);
        }
      } else {
        await handle.open(_episodeSource(info, episode), autoPlay: true);
      }
      if (!mounted || _disposed) return;
      setState(() {
        _play = info;
        _qn = info.servedQuality ?? qn ?? _defaultQn;
        _silent = info.silent;
        _opening = false;
      });
    } on Object catch (failure) {
      if (!mounted || _disposed) return;
      setState(() {
        _opening = false;
        _transport = null;
        _error = failure is VodFailure ? failure.message : '$failure';
      });
    }
  }

  /// The flat source of a muxed answer: the shape a single-URL engine opens,
  /// and the fallback when the DASH pair is unsupported.
  PlayerSource _episodeSource(VodPlayInfo info, VodEpisode episode) {
    final uri = Uri.parse(info.url);
    return PlayerSource.of(
      id: SourceId('vod:pgc:${episode.id}:${DateTime.now().microsecondsSinceEpoch}'),
      uri: uri,
      type: SourceType.remote,
      protocol: SourceProtocol.fromScheme(uri.scheme),
      format: SourceFormat.fromUri(uri),
      headers: info.headers.isEmpty ? null : SourceHeaders(info.headers),
      title: episode.title,
    );
  }

  void _bind(PlayerHandle handle) {
    if (_boundPlayer == handle.id) return;
    _boundPlayer = handle.id;
    unawaited(_transportSub?.cancel() ?? Future<void>.value());
    _transportSub = handle.playbackStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _transport = state;
        if (state.isPlaying) _error = null;
      });
    });
  }

  /// Hands the current episode to the app-wide download queue; the queue
  /// resolves its own muxed address when the task's turn comes, and the
  /// 下载管理 page (the station's sidebar, or Settings → 视频) takes over
  /// from there.
  Future<void> _startDownload() async {
    final t = context.t;
    final episode = _episode;
    final cid = episode?.cid ?? 0;
    if (episode == null || cid <= 0) return;
    final season = ref.read(vodSeasonDetailProvider(widget.seasonId)).value;
    final episodes = season?.episodes ?? const <VodEpisode>[];
    final position = episodes.indexWhere((entry) => entry.id == episode.id);
    final result = await ref
        .read(vodDownloadsProvider.notifier)
        .download(
          epId: episode.id,
          cid: cid,
          title: season?.title ?? episode.title,
          part: episode.title,
          index: position >= 0 ? position + 1 : 1,
          parts: episodes.isEmpty ? 1 : episodes.length,
          qn: ref.read(vodDownloadQualityProvider).qn,
          cover: episode.coverUrl?.toString() ?? season?.coverUrl?.toString() ?? '',
        );
    if (!mounted) return;
    switch (result.outcome) {
      case VodDownloadEnqueue.queued:
        showDsToast(context: context, title: t.vod.downloadQueued, status: DsStatus.success);
      case VodDownloadEnqueue.duplicate:
        showDsToast(context: context, title: t.vod.downloadDuplicate);
      case VodDownloadEnqueue.failed:
        showDsToast(context: context, title: t.vod.downloadFailed, description: result.error, status: DsStatus.danger);
    }
  }

  void _togglePlay() {
    final handle = _handle;
    if (handle == null) return;
    unawaited(_transport?.isPlaying ?? false ? handle.pause() : handle.play());
  }

  Future<void> _seekTo(double seconds) async {
    final handle = _handle;
    if (handle == null) return;
    await handle.seek(Duration(milliseconds: (seconds * 1000).round()));
  }

  void _toggleFullscreen() {
    final handle = _handle;
    if (handle == null) return;
    unawaited(ref.read(roomPresentationProvider.notifier).toggleFullscreen(handle.id));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final immersive = _immersive;
    // This episode's queue rows announce themselves: a finished episode
    // says where it landed, a failed one says so — however the page was left.
    ref.listen(vodDownloadsProvider, (previous, next) {
      final episode = _episode;
      if (episode == null) return;
      final prefix = 'ep${episode.id}:';
      final before = {for (final item in previous ?? const <VodDownloadItem>[]) item.id: item.phase};
      for (final item in next) {
        if (!item.id.startsWith(prefix) || before[item.id] == item.phase) continue;
        if (!mounted) return;
        final t = context.t;
        if (item.phase == VodDownloadPhase.done) {
          showDsToast(
            context: context,
            title: t.vod.downloadDone(name: item.fileName),
            status: DsStatus.success,
          );
        } else if (item.phase == VodDownloadPhase.failed) {
          showDsToast(context: context, title: t.vod.downloadFailed, status: DsStatus.danger);
        }
      }
    });
    final detail = ref.watch(vodSeasonDetailProvider(widget.seasonId));
    final season = detail.value;
    if (season != null && !_autoOpened && season.episodes.isNotEmpty) {
      _autoOpened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_openEpisode(season.episodes.first));
      });
    }
    final Widget body;
    if (season == null && detail.hasError) {
      body = Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.cloudOff),
          title: Text(t.vod.loadFailed),
          description: Text('${detail.error}'),
          actions: [
            DsButton(
              onPressed: () => ref.invalidate(vodSeasonDetailProvider(widget.seasonId)),
              child: Text(t.vod.retry),
            ),
          ],
        ),
      );
    } else if (season == null) {
      body = const Center(child: DsSpinner(style: DsSpinnerStyle(size: 28)));
    } else if (immersive) {
      body = _player(immersive: true);
    } else {
      body = _page(season, t);
    }
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): _togglePlay,
        const SingleActivator(LogicalKeyboardKey.keyF): _toggleFullscreen,
        const SingleActivator(LogicalKeyboardKey.escape): () {
          final handle = _handle;
          if (_immersive && handle != null) {
            unawaited(ref.read(roomPresentationProvider.notifier).exit(handle.id));
          } else {
            context.pop();
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: immersive ? colors.canvas : colors.surface,
          appBar: immersive
              ? null
              : AppBar(
                  backgroundColor: colors.surface,
                  surfaceTintColor: const Color(0x00000000),
                  elevation: 0,
                  title: Text(season?.title ?? t.vod.opening, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
          body: body,
        ),
      ),
    );
  }

  Widget _page(VodSeasonDetail detail, Translations t) {
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(inset, DsSpace.s12, inset, DsSpace.s24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s16,
            children: [
              _player(immersive: false),
              _header(detail),
              if (detail.episodes.isNotEmpty) _episodes(detail, t),
            ],
          ),
        ),
      ),
    );
  }

  /// The season's own front, taken out of the answer the page already reads:
  /// the poster, the name said once, where the season stands, the episode on
  /// the picture, its figures and tags, and the blurb the card wall could only
  /// truncate.
  Widget _header(VodSeasonDetail detail) {
    return VodSeasonHead(
      season: detail,
      episode: _episode,
      // The station's one switch for the figures and the blurb; the video
      // page's details obey it, so this page's do too.
      showDetails: ref.watch(vodPlaybackSettingsProvider).showDetails,
    );
  }

  Widget _episodes(VodSeasonDetail detail, Translations t) {
    return _EpisodesSection(
      episodes: detail.episodes,
      current: _episode,
      onOpen: (episode) => unawaited(_openEpisode(episode)),
    );
  }

  /// The picture and its controls; [immersive] drops the page's chrome and
  /// puts the way out over the picture, since the app bar is gone there.
  Widget _player({required bool immersive}) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final handle = _handle;
    final transport = _transport;
    final episode = _episode;
    final duration = transport?.duration ?? episode?.duration ?? Duration.zero;
    final position = _dragSeconds != null
        ? Duration(milliseconds: (_dragSeconds! * 1000).round())
        : transport?.position ?? Duration.zero;
    final playing = transport?.isPlaying ?? false;
    final qualities = _play?.qualities ?? const <VodQuality>[];
    return ClipRRect(
      borderRadius: BorderRadius.circular(immersive ? 0 : theme.radii.overlay),
      child: ColoredBox(
        color: colors.overlay,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (handle != null)
                MediaPlayerView(handle: handle, backgroundColor: colors.overlay)
              else
                const ColoredBox(color: Color(0xFF000000)),
              if (_opening || (transport?.isBuffering ?? false))
                const Center(child: DsSpinner(style: DsSpinnerStyle(size: 40))),
              if (immersive)
                PositionedDirectional(
                  top: DsSpace.s8,
                  start: DsSpace.s8,
                  child: DsButton.icon(
                    variant: DsButtonVariant.ghost,
                    size: DsSize.sm,
                    semanticLabel: t.vod.exitFullscreen,
                    onPressed: _toggleFullscreen,
                    icon: const DsIcon(DsIcons.minimize2),
                  ),
                ),
              if (_silent)
                PositionedDirectional(
                  top: DsSpace.s8,
                  end: DsSpace.s8,
                  child: DsBadge(label: Text(t.vod.pictureOnly), icon: const DsIcon(DsIcons.volumeOff)),
                ),
              PositionedDirectional(
                bottom: 0,
                start: 0,
                end: 0,
                child: Container(
                  padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s8, DsSpace.s24, DsSpace.s8, DsSpace.s4),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: AlignmentDirectional.bottomCenter,
                      end: AlignmentDirectional.topCenter,
                      colors: [Color(0xD9000000), Color(0x00000000)],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: DsSpace.s4,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (vodDownloadOf(ref.watch(vodDownloadsProvider), 'ep${episode?.id ?? 0}', episode?.cid ?? 0)
                          case final download?
                          when download.phase == VodDownloadPhase.running || download.phase == VodDownloadPhase.queued)
                        Row(
                          spacing: DsSpace.s8,
                          children: [
                            const DsSpinner(style: DsSpinnerStyle(size: 12)),
                            Expanded(
                              child: Text(
                                switch (download.progress) {
                                  final progress? => t.vod.downloading(percent: (progress * 100).round()),
                                  null => t.vod.downloadingUnknown,
                                },
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.typography.caption.copyWith(color: const Color(0xFFFFFFFF)),
                              ),
                            ),
                            DsButton.icon(
                              variant: DsButtonVariant.ghost,
                              size: DsSize.sm,
                              semanticLabel: t.vod.downloadPause,
                              onPressed: () => unawaited(ref.read(vodDownloadsProvider.notifier).pause(download.id)),
                              icon: const DsIcon(DsIcons.pause),
                            ),
                          ],
                        ),
                      Row(
                        spacing: DsSpace.s8,
                        children: [
                          SizedBox(
                            width: 54,
                            child: Text(
                              vodDurationText(position),
                              textAlign: TextAlign.center,
                              style: theme.typography.numeric(
                                theme.typography.caption.copyWith(color: const Color(0xFFFFFFFF)),
                              ),
                            ),
                          ),
                          Expanded(
                            child: DsSlider(
                              value: duration.inMilliseconds <= 0
                                  ? 0
                                  : position.inMilliseconds.clamp(0, duration.inMilliseconds).toDouble(),
                              max: duration.inMilliseconds <= 0 ? 1 : duration.inMilliseconds.toDouble(),
                              onChanged: duration.inMilliseconds <= 0
                                  ? null
                                  : (value) => setState(() => _dragSeconds = value / 1000),
                              onChangeEnd: duration.inMilliseconds <= 0
                                  ? null
                                  : (value) {
                                      final seconds = value / 1000;
                                      setState(() => _dragSeconds = null);
                                      unawaited(_seekTo(seconds));
                                    },
                            ),
                          ),
                          SizedBox(
                            width: 54,
                            child: Text(
                              vodDurationText(duration),
                              textAlign: TextAlign.center,
                              style: theme.typography.numeric(
                                theme.typography.caption.copyWith(color: const Color(0xFFFFFFFF)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        spacing: DsSpace.s8,
                        children: [
                          DsButton.icon(
                            variant: DsButtonVariant.ghost,
                            size: DsSize.sm,
                            semanticLabel: playing ? t.vod.pause : t.vod.play,
                            onPressed: handle == null ? null : _togglePlay,
                            icon: DsIcon(playing ? DsIcons.pause : DsIcons.play),
                          ),
                          if (qualities.isNotEmpty)
                            DsMenuAnchor(
                              semanticLabel: t.vod.quality,
                              builder: (context, controller, child) => DsButton.icon(
                                variant: DsButtonVariant.ghost,
                                size: DsSize.sm,
                                semanticLabel: t.vod.quality,
                                onPressed: controller.open,
                                icon: const DsIcon(DsIcons.settings2),
                              ),
                              items: [
                                for (final quality in qualities)
                                  DsMenuItem(
                                    label: Text(quality.label),
                                    checked: quality.qn == _qn,
                                    onPressed: () {
                                      final current = _episode;
                                      if (current != null) unawaited(_openEpisode(current, qn: quality.qn));
                                    },
                                  ),
                              ],
                            ),
                          DsButton.icon(
                            variant: DsButtonVariant.ghost,
                            size: DsSize.sm,
                            semanticLabel: t.vod.download,
                            onPressed: (episode?.cid ?? 0) <= 0 ? null : () => unawaited(_startDownload()),
                            icon: const DsIcon(DsIcons.download),
                          ),
                          if (!immersive)
                            DsButton.icon(
                              variant: DsButtonVariant.ghost,
                              size: DsSize.sm,
                              semanticLabel: t.vod.fullscreen,
                              onPressed: handle == null ? null : _toggleFullscreen,
                              icon: const DsIcon(DsIcons.maximize2),
                            ),
                          if (_error != null)
                            Expanded(
                              child: Text(
                                _error!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.typography.caption.copyWith(color: theme.colors.danger.text),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A season's episodes, [kVodEpisodeGroup] at a time with a pager and a jump
/// box when they run past one group — the episode shelf's pattern shared with
/// the video page's parts, for the seasons that run to hundreds of episodes.
const int kVodEpisodeGroup = 20;

final class _EpisodesSection extends StatefulWidget {
  const _EpisodesSection({required this.episodes, required this.current, required this.onOpen});

  final List<VodEpisode> episodes;

  /// The episode the page is playing, when one is.
  final VodEpisode? current;

  /// Runs when the viewer picks another episode.
  final void Function(VodEpisode episode) onOpen;

  @override
  State<_EpisodesSection> createState() => _EpisodesSectionState();
}

final class _EpisodesSectionState extends State<_EpisodesSection> {
  int _group = 0;

  @override
  void initState() {
    super.initState();
    _group = _groupOf(widget.current);
  }

  @override
  void didUpdateWidget(_EpisodesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Switching the playing episode turns the shelf to the page it sits on.
    if (oldWidget.current?.id != widget.current?.id) {
      setState(() => _group = _groupOf(widget.current));
    }
  }

  /// The group [episode] sits in, by its place in the season's list.
  int _groupOf(VodEpisode? episode) {
    if (episode == null) return 0;
    final position = widget.episodes.indexWhere((candidate) => candidate.id == episode.id);
    return position < 0 ? 0 : position ~/ kVodEpisodeGroup;
  }

  /// Asks for an episode number and opens it; an empty or unknown answer
  /// leaves the shelf where it was.
  Future<void> _jump() async {
    final episodes = widget.episodes;
    if (episodes.isEmpty) return;
    final controller = TextEditingController();
    int? parse() {
      final typed = int.tryParse(controller.text.trim());
      if (typed == null) return null;
      final byIndex = episodes.where((episode) => int.tryParse(episode.index) == typed);
      if (byIndex.isNotEmpty) return episodes.indexOf(byIndex.first);
      return typed >= 1 && typed <= episodes.length ? typed - 1 : null;
    }

    final position = await showDsDialog<int>(
      context: context,
      builder: (dialogContext) {
        final t = dialogContext.t;
        return DsDialog(
          title: Text(t.vod.episodesJump),
          description: DsTextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            placeholder: '1–${episodes.length}',
            onSubmitted: (_) => Navigator.of(dialogContext).pop(parse()),
          ),
          actions: [
            DsButton(
              variant: DsButtonVariant.ghost,
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(t.common.cancel),
            ),
            DsButton(onPressed: () => Navigator.of(dialogContext).pop(parse()), child: Text(t.common.confirm)),
          ],
        );
      },
    );
    controller.dispose();
    if (position == null || position < 0 || position >= episodes.length || !mounted) return;
    widget.onOpen(episodes[position]);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final episodes = widget.episodes;
    final groups = (episodes.length + kVodEpisodeGroup - 1) ~/ kVodEpisodeGroup;
    final group = _group.clamp(0, groups - 1);
    final first = group * kVodEpisodeGroup;
    final shown = episodes.skip(first).take(kVodEpisodeGroup).toList();
    final last = first + shown.length;
    final muted = theme.typography.caption.copyWith(color: colors.textMuted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        Row(
          spacing: DsSpace.s8,
          children: [
            Expanded(
              child: Text(
                '${t.vod.episodes} · ${episodes.length}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.title.copyWith(color: colors.text),
              ),
            ),
            if (groups > 1) ...[
              Text('$first–$last / ${episodes.length}', style: muted),
              DsButton.icon(
                icon: const DsIcon(DsIcons.chevronLeft),
                semanticLabel: t.vod.episodesPrevious,
                variant: DsButtonVariant.secondary,
                size: DsSize.sm,
                onPressed: group > 0 ? () => setState(() => _group = group - 1) : null,
              ),
              DsButton.icon(
                icon: const DsIcon(DsIcons.chevronRight),
                semanticLabel: t.vod.episodesNext,
                variant: DsButtonVariant.secondary,
                size: DsSize.sm,
                onPressed: group < groups - 1 ? () => setState(() => _group = group + 1) : null,
              ),
              DsButton(
                variant: DsButtonVariant.secondary,
                size: DsSize.sm,
                leading: const DsIcon(DsIcons.listOrdered, size: 16),
                onPressed: () => unawaited(_jump()),
                child: Text(t.vod.episodesJump),
              ),
            ],
          ],
        ),
        Wrap(
          spacing: DsSpace.s8,
          runSpacing: DsSpace.s8,
          children: [
            for (final candidate in shown)
              DsButton(
                variant: candidate.id == widget.current?.id ? DsButtonVariant.primary : DsButtonVariant.secondary,
                size: DsSize.sm,
                onPressed: () => widget.onOpen(candidate),
                child: Text(candidate.index),
              ),
          ],
        ),
      ],
    );
  }
}
