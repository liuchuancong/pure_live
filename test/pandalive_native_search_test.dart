import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/site/pandalive/pandalive_api.dart';
import 'package:pure_live/core/site/pandalive/pandalive_link.dart';
import 'package:pure_live/core/site/pandalive/pandalive_site.dart';
import 'package:pure_live/core/sites.dart';
import 'package:pure_live/modules/search/search_capability.dart';

Map<String, Object?> _live({String id = 'gaoninc', int idx = 101, String nick = '가온'}) => {
  'userId': id,
  'userIdx': idx,
  'userNick': nick,
  'title': '$nick 방송',
  'isLive': true,
  'user': 12,
  'fanCnt': 34,
  'isAdult': false,
  'isPw': false,
  'thumbUrl': 'https://cdn.pandalive.co.kr/cover.jpg',
  'userImg': 'https://cdn.pandalive.co.kr/avatar.jpg',
};

Map<String, Object?> _bj({String id = 'see994', int idx = 202, Object? media}) => {
  'userId': id,
  'userIdx': idx,
  'userNick': '가온主播',
  'thumbUrl': 'https://cdn.pandalive.co.kr/avatar.jpg',
  'blockService': false,
  if (media != null) 'media': media,
};

({int status, String body}) _page(List<Object?> rows, {required int page, required int size, required int total}) => (
  status: 200,
  body: jsonEncode({
    'result': true,
    'message': '',
    'page': {'offset': (page - 1) * size, 'limit': size, 'total': total, 'page': page},
    'list': rows,
  }),
);

void main() {
  test('official LIVE title search uses native searchVal, order and offset', () async {
    final forms = <Map<String, String>>[];
    final api = PandaLiveApi(
      request: (method, uri, form, referer, _) async {
        expect(method, 'POST');
        expect(uri.path, '/v1/live/index');
        expect(referer, contains('/search/live?text='));
        forms.add(form!);
        return _page([_live()], page: 2, size: 2, total: 5);
      },
    );
    final result = await api.searchLive(' 가온 ', page: 2, size: 2);
    expect(forms.single, containsPair('searchVal', '가온'));
    expect(forms.single, containsPair('orderBy', 'user'));
    expect(forms.single, containsPair('offset', '2'));
    expect(result.rooms.single.userId, 'gaoninc');
    expect(result.rooms.single.onlineViewers, 12);
    expect(result.hasMore, isTrue);
  });

  test('official BJ search includes offline profiles and verifies nested live identity', () async {
    final media = _live();
    final api = PandaLiveApi(
      request: (_, uri, form, referer, _) async {
        expect(uri.path, '/v1/live/bj_list');
        expect(form, containsPair('searchVal', '가온'));
        expect(referer, contains('/search/bj?text='));
        return _page(
          [
            _bj(id: 'gaoninc', idx: 101, media: media),
            _bj(id: '1506087545@ka', idx: 303),
            _bj(id: 'bad', idx: 404, media: _live()),
          ],
          page: 1,
          size: 3,
          total: 3,
        );
      },
    );
    final result = await api.searchBroadcasters('가온', size: 3);
    expect(result.rooms.map((room) => room.userId), ['gaoninc', '1506087545@ka']);
    expect(result.rooms.first.state, PandaLiveState.live);
    expect(result.rooms.first.onlineViewers, 12);
    expect(result.rooms.first.streams, isEmpty);
    expect(result.rooms.last.state, PandaLiveState.offline);
    expect(result.rooms.last.onlineViewers, isNull);
    expect(result.hasMore, isFalse);
    expect(PandaLiveLink.parse('https://www.pandalive.co.kr/channel/1506087545%40ka'), '1506087545@ka');
    expect(PandaLiveLink.url('1506087545@ka'), contains('1506087545'));
    expect(PandaLiveLink.normalizeUserId('name@ka/evil'), isNull);
  });

  test('site merges LIVE and BJ pages without duplicating the same channel', () async {
    final calls = <String>[];
    var inFlight = 0;
    var maxInFlight = 0;
    final site = PandaLiveSite(
      api: PandaLiveApi(
        request: (_, uri, form, _, _) async {
          inFlight++;
          if (inFlight > maxInFlight) maxInFlight = inFlight;
          await Future<void>.delayed(const Duration(milliseconds: 2));
          inFlight--;
          calls.add('${uri.path}:${form?['offset']}');
          final page = int.parse(form!['offset']!) ~/ int.parse(form['limit']!) + 1;
          final size = int.parse(form['limit']!);
          if (uri.path == '/v1/live/index') {
            return _page(page == 1 ? [_live()] : [], page: page, size: size, total: 1);
          }
          expect(uri.path, '/v1/live/bj_list');
          return _page(
            page == 1 ? [_bj(id: 'gaoninc', idx: 101, media: _live()), _bj()] : [],
            page: page,
            size: size,
            total: 2,
          );
        },
      ),
    );
    final first = await site.searchRooms('가온', pageSize: 4);
    expect(first.map((room) => room.roomId), ['gaoninc', 'see994']);
    expect(first.first.effectiveLiveStatus, LiveStatus.live);
    expect(first.last.effectiveLiveStatus, LiveStatus.offline);
    expect(first.last.onlineViewers, isNull);
    expect(await site.searchRooms('가온', page: 2, pageSize: 4), isEmpty);
    expect(calls, ['/v1/live/bj_list:0', '/v1/live/index:0', '/v1/live/bj_list:2', '/v1/live/index:2']);
    expect(maxInFlight, 1);
    final capability = LiveSearchCapabilities.forPlatform(Sites.pandaLiveSite);
    expect(capability.coverage, NativeSearchCoverage.liveAndOffline);
    expect(capability.supportsPagination, isTrue);
  });

  test('official channel link remains exact and malformed web URLs do not become keywords', () async {
    final calls = <String>[];
    final site = PandaLiveSite(
      api: PandaLiveApi(
        request: (_, uri, _, _, _) async {
          calls.add(uri.path);
          if (uri.path == '/v1/member/bj') {
            return (
              status: 200,
              body: jsonEncode({
                'result': true,
                'bjInfo': {
                  'id': 'gaoninc',
                  'idx': 101,
                  'nick': '가온',
                  'thumbUrl': 'https://cdn.pandalive.co.kr/avatar.jpg',
                },
              }),
            );
          }
          throw StateError('unexpected endpoint');
        },
      ),
    );
    final exact = await site.searchRooms('https://www.pandalive.co.kr/channel/gaoninc');
    expect(exact.single.roomId, 'gaoninc');
    expect(exact.single.effectiveLiveStatus, LiveStatus.offline);
    expect(calls, ['/v1/member/bj']);
    expect(await site.searchRooms('https://other.test/channel/gaoninc'), isEmpty);
    expect(calls, ['/v1/member/bj']);
  });

  test('search input validation and cancellation reject invalid requests before transport', () async {
    final api = PandaLiveApi(request: (_, _, _, _, _) async => throw StateError('unexpected request'));
    await expectLater(
      api.searchLive('a'),
      throwsA(isA<PandaLiveException>().having((e) => e.kind, 'kind', PandaLiveFailure.schema)),
    );
    await expectLater(
      api.searchBroadcasters('가온', cancel: CancelToken()..cancel('fixture')),
      throwsA(isA<PandaLiveException>().having((e) => e.kind, 'kind', PandaLiveFailure.cancelled)),
    );
  });
}
