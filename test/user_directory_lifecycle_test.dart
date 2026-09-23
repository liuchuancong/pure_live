import 'dart:async';
import 'dart:typed_data';

import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/index.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/modules/auth/utils/firebase_manager.dart';
import 'package:pure_live/modules/auth/user_server_remote_controller.dart';

// This isolated I/O double is never passed to a Firestore query. The SDK's
// production-extension restriction does not describe this id/data-only fixture.
// ignore: subtype_of_sealed_class
class _Doc implements DocumentSnapshot {
  _Doc(this.id);
  @override
  final String id;
  @override
  Map<String, dynamic> data() => {'email': '$id@example.invalid', 'canUpload': true};
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Controller extends UserServerRemoteController {
  Future<List<String>>? ids;
  Future<Map<String, String>>? statsRoles;
  Future<List<DocumentSnapshot>>? rows;
  Future<Map<String, String>>? roles;
  Future<void>? write;
  Future<List<DocumentSnapshot>> Function(int count, String keyword, DocumentSnapshot? after)? reader;
  int authReads = 0;
  int globalRoles = 0;
  int writes = 0;
  final roleQueries = <List<String>>[];
  final queries = <({String keyword, String? after, int size})>[];
  final errors = <Object>[];
  @override
  String get currentUserUid {
    authReads++;
    return 'self';
  }

  @override
  Future<bool> checkNetworkBeforeRequest() async => true;
  @override
  void handleError(Object error, {bool showPageError = false}) {
    errors.add(error);
  }

  Map<String, Object?> snapshot() => {
    'keyword': searchKeyword,
    'input': rxSearchKeyword.value,
    'cursor': lastDocument?.id,
    'admin': adminCount.value,
    'manager': managerCount.value,
    'users': userCount.value,
    'rows': list.map((e) => e.uid).toList(),
    'loading': loadding.value,
    'page': currentPage,
  };
}

void _test(
  String name,
  Future<void> Function(WidgetTester, _Controller) body, {
  void Function(_Controller)? configure,
}) {
  testWidgets(name, (tester) async {
    Get.testMode = true;
    Get.reset();
    Get.put(SettingsService(), permanent: true);
    FirebaseManager.currentUserRole = 'admin';
    FirebaseManager.roleWeights = {'admin': 0, 'manager': 1, 'user': 2};
    FirebaseManager.roleVisibilityMap = {
      'admin': ['manager', 'user'],
    };
    _Controller? owner;
    try {
      await tester.pumpWidget(
        GetMaterialApp(
          home: Builder(
            builder: (_) {
              if (owner == null) {
                owner = _Controller();
                configure?.call(owner!);
                owner!.onStart();
                owner!.pageSize.value = 2;
              }
              return const SizedBox();
            },
          ),
        ),
      );
      for (var i = 0; i < 10 && owner == null; i++) {
        await tester.pump(Duration.zero);
      }
      expect(owner, isNotNull);
      await tester.pump(Duration.zero);
      await body(tester, owner!);
    } finally {
      owner?.onDelete();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
      Get.reset();
      FirebaseManager.currentUserRole = null;
      FirebaseManager.roleWeights = {};
      FirebaseManager.roleVisibilityMap = {};
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await Hive.openBox('app_settings', bytes: Uint8List(0));
    await HivePrefUtil.init();
  });
  tearDownAll(Hive.close);

  _test('closed raw user result does not advance cursor or request permissions', (tester, c) async {
    final gate = Completer<List<DocumentSnapshot>>();
    c.rows = gate.future;
    c.lastDocument = _Doc('previous');
    final operation = c.fetchNetworkData(2, 1);
    c.onDelete();
    gate.complete([_Doc('late')]);
    await tester.pump(Duration.zero);
    expect(await operation, isEmpty);
    expect(c.lastDocument?.id, 'previous');
    expect(c.roleQueries, isEmpty);
  });

  _test('closed permission result does not publish rows or advance cursor', (tester, c) async {
    c.rows = Future.value([_Doc('next')]);
    final gate = Completer<Map<String, String>>();
    c.roles = gate.future;
    c.lastDocument = _Doc('previous');
    final operation = c.fetchNetworkData(2, 1);
    await tester.pump(Duration.zero);
    c.onDelete();
    gate.complete({});
    await tester.pump(Duration.zero);
    expect(await operation, isEmpty);
    expect(c.lastDocument?.id, 'previous');
  });

  late Completer<List<String>> statsIds;
  _test(
    'closed statistics first response does not issue a second query',
    (tester, c) async {
      c.onDelete();
      statsIds.complete(['u']);
      await tester.pump(Duration.zero);
      expect(c.globalRoles, 0);
    },
    configure: (c) {
      statsIds = Completer<List<String>>();
      c.ids = statsIds.future;
    },
  );

  late Completer<Map<String, String>> statsRoles;
  _test(
    'closed statistics permission response does not update counters',
    (tester, c) async {
      c.onDelete();
      final before = c.snapshot();
      statsRoles.complete({'a': 'admin', 'b': 'manager'});
      await tester.pump(Duration.zero);
      expect(c.snapshot(), before);
    },
    configure: (c) {
      statsRoles = Completer<Map<String, String>>();
      c.ids = Future.value(['a', 'b', 'c']);
      c.statsRoles = statsRoles.future;
    },
  );

  _test('closed fetch and config-save entrypoints avoid auth reads and writes', (tester, c) async {
    c.onDelete();
    await c.fetchNetworkData(1, 2);
    await c.onConfigSaved('u', {'canUpload': false});
    expect(c.authReads, 0);
    expect(c.queries, isEmpty);
    expect(c.writes, 0);
  });

  _test('permission failure retains committed cursor for retry', (tester, c) async {
    c.lastDocument = _Doc('previous');
    c.rows = Future.value([_Doc('next')]);
    final gate = Completer<Map<String, String>>();
    c.roles = gate.future;
    final operation = c.fetchNetworkData(2, 1);
    final observed = operation.then((_) {}, onError: (Object _) {});
    await tester.pump(Duration.zero);
    gate.completeError(StateError('permission read failed'));
    await tester.pump(Duration.zero);
    await observed;
    final failedCursor = c.lastDocument?.id;
    c.roles = null;
    await c.fetchNetworkData(2, 1);
    expect(failedCursor, 'previous');
    expect(c.queries.map((q) => q.after), ['previous', 'previous']);
    expect(c.lastDocument?.id, 'next');
  });

  _test('search commit waits for active fetch instead of changing its query', (tester, c) async {
    final gate = Completer<List<DocumentSnapshot>>();
    c.rows = gate.future;
    final load = c.loadData();
    await tester.pump(Duration.zero);
    await c.refreshByKeyword('new');
    await tester.pump(const Duration(milliseconds: 600));
    final during = c.searchKeyword;
    gate.complete([_Doc('a'), _Doc('b')]);
    await tester.pump(Duration.zero);
    await load;
    await tester.pump(Duration.zero);
    expect(during, '');
    expect(c.searchKeyword, 'new');
    expect(c.queries.map((q) => q.keyword), ['', 'new']);
  });

  _test('new search input invalidates an older debounced waiter immediately', (tester, c) async {
    final gate = Completer<List<DocumentSnapshot>>();
    c.rows = gate.future;
    final load = c.loadData();
    await tester.pump(Duration.zero);
    await c.refreshByKeyword('old');
    await tester.pump(const Duration(milliseconds: 600));
    await c.refreshByKeyword('latest');
    await tester.pump(const Duration(milliseconds: 100));
    gate.complete([_Doc('a'), _Doc('b')]);
    await tester.pump(Duration.zero);
    await load;
    await tester.pump(const Duration(milliseconds: 500));
    expect(c.searchKeyword, 'latest');
    expect(c.queries.map((q) => q.keyword), ['', 'latest']);
  });

  _test('closing cancels a pending search timer without late state writes', (tester, c) async {
    await c.refreshByKeyword('pending');
    await tester.pump(Duration.zero);
    c.onDelete();
    final before = c.snapshot();
    await tester.pump(const Duration(milliseconds: 600));
    expect(c.snapshot(), before);
    expect(c.queries, isEmpty);
  });

  _test('closed search input stays unchanged', (tester, c) async {
    c.onDelete();
    await c.refreshByKeyword('late');
    expect(c.rxSearchKeyword.value, '');
    await tester.pump(const Duration(milliseconds: 600));
  });

  _test(
    'open statistics retain role counts',
    (tester, c) async {
      expect(c.adminCount.value, 1);
      expect(c.managerCount.value, 1);
      expect(c.userCount.value, 1);
    },
    configure: (c) {
      c.ids = Future.value(['a', 'b', 'c']);
      c.statsRoles = Future.value({'a': 'admin', 'b': 'manager'});
    },
  );

  _test('open user save completes before its refresh', (tester, c) async {
    final gate = Completer<void>();
    c.write = gate.future;
    final operation = c.onConfigSaved('u', {'canUpload': true});
    expect(c.queries, isEmpty);
    gate.complete();
    await tester.pump(Duration.zero);
    await operation;
    expect(c.writes, 1);
    expect(c.queries, hasLength(1));
  });

  _test('filtered chunks preserve visibility, ordering and the final cloud cursor', (tester, c) async {
    c.roles = Future.value({'hidden': 'admin', 'manager': 'manager'});
    c.reader = (chunkSize, keyword, after) async =>
        after == null ? [_Doc('self'), _Doc('hidden'), _Doc('user')] : [_Doc('manager'), _Doc('z')];
    final result = await c.fetchNetworkData(1, 3);
    expect(result.map((u) => u.uid), ['manager', 'user', 'z']);
    expect(c.queries.map((q) => q.size), [3, 2]);
    expect(c.queries.map((q) => q.after), [null, 'user']);
    expect(c.lastDocument?.id, 'z');
  });

  _test('later chunk failure rolls back the whole uncommitted cloud cursor', (tester, c) async {
    c.lastDocument = _Doc('previous');
    c.reader = (chunkSize, keyword, after) async {
      if (after?.id == 'previous') return [_Doc('self'), _Doc('a')];
      throw StateError('second chunk failed');
    };
    Object? error;
    await c
        .fetchNetworkData(2, 2)
        .then(
          (_) {},
          onError: (Object e) {
            error = e;
          },
        );
    expect(error, isA<StateError>());
    expect(c.queries.map((q) => q.after), ['previous', 'a']);
    expect(c.lastDocument?.id, 'previous');
  });

  _test('open cursor commits only when permissions finish', (tester, c) async {
    c.lastDocument = _Doc('previous');
    c.rows = Future.value([_Doc('next')]);
    final gate = Completer<Map<String, String>>();
    c.roles = gate.future;
    final operation = c.fetchNetworkData(2, 1);
    await tester.pump(Duration.zero);
    final during = c.lastDocument?.id;
    gate.complete({});
    await tester.pump(Duration.zero);
    await operation;
    expect(during, 'previous');
    expect(c.lastDocument?.id, 'next');
  });

  _test('in-flight save can finish after close without starting a refresh', (tester, c) async {
    final gate = Completer<void>();
    c.write = gate.future;
    final operation = c.onConfigSaved('u', {'canUpload': true});
    c.onDelete();
    final before = c.snapshot();
    gate.complete();
    await tester.pump(Duration.zero);
    await operation;
    expect(c.snapshot(), before);
    expect(c.writes, 1);
    expect(c.queries, isEmpty);
  });

  _test('closing invalidates a search already waiting for its old request', (tester, c) async {
    final gate = Completer<List<DocumentSnapshot>>();
    c.rows = gate.future;
    final operation = c.loadData();
    await tester.pump(Duration.zero);
    await c.refreshByKeyword('pending');
    await tester.pump(const Duration(milliseconds: 600));
    c.onDelete();
    final before = c.snapshot();
    gate.complete([_Doc('late')]);
    await tester.pump(Duration.zero);
    await operation;
    expect(c.snapshot(), before);
    expect(c.queries, hasLength(1));
    expect(c.roleQueries, isEmpty);
  });

  _test('returning to the committed search cancels a transient input', (tester, c) async {
    await c.refreshByKeyword('transient');
    await tester.pump(const Duration(milliseconds: 100));
    await c.refreshByKeyword('');
    await tester.pump(const Duration(milliseconds: 600));
    expect(c.searchKeyword, '');
    expect(c.queries, isEmpty);
  });
}
