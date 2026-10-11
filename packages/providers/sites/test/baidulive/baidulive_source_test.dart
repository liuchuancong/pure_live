// Module: test/baidulive/baidulive_source_test.dart
// Purpose: The Baidu live source against a canned transport: the session-cursored feed, the two status numbering
// schemes, the signed feed request and the host-allow-listed per-codec addresses.
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

const String _feedKey = 'tiebac.baidu.com/livefeed/feed';
const String _roomKey = 'mbd.baidu.com/searchbox';

final DateTime _now = DateTime.fromMillisecondsSinceEpoch(1700000000000);
const ContentRef _room = ContentRef(sourceId: 'baidulive.live', contentId: '123456', kind: ContentKind.liveRoom);

const String _flvUrl = 'http://flv-live.bdstatic.com/live/show_123456-avc.flv?sign=abc';
const String _hlsUrl = 'http://hls-live.bdstatic.com/live/show_123456.m3u8?sign=abc';
const String _hevcUrl = 'https://pull.liveshow.bdstatic.com/live/show_123456-hevc.flv?sign=abc';

NetworkClient _client(ScriptedTransport transport) => NetworkClient(
  adapter: transport,
  clock: () => _now,
  settings: const NetworkSettings(retry: RetryPolicy(attempts: 1)),
);

(ScriptedTransport, BaiduliveSource) _source(Map<String, List<String>> script) {
  final transport = ScriptedTransport(script);
  return (transport, BaiduliveSource(client: _client(transport), clock: () => _now));
}

Map<String, Object?> _card({String roomId = '123456', int liveStatus = 1, int audience = 50, String title = '开播了'}) =>
    <String, Object?>{
      'room_id': roomId,
      'live_status': liveStatus,
      'title': title,
      'audience_count': audience,
      'live_tag': '购物',
      'host': <String, Object?>{'name': '主播甲', 'uk': 'uk-9', 'avatar': 'https://pic.bdstatic.com/a.png'},
      'cover': 'https://img.bdstatic.com/c.jpg',
    };

/// A filled page. The feed's own fill is ten, and `hasMore` is decided against that number, so a one-row script
/// would already be a short page.
List<Object?> _cards(int count, {int first = 123456}) => <Object?>[
  for (var index = 0; index < count; index++) _card(roomId: '${first + index}'),
];

String _feed({
  List<Object?> items = const <Object?>[],
  List<Object?> tabs = const <Object?>[],
  String session = 'sess-1',
  int refreshIndex = 1,
  int errno = 0,
  int innerErrno = 0,
}) => jsonEncode(<String, Object?>{
  'errno': errno,
  'data': <String, Object?>{
    'feed': <String, Object?>{
      'inner_errno': innerErrno,
      'items': items,
      'session_id': session,
      'refresh_index': refreshIndex,
    },
    if (tabs.isNotEmpty) 'tab': <String, Object?>{'inner_errno': 0, 'items': tabs},
  },
});

Map<String, Object?> _video({List<Object?>? clarity, List<Object?>? urlList, Map<String, Object?>? bare}) =>
    <String, Object?>{
      'title': '开播了',
      'cover': <String, Object?>{'cover_100': 'https://img.bdstatic.com/c.jpg'},
      if (clarity != null) 'url_clarity_list': clarity,
      if (urlList != null) 'url_list': urlList,
      ...?bare,
    };

Map<String, Object?> _clarity(int resolution, Map<String, Object?> urls) => <String, Object?>{
  'resolution': resolution,
  'urls': urls,
};

String _roomAnswer({
  int status = 0,
  Map<String, Object?>? video,
  Map<String, Object?>? host,
  int? errorCode,
  String? shareUrl,
  Map<String, Object?>? commandExtra,
  int errno = 0,
}) => jsonEncode(<String, Object?>{
  'errno': errno,
  'data': <String, Object?>{
    '371': <String, Object?>{
      'error_code': errorCode ?? 0,
      if (shareUrl != null) 'share_url': shareUrl,
      'status': status,
      'online_users': 300,
      'real_fans_num': 900,
      'category': '购物',
      'host':
          host ??
          <String, Object?>{
            'uk': 'uk-9',
            'nick_name': '主播甲',
            'image': <String, Object?>{'image_33': 'https://pic.bdstatic.com/a.png'},
          },
      'video':
          video ??
          _video(
            clarity: <Object?>[
              _clarity(4, <String, Object?>{'flv': _flvUrl, 'hls': _hlsUrl}),
            ],
          ),
      ...?commandExtra,
    },
  },
});

void main() {
  group('test_baiduliveSource_directory', () {
    test('test_theFeedPagesByTheCursorTheAnswerGave', () async {
      final (transport, baidu) = _source(<String, List<String>>{
        _feedKey: <String>[
          _feed(items: _cards(10), session: 'sess-1', refreshIndex: 1),
          _feed(items: _cards(10, first: 200000), session: 'sess-1', refreshIndex: 2),
        ],
      });
      final first = await baidu.feed(PageRequest.first);
      expect(first.mode, PageMode.cursor);
      expect(first.pageSize, baiduliveFeedPageSize, reason: 'the server fills ten, not what the caller asked for');
      expect(first.hasMore, isTrue);
      expect(first.nextCursor, isNotNull);
      final second = await baidu.feed(PageRequest(page: 2, cursor: first.nextCursor));
      expect(second.items.first.ref.contentId, '200000');
      // The continuation is the previous answer's counter plus one, sent with the session it came from.
      final sent = Uri.splitQueryString(transport.requests.last.bodyText!);
      expect(sent['session_id'], 'sess-1');
      expect(sent['refresh_index'], '2');
      expect(sent['resource'], 'feed', reason: 'only the first page asks for the banner and tab blocks');
      expect(sent['sign'], hasLength(32));
    });

    test('test_aSecondPageWithoutItsCursorIsRefusedNotAnsweredAsTheFirst', () async {
      final (transport, baidu) = _source(<String, List<String>>{
        _feedKey: <String>[_feed(items: _cards(10))],
      });
      await expectLater(baidu.feed(const PageRequest(page: 2)), throwsA(isA<BaiduliveFailure>()));
      expect(transport.requestsTo(_feedKey), 0);
    });

    test('test_aRefreshCounterThatDidNotAdvanceEndsTheList', () async {
      final (_, baidu) = _source(<String, List<String>>{
        _feedKey: <String>[
          _feed(items: _cards(10), refreshIndex: 1),
          _feed(items: _cards(10, first: 200000), refreshIndex: 1),
        ],
      });
      final first = await baidu.feed(PageRequest.first);
      final second = await baidu.feed(PageRequest(page: 2, cursor: first.nextCursor));
      expect(first.hasMore, isTrue);
      // The site repeated its own counter: the next request would return the same page, so the list is over.
      expect(second.hasMore, isFalse);
    });

    test('test_theTabBlockArrivesWithTheFeedBecauseThereIsNoCategoryEndpoint', () async {
      final (_, baidu) = _source(<String, List<String>>{
        _feedKey: <String>[
          _feed(
            items: _cards(10),
            tabs: <Object?>[
              <String, Object?>{'type': 'REC', 'name': '推荐', 'channel_id': 570},
              <String, Object?>{'type': 'finance', 'name': '财经', 'channel_id': 611},
              <String, Object?>{'type': '推荐', 'name': '畸形', 'channel_id': 0},
            ],
          ),
        ],
      });
      final categories = await baidu.categories();
      // The tab name is lower-cased because it doubles as the request's `tab` parameter, which is `[a-z]` shaped.
      expect(categories.map((category) => category.id), <String>['rec', 'finance']);
      final page = await baidu.browse(const ContentQuery(category: 'finance'));
      expect(page.items, hasLength(10));
    });

    test('test_anUnseenTabIsRefusedRatherThanAnsweredWithTheRecommendations', () async {
      final (transport, baidu) = _source(<String, List<String>>{
        _feedKey: <String>[_feed(items: _cards(10))],
      });
      await expectLater(baidu.browse(const ContentQuery(category: 'games')), throwsA(isA<BaiduliveFailure>()));
      expect(transport.requestsTo(_feedKey), 0, reason: 'a refused menu choice must not cost a request');
    });

    test('test_theSiteOwnMenuSurvivesAnAnswerWithNoTabs', () async {
      final (_, baidu) = _source(<String, List<String>>{
        _feedKey: <String>[_feed(items: _cards(10))],
      });
      expect(await baidu.categories(), hasLength(7), reason: 'absent tabs are not "this site has no channels"');
    });

    test('test_aFeedRefusalIsAServiceFailureNotAnEmptyPage', () async {
      final (_, baidu) = _source(<String, List<String>>{
        _feedKey: <String>[_feed(items: _cards(10), errno: 4)],
      });
      await expectLater(baidu.feed(PageRequest.first), throwsA(isA<BaiduliveFailure>()));
    });
  });

  group('test_baiduliveSource_states', () {
    test('test_theFeedCallsOneLiveAndTheRoomCommandCallsZeroLive', () async {
      final (_, baidu) = _source(<String, List<String>>{
        _feedKey: <String>[
          _feed(
            items: <Object?>[
              _card(liveStatus: 1),
              _card(roomId: '234567', liveStatus: 0),
              _card(roomId: '345678', liveStatus: 3, audience: 0),
              _card(roomId: '456789', liveStatus: 7),
            ],
          ),
        ],
      });
      // Two endpoints, two numberings for the same words: a shared mapping would call every live grid card preview.
      expect(baiduliveFeedState(1), BaiduliveState.live);
      expect(baiduliveCommandState(0), BaiduliveState.live);
      expect(baiduliveFeedState(0), BaiduliveState.preview);
      expect(baiduliveCommandState(-1), BaiduliveState.preview);
      expect(baiduliveCommandState(20), BaiduliveState.offline);
      expect(baiduliveFeedState(7), BaiduliveState.unknown);
      final page = await baidu.feed(PageRequest.first);
      expect(page.items.map((item) => item.metadata.extra['baidulive.state']), <String>[
        'live',
        'preview',
        'replay',
        'unknown',
      ]);
    });

    test('test_aReplayCardIsEndedWithCatchUpOffered', () {
      final room = baiduliveFeedCard(_card(liveStatus: 3))!.toLiveRoom();
      expect(room.state, LiveRoomState.ended);
      expect(room.catchUp?.isOffered, isTrue);
      expect(room.audience, isNull, reason: 'a replay has no current audience');
    });

    test('test_aPreviewRoomIsNotCalledOffline', () async {
      final (_, baidu) = _source(<String, List<String>>{
        _roomKey: <String>[_roomAnswer(status: 1)],
      });
      expect((await baidu.room(_room)).state, LiveRoomState.notStarted);
      await expectLater(
        baidu.resolve(_room),
        throwsA(isA<StateError>().having((StateError e) => e.message, 'message', contains('has not started'))),
      );
    });

    test('test_aCardThatIsNotARoomIsAnAdSlotNotATile', () async {
      final (_, baidu) = _source(<String, List<String>>{
        _feedKey: <String>[
          _feed(
            items: <Object?>[
              _card(),
              <String, Object?>{'room_id': 'banner', 'title': '活动位'},
            ],
          ),
        ],
      });
      expect((await baidu.feed(PageRequest.first)).items, hasLength(1));
    });

    test('test_theRoomAnswerAboutAnotherRoomIsRefused', () async {
      final (_, baidu) = _source(<String, List<String>>{
        _roomKey: <String>[_roomAnswer(shareUrl: 'https://live.baidu.com/m/room/234567')],
      });
      await expectLater(baidu.room(_room), throwsA(isA<BaiduliveFailure>()));
    });

    test('test_errorOneAndFourAreMissingWhileOthersAreTheService', () async {
      for (final (int code, bool missing) in <(int, bool)>[(1, true), (4, true), (9, false)]) {
        final (_, baidu) = _source(<String, List<String>>{
          _roomKey: <String>[_roomAnswer(errorCode: code)],
        });
        await expectLater(
          baidu.room(_room),
          throwsA(predicate<BaiduliveFailure>((BaiduliveFailure error) => error.missing == missing)),
          reason: 'error_code $code should read as missing: $missing',
        );
      }
    });

    test('test_anAnswerWithNoCommandBlockIsMissingNotService', () async {
      final (_, baidu) = _source(<String, List<String>>{
        _roomKey: <String>[
          jsonEncode(<String, Object?>{'errno': 0, 'data': <String, Object?>{}}),
        ],
      });
      await expectLater(baidu.room(_room), throwsA(predicate<BaiduliveFailure>((BaiduliveFailure e) => e.missing)));
    });

    test('test_aThinRoomAnswerKeepsWhatTheListingShowedButNoAudience', () async {
      final (_, baidu) = _source(<String, List<String>>{
        _feedKey: <String>[_feed(items: _cards(10))],
        _roomKey: <String>[
          _roomAnswer(status: 2, video: <String, Object?>{}, host: <String, Object?>{'uk': 'uk-9'}),
        ],
      });
      await baidu.feed(PageRequest.first);
      final room = await baidu.room(_room);
      // The command said nothing about the anchor or the pictures, so the card's are kept…
      expect(room.anchorName, '主播甲');
      expect(room.cover, 'https://img.bdstatic.com/c.jpg');
      // …but the card's viewer count is never carried onto a room the command says is off air.
      expect(room.audience, isNull);
      expect(room.state, LiveRoomState.ended);
    });
  });

  group('test_baiduliveSource_media', () {
    test('test_qualitiesAreProtocolResolutionCodecAndLinesAreTheAddressesInsideOne', () async {
      final (_, baidu) = _source(<String, List<String>>{
        _roomKey: <String>[
          _roomAnswer(
            video: _video(
              clarity: <Object?>[
                _clarity(4, <String, Object?>{'flv': _flvUrl, 'hls': _hlsUrl, 'hevc_flv': _hevcUrl}),
                _clarity(2, <String, Object?>{'flv': 'https://pull.liveshow.bdstatic.com/live/show_123456-2.flv'}),
              ],
            ),
          ),
        ],
      });
      final qualities = await baidu.qualities(_room);
      expect(qualities.map((option) => option.id), <String>['flv:4:avc', 'flv:4:hevc', 'hls:4:avc', 'flv:2:avc']);
      expect(qualities.first.label, 'FLV 4 AVC');
      expect(qualities.first.rank, 4);
      // The lines are the addresses of the top variant only.
      expect((await baidu.lines(_room)).map((line) => line.id), <String>['1']);
    });

    test('test_theFlvHostStaysHttpAndTheOthersBecomeHttps', () {
      expect(baiduliveMediaUrl(_flvUrl, roomId: '123456', protocol: 'flv'), startsWith('http://flv-live.'));
      expect(baiduliveMediaUrl(_hlsUrl, roomId: '123456', protocol: 'hls'), startsWith('https://hls-live.'));
      expect(baiduliveMediaUrl(_hevcUrl, roomId: '123456', protocol: 'flv'), startsWith('https://pull.liveshow.'));
    });

    test('test_anAddressForAnotherBroadcastIsNeverPlayed', () {
      expect(
        baiduliveMediaUrl('https://hls-live.bdstatic.com/live/show_999999.m3u8', roomId: '123456', protocol: 'hls'),
        isNull,
      );
      expect(
        baiduliveMediaUrl('https://evil.example.com/live/show_123456.flv', roomId: '123456', protocol: 'flv'),
        isNull,
      );
      expect(
        baiduliveMediaUrl('https://hls-live.bdstatic.com/movie/show_123456.flv', roomId: '123456', protocol: 'flv'),
        isNull,
        reason: 'the path has to start under /live/',
      );
    });

    test('test_aBareUrlInheritsTheResolutionWrittenNextToTheSameFile', () async {
      final (_, baidu) = _source(<String, List<String>>{
        _roomKey: <String>[
          _roomAnswer(
            video: _video(
              urlList: <Object?>[
                <String, Object?>{
                  'resolution': 3,
                  'urls': <Object?>[
                    <String, Object?>{'hls': _hlsUrl, 'flv': _flvUrl},
                  ],
                },
              ],
              bare: <String, Object?>{'live_hls_url': _hlsUrl, 'live_flv_url': _flvUrl},
            ),
          ),
        ],
      });
      final qualities = await baidu.qualities(_room);
      // The bare hls field names the same file as the listed one, so it takes that entry's resolution…
      expect(qualities.map((option) => option.id), contains('hls:3:avc'));
      // …while the bare flv field states none and is labelled without a number rather than as a 0p row.
      final unknown = qualities.firstWhere((StreamOption option) => option.id == 'flv:0:avc');
      expect(unknown.label, 'FLV AVC');
      expect(unknown.rank, isNull);
    });

    test('test_aLiveRoomWithNoUsableAddressIsUnplayableNotOffline', () async {
      final (_, baidu) = _source(<String, List<String>>{
        _roomKey: <String>[_roomAnswer(video: _video(clarity: const <Object?>[]))],
      });
      final room = await baidu.room(_room);
      expect(room.state, LiveRoomState.live);
      expect(room.restriction, LiveRestriction.unplayable);
      await expectLater(baidu.resolve(_room), throwsA(isA<StateError>()));
    });

    test('test_aPaidRoomSaysSoInsteadOfFailingSilently', () async {
      final (_, baidu) = _source(<String, List<String>>{
        _roomKey: <String>[
          _roomAnswer(commandExtra: <String, Object?>{'has_pay_service': 1}),
        ],
      });
      final room = await baidu.room(_room);
      expect(room.restriction, LiveRestriction.paid);
      expect(room.requiresAuth, isTrue);
    });

    test('test_aBannedRoomIsUnplayableRatherThanPaid', () async {
      final (_, baidu) = _source(<String, List<String>>{
        _roomKey: <String>[
          _roomAnswer(commandExtra: <String, Object?>{'ban_status': 2}),
        ],
      });
      expect((await baidu.room(_room)).restriction, LiveRestriction.unplayable);
    });

    test('test_resolveNamesTheProtocolAndCarriesTheVariantIntoRefresh', () async {
      final (transport, baidu) = _source(<String, List<String>>{
        _roomKey: <String>[
          _roomAnswer(
            video: _video(
              clarity: <Object?>[
                _clarity(4, <String, Object?>{'flv': _flvUrl, 'hls': _hlsUrl}),
              ],
            ),
          ),
        ],
      });
      final ticket = await baidu.resolve(_room, quality: const SelectionRef('hls:4:avc'));
      expect(ticket.protocol, MediaProtocol.hls);
      expect(ticket.uri.queryParameters['sign'], 'abc');
      expect(ticket.headers['referer'], 'https://live.baidu.com/m/room/123456');
      final flv = await baidu.resolve(_room, quality: const SelectionRef('flv:4:avc'));
      // The flv host is served without TLS by the site itself; the ticket says http rather than claiming https.
      expect(flv.protocol, MediaProtocol.http);
      expect(flv.uri.scheme, 'http');
      final again = await baidu.refresh(ticket, RefreshReason.expiring);
      expect(again.metadata.extra['baidulive.quality'], 'hls:4:avc');
      expect(transport.requestsTo(_roomKey), 3);
    });

    test('test_anUnknownLineIsRefusedRatherThanPlayedAsLineOne', () async {
      final (_, baidu) = _source(<String, List<String>>{
        _roomKey: <String>[_roomAnswer()],
      });
      await expectLater(baidu.resolve(_room, line: const SelectionRef('4')), throwsA(isA<StateError>()));
    });

    test('test_theChatHandshakePollsOnTheSitesOwnInterval', () async {
      final (_, baidu) = _source(<String, List<String>>{
        _roomKey: <String>[
          _roomAnswer(
            commandExtra: <String, Object?>{
              'chat_msg_hls_url': 'https://hls-live.bdstatic.com/live/show_123456.m3u8',
              'msg_hls_pull_internal_in_second': 30,
            },
          ),
        ],
      });
      final payload = (await baidu.room(_room)).danmakuPayload;
      expect(payload['chatListUrl'], 'https://hls-live.bdstatic.com/live/show_123456.m3u8');
      // The interval is clamped to what the site's own client will ask for.
      expect(payload['pollSeconds'], 10);
    });

    test('test_aRoomWithoutAChatUrlCarriesNoHandshake', () async {
      final (_, baidu) = _source(<String, List<String>>{
        _roomKey: <String>[_roomAnswer()],
      });
      expect((await baidu.room(_room)).danmakuPayload, isEmpty);
    });
  });

  group('test_baiduliveSource_readers', () {
    test('test_theSignatureHashesSortedParametersPlusTheSiteKey', () {
      // Insertion order is not the hash order: 'b' before 'a' in the map, 'a' first in the canonical string.
      expect(baiduliveSign(<String, String>{'b': '2', 'a': '1'}), '6ccb27769bec11fe1c1db46f74b97f15');
      expect(
        baiduliveSign(<String, String>{
          'appname': 'pclive',
          'sid': '',
          'ua': baiduliveRoomUa,
          'uid': 'pc-aaaaaaaaaaaaaaaaaaaaaaaa',
          'timestamp': '1700000000',
          'source': 'pclive',
          'resource': 'banner,tab,feed',
          'scene': 'pc_channel',
          'session_id': '',
          'refresh_type': '0',
          'refresh_index': '1',
          'tab': 'rec',
          'channel_id': '570',
          'sign': 'ignored',
        }),
        '71842f33d46bb9dc7a09d653530af050',
      );
    });

    test('test_theRoomIdAcceptsItsOwnDigitsAndThePagesTheSitePublishes', () {
      expect(baiduliveParseRoomId('123456'), '123456');
      expect(baiduliveRoomFromUri(Uri.parse('https://live.baidu.com/m/room/123456')), '123456');
      expect(
        baiduliveRoomFromUri(Uri.parse('https://live.baidu.com/m/media/pclive/pchome/live.html?room_id=123456')),
        '123456',
      );
      expect(
        baiduliveRoomFromUri(Uri.parse('https://live.baidu.com/m/media/multipage/liveshow/index?room_id=123456&x=1')),
        isNull,
        reason: 'the share path needs its token segment, which this url does not have',
      );
      expect(baiduliveRoomFromUri(Uri.parse('https://live.baidu.com/other?room_id=123456')), isNull);
      expect(baiduliveRoomFromUri(Uri.parse('https://live.baidu.com/m/room/12345')), isNull);
      expect(() => baiduliveRoomId('nonsense'), throwsA(isA<BaiduliveFailure>()));
    });

    test('test_theCursorRoundTripsAndGarbageIsRefused', () {
      final cursor = baiduliveEncodeCursor('sess/1?a', 7);
      expect(cursor, isNotNull);
      expect(baiduliveDecodeCursor(cursor), (sessionId: 'sess/1?a', refreshIndex: 7));
      expect(baiduliveDecodeCursor(null), isNull);
      expect(() => baiduliveDecodeCursor('no-separator'), throwsA(isA<BaiduliveFailure>()));
      expect(baiduliveEncodeCursor('', 1), isNull);
    });

    test('test_aPictureOffTheImageHostsIsDropped', () {
      expect(baiduliveImage('//pic.bdstatic.com/a.png'), 'https://pic.bdstatic.com/a.png');
      expect(baiduliveImage('http://pic.bdstatic.com/a.png'), isNull, reason: 'pictures are asked for over https');
      expect(baiduliveImage('https://evil.example.com/a.png'), isNull);
    });
  });
}
