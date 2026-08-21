/// Bounded low-latency buffer budget for non-seekable live streams.
///
/// A 32 MiB forward budget still covers roughly eight seconds at 32 Mbit/s,
/// while avoiding the long native-memory ramp produced by mpv's file-oriented
/// defaults. The small back budget only protects short decoder/output
/// transitions; live playback never needs a large seek history.
abstract final class LiveBufferPolicy {
  static const int forwardBytes = 32 * 1024 * 1024;
  static const int backBytes = 4 * 1024 * 1024;
  static const int readaheadSeconds = 2;
}
