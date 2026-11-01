import 'package:live_lan_sync/src/config/device_config.dart';
import 'package:live_lan_sync/src/config/discovery_config.dart';
import 'package:live_lan_sync/src/config/logging_config.dart';
import 'package:live_lan_sync/src/config/security_config.dart';
import 'package:live_lan_sync/src/config/server_config.dart';
import 'package:live_lan_sync/src/config/synchronization_config.dart';
import 'package:live_lan_sync/src/config/transfer_config.dart';
import 'package:live_lan_sync/src/domain/conflict/conflict.dart';

/// The engine's whole configuration, validated as one unit.
///
/// A host builds this once at composition time and hands it to the client.
/// `validate` collects the problems of every area so the host fixes them in
/// one pass; a failed validation must never be applied partially.
///
/// Some areas accept runtime updates (device name, sync scope set, log
/// level, concurrency limits) while others bind at start-up (listening
/// port, service type, security parameters). The client's `updateConfig`
/// contract distinguishes the two and never silently ignores a change.
final class LanSyncConfig {
  /// The whole configuration.
  const new({
    required this.device,
    this.discovery = const LanSyncDiscoveryConfig(),
    this.server = const LanSyncServerConfig(),
    this.security = const LanSyncSecurityConfig(),
    this.synchronization = const LanSyncOptions(),
    this.transfer = const LanSyncTransferConfig(),
    this.logging = const LanSyncLoggingConfig(),
  });

  /// The identity this device publishes.
  final LanSyncDeviceConfig device;

  /// How peers are discovered.
  final LanSyncDiscoveryConfig discovery;

  /// How this device serves peers.
  final LanSyncServerConfig server;

  /// How strictly peers are authenticated.
  final LanSyncSecurityConfig security;

  /// How data moves and what happens on collisions.
  final LanSyncOptions synchronization;

  /// How files travel.
  final LanSyncTransferConfig transfer;

  /// What the engine logs.
  final LanSyncLoggingConfig logging;

  /// The default conflict policy every scope inherits unless its adapter
  /// narrows it. Exposed here for engine plumbing that runs before it
  /// reaches a scope.
  ConflictPolicy get effectiveConflictPolicy => synchronization.defaultConflictPolicy;

  /// Every problem with the configuration across all areas, human-readable
  /// and prefixed by the area's name. An empty list means usable as is.
  List<String> validate() => [
    for (final problem in <List<String>>[
      device.validate(),
      discovery.validate(),
      server.validate(),
      security.validate(),
      synchronization.validate(),
      transfer.validate(),
      logging.validate(),
    ])
      ...problem,
  ];
}
