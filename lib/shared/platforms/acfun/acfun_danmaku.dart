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
    this.refresh,
  });

  final String authorId;

  final String liveId;

  final String userId;
  final String deviceId;
  final String visitorToken;

  final String security;

  final List<String> tickets;

  final String enterRoomAttach;

  final Future<AcfunDanmakuArgs> Function()? refresh;
}
