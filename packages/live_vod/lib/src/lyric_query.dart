/// The song a video's title names: a lyric lookup needs the two parts apart,
/// and a video title carries them inside decorations.
///
/// The parser is deliberately conservative: it removes the bracket groups and
/// the tags a music uploader adds, then reads the two shapes an uploader
/// writes — "artist - title" and "title《artist》" — and otherwise reports the
/// whole text as the title with the uploader as the artist. A wrong artist
/// costs a failed lookup; a wrong title would cost the wrong song.
final class LyricQuery {
  /// A query with its parts.
  const new({required this.title, required this.artist});

  /// Reads [videoTitle], falling back to [uploader] for the artist.
  factory fromVideoTitle(String videoTitle, {String? uploader}) {
    final cleaned = _stripDecorations(videoTitle);
    // "artist - title" (the uploader's usual order); the hyphen must have
    // spaces, so a hyphenated word stays whole.
    for (final separator in const [' - ', ' – ', ' — ']) {
      final at = cleaned.indexOf(separator);
      if (at > 0 && at < cleaned.length - separator.length) {
        final left = cleaned.substring(0, at).trim();
        final right = cleaned.substring(at + separator.length).trim();
        if (left.isNotEmpty && right.isNotEmpty) {
          return LyricQuery(title: right, artist: left);
        }
      }
    }
    // "title《artist》" — the book-title marks survive the decoration strip.
    final book = RegExp('^(.+?)《(.+?)》').firstMatch(cleaned);
    if (book != null) {
      return LyricQuery(title: book.group(1)!.trim(), artist: book.group(2)!.trim());
    }
    final singer = uploader == null ? '' : _stripDecorations(uploader);
    return LyricQuery(title: cleaned, artist: singer);
  }

  /// The song's name.
  final String title;

  /// The performing artist; empty when neither the title nor the uploader
  /// named one.
  final String artist;

  /// Whether the query is worth sending to a lyric service.
  bool get isUsable => title.trim().isNotEmpty;

  @override
  String toString() => '$title - $artist';

  /// Drops the bracket groups (`【】 [] () （）`) and the bare tags uploaders
  /// sprinkle around them.
  static String _stripDecorations(String text) {
    var cleaned = text;
    for (final pattern in _groups) {
      cleaned = cleaned.replaceAll(pattern, ' ');
    }
    // Tags are removed as whole tokens: a title that contains a tag as part
    // of a word ("纯享版") keeps its word.
    cleaned = cleaned.replaceAll(_spaces, ' ').trim();
    final tokens = cleaned.split(' ').where((token) {
      final lower = token.toLowerCase();
      return !_tags.any((tag) => tag.toLowerCase() == lower);
    });
    return tokens.join(' ').trim();
  }

  static final List<RegExp> _groups = [
    RegExp('【[^】]*】'),
    RegExp(r'\[[^\]]*\]'),
    RegExp(r'\([^)]*\)'),
    RegExp('（[^）]*）'),
  ];

  /// The tags that are never part of a song's name. The list is short on
  /// purpose: a tag that really is part of a title would be lost.
  static const List<String> _tags = [
    '4K',
    '8K',
    '1080P',
    '720P',
    '60FPS',
    'HDR',
    'Hi-Res',
    '无损',
    '高音质',
    'MV',
    'Official',
    'OFFICIAL',
    '官方',
    '完整版',
    '字幕版',
    '中文字幕',
    '动态歌词',
    '无损音质',
    '纯享',
    '高清',
    '修复',
    '重制',
  ];

  static final RegExp _spaces = RegExp(r'\s+');
}
