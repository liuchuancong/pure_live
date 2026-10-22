import 'dart:math';

import 'package:live_sites/src/models/enums/live_gift_kind.dart';
import 'package:live_sites/src/models/enums/live_gift_unit.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/enums/live_notice_kind.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/gift/live_gift_combo/live_gift_combo.dart';
import 'package:live_sites/src/models/gift/live_gift_value/live_gift_value.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/message/live_retraction/live_retraction.dart';
import 'package:live_sites/src/models/message/message_sender/message_sender.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// The community gift a subscription notice belongs to: the
/// `msg-param-community-gift-id`, whether this notice is the gift's
/// announcement (`submysterygift`: its count of subscriptions,
/// `msg-param-mass-gift-count`) or one of the subscriptions it gives
/// (`subgift`).
typedef TwitchCommunityGift = ({String id, bool announcement, int count});

/// What one Twitch frame held: the messages in order, the lines to send back
/// at once (a `PONG` for every server `PING`), whether the server refused the
/// chat login, whether it asked to reconnect, and the subscription notices
/// that belong to a community gift (keyed by the notice itself).
final class TwitchDanmakuFrame {
  /// Creates the result of one frame.
  const TwitchDanmakuFrame({
    this.messages = const [],
    this.replies = const [],
    this.loginRejected = false,
    this.reconnect = false,
    this.communityGifts = const {},
  });

  /// Chat, notices, gifts and retractions, in receive order.
  final List<LiveMessage> messages;

  /// The lines to send back at once.
  final List<String> replies;

  /// The server refused the chat login (a `NOTICE *`, such as "Login
  /// authentication failed").
  final bool loginRejected;

  /// The server is about to drop the socket for maintenance (`RECONNECT`) and
  /// asks the client to connect and join again.
  final bool reconnect;

  /// The subscription notices of [messages] that belong to a community gift,
  /// by the notice itself (an identity map): a community gift shows as its
  /// announcement only.
  final Map<LiveMessage, TwitchCommunityGift> communityGifts;
}

/// One IRC line split as IRCv3 does: `@tags :prefix COMMAND params :trailing`.
final class TwitchIrcLine {
  /// Creates the line.
  const TwitchIrcLine({
    required this.command,
    this.tags = const {},
    this.prefix,
    this.params = const [],
    this.trailing,
  });

  /// Splits a trimmed [line]; null when it has no command. Tag values are
  /// unescaped in one pass from left to right (IRCv3: `\:` → `;`, `\s` →
  /// space, `\\` → backslash, `\r`, `\n`, any other escaped character itself,
  /// a lone trailing backslash dropped).
  static TwitchIrcLine? parse(String line) {
    var rest = line;
    final tags = <String, String>{};
    if (rest.startsWith('@')) {
      final space = rest.indexOf(' ');
      if (space < 0) return null;
      for (final entry in rest.substring(1, space).split(';')) {
        if (entry.isEmpty) continue;
        final separator = entry.indexOf('=');
        if (separator < 0) {
          tags[entry] = '';
        } else {
          tags[entry.substring(0, separator)] = unescape(entry.substring(separator + 1));
        }
      }
      rest = rest.substring(space + 1).trimLeft();
    }
    String? prefix;
    if (rest.startsWith(':')) {
      final space = rest.indexOf(' ');
      if (space < 0) return null;
      prefix = rest.substring(1, space);
      rest = rest.substring(space + 1).trimLeft();
    }
    final trailingStart = rest.startsWith(':') ? 0 : rest.indexOf(' :');
    final head = trailingStart < 0 ? rest : rest.substring(0, trailingStart);
    final trailing = trailingStart < 0 ? null : rest.substring(trailingStart + (trailingStart == 0 ? 1 : 2));
    final words = head.split(' ').where((word) => word.isNotEmpty).toList();
    if (words.isEmpty) return null;
    return TwitchIrcLine(
      tags: tags,
      prefix: prefix,
      command: words.first,
      params: words.sublist(1),
      trailing: trailing,
    );
  }

  /// An IRCv3 tag value unescaped in one pass.
  static String unescape(String value) {
    if (!value.contains(r'\')) return value;
    final out = StringBuffer();
    for (var index = 0; index < value.length; index++) {
      final char = value[index];
      if (char != r'\') {
        out.write(char);
        continue;
      }
      if (++index == value.length) break;
      out.write(switch (value[index]) {
        ':' => ';',
        's' => ' ',
        'r' => '\r',
        'n' => '\n',
        final other => other,
      });
    }
    return out.toString();
  }

  /// Tags, unescaped; a tag without `=` has an empty value.
  final Map<String, String> tags;

  /// The source (`tmi.twitch.tv`, `nick!user@host`), without the colon.
  final String? prefix;

  /// The command (`PRIVMSG`, `USERNOTICE`, `001`).
  final String command;

  /// The middle parameters (the channel).
  final List<String> params;

  /// The last parameter, after ` :`; null when the line has none.
  final String? trailing;
}

/// The codec of Twitch chat: IRC over a WebSocket of text frames, without I/O.
///
/// A frame holds one or more lines separated by `\r\n`. The client joins with
/// `PASS`, `NICK`, `CAP REQ` and `JOIN`; chat is `PRIVMSG` with IRCv3 tags.
abstract final class TwitchDanmakuCodec {
  /// The chat server.
  static final Uri endpoint = Uri.parse('wss://irc-ws.chat.twitch.tv');

  /// Heartbeat period (the server answers a client `PING` with a `PONG`).
  static const Duration heartbeatInterval = Duration(seconds: 40);

  /// How long a socket may stay silent before it is replaced: three beats,
  /// never under 90 s.
  static const Duration inactivityTimeout = Duration(seconds: 120);

  /// The client heartbeat line.
  static const String heartbeat = 'PING :tmi.twitch.tv';

  /// The capabilities asked for: tags (names, colours, ids, times), commands
  /// and membership.
  static const String capabilities = 'CAP REQ :twitch.tv/tags twitch.tv/commands twitch.tv/membership';

  /// The password of an anonymous nick.
  static const String anonymousPassword = 'PASS SCHMOOPIIE';

  /// The currency a cheer gives: Twitch's own name.
  static const String bitsName = 'Bits';

  /// How long a subscription of a community gift waits for the gift's
  /// announcement (the recordings have it 0.6 s before or after). One whose
  /// announcement does not come in time is shown on its own.
  static const Duration communityGiftWait = Duration(seconds: 2);

  /// How long a community gift's announcement leaves out the subscriptions it
  /// gives that are still to come.
  static const Duration communityGiftLifetime = Duration(minutes: 1);

  /// How many reconnects in a row may fail before the session is abandoned.
  static const int maxReconnectAttempts = 8;

  /// The most a single backoff step waits (one second per consecutive failure,
  /// never past this).
  static const Duration reconnectStepCap = Duration(seconds: 6);

  /// The `msg-id`s of a `USERNOTICE` shown as [LiveNoticeKind.subscription]:
  /// subscribing, renewing, gifting subscriptions (named, anonymous, to the
  /// community) and continuing or upgrading one.
  static const Set<String> subscriptionNotices = {
    'sub',
    'resub',
    'extendsub',
    'subgift',
    'anonsubgift',
    'submysterygift',
    'anonsubmysterygift',
    'giftpaidupgrade',
    'anongiftpaidupgrade',
    'primepaidupgrade',
    'communitypayforward',
    'standardpayforward',
  };

  /// The `msg-id`s that announce a community gift.
  static const Set<String> communityGiftAnnouncements = {'submysterygift', 'anonsubmysterygift'};

  /// The `msg-id`s of the subscriptions a community gift gives.
  static const Set<String> communityGiftMembers = {'subgift', 'anonsubgift'};

  /// An anonymous nick: `justinfan` and 1000–99999, drawn at every join.
  static String anonymousNick(Random random) => 'justinfan${1000 + random.nextInt(99000)}';

  /// The lines that join [channel], each sent as its own text frame: the
  /// user's [chat] login when it has both a token and a login, otherwise an
  /// anonymous nick drawn from [random]. The channel is trimmed and
  /// lower-cased, as the web client does.
  static List<String> join(String channel, {required Random random, ({String login, String token})? chat}) {
    final token = chat?.token.trim() ?? '';
    final login = chat?.login.trim().toLowerCase() ?? '';
    final authenticated = token.isNotEmpty && login.isNotEmpty;
    return [
      if (authenticated) 'PASS oauth:$token' else anonymousPassword,
      'NICK ${authenticated ? login : anonymousNick(random)}',
      capabilities,
      'JOIN #${channel.trim().toLowerCase()}',
    ];
  }

  /// Reads one frame: every line starting with `PING` is answered with the
  /// same line as `PONG`; every `PRIVMSG` is chat, after its cheer when it
  /// gives Bits; a `NOTICE *` marks the login rejected. `CLEARMSG`,
  /// `CLEARCHAT` and `USERNOTICE` become retractions, notices and chat;
  /// `RECONNECT` marks the socket switch. A subscription notice of a community
  /// gift is marked as one. A line that fails to decode is skipped without
  /// losing the others.
  static TwitchDanmakuFrame decode(String data) {
    final messages = <LiveMessage>[];
    final community = Map<LiveMessage, TwitchCommunityGift>.identity();
    final replies = <String>[];
    var loginRejected = false;
    var reconnect = false;
    for (final raw in data.split(_lineBreak)) {
      if (raw.startsWith('PING')) replies.add(raw.replaceFirst('PING', 'PONG').trim());
      final line = raw.trim();
      if (isLoginRejection(line)) loginRejected = true;
      try {
        final irc = TwitchIrcLine.parse(line);
        switch (irc?.command) {
          case 'RECONNECT':
            reconnect = true;
          case 'CLEARMSG' || 'CLEARCHAT' || 'USERNOTICE':
            final read = command(irc!);
            if (communityGift(irc) case final gift?) {
              for (final message in read) {
                if (message.type == LiveMessageType.notice) community[message] = gift;
              }
            }
            messages.addAll(read);
          default:
            final spoken = chat(line);
            if (spoken != null) {
              if (irc != null) {
                final cheerMessage = cheer(irc, spoken);
                if (cheerMessage != null) messages.add(cheerMessage);
              }
              messages.add(spoken);
            }
        }
      } on Object {
        // A timestamp out of DateTime's range: only this line is lost.
      }
    }
    return TwitchDanmakuFrame(
      messages: messages,
      replies: replies,
      loginRejected: loginRejected,
      reconnect: reconnect,
      communityGifts: community,
    );
  }

  /// The cheer of a `PRIVMSG` [line] whose chat is [chat]: its `bits` tag
  /// above 0, as a gift of [chat]'s sender, time and colour, with the id
  /// `<chat's id>:bits` (the chat line keeps its own; the words stay
  /// [chat]'s). Null without Bits.
  static LiveMessage? cheer(TwitchIrcLine line, LiveMessage chat) {
    final bits = int.tryParse(line.tags['bits']?.trim() ?? '');
    if (line.command != 'PRIVMSG' || bits == null || bits <= 0) return null;
    final id = chat.messageId;
    final key = id.isNotEmpty
        ? 'bits:$id'
        : 'bits:${chat.sender?.userId ?? ''}:${chat.sentAt?.millisecondsSinceEpoch ?? ''}';
    final gift = LiveGift(
      name: bitsName,
      kind: LiveGiftKind.tip,
      count: bits,
      value: LiveGiftValue(unit: LiveGiftUnit.bits, unitPrice: bits.toDouble(), totalValue: bits.toDouble()),
      combo: LiveGiftCombo(comboKey: key),
    );
    return LiveMessage.normalized(
      type: LiveMessageType.gift,
      text: '$bits $bitsName',
      sender: chat.sender,
      color: chat.color,
      payload: gift,
      messageId: id.isEmpty ? '' : '$id:bits',
      sentAt: chat.sentAt,
    );
  }

  /// The community gift of a `USERNOTICE` [line]: an announcement or a member
  /// notice with a `msg-param-community-gift-id`; the announcement's count is
  /// `msg-param-mass-gift-count` (1 when missing). Null otherwise.
  static TwitchCommunityGift? communityGift(TwitchIrcLine line) {
    if (line.command != 'USERNOTICE') return null;
    final kind = line.tags['msg-id'] ?? '';
    final announcement = communityGiftAnnouncements.contains(kind);
    if (!announcement && !communityGiftMembers.contains(kind)) return null;
    final id = line.tags['msg-param-community-gift-id']?.trim() ?? '';
    if (id.isEmpty) return null;
    final count = int.tryParse(line.tags['msg-param-mass-gift-count'] ?? '') ?? 1;
    return (id: id, announcement: announcement, count: count > 0 ? count : 1);
  }

  /// The messages of a `CLEARMSG`, `CLEARCHAT` or `USERNOTICE` [line], as
  /// Twitch's web chat reads them:
  ///
  /// - `CLEARMSG` (a moderator deleted one message): a retraction of the
  ///   message `target-msg-id`;
  /// - `CLEARCHAT` naming a user (a timeout or a ban): a retraction of every
  ///   message of `target-user-id`; without a user (the chat was cleared): a
  ///   retraction of everything. A user named without an id cannot be matched
  ///   and is skipped, never taken for a clear;
  /// - `USERNOTICE`: the `system-msg` as a notice ([LiveNoticeKind.subscription]
  ///   for [subscriptionNotices], [LiveNoticeKind.raid] for `raid`,
  ///   [LiveNoticeKind.system] otherwise; none when the text is empty), then
  ///   the viewer's own words, when there are any, as their chat carrying the
  ///   notice's id. An `announcement` has no `system-msg`: its words are the
  ///   system notice. A `sharedchatnotice` (an event of a channel sharing the
  ///   chat) counts as its `source-msg-id`.
  ///
  /// Retractions carry no message id of their own (Twitch gives none). Other
  /// commands give nothing.
  static List<LiveMessage> command(TwitchIrcLine line) {
    final tags = line.tags;
    final sentAt = _time(tags['tmi-sent-ts']);
    LiveMessage retraction(LiveRetraction target) => LiveMessage.normalized(
      type: LiveMessageType.retraction,
      color: LiveMessageColor.white,
      payload: target,
      sentAt: sentAt,
    );
    switch (line.command) {
      case 'CLEARMSG':
        final target = tags['target-msg-id']?.trim() ?? '';
        return [if (target.isNotEmpty) retraction(LiveRetraction(messageId: target))];
      case 'CLEARCHAT':
        final user = tags['target-user-id']?.trim() ?? '';
        if (user.isNotEmpty) return [retraction(LiveRetraction(userId: user))];
        return [if (line.trailing == null) retraction(const LiveRetraction(all: true))];
      case 'USERNOTICE':
        final noticeId = tags['msg-id'] ?? '';
        final kind = noticeId == 'sharedchatnotice' ? tags['source-msg-id'] ?? '' : noticeId;
        final displayName = tags['display-name']?.trim() ?? '';
        final userName = displayName.isNotEmpty ? displayName : tags['login']?.trim() ?? '';
        final userId = tags['user-id'] ?? '';
        final words = line.trailing?.trim() ?? '';
        final announcement = kind == 'announcement';
        final text = announcement ? words : tags['system-msg']?.trim() ?? '';
        final color = _color(tags['color']);
        return [
          if (text.isNotEmpty)
            LiveMessage.normalized(
              type: LiveMessageType.notice,
              text: text,
              sender: MessageSender.normalized(userId: userId, userName: userName, nameColor: color),
              color: LiveMessageColor.white,
              payload: subscriptionNotices.contains(kind)
                  ? LiveNoticeKind.subscription
                  : kind == 'raid'
                  ? LiveNoticeKind.raid
                  : LiveNoticeKind.system,
              sentAt: sentAt,
            ),
          if (!announcement && words.isNotEmpty)
            LiveMessage.normalized(
              text: words,
              sender: MessageSender.normalized(
                userId: userId,
                userName: userName.isEmpty ? 'Twitch' : userName,
                nameColor: color,
              ),
              color: color,
              messageId: tags['id'] ?? '',
              sentAt: sentAt,
            ),
        ];
    }
    return const [];
  }

  /// The chat of one trimmed [line], or null.
  ///
  /// As the 3.x client read it, any line containing ` PRIVMSG ` counts, and
  /// the text is what follows the first ` :` after it. The name is the
  /// `display-name` tag (trimmed), else the nick before the first `!` that
  /// follows a space, else `Twitch`; the colour is the `color` tag (empty or
  /// unreadable: white); the user id, message id (`id`) and time
  /// (`tmi-sent-ts`, ms) come from their tags. A `/me` line loses its CTCP
  /// `ACTION` wrapper.
  static LiveMessage? chat(String line) {
    if (!line.contains(' PRIVMSG ')) return null;
    final tags = <String, String>{};
    if (line.startsWith('@')) {
      final tagEnd = line.indexOf(' ');
      if (tagEnd > 1) {
        for (final entry in line.substring(1, tagEnd).split(';')) {
          final separator = entry.indexOf('=');
          if (separator < 0) continue;
          tags[entry.substring(0, separator)] = unescapeTag(entry.substring(separator + 1));
        }
      }
    }
    final messageStart = line.indexOf(' :', line.indexOf(' PRIVMSG '));
    if (messageStart < 0) return null;
    final content = line.substring(messageStart + 2);
    final displayName = tags['display-name']?.trim() ?? '';
    final userName = displayName.isNotEmpty ? displayName : (_prefixNick.firstMatch(line)?.group(1) ?? 'Twitch');
    final color = _color(tags['color']);
    return LiveMessage.normalized(
      text: _withoutAction(content),
      sender: MessageSender.normalized(userId: tags['user-id'] ?? '', userName: userName, nameColor: color),
      color: color,
      messageId: tags['id'] ?? '',
      sentAt: _time(tags['tmi-sent-ts']),
    );
  }

  /// A tag value with the 3.x client's unescaping: `\s`, `\:`, `\r`, `\n`,
  /// then `\\`, each replaced everywhere in that order. (Values holding an
  /// escaped backslash come out differently from IRCv3's single pass; the tags
  /// read here never hold one.)
  static String unescapeTag(String value) => value
      .replaceAll(r'\s', ' ')
      .replaceAll(r'\:', ';')
      .replaceAll(r'\r', '\r')
      .replaceAll(r'\n', '\n')
      .replaceAll(r'\\', r'\');

  /// Whether [line] is a `NOTICE` to `*`: the server's answer to a refused
  /// login ("Login authentication failed", "Improperly formatted auth"), after
  /// which it ignores the join and drops the socket.
  static bool isLoginRejection(String line) {
    var rest = line;
    for (final marker in const ['@', ':']) {
      if (!rest.startsWith(marker)) continue;
      final space = rest.indexOf(' ');
      if (space < 0) return false;
      rest = rest.substring(space + 1).trimLeft();
    }
    return rest.startsWith('NOTICE * ');
  }

  /// The system notice reported once when Twitch refused the stored chat login
  /// and chat went on anonymously.
  static LiveMessage cookieExpiredNotice() => LiveMessage.normalized(
    type: LiveMessageType.notice,
    text: 'Twitch 的 Cookie 已失效，弹幕已改为匿名接收，请重新填写 Twitch Cookie',
    color: LiveMessageColor.white,
    payload: LiveNoticeKind.system,
  );

  static final RegExp _lineBreak = RegExp(r'\r?\n');
  static final RegExp _prefixNick = RegExp(' :?([^! ]+)!');
  static final RegExp _action = RegExp('^\u0001ACTION(?: (.*?))?\u0001?\$');

  /// A `#rrggbb` colour tag, white when empty or unreadable.
  static LiveMessageColor _color(String? value) =>
      LiveMessageColor.numberToColor(int.tryParse((value ?? '').replaceFirst('#', ''), radix: 16) ?? 0xFFFFFF);

  static DateTime? _time(String? value) {
    final timestamp = int.tryParse(value ?? '');
    return timestamp == null ? null : DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  /// `\x01ACTION text\x01` (a `/me` line) as `text`; the closing `\x01` may be
  /// missing. Other text is returned as it is.
  static String _withoutAction(String text) {
    final match = _action.firstMatch(text);
    return match == null ? text : match.group(1) ?? '';
  }
}
