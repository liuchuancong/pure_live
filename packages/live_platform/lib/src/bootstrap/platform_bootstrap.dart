import 'dart:io';

import 'package:live_platform/src/contracts/platform_environment.dart';
import 'package:live_platform/src/runtime/desktop_distribution.dart';
import 'package:live_platform/src/runtime/distribution_resolver.dart';
import 'package:live_platform/src/runtime/form_factor.dart';
import 'package:live_platform/src/runtime/package_identity.dart';
import 'package:live_platform/src/runtime/platform_capabilities.dart';
import 'package:live_platform/src/runtime/platform_kind.dart';
import 'package:live_platform/src/runtime/platform_runtime_info.dart';

/// Everything bootstrap produced: the environment snapshot the app and the
/// sibling packages (path provider, file access) read their platform facts
/// from. This package only *distinguishes* platforms — where data lives is
/// `live_platform_path_provider`'s decision.
final class PlatformRuntime {
  /// A completed bootstrap result.
  const new({required this.environment});

  /// Runtime facts and capabilities.
  final PlatformEnvironment environment;
}

/// The composition entry point: run once at startup, before anything reads a
/// platform fact.
///
/// The distribution verdict comes from `DistributionResolver`'s trust chain
/// — launcher declaration, bundled `build` claim, the native package-
/// identity probe, the portable markers, the MSIX path shape, and finally
/// the cached inferred claim — and a reliable fresh detection is persisted
/// as the new cache: portable verdicts beside the executable, everything
/// else in the writable metadata directory handed to init. Nothing here can
/// fail a startup: every read and write failure degrades to less evidence.
abstract final class PlatformBootstrap {
  /// Builds the runtime.
  ///
  /// [declaredDistribution] is the launcher's or the user's own statement
  /// and outranks everything on disk. [claimDirectory] is a writable
  /// metadata home for the inferred caches of non-portable verdicts — pass
  /// the OS application-support directory or a portable metadata tree, never
  /// the read-only install resources; null disables caching. A portable
  /// verdict is cached beside the executable instead, on the medium it
  /// vouches for.
  /// [packageIdentity] carries the native probe's answer (a non-null
  /// `windowsFamilyName()`); null means not probed. [formFactor] overrides
  /// the default (desktop for desktop OSes, phone for mobile) — the user's
  /// own phone/tablet/TV choice travels here from the app's settings,
  /// because a TV build is a UI and storage composition, not a hardware
  /// fact. [appNamespace] is the one place a host application declares the
  /// name it writes under — storage, logs and startup registration read it
  /// off the snapshot instead of carrying their own product literal.
  static PlatformRuntime init({
    DesktopDistribution? declaredDistribution,
    FormFactor? formFactor,
    Directory? claimDirectory,
    bool? packageIdentity,
    String appNamespace = PlatformRuntimeInfo.defaultAppNamespace,
  }) {
    // The namespace is one path segment everywhere it lands; the check
    // lives here rather than in the const constructor's assert because no
    // string test is a constant expression in a const constructor.
    if (appNamespace.isEmpty || appNamespace.contains('/') || appNamespace.contains(r'\')) {
      throw ArgumentError.value(appNamespace, 'appNamespace', 'must be one non-empty path segment');
    }
    final kind = PlatformRuntimeInfo.inferKind();
    final executableRoot = File(Platform.resolvedExecutable).parent;
    final resolution = DistributionResolver.resolve(
      declared: declaredDistribution,
      executableRoot: executableRoot,
      claimDirectory: claimDirectory,
      packageIdentity: packageIdentity ?? (Platform.isWindows ? PackageIdentity.windowsFamilyName() != null : null),
    );
    final distribution = resolution.distribution;
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
      distributionOrigin: resolution.origin,
      distributionConflicts: resolution.conflicts,
      appNamespace: appNamespace,
    );

    return PlatformRuntime(
      environment: _Environment(runtime, PlatformCapabilities.defaults(kind: kind, formFactor: resolvedFormFactor)),
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
