/// The speaking party's role in a room, as declared by the platform.
enum LiveAnchorRole {
  /// The streamer themselves.
  anchor,

  /// A moderator appointed by the streamer or platform.
  moderator,

  /// An ordinary viewer.
  viewer,

  /// An official platform account.
  platform,

  /// A synthesized system event without a human sender.
  system,
}
