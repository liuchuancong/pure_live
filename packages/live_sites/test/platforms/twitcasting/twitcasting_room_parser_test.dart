import 'dart:convert';

import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/twitcasting/api/twitcasting_endpoints.dart';
import 'package:live_sites/src/platforms/twitcasting/danmaku/twitcasting_danmaku_codec.dart';
import 'package:live_sites/src/platforms/twitcasting/parsers/twitcasting_failure.dart';
import 'package:live_sites/src/platforms/twitcasting/parsers/twitcasting_json.dart';
import 'package:live_sites/src/platforms/twitcasting/parsers/twitcasting_room_parser.dart';
import 'package:test/test.dart';

const String _channel = 'ch1';
const int _movie = 123;
final DateTime _now = DateTime.utc(2026, 10, 1, 12);

String _tier(int movie, int node) =>
    'https://cdn$node.twitcasting.tv/tc.livehls/v1/streams/$movie/hls/$node.0/media.m3u8';

Map<String, Object?> _row([Map<String, Object?>? override]) => {
  'user_id': _channel,
  'id': _movie,
  'live_url': '/$_channel/movie/$_movie',
  'current_viewer_count': 40,
  'is_live': true,
  'is_locked': false,
  'is_group': false,
  'is_deleted': false,
  'telop': 'テロップ',
  'title': 'タイトル',
  'user_name': '名前',
  'user_icon_url': 'https://img.twitcasting.tv/a.jpg',
  'thumbnail_url': 'https://img.twitcasting.tv/t.jpg',
  'elapsed_time': 120,
  ...?override,
};

String _directory(List<Object?> rows) => jsonEncode({'movies': rows});

String _searchBody(List<String> rows, {bool section = true}) => [
  '<html><body>',
  if (section) '<div id="tw-search-result-live">' else '<div id="tw-search-result-user">',
  ...rows,
  '</div></body></html>',
].join();

/// One live search row of the shape the page writes.
String _searchRow({
  String channel = _channel,
  int movie = _movie,
  bool playable = true,
  bool liveBadge = true,
  bool privateBadge = false,
  String? status,
}) =>
    '''
<div class="tw-search-result-row">
  ${liveBadge ? '<span class="tw-movie-thumbnail2-badge" data-status="${status ?? 'live'}">LIVE</span>' : '<span class="tw-movie-thumbnail2-badge">アーカイブ</span>'}
  ${privateBadge ? '<span class="tw-movie-thumbnail2-badge">Private</span>' : ''}
  ${playable ? '<a class="tw-movie-thumbnail2-image-wrapper" data-can-play="true" href="/$channel/movie/$movie"></a>' : '<a class="tw-movie-thumbnail2-image-wrapper" data-can-play="false" href="/$channel/movie/$movie"></a>'}
  <a class="tw-movie-thumbnail2" href="/$channel/movie/$movie"><img class="tw-movie-thumbnail2-image" src="https://img.twitcasting.tv/cover.jpg"></a>
  <span class="tw-movie-thumbnail-title">タイトル</span>
  <div class="tw-search-result-row-user-name"><span class="usertext"><a href="/$channel"></a></span><span class="username">名前</span></div>
  <span class="userimage32"><img src="https://img.twitcasting.tv/avatar.jpg"></span>
  <time class="tw-movie-thumbnail-date" datetime="Sun, 27 Sep 2026 23:26:34 +0900"></time>
</div>''';

Object? _kindOf(void Function() answer) {
  try {
    answer();
    return null;
  } on TwitcastingFailure catch (failure) {
    return failure.kind;
  }
}

TwitcastingFailure _failure(void Function() answer) {
  try {
    answer();
  } on TwitcastingFailure catch (failure) {
    return failure;
  }
  throw StateError('the answer was accepted');
}

void main() {
  group('the status gate and the readers', () {
    test('one status, one kind', () {
      expect(_kindOf(() => TwitcastingJson.checkStatus(200, 'x')), isNull);
      expect(_kindOf(() => TwitcastingJson.checkStatus(401, 'x')), TwitcastingFailureKind.riskControl);
      expect(_kindOf(() => TwitcastingJson.checkStatus(403, 'x')), TwitcastingFailureKind.riskControl);
      expect(_kindOf(() => TwitcastingJson.checkStatus(404, 'x')), TwitcastingFailureKind.notFound);
      expect(_kindOf(() => TwitcastingJson.checkStatus(429, 'x')), TwitcastingFailureKind.rateLimited);
      expect(_kindOf(() => TwitcastingJson.checkStatus(500, 'x')), TwitcastingFailureKind.network);
      expect(_kindOf(() => TwitcastingJson.checkStatus(302, 'x')), TwitcastingFailureKind.network);
    });

    test('the readers', () {
      expect(TwitcastingJson.decode('{"a":1}', 'x'), {'a': 1});
      expect(_kindOf(() => TwitcastingJson.decode('nope', 'x')), TwitcastingFailureKind.apiChanged);
      expect(TwitcastingJson.object({'a': 1}, 'x'), {'a': 1});
      expect(
        _kindOf(() => TwitcastingJson.object({'a': 1, 2: 3}, 'x')),
        TwitcastingFailureKind.apiChanged,
        reason: 'a key that is not text is not an answer object',
      );
      expect(TwitcastingJson.text(' a '), 'a');
      expect(TwitcastingJson.text(7), isEmpty);
      expect(TwitcastingJson.integer('12'), 12);
      expect(TwitcastingJson.integer(12.5), isNull);
      expect(TwitcastingJson.segments(Uri.parse('/ch1/movie/123')), 'ch1/movie/123');
      expect(TwitcastingJson.picture('//img.twitcasting.tv/a.jpg'), 'https://img.twitcasting.tv/a.jpg');
      expect(TwitcastingJson.picture('ftp://img/a.jpg'), isEmpty);
    });

    test('a channel name, and the pages that look like one', () {
      expect(TwitcastingEndpoints.channelName(' Ch1 '), 'ch1');
      expect(TwitcastingEndpoints.channelName('c:ch1'), 'c:ch1');
      expect(TwitcastingEndpoints.channelName('ig:ch1'), 'ig:ch1');
      expect(TwitcastingEndpoints.channelName('search'), isNull, reason: 'a site page is not a channel');
      expect(TwitcastingEndpoints.channelName('ch-1'), isNull, reason: 'dashes are not in a channel name');
      expect(TwitcastingEndpoints.channelName('x' * 65), isNull);
      expect(
        TwitcastingEndpoints.playlistPath(_movie).hasMatch('/tc.livehls/v1/streams/$_movie/hls/3.0/media.m3u8'),
        isTrue,
      );
      expect(
        TwitcastingEndpoints.playlistPath(_movie).hasMatch('/tc.livehls/v1/streams/999/hls/3.0/media.m3u8'),
        isFalse,
      );
      expect(TwitcastingEndpoints.isSiteHost('cdn.twitcasting.tv'), isTrue);
      expect(TwitcastingEndpoints.isSiteHost('evil.tv'), isFalse);
    });
  });

  group('the home tabs', () {
    test('one area per tab, in page order', () {
      final body = [
        '<a class="tw-top-tab-item" data-channel="recommendation">あなたへ</a>',
        '<a class="tw-top-tab-item" data-channel="game">ゲーム</a>',
        '<a data-channel="no_class">タブでない</a>',
        '<span class="tw-top-tab-item" data-channel="not_an_a">タブでない</span>',
        '<a class="tw-top-tab-item" data-channel="game">重複</a>',
      ].join();
      final areas = TwitcastingRoomParser.areas(body);
      expect(areas.map((area) => area.areaId), ['recommendation', 'game']);
      expect(areas.first.areaName, 'あなたへ');
      expect(areas.first.parentAreaId, 'twitcasting');
      expect(areas.first.parentAreaName, 'TwitCasting');
      expect(_kindOf(() => TwitcastingRoomParser.areas('<html/>')), TwitcastingFailureKind.apiChanged);
      expect(_kindOf(() => TwitcastingRoomParser.areas('<a class="tw-top-tab-item" data-channel="ok">名前</a>')), isNull);
      expect(
        _failure(() => TwitcastingRoomParser.areas('<a class="tw-top-tab-item" data-channel="bad-name!">名前</a>'))
            .message,
        contains('tab "bad-name!"'),
      );
      expect(
        _failure(() => TwitcastingRoomParser.areas('<a class="tw-top-tab-item" data-channel="ok"></a>')).message,
        contains('tab "ok"'),
        reason: 'a tab without a label is refused, not dropped',
      );
      expect(_kindOf(() => TwitcastingRoomParser.areas('<html/>', status: 429)), TwitcastingFailureKind.rateLimited);
    });
  });

  group('the directory window', () {
    test('a row is the broadcast the site still shows', () {
      final rows = TwitcastingRoomParser.directoryRows(_directory([_row()]), now: _now);
      final room = rows.single!;
      expect(room.roomId, _channel);
      expect(room.content.title, 'テロップ', reason: 'the telop is the title a viewer reads');
      expect(room.content.coverUrl, 'https://img.twitcasting.tv/t.jpg');
      expect(room.anchor?.name, '名前');
      expect(room.anchor?.avatarUrl, 'https://img.twitcasting.tv/a.jpg');
      expect(room.audience.onlineViewers, 40);
      expect(room.audience.primaryMetric, LiveAudienceMetricType.onlineViewers);
      expect(room.broadcast.startedAt, _now.subtract(const Duration(seconds: 120)));
      expect(room.broadcast.restriction, LiveRestriction.none);
      expect(room.links.webUrl, 'https://twitcasting.tv/ch1');
      expect(
        TwitcastingRoomParser.directoryRows(
          _directory([
            _row({'telop': '', 'title': '  タイトル '}),
          ]),
        ).single!.content.title,
        'タイトル',
      );
      expect(
        TwitcastingRoomParser.directoryRows(
          _directory([
            _row({'is_locked': true}),
          ]),
        ).single!.broadcast.restriction,
        LiveRestriction.password,
      );
      expect(
        TwitcastingRoomParser.directoryRows(
          _directory([
            _row({'elapsed_time': null}),
          ]),
        ).single!.broadcast.startedAt,
        isNull,
      );
      expect(
        TwitcastingRoomParser.directoryRows(
          _directory([
            _row({'current_viewer_count': '7'}),
          ]),
        ).single!.audience.onlineViewers,
        7,
      );
    });

    test('ended, group and deleted rows are left out, malformed ones refused', () {
      List<LiveRoom?> read(List<Object?> rows) => TwitcastingRoomParser.directoryRows(_directory([_row(), ...rows]));
      expect(
        read([
          _row({'is_live': false}),
        ]),
        [isA<LiveRoom>(), null],
      );
      expect(
        read([
          _row({'is_group': true}),
        ]),
        [isA<LiveRoom>(), null],
      );
      expect(
        read([
          _row({'is_deleted': true}),
        ]),
        [isA<LiveRoom>(), null],
      );
      expect(
        read([
          _row({'is_live': 'true'}),
        ]),
        [isA<LiveRoom>(), null],
        reason: 'a flag that is not a boolean is a malformed row',
      );
      expect(read(['not a row']), [isA<LiveRoom>(), null]);
      expect(
        read([
          _row({'user_id': 'search'}),
        ]),
        [isA<LiveRoom>(), null],
        reason: 'a site page is not a channel',
      );
      expect(
        read([
          _row({'id': 0}),
        ]),
        [isA<LiveRoom>(), null],
      );
      expect(
        read([
          _row({'current_viewer_count': -1}),
        ]),
        [isA<LiveRoom>(), null],
      );
      expect(
        read([
          _row({'live_url': '/ch1/movie/999'}),
        ]),
        [isA<LiveRoom>(), null],
        reason: 'the link must name this row',
      );
      expect(
        read([
          _row({'live_url': 'https://twitcasting.tv/ch1/movie/123'}),
        ]),
        [isA<LiveRoom>(), null],
        reason: "an absolute link is not the site's own path",
      );
      expect(
        read([
          _row({'live_url': '/ch1/movie/123?x=1'}),
        ]),
        [isA<LiveRoom>(), null],
      );
      expect(
        read([
          _row({'live_url': null}),
        ]),
        [isA<LiveRoom>(), null],
      );
      expect(read(const []), hasLength(1));
      expect(
        _kindOf(
          () => TwitcastingRoomParser.directoryRows(
            _directory([
              _row({'is_live': 'true'}),
              _row({'id': -1}),
            ]),
          ),
        ),
        TwitcastingFailureKind.apiChanged,
        reason: 'a window whose every row is malformed is a changed answer',
      );
      expect(
        _kindOf(
          () => TwitcastingRoomParser.directoryRows(
            _directory([
              for (var i = 0; i < 61; i++) _row({'id': i + 1}),
            ]),
          ),
        ),
        TwitcastingFailureKind.apiChanged,
      );
      expect(_failure(() => TwitcastingRoomParser.directoryRows('{"movies":{}}')).message, contains('movies is'));
      expect(_kindOf(() => TwitcastingRoomParser.directoryRows('{}')), TwitcastingFailureKind.apiChanged);
      expect(_kindOf(() => TwitcastingRoomParser.directoryRows('not json')), TwitcastingFailureKind.apiChanged);
    });

    test('the page is sliced first, then the holes are dropped', () {
      final window = TwitcastingRoomParser.directoryRows(
        _directory([
          _row(),
          _row({'is_live': false}),
          _row({'user_id': 'ch2', 'id': 456, 'live_url': '/ch2/movie/456'}),
          _row({'user_id': 'ch3', 'id': 789, 'live_url': '/ch3/movie/789'}),
          _row({'user_id': 'ch2', 'id': 456, 'live_url': '/ch2/movie/456'}),
        ]),
      );
      expect(TwitcastingRoomParser.slice(window, offset: 0, pageSize: 2).map((room) => room.roomId), [
        _channel,
      ], reason: 'holes are dropped after slicing, so a page can hold fewer rooms than its size');
      expect(TwitcastingRoomParser.slice(window, offset: 2, pageSize: 2).map((room) => room.roomId), ['ch2', 'ch3']);
      expect(TwitcastingRoomParser.slice(window, offset: 4, pageSize: 2).map((room) => room.roomId), [
        'ch2',
      ], reason: 'a repeated channel on the page is shown once');
      expect(TwitcastingRoomParser.slice(window, offset: 9, pageSize: 2), isEmpty);
    });

    test('a start is the second, not the millisecond', () {
      expect(
        TwitcastingRoomParser.startedBefore(DateTime.utc(2026, 1, 1, 0, 0, 0, 500), 1),
        DateTime.utc(2025, 12, 31, 23, 59, 59),
        reason: 'the fraction of the request moment is dropped first',
      );
      expect(TwitcastingRoomParser.startedBefore(_now, 0), _now);
    });
  });

  group('the search page', () {
    test('the live section is what is read', () {
      expect(TwitcastingRoomParser.searchRows(_searchBody([_searchRow()])).single!.roomId, _channel);
      expect(
        _failure(() => TwitcastingRoomParser.searchRows(_searchBody(const [], section: false))).message,
        contains('no live section'),
      );
      expect(
        _kindOf(() => TwitcastingRoomParser.searchRows(_searchBody(const []))),
        isNull,
        reason: 'an empty section is no answer change',
      );
      expect(
        _kindOf(
          () => TwitcastingRoomParser.searchRows(_searchBody([for (var i = 0; i < 51; i++) _searchRow(movie: i + 1)])),
        ),
        TwitcastingFailureKind.apiChanged,
      );
      expect(
        _failure(
          () =>
              TwitcastingRoomParser.searchRows(_searchBody(['<div class="tw-search-result-row"><b>nothing</b></div>'])),
        ).message,
        contains('all 1 live rows malformed'),
      );
      expect(_kindOf(() => TwitcastingRoomParser.searchRows('<html/>', status: 404)), TwitcastingFailureKind.notFound);
    });

    test('badges decide whether the row is a room we can watch', () {
      LiveRoom? row(String body) => TwitcastingRoomParser.searchRows(_searchBody([_searchRow(), body])).last;
      expect(row(_searchRow())!.broadcast.restriction, LiveRestriction.none);
      expect(row(_searchRow(playable: false, privateBadge: true))!.broadcast.restriction, LiveRestriction.private);
      expect(row(_searchRow(playable: false))!.broadcast.restriction, LiveRestriction.unplayable);
      expect(
        row(_searchRow(playable: false))!.roomId,
        _channel,
        reason: 'a row we cannot play is still a room, just marked',
      );
      expect(row(_searchRow(liveBadge: false)), isNull, reason: 'playable without the LIVE badge is left out');
      expect(
        row(_searchRow(playable: false, liveBadge: false, privateBadge: true))!.broadcast.restriction,
        LiveRestriction.private,
      );
      final room = row(_searchRow())!;
      expect(room.content.title, 'タイトル');
      expect(room.content.coverUrl, 'https://img.twitcasting.tv/cover.jpg');
      expect(room.anchor?.name, '名前');
      expect(room.anchor?.avatarUrl, 'https://img.twitcasting.tv/avatar.jpg');
      expect(room.anchor?.liveStatus, LiveStatus.live);
      expect(room.audience.primaryMetric, LiveAudienceMetricType.unknown, reason: 'the page shows no figures here');
      expect(room.broadcast.startedAt, DateTime.utc(2026, 9, 27, 14, 26, 34));
      expect(room.links.webUrl, 'https://twitcasting.tv/ch1');
      expect(
        row(
          '<div class="tw-search-result-row"><a class="tw-movie-thumbnail2-image-wrapper" data-can-play="true"></a><span class="tw-movie-thumbnail2-badge" data-status="live">LIVE</span></div>',
        ),
        isNull,
        reason: 'a row whose links do not agree is malformed, and one malformed row does not fail the page',
      );
    });

    test('the two links must name the same channel', () {
      String rowWith(String movieHref, String channelHref) =>
          '''
<div class="tw-search-result-row">
  <span class="tw-movie-thumbnail2-badge" data-status="live">LIVE</span>
  <a class="tw-movie-thumbnail2-image-wrapper" data-can-play="true" href="$movieHref"><img class="tw-movie-thumbnail2-image" src="https://img.twitcasting.tv/cover.jpg"></a>
  <a class="tw-movie-thumbnail2" href="$movieHref">タイトル</a>
  <span class="tw-movie-thumbnail-title">タイトル</span>
  <div class="tw-search-result-row-user-name"><span class="usertext"><a href="$channelHref">名前</a></span><span class="username">名前</span></div>
  <span class="userimage32"><img src="https://img.twitcasting.tv/avatar.jpg"></span>
  <time class="tw-movie-thumbnail-date" datetime="Sun, 27 Sep 2026 23:26:34 +0900"></time>
</div>
''';
      expect(TwitcastingRoomParser.searchRows(_searchBody([rowWith('/ch1/movie/123', '/ch1')])).single!.roomId, 'ch1');
      for (final pair in [
        ['/ch1/movie/123', '/ch2'],
        ['/ch2/movie/123', '/ch1'],
        ['/ch1/movie/abc', '/ch1'],
        ['/ch1/movie/0', '/ch1'],
        ['/ch1/archive/123', '/ch1'],
        ['/ch1/movie/123/', '/ch1'],
        ['/ch1/movie/123', '/ch1/'],
        ['/ch1/movie/123?x=1', '/ch1'],
        ['//other/ch1/movie/123', '/ch1'],
      ]) {
        expect(
          _failure(() => TwitcastingRoomParser.searchRows(_searchBody([rowWith(pair[0], pair[1])]))).message,
          contains('all 1 live rows malformed'),
          reason: '${pair[0]} ${pair[1]}',
        );
      }
      expect(rowWith('/ch1/movie/123', '/ch1'), isNotEmpty);
      expect(
        TwitcastingRoomParser.searchRows(_searchBody([rowWith('/ch1/movie/123', '/CH1')])).single!.roomId,
        'ch1',
        reason: 'the channel is lower-cased',
      );
      expect(
        _kindOf(() => TwitcastingRoomParser.searchRows(_searchBody([rowWith('/ch1/movie/123', '/ch1?tab=1')]))),
        TwitcastingFailureKind.apiChanged,
        reason: 'a query on either link is refused, not just on the movie one',
      );
    });

    test('a page date is read with its own zone', () {
      expect(TwitcastingRoomParser.pageDate('Sun, 27 Sep 2026 23:26:34 +0900'), DateTime.utc(2026, 9, 27, 14, 26, 34));
      expect(TwitcastingRoomParser.pageDate('Sun, 27 Sep 2026 23:26:34 -0900'), DateTime.utc(2026, 9, 28, 8, 26, 34));
      expect(
        TwitcastingRoomParser.pageDate('  Sun, 27 Sep 2026 23:26:34 +0900  '),
        DateTime.utc(2026, 9, 27, 14, 26, 34),
      );
      expect(
        TwitcastingRoomParser.pageDate('Sun, 27 Sep 2026 23:26:34 +0960'),
        isNull,
        reason: 'sixty minutes is not an hour',
      );
      expect(TwitcastingRoomParser.pageDate('Sun, 31 Feb 2026 23:26:34 +0900'), isNull);
      expect(TwitcastingRoomParser.pageDate('Sun, 31 Sep 2026 23:26:34 +0900'), isNull);
      expect(TwitcastingRoomParser.pageDate('Sun, 00 Sep 2026 23:26:34 +0900'), isNull);
      expect(TwitcastingRoomParser.pageDate('Sun, 27 Dec 1969 23:26:34 +0900'), isNull);
      expect(TwitcastingRoomParser.pageDate('2026-09-27T23:26:34+09:00'), isNull, reason: 'the page writes RFC 1123');
      expect(TwitcastingRoomParser.pageDate(''), isNull);
    });
  });

  group('the channel page and streamserver', () {
    TwitcastingChannelPage pageOf(String body, {String channel = _channel, String? roomId, int status = 200}) =>
        TwitcastingRoomParser.channelPage(body, roomId: roomId ?? channel, channel: channel, status: status);
    const meta =
        '<meta name="twitter:creator" content="ch1"> '
        '<meta name="twitter:title" content="Live #タイトル"> '
        '<meta property="og:image" content="https://img.twitcasting.tv/og.jpg">';
    const header = '<div class="tw-user-header" data-user-id="ch1"></div>';

    test('a redirect is a channel that does not exist', () {
      expect(_failure(() => pageOf('<html/>', status: 302)).message, contains('HTTP 302 (sent home)'));
      expect(_kindOf(() => pageOf('<html/>', status: 302)), TwitcastingFailureKind.notFound);
      expect(_kindOf(() => pageOf('<html/>', status: 500)), TwitcastingFailureKind.network);
      expect(_failure(() => pageOf(meta + header, status: 404)).message, contains('HTTP 404'));
    });

    test('the secret-word page carries no names at all', () {
      final page = pageOf('<html><body>Enter the secret word to access this channel</body></html>');
      expect(page.secretWord, isTrue);
      expect(page.room.roomId, _channel);
      expect(page.room.anchor, isNull, reason: 'the page shows no name that could be checked');
      expect(page.room.content.title, isEmpty);
      expect(page.room.links.webUrl, 'https://twitcasting.tv/ch1');
      expect(page.movieId, isNull);
    });

    test('the page must be about the channel that was asked for', () {
      expect(_failure(() => pageOf('<html/>')).message, contains('twitter:creator []'));
      expect(
        _kindOf(
          () => pageOf('<meta name="twitter:creator" content="ch1"><meta name="twitter:creator" content="ch1">$header'),
        ),
        TwitcastingFailureKind.apiChanged,
        reason: 'two creator metas are not one answer',
      );
      expect(
        _kindOf(() => pageOf('<meta name="twitter:creator" content="other">$header')),
        TwitcastingFailureKind.apiChanged,
      );
      expect(
        _failure(() => pageOf('<meta name="twitter:creator" content="other">$header')).message,
        contains('twitter:creator [other]'),
      );
      expect(
        _kindOf(() => pageOf('<meta name="twitter:creator" content="ch1">')),
        TwitcastingFailureKind.apiChanged,
        reason: 'a page without the user header is not the channel page',
      );
      expect(
        _kindOf(
          () => pageOf(
            '<meta name="twitter:creator" content="ch1"><div class="tw-user-header" data-user-id="other"></div>',
          ),
        ),
        TwitcastingFailureKind.apiChanged,
      );
    });

    test('the telop is the title, the hashtags are not part of it', () {
      final page = pageOf(
        '$meta$header '
        '<span class="tw-player-page-title-description">テレ<span class="tag">#タグ</span>トップ</span> '
        '<span class="tw-user-nav2-name">名前</span> '
        '<span class="tw-user-nav2-icon"><img src="https://img.twitcasting.tv/avatar.jpg"></span> '
        '<span class="tw-player-duration-time" id="updatetimer" data-live-type="live" data-started-at="1760000000000"></span> '
        '<div data-movie-id="$_movie"></div>',
      );
      expect(page.room.content.title, 'テレトップ', reason: "the description text is the page's own, tags excluded");
      expect(page.room.content.coverUrl, 'https://img.twitcasting.tv/og.jpg');
      expect(page.room.anchor?.name, '名前');
      expect(page.room.anchor?.avatarUrl, 'https://img.twitcasting.tv/avatar.jpg');
      expect(page.movieId, _movie);
      expect(page.liveStartedAt, DateTime.fromMillisecondsSinceEpoch(1760000000000, isUtc: true));
      expect(page.secretWord, isFalse);
      final noTelop = pageOf(
        '$meta$header<span class="tw-player-page-title-description"><span class="tag">#タグ</span></span>',
      );
      expect(noTelop.room.content.title, 'Live #タイトル', reason: 'without a telop the page title is what 3.x showed');
      expect(noTelop.liveStartedAt, isNull, reason: 'no timer, no start');
      expect(noTelop.room.anchor?.name, _channel, reason: 'with no nav name the channel is the name');
      expect(
        pageOf('<meta name="twitter:creator" content="ch1"><meta name="twitter:title" content="  ">$header')
            .room
            .content
            .title,
        isEmpty,
      );
      expect(
        pageOf(
          '$meta$header<span class="tw-player-duration-time" id="updatetimer" data-live-type="archive" data-started-at="1760000000000"></span>',
        ).liveStartedAt,
        isNull,
        reason: 'a timer counting a recording is not a live start',
      );
    });

    test('streamserver says whether the channel is broadcasting', () {
      TwitcastingRoomData server(Object? content) => TwitcastingRoomParser.streamServer(jsonEncode(content));
      final live = server({
        'movie': {'live': true, 'id': _movie},
        'tc-hls': {
          'streams': {'high': _tier(_movie, 1), 'medium': _tier(_movie, 2), 'low': _tier(_movie, 3), 'other': 'x'},
        },
      });
      expect(live.live, isTrue);
      expect(live.movieId, _movie);
      expect(live.streams!.keys, ['high', 'medium', 'low'], reason: "only the three tiers, in the platform's order");
      expect(live.secretWord, isFalse);
      expect(
        server({
          'movie': {'live': false, 'id': _movie},
        }).streams,
        isEmpty,
        reason: 'an offline answer keeps no tiers',
      );
      expect(
        server({
          'movie': {'live': false},
        }).movieId,
        isNull,
      );
      expect(
        _failure(
          () => server({
            'movie': {'live': 'true'},
          }),
        ).message,
        contains('no movie.live'),
        reason: 'live must really be a boolean',
      );
      expect(_failure(() => server({})).message, contains('{} (no such channel)'));
      expect(_kindOf(() => server('{"movie":{}}')), TwitcastingFailureKind.apiChanged);
      expect(_kindOf(() => TwitcastingRoomParser.streamServer('{}')), TwitcastingFailureKind.notFound);
      expect(_kindOf(() => server('[]')), TwitcastingFailureKind.apiChanged);
      expect(
        _kindOf(
          () => server({
            'movie': {'live': true},
          }),
        ),
        isNull,
        reason: 'no tc-hls is a null streams map',
      );
      expect(
        server({
          'movie': {'live': true},
          'tc-hls': {'streams': 'x'},
        }).streams,
        isNull,
      );
      expect(_kindOf(() => TwitcastingRoomParser.streamServer('{}', status: 500)), TwitcastingFailureKind.network);
    });
  });

  group('the room, its qualities and its lines', () {
    final page = TwitcastingRoomParser.channelPage(
      '<meta name="twitter:creator" content="ch1"> '
      '<meta name="twitter:title" content="タイトル"> '
      '<div class="tw-user-header" data-user-id="ch1"></div> '
      '<span class="tw-player-duration-time" id="updatetimer" data-live-type="live" data-started-at="1760000000000"></span> '
      '<div data-movie-id="$_movie"></div>',
      roomId: _channel,
      channel: _channel,
    );
    TwitcastingRoomData data({
      bool live = true,
      int? movie = _movie,
      Map<String, String>? streams,
      bool secret = false,
    }) => TwitcastingRoomData(
      live: live,
      movieId: movie,
      streams: streams ?? {'high': _tier(_movie, 1)},
      secretWord: secret,
    );

    test('the stream answer decides the state', () {
      final offline = TwitcastingRoomParser.roomDetail(page, data(live: false));
      expect(offline.broadcast.liveStatus, LiveStatus.offline);
      expect(offline.anchor?.liveStatus, LiveStatus.offline);
      expect(offline.broadcast.startedAt, isNull, reason: 'offline has neither a start nor a restriction');
      expect(offline.broadcast.restriction, isNull);
      expect((offline.runtime.streamHandle! as TwitcastingRoomData).live, isFalse);
      expect(offline.runtime.danmakuHandle, isNull);
      final live = TwitcastingRoomParser.roomDetail(page, data());
      expect(live.broadcast.liveStatus, LiveStatus.live);
      expect(live.broadcast.startedAt, DateTime.fromMillisecondsSinceEpoch(1760000000000, isUtc: true));
      expect(live.broadcast.restriction, LiveRestriction.none);
      expect((live.runtime.streamHandle! as TwitcastingRoomData).streams, hasLength(1));
      expect((live.runtime.danmakuHandle! as TwitcastingDanmakuArgs).movieId, _movie);
      expect((live.runtime.danmakuHandle! as TwitcastingDanmakuArgs).channel, _channel);
      final secret = TwitcastingRoomParser.roomDetail(
        TwitcastingRoomParser.channelPage('Enter the secret word to access', roomId: _channel, channel: _channel),
        data(),
      );
      expect(secret.broadcast.restriction, LiveRestriction.password);
      expect(secret.broadcast.startedAt, isNull, reason: 'the protected page named no broadcast');
      final restarted = TwitcastingRoomParser.roomDetail(page, data(movie: 999, streams: {'high': _tier(999, 1)}));
      expect(restarted.broadcast.startedAt, isNull, reason: 'the channel went live again between the two requests');
      expect((restarted.runtime.danmakuHandle! as TwitcastingDanmakuArgs).movieId, 999);
      expect(TwitcastingRoomParser.roomDetail(page, data(movie: null)).runtime.danmakuHandle, isNull);
    });

    test('one quality per valid tier, best first', () {
      final qualities = TwitcastingRoomParser.qualities(
        data(streams: {'high': _tier(_movie, 1), 'medium': _tier(_movie, 2), 'low': _tier(_movie, 3)}),
      );
      expect(qualities.map((quality) => quality.qualityId), ['high', 'medium', 'low']);
      expect(qualities.map((quality) => quality.label), ['高清', '标清', '流畅']);
      expect(qualities.map((quality) => quality.platformOrder), [3, 2, 1]);
      expect(
        TwitcastingRoomParser.qualities(data(streams: {'low': _tier(_movie, 3)})).single.platformOrder,
        3,
        reason: 'the order counts the valid tiers, not the key',
      );
      expect(
        TwitcastingRoomParser.qualities(data(streams: {'medium': _tier(_movie, 2), 'high': _tier(_movie, 1)}))
            .map((quality) => quality.qualityId),
        ['high', 'medium'],
        reason: "the platform's order is kept whatever the answer's",
      );
      for (final url in [
        'http://cdn1.twitcasting.tv/tc.livehls/v1/streams/$_movie/hls/1.0/media.m3u8',
        'https://evil.tv/tc.livehls/v1/streams/$_movie/hls/1.0/media.m3u8',
        'https://u:p@cdn1.twitcasting.tv/tc.livehls/v1/streams/$_movie/hls/1.0/media.m3u8',
        'https://cdn1.twitcasting.tv:8443/tc.livehls/v1/streams/$_movie/hls/1.0/media.m3u8',
        'https://cdn1.twitcasting.tv/tc.livehls/v1/streams/999/hls/1.0/media.m3u8',
        'https://cdn1.twitcasting.tv/tc.livehls/v1/streams/$_movie/hls/1/media.m3u8',
        'https://cdn1.twitcasting.tv/tc.livehls/v1/streams/$_movie/hls/1.0/media.m3u8#f',
        'https://cdn1.twitcasting.tv/tc.livehls/v1/streams/$_movie/hls/1.0/other.m3u8',
      ]) {
        expect(
          _kindOf(() => TwitcastingRoomParser.qualities(data(streams: {'high': url}))),
          TwitcastingFailureKind.apiChanged,
          reason: url,
        );
      }
      expect(
        TwitcastingRoomParser.qualities(data(streams: {'high': _tier(_movie, 1), 'low': 'https://evil/x'}))
            .map((quality) => quality.qualityId),
        ['high'],
        reason: 'a bad tier is left out, the other still plays',
      );
      expect(
        _failure(() => TwitcastingRoomParser.qualities(data(streams: {'low': 'https://evil/x', 'high': 'nope'})))
            .message,
        contains('no valid tc-hls tier of movie'),
      );
      expect(_failure(() => TwitcastingRoomParser.qualities(data(live: false))).message, contains('not broadcasting'));
      expect(
        _failure(() => TwitcastingRoomParser.qualities(data(secret: true))).message,
        contains('password-protected'),
      );
      const noStreams = TwitcastingRoomData(live: true, movieId: _movie, streams: null);
      expect(_kindOf(() => TwitcastingRoomParser.qualities(noStreams)), TwitcastingFailureKind.apiChanged);
      expect(_kindOf(() => TwitcastingRoomParser.qualities(data(movie: null))), TwitcastingFailureKind.apiChanged);
      expect(_kindOf(() => TwitcastingRoomParser.qualities(data(movie: 0))), TwitcastingFailureKind.apiChanged);
      expect(_kindOf(() => TwitcastingRoomParser.qualities(data(streams: {}))), TwitcastingFailureKind.apiChanged);
    });

    test('the line of a tier is the playlist itself, with the media headers', () {
      final lines = TwitcastingRoomParser.lines(
        data(streams: {'high': _tier(_movie, 1), 'low': _tier(_movie, 3)}),
        'low',
      );
      expect(lines.single.url, _tier(_movie, 3));
      expect(lines.single.format, LiveStreamFormat.hls);
      expect(lines.single.headers.toMap(), TwitcastingEndpoints.headers);
      expect(lines.single.lineLabel, 'cdn3.twitcasting.tv', reason: 'the CDN node is the line identity of 3.x');
      expect(lines.single.lease, isNull, reason: 'the address carries no signature');
      expect(_failure(() => TwitcastingRoomParser.lines(data(), 'low')).message, contains('tier low is not offered'));
      expect(
        _kindOf(() => TwitcastingRoomParser.lines(data(live: false), 'high')),
        TwitcastingFailureKind.streamUnavailable,
      );
      expect(
        _failure(() => TwitcastingRoomParser.lines(data(streams: {'high': _tier(_movie, 1)}), 'auto')).message,
        contains('tier auto is not offered'),
      );
    });
  });
}
