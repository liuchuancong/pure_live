/// The playlist format the parser recognised.
enum IptvPlaylistFormat {
  /// Extended M3U (`#EXTM3U` first line).
  m3u,

  /// The plain `name,url` / `group,#genre#` text lists.
  txt,
}

/// Detects [text]'s format, or null when it is neither.
IptvPlaylistFormat? detectPlaylistFormat(String text) {
  final trimmed = text.trimLeft();
  if (trimmed.startsWith('#EXTM3U')) {
    return IptvPlaylistFormat.m3u;
  }
  if (trimmed.isEmpty) {
    return null;
  }
  return IptvPlaylistFormat.txt;
}
