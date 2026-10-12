import 'dart:convert';

import 'package:live_sites/src/models/live_gift/live_gift.dart';
import 'package:live_sites/src/models/live_message/live_message.dart';
import 'package:live_sites/src/platforms/pandalive/parsers/pandalive_parser.dart';
import 'package:meta/meta.dart';

/// `live/play` refused the broadcast (ended, adult, password, fans only, not
/// live): its chat cannot be joined.
final class PandaLiveChatRefusal implements Exception {
  /// Creates the refusal with `errorData.code` [code] (empty without one).
  const new(this.code);

  /// `errorData.code` (`castEnd`, `needAdult`, `needLogin`, …), `not live`
  /// for an accepted answer whose broadcast is not live, or empty.
  final String code;

  @override
  String toString() => 'live/play: ${code.isEmpty ? 'refused' : code}';
}

/// What one PandaTV chat frame held ([PandaLiveDanmakuProtocol.decode]).
@immutable
final class PandaLiveDanmakuFrame {
  /// Creates the result.
  const new({this.messages = const [], this.joined = false, this.refusal});

  /// Chat and gifts, in order.
  final List<LiveMessage> messages;

  /// The server accepted the subscription (the reply to command 2).
  final bool joined;

  /// The server answered the connect or the subscription with an error
  /// (`connect: 109 token expired`), or null.
  final String? refusal;
}

/// PandaTV's chat, without I/O: a Centrifugo 3 server speaking its JSON
/// protocol, joined with the guest token of the broadcast's `live/play`.
///
/// - Every command carries an `id` its reply echoes, and one frame may hold
///   several newline-separated replies and pushes.
/// - The client connects with the guest token (a JWT of ~30 minutes) and
///   subscribes to its channel (the broadcaster's number); the server closes a
///   socket whose token is not valid.
/// - A publication on the channel is a push without an id; the inner `data` is
///   the message, whose `type` says what it is (`chatter`, `bj`, `manager`,
///   `support` are chat, `SponCoin` hearts).
///
/// Mapped onto this tree's models: a name colour is white (an int), a message
/// id is `id`, and hearts are a [LiveGift] of the platform's paid currency
/// (`하트`); the token's auto-renewal and the receiver name of a multistream tip
/// have no place here (the session asks a fresh token per connect, and the
/// reconnect is the caller's).
abstract final class PandaLiveDanmakuProtocol {
  /// The chat socket (the website's `newChat.node`).
  static final Uri endpoint = Uri.parse('wss://chat-ws.neolive.kr/connection/websocket');

  /// Ping period (centrifuge-js's default).
  static const Duration heartbeatInterval = Duration(seconds: 25);

  /// The id of the connect command.
  static const int connectId = 1;

  /// The id of the subscribe command; pings count on from it.
  static const int subscribeId = 2;

  /// Message types that are chat (the website's `isNormalChatMessage`).
  static const Set<String> chatTypes = {'bj', 'chatter', 'manager', 'support'};

  /// The platform's name of its currency (하트), as a [LiveGift.name].
  static const String heartName = '하트';

  /// Handshake headers: the site's origin and the desktop UA (the server also
  /// accepts a handshake without them).
  static Map<String, String> get socketHeaders => {
    'origin': PandaLiveParser.origin,
    'user-agent': PandaLiveParser.headers['user-agent']!,
  };

  static const int _maxEpochSeconds = 8640000000000;

  static final RegExp _channel = RegExp(r'^[0-9]{1,19}$');

  /// Printable ASCII without spaces: a token goes into a JSON command.
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

  /// The chat channel and token of a `live/play` answer. A refusal (a `result`
  /// that is not true, or an accepted broadcast that is not live) throws
  /// [PandaLiveChatRefusal]; an answer that cannot be read throws its
  /// `SiteError` (from [PandaLiveParser.data]) or a [FormatException] (no
  /// numeric channel or no usable token).
  static ({String channel, String token}) grant(String body, {required int status}) {
    final data = PandaLiveParser.data(body, status: status, what: 'live/play');
    if (data['result'] != true) {
      throw PandaLiveChatRefusal(_scalar(_map(data['errorData'])['code']).trim());
    }
    final media = data['media'];
    if (media is Map && media['isLive'] != true && media['isLive'] != 1) {
      throw const PandaLiveChatRefusal('not live');
    }
    final channel = _scalar(data['channel']).trim();
    final token = data['token'];
    if (!_channel.hasMatch(channel) || token is! String || !_token.hasMatch(token.trim())) {
      throw const FormatException('live/play: no chat channel or token');
    }
    return (channel: channel, token: token.trim());
  }

  /// One frame (text, or UTF-8 bytes) on [channel]: each line one JSON reply
  /// or push. The subscription reply joins; an error reply to the connect or
  /// the subscription is [PandaLiveDanmakuFrame.refusal]. A publication on
  /// [channel] whose message is chat ([chat]) or hearts ([hearts]) is reported;
  /// ping replies and other pushes give nothing. A line that is not a JSON
  /// object is skipped.
  static PandaLiveDanmakuFrame decode(Object? data, {required String channel}) {
    final text = switch (data) {
      final String text => text,
      final List<int> bytes => utf8.decode(bytes, allowMalformed: true),
      _ => null,
    };
    if (text == null) return const PandaLiveDanmakuFrame();
    final messages = <LiveMessage>[];
    var joined = false;
    String? refusal;
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
        }
        continue;
      }
      final result = reply['result'];
      if (result is! Map || result['type'] != null || _scalar(result['channel']).trim() != channel) continue;
      if (chat(result['data'], channel: channel) case final message?) messages.add(message);
      messages.addAll(hearts(result['data'], channel: channel));
    }
    return PandaLiveDanmakuFrame(messages: messages, joined: joined, refusal: refusal);
  }

  /// A publication (`{"data": <message>, "offset"}`) on [channel] as white
  /// chat, or null when its message is not chat. The text is `message`
  /// trimmed; without text an emoticon's bracketed name; the name is `nk`, the
  /// user id `id`; the id is `<channel>:<offset>`; the time `created_at`
  /// (seconds).
  static LiveMessage? chat(Object? publication, {required String channel}) {
    if (publication is! Map) return null;
    final message = publication['data'];
    if (message is! Map || !chatTypes.contains(message['type'])) return null;
    var text = _text(message['message']);
    if (text.isEmpty) text = _emoticon(message['emoticon']);
    if (text.isEmpty) return null;
    final offset = publication['offset'];
    return LiveMessage(
      type: LiveMessageType.chat,
      userName: _text(message['nk']),
      userId: _text(message['id']),
      message: text,
      id: offset is int && offset >= 0 ? '$channel:$offset' : null,
      sentAt: _time(message['created_at']),
      color: 0xFFFFFF,
    );
  }

  /// Hearts sent to the broadcast (`SponCoin`, 후원) as a gift of `coin`
  /// [LiveGift]s, then the words sent with them as a chat line; nothing for
  /// another message or one without a sender or hearts. A multistream tip's
  /// receiver name (`excelNick`) has no field here.
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
    final gift = LiveGift(name: heartName, count: coin, unitPrice: 1, totalValue: coin);
    final offset = publication['offset'];
    final id = offset is int && offset >= 0 ? '$channel:$offset' : '';
    final sentAt = _time(message['created_at']);
    final words = sponsor['heartMessage'] is Map ? _text((sponsor['heartMessage'] as Map)['message']) : '';
    return [
      LiveMessage(
        type: LiveMessageType.gift,
        userName: name,
        userId: _text(sponsor['id']),
        message: '$heartName ×$coin',
        id: id.isEmpty ? null : id,
        sentAt: sentAt,
        color: 0xFFFFFF,
        data: gift,
      ),
      if (words.isNotEmpty)
        LiveMessage(
          type: LiveMessageType.chat,
          userName: name,
          userId: _text(sponsor['id']),
          message: words,
          id: id.isEmpty ? null : '$id:words',
          sentAt: sentAt,
          color: 0xFFFFFF,
        ),
    ];
  }

  static String _emoticon(Object? emoticon) {
    if (emoticon is! Map) return '';
    for (final value in emoticon.values) {
      final name = value is Map ? _text(value['name']) : '';
      if (name.isNotEmpty) return '[$name]';
    }
    return '';
  }

  static String _error(Object? error) => error is Map ? '${error['code']} ${error['message']}'.trim() : '$error';

  static DateTime? _time(Object? value) =>
      value is int && value > 0 && value <= _maxEpochSeconds ? DateTime.fromMillisecondsSinceEpoch(value * 1000) : null;

  static String _text(Object? value) => switch (value) {
    final String text => text.trim(),
    final int number => '$number',
    _ => '',
  };

  static String _scalar(Object? value) => value is String || value is num ? '$value' : '';

  static Map<Object?, Object?> _map(Object? value) => value is Map ? value.cast<Object?, Object?>() : const {};
}
