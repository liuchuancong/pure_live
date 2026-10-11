/// Image URL normalization shared by every adapter.
///
/// Platforms disagree on whether an image field is a full URL or a bare
/// upload path, and each has its own CDN base for the bare form. Every
/// adapter therefore needs the same three-case rule — full URL passes
/// through, protocol-relative gets `https:`, everything else is joined onto
/// the site's CDN — and this is it, so the rule cannot drift per site.
abstract final class SiteImages {
  /// The URL for [value], or null when there is nothing usable.
  ///
  /// [cdnBase] is the site's upload host (`https://apic.douyucdn.cn/upload`,
  /// say); [suffix] is appended to a bare path, for platforms that ask for a
  /// specific derivative (`_middle.jpg`).
  static String? url(Object? value, {String? cdnBase, String suffix = ''}) {
    final path = value?.toString().trim() ?? '';
    if (path.isEmpty) {
      return null;
    }
    if (path.startsWith('//')) {
      return 'https:$path';
    }
    if (path.startsWith('https://') || path.startsWith('http://')) {
      return path;
    }
    if (cdnBase == null) {
      return path;
    }
    final clean = path.startsWith('/') ? path.substring(1) : path;
    return '$cdnBase/$clean$suffix';
  }

  /// The URL for [value] only when the platform already sends an absolute
  /// one; otherwise the field is treated as unusable rather than guessed at.
  static String? absolute(Object? value) {
    final path = value?.toString().trim() ?? '';
    if (path.startsWith('https://') || path.startsWith('http://')) {
      return path;
    }
    if (path.startsWith('//')) {
      return 'https:$path';
    }
    return null;
  }
}
