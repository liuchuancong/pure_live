/// The playlist format the parser recognised.
enum IptvPlaylistFormat {
  /// Extended M3U (`#EXTM3U` first line, or `#EXTINF` stanzas without it).
  m3u,

  /// The plain `name,url` / `group,#genre#` text lists.
  txt,
}

/// Markup that arrived where a playlist was expected.
enum PlaylistMarkup {
  /// A web page: the answer a host gives a dead link with a 200, a login
  /// wall, a repository page copied instead of its raw file.
  html,

  /// An XMLTV programme guide imported as a playlist.
  guide,
}

/// Detects [text]'s format, or null when it is neither.
///
/// A list that lost its `#EXTM3U` line is still an M3U when its stanzas say
/// so: providers cut the header when they concatenate lists, and reading
/// such a list as text found no channels at all.
IptvPlaylistFormat? detectPlaylistFormat(String text) {
  final trimmed = text.trimLeft();
  if (trimmed.isEmpty) {
    return null;
  }
  if (trimmed.startsWith('#EXTM3U') || trimmed.contains('#EXTINF')) {
    return IptvPlaylistFormat.m3u;
  }
  return IptvPlaylistFormat.txt;
}

/// The markup [text] is, or null when it does not open like markup.
///
/// No playlist begins with `<`, so the first character decides; the rest of
/// the opening only tells a guide (worth naming, because the user meant to
/// import it somewhere else) from everything else.
PlaylistMarkup? detectMarkup(String text) {
  final trimmed = text.trimLeft();
  if (!trimmed.startsWith('<')) {
    return null;
  }
  final opening = (trimmed.length > 2048 ? trimmed.substring(0, 2048) : trimmed).toLowerCase();
  if (opening.contains('<tv') && !opening.contains('<html')) {
    return PlaylistMarkup.guide;
  }
  return PlaylistMarkup.html;
}
