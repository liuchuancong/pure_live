import 'dart:async' show Timer, unawaited;
import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:io' show Directory, File, FileMode, HttpClient, HttpException, IOSink;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:live_vod/live_vod.dart' show HuyaVideoApi, HuyaVideoQuality;
import 'package:path/path.dart' as p;
import 'package:pure_live/app/providers/boot/storage_providers.dart' show appPathsProvider;
import 'package:pure_live/modules/huya/controller/huya_video.dart' show huyaVideoApiProvider;
import 'package:pure_live/modules/vod/controller/vod_download.dart' show freeDownloadFile, vodDownloadFileName;

/// The preference the download queue is kept under.
const String kHuyaDownloadsKey = 'huya.downloads';

/// What a task is doing.
enum HuyaDownloadPhase {
  /// Waiting for the lane.
  queued,

  /// Bytes are moving.
  running,

  /// Stopped with its `.part` kept, so a resume carries on from there.
  paused,

  /// The file is complete.
  done,

  /// The last attempt errored; the bytes it wrote stay for a retry.
  failed,
}

/// What asking for a download did.
enum HuyaDownloadEnqueue {
  /// A new task joined the queue.
  queued,

  /// The same video is already in the queue.
  duplicate,

  /// Resolving the video failed; the result's error says why.
  failed,
}

/// The result of asking for a download.
typedef HuyaDownloadResult = ({HuyaDownloadEnqueue outcome, String? error});

/// One row in the station's video download queue: which video, the target
/// file, and how far the bytes got.
final class HuyaDownloadItem {
  const HuyaDownloadItem({
    required this.videoId,
    required this.title,
    required this.qualityId,
    required this.fileName,
    required this.filePath,
    required this.phase,
    required this.stamp,
    this.cover = '',
    this.received = 0,
    this.total = 0,
    this.speed = 0,
    this.error,
  });

  factory HuyaDownloadItem.fromJson(Map<String, Object?> json) {
    final phase = HuyaDownloadPhase.values.firstWhere(
      (value) => value.name == json['phase'],
      orElse: () => HuyaDownloadPhase.paused,
    );
    return HuyaDownloadItem(
      videoId: '${json['videoId'] ?? ''}',
      title: '${json['title'] ?? ''}',
      qualityId: '${json['qualityId'] ?? ''}',
      fileName: '${json['fileName'] ?? ''}',
      filePath: '${json['filePath'] ?? ''}',
      phase: phase,
      stamp: (json['stamp'] as num?)?.toInt() ?? 0,
      cover: '${json['cover'] ?? ''}',
      received: (json['received'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
      error: json['error'] as String?,
    );
  }

  /// The station's video id — one task per video.
  final String videoId;

  /// The video's title, as the file name starts with it.
  final String title;

  /// The rendition the task asked for; a run falls back to the best one the
  /// source serves when the station has dropped it.
  final String qualityId;

  /// The finished file's name.
  final String fileName;

  /// Where the finished file lands; the `.part` sits beside it.
  final String filePath;

  /// Where the task stands.
  final HuyaDownloadPhase phase;

  /// When the task joined, in epoch milliseconds.
  final int stamp;

  /// The video's own cover, for a manager that previews the title it
  /// downloaded rather than a file name.
  final String cover;

  /// Bytes written so far.
  final int received;

  /// The answer's length, when the source named one.
  final int total;

  /// Bytes per second over the last windows; ephemeral, never stored.
  final int speed;

  /// What went wrong, when [phase] is failed.
  final String? error;

  /// The answered fraction, when the response named its length.
  double? get progress => total > 0 ? (received / total).clamp(0.0, 1.0) : null;

  HuyaDownloadItem copyWith({int? received, int? total, int? speed, HuyaDownloadPhase? phase, String? error}) {
    return HuyaDownloadItem(
      videoId: videoId,
      title: title,
      qualityId: qualityId,
      fileName: fileName,
      filePath: filePath,
      phase: phase ?? this.phase,
      stamp: stamp,
      cover: cover,
      received: received ?? this.received,
      total: total ?? this.total,
      speed: speed ?? this.speed,
      error: error,
    );
  }

  Map<String, Object?> toJson() => {
    'videoId': videoId,
    'title': title,
    'qualityId': qualityId,
    'fileName': fileName,
    'filePath': filePath,
    'phase': phase.name,
    'stamp': stamp,
    'cover': cover,
    'received': received,
    'total': total,
    if (error != null) 'error': error,
  };
}

/// The station's video download queue.
///
/// The address is signed and short-lived, so every run — a start, a resume,
/// a retry — resolves a fresh one through the station's own API before a
/// byte moves. What was written stays in a `.part` file and the next run
/// carries on from there with a range request. One lane at a time: the
/// videos are whole files, and interleaving them buys nothing.
final class HuyaDownloadsController extends Notifier<List<HuyaDownloadItem>> {
  final List<HuyaDownloadItem> _items = [];
  final Map<String, HttpClient> _clients = {};
  final Map<String, _HuyaStop> _stops = {};
  Timer? _persistTimer;

  @override
  List<HuyaDownloadItem> build() {
    _items
      ..clear()
      ..addAll(_readTasks());
    // A run the previous session left mid-flight keeps its bytes, paused.
    for (var index = 0; index < _items.length; index++) {
      if (_items[index].phase == HuyaDownloadPhase.running) {
        _items[index] = _items[index].copyWith(phase: HuyaDownloadPhase.paused, speed: 0);
      }
    }
    ref.onDispose(() {
      _persistTimer?.cancel();
      for (final client in _clients.values) {
        client.close(force: true);
      }
      _clients.clear();
    });
    Timer.run(_pump);
    return List.unmodifiable(_items);
  }

  /// Adds one video to the queue; the file name and its place are fixed here
  /// so a resume and its `.part` find each other after a restart.
  Future<HuyaDownloadResult> download({
    required String videoId,
    required String title,
    required String qualityId,
    String cover = '',
  }) async {
    final existing = _items.where((item) => item.videoId == videoId).firstOrNull;
    if (existing != null && existing.phase != HuyaDownloadPhase.failed) {
      return (outcome: HuyaDownloadEnqueue.duplicate, error: null);
    }
    try {
      final detail = await ref.read(huyaVideoApiProvider).detail(videoId);
      final directory = ref.read(appPathsProvider).videos;
      // The station's video folder is made here, not trusted to boot: the
      // folder row can point at a path that does not exist yet, and a missing
      // directory would fail the first write deep inside the sink instead of
      // here where the queue can report it.
      await directory.create(recursive: true);
      final quality = _qualityOf(detail.qualities, qualityId);
      final extension = p.extension(quality.url).replaceFirst('.', '');
      final name = vodDownloadFileName(title: title, part: '', extension: extension);
      final target = freeDownloadFile(directory, name);
      final item = HuyaDownloadItem(
        videoId: videoId,
        title: title,
        qualityId: quality.id,
        fileName: p.basename(target.path),
        filePath: target.path,
        phase: HuyaDownloadPhase.queued,
        stamp: DateTime.now().millisecondsSinceEpoch,
        cover: cover,
      );
      if (existing != null) {
        _items[_items.indexOf(existing)] = item;
      } else {
        _items.add(item);
      }
      _publish();
      await _persist();
      _pump();
      return (outcome: HuyaDownloadEnqueue.queued, error: null);
    } on Object catch (failure) {
      return (outcome: HuyaDownloadEnqueue.failed, error: '$failure');
    }
  }

  /// The rendition the task asks for, falling back to the best the source
  /// serves when the station has dropped it.
  static HuyaVideoQuality _qualityOf(List<HuyaVideoQuality> qualities, String qualityId) {
    for (final quality in qualities) {
      if (quality.id == qualityId) return quality;
    }
    return qualities.first;
  }

  /// The task for one video, when the queue has it.
  HuyaDownloadItem? taskOf(String videoId) => _items.where((row) => row.videoId == videoId).firstOrNull;

  Future<void> pause(String videoId) async {
    final item = _items.where((row) => row.videoId == videoId).firstOrNull;
    if (item == null) return;
    switch (item.phase) {
      case HuyaDownloadPhase.running:
        _stops[videoId] = _HuyaStop.pause;
        _clients[videoId]?.close(force: true);
      case HuyaDownloadPhase.queued:
        _replace(item.copyWith(phase: HuyaDownloadPhase.paused, speed: 0));
        await _persist();
      case HuyaDownloadPhase.paused || HuyaDownloadPhase.done || HuyaDownloadPhase.failed:
        break;
    }
  }

  /// Resumes a paused task, or retries a failed one — the bytes already
  /// written stay and a range request carries on from there.
  Future<void> resume(String videoId) async {
    final item = _items.where((row) => row.videoId == videoId).firstOrNull;
    if (item == null) return;
    if (item.phase != HuyaDownloadPhase.paused && item.phase != HuyaDownloadPhase.failed) return;
    _replace(item.copyWith(phase: HuyaDownloadPhase.queued, speed: 0));
    await _persist();
    _pump();
  }

  /// Stops a task and drops its row and its `.part`; a finished task keeps
  /// its file unless [deleteFile] says otherwise.
  Future<void> remove(String videoId, {bool deleteFile = false}) async {
    final item = _items.where((row) => row.videoId == videoId).firstOrNull;
    if (item == null) return;
    if (item.phase == HuyaDownloadPhase.running) {
      _stops[videoId] = _HuyaStop.drop;
      _clients[videoId]?.close(force: true);
      return;
    }
    await _drop(item, deleteFile: deleteFile);
  }

  /// Drops the finished rows; their files stay.
  Future<void> clearFinished() async {
    _items.removeWhere((item) => item.phase == HuyaDownloadPhase.done);
    _publish();
    await _persist();
  }

  Future<void> _drop(HuyaDownloadItem item, {bool deleteFile = false}) async {
    _items.removeWhere((row) => row.videoId == item.videoId);
    _publish();
    await _delete(File('${item.filePath}.part'));
    if (deleteFile && item.phase == HuyaDownloadPhase.done) {
      await _delete(File(item.filePath));
    }
    await _persist();
  }

  static Future<void> _delete(File file) async {
    try {
      if (file.existsSync()) await file.delete();
    } on Object {
      // A part file the system still holds is left for the cleaner.
    }
  }

  /// Fills the one lane with a queued task, oldest first.
  void _pump() {
    if (!ref.mounted) return;
    for (final item in _items) {
      if (item.phase != HuyaDownloadPhase.queued) continue;
      unawaited(_run(item.videoId));
      break;
    }
  }

  /// Runs one task to an end: a fresh address, the part file carried on with
  /// a range request, and the row kept in step every quarter second.
  Future<void> _run(String videoId) async {
    final found = _items.where((row) => row.videoId == videoId).firstOrNull;
    if (found == null || found.phase != HuyaDownloadPhase.queued) return;
    var item = found.copyWith(phase: HuyaDownloadPhase.running);
    _replace(item);

    HttpClient? client;
    IOSink? sink;
    var received = item.received;
    var stopped = false;
    try {
      final detail = await ref.read(huyaVideoApiProvider).detail(videoId);
      if (_stops.containsKey(videoId)) throw const _HuyaStopped();
      final quality = _qualityOf(detail.qualities, item.qualityId);
      // A row kept from the last session can outlive its folder (the viewer
      // moved or deleted it); the run makes room for itself again.
      await Directory(item.filePath).parent.create(recursive: true);
      final scratch = File('${item.filePath}.part');
      final written = scratch.existsSync() ? scratch.lengthSync() : 0;
      client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
      _clients[videoId] = client;
      final request = await client.getUrl(Uri.parse(quality.url));
      for (final entry in HuyaVideoApi.pageHeaders.entries) {
        request.headers.set(entry.key, entry.value);
      }
      if (written > 0) request.headers.set('range', 'bytes=$written-');
      final response = await request.close();
      var resume = false;
      if (written > 0 && response.statusCode == 206) {
        // The source honoured the range; carry on from the part file.
        resume = true;
      } else if (written > 0 && response.statusCode == 200) {
        // It answered from the top; start over.
        await _delete(scratch);
      } else if (written > 0 && response.statusCode == 416) {
        // The part on disk begins past the end of the file the source serves
        // now: drop the scratch, drain, and fail this attempt once — the next
        // one starts from the front.
        await response.drain<void>();
        await _delete(scratch);
        throw const HttpException('HTTP 416');
      } else if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      received = resume ? written : 0;
      final total = resume ? written + response.contentLength : response.contentLength;
      item = item.copyWith(received: received, total: total);
      _replace(item);

      sink = scratch.openWrite(mode: resume ? FileMode.append : FileMode.write);
      // The sink's own future reports a failed write; observing it keeps the
      // failure here (the flush and close below surface it again) instead of
      // as an unattributed uncaught error in the zone.
      unawaited(sink.done.catchError((Object _) {}));
      var windowBytes = 0;
      var windowStarted = DateTime.now();
      var speed = 0;
      var lastTick = DateTime.now().millisecondsSinceEpoch;
      await for (final chunk in response) {
        if (_stops.containsKey(videoId)) {
          stopped = true;
          break;
        }
        sink.add(chunk);
        received += chunk.length;
        windowBytes += chunk.length;
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - lastTick < 250) continue;
        lastTick = now;
        final elapsed = DateTime.now().difference(windowStarted).inMilliseconds;
        if (elapsed > 0) {
          final instant = windowBytes * 1000 ~/ elapsed;
          speed = speed == 0 ? instant : (speed * 2 + instant) ~/ 3;
        }
        windowBytes = 0;
        windowStarted = DateTime.now();
        item = item.copyWith(received: received, speed: speed);
        _replace(item);
      }
      await sink.flush();
      await sink.close();
      sink = null;
      if (stopped) return;
      // A stream that ends early with a polite close is not a finished
      // file: the row must not claim done over bytes it never received.
      if (total > 0 && received < total) {
        throw HttpException('transfer ended at $received of $total bytes');
      }
      final target = File(item.filePath);
      await _delete(target);
      await scratch.rename(target.path);
      _replace(item.copyWith(received: received, speed: 0, phase: HuyaDownloadPhase.done));
    } on Object catch (error) {
      if (error is! _HuyaStopped && !stopped) {
        _replace(item.copyWith(received: received, speed: 0, phase: HuyaDownloadPhase.failed, error: '$error'));
      }
    } finally {
      _clients.remove(videoId);
      client?.close(force: true);
      if (sink != null) {
        try {
          await sink.close();
        } on Object {
          // The socket is gone; the bytes written are already on disk.
        }
      }
      final stop = _stops.remove(videoId);
      if (stop == _HuyaStop.drop) {
        await _drop(item);
      } else {
        if (stop == _HuyaStop.pause) {
          _replace(item.copyWith(received: received, speed: 0, phase: HuyaDownloadPhase.paused));
        }
        await _persist();
        _pump();
      }
    }
  }

  void _replace(HuyaDownloadItem item) {
    final index = _items.indexWhere((row) => row.videoId == item.videoId);
    if (index < 0) return;
    _items[index] = item;
    _publish();
  }

  void _publish() {
    if (!ref.mounted) return;
    state = List.unmodifiable(_items);
  }

  Future<void> _persist() async {
    try {
      await StoragePrefs.setString(kHuyaDownloadsKey, jsonEncode([for (final item in _items) item.toJson()]));
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  static List<HuyaDownloadItem> _readTasks() {
    try {
      final raw = StoragePrefs.getString(kHuyaDownloadsKey);
      if (raw == null || raw.isEmpty) return const [];
      final json = jsonDecode(raw);
      if (json is! List) return const [];
      return [
        for (final entry in json)
          if (entry is Map) HuyaDownloadItem.fromJson(entry.cast<String, Object?>()),
      ];
    } on Object {
      return const [];
    }
  }
}

/// A stop the viewer asked for while the address was being resolved.
final class _HuyaStopped implements Exception {
  const _HuyaStopped();
}

/// What a stop in flight means: the task comes back paused, or goes away.
enum _HuyaStop { pause, drop }

/// The station's video download queue.
final huyaDownloadsProvider = NotifierProvider<HuyaDownloadsController, List<HuyaDownloadItem>>(
  HuyaDownloadsController.new,
);

/// The task for one video, when the queue has it.
HuyaDownloadItem? huyaDownloadOf(List<HuyaDownloadItem> items, String videoId) {
  return items.where((item) => item.videoId == videoId).firstOrNull;
}
