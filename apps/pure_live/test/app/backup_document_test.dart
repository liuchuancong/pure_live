// The backup document and the restore guard: what a document carries, what a
// reader tolerates, and — the part that matters most — which restores are
// refused before anything is written, one restore at a time, and what the
// preview promises before a restore runs. A restore clears stores, so every
// one of these rules is a data-loss boundary.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:live_iptv/live_iptv.dart' show IptvKeys;
import 'package:live_storage/live_storage.dart';

import 'package:pure_live/features/backup/document/backup_document.dart';
import 'package:pure_live/features/backup/document/backup_repository.dart';
import 'package:pure_live/modules/live/areas/areas.dart';
import 'package:pure_live/modules/live/favorites/favorites.dart';
import 'package:pure_live/modules/live/history/history.dart';
import 'package:pure_live/modules/live/recorder/data/recording_repository.dart';
import 'package:pure_live/modules/live/recorder/data/recording_task.dart';

/// Just enough of [JsonStore] for a restore: an ordered map and the change
/// streams the interface promises.
final class _MemoryStore implements JsonStore {
  final Map<String, Object?> _values = {};
  final StreamController<void> _changes = StreamController<void>.broadcast();
  final StreamController<String> _keys = StreamController<String>.broadcast();

  /// When set, a `clear` waits for it: a restore caught halfway through.
  Completer<void>? hold;

  @override
  String get namespace => 'memory';

  @override
  Object? get(String key) => _values[key];

  @override
  bool contains(String key) => _values.containsKey(key);

  @override
  List<String> get keys => _values.keys.toList();

  @override
  List<Object?> get values => _values.values.toList();

  @override
  Map<String, Object?> get entries => Map<String, Object?>.of(_values);

  @override
  int get length => _values.length;

  @override
  bool get isEmpty => _values.isEmpty;

  @override
  bool get isNotEmpty => _values.isNotEmpty;

  @override
  Stream<void> watch() => _changes.stream;

  @override
  Stream<String> watchKeys() => _keys.stream;

  @override
  Future<void> put(String key, Object? value) async {
    _values[key] = value;
    _keys.add(key);
    _changes.add(null);
  }

  @override
  Future<void> putAll(Map<String, Object?> values) async {
    _values.addAll(values);
    _changes.add(null);
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
    _changes.add(null);
  }

  @override
  Future<void> deleteAll(Iterable<String> keys) async {
    keys.forEach(_values.remove);
    _changes.add(null);
  }

  @override
  Future<void> clear() async {
    await hold?.future;
    _values.clear();
    _changes.add(null);
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> dispose() async {
    await _changes.close();
    await _keys.close();
  }
}

/// A vault that keeps its secrets in a map.
final class _MemoryVault implements SecretVault {
  new([Map<String, String> seed = const {}]) : _values = {...seed};

  final Map<String, String> _values;

  @override
  Future<Map<String, String>> readAll() async => {..._values};

  @override
  Future<void> write(String ref, String plain) async => _values[ref] = plain;

  @override
  Future<void> delete(String ref) async => _values.remove(ref);
}

({BackupRepository repository, _MemoryStore follows, _MemoryStore history, _MemoryStore areas, _MemoryStore recordings})
_build({BackupRestoreLock? lock, JsonStore? iptv, JsonStore? multiview, SecretStore? secrets}) {
  final follows = _MemoryStore();
  final history = _MemoryStore();
  final areas = _MemoryStore();
  final recordings = _MemoryStore();
  return (
    repository: BackupRepository(
      follows: FollowRepository(follows),
      history: HistoryRepository(history),
      areaFollows: AreaFollowRepository(areas),
      recordings: RecordingTaskRepository(recordings),
      iptv: iptv,
      multiview: multiview,
      secrets: secrets,
      restoreLock: lock,
    ),
    follows: follows,
    history: history,
    areas: areas,
    recordings: recordings,
  );
}

Map<String, Object?> _room(String id) => {'platform': 'bili', 'roomId': id, 'title': 'r$id'};

RecordingTask _task({
  String id = 'bili:1',
  RecordingTaskState state = RecordingTaskState.stopped,
  bool processing = false,
}) => RecordingTask(
  id: id,
  platform: 'bili',
  roomId: id.split(':').last,
  roomTitle: '房间',
  state: state,
  startedAt: DateTime.utc(2026, 10, 31),
  postProcessing: processing,
);

void main() {
  group('BackupDocument', () {
    test('a document round-trips through its own wire form', () {
      final document = BackupDocument(
        exportedAt: DateTime.utc(2026, 10, 31, 12),
        follows: {'bili:1': _room('1')},
        history: {'bili:2': _room('2')},
        areaFollows: {
          'bili:area': {'id': 'area'},
        },
        recordings: {'bili:3': _task(id: 'bili:3').toJson()},
        settings: {'recorder.combine': true},
      );

      final decoded = BackupDocument.tryDecode(document.encode())!;

      expect(decoded.presentSections, BackupSection.all);
      expect(decoded.followsOnly, isFalse);
      expect(decoded.follows, {'bili:1': _room('1')});
      expect(decoded.recordings.keys, ['bili:3']);
      expect(decoded.counts, (follows: 1, history: 1, areas: 1, recordings: 1, settings: 1, secrets: 0));
      expect(decoded.isEmpty, isFalse);
      expect(decoded.hasRecordings, isTrue);
    });

    test('a document that is not one is refused rather than read as empty', () {
      expect(BackupDocument.tryDecode('not json'), isNull);
      expect(BackupDocument.tryDecode('[]'), isNull);
      expect(BackupDocument.tryDecode('{}'), isNull);
      // Tagged but carrying nothing: a real answer, and an empty one.
      final empty = BackupDocument.tryDecode('{"version":{"app":"pure_live"}}')!;
      expect(empty.isEmpty, isTrue);
      expect(empty.presentSections, isEmpty);
    });

    test('wrong-shaped entries are dropped, not fatal', () {
      final decoded = BackupDocument.tryDecode(
        '{"version":{"app":"pure_live"},"follows":{"bili:1":"not a map","bili:2":{"roomId":"2"}},'
        ' "settings":{"a":1},"future":{"x":1}}',
      )!;
      expect(decoded.follows.keys, ['bili:2']);
      expect(decoded.settings, {'a': 1});
      expect(decoded.presentSections, {
        BackupSection.follows,
        BackupSection.settings,
      }, reason: 'an unknown section is not claimed');
      expect(decoded.skipped, {BackupSection.follows: 1}, reason: 'the preview says what was left out');
    });

    test('what the reader leaves out is counted for the sections a restore takes', () {
      final decoded = BackupDocument.tryFromJson({
        'version': {'app': 'pure_live', 'schema': 2},
        'follows': {'bili:1': _room('1'), 'bili:2': 'not a map', 'bili:3': null},
        'history': {'bili:4': 7},
        'secrets': {'cookie/bilibili': 'SESSDATA=1', 'cookie/huya': 42},
      })!;
      expect(decoded.skipped, {BackupSection.follows: 2, BackupSection.history: 1, BackupSection.secrets: 1});
      expect(decoded.secrets, {'cookie/bilibili': 'SESSDATA=1'});
      expect(decoded.only({BackupSection.follows}).skipped, {
        BackupSection.follows: 2,
      }, reason: 'an unchecked section takes its count with it');

      final followsOnly = BackupDocument.tryFromJson({
        'version': {'app': 'pure_live', 'schema': 1, 'scope': 'follows'},
        'follows': {'bili:1': _room('1')},
        'history': {'bili:4': 7},
      })!;
      expect(followsOnly.skipped, isEmpty, reason: 'the history this scope never restores keeps no count');
    });

    test('a follows-only document says so and carries no other section', () {
      final document = BackupDocument(exportedAt: DateTime.utc(2026), presentSections: BackupSection.followsOnly);
      final json = document.toJson();
      expect(json.containsKey('history'), isFalse, reason: 'an unselected section is absent, not empty');
      expect(json['version'], containsPair('scope', 'follows'));
      final decoded = BackupDocument.tryDecode(document.encode())!;
      expect(decoded.followsOnly, isTrue);
      expect(decoded.isEmpty, isTrue);
      expect(decoded.counts.recordings, 0);
    });

    test('a schema-1 follows-only file (every section written) restores only follows and areas', () {
      final decoded = BackupDocument.tryDecode(
        '{"version":{"app":"pure_live","schema":1,"scope":"follows"},'
        '"follows":{"bili:1":{"roomId":"1"}},"history":{},"areaFollows":{},"recordings":{},"settings":{}}',
      )!;
      expect(decoded.presentSections, BackupSection.followsOnly);
      expect(decoded.hasHistory, isFalse, reason: 'the empty history map must not clear the device');
    });

    test('secrets ride as their own section and only() narrows the restore', () {
      final document = BackupDocument(
        exportedAt: DateTime.utc(2026),
        follows: {'bili:1': _room('1')},
        secrets: {'cookie/bilibili': 'SESSDATA=1'},
        presentSections: {BackupSection.follows, BackupSection.secrets},
      );
      final decoded = BackupDocument.tryDecode(document.encode())!;
      expect(decoded.secrets, {'cookie/bilibili': 'SESSDATA=1'});
      expect(decoded.hasSecrets, isTrue);
      final narrowed = decoded.only({BackupSection.follows});
      expect(narrowed.hasSecrets, isFalse);
      expect(narrowed.toJson().containsKey('secrets'), isFalse);
      expect(narrowed.follows.keys, ['bili:1']);
    });

    test('the IPTV setup and the multiview layout ride as keyed sections', () {
      final document = BackupDocument(
        exportedAt: DateTime.utc(2026),
        iptv: {
          'iptv.playlists.v1': {
            'items': [
              {'id': 'p1'},
              {'id': 'p2'},
            ],
          },
          'iptv.groups.v1': {'items': <Object?>[]},
        },
        multiview: {
          'current': {'layout': 'grid2x2', 'slots': <Object?>[]},
        },
        presentSections: {BackupSection.iptv, BackupSection.multiview},
      );
      final decoded = BackupDocument.tryDecode(document.encode())!;
      expect(decoded.presentSections, {BackupSection.iptv, BackupSection.multiview});
      expect(decoded.countOf(BackupSection.iptv), 2, reason: 'items across the keys, not the keys');
      expect(decoded.countOf(BackupSection.multiview), 1);
      expect(decoded.iptv['iptv.playlists.v1']!['items'], hasLength(2));
      expect(decoded.multiview['current']!['layout'], 'grid2x2');
      expect(decoded.hasFollows, isFalse);
    });

    test('the export name carries the kind and the moment', () {
      final moment = DateTime(2026, 10, 31, 9, 5, 7);
      expect(BackupDocument.exportFileName(moment), 'pure_live_backup_20261031_090507.json');
      expect(BackupDocument.exportFileName(moment, followsOnly: true), 'pure_live_follows_20261031_090507.json');
    });
  });

  group('BackupRepository.apply', () {
    test('a present section replaces its store, an absent one is left alone', () async {
      final built = _build();
      await built.follows.put('old:1', _room('1'));
      await built.history.put('old:2', _room('2'));

      await built.repository.apply(
        BackupDocument(
          exportedAt: DateTime.utc(2026),
          follows: {'bili:1': _room('1')},
          presentSections: {BackupSection.follows},
        ),
      );

      expect(built.follows.keys, ['bili:1'], reason: 'the document is the word on follows');
      expect(built.history.keys, ['old:2'], reason: 'a section it never carried must not be emptied');
    });

    test('a follows-only document touches only follows and areas', () async {
      final built = _build();
      await built.history.put('old:2', _room('2'));
      await built.recordings.put('bili:9', _task(id: 'bili:9').toJson());

      await built.repository.apply(
        BackupDocument(
          exportedAt: DateTime.utc(2026),
          follows: {'bili:1': _room('1')},
          presentSections: BackupSection.followsOnly,
        ),
      );

      expect(built.follows.keys, ['bili:1']);
      expect(built.history.keys, ['old:2']);
      expect(built.recordings.length, 1);
    });

    test('an empty document is refused before anything is written', () async {
      final built = _build();
      await built.follows.put('old:1', _room('1'));

      await expectLater(
        built.repository.apply(BackupDocument(exportedAt: DateTime.utc(2026), presentSections: const {})),
        throwsA(isA<BackupDocumentEmpty>()),
      );
      expect(built.follows.keys, ['old:1']);
    });

    test('a restore with a live take is refused and leaves every store as it was', () async {
      final built = _build();
      await built.follows.put('old:1', _room('1'));
      await built.recordings.put('bili:9', _task(id: 'bili:9', state: RecordingTaskState.recording).toJson());

      await expectLater(
        built.repository.apply(
          BackupDocument(
            exportedAt: DateTime.utc(2026),
            follows: {'bili:1': _room('1')},
            recordings: {'bili:3': _task(id: 'bili:3').toJson()},
          ),
        ),
        throwsA(isA<BackupRecordingsBusy>()),
      );
      expect(built.follows.keys, ['old:1'], reason: 'the guard runs before the first write');
      expect(built.recordings.keys, ['bili:9']);
    });

    test('restored tasks come back idle, and a take still finishing counts as live', () async {
      final built = _build();
      await built.recordings.put('bili:9', _task(id: 'bili:9', processing: true).toJson());

      await expectLater(
        built.repository.apply(
          BackupDocument(
            exportedAt: DateTime.utc(2026),
            recordings: {'bili:3': _task(id: 'bili:3').toJson()},
          ),
        ),
        throwsA(isA<BackupRecordingsBusy>()),
        reason: 'a join in progress owns its row, whoever wrote the document',
      );

      await built.recordings.clear();
      await built.repository.apply(
        BackupDocument(
          exportedAt: DateTime.utc(2026),
          recordings: {
            'bili:3': _task(id: 'bili:3', state: RecordingTaskState.recording, processing: true).toJson(),
            'broken': {'platform': '', 'roomId': ''},
          },
        ),
      );

      final restored = RecordingTaskRepository(built.recordings).list();
      expect(restored, hasLength(1), reason: 'an entry without a room cannot be recorded or listed usefully');
      expect(restored.single.state, RecordingTaskState.waiting, reason: 'no session runs behind a restored take');
      expect(restored.single.postProcessing, isFalse);
      expect(restored.single.postProcessingProgress, -1);
    });

    test('a follows-only backup asked for everything restores just the follows', () async {
      final built = _build();
      await built.history.put('old:2', _room('2'));
      // A follows-only file that also carries a history section: its scope
      // still decides, as the reference's downgrade did.
      final file = BackupDocument.tryFromJson({
        'version': {'app': 'pure_live', 'schema': 2, 'scope': 'follows'},
        'follows': {'bili:1': _room('1')},
        'areaFollows': <String, Object?>{},
        'history': {'bili:9': _room('9')},
      })!;
      final everything = file.only(BackupSection.values.toSet());
      expect(everything.presentSections, BackupSection.followsOnly);
      expect(file.restoresFollowsOnly, isTrue);

      await built.repository.apply(everything);

      expect(built.follows.keys, ['bili:1']);
      expect(built.history.keys, ['old:2'], reason: 'a follows-only file never touches the history');
    });
  });

  group('BackupRestoreLock', () {
    BackupDocument followsDocument(String id) => BackupDocument(
      exportedAt: DateTime.utc(2026),
      follows: {'bili:$id': _room(id)},
      presentSections: {BackupSection.follows},
    );

    test('a second restore is refused before it writes, on every repository sharing the lock', () async {
      final lock = BackupRestoreLock();
      final first = _build(lock: lock);
      // The repository the provider rebuilds when a store reopens: the same
      // lock, so the rebuild cannot let a second restore in.
      final second = _build(lock: lock);
      await second.follows.put('old:1', _room('1'));
      final hold = Completer<void>();
      first.follows.hold = hold;

      final running = first.repository.apply(followsDocument('2'));
      expect(lock.busy, isTrue);
      await expectLater(second.repository.apply(followsDocument('3')), throwsA(isA<BackupRestoreBusy>()));
      await expectLater(first.repository.apply(followsDocument('3')), throwsA(isA<BackupRestoreBusy>()));
      expect(second.follows.keys, ['old:1'], reason: 'the refused restore wrote nothing');

      final idle = lock.idle;
      hold.complete();
      await running;
      await idle;
      expect(lock.busy, isFalse);
      expect(first.follows.keys, ['bili:2']);

      await second.repository.apply(followsDocument('3'));
      expect(second.follows.keys, ['bili:3'], reason: 'free again once the first one ended');
    });

    test('a refused restore frees the lock', () async {
      final lock = BackupRestoreLock();
      final built = _build(lock: lock);

      await expectLater(
        built.repository.apply(BackupDocument(exportedAt: DateTime.utc(2026), presentSections: const {})),
        throwsA(isA<BackupDocumentEmpty>()),
      );
      expect(lock.busy, isFalse);
      await built.repository.apply(followsDocument('1'));
      expect(built.follows.keys, ['bili:1']);
    });
  });

  group('BackupRepository.preview', () {
    setUp(() => StoragePrefs.initSeeded(const <String, Object?>{}));

    test('keyed sections tell additions and removals apart by identity, not by count', () async {
      final built = _build();
      for (final id in ['1', '2', '3']) {
        await built.follows.put('bili:$id', _room(id));
      }
      await built.areas.put('bili:a', {'areaId': 'a'});

      final preview = built.repository.preview(
        BackupDocument(
          exportedAt: DateTime.utc(2026),
          follows: {
            for (final id in ['2', '3', '4']) 'bili:$id': _room(id),
          },
          areaFollows: {
            'bili:a': {'areaId': 'a'},
          },
          presentSections: {BackupSection.follows, BackupSection.areaFollows},
        ),
      );

      final follows = preview.parts.first;
      expect((follows.section, follows.current, follows.incoming), (BackupSection.follows, 3, 3));
      expect((follows.added, follows.removed), (1, 1));
      expect(follows.unchanged, isFalse, reason: 'three in and three out is still a change');
      expect(preview.parts.last.unchanged, isTrue);
      expect(preview.kept, [
        BackupSection.history,
        BackupSection.recordings,
        BackupSection.settings,
      ], reason: 'what the file lacks stays; boxes this device lacks are not named');
      expect(preview.changesSomething, isTrue);
    });

    test("the restore's own filters decide the counts, and the restore keeps to them", () async {
      await StoragePrefs.initSeeded(const <String, Object?>{
        'theme.mode': 'dark',
        'playback.muted': false,
        'history.limit': 100,
      });
      final built = _build();
      await built.recordings.put('bili:9', _task(id: 'bili:9').toJson());
      final document = BackupDocument.tryFromJson({
        'version': {'app': 'pure_live', 'schema': 2},
        'recordings': {
          'bili:9': _task(id: 'bili:9').toJson(),
          'broken': {'platform': '', 'roomId': ''},
          'garbage': 'not a task',
        },
        'settings': {
          'theme.mode': 'dark',
          'playback.muted': true,
          // Unset here, and an int where a double is written.
          'browse.crossSpacing': 8,
          // The wrong shape: skipped, as the restore skips it.
          'history.limit': 'many',
          // A newer build's pref: ignored, as the restore ignores it.
          'some.future.pref': 1,
        },
      })!;

      final preview = built.repository.preview(document);

      final tasks = preview.parts.single;
      expect((tasks.current, tasks.incoming, tasks.added, tasks.removed), (1, 1, 0, 0));
      expect((preview.settingsInFile, preview.settingsChanged), (3, 2));
      expect(preview.skipped, 3, reason: 'the non-map task, the roomless one, the misshapen setting');

      await built.repository.apply(document);
      expect(StoragePrefs.getBool('playback.muted'), isTrue);
      expect(StoragePrefs.getDouble('browse.crossSpacing'), 8.0);
      expect(StoragePrefs.getInt('history.limit'), 100, reason: 'what the preview skipped the restore left alone');
      expect(RecordingTaskRepository(built.recordings).list().map((task) => task.id), ['bili:9']);
    });

    test('credentials count as written; a restore without them keeps the vault', () async {
      final vault = await SecretStore.load(vault: _MemoryVault({'cookie/bilibili': 'old'}));
      final built = _build(secrets: vault);

      final withSecrets = built.repository.preview(
        BackupDocument(
          exportedAt: DateTime.utc(2026),
          follows: {'bili:1': _room('1')},
          secrets: {'cookie/bilibili': 'SESSDATA=1', 'cookie/huya': 'x', 'cookie/douyu': ''},
          presentSections: {BackupSection.follows, BackupSection.secrets},
        ),
      );
      expect(withSecrets.accounts, 2, reason: 'an empty value writes no credential');
      expect(withSecrets.kept, isNot(contains(BackupSection.secrets)));

      final without = built.repository.preview(
        BackupDocument(
          exportedAt: DateTime.utc(2026),
          follows: {'bili:1': _room('1')},
          presentSections: {BackupSection.follows},
        ),
      );
      expect(without.accounts, 0);
      expect(without.kept, contains(BackupSection.secrets), reason: "the device's credentials stay as they are");
    });

    test('IPTV items compare by id, and the keys the document does not carry keep theirs', () async {
      final iptv = _MemoryStore();
      await iptv.put(IptvKeys.playlists, [
        {'id': 'p1'},
        {'id': 'p2'},
      ]);
      await iptv.put(IptvKeys.groups, [
        {'name': '新闻'},
      ]);
      final built = _build(iptv: iptv);

      final preview = built.repository.preview(
        BackupDocument(
          exportedAt: DateTime.utc(2026),
          iptv: {
            IptvKeys.playlists: {
              'items': [
                {'id': 'p2'},
                {'id': 'p3'},
              ],
            },
            IptvKeys.guideSources: {'items': 'not a list'},
          },
          presentSections: {BackupSection.iptv},
        ),
      );

      final part = preview.parts.single;
      expect((part.current, part.incoming, part.added, part.removed), (3, 3, 1, 1));
      expect(preview.skipped, 1, reason: 'a setup key whose items are not a list is not written');
    });

    test('the multiview compares the rooms in its slots', () async {
      final board = _MemoryStore();
      await board.put('current', {
        'layout': 'grid2x2',
        'slots': ['bili:1', null, 'bili:2', null],
      });
      final built = _build(multiview: board);

      final preview = built.repository.preview(
        BackupDocument(
          exportedAt: DateTime.utc(2026),
          multiview: {
            'current': {
              'layout': 'grid2x2',
              'slots': ['bili:2', 'bili:3', null, null],
            },
          },
          presentSections: {BackupSection.multiview},
        ),
      );

      final part = preview.parts.single;
      expect((part.current, part.incoming, part.added, part.removed), (2, 2, 1, 1));
    });

    test("this device's own backup changes nothing", () async {
      await StoragePrefs.initSeeded(const <String, Object?>{'theme.mode': 'dark', 'playback.muted': true});
      final built = _build();
      await built.follows.put('bili:1', _room('1'));
      await built.history.put('bili:2', _room('2'));
      await built.recordings.put('bili:3', _task(id: 'bili:3').toJson());

      final preview = built.repository.preview(built.repository.capture());

      expect(preview.parts.every((part) => part.unchanged), isTrue);
      expect((preview.settingsInFile, preview.settingsChanged, preview.skipped), (2, 0, 0));
      expect(preview.changesSomething, isFalse);
    });
  });
}
