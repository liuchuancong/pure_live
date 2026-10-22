import 'dart:convert';
import 'dart:io' show gzip;

import 'package:live_sites/src/models/audience/live_audience_update/live_audience_update.dart';
import 'package:live_sites/src/models/enums/live_audience_signal_kind.dart';
import 'package:live_sites/src/models/enums/live_gift_unit.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/enums/live_notice_kind.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/gift/live_gift_combo/live_gift_combo.dart';
import 'package:live_sites/src/models/gift/live_gift_value/live_gift_value.dart';
import 'package:live_sites/src/models/message/live_badge/live_badge.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/message/message_sender/message_sender.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_display/live_super_chat_display.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_message/live_super_chat_message.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_price/live_super_chat_price.dart';
import 'package:live_sites/src/platforms/seventeenlive/api/seventeenlive_endpoints.dart';
import 'package:live_sites/src/platforms/seventeenlive/parsers/seventeenlive_failure.dart';
import 'package:live_sites/src/platforms/seventeenlive/parsers/seventeenlive_json.dart';
import 'package:meta/meta.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// What an Ably protocol message of a 17LIVE chat socket asks of the connection
/// ([SeventeenLiveDanmakuFrame.signal]).
enum SeventeenLiveSignal {
  /// Nothing: a heartbeat (`action 0`), a presence sync, another channel's
  /// message, a frame that cannot be read.
  none,

  /// `CONNECTED` (4): the socket may attach the channel now.
  connected,

  /// `ATTACHED` (11) for the room's channel: joined.
  attached,

  /// `DETACHED` (13) for the room's channel, sent by the server: the channel has
  /// to be attached again.
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
  const SeventeenLiveAblyError({required this.code, this.statusCode, this.message = ''});

  /// Ably's error code; 0 when the frame gave none.
  final int code;

  /// Its HTTP status, when given.
  final int? statusCode;

  /// Its message, when given.
  final String message;

  /// A token error (40140 to 40149: token expired, revoked, unrecognised…): a
  /// new token fixes it (ably-js's `isTokenErr`).
  bool get isTokenError => code >= 40140 && code < 40150;

  @override
  bool operator ==(Object other) =>
      other is SeventeenLiveAblyError && other.code == code && other.statusCode == statusCode && other.message == message;

  @override
  int get hashCode => Object.hash(code, statusCode, message);

  @override
  String toString() => '$code $message'.trim();
}

/// The connection a `CONNECTED` names: what a later socket resumes.
@immutable
final class SeventeenLiveConnectionDetails {
  /// Creates the details.
  const SeventeenLiveConnectionDetails({
    required this.id,
    required this.key,
    this.stateTtl = SeventeenLiveDanmakuCodec.defaultConnectionStateTtl,
    this.maxIdleInterval = SeventeenLiveDanmakuCodec.heartbeatInterval,
  });

  /// `connectionId`: the same one after a resume means the connection went on.
  final String id;

  /// `connectionDetails.connectionKey`: a socket's `resume` query parameter.
  final String key;

  /// `connectionDetails.connectionStateTtl`: how long the server keeps the
  /// connection after the socket dropped.
  final Duration stateTtl;

  /// `connectionDetails.maxIdleInterval`: the server's heartbeat period.
  final Duration maxIdleInterval;

  @override
  bool operator ==(Object other) =>
      other is SeventeenLiveConnectionDetails &&
      other.id == id &&
      other.key == key &&
      other.stateTtl == stateTtl &&
      other.maxIdleInterval == maxIdleInterval;

  @override
  int get hashCode => Object.hash(id, key, stateTtl, maxIdleInterval);
}

/// One Ably message of a `MESSAGE` frame, as the codec read it.
final class SeventeenLiveEntry {
  /// Creates the entry.
  const SeventeenLiveEntry({
    this.id = '',
    this.messages = const [],
    this.muted,
    this.ended = false,
    this.publishedAt,
    this.replayed = false,
  });

  /// Ably's message id (or the frame's id and the index): a message the server
  /// sends again after a resume has the same one.
  final String id;

  /// What it shows, in order: a comment's chat line, then a paid barrage's super
  /// chat; the viewers now.
  final List<LiveMessage> messages;

  /// The live figures' (38) `liveinfo.mute`, when it is a boolean.
  final bool? muted;

  /// A stream end (`LIVE_STREAM_END`, 5).
  final bool ended;

  /// When Ably published it: the message's `timestamp`, else its frame's; null
  /// when neither is a time.
  final DateTime? publishedAt;

  /// Whether it is part of the backlog an `ATTACHED` announced: its [messages]
  /// are marked replayed.
  final bool replayed;
}

/// What one 17LIVE chat frame held ([SeventeenLiveDanmakuCodec.decode]).
final class SeventeenLiveDanmakuFrame {
  /// Creates the result.
  const SeventeenLiveDanmakuFrame({
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

  /// The error a `DISCONNECTED`, `DETACHED` or `ERROR` carried, or that a
  /// `CONNECTED` (a resume that failed: 80018 an invalid key) or an `ATTACHED`
  /// (90003: the channel's messages since the serial expired) came with; null
  /// otherwise.
  final SeventeenLiveAblyError? error;

  /// The Ably messages of a `MESSAGE`, in order.
  final List<SeventeenLiveEntry> entries;

  /// Chat, super chats and audience figures of a `MESSAGE`, in order.
  List<LiveMessage> get messages => [for (final entry in entries) ...entry.messages];

  /// A `CONNECTED`'s connection, when it names its id and key.
  final SeventeenLiveConnectionDetails? connection;

  /// The room channel's `channelSerial` of an `ATTACHED`, `MESSAGE` or
  /// `PRESENCE`: where an attach resumes from.
  final String? channelSerial;

  /// Whether an `ATTACHED` has the `RESUMED` flag: the channel went on from the
  /// serial the attach gave, missing nothing.
  final bool resumed;

  /// Whether an `ATTACHED` has the `HAS_BACKLOG` flag: messages sent before the
  /// attach follow it (what a resume missed, or the recent ones when it could not
  /// resume).
  final bool backlog;
}

/// 17LIVE's chat (the website's Ably realtime protocol, checked against the
/// recordings `S05-live`/`S06-live` and read-only sessions of 2026-09-28 to
/// 09-30), without I/O.
///
/// - The website's push service is Ably (ably-js with `environment: "17media"`).
///   An anonymous token comes from `POST messenger/auth` ([grant]); the socket is
///   Ably's JSON realtime protocol ([endpoints], [withToken]).
/// - After `CONNECTED` the client attaches the room's channel, named by the room
///   id ([attach]); `ATTACHED` joins it. The server sends a heartbeat every 15 s;
///   the client sends none.
/// - A `MESSAGE` (15) holds messages whose `data` is JSON, gzipped and
///   base64-encoded (the website's `gzip_base64`); its `type` is the website's
///   message enum: 3 a comment, 13 a gift, 38 the live figures, 5 the stream end
///   ([entry]).
/// - A later socket resumes as ably-js 2.21.0 does: `resume` with the last
///   `CONNECTED`'s key ([withToken]), and an `ATTACH` with the last
///   `channelSerial` and the `ATTACH_RESUME` flag ([attach]); the server answers
///   `ATTACHED` with `RESUMED` and sends the messages missed meanwhile. An
///   `ATTACHED` with `HAS_BACKLOG` announces them; the messages published before
///   it are replayed.
abstract final class SeventeenLiveDanmakuCodec {
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

  /// The sockets, primary host first, without their token ([withToken]): the JSON
  /// protocol, version 3, with server heartbeats.
  static final List<Uri> endpoints = List.unmodifiable([
    for (final host in [primaryHost, ...fallbackHosts])
      Uri(scheme: 'wss', host: host, path: '/', queryParameters: {'format': 'json', 'heartbeats': 'true', 'v': '3'}),
  ]);

  /// Handshake headers: the website's origin and the platform's desktop UA, as
  /// the recordings sent them.
  static const Map<String, String> handshakeHeaders = {
    'origin': SeventeenLiveEndpoints.origin,
    'user-agent': SeventeenLiveEndpoints.userAgent,
  };

  /// The server's heartbeat period (`CONNECTED`'s `maxIdleInterval`, 15 000 ms in
  /// every recording). The client sends no heartbeat; this is the tick of the
  /// silence watchdog.
  static const Duration heartbeatInterval = Duration(seconds: 15);

  /// Silence after which the socket is replaced: ably-js's idle limit,
  /// `maxIdleInterval` plus its `realtimeRequestTimeout` (10 s).
  static const Duration inactivityTimeout = Duration(seconds: 25);

  /// How long the attach may take: ably-js's `realtimeRequestTimeout`.
  static const Duration joinTimeout = Duration(seconds: 10);

  /// The handshake budget of one socket.
  static const Duration connectTimeout = Duration(seconds: 10);

  /// Refusals in a row (token errors and server-sent detaches) after which the
  /// chat gives up; an attached channel starts the count again.
  static const int maxRefusals = 3;

  /// Failed sockets in a row before the session is abandoned.
  static const int maxReconnectAttempts = 8;

  /// The largest token taken from `messenger/auth`.
  static const int maxTokenLength = 4096;

  /// The comment type (`COMMENT`).
  static const int commentType = 3;

  /// A gift's type (`giftMsg`).
  static const int giftType = 13;

  /// The stream end's type (`LIVE_STREAM_END`): the website leaves the channel.
  static const int streamEndType = 5;

  /// The live figures' type (`LIVE`): `liveinfo.liveViewerCount`.
  static const int liveType = 38;

  /// How long the server keeps a dropped connection when `CONNECTED` does not say
  /// (`connectionStateTtl`, 120 000 ms in every recording and in ably-js's
  /// defaults).
  static const Duration defaultConnectionStateTtl = Duration(seconds: 120);

  /// `ATTACH`'s `ATTACH_RESUME` flag: the channel was attached before.
  static const int attachResumeFlag = 32;

  /// `ATTACHED`'s `RESUMED` flag.
  static const int resumedFlag = 4;

  /// `ATTACHED`'s `HAS_BACKLOG` flag: a backlog follows (ably-js hands it to the
  /// attached state change as `hasBacklog`; it marks no message).
  static const int hasBacklogFlag = 2;

  /// How long a paid barrage stays a super chat: the website flies it once over
  /// the player, 1 px a frame from the right edge until it leaves the left one:
  /// (player width + barrage width) / 60 fps, about 20 s for a 900 px player and a
  /// 300 px barrage.
  static const Duration superChatDuration = Duration(seconds: 20);

  /// The unit a barrage and a gift are worth in: 17LIVE points (baby coins).
  static const String pointUnit = 'points';

  /// The notice when the live figures' `liveinfo.mute` turns true: the streamer
  /// paused the stream, which then shows a still picture without sound (measured
  /// 2026-09-30; viewers can still write). The website shows nothing for it.
  static const String mutedNotice = '主播暂停了直播（画面静止、没有声音）';

  /// The notice when it turns false again.
  static const String unmutedNotice = '主播恢复了直播';

  /// The most prefix badges read from one comment.
  static const int badgeLimit = 16;

  /// The places of a comment's badges, in the order the comment names them around
  /// the sender's name (`prefixBadges` holds the prefix badges, and the single
  /// `prefixBadge` is one of them when set).
  static const List<String> badgeFields = [
    'prefixBadge',
    'middleBadge',
    'roleBadge',
    'attendanceBadge',
    'mLevelBadge',
    'topRightBadge',
  ];

  /// Largest time a `DateTime` can hold, in milliseconds.
  static const int maxMillis = 8640000000000000;

  /// Largest `connectionStateTtl` or `maxIdleInterval` taken: a day.
  static const int _maxDetailMillis = 86400000;

  static final RegExp _token = RegExp('^[\\x21-\\x7e]{1,$maxTokenLength}\$');
  static final RegExp _hexColor = RegExp(r'^(?:[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$');

  /// The token request's headers: the platform's catalog headers (desktop UA,
  /// `Origin`, `Referer: https://17.live/`) and a JSON content type.
  static Map<String, String> get authHeaders => SeventeenLiveEndpoints.authHeaders;

  /// The Ably token of a `messenger/auth` answer
  /// (`{"provider":1,"token":…,"permissions":["*"]}`). Another provider throws
  /// [SeventeenLiveFailureKind.chatRefused]; an answer that is not a 200 or not
  /// JSON throws its failure; one without a usable token (printable ASCII, at most
  /// [maxTokenLength]) an api-changed failure.
  static String grant(String body, {int status = 200}) {
    const what = 'messenger/auth';
    if (statusFailure(status, body, what) case final failure?) throw failure;
    if (body.length > SeventeenLiveEndpoints.responseLimit) {
      throw const SeventeenLiveFailure(SeventeenLiveFailureKind.apiChanged, 'messenger/auth: answer too big');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const SeventeenLiveFailure(SeventeenLiveFailureKind.apiChanged, 'messenger/auth: not JSON');
    }
    final data = decoded is Map ? decoded.map((key, entry) => MapEntry('$key', entry)) : null;
    if (data == null) {
      throw const SeventeenLiveFailure(SeventeenLiveFailureKind.apiChanged, 'messenger/auth: not an object');
    }
    final provider = data['provider'];
    if (provider != ablyProvider) {
      throw SeventeenLiveFailure(
        SeventeenLiveFailureKind.chatRefused,
        'messenger/auth: provider ${provider is String || provider is num ? '$provider' : 'missing'}',
      );
    }
    final token = data['token'];
    if (token is! String || !_token.hasMatch(token)) {
      throw const SeventeenLiveFailure(SeventeenLiveFailureKind.apiChanged, 'messenger/auth: no token');
    }
    return token;
  }

  /// [endpoint] with the `access_token` [token] first, as ably-js orders it, and
  /// with a [resume] key the `resume` of the connection it names.
  static Uri withToken(Uri endpoint, String token, {String? resume}) => endpoint.replace(
    queryParameters: {'access_token': token, 'resume': ?resume, ...endpoint.queryParameters},
  );

  /// The `ATTACH` (10) of the channel [roomId]: as the recordings sent it, or,
  /// for a channel attached before ([resume]), with ably-js's `ATTACH_RESUME`
  /// flag and the last [channelSerial], from which the server sends what was
  /// missed.
  static String attach(String roomId, {String? channelSerial, bool resume = false}) => jsonEncode({
    'action': 10,
    'channel': roomId,
    'channelSerial': ?channelSerial,
    if (resume) 'flags': attachResumeFlag,
  });

  /// The `AUTH` (17) answering a server's request with [token] (ably-js's
  /// in-place reauthorisation).
  static String reauthorize(String token) => jsonEncode({
    'action': 17,
    'auth': {'accessToken': token},
  });

  /// Reads one frame of a chat socket for the room [roomId]: text, or UTF-8 bytes
  /// (malformed bytes become U+FFFD). The frame is one Ably protocol message,
  /// named by `action`:
  ///
  /// - 4 `CONNECTED`, 6 `DISCONNECTED`, 17 `AUTH`: [SeventeenLiveSignal.connected]
  ///   (with its connection id, key and times, and the error of a resume that
  ///   failed), [SeventeenLiveSignal.disconnected] (with its `error`),
  ///   [SeventeenLiveSignal.reauthorize];
  /// - 9 `ERROR`: of the room's channel when it names it, of the connection when
  ///   it names none;
  /// - 11 `ATTACHED` (its `channelSerial`, the `RESUMED` and `HAS_BACKLOG` flags
  ///   and an error), 13 `DETACHED` of the room's channel;
  /// - 15 `MESSAGE` of the room's channel: its `channelSerial` and its `messages`
  ///   ([entry]). A comment without its own time gets [now] (default: the current
  ///   time) as its super chat's start; with [backlogBefore] (when the `ATTACHED`
  ///   that announced a backlog came), the messages Ably published before it are
  ///   the backlog, replayed (up to the first published at it or later);
  /// - 14 `PRESENCE` of the room's channel: its `channelSerial` only (ably-js
  ///   keeps it as the channel's).
  ///
  /// Anything else (the heartbeat 0, a presence `SYNC` 16, another channel, a
  /// frame that is not a JSON object) holds nothing. A field of the wrong type
  /// costs only that field or that message.
  static SeventeenLiveDanmakuFrame decode(Object? data, {required String roomId, DateTime? now, DateTime? backlogBefore}) {
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
    Duration? millis(Object? value) =>
        value is int && value > 0 && value <= _maxDetailMillis ? Duration(milliseconds: value) : null;
    return SeventeenLiveConnectionDetails(
      id: id,
      key: key,
      stateTtl: millis(details['connectionStateTtl']) ?? defaultConnectionStateTtl,
      maxIdleInterval: millis(details['maxIdleInterval']) ?? heartbeatInterval,
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
      // The backlog ends at the first message published at the attach or later;
      // one without a time cannot tell.
      if (backlog && published != null && !published.isBefore(backlogBefore!)) backlog = false;
      entries.add(
        entry(
          decoded,
          id: switch (item['id']) {
            final String id when id.isNotEmpty => id,
            _ => frameId is String && frameId.isNotEmpty ? '$frameId:$index' : '',
          },
          now: now,
          publishedAt: published,
          replayed: backlog && published != null,
        ),
      );
    }
    return entries;
  }

  /// A time in milliseconds from the epoch, above zero and within `DateTime`'s
  /// range, or null.
  static DateTime? timeMillis(Object? value) =>
      value is int && value > 0 && value <= maxMillis ? DateTime.fromMillisecondsSinceEpoch(value) : null;

  static DateTime? _millis(Object? value) => timeMillis(value);

  /// A decoded [payload] with the Ably message [id]:
  ///
  /// - a comment: its chat line ([message]), then, for a paid barrage, its super
  ///   chat ([superChat]), which starts at [now] when the comment has no time of
  ///   its own;
  /// - the live figures: the viewers now ([message]) and `liveinfo.mute` when it
  ///   is a boolean;
  /// - a gift ([giftType]): its gift ([message], one message one gift);
  /// - the stream end ([streamEndType]): [SeventeenLiveEntry.ended];
  /// - anything else: nothing.
  ///
  /// [publishedAt] is when Ably published it; a [replayed] one (a backlog) has
  /// its messages marked so.
  static SeventeenLiveEntry entry(
    Map<Object?, Object?> payload, {
    String id = '',
    DateTime? now,
    DateTime? publishedAt,
    bool replayed = false,
  }) {
    final shown = message(payload, id: id, replayed: replayed);
    return switch (payload['type']) {
      commentType => SeventeenLiveEntry(
        id: id,
        publishedAt: publishedAt,
        replayed: replayed,
        messages: [?shown, ?superChat(payload, id: id, now: now, replayed: replayed)],
      ),
      liveType => SeventeenLiveEntry(
        id: id,
        publishedAt: publishedAt,
        replayed: replayed,
        messages: [?shown],
        muted: switch (payload['liveinfo']) {
          {'mute': final bool muted} => muted,
          _ => null,
        },
      ),
      streamEndType => SeventeenLiveEntry(id: id, publishedAt: publishedAt, replayed: replayed, ended: true),
      giftType => SeventeenLiveEntry(id: id, publishedAt: publishedAt, replayed: replayed, messages: [?shown]),
      _ => SeventeenLiveEntry(id: id, publishedAt: publishedAt, replayed: replayed),
    };
  }

  /// The super chat of a paid barrage: a comment the website shows ([message])
  /// whose `barrageStyle` is true and whose `barrage.point`, the baby coins it
  /// cost, is above zero. The website flies such a comment over the player besides
  /// its chat line; the ones that cost no coins (`point` 0: the platform's army
  /// and welcome lines, the streamer assistant's, and barrages from the sender's
  /// stock) stay chat only. Null for anything else.
  ///
  /// - The text is what the website flies: `comment.text` with line breaks as
  ///   spaces, trimmed, and the chat line's text when it has none.
  /// - The price is the point, displayed as the website's `{point} coins`.
  /// - It starts at the line's time ([now], default the current time, without one)
  ///   and lasts [superChatDuration].
  /// - Both display colours are the comment's own `backgroundColor`, the
  ///   background the website paints its chat line with.
  /// - The face is the sender's `picture` as the website shows it
  ///   (`THUMBNAIL_<file>` on the platform's CDN, or its own URL there).
  /// - It is [replayed] as its chat line is.
  static LiveMessage? superChat(Map<Object?, Object?> payload, {String id = '', DateTime? now, bool replayed = false}) {
    if (payload['type'] != commentType) return null;
    final chat = message(payload, id: id);
    final comment = optionalObject(payload['commentMsg']);
    if (chat == null || comment == null) return null;
    final barrage = optionalObject(comment['barrage']);
    final point = barrage?['point'];
    if (comment['barrageStyle'] != true || point is! int || point <= 0) return null;
    final body = optionalObject(comment['comment']);
    var text = _string(body?['text']).replaceAll('\n', ' ').trim();
    if (text.isEmpty) text = chat.text;
    final fill = backgroundColor(comment['backgroundColor']);
    final user = optionalObject(comment['displayUser']);
    final picture = _string(user?['picture']);
    final start = chat.sentAt ?? now ?? DateTime.now();
    return LiveMessage.normalized(
      type: LiveMessageType.superChat,
      sender: chat.sender,
      text: text,
      color: LiveMessageColor.white,
      messageId: id,
      sentAt: chat.sentAt,
      replayed: replayed,
      payload: LiveSuperChatMessage(
        messageId: id,
        userName: chat.effectiveSender.userName,
        faceUrl: picture.isEmpty
            ? ''
            : image(picture.startsWith('http://') || picture.startsWith('https://') ? picture : 'THUMBNAIL_$picture'),
        text: text,
        price: SuperChatPrice(
          amount: point,
          currency: pointUnit,
          displayText: '$point coins',
        ),
        startTime: start,
        endTime: start.add(superChatDuration),
        display: SuperChatDisplay(backgroundColor: fill, backgroundBottomColor: fill),
      ),
    );
  }

  /// The system notice of the live figures' `liveinfo.mute` turning [muted]
  /// ([mutedNotice], [unmutedNotice]), with the Ably message [id]; [replayed]
  /// when that message was.
  static LiveMessage muteNotice({required bool muted, String id = '', bool replayed = false}) =>
      LiveMessage.normalized(
        type: LiveMessageType.notice,
        text: muted ? mutedNotice : unmutedNotice,
        color: LiveMessageColor.white,
        messageId: id,
        payload: LiveNoticeKind.system,
        replayed: replayed,
      );

  /// A message's `data`: base64 of gzipped UTF-8 JSON, as the website reads it
  /// (`gzip_base64`); null when it is not that or not a JSON object.
  static Map<Object?, Object?>? payload(Object? data) {
    if (data is! String || data.isEmpty) return null;
    try {
      final value = jsonDecode(utf8.decode(gzip.decode(base64.decode(data))));
      return value is Map ? value : null;
    } on FormatException {
      return null;
    }
  }

  /// The message a decoded [payload] shows, with the Ably message [id]; null for
  /// every other type (reactions, entries, rankings, missions…).
  ///
  /// - A comment ([commentType], `commentMsg`) is chat, unless the website hides
  ///   it: `isDirty`, `isDirtyWord` or `isDirtyUser` is true. The text is
  ///   `content` (what the website shows; `comment.text` when it has none),
  ///   trimmed; a blank one shows nothing. The name is
  ///   `displayUser.displayName` (its `openID` without one), the user id
  ///   `displayUser.userID`, the level `displayUser.level` (`commentMsg`'s
  ///   without one), the colour `comment.textColor` ([color]) and the time
  ///   `sendTime` (milliseconds). The name's colour is `name.textColor`
  ///   ([nameColor]) and the badges the website draws by the name are [badges].
  ///   A barrage (a comment that also flies over the video on the website) is
  ///   chat as well; a paid one also has a super chat ([superChat]).
  /// - The live figures ([liveType]) carry `liveinfo.liveViewerCount`, the
  ///   viewers now, which the website shows: an audience update.
  /// - A gift ([giftType]) is a gift ([gift]).
  ///
  /// [replayed] marks a message of a backlog.
  static LiveMessage? message(Map<Object?, Object?> payload, {String id = '', bool replayed = false}) {
    switch (payload['type']) {
      case commentType:
        final comment = optionalObject(payload['commentMsg']);
        if (comment == null) return null;
        if (comment['isDirty'] == true || comment['isDirtyWord'] == true || comment['isDirtyUser'] == true) return null;
        final body = optionalObject(comment['comment']);
        var text = _string(comment['content']).trim();
        if (text.isEmpty && body != null) text = _string(body['text']).trim();
        if (text.isEmpty) return null;
        final user = optionalObject(comment['displayUser']);
        final name = _string(user?['displayName']);
        final level = _level(user?['level']) ?? _level(comment['level']);
        return LiveMessage.normalized(
          sender: MessageSender.normalized(
            userId: _string(user?['userID']),
            userName: name.isNotEmpty || user == null ? name : _string(user['openID']),
            userLevel: level == null ? null : '$level',
            nameColor: nameColor(comment['name']),
            badges: badges(comment),
          ),
          text: text,
          color: color(body?['textColor']),
          messageId: id,
          sentAt: timeMillis(comment['sendTime']),
          replayed: replayed,
        );
      case giftType:
        return gift(payload, id: id, replayed: replayed);
      case liveType:
        final viewers = optionalObject(payload['liveinfo'])?['liveViewerCount'];
        if (viewers is! int || viewers < 0) return null;
        return LiveMessage.normalized(
          type: LiveMessageType.audienceUpdate,
          color: LiveMessageColor.white,
          payload: audienceUpdate(viewers),
          replayed: replayed,
        );
      default:
        return null;
    }
  }

  /// A gift (`type` 13): `giftMsg` with `giftID`, `point` (its value in points; 0
  /// for the free daily gifts and tickets), the sender `displayUser` (read as a
  /// comment's) and `giftMetas`, whose entry for the gift (`targetGiftID`, else
  /// the first) has `combo.count`, the combo's sends so far (1, 2, 3…). One
  /// message is one gift (count 1): there is no combo id, so the app's own combo
  /// merge keys by sender and gift and shows `combo.count`. The text is
  /// `{giftID} ×1`. The name and the picture live in a gift table no anonymous
  /// request was found for, so the gift is unnamed. Null without a gift id.
  ///
  /// `combo.validDurationMs`, how long the website waits for the next send, has
  /// no field in this contract's combo state and is not carried.
  static LiveMessage? gift(Map<Object?, Object?> payload, {String id = '', bool replayed = false}) {
    final event = optionalObject(payload['giftMsg']);
    if (event == null) return null;
    final giftId = _string(event['giftID']).trim();
    if (giftId.isEmpty) return null;
    final metas = [for (final meta in optionalList(event['giftMetas'])) if (meta is Map) meta];
    final meta = metas.where((item) => item['targetGiftID'] == giftId).firstOrNull ?? metas.firstOrNull;
    final combo = optionalObject(meta?['combo']);
    final count = combo?['count'];
    final point = event['point'];
    final value = point is int && point >= 0 ? point : null;
    final gift = LiveGift(
      giftId: giftId,
      value: LiveGiftValue(
        unit: switch (value) {
          null => LiveGiftUnit.other,
          0 => LiveGiftUnit.free,
          _ => LiveGiftUnit.point,
        },
        unitPrice: value == null || value == 0 ? null : value.toDouble(),
        totalValue: value == null || value == 0 ? null : value.toDouble(),
      ),
      combo: LiveGiftCombo(comboTotal: count is int && count > 0 ? count : null),
    );
    final user = optionalObject(event['displayUser']);
    final name = _string(user?['displayName']);
    final level = _level(user?['level']);
    return LiveMessage.normalized(
      type: LiveMessageType.gift,
      sender: MessageSender.normalized(
        userId: _string(user?['userID']),
        userName: name.isNotEmpty || user == null ? name : _string(user['openID']),
        userLevel: level == null ? null : '$level',
      ),
      text: '$giftId ×1',
      color: LiveMessageColor.white,
      messageId: id,
      payload: gift,
      replayed: replayed,
    );
  }

  /// A comment colour: `#AARRGGBB` (the alpha first, as the website reads it) or
  /// `#RRGGBB`, the `#` optional; anything else is white, the website's default.
  static LiveMessageColor color(Object? value) {
    if (value is! String) return LiveMessageColor.white;
    var hex = value.trim();
    if (hex.startsWith('#')) hex = hex.substring(1);
    if (!_hexColor.hasMatch(hex)) return LiveMessageColor.white;
    return LiveMessageColor.numberToColor(int.parse(hex.substring(hex.length - 6), radix: 16));
  }

  /// The colour of a comment's sender name: `name.textColor` read as [color]
  /// reads a text colour; null when the comment has none that reads (the website
  /// then draws its default).
  static LiveMessageColor? nameColor(Object? name) {
    final value = optionalObject(name)?['textColor'];
    if (value is! String) return null;
    var hex = value.trim();
    if (hex.startsWith('#')) hex = hex.substring(1);
    return _hexColor.hasMatch(hex) ? color(hex) : null;
  }

  /// The badges of a comment: `{URL, styleID}` objects, the prefix badges
  /// (`prefixBadges`, then `prefixBadge`) first and the others in [badgeFields]
  /// order. A badge without a picture, or with one off the platform's hosts, is
  /// left out ([image], made https); a picture named twice is shown once.
  static List<LiveBadge> badges(Map<String, dynamic> comment) {
    final seen = <String>{};
    final result = <LiveBadge>[];
    void add(Object? badge) {
      if (badge is! Map) return;
      final url = image(badge['URL']);
      if (url.isEmpty || !seen.add(url)) return;
      result.add(LiveBadge(url: url, id: _string(badge['styleID']).trim()));
    }

    final prefixes = comment['prefixBadges'];
    if (prefixes is List) prefixes.take(badgeLimit).forEach(add);
    for (final field in badgeFields) {
      add(comment[field]);
    }
    return List.unmodifiable(result);
  }

  /// A comment's `backgroundColor` as `#RRGGBB` (upper case; the alpha of
  /// `#AARRGGBB` dropped, the `#` optional), or empty for anything else.
  static String backgroundColor(Object? value) {
    if (value is! String) return '';
    var hex = value.trim();
    if (hex.startsWith('#')) hex = hex.substring(1);
    if (!_hexColor.hasMatch(hex)) return '';
    return '#${hex.substring(hex.length - 6).toUpperCase()}';
  }

  /// The audience update of the live figures: the viewers now, as this
  /// contract's typed audience signal.
  static LiveAudienceUpdate audienceUpdate(int viewers) =>
      LiveAudienceUpdate(kind: LiveAudienceSignalKind.onlineViewers, value: viewers);

  static int? _level(Object? value) => value is int && value > 0 ? value : null;

  static String _string(Object? value) => value is String ? value : '';
}
