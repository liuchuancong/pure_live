/// The wire format a playlist entry plays.
enum IptvStreamType {
  /// HLS.
  hls,

  /// HTTP-FLV.
  flv,

  /// Whatever else the URL is (mp4, ts, a plugin scheme).
  other,
}

/// The stream type a URL maps to.
///
/// Judged from the path, because a playlist gives nothing else: the same
/// channel is served as `.m3u8` by one provider and `.flv` by another, and
/// the interface has to say which it is about to play.
IptvStreamType streamTypeOf(String url) {
  final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
  if (path.endsWith('.m3u8')) {
    return IptvStreamType.hls;
  }
  if (path.endsWith('.flv')) {
    return IptvStreamType.flv;
  }
  return IptvStreamType.other;
}
