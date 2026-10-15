import 'dart:io';

import 'package:live_platform/src/runtime/desktop_distribution.dart';
import 'package:live_platform/src/runtime/distribution_claim.dart';
import 'package:live_platform/src/runtime/distribution_detector.dart';
import 'package:live_platform/src/runtime/distribution_resolution.dart';
import 'package:live_platform/src/runtime/distribution_store.dart';

/// Weighs every distribution evidence by trust and hands out one verdict.
///
/// Trust order: launcher declaration, bundled `build` claim, native probe
/// (Windows package identity), user-placed portable markers, path-shape
/// metadata, and finally the cached inferred claim — a hint that only
/// answers when nothing fresh can. A verdict from a lower tier while a
/// higher one spoke is impossible; the reverse is recorded as a conflict
/// line for diagnostics. Only fresh detections are persisted, never a build
/// claim, never `unknown`, and never a rewrite of an unchanged cache.
abstract final class DistributionResolver {
  /// Resolves the distribution for this process.
  ///
  /// [declared] is the launcher/native-bridge statement (`unknown` means no
  /// statement). [executableRoot] is where the bundled claim and the
  /// portable markers live. [claimDirectory] is the writable metadata home
  /// for the inferred cache — null disables caching, and a directory that
  /// cannot be read or written simply disables that half. [packageIdentity]
  /// is the native probe's answer; null means "not probed", false removes
  /// the MSIX hypothesis without proving an installed build.
  static DistributionResolution resolve({
    DesktopDistribution? declared,
    Directory? executableRoot,
    Directory? claimDirectory,
    bool? packageIdentity,
  }) {
    final conflicts = <String>[];

    final bundledClaim = executableRoot == null ? null : DistributionStore.read(executableRoot);
    final cachedClaim = claimDirectory == null ? null : DistributionStore.read(claimDirectory);
    final buildClaim = bundledClaim?.source == DistributionClaimSource.build
        ? bundledClaim
        : cachedClaim?.source == DistributionClaimSource.build
        ? cachedClaim
        : null;
    final cachedInference = bundledClaim?.source == DistributionClaimSource.inferred
        ? bundledClaim
        : cachedClaim?.source == DistributionClaimSource.inferred
        ? cachedClaim
        : null;

    final markers = executableRoot == null ? null : DistributionDetector.detectMarkers(executableRoot);
    final shape = executableRoot == null ? null : DistributionDetector.detect(executableRoot);
    final nativeMsix = packageIdentity == true;

    final DesktopDistribution distribution;
    final DistributionOrigin origin;
    if (declared != null && declared != DesktopDistribution.unknown) {
      distribution = declared;
      origin = DistributionOrigin.launcherDeclaration;
    } else if (buildClaim != null) {
      distribution = buildClaim.distribution;
      origin = DistributionOrigin.buildClaim;
    } else if (nativeMsix) {
      distribution = DesktopDistribution.msix;
      origin = DistributionOrigin.nativeIdentity;
    } else if (markers != null) {
      distribution = markers;
      origin = DistributionOrigin.portableMarker;
    } else if (shape == DesktopDistribution.msix) {
      distribution = DesktopDistribution.msix;
      origin = DistributionOrigin.pathShape;
    } else if (cachedInference != null) {
      distribution = cachedInference.distribution;
      origin = DistributionOrigin.cachedInference;
    } else {
      distribution = DesktopDistribution.unknown;
      origin = DistributionOrigin.undetermined;
    }

    // Conflicts: the verdict against every fresh evidence tier below it that
    // disagreed. A differing cached inference is not a disagreement — it is
    // exactly what the update write refreshes.
    void disagree(DesktopDistribution? evidence, String name) {
      if (evidence != null && evidence != distribution) {
        conflicts.add('${origin.name} ${distribution.name} overrides $name ${evidence.name}');
      }
    }

    disagree(origin.index < DistributionOrigin.buildClaim.index ? buildClaim?.distribution : null, 'build claim');
    disagree(
      origin.index < DistributionOrigin.nativeIdentity.index && nativeMsix ? DesktopDistribution.msix : null,
      'package identity',
    );
    disagree(origin.index < DistributionOrigin.portableMarker.index ? markers : null, 'portable markers');
    disagree(
      origin.index < DistributionOrigin.pathShape.index && shape == DesktopDistribution.msix
          ? DesktopDistribution.msix
          : null,
      'path shape',
    );

    // Persist only fresh detections; never a build claim's value, never
    // unknown, never an unchanged cache. The store itself refuses to touch
    // an existing build claim.
    final fresh =
        origin == DistributionOrigin.nativeIdentity ||
        origin == DistributionOrigin.portableMarker ||
        origin == DistributionOrigin.pathShape;
    if (fresh && claimDirectory != null) {
      DistributionStore.writeInferred(claimDirectory, distribution);
    }

    return DistributionResolution(distribution: distribution, origin: origin, conflicts: List.unmodifiable(conflicts));
  }
}
