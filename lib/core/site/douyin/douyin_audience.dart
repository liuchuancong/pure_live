/// Returns only fields that Douyin uses for a concurrent room audience.
///
/// `total_user`, `total_user_str` and `room_view_stats.display_value` are the
/// cumulative audience for the current session. They deliberately stay out of
/// this resolver so a large cumulative value is never ranked as people online.
String douyinOnlineViewers(dynamic room) {
  if (room is! Map) return '';
  final viewStats = room['room_view_stats'];
  final roomStats = room['stats'];
  final candidates = <dynamic>[
    if (viewStats is Map) viewStats['user_count'],
    if (viewStats is Map) viewStats['online_user_count'],
    if (viewStats is Map) viewStats['online_user_for_anchor'],
    if (roomStats is Map) roomStats['user_count'],
    if (roomStats is Map) roomStats['online_user_count'],
    if (roomStats is Map) roomStats['online_user_for_anchor'],
  ];
  for (final value in candidates) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty && text != 'null' && RegExp(r'[0-9]').hasMatch(text)) return text;
  }
  return '';
}
