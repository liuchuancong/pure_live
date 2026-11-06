import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:live_net/live_net.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/platforms/bilibili/api/bilibili_http.dart';
import 'package:live_sites/src/platforms/bilibili/bilibili_site.dart';
import 'package:live_sites/src/platforms/bilibili/danmaku/bilibili_danmaku_codec.dart';
import 'package:live_sites/src/platforms/bilibili/danmaku/bilibili_danmaku_session.dart';
import 'package:test/test.dart';

// Platform-internal code: constructor-name rules that govern the public
// surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// The room and credentials the tests join; the port is filled in by the
/// local server.
BilibiliDanmakuArgs _args(Uri endpoint, {String token = 'tok1', Future<BilibiliDanmakuArgs> Function()? refresh}) =>
    BilibiliDanmakuArgs(
      longId: '23058',
      uid: 0,
      token: token,
      servers: [endpoint],
      buvid: 'buvid3-test',
      headers: const {'user-agent': 'test'},
      refresh: refresh,
    );

/// One connection the local server accepted.
final class _Link {
  _Link(this.socket);

  final WebSocket socket;

  /// What the test answers with once this connection's auth packet arrives.
  void Function(_Link link)? onAuth;

  /// The bodies of the op 7 and op 2 packets the client wrote, in order.
  final List<Map<String, dynamic>> auths = [];
  int heartbeats = 0;

  void read(Object? data) {
    if (data is! List<int>) return;
    final bytes = Uint8List.fromList(data);
    final view = ByteData.sublistView(bytes);
    var offset = 0;
    while (offset + 16 <= bytes.length) {
      final length = view.getUint32(offset);
      final operation = view.getUint32(offset + 8);
      final body = utf8.decode(bytes.sublist(offset + 16, offset + length), allowMalformed: true);
      if (operation == BilibiliDanmakuProtocol.opAuth) {
        auths.add(jsonDecode(body) as Map<String, dynamic>);
        onAuth?.call(this);
      }
      if (operation == BilibiliDanmakuProtocol.opHeartbeat) heartbeats++;
      offset += length;
    }
  }

  /// Answers with [code] as the auth reply.
  void acceptOrReject(int code) =>
      socket.add(BilibiliDanmakuProtocol.packet(BilibiliDanmakuProtocol.opAuthReply, '{"code":$code}'));

  Future<void> close() => socket.close();
}

/// A local stand-in for Bilibili's broadcast gateway: it upgrades every
/// connection, hands each [_Link] to [onLink], and the test drives the
/// protocol from there.
Future<HttpServer> _gateway(void Function(_Link link) onLink) async {
  final server = await HttpServer.bind('127.0.0.1', 0);
  server.listen((request) async {
    final socket = await WebSocketTransformer.upgrade(request);
    final link = _Link(socket);
    onLink(link);
    socket.listen(link.read);
  });
  return server;
}

/// The session with its event log; [connect] starts the room.
final class _Room {
  _Room(this.session) {
    subscription = session.events.listen(seen.add, onDone: closed.complete);
  }

  final BilibiliDanmakuSession session;
  late final StreamSubscription<LiveMessage> subscription;
  final seen = <LiveMessage>[];
  final closed = Completer<void>();

  Future<LiveSiteError?> connect() => session.connect();

  List<LiveMessage> get system => seen.where((message) => message.type == LiveMessageType.system).toList();

  Future<void> dispose() async {
    await subscription.cancel();
    await session.dispose();
  }
}

/// Waits until [probe] is true, failing at the cap.
Future<void> _until(bool Function() probe, {String because = ''}) async {
  for (var waited = 0; waited < 50; waited++) {
    if (probe()) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  fail('condition never held $because');
}

void main() {
  test('a join is the auth packet, and the acceptance starts the beat at once', () async {
    final links = <_Link>[];
    final server = await _gateway(links.add);
    final room = _Room(BilibiliDanmakuSession(args: _args(Uri.parse('ws://127.0.0.1:${server.port}'))));
    try {
      expect(await room.connect(), isNull);
      await _until(() => links.isNotEmpty && links.first.auths.isNotEmpty);
      final auth = links.first.auths.single;
      expect(auth['roomid'], 23058);
      expect(auth['uid'], 0);
      expect(auth['key'], 'tok1');
      expect(auth['buvid'], 'buvid3-test');
      links.first.acceptOrReject(0);
      await _until(() => links.first.heartbeats >= 1);
      expect(room.system, isEmpty);
    } finally {
      await room.dispose();
      await server.close(force: true);
    }
  });

  test('a rejected auth brings fresh credentials and joins with them', () async {
    final links = <_Link>[];
    final server = await _gateway(links.add);
    var refreshes = 0;
    final room = _Room(
      BilibiliDanmakuSession(
        args: _args(
          Uri.parse('ws://127.0.0.1:${server.port}'),
          refresh: () async {
            refreshes++;
            return _args(Uri.parse('ws://127.0.0.1:${server.port}'), token: 'tok2');
          },
        ),
      ),
    );
    try {
      expect(await room.connect(), isNull);
      await _until(() => links.isNotEmpty && links.first.auths.isNotEmpty);
      expect(links.first.auths.single['key'], 'tok1');
      links.first.acceptOrReject(-3);
      await _until(() => links.length >= 2 && links[1].auths.isNotEmpty, because: 'the fresh join never arrived');
      expect(refreshes, 1, reason: 'one rejection costs one refresh');
      expect(links[1].auths.single['key'], 'tok2', reason: 'the new token is the one joined with');
      links[1].acceptOrReject(0);
      await _until(() => links[1].heartbeats >= 1);
      expect(room.system, isEmpty, reason: 'the room never learns of a refused token');
    } finally {
      await room.dispose();
      await server.close(force: true);
    }
  });

  test('after the refresh budget the rejected room is given up on, named as such', () async {
    final server = await _gateway((link) => link.onAuth = (link) => link.acceptOrReject(-3));
    var refreshes = 0;
    // The credentials the site hands out always carry their own refresh, so
    // every round can ask again until the budget is spent.
    Future<BilibiliDanmakuArgs> next() async {
      refreshes++;
      return _args(Uri.parse('ws://127.0.0.1:${server.port}'), token: 'tok$refreshes', refresh: next);
    }

    final room = _Room(BilibiliDanmakuSession(args: _args(Uri.parse('ws://127.0.0.1:${server.port}'), refresh: next)));
    try {
      expect(await room.connect(), isNull);
      await room.closed.future.timeout(const Duration(seconds: 15));
      expect(refreshes, BilibiliDanmakuSession.maxCredentialRefreshes);
      expect(room.system, hasLength(1));
      expect(room.system.single.text, contains('auth rejected'));
      expect(room.system.single.text, contains('credentials unavailable'));
    } finally {
      await room.dispose();
      await server.close(force: true);
    }
  });

  test('a refresh that fails ends the session the same way', () async {
    final server = await _gateway((link) => link.onAuth = (link) => link.acceptOrReject(-3));
    var refreshes = 0;
    final room = _Room(
      BilibiliDanmakuSession(
        args: _args(
          Uri.parse('ws://127.0.0.1:${server.port}'),
          refresh: () async {
            refreshes++;
            throw StateError('site is down');
          },
        ),
      ),
    );
    try {
      expect(await room.connect(), isNull);
      await room.closed.future.timeout(const Duration(seconds: 15));
      expect(refreshes, 1);
      expect(room.system.single.text, contains('credentials unavailable'));
    } finally {
      await room.dispose();
      await server.close(force: true);
    }
  });

  test('the site wires the refresh: it fetches a new token when asked', () async {
    final asked = <Uri>[];
    final site = BilibiliSite(http: BilibiliHttp(_ScriptedHttp(asked)), loginCookie: () => '', sleep: (_) async {});
    final args = await site.danmakuArgs('23058', maxAttempts: 1);
    final refreshed = await args.refresh?.call();
    expect(refreshed, isNotNull);
    expect(refreshed!.token, 'fresh-token');
    expect(refreshed.uid, 0);
    expect(asked.where((uri) => uri.path.endsWith('getDanmuInfo')), hasLength(2));
  });
}

/// The transport the wired-refresh case reads: the session prelude (guest
/// buvid, WBI keys) and every `getDanmuInfo`, each with the answer its path
/// asks for.
final class _ScriptedHttp implements LiveHttp {
  _ScriptedHttp(this.asked);

  final List<Uri> asked;

  static String _json(Object data) => jsonEncode({'code': 0, 'data': data});

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    asked.add(request.url);
    final body = switch (request.url.path) {
      '/x/frontend/finger/spi' => _json({'b_3': 'b3-guest', 'b_4': 'b4-guest'}),
      '/x/web-interface/nav' => _json({
        'wbi_img': {
          'img_url': 'https://i0.hdslb.com/bfs/wbi/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.png',
          'sub_url': 'https://i0.hdslb.com/bfs/wbi/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.png',
        },
      }),
      final path when path.endsWith('getDanmuInfo') => _json({
        'token': 'fresh-token',
        'host_list': [
          {'host': 'broadcastlv-chat.chat.bilibili.com', 'wss_port': 443},
        ],
      }),
      _ => throw StateError('the test answers no ${request.url.path}'),
    };
    return LiveResponse(statusCode: 200, headers: const {}, bodyBytes: utf8.encode(body));
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) => throw UnimplementedError();

  @override
  void close() {}
}
