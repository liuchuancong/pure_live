import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pure_live/recorder/services/cache_service.dart';
import 'package:pure_live/recorder/services/path_helper.dart';

void main() {
  late Directory sandbox;
  late Directory defaultDirectory;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('pure_live_recorder_policy_');
    defaultDirectory = Directory(p.join(sandbox.path, 'default_records'));
  });

  tearDown(() async {
    if (await sandbox.exists()) await sandbox.delete(recursive: true);
  });

  CacheService serviceFor(String? configuredPath) {
    return CacheService(
      configuredPathResolver: () => configuredPath,
      defaultDirectoryResolver: () async => defaultDirectory,
    );
  }

  test('default app recording directory remains the managed root', () async {
    final service = serviceFor(null);

    final directory = await service.getRecordDir();

    expect(p.equals(directory.path, defaultDirectory.path), isTrue);
    expect(File(p.join(directory.path, CacheService.ownershipMarkerName)).existsSync(), isTrue);
  });

  test('custom selection receives an isolated PureLiveRecords child', () async {
    final selectedParent = Directory(p.join(sandbox.path, 'Downloads'));
    final service = serviceFor(selectedParent.path);

    final directory = await service.getRecordDir();

    expect(p.equals(directory.path, p.join(selectedParent.path, CacheService.managedFolderName)), isTrue);
  });

  test('selecting the managed child does not create a duplicate nesting level', () async {
    final managed = await Directory(p.join(sandbox.path, CacheService.managedFolderName)).create(recursive: true);
    await File(p.join(managed.path, CacheService.ownershipMarkerName)).writeAsString('owned');
    final service = serviceFor(managed.path);

    final directory = await service.getRecordDir();

    expect(p.equals(directory.path, managed.path), isTrue);
  });

  test('an unmarked folder with the managed name is still treated as a parent', () async {
    final unmarked = await Directory(p.join(sandbox.path, CacheService.managedFolderName)).create(recursive: true);
    final unrelated = await File(p.join(unmarked.path, 'notes.txt')).writeAsString('keep');
    final service = serviceFor(unmarked.path);

    final directory = await service.getRecordDir();

    expect(p.equals(directory.path, p.join(unmarked.path, CacheService.managedFolderName)), isTrue);
    await service.clearAll();
    expect(await unrelated.exists(), isTrue);
  });

  test('clearAll preserves unrelated files next to the managed recording directory', () async {
    final selectedParent = await Directory(p.join(sandbox.path, 'Downloads')).create(recursive: true);
    final unrelated = await File(p.join(selectedParent.path, 'family-photo.jpg')).writeAsString('keep');
    final service = serviceFor(selectedParent.path);
    final managed = await service.getRecordDir();
    final nested = await Directory(p.join(managed.path, 'douyu', 'room')).create(recursive: true);
    final recording = await File(p.join(nested.path, 'segment.ts')).writeAsBytes(List<int>.filled(32, 1));

    await service.clearAll();

    expect(await unrelated.exists(), isTrue);
    expect(await recording.exists(), isFalse);
    expect(File(p.join(managed.path, CacheService.ownershipMarkerName)).existsSync(), isTrue);
  });

  test('recursive oldest deletion sees nested recording segments', () async {
    final service = serviceFor(null);
    final managed = await service.getRecordDir();
    final nested = await Directory(p.join(managed.path, 'bilibili', 'room')).create(recursive: true);
    final oldest = await File(p.join(nested.path, '001.ts')).writeAsBytes(List<int>.filled(1024, 1));
    final newest = await File(p.join(nested.path, '002.ts')).writeAsBytes(List<int>.filled(1024, 2));
    await oldest.setLastModified(DateTime(2024));
    await newest.setLastModified(DateTime(2025));

    expect(await service.deleteOldest(), isTrue);

    expect(await oldest.exists(), isFalse);
    expect(await newest.exists(), isTrue);
  });

  test('cache limit has bounded work for empty and nested directories', () async {
    final service = serviceFor(null);
    final managed = await service.getRecordDir();

    await service.enforceLimit(maxMB: 0).timeout(const Duration(seconds: 2));

    final nested = await Directory(p.join(managed.path, 'kuaishou', 'room')).create(recursive: true);
    final oldest = await File(p.join(nested.path, '001.ts')).writeAsBytes(List<int>.filled(2048, 1));
    final newest = await File(p.join(nested.path, '002.ts')).writeAsBytes(List<int>.filled(2048, 2));
    await oldest.setLastModified(DateTime(2024));
    await newest.setLastModified(DateTime(2025));

    await service.enforceLimit(maxMB: 0.002).timeout(const Duration(seconds: 2));

    expect(await oldest.exists(), isFalse);
    expect(await newest.exists(), isTrue);
  });

  test('room directory labels are portable even without pinyin mode', () async {
    final service = serviceFor(null);

    final directory = await service.getRoomDir(platform: 'douyu:/', nick: r'主播 <A>|CON?');

    final relative = p.relative(directory.path, from: (await service.getRecordDir()).path);
    expect(relative, isNot(contains(RegExp(r'[<>:"|?*]'))));
    expect(relative, contains('douyu_'));
    expect(relative, contains('主播_A_CON_'));
  });

  test('safe path components handle reserved names, empty labels and length', () {
    expect(PathHelper.toSafeComponent('CON'), '_CON');
    expect(PathHelper.toSafeComponent(' <>:"/\\|?* '), 'unknown');
    expect(PathHelper.toSafeComponent(List<String>.filled(100, 'a').join()).runes.length, 80);
    expect(PathHelper.toSafeComponent('anything', maxRunes: 0), 'unknown');
  });
}
