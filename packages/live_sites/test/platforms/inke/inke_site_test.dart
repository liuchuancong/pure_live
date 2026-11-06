import 'dart:convert';
import 'dart:typed_data';

import 'package:live_net/live_net.dart';
import 'package:live_sites/src/capabilities/live_discovery_provider.dart';
import 'package:live_sites/src/capabilities/live_play_recovery.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/capabilities/live_room_refresh.dart';
import 'package:live_sites/src/capabilities/live_status_check.dart';
import 'package:live_sites/src/core/live_site_cancellation.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/platforms/inke/api/inke_endpoints.dart';
import 'package:live_sites/src/platforms/inke/api/inke_http.dart';
import 'package:live_sites/src/platforms/inke/inke_site.dart';
import 'package:test/test.dart';

// The private helpers spell their own class name in their constructors, as the
// package's value wrappers do.
// ignore_for_file: unnecessary_type_name_in_constructor

const String _uid = '555';
const String _liveId = '987';

/// The transport under the site: every URL asked is recorded, and the answer
/// is the handler's for it.
final class _Http implements LiveHttp {
  _Http(this.answer);

  final String Function(Uri url) answer;
  final asked = <Uri>[];
  final requests = <LiveRequest>[];

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    asked.add(request.url);
    requests.add(request);
    return LiveResponse(
      statusCode: 200,
      headers: const {'content-type': 'application/json; charset=utf-8'},
      bodyBytes: Uint8List.fromList(utf8.encode(answer(request.url))),
    );
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) async => throw UnimplementedError();

  @override
  void close() {}
}

/// A transport that never answers on its own: the wait ends only when the
/// request's own token is cancelled (or was already), as an interrupted
/// transport would.
final class _HangingHttp implements LiveHttp {
  final requests = <LiveRequest>[];

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    requests.add(request);
    final token = request.cancelToken;
    if (token.isCancelled) throw const CancelledFailure();
    await token.whenCancel;
    throw const CancelledFailure();
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) async => throw UnimplementedError();

  @override
  void close() {}
}

/// The Wangsu pull URL of the broadcast, as signed by [sign].
String _pull(String sign) => 'https://live-pull-ws.ikstatic.cn/live/${_liveId}_t.flv?sign=$sign';

/// `live_share_pc` of the anchor: live, or the platform's "no live" code.
String _share({bool live = true}) => jsonEncode(
  live
      ? {
          'error_code': 0,
          'data': {
            'live_uid': _uid,
            'status': 1,
            'liveid': _liveId,
            'live_name': 'Show',
            'portrait': 'https://img.inke.cn/cover.jpg',
            'media_info': {'nick': 'Ann', 'inke_id': _uid, 'portrait': 'https://img.inke.cn/avatar.jpg'},
          },
        }
      : {'error_code': InkeEndpoints.noLiveCode},
);

/// `now_publish` of the anchor: the broadcast with its pull URL signed
/// [sign], or (null) none.
String _publish(String? sign) => jsonEncode({
  'dm_error': 0,
  'live': sign == null
      ? null
      : {
          'id': _liveId,
          'creator': _uid,
          'status': 1,
          'name': 'App Show',
          'cover': 'https://img.inke.cn/app.jpg',
          'stream_addr': _pull(sign),
          'numbers': {'real': 76},
          'online_users': 12000,
        },
});

/// A showcase row of anchor [uid] named [nick].
Map<String, Object?> _row(String uid, String nick) => {
  'uid': uid,
  'live_id': '1$uid',
  'nick': nick,
  'portrait': 'https://img.inke.cn/$uid.jpg',
};

/// The site's answers by endpoint: the share page and the app's broadcast
/// as [share] and [publish] give them; a top list and one channel with a
/// fixed "Ann" each; the app's hot list, whose one "Ann" is a new broadcast
/// at each request (as the real list changes between requests).
String Function(Uri url) _site({String Function()? share, String? Function()? publish}) {
  var hot = 0;
  return (url) => switch (url.path) {
    '/web/live_share_pc' => (share ?? _share)(),
    '/api/live/now_publish' => _publish(publish == null ? 'a' : publish()),
    '/web/Live_top_pc' => jsonEncode({
      'error_code': 0,
      'data': {
        'list': [_row('601', 'Ann top')],
      },
    }),
    '/web/Live_channel_pc' => jsonEncode({
      'error_code': 0,
      'data': {
        'list': [
          {
            'tab_key': 'music',
            'channel_name': '音乐',
            'list': [_row('602', 'Ann channel')],
          },
        ],
      },
    }),
    '/api/live/simpleall' => jsonEncode({
      'dm_error': 0,
      'lives': [
        {
          'creator': {'id': '${700 + ++hot}', 'nick': 'Ann hot $hot', 'portrait': ''},
          'id': '${900 + hot}',
          'status': 1,
        },
      ],
    }),
    _ => throw StateError('unexpected request $url'),
  };
}

LiveRoom _card() => LiveRoom.normalized(platform: 'inke', roomId: _uid);

void main() {
  group('follow refreshes', () {
    test("a live room's refresh carries the app's title and audience, as its entry does", () async {
      final http = _Http(_site());
      final site = InkeSite(http: InkeHttp(http));
      final read = await site.capability<LiveRoomRefresh>()!.getRoomForRefresh(roomId: _uid);
      final room = read.getOrElse((error) => fail('$error'));
      expect(room.content.title, 'App Show');
      expect(room.audience.onlineViewers, 76);
      expect(http.asked.map((url) => url.path), ['/web/live_share_pc', '/api/live/now_publish']);
    });

    test("an offline room's refresh is the share page alone", () async {
      final http = _Http(_site(share: () => _share(live: false)));
      final site = InkeSite(http: InkeHttp(http));
      final read = await site.capability<LiveRoomRefresh>()!.getRoomForRefresh(roomId: _uid);
      expect(read.getOrElse((error) => fail('$error')).broadcast.liveStatus, LiveStatus.offline);
      expect(http.asked, hasLength(1));
    });
  });

  group('the one-bit status', () {
    test('is the share page alone, live or not', () async {
      for (final live in [true, false]) {
        final http = _Http(_site(share: () => _share(live: live)));
        final site = InkeSite(http: InkeHttp(http));
        final read = await site.capability<LiveStatusCheck>()!.getLiveStatus(room: _card());
        expect(read.getOrElse((error) => fail('$error')), live);
        expect(http.asked.map((url) => url.path), ['/web/live_share_pc'], reason: 'the bit needs no broadcast');
      }
    });

    test('an id that is no uid is not-found, without a request', () async {
      final http = _Http(_site());
      final site = InkeSite(http: InkeHttp(http));
      final read = await site.capability<LiveStatusCheck>()!.getLiveStatus(
        room: LiveRoom.normalized(platform: 'inke', roomId: 'abc'),
      );
      expect(read.getLeft().toNullable(), isA<LiveSiteNotFound>());
      expect(http.asked, isEmpty);
    });
  });

  group('search pages', () {
    test('later pages cut the answers page 1 fetched while they are young', () async {
      var clock = DateTime.utc(2026, 11, 6, 12);
      final http = _Http(_site());
      final site = InkeSite(http: InkeHttp(http), now: () => clock);

      final first = await site.search('ann', pageSize: 2);
      expect(first.rooms.map((room) => room.roomId), ['601', '602']);
      expect(first.hasMore, isTrue);
      expect(http.asked, hasLength(3), reason: 'the top list, the channels and the hot list');

      clock = clock.add(const Duration(seconds: 20));
      final second = await site.search('ann', page: 2, pageSize: 2);
      expect(second.rooms.single.roomId, '701', reason: "page 1's hot list, not a new one");
      expect(http.asked, hasLength(3));

      clock = clock.add(InkeSite.snapshotLifetime);
      final stale = await site.search('ann', page: 2, pageSize: 2);
      expect(stale.rooms.single.roomId, '702');
      expect(http.asked, hasLength(6), reason: 'past the lifetime the lists are asked again');

      await site.search('ann', pageSize: 2);
      expect(http.asked, hasLength(9), reason: 'a page 1 is a new search and always asks');
    });
  });

  group('recovery', () {
    test("the entry's answer serves the first play; recovery asks the app for newly signed lines", () async {
      var sign = 'a';
      final http = _Http(_site(publish: () => sign));
      final site = InkeSite(http: InkeHttp(http));
      final room = await site.detail(_uid);
      expect(http.asked, hasLength(2));

      final held = (await site.capability<LivePlaybackProvider>()!.getLines(
        room: room,
      )).getOrElse((error) => fail('$error'));
      expect(held.single.url, _pull('a'));
      expect(http.asked, hasLength(2), reason: "the entry's answer is young enough");

      sign = 'b';
      final recovery = site.capability<LivePlayRecovery>();
      expect(recovery, isNotNull);
      final fresh = (await recovery!.refetchLines(room: room)).getOrElse((error) => fail('$error'));
      expect(fresh.single.url, _pull('b'));
      expect(http.asked.skip(2).map((url) => url.path), ['/api/live/now_publish']);
    });

    test('an anchor the app says is not live says so instead of replaying the held line', () async {
      String? sign = 'a';
      final http = _Http(_site(publish: () => sign));
      final site = InkeSite(http: InkeHttp(http));
      final room = await site.detail(_uid);
      sign = null;
      final answer = await site.capability<LivePlayRecovery>()!.refetchLines(room: room);
      expect(answer.getLeft().toNullable(), isA<LiveSiteContentUnavailable>());
      expect(http.asked, hasLength(3));
    });

    test('a room entered offline is asked again: the anchor may be live by now', () async {
      final http = _Http(_site(share: () => _share(live: false), publish: () => 'c'));
      final site = InkeSite(http: InkeHttp(http));
      final room = await site.detail(_uid);
      expect(http.asked, hasLength(1));

      final held = await site.capability<LivePlaybackProvider>()!.getLines(room: room);
      expect(held.getLeft().toNullable(), isA<LiveSiteContentUnavailable>());
      expect(http.asked, hasLength(1), reason: 'the kept offline answer needs no request');

      final fresh = (await site.capability<LivePlayRecovery>()!.refetchLines(
        room: room,
      )).getOrElse((error) => fail('$error'));
      expect(fresh.single.url, _pull('c'));
      expect(http.asked, hasLength(2));
    });
  });

  group('cancellation', () {
    test("the caller's token rides on the request and the answer passes", () async {
      final http = _Http(_site());
      final site = InkeSite(http: InkeHttp(http));
      final token = CancelToken();

      final answer = await site.fetchRecommended(cancel: token);
      expect(answer!.isRight(), isTrue);
      expect(http.requests, hasLength(1));
      expect(identical(http.requests.single.cancelToken, token), isTrue, reason: 'the very token rides on the request');
    });

    test('a cancelled wait is interrupted and reported as cancelled', () async {
      final http = _HangingHttp();
      final site = InkeSite(http: InkeHttp(http));
      final token = CancelToken();

      final answer = site.fetchSearch(LiveSearchRequest.of(query: 'ann', target: LiveSearchTarget.rooms), cancel: token);
      expect(http.requests, isNotEmpty, reason: 'the search asked its first list');
      token.cancel();
      expect((await answer)!.getLeft().toNullable(), isA<LiveSiteCancelled>());
      expect(http.requests.every((request) => request.cancelToken.isCancelled), isTrue);
    });

    test('a token set before the call stops at the transport', () async {
      final http = _HangingHttp();
      final site = InkeSite(http: InkeHttp(http));
      final provider = site.capability<LiveDiscoveryProvider>()! as LiveCancellableDiscovery;
      final token = CancelToken()..cancel();

      final answer = await provider.getRecommendedRooms(cancel: token);
      expect(answer.getLeft().toNullable(), isA<LiveSiteCancelled>());
      expect(http.requests.single.cancelToken.isCancelled, isTrue, reason: 'the request carried the token and was refused');
    });

    test("a scope ends the site's calls and waits for them to settle", () async {
      final http = _HangingHttp();
      final site = InkeSite(http: InkeHttp(http));
      final scope = LiveFetchScope();

      final answer = scope.recommended(site);
      await scope.dispose();
      expect((await answer)!.getLeft().toNullable(), isA<LiveSiteCancelled>());
      expect(http.requests.single.cancelToken.isCancelled, isTrue);
    });
  });
}
