import 'package:live_sites/live_sites.dart';

/// Whether [message] is a platform's standalone fan-badge echo rather than
/// something a viewer said.
///
/// Huya and some other platforms push a line whose whole text is the room's
/// fan-badge name plus its level ("玩机器 18"). It is decoration, not chat;
/// the sender's real lines already carry the badge, so the separate echo is
/// dropped from the danmaku feed and the picture overlay.
bool isStandaloneBadgeEcho(LiveMessage message) {
  if (message.type == LiveMessageType.superChat || message.type == LiveMessageType.gift) {
    return false;
  }
  final sender = message.sender;
  final name = sender?.userName.trim() ?? '';
  final badgeName = sender?.fanBadgeName.trim() ?? '';
  final badgeLevel = sender?.fanBadgeLevel.trim() ?? '';
  final text = message.text.trim();
  if (text.isEmpty) return false;
  if (badgeName.isNotEmpty && badgeLevel.isNotEmpty) {
    if (text == '$badgeName $badgeLevel' || text == badgeLevel) return true;
    if (name == badgeName && text == badgeLevel) return true;
  }
  // An anonymous notice that is only a badge label: one short word and a
  // small number. A named sender is never treated this way.
  if (name.isEmpty && badgeName.isEmpty) {
    return RegExp(r'^\S{1,24}\s+\d{1,3}$').hasMatch(text);
  }
  return false;
}
