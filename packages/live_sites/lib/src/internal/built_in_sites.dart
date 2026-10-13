import 'package:live_sites/src/core/live_site.dart';

/// The single internal construction entry point for built-in sites.
///
/// Only platforms implemented against this contract belong here; an
/// unimplemented platform is not registered. The application composition
/// root calls this and hands the result to `LiveSiteRegistry`.
List<LiveSite> createBuiltInLiveSites() {
  return const [
    // Implemented site adapters are added here as they are ported to the
    // ARCHITECTURE.md contract (Phase 2: douyu, huya).
  ];
}
