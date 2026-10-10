// Module: test/support/backup_fakes.dart
// Purpose: The in-process transports, sources and targets the backup tests run against.
// Author: liuchuancong
// Created: 2026-10-10
//
// Shared by the service and document suites: one fake remote plus a couple of throwaway domain adapters are
// enough to exercise every branch, and duplicating them per file is how a test ends up asserting on its own
// fake instead of on the code under test.

import 'package:pure_live_backup/pure_live_backup.dart';
import 'package:pure_live_backup_feature/pure_live_backup_feature.dart';

/// A [SnapshotRemote] that keeps archives in memory and can be told to fail one operation.
final class InMemoryRemote implements SnapshotRemote {
  final Map<String, Map<String, Object?>> files = <String, Map<String, Object?>>{};
  final List<SnapshotListing> listings = <SnapshotListing>[];

  /// Thrown by the next [upload], once.
  Object? failNextUpload;

  /// Thrown by the next [download], once.
  Object? failNextDownload;

  int uploadCount = 0;

  @override
  Future<void> upload(String name, Map<String, Object?> document) async {
    final failure = failNextUpload;
    if (failure != null) {
      failNextUpload = null;
      throw failure;
    }
    uploadCount++;
    files[name] = document;
    listings.removeWhere((entry) => entry.name == name);
    listings.add(SnapshotListing(name: name, sizeBytes: 128, modifiedAt: DateTime.utc(2026, 10, 10, uploadCount)));
  }

  @override
  Future<Map<String, Object?>> download(String name) async {
    final failure = failNextDownload;
    if (failure != null) {
      failNextDownload = null;
      throw failure;
    }
    final file = files[name];
    if (file == null) {
      throw StateError('no such snapshot: $name');
    }
    return file;
  }

  @override
  Future<List<SnapshotListing>> list() async => List<SnapshotListing>.of(listings);
}

/// One settings domain written into an archive.
final class FakeSource implements DomainSource {
  FakeSource(this.name, this.values);

  @override
  final String name;

  final Map<String, Object?> values;

  @override
  Future<Map<String, Object?>> snapshot() async => Map<String, Object?>.of(values);
}

/// One domain read back out, with a switch to make it fail.
final class FakeTarget implements DomainTarget {
  FakeTarget(this.name, {this.failOnce = false});

  @override
  final String name;

  /// True when the first [restore] call should throw, to exercise the per-domain failure record.
  bool failOnce;

  final List<Map<String, Object?>> restored = <Map<String, Object?>>[];

  @override
  Future<void> restore(Map<String, Object?> values) async {
    if (failOnce) {
      failOnce = false;
      throw StateError('$name refused the restore');
    }
    restored.add(Map<String, Object?>.of(values));
  }
}

/// The credential rule both suites use: any key the auth package would own.
bool fakeIsCredentialKey(String key) => key.startsWith('auth.');
