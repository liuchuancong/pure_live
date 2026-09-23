import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:html_unescape/html_unescape.dart';
import 'package:pure_live/common/models/live_message.dart';
import 'package:pure_live/core/common/web_socket_util.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

typedef GoodGameChatFrame = ({bool welcome, bool joined, bool error, LiveMessage? message});

/// Guest, read-only implementation of GoodGame's published Chat v2 protocol.
class GoodGameDanmaku extends LiveDanmaku {
  GoodGameDanmaku({this.connector = _connectSocket}) {
    heartbeatTime = 60000;
  }

  static const endpoint = 'wss://chat-1.goodgame.ru/chat2/';
  static final HtmlUnescape _html = HtmlUnescape();

  final WebSocketConnector connector;
  WebScoketUtils? _socket;
  Timer? _joinTimer;
  int _generation = 0;

  static WebSocketChannel _connectSocket(
    String endpoint, {
    Duration? connectTimeout,
    Iterable<String>? protocols,
    Map<String, dynamic>? headers,
    io.HttpClient? customClient,
  }) => IOWebSocketChannel.connect(
    endpoint,
    connectTimeout: connectTimeout,
    protocols: protocols,
    headers: headers,
    customClient: customClient,
  );

  @override
  Future<void> start(dynamic args) async {
    final channel = args?.toString() ?? '';
    final channelId = int.tryParse(channel);
    if (channelId == null || channelId <= 0 || channelId > 0x7fffffff) {
      throw ArgumentError.value(args, 'args', 'GoodGame channel ID is required');
    }
    final generation = ++_generation;
    final previous = _socket;
    _socket = null;
    _joinTimer?.cancel();
    _joinTimer = null;
    markDisconnected();
    await previous?.close();
    if (generation != _generation) return;

    final socket = WebScoketUtils(
      url: endpoint,
      heartBeatTime: heartbeatTime,
      inactivityTimeout: const Duration(minutes: 5),
      connector: connector,
      onReady: () {
        if (generation != _generation) return;
        markDisconnected();
        _joinTimer?.cancel();
        _joinTimer = Timer(const Duration(seconds: 10), () {
          if (generation == _generation && !isConnected) _socket?.reconnect();
        });
      },
      onMessage: (raw) {
        if (generation != _generation) return;
        final frame = parseFrame(raw, channelId);
        if (frame.welcome) {
          _socket?.sendMessage(
            jsonEncode({
              'type': 'join',
              'data': {'channel_id': channel, 'hidden': 0, 'mobile': false, 'reload': false},
            }),
          );
        }
        if (frame.error) {
          markDisconnected();
          _socket?.reconnect();
        }
        if (frame.joined) {
          _joinTimer?.cancel();
          _joinTimer = null;
          markConnected();
          onReady?.call();
        }
        if (isConnected && frame.message != null) onMessage?.call(frame.message!);
      },
      onReconnect: () {
        _joinTimer?.cancel();
        markDisconnected();
        onReconnect?.call('GoodGame chat reconnecting');
      },
      onClose: (reason) {
        _joinTimer?.cancel();
        markDisconnected();
        onClose?.call('GoodGame chat connection failed: $reason');
      },
    );
    _socket = socket;
    await socket.connect();
  }

  @override
  Future<void> stop() async {
    ++_generation;
    _joinTimer?.cancel();
    _joinTimer = null;
    final socket = _socket;
    _socket = null;
    markDisconnected();
    onMessage = null;
    onReady = null;
    onReconnect = null;
    onClose = null;
    await socket?.close();
  }

  static GoodGameChatFrame parseFrame(Object? raw, int channelId) {
    const ignored = (welcome: false, joined: false, error: false, message: null);
    if (raw is! String || raw.length > 16 * 1024) return ignored;
    try {
      final envelope = _object(jsonDecode(raw));
      if (envelope == null) return ignored;
      final type = envelope['type'];
      final data = _object(envelope['data']);
      if (type == 'welcome') {
        return data?['protocolVersion'] == 2 ? (welcome: true, joined: false, error: false, message: null) : ignored;
      }
      if (data == null || int.tryParse(data['channel_id']?.toString() ?? '') != channelId) return ignored;
      if (type == 'success_join') return (welcome: false, joined: true, error: false, message: null);
      if (type == 'error') return (welcome: false, joined: false, error: true, message: null);
      if (type != 'message') return ignored; // Historical and private messages are not live room chat.

      final text = data['text'];
      final name = data['user_name'];
      if (text is! String || name is! String || text.isEmpty || text.length > 4096 || name.trim().isEmpty) {
        return ignored;
      }
      final timestamp = int.tryParse(data['timestamp']?.toString() ?? '');
      final messageId = data['message_id']?.toString() ?? '';
      final userId = data['user_id']?.toString() ?? '';
      return (
        welcome: false,
        joined: false,
        error: false,
        message: LiveMessage(
          type: LiveMessageType.chat,
          userName: name.trim(),
          userId: userId,
          message: _html.convert(text),
          messageId: messageId,
          sentAt: timestamp == null ? null : DateTime.fromMillisecondsSinceEpoch(timestamp * 1000),
          color: LiveMessageColor.white,
        ),
      );
    } catch (_) {
      return ignored;
    }
  }

  static Map<String, dynamic>? _object(Object? value) {
    if (value is! Map) return null;
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
}
