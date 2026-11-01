/// Finds peers on the LAN and announces this device to them.
///
/// The Bonsoir (mDNS / DNS-SD) implementation lives under
/// `src/infrastructure/discovery/bonsoir/`; application code depends on
/// this interface and never on Bonsoir's types (spec §8.1). Discovery feeds
/// the device list only — it never grants trust and never opens sessions.
///
/// The default implementation is available through `createMdnsDiscovery`;
/// `NetworkMonitor` is the network-change abstraction the discovery uses to
/// self-heal after interface changes.
library;

export '../infrastructure/discovery/network_monitor.dart';
export 'device_directory.dart';
export 'device_discovery.dart';
export 'discovery_factory.dart';
