import 'dart:async' show Timer, unawaited;
import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:io' show File, FileSystemException;
import 'dart:typed_data' show Uint8List;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_net/live_net.dart' show ClientProfile, LiveRequest, LiveStreamedResponse;
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:path/path.dart' as p;

import 'package:pure_live/app/background/tone/background_thumbnails.dart' show backgroundClipStillsProvider;
import 'package:pure_live/app/providers/boot/storage_providers.dart' show appPathsProvider;
import 'package:pure_live/app/providers/network/network_providers.dart' show networkFactoryProvider;

/// The preference the finished-and-failed history is kept under.
const String kWallpaperDownloadsKey = 'wallpaper.downloads';

/// How many history rows survive a restart.
const int _kHistoryLimit = 60;

/// Progress redraws are throttled to this; the settle that ends a task
/// always paints, so the final numbers are never dropped.
const Duration _kPaintGap = Duration(milliseconds: 250);

/// Where one download got to.
enum WallpaperDownloadPhase {
  /// Fetching bytes.
  running,

  /// Stopped by the viewer; the row waits for its continue.
  paused,

  /// The file is complete and in the download folder.
  done,

  /// Stopped by an error; nothing usable was kept.
  failed,
}

/// What kind of media a row holds — the manager's thumbnail, its category
/// chip and the type filter all read it.
enum WallpaperDownloadKind {
  /// A picture.
  image,

  /// A clip.
  video,

  /// A painted swatch saved as a PNG.
  paint;

  /// The stored name.
  String get storedName => name;

  /// Restores the stored name; anything unreadable falls back to a picture.
  static WallpaperDownloadKind ofStored(String? value) => switch (value) {
    'video' => WallpaperDownloadKind.video,
    'paint' => WallpaperDownloadKind.paint,
    _ => WallpaperDownloadKind.image,
  };
}

/// One row in the wallpaper download manager: what is being fetched, where it
/// lands, how far it has gone and when.
final class WallpaperDownloadTask {
  const WallpaperDownloadTask({
    required this.id,
    required this.title,
    required this.fileName,
    required this.directory,
    required this.phase,
    required this.startedAt,
    required this.kind,
    this.finishedAt,
    this.received = 0,
    this.total = 0,
    this.speedBps = 0,
    this.etaSeconds,
    this.error,
    this.filePath,
    this.url,
    this.thumbUrl,
    this.thumbPath,
  });

  /// Restores a history row the last run kept.
  factory WallpaperDownloadTask.fromJson(Map<String, Object?> json) => WallpaperDownloadTask(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    fileName: json['fileName'] as String? ?? '',
    directory: json['directory'] as String? ?? '',
    phase: switch (json['phase']) {
      final String name when name == WallpaperDownloadPhase.failed.name => WallpaperDownloadPhase.failed,
      final String name when name == WallpaperDownloadPhase.paused.name => WallpaperDownloadPhase.paused,
      _ => WallpaperDownloadPhase.done,
    },
    kind: WallpaperDownloadKind.ofStored(json['kind'] as String?),
    startedAt: DateTime.fromMillisecondsSinceEpoch(json['startedAt'] as int? ?? 0),
    finishedAt: switch (json['finishedAt']) {
      final int milliseconds => DateTime.fromMillisecondsSinceEpoch(milliseconds),
      _ => null,
    },
    received: json['received'] as int? ?? 0,
    total: json['total'] as int? ?? 0,
    speedBps: json['speedBps'] as int? ?? 0,
    etaSeconds: json['etaSeconds'] as int?,
    error: json['error'] as String?,
    filePath: json['filePath'] as String?,
    url: json['url'] as String?,
    thumbUrl: json['thumbUrl'] as String?,
    thumbPath: json['thumbPath'] as String?,
  );

  final String id;

  /// What the viewer asked for, as the row names it.
  final String title;

  /// The file's name under [directory].
  final String fileName;
  final String directory;
  final WallpaperDownloadPhase phase;

  /// The media kind the row holds.
  final WallpaperDownloadKind kind;

  /// The catalogue's thumbnail address, when the row came from one; the
  /// manager paints it until the file itself exists.
  final String? thumbUrl;
  final DateTime startedAt;
  final DateTime? finishedAt;

  /// Bytes arrived so far; [total] is 0 when the answer carried no length.
  final int received;
  final int total;

  /// The transfer's recent pace, in bytes per second; 0 while it settles.
  final int speedBps;

  /// How many seconds the rest of the transfer needs at that pace; null
  /// when there is nothing to extrapolate from.
  final int? etaSeconds;

  /// Why a failed transfer stopped, in the transport's own words.
  final String? error;

  /// The saved file, once done.
  final String? filePath;

  /// The address a network download can be retried from; a kept picture or a
  /// copied file has none.
  final String? url;

  /// The still taken from a downloaded clip, so a row without a
  /// catalogue cover still shows a frame — and the wallpaper's tone lookup
  /// finds the clip by this mapping. Pictures paint themselves.
  final String? thumbPath;

  bool get isRunning => phase == WallpaperDownloadPhase.running;
  bool get isTerminal => phase == WallpaperDownloadPhase.done || phase == WallpaperDownloadPhase.failed;

  /// Whether the row can be fetched again after a failure.
  bool get isRetriable => phase == WallpaperDownloadPhase.failed && url != null && url!.isNotEmpty;

  /// Whether the row can be picked back up where the viewer left it.
  bool get isResumable => phase == WallpaperDownloadPhase.paused && url != null && url!.isNotEmpty;

  /// A fresh row with the transfer started over.
  WallpaperDownloadTask restarted() => WallpaperDownloadTask(
    id: id,
    title: title,
    fileName: fileName,
    directory: directory,
    phase: WallpaperDownloadPhase.running,
    kind: kind,
    thumbUrl: thumbUrl,
    thumbPath: thumbPath,
    startedAt: DateTime.now(),
    url: url,
  );

  /// The row with only its phase moved; everything else, the partial bytes
  /// included, is kept as it was.
  WallpaperDownloadTask withPhase(WallpaperDownloadPhase phase) => WallpaperDownloadTask(
    id: id,
    title: title,
    fileName: fileName,
    directory: directory,
    phase: phase,
    kind: kind,
    thumbUrl: thumbUrl,
    thumbPath: thumbPath,
    startedAt: startedAt,
    finishedAt: finishedAt,
    received: received,
    total: total,
    error: error,
    filePath: filePath,
    url: url,
  );

  /// The row with the still cut from its clip.
  WallpaperDownloadTask withThumbnail(String path) => WallpaperDownloadTask(
    id: id,
    title: title,
    fileName: fileName,
    directory: directory,
    phase: phase,
    kind: kind,
    thumbUrl: thumbUrl,
    thumbPath: path,
    startedAt: startedAt,
    finishedAt: finishedAt,
    received: received,
    total: total,
    speedBps: speedBps,
    etaSeconds: etaSeconds,
    error: error,
    filePath: filePath,
    url: url,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'fileName': fileName,
    'directory': directory,
    'phase': phase.name,
    'kind': kind.storedName,
    'thumbUrl': thumbUrl,
    'startedAt': startedAt.millisecondsSinceEpoch,
    'finishedAt': finishedAt?.millisecondsSinceEpoch,
    'received': received,
    'total': total,
    'speedBps': speedBps,
    'etaSeconds': etaSeconds,
    'error': error,
    'filePath': filePath,
    'url': url,
    'thumbPath': thumbPath,
  };
}

/// What handing a job to the queue did: the row it lives in, and whether
/// that row was already there.
typedef WallpaperDownloadHandover = ({WallpaperDownloadTask task, bool duplicate});

/// The wallpaper downloads' queue and the history behind it.
///
/// The preview and the library grid hand a job over and keep walking; the
/// manager panel watches this list. Transfers write a `.part` beside the
/// target and rename only once the whole answer arrived, so a broken or
/// stopped download never looks like a usable file. Finished and failed rows
/// are kept for the next run, so the manager reads like a download tool's
/// list rather than whatever happened to be moving.
final class WallpaperDownloadsController extends Notifier<List<WallpaperDownloadTask>> {
  final Map<String, LiveStreamedResponse?> _transfers = {};
  Timer? _persistTimer;
  DateTime? _lastPaint;
  int _serial = 0;

  /// The last pace sample per running row: bytes seen, when, and the speed
  /// the smoothed estimate carries. A fresh row starts empty and settles on
  /// the second paint.
  final Map<String, ({int bytes, DateTime at, double speed})> _samples = {};

  @override
  List<WallpaperDownloadTask> build() {
    ref.onDispose(() {
      _persistTimer?.cancel();
      for (final response in _transfers.values) {
        try {
          unawaited(response?.close() ?? Future<void>.value());
        } on Object {
          // A transfer already gone needs no closing.
        }
      }
    });
    return _readHistory();
  }

  /// Fetches [url] into the shared download folder.
  ///
  /// An address already moving — or already saved with its file still there —
  /// answers with that row instead of a second copy of the same file.
  WallpaperDownloadHandover enqueueUrl({
    required String title,
    required String url,
    required String fileName,
    required WallpaperDownloadKind kind,
    String? thumbUrl,
  }) {
    final duplicate = _duplicateOf(url: url, fileName: fileName, kind: kind);
    if (duplicate != null) return (task: duplicate, duplicate: true);
    final task = WallpaperDownloadTask(
      id: _nextId(),
      title: title,
      fileName: fileName,
      directory: _directoryFor(kind),
      phase: WallpaperDownloadPhase.running,
      kind: kind,
      thumbUrl: thumbUrl,
      startedAt: DateTime.now(),
      url: url,
    );
    _insert(task);
    unawaited(_transfer(task));
    return (task: task, duplicate: false);
  }

  /// Saves [bytes] — a random picture or a painted swatch — as one row.
  Future<WallpaperDownloadHandover> enqueueBytes({
    required String title,
    required Uint8List bytes,
    required String fileName,
    WallpaperDownloadKind kind = WallpaperDownloadKind.image,
  }) async {
    final duplicate = _duplicateOf(fileName: fileName, kind: kind);
    if (duplicate != null) return (task: duplicate, duplicate: true);
    final task = WallpaperDownloadTask(
      id: _nextId(),
      title: title,
      fileName: fileName,
      directory: _directoryFor(kind),
      phase: WallpaperDownloadPhase.running,
      kind: kind,
      startedAt: DateTime.now(),
      total: bytes.length,
      received: bytes.length,
    );
    _insert(task);
    await _writeBytes(task, bytes);
    return (task: task, duplicate: false);
  }

  /// Copies a file the viewer already owns (an imported picture or clip) into
  /// the download folder, so the manager tells one story about every file.
  Future<WallpaperDownloadHandover> enqueueCopy({
    required String title,
    required String sourcePath,
    required String fileName,
    WallpaperDownloadKind kind = WallpaperDownloadKind.image,
    String? thumbUrl,
  }) async {
    final duplicate = _duplicateOf(fileName: fileName, kind: kind);
    if (duplicate != null) return (task: duplicate, duplicate: true);
    final task = WallpaperDownloadTask(
      id: _nextId(),
      title: title,
      fileName: fileName,
      directory: _directoryFor(kind),
      phase: WallpaperDownloadPhase.running,
      kind: kind,
      thumbUrl: thumbUrl,
      startedAt: DateTime.now(),
    );
    _insert(task);
    try {
      final source = File(sourcePath);
      final target = File(p.join(task.directory, task.fileName));
      await target.parent.create(recursive: true);
      await source.copy(target.path);
      final size = target.existsSync() ? target.lengthSync() : 0;
      _settle(task.id, phase: WallpaperDownloadPhase.done, filePath: target.path, received: size, total: size);
    } on Object catch (error) {
      _settle(task.id, phase: WallpaperDownloadPhase.failed, error: '$error');
    }
    return (task: task, duplicate: false);
  }

  /// The row that already holds this job: the same name or the same address,
  /// either still moving or saved with its file still on disk. A row whose
  /// file has since been deleted does not count — the viewer asking again is
  /// how the file comes back.
  WallpaperDownloadTask? _duplicateOf({required String fileName, required WallpaperDownloadKind kind, String? url}) {
    final directory = _directoryFor(kind);
    for (final task in state) {
      if (task.directory != directory || task.fileName != fileName) continue;
      if (_holdsFile(task)) return task;
    }
    if (url == null || url.isEmpty) return null;
    for (final task in state) {
      if (task.url != url) continue;
      if (_holdsFile(task)) return task;
    }
    return null;
  }

  static bool _holdsFile(WallpaperDownloadTask task) =>
      task.isRunning || (task.phase == WallpaperDownloadPhase.done && _exists(task.filePath));

  /// Fetches a failed row again, from its own address, into its own name.
  Future<void> retry(String id) async {
    final task = _taskOf(id);
    if (task == null || !task.isRetriable) return;
    final restarted = task.restarted();
    _patch(id, (_) => restarted);
    _samples.remove(id);
    await _transfer(restarted);
  }

  /// Stops a moving transfer at the viewer's word; the row keeps its
  /// partial bytes and waits for [resume].
  Future<void> pause(String id) async {
    final task = _taskOf(id);
    if (task == null || !task.isRunning) return;
    _patch(id, (task) => task.withPhase(WallpaperDownloadPhase.paused));
    _samples.remove(id);
    final response = _transfers.remove(id);
    try {
      await response?.close();
    } on Object {
      // The transfer's own unwind reports the stop.
    }
    await _persist();
  }

  /// Picks a paused row back up.
  Future<void> resume(String id) async {
    final task = _taskOf(id);
    if (task == null || !task.isResumable) return;
    final restarted = task.restarted();
    _patch(id, (_) => restarted);
    await _transfer(restarted);
  }

  /// Drops a row; a running transfer is stopped and its `.part` is cleaned up
  /// by the transfer's own unwind.
  Future<void> remove(String id) async {
    state = [
      for (final task in state)
        if (task.id != id) task,
    ];
    final response = _transfers.remove(id);
    try {
      await response?.close();
    } on Object {
      // The transfer already ended.
    }
    await _persist();
  }

  /// Drops many rows at once — the manager's multi-select delete. One
  /// write, one stop per moving transfer.
  Future<void> removeMany(Iterable<String> ids) async {
    if (ids.isEmpty) return;
    final dropping = ids.toSet();
    state = [
      for (final task in state)
        if (!dropping.contains(task.id)) task,
    ];
    for (final id in dropping) {
      final response = _transfers.remove(id);
      try {
        await response?.close();
      } on Object {
        // The transfer already ended.
      }
    }
    await _persist();
  }

  /// Drops every row — the manager's clear-all. Moving transfers are
  /// stopped on their way out.
  Future<void> removeAll() async {
    state = const [];
    final responses = [..._transfers.values];
    _transfers.clear();
    for (final response in responses) {
      try {
        await response?.close();
      } on Object {
        // The transfer already ended.
      }
    }
    await _persist();
  }

  /// Drops the finished and failed rows; what is still moving stays.
  Future<void> clearFinished() async {
    state = [
      for (final task in state)
        if (!task.isTerminal) task,
    ];
    await _persist();
  }

  /// Where a row's file lands: the clips keep a folder of their own beside the
  /// pictures, and a painted swatch is a picture by any other name.
  String _directoryFor(WallpaperDownloadKind kind) {
    final folders = ref.read(appPathsProvider);
    return (kind == WallpaperDownloadKind.video ? folders.videoWallpapers : folders.wallpapers).path;
  }

  String _nextId() => 'wallpaper-${DateTime.now().microsecondsSinceEpoch}-${_serial++}';

  WallpaperDownloadTask? _taskOf(String id) => state.where((task) => task.id == id).firstOrNull;

  void _insert(WallpaperDownloadTask task) {
    if (!ref.mounted) return;
    state = [task, ...state];
    _persistSoon();
  }

  void _patch(String id, WallpaperDownloadTask Function(WallpaperDownloadTask task) change) {
    if (!ref.mounted) return;
    state = [
      for (final task in state)
        if (task.id == id) change(task) else task,
    ];
  }

  Future<void> _writeBytes(WallpaperDownloadTask task, Uint8List bytes) async {
    try {
      final target = File(p.join(task.directory, task.fileName));
      await target.parent.create(recursive: true);
      await target.writeAsBytes(bytes, flush: true);
      _settle(task.id, phase: WallpaperDownloadPhase.done, filePath: target.path);
    } on Object catch (error) {
      _settle(task.id, phase: WallpaperDownloadPhase.failed, error: '$error');
    }
  }

  /// Streams one network download, painting progress as it goes.
  Future<void> _transfer(WallpaperDownloadTask task) async {
    LiveStreamedResponse? response;
    final target = File(p.join(task.directory, task.fileName));
    final part = File('${target.path}.part');
    var received = 0;
    var total = 0;
    try {
      await target.parent.create(recursive: true);
      final http = ref.read(networkFactoryProvider).create(profile: ClientProfile.api);
      response = await http.open(LiveRequest.get(Uri.parse(task.url!), timeout: const Duration(minutes: 10)));
      _transfers[task.id] = response;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.close();
        throw FileSystemException('HTTP ${response.statusCode}', task.url);
      }
      total = int.tryParse(response.headers['content-length'] ?? '') ?? 0;
      final sink = part.openWrite();
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          _paint(task.id, received: received, total: total);
        }
      } finally {
        await sink.close();
      }
      if (target.existsSync()) await target.delete();
      await part.rename(target.path);
      _samples.remove(task.id);
      _settle(task.id, phase: WallpaperDownloadPhase.done, filePath: target.path, received: received, total: total);
    } on Object catch (error) {
      try {
        if (part.existsSync()) await part.delete();
      } on Object {
        // A leftover `.part` is invisible to the UI and harmless.
      }
      // The viewer's own pause already wrote the row's next phase; a closed
      // stream unwinding through here must not call it a failure.
      final phase = _taskOf(task.id)?.phase;
      if (phase == WallpaperDownloadPhase.paused) {
        _samples.remove(task.id);
      } else {
        _samples.remove(task.id);
        _settle(task.id, phase: WallpaperDownloadPhase.failed, error: '$error', received: received, total: total);
      }
    } finally {
      _transfers.remove(task.id);
    }
  }

  void _paint(String id, {required int received, required int total}) {
    final now = DateTime.now();
    final last = _lastPaint;
    if (last != null && now.difference(last) < _kPaintGap) return;
    _lastPaint = now;
    // The pace between paints, smoothed the way a speedometer rides out the
    // bursts: the new sample carries 40% of the reading.
    final sample = _samples[id];
    final double speed;
    if (sample == null) {
      speed = 0;
      _samples[id] = (bytes: received, at: now, speed: 0);
    } else {
      final seconds = now.difference(sample.at).inMicroseconds / 1e6;
      final measured = seconds > 0 ? (received - sample.bytes) / seconds : 0.0;
      speed = sample.speed == 0 ? measured : sample.speed * 0.6 + measured * 0.4;
      _samples[id] = (bytes: received, at: now, speed: speed < 0 ? 0 : speed);
    }
    final eta = total > 0 && speed > 0 ? ((total - received) / speed).round() : null;
    _patch(
      id,
      (task) => _withProgress(task, received: received, total: total, speedBps: speed.round(), etaSeconds: eta),
    );
  }

  void _settle(
    String id, {
    required WallpaperDownloadPhase phase,
    String? filePath,
    String? error,
    int? received,
    int? total,
  }) {
    _lastPaint = null;
    _patch(id, (task) {
      return WallpaperDownloadTask(
        id: task.id,
        title: task.title,
        fileName: task.fileName,
        directory: task.directory,
        phase: phase,
        kind: task.kind,
        thumbUrl: task.thumbUrl,
        thumbPath: task.thumbPath,
        startedAt: task.startedAt,
        finishedAt: DateTime.now(),
        received: received ?? task.received,
        total: total ?? task.total,
        error: error,
        filePath: filePath ?? task.filePath,
        url: task.url,
      );
    });
    if (ref.mounted) unawaited(_persist());
    if (phase == WallpaperDownloadPhase.done && filePath != null) unawaited(_cutThumbnail(id, filePath));
  }

  /// Cuts one still from a clip that just landed: the row paints it where
  /// the catalogue sent no cover, and the wallpaper's tone lookup reads the
  /// clip's colour off it. Pictures paint themselves and are left alone.
  Future<void> _cutThumbnail(String id, String filePath) async {
    final task = _taskOf(id);
    if (task == null || task.kind != WallpaperDownloadKind.video) return;
    final still = await ref.read(backgroundClipStillsProvider).ensure(Uri.file(filePath).toString());
    if (still == null || !ref.mounted) return;
    _patch(id, (task) => task.thumbPath == still ? task : task.withThumbnail(still));
    unawaited(_persist());
  }

  WallpaperDownloadTask _withProgress(
    WallpaperDownloadTask task, {
    required int received,
    required int total,
    required int speedBps,
    int? etaSeconds,
  }) => WallpaperDownloadTask(
    id: task.id,
    title: task.title,
    fileName: task.fileName,
    directory: task.directory,
    phase: task.phase,
    kind: task.kind,
    thumbUrl: task.thumbUrl,
    thumbPath: task.thumbPath,
    startedAt: task.startedAt,
    finishedAt: task.finishedAt,
    received: received,
    total: total,
    speedBps: speedBps,
    etaSeconds: etaSeconds,
    error: task.error,
    filePath: task.filePath,
    url: task.url,
  );

  void _persistSoon() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 500), () => unawaited(_persist()));
  }

  Future<void> _persist() async {
    try {
      // Paused rows stay too: their files are half there, and the manager's
      // continue is how they come back.
      final history = state.where((task) => !task.isRunning).take(_kHistoryLimit).toList();
      await StoragePrefs.setString(kWallpaperDownloadsKey, jsonEncode([for (final task in history) task.toJson()]));
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  static List<WallpaperDownloadTask> _readHistory() {
    try {
      final raw = StoragePrefs.getString(kWallpaperDownloadsKey);
      if (raw == null || raw.isEmpty) return const [];
      final json = jsonDecode(raw);
      if (json is! List) return const [];
      // A completed row whose file has since been deleted tells nothing the
      // folder could not; the record goes with the file.
      return [
        for (final entry in json)
          if (entry is Map) WallpaperDownloadTask.fromJson(entry.cast<String, Object?>()),
      ].where((task) => task.phase != WallpaperDownloadPhase.done || _exists(task.filePath)).toList();
    } on Object {
      return const [];
    }
  }

  static bool _exists(String? path) => path != null && path.isNotEmpty && File(path).existsSync();
}

/// The wallpaper download queue and its history.
final wallpaperDownloadsProvider = NotifierProvider<WallpaperDownloadsController, List<WallpaperDownloadTask>>(
  WallpaperDownloadsController.new,
);

/// How many downloads are still moving.
int wallpaperDownloadsActive(List<WallpaperDownloadTask> tasks) => tasks.where((task) => task.isRunning).length;
