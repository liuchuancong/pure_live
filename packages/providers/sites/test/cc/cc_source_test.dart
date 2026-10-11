// Module: test/cc/cc_source_test.dart
// Purpose: The NetEase CC source against a canned transport: the assembled menu, the fixed-width grids, the
// two-call room and the tier/cdn reading.
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

const String _registryKey = 'inf.ds.163.com/v1/web/game-center/basic/base-info-list/by-type';
const String _configKey = 'inf-act.ds.163.com/v1/act-web/pageConf/commonAppConfig';
const String _gameKey = 'cc.163.com/api/category/1001/';
const String _homeKey = 'cc.163.com/api/category/live/';
const String _anchorKey = 'api.cc.163.com/v1/activitylives/anchor/lives';
const String _channelKey = 'cc.163.com/live/channel/';
const String _searchKey = 'cc.163.com/search/anchor';

final DateTime _now = DateTime.fromMillisecondsSinceEpoch(1700000000000);
const ContentRef _room = ContentRef(sourceId: 'cc.live', contentId: '13906009', kind: ContentKind.liveRoom);
const String _m3u8 = 'https://live.ws.163.net/5001.m3u8';

NetworkClient _client(ScriptedTransport transport) => NetworkClient(
  adapter: transport,
  clock: () => _now,
  settings: const NetworkSettings(retry: RetryPolicy(attempts: 1)),
);

(ScriptedTransport, CcSource) _source(Map<String, List<String>> script) {
  final transport = ScriptedTransport(script);
  return (transport, CcSource(client: _client(transport), clock: () => _now));
}

String _registry(List<Object?> rows) => jsonEncode(<String, Object?>{'code': 200, 'result': rows});

String _config(List<Object?> entries, {bool hideGroup = false, String id = ccCatalogConfigurationId}) =>
    jsonEncode(<String, Object?>{
      'code': 200,
      'result': <String, Object?>{
        'id': id,
        'itemList': <Object?>[
          <String, Object?>{'name': '直播入口列表', 'hidden': hideGroup, 'itemList': entries},
        ],
      },
    });

Map<String, Object?> _entry(String appKey, String path) => <String, Object?>{
  'name': appKey,
  'content': 'https://cc.163.com$path',
};

Map<String, Object?> _game(String appKey, String name) => <String, Object?>{
  'appKey': appKey,
  'name': name,
  'icon': 'https://ds.nie.163.net/$appKey.png',
};

String _listing(String key, List<Object?> rows) => jsonEncode(<String, Object?>{'gametype': key, 'lives': rows});

Map<String, Object?> _row({
  String cuteid = '13906009',
  int? status = 1,
  String title = '开播了',
  int webcc = 500000,
  int vision = 20,
}) => <String, Object?>{
  'cuteid': cuteid,
  'status': status,
  'title': title,
  'nickname': '主播甲',
  'cover': 'https://ccimg.hz.netease.com/c.jpg',
  'purl': 'https://ccimg.hz.netease.com/a.jpg',
  'game_name': '永劫无间',
  'webcc_visitor': webcc,
  'vision_visitor': vision,
  'startat': '2026-10-11 20:00:00',
  'follower_num': 1200,
};

String _anchor({String roomId = '13906009', String channelId = '5001', bool broken = false}) =>
    jsonEncode(<String, Object?>{
      'code': 200,
      'data': <String, Object?>{
        if (!broken)
          roomId: <String, Object?>{'channel_id': channelId}
        else
          '99999': <String, Object?>{'channel_id': channelId},
      },
    });

String _channel(Map<String, Object?> row) => jsonEncode(<String, Object?>{
  'code': 200,
  'data': <Object?>[row],
});

Map<String, Object?> _channelRow({Map<String, Object?>? quickplay, String? m3u8, int status = 1, Object? streamList}) =>
    <String, Object?>{
      'ccid': '5001',
      'cid': '777',
      'title': '开播了',
      'nickname': '主播甲',
      'gamename': '永劫无间',
      'status': status,
      'cover': 'https://ccimg.hz.netease.com/c.jpg',
      'purl': 'https://ccimg.hz.netease.com/a.jpg',
      'personal_label': '主播简介',
      'follower_num': 1200,
      'vision_visitor': 20,
      'webcc_visitor': 500000,
      'startat': '2026-10-11 20:00:00',
      if (m3u8 != null) 'm3u8': m3u8,
      if (quickplay != null) 'quickplay': quickplay,
      if (streamList != null) 'stream_list': streamList,
    };

void main() {
  group('test_ccSource_catalog', () {
    test('test_theMenuIsTheConfigurationSelectingFromTheRegistry', () async {
      final (_, cc) = _source(<String, List<String>>{
        _registryKey: <String>[
          _registry(<Object?>[
            _game('yjj', '永劫无间'),
            _game('mh', '梦幻西游'),
            _game('ds', '官方入口'),
            _game('unlisted', '没被配置的'),
          ]),
        ],
        _configKey: <String>[
          _config(<Object?>[
            _entry('yjj', '/n/ds_category/1001/'),
            _entry('mh', '/n/ds_category/1002/'),
            _entry('ds', '/13906009/'),
          ]),
        ],
      });
      final categories = await cc.categories();
      // Only the games the live-entry configuration lists are navigable.
      expect(categories.map((category) => category.id), <String>['1001', '1002', 'official:13906009']);
      expect(categories.first.name, '永劫无间');
      expect(categories.first.parentId, '1');
      expect(categories.last.parentId, 'official');
      // An official entry is named by its game record too; only its destination differs.
      expect(categories.last.icon, 'https://ds.nie.163.net/ds.png');
    });

    test('test_anEntryWhoseGameIsMissingIsAChangedConfiguration', () async {
      final (_, cc) = _source(<String, List<String>>{
        _registryKey: <String>[
          _registry(<Object?>[_game('yjj', '永劫无间')]),
        ],
        _configKey: <String>[
          _config(<Object?>[_entry('ghost', '/n/ds_category/1002/')]),
        ],
      });
      await expectLater(
        cc.categories(),
        throwsA(isA<CcFailure>().having((CcFailure e) => e.message, 'message', contains('no game behind it'))),
      );
    });

    test('test_aConfigurationForAnotherPageIsNotTheMenu', () async {
      final (_, cc) = _source(<String, List<String>>{
        _registryKey: <String>[
          _registry(<Object?>[_game('yjj', '永劫无间')]),
        ],
        _configKey: <String>[
          _config(<Object?>[_entry('yjj', '/n/ds_category/1001/')], id: 'someone-else'),
        ],
      });
      await expectLater(cc.categories(), throwsA(isA<CcFailure>()));
    });

    test('test_aHiddenGroupIsAnEmptyMenuAndAHiddenEntryIsSkipped', () async {
      final (_, hidden) = _source(<String, List<String>>{
        _registryKey: <String>[
          _registry(<Object?>[_game('yjj', '永劫无间')]),
        ],
        _configKey: <String>[
          _config(<Object?>[_entry('yjj', '/n/ds_category/1001/')], hideGroup: true),
        ],
      });
      expect(await hidden.categories(), isEmpty);

      final (_, one) = _source(<String, List<String>>{
        _registryKey: <String>[
          _registry(<Object?>[_game('yjj', '永劫无间'), _game('mh', '梦幻西游')]),
        ],
        _configKey: <String>[
          _config(<Object?>[
            _entry('yjj', '/n/ds_category/1001/'),
            <String, Object?>{..._entry('mh', '/n/ds_category/1002/'), 'hidden': true},
          ]),
        ],
      });
      expect(await one.categories(), hasLength(1));
    });

    test('test_anOfficialEntryIsADestinationAndNotAListing', () async {
      final (transport, cc) = _source(<String, List<String>>{
        _registryKey: <String>[
          _registry(<Object?>[_game('ds', '官方入口')]),
        ],
        _configKey: <String>[
          _config(<Object?>[_entry('ds', '/13906009/')]),
        ],
      });
      await expectLater(
        cc.browse(const ContentQuery(category: 'official:13906009')),
        throwsA(
          isA<CcFailure>().having((CcFailure e) => e.message, 'message', contains('https://cc.163.com/13906009/')),
        ),
      );
      expect(transport.requestsTo(_gameKey), 0);
      expect(
        ccOfficialEntryUri('official:13906009').toString(),
        'https://cc.163.com/13906009/?open=blizzardtv&from=8382&platform=ds',
      );
      expect(ccOfficialEntryUri('official:../etc'), isNull);
      expect(ccOfficialEntryUri('1001'), isNull);
    });

    test('test_anEntryPointingOffTheSiteIsRefused', () async {
      final (_, cc) = _source(<String, List<String>>{
        _registryKey: <String>[
          _registry(<Object?>[_game('yjj', '永劫无间')]),
        ],
        _configKey: <String>[
          _config(<Object?>[
            <String, Object?>{'name': 'yjj', 'content': 'https://evil.example/n/ds_category/1001/'},
          ]),
        ],
      });
      await expectLater(cc.categories(), throwsA(isA<CcFailure>()));
    });
  });

  group('test_ccSource_listings', () {
    test('test_theGridPagesAtTheSitesOwnWidth', () async {
      final rows = <Object?>[
        for (var index = 0; index < ccNativePageSize; index++) _row(cuteid: '${13906009 + index}'),
      ];
      final (_, cc) = _source(<String, List<String>>{
        _gameKey: <String>[_listing('1001', rows)],
      });
      final page = await cc.browse(const ContentQuery(category: '1001', page: PageRequest(page: 1, pageSize: 50)));
      // The caller asked for 50 and the offsets are the site's 30; echoing 50 would resample on the next page.
      expect(page.pageSize, ccNativePageSize);
      expect(page.items, hasLength(ccNativePageSize));
      expect(page.hasMore, isTrue);
    });

    test('test_anAnswerLongerThanAskedIsNotAPage', () async {
      final rows = <Object?>[
        for (var index = 0; index < ccNativePageSize + 1; index++) _row(cuteid: '${13906009 + index}'),
      ];
      final (_, cc) = _source(<String, List<String>>{
        _gameKey: <String>[_listing('1001', rows)],
      });
      await expectLater(cc.browse(const ContentQuery(category: '1001')), throwsA(isA<CcFailure>()));
    });

    test('test_theAnswerMustBeAboutTheGameAsked', () async {
      final (_, cc) = _source(<String, List<String>>{
        _gameKey: <String>[
          _listing('2002', <Object?>[_row()]),
        ],
      });
      await expectLater(
        cc.browse(const ContentQuery(category: '1001')),
        throwsA(isA<CcFailure>().having((CcFailure e) => e.message, 'message', contains('about game 2002'))),
      );
    });

    test('test_aMalformedRowFailsThePageRatherThanLosingARoom', () async {
      final (_, cc) = _source(<String, List<String>>{
        _homeKey: <String>[
          jsonEncode(<String, Object?>{
            'lives': <Object?>[_row(), 'not-a-room'],
          }),
        ],
      });
      await expectLater(cc.feed(PageRequest.first), throwsA(isA<CcFailure>()));
    });

    test('test_theHeatAndTheHeadcountStayDifferentNumbers', () async {
      final (_, cc) = _source(<String, List<String>>{
        _homeKey: <String>[
          jsonEncode(<String, Object?>{
            'lives': <Object?>[_row()],
          }),
        ],
      });
      // Read through the source, so the wiring is pinned as well as the reader.
      final room = (await cc.feed(PageRequest.first)).items.single;
      expect(room.metadata.popularity, 20);
      final detail = ccListingRow(_row(), gameRow: false, assumeLive: true)!.toLiveRoom();
      expect(detail.audience?.onlineViewers, 20);
      expect(detail.audience?.popularity, 500000);
      // The number a surface shows first is the headcount, and the metric says it counts people.
      expect(detail.audiencePrimary, 20);
      expect(detail.audienceCountsPeople, isTrue);
    });

    test('test_aTitleSayingReplayIsTaggedWhileTheStatusStaysLive', () {
      final room = ccListingRow(_row(title: '【重播】昨天的比赛'), gameRow: true, assumeLive: false)!.toLiveRoom();
      expect(room.state, LiveRoomState.live);
      expect(room.tags, <String>['重播']);
      expect(room.extra['cc.replayTitle'], isTrue);
    });

    test('test_aStatusThatIsNeitherOneNorZeroIsTheSiteNotSaying', () {
      expect(
        ccListingRow(_row(status: 5), gameRow: true, assumeLive: false)!.toLiveRoom().state,
        LiveRoomState.unknown,
      );
      expect(ccListingRow(_row(status: 0), gameRow: true, assumeLive: false)!.toLiveRoom().state, LiveRoomState.ended);
      // A recommendation block carries no status field at all, and that block is a live grid by construction.
      expect(
        ccListingRow(_row(status: null), gameRow: false, assumeLive: true)!.toLiveRoom().state,
        LiveRoomState.live,
      );
    });

    test('test_startatIsTheSitesWallClockConvertedToUtc', () {
      final room = ccListingRow(_row(), gameRow: false, assumeLive: true)!.toLiveRoom();
      // 20:00 in the site's UTC+8 is 12:00 UTC; keeping the reading local makes "已直播 -3 小时".
      expect(room.startedAt, DateTime.utc(2026, 10, 11, 12));
      expect(ccStartedAt('2026-10-11 20:00:00'), DateTime.utc(2026, 10, 11, 12));
      expect(ccStartedAt('1999-01-01 00:00:00'), isNull);
      expect(ccStartedAt('昨天'), isNull);
    });
  });

  group('test_ccSource_room', () {
    test('test_theRoomIsTwoCallsAndKeepsTheIdTheCallerStored', () async {
      final (transport, cc) = _source(<String, List<String>>{
        _anchorKey: <String>[_anchor()],
        _channelKey: <String>[_channel(_channelRow(m3u8: _m3u8))],
      });
      final room = await cc.room(_room);
      expect(room.ref.contentId, '13906009');
      // The channel block calls itself 5001; that is the live channel, so it is a stream id and not the ref.
      expect(room.streamId, '5001');
      expect(room.anchorId, '777');
      expect(room.link, 'https://cc.163.com/13906009/');
      expect(room.followers, 1200);
      expect(room.introduction, '主播简介');
      expect(room.sitePayload['cc.m3u8'], _m3u8);
      expect(transport.requestsTo(_anchorKey), 1);
      expect(transport.requestsTo(_channelKey), 1);
    });

    test('test_anAnchorAnswerWithoutTheAskedRoomIsMissing', () async {
      final (_, cc) = _source(<String, List<String>>{
        _anchorKey: <String>[_anchor(broken: true)],
      });
      await expectLater(cc.room(_room), throwsA(predicate<CcFailure>((CcFailure error) => error.missing)));
    });

    test('test_tiersAreQualitiesAndCdnFamiliesAreLines', () async {
      final (_, cc) = _source(<String, List<String>>{
        _anchorKey: <String>[_anchor()],
        _channelKey: <String>[
          _channel(
            _channelRow(
              m3u8: _m3u8,
              quickplay: <String, Object?>{
                // The untouched tier ships no vbr; the site's own name is what keeps it on top.
                'blueray': <String, Object?>{
                  // `hs` is on the site's own preference table and `nimas` is not, so the suffix-derived
                  // address is line 1 even though the complete url was written first.
                  'CDN_FMT': <String, Object?>{'nimas': 'https://nimas.example/5001.m3u8', 'hs': '?sign=1'},
                },
                'high': <String, Object?>{
                  'vbr': 2000,
                  'CDN_FMT': <String, Object?>{'nimas': 'https://nimas.example/5001.m3u8', 'ks': '?sign=2'},
                },
              },
            ),
          ),
        ],
      });
      final qualities = await cc.qualities(_room);
      expect(qualities.map((option) => option.label), <String>['原画', '高清']);
      expect(qualities.first.rank!, greaterThan(qualities.last.rank!));
      // A line inside a tier is the site's own cdn family, preferred ones first; the ids stay ordinals because
      // the viewer needs to name a position, not learn the site's cdn spelling.
      expect(qualities.first.bitrateKbps, isNull);
      expect((await cc.lines(_room)).map((line) => line.id), <String>['1', '2']);
      final ticket = await cc.resolve(_room, line: const SelectionRef('2'));
      expect(ticket.uri.toString(), 'https://nimas.example/5001.m3u8');
    });

    test('test_aLiveBundleSuffixIsBuiltOntoTheRoomAddress', () async {
      final (_, cc) = _source(<String, List<String>>{
        _anchorKey: <String>[_anchor()],
        _channelKey: <String>[
          _channel(
            _channelRow(
              m3u8: _m3u8,
              quickplay: <String, Object?>{
                'high': <String, Object?>{
                  'CDN_FMT': <String, Object?>{'hs': '?sign=abc'},
                },
              },
            ),
          ),
        ],
      });
      final ticket = await cc.resolve(_room);
      // `?sign=abc` is not an address; it is a query that belongs on the room's own m3u8.
      expect(ticket.uri.toString(), 'https://live.ws.163.net/5001.m3u8?sign=abc');
      expect(ticket.protocol, MediaProtocol.hls);
    });

    test('test_anUnknownTierKeyKeepsItsOwnName', () async {
      final room = _channelRow(
        m3u8: _m3u8,
        quickplay: <String, Object?>{
          'quark': <String, Object?>{
            'vbr': 900,
            'CDN_FMT': <String, Object?>{'hs': '?sign=1'},
          },
        },
      );
      final qualities = ccQualities(room, baseUrl: _m3u8);
      expect(qualities.single.label, 'quark');
      // Unknown key ⇒ sorted by its stated bitrate alone.
      expect(qualities.single.sort, 900);
    });

    test('test_aLiveRoomWithNoTierAndNoAddressIsUnplayable', () async {
      final (_, cc) = _source(<String, List<String>>{
        _anchorKey: <String>[_anchor()],
        _channelKey: <String>[_channel(_channelRow())],
      });
      final room = await cc.room(_room);
      expect(room.state, LiveRoomState.live);
      expect(room.restriction, LiveRestriction.unplayable);
      expect(await cc.qualities(_room), isEmpty);
      await expectLater(
        cc.resolve(_room),
        throwsA(isA<StateError>().having((StateError e) => e.message, 'message', contains('no address'))),
      );
    });

    test('test_anOfflineRoomIsNamedAsOffline', () async {
      final (_, cc) = _source(<String, List<String>>{
        _anchorKey: <String>[_anchor()],
        _channelKey: <String>[_channel(_channelRow(status: 0, m3u8: _m3u8))],
      });
      final room = await cc.room(_room);
      expect(room.state, LiveRoomState.ended);
      expect(room.restriction, isNull, reason: 'an ended broadcast has no gate, it has nothing to open');
      expect(room.startedAt, isNull);
      await expectLater(cc.resolve(_room), throwsA(isA<StateError>()));
    });

    test('test_refreshKeepsTheTierAndTheLine', () async {
      final (transport, cc) = _source(<String, List<String>>{
        _anchorKey: <String>[_anchor()],
        _channelKey: <String>[
          _channel(
            _channelRow(
              m3u8: _m3u8,
              quickplay: <String, Object?>{
                'blueray': <String, Object?>{
                  'CDN_FMT': <String, Object?>{'hs': '?sign=1'},
                },
                'high': <String, Object?>{
                  'CDN_FMT': <String, Object?>{'hs': '?sign=2'},
                },
              },
            ),
          ),
        ],
      });
      final ticket = await cc.resolve(_room, quality: const SelectionRef('high'));
      expect(ticket.metadata.extra['cc.quality'], 'high');
      final again = await cc.refresh(ticket, RefreshReason.expiring);
      expect(again.metadata.extra['cc.line'], ticket.metadata.extra['cc.line']);
      expect(transport.requestsTo(_channelKey), 2);
    });

    test('test_aForeignTicketIsRefused', () async {
      final (_, cc) = _source(<String, List<String>>{
        _anchorKey: <String>[_anchor()],
      });
      final foreign = MediaTicket(
        id: 'elsewhere/1',
        uri: Uri.parse(_m3u8),
        kind: MediaKind.live,
        protocol: MediaProtocol.hls,
        createdAt: _now,
      );
      await expectLater(
        cc.refresh(foreign, RefreshReason.expiring),
        throwsA(isA<StateError>().having((StateError e) => e.message, 'message', contains('does not name a room'))),
      );
    });
  });

  group('test_ccSource_search', () {
    test('test_theSearchRowsAreCappedAndReadAsPeople', () async {
      final (transport, cc) = _source(<String, List<String>>{
        _searchKey: <String>[
          jsonEncode(<String, Object?>{
            'webcc_anchor': <String, Object?>{
              'result': <Object?>[_row(), _row(cuteid: '13906010', title: '【重播】昨天的比赛', status: 0)],
            },
          }),
        ],
      });
      final rooms = await cc.search(const SearchQuery(keyword: '主播', page: PageRequest(page: 1, pageSize: 200)));
      expect(rooms.items, hasLength(2));
      // The requested 200 is clamped to what the endpoint will serve.
      expect(Uri.splitQueryString(transport.requests.last.uri.query), <String, String>{
        'query': '主播',
        'size': '50',
        'page': '1',
      });
      final anchors = await cc.searchAnchors(const SearchQuery(keyword: '主播'));
      expect(anchors.items.first.name, '主播甲');
      expect(anchors.items.first.fans, 1200);
      expect(anchors.items.first.isLiveNow, isTrue);
      // The replay-tagged row is off air, so its anchor row links to nothing.
      expect(anchors.items.last.isLiveNow, isFalse);
    });

    test('test_aWatchPageUrlYieldsItsRoomAndOtherPathsDoNot', () {
      expect(ccRoomFromUri(Uri.parse('https://cc.163.com/13906009/')), '13906009');
      expect(ccRoomFromUri(Uri.parse('https://cc.163.com/n/ds_category/1001/')), isNull);
      expect(ccRoomFromUri(Uri.parse('https://cc.163.com/13906009/star')), isNull);
      expect(ccRoomFromUri(Uri.parse('https://ds.163.com/13906009')), isNull);
      expect(() => ccRoomId('013906009'), throwsA(isA<CcFailure>()));
    });
  });
}
