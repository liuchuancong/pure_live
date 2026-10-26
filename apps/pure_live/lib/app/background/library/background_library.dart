import 'dart:convert' show jsonDecode;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_net/live_net.dart' show ClientProfile, LiveRequest;

import 'package:pure_live/app/background/library/background_library_catalog.dart';
import 'package:pure_live/app/background/library/background_library_models.dart';
import 'package:pure_live/app/providers/providers.dart';

/// The iTab API headers (the requests its own extension sends). The server
/// checks them before answering; without them the JSON is a refusal.
const Map<String, String> _itabHeaders = {
  'user-agent':
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/152.0.0.0 Safari/537.36',
  'fp': 'zhVusd_0lS.1758762915',
  'mode': 'itab',
  'origin': 'chrome-extension://mhloojimgilafopcmlcikiidgbbnelip',
  'version': '2.2.25',
  'accept': 'application/json, text/plain, */*',
  'referer': 'https://www.itab.link/',
};

const String _itabBase = 'https://base.itab.link';

/// The app's reader for the built-in wallpaper library: the iTab picture
/// and video sources, plus the compiled-in deepin set.
final class BackgroundLibraryClient {
  BackgroundLibraryClient(this._ref);

  final Ref _ref;

  /// Reads one page of [source]'s [category]. The deepin set is compiled
  /// in, so it ignores [page] and returns everything once.
  Future<List<WallpaperItem>> fetch({
    required WallpaperSource source,
    required WallpaperCategory? category,
    required int page,
  }) async {
    if (source.isLocal) return deepinWallpaperItems();
    final (path, query) = switch (source.id) {
      WallpaperSourceId.official => (
        '/wallpaper/list',
        <String, String>{'sr': '3840x2160', 'category': category?.query ?? 'nature', 'sortKey': 'updateTime'},
      ),
      WallpaperSourceId.wallhaven => (
        '/wallpaper/wallhaven',
        <String, String>{'sr': '3840x2160', if (category != null && category.query.isNotEmpty) 'q': category.query},
      ),
      WallpaperSourceId.bing => ('/bing/list', const <String, String>{}),
      WallpaperSourceId.video => ('/wallpaper/video/list', const <String, String>{'sortKey': 'updateTime'}),
      WallpaperSourceId.deepin => throw StateError('deepin is local'),
    };
    final uri = Uri.parse('$_itabBase$path')
        .replace(queryParameters: {'lang': 'cn', ...query, 'size': '${source.pageSize}', 'page': '$page'});
    final http = _ref.read(networkFactoryProvider).create(profile: ClientProfile.api);
    final response = await http.send(LiveRequest.get(uri, headers: _itabHeaders, timeout: const Duration(seconds: 20)));
    if (!response.isOk) throw StateError('HTTP ${response.statusCode}');
    final decoded = jsonDecode(response.text);
    if (decoded is! Map) throw const FormatException('The wallpaper library did not answer with an object');
    final code = decoded['code'];
    if (code is num && code != 200 && code != 0) {
      throw StateError('iTab code=$code ${decoded['msg'] ?? ''}');
    }
    final rows = decoded['data'];
    if (rows is! List) return const [];
    final video = source.isVideo;
    return [
      for (final row in rows)
        if (row is Map) ?_itemOf(Map<String, Object?>.from(row), video: video),
    ];
  }

  /// One API row; a row without a playable/paintable address is dropped.
  WallpaperItem? _itemOf(Map<String, Object?> row, {required bool video}) {
    final raw = (video ? row['url'] : (row['raw'] ?? row['url']))?.toString().trim() ?? '';
    if (raw.isEmpty) return null;
    // The API asks its CDN for AVIF by default. The app's image pipeline is
    // not guaranteed to decode AVIF on every desktop backend, so the same
    // rendition is requested as JPEG; the server accepts both.
    final image = video ? raw : _jpeg(raw);
    final thumbRaw = (row['thumb']?.toString().trim() ?? '').isNotEmpty ? row['thumb']!.toString().trim() : image;
    final thumb = _jpeg(thumbRaw);
    final name = (row['name']?.toString().trim() ?? row['copyright']?.toString().trim() ?? _stem(image)).trim();
    return WallpaperItem(
      (b) => b
        ..id = (row['id'] ?? row['_id'])?.toString() ?? raw
        ..name = name.isEmpty ? _stem(image) : name
        ..url = image
        ..thumb = thumb
        ..video = video,
    );
  }

  /// The same CDN object in a format the app decodes everywhere.
  static String _jpeg(String url) => url.replaceAll('format,avif', 'format,jpg');

  static String _stem(String url) {
    final path = url.split('?').first;
    final name = path.split('/').last;
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }
}

/// The library's client.
final backgroundLibraryClientProvider = Provider<BackgroundLibraryClient>(BackgroundLibraryClient.new);
