import 'dart:io';

import 'package:live_platform/live_platform.dart';
import 'package:live_platform_path_provider/live_platform_path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// `DefaultStorageManager` is the probe-and-fallback engine, so the cases
/// below pin its promises: only a real write wins, a winner is memoised, a
/// clearable area may degrade to the system temp while a persistent one fails
/// loudly, and probing leaves no trace of itself in the user's directories.
/// The degraded and probe names come off the snapshot's namespace (`unit_host`
/// here) — the manager owns no product name either. A candidate list fixed by
/// the test — the policy layer has its own suite.
final class _StaticPolicy implements StoragePolicy {
  const new(this.candidates);

  final List<Directory> candidates;

  @override
  List<Directory> candidatesFor(StorageArea area, PlatformRuntimeInfo runtime) => candidates;
}

void main() {
  const hostNamespace = 'unit_host';

  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('live_platform_manager');
  });

  tearDown(() {
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // A transient Windows lock; the temporary directory goes with the process.
    }
  });

  PlatformRuntimeInfo snapshot({String namespace = hostNamespace}) => PlatformRuntimeInfo(
    kind: PlatformKind.windows,
    formFactor: FormFactor.desktop,
    distribution: DesktopDistribution.installed,
    isPackaged: false,
    executableRoot: root,
    appNamespace: namespace,
  );

  /// A candidate whose path is occupied by a file, so `create` fails the way
  /// an unwritable directory does — without depending on host ACLs.
  Future<Directory> blockedCandidate(String name) async {
    final file = File('${root.path}/$name');
    await file.writeAsString('occupies the candidate path');
    return Directory(file.path);
  }

  List<String> probeStrays(Directory directory) => directory
      .listSync()
      .whereType<File>()
      .map((file) => file.uri.pathSegments.last)
      .where((name) => name.startsWith('.${DefaultStoragePolicy.probeBaseName(hostNamespace)}'))
      .toList();

  test('the first writable candidate wins and is then memoised', () async {
    final winner = Directory('${root.path}/winner');
    final manager = DefaultStorageManager(policy: _StaticPolicy([winner]), runtime: snapshot());

    final first = await manager.resolve(StorageArea.data);
    expect(first.path, winner.path);

    // The memoised answer survives even though the directory itself does not:
    // resolution happens once, `revalidate` is the way to re-probe.
    await winner.delete(recursive: true);
    final second = await manager.resolve(StorageArea.data);
    expect(second.path, winner.path);

    final fresh = await manager.revalidate(StorageArea.data);
    expect(fresh.path, winner.path, reason: 'revalidate recreates and re-probes the winner');
  });

  test('an unwritable candidate is skipped for the next one', () async {
    final blocked = await blockedCandidate('blocked');
    final good = Directory('${root.path}/good');
    final manager = DefaultStorageManager(policy: _StaticPolicy([blocked, good]), runtime: snapshot());

    final location = await manager.resolve(StorageArea.data);
    expect(location.path, good.path);
  });

  test('a persistent area fails loudly when every candidate fails', () async {
    final blocked = await blockedCandidate('blocked');
    final manager = DefaultStorageManager(policy: _StaticPolicy([blocked]), runtime: snapshot());

    await expectLater(manager.resolve(StorageArea.data), throwsA(isA<StorageUnavailableException>()));
  });

  test('a clearable area degrades to the system temp directory', () async {
    final blocked = await blockedCandidate('blocked');
    final systemTemp = Directory('${root.path}/system');
    final manager = DefaultStorageManager(
      policy: _StaticPolicy([blocked]),
      runtime: snapshot(),
      systemTemp: systemTemp,
    );

    final location = await manager.resolve(StorageArea.cache);
    expect(location.path, p.join(systemTemp.path, '${hostNamespace}_cache'));
    expect(location.isPersistent, isFalse);
  });

  test("the degraded names are the namespace's, taken from the snapshot", () async {
    final blocked = await blockedCandidate('blocked');
    final systemTemp = Directory('${root.path}/system');
    final otherHost = DefaultStorageManager(
      policy: _StaticPolicy([blocked]),
      runtime: snapshot(namespace: 'other_host'),
      systemTemp: systemTemp,
    );

    expect((await otherHost.resolve(StorageArea.cache)).path, p.join(systemTemp.path, 'other_host_cache'));
    expect((await otherHost.resolve(StorageArea.temporary)).path, p.join(systemTemp.path, 'other_host_temp'));

    final thisHost = DefaultStorageManager(
      policy: _StaticPolicy([blocked]),
      runtime: snapshot(),
      systemTemp: systemTemp,
    );
    expect((await thisHost.resolve(StorageArea.temporary)).path, p.join(systemTemp.path, '${hostNamespace}_temp'));
  });

  test('probing leaves no trace in the resolved directory', () async {
    final winner = Directory('${root.path}/winner');
    final manager = DefaultStorageManager(policy: _StaticPolicy([winner]), runtime: snapshot());

    await manager.resolve(StorageArea.data);
    await manager.revalidate(StorageArea.data);

    expect(probeStrays(winner), isEmpty);
  });

  test('concurrent resolutions do not fight over one probe file', () async {
    final winner = Directory('${root.path}/winner');
    final manager = DefaultStorageManager(policy: _StaticPolicy([winner]), runtime: snapshot());

    final locations = await Future.wait([
      manager.resolve(StorageArea.data),
      manager.resolve(StorageArea.data),
      manager.resolve(StorageArea.cache),
    ]);

    for (final location in locations) {
      expect(location.accessState, AccessState.writable);
    }
    expect(probeStrays(winner), isEmpty);
  });
}
