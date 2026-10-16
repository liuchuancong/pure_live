import 'package:live_device/src/network/connectivity/network_interface.dart';

/// Connectivity operations available on the current runtime platform.
///
/// These flags describe what the backend can report, not what is currently
/// attached. A platform that can report [NetworkInterface.wifi] still reports
/// [NetworkInterface.none] while the radio is off.
final class NetworkConnectivityCapabilities {
  /// Creates an immutable capability description.
  const new({
    required this.canRead,
    required this.canObserve,
    required this.reportsCellular,
    required this.reportsWifi,
    required this.platformName,
  });

  /// Whether a one-shot connectivity reading can be requested.
  final bool canRead;

  /// Whether connectivity changes can be observed.
  ///
  /// On web the browser exposes an on/offline signal, but it may deliver
  /// changes late or never, so an observing screen should still read on resume.
  final bool canObserve;

  /// Whether the platform can report [NetworkInterface.cellular] at all.
  final bool reportsCellular;

  /// Whether the platform can report [NetworkInterface.wifi] at all.
  final bool reportsWifi;

  /// Runtime platform label for diagnostics, not intended for feature branching.
  final String platformName;

  /// Whether any connectivity information can be offered to the UI.
  bool get canOfferConnectivity => canRead || canObserve;
}
