import 'package:live_device/src/network/connectivity/network_connectivity.dart';
import 'package:live_device/src/network/connectivity/network_connectivity_capabilities.dart';
import 'package:live_device/src/network/connectivity/network_connectivity_exception.dart';

/// Reads and observes which network interfaces the device reports as active.
///
/// Depend on this contract in playback or application services so the concrete
/// connectivity backend can be replaced without changing those callers. The
/// readings describe radio state, not reachability, so a request can still fail
/// while [NetworkConnectivity.isOnline] is true.
abstract interface class NetworkConnectivityService {
  /// Requests the interfaces that are active right now.
  ///
  /// Failures are reported as [NetworkConnectivityException], whose code
  /// `unsupported_on_platform` marks a backend that cannot answer at all.
  Future<NetworkConnectivity> read();

  /// Emits a reading whenever the platform reports a change.
  ///
  /// The stream does not replay the current value, so listeners that need one
  /// should call [read] first. The underlying event source is single-
  /// subscription, therefore each returned stream creates its own native
  /// subscription when listened to and cancels it when the subscription is
  /// cancelled: listen to a returned stream once and never twice.
  Stream<NetworkConnectivity> watch();

  /// Returns support declared for the current runtime platform.
  ///
  /// A declared capability can still yield no information at runtime, for
  /// example on a simulator or a browser that hides its network type.
  Future<NetworkConnectivityCapabilities> getCapabilities();
}
