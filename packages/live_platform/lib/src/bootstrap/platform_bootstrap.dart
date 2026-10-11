import 'dart:io';

import 'package:live_platform/src/contracts/platform_environment.dart';
import 'package:live_platform/src/contracts/storage_manager.dart';
import 'package:live_platform/src/runtime/desktop_distribution.dart';
import 'package:live_platform/src/runtime/distribution_detector.dart';
import 'package:live_platform/src/runtime/form_factor.dart';
import 'package:live_platform/src/runtime/platform_capabilities.dart';
import 'package:live_platform/src/runtime/platform_kind.dart';
import 'package:live_platform/src/runtime/platform_runtime_info.dart';
import 'package:live_platform/src/storage/default_storage_manager.dart';
import 'package:live_platform/src/storage/storage_policy.dart';

/// Everything bootstrap produced: the environment snapshot and the
/// storage manager business modules consume.
final class PlatformRuntime {
  /// A completed bootstrap result.
  const new({required this.environment, required this.storage});

  /// Runtime facts and capabilities.
  final PlatformEnvironment environment;

  /// Directory resolution for every storage area.
  final StorageManager storage;
}

/// The composition entry point: run once at startup, before any storage
/// access.
///
/// Facts are assembled in strict trust order — explicit declarations from
/// the app shell (or launcher/native bridge) win, conservative detection
/// fills the rest, uncertainty stays visible as
/// [DesktopDistribution.unknown]. Directory roots come from the app
/// shell's path_provider calls; portable mode additionally offers the
/// executable-adjacent tree.
abstract final class PlatformBootstrap {
  /// Builds the runtime. [declaredDistribution] comes from a trusted
  /// source (launcher argument, native bridge); when omitted, MSIX is
  /// detected conservatively and everything else stays unknown.
  /// [userDataDirectory] / [cacheDirectory] resolve the OS directories
  /// (path_provider in a Flutter shell); portable layouts work without
  /// them. [formFactor] overrides the default (desktop for desktop OSes,
  /// phone for mobile, TV stays an explicit declaration).
  static Future<PlatformRuntime> init({
    DesktopDistribution? declaredDistribution,
    FormFactor? formFactor,
    Future<Directory?> Function()? userDataDirectory,
    Future<Directory?> Function()? cacheDirectory,
    StoragePolicy? policy,
  }) async {
    final kind = PlatformRuntimeInfo.inferKind();
    final executableRoot = File(Platform.resolvedExecutable).parent;
    final distribution = declaredDistribution ?? DistributionDetector.detect(executableRoot);
    final resolvedFormFactor =
        formFactor ??
        switch (kind) {
          PlatformKind.android => FormFactor.phone,
          PlatformKind.ios => FormFactor.phone,
          PlatformKind.windows || PlatformKind.macos || PlatformKind.linux => FormFactor.desktop,
          PlatformKind.unknown => FormFactor.desktop,
        };

    final runtime = PlatformRuntimeInfo(
      kind: kind,
      formFactor: resolvedFormFactor,
      distribution: distribution,
      isPackaged: distribution == DesktopDistribution.msix,
      executableRoot: executableRoot,
      osVersion: Platform.operatingSystemVersion,
    );

    final userRoot = await userDataDirectory?.call();
    final cacheRoot = await cacheDirectory?.call();
    final storage =
        DefaultStorageManager(
            policy:
                policy ?? DefaultStoragePolicy(portableRoot: executableRoot, userRoot: userRoot, cacheRoot: cacheRoot),
          )
          // The manager needs the snapshot to honour portable ordering.
          ..runtime = runtime;

    return PlatformRuntime(
      environment: _Environment(runtime, PlatformCapabilities.defaults(kind: kind, formFactor: resolvedFormFactor)),
      storage: storage,
    );
  }
}

final class _Environment implements PlatformEnvironment {
  const new(this.runtime, this.capabilities);

  @override
  final PlatformRuntimeInfo runtime;

  @override
  final PlatformCapabilities capabilities;
}
