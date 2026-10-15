import 'dart:io';

import 'package:live_platform/live_platform.dart';
import 'package:test/test.dart';

/// The resolver is the trust chain, so the cases below walk it tier by
/// tier: a launcher declaration outranks a build claim, a build claim
/// outranks the native probe, the probe outranks the markers, the markers
/// outrank the path shape, and the cached inference only answers when
/// nothing fresh can — with every disagreement recorded for diagnostics and
/// only fresh detections persisted.
void main() {
  late Directory root;
  late Directory exeRoot;
  late Directory claimDir;

  setUp(() {
    root = Directory.systemTemp.createTempSync('live_platform_resolver');
    exeRoot = Directory('${root.path}/bin')..createSync();
    claimDir = Directory('${root.path}/meta')..createSync();
  });

  tearDown(() {
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // A transient Windows lock; the temporary directory goes with the process.
    }
  });

  void writeBundledClaim(DesktopDistribution distribution) {
    File('${exeRoot.path}/${DistributionClaim.fileName}')
        .writeAsStringSync('{"schemaVersion":1,"distribution":"${distribution.name}","source":"build"}');
  }

  test('nothing at all is unknown, and unknown is never persisted', () {
    final resolution = DistributionResolver.resolve(
      executableRoot: exeRoot,
      claimDirectory: claimDir,
      packageIdentity: false,
    );

    expect(resolution.distribution, DesktopDistribution.unknown);
    expect(resolution.origin, DistributionOrigin.undetermined);
    expect(resolution.conflicts, isEmpty);
    expect(DistributionStore.read(claimDir), isNull, reason: 'unknown must not be cached');
  });

  test('a launcher declaration outranks everything on disk', () {
    writeBundledClaim(DesktopDistribution.portable);

    final resolution = DistributionResolver.resolve(
      declared: DesktopDistribution.msix,
      executableRoot: exeRoot,
      claimDirectory: claimDir,
      packageIdentity: true,
    );

    expect(resolution.distribution, DesktopDistribution.msix);
    expect(resolution.origin, DistributionOrigin.launcherDeclaration);
    expect(resolution.conflicts, hasLength(1), reason: 'only the build claim disagreed; identity agreed');
    expect(resolution.conflicts.first, contains('build claim'));
    // The launcher's word is not a detection; the cache keeps the build
    // claim's value instead of being rewritten.
    expect(DistributionStore.read(claimDir), isNull);
  });

  test('an unknown declaration means no declaration', () {
    final resolution = DistributionResolver.resolve(declared: DesktopDistribution.unknown);

    expect(resolution.origin, DistributionOrigin.undetermined);
  });

  test('a build claim outranks the native probe and the markers', () {
    writeBundledClaim(DesktopDistribution.installed);

    final resolution = DistributionResolver.resolve(
      executableRoot: exeRoot,
      claimDirectory: claimDir,
      packageIdentity: true,
    );

    expect(resolution.distribution, DesktopDistribution.installed);
    expect(resolution.origin, DistributionOrigin.buildClaim);
    expect(resolution.conflicts, hasLength(1), reason: 'package identity said msix');
    expect(resolution.conflicts.first, contains('overrides package identity'));
    // A build claim's value is never re-persisted as inferred.
    expect(DistributionStore.read(claimDir), isNull);
  });

  test('package identity is native evidence above the markers', () {
    File('${exeRoot.path}/portable.marker').writeAsStringSync('');

    final resolution = DistributionResolver.resolve(
      executableRoot: exeRoot,
      claimDirectory: claimDir,
      packageIdentity: true,
    );

    expect(resolution.distribution, DesktopDistribution.msix);
    expect(resolution.origin, DistributionOrigin.nativeIdentity);
    expect(resolution.conflicts, hasLength(1), reason: 'the portable marker disagreed');
    expect(resolution.conflicts.first, contains('portable markers'));

    // A reliable fresh detection is persisted.
    expect(DistributionStore.read(claimDir)!.distribution, DesktopDistribution.msix);
  });

  test('identity absent does not prove an installed build', () {
    final resolution = DistributionResolver.resolve(
      executableRoot: exeRoot,
      claimDirectory: claimDir,
      packageIdentity: false,
    );

    expect(resolution.distribution, DesktopDistribution.unknown);
    expect(resolution.origin, DistributionOrigin.undetermined);
  });

  test('the marker outranks the path shape and is recorded on its own medium', () {
    File('${exeRoot.path}/portable.marker').writeAsStringSync('');

    final resolution = DistributionResolver.resolve(
      executableRoot: exeRoot,
      claimDirectory: claimDir,
      packageIdentity: false,
    );

    expect(resolution.distribution, DesktopDistribution.portable);
    expect(resolution.origin, DistributionOrigin.portableMarker);
    expect(resolution.conflicts, isEmpty);
    // The portable hint belongs to the executable's own medium — the shared
    // metadata tree stays empty, exactly as a portable build promises.
    expect(DistributionStore.read(exeRoot)!.distribution, DesktopDistribution.portable);
    expect(DistributionStore.read(claimDir), isNull);
  });

  test('a fresh detection different from the cache updates it', () {
    DistributionStore.writeInferred(exeRoot, DesktopDistribution.installed);
    File('${exeRoot.path}/portable.marker').writeAsStringSync('');

    final resolution = DistributionResolver.resolve(
      executableRoot: exeRoot,
      claimDirectory: claimDir,
      packageIdentity: false,
    );

    expect(resolution.distribution, DesktopDistribution.portable);
    expect(resolution.origin, DistributionOrigin.portableMarker);
    expect(DistributionStore.read(exeRoot)!.distribution, DesktopDistribution.portable);
  });

  test('a stale portable hint in the shared metadata tree is not evidence', () {
    // What an older version left behind: a portable inference in the OS
    // metadata tree an installed build reads too. The installed build must
    // resolve unknown, not inherit the other deployment's answer.
    DistributionStore.writeInferred(claimDir, DesktopDistribution.portable);

    final resolution = DistributionResolver.resolve(
      executableRoot: exeRoot,
      claimDirectory: claimDir,
      packageIdentity: false,
    );

    expect(resolution.distribution, DesktopDistribution.unknown);
    expect(resolution.origin, DistributionOrigin.undetermined);
  });

  test('the cached inference only answers when nothing fresh can', () {
    DistributionStore.writeInferred(exeRoot, DesktopDistribution.portable);

    final resolution = DistributionResolver.resolve(
      executableRoot: exeRoot,
      claimDirectory: claimDir,
      packageIdentity: false,
    );

    expect(resolution.distribution, DesktopDistribution.portable);
    expect(resolution.origin, DistributionOrigin.cachedInference);
  });

  test('a bundled inferred claim is a cache too, not a declaration', () {
    File('${exeRoot.path}/${DistributionClaim.fileName}')
        .writeAsStringSync('{"schemaVersion":1,"distribution":"msix","source":"inferred"}');

    final resolution = DistributionResolver.resolve(
      executableRoot: exeRoot,
      claimDirectory: claimDir,
      packageIdentity: false,
    );

    expect(resolution.distribution, DesktopDistribution.msix);
    expect(resolution.origin, DistributionOrigin.cachedInference);
  });

  test('a corrupt claim is ignored, not defaulted', () {
    File('${exeRoot.path}/${DistributionClaim.fileName}').writeAsStringSync('{ broken');
    File('${claimDir.path}/${DistributionClaim.fileName}')
        .writeAsStringSync('{"schemaVersion":9,"distribution":"msix","source":"build"}');

    final resolution = DistributionResolver.resolve(
      executableRoot: exeRoot,
      claimDirectory: claimDir,
      packageIdentity: false,
    );

    expect(resolution.distribution, DesktopDistribution.unknown);
    expect(DistributionStore.read(claimDir), isNull);
  });

  test('null locations disable the halves they describe', () {
    final resolution = DistributionResolver.resolve(declared: DesktopDistribution.portable);

    expect(resolution.distribution, DesktopDistribution.portable);
    expect(resolution.conflicts, isEmpty);
  });
}
