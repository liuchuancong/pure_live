// Module: test/acfun/acfun_source_test.dart
// Purpose: The AcFun source against a canned transport: cursor directory, categories, envelope identity, the
// visitor session, the quality menu, the play ticket and the HTML anchor search.
// Author: liuchuancong
// Created: 2026-10-11
//
// The bodies below are written to the field names the v1 line reads, not recorded from the site - see the package
// README's 未验证 section. What these tests can prove is the reading and failure rules, not that the wire still
// looks like this.

import 'dart:convert';

import 'package:pure_live_network/pure_live_network.dart';
import 'package:pure_live_network/testing.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_sites/pure_live_sites.dart';
import 'package:test/test.dart';

const String _directoryKey = 'live.acfun.cn/api/channel/list';
const String _roomKey = 'live.acfun.cn/api/live/info';
const String _visitorKey = 'id.app.acfun.cn/rest/app/visitor/login';
const String _playKey = 'api.kuaishouzt.com/rest/zt/live/web/startPlay';
const String _searchKey = 'www.acfun.cn/search';

final DateTime _now = DateTime.fromMillisecondsSinceEpoch(1700000000000);

const ContentRef _room1001 = ContentRef(sourceId: 'acfun.live', contentId: '1001', kind: ContentKind.liveRoom);

NetworkClient _client(ScriptedTransport transport) => NetworkClient(
  adapter: transport,
  clock: () => _now,
  // One attempt per request: the failure paths are connection errors, which the production retry policy
  // legitimately re-attempts, and a source test wants one request per call or its counts mean nothing.
  settings: const NetworkSettings(retry: RetryPolicy(attempts: 1)),
);

(ScriptedTransport, AcfunSource) _source(Map<String, List<String>> script) {
  final transport = ScriptedTransport(script);
  return (transport, AcfunSource(client: _client(transport), clock: () => _now));
}

Map<String, Object?> _row({String authorId = '1001', String name = '主播甲', String title = '深夜分类'}) => <String, Object?>{
  'authorId': authorId,
  'title': title,
  'onlineCount': 42,
  'coverUrls': <Object?>['https://thumb.example/a.jpg'],
  'user': <String, Object?>{'id': authorId, 'name': name, 'headUrl': 'https://avatar.example/a.png'},
  'type': <String, Object?>{'name': '手游'},
  'liveId': '900001',
  'streamName': 'acflv01-8000000000-900001',
};

Map<String, Object?> _offlineRow(String authorId) => <String, Object?>{
  'authorId': authorId,
  'title': '没在播',
  'user': <String, Object?>{'id': authorId, 'name': '乙'},
};

String _directory({Object? cursor = '1', List<Object?> rooms = const <Object?>[], Object? filterGroups}) =>
    jsonEncode(<String, Object?>{
      'channelListData': <String, Object?>{'result': 0, 'pcursor': cursor, 'liveList': rooms},
      // The site's own nesting: channelFilters is an object whose liveChannelDisplayFilters field carries the
      // groups. Reading the list directly is what made a category browser come back empty and nobody notice.
      if (filterGroups != null) 'channelFilters': <String, Object?>{'liveChannelDisplayFilters': filterGroups},
    });

String _play({String? override}) =>
    override ??
    jsonEncode(<String, Object?>{
      'result': 1,
      'data': <String, Object?>{
        'liveId': '900001',
        'enterRoomAttach': 'attach-token',
        'availableTickets': <Object?>['ticket-1'],
        'videoPlayRes': <String, Object?>{
          'liveAdaptiveManifest': <Object?>[
            <String, Object?>{
              'adaptationSet': <String, Object?>{
                'representation': <Object?>[
                  <String, Object?>{
                    'name': '蓝光',
                    'qualityType': 'BLUE_RAY',
                    'level': 5,
                    'bitrate': 6000,
                    'url': 'https://acfun.example/blue.flv?s2=1',
                  },
                  <String, Object?>{
                    'name': '超清',
                    'qualityType': 'HIGH',
                    'level': 3,
                    'bitrate': 2000,
                    'url': 'https://acfun.example/high.flv?s2=1',
                  },
                  // A second cdn url for the same quality: this is what the line axis numbers.
                  <String, Object?>{'qualityType': 'HIGH', 'level': 3, 'url': 'https://acfun2.example/high.flv?s2=1'},
                  <String, Object?>{'qualityType': 'HIDDEN', 'hidden': true, 'url': 'https://acfun.example/x.flv'},
                  // No `level`, no `name`: an unknown-scale row that must still sort below the levelled ones.
                  <String, Object?>{'qualityType': 'ODD', 'bitrate': 999999, 'url': 'https://acfun3.example/odd.flv'},
                ],
              },
            },
          ],
        },
      },
    });

String _visitor({String? override}) =>
    override ??
    jsonEncode(<String, Object?>{
      'result': 0,
      'userId': '1001',
      'acfun.api.visitor_st': 'visitor-token',
      'acSecurity': 'sec',
    });

String _card(int index, {bool live = true, String hrefTo = ''}) {
  final authorId = '${1000 + index}';
  final meta = jsonEncode(<String, Object?>{'up_id': authorId, 'is_on_live': live});
  // The attribute holds json *text*; the parser entity-decodes the quotes, so the test must send them escaped.
  return '<div class="search-up" data-up-exposure-log="${meta.replaceAll('"', '&quot;')}">'
      '<img class="up__avatar" src="//avatar.example/$index.png">'
      '<div class="up__main__name"><a href="${hrefTo.isEmpty ? '/u/$authorId' : hrefTo}">主播 $index</a></div>'
      '<div class="up__main__intro">简介 $index</div>'
      '<div class="info__danmaku-count">1.2万粉丝</div>'
      '</div>';
}

String _search({int cards = 1, String total = '58', String? html}) => jsonEncode(<String, Object?>{
  'html':
      '<span class="total-num" data-total="$total"></span>'
      '<div class="result-list">${List<String>.generate(cards, (int index) => _card(index + 1)).join()}</div>'
      '${html ?? ''}',
});

void main() {
  group('test_acfunSource_directory', () {
    test('test_feed_pagesByCursorAndHandsBackTheNextOne', () async {
      final (transport, acfun) = _source(<String, List<String>>{
        _directoryKey: <String>[
          _directory(rooms: <Object?>[_row()], cursor: '2'),
        ],
      });
      final page = await acfun.feed(const PageRequest(pageSize: 30));
      expect(page.items, hasLength(1));
      expect(page.mode, PageMode.cursor);
      expect(page.nextCursor, '2');
      expect(page.hasMore, isTrue);
      expect(page.items.single.title, '深夜分类');
      expect(page.items.single.ref.contentId, '1001');
      expect(transport.unconsumedKeys, isEmpty);
    });

    test('test_noMoreEndsTheListRatherThanSpinning', () async {
      final (_, acfun) = _source(<String, List<String>>{
        _directoryKey: <String>[
          _directory(rooms: <Object?>[_row()], cursor: 'no_more'),
        ],
      });
      final page = await acfun.feed(PageRequest.first);
      expect(page.nextCursor, isNull);
      expect(page.hasMore, isFalse);
    });

    test('test_aPageNumberWithoutItsCursorIsRefused', () async {
      // Answering page 1 while the caller asked for page 4 is the silent version of the same bug.
      final (transport, acfun) = _source(<String, List<String>>{
        _directoryKey: <String>[_directory()],
      });
      await expectLater(acfun.feed(const PageRequest(page: 4)), throwsA(isA<AcfunApiFailure>()));
      expect(transport.requestsTo(_directoryKey), 0);
    });

    test('test_aDirectoryRowWithoutItsAuthorIsNotATile', () async {
      final (_, acfun) = _source(<String, List<String>>{
        _directoryKey: <String>[
          _directory(
            cursor: 'no_more',
            rooms: <Object?>[
              _row(authorId: '1001'),
              <String, Object?>{'title': '没有 id 的行'},
              _row(authorId: '1001'),
            ],
          ),
        ],
      });
      final page = await acfun.feed(PageRequest.first);
      // One row survives: the third is the same author the first listed.
      expect(page.items.map((item) => item.ref.contentId), <String>['1001']);
    });

    test('test_aCategoryBecomesTheSitesOwnFilterPair', () async {
      final transport = ScriptedTransport(<String, List<String>>{
        _directoryKey: <String>[_directory()],
      });
      final acfun = AcfunSource(client: _client(transport), clock: () => _now);
      await acfun.browse(const ContentQuery(category: 'liveChannelFilter/1/22'));
      expect(transport.requests.last.query['filters'], 'liveChannelFilter/1/22');
    });

    test('test_categories_comeFromTheFilterTableAndSkipTheAllRow', () async {
      final (_, acfun) = _source(<String, List<String>>{
        _directoryKey: <String>[
          _directory(
            cursor: 'no_more',
            filterGroups: <Object?>[
              <String, Object?>{
                'displayFilters': <Object?>[
                  <String, Object?>{'filterType': 1, 'filterId': 0, 'name': '全部'},
                  <String, Object?>{'filterType': 1, 'filterId': 22, 'name': '手游', 'cover': '//c/22.jpg'},
                  <String, Object?>{'filterType': 2, 'filterId': 22, 'name': '网游'},
                  <String, Object?>{'filterType': 1, 'filterId': 22, 'name': '重复'},
                ],
              },
            ],
          ),
        ],
      });
      final categories = await acfun.categories();
      expect(categories.map((category) => category.id), <String>['liveChannelFilter/1/22', 'liveChannelFilter/2/22']);
      expect(categories.first.name, '手游');
      expect(categories.first.icon, 'https://c/22.jpg');
    });

    test('test_aDirectoryWithoutItsCursorFieldIsASchemaChange', () async {
      final (_, acfun) = _source(<String, List<String>>{
        _directoryKey: <String>[
          jsonEncode(<String, Object?>{
            'channelListData': <String, Object?>{'result': 0},
          }),
        ],
      });
      await expectLater(acfun.feed(PageRequest.first), throwsA(isA<AcfunApiFailure>()));
    });
  });

  group('test_acfunSource_room', () {
    test('test_liveStatus_readsTheEnvelopeThatStatesIt', () async {
      final (_, acfun) = _source(<String, List<String>>{
        _roomKey: <String>[
          jsonEncode(<String, Object?>{'result': 0, ..._row()}),
        ],
      });
      final status = await acfun.liveStatus(_room1001);
      expect(status.state, LiveRoomState.live);
      expect(status.viewers, 42);
      expect(status.anchorName, '主播甲');
      expect(status.startedAt, isNull);
    });

    test('test_anOfflineEnvelopeIsEndedNotUnknown', () async {
      final (_, acfun) = _source(<String, List<String>>{
        _roomKey: <String>[
          jsonEncode(<String, Object?>{'result': 0, ..._offlineRow('1002')}),
        ],
      });
      final status = await acfun.liveStatus(
        const ContentRef(sourceId: 'acfun.live', contentId: '1002', kind: ContentKind.liveRoom),
      );
      expect(status.state, LiveRoomState.ended);
    });

    test('test_aLiveIdWithoutAStreamNameIsRefusedNotReadAsOffline', () async {
      final (_, acfun) = _source(<String, List<String>>{
        _roomKey: <String>[
          jsonEncode(<String, Object?>{
            'result': 0,
            'authorId': '1003',
            'liveId': '55',
            'user': <String, Object?>{'id': '1003', 'name': '丙'},
          }),
        ],
      });
      // Guessing "offline" here is what makes a follow list stop watching a room that is up.
      await expectLater(
        acfun.liveStatus(const ContentRef(sourceId: 'acfun.live', contentId: '1003', kind: ContentKind.liveRoom)),
        throwsA(isA<AcfunApiFailure>()),
      );
    });

    test('test_anEnvelopeAboutSomeoneElseIsRefused', () async {
      final (_, acfun) = _source(<String, List<String>>{
        _roomKey: <String>[
          jsonEncode(<String, Object?>{'result': 0, ..._row(authorId: '2002')}),
        ],
      });
      await expectLater(acfun.liveStatus(_room1001), throwsA(isA<AcfunApiFailure>()));
    });

    test('test_detail_carriesTheOnAirFactTheRowCouldNotState', () async {
      final (_, acfun) = _source(<String, List<String>>{
        _roomKey: <String>[
          jsonEncode(<String, Object?>{'result': 0, ..._row()}),
        ],
      });
      final detail = await acfun.detail(_room1001);
      expect(detail.metadata['isLive'], isTrue);
      expect(detail.summary.metadata.extra['avatar'], 'https://avatar.example/a.png');
    });

    test('test_anAuthorIdThatIsNotOneIsRefusedBeforeTheRequest', () async {
      final (transport, acfun) = _source(<String, List<String>>{
        _roomKey: <String>['{}'],
      });
      await expectLater(
        acfun.liveStatus(const ContentRef(sourceId: 'acfun.live', contentId: '../etc', kind: ContentKind.liveRoom)),
        throwsA(isA<AcfunApiFailure>()),
      );
      expect(transport.requestsTo(_roomKey), 0);
    });
  });

  group('test_acfunSource_play', () {
    test('test_resolve_logsInOnceAndOpensTheTopQuality', () async {
      final (transport, acfun) = _source(<String, List<String>>{
        _visitorKey: <String>[_visitor()],
        _playKey: <String>[_play()],
      });
      final ticket = await acfun.resolve(_room1001);
      expect(ticket.uri.path, '/blue.flv');
      expect(ticket.metadata.extra['container'], 'flv');
      expect(ticket.metadata.extra[acfunQualityKey], 'BLUE_RAY');
      expect(ticket.metadata.extra[acfunLiveIdKey], '900001');
      expect(ticket.metadata.extra[acfunLineKey], 1);
      // No expiry is stated by the answer, so none is invented.
      expect(ticket.expiresAt, isNull);
      expect(ticket.headers['referer'], 'https://live.acfun.cn/');
      expect(transport.requestsTo(_visitorKey), 1);
      final login = transport.requests.lastWhere((request) => request.hostKey == _visitorKey);
      expect(login.bodyText, contains('sid=acfun.api.visitor'));
    });

    test('test_theSessionIsReusedAcrossRoomsAndAskedOnce', () async {
      final (transport, acfun) = _source(<String, List<String>>{
        _visitorKey: <String>[_visitor()],
        _playKey: <String>[_play()],
      });
      for (final id in <String>['1001', '1002', '1003']) {
        await acfun.resolve(ContentRef(sourceId: acfunSourceId, contentId: id, kind: ContentKind.liveRoom));
      }
      expect(transport.requestsTo(_visitorKey), 1);
      expect(transport.requestsTo(_playKey), 3);
    });

    test('test_aRejectedPlayDropsTheSessionItRejected', () async {
      final (transport, acfun) = _source(<String, List<String>>{
        _visitorKey: <String>[_visitor()],
        _playKey: <String>[
          jsonEncode(<String, Object?>{'result': 2}),
          _play(),
        ],
      });
      await expectLater(acfun.resolve(_room1001), throwsA(isA<AcfunApiFailure>()));
      final retry = await acfun.resolve(_room1001);
      expect(retry.uri.path, '/blue.flv');
      // Two logins for two plays: the first session is what the endpoint said no to.
      expect(transport.requestsTo(_visitorKey), 2);
    });

    test('test_qualities_areOrderedByTheSitesOwnLevelNotTheBitrateNumber', () async {
      final (_, acfun) = _source(<String, List<String>>{
        _visitorKey: <String>[_visitor()],
        _playKey: <String>[_play()],
      });
      final options = await acfun.qualities(_room1001);
      expect(options.map((option) => option.id), <String>['BLUE_RAY', 'HIGH', 'ODD']);
      // The site's `level` is a different scale from `bitrate`; a row with a huge bitrate and no level still sorts
      // below every levelled row, which is what the mixed-scale band in the reader is for.
      expect(options.map((option) => option.rank), <int?>[1000005, 1000003, 999999]);
      expect(options.first.label, '蓝光');
      expect(options.first.isDefault, isTrue);
      expect(options[2].label, 'ODD', reason: 'a row with no name of its own is labelled by its id, not guessed');
    });

    test('test_lines_numberTheUrlsOfTheDefaultQualityOnly', () async {
      // A hidden representation is not offered, and the source names no cdn - so the labels stay null.
      final (_, acfun) = _source(<String, List<String>>{
        _visitorKey: <String>[_visitor()],
        _playKey: <String>[_play()],
      });
      final lines = await acfun.lines(_room1001);
      expect(lines.map((line) => line.id), <String>['1']);
      expect(lines.single.isDefault, isTrue);
      expect(lines.single.label, isNull);
    });

    test('test_aLineIsAnOrdinalAndAnythingElseIsRefused', () async {
      final (_, acfun) = _source(<String, List<String>>{
        _visitorKey: <String>[_visitor()],
        _playKey: <String>[_play()],
      });
      await expectLater(acfun.resolve(_room1001, line: const SelectionRef('线路3')), throwsA(isA<StateError>()));
    });

    test('test_aRefusedManifestIsNamedRatherThanAnEmptyTicket', () async {
      final (_, acfun) = _source(<String, List<String>>{
        _visitorKey: <String>[_visitor()],
        _playKey: <String>[
          jsonEncode(<String, Object?>{
            'result': 1,
            'data': <String, Object?>{'liveId': '9'},
          }),
        ],
      });
      await expectLater(acfun.resolve(_room1001), throwsA(isA<AcfunApiFailure>()));
    });

    test('test_refresh_staysOnTheSameQuality', () async {
      final (_, acfun) = _source(<String, List<String>>{
        _visitorKey: <String>[_visitor()],
        _playKey: <String>[_play()],
      });
      final first = await acfun.resolve(_room1001, quality: const SelectionRef('HIGH'));
      final second = await acfun.refresh(first, RefreshReason.expiring);
      expect(second.metadata.extra[acfunQualityKey], 'HIGH');
      expect(second.uri, first.uri);
    });

    test('test_refresh_aForeignTicketIsRefused', () async {
      final (_, acfun) = _source(<String, List<String>>{
        _visitorKey: <String>[_visitor()],
        _playKey: <String>[_play()],
      });
      final foreign = MediaTicket(
        id: 'huya.live/1',
        uri: Uri.parse('https://example/x.flv'),
        kind: MediaKind.live,
        protocol: MediaProtocol.hls,
        createdAt: _now.toUtc(),
      );
      await expectLater(acfun.refresh(foreign, RefreshReason.manual), throwsA(isA<StateError>()));
    });
  });

  group('test_acfunSource_search', () {
    test('test_search_readsTheCardsAndTheTotal', () async {
      final (_, acfun) = _source(<String, List<String>>{
        _searchKey: <String>[_search(cards: 2)],
      });
      final page = await acfun.search(const SearchQuery(keyword: '主播', page: PageRequest(page: 2)));
      expect(page.items, hasLength(2));
      expect(page.total, 58);
      // 58 results at the site's own 30 per page: page 2 is the last one, so the answer says so. A guessed true
      // here is what keeps a search results list spinning.
      expect(page.hasMore, isFalse);
      expect(page.pageSize, acfunSearchServerPageSize);
      expect(page.items.first.cover, 'https://avatar.example/1.png');
      expect(page.items.first.metadata.extra['isLive'], isTrue);
      expect(page.items.first.metadata.extra['followers'], '1.2万');
    });

    test('test_theFirstPageOfAFivePageAnswerSaysMoreFollows', () async {
      final (_, acfun) = _source(<String, List<String>>{
        _searchKey: <String>[_search(cards: 2)],
      });
      final page = await acfun.search(const SearchQuery(keyword: '主播'));
      expect(page.hasMore, isTrue);
      expect(page.total, 58);
    });

    test('test_searchAnchors_returnsPeopleWithTheirRoomWhenLive', () async {
      final (_, acfun) = _source(<String, List<String>>{
        _searchKey: <String>[_search()],
      });
      final page = await acfun.searchAnchors(const SearchQuery(keyword: '甲'));
      final anchor = page.items.single;
      expect(anchor.ref.kind, ContentKind.anchor);
      expect(anchor.currentRoom?.kind, ContentKind.liveRoom);
      expect(anchor.isLiveNow, isTrue);
      expect(anchor.extra['followers'], '1.2万');
    });

    test('test_aCardWhoseLinkNamesSomeoneElseIsNotARow', () async {
      final (_, acfun) = _source(<String, List<String>>{
        _searchKey: <String>[
          jsonEncode(<String, Object?>{
            'html': '<span class="total-num" data-total="1"></span>${_card(1, hrefTo: '/u/2002')}',
          }),
        ],
      });
      final page = await acfun.search(const SearchQuery(keyword: '甲'));
      expect(page.items, isEmpty);
    });

    test('test_anAnswerWithoutAResultTotalIsNotSilenceAboutNoResults', () async {
      final (_, acfun) = _source(<String, List<String>>{
        _searchKey: <String>[
          jsonEncode(<String, Object?>{'html': '<div class="result-list"></div>'}),
        ],
      });
      await expectLater(acfun.search(const SearchQuery(keyword: '甲')), throwsA(isA<AcfunApiFailure>()));
    });

    test('test_theWordedZeroTotalIsAnAnswer', () async {
      final (_, acfun) = _source(<String, List<String>>{
        _searchKey: <String>[
          jsonEncode(<String, Object?>{
            'html': '<span class="total-num" data-total="">共0条结果</span><div class="empty-page"></div>',
          }),
        ],
      });
      final page = await acfun.search(const SearchQuery(keyword: '不存在的人'));
      expect(page.total, 0);
      expect(page.items, isEmpty);
      expect(page.hasMore, isFalse);
    });

    test('test_anEmptyKeywordIsAnEmptyAnswerNotARequest', () async {
      final (transport, acfun) = _source(<String, List<String>>{
        _searchKey: <String>[_search()],
      });
      final page = await acfun.search(const SearchQuery(keyword: '   '));
      expect(page.items, isEmpty);
      expect(transport.requestsTo(_searchKey), 0);
    });
  });
}
