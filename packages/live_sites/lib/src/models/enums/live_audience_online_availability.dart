/// Where a platform exposes its concurrent-viewer count, if anywhere.
enum LiveAudienceOnlineAvailability {
  /// The platform has no concurrent count at all.
  unsupported,

  /// Only inside the room (detail response or realtime messages).
  roomRealtime,

  /// Already present in room lists.
  roomList,
}
