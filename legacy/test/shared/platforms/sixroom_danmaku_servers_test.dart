import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/network/http_client.dart';
import 'package:pure_live/shared/platforms/sixroom/six_room_danmaku.dart';

/// 实测抓到的响应体：内容是 JSON，mime 报的是 `text/html; charset=UTF-8`。
const String _capturedBody =
    '{"a":[],"b":[],"websock":["snbjg1.6rooms.com:5490","snbjg2.6rooms.com:5490",'
    '"snbjh2.6rooms.com:5490","snbjh1.6rooms.com:5490"]}';

/// 用真实的生产响应头回放这个接口，让 dio 自己的 transformer 决定要不要解码。
final class _TextHtmlJsonAdapter implements HttpClientAdapter {
  _TextHtmlJsonAdapter(this.body);

  final String body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(body, 200, headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>['text/html; charset=UTF-8'],
    });
  }

  @override
  void close({bool force = false}) {}
}

void _serve(String body) {
  final dio = HttpClient.instance.dio;
  final previous = dio.httpClientAdapter;
  dio.httpClientAdapter = _TextHtmlJsonAdapter(body);
  addTearDown(() => dio.httpClientAdapter = previous);
}

void main() {
  group('六间房聊天服务器列表', () {
    test('这个接口的 JSON 是以文本到达的，所以只能自己解', () async {
      // 钉的是踩过的坑本身：dio 只在 JSON mime 下解码，`getJson` 对 `text/html`
      // 返回的是**字符串**。曾经 `_refreshServers` 拿它去问 `is Map`，于是服务器
      // 列表永远是空的，弹幕永远停在"连接失败，正在重试"。
      _serve(_capturedBody);

      final viaJson = await HttpClient.instance.getJson('https://v.6.cn/room/getChat.php');
      expect(viaJson, isA<String>());
      expect(viaJson, isNot(isA<Map>()), reason: 'mime 不是 JSON，dio 不会解码');

      final viaText = await HttpClient.instance.getText('https://v.6.cn/room/getChat.php');
      expect(
        SixRoomDanmaku.parseChatServers(viaText),
        <String>[
          'snbjg1.6rooms.com:5490',
          'snbjg2.6rooms.com:5490',
          'snbjh2.6rooms.com:5490',
          'snbjh1.6rooms.com:5490',
        ],
      );
    });

    test('只收 6rooms.com 的合法 host:port，顺序保留、重复只留一个', () {
      // 端口按主播不同（实测 5490 / 5590 / 5690），列表顺序就是轮询顺序。
      final body = jsonEncode(<String, Object?>{
        'websock': <String>[
          'snbjh2.6rooms.com:5690',
          '6rooms.com:5690',
          'evil.example.com:5690',
          'snbjh2.6rooms.com:5690',
          'snbjg1.6rooms.com:0',
          'snbjg2.6rooms.com:70000',
          'snbjh1.6rooms.com',
          ' SNBJG3.6ROOMS.COM:5690 ',
        ],
      });

      expect(
        SixRoomDanmaku.parseChatServers(body),
        <String>['snbjh2.6rooms.com:5690', '6rooms.com:5690', 'SNBJG3.6ROOMS.COM:5690'],
        reason: '站外主机、越界端口、没有端口、重复项都不能进列表；大小写与空白按原样保留主机名可比对',
      );
    });

    test('坏响应抛出来交给重试，没有 websock 才是空列表', () {
      // 静默返回空列表会让 `_loop` 报"没有取到聊天服务器"，把网关错误伪装成
      // 站点没给服务器；抛出来才会在日志里留下真实原因。
      expect(() => SixRoomDanmaku.parseChatServers('<html>502 Bad Gateway</html>'), throwsA(isA<FormatException>()));
      expect(SixRoomDanmaku.parseChatServers('{"a":[],"b":[]}'), isEmpty);
      expect(SixRoomDanmaku.parseChatServers('{"websock":"snbjg1.6rooms.com:5490"}'), isEmpty);
    });
  });
}
