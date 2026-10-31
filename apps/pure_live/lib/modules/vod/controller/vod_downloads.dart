import 'dart:async' show Timer, unawaited;
import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:io' show Directory, File, FileMode, HttpClient, HttpException, IOSink;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:path/path.dart' as p;

import 'package:pure_live/app/providers/boot/storage_providers.dart' show appPathsProvider;
import 'package:pure_live/modules/vod/controller/vod_controller.dart' show vodClientProvider;
import 'package:pure_live/modules/vod/controller/vod_download.dart' show freeDownloadFile, vodDownloadFileName;
import 'package:pure_live/modules/vod/controller/vod_settings.dart' show VodQualityChoice;
import 'package:pure_live/shared/shared.dart' show BilibiliDanmakuXml, danmakuSaveFormatsProvider, writeDanmakuFiles;

/// The preference the download queue is kept under.
const String kVodDownloadsKey = 'vod.downloads';

/// The preference the lane count is kept under.
const String _kMaxConcurrent = 'vod.download.maxConcurrent';

/// What a task is doing.
enum VodDownloadPhase {
  /// Waiting for a lane.
  queued,

  /// Bytes are moving.
  running,

  /// Stopped with its `.part` kept, so a resume carries on from there.
  paused,

  /// The file is complete and the danmaku sidecars written.
  done,

  /// The last attempt errored; the bytes it wrote stay for a retry.
  failed,
}

/// What asking for a download did.
enum VodDownloadEnqueue {
  /// A new task joined the queue.
  queued,

  /// The same part is already in the queue.
  duplicate,

  /// Resolving the address failed; the result's error says why.
  failed,
}

/// The result of asking for a download.
typedef VodDownloadResult = ({VodDownloadEnqueue outcome, String? error});

/// One row in the station's download queue: which archive and part, the
/// target file, and how far the bytes got.
final class VodDownloadItem {
  const VodDownloadItem({
    required this.id,
    required this.cid,
    required this.title,
    required this.part,
    required this.index,
    required this.parts,
    required this.qn,
    required this.fileName,
    required this.filePath,
    required this.phase,
    required this.stamp,
    this.bvid = '',
    this.epId = 0,
    this.cover = '',
    this.received = 0,
    this.total = 0,
    this.speed = 0,
    this.error,
  });

  factory VodDownloadItem.fromJson(Map<String, Object?> json) {
    final phase = VodDownloadPhase.values.firstWhere(
      (value) => value.name == json['phase'],
      orElse: () => VodDownloadPhase.paused,
    );
    final bvid = '${json['bvid'] ?? ''}';
    final epId = (json['epId'] as num?)?.toInt() ?? 0;
    return VodDownloadItem(
      id: '${json['id'] ?? '${bvid.isNotEmpty ? bvid : 'ep$epId'}:${json['cid']}'}',
      bvid: bvid,
      epId: epId,
      cover: '${json['cover'] ?? ''}',
      cid: (json['cid'] as num?)?.toInt() ?? 0,
      title: '${json['title'] ?? ''}',
      part: '${json['part'] ?? ''}',
      index: (json['index'] as num?)?.toInt() ?? 1,
      parts: (json['parts'] as num?)?.toInt() ?? 1,
      qn: (json['qn'] as num?)?.toInt() ?? 64,
      fileName: '${json['fileName'] ?? ''}',
      filePath: '${json['filePath'] ?? ''}',
      phase: phase,
      stamp: (json['stamp'] as num?)?.toInt() ?? 0,
      received: (json['received'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
      error: json['error'] as String?,
    );
  }

  /// `bvid:cid`, or `ep<epId>:cid` for a cinema title — one task per part.
  final String id;

  /// The archive's bvid; empty for a cinema title, which [epId] names.
  final String bvid;

  /// The video's own cover: the manager previews the title it downloaded
  /// rather than a file name. Empty on tasks queued before it was kept.
  final String cover;

  /// The cinema episode's id (`ep_id`), when the task is not an archive.
  final int epId;

  /// The part's cid, the address's other half.
  final int cid;

  /// The archive's title, as the file name starts with it.
  final String title;

  /// The part's own name.
  final String part;

  /// The part's place in the archive, from one.
  final int index;

  /// How many parts the archive has.
  final int parts;

  /// The quality the task asks the source for.
  final int qn;

  /// The finished file's name.
  final String fileName;

  /// Where the finished file lands; the `.part` sits beside it.
  final String filePath;

  /// Where the task stands.
  final VodDownloadPhase phase;

  /// When the task joined, in epoch milliseconds.
  final int stamp;

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

  VodDownloadItem copyWith({int? received, int? total, int? speed, VodDownloadPhase? phase, String? error}) {
    return VodDownloadItem(
      id: id,
      bvid: bvid,
      cid: cid,
      title: title,
      part: part,
      index: index,
      parts: parts,
      qn: qn,
      fileName: fileName,
      filePath: filePath,
      phase: phase ?? this.phase,
      stamp: stamp,
      received: received ?? this.received,
      total: total ?? this.total,
      speed: speed ?? this.speed,
      error: error,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'bvid': bvid,
    'epId': epId,
    'cover': cover,
    'cid': cid,
    'title': title,
    'part': part,
    'index': index,
    'parts': parts,
    'qn': qn,
    'fileName': fileName,
    'filePath': filePath,
    'phase': phase.name,
    'stamp': stamp,
    'received': received,
    'total': total,
    if (error != null) 'error': error,
  };
}

/// How many lanes the queue runs at once.
final class VodDownloadSettingsController extends Notifier<int> {
  @override
  int build() {
    try {
      final stored = StoragePrefs.getInt(_kMaxConcurrent);
      if (stored != null && stored >= 1 && stored <= 5) return stored;
    } on Object {
      // A closed store falls back to three lanes.
    }
    return 3;
  }

  /// Chooses [count] and keeps it for the next run.
  void select(int count) {
    final value = count.clamp(1, 5);
    if (value == state) return;
    state = value;
    try {
      unawaited(StoragePrefs.setInt(_kMaxConcurrent, value));
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// The lane count for the station's download queue.
final vodDownloadSettingsProvider = NotifierProvider<VodDownloadSettingsController, int>(
  VodDownloadSettingsController.new,
);

/// The preference the download quality is kept under, its own choice so the
/// viewer can save in a higher rendition than they watch in.
const String _kDownloadQn = 'vod.download.qn';

/// The rendition a download asks the source for, read at enqueue time and
/// written on every change.
final class VodDownloadQualityController extends Notifier<VodQualityChoice> {
  @override
  VodQualityChoice build() {
    try {
      final qn = StoragePrefs.getInt(_kDownloadQn);
      for (final choice in VodQualityChoice.values) {
        if (choice.qn == qn) return choice;
      }
    } on Object {
      // A closed store falls back to 1080P.
    }
    return VodQualityChoice.p1080;
  }

  /// Chooses [choice] and keeps it for the next download.
  void select(VodQualityChoice choice) {
    if (choice == state) return;
    state = choice;
    try {
      unawaited(StoragePrefs.setInt(_kDownloadQn, choice.qn));
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// The quality a download fetches by default.
final vodDownloadQualityProvider = NotifierProvider<VodDownloadQualityController, VodQualityChoice>(
  VodDownloadQualityController.new,
);

/// The preference the danmaku sidecar toggle is kept under.
const String _kDownloadDanmaku = 'vod.download.danmaku';

/// Whether a finished download also writes the danmaku sidecars the viewer
/// chose; on until the viewer says otherwise.
final class VodDownloadDanmakuController extends Notifier<bool> {
  @override
  bool build() {
    try {
      final stored = StoragePrefs.getBool(_kDownloadDanmaku);
      if (stored != null) return stored;
    } on Object {
      // A closed store falls back to keeping them.
    }
    return true;
  }

  /// Chooses [value] and keeps it for the next download.
  void set({required bool value}) {
    if (value == state) return;
    state = value;
    try {
      unawaited(StoragePrefs.setBool(_kDownloadDanmaku, value));
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// Whether downloads write danmaku sidecars.
final vodDownloadDanmakuProvider = NotifierProvider<VodDownloadDanmakuController, bool>(
  VodDownloadDanmakuController.new,
);

/// Why a running task was told to stop.
enum _VodStop { pause, drop }

/// The station's download queue: the rows kept for the next run, and the
/// lanes that fetch them.
///
/// The address is signed and short-lived, so every run — a start, a resume,
/// a retry — resolves a fresh one through the module's client before a byte
/// moves. What was written stays in a `.part` file and the next run carries
/// on from there with a range request. When a file completes, the danmaku
/// sidecars the viewer chose are written beside it, the way the video page
/// used to do for its one-shot download.
final class VodDownloadsController extends Notifier<List<VodDownloadItem>> {
  final List<VodDownloadItem> _items = [];
  final Map<String, HttpClient> _clients = {};
  final Map<String, _VodStop> _stops = {};
  Timer? _persistTimer;

  @override
  List<VodDownloadItem> build() {
    _items
      ..clear()
      ..addAll(_readTasks());
    // A run the previous session left mid-flight keeps its bytes, paused.
    for (var index = 0; index < _items.length; index++) {
      if (_items[index].phase == VodDownloadPhase.running) {
        _items[index] = _items[index].copyWith(phase: VodDownloadPhase.paused, speed: 0);
      }
    }
    ref.listen(vodDownloadSettingsProvider, (_, _) => _pump());
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

  /// Adds one part to the queue; the file name and its place are fixed here
  /// so a resume and its `.part` find each other after a restart. A cinema
  /// episode passes [epId] and leaves [bvid] empty.
  Future<VodDownloadResult> download({
    required int cid,
    required String title,
    required String part,
    required int index,
    required int parts,
    required int qn,
    String bvid = '',
    int epId = 0,
    String cover = '',
  }) async {
    final id = '${bvid.isNotEmpty ? bvid : 'ep$epId'}:$cid';
    final existing = _items.where((item) => item.id == id).firstOrNull;
    if (existing != null && existing.phase != VodDownloadPhase.failed) {
      return (outcome: VodDownloadEnqueue.duplicate, error: null);
    }
    try {
      final info = bvid.isNotEmpty
          ? await ref.read(vodClientProvider).downloadPart(bvid: bvid, cid: cid, qn: qn)
          : await ref.read(vodClientProvider).pgcDownloadPart(episodeId: epId, cid: cid, qn: qn);
      final directory = ref.read(appPathsProvider).videos;
      // The station's video folder is made here, not trusted to boot: the
      // folder row can point at a path that does not exist yet, and a missing
      // directory would fail the first write deep inside the sink instead of
      // here where the queue can report it.
      await directory.create(recursive: true);
      final extension = info.format.isEmpty ? 'mp4' : info.format;
      final name = vodDownloadFileName(title: title, part: part, index: index, parts: parts, extension: extension);
      final target = freeDownloadFile(directory, name);
      final item = VodDownloadItem(
        id: id,
        bvid: bvid,
        epId: epId,
        cover: cover,
        cid: cid,
        title: title,
        part: part,
        index: index,
        parts: parts,
        qn: qn,
        fileName: p.basename(target.path),
        filePath: target.path,
        phase: VodDownloadPhase.queued,
        stamp: DateTime.now().millisecondsSinceEpoch,
      );
      if (existing != null) {
        _items[_items.indexOf(existing)] = item;
      } else {
        _items.add(item);
      }
      _publish();
      await _persist();
      _pump();
      return (outcome: VodDownloadEnqueue.queued, error: null);
    } on Object catch (failure) {
      return (outcome: VodDownloadEnqueue.failed, error: '$failure');
    }
  }

  /// The task for one part, when the queue has it.
  VodDownloadItem? taskOf(String bvid, int cid) =>
      _items.where((item) => item.bvid == bvid && item.cid == cid).firstOrNull;

  Future<void> pause(String id) async {
    final item = _items.where((row) => row.id == id).firstOrNull;
    if (item == null) return;
    switch (item.phase) {
      case VodDownloadPhase.running:
        _stops[id] = _VodStop.pause;
        _clients[id]?.close(force: true);
      case VodDownloadPhase.queued:
        _replace(item.copyWith(phase: VodDownloadPhase.paused, speed: 0));
        await _persist();
      case VodDownloadPhase.paused || VodDownloadPhase.done || VodDownloadPhase.failed:
        break;
    }
  }

  /// Resumes a paused task, or retries a failed one — the bytes already
  /// written stay and a range request carries on from there.
  Future<void> resume(String id) async {
    final item = _items.where((row) => row.id == id).firstOrNull;
    if (item == null) return;
    if (item.phase != VodDownloadPhase.paused && item.phase != VodDownloadPhase.failed) return;
    _replace(item.copyWith(phase: VodDownloadPhase.queued, speed: 0));
    await _persist();
    _pump();
  }

  /// Stops a task and drops its row and its `.part`; a finished task keeps
  /// its file unless [deleteFile] says otherwise.
  Future<void> remove(String id, {bool deleteFile = false}) async {
    final item = _items.where((row) => row.id == id).firstOrNull;
    if (item == null) return;
    if (item.phase == VodDownloadPhase.running) {
      _stops[id] = _VodStop.drop;
      _clients[id]?.close(force: true);
      return;
    }
    await _drop(item, deleteFile: deleteFile);
  }

  Future<void> pauseAll() async {
    var stopped = false;
    for (final item in _items) {
      switch (item.phase) {
        case VodDownloadPhase.queued:
          _replace(item.copyWith(phase: VodDownloadPhase.paused));
        case VodDownloadPhase.running:
          _stops[item.id] = _VodStop.pause;
          _clients[item.id]?.close(force: true);
          stopped = true;
        case VodDownloadPhase.paused || VodDownloadPhase.done || VodDownloadPhase.failed:
          break;
      }
    }
    await _persist();
    if (stopped) _publish();
  }

  /// Resumes every paused and failed task.
  Future<void> resumeAll() async {
    for (var index = 0; index < _items.length; index++) {
      final item = _items[index];
      if (item.phase == VodDownloadPhase.paused || item.phase == VodDownloadPhase.failed) {
        _items[index] = item.copyWith(phase: VodDownloadPhase.queued, speed: 0);
      }
    }
    _publish();
    await _persist();
    _pump();
  }

  /// Drops the finished rows; their files stay.
  Future<void> clearFinished() async {
    _items.removeWhere((item) => item.phase == VodDownloadPhase.done);
    _publish();
    await _persist();
  }

  /// Removes a part file, and a finished task's file when asked.
  Future<void> _drop(VodDownloadItem item, {bool deleteFile = false}) async {
    _items.removeWhere((row) => row.id == item.id);
    _publish();
    await _delete(File('${item.filePath}.part'));
    if (deleteFile && item.phase == VodDownloadPhase.done) {
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

  /// Fills the free lanes with queued tasks, oldest first.
  void _pump() {
    if (!ref.mounted) return;
    var lanes = ref.read(vodDownloadSettingsProvider);
    for (final item in _items) {
      if (lanes <= 0) break;
      if (item.phase != VodDownloadPhase.queued) continue;
      lanes--;
      unawaited(_run(item.id));
    }
  }

  /// Runs one task to an end: a fresh address, the part file carried on
  /// with a range request, and the row kept in step every quarter second.
  Future<void> _run(String id) async {
    final found = _items.where((row) => row.id == id).firstOrNull;
    if (found == null || found.phase != VodDownloadPhase.queued) return;
    var item = found.copyWith(phase: VodDownloadPhase.running);
    _replace(item);

    HttpClient? client;
    IOSink? sink;
    var received = item.received;
    var stopped = false;
    try {
      final vod = ref.read(vodClientProvider);
      final info = item.epId > 0
          ? await vod.pgcDownloadPart(episodeId: item.epId, cid: item.cid, qn: item.qn)
          : await vod.downloadPart(bvid: item.bvid, cid: item.cid, qn: item.qn);
      if (_stops.containsKey(id)) throw const _Stopped();
      // A row kept from the last session can outlive its folder (the viewer
      // moved or deleted it); the run makes room for itself again.
      await Directory(item.filePath).parent.create(recursive: true);
      final scratch = File('${item.filePath}.part');
      final written = scratch.existsSync() ? scratch.lengthSync() : 0;
      client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
      _clients[id] = client;
      final request = await client.getUrl(Uri.parse(info.url));
      for (final entry in info.headers.entries) {
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
        if (_stops.containsKey(id)) {
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
      final target = File(item.filePath);
      await _delete(target);
      final file = await scratch.rename(target.path);
      item = item.copyWith(received: received, speed: 0);
      _replace(item.copyWith(phase: VodDownloadPhase.done));
      await _saveDanmaku(file, item.cid);
    } on Object catch (error) {
      if (error is! _Stopped && !stopped) {
        item = item.copyWith(received: received, speed: 0, phase: VodDownloadPhase.failed, error: '$error');
        _replace(item);
      }
    } finally {
      _clients.remove(id);
      client?.close(force: true);
      if (sink != null) {
        try {
          await sink.close();
        } on Object {
          // The socket is gone; the bytes written are already on disk.
        }
      }
      final stop = _stops.remove(id);
      if (stop == _VodStop.drop) {
        await _drop(item);
      } else {
        if (stop == _VodStop.pause) {
          item = item.copyWith(received: received, speed: 0, phase: VodDownloadPhase.paused);
          _replace(item);
        }
        await _persist();
        _pump();
      }
    }
  }

  /// The danmaku sidecars the viewer chose, beside the finished file — a
  /// courtesy, so a miss says nothing about the download itself.
  Future<void> _saveDanmaku(File video, int cid) async {
    try {
      if (!ref.read(vodDownloadDanmakuProvider)) return;
      final formats = ref.read(danmakuSaveFormatsProvider);
      if (formats.isEmpty || cid <= 0) return;
      final xml = await ref.read(vodClientProvider).danmakuXml(cid);
      await writeDanmakuFiles(video, BilibiliDanmakuXml.decode(xml), formats);
    } on Object {
      // The video stands on its own.
    }
  }

  void _replace(VodDownloadItem item) {
    final index = _items.indexWhere((row) => row.id == item.id);
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
      await StoragePrefs.setString(kVodDownloadsKey, jsonEncode([for (final item in _items) item.toJson()]));
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  static List<VodDownloadItem> _readTasks() {
    try {
      final raw = StoragePrefs.getString(kVodDownloadsKey);
      if (raw == null || raw.isEmpty) return const [];
      final json = jsonDecode(raw);
      if (json is! List) return const [];
      return [
        for (final entry in json)
          if (entry is Map) VodDownloadItem.fromJson(entry.cast<String, Object?>()),
      ];
    } on Object {
      return const [];
    }
  }
}

/// A stop the viewer asked for while the address was being resolved.
final class _Stopped implements Exception {
  const _Stopped();
}

/// The station's download queue.
final vodDownloadsProvider = NotifierProvider<VodDownloadsController, List<VodDownloadItem>>(
  VodDownloadsController.new,
);

/// The task for one part, when the queue has it. [key] is the archive's
/// bvid, or `ep<epId>` for a cinema episode.
VodDownloadItem? vodDownloadOf(List<VodDownloadItem> items, String key, int cid) {
  return items.where((item) => (item.epId > 0 ? 'ep${item.epId}' : item.bvid) == key && item.cid == cid).firstOrNull;
}
