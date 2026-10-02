import 'package:pure_live/domains/wallpaper/data/itab_client.dart';
import 'package:pure_live/domains/wallpaper/data/local_wallpapers.dart';
import 'package:pure_live/domains/wallpaper/domain/wallpaper_catalog.dart';

/// Loads wallpaper entries one page at a time.
///
/// Nothing here reads a git repository: the source tree is the constant
/// [WallpaperCatalog.builtIn] and the pictures come from the iTab API, which
/// answers in a few hundred milliseconds where a mirror chain needs a probe
/// plus one download per category before a single thumbnail can appear.
///
/// The fixed sets - solid colours and deepin - never leave the device;
/// [isLocalSource] tells the caller to read them in one go and slice locally.
class WallpaperRepository {
  WallpaperRepository._();

  static final WallpaperRepository instance = WallpaperRepository._();

  /// Page sizes the iTab endpoints use. `size` is a server-side promise: ask
  /// `/bing/list` for 24 and it still answers with 16.
  static const int officialPageSize = 24;
  static const int bingPageSize = 16;

  WallpaperCatalog loadCatalog() => WallpaperCatalog.builtIn();

  /// True for sources whose entries are compiled in and never fetched.
  bool isLocalSource(String sourceId) =>
      sourceId == WallpaperSourceIds.solidColor || sourceId == WallpaperSourceIds.deepin;

  /// Entries of a local source.
  List<WallpaperItem> localItems(String sourceId) => LocalWallpapers.of(sourceId);

  /// Server page size for a paged source.
  int serverPageSize(String sourceId) => sourceId == WallpaperSourceIds.bing ? bingPageSize : officialPageSize;

  /// One page of a paged source, 1-based.
  Future<List<WallpaperItem>> fetchPage({
    required WallpaperSource source,
    required WallpaperGroup group,
    required int page,
    required int size,
  }) async {
    final String route;
    final Map<String, dynamic> query;
    String? nameKey;
    var uhd = false;
    var video = false;

    if (source.id == WallpaperSourceIds.wallhaven) {
      route = '/wallpaper/wallhaven';
      query = <String, dynamic>{
        'sr': ItabClient.resolution,
        // The "popular" group has no filter at all; every other group is a
        // `q=id:<n>` selector.
        if (group.apiQuery.isNotEmpty) 'q': group.apiQuery,
      };
    } else if (source.id == WallpaperSourceIds.bing) {
      route = '/bing/list';
      query = const <String, dynamic>{};
      nameKey = 'copyright';
      uhd = true;
    } else if (source.id == WallpaperSourceIds.video) {
      // Live wallpapers page from the API too: the rows carry the mp4 url plus
      // its thumbnail and poster renditions, no token required.
      route = '/wallpaper/video/list';
      query = const <String, dynamic>{'sortKey': 'updateTime'};
      video = true;
    } else {
      route = '/wallpaper/list';
      query = <String, dynamic>{'sr': ItabClient.resolution, 'category': group.apiQuery, 'sortKey': 'updateTime'};
    }

    final json = await ItabClient.instance.getJson(route, <String, dynamic>{
      ...query,
      'size': '$size',
      'page': '$page',
    });

    final rows = json['data'];
    if (rows is! List) return const <WallpaperItem>[];

    final items = <WallpaperItem>[];
    for (final row in rows) {
      if (row is! Map) continue;
      final item = _item(Map<String, dynamic>.from(row), nameKey: nameKey, uhd: uhd, video: video);
      if (item != null) items.add(item);
    }
    return items;
  }

  /// One API row → one entry. Rows without a picture are dropped.
  static WallpaperItem? _item(Map<String, dynamic> row, {String? nameKey, bool uhd = false, bool video = false}) {
    var raw = (video ? row['url'] : (row['raw'] ?? row['url']))?.toString() ?? '';
    if (raw.isEmpty) return null;
    if (uhd) raw = _bingUhd(raw);

    final thumb = row['thumb']?.toString() ?? '';
    final poster = row['poster']?.toString() ?? '';
    String name = row['name']?.toString() ?? '';
    if (name.isEmpty && nameKey != null) name = row[nameKey]?.toString() ?? '';
    if (name.isEmpty) name = _stem(raw);

    return WallpaperItem(
      file: raw,
      // Official, Wallhaven and Bing rows carry their own grid copy; the video
      // endpoint ships thumb + poster renditions. Anything else gets a
      // server-side resize of the full picture.
      thumb: thumb.isNotEmpty ? thumb : cdnThumb(raw),
      poster: video && poster.isNotEmpty ? poster : null,
      id: (row['id'] ?? row['_id'])?.toString(),
      name: name,
    );
  }

  /// Bing's daily endpoint hands out the 1920x1080 rendition; the same id with
  /// `_UHD.jpg` is the 4K original - the swap the extension's own
  /// "download 4K wallpaper" button performs.
  static String _bingUhd(String raw) => raw.replaceFirst('1920x1080.jpg&rf=LaDigue_1920x1080.jpg&pid=hp', 'UHD.jpg');

  /// Last path segment without its extension, used as a display fallback.
  static String _stem(String url) {
    final path = url.split('?').first;
    final name = path.split('/').last;
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }
}
