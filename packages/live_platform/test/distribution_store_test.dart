import 'dart:io';

import 'package:live_platform/live_platform.dart';
import 'package:test/test.dart';

/// The store is a cache with three promises: an existing `build` claim is
/// never touched, an unchanged inferred claim is not rewritten, and every
/// failure is silent because losing the cache only costs one re-detection.
void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('live_platform_store');
  });

  tearDown(() {
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // A transient Windows lock; the temporary directory goes with the process.
    }
  });

  test('reading an absent claim is null', () {
    expect(DistributionStore.read(root), isNull);
  });

  test('a written inferred claim reads back', () {
    DistributionStore.writeInferred(root, DesktopDistribution.portable);

    final claim = DistributionStore.read(root);
    expect(claim, isNotNull);
    expect(claim!.source, DistributionClaimSource.inferred);
    expect(claim.distribution, DesktopDistribution.portable);
  });

  test('a build claim survives a write attempt untouched', () {
    final file = File('${root.path}/${DistributionClaim.fileName}');
    const bundled = '{"schemaVersion":1,"distribution":"msix","source":"build"}';
    file.writeAsStringSync(bundled);

    DistributionStore.writeInferred(root, DesktopDistribution.portable);

    expect(file.readAsStringSync(), bundled, reason: 'the packaging flow owns the build claim');
  });

  test('rewriting the same inferred value keeps the file as it is', () {
    DistributionStore.writeInferred(root, DesktopDistribution.installed);
    final before = File('${root.path}/${DistributionClaim.fileName}').readAsStringSync();

    DistributionStore.writeInferred(root, DesktopDistribution.installed);

    expect(File('${root.path}/${DistributionClaim.fileName}').readAsStringSync(), before);
  });

  test('a changed detection updates the inferred claim', () {
    DistributionStore.writeInferred(root, DesktopDistribution.installed);
    DistributionStore.writeInferred(root, DesktopDistribution.portable);

    expect(DistributionStore.read(root)!.distribution, DesktopDistribution.portable);
  });

  test('an unwritable location fails silently', () {
    // A file occupying the claim directory's path makes every operation
    // below fail; the store must swallow all of it.
    File('${root.path}/blocked').writeAsStringSync('not a directory');

    expect(
      () => DistributionStore.writeInferred(Directory('${root.path}/blocked'), DesktopDistribution.msix),
      returnsNormally,
    );
    expect(() => DistributionStore.read(Directory('${root.path}/blocked')), returnsNormally);
  });

  test('a corrupt cache reads as null and is then replaced', () {
    File('${root.path}/${DistributionClaim.fileName}').writeAsStringSync('{ broken');

    expect(DistributionStore.read(root), isNull);

    DistributionStore.writeInferred(root, DesktopDistribution.installed);
    expect(DistributionStore.read(root)!.distribution, DesktopDistribution.installed);
  });
}
