import 'dart:io';

import 'package:live_platform/live_platform.dart';
import 'package:live_platform_path_provider/live_platform_path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// `PathProviderBootstrap.init` is where the deployment facts become a
/// directory plan. The cases below walk the two deployments end to end: a
/// portable build resolves its data under its own executable and never into
/// the OS directories, an installed build does the opposite, and the
/// download area reports its privacy honestly. The identity the trees are
/// named with is the one the host snapshot declares (`unit_host`), so a test
/// can tell whose layout it is looking at — and a `policy:` override stays
/// the escape hatch it always was.
void main() {
  const hostNamespace = 'unit_host';

  late Directory root;
  late PlatformEnvironment environment;

  setUp(() {
    root = Directory.systemTemp.createTempSync('live_platform_paths');
    environment = _Environment(
      PlatformRuntimeInfo(
        kind: PlatformKind.windows,
        formFactor: FormFactor.desktop,
        distribution: DesktopDistribution.installed,
        isPackaged: false,
        executableRoot: root,
        appNamespace: hostNamespace,
      ),
    );
  });

  tearDown(() {
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // A transient Windows lock; the temporary directory goes with the process.
    }
  });

  test('an installed build keeps data in the OS directories, named for the host', () async {
    final runtime = await PathProviderBootstrap.init(
      environment: environment,
      userDataDirectory: () async => Directory(p.join(root.path, 'userdata')),
      cacheDirectory: () async => Directory(p.join(root.path, 'cache')),
      temporaryDirectory: () async => Directory(p.join(root.path, 'temp')),
      downloadsDirectory: () async => Directory(p.join(root.path, 'downloads')),
    );

    final userRoot = Directory(p.join(root.path, 'userdata'));
    final cacheRoot = Directory(p.join(root.path, 'cache'));
    final tempRoot = Directory(p.join(root.path, 'temp'));
    expect((await runtime.storage.resolve(StorageArea.data)).path, p.join(userRoot.path, 'data'));
    expect((await runtime.storage.resolve(StorageArea.cache)).path, p.join(cacheRoot.path, '${hostNamespace}_cache'));
    expect((await runtime.storage.resolve(StorageArea.temporary)).path, p.join(tempRoot.path, '${hostNamespace}_temp'));
    expect(
      (await runtime.storage.resolve(StorageArea.downloads)).path,
      p.join(root.path, 'downloads'),
      reason: "the host's own download folder needs no namespace",
    );
  });

  test('a portable build keeps everything next to the executable', () async {
    final portable = _Environment(
      PlatformRuntimeInfo(
        kind: PlatformKind.windows,
        formFactor: FormFactor.desktop,
        distribution: DesktopDistribution.portable,
        isPackaged: false,
        executableRoot: Directory(p.join(root.path, 'app')),
        appNamespace: hostNamespace,
      ),
    );
    final runtime = await PathProviderBootstrap.init(
      environment: portable,
      userDataDirectory: () async => Directory(p.join(root.path, 'userdata')),
      downloadsDirectory: () async => Directory(p.join(root.path, 'downloads')),
    );

    final exeRoot = Directory(p.join(root.path, 'app'));
    expect((await runtime.storage.resolve(StorageArea.data)).path, p.join(exeRoot.path, 'data', hostNamespace));
    expect((await runtime.storage.resolve(StorageArea.config)).path, p.join(exeRoot.path, 'config'));

    final downloads = await runtime.storage.resolve(StorageArea.downloads);
    expect(downloads.path, p.join(exeRoot.path, 'downloads'), reason: 'the bundle carries its downloads');
  });

  test('a second host identity resolves onto its own trees, not the first ones', () async {
    final otherHost = _Environment(
      PlatformRuntimeInfo(
        kind: PlatformKind.windows,
        formFactor: FormFactor.desktop,
        distribution: DesktopDistribution.installed,
        isPackaged: false,
        executableRoot: root,
        appNamespace: 'other_host',
      ),
    );
    final cacheRoot = Directory(p.join(root.path, 'cache'));
    final thisHost = await PathProviderBootstrap.init(environment: environment, cacheDirectory: () async => cacheRoot);
    final thatHost = await PathProviderBootstrap.init(environment: otherHost, cacheDirectory: () async => cacheRoot);

    expect((await thisHost.storage.resolve(StorageArea.cache)).path, p.join(cacheRoot.path, '${hostNamespace}_cache'));
    expect((await thatHost.storage.resolve(StorageArea.cache)).path, p.join(cacheRoot.path, 'other_host_cache'));
  });

  test('a policy handed to init replaces the layout, namespace included', () async {
    final overrideRoot = Directory(p.join(root.path, 'chosen'));
    final runtime = await PathProviderBootstrap.init(
      environment: environment,
      cacheDirectory: () async => Directory(p.join(root.path, 'cache')),
      policy: _FixedPolicy(overrideRoot),
    );

    expect((await runtime.storage.resolve(StorageArea.cache)).path, overrideRoot.path);
  });

  test('a desktop resolution is never flagged private', () async {
    final runtime = await PathProviderBootstrap.init(
      environment: environment,
      userDataDirectory: () async => Directory(p.join(root.path, 'userdata')),
    );

    expect((await runtime.storage.resolve(StorageArea.data)).isPrivate, isFalse);
  });
}

/// One candidate, whatever the area: proves `init` does not wrap or re-order
/// a policy the host supplied.
final class _FixedPolicy implements StoragePolicy {
  const new(this.candidate);

  final Directory candidate;

  @override
  List<Directory> candidatesFor(StorageArea area, PlatformRuntimeInfo runtime) => [candidate];
}

final class _Environment implements PlatformEnvironment {
  const new(this.runtime);

  @override
  final PlatformRuntimeInfo runtime;

  @override
  PlatformCapabilities get capabilities =>
      PlatformCapabilities.defaults(kind: runtime.kind, formFactor: runtime.formFactor);
}
