/// AcFun 的弹幕参数（上游 M5.9 / M4.10）：进房时就拿到的访客会话与票据，连接本身
/// **不发任何 HTTP 请求**；只有会话缺 `acSecurity` 或没有票据时才需要先刷新一次。
class AcfunDanmakuArgs {
  const AcfunDanmakuArgs({
    required this.authorId,
    required this.liveId,
    required this.userId,
    required this.deviceId,
    required this.visitorToken,
    required this.security,
    required this.tickets,
    this.enterRoomAttach = '',
  });

  /// 房间（主播 id）。
  final String authorId;

  /// 这一场直播（`liveId`）。
  final String liveId;

  /// 访客会话：`userId`、设备号、`acfun.api.visitor_st` 令牌。
  final String userId;
  final String deviceId;
  final String visitorToken;

  /// `acSecurity`：注册交换用的 Base64 AES-128 密钥；空串时弹幕连不上（只影响弹幕）。
  final String security;

  /// `availableTickets`，按顺序尝试。
  final List<String> tickets;

  /// 进房时原样回带的 `enterRoomAttach`。
  final String enterRoomAttach;
}
