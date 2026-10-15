import 'package:live_platform/src/runtime/desktop_distribution.dart';

/// Which tier of the trust chain produced the final distribution.
///
/// Ordered by descending trust; the resolver picks the highest tier that
/// produced evidence, and every lower tier that disagreed is recorded as a
/// conflict for diagnostics.
enum DistributionOrigin {
  /// The launcher or native bridge declared it in-process — strongest.
  launcherDeclaration,

  /// A valid `source: build` claim bundled with the artifact.
  buildClaim,

  /// A native platform probe (Windows package identity).
  nativeIdentity,

  /// The user-placed portable markers (`data/` tree, `portable.marker`).
  portableMarker,

  /// Deployment path-shape metadata (the MSIX container pattern).
  pathShape,

  /// The cached inferred claim from an earlier reliable detection — a hint,
  /// never trusted above fresh evidence.
  cachedInference,

  /// Nothing was conclusive.
  undetermined,
}

/// The final distribution verdict plus everything diagnostics need.
final class DistributionResolution {
  /// A resolution; [conflicts] may be empty but is never null.
  const new({required this.distribution, required this.origin, this.conflicts = const []});

  /// The distribution the process should plan its data around.
  final DesktopDistribution distribution;

  /// The trust tier the verdict came from.
  final DistributionOrigin origin;

  /// Human-readable lines describing every lower-trust evidence that
  /// disagreed with the verdict — for the app's diagnostics log, not for
  /// users.
  final List<String> conflicts;

  /// Whether the verdict came from a fresh, reliable detection and should be
  /// persisted as the new inferred cache.
  bool get isPersistableDetection =>
      origin == DistributionOrigin.nativeIdentity ||
      origin == DistributionOrigin.portableMarker ||
      origin == DistributionOrigin.pathShape;
}
