import 'package:live_device/src/network/connectivity/network_interface.dart';

/// A point-in-time reading of the network interfaces a device reports.
///
/// Connectivity is a set, not a single value: a phone can report
/// [NetworkInterface.cellular] together with [NetworkInterface.satellite], and a
/// desktop can report [NetworkInterface.ethernet] together with
/// [NetworkInterface.vpn]. Callers that only need a yes/no answer should use
/// [isOnline].
final class NetworkConnectivity {
  /// Creates a connectivity reading from [interfaces].
  ///
  /// The reading stores an unmodifiable, de-duplicated copy, so a later change
  /// to the collection that was passed in cannot alter a snapshot that has
  /// already been handed to a caller.
  new({required Iterable<NetworkInterface> interfaces}) : interfaces = Set<NetworkInterface>.unmodifiable(interfaces);

  /// Interfaces reported as active.
  ///
  /// Platforms report [NetworkInterface.none] alone when nothing is connected,
  /// and a reading is empty only when the backend produced no value at all.
  final Set<NetworkInterface> interfaces;

  /// Whether the device reports a usable connection.
  ///
  /// This is false only for the exclusive [NetworkInterface.none] report. An
  /// empty reading counts as online because backends never use an empty report
  /// to mean "offline", and a mixed report such as [NetworkInterface.none] with
  /// [NetworkInterface.vpn] names an interface that is actually up.
  bool get isOnline => !(interfaces.length == 1 && interfaces.contains(NetworkInterface.none));
}
