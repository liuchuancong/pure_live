import 'dart:async' show StreamController, StreamSubscription, unawaited;

import 'package:bonsoir/bonsoir.dart' show BonsoirBroadcast, BonsoirDiscovery;
import 'package:bonsoir_platform_interface/bonsoir_platform_interface.dart'
    show
        BonsoirBroadcastEvent,
        BonsoirDiscoveryEvent,
        BonsoirDiscoveryServiceLostEvent,
        BonsoirDiscoveryServiceResolvedEvent,
        BonsoirDiscoveryServiceUpdatedEvent,
        BonsoirService;
import 'package:live_lan_sync/src/config/config.dart' show LanSyncDeviceConfig, LanSyncDiscoveryConfig;
import 'package:live_lan_sync/src/discovery/device_directory.dart' show DiscoveredDeviceDirectory;
import 'package:live_lan_sync/src/discovery/device_discovery.dart' show DeviceDiscovery;
import 'package:live_lan_sync/src/domain/device/device.dart' show SyncDevice;
import 'package:live_lan_sync/src/domain/errors/errors.dart' show LanSyncError, LanSyncErrorCategory;
import 'package:live_lan_sync/src/infrastructure/discovery/bonsoir/bonsoir_service_mapping.dart'
    show BonsoirServiceMapping, LanSyncTxtKeys;
import 'package:live_lan_sync/src/infrastructure/discovery/network_monitor.dart' show NetworkMonitor;
import 'package:live_lan_sync/src/logging/logging.dart';

/// The mDNS / DNS-SD implementation of [DeviceDiscovery] over Bonsoir.
///
/// Bonsoir is a replaceable detail of this class and leaks nowhere else:
/// the package's public surface only ever exposes [DeviceDiscovery]. The
/// adapter registers this device under the configured service type, browses
/// for peers, feeds resolved services through the TXT mapping into the
/// directory, and restarts browsing when the network monitor reports an
/// interface change (Wi-Fi switch, dock, VPN toggle).
final class BonsoirDeviceDiscovery implements DeviceDiscovery {
  /// A discovery adapter over Bonsoir.
  ///
  /// [monitor] is optional: without one, a network change is noticed on the
  /// next browse failure instead of proactively. [directory] defaults to a
  /// privately owned directory; share one across subsystems by passing it
  /// in (the caller then also owns its disposal).
  new({
    required this.discoveryConfig,
    required this.deviceConfig,
    DiscoveredDeviceDirectory? directory,
    this.monitor,
    LanSyncLogger? logger,
  }) : _log = logger?.area(LanSyncLogArea.discovery) ?? LanSyncLogger.silent.area(LanSyncLogArea.discovery),
       _directory = directory ?? DiscoveredDeviceDirectory(ttl: discoveryConfig.serviceTtl),
       _ownsDirectory = directory == null;

  /// The discovery parameters this adapter binds at construction.
  final LanSyncDiscoveryConfig discoveryConfig;

  /// The device facts this adapter publishes about this machine.
  final LanSyncDeviceConfig deviceConfig;

  /// The network-change source that restarts browsing; null disables the
  /// self-healing.
  final NetworkMonitor? monitor;

  final LanSyncLog _log;
  final DiscoveredDeviceDirectory _directory;
  final bool _ownsDirectory;

  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;
  StreamSubscription<BonsoirBroadcastEvent>? _broadcastEvents;
  StreamSubscription<BonsoirDiscoveryEvent>? _discoveryEvents;
  StreamSubscription<void>? _networkChanges;
  final StreamController<Object> _errors = StreamController<Object>.broadcast();
  bool _registered = false;
  bool _disposed = false;

  /// The directory this adapter feeds; manual devices are added here.
  DiscoveredDeviceDirectory get directory => _directory;

  @override
  bool get isRunning => _discovery != null && _discovery!.isReady && !_discovery!.isStopped;

  @override
  Stream<SyncDevice> get discoveredDevices => _directory.changes;

  @override
  Stream<Object> get discoveryErrors => _errors.stream;

  /// The TXT keys this device publishes about itself, derived from the
  /// device configuration. Callers pair it with [registerLocalService].
  Map<String, String> get localTxt => BonsoirServiceMapping.localTxt(
    deviceId: deviceConfig.deviceId,
    protocolVersion: deviceConfig.protocolVersion,
    appVersion: deviceConfig.appVersion,
    platform: deviceConfig.platform,
    capabilities: deviceConfig.capabilities,
  );

  @override
  Future<void> start() async {
    _ensureAlive();
    if (_discovery != null) return;
    final discovery = BonsoirDiscovery(type: discoveryConfig.serviceType, printLogs: false);
    await discovery.initialize();
    await discovery.start();
    _discovery = discovery;
    _discoveryEvents = discovery.eventStream?.listen(
      _onDiscoveryEvent,
      onError: (Object error) => _reportError(error, code: 'discovery_event_failed'),
      cancelOnError: false,
    );
    unawaited(_subscribeNetworkMonitor());
  }

  @override
  Future<void> stop() async {
    _ensureAlive();
    await _discoveryEvents?.cancel();
    _discoveryEvents = null;
    await _discovery?.stop();
    _discovery = null;
  }

  @override
  Future<void> registerLocalService({
    required String deviceId,
    required int port,
    Map<String, String> txt = const <String, String>{},
  }) async {
    _ensureAlive();
    if (_registered) return;
    final service = BonsoirService(
      name: deviceConfig.deviceName,
      type: discoveryConfig.serviceType,
      port: port,
      // An empty map means the standard facts derived from the device
      // configuration — the five public fields peers filter by.
      attributes: txt.isEmpty ? localTxt : txt,
    );
    final broadcast = BonsoirBroadcast(service: service, printLogs: false);
    await broadcast.initialize();
    await broadcast.start();
    _broadcast = broadcast;
    _registered = true;
    _broadcastEvents = broadcast.eventStream?.listen(
      (_) {},
      onError: (Object error) => _reportError(error, code: 'registration_failed'),
      cancelOnError: false,
    );
  }

  @override
  Future<void> unregisterLocalService() async {
    _ensureAlive();
    if (!_registered) return;
    await _broadcastEvents?.cancel();
    _broadcastEvents = null;
    await _broadcast?.stop();
    _broadcast = null;
    _registered = false;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _networkChanges?.cancel();
    _networkChanges = null;
    await _discoveryEvents?.cancel();
    _discoveryEvents = null;
    await _broadcastEvents?.cancel();
    _broadcastEvents = null;
    await _discovery?.stop();
    _discovery = null;
    await _broadcast?.stop();
    _broadcast = null;
    _registered = false;
    await _errors.close();
    if (_ownsDirectory) {
      await _directory.dispose();
    }
  }

  /// Restarts browsing when the network's interfaces change: mDNS binds are
  /// interface-scoped, so a Wi-Fi switch silently orphans the old browser.
  Future<void> _subscribeNetworkMonitor() async {
    final changes = monitor?.changes;
    if (changes == null || _networkChanges != null) return;
    await monitor!.start();
    _networkChanges = changes.listen((_) => unawaited(_restartBrowse()));
  }

  Future<void> _restartBrowse() async {
    if (_disposed || _discovery == null) return;
    _log.info('network changed; restarting discovery');
    await stop();
    await start();
  }

  void _onDiscoveryEvent(BonsoirDiscoveryEvent event) {
    switch (event) {
      case BonsoirDiscoveryServiceResolvedEvent(:final service):
      case BonsoirDiscoveryServiceUpdatedEvent(:final service):
        final device = BonsoirServiceMapping.deviceFrom(service);
        if (device == null) {
          // A foreign service on the same type: not ours to list.
          return;
        }
        _log.debug('peer seen', fields: {'device': device.deviceId, 'addresses': device.addresses.length});
        _directory.update(device);
      case BonsoirDiscoveryServiceLostEvent(:final service):
        final deviceId = service.attributes[LanSyncTxtKeys.deviceId];
        if (deviceId != null && deviceId.isNotEmpty) {
          _log.debug('peer lost', fields: {'device': deviceId});
          _directory.markOffline(deviceId);
        }
      default:
        break;
    }
  }

  void _reportError(Object error, {required String code}) {
    _log.warning('discovery failure', fields: {'code': code});
    if (_errors.isClosed) return;
    _errors.add(
      LanSyncError(
        category: LanSyncErrorCategory.discovery,
        code: code,
        message: 'LAN discovery reported a failure.',
        retryable: true,
        debugContext: error.toString(),
      ),
    );
  }

  void _ensureAlive() {
    if (_disposed) {
      throw StateError('BonsoirDeviceDiscovery has been disposed');
    }
  }
}
