import 'dart:io' show Directory, File, FileMode, RandomAccessFile;

import 'package:path/path.dart' as p;

/// The claim one process holds on a task while it captures it.
///
/// The engine's session table is per process, so two windows could otherwise
/// start the same room at once: two takes, two directories, and two processes
/// writing the same task row. A claim is the smallest thing that makes the
/// answer shared — a lock the operating system holds for as long as the process
/// lives, so a crash releases it instead of leaving a stale "recording" flag
/// behind.
///
/// The file is named after the task id, which is `platform:roomId`; a colon is
/// not a file name on Windows, so the id is reduced to characters every
/// platform accepts. Two different ids can therefore collide in theory; the
/// claim is a collision detector, not an identity, and a false "busy" is the
/// safe direction.

/// The file name a task's claim is held under.
String recordingClaimName(String taskId) {
  final safe = taskId.replaceAll(RegExp('[^A-Za-z0-9._-]'), '_');
  return '${safe.isEmpty ? 'task' : safe}.claim';
}

/// Claims [taskId] inside [folder] for this process; null when it cannot be
/// held — another window has it, or the claim folder is not writable.
///
/// The handle must be kept open until [releaseRecordingClaim] — that is what
/// holds the lock — and is released by the system if the process ends without
/// calling it.
Future<RandomAccessFile?> acquireRecordingClaim(Directory folder, String taskId) async {
  try {
    await folder.create(recursive: true);
    final file = File(p.join(folder.path, recordingClaimName(taskId)));
    final handle = await file.open(mode: FileMode.append);
    try {
      await handle.lock();
    } on Object {
      await handle.close();
      return null;
    }
    return handle;
  } on Object {
    // A folder that cannot be written cannot prove this process is the only
    // one: refuse rather than risk two takes on one room.
    return null;
  }
}

/// Releases a claim; a null claim or an already-closed handle is a no-op.
Future<void> releaseRecordingClaim(RandomAccessFile? claim) async {
  if (claim == null) return;
  try {
    await claim.unlock();
  } on Object {
    // Already released with the handle.
  }
  try {
    await claim.close();
  } on Object {
    // A closed handle owns nothing.
  }
}
