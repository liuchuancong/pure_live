/// Where a locally composed danmaku message is rendered.
///
/// Platform messages keep the room-wide danmaku configuration.
enum LiveMessagePlacement {
  /// Normal scrolling danmaku.
  scroll,

  /// Pinned to the top.
  top,

  /// Pinned to the bottom.
  bottom,
}
