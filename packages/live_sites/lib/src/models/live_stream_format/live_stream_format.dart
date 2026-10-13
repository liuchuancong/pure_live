/// Container format of a play line.
enum LiveStreamFormat {
  /// HTTP-FLV.
  flv,

  /// HLS playlist.
  hls,

  /// One HTTP(S) response that is the whole stream, its container told by its
  /// first bytes (IPTV MPEG-TS, udpxy, FLV without a `.flv` path).
  other,
}
