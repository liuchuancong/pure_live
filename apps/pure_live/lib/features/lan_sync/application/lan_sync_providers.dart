import 'dart:async' show StreamSubscription, Timer, unawaited;
import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_lan_sync/live_lan_sync.dart';
import 'package:live_sites/live_sites.dart' show LiveRoom;
import 'package:live_storage/live_storage.dart' show StoragePrefs, StorageStores;
import 'package:pure_live/app/logging/app_log.dart';
import 'package:pure_live/features/backup/panes/backup_actions.dart' show includeSecretsAllowed;
import 'package:pure_live/features/lan_sync/data/drift_lan_sync_store.dart';
import 'package:pure_live/features/lan_sync/data/favorites_sync_adapter.dart';
import 'package:pure_live/features/lan_sync/data/scope_sources.dart';
import 'package:pure_live/features/lan_sync/data/scoped_sync.dart';
import 'package:pure_live/features/lan_sync/data/secure_credential_store.dart';
import 'package:pure_live/features/lan_sync/data/sync_scopes.dart';
import 'package:pure_live/features/lan_sync/data/tls_identity_provider.dart';
import 'package:pure_live/modules/live/favorites/favorites.dart' show followRepositoryProvider;

/// The persisted settings of the feature (spec §6: configuration over
/// runtime state over page state). Lives in `StoragePrefs` under
/// `lan_sync.*`.
final class LanSyncSettings {
  /// The settings snapshot.
  const LanSyncSettings({
    required this.enabled,
    required this.deviceName,
    required this.conflictPolicy,
    required this.scopes,
  });

  /// The defaults: off, the hostname, last-writer-wins for the peer, every
  /// scope but the vault.
  factory LanSyncSettings.defaults() => LanSyncSettings(
    enabled: false,
    deviceName: Platform.localHostname,
    conflictPolicy: ConflictPolicy.preferRemote,
    scopes: LanSyncScope.defaults,
  );

  /// Whether the sync server, discovery and pairing are running.
  final bool enabled;

  /// This device's published name.
  final String deviceName;

  /// The conflict policy, for every scope.
  final ConflictPolicy conflictPolicy;

  /// What this device shares: the scopes it registers adapters for and
  /// asks a peer for. The vault rides only while the user's secrets switch
  /// is on, whatever this set says.
  final Set<LanSyncScope> scopes;

  /// The scopes that actually run: [scopes] minus the vault when the
  /// secrets switch is off.
  Set<LanSyncScope> get activeScopes => {
    for (final scope in scopes)
      if (scope != LanSyncScope.secrets || includeSecretsAllowed()) scope,
  };

  /// A copy with one field changed.
  LanSyncSettings copyWith({
    bool? enabled,
    String? deviceName,
    ConflictPolicy? conflictPolicy,
    Set<LanSyncScope>? scopes,
  }) => LanSyncSettings(
    enabled: enabled ?? this.enabled,
    deviceName: deviceName ?? this.deviceName,
    conflictPolicy: conflictPolicy ?? this.conflictPolicy,
    scopes: scopes ?? this.scopes,
  );
}

/// Reads the settings from `StoragePrefs`.
LanSyncSettings readLanSyncSettings() {
  final defaults = LanSyncSettings.defaults();
  final name = StoragePrefs.getString('lan_sync.deviceName') ?? '';
  final policy = StoragePrefs.getString('lan_sync.conflictPolicy');
  return LanSyncSettings(
    enabled: StoragePrefs.getBool('lan_sync.enabled') ?? defaults.enabled,
    deviceName: name.isNotEmpty ? name : defaults.deviceName,
    conflictPolicy:
        ConflictPolicy.values.where((candidate) => candidate.name == policy).firstOrNull ?? defaults.conflictPolicy,
    scopes: lanSyncScopesFrom(StoragePrefs.getStringList('lan_sync.scopes')),
  );
}

/// Writes the settings back to `StoragePrefs`.
Future<void> writeLanSyncSettings(LanSyncSettings settings) async {
  await StoragePrefs.setBool('lan_sync.enabled', settings.enabled);
  await StoragePrefs.setString('lan_sync.deviceName', settings.deviceName);
  await StoragePrefs.setString('lan_sync.conflictPolicy', settings.conflictPolicy.name);
  await StoragePrefs.setStringList('lan_sync.scopes', [for (final scope in settings.scopes) scope.id]);
}

/// The settings notifier: persists on every change; the runtime provider
/// watches it and starts or stops the machinery.
final class LanSyncSettingsController extends Notifier<LanSyncSettings> {
  @override
  LanSyncSettings build() => readLanSyncSettings();

  /// Turns the whole feature on or off.
  Future<void> setEnabled({required bool value}) async {
    state = state.copyWith(enabled: value);
    await writeLanSyncSettings(state);
  }

  /// Renames this device.
  Future<void> setDeviceName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    state = state.copyWith(deviceName: trimmed);
    await writeLanSyncSettings(state);
  }

  /// Chooses the conflict policy.
  Future<void> setConflictPolicy(ConflictPolicy policy) async {
    state = state.copyWith(conflictPolicy: policy);
    await writeLanSyncSettings(state);
  }

  /// Shares or stops sharing one scope.
  Future<void> setScope(LanSyncScope scope, {required bool shared}) async {
    final next = {...state.scopes};
    if (shared) {
      next.add(scope);
    } else {
      next.remove(scope);
    }
    state = state.copyWith(scopes: next);
    await writeLanSyncSettings(state);
  }
}

/// The settings provider.
final lanSyncSettingsProvider = NotifierProvider<LanSyncSettingsController, LanSyncSettings>(
  LanSyncSettingsController.new,
);

/// The engine's logger over the app's log tree.
final LanSyncLogger lanSyncLogger = LanSyncLogger(appLog.forCategory('lan_sync'));

/// The identity, generated on first use and stable afterwards.
final tlsIdentityProvider = FutureProvider<TlsIdentity>((ref) async {
  final settings = ref.watch(lanSyncSettingsProvider);
  return await DeviceTlsIdentity.ensure(
    credentials: const SecureVaultCredentialStore(),
    deviceName: settings.deviceName,
  );
});

/// The sync store over the app's database namespaces.
final lanSyncStoreProvider = FutureProvider<DriftLanSyncStore>((ref) => DriftLanSyncStore.open());

/// The snapshot ledger the change detector and the adapters share.
final lanSyncLedgerProvider = FutureProvider<ScopeSnapshotLedger>(
  (ref) async => ScopeSnapshotLedger(await StorageStores.instance.openStore('lan_sync_snapshots')),
);

/// Everything running while the feature is on: engine, server, pairing,
/// discovery, the change detector and the network watch. Built when the
/// switch turns on; disposed when it turns off or the device name or the
/// shared scopes change (the device config and the adapters are bound at
/// construction).
final class LanSyncRuntime {
  LanSyncRuntime._({
    required this.store,
    required this.engine,
    required this.server,
    required this.responder,
    required this.discovery,
    required this.directory,
    required this.detector,
    required this.scopes,
    required this.deviceId,
    required this.port,
  });

  final LanSyncStore store;
  final SyncEngine engine;
  final LanSyncHttpServer server;
  final PairingResponder responder;
  final DeviceDiscovery discovery;

  /// The deduplicated device list discovery feeds; the UI reads it.
  final DiscoveredDeviceDirectory directory;

  /// Finds local edits of the hook-less scopes right before a sync.
  final LocalChangeDetector detector;

  /// The scopes this runtime serves.
  final Set<LanSyncScope> scopes;

  final String deviceId;
  final int port;

  final Map<String, LanSyncHttpClient> _clients = <String, LanSyncHttpClient>{};
  final Map<String, ({String host, int port})> _addresses = <String, ({String host, int port})>{};
  final List<StreamSubscription<void>> _subscriptions = <StreamSubscription<void>>[];
  final NetworkMonitor _network = NetworkMonitor();
  Timer? _autoSyncTimer;
  Timer? _periodicTimer;

  /// The local device id every change carries.
  String get localDeviceId => engine.localDeviceId;

  /// The scope ids on the wire.
  Set<String> get scopeIds => {for (final scope in scopes) scope.id};

  /// The trust records' editor: grants and revocation.
  DeviceTrustService get trustService =>
      DeviceTrustService(store: store, credentials: const SecureVaultCredentialStore());

  /// Records a local favorite follow/refresh after the repository write
  /// committed.
  Future<void> recordFavoriteUpsert(String identityKey, Map<String, Object?> payload) async {
    await engine.recordLocalChange(scope: 'favorites', entityType: 'favorite', entityId: identityKey, payload: payload);
  }

  /// Records a local favorite removal after the repository write committed.
  Future<void> recordFavoriteDelete(String identityKey) async {
    await engine.recordLocalChange(
      scope: 'favorites',
      entityType: 'favorite',
      entityId: identityKey,
      operation: SyncOperation.delete,
    );
  }

  /// Remembers where [deviceId] was seen, from discovery or a manual entry,
  /// so a sync can reach it.
  void rememberAddress(String deviceId, {required String host, required int port}) =>
      _addresses[deviceId] = (host: host, port: port);

  /// Follows the discovery stream, remembering every peer's newest address.
  /// Without this a freshly paired device is trusted but unreachable until
  /// someone re-reads the directory by hand.
  void watchDiscovery() {
    _subscriptions.add(
      discovery.discoveredDevices.listen((device) {
        if (device.deviceId == deviceId) return;
        if (device.addresses.isEmpty || device.port == null) return;
        rememberAddress(device.deviceId, host: device.addresses.first, port: device.port!);
      }),
    );
  }

  /// Restarts the mDNS browse and the local registration whenever the
  /// network changes under the app — a Wi‑Fi switch, a cable in or out —
  /// so the nearby list heals on its own instead of waiting for a toggle.
  Future<void> watchNetwork() async {
    _subscriptions.add(
      _network.changes.listen((_) {
        unawaited(() async {
          try {
            await discovery.stop();
            await discovery.start();
            await discovery.registerLocalService(deviceId: deviceId, port: port);
          } on Object catch (error) {
            lanSyncLogger
                .area(LanSyncLogArea.discovery)
                .warning('discovery restart after a network change failed: $error');
          }
        }());
      }),
    );
    await _network.start();
  }

  /// Runs a sync against every paired device every [interval] while the
  /// feature is on, so edits of the hook-less scopes (history, settings…)
  /// travel without anyone pressing the button.
  void startPeriodicSync({Duration interval = const Duration(minutes: 1)}) {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(interval, (_) => unawaited(_syncAllPaired()));
  }

  /// Schedules one automatic sync against every paired device, debounced:
  /// local edits inside the window collapse into a single run (spec §6.6's
  /// auto-sync, off unless the host turns it on — PureLive turns it on
  /// while the feature switch is on).
  void scheduleAutoSync({Duration delay = const Duration(seconds: 3)}) {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer(delay, () {
      _autoSyncTimer = null;
      unawaited(_syncAllPaired());
    });
  }

  Future<void> _syncAllPaired() async {
    for (final trust in await store.loadDeviceTrusts()) {
      if (trust.revoked) continue;
      // synchronizeWith answers null when no address is known (the device
      // is offline); the next scheduled run retries it.
      await synchronizeWith(trust.deviceId);
    }
  }

  /// Runs one bidirectional sync with the device [deviceId], building (and
  /// caching) the pinned, signed client from the trust record. Requires a
  /// remembered address — the discovered or manually entered one — and a
  /// valid pairing; answers null otherwise. The hook-less scopes are
  /// diffed into the log first.
  Future<SyncTask?> synchronizeWith(String deviceId) async {
    final address = _addresses[deviceId];
    if (address == null) return null;
    var client = _clients[deviceId];
    if (client == null) {
      final trust = await store.deviceTrust(deviceId);
      if (trust == null || trust.revoked) return null;
      client = LanSyncHttpClient(
        localDeviceId: localDeviceId,
        peerDeviceId: deviceId,
        host: address.host,
        port: address.port,
        credentials: const SecureVaultCredentialStore(),
        pinnedPeerFingerprint: trust.keyFingerprint,
        logger: lanSyncLogger,
      );
      _clients[deviceId] = client;
    }
    try {
      await detector.recordChanges(scopes.where((scope) => scope != LanSyncScope.favorites));
    } on Object catch (error) {
      lanSyncLogger.area(LanSyncLogArea.sync).warning('local change detection failed: $error');
    }
    return await engine.synchronize(channel: HttpPeerSyncChannel(client), scopes: scopeIds);
  }

  /// The conflicts waiting for the user.
  Future<List<SyncConflict>> pendingConflicts() => engine.pendingConflicts();

  /// Settles one conflict the user's way.
  Future<void> resolveConflict(String key, {required bool keepLocal}) =>
      engine.resolveConflict(key, keepLocal ? const UseLocalResolution() : const UseRemoteResolution());

  /// Stops serving and releases everything.
  Future<void> dispose() async {
    _autoSyncTimer?.cancel();
    _periodicTimer?.cancel();
    await _network.stop();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    for (final client in _clients.values) {
      await client.dispose();
    }
    _clients.clear();
    await discovery.dispose();
    await server.dispose();
    await responder.dispose();
    await engine.dispose();
  }
}

/// The runtime, or null while the feature is off. Disposal stops the server
/// and discovery.
final lanSyncRuntimeProvider = FutureProvider<LanSyncRuntime?>((ref) async {
  final settings = ref.watch(lanSyncSettingsProvider);
  if (!settings.enabled) return null;
  final scopes = settings.activeScopes;

  final store = await ref.watch(lanSyncStoreProvider.future);
  final ledger = await ref.watch(lanSyncLedgerProvider.future);
  final identity = await ref.watch(tlsIdentityProvider.future);
  final deviceId = await LocalDeviceIdentity.ensure(store);

  LanSyncDeviceConfig deviceConfig() => LanSyncDeviceConfig(
    deviceId: deviceId,
    deviceName: settings.deviceName,
    platform: Platform.operatingSystem,
    appVersion: '4',
  );

  final responder = PairingResponder(
    store: store,
    credentials: const SecureVaultCredentialStore(),
    security: const LanSyncSecurityConfig(),
    deviceConfig: deviceConfig(),
    tlsIdentity: identity,
    logger: lanSyncLogger,
  );
  final engine = SyncEngine(
    store: store,
    localDeviceId: deviceId,
    adapters: [
      if (scopes.contains(LanSyncScope.favorites))
        FavoritesSyncAdapter(
          openRepository: () async {
            final repository = await ref.watch(followRepositoryProvider.future);
            return (
              upsert: (String identityKey, Map<String, Object?> payload) async {
                await repository.add(LiveRoom.fromJson(payload));
              },
              delete: (String identityKey) async {
                await repository.remove(identityKey);
              },
            );
          },
        ),
      for (final scope in scopes)
        if (scope != LanSyncScope.favorites)
          ScopedSyncAdapter(syncScope: scope, ledger: ledger, open: () => openScopeSource(ref, scope)),
    ],
    options: LanSyncOptions(scopeConflictPolicies: {for (final scope in scopes) scope.id: settings.conflictPolicy}),
    logger: lanSyncLogger,
  );
  final server = LanSyncHttpServer(
    store: store,
    credentials: const SecureVaultCredentialStore(),
    deviceConfig: deviceConfig(),
    serverConfig: const LanSyncServerConfig(),
    tlsIdentity: identity,
    securityConfig: const LanSyncSecurityConfig(),
    pairingResponder: responder,
    logger: lanSyncLogger,
  );
  await server.start();
  engine.attachTo(server);

  const discoveryConfig = LanSyncDiscoveryConfig();
  final directory = DiscoveredDeviceDirectory(ttl: discoveryConfig.serviceTtl);
  final discovery = createMdnsDiscovery(
    discoveryConfig: discoveryConfig,
    deviceConfig: deviceConfig(),
    directory: directory,
    logger: lanSyncLogger,
  );
  await discovery.start();
  // No explicit TXT: the adapter derives the five public facts from the
  // device configuration. A literal empty map here once broke peer
  // discovery — peers filter services without a device id.
  await discovery.registerLocalService(deviceId: deviceId, port: server.port ?? 0);

  final detector = LocalChangeDetector.into(
    engine,
    ledger: ledger,
    currentOf: (scope) async {
      final source = await openScopeSource(ref, scope);
      return source == null ? const {} : await source.current();
    },
  );

  final runtime = LanSyncRuntime._(
    store: store,
    engine: engine,
    server: server,
    responder: responder,
    discovery: discovery,
    directory: directory,
    detector: detector,
    scopes: scopes,
    deviceId: deviceId,
    port: server.port ?? 0,
  )..watchDiscovery();
  await runtime.watchNetwork();
  runtime.startPeriodicSync();
  ref.onDispose(runtime.dispose);
  return runtime;
});

/// Incoming pairing requests while a window is open; never emits while the
/// feature is off.
final incomingPairingsProvider = StreamProvider<IncomingPairing>((ref) {
  final runtime = switch (ref.watch(lanSyncRuntimeProvider)) {
    AsyncData(:final value) => value,
    _ => null,
  };
  if (runtime == null) return const Stream<IncomingPairing>.empty();
  return runtime.responder.requests;
});

/// The conflicts waiting for the user, re-read on every engine event.
final lanSyncConflictsProvider = StreamProvider<List<SyncConflict>>((ref) async* {
  final runtime = await ref.watch(lanSyncRuntimeProvider.future);
  if (runtime == null) {
    yield const [];
    return;
  }
  yield await runtime.pendingConflicts();
  await for (final _ in runtime.engine.events) {
    yield await runtime.pendingConflicts();
  }
});

/// A favorite room's sync payload: the room's full JSON, exactly what the
/// repository stores.
Map<String, Object?> favoritePayload(LiveRoom room) => room.toJson();
