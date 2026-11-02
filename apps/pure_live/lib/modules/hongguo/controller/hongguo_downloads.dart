import 'dart:async' show Timer, unawaited;
import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:io' show Directory, File, FileMode, FileSystemException, HttpClient, HttpException, IOSink;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_net/live_net.dart' show ClientProfile;
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:path/path.dart' as p;

import 'package:pure_live/app/app.dart' show networkFactoryProvider;
import 'package:pure_live/app/providers/boot/storage_providers.dart' show appPathsProvider;
import 'package:pure_live/modules/hongguo/controller/hongguo_client.dart'
    show hongguoClientProvider, hongguoPickRendition;
import 'package:pure_live/modules/hongguo/controller/hongguo_decoder.dart' show hongguoDecoderLessonsProvider;
import 'package:pure_live/modules/hongguo/controller/hongguo_settings.dart' show HongguoQualityChoice;
import 'package:pure_live/modules/hongguo/official/hongguo_proxy.dart' show HongguoStreamProxy;

/// The preference the download queue is kept under.
const String kHongguoDownloadsKey = 'hongguo.downloads';

/// The preference the lane count is kept under.
const String _kMaxConcurrent = 'hongguo.download.maxConcurrent';

/// The preference the download quality is kept under.
const String _kDownloadQuality = 'hongguo.download.quality';

/// What a task is doing.
enum HongguoDownloadPhase {
  /// Waiting for a lane.
  queued,

  /// Bytes are moving.
  running,

  /// The viewer stopped it; the `.part` file stays.
  paused,

  /// The last run failed; the error names why.
  failed,

  /// The file is complete and renamed into place.
  done;

  /// Reads the phase from its storage JSON; an unknown name reads as paused,
  /// so a half-written entry still lists and can be resumed.
  static HongguoDownloadPhase fromName(Object? name) =>
      HongguoDownloadPhase.values.firstWhere((phase) => phase.name == name, orElse: () => HongguoDownloadPhase.paused);
}

/// What enqueueing one episode came to.
enum HongguoDownloadEnqueue { queued, duplicate, failed }

/// The outcome of asking the queue for one episode.
typedef HongguoDownloadResult = ({HongguoDownloadEnqueue outcome, String? error});

/// One episode being fetched into the viewer's Videos folder.
///
/// The bytes land in a `.part` file beside the target and the finished file
/// is renamed into place, so a failed download leaves nothing half-written
/// behind. The stream rides the station's local decrypting proxy — the queue
/// keeps its own instance, so closing a player page never pulls a download's
/// stream out from under it.
final class HongguoDownloadItem {
  /// Creates the task.
  const HongguoDownloadItem({
    required this.id,
    required this.seriesId,
    required this.title,
    required this.part,
    required this.index,
    required this.parts,
    required this.maxHeight,
    required this.fileName,
    required this.filePath,
    required this.phase,
    required this.stamp,
    this.cover = '',
    this.received = 0,
    this.total = 0,
    this.speed = 0,
    this.attempts = 0,
    this.error,
  });

  /// Reads the task from its storage JSON; a task without a phase reads as
  /// paused, so a half-written entry still lists.
  factory HongguoDownloadItem.fromJson(Map<String, Object?> json) {
    return HongguoDownloadItem(
      id: json['id'] as String? ?? '',
      seriesId: json['seriesId'] as String? ?? '',
      cover: json['cover'] as String? ?? '',
      title: json['title'] as String? ?? '',
      part: json['part'] as String? ?? '',
      index: json['index'] as int? ?? 1,
      parts: json['parts'] as int? ?? 1,
      maxHeight: json['maxHeight'] as int? ?? 1080,
      fileName: json['fileName'] as String? ?? '',
      filePath: json['filePath'] as String? ?? '',
      phase: HongguoDownloadPhase.fromName(json['phase']),
      stamp: json['stamp'] as int? ?? 0,
      received: json['received'] as int? ?? 0,
      total: json['total'] as int? ?? 0,
      speed: json['speed'] as int? ?? 0,
      attempts: json['attempts'] as int? ?? 0,
      error: json['error'] as String?,
    );
  }

  /// The episode's vid — the queue's key.
  final String id;

  /// The series' poster: the manager previews the drama it downloaded rather
  /// than a file name. Empty on tasks queued before it was kept.
  final String cover;

  /// The series the episode belongs to, for the player page's lookup.
  final String seriesId;

  /// The series' name, the visible row title's root.
  final String title;

  /// The episode's own name.
  final String part;

  /// The episode's 1-based place in the series.
  final int index;

  /// How many episodes the series lists.
  final int parts;

  /// The tallest rendition the run may pick.
  final int maxHeight;

  /// The name the finished file carries.
  final String fileName;

  /// Where the finished file lands; the `.part` sits beside it.
  final String filePath;

  /// What the task is doing.
  final HongguoDownloadPhase phase;

  /// When the task was enqueued or finished, in epoch milliseconds.
  final int stamp;

  /// The bytes already written.
  final int received;

  /// The bytes the whole file counts, when the source said.
  final int total;

  /// The smoothed bytes-per-second of the moving task.
  final int speed;

  /// How many automatic retries this row has used since the viewer queued it
  /// (or retried it by hand, which starts the budget again).
  final int attempts;

  /// The failure's words, on a failed task.
  final String? error;

  /// The finished fraction, or null while the total is unknown.
  double? get progress => total > 0 ? (received / total).clamp(0.0, 1.0) : null;

  /// Returns this task with the given fields replaced.
  ///
  /// [filePath] and [fileName] move together: a row whose file was merged into
  /// another folder names the new place and the new file in one write, so no
  /// reader can catch it with one half moved. Unlike the other fields, leaving
  /// them out keeps what the row already had — [error] is the one field this
  /// copy always takes from the caller, so pass it through when you mean to
  /// keep it.
  HongguoDownloadItem copyWith({
    int? received,
    int? total,
    int? speed,
    int? attempts,
    HongguoDownloadPhase? phase,
    String? error,
    String? filePath,
    String? fileName,
  }) {
    return HongguoDownloadItem(
      id: id,
      seriesId: seriesId,
      // Not a copy parameter: the picture the queue kept at enqueue time
      // belongs to the row, and a progress write used to drop it — every
      // paused, retried or measured row lost its poster, and with it the list
      // header's picture.
      cover: cover,
      title: title,
      part: part,
      index: index,
      parts: parts,
      maxHeight: maxHeight,
      fileName: fileName ?? this.fileName,
      filePath: filePath ?? this.filePath,
      phase: phase ?? this.phase,
      stamp: stamp,
      received: received ?? this.received,
      total: total ?? this.total,
      speed: speed ?? this.speed,
      attempts: attempts ?? this.attempts,
      error: error,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'seriesId': seriesId,
    'cover': cover,
    'title': title,
    'part': part,
    'index': index,
    'parts': parts,
    'maxHeight': maxHeight,
    'fileName': fileName,
    'filePath': filePath,
    'phase': phase.name,
    'stamp': stamp,
    'received': received,
    'total': total,
    'speed': speed,
    'attempts': attempts,
    if (error != null) 'error': error,
  };
}

/// How many lanes the queue runs at once.
final class HongguoDownloadSettingsController extends Notifier<int> {
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
final hongguoDownloadSettingsProvider = NotifierProvider<HongguoDownloadSettingsController, int>(
  HongguoDownloadSettingsController.new,
);

/// The most automatic retries a failed run gives itself; zero is off.
const String _kRetryAttempts = 'hongguo.download.retryAttempts';

/// Seconds between two automatic retries.
const String _kRetryDelay = 'hongguo.download.retryDelaySeconds';

/// How many times a failed download retries itself.
final class HongguoDownloadRetryController extends Notifier<int> {
  /// The choices the settings row offers.
  static const List<int> choices = [0, 1, 2, 3];

  @override
  int build() {
    try {
      final stored = StoragePrefs.getInt(_kRetryAttempts);
      if (stored != null && stored >= 0 && stored <= 3) return stored;
    } on Object {
      // A closed store falls back to no automatic retry.
    }
    return 0;
  }

  /// Chooses [count] and keeps it for the next failure.
  void select(int count) {
    final value = count.clamp(0, 3);
    if (value == state) return;
    state = value;
    try {
      unawaited(StoragePrefs.setInt(_kRetryAttempts, value));
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// The retry count for the station's download queue.
final hongguoDownloadRetryProvider = NotifierProvider<HongguoDownloadRetryController, int>(
  HongguoDownloadRetryController.new,
);

/// The wait between two automatic retries, in seconds.
final class HongguoDownloadRetryDelayController extends Notifier<int> {
  /// The choices the settings row offers.
  static const List<int> choices = [5, 10, 30, 60];

  @override
  int build() {
    try {
      final stored = StoragePrefs.getInt(_kRetryDelay);
      if (stored != null && choices.contains(stored)) return stored;
    } on Object {
      // A closed store falls back to ten seconds.
    }
    return 10;
  }

  /// Chooses [seconds] and keeps it for the next failure.
  void select(int seconds) {
    if (!choices.contains(seconds) || seconds == state) return;
    state = seconds;
    try {
      unawaited(StoragePrefs.setInt(_kRetryDelay, seconds));
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// The retry delay for the station's download queue.
final hongguoDownloadRetryDelayProvider = NotifierProvider<HongguoDownloadRetryDelayController, int>(
  HongguoDownloadRetryDelayController.new,
);

/// The rendition tier a download picks, its own choice so the viewer can
/// save a series in a different tier than they watch it in.
final class HongguoDownloadQualityController extends Notifier<HongguoQualityChoice> {
  @override
  HongguoQualityChoice build() {
    try {
      final stored = StoragePrefs.getString(_kDownloadQuality);
      for (final choice in HongguoQualityChoice.values) {
        if (choice.name == stored) return choice;
      }
    } on Object {
      // A closed store falls back to the best tier.
    }
    return HongguoQualityChoice.best;
  }

  /// Chooses [choice] and keeps it for the next download.
  void select(HongguoQualityChoice choice) {
    if (choice == state) return;
    state = choice;
    try {
      unawaited(StoragePrefs.setString(_kDownloadQuality, choice.name));
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// The tier a download fetches by default.
final hongguoDownloadQualityProvider = NotifierProvider<HongguoDownloadQualityController, HongguoQualityChoice>(
  HongguoDownloadQualityController.new,
);

/// The download queue's own decrypting proxy — the player's is separate, so
/// a closed player page never pulls a download's stream out from under it.
final hongguoDownloadProxyProvider = Provider<HongguoStreamProxy>((ref) {
  final proxy = HongguoStreamProxy(http: ref.watch(networkFactoryProvider).create(profile: ClientProfile.api));
  ref.onDispose(proxy.close);
  return proxy;
});

/// Why a running task was told to stop.
enum _HongguoStop { pause, drop }

/// Thrown when a stopped run unwinds; the finally block does the bookkeeping.
final class _Stopped implements Exception {
  const _Stopped();
}

/// The station's download queue: the rows kept for the next run, and the
/// lanes that fetch them.
///
/// Every run — a start, a resume, a retry — asks the platform's ladder again
/// and registers the picked rendition on the queue's own proxy, because the
/// CDN's addresses are short-lived. The proxy answers plain mp4 in at most
/// eight mebibytes a response, so the run keeps asking with a range for what
/// is left until the file is whole. What was written stays in a `.part` file
/// and the next run carries on from there.
final class HongguoDownloadsController extends Notifier<List<HongguoDownloadItem>> {
  final List<HongguoDownloadItem> _items = [];
  final Map<String, HttpClient> _clients = {};
  final Map<String, _HongguoStop> _stops = {};
  final Map<String, Timer> _retryTimers = {};
  Timer? _persistTimer;

  @override
  List<HongguoDownloadItem> build() {
    _items
      ..clear()
      ..addAll(_readTasks());
    // A run the previous session left mid-flight keeps its bytes, paused.
    for (var index = 0; index < _items.length; index++) {
      if (_items[index].phase == HongguoDownloadPhase.running) {
        _items[index] = _items[index].copyWith(phase: HongguoDownloadPhase.paused, speed: 0);
      }
    }
    ref.listen(hongguoDownloadSettingsProvider, (_, _) => _pump());
    ref.onDispose(() {
      _persistTimer?.cancel();
      for (final timer in _retryTimers.values) {
        timer.cancel();
      }
      _retryTimers.clear();
      for (final client in _clients.values) {
        client.close(force: true);
      }
      _clients.clear();
    });
    Timer.run(_pump);
    return List.unmodifiable(_items);
  }

  /// Adds one episode to the queue; the file name and its place are fixed
  /// here so a resume and its `.part` find each other after a restart.
  Future<HongguoDownloadResult> download({
    required String vid,
    required String seriesId,
    required String title,
    required String part,
    required int index,
    required int parts,
    required int maxHeight,
    String cover = '',
  }) async {
    final existing = _items.where((item) => item.id == vid).firstOrNull;
    if (existing != null && existing.phase != HongguoDownloadPhase.failed) {
      return (outcome: HongguoDownloadEnqueue.duplicate, error: null);
    }
    try {
      final directory = ref.read(appPathsProvider).shortDramas;
      // Made here rather than trusted to boot: the folder row can name a path
      // that does not exist yet, and a missing directory fails the first
      // write inside the sink instead of failing the enqueue honestly.
      await directory.create(recursive: true);
      final name = hongguoDownloadFileName(title: title, part: part, index: index, parts: parts);
      final target = hongguoFreeDownloadFile(directory, name);
      final item = HongguoDownloadItem(
        id: vid,
        seriesId: seriesId,
        cover: cover,
        title: title,
        part: part,
        index: index,
        parts: parts,
        maxHeight: maxHeight,
        fileName: p.basename(target.path),
        filePath: target.path,
        phase: HongguoDownloadPhase.queued,
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
      return (outcome: HongguoDownloadEnqueue.queued, error: null);
    } on Object catch (failure) {
      return (outcome: HongguoDownloadEnqueue.failed, error: '$failure');
    }
  }

  /// The task for one episode, when the queue has it.
  HongguoDownloadItem? taskOf(String vid) => _items.where((item) => item.id == vid).firstOrNull;

  Future<void> pause(String id) async {
    final item = _items.where((row) => row.id == id).firstOrNull;
    if (item == null) return;
    _retryTimers.remove(id)?.cancel();
    switch (item.phase) {
      case HongguoDownloadPhase.running:
        _stops[id] = _HongguoStop.pause;
        _clients[id]?.close(force: true);
      case HongguoDownloadPhase.queued:
        _replace(item.copyWith(phase: HongguoDownloadPhase.paused, speed: 0));
        await _persist();
      case HongguoDownloadPhase.paused || HongguoDownloadPhase.done || HongguoDownloadPhase.failed:
        break;
    }
  }

  /// Resumes a paused task, or retries a failed one — the bytes already
  /// written stay and a range request carries on from there.
  Future<void> resume(String id) async {
    final item = _items.where((row) => row.id == id).firstOrNull;
    if (item == null) return;
    if (item.phase != HongguoDownloadPhase.paused && item.phase != HongguoDownloadPhase.failed) return;
    _retryTimers.remove(id)?.cancel();
    _replace(item.copyWith(phase: HongguoDownloadPhase.queued, attempts: 0, speed: 0));
    await _persist();
    _pump();
  }

  /// Stops a task and drops its row and its `.part`; a finished task keeps
  /// its file unless [deleteFile] says otherwise.
  Future<void> remove(String id, {bool deleteFile = false}) async {
    final item = _items.where((row) => row.id == id).firstOrNull;
    if (item == null) return;
    if (item.phase == HongguoDownloadPhase.running) {
      _stops[id] = _HongguoStop.drop;
      _clients[id]?.close(force: true);
      return;
    }
    await _drop(item, deleteFile: deleteFile);
  }

  Future<void> pauseAll() async {
    var stopped = false;
    for (final item in _items) {
      switch (item.phase) {
        case HongguoDownloadPhase.queued:
          _replace(item.copyWith(phase: HongguoDownloadPhase.paused));
        case HongguoDownloadPhase.running:
          _stops[item.id] = _HongguoStop.pause;
          _clients[item.id]?.close(force: true);
          stopped = true;
        case HongguoDownloadPhase.paused || HongguoDownloadPhase.done || HongguoDownloadPhase.failed:
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
      if (item.phase == HongguoDownloadPhase.paused || item.phase == HongguoDownloadPhase.failed) {
        _retryTimers.remove(item.id)?.cancel();
        _items[index] = item.copyWith(phase: HongguoDownloadPhase.queued, attempts: 0, speed: 0);
      }
    }
    _publish();
    await _persist();
    _pump();
  }

  /// Drops the finished rows; their files stay.
  Future<void> clearFinished() async {
    _items.removeWhere((item) => item.phase == HongguoDownloadPhase.done);
    _publish();
    await _persist();
  }

  /// The finished episodes this queue holds whose file sits outside the folder
  /// the viewer uses for them now — what the shared 视频 folder kept before the
  /// dramas got one of their own.
  ///
  /// Only a row that finished and still names an existing file outside that
  /// folder counts. A transfer owed bytes is never a candidate: its `.part`
  /// lives beside where it is writing, and moving it mid-run would leave the
  /// writer appending to a file that is no longer there.
  List<HongguoDownloadItem> stranded() {
    final into = ref.read(appPathsProvider).shortDramas.path;
    return [
      for (final item in _items)
        if (item.phase == HongguoDownloadPhase.done && File(item.filePath).existsSync() && !_under(item.filePath, into))
          item,
    ];
  }

  /// Brings the finished rows in [stranded] under the folder the viewer uses
  /// for dramas, and rewrites each row to the place its file landed.
  ///
  /// One file at a time, each result persisted the moment it lands: a merge
  /// interrupted halfway leaves the rows it moved pointing at the new folder
  /// and the rows it never reached pointing at the old one, and both are true.
  /// The source is deleted only after the copy's byte count matches what the
  /// source held — a move that fails leaves the file exactly where it was, with
  /// its row still naming it, which is why this verb is the viewer's call and
  /// never something the app does on its own.
  Future<({int moved, int failed})> mergeStranded(
    List<HongguoDownloadItem> stranded, {
    void Function(int done, int total, String name)? onProgress,
    bool Function()? cancelled,
  }) async {
    final into = ref.read(appPathsProvider).shortDramas;
    await into.create(recursive: true);
    var moved = 0;
    var failed = 0;
    for (var index = 0; index < stranded.length; index++) {
      if (cancelled != null && cancelled()) break;
      final item = stranded[index];
      // A row the viewer removed while this run was going has no pointer left to
      // update: leave its file where it is rather than move it somewhere nothing
      // names.
      if (!_items.any((row) => row.id == item.id)) continue;
      final name = p.basename(item.filePath);
      onProgress?.call(index, stranded.length, name);
      try {
        final source = File(item.filePath);
        final target = hongguoFreeDownloadFile(into, name);
        try {
          await source.rename(target.path);
        } on FileSystemException {
          // Another volume: the rename cannot link, so copy, prove, then let go.
          await source.copy(target.path);
          if (await source.length() != await target.length()) {
            await target.delete();
            failed++;
            continue;
          }
          await source.delete();
        }
        _replace(item.copyWith(filePath: target.path, fileName: p.basename(target.path), error: item.error));
        await _persist();
        moved++;
      } on Object {
        // The file stayed where it was and the row still names it: say so in
        // the count rather than pretend the queue moved.
        failed++;
      }
    }
    onProgress?.call(stranded.length, stranded.length, '');
    return (moved: moved, failed: failed);
  }

  /// Whether [path] sits under [folder] — the test that decides a row is
  /// already home and needs no moving.
  static bool _under(String path, String folder) {
    final normalised = p.split(p.normalize(path)).join('/');
    final base = p.split(p.normalize(folder)).join('/');
    return normalised == base || normalised.startsWith('$base/');
  }

  /// Removes a part file, and a finished task's file when asked.
  Future<void> _drop(HongguoDownloadItem item, {bool deleteFile = false}) async {
    _retryTimers.remove(item.id)?.cancel();
    _items.removeWhere((row) => row.id == item.id);
    _publish();
    await _delete(File('${item.filePath}.part'));
    if (deleteFile && item.phase == HongguoDownloadPhase.done) {
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
    var lanes = ref.read(hongguoDownloadSettingsProvider);
    for (final item in _items) {
      if (lanes <= 0) break;
      if (item.phase != HongguoDownloadPhase.queued) continue;
      lanes--;
      unawaited(_run(item.id));
    }
  }

  /// Runs one task to an end: a fresh ladder and proxy registration, the
  /// part file carried on with range requests, and the row kept in step
  /// every quarter second.
  Future<void> _run(String id) async {
    final found = _items.where((row) => row.id == id).firstOrNull;
    if (found == null || found.phase != HongguoDownloadPhase.queued) return;
    var item = found.copyWith(phase: HongguoDownloadPhase.running);
    _replace(item);

    HttpClient? client;
    IOSink? sink;
    var received = item.received;
    var stopped = false;
    var proxyUrl = '';
    try {
      final ladder = await ref.read(hongguoClientProvider).playbackLadder(item.id);
      if (_stops.containsKey(id)) throw const _Stopped();
      final rendition = hongguoPickRendition(
        ladder,
        item.maxHeight,
        learnedFailures: ref.read(hongguoDecoderLessonsProvider),
      );
      proxyUrl = await ref.read(hongguoDownloadProxyProvider).register(rendition);
      // A row kept from the last session can outlive its folder; the run
      // makes room for itself again.
      await Directory(item.filePath).parent.create(recursive: true);
      final scratch = File('${item.filePath}.part');
      final written = scratch.existsSync() ? scratch.lengthSync() : 0;
      client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
      _clients[id] = client;
      received = written;
      sink = scratch.openWrite(mode: written > 0 ? FileMode.append : FileMode.write);
      // The sink's own future reports a failed write; observing it keeps the
      // failure here instead of as an unattributed uncaught error.
      unawaited(sink.done.catchError((Object _) {}));
      // The proxy answers at most eight mebibytes a response and names the
      // whole file in its Content-Range, so the run keeps asking for what
      // is left until every byte is home.
      var windowBytes = 0;
      var windowStarted = DateTime.now();
      var speed = 0;
      var lastTick = DateTime.now().millisecondsSinceEpoch;
      var total = 0;
      while (!stopped) {
        final request = await client.getUrl(Uri.parse(proxyUrl));
        if (received > 0) request.headers.set('range', 'bytes=$received-');
        final response = await request.close();
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw HttpException('HTTP ${response.statusCode}');
        }
        final contentRange = response.headers.value('content-range') ?? '';
        final match = RegExp(r'bytes (\d+)-(\d+)/(\d+)').firstMatch(contentRange);
        total = match == null
            ? (received > 0 ? received + response.contentLength : response.contentLength)
            : int.tryParse(match.group(3) ?? '') ?? 0;
        item = item.copyWith(received: received, total: total);
        _replace(item);
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
        if (stopped) break;
        if (total <= 0 || received >= total) break;
      }
      await sink.flush();
      await sink.close();
      sink = null;
      if (stopped) return;
      if (total > 0 && received < total) {
        throw HttpException('the stream ended ${total - received} bytes short');
      }
      final target = File(item.filePath);
      await _delete(target);
      await scratch.rename(target.path);
      _replace(item.copyWith(received: received, speed: 0, phase: HongguoDownloadPhase.done));
    } on Object catch (error) {
      if (error is! _Stopped && !stopped) {
        item = item.copyWith(received: received, speed: 0, phase: HongguoDownloadPhase.failed, error: '$error');
        _replace(item);
        _scheduleRetry(item.id);
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
      if (proxyUrl.isNotEmpty) {
        try {
          ref.read(hongguoDownloadProxyProvider).forget(proxyUrl);
        } on Object {
          // The proxy's entries end with its own lifetime anyway.
        }
      }
      final stop = _stops.remove(id);
      if (stop == _HongguoStop.drop) {
        await _drop(item);
      } else {
        if (stop == _HongguoStop.pause) {
          item = item.copyWith(received: received, speed: 0, phase: HongguoDownloadPhase.paused);
          _replace(item);
        }
        await _persist();
        _pump();
      }
    }
  }

  /// Queues a failed row again after the wait the viewer chose, while the
  /// row still has automatic retries left. A hand retry starts the budget
  /// over: that is a new instruction, not a continuation.
  void _scheduleRetry(String id) {
    final limit = ref.read(hongguoDownloadRetryProvider);
    if (limit <= 0) return;
    final current = _items.where((row) => row.id == id).firstOrNull;
    if (current == null || current.phase != HongguoDownloadPhase.failed) return;
    if (current.attempts >= limit) return;
    final delay = Duration(seconds: ref.read(hongguoDownloadRetryDelayProvider));
    _retryTimers[id]?.cancel();
    _retryTimers[id] = Timer(delay, () {
      _retryTimers.remove(id);
      if (!ref.mounted) return;
      final retry = _items.where((row) => row.id == id).firstOrNull;
      if (retry == null || retry.phase != HongguoDownloadPhase.failed) return;
      _replace(retry.copyWith(phase: HongguoDownloadPhase.queued, attempts: retry.attempts + 1, speed: 0));
      unawaited(_persist());
      _pump();
    });
    // The failed row was published before the wait began; publish again so
    // its caption can say when the queue will come back for it.
    _publish();
  }

  /// Whether [id] is waiting out an automatic retry.
  bool hasPendingRetry(String id) => _retryTimers.containsKey(id);

  void _replace(HongguoDownloadItem item) {
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
      await StoragePrefs.setString(kHongguoDownloadsKey, jsonEncode([for (final item in _items) item.toJson()]));
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  static List<HongguoDownloadItem> _readTasks() {
    try {
      final raw = StoragePrefs.getString(kHongguoDownloadsKey);
      if (raw == null || raw.isEmpty) return const [];
      final json = jsonDecode(raw);
      if (json is! List) return const [];
      return [
        for (final entry in json)
          if (entry is Map) HongguoDownloadItem.fromJson(entry.cast<String, Object?>()),
      ];
    } on Object {
      return const [];
    }
  }
}

/// The station's download queue.
final hongguoDownloadsProvider = NotifierProvider<HongguoDownloadsController, List<HongguoDownloadItem>>(
  HongguoDownloadsController.new,
);

/// The task for one episode, when the queue has it — the pages read this
/// instead of reaching into the list.
HongguoDownloadItem? hongguoDownloadOf(List<HongguoDownloadItem> items, String vid) =>
    items.where((item) => item.id == vid).firstOrNull;

/// The file an episode writes: the series' name, the episode's place when
/// the series has more than one, and the episode's own name.
String hongguoDownloadFileName({
  required String title,
  required String part,
  int index = 1,
  int parts = 1,
  String extension = 'mp4',
}) {
  final raw = parts > 1 ? '$title - EP$index $part' : title;
  final clean = raw.replaceAll(RegExp(r'[\\/:*?"<>|\r\n\t]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  final name = clean.isEmpty ? 'hongguo_$index' : clean;
  return '$name.$extension';
}

/// A file named [name] in [folder] that does not exist yet, adding `_2`,
/// `_3` … when the name is taken.
File hongguoFreeDownloadFile(Directory folder, String name) {
  final base = p.basenameWithoutExtension(name);
  final extension = p.extension(name);
  var file = File(p.join(folder.path, name));
  for (var index = 2; file.existsSync(); index++) {
    file = File(p.join(folder.path, '${base}_$index$extension'));
  }
  return file;
}
