import 'package:live_device/src/network/adapter/network_adapter.dart';
import 'package:live_device/src/network/adapter/network_adapter_capabilities.dart';

/// Lists the machine's network adapters and every address bound to them.
///
/// This is the plural answer that `network_info_plus` cannot give: that plugin's
/// contract reports a single address for the current Wi-Fi association on every
/// platform, so a host holding both `192.168.x.x` and `10.x.x.x` shows only one
/// of them there. Callers that need the full set depend on this contract.
abstract interface class NetworkAdapterService {
  /// Returns one entry per adapter the operating system exposes.
  ///
  /// Loopback and link-local addresses are left out unless asked for, because
  /// callers usually want the addresses a peer could actually reach.
  Future<List<NetworkAdapter>> read({bool includeLoopback = false, bool includeLinkLocal = false});

  /// Returns support declared for the current runtime platform.
  Future<NetworkAdapterCapabilities> getCapabilities();
}
