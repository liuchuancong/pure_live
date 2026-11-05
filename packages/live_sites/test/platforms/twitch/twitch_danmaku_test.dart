import 'dart:math';

import 'package:live_sites/src/models/enums/live_gift_kind.dart';
import 'package:live_sites/src/models/enums/live_gift_unit.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/enums/live_notice_kind.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_retraction/live_retraction.dart';
import 'package:live_sites/src/platforms/twitch/danmaku/twitch_danmaku_codec.dart';
import 'package:test/test.dart';

/// The tags of a chat line, as the server writes them for one speaker.
const String _chatTags =
    '@badge-info=;badges=moderator/1;color=#177DE3;display-name=Tester;emotes=25:0-4;'
    'id=c-1;login=tester;mod=1;room-id=402863002;subscriber=0;tmi-sent-ts=1790519893202;'
    'turbo=0;user-id=123;user-type=mod';

const String _prefix = ':tester!tester@tester.tmi.twitch.tv';

/// The tag block with [extra] tags merged into it.
String _tags([Map<String, String> extra = const <String, String>{}]) {
  final written = <String, String>{};
  for (final part in _chatTags.substring(1).split(';')) {
    final at = part.indexOf('=');
    written[part.substring(0, at)] = part.substring(at + 1);
  }
  written.addAll(extra);
  final parts = <String>[];
  for (final entry in written.entries) {
    parts.add('${entry.key}=${entry.value}');
  }
  return '@${parts.join(';')}';
}

/// A `PRIVMSG` of [text].
String _privmsg({String text = 'hello', Map<String, String> extra = const <String, String>{}}) =>
    '${_tags(extra)} $_prefix PRIVMSG #tester :$text';

/// A `USERNOTICE` with these [tags] and no words of its own.
String _notice(String tags) => '$tags :tmi.twitch.tv USERNOTICE #tester';

/// The one message of a frame holding [line].
LiveMessage _only(String line) {
  final frame = TwitchDanmakuCodec.decode(line);
  expect(frame.messages, hasLength(1), reason: line);
  return frame.messages.single;
}

void main() {
  group('one IRC line', () {
    test('tags, prefix, command, parameters and trailing come apart', () {
      final line = TwitchIrcLine.parse(
        '@badge-info=;badges=staff/1;display-name=Sebastian;emotes= '
        ':seb!seb@seb.tmi.twitch.tv PRIVMSG #channel :hello :world',
      )!;
      expect(line.tags['display-name'], 'Sebastian');
      expect(line.tags['badges'], 'staff/1');
      expect(line.tags['emotes'], isEmpty, reason: 'a tag without = is there, with an empty value');
      expect(line.prefix, 'seb!seb@seb.tmi.twitch.tv');
      expect(line.command, 'PRIVMSG');
      expect(line.params, ['#channel']);
      expect(line.trailing, 'hello :world', reason: 'only the first space-colon opens the trailing part');
    });

    test('a tag value is unescaped in one pass, left to right', () {
      // IRCv3 reads pairs: an escaped space is a space, an escaped colon a
      // semicolon, any other escaped character is itself, and a value ending
      // in a lone backslash drops it.
      expect(TwitchIrcLine.parse(r'@x=a\sb\c\d :tmi.twitch.tv WELCOME')!.tags['x'], 'a bcd');
      expect(TwitchIrcLine.parse(r'@x=a\sb\:c :tmi.twitch.tv WELCOME')!.tags['x'], 'a b;c');
      expect(TwitchIrcLine.parse(r'@x=a\\sb :tmi.twitch.tv WELCOME')!.tags['x'], r'a\sb');
      expect(TwitchIrcLine.parse(r'@x=a\ :tmi.twitch.tv WELCOME')!.tags['x'], 'a');
    });

    test("the chat line's own tag reader keeps 3.x's order, which differs there", () {
      // IRCv3 reads the pairs in one pass; 3.x replaced each sequence
      // everywhere, in that order. `parse` uses the first and `chat` its tags
      // the second, and the two answers differ exactly for a backslash that
      // escapes a backslash opening another escape.
      expect(TwitchIrcLine.unescape(r'a\\sb'), r'a\sb');
      expect(TwitchDanmakuCodec.unescapeTag(r'a\\sb'), r'a\ b');
    });

    test('a line that never reaches a command is nothing', () {
      expect(TwitchIrcLine.parse('@badges=staff/1'), isNull);
      expect(TwitchIrcLine.parse(''), isNull);
      expect(TwitchIrcLine.parse(':tmi.twitch.tv'), isNull);
    });
  });

  group('joining', () {
    test('an anonymous join is PASS, NICK justinfan, the capabilities and JOIN', () {
      final lines = TwitchDanmakuCodec.join('  Tester  ', random: Random(7));
      expect(lines, hasLength(4));
      expect(lines[0], TwitchDanmakuCodec.anonymousPassword);
      expect(lines[1], startsWith('NICK justinfan'));
      expect(lines[2], TwitchDanmakuCodec.capabilities);
      expect(lines[3], 'JOIN #tester', reason: 'the channel is trimmed and lower-cased, as the web client does');
    });

    test('a login joins as itself only when it has its token too', () {
      final signedIn = TwitchDanmakuCodec.join('tester', random: Random(7), chat: (login: 'Tester', token: 'abc123'));
      expect(signedIn[0], 'PASS oauth:abc123');
      expect(signedIn[1], 'NICK tester', reason: 'the login is lower-cased for the join');

      for (final chat in [(login: 'tester', token: ''), (login: '', token: 'abc123'), null]) {
        final anonymous = TwitchDanmakuCodec.join('tester', random: Random(7), chat: chat);
        expect(anonymous[0], TwitchDanmakuCodec.anonymousPassword, reason: '$chat is no session');
        expect(anonymous[1], startsWith('NICK justinfan'));
      }
    });

    test('an anonymous nick is justinfan with 1000 to 99999', () {
      for (var seed = 0; seed < 20; seed++) {
        final nick = TwitchDanmakuCodec.anonymousNick(Random(seed));
        expect(nick, matches(RegExp(r'^justinfan\d{4,5}$')));
        expect(int.parse(nick.substring('justinfan'.length)), inInclusiveRange(1000, 99999));
      }
    });
  });

  group('a frame', () {
    test('a server PING is answered line for line, beside the messages', () {
      final frame = TwitchDanmakuCodec.decode('${_privmsg()}\r\nPING :tmi.twitch.tv\r\n');
      expect(frame.replies, ['PONG :tmi.twitch.tv']);
      expect(frame.messages.map((line) => line.text), ['hello']);
    });

    test('a chat line carries who, their colour, their id and the server time', () {
      final line = _only(_privmsg());
      expect(line.type, LiveMessageType.chat);
      expect(line.text, 'hello');
      expect(line.effectiveSender.userId, '123');
      expect(line.effectiveSender.userName, 'Tester');
      expect(<int>[line.color!.r, line.color!.g, line.color!.b], [0x17, 0x7D, 0xE3]);
      expect(line.effectiveSender.nameColor, line.color);
      expect(line.messageId, 'c-1');
      expect(line.sentAt, DateTime.fromMillisecondsSinceEpoch(1790519893202));
    });

    test('the name falls back to the nick, and then to the site', () {
      expect(_only(_privmsg(extra: const <String, String>{'display-name': ''})).effectiveSender.userName, 'tester');
      expect(_only('tmi.twitch.tv PRIVMSG #tester :hi').effectiveSender.userName, 'Twitch');
    });

    test('no colour, or one that is no number, is white', () {
      final white = _only(_privmsg(extra: const <String, String>{'color': 'zzz'})).color!;
      expect(<int>[white.r, white.g, white.b], [255, 255, 255]);
      expect(_only(_privmsg(extra: const <String, String>{'color': ''})).color, white);
    });

    test('a /me line loses its CTCP wrapper, with or without the closing mark', () {
      final mark = String.fromCharCode(1);
      expect(_only(_privmsg(text: '${mark}ACTION waves$mark')).text, 'waves');
      expect(_only(_privmsg(text: '${mark}ACTION waves')).text, 'waves');
      expect(_only(_privmsg(text: 'ACTION waves')).text, 'ACTION waves', reason: 'no wrapper, no unwrap');
    });

    test('a line that is neither chat nor a known command gives nothing', () {
      expect(TwitchDanmakuCodec.decode(':tmi.twitch.tv 353 * = #tester :a b').messages, isEmpty);
      expect(TwitchDanmakuCodec.decode('NOTICE #tester :slow_mode_off *').messages, isEmpty);
    });

    test('a cheer arrives as its own gift line, before the words it came with', () {
      final frame = TwitchDanmakuCodec.decode(_privmsg(extra: const <String, String>{'bits': '100'}));
      expect(frame.messages, hasLength(2));
      final cheer = frame.messages.first;
      final spoken = frame.messages.last;
      expect(cheer.type, LiveMessageType.gift);
      expect(cheer.text, '100 Bits');
      expect(cheer.messageId, 'c-1:bits', reason: 'the chat line keeps its own id');
      expect(spoken.messageId, 'c-1');
      expect(spoken.text, 'hello');
      final gift = cheer.payload! as LiveGift;
      expect(gift.name, TwitchDanmakuCodec.bitsName);
      expect(gift.kind, LiveGiftKind.tip);
      expect(gift.count, 100);
      expect(gift.value.unit, LiveGiftUnit.bits);
      expect(gift.value.unitPrice, 100);
      expect(cheer.effectiveSender.userName, 'Tester');
    });

    test('no bits, or bits that are no number, is only the words', () {
      for (final bits in ['0', '', 'many']) {
        final frame = TwitchDanmakuCodec.decode(_privmsg(extra: <String, String>{'bits': bits}));
        expect(frame.messages.map((line) => line.type), [LiveMessageType.chat], reason: 'bits=$bits');
      }
    });

    test('a NOTICE to * is the refused login, and RECONNECT asks for a new socket', () {
      final frame = TwitchDanmakuCodec.decode(':tmi.twitch.tv NOTICE * :Login authentication failed\r\n${_privmsg()}');
      expect(frame.loginRejected, isTrue);
      expect(frame.messages, hasLength(1), reason: 'the refusal itself is no line for the list');
      expect(TwitchDanmakuCodec.decode(':tmi.twitch.tv RECONNECT').reconnect, isTrue);
      expect(TwitchDanmakuCodec.decode(_privmsg()).loginRejected, isFalse);
    });

    test('one line that cannot be read only loses itself', () {
      final frame = TwitchDanmakuCodec.decode(
        '${_privmsg(extra: const <String, String>{'tmi-sent-ts': '9007199254740993'})}\r\n${_privmsg()}',
      );
      expect(frame.messages.map((line) => line.text), ['hello']);
    });
  });

  group('what the server takes back and what it announces', () {
    test('a deleted message and a cleared speaker are retractions of just that', () {
      final deleted = _only('@target-msg-id=c-1 :tmi.twitch.tv CLEARMSG #tester :the text');
      expect(deleted.type, LiveMessageType.retraction);
      expect((deleted.payload! as LiveRetraction).messageId, 'c-1');

      final banned = _only('@target-user-id=123 :tmi.twitch.tv CLEARCHAT #tester :tester');
      expect((banned.payload! as LiveRetraction).userId, '123');

      final wholeChat = _only('@room-id=402863002 :tmi.twitch.tv CLEARCHAT #tester');
      expect((wholeChat.payload! as LiveRetraction).all, isTrue);

      expect(
        TwitchDanmakuCodec.decode('@room-id=1 :tmi.twitch.tv CLEARCHAT #tester :someone').messages,
        isEmpty,
        reason: 'a user named with no id cannot be matched, so nothing is taken',
      );
      expect(TwitchDanmakuCodec.decode('@login=mod :tmi.twitch.tv CLEARMSG #tester :x').messages, isEmpty);
    });

    test('a resubscription is the system notice, and the words are the own ones', () {
      const tags =
          '@display-name=Rich;login=rich;msg-id=resub;msg-param-cumulative-months=12'
          r';msg-param-sub-plan=1000;system-msg=Rich\swas\shere\s12\smonths!;tmi-sent-ts=1790519893202;user-id=42';
      final frame = TwitchDanmakuCodec.decode('${_notice(tags)} :thank you');
      final notice = frame.messages.first;
      expect(notice.type, LiveMessageType.notice);
      expect(notice.payload, LiveNoticeKind.subscription);
      expect(notice.text, 'Rich was here 12 months!');
      final spoken = frame.messages.last;
      expect(spoken.type, LiveMessageType.chat);
      expect(spoken.text, 'thank you');
      expect(spoken.effectiveSender.userName, 'Rich');
      expect(spoken.effectiveSender.userId, '42');
    });

    test('an announcement has no system message: its words are the notice', () {
      final frame = TwitchDanmakuCodec.decode('${_notice('@login=mod;msg-id=announcement;system-msg=')} :read this');
      expect(frame.messages, hasLength(1), reason: 'the words are the notice, not a second line');
      expect(frame.messages.single.type, LiveMessageType.notice);
      expect(frame.messages.single.text, 'read this');
      expect(frame.messages.single.payload, LiveNoticeKind.system);
    });

    test('a raid is a raid, the unknown is system, and a shared chat its source', () {
      LiveNoticeKind kindOf(String tags) =>
          TwitchDanmakuCodec.decode(_notice(tags)).messages.single.payload! as LiveNoticeKind;

      expect(kindOf(r'@msg-id=raid;system-msg=a\srider'), LiveNoticeKind.raid);
      expect(kindOf(r'@msg-id=poll_begin;system-msg=a\spoll'), LiveNoticeKind.system);
      expect(
        kindOf('@msg-id=sharedchatnotice;source-msg-id=raid;system-msg=shared'),
        LiveNoticeKind.raid,
        reason: 'the event of a channel sharing the chat is named by its source',
      );
    });

    test('a community gift counts what it gives, and which notices are its own', () {
      TwitchCommunityGift? giftOf(String tags) => TwitchDanmakuCodec.communityGift(TwitchIrcLine.parse(_notice(tags))!);

      expect(giftOf('@msg-id=submysterygift;msg-param-community-gift-id=77;msg-param-mass-gift-count=5'), (
        id: '77',
        announcement: true,
        count: 5,
      ));
      expect(giftOf('@msg-id=anonsubgift;msg-param-community-gift-id=77')!.announcement, isFalse);
      expect(giftOf('@msg-id=anonsubmysterygift;msg-param-community-gift-id=77')!.count, 1, reason: 'no count is one');
      expect(giftOf('@msg-id=submysterygift;msg-param-community-gift-id=77;msg-param-mass-gift-count=0')!.count, 1);
      expect(giftOf('@msg-id=submysterygift;system-msg=x'), isNull, reason: 'no gift id is no community gift');
      expect(giftOf('@msg-id=sub;msg-param-community-gift-id=77'), isNull, reason: 'a plain sub gives none');
    });

    test('a frame pairs the notice of a community gift with the gift', () {
      final frame = TwitchDanmakuCodec.decode(
        _notice('@msg-id=submysterygift;msg-param-community-gift-id=77;msg-param-mass-gift-count=3;system-msg=gifted'),
      );
      final notice = frame.messages.single;
      expect(frame.communityGifts[notice]!.id, '77');
      expect(frame.communityGifts[notice]!.count, 3);
    });
  });

  group('the waits and the words the session keeps', () {
    test('heartbeat, silence, retries and the gift pair have their numbers', () {
      expect(TwitchDanmakuCodec.endpoint.toString(), 'wss://irc-ws.chat.twitch.tv');
      expect(TwitchDanmakuCodec.heartbeatInterval, const Duration(seconds: 40));
      expect(TwitchDanmakuCodec.inactivityTimeout, const Duration(seconds: 120));
      expect(TwitchDanmakuCodec.maxReconnectAttempts, 8);
      expect(TwitchDanmakuCodec.reconnectStepCap, const Duration(seconds: 6));
      expect(TwitchDanmakuCodec.communityGiftWait, const Duration(seconds: 2));
      expect(TwitchDanmakuCodec.communityGiftLifetime, const Duration(minutes: 1));
      expect(TwitchDanmakuCodec.heartbeat, 'PING :tmi.twitch.tv');
      expect(TwitchDanmakuCodec.capabilities, 'CAP REQ :twitch.tv/tags twitch.tv/commands twitch.tv/membership');
    });

    test('which notice ids mean a subscription, and which a community gift', () {
      expect(TwitchDanmakuCodec.communityGiftAnnouncements, {'submysterygift', 'anonsubmysterygift'});
      expect(TwitchDanmakuCodec.communityGiftMembers, {'subgift', 'anonsubgift'});
      expect(
        TwitchDanmakuCodec.subscriptionNotices,
        containsAll(<String>[
          ...TwitchDanmakuCodec.communityGiftAnnouncements,
          ...TwitchDanmakuCodec.communityGiftMembers,
          'sub',
          'resub',
          'primepaidupgrade',
        ]),
        reason: 'a community gift still reads as a subscription notice',
      );
    });

    test('the refused-cookie notice is a system line the room can show', () {
      final notice = TwitchDanmakuCodec.cookieExpiredNotice();
      expect(notice.type, LiveMessageType.notice);
      expect(notice.payload, LiveNoticeKind.system);
      expect(notice.text, contains('Twitch'));
    });
  });

  group('the chat reader of the 3.x client', () {
    test('a line has to reach a trailing part to be chat', () {
      expect(TwitchDanmakuCodec.chat(':tester!tester@t.tmi.twitch.tv PRIVMSG #tester'), isNull);
      expect(TwitchDanmakuCodec.chat('@id=c-1 :t!u@h NOTICE #tester :look, a PRIVMSG here'), isNull);
      expect(TwitchDanmakuCodec.chat('hello'), isNull);
      // Any line that holds ` PRIVMSG ` counts, prefix or no prefix, command or
      // no command: what follows the first ` :` after it is the text.
      final bare = TwitchDanmakuCodec.chat('@id=c-1;user-id=9 PRIVMSG #tester :hi')!;
      expect(bare.text, 'hi');
      expect(bare.messageId, 'c-1');
      expect(bare.effectiveSender.userName, 'Twitch', reason: 'no display-name and no nick! to read');
    });

    test('a tag without = is kept by the line parser and dropped by the chat reader', () {
      const line = '@emotes;id=c-2 :t!u@t.tmi.twitch.tv PRIVMSG #tester :x';
      expect(TwitchIrcLine.parse(line)!.tags['emotes'], isEmpty);
      final spoken = TwitchDanmakuCodec.chat(line)!;
      expect(spoken.messageId, 'c-2');
      // A tag block that holds nothing leaves the chat without its tags.
      expect(TwitchDanmakuCodec.chat('@ PRIVMSG #tester :x')!.messageId, isEmpty);
    });

    test('no time tag, or one that is no number, leaves the line without a time', () {
      for (final timestamp in ['', 'many', '-']) {
        expect(
          TwitchDanmakuCodec.decode(_privmsg(extra: <String, String>{'tmi-sent-ts': timestamp})).messages.single.sentAt,
          isNull,
          reason: 'tmi-sent-ts="$timestamp" is no time',
        );
      }
    });
  });

  group('a cheer that has nothing to key on', () {
    test('without a message id the cheer is keyed by the speaker and the moment', () {
      final cheer = TwitchDanmakuCodec.decode(_privmsg(extra: const <String, String>{'bits': '50', 'id': ''}))
          .messages
          .first;
      final gift = cheer.payload! as LiveGift;
      expect(cheer.messageId, isEmpty, reason: 'there is no chat id to hang ":bits" on');
      expect(gift.combo.comboKey, 'bits:123:1790519893202');
      expect(gift.count, 50);
      expect(gift.value.totalValue, 50);

      final anonymous = TwitchDanmakuCodec.decode('@bits=7 PRIVMSG #tester :hi').messages.first;
      expect((anonymous.payload! as LiveGift).combo.comboKey, 'bits::', reason: 'no account, no time');
      expect(anonymous.effectiveSender.userId, isEmpty);
    });
  });

  group('what the announcements say about their viewer', () {
    test('a USERNOTICE with nothing to say gives no line', () {
      expect(TwitchDanmakuCodec.decode(_notice('@msg-id=raid;system-msg=')).messages, isEmpty);
      expect(TwitchDanmakuCodec.decode('${_notice('@msg-id=sub;system-msg=')} :   ').messages, isEmpty);
    });

    test('the notice names the viewer by display-name, else login, else the site', () {
      String? speaker(String tags) {
        final messages = TwitchDanmakuCodec.decode(_notice(tags)).messages;
        return messages.isEmpty ? null : messages.first.effectiveSender.userName;
      }

      expect(speaker(r'@display-name=Rich;login=rich;msg-id=sub;system-msg=New\ssub'), 'Rich');
      expect(speaker(r'@display-name=;login=rich;msg-id=sub;system-msg=New\ssub'), 'rich');
      expect(speaker(r'@msg-id=sub;system-msg=New\ssub'), isEmpty, reason: 'a notice with nobody behind it');

      final frame = TwitchDanmakuCodec.decode(
        '${_notice(r'@display-name=Rich;user-id=42;color=#177DE3;id=n-1;msg-id=sub;system-msg=New\ssub')} :hi',
      );
      final notice = frame.messages.first;
      final spoken = frame.messages.last;
      expect(notice.effectiveSender.nameColor, isNotNull);
      expect(
        <int>[
          notice.effectiveSender.nameColor!.r,
          notice.effectiveSender.nameColor!.g,
          notice.effectiveSender.nameColor!.b,
        ],
        [0x17, 0x7D, 0xE3],
      );
      expect(spoken.messageId, 'n-1', reason: "the viewer's words keep the notice's own id");
      expect(spoken.color, notice.effectiveSender.nameColor);
      expect(notice.text, 'New sub');
    });

    test('a community gift marks its member notices too, and alike notices are two keys', () {
      final member = TwitchDanmakuCodec.decode(
        _notice(r'@msg-id=subgift;msg-param-community-gift-id=77;display-name=Rich;system-msg=Gifted\sto\ssomeone'),
      );
      expect(member.messages.single.payload, LiveNoticeKind.subscription);
      final paired = member.communityGifts.entries.single;
      expect(paired.value, (id: '77', announcement: false, count: 1));

      final twice = TwitchDanmakuCodec.decode(
        '${_notice('@msg-id=submysterygift;msg-param-community-gift-id=77;system-msg=gifted')}\r\n'
        '${_notice('@msg-id=submysterygift;msg-param-community-gift-id=77;system-msg=gifted')}',
      );
      expect(twice.messages, hasLength(2));
      expect(twice.communityGifts, hasLength(2), reason: 'the map is keyed by identity, so the room can pair each one');
    });
  });

  group('frames the server sends in other shapes', () {
    test('a frame split by bare line feeds still answers every PING', () {
      final frame = TwitchDanmakuCodec.decode('PING :tmi.twitch.tv\n${_privmsg(text: 'one')}\nPING :tmi.twitch.tv');
      expect(frame.replies, ['PONG :tmi.twitch.tv', 'PONG :tmi.twitch.tv']);
      expect(frame.messages.map((line) => line.text), ['one']);
      // Only a server PING is answered; a line that merely mentions one is not.
      expect(TwitchDanmakuCodec.decode(':tmi.twitch.tv PRIVMSG #tester :PING :tmi').replies, isEmpty);
    });

    test('the refused login is found with tags before the prefix, and a channel NOTICE is not it', () {
      expect(
        TwitchDanmakuCodec.isLoginRejection(
          '@msg-id=login_failed :tmi.twitch.tv NOTICE * :Login authentication failed',
        ),
        isTrue,
      );
      expect(TwitchDanmakuCodec.isLoginRejection('NOTICE * :Improperly formatted auth'), isTrue);
      expect(TwitchDanmakuCodec.isLoginRejection(':tmi.twitch.tv NOTICE #tester :slow_mode'), isFalse);
      for (final line in [':tmi.twitch.tv', '@x', '', ' :tmi.twitch.tv NOTICE * :x']) {
        expect(TwitchDanmakuCodec.isLoginRejection(line), isFalse, reason: '"$line" is no refusal');
      }
      final frame = TwitchDanmakuCodec.decode(
        '@msg-id=login_failed :tmi.twitch.tv NOTICE * :Login authentication failed',
      );
      expect(frame.loginRejected, isTrue);
      expect(frame.messages, isEmpty);
    });
  });
}
