import 'package:flutter_test/flutter_test.dart';
import 'package:live_lan_sync/live_lan_sync.dart';
import 'package:pure_live/features/backup/document/backup_settings.dart';
import 'package:pure_live/features/lan_sync/data/scoped_sync.dart';
import 'package:pure_live/features/lan_sync/data/sync_scopes.dart';

import '../features/lan_sync/support/memory_json_store.dart';

SyncChange _change(String id, {Map<String, Object?>? payload}) => SyncChange(
  operationId: 'op-$id-${payload?.length ?? 0}',
  scope: LanSyncScope.history.id,
  entityType: LanSyncScope.history.id,
  entityId: id,
  originDeviceId: 'peer',
  operation: payload == null ? SyncOperation.delete : SyncOperation.upsert,
  schemaVersion: 1,
  revision: VersionVector(const {'peer': 1}),
  createdAt: DateTime.utc(2026),
  payload: payload ?? const {},
);

void main() {
  group('LanSyncScope', () {
    test("every backed-up pref is either one settings scope's or this device's own", () {
      final deviceOwn = <String>[];
      for (final (key, _) in kBackedUpPrefs) {
        final scope = LanSyncScope.ofPrefKey(key);
        if (scope == null) deviceOwn.add(key);
      }
      // What stays home: the backup folder and switch, the logs, the proxy,
      // the LAN sync's own choices. Anything else unmapped is a new prefix
      // nobody sorted yet.
      final unexpected = deviceOwn.where((key) => !RegExp(r'^(backup|log|proxy|lan_sync)\.').hasMatch(key));
      expect(unexpected, isEmpty, reason: 'sort these prefixes into a settings scope or exclude them on purpose');
      expect(LanSyncScope.ofPrefKey('theme.mode'), LanSyncScope.settingsAppearance);
      expect(LanSyncScope.ofPrefKey('danmaku.fontSize'), LanSyncScope.settingsDanmaku);
      expect(LanSyncScope.ofPrefKey('backup.dir'), isNull);
    });

    test('stored ids round-trip and unknown ones are dropped', () {
      expect(lanSyncScopesFrom(null), LanSyncScope.defaults);
      expect(lanSyncScopesFrom(['favorites', 'nope', 'settings.music']), {
        LanSyncScope.favorites,
        LanSyncScope.settingsMusic,
      });
      expect(LanSyncScope.defaults.contains(LanSyncScope.secrets), isFalse);
    });
  });

  group('LocalChangeDetector', () {
    test('records what changed since the ledger, then moves the ledger up', () async {
      final ledger = ScopeSnapshotLedger(MemoryJsonStore());
      await ledger.replaceScope(LanSyncScope.history, {
        'a': {'v': 1},
        'b': {'v': 2},
      });
      final recorded = <(String, Map<String, Object?>?)>[];
      final detector = LocalChangeDetector(
        ledger: ledger,
        record: (scope, id, payload) async => recorded.add((id, payload)),
        currentOf: (_) async => {
          'a': {'v': 1}, // unchanged
          'b': {'v': 3}, // edited
          'c': {'v': 4}, // new
          // 'b' stays, 'a' stays, nothing named 'd' — but 'b' changed and 'a' did not
        },
      );

      final count = await detector.recordChanges([LanSyncScope.history]);

      expect(count, 2);
      expect(recorded.map((entry) => entry.$1), ['b', 'c']);
      expect(recorded.map((entry) => entry.$2?['v']), [3, 4]);
      expect(ledger.entriesOf(LanSyncScope.history).keys, containsAll(['a', 'b', 'c']));
    });

    test('an entry gone from the store becomes a delete', () async {
      final ledger = ScopeSnapshotLedger(MemoryJsonStore());
      await ledger.replaceScope(LanSyncScope.history, {
        'a': {'v': 1},
      });
      final recorded = <(String, Map<String, Object?>?)>[];
      final detector = LocalChangeDetector(
        ledger: ledger,
        record: (scope, id, payload) async => recorded.add((id, payload)),
        currentOf: (_) async => const {},
      );

      await detector.recordChanges([LanSyncScope.history]);

      expect(recorded, [('a', null)]);
      expect(ledger.entriesOf(LanSyncScope.history), isEmpty);
    });
  });

  group('ScopedSyncAdapter', () {
    test('a remote apply lands in the store and the ledger, so the detector does not echo it', () async {
      final store = MemoryJsonStore();
      final ledger = ScopeSnapshotLedger(MemoryJsonStore());
      ScopeSource source() => (
        current: () async => {
          for (final entry in store.entries.entries) entry.key: Map<String, Object?>.from(entry.value! as Map),
        },
        upsert: store.put,
        delete: store.delete,
        afterBatch: null,
      );
      final adapter = ScopedSyncAdapter(syncScope: LanSyncScope.history, ledger: ledger, open: () async => source());

      final result = await adapter.applyChanges(
        changes: [
          _change('x', payload: {'v': 9}),
          _change('y'),
        ],
      );

      expect(result.appliedCount, 2);
      expect(result.failures, isEmpty);
      expect(store.entries['x'], {'v': 9});
      expect(ledger.entriesOf(LanSyncScope.history), {
        'x': {'v': 9},
      });

      final recorded = <String>[];
      final detector = LocalChangeDetector(
        ledger: ledger,
        record: (scope, id, payload) async => recorded.add(id),
        currentOf: (_) => source().current(),
      );
      expect(await detector.recordChanges([LanSyncScope.history]), 0, reason: 'the remote write is not a local edit');
      expect(recorded, isEmpty);
    });

    test('a source that is not open fails every change without throwing', () async {
      final adapter = ScopedSyncAdapter(
        syncScope: LanSyncScope.history,
        ledger: ScopeSnapshotLedger(MemoryJsonStore()),
        open: () async => null,
      );
      final result = await adapter.applyChanges(changes: [_change('x', payload: const {})]);
      expect(result.appliedCount, 0);
      expect(result.failures, hasLength(1));
    });
  });
}
