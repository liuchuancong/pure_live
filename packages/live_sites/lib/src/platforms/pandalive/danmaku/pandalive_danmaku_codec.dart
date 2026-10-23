import 'dart:convert';

import 'package:live_sites/src/models/enums/live_gift_kind.dart';
import 'package:live_sites/src/models/enums/live_gift_unit.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/gift/live_gift_value/live_gift_value.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/message/message_sender/message_sender.dart';
import 'package:live_sites/src/platforms/pandalive/api/pandalive_endpoints.dart';
import 'package:live_sites/src/platforms/pandalive/api/pandalive_http.dart';
import 'package:live_sites/src/platforms/pandalive/parsers/pandalive_failure.dart';
import 'package:live_sites/src/platforms/pandalive/parsers/pandalive_json.dart';
import 'package:live_sites/src/platforms/pandalive/parsers/pandalive_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// What one PandaTV chat frame held.
final class PandaliveDanmakuFrame {
  /// Creates the result.
  const PandaliveDanmakuFrame({this.messages = const [], this.joined = false, this.refusal, this.expiresIn});

  /// Nothing to act on.
  static const PandaliveDanmakuFrame empty = PandaliveDanmakuFrame();

  /// Chat and hearts, in order.
  final List<LiveMessage> messages;

  /// The server accepted the subscription (the reply to command 2).
  final bool joined;

  /// The server answered the connect or the subscription with an error
  /// (`connect: 109 token expired`), or null.
  final String? refusal;

  /// When the connection's token lapses, from the connect reply
  /// (`expires`, `ttl`); null when it does not say.
  final Duration? expiresIn;
}

/// `live/play` refused the broadcast (ended, adult, password, fans only, not
/// live): its chat cannot be joined.
final class PandaliveChatRefusal implements Exception {
  /// Creates the refusal with `errorData.code` [code] (empty without one).
  const PandaliveChatRefusal(this.code);

  /// `errorData.code` (`castEnd`, `needAdult`, `needLogin`, ...), `not live`
  /// for an accepted answer whose broadcast is not live, or empty.
  final String code;

  @override
  String toString() => 'live/play: ${code.isEmpty ? 'refused' : code}';
}

/// The chat arguments of a broadcast: the broadcaster, its chat channel and
/// the guest token of its `live/play` answer.
final class PandaliveDanmakuArgs {
  /// Creates the arguments.
  const PandaliveDanmakuArgs({required this.userId, required this.channel, this.token});

  /// The broadcaster's login id: `live/play` issues a fresh token for it.
  final String userId;

  /// The chat channel: `live/play`'s `channel`, the broadcaster's number.
  final String channel;

  /// `live/play`'s chat `token` (a JWT of about 30 minutes); null when the
  /// answer had none.
  final String? token;

  @override
  String toString() => 'PandaliveDanmakuArgs($userId, $channel)';
}

/// PandaTV's chat, without I/O: a Centrifugo 3 server speaking its JSON
/// protocol.
///
/// - Every command carries an `id` its reply echoes, and one frame may hold
///   several newline-separated replies and pushes.
/// - The client connects with the guest token of the broadcast's
///   `live/play` (a JWT of 30 minutes) and subscribes to its channel (the
///   broadcaster's number). The server closes a socket whose token is not
///   valid (close code 3002, `invalid token`).
/// - It pings with command 7 every 25 s; the server answers every ping.
/// - A publication on the channel is a push without an id, `{"result":
///   {"channel": ..., "data": {"data": ..., "offset": ...}}}`; the inner
///   `data` is the message, whose `type` says what it is (`chatter`, `bj`,
///   `manager` and `support` are chat).
abstract final class PandaliveDanmakuCodec {
  /// The chat socket (`PandaliveEndpoints.chatUrl`, the website's
  /// `newChat.node`).
  static Uri get endpoint => Uri.parse(PandaliveEndpoints.chatUrl);

  /// Ping period (centrifuge-js's default and the website's session).
  static const Duration heartbeatInterval = Duration(seconds: 25);

  /// How long the connect and subscribe replies may take (the website's 8 s;
  /// they come within a second).
  static const Duration joinTimeout = Duration(seconds: 8);

  /// Silence after which the socket is replaced: the server answers every
  /// ping, so this only catches a half-open one.
  static const Duration silenceTimeout = Duration(seconds: 90);

  /// How long before a token lapses it is replaced: a handshake does not use
  /// a token that lapses sooner, and a joined socket is renewed this long
  /// before the server's `ttl` runs out.
  static const Duration renewalLead = Duration(seconds: 60);

  /// Refused joins in a row after which the connection gives up.
  static const int maxRefusals = 3;

  /// Reconnects without a joined run before the session gives up.
  static const int maxReconnects = 8;

  /// The base of the reconnect backoff, stepped once per failed run.
  static const Duration reconnectBaseDelay = Duration(seconds: 1);

  /// Handshake headers: the site's origin and the adapter's desktop UA, as
  /// the website sends them (the server also accepts a handshake without
  /// them).
  static const Map<String, String> socketHeaders = {
    'origin': PandaliveEndpoints.origin,
    'user-agent': PandaliveEndpoints.userAgent,
  };

  /// The id of the connect command.
  static const int connectId = 1;

  /// The id of the subscribe command; pings count on from it.
  static const int subscribeId = 2;

  /// Message types that are chat (the website's `isNormalChatMessage`).
  static const Set<String> chatTypes = {'bj', 'chatter', 'manager', 'support'};

  /// The platform's name of its currency (하트), as a [LiveGift.name].
  static const String heartName = '하트';

  static const int _maxEpochSeconds = 8640000000000;

  static final RegExp _channel = RegExp(r'^[0-9]{1,19}$');

  static final RegExp _token = RegExp(r'^[!-~]{1,4096}$');

  /// The connect command with [token].
  static String connect(String token) => jsonEncode({
    'params': {'token': token, 'name': 'js'},
    'id': connectId,
  });

  /// The subscribe command for [channel].
  static String subscribe(String channel) => jsonEncode({
    'method': 1,
    'params': {'channel': channel},
    'id': subscribeId,
  });

  /// The ping command with id [id].
  static String ping(int id) => jsonEncode({'method': 7, 'id': id});

  /// The chat channel and token of a `live/play` [response]. A refusal (HTTP
  /// 400 with `result: false`, or an accepted broadcast that is not live)
  /// throws [PandaliveChatRefusal]; an answer that cannot be read throws its
  /// [PandaliveFailure] (no numeric channel or no token included).
  static ({String channel, String token}) grant(PandaliveResponse response) {
    final data = PandaliveRoomParser.answer(response.text, what: 'live/play', status: response.status);
    if (data['result'] != true) throw PandaliveChatRefusal(PandaliveRoomParser.refusalCode(data));
    final media = data['media'];
    if (media is Map && PandaliveJson.flag(media['isLive']) == false) {
      throw const PandaliveChatRefusal('not live');
    }
    final channel = PandaliveJson.text(data['channel']);
    final token = data['token'] is String ? (data['token'] as String).trim() : '';
    if (!_channel.hasMatch(channel) || !_token.hasMatch(token)) {
      throw const PandaliveFailure(PandaliveFailureKind.apiChanged, 'live/play: no chat channel or token');
    }
    return (channel: channel, token: token);
  }

  /// When JWT [token] lapses (its payload's `exp`), or null when it does not
  /// say.
  static DateTime? tokenExpiry(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      final exp = payload is Map ? payload['exp'] : null;
      return exp is int && exp > 0 && exp <= _maxEpochSeconds
          ? DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true)
          : null;
    } on FormatException {
      return null;
    }
  }

  /// When a joined socket whose token lapses in [ttl] is renewed:
  /// [renewalLead] before, or halfway for a token shorter than twice that.
  static Duration renewalDelay(Duration ttl) => ttl > renewalLead * 2 ? ttl - renewalLead : ttl ~/ 2;

  /// [args] if they name a chat: a broadcaster id (`PandaliveEndpoints
  /// .normalizeUserId`) and a numeric channel, trimmed; a token that is not
  /// printable ASCII without spaces is dropped (a new one is asked for).
  /// Null otherwise.
  static PandaliveDanmakuArgs? checked(PandaliveDanmakuArgs args) {
    final userId = PandaliveEndpoints.normalizeUserId(args.userId);
    final channel = args.channel.trim();
    if (userId == null || !_channel.hasMatch(channel)) return null;
    final token = args.token?.trim();
    return PandaliveDanmakuArgs(
      userId: userId,
      channel: channel,
      token: token != null && _token.hasMatch(token) ? token : null,
    );
  }

  /// One frame (text, or UTF-8 bytes) on [channel]: each line one JSON
  /// reply or push.
  ///
  /// - The reply to the subscription joins; an error reply to the connect or
  ///   the subscription is a [PandaliveDanmakuFrame.refusal]; the connect
  ///   reply says when the token lapses. Ping replies say nothing.
  /// - A publication on [channel] (a push without `type`) whose message is
  ///   chat ([chat]) or hearts ([hearts]) is reported; other channels, other
  ///   pushes (join, leave, unsubscribe) and other messages give nothing.
  /// - A line that is not a JSON object is skipped.
  static PandaliveDanmakuFrame decode(Object? data, {required String channel}) {
    final text = switch (data) {
      final String text => text,
      final List<int> bytes => utf8.decode(bytes, allowMalformed: true),
      _ => null,
    };
    if (text == null) return PandaliveDanmakuFrame.empty;
    final messages = <LiveMessage>[];
    var joined = false;
    String? refusal;
    Duration? expiresIn;
    for (final line in const LineSplitter().convert(text)) {
      if (line.trim().isEmpty) continue;
      final Object? reply;
      try {
        reply = jsonDecode(line);
      } on FormatException {
        continue;
      }
      if (reply is! Map) continue;
      final id = reply['id'];
      if (id != null) {
        if (id != connectId && id != subscribeId) continue;
        final error = reply['error'];
        if (error != null) {
          refusal ??= '${id == connectId ? 'connect' : 'subscribe'}: ${_error(error)}';
        } else if (id == subscribeId) {
          joined = true;
        } else if (reply['result'] case {'expires': true, 'ttl': final int ttl} when ttl > 0) {
          expiresIn = Duration(seconds: ttl);
        }
        continue;
      }
      final result = reply['result'];
      if (result is! Map || result['type'] != null || PandaliveJson.text(result['channel']) != channel) continue;
      if (chat(result['data'], channel: channel) case final LiveMessage message) messages.add(message);
      messages.addAll(hearts(result['data'], channel: channel));
    }
    return PandaliveDanmakuFrame(messages: messages, joined: joined, refusal: refusal, expiresIn: expiresIn);
  }

  static String _error(Object? error) => error is Map ? '${error['code']} ${error['message']}'.trim() : '$error';

  /// A publication (`{"data": <message>, "offset"}`) on [channel] as white
  /// chat, or null when its message is not chat:
  ///
  /// - the type is one of [chatTypes];
  /// - the text is `message` trimmed; without text, an emoticon's name in
  ///   brackets (`[pandaS하트다발png]`, as the website shows an
  ///   emoticon-only message); neither: null;
  /// - the name is `nk`, the user id `id` (the login id);
  /// - the message id is `<channel>:<offset>`, the publication's place in
  ///   the channel;
  /// - the time is `created_at` (seconds); not positive or out of
  ///   `DateTime`'s range: none.
  ///
  /// `idx`, `ip`, `sex`, `lang`, the translation fields and `filtered` are
  /// not read.
  static LiveMessage? chat(Object? publication, {required String channel}) {
    if (publication is! Map) return null;
    final message = publication['data'];
    if (message is! Map || !chatTypes.contains(message['type'])) return null;
    var text = _text(message['message']);
    if (text.isEmpty) text = _emoticon(message['emoticon']);
    if (text.isEmpty) return null;
    final offset = publication['offset'];
    final created = message['created_at'];
    return LiveMessage.normalized(
      sender: MessageSender.normalized(userId: _text(message['id']), userName: _text(message['nk'])),
      text: text,
      color: LiveMessageColor.white,
      messageId: offset is int && offset >= 0 ? '$channel:$offset' : '',
      sentAt: _timeOf(created),
    );
  }

  /// Hearts sent to the broadcast (`SponCoin`, 후원) as a
  /// [LiveMessageType.gift] message with a [LiveGift] of kind
  /// [LiveGiftKind.tip] valued in hearts, then the words sent with them as
  /// chat; nothing for another message or one without a sender or hearts:
  ///
  /// - the publication's `message` is a JSON object in text: `nick` the
  ///   sender's name, `id` the login id, `coin` the hearts (their own
  ///   value: unit price 1, total `coin`); in a show of several broadcasters
  ///   (엑셀방송) `excelNick` names the one who receives them (the gift's
  ///   recipient);
  /// - the id and time as [chat]'s;
  /// - the words (`heartMessage.message`, which no chat publication
  ///   repeats) are a white chat line of the sender after the hearts, with
  ///   the id `<channel>:<offset>:words`.
  static List<LiveMessage> hearts(Object? publication, {required String channel}) {
    if (publication is! Map) return const [];
    final message = publication['data'];
    if (message is! Map || message['type'] != 'SponCoin') return const [];
    final Object? sponsor;
    try {
      sponsor = jsonDecode(_text(message['message']));
    } on FormatException {
      return const [];
    }
    if (sponsor is! Map) return const [];
    final coin = sponsor['coin'];
    final name = _text(sponsor['nick']);
    if (coin is! int || coin <= 0 || name.isEmpty) return const [];
    final gift = LiveGift.of(
      name: heartName,
      count: coin,
      kind: LiveGiftKind.tip,
      // The hearts are the platform's own denomination (about 110 won each).
      value: LiveGiftValue.of(unit: LiveGiftUnit.heart, unitPrice: 1, totalValue: coin.toDouble()),
      recipientName: _text(sponsor['excelNick']),
    );
    final offset = publication['offset'];
    final created = message['created_at'];
    final id = offset is int && offset >= 0 ? '$channel:$offset' : '';
    final sentAt = _timeOf(created);
    final words = sponsor['heartMessage'] is Map ? _text((sponsor['heartMessage'] as Map)['message']) : '';
    return [
      LiveMessage.normalized(
        type: LiveMessageType.gift,
        sender: MessageSender.normalized(userId: _text(sponsor['id']), userName: name),
        text: '$heartName ×$coin',
        color: LiveMessageColor.white,
        messageId: id,
        sentAt: sentAt,
        payload: gift,
      ),
      if (words.isNotEmpty)
        LiveMessage.normalized(
          sender: MessageSender.normalized(userId: _text(sponsor['id']), userName: name),
          text: words,
          color: LiveMessageColor.white,
          messageId: id.isEmpty ? '' : '$id:words',
          sentAt: sentAt,
        ),
    ];
  }

  /// The first named emoticon of `emoticon` (`{"block": {name, img, ...},
  /// "inline": [...]}`) in brackets, or empty.
  static String _emoticon(Object? emoticon) {
    if (emoticon is! Map) return '';
    for (final value in emoticon.values) {
      final name = value is Map ? _text(value['name']) : '';
      if (name.isNotEmpty) return '[$name]';
    }
    return '';
  }

  static DateTime? _timeOf(Object? created) => created is int && created > 0 && created <= _maxEpochSeconds
      ? DateTime.fromMillisecondsSinceEpoch(created * 1000)
      : null;

  static String _text(Object? value) => switch (value) {
    final String text => text.trim(),
    final int number => '$number',
    _ => '',
  };
}
