import 'dart:io';

import 'package:live_platform/src/contracts/platform_environment.dart';
import 'package:live_platform/src/runtime/desktop_distribution.dart';
import 'package:live_platform/src/runtime/distribution_detector.dart';
import 'package:live_platform/src/runtime/form_factor.dart';
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
/// Facts are assembled in strict trust order — explicit declarations from the
/// app shell (or launcher/native bridge) win, then the user-declared portable
/// markers (a `data/` tree or `portable.marker` placed next to the
/// executable), then conservative detection, and uncertainty stays visible as
/// [DesktopDistribution.unknown]. Nothing here touches the filesystem beyond
/// reading the marker probe.
abstract final class PlatformBootstrap {
  /// Builds the runtime. [declaredDistribution] comes from a trusted source
  /// (launcher argument, native bridge, the user's own setting) and always
  /// wins; when omitted, the portable markers next to the executable are
  /// honoured, then the MSIX container shape is recognised conservatively,
  /// and everything else stays unknown. [formFactor] overrides the default
  /// (desktop for desktop OSes, phone for mobile) — the user's own
  /// phone/tablet/TV choice travels here from the app's settings, because a
  /// TV build is a UI and storage composition, not a hardware fact.
  static PlatformRuntime init({DesktopDistribution? declaredDistribution, FormFactor? formFactor}) {
    final kind = PlatformRuntimeInfo.inferKind();
    final executableRoot = File(Platform.resolvedExecutable).parent;
    final distribution =
        declaredDistribution ??
        DistributionDetector.detectMarkers(executableRoot) ??
        DistributionDetector.detect(executableRoot);
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
