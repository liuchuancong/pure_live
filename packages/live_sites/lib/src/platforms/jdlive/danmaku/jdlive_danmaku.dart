import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart' as crypto;
import 'package:live_sites/src/models/live_gift/live_gift.dart';
import 'package:live_sites/src/models/live_message/live_message.dart';
import 'package:live_sites/src/platforms/jdlive/parsers/jdlive_parser.dart';
import 'package:meta/meta.dart';

/// The chat group's credentials of one `liveauth` handshake: the socket URL
/// (the answer's `liveUrl` and `token`) and, when the answer has one, the key
/// its binary frames are masked with (`msgMaskKey`).
@immutable
final class JdLiveChatAuth {
  /// Creates the credentials.
  const new({required this.socketUrl, this.maskKey});

  /// `<liveUrl>?token=<token>`: the token is good for one socket.
  final Uri socketUrl;

  /// `msgMaskKey`, or null when the answer has none (the guest answers
  /// recorded so far: their frames are plain text).
  final String? maskKey;
}

/// What one pushed frame says.
@immutable
final class JdLiveDanmakuFrame {
  /// Creates the result.
  const new({this.messages = const [], this.ended = false});

  /// A frame that says nothing this client reports.
  static const JdLiveDanmakuFrame none = JdLiveDanmakuFrame();

  /// Chat or audience, in order.
  final List<LiveMessage> messages;

  /// `stop_live_broadcast`: the broadcast ended (the server stops pushing and
  /// closes the socket later).
  final bool ended;
}

/// JD Live's chat: the website's guest `liveauth` and its socket, without I/O.
///
/// - A handshake first POSTs `liveauth` (no h5st signature): the form's `body`
///   holds the website's app id and, as `content`, a JSON object naming the
///   broadcast as the chat group, AES-128-CBC encrypted with the key and IV
///   written in the page script. The answer gives the socket's address and a
///   token that opens one socket.
/// - The client sends nothing on the socket: the website's join frame only
///   announces a visitor and is not needed to receive the room.
/// - The server pushes JSON text: `get_statistics_result` (the audience) and
///   `chat_group_message` events, whose `body.type` says what happened. Chat
///   is `viewer_send_message` and `anchor_send_message`.
///
/// The handshake itself is run by the site (it owns the transport); this
/// class only shapes the request and reads the answer. A per-metric audience
/// update counts as one [LiveAudienceUpdate] here (`current_viewer` as
/// `onlineViewers`, `total_viwer` as `watching`).
abstract final class JdLiveDanmakuProtocol {
  /// Where `liveauth` is asked (the page's API host).
  static Uri get authUrl => Uri.https(JdLiveParser.apiHost, '/api');

  /// The page's app id (`appId`), in the form's `body` and the content.
  static const String appId = 'jd.mall';

  /// The page's appid form field.
  static const String formAppid = 'h5-live';

  /// The page's key (`secretKey`): sent in the content and, as UTF-8, the
  /// AES key that encrypts it.
  static const String secretKey = 'RYm2dMPMWD9AxYFk';

  /// The page's IV (`pyl`), as UTF-8.
  static const String iv = '0102030405060708';

  /// `loginType` of the page in a browser.
  static const String loginType = '2';

  /// `origin` of the content: the page's default when its link names none.
  static const int origin = -100;

  /// The name the website's chat list gives the streamer's own messages.
  static const String anchorName = '主播';

  /// Silence after which the socket is replaced. The server drops a socket
  /// after 180 s without a frame; 200 s catches a half-open one the server's
  /// close never reached.
  static const Duration silenceTimeout = Duration(seconds: 200);

  /// Headers of `liveauth`: the site's API headers and the page's form type.
  static Map<String, String> get authHeaders => {
    ...JdLiveParser.apiHeaders,
    'content-type': 'application/x-www-form-urlencoded',
  };

  /// Handshake headers: the website's origin and the desktop user agent.
  static Map<String, String> get socketHeaders => {
    'origin': JdLiveParser.webOrigin,
    'user-agent': JdLiveParser.apiHeaders['user-agent']!,
  };

  static const int _maxEpochMilliseconds = 8640000000000000;

  /// The JSON the page encrypts for [liveId] (`groupId`), in the page's key
  /// order; [now] is the `timestamp` (ms) and [nonce] its `random`.
  static String content(String liveId, {required DateTime now, required String nonce}) => jsonEncode({
    'appId': appId,
    'secretKey': secretKey,
    'groupId': liveId,
    'clientType': 'm',
    'timestamp': now.millisecondsSinceEpoch,
    'origin': origin,
    'encryptPin': true,
    'random': nonce,
  });

  /// [content] encrypted as the page does: AES-128-CBC with PKCS#7 padding,
  /// Base64.
  static Future<String> encrypt(String content) async {
    final box = await _aes.encrypt(
      utf8.encode(content),
      secretKey: crypto.SecretKey(utf8.encode(secretKey)),
      nonce: utf8.encode(iv),
    );
    return base64Encode(box.cipherText);
  }

  static final crypto.AesCbc _aes = crypto.AesCbc.with128bits(macAlgorithm: crypto.MacAlgorithm.empty);

  /// Six random digits, as the page's `Math.random().toString().slice(-6)`.
  static String nonce(Random random) => [for (var i = 0; i < 6; i++) random.nextInt(10)].join();

  /// The `liveauth` form fields for [liveId]: the app id and the encrypted
  /// [content] in `body`, the clock's milliseconds in `t`.
  static Future<Map<String, String>> liveauthFields(
    String liveId, {
    required DateTime now,
    required String nonce,
  }) async => {
    'loginType': loginType,
    'appid': formAppid,
    'functionId': 'liveauth',
    'body': jsonEncode({'appId': appId, 'content': await encrypt(content(liveId, now: now, nonce: nonce))}),
    't': '${now.millisecondsSinceEpoch}',
  };

  /// The credentials of a `liveauth` answer: `code` 0 and a `data` with a
  /// `wss` `liveUrl` on a `jd.com` host (no query, fragment or user info) and
  /// a `token`. Throws [FormatException] for anything else.
  static JdLiveChatAuth auth(String body, {required int status}) {
    if (status < 200 || status >= 300) throw FormatException('liveauth answered HTTP $status');
    final Object? root;
    try {
      root = jsonDecode(body);
    } on FormatException {
      throw const FormatException('liveauth answered no JSON');
    }
    if (root is! Map) throw const FormatException('liveauth answered no JSON object');
    final data = root['data'];
    if (root['code'] != 0 || data is! Map) {
      final error = data is Map ? data['error'] : null;
      throw FormatException('liveauth refused: ${root['code']} ${root['msg']}${error is String ? ' ($error)' : ''}');
    }
    final address = data['liveUrl'];
    final base = address is String ? Uri.tryParse(address.trim()) : null;
    final token = data['token'];
    if (base == null ||
        !base.isScheme('wss') ||
        !_isJdHost(base.host) ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment ||
        token is! String ||
        token.trim().isEmpty ||
        token.contains(RegExp(r'[\s&#]'))) {
      throw const FormatException('liveauth answered no socket');
    }
    final mask = data['msgMaskKey'];
    return JdLiveChatAuth(
      socketUrl: Uri.parse('$base?token=${token.trim()}'),
      maskKey: mask is String && mask.isNotEmpty ? mask : null,
    );
  }

  static bool _isJdHost(String host) {
    final lower = host.toLowerCase();
    return lower == 'jd.com' || lower.endsWith('.jd.com');
  }

  /// [text] with the socket URL's token left out: `dart:io` names the whole
  /// URL in a failed handshake.
  static String redact(String text) => text.replaceAll(RegExp(r'''(?<=[?&])token=[^&#\s'"]*'''), 'token=…');

  /// One pushed frame of broadcast [liveId]: text, or bytes (XORed with
  /// [maskKey] when the answer gave one, then UTF-8). A frame that is not a
  /// JSON object, an event of another group and every event but the audience,
  /// the two kinds of chat and the end of the broadcast give nothing.
  static JdLiveDanmakuFrame decode(Object? data, {required String liveId, String? maskKey}) {
    final text = switch (data) {
      final String text => text,
      final List<int> bytes => _text(bytes, maskKey),
      _ => null,
    };
    if (text == null) return JdLiveDanmakuFrame.none;
    final Object? root;
    try {
      root = jsonDecode(text);
    } on FormatException {
      return JdLiveDanmakuFrame.none;
    }
    if (root is! Map) return JdLiveDanmakuFrame.none;
    final body = root['body'];
    if (body is! Map || !_sameGroup(body['groupid'], liveId)) return JdLiveDanmakuFrame.none;
    return switch (root['type']) {
      'get_statistics_result' => JdLiveDanmakuFrame(messages: audience(body)),
      'chat_group_message' when body['type'] == 'stop_live_broadcast' => const JdLiveDanmakuFrame(ended: true),
      'chat_group_message' => JdLiveDanmakuFrame(messages: [?chat(root)]),
      _ => JdLiveDanmakuFrame.none,
    };
  }

  /// The bytes of a binary frame as text: XORed with [maskKey]'s code units
  /// (their low bytes, repeated) when there is one, then UTF-8; null when they
  /// are not UTF-8.
  static String? _text(List<int> bytes, String? maskKey) {
    final key = maskKey == null || maskKey.isEmpty ? null : maskKey.codeUnits;
    final plain = key == null
        ? bytes
        : [for (var i = 0; i < bytes.length; i++) (key[i % key.length] ^ bytes[i]) & 0xFF];
    try {
      return utf8.decode(plain);
    } on FormatException {
      return null;
    }
  }

  static bool _sameGroup(Object? group, String liveId) => switch (group) {
    null => true,
    final int number => '$number' == liveId,
    final String text => text.trim() == liveId,
    _ => false,
  };

  /// The audience of a `get_statistics_result` [body] as one update:
  /// `current_viewer` (in the room now) as `onlineViewers`, `total_viwer`
  /// (cumulative) as `watching`. A body with neither says nothing.
  static List<LiveMessage> audience(Map<Object?, Object?> body) {
    final current = _count(body['current_viewer']);
    final total = _count(body['total_viwer']);
    if (current == null && total == null) return const [];
    return [
      LiveMessage(
        type: LiveMessageType.audienceUpdate,
        userName: '',
        message: '',
        data: LiveAudienceUpdate(watching: total, onlineViewers: current),
      ),
    ];
  }

  /// A `chat_group_message` [event] as white chat, or null for any other kind:
  /// `viewer_send_message` names its sender (`body.nickName`),
  /// `anchor_send_message` is [anchorName]; the text is `body.content`,
  /// trimmed; blank or not text gives null. The user id is `from.pinmd5`, the
  /// id `id`, the time `datetime` (ms).
  static LiveMessage? chat(Map<Object?, Object?> event) {
    final body = event['body'];
    if (body is! Map) return null;
    final String name;
    switch (body['type']) {
      case 'viewer_send_message':
        final nick = body['nickName'];
        name = nick is String ? nick.trim() : '';
      case 'anchor_send_message':
        name = anchorName;
      default:
        return null;
    }
    final text = body['content'];
    if (text is! String || text.trim().isEmpty) return null;
    final from = event['from'];
    final user = from is Map ? from['pinmd5'] : null;
    final id = event['id'];
    final time = event['datetime'];
    return LiveMessage(
      type: LiveMessageType.chat,
      userName: name,
      userId: user is String ? user.trim() : '',
      message: text.trim(),
      id: id is String ? id.trim() : null,
      sentAt: time is int && time > 0 && time <= _maxEpochMilliseconds
          ? DateTime.fromMillisecondsSinceEpoch(time)
          : null,
      color: 0xFFFFFF,
    );
  }

  static int? _count(Object? value) {
    final count = switch (value) {
      final int number => number,
      final String text => int.tryParse(text.trim()),
      _ => null,
    };
    return count != null && count >= 0 ? count : null;
  }
}
