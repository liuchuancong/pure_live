// Module: lib/src/disk_tier.dart
// Purpose: The persistent cache tier: byte entries on disk with ttl and
// LRU-by-mtime eviction, plus the two-level cache that fronts memory with it.
// Author: liuchuancong
// Created: 2026-10-09
//
// docs/services/cache.md: one directory per namespace, keys never appear in
// file names (they are hashed), expiry lives in the file so a restart inherits
// it, and eviction is file mtime - which makes recency survive restarts too.

import 'dart:convert';
import 'dart:io';

import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:pure_live_utils/pure_live_utils.dart';

import 'store.dart';

/// One namespace's persistent tier.
final class DiskCacheTier {
  DiskCacheTier({
    required Directory directory,
    this.maxBytes = 128 * 1024 * 1024,
    this.ttl = const Duration(days: 14),
    Clock? clock,
  }) : _directory = directory,
       _clock = clock ?? systemClock;

  final Directory _directory;
  final int maxBytes;
  final Duration ttl;
  final Clock _clock;

  /// The stored bytes for [key], or null when absent, expired, or unreadable.
  /// A corrupt entry is treated as a miss and deleted: a cache that throws on
  /// its own damage is a liability, not a cache.
  Future<Uint8List?> read(String key) async {
    final file = _fileFor(key);
    if (!await file.exists()) {
      return null;
    }
    Uint8List raw;
    try {
      raw = await file.readAsBytes();
    } on FileSystemException {
      return null;
    }
    if (raw.length < 8) {
      await _deleteQuietly(file);
      return null;
    }
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(ByteData.view(raw.buffer, 0, 8).getInt64(0), isUtc: true);
    if (!_clock().toUtc().isBefore(expiresAt)) {
      await _deleteQuietly(file);
      return null;
    }
    // Touch = LRU stamp survives restarts, because eviction orders on mtime.
    await file.setLastModified(_clock());
    return Uint8List.sublistView(raw, 8);
  }

  Future<void> write(String key, List<int> bytes) async {
    await _directory.create(recursive: true);
    final file = _fileFor(key);
    final header = ByteData(8);
    final expiresAt = _clock().toUtc().add(ttl).millisecondsSinceEpoch;
    header.setInt64(0, expiresAt, Endian.little);
    final payload = <int>[...header.buffer.asUint8List(), ...bytes];
    // Write-then-rename: a crash mid-write leaves the temp file, never a
    // half-valid entry under the real name.
    final temp = File('${file.path}.tmp');
    await temp.writeAsBytes(payload, flush: true);
    try {
      await temp.rename(file.path);
    } on FileSystemException {
      await _deleteQuietly(temp);
    }
    await enforceLimit();
  }

  /// Deletes oldest files until the tier fits [maxBytes]. Returns the count
  /// evicted.
  Future<int> enforceLimit() async {
    if (!await _directory.exists()) {
      return 0;
    }
    final files = <File>[];
    var total = 0;
    await for (final entity in _directory.list()) {
      if (entity is File && !entity.path.endsWith('.tmp')) {
        files.add(entity);
        total += await entity.length();
      }
    }
    var evicted = 0;
    if (total <= maxBytes) {
      return evicted;
    }
    final byAge = <(File, DateTime)>[];
    for (final file in files) {
      try {
        byAge.add((file, await file.lastModified()));
      } on FileSystemException {
        // gone already
      }
    }
    byAge.sort((a, b) => a.$2.compareTo(b.$2));
    for (final (file, _) in byAge) {
      if (total <= maxBytes) {
        break;
      }
      final length = await file.length();
      await _deleteQuietly(file);
      total -= length;
      evicted++;
    }
    return evicted;
  }

  Future<void> clear() async {
    if (await _directory.exists()) {
      await _directory.delete(recursive: true);
    }
  }

  Future<void> delete(String key) => _deleteQuietly(_fileFor(key));

  File _fileFor(String key) {
    final digest = sha256.convert(utf8.encode(key)).toString();
    return File(p.join(_directory.path, '$digest.cache'));
  }

  Future<void> _deleteQuietly(File file) async {
    try {
      await file.delete();
    } on FileSystemException {
      // already gone
    }
  }
}

/// Memory front, disk behind. Values are bytes: this is the tier for images,
/// api payloads and media blobs - object graphs stay in the memory tier.
final class TwoLevelCache {
  TwoLevelCache({required this.memory, required this.disk});

  final NamespaceCache memory;
  final DiskCacheTier disk;

  Future<Uint8List?> readBytes(String key) async {
    final inMemory = memory.read(key);
    if (inMemory is Uint8List) {
      return inMemory;
    }
    final fromDisk = await disk.read(key);
    if (fromDisk == null) {
      return null;
    }
    // Promote with the byte cost the memory policy enforces on.
    memory.write(key, fromDisk, bytes: fromDisk.length);
    return fromDisk;
  }

  Future<void> writeBytes(String key, List<int> bytes) async {
    final asBytes = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    memory.write(key, asBytes, bytes: asBytes.length);
    await disk.write(key, asBytes);
  }

  Future<void> remove(String key) async {
    memory.remove(key);
    await disk.delete(key);
  }

  Future<void> clear() async {
    memory.clear();
    await disk.clear();
  }
}
