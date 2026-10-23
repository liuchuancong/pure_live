import 'dart:convert';

import 'package:live_sites/src/models/audience/live_audience_update/live_audience_update.dart';
import 'package:live_sites/src/models/enums/live_audience_signal_kind.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/enums/live_notice_kind.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/message/live_retraction/live_retraction.dart';
import 'package:live_sites/src/models/message/message_sender/message_sender.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_message/live_super_chat_message.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_price/live_super_chat_price.dart';
import 'package:live_sites/src/platforms/picarto/api/picarto_endpoints.dart';
import 'package:meta/meta.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// What one Picarto chat frame held.
@immutable
final class PicartoDanmakuFrame {
  /// Creates the result.
  const PicartoDanmakuFrame({this.messages = const [], this.tokenRefused = false});

  /// Nothing to act on.
  static const PicartoDanmakuFrame empty = PicartoDanmakuFrame();

  /// Chat, chip tips, notices and audience updates, in order.
  final List<LiveMessage> messages;

  /// The chat server refused the token (`{"success":false,"code":"JWT_TOKEN"}`);
  /// it keeps the socket open but sends nothing else.
  final bool tokenRefused;
}

/// What the danmaku connection needs to join one channel's chat: the channel
/// name (the token request takes it) and the channel's numeric id, which
/// chat messages name their channel by.
@immutable
final class PicartoDanmakuArgs {
  /// Creates the arguments.
  const PicartoDanmakuArgs({required this.channelName, required this.channelId});

  /// The channel name as the platform writes it (`generateJwtToken` takes
  /// it).
  final String channelName;

  /// The channel's numeric id.
  final int channelId;

  @override
  String toString() => 'PicartoDanmakuArgs($channelName, $channelId)';
}

/// Picarto's chat, without I/O: an anonymous JWT from the site's GraphQL API
/// names the channel, and a WebSocket of JSON text frames carries the chat.
///
/// The site's own chat client sends the keep-alive [heartbeat] every 50 s and
/// reads both spellings of a frame's type and payload (`type`/`t`,
/// `messages`/`m`).
abstract final class PicartoDanmakuCodec {
  /// The GraphQL query of a chat token; anonymous callers get one with
  /// `userId 0` and no expiry.
  static const String tokenQuery = r'query ($name: String) { generateJwtToken(channel_name: $name) { key } }';

  /// The JSON body asking a token for [channelName] (the platform's
  /// spelling).
  static Map<String, Object?> tokenBody(String channelName) => {
    'query': tokenQuery,
    'variables': {'name': channelName},
  };

  static final RegExp _jwt = RegExp(r'^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$');

  /// The token of a decoded GraphQL answer, or null: an unknown channel
  /// gives `{"key": null}`. Only a JWT (three base64url parts) is taken, as
  /// it goes into the socket's path.
  static String? token(Object? answer) {
    if (answer case {'data': {'generateJwtToken': {'key': final String key}}} when _jwt.hasMatch(key)) {
      return key;
    }
    return null;
  }

  /// The chat socket of [token] (the token is part of the path).
  static Uri endpoint(String token) => Uri.parse('wss://${PicartoEndpoints.chatHost}/chat/token=$token');

  /// Handshake headers: the site's origin and the desktop user agent every
  /// Picarto request carries.
  static const Map<String, String> handshakeHeaders = {
    'origin': PicartoEndpoints.origin,
    'user-agent': PicartoEndpoints.userAgent,
  };

  /// Keep-alive period: the site's chat client pings every 50 s.
  static const Duration heartbeatInterval = Duration(seconds: 50);

  /// The site's keep-alive frame; the server answers
  /// `{"success":true,"code":"PONG"}`, so even a channel whose chat is
  /// silent (every offline one) never looks dead.
  static const String heartbeat = '{"type":"ping","message":"__ping__"}';

  /// Silence after which the socket is replaced: the server answers every
  /// keep-alive, so a socket silent for max(3 × 50 s, 90 s) = 150 s is
  /// half-open.
  static const Duration silenceTimeout = Duration(seconds: 150);

  /// The join budget: an open socket counts as joined (the server sends no
  /// welcome), so this only bounds the handshake.
  static const Duration joinTimeout = Duration(seconds: 10);

  /// How long a chip tip stays in the super chat bar. The site shows a tip
  /// as a framed line in the chat and never takes it out, so it names no
  /// time; 60 s is bilibili's shortest super chat (the bar was made for
  /// it), and a Kudo is worth a cent to the streamer, so tips are small.
  static const Duration tipDuration = Duration(seconds: 60);

  /// The refusal code of a token the chat server does not accept.
  static const String refusedCode = 'JWT_TOKEN';

  /// Refused tokens replaced before the session gives up.
  static const int maxTokenRefreshes = 3;

  /// Reconnects without a joined run before the session gives up (the v2
  /// reconnect budget).
  static const int maxReconnects = 8;

  /// The base of the reconnect backoff, stepped once per failed run.
  static const Duration reconnectBaseDelay = Duration(seconds: 1);

  /// Token requests per attempt to get one.
  static const int tokenAttempts = 3;

  /// The step between token attempts.
  static const Duration tokenRetryDelay = Duration(milliseconds: 500);

  /// Longest wait for one token answer.
  static const Duration tokenTimeout = Duration(seconds: 5);

  /// Where avatar paths of chat lines (`i`) live (the site's prefix).
  static const String imageBase = 'https://images.picarto.tv/';

  /// The name the site gives the chips of a tip (`{count} Kudos`).
  static const String tipUnit = 'Kudos';

  static const int _maxMillis = 8640000000000000;

  static final RegExp _hex6 = RegExp(r'^[0-9a-fA-F]{6}$');
  static final RegExp _hex3 = RegExp(r'^[0-9a-fA-F]{3}$');

  /// Reads one text frame of [channelId]'s chat socket, received [now]
  /// (default: the current time); [channelName] is the room's channel.
  ///
  /// Frames are JSON objects named by `type` or `t`, with their payload in
  /// `messages` or `m` (the site's client reads both spellings):
  ///
  /// - `c` and `ct` (chat, chip tips) and `system`: a list of lines, each
  ///   read by its own type ([line]); a `system` frame for moderators
  ///   (`c` is `b`) is skipped, as the site shows it only to them, and so
  ///   are its lines without a type;
  /// - `raid` ([raid]), `ns` ([subscription]): one notice;
  /// - `rm` ([deletion]), `cm` ([clearance]): a retraction;
  /// - `stream`: the channel's state, whose `viewers` is the concurrent
  ///   audience ([audience]);
  /// - `{"success":false,"code":"JWT_TOKEN"}`: the token was refused.
  ///
  /// A page of history (`paginated` or `p` set) is skipped, as the site's
  /// client skips it. Everything else (joins and leaves, the user list,
  /// whispers, polls, raffles, the answer to [heartbeat]) holds nothing to
  /// show; so does a frame that is not a JSON object. A field of the wrong
  /// type costs only that field (a time out of range, a colour that is not
  /// text) or that line (text that is not text), never the frame.
  static PicartoDanmakuFrame decode(String text, {required int channelId, String channelName = '', DateTime? now}) {
    final Object? root;
    try {
      root = jsonDecode(text);
    } on FormatException {
      return PicartoDanmakuFrame.empty;
    }
    if (root is! Map) return PicartoDanmakuFrame.empty;
    if (root['success'] == false && root['code'] == refusedCode) {
      return const PicartoDanmakuFrame(tokenRefused: true);
    }
    final payload = root['messages'] ?? root['m'];
    final type = root['type'] ?? root['t'];
    if (type == 'stream') {
      final update = audience(payload, channelId: channelId);
      return update == null ? PicartoDanmakuFrame.empty : PicartoDanmakuFrame(messages: [update]);
    }
    if (_truthy(root['paginated'] ?? root['p'])) return PicartoDanmakuFrame.empty;
    final receivedAt = now ?? DateTime.now();
    List<LiveMessage> lines(List<Object?> lines) => [
      for (final entry in lines) ?line(entry, receivedAt: receivedAt, channelName: channelName),
    ];
    final messages = switch (type) {
      'c' || 'ct' when payload is List => lines(payload),
      // The site shows no line without a type; only a chat frame's are
      // taken as chat.
      'system' when payload is List && root['c'] != 'b' => lines([
        for (final entry in payload)
          if (entry is Map && entry['t'] != null) entry,
      ]),
      'raid' => [?raid(payload)],
      'ns' => [?subscription(payload)],
      'rm' => [?deletion(payload)],
      'cm' => [?clearance(payload)],
      _ => const <LiveMessage>[],
    };
    return messages.isEmpty ? PicartoDanmakuFrame.empty : PicartoDanmakuFrame(messages: messages);
  }

  /// One line of a `c`, `ct` or `system` frame, by its type `t` (the site
  /// maps `c` to chat, `ct` to a chip tip, `system` to a notice):
  ///
  /// - a chip tip ([tip]): a chat line whose `v` (the site's `tipping`) is
  ///   set, as recorded (with `x`, `mc`, `mk`), or a `ct` line;
  /// - chat ([chat]): `c`, or no type;
  /// - a system notice ([system]): `system`.
  ///
  /// Other types (whispers, polls, raffles) are not shown. [receivedAt] is
  /// the start of a tip without a time; [channelName] is the room's channel.
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

  /// One chat line, or null when it is not a chat line (`t` other than `c`)
  /// or holds no text.
  ///
  /// Fields: `n` name, `u` user id, `m` text (trimmed), `id` (or `_id`) the
  /// message id, `d` the time in milliseconds, `k` the name colour (hex
  /// without `#`; anything else is white). `c` (the channel the line was
  /// written in) is not checked: channels streaming together share one chat,
  /// and the site shows all of it. Emotes stay as `:name:` in the text.
  static LiveMessage? chat(Object? line) {
    if (line is! Map) return null;
    final type = line['t'];
    if (type != null && type != 'c') return null;
    final text = line['m'];
    if (text is! String || text.trim().isEmpty) return null;
    return LiveMessage.normalized(
      sender: MessageSender.normalized(
        userId: _scalar(line['u']),
        userName: _scalar(line['n']),
        nameColor: color(line['k']),
      ),
      text: text.trim(),
      color: LiveMessageColor.white,
      messageId: _messageId(line),
      sentAt: _time(line['d']),
    );
  }

  /// A chip tip as a super chat, or null without a whole number of chips
  /// above zero (`x`).
  ///
  /// The site shows "<`n`> tipped <`rn`> <`x`>" and the text `m` below, in a
  /// framed line. The super chat's price is `x` chips, shown as `x Kudos`
  /// ([tipUnit]); the sender `n` and avatar `i` ([imageBase]); the text `m`
  /// (trimmed; chipmotes such as `kudo100` stay as text, like emotes); from
  /// `d` (else [receivedAt]) for [tipDuration]. The frame names no colours.
  /// A tip to another channel of a multistream (`rn` is not [channelName])
  /// says so before its text: `打赏给 <rn>：<text>`.
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
    final shown = !elsewhere
        ? text
        : text.isEmpty
        ? '打赏给 $receiver'
        : '打赏给 $receiver：$text';
    return LiveMessage.normalized(
      type: LiveMessageType.superChat,
      sender: MessageSender.normalized(
        userId: _scalar(line['u']),
        userName: _scalar(line['n']),
        avatarUrl: avatar(line['i']),
      ),
      text: shown,
      color: LiveMessageColor.white,
      messageId: id,
      sentAt: sentAt,
      payload: LiveSuperChatMessage.of(
        messageId: id,
        userName: _scalar(line['n']),
        faceUrl: avatar(line['i']),
        text: shown,
        price: SuperChatPrice.of(amount: chips, currency: tipUnit, displayText: '$chips $tipUnit'),
        startTime: start,
        endTime: start.add(tipDuration),
      ),
    );
  }

  /// The URL of an avatar path (`i`), as the site builds it: a path gets
  /// [imageBase] before it, a full URL stays; anything else is empty.
  static String avatar(Object? path) {
    if (path is! String || path.trim().isEmpty) return '';
    final value = path.trim();
    if (value.contains('http://') || value.contains('https://') || value.contains('data:image/')) return value;
    return '$imageBase$value';
  }

  /// A system line as a notice, or null when it has no text.
  ///
  /// The text `m` is the site's own; the site replaces each `{link}` with
  /// the text of a link of `l` and each `{icon}` with an icon of `ic`, and
  /// breaks lines at `\n`. Here an icon is left out, a link is its text, and
  /// lines are joined with a space. As on the site, a placeholder stays
  /// when its list is missing, and the k-th link is `l[2k + 1]`, else `l[0]`
  /// (the site counts the pieces around the placeholders).
  static LiveMessage? system(Object? line) {
    if (line is! Map) return null;
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
    return sentence.isEmpty ? null : _notice(LiveNoticeKind.system, sentence);
  }

  /// A `raid` frame as a notice, or null.
  ///
  /// The site shows "RAID!" over the text `m` (the server's own sentence);
  /// without one the notice is `<n> 突袭了 <rn>` (the raiding channel `n`,
  /// the raided `rn`). The site also takes the raiding channel's viewers to
  /// the raided one after 10 s; that is not done here.
  static LiveMessage? raid(Object? raid) {
    if (raid is! Map) return null;
    final text = switch (raid['m']) {
      final String text => text.trim(),
      _ => '',
    };
    if (text.isNotEmpty) return _notice(LiveNoticeKind.raid, text);
    final (from, to) = (_scalar(raid['n']).trim(), _scalar(raid['rn']).trim());
    if (from.isEmpty || to.isEmpty) return null;
    return _notice(LiveNoticeKind.raid, '$from 突袭了 $to');
  }

  /// An `ns` frame's subscription as a notice, or null when a name the
  /// sentence needs is missing.
  ///
  /// The site builds an English sentence from the fields: `sn` the
  /// subscriber or gifter, `n` the channel, `md` months (1 when missing),
  /// `sg` gifted, `gn` the one who received a gift, `ag` anonymous, `sc` the
  /// community gift's recipients, `slvl` the level. The notice says the same
  /// in Chinese (site → notice):
  ///
  /// - `sn subscribed to n for md month/s` → `sn 订阅了 n，md 个月`;
  /// - `sn activated a Level slvl subscription to n` → `sn 开通了 n 的 slvl
  ///   级订阅`;
  /// - `sn gifted md month/s subscription to gn` → `sn 赠送给 gn md 个月订阅`;
  /// - `sn gifted k subscriptions to the Picarto Community for n` →
  ///   `sn 向 Picarto 社区赠送了 k 份 n 的订阅`;
  /// - `gn received anonymous gift of md month/s subscription for n` →
  ///   `gn 收到匿名赠送的 md 个月 n 订阅`;
  /// - `An anonymous gift of k subscriptions to the Picarto Community for n`
  ///   → `有人匿名向 Picarto 社区赠送了 k 份 n 的订阅`.
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
    return text == null ? null : _notice(LiveNoticeKind.subscription, text);
  }

  /// An `rm` frame's deletion (a moderator deleted a message): takes back
  /// the message whose id is `id`, or null. The site replaces that line's
  /// text with the frame's `m` and marks it deleted.
  static LiveMessage? deletion(Object? deletion) {
    if (deletion case {'id': final String id} when id.trim().isNotEmpty) {
      return _retraction(LiveRetraction.of(messageId: id));
    }
    return null;
  }

  /// A `cm` frame's clearance (a moderator cleared a user's messages):
  /// takes back every message of the user `u`, or null. The site removes
  /// that user's lines.
  static LiveMessage? clearance(Object? clearance) {
    if (clearance is! Map) return null;
    final user = _scalar(clearance['u']);
    return user.trim().isEmpty ? null : _retraction(LiveRetraction.of(userId: user));
  }

  /// The concurrent audience of a `stream` frame's state, or null. A frame
  /// naming another channel (`id`) is skipped; `viewers` must be a whole
  /// number, not negative.
  static LiveMessage? audience(Object? state, {required int channelId}) {
    if (state is! Map) return null;
    final id = state['id'];
    if (id != null && '$id' != '$channelId') return null;
    final viewers = state['viewers'];
    if (viewers is! int || viewers < 0) return null;
    return LiveMessage.normalized(
      type: LiveMessageType.audienceUpdate,
      color: LiveMessageColor.white,
      payload: LiveAudienceUpdate.of(kind: LiveAudienceSignalKind.onlineViewers, value: viewers),
    );
  }

  /// A name colour: 6 hex digits (`66AFFF`), optionally after `#`, or the
  /// 3-digit CSS short form; anything else is white. The site's client
  /// prefixes `#` and hands it to CSS.
  static LiveMessageColor color(Object? value) {
    if (value is! String) return LiveMessageColor.white;
    var hex = value.trim();
    if (hex.startsWith('#')) hex = hex.substring(1);
    if (_hex3.hasMatch(hex)) hex = hex.split('').map((digit) => '$digit$digit').join();
    if (!_hex6.hasMatch(hex)) return LiveMessageColor.white;
    return LiveMessageColor.numberToColor(int.parse(hex, radix: 16));
  }

  static LiveMessage _notice(LiveNoticeKind kind, String text) =>
      LiveMessage.normalized(type: LiveMessageType.notice, text: text, color: LiveMessageColor.white, payload: kind);

  /// A retraction carries no id of its own: the target's would collide with
  /// the target in the duplicate gate.
  static LiveMessage _retraction(LiveRetraction retraction) =>
      LiveMessage.normalized(type: LiveMessageType.retraction, color: LiveMessageColor.white, payload: retraction);

  /// A line's id: `id`, else `_id` (the site's `id || _id`), when it is text.
  static String _messageId(Map<Object?, Object?> line) => switch (line['id'] ?? line['_id']) {
    final String id => id,
    _ => '',
  };

  /// A time in milliseconds (`d`), or null when it is not a whole number
  /// [DateTime] can hold.
  static DateTime? _time(Object? millis) =>
      millis is int && millis.abs() <= _maxMillis ? DateTime.fromMillisecondsSinceEpoch(millis) : null;

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
