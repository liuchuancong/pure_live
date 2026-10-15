import 'dart:io';

import 'package:live_platform/live_platform.dart';
import 'package:live_platform_path_provider/live_platform_path_provider.dart';
import 'package:test/test.dart';

/// `DefaultStoragePolicy` is the deployment ruleset in directory form. The
/// cases below pin the rule that gives the portable distribution its
/// meaning: a portable build's persistent candidates never include the OS
/// application directories — its data follows the executable or nowhere —
/// while an installed build never sees the executable's directory either.
void main() {
  final exeRoot = Directory('/app/bin');
  final userRoot = Directory('/users/x/appdata');
  final cacheRoot = Directory('/users/x/cache');
  final tempRoot = Directory('/tmp');
  final downloadsRoot = Directory('/users/x/downloads');

  PlatformRuntimeInfo snapshot({required bool portable}) => PlatformRuntimeInfo(
    kind: PlatformKind.windows,
    formFactor: FormFactor.desktop,
    distribution: portable ? DesktopDistribution.portable : DesktopDistribution.installed,
    isPackaged: false,
    executableRoot: exeRoot,
  );

  List<String> paths(List<Directory> candidates) => candidates.map((directory) => directory.path).toList();

  test('a portable build never resolves persistent data into the OS directories', () {
    final policy = DefaultStoragePolicy(portableRoot: exeRoot, userRoot: userRoot, cacheRoot: cacheRoot);

    for (final area in StorageArea.values) {
      for (final candidate in policy.candidatesFor(area, snapshot(portable: true))) {
        expect(candidate.path, isNot(startsWith(userRoot.path)), reason: '$area');
        expect(candidate.path, isNot(startsWith(cacheRoot.path)), reason: '$area');
      }
    }
  });

  test('an installed build never sees the executable directory', () {
    final policy = DefaultStoragePolicy(portableRoot: exeRoot, userRoot: userRoot);

    for (final area in StorageArea.values) {
      for (final candidate in policy.candidatesFor(area, snapshot(portable: false))) {
        expect(candidate.path, isNot(startsWith(exeRoot.path)), reason: '$area');
      }
    }
  });

  test('a portable layout puts the area tree under the executable', () {
    final policy = DefaultStoragePolicy(portableRoot: exeRoot, userRoot: userRoot);

    expect(paths(policy.candidatesFor(StorageArea.data, snapshot(portable: true))), ['${exeRoot.path}/data']);
    expect(paths(policy.candidatesFor(StorageArea.exports, snapshot(portable: true))), ['${exeRoot.path}/exports']);
  });

  test('an installed layout keeps data in the OS directories', () {
    final policy = DefaultStoragePolicy(portableRoot: exeRoot, userRoot: userRoot);

    expect(paths(policy.candidatesFor(StorageArea.data, snapshot(portable: false))), ['${userRoot.path}/data']);
  });

  test('a portable layout without the executable root has no persistent home', () {
    final policy = DefaultStoragePolicy(userRoot: userRoot);

    expect(policy.candidatesFor(StorageArea.data, snapshot(portable: true)), isEmpty);
  });

  test('cache prefers the portable tree on a portable build', () {
    final policy = DefaultStoragePolicy(portableRoot: exeRoot, cacheRoot: cacheRoot, tempRoot: tempRoot);

    expect(paths(policy.candidatesFor(StorageArea.cache, snapshot(portable: true))), ['${exeRoot.path}/cache']);
  });

  test('cache falls through OS cache to temp on an installed build', () {
    final policy = DefaultStoragePolicy(portableRoot: exeRoot, cacheRoot: cacheRoot, tempRoot: tempRoot);

    expect(paths(policy.candidatesFor(StorageArea.cache, snapshot(portable: false))), [
      '${cacheRoot.path}/pure_live',
      '${tempRoot.path}/pure_live_cache',
    ]);
  });

  test('temporary follows the same portability rule', () {
    final policy = DefaultStoragePolicy(portableRoot: exeRoot, tempRoot: tempRoot);

    expect(paths(policy.candidatesFor(StorageArea.temporary, snapshot(portable: true))), ['${exeRoot.path}/temp']);
    expect(paths(policy.candidatesFor(StorageArea.temporary, snapshot(portable: false))), [
      '${tempRoot.path}/pure_live_temp',
    ]);
  });

  test('a portable build keeps its downloads in the bundle, the OS folder second', () {
    final policy = DefaultStoragePolicy(portableRoot: exeRoot, userRoot: userRoot, downloadsRoot: downloadsRoot);

    expect(paths(policy.candidatesFor(StorageArea.downloads, snapshot(portable: true))), [
      '${exeRoot.path}/downloads',
      downloadsRoot.path,
    ]);
    expect(paths(policy.candidatesFor(StorageArea.downloads, snapshot(portable: false))), [
      downloadsRoot.path,
      '${userRoot.path}/downloads',
    ]);
  });

  test('without a user choice the download default follows the deployment', () {
    final policy = DefaultStoragePolicy(portableRoot: exeRoot, userRoot: userRoot);

    expect(paths(policy.candidatesFor(StorageArea.downloads, snapshot(portable: true))), ['${exeRoot.path}/downloads']);
    expect(paths(policy.candidatesFor(StorageArea.downloads, snapshot(portable: false))), [
      '${userRoot.path}/downloads',
    ]);
  });
}
