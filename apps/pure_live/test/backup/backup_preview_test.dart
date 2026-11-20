import 'package:flutter_test/flutter_test.dart';
import 'package:live_iptv/live_iptv.dart' show IptvKeys;
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/features/backup/document/backup_document.dart';
import 'package:pure_live/features/backup/document/backup_repository.dart';
import 'package:pure_live/features/backup/document/restore_preview.dart';
import 'package:pure_live/modules/live/areas/data/area_follow_repository.dart';
import 'package:pure_live/modules/live/favorites/data/follow_repository.dart';
import 'package:pure_live/modules/live/history/history_repository.dart';
import 'package:pure_live/modules/live/recorder/data/recording_repository.dart';
import 'package:pure_live/modules/live/recorder/data/recording_task.dart';

/// The restore's preview: the identity comparison that tells twelve rooms
/// in and twelve out apart, the IPTV items named by their own field, the
/// multiview walls read through their one shared reader, and the preview's
/// promise matching what the restore itself writes — the same tasks idle,
/// the same keys written, the same settings through the same gate.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StorageStores stores;
  late BackupRepository repository;

  setUp(() async {
    stores = await StorageStores.openInMemory();
    await StoragePrefs.init();
    repository = BackupRepository(
      follows: FollowRepository(await stores.openStore('follows')),
      history: HistoryRepository(await stores.openStore('history')),
      areaFollows: AreaFollowRepository(await stores.openStore('area_follows')),
      recordings: RecordingTaskRepository(await stores.openStore('recordings')),
      iptv: await stores.openStore(IptvKeys.table),
      multiview: await stores.openStore('multiview'),
    );
  });

  tearDown(() => stores.close());

  test('the comparison tells identity apart from count', () {
    // Twelve in and twelve out is not "no change": the keys decide.
    final swapped = RestorePart.compare(
      BackupSection.follows,
      [for (var i = 0; i < 12; i++) 'old$i'],
      [for (var i = 0; i < 12; i++) 'new$i'],
    );
    expect(swapped.current, 12);
    expect(swapped.incoming, 12);
    expect(swapped.added, 12);
    expect(swapped.removed, 12);
    expect(swapped.unchanged, isFalse);

    final same = RestorePart.compare(BackupSection.follows, ['a', 'b'], ['b', 'a']);
    expect(same.unchanged, isTrue); // order is not a change
    expect(RestorePart.compare(BackupSection.history, ['a', 'a'], ['a', 'a', 'a']).unchanged, isFalse);
  });

  test('every IPTV setup key names its items by its own field', () {
    final identities = iptvItemIdentities({
      IptvKeys.playlists: [
        {'id': 'p1'},
        {'id': ''}, // a blank name falls back to the content
        'a bare string',
      ],
      IptvKeys.groups: [
        {'name': '体育'},
      ],
      IptvKeys.guideMappings: [
        {'channelId': 'cctv1'},
      ],
      IptvKeys.guideSources: [
        {'id': 'g1'},
      ],
    });
    expect(identities, contains('${IptvKeys.playlists}/p1'));
    expect(identities, contains('${IptvKeys.groups}/体育'));
    expect(identities, contains('${IptvKeys.guideMappings}/cctv1'));
    expect(identities, contains('${IptvKeys.guideSources}/g1'));
    // The unnamed and the bare count by what they are, so two different
    // shapes never read as the same row.
    expect(identities.where((identity) => identity.startsWith('${IptvKeys.playlists}/')), hasLength(3));
  });

  test('the multiview walls read through their one shared reader', () {
    final rooms = multiviewRooms({
      'wall-a': {
        'slots': ['roomA', '', 'roomB'],
      },
      'wall-b': '{"slots":["roomC"]}', // the stored JSON text reads the same
      'wall-junk': 'not a wall',
    });
    expect(rooms, ['roomA', 'roomB', 'roomC']);
    expect(multiviewRooms({'wall': <String, Object?>{}}), isEmpty);
  });

  test('the preview promises what the restore writes, section by section', () async {
    final followsStore = repository.follows.store;
    final historyStore = repository.history.store;
    final recordingsStore = repository.recordings.store;
    final iptvStore = repository.iptv!;
    final multiviewStore = repository.multiview!;

    // The device as it stands.
    await followsStore.put('F1', {'roomId': 1});
    await historyStore.put('H1', {'roomId': 2});
    await recordingsStore.put('t1', _taskJson(id: 't1', roomId: '1').toJson());
    await iptvStore.put(IptvKeys.playlists, [
      {'id': 'old'},
    ]);
    await multiviewStore.put('wall-a', {
      'slots': ['roomA'],
    });
    await StoragePrefs.setString('log.level', 'debug');

    // The document asks for changes in every held section, plus two rows
    // the readers must refuse and count.
    final document = BackupDocument(
      exportedAt: DateTime.utc(2026, 11, 21),
      follows: {
        'F1': {'roomId': 1},
        'F2': {'roomId': 2},
      },
      history: {
        'H2': {'roomId': 9},
      },
      areaFollows: {
        'A1': {'areaId': 3},
      },
      recordings: {
        't1': _taskJson(id: 't1', roomId: '1').toJson(), // the same seat, unchanged
        't2': _taskJson(id: 't2', roomId: '2').toJson(), // a new task
        't3': _taskJson(id: 't3', roomId: '').toJson(), // no room: refused, and counted
      },
      settings: {'log.level': 'info', 'brand.new.key': 'x'},
      iptv: {
        IptvKeys.playlists: {
          'items': [
            {'id': 'old'},
            {'id': 'new'},
          ],
        },
        IptvKeys.groups: {'items': []},
        'iptv.not-setup.v1': {
          'items': [1],
        }, // outside the setup: never written
      },
      multiview: {
        'wall-a': {
          'slots': ['roomB'],
        },
      },
      presentSections: BackupSection.all,
    );

    final preview = repository.preview(document);
    expect(preview.parts.map((part) => part.section).toList(), [
      BackupSection.follows,
      BackupSection.areaFollows,
      BackupSection.history,
      BackupSection.recordings,
      BackupSection.iptv,
      BackupSection.multiview,
    ]);
    final partOf = {for (final part in preview.parts) part.section: part};
    expect(partOf[BackupSection.follows]!.added, 1); // F2 arrives
    expect(partOf[BackupSection.follows]!.removed, 0);
    expect(partOf[BackupSection.areaFollows]!.added, 1); // A1 arrives
    expect(partOf[BackupSection.history]!.added, 1); // H2 in
    expect(partOf[BackupSection.history]!.removed, 1); // H1 out — one in, one out is still a change
    expect(partOf[BackupSection.recordings]!.added, 1); // t2 lands; t3 never would
    expect(partOf[BackupSection.iptv]!.added, 1); // playlists/new and groups' empty list keep the seat count
    expect(partOf[BackupSection.iptv]!.removed, 0);
    expect(partOf[BackupSection.multiview]!.added, 1); // roomB in
    expect(partOf[BackupSection.multiview]!.removed, 1); // roomA out

    // The counts the confirm shows beside the parts.
    expect(preview.kept, isEmpty); // every held section is carried
    expect(preview.followsOnlyFile, isFalse);
    expect(preview.settingsInFile, 1); // the known key only
    expect(preview.settingsChanged, 1); // debug → info
    expect(preview.settingsUnknown, 1); // brand.new.key
    expect(preview.skipped, 1); // the room-less task; the not-setup key never counted
    expect(preview.accounts, 0); // no vault, no accounts
    expect(preview.changesSomething, isTrue);
  });

  test('a narrowed document keeps its uncarried boxes, and says the file is follows-only', () async {
    await repository.follows.store.put('F1', {'roomId': 1});
    final document = BackupDocument(
      exportedAt: DateTime.utc(2026, 11, 21),
      follows: {
        'F1': {'roomId': 1},
      },
      presentSections: BackupSection.followsOnly,
    );

    final preview = repository.preview(document, followsOnlyFile: true);
    expect(preview.followsOnlyFile, isTrue);
    expect(preview.kept.map((section) => section), containsAll([BackupSection.history, BackupSection.settings]));
    expect(preview.kept.contains(BackupSection.follows), isFalse);
    expect(preview.settingsInFile, 0);
    expect(preview.changesSomething, isFalse); // the rooms already stand exactly so
  });

  test('a document that would change nothing says so', () async {
    await StoragePrefs.setString('log.level', 'debug');
    final document = repository.capture();
    final preview = repository.preview(document);
    expect(preview.changesSomething, isFalse); // the device backs itself up
    expect(preview.parts.every((part) => part.unchanged), isTrue);
    expect(preview.settingsChanged, 0);
  });
}

/// One recording task's storage JSON, as the document carries it.
RecordingTask _taskJson({required String id, required String roomId}) => RecordingTask(
  id: id,
  platform: 'bilibili',
  roomId: roomId,
  roomTitle: 'room $roomId',
  state: RecordingTaskState.waiting,
  startedAt: DateTime.utc(2026, 11, 21),
);
