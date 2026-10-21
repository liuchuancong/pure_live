/// Whether a started room raises a notice, given the tags 开播提醒 covers.
///
/// Empty [coveredTagIds] covers every follow — the shipping answer — and a
/// room whose record carries none of the chosen tags stays quiet. The
/// reference gates the same way per tag (`LiveAlertTagsTile`).
bool alertCoversRoom(List<String> coveredTagIds, List<String> roomGroupIds) {
  if (coveredTagIds.isEmpty) {
    return true;
  }
  for (final id in roomGroupIds) {
    if (coveredTagIds.contains(id)) {
      return true;
    }
  }
  return false;
}
