// Module: test/data/watch_progress_test.dart
// Purpose: Pins the two resume thresholds, the versioned row and the collision-free key.
// Author: liuchuancong
// Created: 2026-10-10

import 'dart:convert';

import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_storage/pure_live_storage.dart';
import 'package:pure_live_utils/pure_live_utils.dart';
import 'package:pure_live_vod/pure_live_vod.dart';
import 'package:test/test.dart';

ContentRef _ref(String sourceId, String contentId) =>
    ContentRef(sourceId: sourceId, contentId: contentId, kind: ContentKind.series);

void main() {
  late MemoryKeyValueStore store;
  late FixedClock clock;
  late StoredWatchProgress progress;

  setUp(() {
    store = MemoryKeyValueStore();
    clock = FixedClock(DateTime.utc(2026, 10, 10));
    progress = StoredWatchProgress(store: store, clock: clock);
  });

  test('test_storedWatchProgress_roundTripsTheSavedPosition', () async {
    await progress.save(_ref('s1', 'e1'), const Duration(minutes: 4), duration: const Duration(minutes: 40));

    final read = await progress.read(_ref('s1', 'e1'));
    expect(read?.position, const Duration(minutes: 4));
    expect(read?.duration, const Duration(minutes: 40));
    expect(read?.updatedAt, DateTime.utc(2026, 10, 10));
    expect(read!.progress, closeTo(0.1, 0.001));
  });

  test('test_storedWatchProgress_belowTheLeadInIsNotResumable', () async {
    await progress.save(_ref('s1', 'e1'), const Duration(seconds: 10), duration: const Duration(minutes: 20));
    expect((await progress.read(_ref('s1', 'e1')))!.isResumable, isFalse);

    await progress.save(_ref('s1', 'e1'), const Duration(minutes: 1), duration: const Duration(minutes: 20));
    expect((await progress.read(_ref('s1', 'e1')))!.isResumable, isTrue);
  });

  test('test_storedWatchProgress_nearTheEndRestartsInsteadOfResuming', () async {
    // The bug this replaces: only "position > 30s" was asked, so a finished episode resumed at 99%.
    await progress.save(
      _ref('s1', 'e1'),
      const Duration(minutes: 39, seconds: 40),
      duration: const Duration(minutes: 40),
    );

    final read = await progress.read(_ref('s1', 'e1'));
    expect(read!.isResumable, isFalse);
    expect(read.position, isNot(Duration.zero), reason: 'the position is still saved, just not worth seeking to');
  });

  test('test_storedWatchProgress_unknownLengthUsesTheLeadInAlone', () async {
    await progress.save(_ref('s1', 'e1'), const Duration(minutes: 90));

    final read = await progress.read(_ref('s1', 'e1'));
    expect(read!.isResumable, isTrue);
    expect(read.progress, isNull, reason: 'there is no length to divide by, so no fraction is invented');
  });

  test('test_storedWatchProgress_idsContainingSlashesDoNotCollide', () async {
    // sourceId/contentId joined by '/' made 'a' + 'b/c' and 'a/b' + 'c' one row.
    await progress.save(_ref('a', 'b/c'), const Duration(minutes: 2), duration: const Duration(minutes: 30));
    await progress.save(_ref('a/b', 'c'), const Duration(minutes: 7), duration: const Duration(minutes: 30));

    expect((await progress.read(_ref('a', 'b/c')))!.position, const Duration(minutes: 2));
    expect((await progress.read(_ref('a/b', 'c')))!.position, const Duration(minutes: 7));
  });

  test('test_storedWatchProgress_corruptRow_isReportedAndReadsAsAbsent', () async {
    final failures = <WatchProgressReadFailure>[];
    final checked = StoredWatchProgress(store: store, clock: clock, onReadFailure: failures.add);
    await store.write('progress.${identityKey(<Object?>['s1', 'e1'])}', '{not json');

    expect(await checked.read(_ref('s1', 'e1')), isNull);
    expect(failures.single.reason, contains('unusable'));

    await checked.save(_ref('s1', 'e1'), const Duration(minutes: 1));
    expect((await checked.read(_ref('s1', 'e1')))!.isResumable, isTrue);
    expect(failures, hasLength(1), reason: 'a healed row stops reporting the old damage');
  });

  test('test_storedWatchProgress_newerRowVersionIsRefusedNotRewrittenBlindly', () async {
    final failures = <WatchProgressReadFailure>[];
    final checked = StoredWatchProgress(store: store, clock: clock, onReadFailure: failures.add);
    final key = 'progress.${identityKey(<Object?>['s1', 'e1'])}';
    await store.write(
      key,
      jsonEncode(<String, Object?>{'v': 99, 'positionMs': 1000, 'updatedAt': '2026-10-10T00:00:00Z'}),
    );

    expect(await checked.read(_ref('s1', 'e1')), isNull);
    expect(await store.read(key), contains('99'));
  });

  test('test_storedWatchProgress_rejectsImpossibleArguments', () async {
    expect(() => progress.save(_ref('s1', 'e1'), const Duration(seconds: -1)), throwsArgumentError);
    expect(
      () => progress.save(_ref('s1', 'e1'), const Duration(minutes: 1), duration: Duration.zero),
      throwsArgumentError,
      reason: 'a zero length would make every position "past the end" and stop resuming forever',
    );
  });

  test('test_storedWatchProgress_namespaceSeparatesApps', () async {
    await progress.save(_ref('s1', 'e1'), const Duration(minutes: 5));
    final other = StoredWatchProgress(store: store, clock: clock, namespace: 'pure_music');

    expect(await other.read(_ref('s1', 'e1')), isNull);
  });

  test('test_storedWatchProgress_removeMakesItAbsent', () async {
    await progress.save(_ref('s1', 'e1'), const Duration(minutes: 5));
    await progress.remove(_ref('s1', 'e1'));

    expect(await progress.read(_ref('s1', 'e1')), isNull);
  });
}
