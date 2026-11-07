import 'dart:async' show Future, StreamSubscription, TimeoutException, Timer, unawaited;

import 'package:live_net/live_net.dart' show LiveHttp;
import 'package:live_vod/live_vod.dart' show HuyaArchiveApi, HuyaArchiveQuality, HuyaArchiveVideo, VodFailure;
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

import 'package:pure_live/modules/live/archive/archive_playback.dart';
import 'package:pure_live/modules/live/archive/archive_progress.dart';

/// One official Huya recording, independent of the streamer's current live
/// room: one playlist per rendition, opened on the page's own kernel
/// handle. Only the recording's own id persists — media URLs never enter
/// local progress.
final class HuyaArchiveController extends ArchivePlaybackController {
  /// Owns the walk over [session]: [video] names the recording, [http] is
  /// the shared proxied transport, and Huya archives read without a login.
  new({
    required this.http,
    required this.session,
    required this.video,
    required this.progress,
    this.initialVolume = 1,
    this.ownsSession = false,
  }) {
    _states = session.playbackStream.listen(_changed);
  }

  /// The shared transport, behind [HuyaArchiveApi].
  final LiveHttp http;

  /// The page's native player handle from the kernel.
  @override
  final PlayerHandle session;

  /// The recording's metadata, without playback credentials.
  @override
  final HuyaArchiveVideo video;

  /// The local positions.
  final ArchiveProgress progress;

  /// The initial volume, the room's own preference.
  final double initialVolume;

  /// False while another owner disposes the handle.
  final bool ownsSession;

  /// Bounded direct seek before the walk re-enters the recording.
  static const Duration _seekTimeout = Duration(seconds: 10);

  /// The renditions the recording offers now, source first.
  @override
  List<HuyaArchiveQuality> qualities = const [];

  /// The selected rendition id (the playlist itself).
  @override
  String? qualityId;

  /// Opening, or switching rendition or re-entering after a seek.
  @override
  bool busy = false;

  /// Failure the player translates.
  @override
  Object? error;

  @override
  Duration get position => _pending ?? session.position;

  bool _disposed = false;
  bool _ready = false;
  int _generation = 0;
  int _seekSerial = 0;
  Duration? _pending;
  Duration _lastSaved = Duration.zero;
  StreamSubscription<PlayerTransportState>? _states;
  Timer? _seekDeadline;
  Future<void>? _retirement;

  @override
  Future<void> get retirement => _retirement ?? Future.value();

  bool _current(int generation) => !_disposed && generation == _generation;

  /// Whether the transport's clock says the media ran to its end: media_core
  /// derives completion from the clock, never from a status word.
  bool _atEnd(PlayerTransportState state) => state.duration > Duration.zero && state.position >= state.duration;

  /// Opens the recording: its permitted renditions, the viewer's saved
  /// position, and the first playable rendition on screen.
  @override
  Future<void> open(String id, {Duration? start}) async {
    if (_disposed) return;
    if (id != video.id) {
      error = StateError('A different recording was selected');
      notifyListeners();
      return;
    }
    final volume = _ready ? session.playbackStream.value.volume : initialVolume;
    await record().catchError((Object _) {});
    if (_disposed) return;
    _seekDeadline?.cancel();
    final generation = ++_generation;
    busy = true;
    error = null;
    _ready = false;
    _pending = null;
    notifyListeners();
    try {
      await session.stop();
      final offered = await HuyaArchiveApi(http).qualities(video.id);
      if (!_current(generation)) return;
      final selected = offered.where((item) => item.playable).firstOrNull;
      if (selected == null) {
        throw const VodFailure('the recording keeps no permitted rendition');
      }
      var resume = start ?? progress.position(video.id);
      if (!_current(generation)) return;
      if (resume.isNegative || (video.duration > Duration.zero && resume >= video.duration)) resume = Duration.zero;
      qualities = offered;
      qualityId = selected.id;
      _pending = resume > Duration.zero ? resume : null;
      _lastSaved = resume;
      await session.open(_source(selected), autoPlay: true);
      if (!_current(generation)) return;
      await session.setVolume(volume);
      // The kernel's open has no start position: the pending ask above is
      // what the seek's acknowledgement clears.
      if (resume > Duration.zero) await session.seek(resume);
      if (!_current(generation)) return;
      await restoreRate();
      _ready = true;
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
  /// media referer.
  PlayerSource _source(HuyaArchiveQuality quality) {
    final uri = Uri.parse(quality.url);
    return PlayerSource.of(
      id: SourceId('huya-archive:${video.id}:${quality.id.hashCode}'),
      uri: uri,
      type: SourceType.remote,
      protocol: SourceProtocol.fromScheme(uri.scheme),
      format: SourceFormat.m3u8,
      headers: SourceHeaders(HuyaArchiveApi.mediaHeaders),
    );
  }

  /// Re-reads the renditions; the recovery's fresh read, and the rendition
  /// switch's re-opened source.
  Future<PlayerSource> _refresh(int generation) async {
    if (!_current(generation)) throw StateError('The recording was replaced');
    final offered = await HuyaArchiveApi(http).qualities(video.id);
    if (!_current(generation)) throw StateError('The recording was replaced');
    final selected =
        offered.where((item) => item.playable && item.id == qualityId).firstOrNull ??
        offered.where((item) => item.playable).firstOrNull;
    if (selected == null) {
      throw const VodFailure('the rendition the viewer held is no longer offered');
    }
    qualities = offered;
    qualityId = selected.id;
    notifyListeners();
    return _source(selected);
  }

  /// Switches rendition without losing the position, the volume or the
  /// pause the viewer held.
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
      final source = await _refresh(generation);
      if (!_current(generation)) return;
      await session.open(source, autoPlay: true);
      if (!_current(generation)) return;
      await session.setVolume(volume);
      if (at > Duration.zero) await session.seek(at);
      if (!_current(generation)) return;
      await restoreRate();
      if (paused) await session.pause();
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

  /// Seeks the media clock; a seek the engine does not acknowledge inside
  /// the window re-enters the recording at the ask instead of leaving the
  /// viewer stranded.
  @override
  Future<void> seek(Duration requested) async {
    if (_disposed || busy || !_ready) return;
    var target = requested;
    final end = duration;
    if (target.isNegative) target = Duration.zero;
    if (end > Duration.zero && target > end) target = end;
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
  }

  /// Re-enters the recording at [target]: a fresh rendition read, a fresh
  /// open, the ask on the clock again. The pending handshake survives so a
  /// recovery the engine still does not answer names itself in error.
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
      final source = await _refresh(generation);
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
    if (!_ready || _pending != null) return;
    final state = session.playbackStream.value;
    if (state.command.isLoading || state.command.isIdle || state.command.isStopped) return;
    await progress.save(video.id, _atEnd(state) ? Duration.zero : position);
  }

  @override
  void dispose() {
    if (_disposed) return;
    final saved = record().catchError((Object _) {});
    _seekDeadline?.cancel();
    _disposed = true;
    _generation++;
    unawaited(_states?.cancel());
    _retirement = Future.wait<void>([saved, if (ownsSession) session.dispose()]).then((_) {});
    unawaited(_retirement);
    super.dispose();
  }
}
