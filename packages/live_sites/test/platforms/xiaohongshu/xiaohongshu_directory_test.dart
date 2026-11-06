import 'dart:async';
import 'dart:convert';

import 'package:fpdart/fpdart.dart';
import 'package:live_net/live_net.dart';
import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/capabilities/live_discovery_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/xiaohongshu/api/xiaohongshu_endpoints.dart';
import 'package:live_sites/src/platforms/xiaohongshu/api/xiaohongshu_http.dart';
import 'package:live_sites/src/platforms/xiaohongshu/parsers/xiaohongshu_directory_parser.dart';
import 'package:live_sites/src/platforms/xiaohongshu/parsers/xiaohongshu_failure.dart';
import 'package:live_sites/src/platforms/xiaohongshu/xiaohongshu_guest.dart';
import 'package:live_sites/src/platforms/xiaohongshu/xiaohongshu_site.dart';
import 'package:test/test.dart';

// The private helpers spell their own class name in their constructors, as the
// package's value wrappers do.
// ignore_for_file: unnecessary_type_name_in_constructor

String _body(Object data) => jsonEncode({'code': 0, 'success': true, 'data': data});

Map<String, Object?> _row(String id, String cursor, {Object? online = 7, Object? total = 90}) => {
  'cursor_score': cursor,
  'type': 'live',
  'model_type': 'live_v2',
  'live': {
    't_room_info': {
      'room_id': 570000000000000000,
      'room_id_str': id,
      'name': 'Synthetic room',
      'cover': 'https://example.invalid/cover.webp',
      'member_count': ?online,
      'uv': ?total,
      'hot_value': 90000,
    },
    't_live_host_info': {
      'user_id': 'synthetic-host',
      'nickname': 'Test host',
      'avatar': 'https://example.invalid/avatar.jpg',
    },
  },
};

XiaohongshuFeedPage _feed(String body, {required String cursor}) =>
    XiaohongshuDirectoryParser.page(body, cursor: cursor);

T _right<T>(Either<LiveSiteError, T> either) => either.match((left) => throw StateError('$left'), (right) => right);

LiveSiteError _leftOf<T>(Either<LiveSiteError, T> either) =>
    either.match((left) => left, (right) => throw StateError('not a left: $either'));

/// The visitor bootstrap the tests drive: every directory call recorded,
/// answers canned, an optional in-flight hold, an optional refusal.
final class _Guest implements XiaohongshuGuest {
  final calls = <({String category, String cursor, CancelToken? cancel})>[];

  /// When set, every feed answer is a refusal envelope.
  bool refused = false;

  Completer<String>? pending;

  @override
  Future<String> categories({CancelToken? cancel}) async => _body({
    'categories': [
      {'id': 0, 'desc': '全部'},
      {'id': 1, 'desc': '游戏'},
    ],
  });

  @override
  Future<String> directory({required String category, required String cursor, CancelToken? cancel}) async {
    calls.add((category: category, cursor: cursor, cancel: cancel));
    if (refused) return '{"code":-1,"success":false}';
    if (pending != null) return await pending!.future;
    return _body({
      'feeds': cursor == '0' ? [_row('570000000000000001', '4.5')] : [_row('570000000000000002', '4.5')],
    });
  }

  @override
  Future<XiaohongshuPushIdentity> pushIdentity(String roomId, {bool refresh = false, CancelToken? cancel}) =>
      throw UnimplementedError();
}

/// The transport under the site: the share-page answer room entries read.
final class _Http implements LiveHttp {
  _Http(this.answer);

  final String answer;
  int requests = 0;

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    requests += 1;
    return LiveResponse(statusCode: 200, headers: const {}, bodyBytes: utf8.encode(answer));
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) => throw UnimplementedError();
  @override
  void close() {}
}

/// The transport the directory must never use: any request is a test failure.
final class _Never implements LiveHttp {
  @override
  Future<LiveResponse> send(LiveRequest request) => throw StateError('Directory must use its visitor transport');
  @override
  Future<LiveStreamedResponse> open(LiveRequest request) => throw UnimplementedError();
  @override
  void close() {}
}

XiaohongshuSite _guestSite([XiaohongshuGuest? guest]) =>
    XiaohongshuSite(http: XiaohongshuHttp(_Http(_sharePage())), guest: guest ?? _Guest());

void main() {
  group('guest directory categories', () {
    test('ids and names come from the response, with the safe identity gates', () {
      final categories = XiaohongshuDirectoryParser.categories(
        _body({
          'categories': [
            {'id': 0, 'desc': '全部'},
            {'id': '8', 'desc': 'New category'},
            {'id': 8, 'desc': 'Duplicate'},
            {'id': '../bad', 'desc': 'Bad'},
            {'id': '9', 'desc': ''},
            {'id': '10', 'desc': 'x' * 101},
            null,
          ],
        }),
      );
      expect(categories.map((area) => area.areaId), ['0', '8']);
      expect(categories.map((area) => area.areaName), ['全部', 'New category']);
      expect(categories.every((area) => area.platform == 'xiaohongshu'), isTrue);
      expect(categories.every((area) => area.parentAreaId == 'live' && area.parentAreaName == '小红书'), isTrue);
    });

    test('a refusal, a missing list and an oversized body are errors, not empty', () {
      final bodies = [
        '<html>captcha</html>',
        '{}',
        '{"code":-1,"success":false}',
        _body({}),
        _body({'categories': 'no'}),
        'x' * (2 * 1024 * 1024 + 1),
      ];
      for (final body in bodies) {
        expect(
          () => XiaohongshuDirectoryParser.categories(body),
          throwsA(
            isA<XiaohongshuFailure>().having((failure) => failure.kind, 'kind', XiaohongshuFailureKind.apiChanged),
          ),
          reason: 'a bootstrap refusal is never disguised as an empty directory',
        );
      }
    });
  });

  group('guest directory feed', () {
    test('the exact string broadcast id wins; no tokens or streams enter the card', () {
      final row = _row('570000000000000017', '9.75');
      final live = row['live']! as Map<String, Object?>;
      (live['t_room_info']! as Map<String, Object?>)['xsec_token'] = 'synthetic-token-not-for-storage';
      final result = _feed(
        _body({
          'feeds': [row],
        }),
        cursor: '0',
      );
      final room = result.rooms.single;
      expect(room.roomId, '570000000000000017');
      expect(room.anchor!.anchorId, 'synthetic-host');
      expect(room.anchor!.name, 'Test host');
      expect(room.audience.onlineViewers, 7);
      expect(room.audience.totalViewers, 90);
      expect(room.audience.primaryMetric, LiveAudienceMetricType.totalViewers);
      expect(room.audience.popularity, isNull, reason: 'heat is not an audience figure');
      expect(room.links.webUrl, 'https://www.xiaohongshu.com/livestream/570000000000000017');
      expect(jsonEncode(room.toJson()), isNot(contains('synthetic-token')));
      expect(room.runtime.streamHandle, isNull);
      expect(result.nextCursor, '9.75');
      expect(result.hasMore, isTrue, reason: 'a short page still has a real cursor');
    });

    test('a row that is not a live card is left out, a bad one does not stall paging', () {
      final result = _feed(
        _body({
          'feeds': [
            {'type': 'live', 'model_type': 'note_v2', 'cursor_score': '5'},
            {'type': 'note', 'model_type': 'live_v2', 'cursor_score': '6'},
            _row('bad', '2.25'),
          ],
        }),
        cursor: '0',
      );
      expect(result.rooms, isEmpty);
      expect(result.nextCursor, '2.25');
    });

    test('the inclusive tail terminates; the score of an exhausted page is not repeated', () {
      final end = _feed(
        _body({
          'feeds': [_row('570000000000000001', '2.25')],
        }),
        cursor: '2.25',
      );
      expect(end.hasMore, isFalse);
      expect(end.nextCursor, isNull);
      expect(_feed(_body({'feeds': <Object?>[]}), cursor: '0').hasMore, isFalse);
    });

    test('missing audience stays unknown; zero is explicit; the total leads when given', () {
      final rooms = _feed(
        _body({
          'feeds': [
            _row('570000000000000001', '3', online: null, total: null),
            _row('570000000000000002', '2', online: 0, total: 0),
            _row('570000000000000003', '1', online: 4, total: null),
          ],
        }),
        cursor: '0',
      ).rooms;
      expect(rooms[0].audience.onlineViewers, isNull);
      expect(rooms[0].audience.totalViewers, isNull);
      expect(rooms[0].audience.primaryMetric, LiveAudienceMetricType.onlineViewers);
      expect(rooms[1].audience.onlineViewers, 0);
      expect(rooms[1].audience.totalViewers, 0);
      expect(rooms[2].audience.primaryMetric, LiveAudienceMetricType.onlineViewers);
    });

    test('refusals, missing fields, non-JSON and huge payloads are errors, not empty', () {
      final bodies = [
        '<html>captcha</html>',
        '{}',
        '{"code":-1,"success":false}',
        _body({}),
        _body({'feeds': <String, Object?>{}}),
        'x' * (2 * 1024 * 1024 + 1),
      ];
      for (final body in bodies) {
        expect(
          () => _feed(body, cursor: '0'),
          throwsA(
            isA<XiaohongshuFailure>().having((failure) => failure.kind, 'kind', XiaohongshuFailureKind.apiChanged),
          ),
        );
      }
    });
  });

  group('site cursor paging', () {
    test('category cursors and refreshes never share page state', () async {
      final guest = _Guest();
      final site = _guestSite(guest);
      final areas = await site.categories();
      final game = areas.last;
      expect(game.areaId, '1');
      final first = await site.directoryAtCursor(page: 1, category: game);
      await site.directoryAtCursor(page: 1);
      await site.directoryAtCursor(page: 2, category: game, cursor: first.nextCursor);
      await site.directoryAtCursor(page: 1, category: game);
      expect(guest.calls.map((call) => (call.category, call.cursor)), [
        ('1', '0'),
        ('0', '0'),
        ('1', '4.5'),
        ('1', '0'),
      ]);
      expect(site.directoryNoticeKey, 'xiaohongshu_guest_directory_scope');
      expect(site.directoryNotice, XiaohongshuEndpoints.guestDirectoryScope);
      const invalid = XiaohongshuFailureKind.invalidArgument;
      await expectLater(
        site.directoryAtCursor(page: 2),
        throwsA(isA<XiaohongshuFailure>().having((failure) => failure.kind, 'kind', invalid)),
      );
      await expectLater(
        site.directoryAtCursor(page: 1, cursor: 'bad'),
        throwsA(isA<XiaohongshuFailure>().having((failure) => failure.kind, 'kind', invalid)),
      );
      await expectLater(
        site.directoryAtCursor(
          page: 1,
          category: LiveArea.normalized(platform: 'huya', areaId: '1'),
        ),
        throwsA(isA<XiaohongshuFailure>().having((failure) => failure.kind, 'kind', invalid)),
      );
    });

    test('compatibility paging replays cursors and stops at the inclusive tail', () async {
      final guest = _Guest();
      final site = _guestSite(guest);
      final result = await site.directory(3);
      expect(result.rooms, isEmpty);
      expect(result.hasMore, isFalse);
      expect(guest.calls.map((call) => call.cursor), ['0', '4.5']);
      expect(guest.calls.every((call) => call.cancel!.isCancelled), isTrue);
    });

    test('a carried cursor costs one request and skips no rooms', () async {
      final guest = _Guest();
      final site = _guestSite(guest);
      final result = await site.directory(2, cursor: 'kept');
      expect(result.rooms.single.roomId, '570000000000000002');
      expect(guest.calls.single.cursor, 'kept');
    });

    test('room entry carries its chat arguments only where the guest exists', () async {
      final guestSite = _guestSite();
      final detail = await guestSite.detail('123');
      expect(detail.runtime.danmakuHandle, isA<XiaohongshuDanmakuArgs>());
      expect((detail.runtime.danmakuHandle! as XiaohongshuDanmakuArgs).roomId, '123');
      expect(guestSite.capability<LiveAreaProvider>(), isNotNull);
      expect(guestSite.capability<LiveDanmakuProvider>(), isNotNull);

      final bare = XiaohongshuSite(http: XiaohongshuHttp(_Http(_sharePage())));
      final bareDetail = await bare.detail('123');
      expect(bareDetail.runtime.danmakuHandle, isNull);
      expect(bare.capability<LiveAreaProvider>(), isNull);
      expect(bare.capability<LiveDanmakuProvider>(), isNull);
      expect(bare.directoryNoticeKey, 'xiaohongshu_directory_scope');
      expect(bare.directoryNotice, XiaohongshuEndpoints.directoryScope);
      final empty = await bare.directory(1);
      expect(empty.rooms, isEmpty);
      expect(empty.hasMore, isFalse);
      expect(empty.nextCursor, isNull);
      expect(await bare.categories(), isEmpty);
      await expectLater(
        bare.directoryAtCursor(
          page: 1,
          category: LiveArea.normalized(platform: 'xiaohongshu', areaId: '1'),
        ),
        throwsA(
          isA<XiaohongshuFailure>().having((failure) => failure.kind, 'kind', XiaohongshuFailureKind.invalidArgument),
        ),
      );
    });
  });

  group('capability boundary', () {
    test('areas and area rooms ride the flat catalog and the guest feed', () async {
      final guest = _Guest();
      final site = _guestSite(guest);
      final areaProvider = site.capability<LiveAreaProvider>()!;
      final areas = _right(await areaProvider.getAreas());
      final game = areas.last;
      final rooms = _right(
        await areaProvider.getAreaRooms(
          area: game,
          request: LivePageRequest.of(page: 2, cursor: '4.5'),
        ),
      );
      expect(rooms.items.single.roomId, '570000000000000002');
      expect(rooms.nextCursor, isNull, reason: 'the repeated final score ends the listing');
      expect(rooms.hasMore, isFalse);
      expect(guest.calls.map((call) => call.category), ['1']);
      expect(guest.calls.map((call) => call.cursor), ['4.5']);

      final bare = XiaohongshuSite(http: XiaohongshuHttp(_Never()));
      final empty = _right(await bare.capability<LiveDiscoveryProvider>()!.getRecommendedRooms());
      expect(empty.items, isEmpty);
      expect(empty.hasMore, isFalse);
    });

    test('a refused feed is a typed parse error at the boundary, never an empty page', () async {
      final guest = _Guest()..refused = true;
      final site = _guestSite(guest);
      final page = await site.capability<LiveDiscoveryProvider>()!.getRecommendedRooms(request: LivePageRequest.of());
      expect(_leftOf(page), isA<LiveSiteParseError>());
    });

    test('an area of another platform is an invalid-argument error, not a request', () async {
      final guest = _Guest();
      final site = _guestSite(guest);
      final page = await site.capability<LiveAreaProvider>()!.getAreaRooms(
        area: LiveArea.normalized(platform: 'huya', areaId: '1'),
      );
      expect(_leftOf(page), isA<LiveSiteInvalidArgument>());
      expect(guest.calls, isEmpty);
    });
  });
}

/// The share-page answer the stub transport returns for room entries.
String _sharePage() {
  final state = {
    'liveStream': {
      'pageStatus': 'success',
      'liveStatus': 'success',
      'roomData': {
        'roomInfo': {
          'roomId': '123',
          'status': 2,
          'monetizeType': 0,
          'joinLimitTypes': [0],
          'roomTitle': 'A room',
          'roomCover': 'https://img.xhscdn.com/c.jpg',
          'pullConfig': jsonEncode({
            'h264': [
              {
                'master_url': 'https://live-source-play.xhscdn.com/live/123.flv',
                'quality_type': 'HD',
                'quality_type_name': '原画',
              },
            ],
            'h265': <Object?>[],
          }),
        },
        'hostInfo': {'nickName': 'Ann', 'avatar': ''},
      },
    },
  };
  return '<script>window.__INITIAL_STATE__=${jsonEncode(state)}</script>';
}
