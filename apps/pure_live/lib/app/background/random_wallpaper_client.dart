import 'dart:convert' show jsonDecode;
import 'dart:math' show Random;
import 'dart:typed_data' show Uint8List;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_net/live_net.dart' show ClientProfile, LiveRequest, LiveResponse;

import 'package:pure_live/app/background/random_wallpaper_catalog.dart';
import 'package:pure_live/app/providers/network_providers.dart' show networkFactoryProvider;

/// One picture fetched from a random source: the bytes, and the format the
/// bytes themselves declare.
final class RandomWallpaperPicture {
  /// Creates a picture.
  const RandomWallpaperPicture({required this.bytes, required this.format});

  /// The encoded picture.
  final Uint8List bytes;

  /// `jpg`, `png`, `webp`, `gif` or `bmp`; the file suffix and decoder format.
  final String format;
}

/// Why a random source did not produce a picture.
enum RandomWallpaperFailureKind {
  /// The request failed, or answered a non-2xx status.
  network,

  /// The endpoint answered, but carried no picture address or too few bytes.
  empty,

  /// The bytes are not a format the app can decode (an HTML/JSON envelope,
  /// or AVIF/HEIC which the desktop image pipeline does not guarantee).
  unsupported,
}

/// A failed random-picture fetch, carrying enough detail for the dialog.
final class RandomWallpaperFailure implements Exception {
  /// Creates a failure.
  const RandomWallpaperFailure(this.kind, [this.detail = '']);

  /// What went wrong.
  final RandomWallpaperFailureKind kind;

  /// HTTP status, exception text, or the sniffed-but-unusable format.
  final String detail;

  @override
  String toString() => detail.isEmpty ? kind.name : '${kind.name}: $detail';
}

/// Fetches one random picture.
///
/// Random APIs answer a different picture per request, so the bytes — not a
/// stable URL — are the result. Most endpoints redirect to the picture;
/// some answer JSON carrying its address, and jkapi's JSON endpoints need an
/// explicit `type=json`. Requests go through the app's network factory, so
/// the proxy and its timeouts apply here too.
final class RandomWallpaperClient {
  /// Creates a client reading the app's network factory.
  RandomWallpaperClient(this._ref);

  final Ref _ref;
  final Random _random = Random();

  /// A desktop UA: several endpoints reject app-like agents or answer HTML.
  static const Map<String, String> _headers = {
    'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/152.0.0.0 Safari/537.36',
    // AVIF is deliberately not advertised: the desktop image pipeline does
    // not decode it everywhere, and an AVIF answer is rejected below.
    'accept': 'image/jpeg,image/png,image/webp,image/gif,image/bmp,image/*;q=0.8,*/*;q=0.5',
  };

  /// A ceiling for a wallpaper; larger answers are treated as an error rather
  /// than held in memory.
  static const int _maxBytes = 40 * 1024 * 1024;

  /// Fetches one picture from [source].
  ///
  /// Throws [RandomWallpaperFailure] when the source answers without a
  /// usable picture; a JSON envelope or HTML error page is rejected by its
  /// magic number rather than saved as a wallpaper.
  Future<RandomWallpaperPicture> fetch(RandomWallpaperSource source) async {
    final address = switch (source.kind) {
      RandomWallpaperKind.direct => source.url,
      RandomWallpaperKind.alcy => '${source.url}${randomAlcyCategories[_random.nextInt(randomAlcyCategories.length)]}',
      RandomWallpaperKind.json => await _resolve(source),
    };
    if (address == null || address.isEmpty) {
      throw const RandomWallpaperFailure(RandomWallpaperFailureKind.empty, 'no image address');
    }
    final response = await _send(Uri.parse(address));
    if (!response.isOk) {
      throw RandomWallpaperFailure(RandomWallpaperFailureKind.network, 'HTTP ${response.statusCode}');
    }
    final bytes = response.bodyBytes;
    if (bytes.length < 256) {
      throw const RandomWallpaperFailure(RandomWallpaperFailureKind.empty, 'answer too small');
    }
    if (bytes.length > _maxBytes) {
      throw const RandomWallpaperFailure(RandomWallpaperFailureKind.unsupported, 'answer too large');
    }
    final format = _formatOf(bytes);
    if (format == null) {
      throw const RandomWallpaperFailure(RandomWallpaperFailureKind.unsupported, 'not a decodable picture');
    }
    return RandomWallpaperPicture(bytes: bytes, format: format);
  }

  /// Asks a JSON endpoint where the picture is.
  Future<String?> _resolve(RandomWallpaperSource source) async {
    final apiKey = source.apiKey;
    final suffix = apiKey == null ? '' : '${source.url.contains('?') ? '&' : '?'}type=json&apiKey=$apiKey';
    final response = await _send(Uri.parse('${source.url}$suffix'));
    if (!response.isOk) {
      throw RandomWallpaperFailure(RandomWallpaperFailureKind.network, 'HTTP ${response.statusCode}');
    }
    Object? decoded;
    try {
      decoded = jsonDecode(response.text);
    } on Object {
      // An HTML page is not an address.
      throw const RandomWallpaperFailure(RandomWallpaperFailureKind.empty, 'answer is not JSON');
    }
    return _pickUrl(decoded);
  }

  /// Finds the image address in whichever shape the endpoint uses.
  ///
  /// Known shapes: `{"image_url": "..."}` / `{"content": "..."}` (jkapi),
  /// `{"code":200,"data":"..."}` (xxapi), `{"data":{"url":"..."}}`.
  static String? _pickUrl(Object? data) {
    if (data is String) {
      final value = _unescape(data.trim());
      return value.startsWith('http') ? value : null;
    }
    if (data is Map) {
      for (final key in const ['image_url', 'imageUrl', 'content', 'url', 'img', 'imgurl', 'data', 'image', 'images']) {
        final found = _pickUrl(data[key]);
        if (found != null) return found;
      }
      return null;
    }
    if (data is List && data.isNotEmpty) return _pickUrl(data.first);
    return null;
  }

  /// JSON bodies sometimes escape query separators as `&amp;`.
  static String _unescape(String url) => url.replaceAll('&amp;', '&');

  Future<LiveResponse> _send(Uri uri) async {
    try {
      final http = _ref.read(networkFactoryProvider).create(profile: ClientProfile.api);
      return await http.send(
        LiveRequest.custom(
          method: 'GET',
          url: uri,
          headers: _headers,
          timeout: const Duration(seconds: 25),
          // A random endpoint answers a new picture per request; the shared
          // response cache would otherwise hand "another one" the same bytes.
          cache: false,
        ),
      );
    } on Object catch (error) {
      throw RandomWallpaperFailure(RandomWallpaperFailureKind.network, '$error');
    }
  }

  /// The picture's real format by magic number, or null when the bytes are
  /// not a format the app decodes. AVIF/HEIC are recognized but rejected:
  /// the format list here is what the background image pipeline can paint.
  static String? _formatOf(Uint8List bytes) {
    if (bytes.length < 12) return null;
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return 'jpg';
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return 'png';
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) return 'gif';
    if (bytes[0] == 0x42 && bytes[1] == 0x4D) return 'bmp';
    if (bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'webp';
    }
    return null;
  }
}

/// The random-picture client.
final randomWallpaperClientProvider = Provider<RandomWallpaperClient>(RandomWallpaperClient.new);
