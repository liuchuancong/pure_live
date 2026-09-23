import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/danmaku/kick_danmaku.dart';
import 'package:pure_live/core/site/kick/kick_api.dart';
import 'package:pure_live/core/site/kick/kick_site.dart';
import 'package:pure_live/modules/multiview/danmaku/multiview_danmaku_session.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  test('Kick chatroom ID is resolved from the channel response, not channel ID', () async {
    final calls = <Uri>[];
    final api = KickApi(
      request: (uri, _) async {
        calls.add(uri);
        return (
          status: 200,
          body: jsonEncode({
            'slug': 'fixture',
            'id': 676,
            'chatroom': {'id': 668},
          }),
        );
      },
    );
    expect(await api.chatroomId('fixture'), 668);
    expect(calls.single.path, '/api/v2/channels/fixture');
    expect((KickSite(api: api).getDanmaku()), isA<KickDanmaku>());
    expect(MultiviewDanmakuSession.isSupportedPlatform('kick'), isTrue);
  });

  test('Kick room detail carries its chat identity into the playback session', () async {
    final api = KickApi(
      request: (_, _) async => (
        status: 200,
        body: jsonEncode({
          'id': 676,
          'slug': 'fixture',
          'user': {'username': 'fixture'},
          'livestream': null,
        }),
      ),
    );
    final room = await KickSite(api: api).getRoomDetailForRefresh(roomId: 'fixture', platform: 'kick');
    expect(room.danmakuData, 'fixture');
  });

  test('Kick engine subscribes before ready, delivers chat and releases socket', () async {
    final api = KickApi(
      request: (_, _) async => (
        status: 200,
        body: jsonEncode({
          'slug': 'fixture',
          'chatroom': {'id': 668},
        }),
      ),
    );
    final socket = _FakeChannel();
    final engine = KickDanmaku(
      api: api,
      connector: (endpoint, {connectTimeout, protocols, headers, customClient}) {
        expect(endpoint, KickDanmaku.endpoint);
        return socket;
      },
    );
    var ready = 0;
    final messages = <String>[];
    engine.onReady = () => ready++;
    engine.onMessage = (message) => messages.add(message.message);
    await engine.start('fixture');
    expect(engine.isConnected, isFalse);
    expect(jsonDecode(socket.sent.single)['event'], 'pusher:subscribe');
    expect(jsonDecode(socket.sent.single)['data']['channel'], 'chatrooms.668.v2');
    socket.incoming.add(
      jsonEncode({'event': 'pusher_internal:subscription_succeeded', 'channel': 'chatrooms.668.v2', 'data': '{}'}),
    );
    await Future<void>.delayed(Duration.zero);
    expect(engine.isConnected, isTrue);
    expect(ready, 1);
    socket.incoming.add(jsonEncode({'event': 'pusher:ping', 'data': {}}));
    socket.incoming.add(
      jsonEncode({
        'event': r'App\Events\ChatMessageEvent',
        'channel': 'chatrooms.668.v2',
        'data': jsonEncode({
          'id': 'msg-1',
          'chatroom_id': 668,
          'content': 'hello',
          'sender': {'id': 1, 'username': 'viewer'},
        }),
      }),
    );
    await Future<void>.delayed(Duration.zero);
    expect(jsonDecode(socket.sent.last)['event'], 'pusher:pong');
    expect(messages, ['hello']);
    await engine.stop();
    expect(engine.isConnected, isFalse);
    expect(socket.closed, isTrue);
  });

  test('Kick missing or mismatched chatroom identity fails rather than guessing', () async {
    for (final body in [
      {
        'slug': 'other',
        'chatroom': {'id': 668},
      },
      {'slug': 'fixture', 'id': 676},
      {
        'slug': 'fixture',
        'chatroom': {'id': 0},
      },
    ]) {
      final api = KickApi(request: (_, _) async => (status: 200, body: jsonEncode(body)));
      expect(api.chatroomId('fixture'), throwsA(isA<KickException>()));
    }
  });

  test('Pusher ack, ping and current chat message are scoped to chatroom', () {
    final ack = KickDanmaku.parseFrame(
      jsonEncode({'event': 'pusher_internal:subscription_succeeded', 'channel': 'chatrooms.668.v2', 'data': '{}'}),
      668,
    );
    expect(ack.subscribed, isTrue);
    expect(KickDanmaku.parseFrame(jsonEncode({'event': 'pusher:ping', 'data': {}}), 668).ping, isTrue);

    final message = {
      'id': 'abc-123',
      'chatroom_id': 668,
      'content': 'hello world',
      'type': 'message',
      'created_at': '2025-01-01T00:00:00Z',
      'sender': {
        'id': 9999,
        'username': 'hello_kiko',
        'identity': {'color': '#FF0000', 'badges': []},
      },
    };
    String frame(String channel) =>
        jsonEncode({'event': r'App\Events\ChatMessageEvent', 'channel': channel, 'data': jsonEncode(message)});
    final parsed = KickDanmaku.parseFrame(frame('chatrooms.668.v2'), 668).message;
    expect(parsed?.messageId, 'abc-123');
    expect(parsed?.userName, 'hello_kiko');
    expect(parsed?.userId, '9999');
    expect(parsed?.message, 'hello world');
    expect(parsed?.color.toString(), '#ff0000');
    expect(parsed?.sentAt?.toUtc().toIso8601String(), '2025-01-01T00:00:00.000Z');
    expect(KickDanmaku.parseFrame(frame('chatrooms.676.v2'), 668).message, isNull);
    message['chatroom_id'] = 676;
    expect(KickDanmaku.parseFrame(frame('chatrooms.668.v2'), 668).message, isNull);
  });

  test('legacy chat shape, malformed payload and non-chat events stay isolated', () {
    final legacy = KickDanmaku.parseFrame(
      jsonEncode({
        'event': r'App\Events\ChatMessageSentEvent',
        'channel': 'chatrooms.668.v2',
        'data': jsonEncode({
          'message': {'id': 'old-1', 'message': 'legacy', 'chatroom_id': '668', 'created_at': 1677379978},
          'user': {'id': 21, 'username': 'viewer'},
        }),
      }),
      668,
    );
    expect(legacy.message?.message, 'legacy');
    expect(legacy.message?.messageId, 'old-1');
    expect(legacy.message?.sentAt?.year, 2023);
    expect(KickDanmaku.parseFrame('{bad json', 668).message, isNull);
    expect(KickDanmaku.parseFrame(jsonEncode({'event': 'Other', 'channel': 'chatrooms.668.v2'}), 668).message, isNull);
  });
}

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
