import 'package:live_record_core/live_record_core.dart';
import 'package:test/test.dart';

import 'support/fakes.dart';

void main() {
  final naming = RecordNaming(rootDirectory: '/rec');

  RecordOrchestrator build({required FakeServices services, required RecordStore store, RecordPolicy? policy}) {
    final orchestrator = RecordOrchestrator(
      services: services,
      store: store,
      naming: naming,
      policy: policy ?? fastPolicy(),
    );
    addTearDown(orchestrator.dispose);

    return orchestrator;
  }

  /// A stored task, written through the store so recovery reads it back the same
  /// way a launch after a power cut would.
  Future<RecordTask> seed(
    RecordStore store, {
    RecordStatus status = RecordStatus.recording,
    List<PendingAttempt> pending = const <PendingAttempt>[],
    String? mergedFile,
  }) async {
    final task = RecordTask(
      taskId: 'rec_seedseedseed',
      target: target,
      paths: const RecordPaths(
        rootDirectory: '/rec',
        platformSlug: 'douyin',
        anchorSlug: 'zhubo8891',
        day: '2026-10-14',
        taskId: 'rec_seedseedseed',
      ),
      createdAt: DateTime.utc(2026, 10, 14, 12),
      status: status,
      roomState: RoomState.live,
      stage: pending.isNotEmpty ? ArtifactStage.unmergedSegments : ArtifactStage.mergedFile,
      sawLive: true,
      pendingAttempts: pending,
      mergedFile: mergedFile,
    );
    await store.save(task);

    return task;
  }

  const oneAttempt = PendingAttempt(
    directory: '/rec',
    prefix: 'rec_seedseedseed',
    segments: 4,
    bytes: 4096,
    mediaTime: Duration(seconds: 40),
  );

  group('a room that has not started', () {
    test('is waited for: no capture, no message', () async {
      final services = FakeServices(script: <RoomProbe>[offline, offline, offline]);
      final task = await build(services: services, store: RecordJsonStore(MemorySlots())).watch(target);
      await pump(80);

      expect(task.roomState, RoomState.waiting);
      expect(services.captures, isEmpty);
      expect(
        services.notices,
        isEmpty,
        reason: 'a room that never went live has not ended, so there is nothing to say',
      );
      expect(services.guardCount, 0, reason: 'the wake lock is for a recording, not for a wait');
    });
  });

  group('a session, start to finish', () {
    test('records while live, then closes, joins and names', () async {
      final services = FakeServices(script: <RoomProbe>[offline, live(), offline]);
      final store = RecordJsonStore(MemorySlots());
      final task = await build(services: services, store: store).watch(target);
      await pump(60);
      expect(services.captures, hasLength(1), reason: 'the room was found live on the second check');

      // The stream closing is what ends a session: the room is not polled while a
      // capture runs, so this is the signal that the broadcast stopped.
      services.captures.single.end();
      await pump(120);
      expect(services.captures.single.stopCalled, isTrue);
      expect(services.fileLayer.merges, hasLength(1));
      expect(services.fileLayer.renames, hasLength(1));
      expect(task.status, RecordStatus.completed);
      expect(task.roomState, RoomState.ended);
      expect(task.stage, ArtifactStage.published);
      expect(task.pendingAttempts, isEmpty, reason: 'the ledger stops claiming work it has done');
      expect(task.publishedFile, endsWith('.mp4'));
      expect(task.publishedFile, contains('主播8891'));
      expect(services.notices.map((notice) => notice.kind).toList(), <RecordNoticeKind>[
        RecordNoticeKind.liveStarted,
        RecordNoticeKind.liveEnded,
        RecordNoticeKind.recordingSaved,
      ]);
      expect(services.releasedGuards, 1, reason: 'the screen may sleep again once the recording is done');
    });

    test('says 开播 once, however many polls find it live', () async {
      final services = FakeServices(script: <RoomProbe>[live(), live(), live(), live(), offline]);
      await build(services: services, store: RecordJsonStore(MemorySlots())).watch(target);
      await pump(60);
      services.captures.single.end();
      await pump(200);

      expect(
        services.notices.where((notice) => notice.kind == RecordNoticeKind.liveStarted),
        hasLength(1),
        reason: 'one notification per live session is what keeps twenty rooms of monitoring listendable',
      );
      expect(services.captures, hasLength(2), reason: 'the reconnect is a second attempt, not a second session');
    });

    test('keeps the signed address out of everything it writes down', () async {
      final services = FakeServices(
        script: <RoomProbe>[
          live(url: 'https://cdn.test/a.flv?sign=secret'),
          offline,
        ],
      );
      final slots = MemorySlots();
      await build(services: services, store: RecordJsonStore(slots)).watch(target);
      await pump();
      services.captures.single.end();
      await pump(120);

      expect(slots.files.values.join('\n'), isNot(contains('sign=secret')));
    });
  });

  group('a dropped stream', () {
    test('with the room still answering live is retried, and both runs are joined once', () async {
      final services = FakeServices(script: <RoomProbe>[live(), live(), offline]);
      final task = await build(services: services, store: RecordJsonStore(MemorySlots())).watch(target);
      await pump();

      // The CDN stops delivering while the room still answers live: the capture
      // ends, the next check finds it live again, and the second run continues the
      // same session under its own attempt prefix.
      services.captures.single.end();
      await pump(60);
      expect(services.captures.length, greaterThan(1), reason: 'a dropped connection is retried, not an ending');
      services.captures.last.end();
      await pump(150);
      expect(services.fileLayer.merges, hasLength(1), reason: 'one session, one joined file');
      expect(services.fileLayer.merges.single.length, services.captures.length);
      expect(task.recordedFor, Duration(seconds: 30 * services.captures.length));
      expect(task.status, RecordStatus.completed);
    });

    test('a capture that refuses to open retries rather than failing the room', () async {
      final services = _RefusingServices(failures: 1);
      final task = await build(services: services, store: RecordJsonStore(MemorySlots())).watch(target);
      await pump(120);

      expect(task.failureCount, 1);
      expect(services.opened, greaterThanOrEqualTo(2), reason: 'the room says live; one failed start is not a verdict');
      expect(task.status, isNot(RecordStatus.failed));
    });
  });

  group('the launch sweep', () {
    test('joins the segments a power cut left behind', () async {
      final files = FakeFiles();
      final services = FakeServices(script: <RoomProbe>[offline], files: files);
      final store = RecordJsonStore(MemorySlots());
      await seed(store, pending: <PendingAttempt>[oneAttempt]);
      final orchestrator = build(services: services, store: store);

      final report = await orchestrator.restore();
      final recovered = orchestrator.tasks.single;

      expect(report.joined, 1);
      expect(services.fileLayer.merges, hasLength(1));
      expect(services.fileLayer.renames, hasLength(1));
      expect(recovered.status, RecordStatus.completed);
      expect(recovered.publishedFile, isNotNull);
      expect(recovered.pendingAttempts, isEmpty);
      expect(
        services.notices.map((notice) => notice.kind),
        contains(RecordNoticeKind.recovered),
        reason: 'a file recovered from a crash is news the viewer should get',
      );
    });

    test('names a merged file that was never published', () async {
      final asciiPath = naming
          .paths(
            taskId: 'rec_seedseedseed',
            platformId: 'douyin',
            anchorName: target.anchorName,
            roomId: target.roomId,
            startedAt: DateTime.utc(2026, 10, 14, 12),
          )
          .asciiMergedPath;
      final files = FakeFiles()..existing.add(asciiPath);
      final services = FakeServices(script: <RoomProbe>[offline], files: files);
      final store = RecordJsonStore(MemorySlots());
      await seed(store, status: RecordStatus.interrupted, mergedFile: asciiPath);
      final orchestrator = build(services: services, store: store);

      final report = await orchestrator.restore();

      expect(report.published, 1);
      expect(orchestrator.tasks.single.publishedFile, isNotNull);
      expect(orchestrator.tasks.single.status, RecordStatus.completed);
    });

    test('a refused merge keeps the segments and asks again next launch', () async {
      final files = FakeFiles()..failMergeWith = 'ffprobe refused the segment list';
      final services = FakeServices(script: <RoomProbe>[offline], files: files);
      final store = RecordJsonStore(MemorySlots());
      final seeded = await seed(store, pending: <PendingAttempt>[oneAttempt]);
      final orchestrator = build(services: services, store: store);

      final report = await orchestrator.restore();
      final kept = orchestrator.tasks.single;

      expect(report.failures, <String>[seeded.taskId]);
      expect(kept.status, RecordStatus.interrupted);
      expect(kept.pendingAttempts, hasLength(1), reason: 'the evidence stays until the join actually runs');
      expect(kept.publishedFile, isNull);
    });

    test('a damaged attempt is never joined', () async {
      final files = FakeFiles();
      final services = FakeServices(script: <RoomProbe>[offline], files: files);
      final store = RecordJsonStore(MemorySlots());
      await seed(
        store,
        pending: <PendingAttempt>[
          PendingAttempt(
            directory: oneAttempt.directory,
            prefix: oneAttempt.prefix,
            segments: 4,
            bytes: 4096,
            mediaTime: oneAttempt.mediaTime,
            damaged: true,
          ),
        ],
      );

      await build(services: services, store: store).restore();

      expect(files.merges, isEmpty, reason: 'rewriting a damaged window can lose the whole file to save one minute');
      expect(services.notices.map((notice) => notice.kind), contains(RecordNoticeKind.failed));
    });

    test('a rename that cannot happen leaves the recording usable', () async {
      const asciiPath = 'C:/fake/ascii.mp4';
      final files = FakeFiles()
        ..existing.add(asciiPath)
        ..occupiedTarget = naming
            .paths(
              taskId: 'rec_seedseedseed',
              platformId: 'douyin',
              anchorName: target.anchorName,
              roomId: target.roomId,
              startedAt: DateTime.utc(2026, 10, 14, 12),
            )
            .displayPathFor(anchorName: target.anchorName, startedAt: DateTime.utc(2026, 10, 14, 12));
      final services = FakeServices(script: <RoomProbe>[offline], files: files);
      final store = RecordJsonStore(MemorySlots());
      await seed(store, status: RecordStatus.interrupted, mergedFile: asciiPath);
      final first = build(services: services, store: store);
      await first.restore();

      final kept = first.tasks.single;
      expect(kept.publishedFile, isNull);
      expect(kept.desiredFile, isNotNull, reason: 'the intent survives, so the next launch tries again');
      expect(files.existing, contains(asciiPath), reason: 'the capture-named file is never deleted by a rename');

      // The next launch, with the name free, finishes it.
      files.occupiedTarget = null;
      final later = FakeServices(script: <RoomProbe>[offline], files: files);
      final second = build(services: later, store: store);
      await second.restore();

      expect(second.tasks.single.publishedFile, isNotNull);
      expect(second.tasks.single.stage, ArtifactStage.published);
    });

    test('a task that owes nothing is left alone', () async {
      final services = FakeServices(script: <RoomProbe>[offline]);
      final store = RecordJsonStore(MemorySlots());
      await seed(store, status: RecordStatus.completed);

      final report = await build(services: services, store: store).restore();

      expect(report.nothingToFinish, 1);
      expect(services.fileLayer.renames, isEmpty);
    });
  });

  group('what may run at once, and when nothing may', () {
    test('the concurrency limit queues the second room rather than failing it', () async {
      final services = FakeServices(script: <RoomProbe>[live(), live(), live(), live(), live(), live()]);
      const other = RecordTarget(platform: 'bilibili', roomId: '777', anchorName: '另一个人');
      final orchestrator = build(
        services: services,
        store: RecordJsonStore(MemorySlots()),
        policy: fastPolicy(maxConcurrent: 1),
      );

      final first = await orchestrator.watch(target);
      final second = await orchestrator.watch(other);
      await pump(60);

      expect(orchestrator.capturingCount, 1);
      expect(first.status, RecordStatus.recording);
      expect(second.status, RecordStatus.queued);
    });

    test('a full disk is said before the first segment, not after the last', () async {
      final files = FakeFiles()..free = 10;
      final services = FakeServices(script: <RoomProbe>[live()], files: files);
      final task = await build(services: services, store: RecordJsonStore(MemorySlots())).watch(target);
      await pump(60);

      expect(task.status, RecordStatus.failed);
      expect(services.captures, isEmpty);
      expect(
        services.notices.single.detail,
        isNotNull,
        reason: '"there was no room" is a better report than an FFmpeg exit code at the end',
      );
    });

    test('a status endpoint that stops answering gives up and says so', () async {
      final services = FakeServices(
        script: <RoomProbe>[const RoomProbe(outcome: ProbeOutcome.unknown, detail: '503')],
      );
      final task = await build(services: services, store: RecordJsonStore(MemorySlots())).watch(target);
      await pump(120);

      expect(task.status, RecordStatus.failed);
      expect(services.notices.map((notice) => notice.kind), contains(RecordNoticeKind.failed));
    });

    test('stopping the watcher closes and finishes the recording it started', () async {
      final services = FakeServices(script: <RoomProbe>[live(), live(), live()]);
      final orchestrator = build(services: services, store: RecordJsonStore(MemorySlots()));
      final task = await orchestrator.watch(target);
      await pump();

      await orchestrator.stopWatching(task.taskId);
      await pump(60);

      expect(services.captures.single.stopCalled, isTrue);
      expect(services.fileLayer.merges, hasLength(1));
      expect(services.releasedGuards, 1);
      expect(task.publishedFile, isNotNull);
      expect(orchestrator.capturingCount, 0);
    });
  });
}

/// A service double whose first capture attempt throws, then succeeds.
class _RefusingServices extends FakeServices {
  new({required this._failures}) : super(script: <RoomProbe>[live(), live(), live(), live(), offline]);

  int _failures;
  int opened = 0;

  @override
  Future<RecordCapture> openCapture({required RecordTask task, required String streamUrl}) async {
    opened++;

    if (_failures > 0) {
      _failures--;

      throw StateError('the engine refused to start');
    }

    return await super.openCapture(task: task, streamUrl: streamUrl);
  }
}
