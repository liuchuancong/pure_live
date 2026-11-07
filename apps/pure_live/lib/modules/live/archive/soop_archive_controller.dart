import 'dart:async' show Future, StreamSubscription, TimeoutException, Timer, unawaited;

import 'package:live_net/live_net.dart' show LiveHttp;
import 'package:live_vod/live_vod.dart'
    show SoopArchiveApi, SoopArchivePart, SoopArchiveQuality, SoopArchiveVideo, VodFailure;
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

/// Public SOOP files on the page's own kernel handle. No live chat is
/// attached to an old recording, and only local part positions persist.
final class SoopArchiveController extends ArchivePlaybackController {
  /// Owns the walk over [session]: [recording] names the broadcast, [http]
  /// is the shared proxied transport, and [cookie] the viewer's SOOP login
  /// (`''` for a guest; some recordings refuse one).
  new({
    required this.http,
    required this.session,
    required this.recording,
    required this.progress,
    this.cookie = '',
    this.initialVolume = 1,
    this.ownsSession = true,
  }) {
    _states = session.playbackStream.listen(_changed);
  }

  /// The shared transport, behind [SoopArchiveApi].
  final LiveHttp http;

  /// The page's native player handle from the kernel.
  @override
  final PlayerHandle session;

  /// The parent recording's metadata, without playback credentials.
  final SoopArchiveVideo recording;

  /// The local part positions.
  final ArchiveProgress progress;

  /// The viewer's SOOP cookie, or empty for a guest read.
  final String cookie;

  /// The initial volume, the room's own preference.
  final double initialVolume;

  /// False when another owner disposes the handle.
  final bool ownsSession;

  /// The part on screen now; null until its detail has answered.
  @override
  SoopArchivePart? video;

  /// The recording's parts, in the server's own order.
  @override
  List<SoopArchivePart> segments = const [];

  /// The renditions the on-screen part permits now.
  @override
  List<SoopArchiveQuality> qualities = const [];

  /// The selected rendition id.
  @override
  String? qualityId;

  /// Opening, or switching rendition.
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

  /// Opens a part of the recording: `[recordingId]:[order]`, or the bare
  /// recording id to resume the part the viewer stopped in last.
  @override
  Future<void> open(String id, {Duration? start}) async {
    if (_disposed) return;
    final match = RegExp(r'^([1-9][0-9]{0,18})(?::([1-9][0-9]{0,5}))?$').firstMatch(id);
    if (match == null || match[1] != recording.id) {
      error = StateError('A different recording was selected');
      notifyListeners();
      return;
    }
    final volume = _ready ? session.playbackStream.value.volume : initialVolume;
    await record().catchError((Object _) {});
    if (_disposed) return;
    final generation = ++_generation;
    _seekSerial++;
    _seekDeadline?.cancel();
    _pending = null;
    busy = true;
    error = null;
    _ready = false;
    notifyListeners();
    try {
      await session.stop();
      final offered = await SoopArchiveApi(http, cookie: cookie).detail(recording.id);
      if (!_current(generation)) return;
      // An explicit order names its part; the bare recording resumes the
      // last-walked part, and a stored part the station has since dropped
      // falls back to the first for an automatic resume only.
      final recent = match[2] == null ? progress.recent('${recording.id}:') : null;
      final partId = match[2] != null ? id : recent;
      final selected = partId == null ? null : offered.where((part) => part.id == partId).firstOrNull;
      final part = selected ?? (match[2] == null ? offered.firstOrNull : null);
      if (part == null) {
        throw const VodFailure('the recording part is gone from the station');
      }
      segments = offered;
      video = part;
      qualities = part.qualities;
      final quality = qualities.where((item) => item.id == 'original').firstOrNull ?? qualities.first;
      qualityId = quality.id;
      var at = start ?? progress.position(part.id);
      if (!_current(generation)) return;
      if (at.isNegative || (part.duration > Duration.zero && at >= part.duration)) at = Duration.zero;
      _pending = at > Duration.zero ? at : null;
      _lastSaved = at;
      await session.open(_source(part, quality), autoPlay: true);
      if (!_current(generation)) return;
      await session.setVolume(volume);
      // The kernel's open has no start position: the walk lands on its own
      // clock, and the pending ask above is what the seek's acknowledgement
      // clears.
      if (at > Duration.zero) await session.seek(at);
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

  /// The part's address as one video source, wearing the media referer the
  /// station's CDN checks. The address expires; a recovery re-reads.
  PlayerSource _source(SoopArchivePart part, SoopArchiveQuality quality) {
    final uri = Uri.parse(quality.url);
    return PlayerSource.of(
      id: SourceId('soop-archive:${part.id}:${quality.id}'),
      uri: uri,
      type: SourceType.remote,
      protocol: SourceProtocol.fromScheme(uri.scheme),
      format: uri.path.endsWith('.m3u8') ? SourceFormat.m3u8 : SourceFormat.fromUri(uri),
      headers: SourceHeaders(SoopArchiveApi.mediaHeaders(recording.id)),
    );
  }

  /// Re-reads the on-screen part: the recovery's fresh addresses, and the
  /// rendition switch's re-opened source.
  Future<PlayerSource> _refresh(int generation) async {
    if (!_current(generation)) throw StateError('The recording was replaced');
    final partId = video?.id;
    final offered = await SoopArchiveApi(http, cookie: cookie).detail(recording.id);
    if (!_current(generation)) throw StateError('The recording was replaced');
    final part = offered.where((item) => item.id == partId).firstOrNull;
    if (part == null) {
      throw const VodFailure('the recording part is gone from the station');
    }
    final quality = part.qualities.where((item) => item.id == qualityId).firstOrNull;
    if (quality == null) {
      throw const VodFailure('the selected rendition is no longer offered');
    }
    video = part;
    segments = offered;
    qualities = part.qualities;
    notifyListeners();
    return _source(part, quality);
  }

  /// Switches rendition without losing the position, the volume or the
  /// pause the viewer held.
  @override
  Future<void> selectQuality(String id) async {
    if (_disposed || busy || !_ready || id == qualityId) return;
    if (qualities.every((item) => item.id != id)) return;
    final generation = _generation;
    final previous = qualityId;
    final at = position;
    final transport = session.playbackStream.value;
    final paused = transport.command.isPaused;
    final volume = transport.volume;
    _seekSerial++;
    _seekDeadline?.cancel();
    _pending = at;
    busy = true;
    error = null;
    _ready = false;
    qualityId = id;
    notifyListeners();
    try {
      final source = await _refresh(generation);
      if (!_current(generation)) return;
      await session.open(source, autoPlay: true);
      if (!_current(generation)) return;
      await session.setVolume(volume);
      if (paused) await session.pause();
      await restoreRate();
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

  /// Seeks the media clock, holding a pending position until the engine's
  /// own reports name it back.
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
    _seekDeadline = Timer(const Duration(seconds: 10), () {
      if (_current(generation) && serial == _seekSerial && _pending != null) {
        _pending = null;
        error = TimeoutException('The archive seek was not acknowledged');
        notifyListeners();
      }
    });
    notifyListeners();
    try {
      await session.seek(target).timeout(const Duration(seconds: 10));
    } on Object catch (failure) {
      if (_current(generation) && serial == _seekSerial) {
        _pending = null;
        error = failure;
        notifyListeners();
      }
    }
  }

  void _changed(PlayerTransportState state) {
    if (_disposed) return;
    // A queued nonzero snapshot from before the seek is not its
    // acknowledgement: the pending position clears on the end of the media
    // or on a position come within two seconds of the ask.
    if (_pending case final target?) {
      final acked =
          _atEnd(state) || (!state.command.isLoading && (state.position - target).abs() <= const Duration(seconds: 2));
      if (acked) {
        _pending = null;
        _seekDeadline?.cancel();
      }
    }
    if (_ready && !busy) {
      if ((position - _lastSaved).abs() >= const Duration(seconds: 5) || _atEnd(state)) {
        _lastSaved = position;
        unawaited(record().catchError((Object _) {}));
      }
    }
    notifyListeners();
  }

  /// Saves the part and its position only; transient transport states must
  /// not overwrite a walk with zero.
  @override
  Future<void> record() async {
    final part = video;
    if (!_ready || _pending != null || part == null) return;
    final state = session.playbackStream.value;
    if (state.command.isLoading || state.command.isIdle || state.command.isStopped) return;
    await progress.save(part.id, _atEnd(state) ? Duration.zero : position);
  }

  @override
  void dispose() {
    if (_disposed) return;
    final saved = record().catchError((Object _) {});
    _disposed = true;
    _generation++;
    _seekSerial++;
    _seekDeadline?.cancel();
    unawaited(_states?.cancel());
    _retirement = Future.wait<void>([saved, if (ownsSession) session.dispose()]).then((_) {});
    unawaited(_retirement);
    super.dispose();
  }
}
