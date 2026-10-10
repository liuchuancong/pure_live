// Module: test/data/stored_home_layout_test.dart
// Purpose: Pins the layout row's versioning, namespacing and reported read failures.
// Author: liuchuancong
// Created: 2026-10-10

import 'dart:convert';

import 'package:pure_live_home/pure_live_home.dart';
import 'package:pure_live_storage/pure_live_storage.dart';
import 'package:test/test.dart';

void main() {
  test('test_storedHomeLayout_roundTripsThroughAReopenedStore', () async {
    final store = MemoryKeyValueStore();
    await StoredHomeLayout(
      store: store,
      namespace: 'pure_live',
    ).save(const HomeLayout(order: <String>['vod', 'live'], hidden: <String>['live']));

    final reopened = await StoredHomeLayout(store: store, namespace: 'pure_live').load();
    expect(reopened.order, <String>['vod', 'live']);
    expect(reopened.isHidden('live'), isTrue);
  });

  test('test_storedHomeLayout_writesAVersionedEnvelope', () async {
    final store = MemoryKeyValueStore();
    await StoredHomeLayout(store: store, namespace: 'app').save(const HomeLayout(order: <String>['x']));

    expect(jsonDecode(await store.read('app.home_layout') as String), <String, Object?>{
      'v': kHomeLayoutEnvelopeVersion,
      'order': <String>['x'],
      'hidden': <String>[],
    });
  });

  test('test_storedHomeLayout_namespacesPerApp', () async {
    final store = MemoryKeyValueStore();
    await StoredHomeLayout(store: store, namespace: 'pure_live').save(const HomeLayout(order: <String>['a']));

    expect((await StoredHomeLayout(store: store, namespace: 'pure_music').load()).order, isEmpty);
  });

  test('test_storedHomeLayout_rowWithoutHiddenList_isNotCalledCorrupt', () async {
    final store = MemoryKeyValueStore();
    await store.write(
      'app.home_layout',
      jsonEncode(<String, Object?>{
        'order': <String>['a', 'b'],
      }),
    );
    final failures = <HomeLayoutReadFailure>[];

    final layout = await StoredHomeLayout(store: store, namespace: 'app', onReadFailure: failures.add).load();
    expect(layout.order, <String>['a', 'b']);
    expect(layout.hidden, isEmpty);
    expect(failures, isEmpty, reason: 'a field that did not exist yet is a migration, not damage');
  });

  test('test_storedHomeLayout_corruptRow_isReportedAndDefaultsToEmpty', () async {
    final store = MemoryKeyValueStore();
    await store.write('app.home_layout', 'not json at all');
    final failures = <HomeLayoutReadFailure>[];
    final layout = StoredHomeLayout(store: store, namespace: 'app', onReadFailure: failures.add);

    expect(await layout.load(), const HomeLayout());
    expect(failures.single.reason, contains('unusable'));

    await layout.save(const HomeLayout(order: <String>['fixed']));
    expect(failures, hasLength(1), reason: 'a healed row must not keep reporting the old damage');
    expect((await StoredHomeLayout(store: store, namespace: 'app').load()).order, <String>['fixed']);
  });

  test('test_storedHomeLayout_newerVersionRow_isLeftUntouched', () async {
    final store = MemoryKeyValueStore();
    await store.write(
      'app.home_layout',
      jsonEncode(<String, Object?>{
        'v': 99,
        'order': <String>['from a newer build'],
        'hidden': <String>[],
      }),
    );
    final failures = <HomeLayoutReadFailure>[];

    expect(
      await StoredHomeLayout(store: store, namespace: 'app', onReadFailure: failures.add).load(),
      const HomeLayout(),
    );
    expect(failures, hasLength(1));
    expect(await store.read('app.home_layout'), contains('newer build'));
  });

  test('test_storedHomeLayout_resetReturnsToDefaults', () async {
    final store = MemoryKeyValueStore();
    final layout = StoredHomeLayout(store: store, namespace: 'app');
    await layout.save(const HomeLayout(order: <String>['a']));

    await layout.reset();
    expect(await layout.load(), const HomeLayout());
    expect(await store.keys(), isNot(contains('app.home_layout')));
  });

  test('test_storedHomeLayout_rejectsABlankNamespace', () {
    expect(() => StoredHomeLayout(store: MemoryKeyValueStore(), namespace: '  '), throwsA(isA<ArgumentError>()));
  });
}
