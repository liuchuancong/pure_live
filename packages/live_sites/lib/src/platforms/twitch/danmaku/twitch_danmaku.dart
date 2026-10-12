import 'dart:math';

import 'package:live_sites/src/models/live_gift/live_gift.dart';
import 'package:live_sites/src/models/live_message/live_message.dart';
import 'package:meta/meta.dart';

/// The community gift a subscription notice belongs to (D07.6): the
/// `msg-param-community-gift-id`, whether it is the gift's announcement
/// (`submysterygift`) or one of the subscriptions it gives (`subgift`).
typedef TwitchCommunityGift = ({String id, bool announcement, int count});

/// What one Twitch frame held ([TwitchDanmakuProtocol.decode]).
@immutable
final class TwitchDanmakuFrame {
  /// Creates the result.
  const new({
    this.messages = const [],
    this.replies = const [],
    this.loginRejected = false,
    this.reconnect = false,
    this.communityGifts = const {},
  });

  /// Chat, notices and recalls, in order.
  final List<LiveMessage> messages;

  /// The subscription notices of [messages] that belong to a community gift
  /// (D07.6), by the notice itself (identity map): a community gift is shown
  /// as its announcement only.
  final Map<LiveMessage, TwitchCommunityGift> communityGifts;

  /// Lines to send back at once: a `PONG` for every server `PING`.
  final List<String> replies;

  /// The server refused the chat login (a `NOTICE *`).
  final bool loginRejected;

  /// The server is about to drop the socket for maintenance (`RECONNECT`).
  final bool reconnect;
}

/// One IRC line split as IRCv3 does: `@tags :prefix COMMAND params :trailing`.
@immutable
final class TwitchIrcLine {
  /// Creates the line.
  const new({required this.command, this.tags = const {}, this.prefix, this.params = const [], this.trailing});

  /// Splits a trimmed [line]; null when it has no command. Tag values are
  /// unescaped in one pass from left to right.
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

  /// The source, without the colon.
  final String? prefix;

  /// The command (`USERNOTICE`, `001`).
  final String command;

  /// The middle parameters (the channel).
  final List<String> params;

  /// The last parameter, after ` :`; null when the line has none.
  final String? trailing;
}

/// Twitch chat, IRC over a WebSocket of text frames, without I/O.
///
/// A frame holds one or more lines separated by `\r\n`. The client joins with
/// `PASS`, `NICK`, `CAP REQ` and `JOIN`; chat is `PRIVMSG` with IRCv3 tags.
/// This tree has no stored Twitch login, so the join is always anonymous.
///
/// Mapped onto this tree's models: Bits (the platform's paid currency) are a
/// gift counting as [LiveGiftUnit.gold], a deleted message or banned user is a
/// [LiveMessageType.recall] naming it by id or user, a cleared chat has no
/// whole-chat form here and is dropped, notice kinds travel as `data` strings,
/// colour is an int and a message id is `id`.
abstract final class TwitchDanmakuProtocol {
  /// The chat server.
  static final Uri endpoint = Uri.parse('wss://irc-ws.chat.twitch.tv');

  /// Heartbeat period.
  static const Duration heartbeatInterval = Duration(seconds: 40);

  /// The client heartbeat line; the server answers with a `PONG`.
  static const String heartbeat = 'PING :tmi.twitch.tv';

  /// The capabilities: tags, commands and membership.
  static const String capabilities = 'CAP REQ :twitch.tv/tags twitch.tv/commands twitch.tv/membership';

  /// The password of an anonymous nick.
  static const String anonymousPassword = 'PASS SCHMOOPIIE';

  /// An anonymous nick: `justinfan` and 1000–99999.
  static String anonymousNick(Random random) => 'justinfan${1000 + random.nextInt(99000)}';

  /// The lines that join [channel], each sent as its own text frame, as an
  /// anonymous guest. The channel is trimmed and lower-cased.
  static List<String> join(String channel, Random random) => [
    anonymousPassword,
    'NICK ${anonymousNick(random)}',
    capabilities,
    'JOIN #${channel.trim().toLowerCase()}',
  ];

  static final RegExp _lineBreak = RegExp(r'\r?\n');
  static final RegExp _prefixNick = RegExp(' :?([^! ]+)!');
  static final RegExp _action = RegExp('^\u0001ACTION(?: (.*?))?\u0001?\$');

  /// The `msg-id`s of a `USERNOTICE` shown as a subscription.
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

  /// The `msg-id`s that announce a community gift (D07.6).
  static const Set<String> communityGiftAnnouncements = {'submysterygift', 'anonsubmysterygift'};

  /// The `msg-id`s of the subscriptions a community gift gives (D07.6).
  static const Set<String> communityGiftMembers = {'subgift', 'anonsubgift'};

  /// The currency a cheer gives.
  static const String bitsName = 'Bits';

  /// Reads one frame: every `PING` line is answered with the same line as
  /// `PONG`; every `PRIVMSG` is chat, after its cheer when it gives Bits; a
  /// `NOTICE *` sets [TwitchDanmakuFrame.loginRejected]; `CLEARMSG`,
  /// `CLEARCHAT` and `USERNOTICE` become recalls, notices and chat;
  /// `RECONNECT` sets [TwitchDanmakuFrame.reconnect]. A subscription notice of
  /// a community gift is marked. A line that fails to decode is skipped.
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
            final message = chat(line);
            if (message != null) {
              if (irc != null) messages.addAll([?cheer(irc, message)]);
              messages.add(message);
            }
        }
      } on Object {
        // A malformed line loses only itself.
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

  /// The cheer of a `PRIVMSG` whose [chat] gives Bits: its `bits` tag above 0,
  /// as a gift before [chat], with the id `<chat's id>:bits` ([chat] keeps its
  /// own). Null without Bits.
  static LiveMessage? cheer(TwitchIrcLine line, LiveMessage chat) {
    final bits = int.tryParse(line.tags['bits']?.trim() ?? '');
    if (line.command != 'PRIVMSG' || bits == null || bits <= 0) return null;
    final id = chat.id ?? '';
    final key = id.isNotEmpty ? 'bits:$id' : 'bits:${chat.userId}:${chat.sentAt?.millisecondsSinceEpoch ?? ''}';
    return LiveMessage(
      type: LiveMessageType.gift,
      userName: chat.userName,
      userId: chat.userId,
      message: '$bitsName ×1',
      color: chat.color,
      id: id.isEmpty ? null : '$id:bits',
      sentAt: chat.sentAt,
      data: LiveGift(name: bitsName, count: 1, unitPrice: bits, totalValue: bits, combo: key),
    );
  }

  /// The community gift of a `USERNOTICE` (D07.6): an announcement or a member
  /// notice with a `msg-param-community-gift-id`. Null otherwise.
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

  /// The messages of a `CLEARMSG`, `CLEARCHAT` or `USERNOTICE`:
  ///
  /// - `CLEARMSG`: the recall of the message `target-msg-id`;
  /// - `CLEARCHAT` naming a user: the recall of every message of
  ///   `target-user-id`; a cleared chat (no user) has no whole-chat form here
  ///   and is dropped;
  /// - `USERNOTICE`: the `system-msg` as a notice (`subscription`, `raid` or
  ///   `system`), then the viewer's words as their chat when there are any. An
  ///   `announcement` has no `system-msg`: its words are the notice.
  static List<LiveMessage> command(TwitchIrcLine line) {
    final tags = line.tags;
    final sentAt = _time(tags['tmi-sent-ts']);
    switch (line.command) {
      case 'CLEARMSG':
        final target = tags['target-msg-id']?.trim() ?? '';
        return [if (target.isNotEmpty) _recall(id: target, sentAt: sentAt)];
      case 'CLEARCHAT':
        final user = tags['target-user-id']?.trim() ?? '';
        // A cleared chat (no target user) has no whole-chat form here.
        return user.isEmpty ? const [] : [_recall(userId: user, sentAt: sentAt)];
      case 'USERNOTICE':
        final noticeId = tags['msg-id'] ?? '';
        final kind = noticeId == 'sharedchatnotice' ? tags['source-msg-id'] ?? '' : noticeId;
        final displayName = tags['display-name']?.trim() ?? '';
        final userName = displayName.isNotEmpty ? displayName : tags['login']?.trim() ?? '';
        final userId = tags['user-id'] ?? '';
        final words = line.trailing?.trim() ?? '';
        final announcement = kind == 'announcement';
        final text = announcement ? words : tags['system-msg']?.trim() ?? '';
        final kindData = subscriptionNotices.contains(kind)
            ? 'subscription'
            : kind == 'raid'
            ? 'raid'
            : 'system';
        return [
          if (text.isNotEmpty)
            LiveMessage(
              type: LiveMessageType.notice,
              userName: userName,
              userId: userId,
              message: text,
              color: 0xFFFFFF,
              data: kindData,
              sentAt: sentAt,
            ),
          if (!announcement && words.isNotEmpty)
            LiveMessage(
              type: LiveMessageType.chat,
              userName: userName.isNotEmpty ? userName : 'Twitch',
              userId: userId,
              message: words,
              color: _color(tags['color']),
              id: tags['id'],
              sentAt: sentAt,
            ),
        ];
    }
    return const [];
  }

  static LiveMessage _recall({String? id, String? userId, DateTime? sentAt}) =>
      LiveMessage(type: LiveMessageType.recall, userName: '', message: '', id: id, userId: userId, sentAt: sentAt);

  /// The chat of one trimmed [line], or null. Any line with ` PRIVMSG `
  /// counts; the text follows the first ` :` after it. The name is the
  /// `display-name` tag, else the nick, else `Twitch`; the colour the `color`
  /// tag (else white); the user id, message id and time come from their tags.
  /// A `/me` line loses its `ACTION` wrapper. A level has no field here.
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
    final timestamp = int.tryParse(tags['tmi-sent-ts'] ?? '');
    final id = tags['id']?.trim() ?? '';
    return LiveMessage(
      type: LiveMessageType.chat,
      message: _withoutAction(content),
      userName: userName,
      userId: tags['user-id'] ?? '',
      id: id.isEmpty ? null : id,
      sentAt: timestamp == null ? null : DateTime.fromMillisecondsSinceEpoch(timestamp),
      color: _color(tags['color']),
    );
  }

  /// A tag value with 3.x's unescaping.
  static String unescapeTag(String value) => value
      .replaceAll(r'\s', ' ')
      .replaceAll(r'\:', ';')
      .replaceAll(r'\r', '\r')
      .replaceAll(r'\n', '\n')
      .replaceAll(r'\\', r'\');

  static String _withoutAction(String text) {
    final match = _action.firstMatch(text);
    return match == null ? text : match.group(1) ?? '';
  }

  /// Whether [line] is a `NOTICE` to `*`: the server's answer to a refused
  /// login.
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

  static DateTime? _time(String? value) {
    final timestamp = int.tryParse(value ?? '');
    return timestamp == null ? null : DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  static int _color(String? value) {
    final hex = (value ?? '').replaceFirst('#', '');
    final parsed = int.tryParse(hex, radix: 16);
    return parsed == null || parsed < 0 || parsed > 0xFFFFFF ? 0xFFFFFF : parsed;
  }
}
