abstract class HlsPlaylist {
  HlsPlaylist({required this.baseUri, required this.tags, required this.hasIndependentSegments});

  /// The base uri. Used to resolve relative paths.
  final String? baseUri;

  /// The list of tags in the playlist.
  final List<String> tags;

  /// Whether the media is formed of independent segments, as defined by the #EXT-X-INDEPENDENT-SEGMENTS tag.
  final bool hasIndependentSegments;
}
