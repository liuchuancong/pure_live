import 'dart:async' show Completer, StreamController;
import 'dart:convert' show jsonEncode, utf8;
import 'dart:math' show Random, max, min;

import 'package:live_lan_sync/src/adapter/adapter.dart' show LanSyncDataAdapter, SyncApplyResult;
import 'package:live_lan_sync/src/config/config.dart' show LanSyncOptions;
import 'package:live_lan_sync/src/domain/conflict/conflict.dart'
    show
        ConflictPolicy,
        EscalateResolution,
        KeepBothResolution,
        MergedResolution,
        SyncConflict,
        SyncConflictResolution,
        UseLocalResolution,
        UseRemoteResolution,
        VersionRelation,
        VersionVector;
import 'package:live_lan_sync/src/domain/device/device.dart' show DeviceTrust;
import 'package:live_lan_sync/src/domain/errors/errors.dart' show LanSyncError, LanSyncErrorCategory;
import 'package:live_lan_sync/src/domain/events/lan_sync_event.dart'
    show LanSyncEvent, SyncConflictDetected, SyncConflictResolved, SyncConflictSuperseded;
import 'package:live_lan_sync/src/domain/sync/sync.dart'
    show
        LoggedChange,
        SyncChange,
        SyncCursor,
        SyncDirection,
        SyncManifest,
        SyncOperation,
        SyncTask,
        SyncTaskStage,
        SyncTaskStatus;
import 'package:live_lan_sync/src/logging/logging.dart' show LanSyncLog, LanSyncLogArea, LanSyncLogger;
import 'package:live_lan_sync/src/store/store.dart' show LanSyncStore;
import 'package:live_lan_sync/src/sync/batch_applier.dart' show AppliedBatch, BatchApplier;
import 'package:live_lan_sync/src/sync/peer_sync_channel.dart' show PeerSyncChannel, SyncCancellation;
import 'package:live_lan_sync/src/transport/lan_sync_http_server.dart' show LanSyncHttpServer, PeerRequest;
import 'package:live_log/live_log.dart' show LogLevel;

/// The incremental sync engine (spec §10): one change log per device,
/// followed by peers through per-(peer, scope) cursors.
///
/// **Locally**, [recordLocalChange] appends a change with the entity's
/// version vector advanced for this device.
///
/// **As a server** ([attachTo]), the engine answers four routes for paired
/// devices: `manifest/exchange` (what each scope offers this peer),
/// `changes/pull` (a batch of the log after a sequence), `changes/push` (a
/// batch of the peer's log, applied here) and `changes/ack` (how far the
/// peer has applied this device's log).
///
/// **As a client**, [synchronize] runs one task against one peer: manifests
/// first, then per scope a pull loop and/or a push loop in bounded batches.
/// A batch is committed atomically before its cursor moves, so an
/// interrupted task resumes exactly where it stopped: nothing committed is
/// lost and nothing is applied twice.
///
/// Grants are checked on both ends of every flow, from each holder's side:
/// data leaves a device only for a peer granted *read*, and enters a device
/// only from a peer granted *write* (spec §9.4).
final class SyncEngine {
  /// An engine for this device.
  ///
  /// Throws a [LanSyncError] with `configuration` when two adapters claim
  /// the same scope.
  new({
    required this.store,
    required this.localDeviceId,
    required Iterable<LanSyncDataAdapter> adapters,
    this.options = const LanSyncOptions(),
    LanSyncLogger? logger,
    DateTime Function()? now,
    Random? random,
    Future<void> Function(Duration delay)? sleep,
  }) : _log = logger?.area(LanSyncLogArea.sync) ?? LanSyncLogger.silent.area(LanSyncLogArea.sync),
       _now = now ?? DateTime.now,
       _random = random ?? Random.secure(),
       _sleep = sleep ?? Future<void>.delayed {
    for (final adapter in adapters) {
      final capabilities = adapter.capabilities;
      if (capabilities.supportedPolicies.contains(ConflictPolicy.merge) && !capabilities.supportsMerge) {
        throw LanSyncError(
          category: LanSyncErrorCategory.configuration,
          code: 'merge_without_support',
          message: 'The scope "${adapter.scope}" offers the merge policy without supporting merges.',
        );
      }
      if (_adapters.containsKey(adapter.scope)) {
        throw LanSyncError(
          category: LanSyncErrorCategory.configuration,
          code: 'scope_registered_twice',
          message: 'Two adapters claim the scope "${adapter.scope}".',
        );
      }
      _adapters[adapter.scope] = adapter;
    }
  }

  /// Where the change log, cursors, tasks and conflicts live.
  final LanSyncStore store;

  /// This device's id; local changes carry it as their origin.
  final String localDeviceId;

  /// Batch sizes, retries and direction policy.
  final LanSyncOptions options;

  final LanSyncLog _log;

  final Map<String, LanSyncDataAdapter> _adapters = <String, LanSyncDataAdapter>{};
  final DateTime Function() _now;
  final Random _random;
  final Future<void> Function(Duration) _sleep;
  final Map<String, Future<void>> _scopeLocks = <String, Future<void>>{};
  final StreamController<SyncTask> _taskUpdates = StreamController<SyncTask>.broadcast();
  final StreamController<LanSyncEvent> _events = StreamController<LanSyncEvent>.broadcast();
  late final BatchApplier _applier = BatchApplier(store: store, localDeviceId: localDeviceId, now: _now);

  /// Every task state change, as the task record now stands.
  Stream<SyncTask> get taskUpdates => _taskUpdates.stream;

  /// Conflict detections and settlements as they happen (spec §17). The
  /// store, not this stream, is the record of what is still open.
  Stream<LanSyncEvent> get events => _events.stream;

  /// The scopes this device can sync.
  Set<String> get scopes => _adapters.keys.toSet();

  /// Records a change this device made, right after the business write
  /// committed. The entity's version vector advances by one for this
  /// device; an upsert's [payload] is the entity's full state and must be
  /// plain JSON.
  ///
  /// Throws a [LanSyncError] with `dataValidation` for an unknown scope,
  /// empty identifiers, a delete the scope does not support, or a payload
  /// that is not JSON.
  Future<LoggedChange> recordLocalChange({
    required String scope,
    required String entityType,
    required String entityId,
    SyncOperation operation = SyncOperation.upsert,
    Map<String, Object?> payload = const <String, Object?>{},
  }) {
    final adapter = _adapterFor(scope);
    if (entityType.isEmpty ||
        entityId.isEmpty ||
        entityType.length > BatchApplier.maxIdentifierLength ||
        entityId.length > BatchApplier.maxIdentifierLength) {
      throw const LanSyncError(
        category: LanSyncErrorCategory.dataValidation,
        code: 'entity_identifier_invalid',
        message: 'A change needs a non-empty entity type and id.',
      );
    }
    if (operation == SyncOperation.delete && !adapter.capabilities.supportsDelete) {
      throw LanSyncError(
        category: LanSyncErrorCategory.dataValidation,
        code: 'delete_unsupported',
        message: 'The scope "$scope" does not sync deletes.',
      );
    }
    try {
      jsonEncode(payload);
    } on Object {
      throw const LanSyncError(
        category: LanSyncErrorCategory.dataValidation,
        code: 'payload_not_json',
        message: 'A change payload must be plain JSON.',
      );
    }
    return _exclusive(scope, () async {
      final latest = await store.latestChange(scope: scope, entityId: entityId);
      final change = SyncChange(
        operationId: '$localDeviceId/${_newId()}',
        scope: scope,
        entityType: entityType,
        entityId: entityId,
        originDeviceId: localDeviceId,
        operation: operation,
        schemaVersion: adapter.schemaVersion,
        revision: await _pruned((latest?.change.revision ?? const VersionVector.empty()).incremented(localDeviceId)),
        createdAt: _now().toUtc(),
        payload: operation == SyncOperation.delete ? const <String, Object?>{} : payload,
      );
      return await store.recordLocalChange(change);
    });
  }

  /// Registers the engine's routes on [server].
  void attachTo(LanSyncHttpServer server) {
    server
      ..route('POST', 'manifest/exchange', handleManifest)
      ..route('POST', 'changes/pull', handlePull)
      ..route('POST', 'changes/push', handlePush)
      ..route('POST', 'changes/ack', handleAck);
  }

  /// `manifest/exchange`: for each requested scope this device syncs, its
  /// schema version, log reach, and what the requester may do with it.
  Future<Map<String, Object?>> handleManifest(PeerRequest request) async {
    final trust = await _trustOf(request.senderDeviceId);
    final answers = <Map<String, Object?>>[];
    for (final item in _list(request.body['scopes'])) {
      final scope = _string(_map(item), 'scope');
      final adapter = _adapters[scope];
      if (adapter == null) continue;
      answers.add(
        SyncManifest(
          scope: scope,
          schemaVersion: adapter.schemaVersion,
          latestSequence: await store.latestSequence(scope: scope),
          canRead: trust.canAcceptSync && trust.allowsRead(scope),
          canWrite: trust.canAcceptSync && trust.allowsWrite(scope) && adapter.capabilities.supportsBidirectional,
        ).toJson(),
      );
    }
    return <String, Object?>{'scopes': answers};
  }

  /// `changes/pull`: a bounded batch of this device's log after a sequence,
  /// without the requester's own changes.
  Future<Map<String, Object?>> handlePull(PeerRequest request) async {
    final sender = request.senderDeviceId;
    final scope = _string(request.body, 'scope');
    _adapterFor(scope);
    final trust = await _trustOf(sender);
    if (!trust.canAcceptSync || !trust.allowsRead(scope)) {
      throw _denied(scope, 'read');
    }
    final after = _int(request.body, 'after', atLeast: 0);
    final limit = (_optionalInt(request.body, 'limit') ?? options.batchSize).clamp(1, options.batchSize);
    final maxBytes = (_optionalInt(request.body, 'maxBytes') ?? options.maxBatchBytes)
        .clamp(_minBatchBytes, max(_minBatchBytes, options.maxBatchBytes))
        .toInt();
    final scanned = await store.changesAfter(scope: scope, afterSequence: after, limit: limit);
    final page = _page(scanned, start: after, exclude: sender, maxBytes: maxBytes);
    final latest = await store.latestSequence(scope: scope);
    return <String, Object?>{
      'changes': [for (final entry in page.changes) entry.toJson()],
      'through': page.through,
      'hasMore': page.through < latest,
      'latestSequence': latest,
    };
  }

  /// `changes/push`: applies a batch of the requester's log here.
  Future<Map<String, Object?>> handlePush(PeerRequest request) async {
    final sender = request.senderDeviceId;
    final scope = _string(request.body, 'scope');
    final adapter = _adapterFor(scope);
    final trust = await _trustOf(sender);
    if (!trust.canAcceptSync || !trust.allowsWrite(scope) || !adapter.capabilities.supportsBidirectional) {
      throw _denied(scope, 'write');
    }
    final after = _int(request.body, 'after', atLeast: 0);
    final through = _int(request.body, 'through', atLeast: after);
    final batch = _loggedChanges(request.body['changes'], sender);
    return await _exclusive(scope, () async {
      final cursor =
          await store.cursorFor(peerDeviceId: sender, scope: scope) ?? SyncCursor(peerDeviceId: sender, scope: scope);
      final applied = BatchApplier.sequenceOf(cursor.remoteCheckpoint);
      if (after > applied) {
        // The sender believes this device holds more of its log than it
        // does (a store restored from an older backup, say): rewind it.
        return <String, Object?>{'acknowledgedThrough': applied, 'rewound': true};
      }
      final outcome = await _applier.apply(
        peer: sender,
        scope: scope,
        adapter: adapter,
        batch: batch,
        after: after,
        through: through,
        cursor: cursor,
      );
      await _supersede(scope, outcome.appliedChanges);
      await _settle(scope, adapter, outcome.conflicts);
      return <String, Object?>{'acknowledgedThrough': outcome.handledThrough, ..._counts(outcome)};
    });
  }

  /// `changes/ack`: the requester has applied this device's log through a
  /// sequence; pushes to it resume from there.
  Future<Map<String, Object?>> handleAck(PeerRequest request) async {
    final sender = request.senderDeviceId;
    final scope = _string(request.body, 'scope');
    _adapterFor(scope);
    final trust = await _trustOf(sender);
    if (!trust.canAcceptSync) {
      throw _denied(scope, 'sync');
    }
    final through = _int(request.body, 'through', atLeast: 0);
    final acknowledged = min(through, await store.latestSequence(scope: scope));
    await _moveLocalCheckpoint(sender, scope, acknowledged, onlyForward: true);
    return <String, Object?>{'acknowledgedThrough': acknowledged};
  }

  /// Runs one sync task with the peer behind [channel] over [scopes].
  ///
  /// Never throws for sync failures: the returned (and persisted) task says
  /// how it ended — `completed`, `partiallyCompleted` with the per-scope
  /// problems in [SyncTask.error], `failed`, or `cancelled`. Progress is
  /// published on [taskUpdates] as it happens.
  Future<SyncTask> synchronize({
    required PeerSyncChannel channel,
    required Set<String> scopes,
    SyncDirection direction = SyncDirection.bidirectional,
    SyncCancellation? cancellation,
  }) async {
    final peer = channel.peerDeviceId;
    var task = SyncTask(
      taskId: _newId(),
      peerDeviceId: peer,
      direction: direction,
      scopes: scopes,
      status: SyncTaskStatus.connecting,
      stage: SyncTaskStage.connection,
      startedAt: _now().toUtc(),
    );
    await _publish(task);
    _log.info(
      'sync started',
      fields: {'task': task.taskId, 'device': peer, 'direction': direction.name, 'scopes': scopes.length},
    );
    final problems = <String>[];
    try {
      if (direction == SyncDirection.bidirectional && !options.bidirectionalAllowed) {
        throw const LanSyncError(
          category: LanSyncErrorCategory.configuration,
          code: 'bidirectional_disabled',
          message: 'Two-way sync is turned off on this device.',
        );
      }
      final trust = await store.deviceTrust(peer);
      if (trust == null || trust.revoked) {
        throw LanSyncError(
          category: LanSyncErrorCategory.authentication,
          code: 'peer_not_paired',
          message: 'The device is not paired, or the pairing was revoked.',
          deviceId: peer,
        );
      }
      task = task.progressed(status: SyncTaskStatus.negotiating, stage: SyncTaskStage.negotiation);
      await _publish(task);
      final manifests = await _exchangeManifests(channel, scopes);

      for (final scope in scopes) {
        _checkCancelled(cancellation);
        final adapter = _adapters[scope];
        final manifest = manifests[scope];
        if (adapter == null) {
          problems.add('$scope: this device does not sync it');
          continue;
        }
        if (manifest == null) {
          problems.add('$scope: the other device does not sync it');
          _log.child(scope).debug('scope skipped: the other device does not sync it');
          continue;
        }
        if (manifest.schemaVersion != adapter.schemaVersion) {
          problems.add('$scope: schema version ${adapter.schemaVersion} here, ${manifest.schemaVersion} there');
          continue;
        }
        if (direction != SyncDirection.push) {
          if (!trust.allowsWrite(scope)) {
            problems.add("$scope: this device does not accept the other device's data");
          } else if (!manifest.canRead) {
            problems.add('$scope: the other device does not share it with this device');
          } else {
            task = await _pull(channel, scope, adapter, manifest, task, problems, cancellation);
          }
        }
        if (direction != SyncDirection.pull) {
          if (!trust.allowsRead(scope)) {
            problems.add('$scope: this device does not share it with the other device');
          } else if (!manifest.canWrite) {
            problems.add("$scope: the other device does not accept this device's data");
          } else {
            task = await _push(channel, scope, task, problems, cancellation);
          }
        }
      }
      task = task.finished(
        status: problems.isEmpty ? SyncTaskStatus.completed : SyncTaskStatus.partiallyCompleted,
        at: _now().toUtc(),
        error: problems.isEmpty ? null : problems.join('; '),
      );
    } on _SyncCancelled {
      task = task.finished(status: SyncTaskStatus.cancelled, at: _now().toUtc(), error: 'Cancelled.');
      _log.info('sync cancelled', fields: {'task': task.taskId, 'device': peer});
    } on LanSyncError catch (error) {
      task = task.finished(status: SyncTaskStatus.failed, at: _now().toUtc(), error: '${error.code}: ${error.message}');
      _log.failure('sync failed', error, level: LogLevel.error, fields: {'task': task.taskId});
    } on Object catch (error) {
      task = task.finished(status: SyncTaskStatus.failed, at: _now().toUtc(), error: 'unknown: $error');
      _log.error('sync failed unexpectedly', fields: {'task': task.taskId}, error: error);
    }
    _log.info(
      'sync finished',
      fields: {
        'task': task.taskId,
        'status': task.status.name,
        'applied': task.completedChanges,
        if (task.error case final error?) 'problems': error.length,
      },
    );
    await _publish(task);
    return task;
  }

  /// Every conflict waiting for a decision.
  Future<List<SyncConflict>> pendingConflicts() => store.pendingConflicts();

  /// Settles the open conflict [key] with the user's [resolution]: the
  /// decision is applied through the adapter and written as a new version
  /// that follows both conflicting versions, so it propagates and every
  /// device adopts it instead of conflicting again.
  ///
  /// Throws a [LanSyncError] with `conflict` when [key] is unknown, when
  /// [resolution] escalates (no one is left to escalate to), or when the
  /// local version changed since the conflict was recorded
  /// (`conflict_outdated`: the record now shows the current local version —
  /// review it and decide again).
  Future<void> resolveConflict(String key, SyncConflictResolution resolution) async {
    final conflict = await store.conflict(key);
    if (conflict == null) {
      throw LanSyncError(
        category: LanSyncErrorCategory.conflict,
        code: 'conflict_unknown',
        message: 'The conflict is no longer open.',
        debugContext: key,
      );
    }
    if (resolution is EscalateResolution) {
      throw const LanSyncError(
        category: LanSyncErrorCategory.conflict,
        code: 'conflict_needs_decision',
        message: 'A conflict needs a decision to be settled.',
      );
    }
    await _exclusive(conflict.scope, () => _applyResolution(conflict, resolution, automatic: false));
  }

  /// Closes the task and event streams.
  Future<void> dispose() async {
    await _taskUpdates.close();
    await _events.close();
  }

  /// The policy [scope] applies here; one the adapter does not honour falls
  /// back to manual.
  ConflictPolicy _effectivePolicy(String scope, LanSyncDataAdapter adapter) {
    final policy = options.scopeConflictPolicies[scope] ?? options.defaultConflictPolicy;
    return adapter.capabilities.honours(policy) ? policy : ConflictPolicy.manual;
  }

  /// Drops open conflicts that a newly applied version settled — one that
  /// follows both conflicting versions, written by whichever device decided
  /// first.
  Future<void> _supersede(String scope, List<SyncChange> applied) async {
    for (final change in applied) {
      final pending = await store.conflict('$scope/${change.entityId}');
      if (pending == null) continue;
      if (_follows(change.revision, pending.local.revision) && _follows(change.revision, pending.remote.revision)) {
        await store.commitResolution(conflictKey: pending.key, changes: const []);
        _emit(SyncConflictSuperseded(conflict: pending));
      }
    }
  }

  static bool _follows(VersionVector later, VersionVector earlier) {
    final relation = later.compareTo(earlier);
    return relation == VersionRelation.ahead || relation == VersionRelation.equal;
  }

  /// Reports freshly recorded conflicts and settles those the scope's policy
  /// can decide. Runs under the scope lock, after the batch committed, so a
  /// crash here leaves the conflicts recorded — never lost.
  Future<void> _settle(String scope, LanSyncDataAdapter adapter, List<SyncConflict> conflicts) async {
    if (conflicts.isEmpty) return;
    final policy = _effectivePolicy(scope, adapter);
    final scopeLog = _log.child(scope);
    for (final conflict in conflicts) {
      _emit(SyncConflictDetected(conflict: conflict, policy: policy));
      scopeLog.warning('conflict detected', fields: {'entity': conflict.entityId, 'policy': policy.name});
      if (policy == ConflictPolicy.manual) continue;
      try {
        final resolution = switch (policy) {
          ConflictPolicy.preferLocal => const UseLocalResolution(),
          ConflictPolicy.preferRemote => const UseRemoteResolution(),
          ConflictPolicy.merge ||
          ConflictPolicy.keepBoth => await adapter.resolveConflict(local: conflict.local, remote: conflict.remote),
          ConflictPolicy.manual => const EscalateResolution(),
        };
        if (resolution is EscalateResolution) {
          scopeLog.info('conflict left for the user', fields: {'entity': conflict.entityId});
          continue;
        }
        await _applyResolution(conflict, resolution, automatic: true);
      } on LanSyncError catch (error) {
        scopeLog.failure(
          'automatic resolution failed; the conflict waits for the user',
          error,
          fields: {'entity': conflict.entityId},
        );
      } on Object catch (error) {
        scopeLog.error('automatic resolution failed unexpectedly', fields: {'entity': conflict.entityId}, error: error);
      }
    }
  }

  /// Writes [resolution] for [conflict]. Callers hold the scope lock.
  Future<void> _applyResolution(
    SyncConflict conflict,
    SyncConflictResolution resolution, {
    required bool automatic,
  }) async {
    final adapter = _adapterFor(conflict.scope);
    final latest = await store.latestChange(scope: conflict.scope, entityId: conflict.entityId);
    if (latest != null && latest.change.operationId != conflict.local.operationId) {
      final relation = latest.change.revision.compareTo(conflict.remote.revision);
      if (relation == VersionRelation.ahead || relation == VersionRelation.equal) {
        // A version that already follows the remote one is here: another
        // device settled it first.
        await store.commitResolution(conflictKey: conflict.key, changes: const []);
        _emit(SyncConflictSuperseded(conflict: conflict));
        return;
      }
      await store.saveConflict(
        SyncConflict(
          scope: conflict.scope,
          entityId: conflict.entityId,
          local: latest.change,
          remote: conflict.remote,
          relation: VersionRelation.concurrent,
        ),
      );
      throw const LanSyncError(
        category: LanSyncErrorCategory.conflict,
        code: 'conflict_outdated',
        message: 'The local version changed since the conflict was recorded; review it again.',
      );
    }

    final revision = await _pruned(conflict.local.revision.merged(conflict.remote.revision).incremented(localDeviceId));
    SyncChange version(String entityId, SyncOperation operation, Map<String, Object?> payload, VersionVector at) =>
        SyncChange(
          operationId: '$localDeviceId/${_newId()}',
          scope: conflict.scope,
          entityType: conflict.remote.entityType,
          entityId: entityId,
          originDeviceId: localDeviceId,
          operation: operation,
          schemaVersion: adapter.schemaVersion,
          revision: at,
          createdAt: _now().toUtc(),
          payload: operation == SyncOperation.delete ? const <String, Object?>{} : payload,
        );
    final List<SyncChange> changes;
    switch (resolution) {
      case UseLocalResolution():
        changes = [version(conflict.entityId, conflict.local.operation, conflict.local.payload, revision)];
      case UseRemoteResolution():
        changes = [version(conflict.entityId, conflict.remote.operation, conflict.remote.payload, revision)];
      case MergedResolution(:final payload):
        _checkJson(payload);
        changes = [version(conflict.entityId, SyncOperation.upsert, payload, revision)];
      case KeepBothResolution(:final copyEntityId, :final localPayload, :final remotePayload):
        if (copyEntityId.isEmpty ||
            copyEntityId.length > BatchApplier.maxIdentifierLength ||
            copyEntityId == conflict.entityId) {
          throw const LanSyncError(
            category: LanSyncErrorCategory.dataValidation,
            code: 'copy_id_invalid',
            message: 'Keeping both versions needs a distinct id for the copy.',
          );
        }
        _checkJson(localPayload);
        _checkJson(remotePayload);
        final copy = await store.latestChange(scope: conflict.scope, entityId: copyEntityId);
        changes = [
          version(conflict.entityId, SyncOperation.upsert, localPayload, revision),
          version(
            copyEntityId,
            SyncOperation.upsert,
            remotePayload,
            await _pruned((copy?.change.revision ?? const VersionVector.empty()).incremented(localDeviceId)),
          ),
        ];
      case EscalateResolution():
        throw const LanSyncError(
          category: LanSyncErrorCategory.conflict,
          code: 'conflict_needs_decision',
          message: 'A conflict needs a decision to be settled.',
        );
    }

    final SyncApplyResult result;
    try {
      result = await adapter.applyChanges(changes: changes);
    } on LanSyncError {
      rethrow;
    } on Object catch (error) {
      throw LanSyncError(
        category: LanSyncErrorCategory.storage,
        code: 'adapter_apply_failed',
        message: 'The decision could not be saved on this device.',
        debugContext: '$error',
      );
    }
    if (result.failures.isNotEmpty || result.conflicts.isNotEmpty) {
      throw LanSyncError(
        category: LanSyncErrorCategory.conflict,
        code: 'resolution_refused',
        message: 'This device could not apply the decision.',
        debugContext: [for (final failure in result.failures) failure.reason].join('; '),
      );
    }
    await store.commitResolution(conflictKey: conflict.key, changes: changes);
    _log
        .child(conflict.scope)
        .info(
          'conflict resolved',
          fields: {
            'entity': conflict.entityId,
            'resolution': resolution.runtimeType.toString(),
            'who': automatic ? 'policy' : 'user',
          },
        );
    _emit(SyncConflictResolved(conflict: conflict, resolution: resolution, automatic: automatic));
  }

  /// [vector] within [LanSyncOptions.maxVersionVectorEntries]: entries of
  /// devices no longer trusted go first, smallest counters first. This
  /// device's and trusted devices' entries stay, even past the cap.
  Future<VersionVector> _pruned(VersionVector vector) async {
    final cap = options.maxVersionVectorEntries;
    if (vector.deviceIds.length <= cap) return vector;
    final trusted = {
      for (final trust in await store.loadDeviceTrusts())
        if (!trust.revoked) trust.deviceId,
    };
    final droppable = [
      for (final id in vector.deviceIds)
        if (id != localDeviceId && !trusted.contains(id)) id,
    ]..sort((a, b) => vector[a].compareTo(vector[b]));
    var pruned = vector;
    for (final id in droppable) {
      if (pruned.deviceIds.length <= cap) break;
      pruned = pruned.withoutDevice(id);
    }
    return pruned;
  }

  void _emit(LanSyncEvent event) {
    if (!_events.isClosed) {
      _events.add(event);
    }
  }

  static void _checkJson(Map<String, Object?> payload) {
    try {
      jsonEncode(payload);
    } on Object {
      throw const LanSyncError(
        category: LanSyncErrorCategory.dataValidation,
        code: 'payload_not_json',
        message: 'A change payload must be plain JSON.',
      );
    }
  }

  Future<Map<String, SyncManifest>> _exchangeManifests(PeerSyncChannel channel, Set<String> scopes) async {
    final answer = await _retry(
      () => channel.call('manifest/exchange', <String, Object?>{
        'scopes': [
          for (final scope in scopes)
            if (_adapters[scope] case final adapter?)
              <String, Object?>{'scope': scope, 'schemaVersion': adapter.schemaVersion},
        ],
      }),
    );
    final manifests = <String, SyncManifest>{};
    try {
      for (final item in _list(answer['scopes'])) {
        final manifest = SyncManifest.fromJson(_map(item));
        manifests[manifest.scope] = manifest;
      }
    } on LanSyncError {
      rethrow;
    } on Object {
      throw LanSyncError(
        category: LanSyncErrorCategory.dataValidation,
        code: 'manifest_malformed',
        message: 'The other device answered with a malformed manifest.',
        deviceId: channel.peerDeviceId,
      );
    }
    return manifests;
  }

  Future<SyncTask> _pull(
    PeerSyncChannel channel,
    String scope,
    LanSyncDataAdapter adapter,
    SyncManifest manifest,
    SyncTask start,
    List<String> problems,
    SyncCancellation? cancellation,
  ) async {
    final peer = channel.peerDeviceId;
    final stored = await store.cursorFor(peerDeviceId: peer, scope: scope);
    var after = options.incrementalSyncEnabled ? BatchApplier.sequenceOf(stored?.remoteCheckpoint) : 0;
    var task = start.progressed(
      status: SyncTaskStatus.transferring,
      stage: SyncTaskStage.changes,
      totalChanges: start.totalChanges + max(0, manifest.latestSequence - after),
    );
    await _publish(task);
    while (true) {
      _checkCancelled(cancellation);
      final requestedAfter = after;
      final page = await _retry(
        () => channel.call('changes/pull', <String, Object?>{
          'scope': scope,
          'after': requestedAfter,
          'limit': options.batchSize,
          'maxBytes': options.maxBatchBytes,
        }),
      );
      final batch = _loggedChanges(page['changes'], peer);
      final through = _int(page, 'through', atLeast: requestedAfter);
      task = task.progressed(status: SyncTaskStatus.applying, stage: SyncTaskStage.application);
      final outcome = await _exclusive(scope, () async {
        final cursor =
            await store.cursorFor(peerDeviceId: peer, scope: scope) ?? SyncCursor(peerDeviceId: peer, scope: scope);
        final applied = await _applier.apply(
          peer: peer,
          scope: scope,
          adapter: adapter,
          batch: batch,
          after: requestedAfter,
          through: through,
          cursor: cursor,
        );
        await _supersede(scope, applied.appliedChanges);
        await _settle(scope, adapter, applied.conflicts);
        return applied;
      });
      task = task.progressed(
        status: SyncTaskStatus.transferring,
        stage: SyncTaskStage.changes,
        completedChanges: task.completedChanges + outcome.handled,
      );
      await _publish(task);
      if (outcome.handledThrough > requestedAfter) {
        _log
            .child(scope)
            .debug(
              'batch applied',
              fields: {
                'from': requestedAfter,
                'through': outcome.handledThrough,
                'applied': outcome.applied,
                'duplicates': outcome.duplicates,
                'stale': outcome.stale,
                'converged': outcome.converged,
                'conflicts': outcome.conflicts.length,
              },
            );
        try {
          await channel.call('changes/ack', <String, Object?>{'scope': scope, 'through': outcome.handledThrough});
        } on LanSyncError catch (error) {
          // Advisory: the other device only uses it to start its pushes
          // later; the next sync acknowledges again.
          _log.child(scope).failure('acknowledgement failed', error);
        }
      }
      if (outcome.failures.isNotEmpty) {
        problems.add('$scope: ${_failureSummary(outcome)}; the next sync retries from there');
        break;
      }
      if (page['hasMore'] != true || outcome.handledThrough <= requestedAfter) {
        break;
      }
      after = outcome.handledThrough;
    }
    return task;
  }

  Future<SyncTask> _push(
    PeerSyncChannel channel,
    String scope,
    SyncTask start,
    List<String> problems,
    SyncCancellation? cancellation,
  ) async {
    final peer = channel.peerDeviceId;
    final stored = await store.cursorFor(peerDeviceId: peer, scope: scope);
    var after = options.incrementalSyncEnabled ? BatchApplier.sequenceOf(stored?.localCheckpoint) : 0;
    var task = start.progressed(
      status: SyncTaskStatus.transferring,
      stage: SyncTaskStage.changes,
      totalChanges: start.totalChanges + max(0, await store.latestSequence(scope: scope) - after),
    );
    await _publish(task);
    var rewinds = 0;
    while (true) {
      _checkCancelled(cancellation);
      final scanned = await store.changesAfter(scope: scope, afterSequence: after, limit: options.batchSize);
      if (scanned.isEmpty) {
        break;
      }
      final page = _page(scanned, start: after, exclude: peer, maxBytes: max(_minBatchBytes, options.maxBatchBytes));
      var acknowledged = page.through;
      if (page.changes.isNotEmpty) {
        final requestedAfter = after;
        final answer = await _retry(
          () => channel.call('changes/push', <String, Object?>{
            'scope': scope,
            'after': requestedAfter,
            'through': page.through,
            'changes': [for (final entry in page.changes) entry.toJson()],
          }),
        );
        acknowledged = min(_int(answer, 'acknowledgedThrough', atLeast: 0), page.through);
        if (answer['rewound'] == true) {
          _log.child(scope).info('the other device rewound the push cursor; resending', fields: {'from': acknowledged});
          if (++rewinds > 3 || acknowledged >= after) {
            problems.add('$scope: the other device could not agree on where to resume');
            break;
          }
          await _moveLocalCheckpoint(peer, scope, acknowledged, onlyForward: false);
          after = acknowledged;
          continue;
        }
        task = task.progressed(
          completedChanges:
              task.completedChanges +
              _countIn(answer, 'applied') +
              _countIn(answer, 'duplicates') +
              _countIn(answer, 'stale') +
              _countIn(answer, 'converged') +
              _countIn(answer, 'conflicts'),
        );
        await _publish(task);
        final refused = _list(answer['failed']);
        if (refused.isNotEmpty) {
          problems.add('$scope: the other device refused ${refused.length} change(s); the next sync retries them');
        }
      }
      if (acknowledged > after) {
        await _moveLocalCheckpoint(peer, scope, acknowledged, onlyForward: true);
      }
      if (acknowledged < page.through) {
        if (!problems.any((problem) => problem.startsWith('$scope: the other device refused'))) {
          problems.add('$scope: the other device stopped before the end of the batch');
        }
        break;
      }
      after = acknowledged;
    }
    return task;
  }

  /// Moves this device's record of how far [peer] has its log, under the
  /// scope lock so a concurrent pull cannot overwrite it.
  Future<void> _moveLocalCheckpoint(String peer, String scope, int sequence, {required bool onlyForward}) =>
      _exclusive(scope, () async {
        final cursor =
            await store.cursorFor(peerDeviceId: peer, scope: scope) ?? SyncCursor(peerDeviceId: peer, scope: scope);
        if (onlyForward && sequence <= BatchApplier.sequenceOf(cursor.localCheckpoint)) {
          return;
        }
        await store.saveCursor(cursor.acknowledged(localCheckpoint: '$sequence', at: _now().toUtc()));
      });

  /// Retries [call] on retryable failures with exponential backoff, up to
  /// [LanSyncOptions.maxRetries] times. Every protocol call is safe to
  /// repeat: pulls read, pushes are deduplicated, acks only move forward.
  Future<T> _retry<T>(Future<T> Function() call) async {
    var attempt = 0;
    while (true) {
      try {
        return await call();
      } on LanSyncError catch (error) {
        if (!error.retryable || attempt >= options.maxRetries) {
          _log.failure('request failed', error);
          rethrow;
        }
        final delay = Duration(milliseconds: min(5000, 200 * (1 << attempt)));
        _log.debug('retrying request', fields: {'attempt': attempt + 1, 'delayMs': delay.inMilliseconds});
        await _sleep(delay);
        attempt++;
      }
    }
  }

  /// Runs [action] after every earlier action on [scope] finished, so local
  /// records, applied batches and cursor moves never interleave.
  Future<T> _exclusive<T>(String scope, Future<T> Function() action) {
    final previous = _scopeLocks[scope] ?? Future<void>.value();
    final done = Completer<void>();
    _scopeLocks[scope] = done.future;
    return previous.then((_) => action()).whenComplete(done.complete);
  }

  Future<void> _publish(SyncTask task) async {
    await store.saveTask(task);
    if (!_taskUpdates.isClosed) {
      _taskUpdates.add(task);
    }
  }

  Future<DeviceTrust> _trustOf(String deviceId) async {
    final trust = await store.deviceTrust(deviceId);
    if (trust == null || trust.revoked) {
      throw LanSyncError(
        category: LanSyncErrorCategory.authentication,
        code: 'peer_not_paired',
        message: 'The device is not paired, or the pairing was revoked.',
        deviceId: deviceId,
      );
    }
    return trust;
  }

  LanSyncDataAdapter _adapterFor(String scope) =>
      _adapters[scope] ??
      (throw LanSyncError(
        category: LanSyncErrorCategory.dataValidation,
        code: 'scope_unknown',
        message: 'This device does not sync the scope "$scope".',
      ));

  String _newId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  static const int _minBatchBytes = 16 * 1024;

  /// One page of a log scan for [exclude]: entries [exclude] made itself
  /// are skipped (it has them), the rest fill the page up to [maxBytes] —
  /// always at least one entry, so a single oversized change still moves.
  /// `through` is the last scanned sequence the page covers.
  static ({List<LoggedChange> changes, int through}) _page(
    List<LoggedChange> scanned, {
    required int start,
    required String exclude,
    required int maxBytes,
  }) {
    final changes = <LoggedChange>[];
    var through = start;
    var bytes = 0;
    for (final entry in scanned) {
      if (entry.change.originDeviceId == exclude) {
        through = entry.sequence;
        continue;
      }
      final size = utf8.encode(jsonEncode(entry.toJson())).length;
      if (changes.isNotEmpty && bytes + size > maxBytes) {
        break;
      }
      changes.add(entry);
      bytes += size;
      through = entry.sequence;
    }
    return (changes: changes, through: through);
  }

  static Map<String, Object?> _counts(AppliedBatch outcome) => <String, Object?>{
    'applied': outcome.applied,
    'duplicates': outcome.duplicates,
    'stale': outcome.stale,
    'converged': outcome.converged,
    'conflicts': outcome.conflicts.length,
    'failed': [
      for (final failure in outcome.failures)
        <String, Object?>{'operationId': failure.change.operationId, 'reason': failure.reason},
    ],
  };

  static String _failureSummary(AppliedBatch outcome) =>
      '${outcome.failures.length} change(s) could not be applied (${outcome.failures.first.reason})';

  static void _checkCancelled(SyncCancellation? cancellation) {
    if (cancellation?.isCancelled ?? false) {
      throw const _SyncCancelled();
    }
  }

  static List<LoggedChange> _loggedChanges(Object? value, String peer) {
    try {
      return [for (final item in _list(value)) LoggedChange.fromJson(_map(item))];
    } on Object {
      throw LanSyncError(
        category: LanSyncErrorCategory.dataValidation,
        code: 'batch_malformed',
        message: 'The other device sent a malformed batch.',
        deviceId: peer,
      );
    }
  }

  static int _countIn(Map<String, Object?> json, String key) => switch (json[key]) {
    final num value => value.toInt(),
    _ => 0,
  };

  static List<Object?> _list(Object? value) => switch (value) {
    final List<Object?> list => list,
    _ => throw _malformed,
  };

  static Map<String, Object?> _map(Object? value) => switch (value) {
    final Map<Object?, Object?> map => map.cast<String, Object?>(),
    _ => throw _malformed,
  };

  static String _string(Map<String, Object?> json, String key) => switch (json[key]) {
    final String value when value.isNotEmpty => value,
    _ => throw _malformed,
  };

  static int _int(Map<String, Object?> json, String key, {required int atLeast}) => switch (json[key]) {
    final num value when value.toInt() >= atLeast => value.toInt(),
    _ => throw _malformed,
  };

  static int? _optionalInt(Map<String, Object?> json, String key) => switch (json[key]) {
    final num value => value.toInt(),
    _ => null,
  };

  static LanSyncError _denied(String scope, String action) => LanSyncError(
    category: LanSyncErrorCategory.permissionDenied,
    code: 'scope_not_granted',
    message: 'The device may not $action the scope "$scope" here.',
  );

  static const _malformed = LanSyncError(
    category: LanSyncErrorCategory.dataValidation,
    code: 'request_malformed',
    message: 'The sync message is malformed.',
  );
}

final class _SyncCancelled implements Exception {
  const new();
}
