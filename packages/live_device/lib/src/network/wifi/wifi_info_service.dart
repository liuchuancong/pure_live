import 'package:live_device/src/network/wifi/wifi_info_capabilities.dart';
import 'package:live_device/src/network/wifi/wifi_info_exception.dart';
import 'package:live_device/src/network/wifi/wifi_network_info.dart';

/// Reads details of the Wi-Fi network the device is joined to.
///
/// No platform publishes Wi-Fi detail events, so this contract is poll-on-demand
/// by design: call [read] when a screen needs fresh values rather than
/// subscribing. Use `NetworkConnectivityService` for the connective question of
/// whether any interface is up.
abstract interface class WifiInfoService {
  /// Reads every Wi-Fi value the running platform can provide.
  ///
  /// Each value is looked up on its own. A lookup that the platform does not
  /// implement, or whose backend is not registered here, yields `null` for that
  /// value and leaves the remaining ones intact, which mirrors how the platform
  /// backends behave per lookup. Any other failure aborts the read and is
  /// reported as a [WifiInfoException] naming the field that failed.
  Future<WifiNetworkInfo> read();

  /// Returns support declared for the current runtime platform.
  ///
  /// Declared support is not a promise of a value: authorization, entitlement
  /// and the absence of a Wi-Fi interface all legitimately produce `null`.
  Future<WifiInfoCapabilities> getCapabilities();
}
