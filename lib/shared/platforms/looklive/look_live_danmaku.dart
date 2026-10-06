class LookLiveDanmakuArgs {
  const LookLiveDanmakuArgs({required this.roomId, required this.chatroomId, this.anonymousMode = false});

  final String roomId;
  final String chatroomId;
  final bool anonymousMode;
}
