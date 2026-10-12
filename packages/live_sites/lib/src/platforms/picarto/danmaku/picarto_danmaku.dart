import 'dart:convert';

import 'package:live_sites/src/models/live_gift/live_gift.dart';
import 'package:live_sites/src/models/live_message/live_message.dart';
import 'package:live_sites/src/platforms/picarto/parsers/picarto_parser.dart';
import 'package:meta/meta.dart';

/// What one Picarto chat frame held ([PicartoDanmakuProtocol.decode]).
@immutable
final class PicartoDanmakuFrame {
  /// Creates the result.
  const new({this.messages = const [], this.tokenRefused = false});

  /// Chat and audience updates, in order.
  final List<LiveMessage> messages;

  /// The chat server refused the token (`{"success":false,"code":"JWT_TOKEN"}`);
  /// it keeps the socket open but sends nothing else.
  final bool tokenRefused;
}

/// Picarto's chat, without I/O: an anonymous JWT from the site's GraphQL API
/// names the channel, and a WebSocket of JSON text frames carries the chat.
///
/// 3.x had no Picarto danmaku; this follows the archived v4 connector and the
/// site's own chat client, which sends the keep-alive [heartbeat] every 50 s.
///
/// Mapped onto this tree's models: a name colour is an int, the tip's avatar
/// and the super chat's colours have no field here (dropped), a tip counts as
/// a [LiveSuperChat] of `x` Kudos, and a deleted or cleared message becomes a
/// [LiveMessageType.recall] naming it by id or user.
abstract final class PicartoDanmakuProtocol {
  /// The GraphQL endpoint that issues chat tokens.
  static Uri get tokenEndpoint => Uri.https(PicartoParser.apiHost, '/ptvapi');

  /// The GraphQL query of a chat token; anonymous callers get one with
  /// `userId 0` and no expiry.
  static const String tokenQuery = r'query ($name: String) { generateJwtToken(channel_name: $name) { key } }';

  /// The JSON body asking a token for [channelName].
  static Map<String, Object?> tokenBody(String channelName) => {
    'query': tokenQuery,
    'variables': {'name': channelName},
  };

  static final RegExp _jwt = RegExp(r'^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$');

  /// The token of a decoded GraphQL answer, or null: an unknown channel gives
  /// `{"key": null}`. Only a JWT (three base64url parts) is taken, as it goes
  /// into the socket's path.
  static String? token(Object? answer) {
    if (answer case {'data': {'generateJwtToken': {'key': final String key}}} when _jwt.hasMatch(key)) return key;
    return null;
  }

  /// The chat socket of [token] (the token is part of the path).
  static Uri endpoint(String token) => Uri.parse('wss://chat.picarto.tv/chat/token=$token');

  /// Handshake headers: the site's origin and the desktop UA every Picarto
  /// request carries.
  static Map<String, String> get handshakeHeaders => {
    'origin': PicartoParser.web,
    'user-agent': PicartoParser.headers['user-agent']!,
  };

  /// Keep-alive period: the site's chat client pings every 50 s.
  static const Duration heartbeatInterval = Duration(seconds: 50);

  /// The site's keep-alive frame; the server answers
  /// `{"success":true,"code":"PONG"}`, so even a silent channel never looks
  /// dead.
  static const String heartbeat = '{"type":"ping","message":"__ping__"}';

  /// The refusal code of a token the chat server does not accept.
  static const String refusedCode = 'JWT_TOKEN';

  /// How long a chip tip stays in the super chat bar: the site never takes it
  /// out, so this is bilibili's shortest super chat.
  static const Duration tipDuration = Duration(seconds: 60);

  /// The name the site gives the chips of a tip (`{count} Kudos`).
  static const String tipUnit = 'Kudos';

  /// Largest time [DateTime] can hold, in milliseconds.
  static const int _maxMillis = 8640000000000000;

  static final RegExp _hex6 = RegExp(r'^[0-9a-fA-F]{6}$');
  static final RegExp _hex3 = RegExp(r'^[0-9a-fA-F]{3}$');

  /// Reads one text frame of [channelId]'s chat socket, received [now];
  /// [channelName] is the room's channel.
  ///
  /// Frames are JSON objects named by `type` or `t`, with their payload in
  /// `messages` or `m`:
  ///
  /// - `c` and `ct` (chat, chip tips) and `system`: a list of lines, each read
  ///   by its own type ([line]); a `system` frame for moderators (`c` is `b`)
  ///   is skipped, as the site shows it only to them;
  /// - `raid` ([raid]), `ns` ([subscription]): one notice;
  /// - `rm` ([deletion]), `cm` ([clearance]): a recall;
  /// - `stream`: the channel's state, whose `viewers` is the audience
  ///   ([audience]);
  /// - `{"success":false,"code":"JWT_TOKEN"}`: the token was refused.
  ///
  /// A page of history (`paginated`/`p`) and everything else (joins, the user
  /// list, whispers, polls, raffles, the ping answer) hold nothing to show, so
  /// does a frame that is not a JSON object. A field of the wrong type costs
  /// only that field or that line, never the frame.
  static PicartoDanmakuFrame decode(String text, {required int channelId, String channelName = '', DateTime? now}) {
    final Object? root;
    try {
      root = jsonDecode(text);
    } on FormatException {
      return const PicartoDanmakuFrame();
    }
    if (root is! Map) return const PicartoDanmakuFrame();
    if (root['success'] == false && root['code'] == refusedCode) return const PicartoDanmakuFrame(tokenRefused: true);
    final payload = root['messages'] ?? root['m'];
    final type = root['type'] ?? root['t'];
    if (type == 'stream') return PicartoDanmakuFrame(messages: [?audience(payload, channelId: channelId)]);
    if (_truthy(root['paginated'] ?? root['p'])) return const PicartoDanmakuFrame();
    final receivedAt = now ?? DateTime.now();
    List<LiveMessage> lines(List<Object?> lines) => [
      for (final entry in lines) ?line(entry, receivedAt: receivedAt, channelName: channelName),
    ];
    return PicartoDanmakuFrame(
      messages: switch (type) {
        'c' || 'ct' when payload is List => lines(payload),
        'system' when payload is List && root['c'] != 'b' => lines([
          for (final entry in payload)
            if (entry is Map && entry['t'] != null) entry,
        ]),
        'raid' => [?raid(payload)],
        'ns' => [?subscription(payload)],
        'rm' => [?deletion(payload)],
        'cm' => [?clearance(payload)],
        _ => const [],
      },
    );
  }

  /// One line of a `c`, `ct` or `system` frame, by its type `t`: a chip tip
  /// ([tip]) when `v` is set or the type is `ct`, chat ([chat]) for `c` or no
  /// type, a system notice ([system]) for `system`; other types are not shown.
  static LiveMessage? line(Object? line, {required DateTime receivedAt, String channelName = ''}) {
    if (line is! Map) return null;
    return switch (line['t']) {
      null || 'c' when _truthy(line['v']) => tip(line, receivedAt: receivedAt, channelName: channelName),
      'ct' => tip(line, receivedAt: receivedAt, channelName: channelName),
      null || 'c' => chat(line),
      'system' => system(line),
      _ => null,
    };
  }

  /// One chat line, or null when it is not a chat line or holds no text.
  ///
  /// Fields: `n` name, `u` user id, `m` text (trimmed), `id`/`_id` the id, `d`
  /// the time in ms, `k` the name colour (hex; else white). The channel the
  /// line was written in (`c`) is not checked: co-streaming channels share one
  /// chat. Emotes stay as `:name:` in the text.
  static LiveMessage? chat(Object? line) {
    if (line is! Map) return null;
    final type = line['t'];
    if (type != null && type != 'c') return null;
    final text = line['m'];
    if (text is! String || text.trim().isEmpty) return null;
    final id = _messageId(line);
    return LiveMessage(
      type: LiveMessageType.chat,
      userName: _scalar(line['n']),
      userId: _scalar(line['u']),
      message: text.trim(),
      color: color(line['k']),
      id: id.isEmpty ? null : id,
      sentAt: _time(line['d']),
    );
  }

  /// A chip tip as a super chat, or null without a whole number of chips above
  /// zero (`x`). The price is `x` chips (`x Kudos`), the sender `n`, the text
  /// `m`; a tip to another channel of a multistream (`rn`) says so before its
  /// text: `打赏给 <rn>：<text>`. The avatar and the site's framing have no field
  /// here. The line's id, user and time travel so a recall takes it back.
  static LiveMessage? tip(Map<Object?, Object?> line, {required DateTime receivedAt, String channelName = ''}) {
    final chips = line['x'];
    if (chips is! int || chips <= 0) return null;
    final id = _messageId(line);
    final sentAt = _time(line['d']);
    final start = sentAt ?? receivedAt;
    final text = switch (line['m']) {
      final String text => text.trim(),
      _ => '',
    };
    final receiver = _scalar(line['rn']).trim();
    final elsewhere =
        receiver.isNotEmpty && channelName.isNotEmpty && receiver.toLowerCase() != channelName.toLowerCase();
    final message = !elsewhere
        ? text
        : text.isEmpty
        ? '打赏给 $receiver'
        : '打赏给 $receiver：$text';
    return LiveMessage(
      type: LiveMessageType.superChat,
      userName: _scalar(line['n']),
      userId: _scalar(line['u']),
      message: message,
      color: 0xFFFFFF,
      id: id.isEmpty ? null : id,
      sentAt: sentAt,
      data: LiveSuperChat(
        message: message,
        price: chips,
        priceText: '$chips $tipUnit',
        startTime: start,
        endTime: start.add(tipDuration),
      ),
    );
  }

  /// A system line as a notice, or null when it has no text. The site replaces
  /// each `{link}` with a link's text and drops each `{icon}`, joining lines
  /// with a space; the k-th link is `l[2k + 1]`, else `l[0]`.
  static LiveMessage? system(Map<Object?, Object?> line) {
    var text = line['m'];
    if (text is! String) return null;
    if (line['ic'] is List) text = text.replaceAll('{icon}', '');
    if (line['l'] case final List<Object?> links) {
      var index = 0;
      text = text.replaceAllMapped('{link}', (_) {
        final position = 2 * index++ + 1;
        final link = position < links.length ? links[position] : links.firstOrNull;
        return switch (link) {
          {'text': final String text} => text,
          _ => '',
        };
      });
    }
    final sentence = [
      for (final part in text.split('\n'))
        if (part.trim().isNotEmpty) part.trim(),
    ].join(' ');
    return sentence.isEmpty ? null : _notice('system', sentence);
  }

  /// A `raid` frame as a notice, or null. The server's own sentence `m` wins;
  /// otherwise `<n> 突袭了 <rn>`.
  static LiveMessage? raid(Object? raid) {
    if (raid is! Map) return null;
    final text = switch (raid['m']) {
      final String text => text.trim(),
      _ => '',
    };
    if (text.isNotEmpty) return _notice('raid', text);
    final (from, to) = (_scalar(raid['n']).trim(), _scalar(raid['rn']).trim());
    if (from.isEmpty || to.isEmpty) return null;
    return _notice('raid', '$from 突袭了 $to');
  }

  /// An `ns` frame as a subscription notice, or null when a name the sentence
  /// needs is missing. The site's English sentence is told in Chinese: a
  /// plain (`md` months) or levelled (`slvl`) subscription, a gift (`sg`) to a
  /// viewer (`gn`) or the community (`sc`, `k` of them), anonymous (`ag`) or
  /// not.
  static LiveMessage? subscription(Object? subscription) {
    if (subscription is! Map) return null;
    String name(String key) => _scalar(subscription[key]).trim();
    final (sender, channel, receiver) = (name('sn'), name('n'), name('gn'));
    final months = _truthy(subscription['md']) && name('md').isNotEmpty ? name('md') : '1';
    final recipients = switch (subscription['sc']) {
      final List<Object?> list => list.length,
      _ => 0,
    };
    final level = _truthy(subscription['slvl']) ? name('slvl') : '';
    final String? text;
    if (_truthy(subscription['sg'])) {
      text = switch ((_truthy(subscription['ag']), recipients > 0)) {
        (true, true) when channel.isNotEmpty => '有人匿名向 Picarto 社区赠送了 $recipients 份 $channel 的订阅',
        (true, false) when receiver.isNotEmpty && channel.isNotEmpty => '$receiver 收到匿名赠送的 $months 个月 $channel 订阅',
        (false, true) when sender.isNotEmpty && channel.isNotEmpty =>
          '$sender 向 Picarto 社区赠送了 $recipients 份 $channel 的订阅',
        (false, false) when sender.isNotEmpty && receiver.isNotEmpty => '$sender 赠送给 $receiver $months 个月订阅',
        _ => null,
      };
    } else if (sender.isEmpty || channel.isEmpty) {
      text = null;
    } else {
      text = level.isNotEmpty ? '$sender 开通了 $channel 的 $level 级订阅' : '$sender 订阅了 $channel，$months 个月';
    }
    return text == null ? null : _notice('subscription', text);
  }

  /// An `rm` frame (a deleted message): the recall of the message `id`, or
  /// null.
  static LiveMessage? deletion(Object? deletion) {
    if (deletion case {'id': final String id} when id.trim().isNotEmpty) {
      return LiveMessage(type: LiveMessageType.recall, userName: '', message: '', id: id.trim());
    }
    return null;
  }

  /// A `cm` frame (a cleared user): the recall of every message of user `u`,
  /// or null.
  static LiveMessage? clearance(Object? clearance) {
    if (clearance is! Map) return null;
    final user = _scalar(clearance['u']);
    return user.trim().isEmpty
        ? null
        : LiveMessage(type: LiveMessageType.recall, userName: '', message: '', userId: user);
  }

  /// The concurrent audience of a `stream` frame's [state], or null. A frame
  /// naming another channel (`id`) is skipped; `viewers` must be a whole
  /// number, not negative.
  static LiveMessage? audience(Object? state, {required int channelId}) {
    if (state is! Map) return null;
    final id = state['id'];
    if (id != null && '$id' != '$channelId') return null;
    final viewers = _count(state['viewers']);
    if (viewers == null) return null;
    return LiveMessage(
      type: LiveMessageType.audienceUpdate,
      userName: '',
      message: '',
      data: LiveAudienceUpdate(onlineViewers: viewers),
    );
  }

  /// A name colour: 6 hex digits, optionally after `#`, or the 3-digit CSS
  /// short form; anything else is white.
  static int color(Object? value) {
    if (value is! String) return 0xFFFFFF;
    var hex = value.trim();
    if (hex.startsWith('#')) hex = hex.substring(1);
    if (_hex3.hasMatch(hex)) hex = hex.split('').map((digit) => '$digit$digit').join();
    if (!_hex6.hasMatch(hex)) return 0xFFFFFF;
    return int.parse(hex, radix: 16);
  }

  static LiveMessage _notice(String kind, String text) =>
      LiveMessage(type: LiveMessageType.notice, userName: '', message: text, data: kind);

  /// A line's id: `id`, else `_id` (the site's `id || _id`), when it is text.
  static String _messageId(Map<Object?, Object?> line) => switch (line['id'] ?? line['_id']) {
    final String id => id,
    _ => '',
  };

  /// A time in milliseconds (`d`), or null when it is not a whole number
  /// [DateTime] can hold.
  static DateTime? _time(Object? millis) =>
      millis is int && millis.abs() <= _maxMillis ? DateTime.fromMillisecondsSinceEpoch(millis) : null;

  static int? _count(Object? value) {
    final count = value is int ? value : int.tryParse('${value ?? ''}'.trim());
    return count != null && count >= 0 ? count : null;
  }

  static String _scalar(Object? value) => value is String || value is num ? '$value' : '';

  /// JavaScript truthiness, as the site's client tests `paginated || p`.
  static bool _truthy(Object? value) => switch (value) {
    null => false,
    final bool flag => flag,
    final num number => number != 0 && !number.isNaN,
    final String text => text.isNotEmpty,
    _ => true,
  };
}
