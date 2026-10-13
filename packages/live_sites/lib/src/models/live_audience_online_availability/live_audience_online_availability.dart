/// Where a platform exposes its concurrent-viewer count.
enum LiveAudienceOnlineAvailability {
  /// Nowhere.
  unsupported,

  /// Only in the room (detail or realtime messages).
  roomRealtime,

  /// Already in room lists.
  roomList,
}
