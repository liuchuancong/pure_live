// Module: test/kuaishou/kuaishou_source_test.dart
// Purpose: The Kuaishou source against a canned transport: the id-length endpoint choice, one-shot recommendations,
// the room page's embedded state, and the per-codec quality/line reading.
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

const String _homeKey = 'live.kuaishou.com/live_api/home/list';
const String _gameboardKey = 'live.kuaishou.com/live_api/gameboard/list';
const String _boardKey = 'live.kuaishou.com/live_api/non-gameboard/list';
const String _categoryKey = 'live.kuaishou.com/live_api/category/data';
const String _searchKey = 'live.kuaishou.com/live_api/search/author';
const String _pageKey = 'live.kuaishou.com/u/abc123';

final DateTime _now = DateTime.fromMillisecondsSinceEpoch(1700000000000);
const ContentRef _room = ContentRef(sourceId: 'kuaishou.live', contentId: 'abc123', kind: ContentKind.liveRoom);

const String _flvUrl = 'https://pull.kwaicdn.com/live/stream-1.flv?sign=abc123';
const String _hlsUrl = 'https://pull.kwaicdn.com/live/stream-1.m3u8?sign=abc123';

NetworkClient _client(ScriptedTransport transport) => NetworkClient(
  adapter: transport,
  clock: () => _now,
  settings: const NetworkSettings(retry: RetryPolicy(attempts: 1)),
);

(ScriptedTransport, KuaishouSource) _source(Map<String, List<String>> script, {String? cookie}) {
  final transport = ScriptedTransport(script);
  return (transport, KuaishouSource(client: _client(transport), cookie: cookie, clock: () => _now));
}

String _api(Map<String, Object?> data) => jsonEncode(<String, Object?>{'data': data});

Map<String, Object?> _representation({String name = '高清', int? level = 2, int? bitrate, String url = _flvUrl}) =>
    <String, Object?>{
      'name': name,
      if (level != null) 'level': level,
      if (bitrate != null) 'bitrate': bitrate,
      'url': url,
    };

Map<String, Object?> _adaptation(List<Object?> rows) => <String, Object?>{
  'adaptationSet': <String, Object?>{'representation': rows},
};

Map<String, Object?> _row({String author = 'abc123', String streamId = 'stream-1', Object? playUrls}) =>
    <String, Object?>{
      'id': streamId,
      'caption': '开播了',
      'poster': 'https://p.kwaicdn.com/cover/abc',
      'watchingCount': 100,
      'author': <String, Object?>{'id': author, 'name': '主播甲', 'avatar': 'https://p.kwaicdn.com/a.png'},
      'gameInfo': <String, Object?>{'name': '王者荣耀'},
      'playUrls': playUrls ?? _adaptation(<Object?>[_representation()]),
    };

Map<String, Object?> _card({String author = 'abc123', String description = '开播了\n第二行'}) => <String, Object?>{
  'id': 'stream-1',
  'watchingCount': 2200,
  'author': <String, Object?>{
    'id': author,
    'name': '主播甲',
    'avatar': 'https://p.kwaicdn.com/a.png',
    'description': description,
  },
  'gameInfo': <String, Object?>{'name': '王者荣耀', 'poster': 'https://p.kwaicdn.com/cover/abc.jpg'},
  'playUrls': _adaptation(<Object?>[_representation()]),
};

Map<String, Object?> _pageEntry({
  Object? isLiving = true,
  Object? playUrls,
  String authorId = 'abc123',
  String description = '开播了',
  String poster = 'https://p.kwaicdn.com/cover/abc',
}) => <String, Object?>{
  'isLiving': isLiving,
  'author': <String, Object?>{
    'id': authorId,
    'name': '主播甲',
    'avatar': 'https://p.kwaicdn.com/a.png',
    'description': description,
  },
  'gameInfo': <String, Object?>{'name': '王者荣耀', 'watchingCount': 1234},
  'liveStream': <String, Object?>{
    'id': 'stream-1',
    'poster': poster,
    'playUrls': playUrls ?? _adaptation(<Object?>[_representation()]),
  },
};

String _html(List<Object?> playList, {Map<String, Object?>? extra}) => _htmlOf(<String, Object?>{
  'liveroom': <String, Object?>{'playList': playList},
  if (extra != null) ...extra,
});

String _htmlOf(Map<String, Object?> state) =>
    '<html><body><script>window.__INITIAL_STATE__=${jsonEncode(state)};</script></body></html>';

void main() {
  group('test_kuaishouSource_listing', () {
    test('test_theRecommendationBlockIsOneShot', () async {
      final (transport, kuaishou) = _source(<String, List<String>>{
        _homeKey: <String>[
          _api(<String, Object?>{
            'list': <Object?>[
              <String, Object?>{
                'gameLiveInfo': <Object?>[
                  <String, Object?>{
                    'liveInfo': <Object?>[_card(), _card(author: 'def456'), _card()],
                  },
                ],
              },
            ],
          }),
        ],
      });
      final page = await kuaishou.feed(PageRequest.first);
      // The repeated card is one streamer; the second is a different room.
      expect(page.items.map((item) => item.ref.contentId), <String>['abc123', 'def456']);
      expect(page.mode, PageMode.singleShot);
      // The card has no title of its own: the author description, with the line break folded to one line.
      expect(page.items.first.title, '开播了 第二行');
      final second = await kuaishou.feed(const PageRequest(page: 2, pageSize: 20));
      expect(second.items, isEmpty);
      expect(transport.requestsTo(_homeKey), 1, reason: 'a second page must not rescan the same block');
    });

    test('test_theIdLengthPicksTheEndpointAndTheServerPageSizeWins', () async {
      final (transport, kuaishou) = _source(<String, List<String>>{
        _gameboardKey: <String>[
          _api(<String, Object?>{
            'list': <Object?>[_row()],
          }),
        ],
        _boardKey: <String>[
          _api(<String, Object?>{
            'list': <Object?>[_row(author: 'def456')],
          }),
        ],
      });
      final game = await kuaishou.browse(
        const ContentQuery(category: '1001', page: PageRequest(page: 1, pageSize: 50)),
      );
      final board = await kuaishou.browse(
        const ContentQuery(category: '622dbd0a1c92fa00063a5b3c', page: PageRequest(page: 1, pageSize: 50)),
      );
      expect(transport.requestsTo(_gameboardKey), 1);
      expect(transport.requestsTo(_boardKey), 1);
      expect(game.items.single.ref.contentId, 'abc123');
      expect(board.items.single.ref.contentId, 'def456');
      // The caller asked for 50 and got the site's 20. Echoing 50 would make its pager end the list early.
      expect(game.pageSize, kuaishouServerPageSize);
      expect(game.hasMore, isFalse);
    });

    test('test_aRowNamingNoStreamerIsDroppedNotFatal', () async {
      final (_, kuaishou) = _source(<String, List<String>>{
        _gameboardKey: <String>[
          _api(<String, Object?>{
            'list': <Object?>[
              _row(),
              <String, Object?>{'caption': '没有主播', 'author': <String, Object?>{}},
            ],
          }),
        ],
      });
      final page = await kuaishou.browse(const ContentQuery(category: '1001'));
      expect(page.items, hasLength(1));
    });

    test('test_aCategoryListingPagesUntilAShortPage', () async {
      final full = <Object?>[
        for (var index = 0; index < kuaishouCategoryPageSize; index++)
          <String, Object?>{'id': 'g$index', 'name': '分区$index'},
      ];
      final short = _api(<String, Object?>{
        'list': <Object?>[
          <String, Object?>{'id': 'g30', 'name': '分区30'},
          <String, Object?>{'id': '', 'name': '无id'},
        ],
      });
      final (transport, kuaishou) = _source(<String, List<String>>{
        // The canned transport answers a key's bodies in call order and then repeats the last one, so the first
        // group runs two full pages and stops on the short third; the other seven stop on their first short page.
        _categoryKey: <String>[
          _api(<String, Object?>{'list': full}),
          _api(<String, Object?>{'list': full}),
          short,
        ],
      });
      final categories = await kuaishou.categories();
      expect(categories.first.id, 'g0');
      expect(
        categories,
        hasLength(31),
        reason: 'the row without an id is not a category, and ids dedupe across groups',
      );
      expect(
        transport.requestsTo(_categoryKey),
        10,
        reason: 'three pages for the first group, one for each of the other seven',
      );
      expect(categories.first.parentId, '1');
      expect(categories.first.name, '分区0');
    });

    test('test_searchRowsCarryTheirOwnOnAirFlag', () {
      final body = jsonDecode(
        jsonEncode(<String, Object?>{
          'data': <String, Object?>{
            'list': <Object?>[
              <String, Object?>{
                'id': 'abc123',
                'name': '甲',
                'living': true,
                'counts': <String, Object?>{'fan': 900},
              },
              <String, Object?>{'id': 'def456', 'name': '乙'},
              <String, Object?>{
                'id': 'ghi789',
                'name': '丙',
                'bannedStatus': <String, Object?>{'banned': true},
              },
              <String, Object?>{'id': 'abc123', 'name': '甲 again'},
            ],
          },
        }),
      );
      final rooms = <LiveRoom>[for (final row in kuaishouAuthorRows(body)) row.toLiveRoom()];
      expect(rooms.map((room) => room.ref.contentId), <String>['abc123', 'def456', 'ghi789']);
      expect(rooms[0].state, LiveRoomState.live);
      // A row that does not carry `living` told us nothing, and that is unknown rather than ended.
      expect(rooms[1].state, LiveRoomState.unknown);
      // A banned account is refused by the site, which is a restriction, not an offline room.
      expect(rooms[2].state, LiveRoomState.ended);
      expect(rooms[2].restriction, LiveRestriction.unplayable);
      expect(rooms[2].extra['banned'], isTrue);
      // The search states no viewer count; a fabricated 0 would render as "0 人在看".
      expect(rooms[0].audience, isNull);
      expect(rooms[0].audiencePrimary, isNull);
      expect(rooms[0].followers, 900);
    });

    test('test_searchAndAnchorSearchReadTheSamePage', () async {
      final (transport, kuaishou) = _source(<String, List<String>>{
        _searchKey: <String>[
          jsonEncode(<String, Object?>{
            'data': <String, Object?>{
              'list': <Object?>[
                <String, Object?>{'id': 'abc123', 'name': '甲', 'living': true},
              ],
            },
          }),
        ],
      });
      final rooms = await kuaishou.search(const SearchQuery(keyword: '甲'));
      final anchors = await kuaishou.searchAnchors(const SearchQuery(keyword: '甲'));
      expect(rooms.items.single.ref.contentId, 'abc123');
      expect(anchors.items.single.name, '甲');
      // A live streamer is tappable: the anchor row carries the room it is in.
      expect(anchors.items.single.currentRoom?.contentId, 'abc123');
      expect(anchors.items.single.isLiveNow, isTrue);
      expect(transport.requestsTo(_searchKey), 2);
    });
  });

  group('test_kuaishouSource_room', () {
    test('test_thePageStateAndManifestBecomeRoomFields', () async {
      final (transport, kuaishou) = _source(<String, List<String>>{
        _pageKey: <String>[
          _html(<Object?>[_pageEntry()]),
        ],
      });
      final room = await kuaishou.room(_room);
      expect(room.state, LiveRoomState.live);
      expect(room.title, '开播了');
      expect(room.anchorName, '主播甲');
      expect(room.anchorId, isNull, reason: 'kuaishou keys the room on the streamer; the two are not distinct');
      expect(room.streamId, 'stream-1');
      expect(room.link, 'https://live.kuaishou.com/u/abc123');
      expect(room.audiencePrimary, 1234);
      expect(room.audienceMetric, LiveAudienceMetric.onlineViewers);
      // The page stores the poster without an extension; the image cdn only answers to one.
      expect(room.cover, 'https://p.kwaicdn.com/cover/abc.jpg');
      expect(room.restriction, LiveRestriction.none);
      expect(room.danmakuPayload['liveStreamId'], 'stream-1');
      expect(transport.requestsTo(_pageKey), 1, reason: 'one page read, no separate status or media endpoint');
    });

    test('test_aSemicolonInsideTheStateStillParses', () async {
      final (_, kuaishou) = _source(<String, List<String>>{
        _pageKey: <String>[
          _html(<Object?>[_pageEntry(description: '标题;带分号')]),
        ],
      });
      // v1's lazy `(.*?);` cut the literal at the semicolon inside the title and the room became unreadable.
      expect((await kuaishou.room(_room)).title, '标题;带分号');
    });

    test('test_aMissingFlagIsUnknownNotEnded', () async {
      final (_, kuaishou) = _source(<String, List<String>>{
        _pageKey: <String>[
          _html(<Object?>[_pageEntry(isLiving: '@sentinel@')]).replaceAll('"@sentinel@"', 'undefined'),
        ],
      });
      final room = await kuaishou.room(_room);
      expect(room.state, LiveRoomState.unknown);
      expect(room.audience, isNull);
    });

    test('test_anOfflinePageStatesNoAudienceAndCarriesNoRestriction', () async {
      final (_, kuaishou) = _source(<String, List<String>>{
        _pageKey: <String>[
          _html(<Object?>[_pageEntry(isLiving: false)]),
        ],
      });
      final room = await kuaishou.room(_room);
      expect(room.state, LiveRoomState.ended);
      expect(room.audience, isNull, reason: 'the page stopped counting; that is not a count of zero');
      expect(room.restriction, isNull);
    });

    test('test_aPageAboutAnotherStreamerIsRefused', () async {
      final (_, kuaishou) = _source(<String, List<String>>{
        _pageKey: <String>[
          _html(<Object?>[_pageEntry(authorId: 'someoneelse')]),
        ],
      });
      await expectLater(kuaishou.room(_room), throwsA(isA<KuaishouFailure>()));
    });

    test('test_theEmojiPanelTravelsWithTheHandshakeMaterial', () async {
      final (_, kuaishou) = _source(<String, List<String>>{
        _pageKey: <String>[
          _html(
            <Object?>[_pageEntry()],
            extra: <String, Object?>{
              'pcConfig': <String, Object?>{
                'pcConfig': <String, Object?>{
                  'config': <String, Object?>{
                    'pcLive.webConfig.emojiPanel': <String, Object?>{
                      '[笑]': 'https://p.kwaicdn.com/e.png',
                      'x': 'https://p.kwaicdn.com/too-short.png',
                      '[坏]': '/relative.png',
                    },
                  },
                },
              },
            },
          ),
        ],
      });
      final room = await kuaishou.room(_room);
      expect(room.danmakuPayload['emotes'], <String, String>{'[笑]': 'https://p.kwaicdn.com/e.png'});
    });

    test('test_aPageWithNoStateBlockIsAskedOnceAndNamed', () async {
      final (transport, kuaishou) = _source(<String, List<String>>{
        _pageKey: <String>['<html><body>机器人检查</body></html>'],
      });
      // No cookie came back with the canned answer, so there is nothing to retry with: one request, then the
      // refusal is reported as itself rather than turned into a retry loop.
      await expectLater(kuaishou.room(_room), throwsA(isA<KuaishouFailure>()));
      expect(transport.requestsTo(_pageKey), 1);
    });

    test('test_aConfiguredCookieGoesWithThePageRequest', () async {
      final (transport, kuaishou) = _source(<String, List<String>>{
        _pageKey: <String>[
          _html(<Object?>[_pageEntry()]),
        ],
      }, cookie: 'did=web_1');
      await kuaishou.room(_room);
      expect(transport.requests.last.header('cookie'), 'did=web_1');
    });

    test('test_liveStatusReadsThePageOnce', () async {
      final (transport, kuaishou) = _source(<String, List<String>>{
        _pageKey: <String>[
          _html(<Object?>[_pageEntry()]),
        ],
      });
      final status = await kuaishou.liveStatus(_room);
      expect(status.state, LiveRoomState.live);
      expect(status.viewers, 1234);
      expect(status.anchorName, '主播甲');
      expect(transport.requestsTo(_pageKey), 1);
    });
  });

  group('test_kuaishouSource_play', () {
    Map<String, Object?> both() => <String, Object?>{
      'h264': _adaptation(<Object?>[_representation(url: _flvUrl), _representation(url: _hlsUrl)]),
      'hevc': _adaptation(<Object?>[_representation(url: 'https://pull.kwaicdn.com/live/h.flv?sign=1')]),
    };

    test('test_theSameLabelInTwoCodecsStaysTwoChoices', () async {
      final (_, kuaishou) = _source(<String, List<String>>{
        _pageKey: <String>[
          _html(<Object?>[_pageEntry(playUrls: both())]),
        ],
      });
      final qualities = await kuaishou.qualities(_room);
      expect(qualities.map((option) => option.label), <String>['高清', '高清 · H.265']);
      expect(qualities.map((option) => option.codec), <String>['h264', 'hevc']);
      expect(qualities.first.rank, 2);
      // Two rows of one codec are cdn alternatives for the same encode: one quality, two lines.
      final lines = await kuaishou.lines(_room);
      expect(lines.map((line) => line.id), <String>['1', '2']);
    });

    test('test_aPresentButEmptyCodecKeyFallsToTheOtherName', () async {
      final (_, kuaishou) = _source(<String, List<String>>{
        _pageKey: <String>[
          _html(<Object?>[
            _pageEntry(
              playUrls: <String, Object?>{
                'h264': _adaptation(const <Object?>[]),
                'avc': _adaptation(<Object?>[_representation(name: '流畅', level: 1)]),
              },
            ),
          ]),
        ],
      });
      final qualities = await kuaishou.qualities(_room);
      expect(qualities.single.label, '流畅');
      expect(qualities.single.codec, 'h264');
    });

    test('test_aBitrateRowReportsItsBitrateAndALevelRowDoesNot', () async {
      final (_, kuaishou) = _source(<String, List<String>>{
        _pageKey: <String>[
          _html(<Object?>[
            _pageEntry(playUrls: _adaptation(<Object?>[_representation(name: '标清', level: null, bitrate: 800)])),
          ]),
        ],
      });
      final option = (await kuaishou.qualities(_room)).single;
      expect(option.bitrateKbps, 800);
      expect(option.rank, 800, reason: 'with no level stated the bitrate is the ordering weight');
    });

    test('test_resolveKeepsTheSignedQueryAndNamesTheProtocol', () async {
      final (_, kuaishou) = _source(<String, List<String>>{
        _pageKey: <String>[
          _html(<Object?>[_pageEntry(playUrls: both())]),
        ],
      });
      final ticket = await kuaishou.resolve(_room, line: const SelectionRef('2'));
      expect(ticket.uri.path, endsWith('.m3u8'));
      expect(ticket.protocol, MediaProtocol.hls);
      expect(ticket.uri.queryParameters['sign'], 'abc123');
      expect(ticket.metadata.extra['container'], 'm3u8');
      expect(ticket.headers['referer'], 'https://live.kuaishou.com/u/abc123');
    });

    test('test_anUnknownQualityFallsBackAndSaysSo', () async {
      final (_, kuaishou) = _source(<String, List<String>>{
        _pageKey: <String>[
          _html(<Object?>[_pageEntry()]),
        ],
      });
      final ticket = await kuaishou.resolve(_room, quality: const SelectionRef('4K'));
      expect(ticket.metadata.extra['kuaishou.requestedQuality'], '4K');
      expect(ticket.metadata.extra['kuaishou.quality'], '高清');
    });

    test('test_anUnknownLineIsRefusedRatherThanPlayedAsLineOne', () async {
      final (_, kuaishou) = _source(<String, List<String>>{
        _pageKey: <String>[
          _html(<Object?>[_pageEntry()]),
        ],
      });
      await expectLater(kuaishou.resolve(_room, line: const SelectionRef('3')), throwsA(isA<StateError>()));
    });

    test('test_anOfflineRoomIsNamedAsOffline', () async {
      final (_, kuaishou) = _source(<String, List<String>>{
        _pageKey: <String>[
          _html(<Object?>[_pageEntry(isLiving: false)]),
        ],
      });
      await expectLater(kuaishou.resolve(_room), throwsA(isA<StateError>()));
    });

    test('test_aLiveRoomWithNoAddressIsUnplayableNotOffline', () async {
      final (_, kuaishou) = _source(<String, List<String>>{
        _pageKey: <String>[
          _html(<Object?>[_pageEntry(playUrls: _adaptation(const <Object?>[]))]),
        ],
      });
      final room = await kuaishou.room(_room);
      expect(room.state, LiveRoomState.live);
      expect(room.restriction, LiveRestriction.unplayable);
      await expectLater(kuaishou.resolve(_room), throwsA(isA<StateError>()));
    });

    test('test_refreshReReadsThePageInsteadOfReusingTheDeadAddress', () async {
      final (transport, kuaishou) = _source(<String, List<String>>{
        _pageKey: <String>[
          _html(<Object?>[_pageEntry(playUrls: both())]),
        ],
      });
      final ticket = await kuaishou.resolve(_room, quality: const SelectionRef('高清 · H.265'));
      final again = await kuaishou.refresh(ticket, RefreshReason.expiring);
      expect(again.uri, ticket.uri);
      expect(again.metadata.extra['kuaishou.quality'], '高清 · H.265');
      expect(transport.requestsTo(_pageKey), 2);
    });

    test('test_aTicketFromAnotherSourceIsRefused', () async {
      final (_, kuaishou) = _source(<String, List<String>>{
        _pageKey: <String>[
          _html(<Object?>[_pageEntry()]),
        ],
      });
      final foreign = MediaTicket(
        id: 'elsewhere/1',
        uri: Uri.parse(_flvUrl),
        kind: MediaKind.live,
        protocol: MediaProtocol.https,
        createdAt: _now,
      );
      await expectLater(kuaishou.refresh(foreign, RefreshReason.expiring), throwsA(isA<StateError>()));
    });
  });

  group('test_kuaishouSource_readers', () {
    test('test_aPosterWithoutAnExtensionGetsOneAndAQueryCarryingOneDoesNot', () {
      expect(kuaishouPoster('https://p.kwaicdn.com/cover/abc'), 'https://p.kwaicdn.com/cover/abc.jpg');
      // v1 split the url on `.`, so this looked extensionless and got a second `.jpg` appended.
      expect(kuaishouPoster('https://p.kwaicdn.com/cover/abc.jpg?x=1.5'), 'https://p.kwaicdn.com/cover/abc.jpg?x=1.5');
      expect(kuaishouPoster('//p.kwaicdn.com/cover/abc.png'), 'https://p.kwaicdn.com/cover/abc.png');
      expect(kuaishouPoster(''), isNull);
    });

    test('test_theCookieHeaderKeepsTheLastWriteOfEachName', () {
      expect(
        kuaishouCookieHeader(<String>['did=web_1; Path=/; HttpOnly', 'did=web_2; Expires=Wed', 'kww=9']),
        'did=web_2; kww=9',
      );
      expect(kuaishouCookieHeader(<String>['novalue', '=x; y']), '');
    });

    test('test_aRoomUrlYieldsItsStreamerAndOtherPathsDoNot', () {
      expect(kuaishouRoomFromUri(Uri.parse('https://live.kuaishou.com/u/abc123?share=1')), 'abc123');
      expect(kuaishouRoomFromUri(Uri.parse('https://live.kuaishou.com/profile/abc123')), isNull);
      expect(kuaishouRoomFromUri(Uri.parse('https://live.kuaishou.com/u/not*valid')), isNull);
      expect(kuaishouRoomFromUri(Uri.parse('https://www.kuaishou.com/u/abc123')), isNull);
    });

    test('test_anAddressWithCredentialsOrNoSchemeIsNeverPlayed', () {
      expect(
        kuaishouQualities(<Object?>[
          _adaptation(<Object?>[_representation(url: 'https://a@p.example/x.flv')]),
        ]),
        isEmpty,
      );
      expect(
        kuaishouQualities(<Object?>[
          _adaptation(<Object?>[_representation(url: '//p.example/x.flv')]),
        ]),
        isEmpty,
      );
      final kept = kuaishouQualities(_adaptation(<Object?>[_representation(url: _flvUrl)]));
      expect(kept.single.urls, <String>[_flvUrl]);
    });

    test('test_theTelemetryBodyNamesTheDeviceAndNoInventedPage', () {
      final body = kuaishouTelemetry(did: 'web_1', now: _now, sessionId: 'sess-1');
      final common = (body['common']! as Map<String, Object?>)['identity_package']! as Map<String, Object?>;
      expect(common['device_id'], 'web_1');
      // v1 posted a fabricated 王者荣耀 page view; a log row claiming a visit nobody made is not sent here.
      expect((body['logs']! as List<Object?>).single, isNot(contains('url_package')));
      expect(() => kuaishouTelemetry(did: '', now: _now, sessionId: 's'), throwsA(isA<KuaishouFailure>()));
    });
  });
}
