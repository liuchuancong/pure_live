/// LOOK Live 的弹幕参数（上游 M5.28）：`roomId` 是房间号（用来问聊天服务器），
/// `chatroomId` 是房间详情里的聊天室号（登录用它），`anonymousMode` 时按房间页的做法把
/// 名字打成"首字 + ***"。
class LookLiveDanmakuArgs {
  const LookLiveDanmakuArgs({required this.roomId, required this.chatroomId, this.anonymousMode = false});

  final String roomId;
  final String chatroomId;
  final bool anonymousMode;
}
