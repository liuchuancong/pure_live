import 'dart:io';

import 'package:live_platform/live_platform.dart';
import 'package:live_platform_path_provider/live_platform_path_provider.dart';
import 'package:test/test.dart';

/// `PathProviderBootstrap.init` is where the deployment facts become a
/// directory plan. The cases below walk the two deployments end to end: a
/// portable build resolves its data under its own executable and never into
/// the OS directories, an installed build does the opposite, and the
/// download area reports its privacy honestly.
void main() {
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

  test('an installed build keeps data in the OS directories', () async {
    final runtime = await PathProviderBootstrap.init(
      environment: environment,
      userDataDirectory: () async => Directory('${root.path}/userdata'),
      cacheDirectory: () async => Directory('${root.path}/cache'),
      temporaryDirectory: () async => Directory('${root.path}/temp'),
      downloadsDirectory: () async => Directory('${root.path}/downloads'),
    );

    expect((await runtime.storage.resolve(StorageArea.data)).path, '${root.path}/userdata/data');
    expect((await runtime.storage.resolve(StorageArea.cache)).path, '${root.path}/cache/pure_live');
    expect((await runtime.storage.resolve(StorageArea.temporary)).path, '${root.path}/temp/pure_live_temp');
    expect((await runtime.storage.resolve(StorageArea.downloads)).path, '${root.path}/downloads');
  });

  test('a portable build keeps everything next to the executable', () async {
    final portable = _Environment(
      PlatformRuntimeInfo(
        kind: PlatformKind.windows,
        formFactor: FormFactor.desktop,
        distribution: DesktopDistribution.portable,
        isPackaged: false,
        executableRoot: Directory('${root.path}/app'),
      ),
    );
    final runtime = await PathProviderBootstrap.init(
      environment: portable,
      userDataDirectory: () async => Directory('${root.path}/userdata'),
      downloadsDirectory: () async => Directory('${root.path}/downloads'),
    );

    expect((await runtime.storage.resolve(StorageArea.data)).path, '${root.path}/app/data');
    expect((await runtime.storage.resolve(StorageArea.config)).path, '${root.path}/app/config');

    final downloads = await runtime.storage.resolve(StorageArea.downloads);
    expect(downloads.path, '${root.path}/app/downloads', reason: 'the bundle carries its downloads');
  });

  test('a desktop resolution is never flagged private', () async {
    final runtime = await PathProviderBootstrap.init(
      environment: environment,
      userDataDirectory: () async => Directory('${root.path}/userdata'),
    );

    expect((await runtime.storage.resolve(StorageArea.data)).isPrivate, isFalse);
  });
}

final class _Environment implements PlatformEnvironment {
  const new(this.runtime);

  @override
  final PlatformRuntimeInfo runtime;

  @override
  PlatformCapabilities get capabilities =>
      PlatformCapabilities.defaults(kind: runtime.kind, formFactor: runtime.formFactor);
}
