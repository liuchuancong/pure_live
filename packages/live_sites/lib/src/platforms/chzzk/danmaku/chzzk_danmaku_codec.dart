import 'dart:convert';
import 'dart:math';

import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/enums/live_notice_kind.dart';
import 'package:live_sites/src/models/message/live_emote/live_emote.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/message/live_retraction/live_retraction.dart';
import 'package:live_sites/src/models/message/message_sender/message_sender.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_message/live_super_chat_message.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_price/live_super_chat_price.dart';
import 'package:live_sites/src/platforms/chzzk/api/chzzk_endpoints.dart';
import 'package:live_sites/src/platforms/chzzk/parsers/chzzk_json.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// What one chat frame held.
///
/// [joined] is three-state: null when the frame was not a join answer, false
/// when the server refused it ([refusal] says why, and [retry] whether the
/// site's own client would connect again).
final class ChzzkDanmakuFrame {
  /// Creates the result.
  const ChzzkDanmakuFrame({
    this.messages = const [],
    this.ping = false,
    this.joined,
    this.sessionId = '',
    this.refusal,
    this.retry = false,
    this.pushed = false,
    this.closed = false,
  });

  /// The lines the frame carries, in order.
  final List<LiveMessage> messages;

  /// The server's ping, which the client answers at once.
  final bool ping;

  /// The join was accepted (true) or refused (false); null for every other
  /// frame.
  final bool? joined;

  /// The session id of an accepted join, which the recent-chat request needs.
  final String sessionId;

  /// Why the join was refused (`<retCode> <retMsg>`).
  final String? refusal;

  /// Whether the refusal is one the site's client connects again on.
  final bool retry;

  /// Whether the frame held lines pushed live (the only traffic that restarts
  /// the wait before the live's state is read again).
  final bool pushed;

  /// The server ended the session.
  final bool closed;
}

/// The line fields [ChzzkDanmakuCodec.line] reads out of one chat item.
typedef _Row = ({
  String text,
  String user,
  int? time,
  DateTime? sentAt,
  Map<String, dynamic>? profile,
  Map<String, dynamic> extras,
});

/// Chzzk's web chat, as the website's own client speaks it, without I/O.
///
/// Every frame is a JSON object named by its `cmd`; the client's join,
/// recent-chat and ping frames are the SDK's own (`svcid` `game`, `devType`
/// 2001, `auth` `READ`). A line names its fields one way when it is pushed live
/// (`msg`, `uid`, `msgTime`, `msgTypeCode`, `msgStatusType`) and another in the
/// recent chat (`content`, `userId`, `messageTime`, `messageTypeCode`,
/// `messageStatusType`), while `profile` and `extras` arrive either as an
/// object or as JSON text — both forms are read.
///
/// Only a line whose status is `NORMAL` (or missing) is shown: `BLIND` and
/// `CBOTBLIND` lines still carry their text and the site hides it. The
/// message id is `<user>:<time>`, which is how the site itself tells lines
/// apart and how it blinds them. A donation ([donationType]) is a super chat of
/// `extras.payAmount` cheese (1 cheese is one won), a subscription
/// ([subscriptionType]) is a notice *and* its text as chat, and a subscription
/// gift or a system line is a notice.
abstract final class ChzzkDanmakuCodec {
  /// Ping period: the SDK's `pingInterval` (20 000 ms).
  static const Duration heartbeatInterval = Duration(seconds: 20);

  /// Silence after which the socket is replaced: the SDK closes a socket that
  /// answers nothing within its `pingTimeout` (10 000 ms) of a ping sent after
  /// 20 s of quiet, so 30 s in all.
  static const Duration inactivityTimeout = Duration(seconds: 30);

  /// How long the join's answer may take: the SDK's `callbackTimeout`.
  static const Duration joinTimeout = Duration(seconds: 5);

  /// Recent chat lines asked for after joining, as the site asks.
  static const int recentCount = 50;

  /// Text — the kind a line without a numeric type is read as.
  static const int textType = 1;

  /// A donation (`치즈 후원`): a super chat whose text is the donor's message,
  /// the title of the video it pays for, or the pledge of a mission.
  static const int donationType = 10;

  /// A subscription, whose text is the subscriber's message.
  static const int subscriptionType = 11;

  /// A subscription gift (`구독권 선물`).
  static const int subscriptionGiftType = 12;

  /// A system line (chat modes, restrictions).
  static const int systemType = 30;

  /// The name the site shows for an anonymous donor.
  static const String anonymousDonor = '익명의 후원자';

  /// The unit of donations (`치즈`), one won each.
  static const String cheese = '치즈';

  /// The currency a donation is worth in, for sorting and conversion.
  static const String cheeseCurrency = 'KRW';

  /// Join refusals the site's own client connects again on.
  static const Set<int> retryCodes = {302, 303, 304};

  /// The routing answer's fallback, as the SDK has it built in. The routing
  /// service listed six servers on 2026-09-28; this list stays the SDK's five.
  static const List<String> defaultServers = [
    'kr-ss1.chat.naver.com',
    'kr-ss2.chat.naver.com',
    'kr-ss3.chat.naver.com',
    'kr-ss4.chat.naver.com',
    'kr-ss5.chat.naver.com',
  ];

  /// Most session servers taken from a routing answer.
  static const int maxServers = 16;

  /// Handshake headers: the site's origin and the desktop UA of every chzzk
  /// request.
  static const Map<String, String> handshakeHeaders = {
    'origin': ChzzkEndpoints.origin,
    'user-agent': ChzzkEndpoints.userAgent,
  };

  /// The client's ping; the server answers `{"ver":"2","cmd":10000}`.
  static const String ping = '{"ver":"3","cmd":0}';

  /// The answer to a server ping.
  static const String pong = '{"ver":"3","cmd":10000}';

  /// Largest time a `DateTime` can hold, in milliseconds.
  static const int maxMillis = 8640000000000000;

  static final RegExp _chatChannelId = RegExp(r'^[A-Za-z0-9_-]{1,64}$');
  static final RegExp _server = RegExp(r'^[a-z0-9-]{1,63}\.chat\.naver\.com$');
  static final RegExp _emojiCode = RegExp(r'\{:([^{}:\s]+):\}');
  static final RegExp _thousands = RegExp(r'\B(?=(\d{3})+(?!\d))');

  /// Whether [id] can be a chat channel id: base64url characters, at most 64
  /// (`N2l_uf`, `N2l-x_`).
  static bool isChatChannelId(String id) => _chatChannelId.hasMatch(id);

  /// The access token of a decoded token answer (`code` 200 and a non-empty
  /// `content.accessToken`), or null.
  static String? accessToken(Object? answer) => switch (answer) {
    {'code': 200, 'content': {'accessToken': final String token}} when token.isNotEmpty => token,
    _ => null,
  };

  /// The session servers of a decoded routing answer
  /// (`code` 200, `result.sessionServerList`): host names directly under
  /// `chat.naver.com`, in order, without repeats, at most [maxServers]; null
  /// when there is none. The answer's `expireTime` (86400 on 2026-09-28) is not
  /// read — the site re-routes per connect and so does this adapter.
  static List<String>? servers(Object? answer) {
    if (answer case {'code': 200, 'result': {'sessionServerList': final List<Object?> list}}) {
      final hosts = <String>{
        for (final host in list)
          if (host is String && _server.hasMatch(host)) host,
      };
      if (hosts.isNotEmpty) return List.unmodifiable(hosts.take(maxServers));
    }
    return null;
  }

  /// The chat sockets of [servers], starting at [first] and going round.
  static List<Uri> endpoints(List<String> servers, int first) => [
    for (var index = 0; index < servers.length; index++)
      ChzzkEndpoints.chatSocket(servers[(first + index) % servers.length]),
  ];

  /// The read-only join of [chatChannelId] with [token], byte-for-byte what the
  /// recordings of 2026-09-27 sent.
  static String join(String chatChannelId, String token) => jsonEncode({
    'ver': '3',
    'cmd': 100,
    'svcid': 'game',
    'cid': chatChannelId,
    'bdy': {'uid': null, 'devType': 2001, 'accTkn': token, 'auth': 'READ'},
    'tid': 1,
  });

  /// The recent-chat request of the session [sessionId].
  static String recent(String chatChannelId, String sessionId) => jsonEncode({
    'ver': '3',
    'cmd': 5101,
    'svcid': 'game',
    'cid': chatChannelId,
    'sid': sessionId,
    'bdy': {'recentMessageCount': recentCount},
    'tid': 2,
  });

  /// The chat channel of a decoded live-status answer while the live is open
  /// (`code` 200, `content.status` `OPEN`, a usable `chatChannelId`); null
  /// otherwise. A finished broadcast keeps its channel id in the channel's own
  /// answer, which is why the state is asked here and not from the channel.
  static String? liveChatChannel(Object? answer) => switch (answer) {
    {'code': 200, 'content': {'status': 'OPEN', 'chatChannelId': final String id}} when isChatChannelId(id) => id,
    _ => null,
  };

  /// How long a donation stays among the super chats, by the site's five amount
  /// tiers (its `level0`–`level4` styles: below 10 000, 100 000, 500 000 and
  /// 1 000 000 cheese). The site itself keeps donations in the chat list
  /// without a time; these are the first five steps of bilibili's super chats,
  /// which is what the app's super-chat bar already shows.
  static Duration superChatDuration(int amount) => switch (amount) {
    >= 1000000 => const Duration(hours: 1),
    >= 500000 => const Duration(minutes: 30),
    >= 100000 => const Duration(minutes: 5),
    >= 10000 => const Duration(minutes: 2),
    _ => const Duration(minutes: 1),
  };

  /// A donation's amount as the site writes it: digits grouped by commas and the
  /// unit, `1,000 치즈`.
  static String cheeseText(int amount) => '${'$amount'.replaceAll(_thousands, ',')} $cheese';

  /// Reads one frame: text, or UTF-8 bytes (malformed bytes become U+FFFD).
  /// [receivedAt] (default: now) starts the super chat of a donation whose line
  /// carries no time.
  ///
  /// The frame's JSON object is named by `cmd`: `0` is the server's ping;
  /// `10100` the join answer (`retCode` 0 accepts, with `bdy.sid`); `93101`
  /// (chat) and `93102` (lines the server sends on its own) push a list of
  /// lines; `15101` answers the recent chat (`bdy.messageList`, then the
  /// notice pinned now, `bdy.notice`); `94010` is a pin made while live;
  /// `94008` blinds one line afterwards; `90102` ends the session. Everything
  /// else — the pong, the `93006` events (chat modes, donations settings,
  /// bans, predictions, gifts, temporary restrictions) and the `94005`/`94015`
  /// kicks and penalties — holds nothing to show, and so does a frame that is
  /// not a JSON object. A field of the wrong type costs only that field or that
  /// line, never the frame. The member count some lines carry (`mbrCnt`,
  /// `memberCount`, `userCount`) counts the chat's *connections*, not the
  /// audience (it differed from the room's own count by 4%–75% on 2026-09-28),
  /// and is not read.
  static ChzzkDanmakuFrame decode(Object? data, {DateTime? receivedAt}) {
    final text = switch (data) {
      final String text => text,
      final List<int> bytes => utf8.decode(bytes, allowMalformed: true),
      _ => null,
    };
    if (text == null) return const ChzzkDanmakuFrame();
    final Object? root;
    try {
      root = jsonDecode(text);
    } on FormatException {
      return const ChzzkDanmakuFrame();
    }
    if (root is! Map) return const ChzzkDanmakuFrame();
    final body = root['bdy'];
    final now = receivedAt ?? DateTime.now();
    return switch (root['cmd']) {
      0 => const ChzzkDanmakuFrame(ping: true),
      90102 => const ChzzkDanmakuFrame(closed: true),
      10100 => _joinAnswer(root, body),
      93101 || 93102 when body is List => ChzzkDanmakuFrame(
        messages: _lines(body, recent: false, receivedAt: now),
        pushed: true,
      ),
      15101 when root['retCode'] == 0 && body is Map && body['messageList'] is List => ChzzkDanmakuFrame(
        messages: [
          ..._lines(body['messageList']! as List<Object?>, recent: true, receivedAt: now),
          if (_object(body['notice']) case final notice?) ?pinned(notice),
        ],
      ),
      94010 when body is Map => ChzzkDanmakuFrame(messages: [?pinned(_mapOf(body))]),
      94008 when body is Map => ChzzkDanmakuFrame(messages: [?blind(_mapOf(body))]),
      _ => const ChzzkDanmakuFrame(),
    };
  }

  static ChzzkDanmakuFrame _joinAnswer(Map<Object?, Object?> root, Object? body) {
    final code = root['retCode'];
    if (code == 0) {
      final sid = body is Map ? body['sid'] : null;
      return ChzzkDanmakuFrame(joined: true, sessionId: sid is String ? sid : '');
    }
    return ChzzkDanmakuFrame(
      joined: false,
      refusal: '${_scalar(code)} ${_scalar(root['retMsg'])}'.trim(),
      retry: code is int && retryCodes.contains(code),
    );
  }

  static List<LiveMessage> _lines(List<Object?> items, {required bool recent, required DateTime receivedAt}) => [
    for (final item in items)
      if (item is Map) ...[?subscription(item), ?line(item, recent: recent, receivedAt: receivedAt)],
  ];

  /// The notice of a subscription line: the subscriber's name, then 订阅了
  /// 「tier」 and 已订阅 N 个月 in Chinese around the platform's own names
  /// (`extras.tierName`, `extras.month`), the subscriber being
  /// `profile.nickname` else `extras.nickname`. Its id is `subscription:<user>:<time>` so it never
  /// collides with the same line's chat message. Null for any other line, and
  /// for one the site does not show.
  static LiveMessage? subscription(Map<Object?, Object?> item) {
    if (_int(item['messageTypeCode'] ?? item['msgTypeCode']) != subscriptionType) return null;
    final status = item['messageStatusType'] ?? item['msgStatusType'];
    if (status != null && status != 'NORMAL') return null;
    final row = _rowOf(item);
    final extras = row.extras;
    var name = _scalar(row.profile?['nickname']).trim();
    if (name.isEmpty) name = _scalar(extras['nickname']).trim();
    final tier = _scalar(extras['tierName']).trim();
    final months = _int(extras['month']);
    final subscribed = tier.isEmpty ? '订阅了频道' : '订阅了「$tier」';
    final text = months != null && months > 0 ? '$subscribed，已订阅 $months 个月' : subscribed;
    return LiveMessage.normalized(
      type: LiveMessageType.notice,
      sender: MessageSender.normalized(userId: row.user, userName: name),
      text: name.isEmpty ? text : '$name $text',
      color: LiveMessageColor.white,
      messageId: row.id(prefix: 'subscription'),
      sentAt: row.sentAt,
      payload: LiveNoticeKind.subscription,
    );
  }

  /// One line of the chat, or null when the site does not show it or has no
  /// kind this adapter can name.
  ///
  /// A line pushed live names its fields `msg`, `uid`, `msgTime`,
  /// `msgTypeCode` and `msgStatusType`; a recent one `content`, `userId`,
  /// `messageTime`, `messageTypeCode` and `messageStatusType`.
  static LiveMessage? line(Map<Object?, Object?> item, {bool recent = false, DateTime? receivedAt}) {
    final names = recent ? _recentFields : _pushedFields;
    final type = _int(item[names['type']]) ?? textType;
    final status = item[names['status']];
    if (status != null && status != 'NORMAL') return null;
    final row = _rowOf(item, names: names);
    return switch (type) {
      textType || subscriptionType => row.text.isEmpty ? null : _chat(row),
      donationType => _donation(row, receivedAt ?? DateTime.now()),
      subscriptionGiftType => _subscriptionGift(row),
      systemType => _system(row),
      _ => null,
    };
  }

  static const Map<String, String> _pushedFields = {
    'text': 'msg',
    'user': 'uid',
    'time': 'msgTime',
    'type': 'msgTypeCode',
    'status': 'msgStatusType',
  };

  static const Map<String, String> _recentFields = {
    'text': 'content',
    'user': 'userId',
    'time': 'messageTime',
    'type': 'messageTypeCode',
    'status': 'messageStatusType',
  };

  static _Row _rowOf(Map<Object?, Object?> item, {Map<String, String>? names}) {
    final fields = names ?? _pushedFields;
    final time = _int(item[fields['time']]);
    return (
      text: _scalar(item[fields['text']]).trim(),
      user: _scalar(item[fields['user']]),
      time: time,
      sentAt: time != null && time > 0 && time <= maxMillis ? DateTime.fromMillisecondsSinceEpoch(time) : null,
      profile: _object(item['profile']),
      extras: _object(item['extras']) ?? const <String, dynamic>{},
    );
  }

  static LiveMessage _chat(_Row row) => LiveMessage.normalized(
    sender: MessageSender.normalized(userId: row.user, userName: _scalar(row.profile?['nickname'])),
    text: row.text,
    color: LiveMessageColor.white,
    messageId: row.id(),
    sentAt: row.sentAt,
    emotes: emotes(row.text, row.extras['emojis']),
  );

  /// A donation as a super chat of `extras.payAmount` cheese, shown for
  /// [superChatDuration] from the line's time (or [receivedAt] when it has
  /// none), with the donor's avatar when it is one of NAVER's images. An
  /// anonymous donor (`extras.isAnonymous`, or the user `anonymous`) is
  /// [anonymousDonor] without an id, as the site shows it. The site colours
  /// donations by tier in its style sheet and not in the line, so no colours
  /// are invented here. A donation with neither text nor amount shows nothing.
  static LiveMessage? _donation(_Row row, DateTime receivedAt) {
    final anonymous = row.extras['isAnonymous'] == true || row.user == 'anonymous';
    final amount = max(_int(row.extras['payAmount']) ?? 0, 0);
    if (row.text.isEmpty && amount == 0) return null;
    final donor = anonymous ? 'anonymous' : row.user;
    final id = row.id(named: donor);
    final name = anonymous ? anonymousDonor : _scalar(row.profile?['nickname']);
    final start = row.sentAt ?? receivedAt;
    return LiveMessage.normalized(
      type: LiveMessageType.superChat,
      sender: MessageSender.normalized(userId: anonymous ? '' : row.user, userName: name),
      text: row.text,
      color: LiveMessageColor.white,
      messageId: id,
      sentAt: row.sentAt,
      payload: LiveSuperChatMessage.of(
        messageId: id,
        userName: name,
        faceUrl: anonymous ? '' : image(row.profile?['profileImageUrl']),
        text: row.text,
        price: SuperChatPrice.of(
          amount: amount == 0 ? null : amount,
          currency: cheeseCurrency,
          displayText: cheeseText(amount),
        ),
        startTime: start,
        endTime: start.add(superChatDuration(amount)),
      ),
    );
  }

  /// A subscription gift (`구독권 선물`): `<giver> 向频道赠送了 5 张「팬」订阅券`
  /// for `extras.giftType` `SUBSCRIPTION_GIFT` (`quantity`, `giftTierName`),
  /// `<giver> 向 <receiver> 赠送了「팬」订阅券` otherwise (`receiverNickname`).
  /// The giver is [anonymousDonor] when the site shows it so: a channel gift
  /// carrying an `anonymousToken`, a gift to a viewer with no profile, or the
  /// user `anonymous`.
  static LiveMessage? _subscriptionGift(_Row row) {
    final toChannel = row.extras['giftType'] == 'SUBSCRIPTION_GIFT';
    final anonymous =
        row.user == 'anonymous' || (toChannel ? row.extras.containsKey('anonymousToken') : row.profile == null);
    final giver = anonymous ? anonymousDonor : _scalar(row.profile?['nickname']).trim();
    final tier = _scalar(row.extras['giftTierName']).trim();
    final pass = tier.isEmpty ? '订阅券' : '「$tier」订阅券';
    final String gift;
    if (toChannel) {
      final quantity = _int(row.extras['quantity']);
      gift = quantity != null && quantity > 0 ? '向频道赠送了 $quantity 张$pass' : '向频道赠送了$pass';
    } else {
      final receiver = _scalar(row.extras['receiverNickname']).trim();
      gift = receiver.isEmpty ? '赠送了$pass' : '向 $receiver 赠送了$pass';
    }
    return LiveMessage.normalized(
      type: LiveMessageType.notice,
      sender: MessageSender.normalized(userId: anonymous ? '' : row.user, userName: giver),
      text: giver.isEmpty ? gift : '$giver $gift',
      color: LiveMessageColor.white,
      messageId: row.id(named: anonymous ? 'anonymous' : row.user),
      sentAt: row.sentAt,
      payload: LiveNoticeKind.giftedSubscription,
    );
  }

  /// A system line (`SYSTEM_MESSAGE`: `이모티콘 모드 ON`, a restriction): the
  /// site shows its text as the title and `extras.description` beneath it,
  /// joined here by `：`. A line whose `extras.visibleRoles` names roles is for
  /// the streamer and the managers only, and this client is anonymous, so it is
  /// left out.
  static LiveMessage? _system(_Row row) {
    if (row.extras['visibleRoles'] case final List<Object?> roles when roles.isNotEmpty) return null;
    final description = _scalar(row.extras['description']).trim();
    final text = [row.text, description].where((part) => part.isNotEmpty).join('：');
    if (text.isEmpty) return null;
    return LiveMessage.normalized(
      type: LiveMessageType.notice,
      sender: MessageSender.normalized(userId: row.user),
      text: text,
      color: LiveMessageColor.white,
      messageId: row.id(),
      sentAt: row.sentAt,
      payload: LiveNoticeKind.system,
    );
  }

  /// The notice pinned above the chat (the recent chat's `notice`, or the body
  /// of a `94010`, both in the recent form): who pinned whose line, as the
  /// site's pinned bar says it — `<author> 置顶了消息：<text>` when the author
  /// pinned it, `<pinner> 置顶了 <author> 的消息：<text>` when someone else did.
  /// Its id is `notice:<user>:<time>`, never the id of the line it pins, and it
  /// carries no time: the line's is when it was written, not when it was pinned.
  /// A notice without a time (the site's "nothing pinned") or text is null.
  static LiveMessage? pinned(Map<String, dynamic>? notice) {
    if (notice == null) return null;
    final time = _int(notice['messageTime']);
    final text = _scalar(notice['content']).trim();
    if (time == null || time <= 0 || time > maxMillis || text.isEmpty) return null;
    final user = _scalar(notice['userId']);
    final profile = _object(notice['profile']);
    final author = _scalar(profile?['nickname']).trim();
    final register = _object(_object(notice['extras'])?['registerProfile']);
    final pinner = _scalar(register?['nickname']).trim();
    final byAuthor = pinner.isEmpty || _scalar(register?['userIdHash']) == _scalar(profile?['userIdHash']);
    return LiveMessage.normalized(
      type: LiveMessageType.notice,
      sender: MessageSender.normalized(userId: user, userName: author),
      text: author.isEmpty
          ? '置顶消息：$text'
          : byAuthor
          ? '$author 置顶了消息：$text'
          : '$pinner 置顶了 $author 的消息：$text',
      color: LiveMessageColor.white,
      messageId: user.isEmpty ? 'notice:$time' : 'notice:$user:$time',
      payload: LiveNoticeKind.system,
    );
  }

  /// A line blinded afterwards (`94008`): `userId` and `messageTime` name it,
  /// exactly as the site finds the line, so it retracts `<user>:<time>`. Every
  /// kind the site hides (`BLIND`, `CBOTBLIND`, `HIDDEN`, or none) retracts;
  /// `CANCEL` shows the line again on the site, which cannot be undone here.
  /// When the site hides every line of a viewer (a temporary restriction) it
  /// sends one notice per line.
  static LiveMessage? blind(Map<String, dynamic>? body) {
    if (body == null || body['blindType'] == 'CANCEL') return null;
    final user = _scalar(body['userId']);
    final time = _int(body['messageTime']);
    if (user.isEmpty || time == null || time <= 0 || time > maxMillis) return null;
    return LiveMessage.normalized(
      type: LiveMessageType.retraction,
      color: LiveMessageColor.white,
      payload: LiveRetraction.of(messageId: '$user:$time'),
    );
  }

  /// The pictures of the `{:name:}` codes in [text] that [table] (a line's
  /// `extras.emojis`, name → address) names with an http(s) address: each once,
  /// in the order of the text. The codes stay in the text, as the site's own
  /// chat list keeps them.
  static List<LiveEmote> emotes(String text, Object? table) {
    if (table is! Map || table.isEmpty || !text.contains('{:')) return const [];
    final seen = <String>{};
    return [
      for (final match in _emojiCode.allMatches(text))
        if (table[match.group(1)] case final String url
            when (url.startsWith('https://') || url.startsWith('http://')) && seen.add(match.group(0)!))
          LiveEmote.of(code: match.group(0)!, url: url),
    ];
  }

  /// A JSON object, the object a JSON text holds, or null. The site sends
  /// `profile` and `extras` either way.
  static Map<String, dynamic>? _object(Object? value) {
    if (value is Map) return value.map((key, entry) => MapEntry('$key', entry));
    if (value is! String || value.isEmpty) return null;
    try {
      final decoded = jsonDecode(value);
      return decoded is Map ? decoded.map((key, entry) => MapEntry('$key', entry)) : null;
    } on FormatException {
      return null;
    }
  }

  /// A whole number: a JSON integer, a whole double, or its text.
  static int? _int(Object? value) => switch (value) {
    final int number => number,
    final double number when number == number.roundToDouble() && number.isFinite => number.toInt(),
    final String text => int.tryParse(text.trim()),
    _ => null,
  };

  /// A frame body read as an object; empty when it is not one (the caller has
  /// already matched on `Map`, so this only re-keys it).
  static Map<String, dynamic> _mapOf(Object? value) =>
      value is Map ? value.map((key, entry) => MapEntry('$key', entry)) : const <String, dynamic>{};

  static String _scalar(Object? value) => value is String || value is num ? '$value' : '';
}

extension on _Row {
  /// The site's own line identity: `<user>:<time>`, or empty without either.
  /// [prefix] names the kind when one line yields two messages (a
  /// subscription's notice and its chat text), and [named] substitutes the
  /// anonymous donor's stand-in for its account.
  String id({String prefix = '', String? named}) {
    final user = named ?? this.user;
    if (sentAt == null || user.isEmpty || time == null) return '';
    return prefix.isEmpty ? '$user:$time' : '$prefix:$user:$time';
  }
}
