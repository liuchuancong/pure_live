// Module: test/twitcasting/twitcasting_source_test.dart
// Purpose: The TwitCasting source against a canned transport: the channel whitelist, the bounded windows, the
// four directory flags, the two identity marks on the room page and the movie.live rule that gates every address.
// Author: liuchuancong
// Created: 2026-10-11
//
// Bodies are written to the field names and markup classes the v1 line reads, not recorded from the site
// (README 未验证).

import 'dart:convert';

import 'package:pure_live_network/pure_live_network.dart';
import 'package:pure_live_network/testing.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_sites/pure_live_sites.dart';
import 'package:test/test.dart';

const String _homeKey = 'twitcasting.tv/';
const String _directoryKey = 'frontendapi.twitcasting.tv/top/category';
const String _searchKey = 'search.twitcasting.tv/search/text/tokyo';
const String _emptySearchKey = 'search.twitcasting.tv/search/text/none';
const String _roomKey = 'twitcasting.tv/tokyo';
const String _streamKey = 'twitcasting.tv/streamserver.php';

final DateTime _now = DateTime.fromMillisecondsSinceEpoch(1700000000000);
const ContentRef _room = ContentRef(sourceId: 'twitcasting.live', contentId: 'tokyo', kind: ContentKind.liveRoom);
const int _movie = 1234567890;

String _mediaUrl(int movie, {String host = 'twitcasting.tv', String band = '1.1'}) =>
    'https://$host/tc.livehls/v1/streams/$movie/hls/$band/media.m3u8';

NetworkClient _client(ScriptedTransport transport) => NetworkClient(
  adapter: transport,
  clock: () => _now,
  settings: const NetworkSettings(retry: RetryPolicy(attempts: 1)),
);

(TwitcastingApi, ScriptedTransport) _api(Map<String, List<String>> script) {
  final transport = ScriptedTransport(script);
  return (TwitcastingApi(client: _client(transport)), transport);
}

TwitcastingSource _source(Map<String, List<String>> script) {
  final transport = ScriptedTransport(script);
  return TwitcastingSource(client: _client(transport), clock: () => _now);
}

String _roomPage({String channel = 'tokyo', String telop = '今日の配信', bool header = true}) =>
    '''<html><head>
<meta name="twitter:creator" content="$channel">
<meta name="twitter:title" content="TwitCasting title">
<meta property="og:image" content="//img.twitcasting.tv/og.jpg">
</head><body>
${header ? '<div class="tw-user-header" data-user-id="$channel">' : '<div class="tw-user-header">'}
<div class="tw-player-page-title-description">主播badge$telop</div>
<div class="tw-user-nav2-name">東京チャン</div>
<div class="tw-user-nav2-icon"><img src="//img.twitcasting.tv/icon.jpg"></div>
</body></html>''';

String _stream({bool live = true, int movieId = _movie, Map<String, Object?>? tiers, Object? idField}) =>
    jsonEncode(<String, Object?>{
      'movie': <String, Object?>{'live': live, 'id': idField ?? movieId},
      if (live)
        'tc-hls': <String, Object?>{
          'streams': tiers ?? <String, Object?>{'high': _mediaUrl(movieId)},
        },
    });

Map<String, Object?> _directoryRow({
  String channel = 'tokyo',
  int movie = _movie,
  bool live = true,
  bool locked = false,
  bool group = false,
  bool deleted = false,
  Object? viewers = '12',
  String telop = 'タイトル',
}) => <String, Object?>{
  'is_live': live,
  'is_locked': locked,
  'is_group': group,
  'is_deleted': deleted,
  'user_id': channel,
  'id': movie,
  'live_url': '/$channel/movie/$movie',
  'current_viewer_count': viewers,
  'telop': telop,
  'title': 'フォールバック',
  'user_name': '東京チャン',
  'thumbnail_url': '//img.twitcasting.tv/thumb.jpg',
  'user_icon_url': '//img.twitcasting.tv/icon.jpg',
};

String _directory(List<Map<String, Object?>> rows) => jsonEncode(<String, Object?>{'movies': rows});

String _searchRow({String channel = 'tokyo', int movie = _movie, bool playable = true, bool private = false}) =>
    '''<div class="tw-search-result-row">
<a class="tw-movie-thumbnail2" href="/$channel/movie/$movie">
  <span class="tw-movie-thumbnail2-badge" data-status="live">LIVE</span>
  ${playable ? '<span class="tw-movie-thumbnail2-image-wrapper" data-can-play="true">' : '<span class="tw-movie-thumbnail2-image-wrapper">'}
  <span class="tw-movie-thumbnail2-badge">${private ? 'Private' : 'ARCHIVE'}</span>
  <img class="tw-movie-thumbnail2-image" src="//img.twitcasting.tv/cover.jpg">
  <span class="tw-movie-thumbnail-title">検索タイトル</span>
</a>
<div class="tw-search-result-row-user-name"><span class="username">東京チャン</span>
<span class="usertext"><a href="/$channel">@tokyo</a></span></div>
<div class="userimage32"><img src="//img.twitcasting.tv/icon.jpg"></div>
</div>''';

String _searchPage(List<String> rows) =>
    '<html><body><div id="tw-search-result-live">${rows.join()}</div><div id="tw-search-result-user"></div></body></html>';

String _homePage(List<(String, String)> tabs) {
  final buffer = StringBuffer('<html><body>');
  for (final (String id, String name) in tabs) {
    buffer.write('<a class="tw-top-tab-item" data-channel="$id">$name</a>');
  }
  buffer.write('</body></html>');
  return buffer.toString();
}

void main() {
  group('test_twitcastingSource_readers', () {
    test('test_theChannelIsAWhitelistAndTheSiteSPageWordsAreNotChannels', () {
      expect(twitcastingChannelName('Tokyo_01'), 'tokyo_01');
      expect(twitcastingChannelName('g:club'), 'g:club');
      expect(() => twitcastingChannelName('search'), throwsA(isA<TwitcastingFailure>()));
      expect(() => twitcastingChannelName('bad-name'), throwsA(isA<TwitcastingFailure>()));
    });

    test('test_aChannelUrlIsARoomAndAMovieUrlIsNot', () {
      expect(twitcastingChannelFromUri(Uri.parse('https://twitcasting.tv/tokyo')), 'tokyo');
      expect(twitcastingChannelFromUri(Uri.parse('https://www.twitcasting.tv/tokyo/')), 'tokyo');
      // A movie link identifies one broadcast; substituting the channel's latest would file the wrong show.
      expect(twitcastingChannelFromUri(Uri.parse('https://twitcasting.tv/tokyo/movie/123')), isNull);
      expect(twitcastingChannelFromUri(Uri.parse('https://twitcasting.tv/search')), isNull);
      expect(twitcastingChannelFromUri(Uri.parse('https://example.com/tokyo')), isNull);
      expect(twitcastingChannelFromUri(Uri.parse('https://tokyo@twitcasting.tv/')), isNull);
    });

    test('test_theFourFlagsHaveToStayBooleans', () {
      expect(twitcastingDirectoryRows(jsonDecode(_directory(<Map<String, Object?>>[_directoryRow()]))), hasLength(1));
      // `0`/`1` instead of true/false is a changed endpoint; reading it loosely would keep every gated room.
      expect(
        () => twitcastingDirectoryRows(
          jsonDecode(
            _directory(<Map<String, Object?>>[
              <String, Object?>{..._directoryRow(), 'is_live': 1},
            ]),
          ),
        ),
        throwsA(isA<TwitcastingFailure>()),
      );
      final locked = twitcastingDirectoryRows(
        jsonDecode(_directory(<Map<String, Object?>>[_directoryRow(locked: true)])),
      );
      final deleted = twitcastingDirectoryRows(
        jsonDecode(_directory(<Map<String, Object?>>[_directoryRow(deleted: true)])),
      );
      expect(locked, isEmpty);
      expect(deleted, isEmpty);
    });

    test('test_aRowThatIsNotItsOwnBroadcastFailsThePage', () {
      expect(
        () => twitcastingDirectoryRows(
          jsonDecode(
            _directory(<Map<String, Object?>>[
              <String, Object?>{..._directoryRow(), 'live_url': '/tokyo/movie/777'},
            ]),
          ),
        ),
        throwsA(isA<TwitcastingFailure>()),
        reason: 'the url and the id have to name the same broadcast, whatever the row claims',
      );
      expect(
        () => twitcastingDirectoryRows(
          jsonDecode(
            _directory(<Map<String, Object?>>[
              <String, Object?>{..._directoryRow(), 'live_url': 'https://example.com/tokyo/movie/$_movie'},
            ]),
          ),
        ),
        throwsA(isA<TwitcastingFailure>()),
      );
      expect(
        () => twitcastingDirectoryRows(jsonDecode(_directory(<Map<String, Object?>>[_directoryRow(viewers: null)]))),
        throwsA(isA<TwitcastingFailure>()),
      );
      // An explicit zero is the site saying nobody is watching; that is not the same as saying nothing.
      final rows = twitcastingDirectoryRows(
        jsonDecode(_directory(<Map<String, Object?>>[_directoryRow(viewers: '0')])),
      );
      expect(rows.single.viewers, 0);
      // A listed row is affirmatively openable: the locked flag was the filter above.
      expect(rows.single.toRoom().toLiveRoom().restriction, LiveRestriction.none);
    });

    test('test_theSearchWindowCarriesNoAudienceFigure', () {
      final rows = twitcastingSearchRows(_searchPage(<String>[_searchRow()]));
      expect(rows.single.channel, 'tokyo');
      expect(rows.single.viewers, isNull);
      expect(rows.single.restriction, LiveRestriction.none);
      expect(
        twitcastingSearchRows(_searchPage(<String>[_searchRow(playable: false, private: true)])).single.restriction,
        LiveRestriction.private,
      );
      expect(
        twitcastingSearchRows(_searchPage(<String>[_searchRow(playable: false)])).single.restriction,
        LiveRestriction.unplayable,
      );
      expect(() => twitcastingSearchRows('<html></html>'), throwsA(isA<TwitcastingFailure>()));
    });

    test('test_aRowWithoutTheLiveBadgeIsNotALiveRoom', () {
      final rows = twitcastingSearchRows(
        _searchPage(<String>[
          '''<div class="tw-search-result-row">
<a class="tw-movie-thumbnail2" href="/tokyo/movie/$_movie">
  <span class="tw-movie-thumbnail2-badge" data-status="archive">ARCHIVE</span>
</a></div>''',
        ]),
      );
      expect(rows, isEmpty);
    });

    test('test_onlyTheSiteSOwnMediaPathOnItsOwnHostIsAnAddress', () {
      expect(
        twitcastingMediaUrl(_mediaUrl(_movie), movieId: _movie).path,
        '/tc.livehls/v1/streams/$_movie/hls/1.1/media.m3u8',
      );
      expect(
        twitcastingMediaUrl(_mediaUrl(_movie, host: 'media.twitcasting.tv'), movieId: _movie).host,
        'media.twitcasting.tv',
      );
      // A url for another broadcast is another show, not "probably the same one".
      expect(() => twitcastingMediaUrl(_mediaUrl(_movie + 1), movieId: _movie), throwsA(isA<TwitcastingFailure>()));
      expect(
        () => twitcastingMediaUrl(_mediaUrl(_movie, band: '1'), movieId: _movie),
        throwsA(isA<TwitcastingFailure>()),
      );
      expect(
        () => twitcastingMediaUrl(_mediaUrl(_movie).replaceFirst('https', 'http'), movieId: _movie),
        throwsA(isA<TwitcastingFailure>()),
      );
      expect(
        () => twitcastingMediaUrl(_mediaUrl(_movie, host: 'evil.com'), movieId: _movie),
        throwsA(isA<TwitcastingFailure>()),
      );
    });

    test('test_theTiersAreTheSiteSThreeAndNoOneElse', () {
      final tiers = twitcastingTiers(
        jsonDecode(
          jsonEncode(<String, Object?>{
            'low': _mediaUrl(_movie),
            'medium': _mediaUrl(_movie),
            'high': _mediaUrl(_movie),
            'ultra': _mediaUrl(_movie),
          }),
        ),
        movieId: _movie,
      );
      // `ultra` is not a row the site names in its player map, so it is not offered as a choice.
      expect(tiers.map((TwitcastingTier tier) => tier.name), <String>['high', 'medium', 'low']);
      expect(tiers.map((TwitcastingTier tier) => tier.label), <String>['HLS high', 'HLS medium', 'HLS low']);
      expect(tiers.first.rank, greaterThan(tiers.last.rank));
      // A band that is a plain string (the site has answered both shapes) is still read.
      expect(tiers.first.url.host, 'twitcasting.tv');
    });

    test('test_thePicturesAreOnlyKeptWhenTheyCanBeOpened', () {
      expect(twitcastingImage('//img.twitcasting.tv/a.jpg'), 'https://img.twitcasting.tv/a.jpg');
      expect(twitcastingImage('not a url'), '');
      expect(twitcastingImage(null), '');
    });
  });

  group('test_twitcastingSource_lists', () {
    test('test_theCategoryBarIsScrapedAndItsKeysAreSentBack', () async {
      final (api, transport) = _api(<String, List<String>>{
        _homeKey: <String>[
          _homePage(<(String, String)>[('game', 'ゲーム'), ('music', '音楽'), ('game', 'ゲーム')]),
        ],
      });
      final categories = await api.categories();
      expect(categories.map((TwitcastingCategory category) => category.id), <String>['game', 'music']);
      expect(transport.requestsTo(_homeKey), 1);
      expect(
        () => twitcastingCategories(_homePage(<(String, String)>[('bad key!', 'x')])),
        throwsA(isA<TwitcastingFailure>()),
      );
      expect(() => twitcastingCategories('<html></html>'), throwsA(isA<TwitcastingFailure>()));
    });

    test('test_theWindowPagesAreSlicesAndPastTheWindowIsSilence', () async {
      final rows = <Map<String, Object?>>[
        for (var index = 0; index < 6; index++) _directoryRow(channel: 'chan$index', movie: 100 + index),
      ];
      final (api, transport) = _api(<String, List<String>>{
        _directoryKey: <String>[_directory(rows)],
      });
      final second = await api.directory(page: 2, pageSize: 4);
      expect(second.map((TwitcastingCard card) => card.channel), <String>['chan4', 'chan5']);
      // Past the window no request is made: the site has no 16th page of 4 in a 60-row window to give.
      expect(await api.directory(page: 16, pageSize: 4), isEmpty);
      expect(transport.requestsTo(_directoryKey), 1);
      await expectLater(
        api.directory(page: 1, pageSize: twitcastingDirectoryWindow + 1),
        throwsA(isA<TwitcastingFailure>()),
      );
    });

    test('test_aCategoryKeyIsValidatedBeforeItIsSent', () async {
      final (api, transport) = _api(<String, List<String>>{
        _directoryKey: <String>[_directory(const <Map<String, Object?>>[])],
      });
      await expectLater(api.directory(category: '../etc'), throwsA(isA<TwitcastingFailure>()));
      expect(transport.requestsTo(_directoryKey), 0);
    });

    test('test_theSearchTermIsCheckedBeforeItIsSent', () async {
      final (api, transport) = _api(<String, List<String>>{
        _searchKey: <String>[
          _searchPage(<String>[_searchRow()]),
        ],
      });
      await expectLater(api.search(''), throwsA(isA<TwitcastingFailure>()));
      await expectLater(api.search('x' * 101), throwsA(isA<TwitcastingFailure>()));
      expect(await api.search('tokyo'), hasLength(1));
      expect(transport.requestsTo(_searchKey), 1);
    });
  });

  group('test_twitcastingSource_room', () {
    test('test_thePageIdentityHasToNameTheChannelAskedFor', () async {
      final (api, _) = _api(<String, List<String>>{
        _roomKey: <String>[_roomPage(channel: 'osaka')],
        _streamKey: <String>[_stream()],
      });
      await expectLater(api.room('tokyo'), throwsA(isA<TwitcastingFailure>()));

      final (mismatched, _) = _api(<String, List<String>>{
        _roomKey: <String>[_roomPage(header: false)],
        _streamKey: <String>[_stream()],
      });
      await expectLater(mismatched.room('tokyo'), throwsA(isA<TwitcastingFailure>()));
    });

    test('test_thePasswordPageIsAGateAndNotADescriptionOfTheShow', () async {
      final (api, transport) = _api(<String, List<String>>{
        _roomKey: <String>['<html>Enter the secret word to access this page</html>'],
      });
      final room = await api.room('tokyo');
      expect(room.passwordGate, isTrue);
      expect(room.restriction, LiveRestriction.private);
      expect(room.toLiveRoom().extra['twitcasting.passwordGate'], true);
      // The gate is decided from the page alone; the stream server is not asked for a room we cannot open.
      expect(transport.requestsTo(_streamKey), 0);
    });

    test('test_theTitleIgnoresTheBadgeWordsInsideTheTitleElement', () async {
      final (api, _) = _api(<String, List<String>>{
        _roomKey: <String>[_roomPage()],
        _streamKey: <String>[_stream(live: false)],
      });
      final room = await api.room('tokyo');
      expect(room.title, '主播badge今日の配信');
      expect(room.cover, 'https://img.twitcasting.tv/og.jpg');
      expect(room.nick, '東京チャン');
    });

    test('test_movieLiveIsTheOnlyAuthorityAndAnOfflineAnswerSAddressIsIgnored', () async {
      final (api, _) = _api(<String, List<String>>{
        _roomKey: <String>[_roomPage()],
        _streamKey: <String>[
          _stream(live: false, tiers: <String, Object?>{'high': _mediaUrl(_movie)}),
        ],
      });
      final room = await api.room('tokyo');
      expect(room.state, LiveRoomState.ended);
      expect(room.tiers, isEmpty);
      expect(room.reportedLive, isFalse);
      expect(room.toLiveRoom().reportedStateCode, 0);
    });

    test('test_anUnparseableLiveFlagIsAFailureAndNotAnOfflineRoom', () async {
      final (api, _) = _api(<String, List<String>>{
        _roomKey: <String>[_roomPage()],
        _streamKey: <String>[
          jsonEncode(<String, Object?>{
            'movie': <String, Object?>{'live': 'true', 'id': _movie},
          }),
        ],
      });
      await expectLater(api.room('tokyo'), throwsA(isA<TwitcastingFailure>()));
    });

    test('test_aLiveChannelWithNoTierIsUnplayableAndSaysSo', () async {
      final (api, _) = _api(<String, List<String>>{
        _roomKey: <String>[_roomPage()],
        _streamKey: <String>[
          jsonEncode(<String, Object?>{
            'movie': <String, Object?>{'live': true, 'id': _movie},
            'tc-hls': <String, Object?>{'streams': <String, Object?>{}},
          }),
        ],
      });
      final room = await api.room('tokyo');
      expect(room.state, LiveRoomState.live);
      expect(room.restriction, LiveRestriction.unplayable);
      expect(room.movieId, _movie);
    });

    test('test_aLiveAnswerWithNoBroadcastIdIsRefused', () async {
      final (api, _) = _api(<String, List<String>>{
        _roomKey: <String>[_roomPage()],
        _streamKey: <String>[
          jsonEncode(<String, Object?>{
            'movie': <String, Object?>{'live': true},
          }),
        ],
      });
      await expectLater(api.room('tokyo'), throwsA(isA<TwitcastingFailure>()));
    });

    test('test_theStatusReadIsTheStreamServerAlone', () async {
      final (api, transport) = _api(<String, List<String>>{
        _streamKey: <String>[_stream()],
      });
      final room = await api.status('tokyo');
      expect(room.state, LiveRoomState.live);
      expect(room.tiers, hasLength(1));
      expect(transport.requestsTo(_roomKey), 0);
      expect(room.toLiveRoom().streamId, '$_movie');
    });
  });

  group('test_twitcastingSource_capabilities', () {
    test('test_theTicketCarriesTheSiteSAddressAndItsOwnHeaders', () async {
      final source = _source(<String, List<String>>{
        _roomKey: <String>[_roomPage()],
        _streamKey: <String>[
          _stream(
            tiers: <String, Object?>{
              'high': _mediaUrl(_movie),
              'low': _mediaUrl(_movie, band: '2.2'),
            },
          ),
        ],
      });
      final ticket = await source.resolve(_room);
      expect(ticket.uri.toString(), _mediaUrl(_movie));
      expect(ticket.protocol, MediaProtocol.hls);
      expect(ticket.headers['referer'], '$twitcastingWebOrigin/');
      expect(ticket.metadata.extra['twitcasting.tier'], 'high');
      expect(ticket.metadata.extra['twitcasting.movieId'], _movie);
      final qualities = await source.qualities(_room);
      expect(qualities.map((StreamOption option) => option.id), <String>['high', 'low']);
      expect(qualities.first.isDefault, isTrue);
    });

    test('test_anAskedTierIsHonouredAndAGoneOneIsRecorded', () async {
      final source = _source(<String, List<String>>{
        _roomKey: <String>[_roomPage()],
        _streamKey: <String>[
          _stream(
            tiers: <String, Object?>{
              'high': _mediaUrl(_movie),
              'low': _mediaUrl(_movie, band: '2.2'),
            },
          ),
        ],
      });
      final asked = await source.resolve(_room, quality: const SelectionRef('LOW'));
      expect(asked.metadata.extra['twitcasting.tier'], 'low');
      expect(asked.metadata.extra.containsKey('twitcasting.requestedTier'), isFalse);
      final gone = await source.resolve(_room, quality: const SelectionRef('medium'));
      expect(gone.metadata.extra['twitcasting.tier'], 'high');
      expect(gone.metadata.extra['twitcasting.requestedTier'], 'medium');
    });

    test('test_thereIsNoLineAxisAndARefreshIsAFreshRead', () async {
      final source = _source(<String, List<String>>{
        _roomKey: <String>[_roomPage(), _roomPage()],
        _streamKey: <String>[_stream(), _stream()],
      });
      await expectLater(source.resolve(_room, line: const SelectionRef('2')), throwsA(isA<StateError>()));
      final ticket = await source.resolve(_room);
      final again = await source.refresh(ticket, RefreshReason.expiring);
      expect(again.uri, ticket.uri);
      expect(again.metadata.extra['twitcasting.tier'], 'high');
    });

    test('test_resolveRefusesAGatedRoomAndOneThatStopped', () async {
      final gated = _source(<String, List<String>>{
        _roomKey: <String>['<html>Enter the secret word to access</html>'],
      });
      await expectLater(gated.resolve(_room), throwsA(isA<StateError>()));
      final stopped = _source(<String, List<String>>{
        _roomKey: <String>[_roomPage()],
        _streamKey: <String>[_stream(live: false)],
      });
      await expectLater(stopped.resolve(_room), throwsA(isA<StateError>()));
      // A stream answer that never said whether the channel is live is not an offline room; it is the site
      // not answering, and resolve refuses instead of playing a maybe.
      final unknown = _source(<String, List<String>>{
        _roomKey: <String>[_roomPage()],
        _streamKey: <String>[
          jsonEncode(<String, Object?>{
            'movie': <String, Object?>{'id': _movie},
          }),
        ],
      });
      await expectLater(unknown.resolve(_room), throwsA(isA<TwitcastingFailure>()));
    });

    test('test_theFeedAndTheSearchAnswerWithWhatTheSiteFilled', () async {
      final source = _source(<String, List<String>>{
        _directoryKey: <String>[
          _directory(<Map<String, Object?>>[_directoryRow(), _directoryRow(channel: 'chan2', movie: 22)]),
        ],
        _searchKey: <String>[
          _searchPage(<String>[_searchRow()]),
        ],
        _emptySearchKey: <String>[_searchPage(const <String>[])],
        _roomKey: <String>[_roomPage(), _roomPage()],
        _streamKey: <String>[_stream(), _stream()],
      });
      final feed = await source.feed(const PageRequest(page: 1, pageSize: 2));
      expect(feed.items, hasLength(2));
      expect(feed.hasMore, isTrue);
      expect(feed.mode, PageMode.fixedPage);
      final byUrl = await source.search(const SearchQuery(keyword: 'https://twitcasting.tv/tokyo'));
      expect(byUrl.items, hasLength(1));
      final none = await source.search(const SearchQuery(keyword: 'none'));
      expect(none.items, isEmpty);
      final status = await source.liveStatus(_room);
      expect(status.state, LiveRoomState.live);
      // The room page states no audience, so the status read states none either - it is not zero.
      expect(status.viewers, isNull);
    });

    test('test_aRefFromAnotherSourceIsRefused', () async {
      final source = _source(<String, List<String>>{
        _streamKey: <String>[_stream()],
      });
      await expectLater(
        source.liveStatus(const ContentRef(sourceId: 'elsewhere', contentId: 'tokyo', kind: ContentKind.liveRoom)),
        throwsA(isA<TwitcastingFailure>()),
      );
      source.dispose();
    });
  });
}
