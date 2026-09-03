import 'package:pure_live/common/models/live_room.dart';

class LiveCategoryResult {
  final bool hasMore;
  final List<LiveRoom> items;
  LiveCategoryResult({required this.hasMore, required this.items});
}
