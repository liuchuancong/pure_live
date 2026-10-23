import 'dart:io';

import 'package:live_platform/live_platform.dart';
import 'package:live_platform_path_provider/live_platform_path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// `DefaultStoragePolicy` is the deployment ruleset in directory form. The
/// cases below pin the rule that gives the portable distribution its
/// meaning: a portable build's persistent candidates never include the OS
/// application directories — its data follows the executable or nowhere —
/// while an installed build never sees the executable's directory either.
///
/// They also pin the other half: the identity the trees are named with is
/// the one the test injects (`unit_host`, twice over — on the snapshot and
/// on the policy), never a name this package owns.
void main() {
  const hostNamespace = 'unit_host';

  final exeRoot = Directory('/app/bin');
  final userRoot = Directory('/users/x/appdata');
  final cacheRoot = Directory('/users/x/cache');
  final tempRoot = Directory('/tmp');
  final downloadsRoot = Directory('/users/x/downloads');

  PlatformRuntimeInfo snapshot({required bool portable, String namespace = hostNamespace}) => PlatformRuntimeInfo(
    kind: PlatformKind.windows,
    formFactor: FormFactor.desktop,
    distribution: portable ? DesktopDistribution.portable : DesktopDistribution.installed,
    isPackaged: false,
    executableRoot: exeRoot,
    appNamespace: namespace,
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

  test('a portable layout puts the namespace area tree under the executable', () {
    final policy = DefaultStoragePolicy(portableRoot: exeRoot, userRoot: userRoot);

    expect(paths(policy.candidatesFor(StorageArea.data, snapshot(portable: true))), [
      p.join(exeRoot.path, 'data', hostNamespace),
    ], reason: 'the runtime bundle owns data/ itself');
    expect(paths(policy.candidatesFor(StorageArea.exports, snapshot(portable: true))), [
      p.join(exeRoot.path, 'exports'),
    ]);
  });

  test('an installed layout keeps data in the OS directories', () {
    final policy = DefaultStoragePolicy(portableRoot: exeRoot, userRoot: userRoot);

    expect(paths(policy.candidatesFor(StorageArea.data, snapshot(portable: false))), [
      p.join(userRoot.path, 'data'),
    ], reason: 'the OS application-support root is already per-application');
  });

  test('a portable layout without the executable root has no persistent home', () {
    final policy = DefaultStoragePolicy(userRoot: userRoot);

    expect(policy.candidatesFor(StorageArea.data, snapshot(portable: true)), isEmpty);
  });

  test('cache prefers the portable tree on a portable build', () {
    final policy = DefaultStoragePolicy(portableRoot: exeRoot, cacheRoot: cacheRoot, tempRoot: tempRoot);

    expect(paths(policy.candidatesFor(StorageArea.cache, snapshot(portable: true))), [p.join(exeRoot.path, 'cache')]);
  });

  test('cache falls through OS cache to temp on an installed build', () {
    final policy = DefaultStoragePolicy(portableRoot: exeRoot, cacheRoot: cacheRoot, tempRoot: tempRoot);

    expect(paths(policy.candidatesFor(StorageArea.cache, snapshot(portable: false))), [
      p.join(cacheRoot.path, '${hostNamespace}_cache'),
      p.join(tempRoot.path, '${hostNamespace}_cache'),
    ], reason: 'both roots are shared between applications, so both trees take the derived name');
  });

  test('temporary follows the same portability rule', () {
    final policy = DefaultStoragePolicy(portableRoot: exeRoot, tempRoot: tempRoot);

    expect(paths(policy.candidatesFor(StorageArea.temporary, snapshot(portable: true))), [
      p.join(exeRoot.path, 'temp'),
    ]);
    expect(paths(policy.candidatesFor(StorageArea.temporary, snapshot(portable: false))), [
      p.join(tempRoot.path, '${hostNamespace}_temp'),
    ]);
  });

  test('a portable build keeps its downloads in the bundle, the OS folder second', () {
    final policy = DefaultStoragePolicy(portableRoot: exeRoot, userRoot: userRoot, downloadsRoot: downloadsRoot);

    expect(paths(policy.candidatesFor(StorageArea.downloads, snapshot(portable: true))), [
      p.join(exeRoot.path, 'downloads'),
      downloadsRoot.path,
    ]);
    expect(paths(policy.candidatesFor(StorageArea.downloads, snapshot(portable: false))), [
      downloadsRoot.path,
      p.join(userRoot.path, 'downloads'),
    ]);
  });

  test('without a user choice the download default follows the deployment', () {
    final policy = DefaultStoragePolicy(portableRoot: exeRoot, userRoot: userRoot);

    expect(paths(policy.candidatesFor(StorageArea.downloads, snapshot(portable: true))), [
      p.join(exeRoot.path, 'downloads'),
    ]);
    expect(paths(policy.candidatesFor(StorageArea.downloads, snapshot(portable: false))), [
      p.join(userRoot.path, 'downloads'),
    ]);
  });

  test('every namespaced tree follows the namespace the snapshot declares', () {
    final policy = DefaultStoragePolicy(
      portableRoot: exeRoot,
      userRoot: userRoot,
      cacheRoot: cacheRoot,
      tempRoot: tempRoot,
    );

    for (final namespace in ['unit_host', 'other_host']) {
      final portable = snapshot(portable: true, namespace: namespace);
      final installed = snapshot(portable: false, namespace: namespace);

      expect(paths(policy.candidatesFor(StorageArea.data, portable)), [p.join(exeRoot.path, 'data', namespace)]);
      expect(paths(policy.candidatesFor(StorageArea.cache, installed)), [
        p.join(cacheRoot.path, '${namespace}_cache'),
        p.join(tempRoot.path, '${namespace}_cache'),
      ]);
      expect(paths(policy.candidatesFor(StorageArea.temporary, installed)), [
        p.join(tempRoot.path, '${namespace}_temp'),
      ]);
      expect(
        policy.namespaceFor(installed),
        namespace,
        reason: "a policy that declares nothing defers to the host's own declaration",
      );
    }

    // The two hosts never resolve onto one another's trees — which is only
    // true because no name is baked into the layout.
    expect(
      paths(policy.candidatesFor(StorageArea.cache, snapshot(portable: false, namespace: 'alpha_host'))),
      isNot(paths(policy.candidatesFor(StorageArea.cache, snapshot(portable: false, namespace: 'beta_host')))),
    );
  });

  test('a namespace declared on the policy wins over the snapshot', () {
    final policy = DefaultStoragePolicy(
      portableRoot: exeRoot,
      cacheRoot: cacheRoot,
      tempRoot: tempRoot,
      appNamespace: 'policy_host',
    );

    expect(policy.namespaceFor(snapshot(portable: false, namespace: 'snapshot_host')), 'policy_host');
    expect(paths(policy.candidatesFor(StorageArea.data, snapshot(portable: true))), [
      p.join(exeRoot.path, 'data', 'policy_host'),
    ]);
    expect(paths(policy.candidatesFor(StorageArea.cache, snapshot(portable: false))), [
      p.join(cacheRoot.path, 'policy_host_cache'),
      p.join(tempRoot.path, 'policy_host_cache'),
    ]);
  });

  test('the derived names come from the helpers the manager reuses', () {
    const namespace = 'unit_host';

    expect(DefaultStoragePolicy.cacheDirectoryName(namespace), '${namespace}_cache');
    expect(DefaultStoragePolicy.tempDirectoryName(namespace), '${namespace}_temp');
    expect(DefaultStoragePolicy.probeBaseName(namespace), '${namespace}_probe');
  });

  test('the data-root helpers name the exact trees the policy writes', () {
    final policy = DefaultStoragePolicy(portableRoot: exeRoot, userRoot: userRoot);

    // A split-brain check reads these helpers to name the *other*
    // deployment's tree; if they ever drift from candidatesFor, it starts
    // inspecting a directory nothing writes — silently, the way a missing
    // namespacing segment once did.
    expect(
      DefaultStoragePolicy.portableDataRoot(exeRoot, namespace: hostNamespace).path,
      policy.candidatesFor(StorageArea.data, snapshot(portable: true)).single.path,
      reason: 'the portable helper must match the portable data candidate',
    );
    expect(
      DefaultStoragePolicy.installedDataRoot(userRoot).path,
      policy.candidatesFor(StorageArea.data, snapshot(portable: false)).single.path,
      reason: 'the installed helper must match the installed data candidate',
    );
    expect(
      DefaultStoragePolicy.portableDataRoot(exeRoot, namespace: 'other_host').path,
      policy.candidatesFor(StorageArea.data, snapshot(portable: true, namespace: 'other_host')).single.path,
      reason: 'the helper namespaces with whoever the host declared',
    );
  });
}
