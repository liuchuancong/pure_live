// Module: test/data/stored_search_history_test.dart
// Purpose: Pins the history's ordering, bound, migration and the reporting of an unreadable row.
// Author: liuchuancong
// Created: 2026-10-10

import 'dart:convert';

import 'package:pure_live_search_feature/pure_live_search_feature.dart';
import 'package:pure_live_storage/pure_live_storage.dart';
import 'package:pure_live_utils/pure_live_utils.dart';
import 'package:test/test.dart';

void main() {
  test('test_storedSearchHistory_record_movesExistingTermToFront', () async {
    final clock = FixedClock(DateTime.utc(2026, 10, 10));
    final history = StoredSearchHistory(store: MemoryKeyValueStore(), clock: clock);

    await history.record(SearchTerm.tryParse('first')!);
    clock.advance(const Duration(minutes: 1));
    await history.record(SearchTerm.tryParse('second')!);
    clock.advance(const Duration(minutes: 1));
    final result = await history.record(SearchTerm.tryParse('first')!);

    expect(result.map((entry) => entry.term.display), <String>['first', 'second']);
    expect(result.length, 2, reason: 'a re-used keyword is one row, not two');
  });

  test('test_storedSearchHistory_record_evictsLeastRecentlyUsed', () async {
    final clock = FixedClock(DateTime.utc(2026, 10, 10));
    final history = StoredSearchHistory(store: MemoryKeyValueStore(), maxLength: 2, clock: clock);

    for (final keyword in <String>['a', 'b', 'c']) {
      clock.advance(const Duration(minutes: 1));
      await history.record(SearchTerm.tryParse(keyword)!);
    }

    expect((await history.recent()).map((entry) => entry.term.display), <String>['c', 'b']);
  });

  test('test_storedSearchHistory_readsBackWhatWasWritten', () async {
    final store = MemoryKeyValueStore();
    final clock = FixedClock(DateTime.utc(2026, 10, 10));
    await StoredSearchHistory(store: store, clock: clock).record(SearchTerm.tryParse('kept')!);

    // A second instance over the same store must see the row: this is the app restarting, not a cache hit.
    final reopened = await StoredSearchHistory(store: store, clock: clock).recent();
    expect(reopened.single.term.display, 'kept');
    expect(reopened.single.usedAt, DateTime.utc(2026, 10, 10));
  });

  test('test_storedSearchHistory_migratesTheVersionZeroList', () async {
    final store = MemoryKeyValueStore();
    await store.write('search.history', jsonEncode(<String>['legacy one', 'legacy two']));
    final failures = <SearchHistoryReadFailure>[];
    final history = StoredSearchHistory(store: store, onReadFailure: failures.add);

    final entries = await history.recent();
    expect(entries.map((entry) => entry.term.display), <String>['legacy one', 'legacy two']);
    // The migrated rows sort after anything with a real timestamp, oldest of them all.
    expect(entries.first.usedAt, DateTime.utc(1970));
    expect(failures, isEmpty, reason: 'a readable old shape is a migration, not a failure');

    await history.record(SearchTerm.tryParse('new')!);
    expect((await history.recent()).first.term.display, 'new');
  });

  test('test_storedSearchHistory_corruptRow_isReportedAndHealed', () async {
    final store = MemoryKeyValueStore();
    await store.write('search.history', '{not json');
    final failures = <SearchHistoryReadFailure>[];
    final history = StoredSearchHistory(store: store, onReadFailure: failures.add);

    expect(await history.recent(), isEmpty);
    expect(failures.single.reason, contains('unreadable'));

    await history.record(SearchTerm.tryParse('after')!);
    expect(await history.recent(), hasLength(1));
    // The healed row is the shared envelope, with this document's own version carried inside the value: the
    // envelope answers "a typed preference row", the inner v answers "an entry list with timestamps".
    final healed = await store.read('search.history') as Map<Object?, Object?>;
    expect(healed['c'], 'searchHistory');
    final document = healed['value']! as Map<Object?, Object?>;
    expect(document['v'], kSearchHistoryEnvelopeVersion);
    expect((document['items']! as List<Object?>).whereType<Map<Object?, Object?>>(), hasLength(1));
  });

  test('test_storedSearchHistory_newerEnvelopeVersion_isLeftAlone', () async {
    final store = MemoryKeyValueStore();
    await store.write(
      'search.history',
      jsonEncode(<String, Object?>{
        'v': 99,
        'items': <Object?>[
          <String, Object?>{'q': 'from a newer build', 'at': 0},
        ],
      }),
    );
    final failures = <SearchHistoryReadFailure>[];
    final history = StoredSearchHistory(store: store, onReadFailure: failures.add);

    expect(await history.recent(), isEmpty);
    expect(failures, hasLength(1));
    // Refusing to read it is not the same as rewriting it: the row a newer build wrote is still there.
    expect(await store.read('search.history'), contains('newer build'));
  });

  test('test_storedSearchHistory_namespacesPerApp', () async {
    final store = MemoryKeyValueStore();
    await StoredSearchHistory(store: store, namespace: 'live').record(SearchTerm.tryParse('stream')!);
    final music = StoredSearchHistory(store: store, namespace: 'music');

    expect(await music.recent(), isEmpty);
    expect(await store.keys(), contains('live.history'));
  });

  test('test_storedSearchHistory_rejectsAZeroBound', () {
    expect(
      () => StoredSearchHistory(store: MemoryKeyValueStore(), maxLength: 0),
      throwsA(isA<SearchHistoryConfigurationFailure>()),
    );
  });

  test('test_storedSearchHistory_removeAndClear', () async {
    final history = StoredSearchHistory(store: MemoryKeyValueStore(), clock: FixedClock(DateTime.utc(2026)));
    await history.record(SearchTerm.tryParse('drop me')!);
    await history.record(SearchTerm.tryParse('keep me')!);

    await history.remove(SearchTerm.tryParse('DROP ME')!);
    expect((await history.recent()).map((entry) => entry.term.display), <String>['keep me']);

    await history.clear();
    expect(await history.recent(), isEmpty);
  });
}
