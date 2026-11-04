import 'dart:io' show Directory, File, FileStat, FileSystemEntity, FileSystemEntityType;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_core_recording_ffmpeg/media_core_recording_ffmpeg.dart' show FfmpegRecordArguments;
import 'package:path/path.dart' as p;
import 'package:pure_live/app/app.dart' show appPathsProvider;
import 'package:pure_live/modules/live/recorder/data/recording_preview.dart' show playableFileAt;
import 'package:pure_live/modules/live/recorder/data/recording_repository.dart' show recordingTasksProvider;
import 'package:pure_live/modules/live/recorder/data/recording_task.dart'
    show RecordingTask, RecordingTaskState, kIptvRecordingKind, kLiveRecordingKind, recordingKindOf;

/// The folder-name marker the recorder leaves in the root it owns; it is not a
/// take and never belongs in the library.
const String _kManagedRootMarker = '.pure_live_recording_root';

/// One recorded take, read back from the folder tree rather than from the task
/// store.
///
/// The store keys a task by `platform:roomId`, so a room recorded twice keeps
/// exactly one row and its older take — though it still sits on disk at
/// `<root>/<day>/<platform>/<room>/<take>/` — vanishes from any list built on
/// the store alone. The tree is what the viewer actually has, so the library
/// walks the tree and joins the task where the folder still names one.
final class RecordingTake {
  const RecordingTake({
    required this.folder,
    required this.day,
    required this.platformFolder,
    required this.roomFolder,
    required this.name,
    required this.filePath,
    required this.bytes,
    required this.takenAt,
    this.task,
  });

  /// The take's own folder on disk.
  final String folder;

  /// The day folder it lives under — `YYYY-MM-DD` when the recorder wrote it,
  /// or the day the file was last written for anything older or moved.
  final String day;

  /// The platform and room folder names, as the recorder sanitised them.
  final String platformFolder;
  final String roomFolder;

  /// The take's folder name; what the file is called on disk.
  final String name;

  /// The file a player opens, or null while the take holds nothing playable.
  final String? filePath;

  /// The playable file's size, or the folder's when no single file stands.
  final int bytes;

  /// When the take was made: the file's stamp when there is one.
  final DateTime takenAt;

  /// The task whose folder is this take, when the store still knows it. It
  /// carries the room's title, its state and — for the last take only — the
  /// media length.
  final RecordingTask? task;

  /// Whether there is something to play.
  bool get playable => filePath != null;

  /// The day as the viewer reads it: [today] and [yesterday] stand in for the
  /// two dates nobody reads as digits. The grouping never uses this — it keys on
  /// [day], which is the folder's real name.
  String dayTitle({required String today, required String yesterday}) {
    if (day.isEmpty) return day;
    final stamp = DateTime.tryParse(day);
    if (stamp == null) return day;
    final now = DateTime.now();
    if (stamp.year == now.year && stamp.month == now.month && stamp.day == now.day) return today;
    final before = now.subtract(const Duration(days: 1));
    if (stamp.year == before.year && stamp.month == before.month && stamp.day == before.day) return yesterday;
    return day;
  }

  /// The tree this take lives under — `live` for a room, `iptv` for a
  /// channel. Legacy takes filed before the split report the kind their
  /// platform implies, which is the tree a re-file would use.
  String get kind => recordingKindOf(platformId);

  /// The site id, when the store's row still says so; an orphan take whose row
  /// was deleted keeps only the folder's name.
  String get platformId => task?.platform ?? platformFolder;

  /// The room id as the folder names it.
  String get roomId => task?.roomId ?? roomFolder;

  /// What the viewer recognises: the room's title when a row still carries it,
  /// the folder name otherwise.
  String get roomTitle {
    final titled = (task?.roomTitle ?? '').trim();
    return titled.isEmpty ? roomFolder.replaceAll('_', ' ') : titled;
  }

  /// The take's length, and only when the store's row points at *this* file:
  /// one row spans several takes, so a length read off the row would put the
  /// last session's clock on an earlier one.
  Duration? get duration {
    final task = this.task;
    final file = filePath;
    if (task == null || file == null || task.durationMs <= 0) return null;
    if (!taskOwnsFile(task, file)) return null;
    return Duration(milliseconds: task.durationMs);
  }
}

/// Whether [task]'s stored path names [file] — as a joined file, or as the
/// take folder the row still points at before the join wrote one.
bool taskOwnsFile(RecordingTask task, String file) {
  final stored = (task.filePath ?? '').trim();
  if (stored.isEmpty) return false;
  if (p.equals(stored, file)) return true;
  return p.isWithin(stored, file);
}

/// The library: every take the recording folder holds, newest first.
///
/// The walk is depth-bounded to the recorder's own shape (`day/platform/room/
/// take`) with one fallback pass, so a stray folder of segments or a hand-
/// dropped clip still shows up instead of being silently skipped.
final recordingLibraryProvider = AsyncNotifierProvider<RecordingLibraryController, List<RecordingTake>>(
  RecordingLibraryController.new,
);

/// The signal that says the tree is worth walking again: the tasks' ids, states
/// and join flags, with nothing that ticks during a session — no bytes, no
/// progress — in it. A room going from 录制中 to 已保存 changes it; a second of
/// capture does not.
final recordingSettledSignalProvider = Provider<String>((ref) {
  final tasks = ref.watch(recordingTasksProvider).tasks;
  return [for (final task in tasks) '${task.id}:${task.state.name}:${task.postProcessing}'].join('|');
});

/// Owns the scan and its refresh; the page never touches `dart:io`.
final class RecordingLibraryController extends AsyncNotifier<List<RecordingTake>> {
  @override
  Future<List<RecordingTake>> build() {
    // The tree is re-read when a task settles — see [recordingSettledSignal] —
    // so a take that just finished arrives without the viewer pressing refresh,
    // and a capture ticking its bytes every second does not re-scan the disk.
    ref.watch(recordingSettledSignalProvider);
    return _scan();
  }

  /// Reads the tree again — after a take finished, moved or was deleted.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_scan);
  }

  /// Deletes one take: the folder the recorder made, with its joined file, its
  /// segments and its chat log. A take that is still being written or joined is
  /// refused rather than pulled out from under the engine, and the answer says
  /// whether the caller may count the row as gone.
  Future<bool> deleteTake(RecordingTake take) async {
    final task = take.task;
    if (task != null && (task.state == RecordingTaskState.recording || task.postProcessing)) return false;
    if (!await _deletePath(take.folder)) {
      final file = take.filePath;
      // A hand-dropped clip under the root is a file, not a take folder.
      if (file == null || !await _deletePath(file)) return false;
    }
    await refresh();
    return true;
  }

  Future<bool> _deletePath(String path) async {
    try {
      final type = FileSystemEntity.typeSync(path);
      if (type == FileSystemEntityType.directory) {
        await Directory(path).delete(recursive: true);
        return true;
      }
      if (type != FileSystemEntityType.file) return false;
      await File(path).delete();
      return true;
    } on Object {
      return false;
    }
  }

  Future<List<RecordingTake>> _scan() async {
    final root = ref.read(appPathsProvider).recordings;
    if (!root.existsSync()) return const [];
    // The store's rows, indexed by the folder names they would have produced,
    // so a take finds its row without a second read of the store.
    final tasks = ref.read(recordingTasksProvider).tasks;
    final byFolderKey = {
      for (final task in tasks)
        _folderKey(
          FfmpegRecordArguments.safeFilePrefix(task.platform),
          FfmpegRecordArguments.safeFilePrefix(task.roomId),
        ): task,
    };
    final takes = <RecordingTake>[];
    // A day holds platforms, a platform holds rooms, a room holds takes.
    Future<void> walkDay(Directory dayFolder, String dayName) async {
      await for (final platformEntry in dayFolder.list(followLinks: false)) {
        if (platformEntry is! Directory) continue;
        final platformFolder = p.basename(platformEntry.path);
        await for (final roomEntry in platformEntry.list(followLinks: false)) {
          if (roomEntry is! Directory) continue;
          await _collectTakes(
            roomEntry,
            day: dayName,
            platformFolder: platformFolder,
            roomFolder: p.basename(roomEntry.path),
            byFolderKey: byFolderKey,
            takes: takes,
          );
        }
      }
    }

    await for (final entry in root.list(followLinks: false)) {
      if (entry is! Directory) continue;
      final name = p.basename(entry.path);
      if (name == _kManagedRootMarker) continue;
      // The recorder's tree today: a kind (`live` / `iptv`) holds the days,
      // then platforms, rooms and takes. The older flat tree started at the
      // day; both are read, so nothing already filed disappears from the
      // list after the split. Anything else under the root is walked as one
      // folder of takes instead of being dropped.
      if (_isKindFolder(name)) {
        await for (final dayEntry in entry.list(followLinks: false)) {
          if (dayEntry is! Directory) continue;
          final dayName = p.basename(dayEntry.path);
          if (_isDayFolder(dayName)) await walkDay(dayEntry, dayName);
        }
      } else if (_isDayFolder(name)) {
        await walkDay(entry, name);
      } else {
        await _collectTakes(
          entry,
          day: '',
          platformFolder: '',
          roomFolder: name,
          byFolderKey: byFolderKey,
          takes: takes,
        );
      }
    }
    takes.sort((a, b) => b.takenAt.compareTo(a.takenAt));
    return List.unmodifiable(takes);
  }

  /// Gathers the takes inside [folder]: every playable file it holds, and every
  /// child folder that holds one (the recorder's take is a folder of segments
  /// until the join writes a single file). A folder with nothing playable — an
  /// `original/` archive, a half-made directory — stays out of the list.
  Future<void> _collectTakes(
    Directory folder, {
    required String day,
    required String platformFolder,
    required String roomFolder,
    required Map<String, RecordingTask> byFolderKey,
    required List<RecordingTake> takes,
  }) async {
    final direct = _playableFileOf(folder);
    if (direct != null) {
      _add(
        takes,
        folder,
        direct,
        day: day,
        platformFolder: platformFolder,
        roomFolder: roomFolder,
        byFolderKey: byFolderKey,
      );
      return;
    }
    await for (final entry in folder.list(followLinks: false)) {
      if (entry is! Directory) continue;
      if (p.basename(entry.path).toLowerCase() == 'original') continue;
      final file = _playableFileOf(entry);
      if (file == null) continue;
      _add(
        takes,
        entry,
        file,
        day: day,
        platformFolder: platformFolder,
        roomFolder: roomFolder,
        byFolderKey: byFolderKey,
      );
    }
  }

  void _add(
    List<RecordingTake> takes,
    Directory takeFolder,
    File file, {
    required String day,
    required String platformFolder,
    required String roomFolder,
    required Map<String, RecordingTask> byFolderKey,
  }) {
    final FileStat stamp;
    try {
      stamp = file.statSync();
    } on Object {
      return;
    }
    final task = byFolderKey[_folderKey(platformFolder, roomFolder)];
    takes.add(
      RecordingTake(
        folder: takeFolder.path,
        day: day.isEmpty ? _dayOf(stamp.modified) : day,
        platformFolder: platformFolder,
        roomFolder: roomFolder,
        name: p.basename(takeFolder.path),
        filePath: file.path,
        bytes: stamp.size,
        takenAt: stamp.modified,
        task: task,
      ),
    );
  }

  /// The file a player opens inside [folder], mirroring what the task's own
  /// path resolves to: the finished MP4 first, the largest segment otherwise.
  File? _playableFileOf(Directory folder) {
    final path = playableFileAt(folder.path);
    if (path == null) return null;
    final file = File(path);
    return file.existsSync() ? file : null;
  }
}

/// The store's index key for a folder pair; an empty platform or room folder is
/// what a take outside the recorder's tree reports.
String _folderKey(String platformFolder, String roomFolder) => '$platformFolder/$roomFolder';

/// Whether [name] is one of the recorder's day folders.
bool _isDayFolder(String name) => RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(name);

/// Whether [name] is one of the two kind folders the recorder files under.
bool _isKindFolder(String name) => name == kLiveRecordingKind || name == kIptvRecordingKind;

/// A day stamp for media the tree did not file by day.
String _dayOf(DateTime moment) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${moment.year}-${two(moment.month)}-${two(moment.day)}';
}

/// A folder name shaped like a day, for the labels that read one back — a
/// breadcrumb or a crumb knows only the name, not a whole take.
RecordingTake recordingTakeOfDay(String day) => RecordingTake(
  folder: day,
  day: day,
  platformFolder: '',
  roomFolder: '',
  name: day,
  filePath: null,
  bytes: 0,
  takenAt: DateTime(1970),
);

/// The levels the library drills through: the tree's own folders, then the
/// takes inside one room.
enum RecordingBrowseLevel { day, platform, room, take }

/// One row of the drill-down: a folder with what it holds, or a single take.
final class RecordingEntry {
  const RecordingEntry({
    required this.label,
    required this.sublabel,
    required this.bytes,
    required this.takenAt,
    required this.takeCount,
    required this.playableCount,
    required this.level,
    required this.segments,
    this.take,
    this.task,
    this.groupKey = '',
  });

  /// What the row names: a day, a platform, a room's title, or a take's file.
  final String label;

  /// The line under it: how many sit inside, or what the row belongs to.
  final String sublabel;

  final int bytes;
  final DateTime? takenAt;

  /// How many takes sit under this folder; one for a take row.
  final int takeCount;

  /// How many of those can be played.
  final int playableCount;

  /// What the row stands for, which says whether pressing it drills down or
  /// opens the file.
  final RecordingBrowseLevel level;

  /// The folder path this row gathered, as the drill-down wants it: a day, then
  /// a platform folder, then a room folder. Pressing the row appends these and
  /// lands inside it, so no caller has to split a key back apart.
  final List<String> segments;

  /// The take itself, at the leaf level.
  final RecordingTake? take;

  /// The task behind the row, when the store has exactly one for the folder.
  final RecordingTask? task;

  /// The folder this row gathers, so the page can walk back into it.
  final String groupKey;

  /// Whether the row opens something rather than drilling down.
  bool get isLeaf => level == RecordingBrowseLevel.take;

  /// Whether nothing under the row plays — the honest state of a take whose
  /// files were deleted but whose row remains, and of a room recorded so
  /// recently that nothing was written yet.
  bool get unplayable => playableCount == 0;
}

/// Gathers [takes] into the rows of [level].
///
/// Searching and filtering happen before this, so every count a row prints is a
/// count of what the viewer is being shown, not of the folder on disk.
List<RecordingEntry> recordingEntriesFor(
  List<RecordingTake> takes,
  RecordingBrowseLevel level, {
  required String Function(RecordingTake take) platformLabel,
  required String Function(String day) dayTitle,
}) {
  // Keyed by the tree's own folder names, never by the words a day is shown as:
  // a row's "open the folder" and its drill-down both hand these parts back to
  // takesUnder, and 今天 is not a directory.
  String keyOf(RecordingTake take) => switch (level) {
    RecordingBrowseLevel.day => take.day,
    RecordingBrowseLevel.platform => '${take.day}|${take.platformFolder}',
    RecordingBrowseLevel.room => '${take.day}|${take.platformFolder}|${take.roomFolder}',
    RecordingBrowseLevel.take => take.folder,
  };
  final grouped = <String, List<RecordingTake>>{};
  for (final take in takes) {
    grouped.putIfAbsent(keyOf(take), () => <RecordingTake>[]).add(take);
  }
  final entries = <RecordingEntry>[];
  for (final entry in grouped.entries) {
    final group = entry.value;
    final first = group.first;
    final bytes = group.fold(0, (total, take) => total + take.bytes);
    final playable = group.where((take) => take.playable).length;
    DateTime? newest;
    for (final take in group) {
      if (newest == null || take.takenAt.isAfter(newest)) newest = take.takenAt;
    }
    final roomCount = group.map((t) => t.roomFolder).toSet().length;
    final platformCount = group.map((t) => t.platformFolder).toSet().length;
    final tasks = {
      for (final take in group)
        if (take.task != null) take.task!.id,
    };
    final segments = switch (level) {
      RecordingBrowseLevel.day => [first.day],
      RecordingBrowseLevel.platform => [first.day, first.platformFolder],
      RecordingBrowseLevel.room => [first.day, first.platformFolder, first.roomFolder],
      RecordingBrowseLevel.take => [first.day, first.platformFolder, first.roomFolder, first.name],
    };
    entries.add(
      RecordingEntry(
        label: switch (level) {
          RecordingBrowseLevel.day => dayTitle(first.day),
          RecordingBrowseLevel.platform => platformLabel(first),
          RecordingBrowseLevel.room => first.roomTitle,
          RecordingBrowseLevel.take => first.playable ? p.basename(first.filePath!) : first.name,
        },
        sublabel: switch (level) {
          // A folder says what is inside it; a take says what it belongs to,
          // because its own name is already the label.
          RecordingBrowseLevel.day => platformCount > 1 ? '$platformCount · $roomCount' : '$roomCount',
          RecordingBrowseLevel.platform => '$roomCount',
          RecordingBrowseLevel.room => '$playable',
          RecordingBrowseLevel.take => first.roomTitle,
        },
        bytes: bytes,
        takenAt: newest,
        takeCount: group.length,
        playableCount: playable,
        level: level,
        segments: segments,
        take: level == RecordingBrowseLevel.take ? first : null,
        task: level == RecordingBrowseLevel.take ? first.task : (tasks.length == 1 ? first.task : null),
        groupKey: entry.key,
      ),
    );
  }
  entries.sort((a, b) => (b.takenAt ?? DateTime(1970)).compareTo(a.takenAt ?? DateTime(1970)));
  return entries;
}

/// The takes under one drilled path — `day`, then `day/platform`, then
/// `day/platform/room`, then a single take's own folder. An empty path is the
/// whole library, which is what the root of the breadcrumb shows.
List<RecordingTake> takesUnder(List<RecordingTake> takes, List<String> path) {
  if (path.isEmpty) return takes;
  bool matches(RecordingTake take) {
    for (var level = 0; level < path.length; level++) {
      final part = switch (level) {
        0 => take.day,
        1 => take.platformFolder,
        2 => take.roomFolder,
        _ => take.name,
      };
      if (part != path[level]) return false;
    }
    return true;
  }

  return [
    for (final take in takes)
      if (matches(take)) take,
  ];
}
