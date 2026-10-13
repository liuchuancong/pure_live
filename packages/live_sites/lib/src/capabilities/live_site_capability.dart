/// The marker every optional platform capability implements.
///
/// `LiveSite.capability<T>()` returns null for a capability the site does
/// not implement; an empty result from an implemented capability never
/// stands in for "unsupported" (ARCHITECTURE.md §4.1).
abstract interface class LiveSiteCapability;
