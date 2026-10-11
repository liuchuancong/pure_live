// Module: test/jdlive/jdlive_source_test.dart
// Purpose: The JD live source against a canned transport: the gateway body shape, the count cursor, the two
// containers of one stream and the playlist that has to be read before the address is trusted.
// Author: liuchuancong
// Created: 2026-10-11
//
// Bodies are written to the field names the v1 line reads, not recorded from the site (README 未验证).

import 'dart:convert';

import 'package:pure_live_network/pure_live_network.dart';
import 'package:pure_live_network/testing.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_sites/pure_live_sites.dart';
import 'package:test/test.dart';

const String _apiKey = 'api.m.jd.com/api';
const String _hlsUrl = 'https://live-stream.jdcloud.com/live/88776655.m3u8?txSecret=1';
const String _flvUrl = 'https://live-stream.jdcloud.com/live/88776655.flv?txSecret=1';
const String _playlistKey = 'live-stream.jdcloud.com/live/88776655.m3u8';

final DateTime _now = DateTime.fromMillisecondsSinceEpoch(1700000000000);
const ContentRef _room = ContentRef(sourceId: 'jdlive.live', contentId: '88776655', kind: ContentKind.liveRoom);

NetworkClient _client(ScriptedTransport transport) => NetworkClient(
  adapter: transport,
  clock: () => _now,
  settings: const NetworkSettings(retry: RetryPolicy(attempts: 1)),
);

(ScriptedTransport, JdliveSource) _source(Map<String, List<String>> script) {
  final transport = ScriptedTransport(script);
  return (transport, JdliveSource(client: _client(transport), clock: () => _now));
}

String _ok(Map<String, Object?> data, {String code = '0', String subCode = '0'}) =>
    jsonEncode(<String, Object?>{'code': code, 'subCode': subCode, 'data': data});

Map<String, Object?> _card({
  String liveId = '88776655',
  String? id,
  int templateType = 1,
  int status = 1,
  int pv = 40000,
  String title = '开播了',
}) => <String, Object?>{
  'templateType': templateType,
  'data': <String, Object?>{
    'liveId': liveId,
    'id': id ?? liveId,
    'authorId': '12345',
    'userName': '主播甲',
    'title': title,
    'userPic': 'https://img12.360buyimg.com/a.png',
    'indexImage': 'https://img12.360buyimg.com/c.png',
    'status': status,
    'pv': pv,
  },
};

String _directory(List<Object?> cards, {int currentCount = 30}) => _ok(<String, Object?>{
  'list': <Object?>[
    for (final card in cards)
      if (card is Map<String, Object?> && card.containsKey('templateType')) card else _card(),
  ],
  'currentCount': currentCount,
});

String _roomAnswer({String? liveId, int status = 1, String? hls = _hlsUrl, String? flv = _flvUrl, int secret = 0}) =>
    _ok(<String, Object?>{
      'liveId': liveId ?? '88776655',
      'status': status,
      'secret': secret,
      if (hls != null) 'h5VideoUrl': hls,
      if (flv != null) 'videoUrl': flv,
    });

const String _goodPlaylist = '#EXTM3U\n#EXT-X-TARGETDURATION:4\n#EXTINF:4,\n88776655-0.ts\n';

void main() {
  group('test_jdliveSource_directory', () {
    test('test_theGatewayTakesAJsonBodyInTheQuery', () async {
      final (transport, jd) = _source(<String, List<String>>{
        _apiKey: <String>[
          _directory(<Object?>[_card()]),
        ],
      });
      await jd.feed(PageRequest.first);
      final sent = transport.requests.single.uri.queryParameters;
      expect(sent['appid'], 'h5-live');
      expect(sent['functionId'], 'liveListWithTabToM');
      expect(jsonDecode(sent['body']!), <String, Object?>{
        'tabId': 1,
        'currentCount': '0',
        'page': 1,
        'timestamp': _now.millisecondsSinceEpoch,
      });
    });

    test('test_theDirectoryContinuesByTheCountItReported', () async {
      final (transport, jd) = _source(<String, List<String>>{
        _apiKey: <String>[
          _directory(<Object?>[for (var i = 0; i < 30; i++) _card(liveId: '${88000000 + i}')], currentCount: 30),
          _directory(<Object?>[_card(liveId: '88123456')], currentCount: 40),
        ],
      });
      final first = await jd.feed(PageRequest.first);
      expect(first.mode, PageMode.cursor);
      expect(first.hasMore, isTrue);
      final second = await jd.feed(PageRequest(page: 2, cursor: first.nextCursor));
      expect(second.items, hasLength(1));
      final body = jsonDecode(transport.requests.last.uri.queryParameters['body']!) as Map<String, Object?>;
      // The same walk: the first request's timestamp, and the count the last answer reported.
      expect(body['timestamp'], _now.millisecondsSinceEpoch);
      expect(body['currentCount'], '30');
      expect(body['page'], 2);
    });

    test('test_aSecondPageWithoutItsCursorIsRefused', () async {
      final (transport, jd) = _source(<String, List<String>>{
        _apiKey: <String>[
          _directory(<Object?>[_card()]),
        ],
      });
      await expectLater(jd.feed(const PageRequest(page: 2)), throwsA(isA<JdFailure>()));
      expect(transport.requestsTo(_apiKey), 0);
    });

    test('test_aCountThatDidNotMoveEndsTheList', () async {
      final (_, jd) = _source(<String, List<String>>{
        _apiKey: <String>[
          _directory(<Object?>[for (var i = 0; i < 30; i++) _card(liveId: '${88000000 + i}')], currentCount: 30),
          _directory(<Object?>[for (var i = 0; i < 30; i++) _card(liveId: '${88000000 + i}')], currentCount: 30),
        ],
      });
      final first = await jd.feed(PageRequest.first);
      final second = await jd.feed(PageRequest(page: 2, cursor: first.nextCursor));
      expect(second.hasMore, isFalse);
      expect(second.nextCursor, isNull);
    });

    test('test_aCardIsOnlyACardWhenItsTwoIdsAgree', () async {
      final (_, jd) = _source(<String, List<String>>{
        _apiKey: <String>[
          _directory(<Object?>[
            _card(),
            _card(liveId: '99000000', id: '99111111'),
            _card(liveId: '99222222', templateType: 2),
            _card(),
          ], currentCount: 30),
        ],
      });
      final page = await jd.feed(PageRequest.first);
      // The mismatched-id row and the banner template are not rooms; the repeat is one room.
      expect(page.items.map((item) => item.ref.contentId), <String>['88776655']);
    });

    test('test_theSubCodeIsTheRefusalThatMeansNoSuchLive', () async {
      final (_, jd) = _source(<String, List<String>>{
        _apiKey: <String>[
          jsonEncode(<String, Object?>{'code': '0', 'subCode': 'A0400', 'data': <String, Object?>{}}),
        ],
      });
      await expectLater(
        jd.feed(PageRequest.first),
        throwsA(predicate<JdFailure>((JdFailure error) => error.missing && error.subCode == 'A0400')),
      );
    });

    test('test_aRefusedCodeIsTheServiceNotAnEmptyPage', () async {
      final (_, jd) = _source(<String, List<String>>{
        _apiKey: <String>[
          jsonEncode(<String, Object?>{'code': '9002', 'subCode': '0', 'data': <String, Object?>{}}),
        ],
      });
      await expectLater(jd.feed(PageRequest.first), throwsA(predicate<JdFailure>((JdFailure error) => !error.missing)));
    });

    test('test_anUnknownListingIsRefused', () async {
      final (_, jd) = _source(<String, List<String>>{
        _apiKey: <String>[
          _directory(<Object?>[_card()]),
        ],
      });
      await expectLater(
        jd.browse(const ContentQuery(category: 'sports')),
        throwsA(isA<JdFailure>().having((JdFailure e) => e.message, 'message', contains('one featured directory'))),
      );
    });
  });

  group('test_jdliveSource_room', () {
    test('test_theTwoContainersMustNameOneStream', () async {
      final (_, jd) = _source(<String, List<String>>{
        _apiKey: <String>[_roomAnswer(flv: 'https://live-stream.jdcloud.com/live/99999999.flv')],
      });
      await expectLater(
        jd.room(_room),
        throwsA(isA<JdFailure>().having((JdFailure e) => e.message, 'message', contains('different streams'))),
      );
    });

    test('test_theAnswerAboutAnotherLiveIsRefused', () async {
      final (_, jd) = _source(<String, List<String>>{
        _apiKey: <String>[_roomAnswer(liveId: '12345678')],
      });
      await expectLater(jd.room(_room), throwsA(isA<JdFailure>()));
    });

    test('test_aThinRoomAnswerKeepsTheCardsMetadataButNotItsNumbers', () async {
      final (_, jd) = _source(<String, List<String>>{
        _apiKey: <String>[
          _directory(<Object?>[_card()], currentCount: 30),
          jsonEncode(<String, Object?>{
            'code': '0',
            'subCode': '0',
            'data': <String, Object?>{'liveId': '88776655', 'status': 1, 'h5VideoUrl': _hlsUrl},
          }),
        ],
      });
      await jd.feed(PageRequest.first);
      final room = await jd.room(_room);
      expect(room.anchorName, '主播甲');
      expect(room.cover, 'https://img12.360buyimg.com/c.png');
      // The card's cumulative audience is not carried onto a fresh answer that stated none.
      expect(room.audience, isNull);
    });

    test('test_aPausedLiveIsUnknownAndAReplayIsEndedWithCatchUp', () async {
      final (_, paused) = _source(<String, List<String>>{
        _apiKey: <String>[_roomAnswer(status: 10)],
      });
      expect((await paused.room(_room)).state, LiveRoomState.unknown);
      final (_, replay) = _source(<String, List<String>>{
        _apiKey: <String>[_roomAnswer(status: 3)],
      });
      final live = await replay.room(_room);
      expect(live.state, LiveRoomState.ended);
      expect(live.catchUp?.isOffered, isTrue);
      expect(live.restriction, isNull, reason: 'an ended broadcast has no gate; it has nothing to open');
    });

    test('test_theTotalAudienceIsNotAHeadcount', () async {
      final (_, jd) = _source(<String, List<String>>{
        _apiKey: <String>[
          _directory(<Object?>[_card(pv: 500000)]),
        ],
      });
      final room = jdliveCard(_card(pv: 500000))!.toLiveRoom();
      expect(room.audiencePrimary, 500000);
      // 50 万是累计人次,不是同时在看了这么多人。
      expect(room.audienceMetric, LiveAudienceMetric.totalViewers);
      expect(room.audienceCountsPeople, isTrue, reason: 'total visitors do count people, unlike a heat score');
      expect((await jd.feed(PageRequest.first)).items.single.metadata.popularity, 500000);
    });

    test('test_theLiveIdAcceptsItsOwnDigitsAndTheHashRoute', () {
      expect(jdliveId('88776655'), '88776655');
      expect(jdliveRoomFromUri(Uri.parse('https://lives.jd.com/#/88776655')), '88776655');
      expect(jdliveRoomFromUri(Uri.parse('https://lives.jd.com/#/88776655/replay')), '88776655');
      expect(jdliveRoomFromUri(Uri.parse('https://lives.jd.com/#/088776655')), isNull);
      expect(jdliveRoomFromUri(Uri.parse('https://www.jd.com/#/88776655')), isNull);
      expect(jdliveWatchUrl('88776655'), 'https://lives.jd.com/#/88776655');
    });

    test('test_theMediaAddressMustStayOnTheDeliveryFamily', () {
      expect(jdliveMediaUri(_hlsUrl, extension: '.m3u8')?.host, 'live-stream.jdcloud.com');
      expect(jdliveMediaUri('https://evil.example/live/88776655.m3u8', extension: '.m3u8'), isNull);
      expect(jdliveMediaUri('https://live-stream.jdcloud.com/movie/88776655.m3u8', extension: '.m3u8'), isNull);
      expect(jdliveMediaUri('https://live-stream.jdcloud.com/live/88776655.flv', extension: '.m3u8'), isNull);
      expect(jdliveMediaUri('http://live-stream.jdcloud.com/live/88776655.m3u8', extension: '.m3u8'), isNull);
    });
  });

  group('test_jdliveSource_play', () {
    test('test_hlsAndFlvAreLinesOfOneProfile', () async {
      final (_, jd) = _source(<String, List<String>>{
        _apiKey: <String>[_roomAnswer()],
      });
      final qualities = await jd.qualities(_room);
      expect(qualities, hasLength(1));
      expect(qualities.single.id, 'origin');
      final lines = await jd.lines(_room);
      expect(lines.map((line) => line.id), <String>['1', '2']);
      expect(lines.map((line) => line.label), <String>['hls', 'flv']);
    });

    test('test_thePlaylistIsReadBeforeTheAddressIsHandedOut', () async {
      final (transport, jd) = _source(<String, List<String>>{
        _apiKey: <String>[_roomAnswer()],
        _playlistKey: <String>[_goodPlaylist],
      });
      final ticket = await jd.resolve(_room);
      expect(ticket.uri.toString(), _hlsUrl);
      expect(ticket.protocol, MediaProtocol.hls);
      expect(ticket.headers['referer'], 'https://lives.jd.com/#/88776655');
      expect(transport.requestsTo(_apiKey), 1);
      expect(transport.requestsTo(_playlistKey), 1);
    });

    test('test_aPlaylistPointingElsewhereIsRefused', () async {
      final (_, jd) = _source(<String, List<String>>{
        _apiKey: <String>[_roomAnswer()],
        _playlistKey: <String>['#EXTM3U\n#EXT-X-TARGETDURATION:4\n#EXTINF:4,\nother-stream-0.ts\n'],
      });
      await expectLater(
        jd.resolve(_room),
        throwsA(isA<JdFailure>().having((JdFailure e) => e.message, 'message', contains('outside this stream'))),
      );
    });

    test('test_aPlaylistWithNoMediaIsRefused', () async {
      final (_, jd) = _source(<String, List<String>>{
        _apiKey: <String>[_roomAnswer()],
        _playlistKey: <String>['#EXTM3U\n#EXT-X-ENDLIST\n'],
      });
      await expectLater(jd.resolve(_room), throwsA(isA<JdFailure>()));
    });

    test('test_aSecretLiveIsAppOnly', () async {
      final (_, jd) = _source(<String, List<String>>{
        _apiKey: <String>[_roomAnswer(secret: 1)],
      });
      final room = await jd.room(_room);
      expect(room.restriction, LiveRestriction.appOnly);
      expect(room.requiresAuth, isTrue);
      expect((await jd.qualities(_room)).single.requiresAuth, isTrue);
      await expectLater(
        jd.resolve(_room),
        throwsA(isA<StateError>().having((StateError e) => e.message, 'message', contains('inside the JD app'))),
      );
    });

    test('test_anOnAirLiveWithNoAddressIsUnplayable', () async {
      final (_, jd) = _source(<String, List<String>>{
        _apiKey: <String>[_roomAnswer(hls: null, flv: null)],
      });
      final room = await jd.room(_room);
      expect(room.state, LiveRoomState.live);
      expect(room.restriction, LiveRestriction.unplayable);
      expect(await jd.qualities(_room), isEmpty);
    });

    test('test_theFlvLineKeepsItsOwnContainer', () async {
      final (_, jd) = _source(<String, List<String>>{
        _apiKey: <String>[_roomAnswer()],
        _playlistKey: <String>[_goodPlaylist],
      });
      final ticket = await jd.resolve(_room, line: const SelectionRef('2'));
      expect(ticket.metadata.extra['container'], 'flv');
      expect(ticket.protocol, MediaProtocol.https);
      await expectLater(jd.resolve(_room, line: const SelectionRef('3')), throwsA(isA<StateError>()));
    });

    test('test_refreshReReadsTheGrant', () async {
      final (transport, jd) = _source(<String, List<String>>{
        _apiKey: <String>[_roomAnswer(), _roomAnswer()],
        _playlistKey: <String>[_goodPlaylist, _goodPlaylist],
      });
      final ticket = await jd.resolve(_room);
      final again = await jd.refresh(ticket, RefreshReason.expiring);
      expect(again.uri, ticket.uri);
      expect(transport.requestsTo(_apiKey), 2);
      expect(transport.requestsTo(_playlistKey), 2);
    });

    test('test_anOfflineRoomIsNamedAsOffline', () async {
      final (_, jd) = _source(<String, List<String>>{
        _apiKey: <String>[_roomAnswer(status: 2)],
        _playlistKey: <String>[_goodPlaylist],
      });
      await expectLater(
        jd.resolve(_room),
        throwsA(isA<StateError>().having((StateError e) => e.message, 'message', contains('not broadcasting'))),
      );
    });
  });
}
