/// The http(s) links a pasted text carries, read the way share texts are
/// actually written (the reference's `LinkParser.sharedHttpUrls`).
library;

/// Extracts the http(s) URLs of a share text, mending the damage its prose
/// does to them.
abstract final class LinkText {
  static final RegExp _urls = RegExp(
    r'(?<![a-z0-9_@./:-])(?:[a-z][a-z0-9+.-]*://|www\.|(?:[a-z0-9-]+\.)+[a-z]{2,}(?=[:/?#\s<>]|$))[^\s<>]*',
    caseSensitive: false,
  );

  /// Share texts glue prose to links: everything from the first Chinese
  /// punctuation mark belongs to the sentence, not the link.
  static final RegExp _chineseProse = RegExp('[，。！？、；：）》」』”’]');

  /// Hosts whose share texts end in ASCII punctuation that is part of the
  /// sentence, and whose trailing `/.` or `/..` is route structure rather
  /// than a stray dot.
  static const Set<String> _proseHosts = {
    'xhslink.com',
    'www.xiaohongshu.com',
    'xiaohongshu.com',
    'weibo.com',
    'www.weibo.com',
  };

  /// Every http(s) link in [text], adding HTTPS to bare hosts while keeping
  /// the remaining spelling (signed URLs must not be re-encoded, so these
  /// are the spellings themselves, not re-encoded `Uri`s — Dart would
  /// normalize a `/.` segment away). A link with user info, another scheme,
  /// or undecodable percent escapes is skipped.
  static List<String> httpUrls(String text) {
    final found = <String>[];
    for (final match in _urls.allMatches(text)) {
      var candidate = match.group(0)!;
      if (!candidate.contains('://')) candidate = 'https://$candidate';
      candidate = candidate.split(_chineseProse).first;
      if (_proseHosts.contains(Uri.tryParse(candidate)?.host)) {
        candidate = candidate.replaceFirst(RegExp(r'''[,!?;:)\]}"']+$'''), '');
        // A trailing dot segment is URL structure, not prose punctuation.
        if (!candidate.endsWith('/.') && !candidate.endsWith('/..')) {
          candidate = candidate.replaceFirst(RegExp(r'\.+$'), '');
        }
      } else {
        candidate = candidate.replaceFirst(RegExp(r'''[.,!?;:)\]}。！？、，；：）》」』”’"']+$'''), '');
      }
      final uri = Uri.tryParse(candidate);
      if (uri == null ||
          uri.userInfo.isNotEmpty ||
          uri.host.isEmpty ||
          (uri.scheme != 'http' && uri.scheme != 'https')) {
        continue;
      }
      // Uri.tryParse accepts `/%FF`, but decoding it throws.
      try {
        uri
          ..pathSegments
          ..queryParametersAll;
      } on FormatException {
        continue;
      }
      found.add(candidate);
    }
    return found;
  }

  /// The first http(s) link in [text], or null.
  static String? firstHttpUrl(String text) {
    for (final url in httpUrls(text)) {
      return url;
    }
    return null;
  }
}
