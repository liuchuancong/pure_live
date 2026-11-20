import 'dart:async' show Completer, unawaited;

import 'package:flutter_test/flutter_test.dart';
import 'package:live_iptv/live_iptv.dart' show IptvKeys;
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/features/backup/document/backup_document.dart';
import 'package:pure_live/features/backup/document/backup_repository.dart';
import 'package:pure_live/features/backup/document/backup_settings.dart';
import 'package:pure_live/modules/live/areas/data/area_follow_repository.dart';
import 'package:pure_live/modules/live/favorites/data/follow_repository.dart';
import 'package:pure_live/modules/live/history/history_repository.dart';
import 'package:pure_live/modules/live/recorder/data/recording_repository.dart';
import 'package:pure_live/modules/live/recorder/data/recording_task.dart';

/// The backup repository over the real stores on the in-memory storage:
/// the capture that bundles only the selected sections, the restore that
/// clears and takes each carried section while leaving the rest, the two
/// guards that refuse before the first write, the lock that turns a second
/// restore away, and the section walkers — the idle take with its facts
/// kept, the vault that takes only the named refs, the IPTV setup keys
/// alone, and the settings walk through the typed gate.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StorageStores stores;
  late JsonStore followsStore;
  late JsonStore historyStore;
  late JsonStore areasStore;
  late JsonStore recordingsStore;
  late JsonStore iptvStore;
  late JsonStore multiviewStore;
  late _MapVault vault;
  late SecretStore vaultStore;
  late BackupRepository repository;

  setUp(() async {
    stores = await StorageStores.openInMemory();
    await StoragePrefs.init();
    followsStore = await stores.openStore('follows');
    historyStore = await stores.openStore('history');
    areasStore = await stores.openStore('area_follows');
    recordingsStore = await stores.openStore('recordings');
    iptvStore = await stores.openStore(IptvKeys.table);
    multiviewStore = await stores.openStore('multiview');
    vault = _MapVault();
    vaultStore = await SecretStore.load(vault: vault);
    repository = BackupRepository(
      follows: FollowRepository(followsStore),
      history: HistoryRepository(historyStore),
      areaFollows: AreaFollowRepository(areasStore),
      recordings: RecordingTaskRepository(recordingsStore),
      iptv: iptvStore,
      multiview: multiviewStore,
      secrets: vaultStore,
    );
  });

  tearDown(() => stores.close());

  test('the capture bundles only the selected sections, and the summary counts the stores', () async {
    await followsStore.put('bili:1', {'roomId': 1});
    await historyStore.put('bili:2', {'roomId': 2});
    await StoragePrefs.setString('log.level', 'debug');
    // The vault's store is the surface the summary reads, not the raw vault.
    await vaultStore.set('webdav.main.password', 'hush');
    await vaultStore.set('bilibili.cookie', 'sid=1');

    final document = repository.capture(sections: {BackupSection.follows, BackupSection.settings});

    expect(document.hasFollows, isTrue);
    expect(document.hasSettings, isTrue);
    expect(document.hasHistory, isFalse); // not selected, not carried
    expect(document.hasSecrets, isFalse);
    expect(document.hasIptv, isFalse); // the store is held but not selected
    expect(document.follows, hasLength(1));
    expect(document.settings['log.level'], 'debug');
    expect(document.encode(), contains('"follows"'));
    expect(document.encode(), isNot(contains('"history"')));

    final summary = repository.summary();
    expect(summary[BackupSection.follows], 1);
    expect(summary[BackupSection.history], 1);
    expect(summary[BackupSection.settings], 1);
    expect(summary[BackupSection.secrets], 2);
    expect(summary[BackupSection.iptv], 0);

    // Without the vault, the secrets section is not even offered.
    final vaultless = BackupRepository(
      follows: FollowRepository(followsStore),
      history: HistoryRepository(historyStore),
      areaFollows: AreaFollowRepository(areasStore),
      recordings: RecordingTaskRepository(recordingsStore),
    );
    final offered = vaultless.capture();
    expect(offered.hasSecrets, isFalse);
    expect(offered.presentSections.contains(BackupSection.secrets), isFalse);
  });

  test('the restore clears and takes the carried sections and leaves the rest', () async {
    await followsStore.put('F1', {'roomId': 1});
    await historyStore.put('H1', {'roomId': 2});
    await areasStore.put('A1', {'areaId': 3});
    final document = repository.capture(
      sections: {BackupSection.follows, BackupSection.history, BackupSection.areaFollows},
    );

    // A row that grew after the capture is not in the document, so the
    // restore's clear takes it with the rest of the section.
    await historyStore.put('H-junk', {'roomId': 9});

    await repository.apply(document);
    expect(followsStore.keys, ['F1']); // the junk the document never carried fell with the clear
    expect(historyStore.keys, ['H1']);
    expect(areasStore.keys, ['A1']);

    // A section the document does not carry stays as it is.
    await iptvStore.put(IptvKeys.playlists, [
      {'id': 'keep'},
    ]);
    final narrow = repository.capture(sections: {BackupSection.follows});
    await repository.apply(narrow);
    expect(iptvStore.entries[IptvKeys.playlists], [
      {'id': 'keep'},
    ]); // untouched
  });

  test('an empty document refuses before any write', () async {
    await followsStore.put('F1', {'roomId': 1});
    final document = BackupDocument(exportedAt: DateTime.utc(2026, 11, 21), presentSections: {BackupSection.follows});

    await expectLater(repository.apply(document), throwsA(isA<BackupDocumentEmpty>()));
    expect(followsStore.keys, ['F1']); // nothing was cleared
  });

  test('a live take refuses the restore before any write', () async {
    final running = RecordingTask(
      id: 't1',
      platform: 'bilibili',
      roomId: '1',
      roomTitle: 'live',
      state: RecordingTaskState.recording,
      startedAt: DateTime.utc(2026, 11, 21),
    );
    await recordingsStore.put('t1', running.toJson());
    await followsStore.put('F1', {'roomId': 1});
    final document = BackupDocument(
      exportedAt: DateTime.utc(2026, 11, 21),
      follows: {
        'F2': {'roomId': 2},
      },
      recordings: {'t9': _taskJson(roomId: '9')},
    );

    await expectLater(repository.apply(document), throwsA(isA<BackupRecordingsBusy>()));
    expect(followsStore.keys, ['F1']); // the guard ran before the first write
    expect(recordingsStore.keys, ['t1']);

    // A finished take still joining is busy too.
    final post = RecordingTask(
      id: 't2',
      platform: 'bilibili',
      roomId: '2',
      roomTitle: 'x',
      state: RecordingTaskState.stopped,
      startedAt: DateTime.utc(2026, 11, 21),
      postProcessing: true,
    );
    await recordingsStore.put('t2', post.toJson());
    await expectLater(repository.apply(document), throwsA(isA<BackupRecordingsBusy>()));
  });

  test('a restored take lands idle with its facts kept and its machine state dropped', () async {
    final document = BackupDocument(
      exportedAt: DateTime.utc(2026, 11, 21),
      recordings: {
        't1': _taskJson(
          roomId: '1',
          state: 'recording',
          postProcessing: true,
          progress: 0.5,
          warning: 'codec',
          filePath: '/takes/x.mkv',
          bytes: 1024,
          durationMs: 5000,
          errorText: 'disk',
        ),
        't2': _taskJson(roomId: ''), // a room-less entry lists nowhere
      },
    );

    await repository.apply(document);
    final read = RecordingTask.fromJson(recordingsStore.entries['t1']);
    expect(recordingsStore.keys, ['t1']); // the room-less entry never lands
    expect(read.id, 't1'); // the key is the id
    expect(read.state, RecordingTaskState.waiting); // the live check will start it
    expect(read.postProcessing, isFalse); // no session runs behind a restored task
    expect(read.postProcessingProgress, -1);
    expect(read.warning, '');
    expect(read.filePath, '/takes/x.mkv'); // the facts the take left behind
    expect(read.bytes, 1024);
    expect(read.durationMs, 5000);
    expect(read.errorText, 'disk');
  });

  test('the vault takes only the named refs, and an empty value removes', () async {
    await vaultStore.set('keep', 'x');
    await vaultStore.set('gone', 'y');
    final document = BackupDocument(
      exportedAt: DateTime.utc(2026, 11, 21),
      secrets: {'gone': '', 'new': 'v'}, // an empty value is a removal
      // The default selection leaves the secrets out by design; a document
      // that carries them must name the section.
      presentSections: {BackupSection.secrets},
    );

    await repository.apply(document);
    expect(vaultStore.value('keep'), 'x'); // a backup from another device never logs this one out
    expect(vaultStore.contains('gone'), isFalse);
    expect(vaultStore.value('new'), 'v');
  });

  test('the IPTV restore writes the setup keys alone, in list shape', () async {
    await iptvStore.put(IptvKeys.playlists, [
      {'id': 'old'},
    ]);
    await iptvStore.put(IptvKeys.channels, [
      {'id': 'fetched'},
    ]);
    final document = BackupDocument(
      exportedAt: DateTime.utc(2026, 11, 21),
      iptv: {
        IptvKeys.playlists: {
          'items': [
            {'id': 'new'},
          ],
        },
        IptvKeys.groups: {
          'items': [1, 2],
        },
        'iptv.not-setup.v1': {
          'items': [3],
        }, // outside the setup: never written
        IptvKeys.guideSources: {'items': 'not a list'}, // wrong shape: skipped
      },
    );

    await repository.apply(document);
    expect(iptvStore.entries[IptvKeys.playlists], [
      {'id': 'new'},
    ]);
    expect(iptvStore.entries[IptvKeys.groups], [1, 2]);
    expect(iptvStore.entries[IptvKeys.channels], [
      {'id': 'fetched'},
    ]); // the fetched rows are rebuilt by a refresh, never restored
    expect(iptvStore.entries.containsKey('iptv.not-setup.v1'), isFalse);
    expect(iptvStore.entries.containsKey(IptvKeys.guideSources), isFalse);
  });

  test('the settings walk writes the known keys through the typed gate', () async {
    await StoragePrefs.setString('log.level', 'debug');
    await StoragePrefs.setInt('hongguo.download.maxConcurrent', 2);
    await StoragePrefs.setString('vod.progress.BV1', 'p1');
    final document = BackupDocument(
      exportedAt: DateTime.utc(2026, 11, 21),
      settings: {
        'log.level': 'info',
        'lan_sync.enabled': true,
        'hongguo.download.maxConcurrent': 'not an int', // wrong shape for its kind
        'brand.new.key': 'x', // this build does not know it
        'vod.progress.BV2': 'p2', // the family travels by prefix
      },
    );

    final changes = settingsSnapshotChanges(document.settings);
    expect(changes.written, 3); // two known keys + the family key; the misshapen one is not written
    expect(changes.changed, 3); // every written one differs from what this device holds
    expect(changes.skipped, 1); // the misshapen integer
    expect(changes.unknown, 1); // the key this build never listed

    await repository.apply(document);
    expect(StoragePrefs.getString('log.level'), 'info');
    expect(StoragePrefs.getBool('lan_sync.enabled'), isTrue);
    expect(StoragePrefs.getInt('hongguo.download.maxConcurrent'), 2); // the skipped key kept its value
    expect(StoragePrefs.getString('brand.new.key'), isNull); // the unknown key was left alone
    expect(StoragePrefs.getString('vod.progress.BV2'), 'p2');
    expect(StoragePrefs.getString('vod.progress.BV1'), 'p1'); // keys the document does not carry stay
  });

  test('the fractional kind reads a whole number as its double', () {
    expect(restorablePrefValue(BackupPrefKind.floating, 3), 3.0);
    expect(restorablePrefValue(BackupPrefKind.floating, '3'), isNull);
  });

  test('the restore lock turns the second restore away and answers its idle', () async {
    final lock = BackupRestoreLock();
    expect(lock.busy, isFalse);
    final gate = Completer<void>();

    final first = lock.run(() async {
      expect(lock.busy, isTrue); // the holder sees the lock
      await gate.future;
      return 'first';
    });
    await pumpEventQueue();
    expect(lock.busy, isTrue);

    // The idle, asked while a restore holds the lock, waits for its end.
    var landed = false;
    unawaited(lock.idle.then((_) => landed = true));
    await pumpEventQueue();
    expect(landed, isFalse);

    await expectLater(lock.run(() async => 'second'), throwsA(isA<BackupRestoreBusy>()));
    expect(lock.busy, isTrue); // the refusal did not take the lock

    gate.complete();
    expect(await first, 'first');
    expect(lock.busy, isFalse);
    await lock.idle;
    expect(landed, isTrue);
  });
}

/// One recording task's storage JSON, as the document carries it.
Map<String, Object?> _taskJson({
  required String roomId,
  String state = 'stopped',
  bool postProcessing = false,
  double progress = -1,
  String warning = '',
  String? filePath,
  int bytes = 0,
  int durationMs = 0,
  String errorText = '',
}) => {
  'id': roomId.isEmpty ? '' : 't-$roomId',
  'platform': 'bilibili',
  'roomId': roomId,
  'roomTitle': 'room $roomId',
  'state': state,
  'startedAt': '2026-11-21T08:00:00.000Z',
  'postProcessing': postProcessing,
  'postProcessingProgress': progress,
  'warning': warning,
  'filePath': filePath,
  'bytes': bytes,
  'durationMs': durationMs,
  'errorText': errorText,
};

/// A vault of plain strings, as the tests hold it.
final class _MapVault implements SecretVault {
  _MapVault();

  final Map<String, String> values = {};

  @override
  Future<Map<String, String>> readAll() async => Map.of(values);

  @override
  Future<void> write(String ref, String plain) async {
    values[ref] = plain;
  }

  @override
  Future<void> delete(String ref) async {
    values.remove(ref);
  }
}
