import 'dart:async';

import 'package:dio/dio.dart';
import 'package:pure_live/core/interface/live_quality_discovery.dart';
import 'package:pure_live/player/core/live_input_playback_binding.dart';
import 'package:pure_live/player/core/playback_source.dart';
import 'package:pure_live/common/utils/play_quality_label.dart';

import 'dart:developer' as developer;

import 'package:pure_live/common/index.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:pure_live/player/core/playback_header_resolver.dart';
import 'package:pure_live/player/utils/player_consts.dart';
import 'package:pure_live/player/core/player_manager.dart';
import 'package:pure_live/player/models/player_exception.dart';
import 'package:pure_live/player/models/player_error_type.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/core/common/hls_source_query_policy.dart';
import 'package:pure_live/core/site/huya/huya_transport_policy.dart';
import 'package:pure_live/modules/live_play/states/load_type.dart';
import 'package:pure_live/common/utils/latest_async_value_queue.dart';
import 'package:pure_live/modules/live_play/states/live_play_state.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_controller.dart';

typedef StreamSourceOpener = Future<void> Function(
  String url,
  List<String> playUrls,
  Map<String, String> headers,
  LiveRoom room,
  bool audioOnly,
  PlaybackSourceResolver? sourceResolver,
  DateTime? sourceRefreshAt,
  PlaybackSourceQualitySelection? sourceSelection,
);

typedef OwnedStreamSourceOpener = Future<void> Function(
  OwnedPlaybackSource source,
  LiveRoom room,
  bool audioOnly,
  PlaybackSourceResolver? resolver,
  PlaybackSourceQualitySelection selection,
);

@immutable
class StreamSelection {
  const StreamSelection({required this.qualityIndex, required this.lineIndex, required this.isValid});

  final int qualityIndex;
  final int lineIndex;
  final bool isValid;
}

/// Normalizes a selection made from a UI snapshot against the latest stream
/// metadata. A quality change can return a different number of CDN lines.
@visibleForTesting
StreamSelection resolveStreamSelection({
  required int qualityCount,
  required int playUrlCount,
  required int requestedQualityIndex,
  required int requestedLineIndex,
}) {
  if (qualityCount <= 0 || playUrlCount <= 0) {
    return const StreamSelection(qualityIndex: 0, lineIndex: 0, isValid: false);
  }
  return StreamSelection(
    qualityIndex: requestedQualityIndex.clamp(0, qualityCount - 1),
    lineIndex: requestedLineIndex.clamp(0, playUrlCount - 1),
    isValid: true,
  );
}

/// Maps a platform-acknowledged quality identifier back to the current UI
/// list. The requested index remains the fallback for adapters whose response
/// does not expose an applied quality.
@visibleForTesting
int resolveAppliedQualityIndex({
  required List<LivePlayQuality> qualities,
  required int requestedIndex,
  required Object? appliedQualityData,
}) {
  if (qualities.isEmpty) return 0;
  final fallback = requestedIndex.clamp(0, qualities.length - 1);
  if (appliedQualityData == null) return fallback;
  final applied = appliedQualityData.toString();
  final index = qualities.indexWhere((quality) => quality.selectionId.toString() == applied);
  return index < 0 ? fallback : index;
}

List<LivePlayQuality> _qualityChoicesWithConfirmation(
  List<LivePlayQuality> qualities,
  int requestedIndex,
  LivePlayUrlResolution resolution,
) {
  if (qualities.isEmpty) return qualities;
  final applied = resolveAppliedPlayQuality(
    qualities: qualities,
    requested: qualities[requestedIndex.clamp(0, qualities.length - 1)],
    resolution: resolution,
  );
  return List<LivePlayQuality>.unmodifiable([
    for (final quality in qualities)
      quality.selectionId == applied.selectionId ? applied : quality.withPlaybackUnconfirmed(false),
  ]);
}

@visibleForTesting
List<LivePlayQuality> normalizePlayQualities(Iterable<LivePlayQuality> qualities) {
  final unique = <LivePlayQuality>[];
  final ids = <String>{};
  for (final quality in qualities) {
    if (quality.quality.trim().isEmpty || !ids.add(quality.selectionId.toString())) continue;
    unique.add(quality);
  }
  final labelCounts = <String, int>{};
  for (final quality in unique) {
    final label = quality.quality.trim();
    labelCounts.update(label, (count) => count + 1, ifAbsent: () => 1);
  }
  final labelOrdinals = <String, int>{};
  final result = unique.map((quality) {
    final label = quality.quality.trim();
    if (labelCounts[label] == 1) return quality;
    final ordinal = labelOrdinals.update(label, (value) => value + 1, ifAbsent: () => 1);
    return LivePlayQuality(quality: '$label $ordinal', id: quality.id, data: quality.data, sort: quality.sort);
  });
  return List<LivePlayQuality>.unmodifiable(result);
}

@visibleForTesting
bool hasSameStreamChoices(Iterable<String> current, Iterable<String> next) {
  final currentSet = current.map((url) => url.trim()).where((url) => url.isNotEmpty).toSet();
  final nextSet = next.map((url) => url.trim()).where((url) => url.isNotEmpty).toSet();
  return currentSet.isNotEmpty && currentSet.length == nextSet.length && currentSet.containsAll(nextSet);
}

abstract interface class PlayerSessionHost {
  Rx<LivePlayState> get state;

  bool get isClosed;

  void updateRoom({LiveRoom? detail, bool? isLiving, bool? success, bool? isLoading, String? loadError});

  void updatePlayer({
    VideoController? videoController,
    bool clearVideoController = false,
    List<LivePlayQuality>? qualites,
    int? currentQuality,
    List<String>? playUrls,
    Map<String, HlsSourceQueryPolicy>? sourceQueryPolicies,
    OwnedPlaybackSource? ownedSource,
    bool clearOwnedSource = false,
    int? currentLineIndex,
    bool? isCurrentRoomAudioOnly,
    bool? hasUseDefaultResolution,
  });

  Future<void> setCurrentRoomAudioOnlyFromUser(bool value);
}

class PlayerController extends GetxController {
  PlayerController(
    this._main, {
    this._streamSourceOpener,
    this._streamPlayerManager,
    this._ownedStreamSourceOpener,
    LiveInputPlaybackBinder? inputPlaybackBinder,
  }) : _inputPlaybackBinder = inputPlaybackBinder ?? bindLiveInputForPlayback {
    _audioModeTransitions = LatestAsyncValueQueue<bool>(_applyCurrentRoomAudioOnly);
  }

  final PlayerSessionHost _main;
  final StreamSourceOpener? _streamSourceOpener;
  final OwnedStreamSourceOpener? _ownedStreamSourceOpener;
  final LiveInputPlaybackBinder _inputPlaybackBinder;
  final PlayerManager? _streamPlayerManager;
  late final LatestAsyncValueQueue<bool> _audioModeTransitions;
  late Site currentSite;
  int _loadEpoch = 0;
  bool _closed = false;
  CancelToken? _qualityCancel;
  final Set<Future<void>> _qualityRequests = {};
  int _streamSelectionEpoch = 0;
  int _lastSourceCommitRevision = 0;
  final RxBool isStreamSwitching = false.obs;

  Future<void> _openGlobalStream(
    String url,
    List<String> playUrls,
    Map<String, String> headers,
    LiveRoom room,
    bool audioOnly,
    PlaybackSourceResolver? sourceResolver,
    DateTime? sourceRefreshAt,
    PlaybackSourceQualitySelection? sourceSelection,
  ) async {
    final manager = _streamPlayerManager ?? GlobalPlayerService.instance.player;
    final beforeRevision = manager.currentSourceCommit?.revision ?? 0;
    await manager.play(
      url,
      playUrls,
      headers,
      room: room,
      audioOnly: audioOnly,
      sourceResolver: sourceResolver,
      sourceRefreshAt: sourceRefreshAt,
      sourceSelection: sourceSelection,
    );
    _applyOpenReceipt(manager, beforeRevision, room);
  }

  Future<void> _openOwnedGlobalStream(
    OwnedPlaybackSource source,
    LiveRoom room,
    bool audioOnly,
    PlaybackSourceResolver? resolver,
    PlaybackSourceQualitySelection selection,
  ) async {
    final manager = _streamPlayerManager ?? GlobalPlayerService.instance.player;
    final beforeRevision = manager.currentSourceCommit?.revision ?? 0;
    await manager.playSource(
      source,
      room: room,
      audioOnly: audioOnly,
      sourceResolver: resolver,
      sourceSelection: selection,
    );
    _applyOpenReceipt(manager, beforeRevision, room);
  }

  void _applyOpenReceipt(PlayerManager manager, int beforeRevision, LiveRoom room) {
    if (manager.hasError.value) {
      throw PlayerException(message: 'Selected stream failed to open', type: PlayerErrorType.source);
    }
    final commit = manager.currentSourceCommit;
    // A consumed pause/exit is normal lifecycle completion, not a source
    // receipt. Recovery may instead commit a different URL/quality: use that
    // canonical result rather than comparing it with the requested URL.
    if (commit == null ||
        commit.revision <= beforeRevision ||
        !manager.isSourceCommitCurrent(commit) ||
        commit.room.roomId != room.roomId ||
        commit.room.platform != room.platform) {
      throw const _StreamSelectionCancelled();
    }
    // The broadcast listener may not have delivered yet. Applying the same
    // validated receipt here is synchronous and revision-deduplicated.
    applySourceCommit(commit);
  }

  LivePlayState get _state => _main.state.value;
  LiveRoom? get currentRoom => _state.room.detail;

  void initSite(Site site) {
    invalidateLoad();
    currentSite = site;
  }

  void invalidateLoad() {
    _loadEpoch++;
    _qualityCancel?.cancel();
    _qualityCancel = null;
  }

  bool _isLoadCurrent(int epoch, LiveRoom room, Site site) {
    final current = currentRoom;
    return !_closed &&
        !isClosed &&
        !_main.isClosed &&
        epoch == _loadEpoch &&
        currentSite.id == site.id &&
        current?.roomId == room.roomId &&
        current?.platform == room.platform;
  }

  /// 解析指定站点/房间的播放请求头（单一事实来源）。
  ///
  /// 主房间路径（[getHeaders]）与 multiview 每格解析器共用此入口，
  /// 保证 Cookie/UA/Referer 等鉴权头逻辑不发生漂移。
  static Future<Map<String, String>> resolvePlaybackHeaders({required Site site, required LiveRoom? room}) async {
    return PlaybackHeaderResolver.resolve(
      platform: site.id,
      roomId: room?.roomId ?? '',
      roomHeaders: room?.httpHeaders ?? const <String, String>{},
    );
  }

  Future<Map<String, String>> getHeaders({Site? expectedSite, LiveRoom? expectedRoom}) {
    return resolvePlaybackHeaders(site: expectedSite ?? currentSite, room: expectedRoom ?? currentRoom);
  }

  PlaybackSourceResolver? _buildSourceResolver({
    required Site site,
    required LiveRoom room,
    required LivePlayQuality quality,
  }) {
    final liveSite = site.liveSite;
    final bindInput = _inputPlaybackBinder;
    if (liveSite is! LivePlayRecoveryResolver) return null;
    final initialChoices = List<LivePlayQuality>.unmodifiable(
      _state.player.qualites.isEmpty ? <LivePlayQuality>[quality] : _state.player.qualites,
    );

    return (request) async {
      // The native session survives route disposal (app floating). Do not read
      // route state here or keep requesting the quality captured at first open
      // after the server has committed a different rate during recovery.
      final requested = request.currentQuality ?? quality;
      final choices = <LivePlayQuality>[
        for (final item in initialChoices)
          item.selectionId.toString() == requested.selectionId.toString() ? requested : item,
      ];
      var requestedIndex = choices.indexWhere(
        (item) => item.selectionId.toString() == requested.selectionId.toString(),
      );
      if (requestedIndex < 0) {
        requestedIndex = choices.length;
        choices.add(requested);
      }
      final resolution = await liveSite.resolvePlayUrlsForRecovery(detail: room, quality: requested);
      final urls = resolution.urls;
      final input = resolution.inputRecipe;
      if (input != null) {
        return PlaybackSourceRefreshResult.owned(
          source: bindInput(input),
          selection: PlaybackSourceQualitySelection(
            qualities: _qualityChoicesWithConfirmation(choices, requestedIndex, resolution),
            currentQuality: resolveAppliedQualityIndex(
              qualities: choices,
              requestedIndex: requestedIndex,
              appliedQualityData: resolution.appliedQualityData,
            ),
          ),
        );
      }
      if (urls.isEmpty) {
        return const PlaybackSourceRefreshResult(urls: <String>[], preferredLineIndex: 0);
      }
      final currentIndex = request.currentLineIndex.clamp(0, urls.length - 1);
      final preferredIndex = site.id == Sites.huyaSite
          ? HuyaTransportPolicy.selectRefreshedLine(
              urls: urls,
              currentUrl: request.currentUrl,
              currentLineIndex: currentIndex,
              advanceLine: request.advanceLine,
            )
          : (request.advanceLine ? (currentIndex + 1) % urls.length : currentIndex);
      return PlaybackSourceRefreshResult(
        urls: urls,
        preferredLineIndex: preferredIndex,
        selection: PlaybackSourceQualitySelection(
          sourceQueryPolicies: resolution.sourceQueryPolicies,
          qualities: _qualityChoicesWithConfirmation(choices, requestedIndex, resolution),
          currentQuality: resolveAppliedQualityIndex(
            qualities: choices,
            requestedIndex: requestedIndex,
            appliedQualityData: resolution.appliedQualityData,
          ),
        ),
        refreshAt: liveSite is LivePlayLeaseMetadata
            ? (liveSite as LivePlayLeaseMetadata).getPlayUrlRefreshAt(urls[preferredIndex])
            : null,
        invalidAt: liveSite is LivePlayLeaseMetadata
            ? (liveSite as LivePlayLeaseMetadata).getPlayUrlInvalidAt(urls[preferredIndex])
            : null,
      );
    };
  }

  /// Called after the manager validates that this immutable snapshot still
  /// owns the native source, by the route listener or open receipt. Resolver completion is
  /// not a commit, so it never updates these visible selection fields.
  void applySourceCommit(PlaybackSourceCommitSnapshot commit) {
    final room = currentRoom;
    if (_main.isClosed ||
        commit.revision <= _lastSourceCommitRevision ||
        room == null ||
        commit.room.roomId != room.roomId ||
        commit.room.platform != room.platform ||
        currentSite.id != room.platform) {
      return;
    }
    _lastSourceCommitRevision = commit.revision;
    final selection = commit.selection;
    _main.updatePlayer(
      qualites: selection?.qualities,
      currentQuality: selection?.currentQuality,
      playUrls: commit.urls,
      ownedSource: commit.source is OwnedPlaybackSource ? commit.source as OwnedPlaybackSource : null,
      sourceQueryPolicies: selection?.sourceQueryPolicies ?? const {},
      currentLineIndex: commit.currentLineIndex,
    );
    _main.updateRoom(success: true, isLoading: false, loadError: null);
  }

  DateTime? _getSourceRefreshAt({required Site site, required String url}) {
    final liveSite = site.liveSite;
    return liveSite is LivePlayLeaseMetadata ? (liveSite as LivePlayLeaseMetadata).getPlayUrlRefreshAt(url) : null;
  }

  Future<VideoController?> setPlayer({
    required String roomId,
    LiveRoom? expectedRoom,
    Site? expectedSite,
    int? loadEpoch,
  }) async {
    final room = expectedRoom ?? currentRoom;
    if (room == null) return null;
    final site = expectedSite ?? currentSite;

    final playerState = _state.player;
    final headers = playerState.ownedSource == null
        ? await getHeaders(expectedSite: site, expectedRoom: room)
        : const <String, String>{};
    if (loadEpoch != null && !_isLoadCurrent(loadEpoch, room, site)) return null;

    // Refresh/line changes replace the route-scoped controller.  The previous
    // implementation only overwrote the Rx field, leaving its barrage engine,
    // paragraph/picture caches, timers and subscriptions alive for the rest of
    // the room session.  Tear it down before attaching the replacement.
    final previousController = playerState.videoController;
    if (previousController != null) {
      await previousController.destory();
      previousController.dispose();
      if (loadEpoch != null && !_isLoadCurrent(loadEpoch, room, site)) return null;
    }

    final videoController = VideoController(
      room: room,
      playUrs: playerState.playUrls,
      datasource: playerState.playUrlSafe,
      ownedSource: playerState.ownedSource,
      allowScreenKeepOn: SettingsService.to.app.enableScreenKeepOn.v,
      headers: headers,
      qualiteName: playerState.qualitySafe.playbackLabel,
      currentLineIndex: playerState.currentLineIndex,
      currentQuality: playerState.currentQuality,
      isAudioOnly: playerState.isCurrentRoomAudioOnly,
      sourceResolver: _buildSourceResolver(
        site: site,
        room: room,
        quality: playerState.qualites[playerState.currentQuality.clamp(0, playerState.qualites.length - 1)],
      ),
      sourceRefreshAt: playerState.ownedSource == null
          ? _getSourceRefreshAt(site: site, url: playerState.playUrlSafe)
          : null,
      sourceSelection: PlaybackSourceQualitySelection(
        sourceQueryPolicies: playerState.sourceQueryPolicies,
        qualities: playerState.qualites,
        currentQuality: playerState.currentQuality,
      ),
      onSourceCommitted: applySourceCommit,
      onAudioOnlyChanged: _main.setCurrentRoomAudioOnlyFromUser,
    );

    _main.updatePlayer(videoController: videoController);
    return videoController;
  }

  /// Opens a caller-supplied direct source under this controller's normal
  /// latest-load fence.
  ///
  /// IPTV does not run the quality-discovery pipeline, so calling [setPlayer]
  /// directly used to omit the load epoch that protects ordinary sources.
  /// A room switch could therefore attach the older direct source after the
  /// new room had already invalidated playback work.
  Future<VideoController?> setDirectPlayer({required LiveRoom room, required Site site}) async {
    final roomId = room.normalizedRoomId;
    if (roomId.isEmpty) return null;
    invalidateLoad();
    final loadEpoch = _loadEpoch;
    final controller = await setPlayer(roomId: roomId, expectedRoom: room, expectedSite: site, loadEpoch: loadEpoch);
    if (controller == null) return null;
    try {
      await controller.initialization;
    } catch (_) {
      if (!_isLoadCurrent(loadEpoch, room, site)) return null;
      rethrow;
    }
    if (!_isLoadCurrent(loadEpoch, room, site) || controller.status == PlayerStatus.disposed) return null;
    return controller.status == PlayerStatus.error ? null : controller;
  }

  /// Attaches a new route-scoped UI controller to the native player retained by
  /// [PlayerManager] while the app floating window was visible.
  ///
  /// No room endpoint or media source is opened here. The previous page's
  /// controller has already been disposed; only the global native player and
  /// immutable session metadata cross the route boundary.
  Future<VideoController?> attachCurrentSession(RoomSessionSnapshot session) async {
    final manager = GlobalPlayerService.instance.player;
    if (_main.isClosed || manager.currentPlayer == null || manager.currentFloatRoom != session.room) return null;

    final qualities = session.qualities.isEmpty
        ? <LivePlayQuality>[LivePlayQuality(quality: '原画')]
        : List<LivePlayQuality>.unmodifiable(session.qualities);
    final playUrls = session.playUrls.isEmpty && session.dataSource.isNotEmpty
        ? <String>[session.dataSource]
        : List<String>.unmodifiable(session.playUrls);
    final currentQuality = session.currentQuality.clamp(0, qualities.length - 1);
    final currentLineIndex = playUrls.isEmpty ? 0 : session.currentLineIndex.clamp(0, playUrls.length - 1);

    _main.updatePlayer(
      qualites: qualities,
      currentQuality: currentQuality,
      playUrls: playUrls,
      sourceQueryPolicies: session.sourceQueryPolicies,
      ownedSource: session.ownedSource,
      currentLineIndex: currentLineIndex,
      isCurrentRoomAudioOnly: manager.desiredAudioOnlyMode,
      hasUseDefaultResolution: session.hasUseDefaultResolution,
    );

    final videoController = VideoController(
      room: session.room,
      ownedSource: session.ownedSource,
      playUrs: playUrls,
      datasource: session.dataSource.isNotEmpty
          ? session.dataSource
          : (playUrls.isEmpty ? '' : playUrls[currentLineIndex]),
      allowScreenKeepOn: SettingsService.to.app.enableScreenKeepOn.v,
      headers: session.headers,
      qualiteName: qualities[currentQuality].playbackLabel,
      currentLineIndex: currentLineIndex,
      currentQuality: currentQuality,
      isAudioOnly: manager.desiredAudioOnlyMode,
      reuseCurrentSession: true,
      sourceResolver: _buildSourceResolver(site: currentSite, room: session.room, quality: qualities[currentQuality]),
      sourceRefreshAt: session.ownedSource == null
          ? _getSourceRefreshAt(
              site: currentSite,
              url: session.dataSource.isNotEmpty
                  ? session.dataSource
                  : (playUrls.isEmpty ? '' : playUrls[currentLineIndex]),
            )
          : null,
      sourceSelection: PlaybackSourceQualitySelection(
        qualities: qualities,
        currentQuality: currentQuality,
        sourceQueryPolicies: session.sourceQueryPolicies,
      ),
      onSourceCommitted: applySourceCommit,
      onAudioOnlyChanged: _main.setCurrentRoomAudioOnlyFromUser,
    );
    _main.updatePlayer(videoController: videoController);
    return videoController;
  }

  Future<List<LivePlayQuality>> _discoverQualities(Site site, LiveRoom room, CancelToken cancel) async {
    final cleanup = Completer<void>();
    if (site.liveSite is LiveQualityDiscovery) _qualityRequests.add(cleanup.future);
    try {
      return await site.liveSite.discoverPlayQualities(detail: room, cancel: cancel);
    } finally {
      if (identical(_qualityCancel, cancel)) _qualityCancel = null;
      _qualityRequests.remove(cleanup.future);
      cleanup.complete();
    }
  }

  Future<void> getPlayQualites() async {
    if (_closed || isClosed || _main.isClosed) return;
    invalidateLoad();
    final loadEpoch = _loadEpoch;
    final room = currentRoom;
    final site = currentSite;
    if (room == null) return;
    final cancel = CancelToken();
    _qualityCancel = cancel;

    try {
      final playQualites = normalizePlayQualities(await _discoverQualities(site, room, cancel));
      if (!_isLoadCurrent(loadEpoch, room, site)) return;

      if (playQualites.isEmpty) {
        ToastUtil.show(i18n('cannot_read_video_info'));
        _main.updateRoom(success: false);
        return;
      }

      _main.updatePlayer(qualites: playQualites);

      if (!_state.player.hasUseDefaultResolution) {
        await _setDefaultResolution(playQualites, isCurrent: () => _isLoadCurrent(loadEpoch, room, site));
      }
      if (!_isLoadCurrent(loadEpoch, room, site)) return;

      await _getPlayUrl(loadEpoch: loadEpoch, room: room, site: site);
    } catch (error, stackTrace) {
      if (!_isLoadCurrent(loadEpoch, room, site)) return;
      developer.log(
        'Play quality loading failed (${error.runtimeType})',
        name: 'PlayerController',
        stackTrace: stackTrace,
      );
      ToastUtil.show(i18n('read_video_failed'));
      _main.updateRoom(success: false);
    }
  }

  Future<void> _setDefaultResolution(List<LivePlayQuality> playQualites, {required bool Function() isCurrent}) async {
    String userPrefer;
    final List<ConnectivityResult> connectivityResult = await (Connectivity().checkConnectivity());
    if (!isCurrent()) return;

    if (connectivityResult.contains(ConnectivityResult.mobile)) {
      userPrefer = SettingsService.to.player.resolvedPreferResolutionCellular;
    } else {
      userPrefer = SettingsService.to.player.resolvedPreferResolution;
    }

    final availableQualities = playQualites.map((e) => e.quality).toList();
    final matchedIndex = availableQualities.indexOf(userPrefer);

    if (matchedIndex != -1) {
      _main.updatePlayer(currentQuality: matchedIndex, hasUseDefaultResolution: true);
      return;
    }

    final systemResolutions = PlayerConsts.resolutions;
    final preferLevel = systemResolutions.indexOf(userPrefer);
    final preferRatio = preferLevel / (systemResolutions.length - 1);
    final targetIndex = (preferRatio * (availableQualities.length - 1)).round().clamp(0, availableQualities.length - 1);

    _main.updatePlayer(currentQuality: targetIndex, hasUseDefaultResolution: true);
  }

  Future<void> _getPlayUrl({required int loadEpoch, required LiveRoom room, required Site site}) async {
    if (!_isLoadCurrent(loadEpoch, room, site)) return;
    final playerState = _state.player;
    if (playerState.qualites.isEmpty || playerState.currentQuality >= playerState.qualites.length) return;

    final resolution = await site.liveSite.resolvePlayUrls(
      detail: room,
      quality: playerState.qualites[playerState.currentQuality],
    );
    if (!_isLoadCurrent(loadEpoch, room, site)) return;

    if (!resolution.hasSources) {
      ToastUtil.show(i18n('cannot_read_play_url'));
      _main.updateRoom(success: false);
      return;
    }

    final appliedQuality = resolveAppliedQualityIndex(
      qualities: playerState.qualites,
      requestedIndex: playerState.currentQuality,
      appliedQualityData: resolution.appliedQualityData,
    );
    final lineIndex = playerState.currentLineIndex.clamp(0, resolution.lineCount - 1);
    final owned = resolution.inputRecipe == null ? null : _inputPlaybackBinder(resolution.inputRecipe!);
    _main.updatePlayer(
      qualites: _qualityChoicesWithConfirmation(playerState.qualites, playerState.currentQuality, resolution),
      playUrls: List<String>.unmodifiable(resolution.urls),
      ownedSource: owned,
      sourceQueryPolicies: resolution.sourceQueryPolicies,
      currentQuality: appliedQuality,
      currentLineIndex: lineIndex,
    );
    final controller = await setPlayer(
      roomId: room.roomId!,
      expectedRoom: room,
      expectedSite: site,
      loadEpoch: loadEpoch,
    );
    if (controller == null || !_isLoadCurrent(loadEpoch, room, site)) return;
    _main.updateRoom(success: true);
  }

  /// Changes quality or CDN line on the active native player without
  /// refetching room metadata or destroying the route-scoped controller.
  ///
  /// The current stream remains active while a new quality URL is resolved.
  /// Rapid taps are latest-wins and the chosen line is clamped against the URL
  /// count returned by the newly selected quality.
  Future<bool> switchStreamSelection({
    required ReloadDataType type,
    required int qualityIndex,
    required int lineIndex,
  }) async {
    if (type != ReloadDataType.changeQuality && type != ReloadDataType.changeLine) return false;

    final room = currentRoom;
    final site = currentSite;
    final before = _state.player;
    if (room == null || before.qualites.isEmpty || !before.hasPlaybackSource) return false;

    final requestedQuality = type == ReloadDataType.changeLine
        ? before.currentQuality.clamp(0, before.qualites.length - 1)
        : qualityIndex.clamp(0, before.qualites.length - 1);
    // A pending selection may already be opening a different native source.
    // Selecting the committed choice must supersede it and queue a restore;
    // only an idle selection of the current source is a genuine no-op.
    if (!isStreamSwitching.value && requestedQuality == before.currentQuality && lineIndex == before.currentLineIndex) {
      return true;
    }

    final selectionEpoch = ++_streamSelectionEpoch;
    invalidateLoad();
    final loadEpoch = _loadEpoch;
    final sourceCommitBeforeSelection = _lastSourceCommitRevision;
    isStreamSwitching.value = true;

    try {
      final requestedQualityValue = before.qualites[requestedQuality];
      final refreshSignedSource = site.liveSite is LivePlayRecoveryResolver;
      final resolution = refreshSignedSource
          ? await site.liveSite.resolvePlayUrlsForRecovery(detail: room, quality: requestedQualityValue)
          : type == ReloadDataType.changeQuality || before.ownedSource != null
          ? await site.liveSite.resolvePlayUrls(detail: room, quality: requestedQualityValue)
          : LivePlayUrlResolution.withSourcePolicies(
              urls: List<String>.from(before.playUrls),
              sourceQueryPolicies: before.sourceQueryPolicies,
              appliedQualityData: before.qualites[before.currentQuality].selectionId,
              qualityUnconfirmed: before.qualitySafe.isPlaybackUnconfirmed,
            );
      if (!_isLoadCurrent(loadEpoch, room, site) || selectionEpoch != _streamSelectionEpoch) return false;
      final urls = resolution.urls;
      if (!resolution.hasSources) {
        ToastUtil.show(i18n('cannot_read_play_url'));
        return false;
      }

      final appliedQuality = resolveAppliedQualityIndex(
        qualities: before.qualites,
        requestedIndex: requestedQuality,
        appliedQualityData: resolution.appliedQualityData,
      );
      final qualityAdjusted = type == ReloadDataType.changeQuality && appliedQuality != requestedQuality;
      if (qualityAdjusted && appliedQuality == before.currentQuality) {
        ToastUtil.show(i18n('quality_limited_to', args: {'quality': before.qualites[appliedQuality].quality}));
        return false;
      }

      final selection = resolveStreamSelection(
        qualityCount: before.qualites.length,
        playUrlCount: resolution.lineCount,
        requestedQualityIndex: appliedQuality,
        requestedLineIndex: lineIndex,
      );
      if (!selection.isValid) return false;
      if (type == ReloadDataType.changeQuality &&
          selection.qualityIndex != before.currentQuality &&
          before.ownedSource == null &&
          resolution.inputRecipe == null &&
          hasSameStreamChoices(before.playUrls, urls)) {
        ToastUtil.show(i18n('quality_stream_unchanged'));
        return false;
      }

      final owned = resolution.inputRecipe == null ? null : _inputPlaybackBinder(resolution.inputRecipe!);
      final cachedHeaders = before.ownedSource == null ? before.videoController?.headers : null;
      final headers = owned != null
          ? const <String, String>{}
          : cachedHeaders == null || cachedHeaders.isEmpty
          ? await getHeaders(expectedSite: site, expectedRoom: room)
          : Map<String, String>.from(cachedHeaders);
      if (!_isLoadCurrent(loadEpoch, room, site) || selectionEpoch != _streamSelectionEpoch) return false;

      final immutableUrls = List<String>.unmodifiable(urls);
      final committedChoices = _qualityChoicesWithConfirmation(before.qualites, requestedQuality, resolution);
      final sourceCommitBeforeOpen = _lastSourceCommitRevision;
      final sourceSelection = PlaybackSourceQualitySelection(
        qualities: committedChoices,
        currentQuality: selection.qualityIndex,
        sourceQueryPolicies: resolution.sourceQueryPolicies,
      );
      final resolver = _buildSourceResolver(site: site, room: room, quality: before.qualites[selection.qualityIndex]);
      if (owned != null) {
        await (_ownedStreamSourceOpener ?? _openOwnedGlobalStream)(
          owned,
          room,
          _state.player.isCurrentRoomAudioOnly,
          resolver,
          sourceSelection,
        );
      } else {
        await (_streamSourceOpener ?? _openGlobalStream)(
          immutableUrls[selection.lineIndex],
          immutableUrls,
          Map<String, String>.unmodifiable(headers),
          room,
          _state.player.isCurrentRoomAudioOnly,
          resolver,
          _getSourceRefreshAt(site: site, url: immutableUrls[selection.lineIndex]),
          sourceSelection,
        );
      }
      if (!_isLoadCurrent(loadEpoch, room, site) || selectionEpoch != _streamSelectionEpoch) return false;
      if (_lastSourceCommitRevision == sourceCommitBeforeOpen) {
        _main.updatePlayer(
          qualites: committedChoices,
          currentQuality: selection.qualityIndex,
          playUrls: immutableUrls,
          ownedSource: owned,
          sourceQueryPolicies: resolution.sourceQueryPolicies,
          currentLineIndex: selection.lineIndex,
          hasUseDefaultResolution: true,
        );
      } else {
        // Native open may have recovered to another acknowledged source before
        // returning. Its successful commit is newer than this request payload.
        _main.updatePlayer(hasUseDefaultResolution: true);
      }
      _main.updateRoom(success: true, isLoading: false, loadError: null);
      if (qualityAdjusted) {
        ToastUtil.show(i18n('quality_limited_to', args: {'quality': before.qualites[selection.qualityIndex].quality}));
      }
      return true;
    } catch (error, stackTrace) {
      if (_isLoadCurrent(loadEpoch, room, site) && selectionEpoch == _streamSelectionEpoch) {
        if (_lastSourceCommitRevision == sourceCommitBeforeSelection) {
          _main.updatePlayer(
            qualites: before.qualites,
            currentQuality: before.currentQuality,
            playUrls: before.playUrls,
            ownedSource: before.ownedSource,
            sourceQueryPolicies: before.sourceQueryPolicies,
            currentLineIndex: before.currentLineIndex,
            hasUseDefaultResolution: before.hasUseDefaultResolution,
          );
        }
        if (error is! _StreamSelectionCancelled) {
          developer.log(
            'Stream selection failed (${error.runtimeType})',
            name: 'PlayerController',
            error: error,
            stackTrace: stackTrace,
          );
          ToastUtil.show(i18n('read_video_failed'));
        }
      }
      return false;
    } finally {
      if (selectionEpoch == _streamSelectionEpoch) isStreamSwitching.value = false;
    }
  }

  Future<void> changeCurrentRoomAudioOnly(bool value) async {
    await _audioModeTransitions.submit(value);
  }

  Future<void> _applyCurrentRoomAudioOnly(bool value) async {
    if (_state.player.isCurrentRoomAudioOnly == value) return;
    final controller = _state.player.videoController;
    final room = currentRoom;
    final previous = _state.player.isCurrentRoomAudioOnly;

    try {
      if (controller == null) {
        throw PlayerException(message: 'Room video controller is null', type: PlayerErrorType.lifecycle);
      }
      await controller.changeAudioOnlyMode(value);

      // The route may have been popped while the native call was pending.
      if (_main.isClosed || !identical(_state.player.videoController, controller) || currentRoom != room) return;
      _main.updatePlayer(isCurrentRoomAudioOnly: controller.isAudioOnly);
      _main.updateRoom(success: true, isLoading: false);
    } catch (error, stackTrace) {
      developer.log('Audio mode switch failed', name: 'PlayerController', error: error, stackTrace: stackTrace);
      if (!_main.isClosed && identical(_state.player.videoController, controller) && currentRoom == room) {
        _main.updatePlayer(isCurrentRoomAudioOnly: previous);
        _main.updateRoom(success: true, isLoading: false);
        ToastUtil.show(i18n('error_lifecycle'));
      }
    }
  }

  Future<void> destroyPlayer() async {
    invalidateLoad();
    // Capture native ownership before waiting for discovery cleanup. A later
    // room may attach another controller while this old request is draining.
    final controller = _state.player.videoController;
    final cleanup = Future.wait(_qualityRequests.toList());
    try {
      await controller?.destory();
      controller?.dispose();
      if (identical(_state.player.videoController, controller)) {
        _main.updatePlayer(clearVideoController: true);
      }
    } finally {
      await cleanup;
    }
  }

  @override
  void onClose() {
    _closed = true;
    _streamSelectionEpoch++;
    isStreamSwitching.value = false;
    invalidateLoad();
    super.onClose();
  }
}

class _StreamSelectionCancelled implements Exception {
  const _StreamSelectionCancelled();
}
