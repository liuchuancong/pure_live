import 'package:live_sites/src/capabilities/live_site_capability.dart';
import 'package:live_sites/src/core/live_site_context.dart';
import 'package:live_sites/src/core/live_site_manifest.dart';
import 'package:live_sites/src/core/live_site_runtime_info.dart';

/// The primary contract every platform implementation exposes.
///
/// A site has stable identity ([manifest]) and a lifecycle ([initialize] then
/// [dispose]); every feature lives behind an optional capability retrieved
/// through [capability], so the site never gains a convenience method for one
/// platform's quirk. Construction performs no I/O — nothing is fetched until
/// [initialize].
abstract interface class LiveSite {
  /// Stable platform identity and metadata.
  LiveSiteManifest get manifest;

  /// The current runtime status.
  LiveSiteRuntimeInfo get runtimeInfo;

  /// The capability of type [T] this site supports, or null when it does not.
  ///
  /// A null return means the operation is not supported; an empty result from
  /// a supported capability never stands in for that.
  T? capability<T extends LiveSiteCapability>();

  /// Initializes the resources this site needs for [context]. Idempotent, or
  /// it rejects an invalid lifecycle transition.
  Future<void> initialize(LiveSiteContext context);

  /// Releases the resources this instance owns. Safe per the lifecycle
  /// contract; after it the instance is not reusable.
  Future<void> dispose();
}
