import 'dart:math';
import 'dart:typed_data';

import 'package:pure_live/core/network/http_client.dart';
import 'package:pure_live/domains/wallpaper/data/wallpaper_media_store.dart';
import 'package:pure_live/domains/wallpaper/domain/wallpaper_api_catalog.dart';

/// Fetches one random picture from a [WallpaperApiSource].
///
/// Random APIs answer a different picture per request, so the bytes - not the
/// URL - are what can be applied as a background. Returns null when the API
/// answered but carried no usable picture: a JSON envelope or an HTML page
/// passed off as an image is rejected rather than committed as a wallpaper.
///
/// Requests go through the app-wide [HttpClient], so the in-app proxy setting,
/// the shared timeouts and the request log apply here too.
class WallpaperApiClient {
  WallpaperApiClient._();

  static final WallpaperApiClient instance = WallpaperApiClient._();

  /// Desktop UA: several of these APIs reject app-like agents or answer HTML.
  static const Map<String, String> _headers = <String, String>{
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/152.0.0.0 Safari/537.36',
    'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
  };

  final Random _random = Random();

  Future<Uint8List?> fetchRandomImage(WallpaperApiSource source) async {
    final String? imageUrl = switch (source.kind) {
      WallpaperApiKind.direct => source.url,
      WallpaperApiKind.alcy =>
        '${source.url}${WallpaperApiSource.alcyCategories[_random.nextInt(WallpaperApiSource.alcyCategories.length)]}',
      WallpaperApiKind.json => await _resolveJsonUrl(source),
    };
    if (imageUrl == null || imageUrl.isEmpty) return null;
    return _downloadImage(imageUrl);
  }

  /// Asks a JSON endpoint where the picture is.
  Future<String?> _resolveJsonUrl(WallpaperApiSource source) async {
    final String? apiKey = source.apiKey;
    final String query = apiKey == null ? '' : '${source.url.contains('?') ? '&' : '?'}type=json&apiKey=$apiKey';

    final dynamic data = await HttpClient.instance.getJson('${source.url}$query', header: _headers);
    return _pickUrl(data);
  }

  /// Finds the image address in whichever shape the endpoint uses.
  ///
  /// Known shapes:
  /// * `{"image_url": "..."}` / `{"content": "..."}`   (jkapi)
  /// * `{"code":200,"data":"..."}`                    (xxapi)
  /// * `{"data":{"url":"..."}}`                       (defensive)
  static String? _pickUrl(dynamic data) {
    if (data is String) {
      final String value = _unescape(data.trim());
      return value.startsWith('http') ? value : null;
    }
    if (data is Map) {
      for (final String key in const <String>[
        'image_url',
        'imageUrl',
        'content',
        'url',
        'img',
        'imgurl',
        'data',
        'image',
        'images',
      ]) {
        final String? found = _pickUrl(data[key]);
        if (found != null) return found;
      }
      return null;
    }
    if (data is List && data.isNotEmpty) return _pickUrl(data.first);
    return null;
  }

  /// JSON bodies come back with HTML-escaped query separators (`&amp;`), which
  /// would otherwise be sent verbatim to the image host.
  static String _unescape(String url) => url.replaceAll('&amp;', '&');

  Future<Uint8List?> _downloadImage(String url) async {
    final Uint8List bytes = await HttpClient.instance.getBytes(url, header: _headers);
    if (bytes.length < 256) return null;
    // A JSON envelope or an HTML error page is not a wallpaper. Checking the
    // magic number is what keeps "the API answered" from meaning "the background
    // is now a page of text".
    return WallpaperMediaStore.imageFormatOf(bytes) == null ? null : bytes;
  }
}
