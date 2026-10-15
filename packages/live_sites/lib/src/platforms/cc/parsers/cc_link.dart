/// The room links CC answers to (3.x's `roomIdFromUrl`).
///
/// A room of `cc.163.com/{ccid}`, and the two forms the site now shares: the
/// mobile page `h5.cc.163.com/cc/{ccid}` and the Dashen player
/// `ds.163.com/glive/?ccid={ccid}` (where `cc.163.com/{ccid}/` redirects).
/// Only numeric ids are rooms: 3.x's manual-link rule also took any word
/// (`cc.163.com/n/…` pages became room "n").
abstract final class CcLink {
  /// The hosts whose pages can name a CC room.
  static const Set<String> hosts = {'cc.163.com', 'h5.cc.163.com', 'ds.163.com'};

  /// The ccid [uri] names, or null when it is not a CC room link.
  static String? ccidOf(Uri uri) {
    if (!(uri.isScheme('http') || uri.isScheme('https'))) return null;
    final host = uri.host.toLowerCase();
    final segments = [
      for (final segment in uri.pathSegments)
        if (segment.isNotEmpty) segment,
    ];
    return switch (host) {
      'cc.163.com' when segments.isNotEmpty => _roomNumber(segments.first),
      'h5.cc.163.com' when segments.length >= 2 && segments.first == 'cc' => _roomNumber(segments[1]),
      'ds.163.com' when segments.firstOrNull == 'glive' => _roomNumber(uri.queryParameters['ccid'] ?? ''),
      _ => null,
    };
  }

  /// A positive decimal ccid of at most 16 digits, normalized (3.x parsed the
  /// number), or null.
  static String? _roomNumber(String text) {
    final value = text.trim();
    if (!RegExp(r'^\d{1,16}$').hasMatch(value)) return null;
    final number = int.parse(value);
    return number > 0 ? '$number' : null;
  }
}
