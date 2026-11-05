import 'dart:convert';
import 'dart:typed_data';

import 'package:live_net/live_net.dart';
import 'package:live_sites/src/platforms/bilibili/api/bilibili_endpoints.dart';
import 'package:live_sites/src/platforms/bilibili/api/bilibili_http.dart';
import 'package:live_sites/src/platforms/douyin/api/douyin_endpoints.dart';
import 'package:live_sites/src/platforms/douyin/api/douyin_http.dart';
import 'package:live_sites/src/platforms/douyu/api/douyu_endpoints.dart';
import 'package:live_sites/src/platforms/douyu/api/douyu_http.dart';
import 'package:live_sites/src/platforms/kuaishou/api/kuaishou_endpoints.dart';
import 'package:live_sites/src/platforms/kuaishou/api/kuaishou_http.dart';
import 'package:live_sites/src/platforms/soop/api/soop_endpoints.dart';
import 'package:live_sites/src/platforms/soop/api/soop_http.dart';
import 'package:live_sites/src/platforms/twitch/api/twitch_endpoints.dart';
import 'package:live_sites/src/platforms/twitch/api/twitch_http.dart';
import 'package:live_sites/src/platforms/yy/api/yy_endpoints.dart';
import 'package:live_sites/src/platforms/yy/api/yy_http.dart';
import 'package:test/test.dart';

/// A transport answer that parses as nothing in particular: the point of
/// these cases is what went out, not what came back.
LiveResponse _answered() => LiveResponse(
  statusCode: 200,
  headers: const <String, String>{'location': 'https://www.douyu.com/456'},
  bodyBytes: Uint8List.fromList(utf8.encode('{"result":1}')),
  setCookies: const <String>['did=3; Max-Age=1'],
);

/// Every request the transports built, in the order they built them.
final class _RecordingHttp implements LiveHttp {
  final List<LiveRequest> sent = [];

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    sent.add(request);
    return _answered();
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) async => throw UnimplementedError();

  @override
  void close() {}
}

/// Runs [ask], ignoring what a parser makes of the canned answer, and returns
/// the requests the transport built.
Future<List<LiveRequest>> _capture(Future<void> Function(_RecordingHttp http) ask) async {
  final http = _RecordingHttp();
  try {
    await ask(http);
  } on Object {
    // A parser refusing the canned body says nothing about the wait cap.
  }
  return http.sent;
}

void _expectCapped(List<LiveRequest> requests, Duration cap, {int? atLeast}) {
  expect(requests, hasLength(greaterThanOrEqualTo(atLeast ?? 1)));
  for (final request in requests) {
    expect(request.timeout, cap, reason: '${request.method} ${request.url} must not wait forever');
  }
}

void main() {
  group('the wait a platform transport may hold the room open for', () {
    test('bilibili caps its two request shapes', () async {
      _expectCapped(
        await _capture(
          (http) => BilibiliHttp(http).get(Uri.parse('https://api.live.bilibili.com/room/v1/Room/get_info?room_id=1')),
        ),
        BilibiliEndpoints.requestTimeout,
      );
      final both = await _capture((http) async {
        final transport = BilibiliHttp(http as LiveHttp);
        await transport.get(Uri.parse('https://api.live.bilibili.com/xlive/web-room/v1/index/getDanmuInfo?id=1'));
        await transport.getRaw(Uri.parse('https://api.bilibili.com/x/web-interface/nav'));
      });
      _expectCapped(both, BilibiliEndpoints.requestTimeout, atLeast: 2);
    });

    test('douyu caps the api, the play form, the alias and the renewal', () async {
      final requests = await _capture((http) async {
        final transport = DouyuHttp(http as LiveHttp);
        await transport.get(Uri.parse('https://www.douyu.com/betard/1'));
        await transport.postForm(Uri.parse('https://www.douyu.com/liverp/getH5PlayV1/1'), fields: const {});
        await transport.getRedirect(Uri.parse('https://yuba.douyu.com/p/1'));
        await transport.passportSetCookies(Uri.parse('https://passport.douyu.com/index/renewal'), const {});
      });
      _expectCapped(requests, DouyuEndpoints.requestTimeout, atLeast: 4);
    });

    test('douyin caps its page read', () async {
      _expectCapped(
        await _capture(
          (http) => DouyinHttp(http).get(Uri.parse('https://live.douyin.com/webcast/room/web/enter/?web_rid=1')),
        ),
        DouyinEndpoints.requestTimeout,
      );
    });

    test('kuaishou caps the api, the feed post and the comment poll', () async {
      final requests = await _capture((http) async {
        final transport = KuaishouHttp(http as LiveHttp);
        await transport.get(Uri.parse('https://live.kuaishou.com/live-api/x?authorId=1'));
        await transport.postJson(Uri.parse('https://live.kuaishou.com/live-api/y'), json: const {});
        await transport.feedJson(Uri.parse('https://live.kuaishou.com/live-api/feed'));
      });
      _expectCapped(requests, KuaishouEndpoints.requestTimeout, atLeast: 3);
    });

    test('soop caps the api read and the player form', () async {
      final requests = await _capture((http) async {
        final transport = SoopHttp(http as LiveHttp);
        await transport.get(Uri.parse('https://api.sooplive.co.kr/v2/session/play_live?channel_id=1'));
        await transport.postForm(Uri.parse('https://apiv2.sooplive.co.kr/api/v1/BJ/player_live_api'), const {});
      });
      _expectCapped(requests, SoopEndpoints.requestTimeout, atLeast: 2);
    });

    test('twitch caps the page read and the GraphQL post', () async {
      final requests = await _capture((http) async {
        final transport = TwitchHttp(http as LiveHttp);
        await transport.get(Uri.parse('https://gql.twitch.tv/RequestUtils/x'));
        await transport.gql(const <String, Object?>{'query': '{}'});
      });
      _expectCapped(requests, TwitchEndpoints.requestTimeout, atLeast: 2);
    });

    test('yy caps the api read and its form post', () async {
      final requests = await _capture((http) async {
        final transport = YyHttp(http as LiveHttp);
        await transport.get(Uri.parse('https://apigame.yy.com/api/x'));
        await transport.postText(Uri.parse('https://apigame.yy.com/api/y'), body: 'a=1');
      });
      _expectCapped(requests, YyEndpoints.requestTimeout, atLeast: 2);
    });

    test('every cap in the table is the same documented wait', () {
      for (final cap in [
        BilibiliEndpoints.requestTimeout,
        DouyinEndpoints.requestTimeout,
        DouyuEndpoints.requestTimeout,
        KuaishouEndpoints.requestTimeout,
        SoopEndpoints.requestTimeout,
        TwitchEndpoints.requestTimeout,
        YyEndpoints.requestTimeout,
      ]) {
        expect(cap, const Duration(seconds: 20), reason: 'one number, so a stall reads the same everywhere');
      }
    });
  });
}
