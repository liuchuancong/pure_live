import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/site/seventeenlive/seventeenlive_api.dart';
import 'package:pure_live/core/site/seventeenlive/seventeenlive_site.dart';
import 'package:pure_live/core/sites.dart';
import 'package:pure_live/modules/search/search_capability.dart';

Map<String, Object?> _stream(
  int roomId, {
  int status = 2,
  Object? ownerRoomId,
  String name = 'Fixture',
  String? userId,
}) {
  final uid = userId ?? 'user-$roomId';
  return {
    'liveStreamID': roomId,
    'userID': uid,
    'status': status,
    'caption': 'Current broadcast',
    'liveViewerCount': 12,
    'viewerCount': 90,
    'coverPhoto': 'http://cdn.17app.co/snapshot/$uid.jpg',
    'userInfo': {
      'roomID': ownerRoomId,
      'userID': uid,
      'displayName': name,
      'picture': 'avatar.jpg',
      'followerCount': 80,
    },
  };
}

({int status, String body}) _ok(Object data) => (status: 200, body: jsonEncode(data));

void main() {
  test('official current-live search encodes keyword and retains only identified live cards', () async {
    final calls = <Uri>[];
    final api = SeventeenLiveApi(
      request: (uri, _) async {
        calls.add(uri);
        return _ok([
          _stream(123, ownerRoomId: 123, name: 'あかり'),
          _stream(123, ownerRoomId: 123),
          _stream(124, status: 0, ownerRoomId: 124),
          _stream(125, ownerRoomId: 999),
          _stream(125, ownerRoomId: 125),
          _stream(126, ownerRoomId: 126, userId: 'valid')..['userID'] = 'other',
        ]);
      },
    );
    final rooms = await api.searchCurrentLive(' あ/音楽 ');
    expect(calls.single.path, '/api/v1/liveStreams/search');
    expect(calls.single.queryParameters['query'], 'あ/音楽');
    expect(rooms.map((room) => room.roomId), ['123', '125']);
    expect(rooms.first.nickname, 'あかり');
    expect(rooms.first.liveViewers, 12);
    expect(rooms.first.sessionViewers, 90);
    expect(rooms.first.streams, isEmpty);
    expect(() => rooms.add(rooms.first), throwsUnsupportedError);
  });

  test('public JP recommendation sections follow cursor and omit non-live, duplicate, and banner rows', () async {
    final calls = <Uri>[];
    final api = SeventeenLiveApi(
      request: (uri, _) async {
        calls.add(uri);
        if (uri.queryParameters['cursor'] == '') {
          return _ok({
            'cursor': 'opaque:cursor/one=',
            'sections': [
              {
                'id': 'TopBanner',
                'grids': [
                  {'stream': _stream(1)},
                ],
              },
              {
                'id': 'Label',
                'grids': [
                  {'stream': _stream(2)},
                  {'stream': _stream(2)},
                  {'stream': _stream(3, status: 0)},
                  {'stream': _stream(3)},
                  {'stream': _stream(4, userId: 'owner')..['userID'] = 'other'},
                ],
              },
            ],
          });
        }
        return _ok({
          'cursor': '',
          'sections': [
            {
              'id': 'Latest',
              'grids': [
                {'stream': _stream(5)},
              ],
            },
          ],
        });
      },
    );
    final site = SeventeenLiveSite(api: api);
    final first = await site.getDirectoryPageAtCursor(page: 1);
    expect(first.rooms.map((room) => room.roomId), ['2', '3']);
    expect(first.rooms.first.liveStatus, LiveStatus.live);
    expect(first.rooms.first.onlineViewers, '12');
    expect(first.rooms.first.totalViewers, '90');
    expect(first.rooms.first.data, isNull);
    expect(first.hasMore, isTrue);
    expect(first.nextCursor, 'opaque:cursor/one=');
    final second = await site.getDirectoryPageAtCursor(page: 2, cursor: first.nextCursor);
    expect(second.rooms.map((room) => room.roomId), ['5']);
    expect(second.hasMore, isFalse);
    expect(calls.map((uri) => uri.queryParameters['cursor']), ['', 'opaque:cursor/one=']);
    expect(calls.every((uri) => uri.queryParameters['region'] == 'JP'), isTrue);
    expect(calls.every((uri) => uri.queryParameters['typeTab'] == '2'), isTrue);
  });

  test('site keeps exact room lookup and uses the bounded website live search for names', () async {
    final calls = <Uri>[];
    final site = SeventeenLiveSite(
      api: SeventeenLiveApi(
        request: (uri, _) async {
          calls.add(uri);
          if (uri.path.endsWith('/search')) {
            return _ok([_stream(123, ownerRoomId: 123), _stream(124, ownerRoomId: 124)]);
          }
          return _ok(_stream(123, ownerRoomId: 123));
        },
      ),
    );
    final named = await site.searchRooms('あかり', pageSize: 1);
    expect(named, hasLength(1));
    expect(named.single.roomId, '123');
    expect(named.single.data, isNull);
    final exact = await site.searchRooms('https://17.live/en/live/123');
    expect(exact.map((room) => room.roomId), ['123']);
    expect(calls.map((uri) => uri.path), ['/api/v1/liveStreams/search', '/api/v1/lives/123']);
    expect(await site.searchRooms('https://other.test/live/123'), isEmpty);
    expect(await site.searchRooms('あかり', page: 2), isEmpty);
    final capability = LiveSearchCapabilities.forPlatform(Sites.seventeenLiveSite);
    expect(capability.coverage, NativeSearchCoverage.liveOnly);
    expect(capability.supportsPagination, isFalse);
  });

  test('detail keeps strict owner room identity even when directory summaries omit it', () async {
    final api = SeventeenLiveApi(request: (_, _) async => _ok(_stream(123)));
    await expectLater(
      api.room('123'),
      throwsA(isA<SeventeenLiveException>().having((e) => e.kind, 'kind', SeventeenLiveFailure.identity)),
    );
  });

  test('catalogue cancellation, status, and cursor schema are distinct', () async {
    final cancelled = SeventeenLiveApi(request: (_, _) async => throw StateError('unexpected request'));
    await expectLater(
      cancelled.searchCurrentLive('あ', cancel: CancelToken()..cancel('fixture')),
      throwsA(isA<SeventeenLiveException>().having((e) => e.kind, 'kind', SeventeenLiveFailure.cancelled)),
    );
    final denied = SeventeenLiveApi(request: (_, _) async => (status: 403, body: ''));
    await expectLater(
      denied.directory(),
      throwsA(isA<SeventeenLiveException>().having((e) => e.kind, 'kind', SeventeenLiveFailure.access)),
    );
    final malformed = SeventeenLiveApi(request: (_, _) async => _ok({'cursor': 12, 'sections': []}));
    await expectLater(
      malformed.directory(),
      throwsA(isA<SeventeenLiveException>().having((e) => e.kind, 'kind', SeventeenLiveFailure.schema)),
    );
  });
}
