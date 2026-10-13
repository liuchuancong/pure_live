/// The container format of a play line.
enum LiveStreamFormat {
  /// HTTP-FLV long-lived stream (`.flv`; douyu, huya).
  flv,

  /// HLS playlist (`.m3u8`).
  hls,

  /// DASH manifest (`.mpd`; YouTube and some international sites).
  dash,

  /// RTMP live stream, delivered directly by the platform.
  rtmp,

  /// RTSP (camera sources).
  rtsp,

  /// IPTV multicast `udp://@host:port` (after udpxy conversion it is
  /// HTTP + MPEG-TS, see [mpegts]).
  udp,

  /// RTP encapsulated stream.
  rtp,

  /// WebRTC pull (SDP/WHIP/WHEP or a private signaling protocol).
  webrtc,

  /// Bare MPEG-TS over HTTP (IPTV unicast, `.ts`, suffix-less TS streams).
  mpegts,

  /// MP4 file (VOD or replay).
  mp4,

  /// A single HTTP(S) response that is the whole stream; its container is
  /// only told by its first bytes (IPTV MPEG-TS, udpxy, FLV without `.flv`).
  other,
}
