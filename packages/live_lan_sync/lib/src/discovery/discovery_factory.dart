import 'package:live_lan_sync/src/config/config.dart' show LanSyncDeviceConfig, LanSyncDiscoveryConfig;
import 'package:live_lan_sync/src/discovery/device_directory.dart' show DiscoveredDeviceDirectory;
import 'package:live_lan_sync/src/discovery/device_discovery.dart' show DeviceDiscovery;
import 'package:live_lan_sync/src/infrastructure/discovery/bonsoir/bonsoir_device_discovery.dart'
    show BonsoirDeviceDiscovery;
import 'package:live_lan_sync/src/infrastructure/discovery/network_monitor.dart' show NetworkMonitor;
import 'package:live_lan_sync/src/logging/logging.dart' show LanSyncLogger;

/// Creates the package's mDNS discovery: a [DeviceDiscovery] backed by
/// Bonsoir, with deduplication and TTL handled by a [directory] the host
/// may share and a [NetworkMonitor] that restarts browsing on interface
/// changes.
///
/// This factory is the only way application code touches the mDNS
/// implementation; Bonsoir's types stay internal (spec §5.1, §8.1).
DeviceDiscovery createMdnsDiscovery({
  required LanSyncDiscoveryConfig discoveryConfig,
  required LanSyncDeviceConfig deviceConfig,
  DiscoveredDeviceDirectory? directory,
  NetworkMonitor? monitor,
  LanSyncLogger? logger,
}) => BonsoirDeviceDiscovery(
  discoveryConfig: discoveryConfig,
  deviceConfig: deviceConfig,
  directory: directory,
  monitor: monitor,
  logger: logger,
);
