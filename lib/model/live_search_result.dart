import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/model/live_anchor_item.dart';

class LiveSearchRoomResult {
  final bool hasMore;
  final List<LiveRoom> items;
  LiveSearchRoomResult({required this.hasMore, required this.items});
}

class LiveSearchAnchorResult {
  final bool hasMore;
  final List<LiveAnchorItem> items;
  LiveSearchAnchorResult({required this.hasMore, required this.items});
}
