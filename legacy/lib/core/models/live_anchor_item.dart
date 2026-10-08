import 'dart:convert';

class LiveAnchorItem {
  final String roomId;

  final String avatar;

  final String userName;

  final bool liveStatus;

  LiveAnchorItem({
    required this.roomId,
    required this.avatar,
    required this.userName,
    required this.liveStatus,
  });

  @override
  String toString() {
    return json.encode({
      "roomId": roomId,
      "avatar": avatar,
      "userName": userName,
      "liveStatus": liveStatus,
    });
  }
}
