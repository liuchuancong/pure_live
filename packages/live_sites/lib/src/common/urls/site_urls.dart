/// URL building shared by every adapter.
///
/// The reason this exists rather than using `Uri.https` directly: platform
/// query parameters are frequently *absent* rather than empty, and building
/// the map with nulls in it either throws or sends `gameId=null` (which
/// some sites answer with a 404 instead of a default listing). [https] drops
/// the nulls, so a caller writes one map with every parameter it might need
/// and lets the missing ones vanish.
abstract final class SiteUrls {
  /// `https://[host][path]?[query]`, with null and empty values dropped.
  static Uri https(String host, String path, [Map<String, String?> query = const {}]) =>
      Uri.https(host, path, _compact(query));

  /// Joins [path] onto [base], tolerating a base that already ends in `/`
  /// and a path that starts with one.
  static Uri join(Uri base, String path) {
    final prefix = base.path.endsWith('/') ? base.path.substring(0, base.path.length - 1) : base.path;
    final suffix = path.startsWith('/') ? path : '/$path';
    return base.replace(path: '$prefix$suffix');
  }

  /// The same query with null and empty values removed.
  static Map<String, String> _compact(Map<String, String?> query) {
    final compacted = <String, String>{};
    for (final entry in query.entries) {
      final value = entry.value;
      if (value != null && value.isNotEmpty) {
        compacted[entry.key] = value;
      }
    }
    return compacted;
  }
}
