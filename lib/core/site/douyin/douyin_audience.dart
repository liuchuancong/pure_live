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
    // The current anonymous homepage feed exposes the concurrent count on
    // the room itself. Keep these candidates ahead of nested compatibility
    // fields so a stale nested placeholder cannot mask the live value.
    room['user_count'],
    room['user_count_str'],
    room['online_user_count'],
    room['online_user_for_anchor'],
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

/// Returns only Douyin's cumulative audience fields.
///
/// A zero `total_user` in the anonymous feed is an unavailable placeholder
/// when `user_count` is already positive. Ignore that placeholder so the card
/// can use its explicit concurrent count instead of showing a false zero.
String douyinTotalViewers(dynamic room) {
  if (room is! Map) return '';
  final viewStats = room['room_view_stats'];
  final roomStats = room['stats'];
  final candidates = <dynamic>[
    if (viewStats is Map) viewStats['display_value'],
    if (viewStats is Map) viewStats['total_user_str'],
    if (viewStats is Map) viewStats['total_user'],
    if (roomStats is Map) roomStats['total_user_str'],
    if (roomStats is Map) roomStats['total_user'],
    room['total_user_str'],
    room['total_user'],
  ];
  for (final value in candidates) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text == 'null' || !RegExp(r'[0-9]').hasMatch(text)) continue;
    final normalized = text.replaceAll(',', '').replaceAll('，', '');
    final number =
        double.tryParse(RegExp(r'[0-9]+(?:\.[0-9]+)?').firstMatch(normalized)?.group(0) ?? '') ?? 0;
    if (number > 0) return text;
  }
  return '';
}
