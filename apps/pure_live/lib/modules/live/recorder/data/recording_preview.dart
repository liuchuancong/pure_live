import 'dart:io' show Directory, File, FileSystemEntity, FileSystemEntityType;

import 'package:path/path.dart' as p;

import 'package:pure_live/features/media_preview/media_preview_item.dart' show MediaPreviewItem;
import 'package:pure_live/modules/live/recorder/data/recording_task.dart' show RecordingTask, RecordingTaskState;
import 'package:pure_live/shared/widgets/download_format.dart' show formatDownloadBytes;

/// What a take can offer a player, best first.
///
/// A finished take is one MP4; a take whose join never ran is its segments;
/// a take kept for low disk is a folder of them. The preview only cares that
/// something in there plays, so it takes the finished MP4 when the folder
/// holds one, the largest segment otherwise, and leaves the rest to the list.
const Set<String> _playableExtensions = {
  '.mp4',
  '.mkv',
  '.mov',
  '.m4v',
  '.webm',
  '.flv',
  '.ts',
  '.mp3',
  '.m4a',
  '.aac',
  '.flac',
  '.wav',
  '.ogg',
  '.opus',
};

/// The file a stored take path plays, or null when it holds none.
///
/// [storedPath] is what a task keeps in `filePath`: the final file once the
/// take is joined, the take's folder while it is being written or when the
/// join was turned off. The folder's `original/` archive is deliberately not
/// searched — it holds the segments the joined file was made from.
String? playableFileAt(String? storedPath) {
  final path = (storedPath ?? '').trim();
  if (path.isEmpty) return null;
  final FileSystemEntityType type;
  try {
    type = FileSystemEntity.typeSync(path);
  } on Object {
    return null;
  }
  if (type == FileSystemEntityType.file) {
    return _isPlayable(path) ? path : null;
  }
  if (type != FileSystemEntityType.directory) return null;
  String? best;
  var bestRank = -1;
  var bestBytes = 0;
  try {
    for (final entity in Directory(path).listSync(followLinks: false)) {
      if (entity is! File || !_isPlayable(entity.path)) continue;
      final bytes = entity.statSync().size;
      if (bytes <= 0) continue;
      // An MP4 is what this app writes when the join succeeds, so it is the
      // take's picture even when a leftover segment happens to be bigger.
      final rank = _isMp4(entity.path) ? 1 : 0;
      if (rank < bestRank || (rank == bestRank && bytes <= bestBytes)) continue;
      best = entity.path;
      bestRank = rank;
      bestBytes = bytes;
    }
  } on Object {
    return best;
  }
  return best;
}

/// Whether [path] carries an extension a player can open.
bool _isPlayable(String path) {
  final dot = _lastDot(path);
  return dot >= 0 && _playableExtensions.contains(path.substring(dot).toLowerCase());
}

/// Whether [path] names the joined/transcoded picture.
bool _isMp4(String path) => path.toLowerCase().endsWith('.mp4');

/// Where the extension starts, or -1 when the name has none.
int _lastDot(String path) {
  final name = path.replaceAll(r'\', '/');
  final slash = name.lastIndexOf('/');
  final dot = name.lastIndexOf('.');
  return dot <= slash ? -1 : dot;
}

/// The takes a preview can play, in the store's own order: a settled task
/// whose file — or whose folder of segments — still holds something a player
/// opens. A running capture and a take still being joined are not a recording
/// yet, so they stay out of the list.
///
/// [platformName] says each task's platform in the viewer's language; leaving
/// it out is what a page that lists one platform's takes wants, where the
/// fact would repeat itself on every line.
List<MediaPreviewItem> recordingPreviewItems(
  Iterable<RecordingTask> tasks, {
  String Function(RecordingTask task)? platformName,
}) {
  final items = <MediaPreviewItem>[];
  for (final task in tasks) {
    if (task.state == RecordingTaskState.recording || task.postProcessing) continue;
    final file = playableFileAt(task.filePath);
    if (file == null) continue;
    final room = task.roomTitle.trim();
    items.add(
      MediaPreviewItem(
        id: task.id,
        title: room.isEmpty ? p.basename(file) : room,
        path: file,
        subtitle: [
          if (platformName != null) platformName(task),
          if (task.durationMs > 0) formatRecordingDuration(Duration(milliseconds: task.durationMs)),
          if (task.bytes > 0) formatRecordingBytes(task.bytes),
          formatRecordingMoment(task.startedAt),
        ].join(' · '),
      ),
    );
  }
  return items;
}

/// Renders a bytes figure the way a file manager would.
///
/// The shared download formatter is the one implementation; this name stays
/// because the recording rows, the library and the player's captions all read
/// their sizes through it.
String formatRecordingBytes(int bytes) => formatDownloadBytes(bytes);

/// A capture length as a player shows it: minutes and seconds, hours only
/// when the take has them.
String formatRecordingDuration(Duration duration) {
  String two(int value) => value.toString().padLeft(2, '0');
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  final seconds = duration.inSeconds % 60;
  return hours > 0 ? '$hours:${two(minutes)}:${two(seconds)}' : '${two(minutes)}:${two(seconds)}';
}

/// A local moment for a task list row: the clock on today's entries, a
/// short date with the clock otherwise.
String formatRecordingMoment(DateTime utc) {
  String two(int value) => value.toString().padLeft(2, '0');
  final local = utc.toLocal();
  final now = DateTime.now();
  final sameDay = local.year == now.year && local.month == now.month && local.day == now.day;
  final clock = '${two(local.hour)}:${two(local.minute)}';
  return sameDay ? clock : '${two(local.month)}-${two(local.day)} $clock';
}
