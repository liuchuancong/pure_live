import 'package:pure_live/core/utils/invisible_placeholders.dart';

enum LiveMessageType {
  /// 聊天
  chat,

  /// 礼物,暂时不支持
  gift,

  /// 在线人数
  online,

  /// 醒目留言
  superChat,

  /// 撤回：平台收回已发过的弹幕（上游 bilibili 的 `RECALL`/超话删除）。
  /// 它不是一条要显示的弹幕，而是让显示层把命中的消息撤下去。
  retraction,

  /// 系统公告：平台对房间的提示（如 B 站 `WARNING` 警告、`CUT_OFF` 切断直播）。
  notice,
}

/// 撤回的目标（上游 4.x 的 `LiveRetraction`）：
/// - [userId]：撤回某个观众发过的消息；
/// - [messageId]：撤回某一条消息（如 `SUPER_CHAT_MESSAGE_DELETE` 的 id）；
/// - [all]：撤回全部（平台"清屏"）。
class LiveRetraction {
  const LiveRetraction({this.userId, this.messageId, this.all = false});

  /// 某个观众的消息。
  const LiveRetraction.user(this.userId) : messageId = null, all = false;

  /// 某一条消息。
  const LiveRetraction.message(this.messageId) : userId = null, all = false;

  /// 全部。
  const LiveRetraction.all() : userId = null, messageId = null, all = true;

  final String? userId;
  final String? messageId;
  final bool all;

  /// 这条消息是否被本撤回命中（按用户、按 id 或全清）。
  bool matches({String? user, String? messageId}) {
    if (all) return true;
    final target = userId;
    if (target != null && user != null && user.trim().toLowerCase() == target.trim().toLowerCase()) {
      return true;
    }
    final id = this.messageId;
    return id != null && messageId != null && messageId == id;
  }
}

enum LiveAudienceMetricKind { popularity, onlineViewers, totalViewers }

/// Typed audience updates prevent platform heat, concurrent viewers and
/// cumulative viewers from being silently relabelled as the same number.
class LiveAudienceUpdate {
  const LiveAudienceUpdate({required this.kind, required this.value});

  final LiveAudienceMetricKind kind;
  final int value;
}

/// Optional per-message presentation used by locally composed danmaku.
/// Platform messages keep using the room-wide danmaku configuration.
enum LiveMessagePlacement { scroll, top, bottom }

class LiveMessageStyle {
  const LiveMessageStyle({
    required this.fontSize,
    required this.baseSpeed,
    required this.fontWeight,
    required this.showStroke,
    required this.strokeWidth,
    this.placement = LiveMessagePlacement.scroll,
    this.fontFamily,
    this.italic = false,
    this.opacity = 1,
    this.letterSpacing = 0,
    this.strokeColor = 0xFF000000,
    this.showShadow = false,
    this.shadowColor = 0xFF000000,
    this.shadowBlur = 2,
    this.shadowOffset = 1,
    this.fixedDurationMs = 4000,
  });

  final double fontSize;
  final double baseSpeed;
  final int fontWeight;
  final bool showStroke;
  final double strokeWidth;
  final LiveMessagePlacement placement;
  final String? fontFamily;
  final bool italic;
  final double opacity;
  final double letterSpacing;
  final int strokeColor;
  final bool showShadow;
  final int shadowColor;
  final double shadowBlur;
  final double shadowOffset;
  final int fixedDurationMs;
}

class LiveMessage {
  /// 消息类型
  final LiveMessageType type;

  /// 用户名
  final String userName;
  final String userId;

  /// 信息
  final String message;

  /// 数据
  /// When [type] is [LiveMessageType.online], this is normally a
  /// [LiveAudienceUpdate]. Legacy engines may still send a numeric value.
  final dynamic data;

  /// 弹幕颜色
  final LiveMessageColor color;

  /// 用户等级
  final String userLevel;

  /// 粉丝等级
  final String fansLevel;

  /// 粉丝牌子名
  final String fansName;
  final bool isLocal;

  /// Stable identifier supplied by the platform when available. It is used to
  /// suppress replayed packets after a WebSocket reconnect without treating
  /// two genuine messages with the same text as one message.
  final String messageId;

  /// Original platform timestamp. A missing timestamp means the platform did
  /// not expose one and reception time is used for ordering instead.
  final DateTime? sentAt;
  final LiveMessageStyle? style;

  /// 文本里出现的表情图片（上游 4.x 的 `LiveMessage.emotes`）：平台能给出
  /// "编码 → 图片"时填上，渲染层可以把它画成图而不是一段文字。默认空。
  final List<LiveEmote> emotes;

  LiveMessage({
    required this.type,
    required String userName,
    this.userId = "",
    required String message,
    this.data,
    required this.color,
    this.userLevel = "",
    this.fansLevel = "",
    this.fansName = "",
    this.isLocal = false,
    this.messageId = "",
    this.sentAt,
    this.style,
    this.emotes = const <LiveEmote>[],
  }) : userName = stripInvisiblePlaceholders(userName),
       // 弹幕文本同样清掉不可见占位字符：平台在"原本有图"的位置留下的 U+FFFC
       // 等字符，字体画出来是方块（上游 M13.16 在弹幕运行时统一处理）。
       message = stripInvisiblePlaceholders(message);
}

/// 文本里的一个表情（上游 4.x 的 `LiveEmote`）：[code] 是文本中出现的编码
/// （如 `[笑哭]`、`{:name:}`），[url] 是它的图片地址。
class LiveEmote {
  const LiveEmote({required this.code, required this.url});

  /// 文本里的编码，原样匹配。
  final String code;

  /// 表情图片地址（http/https）。
  final String url;

  /// 从平台给的映射里挑出 [text] 中真正出现的编码。
  static List<LiveEmote> inText(String text, Map<String, String> codes) {
    if (text.isEmpty || codes.isEmpty) return const <LiveEmote>[];
    final found = <LiveEmote>[];
    for (final entry in codes.entries) {
      final code = entry.key;
      final url = entry.value;
      if (code.isEmpty || url.isEmpty) continue;
      if (text.contains(code)) found.add(LiveEmote(code: code, url: url));
    }
    return List.unmodifiable(found);
  }
}

class LiveMessageColor {
  final int r, g, b;
  const LiveMessageColor(this.r, this.g, this.b);
  static LiveMessageColor get white => LiveMessageColor(255, 255, 255);
  static LiveMessageColor numberToColor(int intColor) {
    var obj = intColor.toRadixString(16);

    LiveMessageColor color = LiveMessageColor.white;
    if (obj.length == 4) {
      obj = "00$obj";
    }
    if (obj.length == 6) {
      var R = int.parse(obj.substring(0, 2), radix: 16);
      var G = int.parse(obj.substring(2, 4), radix: 16);
      var B = int.parse(obj.substring(4, 6), radix: 16);

      color = LiveMessageColor(R, G, B);
    }
    if (obj.length == 8) {
      var R = int.parse(obj.substring(2, 4), radix: 16);
      var G = int.parse(obj.substring(4, 6), radix: 16);
      var B = int.parse(obj.substring(6, 8), radix: 16);
      //var A = int.parse(obj.substring(0, 2), radix: 16);
      color = LiveMessageColor(R, G, B);
    }

    return color;
  }

  @override
  String toString() {
    return "#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}";
  }
}

class LiveSuperChatMessage {
  /// Stable platform event identity when the protocol exposes one.
  ///
  /// Some message-board APIs rebuild [startTime] from a countdown on every
  /// poll, so time-based equality would make the same paid message look new.
  /// Keeping the protocol identity here lets transports coalesce snapshots
  /// without suppressing a later, genuinely distinct message with identical
  /// user/text/price fields.
  final String messageId;
  final String userName;
  final String face;
  final String message;
  final int price;
  final DateTime startTime;
  final DateTime endTime;
  final String backgroundColor;
  final String backgroundBottomColor;

  LiveSuperChatMessage({
    this.messageId = '',
    required this.backgroundBottomColor,
    required this.backgroundColor,
    required this.endTime,
    required this.face,
    required this.message,
    required this.price,
    required this.startTime,
    required this.userName,
  });

  @override
  bool operator ==(Object other) {
    if (other is! LiveSuperChatMessage) return false;
    if (messageId.isNotEmpty || other.messageId.isNotEmpty) {
      return messageId.isNotEmpty && other.messageId.isNotEmpty && other.messageId == messageId;
    }
    return other.userName == userName && other.message == message && other.price == price;
  }

  @override
  int get hashCode => messageId.isNotEmpty ? messageId.hashCode : Object.hash(userName, message, price);
}
