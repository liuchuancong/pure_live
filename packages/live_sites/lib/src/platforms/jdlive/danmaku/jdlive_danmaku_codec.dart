import 'dart:convert';
import 'dart:math';

import 'package:live_sites/src/common/crypto/aes_cbc.dart';
import 'package:live_sites/src/models/audience/live_audience_update/live_audience_update.dart';
import 'package:live_sites/src/models/enums/live_audience_signal_kind.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/message/message_sender/message_sender.dart';
import 'package:live_sites/src/platforms/jdlive/api/jdlive_endpoints.dart';
import 'package:live_sites/src/platforms/jdlive/parsers/jdlive_failure.dart';
import 'package:live_sites/src/platforms/jdlive/parsers/jdlive_json.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// The chat group's credentials of one handshake: the socket URL (the
/// `liveauth` answer's `liveUrl` and `token`) and, when the answer has one,
/// the key its binary frames are masked with (`msgMaskKey`).
final class JdliveChatAuth {
  /// Creates the credentials.
  const JdliveChatAuth({required this.socketUrl, this.maskKey});

  /// `<liveUrl>?token=<token>`: the token is good for one handshake.
  final Uri socketUrl;

  /// `msgMaskKey`, or null when the answer has none (the guest answers
  /// recorded so far: their frames are plain text).
  final String? maskKey;
}

/// What one pushed frame says.
final class JdliveDanmakuFrame {
  /// Creates the result.
  const JdliveDanmakuFrame({this.messages = const [], this.ended = false});

  /// A frame that says nothing this client reports.
  static const JdliveDanmakuFrame none = JdliveDanmakuFrame();

  /// Chat or audience, in order.
  final List<LiveMessage> messages;

  /// `stop_live_broadcast`: the broadcast ended (the page then shows its
  /// end; the server stops pushing and closes the socket later).
  final bool ended;
}

/// The chat arguments of a live broadcast: its `liveId`, which the website's
/// `liveauth` takes as the chat group (`groupId`). A room entry of a live
/// broadcast that is not app-only hands it over in the room's danmaku
/// handle, without a request.
final class JdliveDanmakuArgs {
  /// Creates the arguments.
  const JdliveDanmakuArgs({required this.liveId});

  /// The broadcast (`liveId`).
  final String liveId;

  @override
  String toString() => 'JdliveDanmakuArgs($liveId)';
}

/// JD Live's chat: the website's guest `liveauth` and its socket
/// (`lives.jd.com`'s live page script), without I/O.
///
/// - A handshake first POSTs `liveauth` (no h5st signature): the form's
///   `body` holds the website's app id and, as `content`, a JSON object
///   naming the broadcast as the chat group, AES-128-CBC encrypted with the
///   key and IV written in the page script. The answer gives the socket's
///   address and a token that opens one socket.
/// - The client sends nothing on the socket: the website's join frame only
///   announces a visitor and is not needed to receive the room.
/// - The server pushes JSON text: `get_statistics_result` (the audience,
///   about every 3.5 s while live) and `chat_group_message` events, whose
///   `body.type` says what happened. Chat is `viewer_send_message` and
///   `anchor_send_message`, the two kinds the website's chat list shows.
abstract final class JdliveDanmakuCodec {
  /// Where `liveauth` is asked (the page's API host).
  static final Uri authUrl = Uri.parse('https://${JdliveEndpoints.apiHost}/api');

  /// The page's app id (`appId`), in the form's `body` and the content.
  static const String appId = 'jd.mall';

  /// The page's key (`secretKey`): sent in the content and, as UTF-8, the
  /// AES key that encrypts it.
  static const String secretKey = 'RYm2dMPMWD9AxYFk';

  /// The page's IV (`pyl`), as UTF-8.
  static const String iv = '0102030405060708';

  /// `loginType` of the page in a browser (11 in the mini program).
  static const String loginType = '2';

  /// `origin` of the content: the page's default when its link names none.
  static const int origin = -100;

  /// The name the website's chat list gives the streamer's own messages
  /// (`anchor_send_message` carries no name).
  static const String anchorName = '主播';

  /// How often the server sends the audience while a broadcast is live
  /// (measured: about every 3.5 s, at most 6.8 s apart in 32 room-hours).
  /// Not every live room has it: one pushed no statistics for 30 minutes,
  /// only product events, up to 119 s apart.
  static const Duration statisticsInterval = Duration(milliseconds: 3500);

  /// The server drops a socket that got nothing for this long (measured:
  /// four sockets, each closed 180 s after its last frame).
  static const Duration serverIdleTimeout = Duration(seconds: 180);

  /// Silence after which the socket is replaced: longer than
  /// [serverIdleTimeout], so it only catches a socket the server's close
  /// never reached (a quiet room without statistics is normal). The website
  /// has no watchdog.
  static const Duration silenceTimeout = Duration(seconds: 200);

  /// Reconnects without a joined run before the session gives up, as the
  /// reference's runtime does.
  static const int maxReconnects = 8;

  /// The base of the reconnect backoff, stepped once per failed run.
  static const Duration reconnectBaseDelay = Duration(seconds: 1);

  /// Headers of `liveauth`: the adapter's API headers and the page's form
  /// type (axios, without a charset).
  static const Map<String, String> authHeaders = {
    ...JdliveEndpoints.apiHeaders,
    'content-type': 'application/x-www-form-urlencoded',
  };

  /// Handshake headers: the website's origin and the adapter's user agent.
  static const Map<String, String> socketHeaders = {
    'origin': JdliveEndpoints.webOrigin,
    'user-agent': JdliveEndpoints.userAgent,
  };

  static const int _maxEpochMilliseconds = 8640000000000000;
  static final RegExp _token = RegExp(r'''(?<=[?&])token=[^&#\s'"]*''');

  /// The JSON the page encrypts for [liveId] (`groupId`), in the page's key
  /// order; [now] is the `timestamp` (ms) and [nonce] its `random` (six
  /// digits). No `pin` (no account) and no `eid` (the risk fingerprint the
  /// page asks another script for; the server does not need it).
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
  static String encrypt(String content) =>
      base64.encode(AesCbc.encrypt(utf8.encode(content), key: utf8.encode(secretKey), iv: utf8.encode(iv)));

  /// Six random digits, as the page's `Math.random().toString().slice(-6)`.
  static String nonce(Random random) => [for (var i = 0; i < 6; i++) random.nextInt(10)].join();

  /// The `liveauth` form fields for [liveId] (`loginType`, `appid`,
  /// `functionId`, `body`, `t`).
  static Map<String, String> authFields(String liveId, {required DateTime now, required String nonce}) => {
    'loginType': loginType,
    'appid': 'h5-live',
    'functionId': 'liveauth',
    'body': jsonEncode({'appId': appId, 'content': encrypt(content(liveId, now: now, nonce: nonce))}),
    't': '${now.millisecondsSinceEpoch}',
  };

  /// The credentials of a `liveauth` answer: `code` 0 and a `data` with a
  /// `wss` `liveUrl` on a `jd.com` host (no query, fragment or user info)
  /// and a `token`. Throws [JdliveFailure] for anything else (a status that
  /// is not 2xx, no JSON, a refusal such as `{"code":1,"msg":
  /// "鉴权失败","data":{"error":"解密失败!"}}`).
  static JdliveChatAuth auth(String body, {int status = 200}) {
    const what = 'liveauth';
    if (status < 200 || status > 299) {
      throw JdliveFailure(JdliveFailureKind.network, '$what answered HTTP $status');
    }
    final Object? root;
    try {
      root = jsonDecode(body);
    } on FormatException {
      throw const JdliveFailure(JdliveFailureKind.apiChanged, '$what answered no JSON');
    }
    if (root is! Map) throw const JdliveFailure(JdliveFailureKind.apiChanged, '$what answered no JSON object');
    final data = root['data'];
    if (data is! Map || root['code'] != 0) {
      final error = data is Map ? data['error'] : null;
      throw JdliveFailure(
        JdliveFailureKind.apiChanged,
        '$what refused: ${root['code']} ${root['msg']}${error is String ? ' ($error)' : ''}',
      );
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
      throw const JdliveFailure(JdliveFailureKind.apiChanged, '$what answered no socket');
    }
    final mask = data['msgMaskKey'];
    return JdliveChatAuth(
      socketUrl: Uri.parse('$base?token=${token.trim()}'),
      maskKey: mask is String && mask.isNotEmpty ? mask : null,
    );
  }

  static bool _isJdHost(String host) {
    final lower = host.toLowerCase();
    return lower == 'jd.com' || lower.endsWith('.jd.com');
  }

  /// The address a handshake is asked for with [liveId]: `liveauth` naming
  /// the broadcast. Every handshake turns it into a fresh socket URL (a
  /// token opens one socket).
  static Uri endpoint(String liveId) => authUrl.replace(queryParameters: {'functionId': 'liveauth', 'groupId': liveId});

  /// The broadcast of an [endpoint] address, or null for any other address.
  static String? liveIdOf(Uri address) {
    if (address.scheme != authUrl.scheme || address.host != authUrl.host || address.path != authUrl.path) return null;
    final parameters = address.queryParameters;
    final liveId = parameters['groupId'] ?? '';
    return parameters['functionId'] == 'liveauth' && JdliveEndpoints.isLiveId(liveId) ? liveId : null;
  }

  /// [text] with the socket URL's token left out: the transport names the
  /// whole URL in a failed handshake.
  static String redact(String text) => text.replaceAll(_token, 'token=…');

  /// One pushed frame of broadcast [liveId]: text, or bytes (XORed with
  /// [maskKey] when the answer gave one, as the page does, then UTF-8). A
  /// frame that is not a JSON object, an event of another group (a
  /// `body.groupid` that is not [liveId]) and every event but the audience,
  /// the two kinds of chat and the end of the broadcast give nothing.
  static JdliveDanmakuFrame decode(Object? data, {required String liveId, String? maskKey}) {
    final text = switch (data) {
      final String text => text,
      final List<int> bytes => _text(bytes, maskKey),
      _ => null,
    };
    if (text == null) return JdliveDanmakuFrame.none;
    final Object? root;
    try {
      root = jsonDecode(text);
    } on FormatException {
      return JdliveDanmakuFrame.none;
    }
    if (root is! Map) return JdliveDanmakuFrame.none;
    final body = root['body'];
    if (body is! Map || !_sameGroup(body['groupid'], liveId)) return JdliveDanmakuFrame.none;
    return switch (root['type']) {
      'get_statistics_result' => JdliveDanmakuFrame(messages: audience(body)),
      'chat_group_message' when body['type'] == 'stop_live_broadcast' => const JdliveDanmakuFrame(ended: true),
      'chat_group_message' => JdliveDanmakuFrame(messages: [if (chat(root) case final LiveMessage message) message]),
      _ => JdliveDanmakuFrame.none,
    };
  }

  /// The audience numbers a `get_statistics_result` [body] carries, as the
  /// messages the session reports (`current_viewer` the viewers in the room
  /// now, `total_viwer` — sic — the cumulative views the list shows as
  /// `pv`); each a whole number, not negative, or left out. `pv`,
  /// `max_viewer`, `message_num`, `thumbs_up_num` and `cart_num` are not
  /// read.
  static List<LiveMessage> audience(Map<Object?, Object?> body) => [
    for (final (key, kind) in const [
      ('current_viewer', LiveAudienceSignalKind.onlineViewers),
      ('total_viwer', LiveAudienceSignalKind.totalViewers),
    ])
      if (JdliveJson.count(body[key]) case final value?)
        LiveMessage.normalized(
          type: LiveMessageType.audienceUpdate,
          color: LiveMessageColor.white,
          payload: LiveAudienceUpdate(kind: kind, value: value),
        ),
  ];

  /// The bytes of a binary frame as text: XORed with [maskKey]'s code units
  /// (their low bytes, repeated) when there is one, then UTF-8; null when
  /// they are not UTF-8 (the page's `decodeURIComponent` throws and the
  /// frame is dropped).
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

  /// Whether an event's `groupid` (a number or its text) is [liveId]'s; an
  /// event without one counts as this group's.
  static bool _sameGroup(Object? group, String liveId) => switch (group) {
    null => true,
    final int number => '$number' == liveId,
    final String text => text.trim() == liveId,
    _ => false,
  };

  /// A `chat_group_message` [event] as white chat, or null for any other
  /// kind (entries, likes, purchases, products, replies to one viewer, room
  /// state):
  ///
  /// - `viewer_send_message`: the name is `body.nickName`;
  /// - `anchor_send_message`: the name is [anchorName], as the page shows;
  /// - the text is `body.content`, trimmed; blank or not text: null;
  /// - the user id is `from.pinmd5` (a hash of the account; the page never
  ///   shows the account), the message id `id`, the time `datetime` (ms;
  ///   left out when not a positive whole number within `DateTime`'s range).
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
    return LiveMessage.normalized(
      sender: MessageSender.normalized(userId: user is String ? user.trim() : '', userName: name),
      text: text.trim(),
      messageId: id is String ? id.trim() : '',
      sentAt: time is int && time > 0 && time <= _maxEpochMilliseconds
          ? DateTime.fromMillisecondsSinceEpoch(time)
          : null,
      color: LiveMessageColor.white,
    );
  }
}
