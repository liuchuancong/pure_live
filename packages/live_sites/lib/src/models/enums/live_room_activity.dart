/// The activity format a room's current broadcast takes.
///
/// Orthogonal to `LiveStatus`: a room can be live and in a PK at once, and a
/// carousel room reports `carousel` on both sides (MODELS.md §2.15).
enum LiveRoomActivity {
  /// An ordinary single-stream broadcast.
  none,

  /// A streamer-vs-streamer PK battle.
  pk,

  /// Co-streaming: several streamers share one room.
  coStream,

  /// Radio: audio only.
  radio,

  /// Carousel filler (the streamer is off).
  carousel,
}
