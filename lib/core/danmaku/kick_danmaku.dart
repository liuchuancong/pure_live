import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:pure_live/common/models/live_message.dart';
import 'package:pure_live/core/common/web_socket_util.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
import 'package:pure_live/core/site/kick/kick_api.dart';
import 'package:pure_live/core/site/kick/kick_link.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

typedef KickPusherFrame = ({bool subscribed, bool ping, bool error, LiveMessage? message});

/// Read-only public chatroom subscription. The channel's numeric ID is not
/// its chatroom ID; the latter is resolved from the current channel response.
class KickDanmaku extends LiveDanmaku {
  KickDanmaku({KickApi? api, this._connector = _connectSocket}) : _api = api ?? KickApi() {
    heartbeatTime = 30000;
  }

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

  static const endpoint =
      'wss://ws-us2.pusher.com/app/32cbd69e4b950bf97679?protocol=7&client=js&version=8.4.0&flash=false';

  final KickApi _api;
  final WebSocketConnector _connector;
  WebScoketUtils? _socket;
  Timer? _subscriptionTimer;
  int _generation = 0;

  @override
  Future<void> start(dynamic args) async {
    final slug = args is String ? KickLink.normalize(args) : null;
    if (slug == null) throw const KickException(KickFailure.identity);
    final generation = ++_generation;
    final previous = _socket;
    _socket = null;
    _subscriptionTimer?.cancel();
    _subscriptionTimer = null;
    markDisconnected();
    await previous?.close();
    if (generation != _generation) return;
    final chatroomId = await _api.chatroomId(slug);
    if (generation != _generation) return;
    final socket = WebScoketUtils(
      url: endpoint,
      heartBeatTime: heartbeatTime,
      connector: _connector,
      onReady: () {
        if (generation != _generation) return;
        markDisconnected();
        _subscriptionTimer?.cancel();
        _socket?.sendMessage(
          jsonEncode({
            'event': 'pusher:subscribe',
            'data': {'auth': '', 'channel': 'chatrooms.$chatroomId.v2'},
          }),
        );
        _subscriptionTimer = Timer(const Duration(seconds: 10), () {
          if (generation == _generation && !isConnected) _socket?.reconnect();
        });
      },
      onMessage: (raw) {
        if (generation != _generation) return;
        final frame = parseFrame(raw, chatroomId);
        if (frame.ping) _socket?.sendMessage(jsonEncode({'event': 'pusher:pong', 'data': {}}));
        if (frame.error) {
          markDisconnected();
          _socket?.reconnect();
        }
        if (frame.subscribed) {
          _subscriptionTimer?.cancel();
          _subscriptionTimer = null;
          markConnected();
          onReady?.call();
        }
        if (isConnected && frame.message != null) onMessage?.call(frame.message!);
      },
      onHeartBeat: () => _socket?.sendMessage(jsonEncode({'event': 'pusher:ping', 'data': {}})),
      onReconnect: () {
        _subscriptionTimer?.cancel();
        markDisconnected();
        onReconnect?.call('Kick chat reconnecting');
      },
      onClose: (message) {
        _subscriptionTimer?.cancel();
        markDisconnected();
        onClose?.call('Kick chat connection failed: $message');
      },
    );
    _socket = socket;
    await socket.connect();
  }

  @override
  Future<void> stop() async {
    ++_generation;
    _subscriptionTimer?.cancel();
    _subscriptionTimer = null;
    final socket = _socket;
    _socket = null;
    markDisconnected();
    onMessage = null;
    onReady = null;
    onReconnect = null;
    onClose = null;
    await socket?.close();
  }

  static KickPusherFrame parseFrame(Object? raw, int chatroomId) {
    const ignored = (subscribed: false, ping: false, error: false, message: null);
    if (raw is! String || raw.length > 128 * 1024) return ignored;
    try {
      final envelope = _object(jsonDecode(raw));
      if (envelope == null) return ignored;
      final event = envelope['event'];
      if (event == 'pusher:ping') return (subscribed: false, ping: true, error: false, message: null);
      if (event == 'pusher:error' || event == 'pusher_internal:subscription_error') {
        return (subscribed: false, ping: false, error: true, message: null);
      }
      if (envelope['channel'] != 'chatrooms.$chatroomId.v2') return ignored;
      if (event == 'pusher_internal:subscription_succeeded') {
        return (subscribed: true, ping: false, error: false, message: null);
      }
      if (event != r'App\Events\ChatMessageEvent' && event != r'App\Events\ChatMessageSentEvent') return ignored;
      final data = envelope['data'];
      final payload = _object(data is String ? jsonDecode(data) : data);
      if (payload == null) return ignored;
      final legacy = _object(payload['message']);
      final message = legacy ?? payload;
      final sender = _object(payload['sender']) ?? _object(payload['user']);
      if (sender == null) return ignored;
      final room = message['chatroom_id'];
      if (room != null && int.tryParse(room.toString()) != chatroomId) return ignored;
      final type = message['type'];
      if (type != null && type != '' && type != 'message' && type != 'reply') return ignored;
      final content = (legacy == null ? message['content'] : message['message'])?.toString().trim() ?? '';
      final userName = sender['username']?.toString().trim() ?? '';
      if (content.isEmpty || content.length > 16000 || userName.isEmpty || userName.length > 256) return ignored;
      final identity = _object(sender['identity']);
      final colorText = identity?['color']?.toString().replaceFirst('#', '') ?? '';
      final color = int.tryParse(colorText, radix: 16);
      final stamp = message['created_at'];
      final sentAt = stamp is int
          ? DateTime.fromMillisecondsSinceEpoch(stamp * 1000)
          : stamp is String
          ? DateTime.tryParse(stamp)
          : null;
      return (
        subscribed: false,
        ping: false,
        error: false,
        message: LiveMessage(
          type: LiveMessageType.chat,
          userName: userName,
          userId: sender['id']?.toString() ?? '',
          message: content,
          messageId: message['id']?.toString() ?? '',
          sentAt: sentAt,
          color: color == null ? LiveMessageColor.white : LiveMessageColor.numberToColor(color),
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
