import 'dart:convert';
import 'dart:math';

import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/chzzk/parsers/chzzk_parser.dart';

/// What one CHZZK chat frame held ([ChzzkDanmakuProtocol.decode]).
final class ChzzkDanmakuFrame {
  /// A frame with nothing to act on.
  const new({
    this.messages = const [],
    this.pushed = false,
    this.joined,
    this.sessionId = '',
    this.refusal = '',
    this.retry = false,
    this.ping = false,
    this.closed = false,
  });

  /// Chat lines, super chats, notices and retractions, in order.
  final List<LiveMessage> messages;

  /// The frame carried lines pushed live (`cmd` 93101 or 93102): the chat
  /// channel is in use.
  final bool pushed;

  /// The answer to the join (`cmd 10100`): true when accepted (`retCode 0`),
  /// false when refused, null when the frame held no answer to it.
  final bool? joined;

  /// The session id (`bdy.sid`) of an accepted join, which the recent-chat
  /// request names; empty when the answer had none.
  final String sessionId;

  /// A refused join's code and text (`105 Incorrect parameter`).
  final String refusal;

  /// The refusal asks the client to connect again (`retCode` 302, 303 or
  /// 304, on which the site's chat SDK reconnects).
  final bool retry;

  /// The server's ping (`cmd 0`), to be answered with
  /// [ChzzkDanmakuProtocol.pong].
  final bool ping;

  /// The server ended the session (`cmd 90102`); the site's chat SDK then
  /// closes without reconnecting.
  final bool closed;
}

/// CHZZK's chat protocol, without I/O.
///
/// Every message is a JSON text frame: the join (`cmd 100`, read-only) is
/// answered by `cmd 10100`, after which the client asks the recent chat
/// (`cmd 5101`, answered by `15101`); chat arrives as `93101` and `93102`;
/// the client pings (`cmd 0`) and the server pongs (`10000`), and a server
/// ping is answered the same way. Donations become super chats,
/// subscription gifts, system lines and the pinned notice become notices of
/// their own, and a line a manager or the clean bot blinded afterwards
/// (`94008`) becomes a retraction.
abstract final class ChzzkDanmakuProtocol {
  /// Ping period: the site's chat SDK pings every twenty seconds.
  static const Duration heartbeatInterval = Duration(seconds: 20);

  /// Silence after which the socket is replaced: the SDK closes a socket
  /// that answers nothing within its ping timeout of a ping sent after 20 s
  /// without a message — thirty seconds in all.
  static const Duration quietPeriod = Duration(seconds: 30);

  /// Recent chat lines asked for after joining, as the site asks.
  static const int recentCount = 50;

  /// Text, the first of the message kinds (`msgTypeCode`); the others are
  /// the constants below. Images, stickers, parties and shop purchases are
  /// not read.
  static const int textType = 1;

  /// A donation (`치즈 후원`): a super chat whose text is the donor's
  /// message, the title of the video it pays for or the mission it pledges.
  static const int donationType = 10;

  /// A subscription, whose text is the subscriber's message: a notice, then
  /// the message as chat.
  static const int subscriptionType = 11;

  /// A subscription gift (`구독권 선물`): a notice composed from `extras`.
  static const int subscriptionGiftType = 12;

  /// A system line (chat modes, restrictions): a notice.
  static const int systemType = 30;

  /// The name the site shows for an anonymous donor (its `익명의 후원자`).
  static const String anonymousDonor = '익명의 후원자';

  /// The unit of donations (1 치즈 is one won), as the site names it after
  /// an amount. The unified unit table has no cheese of its own, so a
  /// donation counts as the platform's paid currency.
  static const String cheese = '치즈';

  /// How long a donation stays among the super chats, by the site's five
  /// amount tiers (below 10 000, 100 000, 500 000 and 1 000 000 치즈, and
  /// above) — the first five steps of Bilibili's super chats, the durations
  /// the previous generation's super chat bar already showed.
  static Duration superChatDuration(int amount) => switch (amount) {
    >= 1000000 => const Duration(hours: 1),
    >= 500000 => const Duration(minutes: 30),
    >= 100000 => const Duration(minutes: 5),
    >= 10000 => const Duration(minutes: 2),
    _ => const Duration(minutes: 1),
  };

  /// A donation's amount as the site writes it: digits grouped by commas
  /// and the unit, `1,000 치즈`.
  static String cheeseText(int amount) => '${'$amount'.replaceAll(_thousands, ',')} $cheese';

  static final RegExp _thousands = RegExp(r'\B(?=(\d{3})+(?!\d))');

  /// Join refusals on which the site's chat SDK connects again.
  static const Set<int> retryCodes = {302, 303, 304};

  /// The routing answer's fallback, as the SDK has it built in.
  static const List<String> defaultServers = [
    'kr-ss1.chat.naver.com',
    'kr-ss2.chat.naver.com',
    'kr-ss3.chat.naver.com',
    'kr-ss4.chat.naver.com',
    'kr-ss5.chat.naver.com',
  ];

  /// Most session servers taken from a routing answer.
  static const int maxServers = 16;

  /// The session servers of the chat service `game`.
  static final Uri routingUrl = Uri.https('routing.chat.naver.com', '/routing/getRouting', {'serviceId': 'game'});

  /// Handshake headers: the site's origin and the desktop UA of every CHZZK
  /// request.
  static Map<String, String> get handshakeHeaders => {
    'origin': ChzzkParser.origin,
    'user-agent': ChzzkParser.headers['user-agent']!,
  };

  /// The client's ping; the server answers `{"ver":"2","cmd":10000}`.
  static const String ping = '{"ver":"3","cmd":0}';

  /// The answer to a server ping.
  static const String pong = '{"ver":"3","cmd":10000}';

  /// Largest time [DateTime] can hold, in milliseconds.
  static const int _maxMillis = 8640000000000000;

  static final RegExp _chatChannelId = RegExp(r'^[A-Za-z0-9_-]{1,64}$');
  static final RegExp _server = RegExp(r'^[a-z0-9-]{1,63}\.chat\.naver\.com$');

  /// Whether [id] can be a chat channel id: base64url characters, at most
  /// 64.
  static bool isChatChannelId(String id) => _chatChannelId.hasMatch(id);

  /// The access token request of [chatChannelId].
  static Uri tokenUrl(String chatChannelId) => Uri.https('comm-api.game.naver.com', '/nng_main/v1/chats/access-token', {
    'channelId': chatChannelId,
    'chatType': 'STREAMING',
  });

  /// The access token of a decoded token answer (`code 200`,
  /// `content.accessToken`), or null.
  static String? accessToken(Object? answer) {
    if (answer case {'code': 200, 'content': {'accessToken': final String token}} when token.isNotEmpty) {
      return token;
    }
    return null;
  }

  /// The session servers of a decoded routing answer (`code 200`,
  /// `result.sessionServerList`): host names under `chat.naver.com`, in
  /// order, without repeats, at most [maxServers]; null when there is none.
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
      Uri(scheme: 'wss', host: servers[(first + index) % servers.length], path: '/chat'),
  ];

  /// The read-only join of [chatChannelId] with [token], as the site's own
  /// client sends it.
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

  /// The live state of the channel [channelId], which the site's chat page
  /// polls every 30 s while the live is open.
  static Uri liveStatusUrl(String channelId) =>
      Uri.https(ChzzkParser.apiHost, '/polling/v3.1/channels/$channelId/live-status');

  /// The chat channel of a decoded live-status answer (`code 200`,
  /// `content.chatChannelId`) while the live is open (`status` `OPEN`);
  /// null otherwise (closed, no chat, not a chat channel id).
  static String? liveChatChannel(Object? answer) {
    if (answer case {'code': 200, 'content': {'status': 'OPEN', 'chatChannelId': final String id}}
        when isChatChannelId(id)) {
      return id;
    }
    return null;
  }

  /// Reads one frame of a chat socket: text, or UTF-8 bytes (malformed
  /// bytes become U+FFFD). [receivedAt] starts the super chat of a donation
  /// that has no time.
  ///
  /// The frame's JSON object is named by `cmd`:
  ///
  /// - `0`: the server's ping;
  /// - `10100`: the answer to the join; `retCode 0` accepts it (with
  ///   `bdy.sid`), anything else refuses it;
  /// - `93101` (chat) and `93102` (lines the server sends on its own:
  ///   donations, subscriptions, system lines): `bdy` lists the lines;
  /// - `15101` with `retCode 0`: the recent chat, `bdy.messageList`, then
  ///   the notice pinned now, `bdy.notice`;
  /// - `94010`: the notice pinned now;
  /// - `94008`: a line blinded afterwards;
  /// - `90102`: the server ended the session.
  ///
  /// Everything else (the pong `10000`, events, kicks and penalties) holds
  /// nothing to show; so does a frame that is not a JSON object. A field of
  /// the wrong type costs only that field or that line, never the frame.
  /// The member count of every line (`mbrCnt`, `memberCount`, `userCount`)
  /// counts the chat's connections, not the audience, and is not read.
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
    switch (root['cmd']) {
      case 0:
        return const ChzzkDanmakuFrame(ping: true);
      case 90102:
        return const ChzzkDanmakuFrame(closed: true);
      case 10100:
        final code = root['retCode'];
        if (code == 0) {
          final sid = body is Map ? body['sid'] : null;
          return ChzzkDanmakuFrame(joined: true, sessionId: sid is String ? sid : '');
        }
        return ChzzkDanmakuFrame(
          joined: false,
          refusal: '${_scalar(code)} ${_scalar(root['retMsg'])}'.trim(),
          retry: retryCodes.contains(code),
        );
      case 93101 || 93102 when body is List:
        return ChzzkDanmakuFrame(messages: _lines(body, recent: false, receivedAt: now), pushed: true);
      case 15101 when root['retCode'] == 0 && body is Map && body['messageList'] is List:
        return ChzzkDanmakuFrame(
          messages: [
            ..._lines(body['messageList'] as List<Object?>, recent: true, receivedAt: now),
            if (_object(body['notice']) case final notice?) ?pinned(notice),
          ],
        );
      case 94010 when body is Map:
        return ChzzkDanmakuFrame(messages: [?pinned(body)]);
      case 94008 when body is Map:
        return ChzzkDanmakuFrame(messages: [?blind(body)]);
      default:
        return const ChzzkDanmakuFrame();
    }
  }

  static List<LiveMessage> _lines(List<Object?> items, {required bool recent, required DateTime receivedAt}) => [
    for (final item in items)
      if (item is Map) ...[?subscription(item, recent: recent), ?line(item, recent: recent, receivedAt: receivedAt)],
  ];

  /// The notice of a subscription line: a subscription notice of the
  /// subscriber (`profile.nickname`, else `extras.nickname`) with the tier's
  /// name (`extras.tierName`) and the months (`extras.month`), in Chinese
  /// around the platform's names. Its id is `subscription:<user>:<time>`.
  /// Null for any other line, and for one the site does not show (a status
  /// other than `NORMAL`).
  static LiveMessage? subscription(Map<Object?, Object?> item, {bool recent = false}) {
    final type = _int(item[recent ? 'messageTypeCode' : 'msgTypeCode']);
    if (type != subscriptionType) return null;
    final status = item[recent ? 'messageStatusType' : 'msgStatusType'];
    if (status != null && status != 'NORMAL') return null;
    final time = _int(item[recent ? 'messageTime' : 'msgTime']);
    final user = _scalar(item[recent ? 'userId' : 'uid']);
    final extras = _object(item['extras']) ?? const <Object?, Object?>{};
    final profile = _object(item['profile']);
    var name = _scalar(profile?['nickname']).trim();
    if (name.isEmpty) name = _scalar(extras['nickname']).trim();
    final tier = _scalar(extras['tierName']).trim();
    final months = _int(extras['month']);
    final subscribed = tier.isEmpty ? '订阅了频道' : '订阅了「$tier」';
    final text = months != null && months > 0 ? '$subscribed，已订阅 $months 个月' : subscribed;
    final sentAt = time != null && time > 0 && time <= _maxMillis ? DateTime.fromMillisecondsSinceEpoch(time) : null;
    return LiveMessage(
      type: LiveMessageType.notice,
      userName: name,
      userId: user,
      message: name.isEmpty ? text : '$name $text',
      id: sentAt == null || user.isEmpty ? '' : 'subscription:$user:$time',
      sentAt: sentAt,
      data: 'subscription',
    );
  }

  /// One line of the chat, or null when the site does not show it.
  ///
  /// A line pushed live names its fields `msg`, `uid`, `msgTime` and
  /// `msgTypeCode`; a recent one `content`, `userId`, `messageTime` and
  /// `messageTypeCode`. Both carry `profile` and `extras` as JSON text (or
  /// objects). Only lines whose status is `NORMAL` (or missing) are read:
  /// `BLIND` and `CBOTBLIND` lines still carry their text, and the site does
  /// not show it. The name is `profile.nickname`, the user id `uid`; an
  /// anonymous donation (`extras.isAnonymous`, or the user `anonymous`) is
  /// [anonymousDonor] without a user id. The site tells lines apart by user
  /// and time, so the message id is `<user>:<time>`. Emoji stay as
  /// `{:name:}` in the text; the ones the line's `extras.emojis` names are
  /// its emotes.
  static LiveMessage? line(Map<Object?, Object?> item, {bool recent = false, DateTime? receivedAt}) {
    final type = _int(item[recent ? 'messageTypeCode' : 'msgTypeCode']) ?? textType;
    final status = item[recent ? 'messageStatusType' : 'msgStatusType'];
    if (status != null && status != 'NORMAL') return null;
    final time = _int(item[recent ? 'messageTime' : 'msgTime']);
    final row = _Row(
      text: _scalar(item[recent ? 'content' : 'msg']).trim(),
      user: _scalar(item[recent ? 'userId' : 'uid']),
      time: time,
      sentAt: time != null && time > 0 && time <= _maxMillis ? DateTime.fromMillisecondsSinceEpoch(time) : null,
      profile: _object(item['profile']),
      extras: _object(item['extras']) ?? const <Object?, Object?>{},
    );
    switch (type) {
      case textType || subscriptionType:
        if (row.text.isEmpty) return null;
        return LiveMessage(
          type: LiveMessageType.chat,
          userName: _scalar(row.profile?['nickname']),
          userId: row.user,
          message: row.text,
          id: _id(row.user, row),
          sentAt: row.sentAt,
          emotes: emojis(row.text, row.extras['emojis']),
        );
      case donationType:
        return _donation(row, receivedAt ?? DateTime.now());
      case subscriptionGiftType:
        return _subscriptionGift(row);
      case systemType:
        return _system(row);
      default:
        return null;
    }
  }

  /// The pictures of the `{:name:}` codes in [text] that [table] (a line's
  /// `extras.emojis`, `name` → address) names with an http(s) address, each
  /// once, in the order of the text.
  static List<LiveEmote> emojis(String text, Object? table) {
    if (table is! Map || table.isEmpty || !text.contains('{:')) return const [];
    final seen = <String>{};
    return [
      for (final match in _emojiCode.allMatches(text))
        if (table[match.group(1)] case final String url
            when (url.startsWith('https://') || url.startsWith('http://')) && seen.add(match.group(0)!))
          LiveEmote(code: match.group(0)!, url: url),
    ];
  }

  static final RegExp _emojiCode = RegExp(r'\{:([^{}:\s]+):\}');

  /// The message id of [row] by [user]: `<user>:<time>`, or empty without
  /// a user or a time.
  static String _id(String user, _Row row) => row.sentAt == null || user.isEmpty ? '' : '$user:${row.time}';

  /// A donation: a super chat of `extras.payAmount` 치즈 ([cheeseText]),
  /// shown for [superChatDuration] from the line's time (or [receivedAt]),
  /// with the donor's name and avatar. Its message is the donor's text, the
  /// video title of a video donation or the pledge of a mission; a donation
  /// with neither text nor amount shows nothing.
  static LiveMessage? _donation(_Row row, DateTime receivedAt) {
    final anonymous = row.extras['isAnonymous'] == true || row.user == 'anonymous';
    final amount = max(_int(row.extras['payAmount']) ?? 0, 0);
    if (row.text.isEmpty && amount == 0) return null;
    final id = _id(anonymous ? 'anonymous' : row.user, row);
    final start = row.sentAt ?? receivedAt;
    return LiveMessage(
      type: LiveMessageType.superChat,
      userName: anonymous ? anonymousDonor : _scalar(row.profile?['nickname']),
      message: row.text,
      userId: anonymous ? '' : row.user,
      id: id,
      sentAt: row.sentAt,
      data: LiveSuperChat(
        message: row.text,
        price: amount,
        priceText: amount > 0 ? cheeseText(amount) : '',
        startTime: start,
        endTime: start.add(superChatDuration(amount)),
      ),
    );
  }

  /// A subscription gift: a subscription notice whose text says what the
  /// site's gift line says, in Chinese around the platform's names:
  /// `<giver> 向频道赠送了 5 张「팬」订阅券` for a `SUBSCRIPTION_GIFT`
  /// (`quantity`, `giftTierName`), `<giver> 向 <receiver> 赠送了「팬」订阅券`
  /// otherwise (`receiverNickname`). The giver is [anonymousDonor] when the
  /// site shows it so: a channel gift with an `anonymousToken`, a gift to a
  /// viewer without a profile, or the user `anonymous`.
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
    return LiveMessage(
      type: LiveMessageType.notice,
      userName: giver,
      userId: anonymous ? '' : row.user,
      message: giver.isEmpty ? gift : '$giver $gift',
      id: _id(anonymous ? 'anonymous' : row.user, row),
      sentAt: row.sentAt,
      data: 'subscription',
    );
  }

  /// A system line (chat modes, restrictions): a system notice of its text
  /// and `extras.description`, joined by `：`. A line whose
  /// `extras.visibleRoles` names roles is for the streamer and the managers
  /// only: the site shows it to no one else, and this client is anonymous.
  static LiveMessage? _system(_Row row) {
    if (row.extras['visibleRoles'] case final List<Object?> roles when roles.isNotEmpty) return null;
    final description = _scalar(row.extras['description']).trim();
    final text = [row.text, description].where((part) => part.isNotEmpty).join('：');
    if (text.isEmpty) return null;
    return LiveMessage(
      type: LiveMessageType.notice,
      userName: '',
      message: text,
      id: _id(row.user, row),
      sentAt: row.sentAt,
      data: 'system',
    );
  }

  /// The notice pinned above the chat (the recent chat's `notice`, or the
  /// body of a `94010`): a system notice that says whose line is pinned, as
  /// the site's pinned bar does, in Chinese — `<author> 置顶了消息：<text>`
  /// when the author pinned it, `<pinner> 置顶了 <author> 的消息：<text>`
  /// when someone else did. Its id is `notice:<user>:<time>`, never the id
  /// of the line it pins.
  static LiveMessage? pinned(Map<Object?, Object?> body) {
    final row = _Row(
      text: _scalar(body['content']).trim(),
      user: _scalar(body['userId']),
      time: _int(body['messageTime']),
      sentAt: null,
      profile: _object(body['profile']),
      extras: _object(body['extras']) ?? const <Object?, Object?>{},
    );
    if (row.text.isEmpty) return null;
    final author = _scalar(row.profile?['nickname']).trim();
    final pinner = _scalar(_object(row.extras['registerProfile'])?['nickname']).trim();
    final pinnedBy = pinner.isEmpty || pinner == author
        ? '$author 置顶了消息：${row.text}'
        : '$pinner 置顶了 $author 的消息：${row.text}';
    return LiveMessage(
      type: LiveMessageType.notice,
      userName: author,
      userId: row.user,
      message: author.isEmpty ? row.text : pinnedBy,
      id: 'notice:${row.user}:${row.time ?? 0}',
      data: 'system',
    );
  }

  /// The retraction of a line blinded after it was shown (`94008`): a
  /// retraction naming the line by user and time — the same id the line
  /// itself carried.
  static LiveMessage? blind(Map<Object?, Object?> body) {
    final user = _scalar(body['userId']);
    final time = _int(body['msgTime']);
    if (user.isEmpty || time == null) return null;
    return LiveMessage(type: LiveMessageType.recall, userName: '', message: '', userId: user, id: '$user:$time');
  }

  static String _scalar(Object? value) => switch (value) {
    final String text => text,
    final num number => '$number',
    final bool flag => '$flag',
    _ => '',
  };

  static int? _int(Object? value) => SiteCounts.integer(value);

  static Map<Object?, Object?>? _object(Object? value) => value is Map ? value.cast<Object?, Object?>() : null;
}

/// The fields one chat line carries, once the recent and pushed spellings
/// have been resolved.
class _Row {
  /// A row.
  const new({
    required this.text,
    required this.user,
    required this.time,
    required this.sentAt,
    required this.profile,
    required this.extras,
  });

  /// The line's text.
  final String text;

  /// The sender's user id.
  final String user;

  /// The line's time, in milliseconds.
  final int? time;

  /// The line's time as a moment.
  final DateTime? sentAt;

  /// The sender's profile (`nickname`, `profileImageUrl`).
  final Map<Object?, Object?>? profile;

  /// The line's extras.
  final Map<Object?, Object?> extras;
}
