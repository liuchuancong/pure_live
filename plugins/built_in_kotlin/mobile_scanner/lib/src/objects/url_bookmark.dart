/// A URL and title from a `MEBKM:` or similar QRCode type.
class UrlBookmark {
  /// Construct a new [UrlBookmark] instance.
  const UrlBookmark({required this.url, this.title});

  /// Construct a new [UrlBookmark] instance from the given [data].
  factory UrlBookmark.fromNative(Map<Object?, Object?> data) {
    return UrlBookmark(
      title: data['title'] as String?,
      url: data['url'] as String? ?? '',
    );
  }

  /// The title of the bookmark.
  final String? title;

  /// The url of the bookmark.
  final String url;
}
