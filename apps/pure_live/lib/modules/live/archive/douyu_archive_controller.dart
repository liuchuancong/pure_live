import 'dart:async' show Future, StreamController, StreamSubscription, TimeoutException, Timer, unawaited;

import 'package:live_net/live_net.dart' show CancelToken, LiveHttp;
import 'package:live_sites/live_sites.dart' show LiveMessage, LiveMessageColor, LiveMessageType, LiveRetraction;
import 'package:live_vod/live_vod.dart'
    show DouyuVodApi, DouyuVodDetail, DouyuVodQuality, DouyuVodTimeline, DouyuVodVideo, VodDanmaku, VodFailure;
import 'package:media_core/media_core.dart'
    show
        PlayerHandle,
        PlayerHandlePlayback,
        PlayerSource,
        PlayerTransportState,
        SourceFormat,
        SourceHeaders,
        SourceId,
        SourceProtocol,
        SourceType;
import 'package:pure_live/app/logging/app_log.dart' show appLog;
import 'package:pure_live/modules/live/archive/archive_playback.dart';
import 'package:pure_live/modules/live/archive/archive_progress.dart';

/// One official Douyu recording — a replay session's segment the catalog
/// picked — on the page's own kernel handle. The daily signature is read
/// again whenever the address is renewed, because a replay walked across
/// midnight signs under the next day's descriptor. Comments ride their own
/// position timeline, converted to the shared overlay's model.
final class DouyuArchiveController extends ArchivePlaybackController {
  /// Owns the walk over [session]: [video] seeds the recording, [http] is
  /// the shared proxied transport, and [cookie] is the viewer's Douyu
  /// login (`''` reads guest renditions).
  new({
    required this.http,
    required this.session,
    required DouyuVodVideo video,
    required this.progress,
    this.cookie = '',
    this.initialVolume = 1,
    this.ownsSession = false,
  }) : _seed = video {
    _api = DouyuVodApi(http, cookie: cookie);
    _states = session.playbackStream.listen(_changed);
  }

  /// The shared transport, behind [DouyuVodApi].
  final LiveHttp http;

  /// The page's native player handle from the kernel.
  @override
  final PlayerHandle session;

  /// The recording the catalog picked, before its detail arrives.
  final DouyuVodVideo _seed;

  /// The local positions.
  final ArchiveProgress progress;

  /// The viewer's Douyu login, the live site's own credential.
  final String cookie;

  /// The initial volume, the room's own preference.
  final double initialVolume;

  /// False while another owner disposes the handle.
  final bool ownsSession;

  late final DouyuVodApi _api;
  DouyuVodDetail? _detail;
  CancelToken? _cancel;

  /// The selected recording's metadata, its own detail once read.
  @override
  DouyuVodVideo? get video => _detail?.video ?? _seed;

  /// Server-offered renditions, including unavailable permission tiers.
  @override
  List<DouyuVodQuality> qualities = const [];

  /// Actually selected rendition id.
  @override
  String? qualityId;

  /// The replay session's own segments, in the platform's order.
  @override
  List<DouyuVodVideo> segments = const [];

  /// Opening, or switching rendition or re-entering after a seek.
  @override
  bool busy = false;

  /// Failure the player translates; never a signed URL.
  @override
  Object? error;

  @override
  bool get supportsDanmaku => true;

  @override
  bool danmakuVisible = true;

  /// Timeline comments as the shared overlay's model, marked replayed:
  /// they are the recording's past, not a live room's now.
  @override
  Stream<LiveMessage> get messages => _messages.stream;

  /// Clears the flying layer after a seek or recording change.
  @override
  Stream<LiveRetraction> get retractions => _retractions.stream;

  final StreamController<LiveMessage> _messages = StreamController.broadcast();
  final StreamController<LiveRetraction> _retractions = StreamController.broadcast();
  DouyuVodTimeline? _timeline;
  StreamSubscription<PlayerTransportState>? _states;
  int _generation = 0;
  int _seekSerial = 0;
  bool _disposed = false;
  bool _ready = false;
  Duration _lastSaved = Duration.zero;
  Duration? _pending;
  Timer? _seekDeadline;
  Future<void>? _retirement;

  @override
  Future<void> get retirement => _retirement ?? Future.value();

  bool _current(int generation) => !_disposed && generation == _generation;

  /// Whether the transport's clock says the media ran to its end: media_core
  /// derives completion from the clock, never from a status word.
  bool _atEnd(PlayerTransportState state) => state.duration > Duration.zero && state.position >= state.duration;

  @override
  Duration get position => _pending ?? session.position;

  /// Opens a recording of the session: its detail and permitted renditions,
  /// the viewer's saved position, and the comment timeline underneath.
  @override
  Future<void> open(String id, {Duration? start}) async {
    final volume = _ready ? session.playbackStream.value.volume : initialVolume;
    await record().catchError((Object _) {});
    if (_disposed) return;
    _seekDeadline?.cancel();
    final generation = ++_generation;
    _cancel?.cancel();
    final cancel = _cancel = CancelToken();
    _timeline?.dispose();
    _timeline = null;
    _retractions.add(LiveRetraction.of(all: true));
    _ready = false;
    _pending = null;
    _detail = null;
    qualities = const [];
    segments = const [];
    qualityId = null;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await session.stop();
      final detail = await _api.detail(id);
      if (!_current(generation)) return;
      _detail = detail;
      var resume = start ?? progress.position(id);
      final duration = detail.video.duration;
      if (resume.isNegative || (duration > Duration.zero && resume >= duration)) resume = Duration.zero;
      final offered = await _api.qualities(detail);
      if (!_current(generation)) return;
      final selected = offered.where((item) => item.playable).firstOrNull;
      if (selected == null) {
        throw const VodFailure('the recording keeps no permitted rendition');
      }
      qualities = offered;
      qualityId = selected.id;
      _lastSaved = resume;
      _pending = resume > Duration.zero ? resume : null;
      _timeline = DouyuVodTimeline(fetch: (at, _) => _api.danmaku(id, at), clear: _retractAll, emit: _emit)
        ..seek(resume);
      await session.open(_source(selected), autoPlay: true);
      if (!_current(generation)) return;
      await session.setVolume(volume);
      // The kernel's open has no start position: the pending ask above is
      // what the seek's acknowledgement clears.
      if (resume > Duration.zero) await session.seek(resume);
      if (!_current(generation)) return;
      await restoreRate();
      _ready = true;
      unawaited(_loadSegments(detail.video, generation, cancel));
    } on Object catch (failure) {
      if (_current(generation)) error = failure;
    } finally {
      if (_current(generation)) {
        busy = false;
        notifyListeners();
      }
    }
  }

  /// The rendition's address as one video source, wearing the station's
  /// media headers.
  PlayerSource _source(DouyuVodQuality quality) {
    final uri = Uri.parse(quality.url);
    final lower = uri.path.toLowerCase();
    final format = lower.contains('.m3u8')
        ? SourceFormat.m3u8
        : lower.contains('.flv')
        ? SourceFormat.flv
        : SourceFormat.unknown;
    return PlayerSource.of(
      id: SourceId('douyu-archive:${video?.id ?? _seed.id}:${quality.id}'),
      uri: uri,
      type: SourceType.remote,
      protocol: SourceProtocol.fromScheme(uri.scheme),
      format: format,
      headers: SourceHeaders(const {'referer': 'https://v.douyu.com/', 'user-agent': DouyuVodApi.userAgent}),
    );
  }

  /// Reads the day's descriptor and renditions again for a fresh signed
  /// address: a replay walked across the signing rollover must not keep
  /// signing with yesterday's program.
  Future<PlayerSource> _renew(int generation) async {
    final detail = _detail;
    if (!_current(generation) || detail == null) throw StateError('The recording was replaced');
    final fresh = await _api.detail(detail.video.id);
    if (!_current(generation)) throw StateError('The recording was replaced');
    final offered = await _api.qualities(fresh);
    if (!_current(generation)) throw StateError('The recording was replaced');
    final selected =
        offered.where((item) => item.playable && item.id == qualityId).firstOrNull ??
        offered.where((item) => item.playable).firstOrNull;
    if (selected == null) {
      throw const VodFailure('the rendition the viewer held is no longer offered');
    }
    _detail = fresh;
    qualities = offered;
    qualityId = selected.id;
    notifyListeners();
    return _source(selected);
  }

  Future<void> _loadSegments(DouyuVodVideo video, int generation, CancelToken cancel) async {
    try {
      final values = await _api.replaySegments(video);
      if (!_current(generation)) return;
      segments = values;
      notifyListeners();
    } on Object catch (error) {
      appLog.forCategory('douyu.archive').warning('archive read failed', fields: {'error': '$error'});
      // The recording itself remains playable if its companion list fails.
    }
  }

  /// Switches rendition without losing the position, the volume or the
  /// pause the viewer held; the fresh address is signed again.
  @override
  Future<void> selectQuality(String id) async {
    if (busy || _disposed || !_ready || id == qualityId) return;
    if (qualities.every((item) => item.id != id || !item.playable)) return;
    final generation = _generation;
    final previous = qualityId;
    final at = position;
    final transport = session.playbackStream.value;
    final paused = transport.command.isPaused;
    final volume = transport.volume;
    _seekSerial++;
    _seekDeadline?.cancel();
    qualityId = id;
    busy = true;
    error = null;
    _pending = at;
    _ready = false;
    notifyListeners();
    try {
      final source = await _renew(generation);
      if (!_current(generation)) return;
      await session.open(source, autoPlay: true);
      if (!_current(generation)) return;
      await session.setVolume(volume);
      if (at > Duration.zero) await session.seek(at);
      if (!_current(generation)) return;
      await restoreRate();
      if (paused) await session.pause();
      _timeline?.seek(at);
      _ready = true;
    } on Object catch (failure) {
      if (_current(generation)) {
        qualityId = previous;
        error = failure;
        _pending = null;
        _ready = true;
      }
    } finally {
      if (_current(generation)) {
        busy = false;
        notifyListeners();
      }
    }
  }

  /// Seeks the media and comment clocks together; a seek the engine does
  /// not acknowledge inside the window re-enters the recording under a
  /// fresh signature instead of leaving the viewer stranded.
  @override
  Future<void> seek(Duration requested) async {
    if (_disposed || busy || !_ready) return;
    var target = requested;
    final end = duration;
    if (target.isNegative) target = Duration.zero;
    if (end > Duration.zero && target > end) target = end;
    _timeline?.seek(target);
    final generation = _generation;
    final serial = ++_seekSerial;
    _pending = target;
    error = null;
    _seekDeadline?.cancel();
    _seekDeadline = Timer(_seekTimeout, () {
      if (_current(generation) && serial == _seekSerial && _pending != null) {
        unawaited(_recoverSeek(target, generation, serial));
      }
    });
    notifyListeners();
    try {
      await session.seek(target).timeout(_seekTimeout);
    } on Object catch (failure) {
      if (_current(generation) && serial == _seekSerial && _pending != null) {
        _seekDeadline?.cancel();
        await _recoverSeek(target, generation, serial);
        return;
      }
      if (_current(generation) && serial == _seekSerial) {
        _pending = null;
        error = failure;
        notifyListeners();
      }
    }
    await record().catchError((Object _) {});
  }

  /// Bounded direct seek before the walk re-enters the recording.
  static const Duration _seekTimeout = Duration(seconds: 10);

  /// Re-enters the recording at [target] under a fresh signature. The
  /// pending handshake survives so a recovery the engine still does not
  /// answer names itself in error.
  Future<void> _recoverSeek(Duration target, int generation, int serial) async {
    bool current() => _current(generation) && serial == _seekSerial;
    if (!current() || busy) return;
    final transport = session.playbackStream.value;
    final paused = transport.command.isPaused;
    final volume = transport.volume;
    busy = true;
    error = null;
    _ready = false;
    notifyListeners();
    try {
      final source = await _renew(generation);
      if (!current()) return;
      await session.open(source, autoPlay: true);
      if (!current()) return;
      await session.setVolume(volume);
      if (target > Duration.zero) await session.seek(target);
      if (!current()) return;
      await restoreRate();
      if (paused) await session.pause();
      _ready = true;
      if (_pending != null) {
        _seekDeadline = Timer(_seekTimeout, () {
          if (!current() || _pending == null) return;
          _pending = null;
          error = TimeoutException('The archive seek recovery was not acknowledged');
          notifyListeners();
        });
      }
    } on Object catch (failure) {
      if (current()) {
        _pending = null;
        error = failure;
      }
    } finally {
      if (current()) {
        busy = false;
        notifyListeners();
      }
    }
  }

  void _changed(PlayerTransportState state) {
    if (_disposed) return;
    // The acknowledgement window widens with the speed: a fast walk covers
    // more ground between two of the engine's own reports.
    final tolerance = Duration(milliseconds: 1000 + (rate * 1000).round());
    if (_pending case final target?) {
      final acked = _atEnd(state) || (state.position - target).abs() <= tolerance;
      if (acked) {
        _pending = null;
        _seekDeadline?.cancel();
        error = null;
      }
    }
    if (_ready && _pending == null) {
      _timeline?.update(position, playing: state.command.isPlaying);
      if ((position - _lastSaved).abs().inSeconds >= 5 || _atEnd(state)) {
        _lastSaved = position;
        unawaited(record().catchError((Object _) {}));
      }
    }
    notifyListeners();
  }

  /// Saves the recording's own id and position only; transient transport
  /// states must not overwrite a walk with zero.
  @override
  Future<void> record() async {
    final selected = video;
    if (!_ready || _pending != null || selected == null) return;
    final state = session.playbackStream.value;
    if (state.command.isLoading || state.command.isIdle || state.command.isStopped) return;
    await progress.save(selected.id, _atEnd(state) ? Duration.zero : position);
  }

  /// Hiding also clears the current frame; re-enabling starts at the
  /// current clock.
  @override
  void toggleDanmaku() {
    danmakuVisible = !danmakuVisible;
    _timeline?.seek(position);
    notifyListeners();
  }

  void _retractAll() {
    if (!_disposed) _retractions.add(LiveRetraction.of(all: true));
  }

  void _emit(VodDanmaku message) {
    if (_disposed || !danmakuVisible) return;
    _messages.add(
      LiveMessage.of(
        type: LiveMessageType.chat,
        text: message.text,
        messageId: message.id,
        replayed: true,
        color: LiveMessageColor((message.color >> 16) & 255, (message.color >> 8) & 255, message.color & 255),
      ),
    );
  }

  @override
  void dispose() {
    if (_disposed) return;
    final saved = record().catchError((Object _) {});
    _seekDeadline?.cancel();
    _disposed = true;
    _generation++;
    _cancel?.cancel();
    _timeline?.dispose();
    unawaited(_states?.cancel());
    unawaited(_messages.close());
    unawaited(_retractions.close());
    _retirement = Future.wait<void>([saved, if (ownsSession) session.dispose()]).then((_) {});
    unawaited(_retirement);
    super.dispose();
  }
}
