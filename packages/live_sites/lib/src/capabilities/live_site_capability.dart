/// The marker every optional site capability implements.
///
/// A site exposes a capability only when it genuinely supports it;
/// `LiveSite.capability<T>()` returns null for a capability the site lacks. An
/// empty result never stands in for an unsupported operation.
abstract interface class LiveSiteCapability {
  /// A capability has no members of its own; it only marks the type.
  const new();
}
