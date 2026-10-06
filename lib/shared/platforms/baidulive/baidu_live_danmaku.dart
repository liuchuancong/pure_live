import 'dart:async';
import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:typed_data';

import 'package:pure_live/core/index.dart';
import 'package:pure_live/core/logging/core_log.dart';
import 'package:pure_live/core/models/live_message.dart';
import 'package:pure_live/core/network/http_client.dart';
import 'package:pure_live/shared/platforms/live_danmaku.dart';

class BaiduLiveDanmakuArgs {
  const BaiduLiveDanmakuArgs({
    required this.chatListUrl,
    this.reliableListUrl = '',
    this.hostListUrl = '',
    this.pollInterval = const Duration(seconds: 5),
    this.roomId = '',
  });

  final String chatListUrl;

  final String reliableListUrl;

  final String hostListUrl;

  final Duration pollInterval;

  final String roomId;
}

class BaiduLiveDanmaku extends LiveDanmaku {
  BaiduLiveDanmaku();

  var _args = const BaiduLiveDanmakuArgs(chatListUrl: '');
  var _generation = 0;
  var _running = false;

  final Set<String> _seen = <String>{};
  final Map<String, int> _failures = <String, int>{};

  @override
  Future start(dynamic args) async {
    if (args is! BaiduLiveDanmakuArgs || args.chatListUrl.trim().isEmpty) {
      onClose?.call('百度直播：没有可用的弹幕列表');
      return;
    }
    _args = args;
    _generation++;
    final generation = _generation;
    _running = true;
    _seen.clear();
    _failures.clear();
    unawaited(_loop(generation));
  }

  @override
  Future stop() async {
    _running = false;
    _generation++;
    markDisconnected();
  }

  Future<void> _loop(int generation) async {
    while (_running && generation == _generation) {
      try {
        final segments = await _pollOnce(generation);
        if (segments) {
          if (!isConnected) {
            markConnected();
            onReady?.call();
          }
        }
      } catch (error) {
        if (generation != _generation) return;
        CoreLog.error('Baidu Live chat poll failed: $error');
        onReconnect?.call('百度直播弹幕拉取失败，正在重试');
      }
      if (!_running || generation != _generation) return;
      await Future<void>.delayed(_args.pollInterval);
    }
  }

  Future<bool> _pollOnce(int generation) async {
    var answered = false;
    for (final url in <String>[_args.chatListUrl, _args.reliableListUrl, _args.hostListUrl]) {
      if (url.trim().isEmpty) continue;
      final ok = await _pollList(url, generation, tolerateNotFound: url == _args.hostListUrl);
      answered = answered || ok;
      if (!_running || generation != _generation) return answered;
    }
    return answered;
  }

  Future<bool> _pollList(String listUrl, int generation, {required bool tolerateNotFound}) async {
    final Uint8List playlistBytes;
    try {
      playlistBytes = await HttpClient.instance.getBytes(listUrl, header: _headers(listUrl));
    } catch (error) {
      if (tolerateNotFound) return false;
      rethrow;
    }
    final text = utf8.decode(playlistBytes, allowMalformed: true);
    if (!text.startsWith('#EXTM3U')) {
      return false;
    }
    final base = Uri.tryParse(listUrl);
    if (base == null) return false;
    for (final line in const LineSplitter().convert(text)) {
      final value = line.trim();
      if (value.isEmpty || value.startsWith('#')) continue;
      final segment = base.resolve(value).toString();
      if (_seen.contains(segment)) continue;
      _seen.add(segment);
      if (_seen.length > 512) _seen.remove(_seen.first);
      await _fetchSegment(segment, generation);
      if (!_running || generation != _generation) return true;
    }
    return true;
  }

  Future<void> _fetchSegment(String segment, int generation) async {
    try {
      final bytes = await HttpClient.instance.getBytes(segment, header: _headers(segment));
      if (generation != _generation) return;
      _failures.remove(segment);
      _decodeSegment(_gunzip(bytes));
    } catch (error) {
      final attempts = (_failures[segment] ?? 0) + 1;
      _failures[segment] = attempts;
      if (attempts >= 3) _seen.remove(segment);
      CoreLog.error('Baidu Live chat segment failed: $error');
    }
  }

  static Uint8List _gunzip(Uint8List bytes) {
    var result = bytes;
    for (var layer = 0; layer < 2; layer++) {
      if (result.length < 2 || result[0] != 0x1f || result[1] != 0x8b) break;
      try {
        result = Uint8List.fromList(gzip.decode(result));
      } catch (_) {
        break;
      }
    }
    return result;
  }

  void _decodeSegment(Uint8List bytes) {
    final Object? root;
    try {
      root = json.decode(utf8.decode(bytes, allowMalformed: true));
    } catch (_) {
      return;
    }
    if (root is! Map) return;
    final list = root['list'];
    if (list is! List) return;
    for (final entry in list) {
      if (entry is! Map) continue;
      final messages = entry['messages'];
      if (messages is! List) continue;
      for (final message in messages) {
        if (message is! Map) continue;
        final decoded = _decodeMessage(message);
        if (decoded != null) onMessage?.call(decoded);
      }
    }
  }

  LiveMessage? _decodeMessage(Map<dynamic, dynamic> message) {
    if (_int(message['type']) != 0) return null;
    final msgId = _int(message['msgid']);
    final createTime = _int(message['create_time']);
    final sentAt = createTime == null || createTime <= 0
        ? null
        : DateTime.fromMillisecondsSinceEpoch(createTime * 1000);
    final messageId = msgId == null ? '' : '$msgId';
    final content = _jsonObject(message['content']);
    if (content == null) return null;
    final fromUser = _jsonObject(message['from_user']) ?? const <String, dynamic>{};
    final userId = _text(fromUser['uid']) ?? '';
    final userName = _text(fromUser['uname']) ?? _text(fromUser['name']) ?? '';

    final type = _text(content['type']) ?? '';
    if (type == '101') {
      final count = _int(_jsonObject(content['data'])?['onlineusercnt']);
      if (count == null || count < 0) return null;
      return LiveMessage(
        type: LiveMessageType.online,
        data: LiveAudienceUpdate(kind: LiveAudienceMetricKind.onlineViewers, value: count),
        color: LiveMessageColor.white,
        message: '',
        userName: '',
      );
    }
    if (type == '107') {
      final gift = _decodeGift(content, userId: userId, userName: userName, messageId: messageId, sentAt: sentAt);
      if (gift != null) return gift;
    }
    final text = _chatText(content);
    if (text == null) return null;
    return LiveMessage(
      type: LiveMessageType.chat,
      userName: userName.isEmpty ? '百度用户' : userName,
      userId: userId,
      message: text,
      messageId: messageId,
      sentAt: sentAt,
      color: LiveMessageColor.white,
    );
  }

  static String? _chatText(Map<String, dynamic> content) {
    final body = _jsonObject(content['message_body']);
    final type = _text(content['message_type']);
    String? text;
    switch (type) {
      case '0':
        text = _text(content['content']);
        break;
      case '3':
        text = _text(_jsonObject(body?['link'])?['title']);
        break;
      case '1':
      case '2':
      case '4':
      case '5':
        return null;
      default:
        text = _text(content['content']);
    }
    final atName = _text(content['at_name']);
    if (atName != null && atName.trim().isNotEmpty && _text(content['at_message_type']) == '0') {
      final own = _text(_jsonObject(body?['txt'])?['word']);
      if (own != null && own.trim().isNotEmpty) text = own;
    }
    text ??= _text(_jsonObject(body?['txt'])?['word']);
    if (text == null) return null;
    final trimmed = text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  LiveMessage? _decodeGift(
    Map<String, dynamic> content, {
    required String userId,
    required String userName,
    required String messageId,
    required DateTime? sentAt,
  }) {
    final service = _jsonObject(content['service_info']);
    if (service == null) return null;
    final roomId = _text(service['room_id']);
    if (_args.roomId.isNotEmpty && roomId != null && roomId.isNotEmpty && roomId != _args.roomId) return null;
    final payload = _jsonObject(service['content']);
    if (payload == null) return null;
    final name = _text(payload['gift_name']);
    if (name == null || name.trim().isEmpty) return null;
    final count = _int(payload['gift_count']);
    final gift = BaiduLiveGift(
      id: _text(payload['gift_id']) ?? '',
      name: name.trim(),
      count: count != null && count > 0 ? count : 1,
      isFree: _int(payload['is_free']) == 1,
      url: _text(payload['gift_url']) ?? '',
    );
    return LiveMessage(
      type: LiveMessageType.gift,
      userName: _text(service['user_name']) ?? userName,
      userId: _text(service['user_id']) ?? userId,
      message: '${gift.name} ×${gift.count}',
      messageId: messageId,
      sentAt: sentAt,
      color: LiveMessageColor.white,
      data: gift,
    );
  }

  static Map<String, String> _headers(String url) => <String, String>{
    'Accept': 'application/json, text/plain, */*',
    'Origin': 'https://live.baidu.com',
    if (url.startsWith('http')) 'Referer': 'https://live.baidu.com/',
  };

  static Map<String, dynamic>? _jsonObject(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String) {
      final text = value.trim();
      if (text.isEmpty || (!text.startsWith('{') && !text.startsWith('['))) return null;
      try {
        final decoded = json.decode(text);
        return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static String? _text(Object? value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is num || value is bool) return '$value';
    return null;
  }

  static int? _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }
}

class BaiduLiveGift {
  const BaiduLiveGift({required this.id, required this.name, required this.count, this.isFree = false, this.url = ''});

  final String id;
  final String name;
  final int count;
  final bool isFree;
  final String url;
}
