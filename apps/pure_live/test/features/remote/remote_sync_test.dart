import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:live_library/live_library.dart';
import 'package:live_storage/live_storage.dart' show StorageRepository;

import 'package:pure_live/features/remote_receiver/remote_sync_parts.dart';
import 'package:pure_live/features/remote_receiver/remote_sync_payload.dart';
import 'package:pure_live/features/remote_receiver/remote_sync_protocol.dart';
import 'package:pure_live/features/remote_receiver/remote_sync_service.dart';
import 'package:pure_live/system/configuration/app_preferences.dart';

final class _MapRepository implements StorageRepository<Map<dynamic, dynamic>> {
  final Map<String, Map<dynamic, dynamic>> documents = {};
  final StreamController<void> _changes = StreamController<void>.broadcast();

  @override
  Stream<void> watch({String? key}) => _changes.stream;

  @override
  Map<dynamic, dynamic>? get(String key) => documents[key];

  @override
  Map<String, Map<dynamic, dynamic>> getMany(Iterable<String> keys) => {
    for (final key in keys)
      if (documents.containsKey(key)) key: documents[key]!,
  };

  @override
  List<Map<dynamic, dynamic>> getAll() => List.of(documents.values);

  @override
  Map<String, Map<dynamic, dynamic>> getAllEntries() => Map.of(documents);

  @override
  List<String> getAllKeys() => List.of(documents.keys);

  @override
  bool contains(String key) => documents.containsKey(key);

  @override
  bool containsAll(Iterable<String> keys) => keys.every(documents.containsKey);

  @override
  Future<void> save(String key, Map<dynamic, dynamic> value) async {
    documents[key] = value;
    _changes.add(null);
  }

  @override
  Future<void> saveAll(Map<String, Map<dynamic, dynamic>> values) async {
    documents.addAll(values);
    _changes.add(null);
  }

  @override
  Future<bool> insertIfAbsent(String key, Map<dynamic, dynamic> value) async {
    final inserted = !documents.containsKey(key);
    if (inserted) {
      documents[key] = value;
      _changes.add(null);
    }
    return inserted;
  }

  @override
  Future<bool> update(String key, Map<dynamic, dynamic> Function(Map<dynamic, dynamic> current) updater) async {
    if (!documents.containsKey(key)) {
      return false;
    }
    documents[key] = updater(documents[key]!);
    _changes.add(null);
    return true;
  }

  @override
  Future<void> delete(String key) async {
    documents.remove(key);
    _changes.add(null);
  }

  @override
  Future<void> deleteAll(Iterable<String> keys) async {
    keys.forEach(documents.remove);
    _changes.add(null);
  }

  @override
  Future<int> deleteWhere(bool Function(String key, Map<dynamic, dynamic> value) test) async {
    final doomed = [
      for (final entry in documents.entries)
        if (test(entry.key, entry.value)) entry.key,
    ]..forEach(documents.remove);
    _changes.add(null);
    return doomed.length;
  }

  @override
  int get count => documents.length;

  @override
  bool get isEmpty => documents.isEmpty;

  @override
  bool get isNotEmpty => documents.isNotEmpty;

  @override
  Future<void> clear() async {
    documents.clear();
    _changes.add(null);
  }

  @override
  Future<void> flush() async {}
}

Map<String, Object?> samplePayload() => {
  'backupVersion': 3,
  'sensitiveDataIncluded': false,
  'favorite': {
    'favoriteRooms': [
      {'roomId': '1', 'platform': 'douyu'},
    ],
    'shieldList': ['word'],
    'blockedDanmakuUsers': <String>[],
    'favoriteAreas': <Map<String, Object?>>[],
  },
  'history': {
    'historyRooms': [
      {'roomId': '2', 'platform': 'bilibili'},
      {'roomId': '3', 'platform': 'bilibili'},
    ],
  },
  'tags': {
    'tags': [
      {'id': 'g1', 'name': '分组'},
    ],
    'roomTagsMap': <String, Object?>{},
  },
  'roomCard': {'mobilePreset': 'custom'},
  'loading': {'loadingStyle': 'shimmer'},
};

void main() {
  group('pairing codes', () {
    test('a new code is six digits', () {
      final code = RemoteSyncProtocol.newPairingCode();
      expect(code.length, RemoteSyncProtocol.pairingCodeLength);
      expect(int.tryParse(code), isNotNull);
    });

    test('matching ignores white space but needs the full length', () {
      expect(RemoteSyncProtocol.pairingCodesMatch('123456', ' 123 456 '), isTrue);
      expect(RemoteSyncProtocol.pairingCodesMatch('123456', '12345'), isFalse);
      expect(RemoteSyncProtocol.pairingCodesMatch('123456', '123457'), isFalse);
      expect(RemoteSyncProtocol.pairingCodesMatch('', ''), isFalse);
      expect(RemoteSyncProtocol.pairingCodesMatch('123456', null), isFalse);
    });

    test('the QR carries the code and parses back with it', () {
      final uri = RemoteSyncProtocol.createQrUri(ip: '192.168.1.5', port: 39888, code: '246810');
      final parsed = RemoteSyncProtocol.parseQr(uri.toString());
      expect(parsed!.ip, '192.168.1.5');
      expect(parsed.port, 39888);
      expect(parsed.code, '246810');
      // A bare address still parses — its code is simply absent.
      final plain = RemoteSyncProtocol.parseQr('192.168.1.5:39890');
      expect(plain!.code, isNull);
      // Junk that only looks like a sync link parses to nothing.
      expect(RemoteSyncProtocol.parseQr('purelive://x'), isNull);
    });
  });

  group('parts codec', () {
    test('a sectioned payload lists its parts in order with counts', () {
      final data = samplePayload();
      expect(syncPartsSplittable(data), isTrue);
      expect(syncPartsIn(data), [
        RemoteSyncPart.settings,
        RemoteSyncPart.follows,
        RemoteSyncPart.history,
        RemoteSyncPart.groups,
        RemoteSyncPart.keywords,
        RemoteSyncPart.users,
      ]);
      final counts = syncPartCounts(data);
      expect(counts[RemoteSyncPart.follows], 1);
      expect(counts[RemoteSyncPart.history], 2);
      expect(counts[RemoteSyncPart.groups], 1);
      expect(counts[RemoteSyncPart.keywords], 1);
      expect(counts[RemoteSyncPart.users], 0);
      // roomCard (1 key) + loading (1 key) make the settings part.
      expect(counts[RemoteSyncPart.settings], 2);
    });

    test('a flat file is not splittable and survives a pick whole', () {
      final flat = <String, Object?>{'favorite': {'favoriteRooms': <Object?>[]}};
      expect(syncPartsSplittable(flat), isFalse);
      expect(pickSyncParts(flat, {RemoteSyncPart.follows}), flat);
      expect(syncPartsLeaveOut(flat, {RemoteSyncPart.follows}), isFalse);
    });

    test('a pick keeps the file keys and drops whole parts', () {
      final data = samplePayload();
      final picked = pickSyncParts(data, {RemoteSyncPart.follows, RemoteSyncPart.settings});
      final favorite = picked['favorite']! as Map<Object?, Object?>;
      expect(favorite.containsKey('favoriteRooms'), isTrue);
      expect(favorite.containsKey('shieldList'), isFalse);
      expect(favorite.containsKey('blockedDanmakuUsers'), isFalse);
      expect(picked.containsKey('history'), isFalse);
      expect(picked.containsKey('tags'), isFalse);
      expect(picked['backupVersion'], 3);
      expect(syncSectionsOf(picked), ['favorite', 'roomCard', 'loading']);
    });

    test('a packet re-narrows to the sections it lists', () {
      final within = withinSyncSections(samplePayload(), ['history']);
      expect(within.keys.toSet(), {'backupVersion', 'sensitiveDataIncluded', 'history'});
      expect(withinSyncSections(samplePayload(), null), samplePayload());
    });
  });

  group('service gate', () {
    late RemoteSyncService service;
    late HttpServer server;
    late int port;

    Future<Map<String, Object?>> request(
      String method, {
      String? code,
      Object? body,
      String path = RemoteSyncProtocol.apiSettings,
    }) async {
      final client = HttpClient();
      try {
        final request = await client.openUrl(method, Uri(scheme: 'http', host: '127.0.0.1', port: port, path: path));
        if (code != null) {
          request.headers.set(RemoteSyncProtocol.pairingHeader, code);
        }
        if (body != null) {
          request.headers.contentType = ContentType('application', 'json', charset: 'utf-8');
          request.write(jsonEncode(body));
        }
        final response = await request.close();
        final text = await utf8.decoder.bind(response).join();
        return {'status': response.statusCode, 'body': jsonDecode(text)};
      } finally {
        client.close(force: true);
      }
    }

    setUp(() async {
      service = RemoteSyncService.inert(
        follows: FollowRepository(InMemoryLibraryStore()),
        history: HistoryRepository(InMemoryLibraryStore()),
        preferences: AppPreferencesStore(repository: _MapRepository()),
      )..pairingCode = '123456';
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      port = server.port;
      server.listen((request) => unawaited(service.handleRequest(request)));
    });

    tearDown(() async {
      await server.close(force: true);
      service.dispose();
    });

    test('a settings request without the pairing code is refused, and ten wrong codes roll it over', () async {
      final answer = await request('GET');
      expect(answer['status'], 403);
      final first = service.pairingCode;
      for (var i = 0; i < RemoteSyncService.maxWrongCodes; i++) {
        await request('GET', code: '000000');
      }
      expect(service.pairingCode, isNot(first));
    });

    test('a refused user still means no', () async {
      service.confirmRequest = (action, address) async => false;
      final answer = await request('GET', code: '123456');
      expect(answer['status'], 403);
    });

    test('an allowed export answers the payload document', () async {
      service.confirmRequest = (action, address) async => true;
      final answer = await request('GET', code: ' 123 456 ');
      expect(answer['status'], 200);
      final body = answer['body']! as Map<String, Object?>;
      expect(body['code'], 200);
      final data = body['data']! as Map<String, Object?>;
      expect(data['backupVersion'], 3);
      expect(data['favorite'], isA<Map<Object?, Object?>>());
    });

    test('an import asks the parts picker, not the flat confirm', () async {
      var confirmed = false;
      service.confirmRequest = (action, address) async {
        confirmed = true;
        return true;
      };
      Set<RemoteSyncPart>? asked;
      service.chooseImport = (address, settings) async {
        asked = {for (final part in syncPartsIn(settings)) part};
        return {RemoteSyncPart.settings};
      };
      final answer = await request(
        'POST',
        code: '123456',
        body: RemoteSyncProtocol.settingsPacket(settings: samplePayload()),
      );
      expect(answer['status'], 200);
      expect(asked, contains(RemoteSyncPart.follows));
      // The picker answered, so the flat confirm never ran.
      expect(confirmed, isFalse);
    });

    test('a bad packet is refused before any prompt', () async {
      var asked = false;
      service.chooseImport = (address, settings) async {
        asked = true;
        return {RemoteSyncPart.settings};
      };
      final answer = await request('POST', code: '123456', body: {'type': 'other'});
      expect(answer['status'], 400);
      expect(asked, isFalse);
    });

    test('the status card lists the parts this device takes', () async {
      final answer = await request('GET', path: RemoteSyncProtocol.apiStatus, code: 'ignored');
      final body = answer['body']! as Map<String, Object?>;
      final data = body['data']! as Map<String, Object?>;
      expect(RemoteSyncProtocol.takesParts(data), isTrue);
      expect(data[RemoteSyncProtocol.partsKey], [for (final part in RemoteSyncPart.values) part.wireName]);
    });

    test('a client send carries the code header and the picked sections', () async {
      // A stand-in peer: it records what arrived and answers like a device
      // that applied the payload.
      final peer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => peer.close(force: true));
      final seenHeaders = <String, String>{};
      Object? seenBody;
      peer.listen((request) async {
        request.headers.forEach((name, values) {
          if (values.isNotEmpty) {
            seenHeaders[name] = values.first;
          }
        });
        seenBody = jsonDecode(await utf8.decoder.bind(request).join());
        request.response.headers.contentType = ContentType('application', 'json', charset: 'utf-8');
        request.response.write(jsonEncode({'code': 200, 'msg': 'ok', 'data': true}));
        await request.response.close();
      });
      final ok = await service.send('127.0.0.1', peer.port, '654321', parts: {RemoteSyncPart.settings});
      expect(ok, isTrue);
      expect(seenHeaders[RemoteSyncProtocol.pairingHeader], '654321');
      final packet = seenBody! as Map<String, Object?>;
      expect(packet['type'], RemoteSyncProtocol.syncType);
      // The whole payload minus the unticked parts: the settings part
      // travels, the follow list and history do not.
      final sections = packet['sections']! as List<Object?>;
      expect(sections, containsAll(<String>['roomCard', 'refresh', 'page', 'proxy', 'loading']));
      final body = packet['settings']! as Map<String, Object?>;
      expect(body.containsKey('history'), isFalse);
      expect(body.containsKey('tags'), isFalse);
      expect((body['favorite']! as Map<Object?, Object?>).containsKey('favoriteRooms'), isFalse);
    });
  });

  group('payload sensitive sections', () {
    test('the export only carries them when handed in', () {
      Map<String, dynamic> build({List<Map<String, dynamic>>? webdav, List<Map<String, dynamic>>? accounts}) =>
          RemoteSyncPayload.buildExport(
            preferences: const AppPreferences(),
            follows: const [],
            groups: const [],
            history: const [],
            shieldKeywords: const [],
            shieldUsers: const [],
            webdavServers: webdav,
            accountCredentials: accounts,
          );
      final plain = build();
      expect(plain.containsKey('webdav'), isFalse);
      expect(plain['sensitiveDataIncluded'], false);
      final sensitive = build(webdav: [{'name': 'drive'}], accounts: [{'site': 'douyu', 'document': '{}'}]);
      expect(sensitive['sensitiveDataIncluded'], true);
      expect(syncPartsIn(sensitive), containsAll([RemoteSyncPart.webdav, RemoteSyncPart.accounts]));
      expect(syncPartCounts(sensitive)[RemoteSyncPart.accounts], 1);
    });

    test('apply routes the sensitive sections through their sinks only when ticked', () async {
      final webdavSeen = <Map<String, dynamic>>[];
      final accountsSeen = <Map<String, dynamic>>[];
      Future<void> noteWebDav(Map<String, dynamic> entry) async => webdavSeen.add(entry);
      Future<void> noteAccounts(Map<String, dynamic> entry) async => accountsSeen.add(entry);
      final payload = RemoteSyncPayload.buildExport(
        preferences: const AppPreferences(),
        follows: const [],
        groups: const [],
        history: const [],
        shieldKeywords: const [],
        shieldUsers: const [],
        webdavServers: [{'name': 'drive', 'address': 'https://x', 'username': 'u', 'password': 'p'}],
        accountCredentials: [{'site': 'douyu', 'document': '{"siteId":"douyu","cookies":{}}'}],
      );
      await RemoteSyncPayload.apply(
        payload,
        preferences: AppPreferencesStore(repository: _MapRepository()),
        follows: FollowRepository(InMemoryLibraryStore()),
        history: HistoryRepository(InMemoryLibraryStore()),
        shield: (key, values) async {},
        webdav: noteWebDav,
        accounts: noteAccounts,
        sections: const ['favorite'],
      );
      expect(webdavSeen, isEmpty);
      expect(accountsSeen, isEmpty);
      await RemoteSyncPayload.apply(
        payload,
        preferences: AppPreferencesStore(repository: _MapRepository()),
        follows: FollowRepository(InMemoryLibraryStore()),
        history: HistoryRepository(InMemoryLibraryStore()),
        shield: (key, values) async {},
        webdav: noteWebDav,
        accounts: noteAccounts,
        sections: const ['webdav', 'accounts'],
      );
      expect(webdavSeen.single['name'], 'drive');
      expect(accountsSeen.single['site'], 'douyu');
    });
  });
}
