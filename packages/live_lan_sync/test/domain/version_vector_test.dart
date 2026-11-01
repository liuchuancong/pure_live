import 'package:live_lan_sync/live_lan_sync.dart';
import 'package:test/test.dart';

void main() {
  group('VersionVector', () {
    test('empty vector is empty and compares equal to itself', () {
      const vector = VersionVector.empty();
      expect(vector.isEmpty, isTrue);
      expect(vector.compareTo(const VersionVector.empty()), VersionRelation.equal);
    });

    test('increment advances only the acting device', () {
      final vector = const VersionVector.empty().incremented('a').incremented('a');
      expect(vector['a'], 2);
      expect(vector['b'], 0);
      expect(vector.deviceIds, ['a']);
    });

    test('increment does not mutate the receiver', () {
      final base = VersionVector(const <String, int>{'a': 1});
      final next = base.incremented('a');
      expect(base['a'], 1);
      expect(next['a'], 2);
    });

    test('causal ahead, behind, equal and concurrent', () {
      final a1 = VersionVector(const <String, int>{'a': 1});
      final a2 = VersionVector(const <String, int>{'a': 2});
      final ab = VersionVector(const <String, int>{'a': 1, 'b': 1});
      final ac = VersionVector(const <String, int>{'a': 3, 'c': 1});

      expect(a2.compareTo(a1), VersionRelation.ahead);
      expect(a1.compareTo(a2), VersionRelation.behind);
      expect(a1.compareTo(VersionVector(const <String, int>{'a': 1})), VersionRelation.equal);
      // Two devices edited without seeing each other: the conflict case.
      expect(a2.compareTo(ab), VersionRelation.concurrent);
      expect(ab.compareTo(ac), VersionRelation.concurrent);
    });

    test('merge takes the component-wise maximum', () {
      final left = VersionVector(const <String, int>{'a': 3, 'b': 1});
      final right = VersionVector(const <String, int>{'a': 1, 'c': 5});
      final merged = left.merged(right);
      expect(merged['a'], 3);
      expect(merged['b'], 1);
      expect(merged['c'], 5);
      expect(merged.compareTo(left), VersionRelation.ahead);
      expect(merged.compareTo(right), VersionRelation.ahead);
    });

    test('withoutDevice retires a leaving device', () {
      final vector = VersionVector(const <String, int>{'a': 1, 'b': 2});
      final retired = vector.withoutDevice('b');
      expect(retired.deviceIds, ['a']);
      expect(retired['b'], 0);
    });

    test('json round trip preserves counters', () {
      final vector = VersionVector(const <String, int>{'a': 3, 'b': 7});
      final restored = VersionVector.fromJson(vector.toJson());
      expect(restored, vector);
      expect(restored.compareTo(vector), VersionRelation.equal);
    });

    test('equality is structural', () {
      expect(VersionVector(const <String, int>{'a': 1}), VersionVector(const <String, int>{'a': 1}));
      expect(VersionVector(const <String, int>{'a': 1}), isNot(VersionVector(const <String, int>{'a': 2})));
    });
  });

  group('ConflictPolicy', () {
    test('the safe default is manual escalation', () {
      const options = LanSyncOptions();
      expect(options.defaultConflictPolicy, ConflictPolicy.manual);
    });
  });

  group('SyncConflict', () {
    test('json round trip and stable key', () {
      final conflict = SyncConflict(
        scope: 'favorites',
        entityId: 'room-1',
        local: _change('a'),
        remote: _change('b'),
        relation: VersionRelation.concurrent,
      );

      expect(conflict.key, 'favorites/room-1');
      final restored = SyncConflict.fromJson(conflict.toJson());
      expect(restored.key, conflict.key);
      expect(restored.relation, VersionRelation.concurrent);
      expect(restored.local.payload, _change('a').payload);
      expect(restored.remote.revision, _change('b').revision);
    });

    test('merged head is the union of both revisions', () {
      final conflict = SyncConflict(
        scope: 'favorites',
        entityId: 'room-1',
        local: _change('a'),
        remote: _change('b'),
        relation: VersionRelation.concurrent,
      );
      expect(conflict.mergedHead['a'], 1);
      expect(conflict.mergedHead['b'], 1);
    });
  });
}

SyncChange _change(String deviceId) {
  final createdAt = DateTime.utc(2026, 11, 3);
  return SyncChange(
    operationId: '$deviceId-op',
    scope: 'favorites',
    entityType: 'favorite',
    entityId: 'room-1',
    originDeviceId: deviceId,
    operation: SyncOperation.upsert,
    schemaVersion: 1,
    revision: const VersionVector.empty().incremented(deviceId),
    createdAt: createdAt,
    payload: {'tag': deviceId},
  );
}
