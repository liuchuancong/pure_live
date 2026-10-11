// Module: test/bigo/bigo_source_test.dart
// Purpose: The Bigo source against a canned transport: the finite block, the three-way access gate, the jsonp
// token handshake and the manifest protection codec.
// Author: liuchuancong
// Created: 2026-10-11
//
// Bodies are written to the field names the v1 line reads, not recorded from the site (README 未验证).

import 'dart:convert';
import 'dart:typed_data';

import 'package:pure_live_network/pure_live_network.dart';
import 'package:pure_live_network/testing.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_sites/pure_live_sites.dart';
import 'package:test/test.dart';

const String _directoryKey = 'ta.bigo.tv/official_website/OInterfaceWeb/vedioList/72';
const String _studioKey = 'ta.bigo.tv/official_website/studio/getInternalStudioInfo';
const String _timeKey = 'sec.bigo.sg/v1/webjs/t';
const String _statusKey = 'sec.bigo.sg/v1/webjs/status';
const String _callback = 'jsonpcallback_1';

final DateTime _now = DateTime.fromMillisecondsSinceEpoch(1700000000000);
const ContentRef _room = ContentRef(sourceId: 'bigo.live', contentId: '1234567', kind: ContentKind.liveRoom);

const String _hlsUrl = 'https://bigolive-hk.mada.tv/live/1234567.m3u8?token=abc';

NetworkClient _client(ScriptedTransport transport) => NetworkClient(
  adapter: transport,
  clock: () => _now,
  settings: const NetworkSettings(retry: RetryPolicy(attempts: 1)),
);

(ScriptedTransport, BigoSource) _source(Map<String, List<String>> script, {String? cookie}) {
  final transport = ScriptedTransport(script);
  return (
    transport,
    BigoSource(client: _client(transport), clock: () => _now, cookie: cookie, jsonpCallback: () => _callback),
  );
}

String _envelope(Map<String, Object?> data) => jsonEncode(<String, Object?>{'code': 0, 'data': data});

String _directory(int rows, {int first = 1234567, bool repeat = false}) => _envelope(<String, Object?>{
  'resCode': '0',
  'data': <Object?>[
    for (var index = 0; index < rows; index++)
      <String, Object?>{
        'bigo_id': '${first + (repeat ? 0 : index)}',
        'owner': 9000 + index,
        'room_id': 9007199254740993 + index,
        'sid': 7000 + index,
        'room_topic': '标题 $index',
        'nick_name': '主播 $index',
        'cover_m': 'https://cover.bigo.tv/$index.jpg',
        'user_count': 100 + index,
        'is_locked': 0,
        'room_flag': 1,
      },
  ],
});

Map<String, Object?> _studio({
  int uid = 9000,
  String clientBigoId = '1234567',
  bool needLogin = false,
  bool passRoom = false,
  String paid = '',
  int alive = 1,
  int roomStatus = 1,
  String roomType = 'live',
  int? roomId = 55500,
  String? hls,
  String nickname = '主播 0',
  String title = '标题 0',
}) => <String, Object?>{
  'uid': uid,
  'clientBigoId': clientBigoId,
  'needLogin': needLogin,
  'passRoom': passRoom,
  'isPaidShow': paid,
  'alive': alive,
  'roomStatus': roomStatus,
  'roomType': roomType,
  'nick_name': nickname,
  'roomTopic': title,
  'gameTitle': '棋牌',
  'avatar': 'https://avatar.bigo.tv/a.jpg',
  'snapshot': 'https://snap.bigo.tv/s.jpg',
  'roomId': roomId,
  if (hls != null) 'hls_src': hls,
};

String _jsonp(Object? payload) => '$_callback(${jsonEncode(payload)});';

Map<String, List<String>> _handshake() => <String, List<String>>{
  _timeKey: <String>[
    _jsonp(<String, Object?>{'code': 0, 'time': '1700000000'}),
  ],
  _statusKey: <String>[
    _jsonp(<String, Object?>{'code': 0, 'token': 'tok-1'}),
  ],
};

void main() {
  group('test_bigoSource_block', () {
    test('test_theBlockIsOneFiniteSnapshotSlicedLocally', () async {
      final (transport, bigo) = _source(<String, List<String>>{
        _directoryKey: <String>[_directory(25)],
      });
      final first = await bigo.feed(PageRequest.first);
      expect(first.items, hasLength(20));
      expect(first.total, 25);
      expect(first.hasMore, isTrue);
      final second = await bigo.feed(const PageRequest(page: 2));
      expect(second.items, hasLength(5));
      expect(second.hasMore, isFalse);
      expect(transport.requestsTo(_directoryKey), 1, reason: 'the same block serves both pages');
    });

    test('test_theSnapshotSurvivesUntilItsHalfMinuteIsUp', () async {
      var now = DateTime.fromMillisecondsSinceEpoch(1700000000000);
      final transport = ScriptedTransport(<String, List<String>>{
        _directoryKey: <String>[_directory(20)],
      });
      final bigo = BigoSource(
        client: NetworkClient(
          adapter: transport,
          clock: () => now,
          settings: const NetworkSettings(retry: RetryPolicy(attempts: 1)),
        ),
        clock: () => now,
        jsonpCallback: () => _callback,
      );
      await bigo.feed(PageRequest.first);
      now = now.add(const Duration(seconds: 29));
      await bigo.feed(PageRequest.first);
      expect(transport.requestsTo(_directoryKey), 1);
      now = now.add(const Duration(seconds: 3));
      await bigo.feed(PageRequest.first);
      expect(transport.requestsTo(_directoryKey), 2, reason: 'a stale snapshot is refetched, never pinned');
    });

    test('test_theBroadcastIdStaysText', () {
      final card = bigoDirectory(jsonDecode(_directory(1))).single;
      // int64 above javascript's exact range, kept as the site spelled it.
      expect(card.broadcastId, '9007199254740993');
      expect(card.toLiveRoom().streamId, '9007199254740993');
      expect(card.toLiveRoom().restriction, isNull, reason: 'an unlocked card states no gate');
    });

    test('test_aRepeatedHandleOrOwnerIsASchemaChangeNotADuplicateTile', () async {
      final (_, bigo) = _source(<String, List<String>>{
        _directoryKey: <String>[_directory(2, repeat: true)],
      });
      await expectLater(bigo.feed(PageRequest.first), throwsA(isA<BigoFailure>()));
    });

    test('test_aLockedCardIsPrivateNotOffline', () async {
      final body = _envelope(<String, Object?>{
        'resCode': '0',
        'data': <Object?>[
          <String, Object?>{
            'bigo_id': '1234567',
            'owner': 9000,
            'room_id': 55,
            'sid': 7,
            'room_topic': '标题',
            'nick_name': '主播',
            'user_count': 10,
            'is_locked': 1,
            'room_flag': 1,
          },
        ],
      });
      final room = bigoDirectory(jsonDecode(body)).single.toLiveRoom();
      expect(room.restriction, LiveRestriction.private);
      expect(room.state, LiveRoomState.live, reason: 'the block lists it as on air; only the room can contradict that');
    });

    test('test_anHttpErrorIsNamedAndAFourOhFourIsMissing', () async {
      final transport = ScriptedTransport(<String, List<String>>{
        _directoryKey: <String>['ignored'],
      }, defaultStatus: 404);
      final bigo = BigoSource(client: _client(transport), clock: () => _now, jsonpCallback: () => _callback);
      await expectLater(
        bigo.feed(PageRequest.first),
        throwsA(predicate<BigoFailure>((BigoFailure error) => error.missing && error.code == 404)),
      );
    });
  });

  group('test_bigoSource_access', () {
    test('test_anAccountGatedRoomIsPrivateAndUnknownNotEnded', () async {
      final (_, bigo) = _source(<String, List<String>>{
        ..._handshake(),
        _studioKey: <String>[_envelope(_studio(needLogin: true, alive: 0))],
      });
      final room = await bigo.room(_room);
      expect(room.restriction, LiveRestriction.private);
      expect(room.state, LiveRoomState.unknown, reason: 'a gated alive=0 is not an observed offline room');
      expect(room.requiresAuth, isTrue);
      await expectLater(
        bigo.resolve(_room),
        throwsA(
          isA<StateError>().having((StateError error) => error.message, 'message', contains('requires an account')),
        ),
      );
    });

    test('test_aPasswordRoomIsPrivateAndAPaidRoomIsPaid', () {
      final private = bigoStatus(jsonDecode(_envelope(_studio(passRoom: true, alive: 0))), siteId: '1234567');
      final paid = bigoStatus(jsonDecode(_envelope(_studio(paid: '1', alive: 0))), siteId: '1234567');
      expect(private.restriction, LiveRestriction.private);
      expect(paid.restriction, LiveRestriction.paid);
      // Both are gated, so neither answer's `alive` becomes a claim about the broadcast having ended.
      expect(private.state, LiveRoomState.unknown);
      expect(paid.state, LiveRoomState.unknown);
    });

    test('test_aPublicRoomWithoutAnAddressIsUnplayable', () async {
      final (_, bigo) = _source(<String, List<String>>{
        ..._handshake(),
        _studioKey: <String>[_envelope(_studio())],
      });
      final room = await bigo.room(_room);
      expect(room.restriction, LiveRestriction.unplayable);
      expect(room.state, LiveRoomState.live);
      expect(await bigo.qualities(_room), isEmpty);
      await expectLater(
        bigo.resolve(_room),
        throwsA(isA<StateError>().having((StateError e) => e.message, 'message', contains('shipped no address'))),
      );
    });

    test('test_aGatedRoomOrOfflineRoomShippingAnAddressIsRefused', () async {
      final (_, gated) = _source(<String, List<String>>{
        ..._handshake(),
        _studioKey: <String>[_envelope(_studio(needLogin: true, hls: _hlsUrl))],
      });
      await expectLater(
        gated.room(_room),
        throwsA(isA<BigoFailure>().having((BigoFailure e) => e.message, 'message', contains('gated room'))),
      );
      final (_, offline) = _source(<String, List<String>>{
        ..._handshake(),
        _studioKey: <String>[_envelope(_studio(alive: 0, hls: _hlsUrl))],
      });
      await expectLater(
        offline.room(_room),
        throwsA(isA<BigoFailure>().having((BigoFailure e) => e.message, 'message', contains('not broadcasting'))),
      );
    });

    test('test_theStudioAnswerAboutAnotherHandleIsRefused', () async {
      final (_, bigo) = _source(<String, List<String>>{
        ..._handshake(),
        _studioKey: <String>[_envelope(_studio(clientBigoId: '7654321'))],
      });
      await expectLater(bigo.room(_room), throwsA(isA<BigoFailure>()));
    });

    test('test_theOwnerCheckIsMadeAgainstTheListingThatOfferedTheRoom', () {
      final body = jsonDecode(_envelope(_studio(uid: 9001)));
      expect(bigoStatus(body, siteId: '1234567').ownerId, 9001);
      expect(() => bigoStatus(body, siteId: '1234567', expectedOwnerId: 9000), throwsA(isA<BigoFailure>()));
    });
  });

  group('test_bigoSource_play', () {
    test('test_theLeaseHandshakeIsTwoJsonpCallsBeforeTheStudioPost', () async {
      final (transport, bigo) = _source(<String, List<String>>{
        _timeKey: <String>[
          _jsonp(<String, Object?>{'code': 0, 'time': '1700000000'}),
        ],
        _statusKey: <String>[
          _jsonp(<String, Object?>{'code': 0, 'token': 'tok-1'}),
        ],
        _studioKey: <String>[_envelope(_studio(hls: _hlsUrl))],
      });
      final ticket = await bigo.resolve(_room);
      expect(transport.requestsTo(_timeKey), 1);
      expect(transport.requestsTo(_statusKey), 1);
      expect(transport.requestsTo(_studioKey), 1);
      expect(ticket.protocol, MediaProtocol.hls);
      expect(ticket.uri.queryParameters['token'], 'abc');
      expect(ticket.metadata.extra['container'], 'm3u8');
      // The lease goes out with the site's own web headers.
      expect(ticket.headers['origin'], 'https://www.bigo.tv');
    });

    test('test_qualitiesAreOneUnnamedProfileAndThereIsNoLineMenu', () async {
      final (_, bigo) = _source(<String, List<String>>{
        _timeKey: <String>[
          _jsonp(<String, Object?>{'code': 0, 'time': '1700000000'}),
        ],
        _statusKey: <String>[
          _jsonp(<String, Object?>{'code': 0, 'token': 'tok-1'}),
        ],
        _studioKey: <String>[_envelope(_studio(hls: _hlsUrl))],
      });
      final qualities = await bigo.qualities(_room);
      expect(qualities.single.id, 'hls');
      // The site gives its single stream no name, so no word is invented for the menu.
      expect(qualities.single.label, isNull);
      expect(qualities.single.requiresAuth, isFalse);
      await expectLater(bigo.resolve(_room, line: const SelectionRef('2')), throwsA(isA<StateError>()));
      await expectLater(bigo.resolve(_room, quality: const SelectionRef('sd')), throwsA(isA<StateError>()));
    });

    test('test_aJsonpAnswerWithAnotherCallbackIsNotExecuted', () async {
      final (_, bigo) = _source(<String, List<String>>{
        _timeKey: <String>['someoneElsesCallback({"code":0,"time":"1700000000"});'],
      });
      await expectLater(bigo.room(_room), throwsA(isA<BigoFailure>()));
    });

    test('test_aTokenWeCouldNotPutInAUrlIsRefused', () async {
      final (_, bigo) = _source(<String, List<String>>{
        _timeKey: <String>[
          _jsonp(<String, Object?>{'code': 0, 'time': '1700000000'}),
        ],
        _statusKey: <String>[
          _jsonp(<String, Object?>{'code': 0, 'token': 'has space'}),
        ],
      });
      await expectLater(bigo.room(_room), throwsA(isA<BigoFailure>()));
    });

    test('test_theStatusPathSkipsTheTokenHandshake', () async {
      final (transport, bigo) = _source(<String, List<String>>{
        _studioKey: <String>[_envelope(_studio(hls: _hlsUrl))],
      });
      final status = await bigo.liveStatus(_room);
      expect(status.state, LiveRoomState.live);
      expect(transport.requestsTo(_studioKey), 1);
      expect(transport.requestsTo(_timeKey), 0);
    });

    test('test_refreshReHandshakesInsteadOfReusingTheLease', () async {
      final (transport, bigo) = _source(<String, List<String>>{
        _timeKey: <String>[
          _jsonp(<String, Object?>{'code': 0, 'time': '1700000000'}),
        ],
        _statusKey: <String>[
          _jsonp(<String, Object?>{'code': 0, 'token': 'tok-1'}),
        ],
        _studioKey: <String>[_envelope(_studio(hls: _hlsUrl))],
      });
      final ticket = await bigo.resolve(_room);
      final again = await bigo.refresh(ticket, RefreshReason.expiring);
      expect(again.uri, ticket.uri);
      expect(transport.requestsTo(_timeKey), 2);
    });
  });

  group('test_bigoSource_search', () {
    test('test_aPastedLinkGoesToTheRoomCommand', () async {
      final (transport, bigo) = _source(<String, List<String>>{
        _studioKey: <String>[_envelope(_studio(hls: _hlsUrl))],
      });
      final page = await bigo.search(const SearchQuery(keyword: 'https://www.bigo.tv/1234567'));
      expect(page.items.single.ref.contentId, '1234567');
      expect(transport.requestsTo(_directoryKey), 0);
    });

    test('test_aWordFiltersTheVerifiedBlockBecauseItsSearchEndpointAnswersNull', () async {
      final (_, bigo) = _source(<String, List<String>>{
        _directoryKey: <String>[_directory(3)],
      });
      final page = await bigo.search(const SearchQuery(keyword: '主播 1'));
      expect(page.items.map((item) => item.ref.contentId), <String>['1234568']);
      expect(page.mode, PageMode.singleShot);
    });

    test('test_aHandleThatDoesNotExistIsNoResultsWhileTheServiceFailingIsNot', () async {
      final (_, missing) = _source(<String, List<String>>{
        // The site's own "no such room" is an envelope code, not an http status.
        _studioKey: <String>[
          jsonEncode(<String, Object?>{'code': 404, 'msg': 'no room'}),
        ],
        _directoryKey: <String>[_directory(3)],
      });
      expect((await missing.search(const SearchQuery(keyword: 'room.99'))).items, isEmpty);

      final (_, down) = _source(<String, List<String>>{
        _studioKey: <String>[
          jsonEncode(<String, Object?>{'code': 500, 'msg': 'server'}),
        ],
        _directoryKey: <String>[_directory(3)],
      });
      // A refused service stays a failure: swallowing it is how a search reports "nobody by that name".
      await expectLater(down.search(const SearchQuery(keyword: 'room.99')), throwsA(isA<BigoFailure>()));
    });

    test('test_theSecondPageAsksNothing', () async {
      final (transport, bigo) = _source(<String, List<String>>{
        _directoryKey: <String>[_directory(3)],
      });
      final page = await bigo.search(const SearchQuery(keyword: '主播', page: PageRequest(page: 2)));
      expect(page.items, isEmpty);
      expect(transport.requestsTo(_directoryKey), 0);
    });
  });

  group('test_bigoSource_readers', () {
    test('test_theTokenEnvelopeIsSaltedAndDeterministicForOneSalt', () {
      final salt = Uint8List.fromList(<int>[1, 2, 3, 4, 5, 6, 7, 8]);
      const nonce = '0123456789abcdef0123456789abcdef';
      final first = BigoTokenCodec.buildData('1700000000', salt: salt, randomHex: nonce);
      final again = BigoTokenCodec.buildData('1700000000', salt: salt, randomHex: nonce);
      expect(first, again);
      final bytes = base64Decode(first);
      expect(latin1.decode(bytes.sublist(0, 8)), 'Salted__');
      expect(bytes.sublist(8, 16), salt);
      // One AES block of padding at least: the payload is under 32 bytes of json plus PKCS7.
      expect(bytes.length, greaterThan(24));
      expect(() => BigoTokenCodec.buildData('not-a-time'), throwsA(isA<BigoFailure>()));
    });

    test('test_theProtectionTransformIsItsOwnInverse', () {
      final source = Uint8List.fromList(<int>[for (var index = 0; index < 512; index++) (index * 7) & 0xff]);
      final protected = BigoHlsProtection.transformSegment(source, 987654321);
      expect(protected, isNot(source));
      // Only the two packet prefixes move; the rest of the segment is untouched.
      expect(protected.sublist(400), source.sublist(400));
      expect(BigoHlsProtection.transformSegment(protected, 987654321), source);
    });

    test('test_theSeedComesFromTheManifestTag', () {
      expect(BigoHlsProtection.seedFromManifest('#EXTM3U\n#EXT-X-BIGO-WEB-PROTECTION:SEED=12345\n#EXTINF:4\n'), 12345);
      expect(BigoHlsProtection.seedFromManifest('#EXTM3U\n#EXT-X-TARGETDURATION:4\n'), isNull);
      expect(BigoHlsProtection.isProtected('#EXTM3U\n#EXT-X-BIGO-WEB-PROTECTION:SEED=1\n'), isTrue);
      expect(
        () => BigoHlsProtection.seedFromManifest('#EXT-X-BIGO-WEB-PROTECTION:SEED=99999999999\n'),
        throwsA(isA<BigoFailure>()),
      );
    });

    test('test_aReservedPathIsNotAHandle', () {
      expect(bigoRoomFromUri(Uri.parse('https://www.bigo.tv/1234567')), '1234567');
      expect(bigoRoomFromUri(Uri.parse('https://bigo.tv/ab/1234567')), '1234567');
      expect(bigoRoomFromUri(Uri.parse('https://www.bigo.tv/live')), isNull);
      expect(bigoRoomFromUri(Uri.parse('https://www.bigo.tv/1234567/deep/path')), isNull);
      expect(bigoRoomFromUri(Uri.parse('https://evil.example/1234567')), isNull);
      expect(bigoHandleFromText('https://www.bigo.tv/search'), isNull);
      expect(bigoHandleFromText('1234567'), '1234567');
    });

    test('test_anAddressThatIsNotAnHttpsManifestIsNeverOpened', () {
      expect(() => bigoHlsUri('http://live.example/1.m3u8'), throwsA(isA<BigoFailure>()));
      expect(() => bigoHlsUri('https://live.example/1.flv'), throwsA(isA<BigoFailure>()));
      expect(bigoHlsUri(_hlsUrl).path, endsWith('.m3u8'));
    });
  });
}
