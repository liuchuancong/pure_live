// Module: lib/src/atomic_file.dart
// Purpose: Crash-safe file writes and honest directory accounting.
// Author: liuchuancong
// Created: 2026-10-10
//
// Every persistent store in the app writes through this: write-then-rename
// means a crash mid-write leaves the previous content intact, and the temp
// suffix is skipped by directory scans that filter on the store suffix.

import 'dart:convert';
import 'dart:io';

Future<void> _deleteQuietly(File file) async {
  try {
    await file.delete();
  } on FileSystemException {
    // already gone
  }
}

/// Writes [content] to [file] atomically: bytes land in a sibling `.tmp` file
/// first, then rename over the target. On Windows a rename onto an existing
/// file throws, so the old file is removed first - the window without the
/// target file is a single syscall wide.
Future<void> writeAtomic(File file, List<int> content) async {
  await file.parent.create(recursive: true);
  final temp = File('${file.path}.tmp');
  await temp.writeAsBytes(content, flush: true);
  try {
    if (await file.exists()) {
      await file.delete();
    }
    await temp.rename(file.path);
  } on FileSystemException {
    await _deleteQuietly(temp);
    rethrow;
  }
}

/// Writes [text] as UTF-8 atomically.
Future<void> writeAtomicString(File file, String text) => writeAtomic(file, utf8.encode(text));

/// Reads a file as UTF-8 text, treating every failure (missing, unreadable,
/// undecodable) as empty: callers store recovery logic, not crash handling.
Future<String> readStringOrEmpty(File file) async {
  try {
    return await file.readAsString();
  } catch (_) {
    return '';
  }
}

/// The total size of a directory in bytes, following subdirectories. Missing
/// directories report zero.
Future<int> directorySize(Directory directory) async {
  if (!await directory.exists()) {
    return 0;
  }
  var total = 0;
  await for (final entity in directory.list(recursive: true, followLinks: false)) {
    if (entity is File) {
      try {
        total += await entity.length();
      } on FileSystemException {
        // deleted mid-walk
      }
    }
  }
  return total;
}
