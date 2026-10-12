import 'dart:convert';
import 'dart:io' show gzip;

import 'package:live_sites/src/models/live_gift/live_gift.dart';
import 'package:live_sites/src/models/live_message/live_message.dart';
import 'package:live_sites/src/platforms/seventeenlive/parsers/seventeenlive_parser.dart';
import 'package:meta/meta.dart';

/// What an Ably protocol message of a 17LIVE chat socket asks of the
/// connection ([SeventeenLiveDanmakuFrame.signal]).
enum SeventeenLiveSignal {
  /// Nothing: a heartbeat (`action 0`), a presence sync, another channel's
  /// message, a frame that cannot be read.
  none,

  /// `CONNECTED` (4): the socket may attach the channel now.
  connected,

  /// `ATTACHED` (11) for the room's channel: joined.
  attached,

  /// `DETACHED` (13) for the room's channel, sent by the server: attach again.
  detached,

  /// `DISCONNECTED` (6): the server drops the socket; a new one follows.
  disconnected,

  /// `ERROR` (9) of the connection: fatal unless it is a token error.
  connectionError,

  /// `ERROR` (9) of the room's channel: the channel failed.
  channelError,

  /// `AUTH` (17): the server asks for a new token on this socket.
  reauthorize,
}

/// An Ably error (`{"code":40142,"statusCode":401,"message":…}`).
@immutable
final class SeventeenLiveAblyError {
  /// Creates the error.
  const new({required this.code, this.statusCode, this.message = ''});

  /// Ably's error code; 0 when the frame gave none.
  final int code;

  /// Its HTTP status, when given.
  final int? statusCode;

  /// Its message, when given.
  final String message;

  /// A token error (40140 to 40149): a new token fixes it.
  bool get isTokenError => code >= 40140 && code < 40150;

  @override
  String toString() => '$code $message'.trim();
}

/// The connection a `CONNECTED` names: what a later socket resumes from.
@immutable
final class SeventeenLiveConnectionDetails {
  /// Creates the details.
  const new({
    required this.id,
    required this.key,
    this.stateTtl = SeventeenLiveDanmakuProtocol.defaultConnectionStateTtl,
  });

  /// `connectionId`: the same one after a resume means the connection went on.
  final String id;

  /// `connectionDetails.connectionKey`: a socket's `resume` query parameter.
  final String key;

  /// How long the server keeps the connection after the socket dropped.
  final Duration stateTtl;
}

/// A decoded Ably message and what it shows.
@immutable
final class SeventeenLiveEntry {
  /// Creates the entry.
  const new({this.id = '', this.messages = const [], this.muted, this.ended = false});

  /// Ably's message id (or the frame's id and the index).
  final String id;

  /// What it shows, in order.
  final List<LiveMessage> messages;

  /// The live figures' `liveinfo.mute`, when it is a boolean.
  final bool? muted;

  /// A stream end (`LIVE_STREAM_END`, 5).
  final bool ended;
}

/// What one 17LIVE chat frame held ([SeventeenLiveDanmakuProtocol.decode]).
@immutable
final class SeventeenLiveDanmakuFrame {
  /// Creates the result.
  const new({
    this.signal = SeventeenLiveSignal.none,
    this.error,
    this.entries = const [],
    this.connection,
    this.channelSerial,
    this.resumed = false,
    this.backlog = false,
  });

  /// What the frame asks of the connection.
  final SeventeenLiveSignal signal;

  /// The error a `DISCONNECTED`, `DETACHED` or `ERROR` carried.
  final SeventeenLiveAblyError? error;

  /// The Ably messages of a `MESSAGE`, in order.
  final List<SeventeenLiveEntry> entries;

  /// A `CONNECTED`'s connection, when it names its id and key.
  final SeventeenLiveConnectionDetails? connection;

  /// The room channel's `channelSerial` of an `ATTACHED`, `MESSAGE` or
  /// `PRESENCE`: where an attach resumes from.
  final String? channelSerial;

  /// Whether an `ATTACHED` has the `RESUMED` flag.
  final bool resumed;

  /// Whether an `ATTACHED` has the `HAS_BACKLOG` flag.
  final bool backlog;
}

/// `messenger/auth` answered with another push service than Ably.
final class SeventeenLiveChatRefusal implements Exception {
  /// Creates the refusal for [provider].
  const new(this.provider);

  /// The answer's `provider` (1 Ably, 2 PubNub) as text; empty when none.
  final String provider;

  @override
  String toString() => 'messenger/auth: provider ${provider.isEmpty ? 'missing' : provider}';
}

/// 17LIVE's chat (its push service is Ably, ably-js with `environment:
/// "17media"`), without I/O.
///
/// - An anonymous token comes from `POST messenger/auth` ([grant]); the socket
///   is Ably's JSON realtime protocol ([endpoints], [withToken]).
/// - After `CONNECTED` the client attaches the room's channel, named by the
///   room id ([attach]); `ATTACHED` joins it. The server heartbeats every 15 s;
///   the client sends none.
/// - A `MESSAGE` (15) holds messages whose `data` is JSON, gzipped and
///   base64-encoded; its `type` is the website's enum: 3 a comment, 38 the live
///   figures, 13 a gift, 5 the stream end ([entry]).
/// - A later socket resumes with the last `CONNECTED`'s key ([withToken]) and an
///   `ATTACH` with the last `channelSerial` and the `ATTACH_RESUME` flag
///   ([attach]).
///
/// Archived from the reference and mapped onto this tree's models: a colour is
/// an int, a notice's `data` is `'system'`, the online count is a
/// [LiveAudienceUpdate], a gift is a [LiveGift] named `礼物 {id}` (the anonymous
/// chat has no gift table), a paid barrage is the reduced [LiveSuperChat], and
/// a message carries no badges, name colour, sender level or replay mark (no
/// field here).
abstract final class SeventeenLiveDanmakuProtocol {
  /// The token source; ably-js asks it in its `authCallback`.
  static final Uri authUrl = Uri.https(SeventeenLiveParser.apiHost, '/api/v1/messenger/auth');

  /// `messenger/auth`'s `provider` for Ably; the website's `PUBNUB` is 2.
  static const int ablyProvider = 1;

  /// The realtime host of ably-js's `environment: "17media"`.
  static const String primaryHost = '17media.realtime.ably.net';

  /// The website's `fallbackHosts`, tried after the primary host fails.
  static const List<String> fallbackHosts = [
    '17-media-a-fallback.ably-realtime.com',
    '17-media-b-fallback.ably-realtime.com',
    '17-media-c-fallback.ably-realtime.com',
  ];

  /// The sockets, primary first, without a token ([withToken]).
  static final List<Uri> endpoints = List.unmodifiable([
    for (final host in [primaryHost, ...fallbackHosts])
      Uri(scheme: 'wss', host: host, path: '/', queryParameters: {'format': 'json', 'heartbeats': 'true', 'v': '3'}),
  ]);

  /// Handshake headers: the website's origin and the platform's UA.
  static const Map<String, String> handshakeHeaders = {
    'origin': SeventeenLiveParser.origin,
    'user-agent': SeventeenLiveParser.userAgent,
  };

  /// The token request's headers (a JSON content type over the catalog's).
  static const Map<String, String> authHeaders = {
    ...SeventeenLiveParser.catalogHeaders,
    'content-type': 'application/json',
  };

  /// The server's heartbeat period; the tick of the silence watchdog.
  static const Duration heartbeatInterval = Duration(seconds: 15);

  /// Silence after which the socket is replaced.
  static const Duration inactivityTimeout = Duration(seconds: 25);

  /// How long the attach may take.
  static const Duration joinTimeout = Duration(seconds: 10);

  /// Refusals in a row after which the chat gives up.
  static const int maxRefusals = 3;

  /// The largest token taken from `messenger/auth`.
  static const int maxTokenLength = 4096;

  /// The comment type (`COMMENT`).
  static const int commentType = 3;

  /// The live figures' type (`LIVE`).
  static const int liveType = 38;

  /// A gift's type (`giftMsg`).
  static const int giftType = 13;

  /// The stream end's type (`LIVE_STREAM_END`).
  static const int streamEndType = 5;

  /// How long a dropped connection is kept when `CONNECTED` does not say.
  static const Duration defaultConnectionStateTtl = Duration(seconds: 120);

  /// `ATTACH`'s `ATTACH_RESUME` flag.
  static const int attachResumeFlag = 32;

  /// `ATTACHED`'s `RESUMED` flag.
  static const int resumedFlag = 4;

  /// `ATTACHED`'s `HAS_BACKLOG` flag.
  static const int hasBacklogFlag = 2;

  /// How long a paid barrage stays a super chat.
  static const Duration superChatDuration = Duration(seconds: 20);

  /// The notice when the streamer paused the stream.
  static const String mutedNotice = '主播暂停了直播（画面静止、没有声音）';

  /// The notice when they resumed it.
  static const String unmutedNotice = '主播恢复了直播';

  /// White, the danmaku default.
  static const int defaultColor = 0xFFFFFF;

  static const int _maxMillis = 8640000000000000;
  static const int _maxDetailMillis = 86400000;

  static final RegExp _token = RegExp('^[\\x21-\\x7e]{1,$maxTokenLength}\$');
  static final RegExp _hexColor = RegExp(r'^(?:[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$');

  /// The Ably token of a `messenger/auth` [body]: the printable-ASCII token
  /// when the provider is Ably. Another provider throws [SeventeenLiveChatRefusal];
  /// a non-200/non-JSON answer throws its `SiteError`; a missing or unusable
  /// token, a [FormatException].
  static String grant(String body, {int status = 200}) {
    final data = SeventeenLiveParser.decode(body, status: status, what: 'messenger/auth');
    if (data is! Map) throw const FormatException('messenger/auth: not an object');
    final provider = data['provider'];
    if (provider != ablyProvider) {
      throw SeventeenLiveChatRefusal(provider is String || provider is num ? '$provider' : '');
    }
    final token = data['token'];
    if (token is! String || !_token.hasMatch(token)) throw const FormatException('messenger/auth: no token');
    return token;
  }

  /// [endpoint] with the `access_token` [token] first and an optional [resume].
  static Uri withToken(Uri endpoint, String token, {String? resume}) =>
      endpoint.replace(queryParameters: {'access_token': token, 'resume': ?resume, ...endpoint.queryParameters});

  /// The `ATTACH` (10) of the channel [roomId]; a resumed one carries the last
  /// [channelSerial] and the `ATTACH_RESUME` flag.
  static String attach(String roomId, {String? channelSerial, bool resume = false}) => jsonEncode({
    'action': 10,
    'channel': roomId,
    'channelSerial': ?channelSerial,
    if (resume) 'flags': attachResumeFlag,
  });

  /// The `AUTH` (17) answering a server's request with [token].
  static String reauthorize(String token) => jsonEncode({
    'action': 17,
    'auth': {'accessToken': token},
  });

  /// Reads one frame of a chat socket for the room [roomId]: one Ably protocol
  /// message, named by `action`. The heartbeat (0), a presence sync (16) and
  /// other channels hold nothing. With [backlogBefore], the messages published
  /// before the announcing `ATTACHED` are the backlog.
  static SeventeenLiveDanmakuFrame decode(
    Object? data, {
    required String roomId,
    DateTime? now,
    DateTime? backlogBefore,
  }) {
    final text = switch (data) {
      final String text => text,
      final List<int> bytes => utf8.decode(bytes, allowMalformed: true),
      _ => null,
    };
    if (text == null) return const SeventeenLiveDanmakuFrame();
    final Object? root;
    try {
      root = jsonDecode(text);
    } on FormatException {
      return const SeventeenLiveDanmakuFrame();
    }
    if (root is! Map) return const SeventeenLiveDanmakuFrame();
    final channel = root['channel'];
    final ours = channel == roomId;
    final error = _error(root['error']);
    final serial = switch (root['channelSerial']) {
      final String serial when serial.isNotEmpty => serial,
      _ => null,
    };
    return switch (root['action']) {
      4 => SeventeenLiveDanmakuFrame(
        signal: SeventeenLiveSignal.connected,
        error: error,
        connection: _connection(root),
      ),
      6 => SeventeenLiveDanmakuFrame(signal: SeventeenLiveSignal.disconnected, error: error),
      9 when channel == null => SeventeenLiveDanmakuFrame(
        signal: SeventeenLiveSignal.connectionError,
        error: error ?? const SeventeenLiveAblyError(code: 0),
      ),
      9 when ours => SeventeenLiveDanmakuFrame(
        signal: SeventeenLiveSignal.channelError,
        error: error ?? const SeventeenLiveAblyError(code: 0),
      ),
      11 when ours => SeventeenLiveDanmakuFrame(
        signal: SeventeenLiveSignal.attached,
        error: error,
        channelSerial: serial,
        resumed: switch (root['flags']) {
          final int flags => (flags & resumedFlag) != 0,
          _ => false,
        },
        backlog: switch (root['flags']) {
          final int flags => (flags & hasBacklogFlag) != 0,
          _ => false,
        },
      ),
      13 when ours => SeventeenLiveDanmakuFrame(signal: SeventeenLiveSignal.detached, error: error),
      14 when ours => SeventeenLiveDanmakuFrame(channelSerial: serial),
      15 when ours => SeventeenLiveDanmakuFrame(
        entries: _entries(root, now ?? DateTime.now(), backlogBefore),
        channelSerial: serial,
      ),
      17 => const SeventeenLiveDanmakuFrame(signal: SeventeenLiveSignal.reauthorize),
      _ => const SeventeenLiveDanmakuFrame(),
    };
  }

  static SeventeenLiveConnectionDetails? _connection(Map<Object?, Object?> root) {
    final id = root['connectionId'];
    final details = root['connectionDetails'];
    if (id is! String || id.isEmpty || details is! Map) return null;
    final key = details['connectionKey'];
    if (key is! String || key.isEmpty) return null;
    final ttl = details['connectionStateTtl'];
    return SeventeenLiveConnectionDetails(
      id: id,
      key: key,
      stateTtl: ttl is int && ttl > 0 && ttl <= _maxDetailMillis
          ? Duration(milliseconds: ttl)
          : defaultConnectionStateTtl,
    );
  }

  static SeventeenLiveAblyError? _error(Object? value) {
    if (value is! Map) return null;
    final code = value['code'];
    final status = value['statusCode'];
    final message = value['message'];
    return SeventeenLiveAblyError(
      code: code is int ? code : 0,
      statusCode: status is int ? status : null,
      message: message is String ? message.trim() : '',
    );
  }

  static List<SeventeenLiveEntry> _entries(Map<Object?, Object?> root, DateTime now, DateTime? backlogBefore) {
    final messages = root['messages'];
    if (messages is! List) return const [];
    final frameId = root['id'];
    final frameTime = _millis(root['timestamp']);
    var backlog = backlogBefore != null;
    final entries = <SeventeenLiveEntry>[];
    for (final (index, item) in messages.indexed) {
      if (item is! Map) continue;
      final decoded = payload(item['data']);
      if (decoded == null) continue;
      final published = _millis(item['timestamp']) ?? frameTime;
      if (backlog && published != null && !published.isBefore(backlogBefore!)) backlog = false;
      final id = switch (item['id']) {
        final String id when id.isNotEmpty => id,
        _ => frameId is String && frameId.isNotEmpty ? '$frameId:$index' : '',
      };
      entries.add(entry(decoded, id: id, now: now, replayed: backlog && published != null));
    }
    return entries;
  }

  static DateTime? _millis(Object? value) =>
      value is int && value > 0 && value <= _maxMillis ? DateTime.fromMillisecondsSinceEpoch(value) : null;

  /// A decoded [payload] with the Ably message [id], by its `type`: a comment's
  /// chat line then (for a paid barrage) its super chat, the live figures, a gift
  /// or the stream end. [replayed] marks a backlog message (not carried onto the
  /// reduced [LiveMessage]).
  static SeventeenLiveEntry entry(
    Map<Object?, Object?> payload, {
    String id = '',
    DateTime? now,
    bool replayed = false,
  }) {
    final shown = message(payload, id: id);
    return switch (payload['type']) {
      commentType => SeventeenLiveEntry(
        id: id,
        messages: [
          ?shown,
          ?superChat(payload, id: id, now: now),
        ],
      ),
      liveType => SeventeenLiveEntry(
        id: id,
        messages: [?shown],
        muted: switch (payload['liveinfo']) {
          {'mute': final bool muted} => muted,
          _ => null,
        },
      ),
      streamEndType => SeventeenLiveEntry(id: id, ended: true),
      giftType => SeventeenLiveEntry(id: id, messages: [?shown]),
      _ => SeventeenLiveEntry(id: id),
    };
  }

  /// The super chat of a paid barrage: a comment whose `barrageStyle` is true
  /// and `barrage.point` is above zero. Only the reduced fields are kept.
  static LiveMessage? superChat(Map<Object?, Object?> payload, {String id = '', DateTime? now}) {
    if (payload['type'] != commentType) return null;
    final chat = message(payload, id: id);
    final comment = payload['commentMsg'];
    if (chat == null || comment is! Map) return null;
    final barrage = comment['barrage'];
    final point = barrage is Map ? barrage['point'] : null;
    if (comment['barrageStyle'] != true || point is! int || point <= 0) return null;
    final body = comment['comment'];
    var text = (body is Map ? _string(body['text']) : '').replaceAll('\n', ' ').trim();
    if (text.isEmpty) text = chat.message;
    final start = chat.sentAt ?? now ?? DateTime.now();
    return LiveMessage(
      type: LiveMessageType.superChat,
      userName: chat.userName,
      userId: chat.userId,
      message: text,
      color: defaultColor,
      id: id,
      sentAt: chat.sentAt,
      data: LiveSuperChat(
        message: text,
        price: point,
        priceText: '$point coins',
        startTime: start,
        endTime: start.add(superChatDuration),
      ),
    );
  }

  /// The system notice of the live figures' `liveinfo.mute` turning [muted].
  static LiveMessage muteNotice({required bool muted, String id = ''}) => LiveMessage(
    type: LiveMessageType.notice,
    userName: '',
    message: muted ? mutedNotice : unmutedNotice,
    color: defaultColor,
    id: id.isEmpty ? null : id,
    data: 'system',
  );

  /// A message's `data`: base64 of gzipped UTF-8 JSON; null when it is not
  /// that or not a JSON object.
  static Map<Object?, Object?>? payload(Object? data) {
    if (data is! String || data.isEmpty) return null;
    try {
      final value = jsonDecode(utf8.decode(gzip.decode(base64.decode(data))));
      return value is Map ? value : null;
    } on FormatException {
      return null;
    }
  }

  /// The message a decoded [payload] shows, with the Ably message [id]: a
  /// comment's chat line (unless dirty), a gift, or the live figures as an
  /// audience update. Sender level, badges and name colour have no field here.
  static LiveMessage? message(Map<Object?, Object?> payload, {String id = ''}) {
    switch (payload['type']) {
      case commentType:
        final comment = payload['commentMsg'];
        if (comment is! Map) return null;
        if (comment['isDirty'] == true || comment['isDirtyWord'] == true || comment['isDirtyUser'] == true) return null;
        final body = comment['comment'];
        var text = _string(comment['content']).trim();
        if (text.isEmpty && body is Map) text = _string(body['text']).trim();
        if (text.isEmpty) return null;
        final user = comment['displayUser'];
        final name = user is Map ? _string(user['displayName']) : '';
        return LiveMessage(
          type: LiveMessageType.chat,
          userName: name.isNotEmpty || user is! Map ? name : _string(user['openID']),
          userId: user is Map ? _string(user['userID']) : '',
          message: text,
          color: color(body is Map ? body['textColor'] : null),
          id: id,
          sentAt: _millis(comment['sendTime']),
        );
      case giftType:
        return gift(payload, id: id);
      case liveType:
        final info = payload['liveinfo'];
        final viewers = info is Map ? info['liveViewerCount'] : null;
        if (viewers is! int || viewers < 0) return null;
        return LiveMessage(
          type: LiveMessageType.audienceUpdate,
          userName: '',
          message: '',
          data: LiveAudienceUpdate(onlineViewers: viewers),
        );
      default:
        return null;
    }
  }

  /// A gift (`type` 13): `giftMsg` with `giftID`, `point` and `giftMetas`'s
  /// `combo.count`. There is no gift table, so the name is `礼物 {giftID}` and
  /// the picture, combo id and points unit have no field here.
  static LiveMessage? gift(Map<Object?, Object?> payload, {String id = ''}) {
    final message = payload['giftMsg'];
    if (message is! Map) return null;
    final giftId = _string(message['giftID']).trim();
    if (giftId.isEmpty) return null;
    final metas = message['giftMetas'];
    final entries = [
      if (metas is List)
        for (final meta in metas)
          if (meta is Map) meta,
    ];
    final meta = entries.where((meta) => meta['targetGiftID'] == giftId).firstOrNull ?? entries.firstOrNull;
    final combo = meta?['combo'];
    final count = combo is Map && combo['count'] is int && (combo['count'] as int) > 0 ? combo['count'] as int : 1;
    final point = message['point'] is int && (message['point'] as int) >= 0 ? message['point'] as int : 0;
    final name = '礼物 $giftId';
    final user = message['displayUser'];
    final sender = user is Map ? _string(user['displayName']) : '';
    return LiveMessage(
      type: LiveMessageType.gift,
      userName: sender.isNotEmpty || user is! Map ? sender : _string(user['openID']),
      userId: user is Map ? _string(user['userID']) : '',
      message: '$name ×$count',
      color: defaultColor,
      id: id,
      data: LiveGift(name: name, count: count, unitPrice: point, totalValue: point * count),
    );
  }

  /// A colour: `#AARRGGBB` (alpha first) or `#RRGGBB`, the `#` optional; else
  /// white. Returned as a 24-bit RGB int.
  static int color(Object? value) {
    if (value is! String) return defaultColor;
    var hex = value.trim();
    if (hex.startsWith('#')) hex = hex.substring(1);
    if (!_hexColor.hasMatch(hex)) return defaultColor;
    return int.parse(hex.substring(hex.length - 6), radix: 16);
  }

  static String _string(Object? value) => value is String ? value : '';
}
