import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:live_lan_sync/live_lan_sync.dart';

/// A business store for one scope, kept in memory: entity id → payload.
/// Records every operation it applied so tests can prove nothing was
/// applied twice.
class MemoryScopeAdapter implements LanSyncDataAdapter {
  new({
    this.scope = 'favorites',
    this.schemaVersion = 1,
    this.capabilities = const ScopeSyncCapabilities(
      supportsDelete: true,
      supportsBidirectional: true,
      supportsMerge: false,
    ),
  });

  @override
  final String scope;

  @override
  final int schemaVersion;

  @override
  final ScopeSyncCapabilities capabilities;

  /// The business data: entity id → its current state.
  final Map<String, Map<String, Object?>> entities = <String, Map<String, Object?>>{};

  /// Every operation applied, in order.
  final List<String> appliedOperationIds = <String>[];

  /// Entities whose changes this adapter refuses, for failure tests.
  final Set<String> refuseEntityIds = <String>{};

  /// When set, the next call throws, as a broken business store would.
  bool failNextCall = false;

  /// How [resolveConflict] decides; escalates when unset.
  SyncConflictResolution Function(SyncChange local, SyncChange remote)? resolver;

  @override
  Future<SyncApplyResult> applyChanges({required List<SyncChange> changes}) async {
    if (failNextCall) {
      failNextCall = false;
      throw StateError('business store unavailable');
    }
    var applied = 0;
    final failures = <SyncChangeFailure>[];
    for (final change in changes) {
      if (refuseEntityIds.contains(change.entityId)) {
        failures.add(SyncChangeFailure(change: change, reason: 'refused by the test adapter'));
        continue;
      }
      appliedOperationIds.add(change.operationId);
      if (change.isTombstone) {
        entities.remove(change.entityId);
      } else {
        entities[change.entityId] = Map<String, Object?>.of(change.payload);
      }
      applied++;
    }
    return SyncApplyResult(appliedCount: applied, failures: failures);
  }

  @override
  Future<SyncConflictResolution> resolveConflict({required SyncChange local, required SyncChange remote}) async =>
      resolver?.call(local, remote) ?? const EscalateResolution();
}

/// A [PeerSyncChannel] that calls another engine's handlers in-process,
/// with a JSON round trip each way so only wire-safe data passes. Counts
/// calls per route and can fail chosen calls.
final class LoopbackChannel implements PeerSyncChannel {
  new({required this.peer, required this.callerId});

  /// The engine on the other end.
  final SyncEngine peer;

  /// The calling device's id, as the server would have authenticated it.
  final String callerId;

  /// Calls made so far, per route.
  final Map<String, int> calls = <String, int>{};

  /// Called before each request; throwing fails that request.
  void Function(String route, int callNumber)? beforeCall;

  @override
  String get peerDeviceId => peer.localDeviceId;

  @override
  Future<Map<String, Object?>> call(String route, Map<String, Object?> body) async {
    final number = calls[route] = (calls[route] ?? 0) + 1;
    beforeCall?.call(route, number);
    final request = PeerRequest(senderDeviceId: callerId, path: route, body: _wire(body));
    final answer = switch (route) {
      'manifest/exchange' => await peer.handleManifest(request),
      'changes/pull' => await peer.handlePull(request),
      'changes/push' => await peer.handlePush(request),
      'changes/ack' => await peer.handleAck(request),
      _ => throw StateError('unknown route $route'),
    };
    return _wire(answer);
  }

  static Map<String, Object?> _wire(Map<String, Object?> json) =>
      (jsonDecode(jsonEncode(json)) as Map<Object?, Object?>).cast<String, Object?>();
}
