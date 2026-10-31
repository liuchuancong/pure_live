import 'dart:io' show Directory, File, FileSystemException;

import 'package:path/path.dart' as p;

// The file half of "bring a take home": measuring a folder, copying one to a
// new home and checking the copy, and reading a task's path after the move.
// The engine owns the decisions around them (which takes move, the rename
// attempt, the store write); everything here is a plain filesystem statement so
// it can be exercised without starting a recording.

/// The bytes every file under [folder] holds, summed.
///
/// [exclude] names files that are the app's own bookkeeping rather than take
/// content — the managed recording root carries one, a take never does.
Future<int> folderBytes(Directory folder, {Set<String> exclude = const {}}) async {
  var total = 0;
  try {
    await for (final entity in folder.list(recursive: true, followLinks: false)) {
      if (entity is! File || exclude.contains(p.basename(entity.path))) continue;
      try {
        total += await entity.length();
      } on FileSystemException {
        // A file that vanished mid-walk is simply not counted.
      }
    }
  } on FileSystemException {
    // A folder that cannot be read holds nothing this caller can trust.
  }
  return total;
}

/// Copies [source] into [destination] and measures the result against it: the
/// same files, the same total.
///
/// False means the copy cannot be trusted and the source must stay the take —
/// which also answers a cancellation, whose half copy the caller discards. The
/// last statement is the total, not just per-file lengths: a destination that
/// already held something would otherwise pass a file-by-file check.
Future<bool> copyTakeVerified(Directory source, Directory destination, {bool Function()? cancelled}) async {
  try {
    await destination.create(recursive: true);
    await for (final entity in source.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      if (cancelled?.call() ?? false) return false;
      final target = File(p.join(destination.path, p.relative(entity.path, from: source.path)));
      await target.parent.create(recursive: true);
      final copied = await entity.copy(target.path);
      if (await copied.length() != await entity.length()) return false;
    }
  } on Object {
    return false;
  }
  return await folderBytes(source) == await folderBytes(destination);
}

/// The path a task should carry once its take folder moved from [from] to [to].
///
/// A row names either the folder itself or a file inside it, so the relative
/// part is what survives the move; a row naming something that was never in
/// [from] keeps its own file name beside the new folder rather than a `..`
/// walk out of it.
String rebaseTakePath(String stored, {required String from, required String to}) {
  final path = stored.trim();
  return switch (path) {
    '' => to,
    final String value when p.equals(value, from) => to,
    final String value when p.isWithin(from, value) => p.join(to, p.relative(value, from: from)),
    final String value => p.join(to, p.basename(value)),
  };
}
