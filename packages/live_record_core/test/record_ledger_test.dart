import 'package:live_record_core/live_record_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/fakes.dart';

void main() {
  group('capture-safe naming', () {
    const naming = RecordNaming(rootDirectory: '/rec');
    final started = DateTime(2026, 10, 14, 22, 40);

    test('ffmpeg only ever sees an ASCII path', () {
      final paths = naming.paths(
        taskId: 'rec_a1b2c3d4e5f6',
        platformId: 'douyin',
        anchorName: '主播8891',
        roomId: '8891',
        startedAt: started,
      );

      expect(paths.sessionDirectory, p.join('/rec', 'douyin', 'zhubo8891', '2026-10-14'));
      expect(paths.capturePrefix, 'rec_a1b2c3d4e5f6');
      expect(paths.asciiMergedPath, endsWith('rec_a1b2c3d4e5f6.combined.mp4'));
      expect(
        RegExp(r'^[\x00-\x7F]+$').hasMatch(paths.sessionDirectory + paths.capturePrefix),
        isTrue,
        reason: 'a non-ASCII path is what makes the Windows build fail to open the output at all',
      );
    });

    test("the display name keeps the anchor's own script", () {
      final paths = naming.paths(
        taskId: 'rec_a1b2c3d4e5f6',
        platformId: 'douyin',
        anchorName: '主播8891',
        roomId: '8891',
        startedAt: started,
      );

      expect(
        paths.displayNameFor(anchorName: '主播8891', roomTitle: '今晚打老虎', startedAt: started),
        '主播8891_2026-10-14_2240_今晚打老虎.mp4',
      );
    });

    test('the identifier style drops pinyin entirely', () {
      const byId = RecordNaming(rootDirectory: '/rec', anchorDirectoryStyle: AnchorDirectoryStyle.identifier);
      final paths = byId.paths(
        taskId: 'rec_1',
        platformId: 'douyin',
        anchorName: '🎵🎶',
        roomId: '8891',
        startedAt: started,
      );

      expect(paths.sessionDirectory, endsWith(p.join('douyin', '8891', '2026-10-14')));
    });

    test('a name with nothing portable in it still yields a directory', () {
      final paths = naming.paths(
        taskId: 'rec_1',
        platformId: 'douyin',
        anchorName: '···',
        roomId: '8891',
        startedAt: started,
      );

      expect(paths.anchorSlug, isNot('unknown'));
      expect(paths.anchorSlug, '8891', reason: 'a numeric room id beats an empty component');
    });

    test('hostile labels cannot escape their directory', () {
      expect(safePathComponent('../../etc/passwd'), 'etc_passwd');
      expect(safePathComponent('con'), '_con', reason: 'a Windows device name is not a directory');
      expect(safePathComponent('   '), 'unknown');
      expect(safePinyinComponent(''), 'unknown');
    });

    test('capture ids are ASCII, bounded and different', () {
      final ids = <String>{for (var index = 0; index < 200; index++) RecordNaming.newTaskId()};

      expect(ids, hasLength(200));
      expect(ids.every((id) => RegExp(r'^rec_[0-9a-f]{12}$').hasMatch(id)), isTrue);
    });
  });

  group('the task record', () {
    final task = RecordTask(
      taskId: 'rec_a1b2c3d4e5f6',
      target: const RecordTarget(
        platform: 'douyin',
        roomId: '8891',
        anchorName: '主播8891',
        roomTitle: '今晚打老虎',
        watchUrl: 'https://live.douyin.com/8891',
      ),
      paths: const RecordPaths(
        rootDirectory: '/rec',
        platformSlug: 'douyin',
        anchorSlug: 'zhubo8891',
        day: '2026-10-14',
        taskId: 'rec_a1b2c3d4e5f6',
      ),
      createdAt: DateTime.utc(2026, 10, 14),
      status: RecordStatus.merging,
      roomState: RoomState.ended,
      stage: ArtifactStage.unmergedSegments,
      sawLive: true,
      pendingAttempts: const <PendingAttempt>[
        PendingAttempt(
          directory: '/x',
          prefix: 'rec_a1b2c3d4e5f6',
          segments: 3,
          bytes: 3000,
          mediaTime: Duration(seconds: 30),
        ),
        PendingAttempt(
          directory: '/x',
          prefix: 'rec_a1b2c3d4e5f6_r1',
          segments: 1,
          bytes: 900,
          mediaTime: Duration(seconds: 9),
          damaged: true,
        ),
      ],
      mergedFile: '/x/merged.mp4',
      desiredFile: '/x/主播8891.mp4',
      recordedFor: const Duration(seconds: 39),
      bytesWritten: 3900,
      segments: 4,
      failureReason: '分段含损坏包',
      failureCount: 2,
    );

    test('survives a round trip through the store', () {
      final back = RecordTask.fromJson(task.toJson())!;

      expect(back.taskId, task.taskId);
      expect(back.status, RecordStatus.merging);
      expect(back.roomState, RoomState.ended);
      expect(back.stage, ArtifactStage.unmergedSegments);
      expect(back.sawLive, isTrue);
      expect(back.pendingAttempts, hasLength(2));
      expect(back.pendingAttempts.last.damaged, isTrue);
      expect(back.desiredFile, '/x/主播8891.mp4');
      expect(back.paths.sessionDirectory, p.join('/rec', 'douyin', 'zhubo8891', '2026-10-14'));
      expect(back.failureReason, '分段含损坏包');
    });

    test('a signed stream address is never stored', () {
      final json = task.toJson();

      expect(json.keys, isNot(contains('streamUrl')));
      expect(json.values.whereType<String>().any((value) => value.contains('expires')), isFalse);
      expect(
        json['target'],
        isA<Map<String, Object?>>().having((t) => t['watchUrl'], 'watch page', 'https://live.douyin.com/8891'),
        reason: 'the room page is fine to keep; the media address is a credential and expires',
      );
    });

    test('a record that cannot say where its files are is dropped', () {
      expect(RecordTask.fromJson(<String, Object?>{'taskId': 'rec_1'}), isNull);
      expect(RecordTask.fromJson(<String, Object?>{'taskId': 'rec_1', 'root': '/r', 'day': '2026-10-14'}), isNull);
    });

    test('an unknown stored name falls back instead of throwing', () {
      final json = task.toJson()..['status'] = 'suspended_by_a_future_version';
      final back = RecordTask.fromJson(json)!;

      expect(back.status, RecordStatus.queued, reason: 'a later build must not make this one crash at open');
    });

    test('the outstanding work is what recovery reads', () {
      expect(task.hasOutstandingWork, isTrue);
      expect(task.pendingTotals.segments, 4);
      expect(task.pendingTotals.mediaTime, const Duration(seconds: 39));
    });
  });

  group('the json store', () {
    test('reads back what it wrote, oldest first', () async {
      final store = RecordJsonStore(MemorySlots());
      final older = RecordTask.forTarget(
        target: target,
        paths: const RecordPaths(
          rootDirectory: '/rec',
          platformSlug: 'douyin',
          anchorSlug: 'zhubo8891',
          day: '2026-10-13',
          taskId: 'rec_old',
        ),
        now: DateTime.utc(2026, 10, 13),
      );
      final newer = RecordTask.forTarget(
        target: target,
        paths: const RecordPaths(
          rootDirectory: '/rec',
          platformSlug: 'douyin',
          anchorSlug: 'zhubo8891',
          day: '2026-10-14',
          taskId: 'rec_new',
        ),
        now: DateTime.utc(2026, 10, 14),
      );

      await store.save(newer);
      await store.save(older);

      expect((await store.loadAll()).map((task) => task.taskId), <String>['rec_old', 'rec_new']);

      await store.remove('rec_old');
      expect((await store.loadAll()).map((task) => task.taskId), <String>['rec_new']);
    });

    test('one half-written record costs only itself', () async {
      final slots = MemorySlots();
      final store = RecordJsonStore(slots);
      final good = RecordTask.forTarget(
        target: target,
        paths: const RecordPaths(
          rootDirectory: '/rec',
          platformSlug: 'douyin',
          anchorSlug: 'zhubo8891',
          day: '2026-10-14',
          taskId: 'rec_good',
        ),
        now: DateTime.utc(2026, 10, 14),
      );

      await store.save(good);
      slots.files['broken.json'] = '{"taskId": "rec_x", "created';
      slots.unreadable = 'gone.json';

      expect((await store.loadAll()).map((task) => task.taskId), <String>['rec_good']);
    });
  });
}
