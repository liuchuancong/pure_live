/// The video codec a platform declared for a quality or play line.
///
/// `null` on the model means "not declared"; [unknown] means the platform
/// explicitly carries an unrecognized marker and probing remains the fallback.
enum LiveStreamCodec {
  /// H.264 / AVC (platforms mark it `avc` or `h264`).
  avc,

  /// H.265 / HEVC (platforms mark it `hevc` or `h265`).
  hevc,

  /// AV1.
  av1,

  /// VP9.
  vp9,

  /// Declared but not one of the known codecs.
  unknown,
}
