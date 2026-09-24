import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/danmaku/goodgame_danmaku.dart';
import 'package:pure_live/core/site/goodgame/goodgame_api.dart';
import 'package:pure_live/core/site/goodgame/goodgame_site.dart';
import 'package:pure_live/modules/multiview/danmaku/multiview_danmaku_session.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  test('GoodGame room carries numeric chat channel ID while retaining its stable slug', () async {
    final api = GoodGameApi(
      request: (uri, _, _) async {
        expect(uri.path, '/api/4/users/fixture/stream');
        return (
          status: 200,
          body: jsonEncode({
            'id': 15365,
            'channelkey': 'fixture',
            'streamer': {'username': 'fixture'},
            'online': false,
          }),
        );
      },
    );
    final site = GoodGameSite(api: api);
    final room = await site.getRoomDetailForRefresh(roomId: 'fixture', platform: 'goodgame');
    expect(room.roomId, 'fixture');
    expect(room.danmakuData, '15365');
    expect(site.getDanmaku(), isA<GoodGameDanmaku>());
    expect(MultiviewDanmakuSession.supportsRoom(room), isTrue);
  });

  test('GoodGame guest protocol waits for welcome and join acknowledgement', () async {
    final socket = _FakeChannel();
    final engine = GoodGameDanmaku(
      connector: (endpoint, {connectTimeout, protocols, headers, customClient}) {
        expect(endpoint, GoodGameDanmaku.endpoint);
        return socket;
      },
    );
    var ready = 0;
    final messages = <String>[];
    engine.onReady = () => ready++;
    engine.onMessage = (message) => messages.add(message.message);
    await engine.start('15365');
    expect(engine.isConnected, isFalse);
    expect(socket.sent, isEmpty);
    socket.incoming.add(
      jsonEncode({
        'type': 'welcome',
        'data': {'protocolVersion': 2},
      }),
    );
    await Future<void>.delayed(Duration.zero);
    expect(jsonDecode(socket.sent.single)['type'], 'join');
    expect(jsonDecode(socket.sent.single)['data']['channel_id'], '15365');
    expect(engine.isConnected, isFalse);
    socket.incoming.add(
      jsonEncode({
        'type': 'success_join',
        'data': {'channel_id': '15365'},
      }),
    );
    await Future<void>.delayed(Duration.zero);
    expect(engine.isConnected, isTrue);
    expect(ready, 1);
    socket.incoming.add(_message(15365));
    await Future<void>.delayed(Duration.zero);
    expect(messages, ['Привет & hello']);
    await engine.stop();
    expect(engine.isConnected, isFalse);
    expect(socket.closed, isTrue);
  });

  test('GoodGame parser isolates other rooms and excludes history/private messages', () {
    expect(GoodGameDanmaku.parseFrame(_message(15365), 15365).message?.messageId, '1693043578692');
    expect(GoodGameDanmaku.parseFrame(_message(15365), 15365).message?.userId, '162675');
    expect(GoodGameDanmaku.parseFrame(_message(15365), 15365).message?.sentAt?.year, 2023);
    expect(GoodGameDanmaku.parseFrame(_message(15365), 5).message, isNull);
    expect(GoodGameDanmaku.parseFrame(_message(5), 15365).message, isNull);
    expect(
      GoodGameDanmaku.parseFrame(
        jsonEncode({
          'type': 'channel_history',
          'data': {'channel_id': '15365'},
        }),
        15365,
      ).message,
      isNull,
    );
    expect(
      GoodGameDanmaku.parseFrame(
        jsonEncode({
          'type': 'private_message',
          'data': {'channel_id': '15365'},
        }),
        15365,
      ).message,
      isNull,
    );
    expect(GoodGameDanmaku.parseFrame('{invalid', 15365).message, isNull);
    expect(
      GoodGameDanmaku.parseFrame(
        jsonEncode({
          'type': 'welcome',
          'data': {'protocolVersion': 1},
        }),
        15365,
      ).welcome,
      isFalse,
    );
  });

  test('GoodGame rejects invalid channel identity before connecting', () async {
    final engine = GoodGameDanmaku(
      connector: (_, {connectTimeout, protocols, headers, customClient}) => throw StateError('must not connect'),
    );
    for (final id in ['0', '-1', 'fixture', '', '2147483648']) {
      await expectLater(engine.start(id), throwsArgumentError);
    }
  });
}

String _message(int channelId) => jsonEncode({
  'type': 'message',
  'data': {
    'channel_id': '$channelId',
    'user_id': 162675,
    'user_name': 'Resmile',
    'message_id': 1693043578692,
    'timestamp': 1693043579,
    'text': 'Привет &amp; hello',
  },
});

class _FakeChannel implements WebSocketChannel {
  final StreamController<dynamic> incoming = StreamController<dynamic>();
  final List<String> sent = [];
  bool closed = false;
  late final WebSocketSink _sink = _FakeSink(sent, () => closed = true);

  @override
  Stream<dynamic> get stream => incoming.stream;
  @override
  WebSocketSink get sink => _sink;
  @override
  Future<void> get ready => Future<void>.value();
  @override
  int? get closeCode => null;
  @override
  String? get closeReason => null;
  @override
  String? get protocol => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSink implements WebSocketSink {
  _FakeSink(this.sent, this.onClose);
  final List<String> sent;
  final void Function() onClose;
  @override
  void add(dynamic data) => sent.add(data as String);
  @override
  Future<void> close([int? closeCode, String? closeReason]) async => onClose();
  @override
  Future<void> get done => Future<void>.value();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
