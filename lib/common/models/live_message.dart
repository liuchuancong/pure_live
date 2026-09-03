enum LiveMessageType {
  /// 聊天
  chat,

  /// 礼物,暂时不支持
  gift,

  /// 在线人数
  online,

  /// 醒目留言
  superChat,
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

  LiveMessage({
    required this.type,
    required this.userName,
    this.userId = '',
    required this.message,
    this.data,
    required this.color,
    this.userLevel = '',
    this.fansLevel = '',
    this.fansName = '',
    this.isLocal = false,
    this.messageId = '',
    this.sentAt,
    this.style,
  });
}

class LiveMessageColor {
  final int r, g, b;
  const LiveMessageColor(this.r, this.g, this.b);
  static LiveMessageColor get white => const LiveMessageColor(255, 255, 255);
  static LiveMessageColor numberToColor(int intColor) {
    var obj = intColor.toRadixString(16);

    LiveMessageColor color = LiveMessageColor.white;
    if (obj.length == 4) {
      obj = '00$obj';
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
  int get hashCode =>
      messageId.isNotEmpty ? messageId.hashCode : Object.hash(userName, message, price);
}
