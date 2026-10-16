/// Adapter-enumeration support reported for the current runtime platform.
///
/// This describes whether the enumeration API exists, not what it finds: a
/// machine behind a VPN, a container bridge or a disabled interface still
/// answers with whichever adapters the operating system chooses to expose, and
/// prefix or broadcast information is only known per address from the reading.
final class NetworkAdapterCapabilities {
  /// Creates an immutable capability description.
  const new({required this.canEnumerateAdapters, required this.platformName});

  /// Whether adapters and their addresses can be listed at all.
  final bool canEnumerateAdapters;

  /// Runtime platform label for diagnostics, not intended for feature branching.
  final String platformName;
}
