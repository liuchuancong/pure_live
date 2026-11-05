import 'dart:convert';

import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/enums/live_stream_codec.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/picarto/api/picarto_endpoints.dart';
import 'package:live_sites/src/platforms/picarto/parsers/picarto_failure.dart';
import 'package:live_sites/src/platforms/picarto/parsers/picarto_json.dart';
import 'package:live_sites/src/platforms/picarto/parsers/picarto_room_parser.dart';
import 'package:test/test.dart';

const String _name = 'TheBaker';
final Uri _master = Uri.parse('https://edge-1.picarto.tv/stream/hls/$_name/index.m3u8');

Map<String, Object?> _row([Map<String, Object?>? override]) => {
  'id': 7,
  'name': _name,
  'online': true,
  'adult': false,
  'private': false,
  'viewers': 30,
  'total_views': 900,
  'title': '在做饭',
  'image_thumbnail': 'https://cdn.picarto.tv/t.jpg',
  'avatar': 'https://cdn.picarto.tv/a.jpg',
  'categories': <Map<String, Object?>>[
    {'id': 3, 'name': 'IRL'},
  ],
  'followers_count': 1200,
  ...?override,
};

String _json(Map<String, Object?> root) => jsonEncode(root);

String _detail({Map<String, Object?>? channel, Object? streams, String? edge}) => jsonEncode({
  'channel': ?channel,
  'getMultiStreams': {'streams': ?streams},
  'getLoadBalancerUrl': {'origin': ?edge},
});

String _explore(List<Object?> rows, {int page = 1, int pageSize = 30, int? last, int? total}) =>
    jsonEncode({'data': rows, 'current_page': page, 'per_page': pageSize, 'last_page': ?last, 'total': ?total});

String _search(List<Object?> rows) => jsonEncode({
  'searchProfiles': {'data': rows, 'count': 99},
});

/// A playlist whose first line is `#EXTM3U` and whose rest is [entries].
String _playlist(List<String> entries) => ['#EXTM3U', ...entries].join('\n');

String _variant({
  int? height,
  int bandwidth = 3000000,
  String? fps,
  String? codecs = '"avc1.640028"',
  String? video,
  String? audio,
  String? uri,
}) =>
    '#EXT-X-STREAM-INF:BANDWIDTH=$bandwidth'
    '${height == null ? '' : ',RESOLUTION=1280x$height'}'
    '${fps == null ? '' : ',FRAME-RATE=$fps'}'
    '${codecs == null ? '' : ',CODECS=$codecs'}'
    '${video == null ? '' : ',VIDEO="$video"'}'
    '${audio == null ? '' : ',AUDIO="$audio"'}'
    '\n${uri ?? 'https://edge-1.picarto.tv/stream/hls/$_name/$height/index.m3u8'}';

Object? _kindOf(void Function() answer) {
  try {
    answer();
    return null;
  } on PicartoFailure catch (failure) {
    return failure.kind;
  }
}

PicartoFailure _failure(void Function() answer) {
  try {
    answer();
  } on PicartoFailure catch (failure) {
    return failure;
  }
  throw StateError('the answer was accepted');
}

void main() {
  group('the gates of an answer', () {
    test('one status, one kind', () {
      expect(_kindOf(() => PicartoJson.checkStatus(200, 'x')), isNull);
      expect(_kindOf(() => PicartoJson.checkStatus(401, 'x')), PicartoFailureKind.riskControl);
      expect(_kindOf(() => PicartoJson.checkStatus(403, 'x')), PicartoFailureKind.riskControl);
      expect(_kindOf(() => PicartoJson.checkStatus(404, 'x')), PicartoFailureKind.notFound);
      expect(_kindOf(() => PicartoJson.checkStatus(429, 'x')), PicartoFailureKind.rateLimited);
      expect(_kindOf(() => PicartoJson.checkStatus(500, 'x')), PicartoFailureKind.network);
      expect(_kindOf(() => PicartoJson.checkStatus(301, 'x')), PicartoFailureKind.network);
      expect(
        _kindOf(() => PicartoJson.checkBody('漢' * 400000, 'x', 200)),
        PicartoFailureKind.apiChanged,
        reason: 'the cap is counted in UTF-8 bytes',
      );
      expect(_kindOf(() => PicartoJson.checkBody('x' * 500000, 'x', 200)), isNull);
    });

    test('the readers', () {
      expect(PicartoJson.json('{"a":1}', 'x', 200), {'a': 1});
      expect(_kindOf(() => PicartoJson.json('nope', 'x', 200)), PicartoFailureKind.apiChanged);
      expect(_kindOf(() => PicartoJson.json('[]', 'x', 200)), PicartoFailureKind.apiChanged);
      expect(_failure(() => PicartoJson.json('[]', 'x', 200)).message, startsWith('x: expected an object'));
      expect(PicartoJson.integer('12'), 12);
      expect(PicartoJson.integer(12.0), 12);
      expect(PicartoJson.integer(12.5), isNull, reason: 'a fraction is not an id');
      expect(PicartoJson.integer(''), isNull);
      expect(PicartoJson.count(-1), isNull);
      expect(PicartoJson.count(0), 0);
      expect(PicartoJson.string(' a '), 'a');
      expect(PicartoJson.string('  '), isNull);
      expect(PicartoJson.string(null), isNull);
    });

    test('a channel is a name, a positive id and a boolean state', () {
      expect(PicartoEndpoints.isChannelName(_name), isTrue);
      expect(PicartoEndpoints.isChannelName('bad name'), isFalse);
      expect(PicartoEndpoints.isChannelName('explore'), isFalse, reason: 'a site path is never a channel');
    });
  });

  group('the catalog', () {
    test('the public directory leads the categories', () {
      final body = _json({
        'categories': [
          {'id': 3, 'label': 'IRL'},
          {'id': '4', 'label': ' Art '},
          {'id': 4, 'label': '重复的'},
          {'id': 0, 'label': '零'},
          {'id': -1, 'label': '负'},
          {'id': 5, 'label': ''},
          {'id': 6, 'label': 'x' * 101},
          {'label': '没有号'},
        ],
      });
      final areas = PicartoRoomParser.areas(body);
      expect(areas.map((area) => area.areaId), [PicartoEndpoints.publicDirectory.id, '3', '4']);
      expect(areas.first.areaName, PicartoEndpoints.publicDirectory.name);
      expect(areas[2].areaName, 'Art', reason: 'the label is trimmed, not rewritten');
      expect(areas.every((area) => area.parentAreaId == PicartoEndpoints.category.id), isTrue);
      expect(areas[2].parentAreaName, 'Picarto');
      expect(
        _kindOf(
          () => PicartoRoomParser.areas(
            _json({
              'categories': ['not a row'],
            }),
          ),
        ),
        PicartoFailureKind.apiChanged,
        reason: 'a row that is not an object is not a bad row, it is a changed answer',
      );
    });

    test('an answer with no usable category is a changed API, never an empty catalog', () {
      expect(_kindOf(() => PicartoRoomParser.areas('{}')), PicartoFailureKind.apiChanged);
      expect(_kindOf(() => PicartoRoomParser.areas('{"categories":[]}')), PicartoFailureKind.apiChanged);
      expect(_kindOf(() => PicartoRoomParser.areas('{"categories":{"a":1}}')), PicartoFailureKind.apiChanged);
      expect(
        _kindOf(
          () => PicartoRoomParser.areas(
            _json({
              'categories': [
                for (var i = 0; i < 201; i++) {'id': i + 1, 'label': 'c$i'},
              ],
            }),
          ),
        ),
        PicartoFailureKind.apiChanged,
      );
      expect(
        _kindOf(
          () => PicartoRoomParser.areas(
            _json({
              'categories': [
                {'id': 0},
              ],
            }),
          ),
        ),
        PicartoFailureKind.apiChanged,
      );
      expect(_failure(() => PicartoRoomParser.areas(_json({'categories': 'x'}))).message, contains('no category list'));
    });

    test('an area id names a category, or the directory, or nothing else', () {
      expect(PicartoRoomParser.categoryIdOf('live'), isNull);
      expect(PicartoRoomParser.categoryIdOf(' 12 '), 12);
      for (final id in ['0', '-1', '012', 'x', '', '1.5']) {
        expect(_failure(() => PicartoRoomParser.categoryIdOf(id)).kind, PicartoFailureKind.invalidArgument, reason: id);
        expect(_failure(() => PicartoRoomParser.categoryIdOf(id)).message, contains('is not a Picarto area'));
      }
    });
  });

  group('the explore directory', () {
    test('the page must be the page that was asked for', () {
      ({List<LiveRoom> rooms, bool hasMore}) of({
        int page = 1,
        int pageSize = 30,
        int? last,
        int? total,
        List<Object?>? rows,
      }) => PicartoRoomParser.directoryPage(
        _explore(rows ?? [_row()], page: page, pageSize: pageSize, last: last, total: total),
        page: page,
        pageSize: pageSize,
      );
      expect(of(page: 2, last: 4, total: 100).hasMore, isTrue);
      expect(of(page: 4, last: 4, total: 100).hasMore, isFalse, reason: 'the last page is the last page');
      expect(
        of(page: 5, last: 4, total: 100, rows: const <Object?>[]).hasMore,
        isFalse,
        reason: 'past the end is only allowed when nothing came back',
      );
      expect(
        _kindOf(
          () => PicartoRoomParser.directoryPage(
            _json({
              'data': [_row()],
              'current_page': 1,
              'per_page': 30,
              'total': 5,
            }),
            page: 1,
            pageSize: 30,
          ),
        ),
        PicartoFailureKind.apiChanged,
        reason: 'no last page',
      );
      expect(
        _kindOf(
          () => PicartoRoomParser.directoryPage(
            _json({
              'data': [_row()],
              'current_page': 1,
              'per_page': 30,
              'last_page': 2,
            }),
            page: 1,
            pageSize: 30,
          ),
        ),
        PicartoFailureKind.apiChanged,
        reason: 'no total',
      );
      expect(_kindOf(() => of(last: 0)), PicartoFailureKind.apiChanged);
      expect(_kindOf(() => of(total: -1)), PicartoFailureKind.apiChanged);
      expect(
        _kindOf(() => of(page: 2, last: 3)),
        PicartoFailureKind.apiChanged,
        reason: 'the answer is of another page',
      );
      expect(_kindOf(() => of(pageSize: 20, last: 3)), PicartoFailureKind.apiChanged, reason: 'another page size');
      expect(
        _kindOf(
          () => PicartoRoomParser.directoryPage(
            '{"data":{},"last_page":1,"total":1,"current_page":1,"per_page":30}',
            page: 1,
            pageSize: 30,
          ),
        ),
        PicartoFailureKind.apiChanged,
        reason: 'the rows are not a list',
      );
      expect(
        _kindOf(
          () => PicartoRoomParser.directoryPage(
            _explore(
              [
                _row(),
                _row({'id': 8, 'name': 'Other'}),
              ],
              pageSize: 1,
              last: 2,
              total: 9,
            ),
            page: 1,
            pageSize: 1,
          ),
        ),
        PicartoFailureKind.apiChanged,
        reason: 'more rows than the page asked for',
      );
    });

    test('adult and offline rows are filtered, not invented', () {
      final body = _explore(
        [
          _row(),
          _row({'adult': true}),
          _row({'online': false, 'id': 8, 'name': 'Offline'}),
          _row({'name': 'bad name!'}),
          _row({'id': 0, 'name': 'NoId'}),
          {'adult': false, 'online': true, 'name': 'NoState'},
          _row({'name': 'thebaker', 'id': 99}),
        ],
        last: 2,
        total: 40,
      );
      final page = PicartoRoomParser.directoryPage(body, page: 1, pageSize: 30);
      expect(page.rooms.map((room) => room.roomId), [
        _name,
      ], reason: 'the repeated name in another spelling is one room');
      expect(page.hasMore, isTrue);
      expect(
        PicartoRoomParser.directoryPage(_explore(const [], last: 1, total: 0), page: 1, pageSize: 30).rooms,
        isEmpty,
      );
      expect(
        PicartoRoomParser.directoryPage(
          _explore(
            [
              _row({'adult': true}),
              _row({'online': false}),
            ],
            last: 1,
            total: 2,
          ),
          page: 1,
          pageSize: 30,
        ).rooms,
        isEmpty,
        reason: 'adult and offline rows are filtered, and filtering is not a changed answer',
      );
      expect(
        _kindOf(
          () => PicartoRoomParser.directoryPage(
            _explore(
              [
                {'title': 'no channel'},
              ],
              last: 1,
              total: 1,
            ),
            page: 1,
            pageSize: 30,
          ),
        ),
        PicartoFailureKind.apiChanged,
        reason: 'a page whose every row is not a channel is a changed answer',
      );
    });

    test('a category filter is checked against the answer', () {
      String body() => _explore(
        [
          _row(),
          _row({
            'id': 8,
            'name': 'Other',
            'categories': <Map<String, Object?>>[
              {'id': 4},
            ],
          }),
          _row({'id': 9, 'name': 'NoCats', 'categories': null}),
        ],
        last: 1,
        total: 3,
      );
      final filtered = PicartoRoomParser.directoryPage(body(), page: 1, pageSize: 30, categoryId: 3);
      expect(filtered.rooms.map((room) => room.roomId), [_name]);
      expect(
        _kindOf(() => PicartoRoomParser.directoryPage(body(), page: 1, pageSize: 30, categoryId: 55)),
        PicartoFailureKind.apiChanged,
        reason: 'the filter was ignored',
      );
      expect(
        _failure(() => PicartoRoomParser.directoryPage(body(), page: 1, pageSize: 30, categoryId: 55)).message,
        contains('of category 55'),
      );
    });

    test("a card is the channel under the platform's own spelling", () {
      final room = PicartoRoomParser.directoryPage(
        _explore(
          [
            _row({'title': 'My Channel Title'}),
          ],
          last: 1,
          total: 1,
        ),
        page: 1,
        pageSize: 30,
      ).rooms.single;
      expect(room.roomId, _name);
      expect(room.content.title, isEmpty, reason: 'the placeholder title is no title');
      expect(room.content.platformTags, ['IRL'], reason: 'the categories ride along as tags');
      expect(room.anchor?.anchorId, '7');
      expect(room.anchor?.name, _name);
      expect(room.anchor?.avatarUrl, 'https://cdn.picarto.tv/a.jpg');
      expect(room.audience.onlineViewers, 30);
      expect(room.audience.totalViewers, 900);
      expect(room.audience.primaryMetric, LiveAudienceMetricType.onlineViewers);
      expect(room.broadcast.restriction, LiveRestriction.none);
      expect(room.links.webUrl, 'https://picarto.tv/$_name');
      expect(
        PicartoRoomParser.directoryPage(
          _explore(
            [
              _row({'private': true, 'viewers': null}),
            ],
            last: 1,
            total: 1,
          ),
          page: 1,
          pageSize: 30,
        ).rooms.single.broadcast.restriction,
        LiveRestriction.private,
      );
      expect(
        PicartoRoomParser.directoryPage(
          _explore(
            [
              _row({'private': null}),
            ],
            last: 1,
            total: 1,
          ),
          page: 1,
          pageSize: 30,
        ).rooms.single.broadcast.restriction,
        isNull,
      );
    });
  });

  group('the profile search', () {
    test('profiles are rooms without a stream, live or not', () {
      final rooms = PicartoRoomParser.searchRooms(
        _search([
          _row({'bio': '个人简介 &amp; 更多', 'follower_count': 1200}),
          _row({'id': 8, 'name': 'Offline', 'online': false, 'bio': '   '}),
          _row({'id': 9, 'name': _name.toLowerCase(), 'follower_count': 3}),
          _row({'id': 10, 'name': 'Bad', 'follower_count': -1}),
          {'id': 11, 'name': 'NoState'},
        ]),
        pageSize: 30,
      );
      expect(rooms.map((room) => room.roomId), [
        _name,
        'Offline',
      ], reason: 'a repeated name in another spelling is one profile');
      expect(rooms.first.content.title, _name, reason: 'a profile has no stream title');
      expect(rooms.first.content.introduction, '个人简介 & 更多', reason: 'the bio arrives as character references');
      expect(rooms[1].content.introduction, isNull, reason: 'a blank bio is no introduction');
      expect(rooms.first.broadcast.liveStatus, LiveStatus.live);
      expect(rooms[1].broadcast.liveStatus, LiveStatus.offline);
      expect(
        rooms.first.audience.primaryMetric,
        LiveAudienceMetricType.unknown,
        reason: 'a profile counts nobody watching',
      );
      expect(rooms.first.anchor?.followerCount, 1200);
      expect(_kindOf(() => PicartoRoomParser.searchRooms('{}', pageSize: 30)), PicartoFailureKind.apiChanged);
      expect(
        _kindOf(
          () => PicartoRoomParser.searchRooms(
            _json({
              'searchProfiles': {'data': <String, Object?>{}},
            }),
            pageSize: 30,
          ),
        ),
        PicartoFailureKind.apiChanged,
      );
      expect(
        _kindOf(
          () => PicartoRoomParser.searchRooms(
            _json({
              'searchProfiles': {
                'data': [
                  _row(),
                  _row({'id': 8, 'name': 'Other'}),
                ],
              },
            }),
            pageSize: 1,
          ),
        ),
        PicartoFailureKind.apiChanged,
      );
      expect(
        _kindOf(
          () => PicartoRoomParser.searchRooms(
            _search([
              {'id': 5},
            ]),
            pageSize: 30,
          ),
        ),
        PicartoFailureKind.apiChanged,
      );
      expect(PicartoRoomParser.searchRooms(_search(const []), pageSize: 30), isEmpty);
    });
  });

  group('channel/detail', () {
    test('the channel must be the one that was asked for', () {
      expect(
        _failure(() => PicartoRoomParser.roomDetail('{"channel":null}', requestedId: _name)).kind,
        PicartoFailureKind.notFound,
      );
      expect(
        _failure(() => PicartoRoomParser.roomDetail('{"channel":null}', requestedId: _name)).message,
        contains('no channel'),
      );
      expect(
        _kindOf(() => PicartoRoomParser.roomDetail(_json({'channel': 'x'}), requestedId: _name)),
        PicartoFailureKind.apiChanged,
      );
      expect(
        _failure(
          () => PicartoRoomParser.roomDetail(_detail(channel: _row({'name': 'SomeoneElse'})), requestedId: _name),
        ).message,
        contains('without a valid name'),
      );
      expect(
        _kindOf(() => PicartoRoomParser.roomDetail(_detail(channel: _row({'private': null})), requestedId: _name)),
        PicartoFailureKind.apiChanged,
        reason: 'a channel without the private flag says nothing about watching it',
      );
      expect(
        _kindOf(() => PicartoRoomParser.roomDetail(_detail(channel: _row({'online': 'true'})), requestedId: _name)),
        PicartoFailureKind.apiChanged,
      );
      final asked = PicartoRoomParser.roomDetail(_detail(channel: _row()), requestedId: ' thebaker ', stream: false);
      expect(asked.requestedId, 'thebaker');
      expect(asked.name, _name, reason: "the room id is the platform's own spelling");
      expect(asked.channelId, 7);
      expect(asked.master, isNull, reason: 'a state-only refresh does not look for a stream');
    });

    test('a live public channel needs an edge and exactly one own stream', () {
      PicartoChannel detail({
        Object? streams = const <Object?>[],
        String? edge = 'edge-1',
        bool stream = true,
        Map<String, Object?>? channel,
      }) => PicartoRoomParser.roomDetail(
        _detail(channel: channel ?? _row(), streams: streams, edge: edge),
        requestedId: _name,
        stream: stream,
      );
      final own = <Map<String, Object?>>[
        {'channelId': 7, 'stream_name': _name, 'thumbnail_image': 'https://cdn.picarto.tv/live.jpg'},
      ];
      expect(detail(streams: own).master, _master, reason: 'the balancer edge names the host');
      expect(
        detail(
          streams: [
            own.single,
            {'channelId': 8, 'stream_name': 'other'},
          ],
        ).master,
        _master,
        reason: "a multistream group lists the others too, and they are not this channel's",
      );
      expect(
        detail(streams: own).room.content.coverUrl,
        'https://cdn.picarto.tv/live.jpg',
        reason: 'the thumbnail of the stream itself is the cover',
      );
      expect(detail(streams: own).room.broadcast.restriction, LiveRestriction.none);
      expect(
        detail(streams: own, channel: _row({'private': true})).room.broadcast.restriction,
        LiveRestriction.private,
      );
      expect(
        detail(streams: own, channel: _row({'private': true})).master,
        isNull,
        reason: 'a private channel has no stream for us',
      );
      expect(
        detail(streams: own, channel: _row({'adult': true})).master,
        _master,
        reason: 'adult channels play without an account',
      );
      expect(detail(streams: own, channel: _row({'online': false})).master, isNull);
      for (final streams in [
        const <Object?>[],
        [own.single, own.single],
      ]) {
        expect(_failure(() => detail(streams: streams)).message, contains('streams of channel 7'), reason: '$streams');
      }
      expect(_kindOf(() => detail(streams: null)), PicartoFailureKind.apiChanged);
      expect(
        _kindOf(
          () => detail(
            streams: [
              for (var i = 0; i < 101; i++) {'channelId': 7, 'stream_name': 's$i'},
            ],
          ),
        ),
        PicartoFailureKind.apiChanged,
      );
      for (final edge in ['Edge-1', 'edge_1', 'a.b', '', 'x' * 64]) {
        expect(
          _failure(() => detail(streams: own, edge: edge)).message,
          contains('no load balancer edge'),
          reason: edge,
        );
      }
      expect(
        _kindOf(
          () => detail(
            streams: [
              {'channelId': 7, 'stream_name': 'bad name'},
            ],
          ),
        ),
        PicartoFailureKind.apiChanged,
      );
      expect(
        _failure(
          () => detail(
            streams: [
              {'channelId': 7, 'stream_name': 'a/b'},
            ],
          ),
        ).message,
        contains('bad stream name'),
      );
    });

    test('the detail adds the panels, the followers and the private flag', () {
      PicartoChannel of([Map<String, Object?>? override]) => PicartoRoomParser.roomDetail(
        _detail(channel: _row(override), streams: const <Object?>[], edge: 'edge-1'),
        requestedId: _name,
        stream: false,
      );
      final room = of({
        'descriptions': [
          {'body': '第一段 &amp; 继续'},
          {'body': '第二段'},
          {'no_body': 1},
        ],
      }).room.content;
      expect(room.introduction, '第一段 & 继续\n\n第二段', reason: 'the panels are joined by a blank line');
      expect(of().room.anchor?.followerCount, 1200);
      expect(
        of({'followers_count': null}).room.anchor,
        isNull,
        reason: 'a detail without a follower count carries no anchor',
      );
      expect(of({'followers_count': 'x'}).room.anchor, isNull);
      expect(of({'descriptions': null}).room.content.introduction, isNull);
      expect(of({'title': '  My Channel Title  '}).room.content.title, isEmpty);
      expect(of({'image_thumbnail': '//cdn.picarto.tv/t.jpg'}).room.content.coverUrl, 'https://cdn.picarto.tv/t.jpg');
      expect(of({'image_thumbnail': 'ftp://cdn/t.jpg'}).room.content.coverUrl, isEmpty);
      expect(of({'followers_count': 0}).room.anchor?.followerCount, 0);
    });

    test('when the broadcast on air started comes from the public API', () {
      DateTime? since([Map<String, Object?>? override]) => PicartoRoomParser.liveSince(
        _json({'name': _name, 'online': true, 'last_live': '2026-09-28 16:12:10', ...?override}),
        name: _name,
      );
      expect(since(), DateTime.utc(2026, 9, 28, 16, 12, 10));
      expect(since({'name': _name.toLowerCase()}), DateTime.utc(2026, 9, 28, 16, 12, 10));
      expect(since({'name': 'Someone'}), isNull, reason: 'an answer about another channel says nothing');
      expect(since({'online': false}), isNull, reason: 'offline, last_live is the previous broadcast');
      expect(since({'last_live': '2026-09-28T16:12:10'}), isNull, reason: 'the public API writes a space');
      expect(since({'last_live': '2026-02-30 16:12:10'}), isNull);
      expect(since({'last_live': '1969-01-01 00:00:00'}), isNull);
      expect(since({'last_live': null}), isNull);
      expect(_kindOf(() => PicartoRoomParser.liveSince('{}', name: _name, status: 404)), PicartoFailureKind.notFound);
      expect(
        PicartoRoomParser.liveSince(
          _json({'name': ' $_name ', 'online': true, 'last_live': '2026-09-28 16:12:10'}),
          name: ' thebaker ',
        ),
        DateTime.utc(2026, 9, 28, 16, 12, 10),
      );
    });
  });

  group('the master playlist', () {
    test('one quality per video profile, tallest first', () {
      final qualities = PicartoRoomParser.qualities(
        _playlist([
          _variant(height: 720, bandwidth: 2000000, fps: '30'),
          _variant(height: 1080, bandwidth: 5000000, fps: '59.94'),
          _variant(height: 1080, bandwidth: 6000000, fps: '59.94', uri: 'https://edge-2.picarto.tv/x.m3u8'),
          _variant(height: 360, bandwidth: 800000),
          _variant(bandwidth: 3500000, codecs: null),
        ]),
        master: _master,
      );
      expect(qualities.map((quality) => quality.quality.label), [
        '1080p 59.94fps',
        '720p 30fps',
        '360p',
        'HLS 3.5 Mbps',
      ]);
      expect(qualities.first.urls, [
        'https://edge-1.picarto.tv/stream/hls/$_name/1080/index.m3u8',
        'https://edge-2.picarto.tv/x.m3u8',
      ], reason: 'the same profile on two edges is one quality with both addresses');
      expect(qualities.first.height, 1080);
      expect(qualities.first.frameRate, 59.94);
      expect(qualities.first.bitrateKbps, 6000, reason: 'the profile keeps its highest bandwidth');
      expect(qualities.first.quality.platformOrder, 1080 * PicartoRoomParser.heightWeight + 6000000);
      expect(qualities[1].quality.platformOrder, 720 * PicartoRoomParser.heightWeight + 2000000);
      expect(qualities.last.height, 0, reason: 'a variant without a resolution has no height');
      expect(qualities.last.quality.codec, null, reason: 'no CODECS is declared');
      expect(qualities[2].quality.codec, LiveStreamCodec.avc);
      expect(PicartoRoomParser.autoQualityId, 'master');
      expect(
        qualities.map((entry) => entry.quality.qualityId).every((id) => id!.startsWith('[')),
        isTrue,
        reason: 'a quality id is the JSON of its profile',
      );
    });

    test('a playlist we cannot split is played as it is', () {
      List<PicartoQuality> read(String body) => PicartoRoomParser.qualities(body, master: _master);
      final audio = read(
        _playlist(['#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="a",NAME="a",URI="audio.m3u8"', _variant(height: 720)]),
      );
      expect(
        audio.single.quality.qualityId,
        PicartoRoomParser.autoQualityId,
        reason: 'a bare variant would play without sound',
      );
      expect(audio.single.quality.label, PicartoRoomParser.autoQualityName);
      expect(audio.single.urls, [_master.toString()]);
      final media = read('#EXTM3U\n#EXT-X-TARGETDURATION:4\n#EXTINF:4\nsegment.ts\n#EXT-X-ENDLIST');
      expect(
        media.single.quality.qualityId,
        PicartoRoomParser.autoQualityId,
        reason: 'a media playlist names no profiles',
      );
      expect(media.single.urls, [_master.toString()]);
    });

    test('what a playlist cannot be', () {
      List<PicartoQuality> read(String body, {int status = 200}) =>
          PicartoRoomParser.qualities(body, master: _master, status: status);
      expect(_failure(() => read('', status: 404)).kind, PicartoFailureKind.streamUnavailable);
      expect(_kindOf(() => read('', status: 500)), PicartoFailureKind.network);
      expect(_kindOf(() => read('nope')), PicartoFailureKind.apiChanged);
      expect(_kindOf(() => read('\n  #EXTM3U\n')), PicartoFailureKind.apiChanged);
      expect(
        _failure(() => read('#EXTM3U')).message,
        contains('no variant or media'),
        reason: 'the header may follow blanks',
      );
      expect(_kindOf(() => read('#EXTM3U#EXT-X-STREAM-INF:BANDWIDTH=1')), PicartoFailureKind.apiChanged);
      expect(
        _failure(() => read(_playlist(['#EXT-X-STREAM-INF:BANDWIDTH=1']))).message,
        contains('no variant or media'),
      );
      expect(
        _failure(() => read(_playlist(['#EXT-X-STREAM-INF:BANDWIDTH=1', '#EXT-X-STREAM-INF:BANDWIDTH=2', 'a.m3u8'])))
            .message,
        contains('a variant without a URL'),
      );
      for (final bad in [
        'BANDWIDTH=0',
        'BANDWIDTH=x',
        'RESOLUTION=1280x0',
        'RESOLUTION=abc',
        'FRAME-RATE=abc',
        'FRAME-RATE=-1',
        'FRAME-RATE=NaN',
      ]) {
        expect(
          _kindOf(() => read(_playlist(['#EXT-X-STREAM-INF:$bad\na.m3u8']))),
          PicartoFailureKind.apiChanged,
          reason: bad,
        );
        expect(
          _failure(() => read(_playlist(['#EXT-X-STREAM-INF:$bad\na.m3u8']))).message,
          contains('bad variant'),
          reason: bad,
        );
      }
      expect(
        _kindOf(() => read(_playlist(['#EXT-X-STREAM-INF:BANDWIDTH=1000\nfile:///etc/passwd']))),
        PicartoFailureKind.apiChanged,
      );
      expect(
        _kindOf(() => read(_playlist(['#EXT-X-STREAM-INF:BANDWIDTH=1000\nhttps://u:p@e.picarto.tv/a.m3u8']))),
        PicartoFailureKind.apiChanged,
      );
      expect(
        _failure(() => read(_playlist(['#EXT-X-STREAM-INF:BANDWIDTH=1000\nftp://e.picarto.tv/a.m3u8']))).message,
        contains('not a web URL'),
      );
    });

    test('the codec of a quality id, and the lines of a quality', () {
      expect(PicartoRoomParser.codecOfId(PicartoRoomParser.autoQualityId), isNull);
      expect(PicartoRoomParser.codecOfId('not json'), isNull);
      expect(PicartoRoomParser.codecOfId('[1,2]'), isNull);
      expect(PicartoRoomParser.codecOfId('["1280x720",30.0,"hvc1.1.6.L93.90",null,null]'), LiveStreamCodec.hevc);
      expect(PicartoRoomParser.codecOfId('["1280x720",30.0,"mp4a.40.2,avc3.1",null,null]'), LiveStreamCodec.avc);
      expect(PicartoRoomParser.codecOfId('["1280x720",30.0,"mp4a.40.2",null,null]'), isNull);
      final qualities = PicartoRoomParser.qualities(
        _playlist([_variant(height: 720, bandwidth: 2000000, fps: '59.94'), _variant(height: 360, bandwidth: 800000)]),
        master: _master,
      );
      final lines = PicartoRoomParser.lines(qualities.first, master: _master);
      expect(lines.single.url, 'https://edge-1.picarto.tv/stream/hls/$_name/720/index.m3u8');
      expect(lines.single.format, LiveStreamFormat.hls);
      expect(lines.single.lineLabel, 'edge-1.picarto.tv', reason: 'the edge host is the line name');
      expect(lines.single.lease, isNull, reason: 'the addresses carry no signature');
      expect(lines.single.headers.toMap(), PicartoEndpoints.headers);
      expect(lines.single.geometry.height, 720);
      expect(lines.single.geometry.frameRate, 60);
      expect(lines.single.geometry.bitrateKbps, 2000);
      expect(PicartoRoomParser.lines(qualities[1], master: _master).single.geometry.frameRate, isNull);
      expect(
        _failure(
          () => PicartoRoomParser.lines(
            PicartoQuality(
              quality: LivePlayQuality.of(label: 'x', qualityId: 'y'),
              urls: const <String>[],
            ),
            master: _master,
          ),
        ).message,
        contains('has no playlist'),
      );
    });
  });
}
