import 'dart:io' show Directory, File, FileMode, FileSystemException, RandomAccessFile;

import 'package:path/path.dart' as p;

/// The file a take's post-processing holds while it joins, transcodes or
/// renames.
///
/// The lock is what makes the status cross-window: a take whose task says
/// `postProcessing` but whose lock can be acquired belongs to a process that
/// died, while a lock held by another window means its work is still real.
const String kFinalizeLockName = '.pure_live_finalizing.lock';

/// Takes an exclusive lock on [root]'s finalize marker.
///
/// Returns null when another process holds the lock. The handle must be kept
/// open until [releaseFinalizeLock]; the marker is removed when it closes.
Future<RandomAccessFile?> acquireFinalizeLock(Directory root) async {
  try {
    await root.create(recursive: true);
    final file = File(p.join(root.path, kFinalizeLockName));
    final handle = await file.open(mode: FileMode.append);
    try {
      await handle.lock();
    } on Object {
      await handle.close();
      return null;
    }
    await handle.setPosition(0);
    await handle.truncate(0);
    await handle.writeString('${DateTime.now().toUtc().toIso8601String()}\n');
    await handle.flush();
    return handle;
  } on FileSystemException {
    return null;
  }
}

/// Releases [handle] and removes the marker under [root].
Future<void> releaseFinalizeLock(RandomAccessFile? handle, Directory root) async {
  if (handle != null) {
    try {
      await handle.unlock();
    } on Object {
      // The process is ending; the OS releases the lock anyway.
    }
    try {
      await handle.close();
    } on Object {
      // A handle that cannot close owns nothing else.
    }
  }
  try {
    final marker = File(p.join(root.path, kFinalizeLockName));
    if (marker.existsSync()) marker.deleteSync();
  } on FileSystemException {
    // A marker that cannot be removed is retried by stale recovery.
  }
}

/// Whether another process holds [root]'s finalize lock.
///
/// The probe takes the lock and immediately releases it: success means no one
/// else is working, so a task still marked processing is stale. A missing
/// marker is also "not held"; an unreadable one is treated as held, because
/// the safe mistake is leaving a status alone.
Future<bool> hasLiveFinalizeLock(Directory root) async {
  final marker = File(p.join(root.path, kFinalizeLockName));
  if (!marker.existsSync()) return false;
  RandomAccessFile? handle;
  var acquired = false;
  try {
    handle = await marker.open(mode: FileMode.append);
    await handle.lock();
    acquired = true;
    return false;
  } on Object {
    return true;
  } finally {
    if (handle != null) {
      try {
        await handle.unlock();
      } on Object {
        // Not held by this probe.
      }
      try {
        await handle.close();
      } on Object {
        // Closing a probe that never locked is harmless.
      }
    }
    if (acquired) {
      try {
        if (marker.existsSync()) marker.deleteSync();
      } on FileSystemException {
        // The stale marker stays for the next probe; the status is already clear.
      }
    }
  }
}
