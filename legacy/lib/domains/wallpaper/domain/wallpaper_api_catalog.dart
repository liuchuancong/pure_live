/// The random-image APIs offered next to the wallpaper library.
///
/// These sources are not part of the iTab catalogue: each one answers a *random*
/// picture per request, so there is no list to page through - the preview asks
/// for a picture, shows it, and offers "another one" until the user keeps it.
///
/// The endpoints look alike and behave completely differently, which is why the
/// kind is spelled out per entry. Measured behaviour:
///
/// * `https://v2.xxapi.cn/api/wallpaper` answers
///   `{"code":200,"data":"https://images.xxapi.cn/...jpg"}` - a JSON envelope,
///   not a picture. Saving the response body as an image yields a few hundred
///   bytes of JSON and a broken background.
/// * `https://jkapi.com/api/<name>` answers an **HTML page** unless it is asked
///   for JSON, and then it carries `image_url` or `content`.
/// * `https://t.alcy.cc/` on its own answers an HTML page; only the category
///   path (`https://t.alcy.cc/ycy`) streams a picture.
/// * Everything else (picsum, dmoe, loliapi, mtyqx, ...) redirects straight to
///   an image and needs no decoding at all.
library;

/// How a random-image API hands over its picture.
enum WallpaperApiKind {
  /// The URL itself streams an image, following redirects.
  direct,

  /// The URL answers JSON (or an HTML page unless JSON is requested) carrying
  /// the real image address.
  json,

  /// t.alcy.cc style: the category is a URL path segment.
  alcy,
}

/// Locale key of a random-API family's display name.
String wallpaperApiGroupNameKey(String id) => 'wallpaper_api_group_${wallpaperApiNameSlug(id)}';

/// Locale key of one random-API source's display name.
///
/// Keyed by the entry's own id rather than by its URL: the labels name the
/// provider and the category (`360 Wallpaper · Beauty`), several entries share a
/// host, and the 360 family's query strings carry Chinese values the API itself
/// requires - those are request data and stay in this file.
String wallpaperApiSourceNameKey(String id) => 'wallpaper_api_source_${wallpaperApiNameSlug(id)}';

String wallpaperApiNameSlug(String value) => value.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_').toLowerCase();

/// One random-wallpaper API source.
class WallpaperApiSource {
  const WallpaperApiSource({required this.id, required this.url, this.kind = WallpaperApiKind.direct, this.apiKey});

  /// Stable identity of this row; the readable name lives in the locale bundles.
  final String id;
  final String url;
  final WallpaperApiKind kind;

  /// Some JSON endpoints need a key appended as `type=json&apiKey=<key>`.
  final String? apiKey;

  String get nameKey => wallpaperApiSourceNameKey(id);

  /// Categories accepted as a path segment by the alcy host.
  ///
  /// Only the ones that still resolve are listed: `ai` and `aimp` are published
  /// by the old app but the host answers 404 for both, and a dead entry in the
  /// random pool would only burn a request.
  static const List<String> alcyCategories = <String>[
    'ycy',
    'moez',
    'ysz',
    'ys',
    'mp',
    'moemp',
    'ysmp',
    'tx',
    'lai',
    'xhl',
    'bd',
  ];

  /// The alcy host, shared by the random entry and its per-category entries.
  static const String alcyBase = 'https://t.alcy.cc/';

  String get host => Uri.tryParse(url)?.host ?? url;
}

/// One row of the random-API list: a family of random-image sources.
///
/// A group row opens [sources] on a page of its own, because the flat list
/// reached nearly thirty entries once alcy's categories became individual
/// sources.
class WallpaperApiGroup {
  const WallpaperApiGroup({required this.id, required this.sources});

  final String id;
  final List<WallpaperApiSource> sources;

  String get nameKey => wallpaperApiGroupNameKey(id);
}

/// The groups, in the order the random-API page lists them.
final List<WallpaperApiGroup> kWallpaperApiGroups = <WallpaperApiGroup>[
  WallpaperApiGroup(
    id: 'bing',
    sources: <WallpaperApiSource>[
      const WallpaperApiSource(
        id: 'bing_biturl',
        url: 'https://bing.biturl.top/?resolution=1920x1080&format=image&index=random',
      ),
      const WallpaperApiSource(
        id: 'bing_jason_zeng',
        url: 'https://bingw.jasonzeng.dev/?resolution=1920x1080&index=random',
      ),
      const WallpaperApiSource(
        id: 'bing_uapi',
        url: 'https://uapis.cn/api/v1/image/bing-daily?random=true&resolution=1080',
      ),
      const WallpaperApiSource(id: 'bing_ying_joy', url: 'https://api.1314.cool/bingimg'),
      const WallpaperApiSource(id: 'bing_w3h5', url: 'https://bz.w3h5.com/img/rand_fhd'),
      const WallpaperApiSource(
        id: 'bing_wuming_daily',
        url: 'https://jkapi.com/api/bing_img',
        kind: WallpaperApiKind.json,
        apiKey: '0f57c17bca42966996d6a8bc28594858',
      ),
    ],
  ),
  WallpaperApiGroup(
    id: 'alcy',
    sources: <WallpaperApiSource>[
      const WallpaperApiSource(id: 'alcy_random', url: WallpaperApiSource.alcyBase, kind: WallpaperApiKind.alcy),
      for (final String category in WallpaperApiSource.alcyCategories)
        WallpaperApiSource(id: 'alcy_$category', url: '${WallpaperApiSource.alcyBase}$category'),
    ],
  ),
  WallpaperApiGroup(
    id: 'wuming',
    sources: <WallpaperApiSource>[
      const WallpaperApiSource(
        id: 'wuming_girl',
        url: 'https://jkapi.com/api/meinv_img',
        kind: WallpaperApiKind.json,
        apiKey: '872080c8858c40e6a1eb2ba86694d4d8',
      ),
      const WallpaperApiSource(
        id: 'wuming_black_stocking',
        url: 'https://jkapi.com/api/heisi_img',
        kind: WallpaperApiKind.json,
        apiKey: '0c0c7a39e084db0e9c7cf2e25318f42c',
      ),
      const WallpaperApiSource(
        id: 'wuming_douyin_girl',
        url: 'https://jkapi.com/api/dymm_img',
        kind: WallpaperApiKind.json,
        apiKey: '7b6c5500e52878bc46264cd140196699',
      ),
      const WallpaperApiSource(
        id: 'wuming_white_stocking',
        url: 'https://jkapi.com/api/baisi_img',
        kind: WallpaperApiKind.json,
        apiKey: '7605369407c689e9b2804bfc56a82ac7',
      ),
      const WallpaperApiSource(
        id: 'wuming_douyin_girl_alt',
        url: 'https://jkapi.com/api/dymm_img',
        kind: WallpaperApiKind.json,
        apiKey: '7b6c5500e52878bc46264cd140196699',
      ),
      const WallpaperApiSource(
        id: 'wuming_bcy_cos',
        url: 'https://jkapi.com/api/bcy_cos',
        kind: WallpaperApiKind.json,
        apiKey: 'f5bce3b84b7409fbe8abb2246b46f4c8',
      ),
      const WallpaperApiSource(
        id: 'wuming_anime_wallpaper',
        url: 'https://jkapi.com/api/dm_wallpaper',
        kind: WallpaperApiKind.json,
        apiKey: '95e3a0e608a8b1bed6d513346f929202',
      ),
      const WallpaperApiSource(
        id: 'wuming_aesthetic_girl',
        url: 'https://jkapi.com/api/wm_girl',
        kind: WallpaperApiKind.json,
        apiKey: '0a7c2239bc57624cac60967937da8a1b',
      ),
    ],
  ),
  WallpaperApiGroup(
    id: 'uapi',
    sources: <WallpaperApiSource>[
      const WallpaperApiSource(id: 'uapi_all', url: 'https://uapis.cn/api/v1/random/image'),
      const WallpaperApiSource(id: 'uapi_acg', url: 'https://uapis.cn/api/v1/random/image?category=acg'),
      const WallpaperApiSource(id: 'uapi_acg_pc', url: 'https://uapis.cn/api/v1/random/image?category=acg&type=pc'),
      const WallpaperApiSource(id: 'uapi_acg_mobile', url: 'https://uapis.cn/api/v1/random/image?category=acg&type=mb'),
      const WallpaperApiSource(id: 'uapi_landscape', url: 'https://uapis.cn/api/v1/random/image?category=landscape'),
      const WallpaperApiSource(id: 'uapi_anime', url: 'https://uapis.cn/api/v1/random/image?category=anime'),
      const WallpaperApiSource(
        id: 'uapi_pc_wallpaper',
        url: 'https://uapis.cn/api/v1/random/image?category=pc_wallpaper',
      ),
      const WallpaperApiSource(
        id: 'uapi_mobile_wallpaper',
        url: 'https://uapis.cn/api/v1/random/image?category=mobile_wallpaper',
      ),
      const WallpaperApiSource(
        id: 'uapi_general_anime',
        url: 'https://uapis.cn/api/v1/random/image?category=general_anime',
      ),
      const WallpaperApiSource(id: 'uapi_furry', url: 'https://uapis.cn/api/v1/random/image?category=furry'),
      const WallpaperApiSource(
        id: 'uapi_furry_z4k',
        url: 'https://uapis.cn/api/v1/random/image?category=furry&type=z4k',
      ),
      const WallpaperApiSource(
        id: 'uapi_furry_szs8k',
        url: 'https://uapis.cn/api/v1/random/image?category=furry&type=szs8k',
      ),
      const WallpaperApiSource(
        id: 'uapi_furry_s4k',
        url: 'https://uapis.cn/api/v1/random/image?category=furry&type=s4k',
      ),
      const WallpaperApiSource(id: 'uapi_furry_4k', url: 'https://uapis.cn/api/v1/random/image?category=furry&type=4k'),
    ],
  ),
  WallpaperApiGroup(
    id: '360',
    sources: <WallpaperApiSource>[
      const WallpaperApiSource(
        id: '360_beauty',
        url: 'https://v1.apizero.cn/api/wallpaper?category=美女&resolution=1920x1080&count=1',
        kind: WallpaperApiKind.json,
      ),
      const WallpaperApiSource(
        id: '360_landscape',
        url: 'https://v1.apizero.cn/api/wallpaper?category=风景&resolution=1920x1080&count=1',
        kind: WallpaperApiKind.json,
      ),
      const WallpaperApiSource(
        id: '360_game',
        url: 'https://v1.apizero.cn/api/wallpaper?category=游戏&resolution=1920x1080&count=1',
        kind: WallpaperApiKind.json,
      ),
      const WallpaperApiSource(
        id: '360_movie',
        url: 'https://v1.apizero.cn/api/wallpaper?category=影视&resolution=1920x1080&count=1',
        kind: WallpaperApiKind.json,
      ),
      const WallpaperApiSource(
        id: '360_fashion',
        url: 'https://v1.apizero.cn/api/wallpaper?category=时尚&resolution=1920x1080&count=1',
        kind: WallpaperApiKind.json,
      ),
      const WallpaperApiSource(
        id: '360_star',
        url: 'https://v1.apizero.cn/api/wallpaper?category=明星&resolution=1920x1080&count=1',
        kind: WallpaperApiKind.json,
      ),
      const WallpaperApiSource(
        id: '360_car',
        url: 'https://v1.apizero.cn/api/wallpaper?category=汽车&resolution=1920x1080&count=1',
        kind: WallpaperApiKind.json,
      ),
      const WallpaperApiSource(
        id: '360_pet',
        url: 'https://v1.apizero.cn/api/wallpaper?category=萌宠&resolution=1920x1080&count=1',
        kind: WallpaperApiKind.json,
      ),
      const WallpaperApiSource(
        id: '360_fresh',
        url: 'https://v1.apizero.cn/api/wallpaper?category=清新&resolution=1920x1080&count=1',
        kind: WallpaperApiKind.json,
      ),
      const WallpaperApiSource(
        id: '360_sport',
        url: 'https://v1.apizero.cn/api/wallpaper?category=体育&resolution=1920x1080&count=1',
        kind: WallpaperApiKind.json,
      ),
      const WallpaperApiSource(
        id: '360_child',
        url: 'https://v1.apizero.cn/api/wallpaper?category=萌娃&resolution=1920x1080&count=1',
        kind: WallpaperApiKind.json,
      ),
      const WallpaperApiSource(
        id: '360_military',
        url: 'https://v1.apizero.cn/api/wallpaper?category=军事&resolution=1920x1080&count=1',
        kind: WallpaperApiKind.json,
      ),
      const WallpaperApiSource(
        id: '360_anime',
        url: 'https://v1.apizero.cn/api/wallpaper?category=动漫&resolution=1920x1080&count=1',
        kind: WallpaperApiKind.json,
      ),
      const WallpaperApiSource(
        id: '360_calendar',
        url: 'https://v1.apizero.cn/api/wallpaper?category=日历&resolution=1920x1080&count=1',
        kind: WallpaperApiKind.json,
      ),
      const WallpaperApiSource(
        id: '360_love',
        url: 'https://v1.apizero.cn/api/wallpaper?category=爱情&resolution=1920x1080&count=1',
        kind: WallpaperApiKind.json,
      ),
      const WallpaperApiSource(
        id: '360_motto',
        url: 'https://v1.apizero.cn/api/wallpaper?category=格言&resolution=1920x1080&count=1',
        kind: WallpaperApiKind.json,
      ),
    ],
  ),
  WallpaperApiGroup(
    id: 'misc',
    sources: <WallpaperApiSource>[
      const WallpaperApiSource(id: 'xxapi', url: 'https://v2.xxapi.cn/api/wallpaper', kind: WallpaperApiKind.json),
      const WallpaperApiSource(id: 'mtyqx', url: 'https://api.mtyqx.cn/tapi/random.php'),
      const WallpaperApiSource(id: 'picsum', url: 'https://picsum.photos/1920/1080'),
      const WallpaperApiSource(id: 'dmoe', url: 'https://www.dmoe.cc/random.php'),
      const WallpaperApiSource(id: 'loliapi', url: 'https://www.loliapi.com/bg/'),
      const WallpaperApiSource(id: 'catvod', url: 'https://pictures.catvod.eu.org/'),
    ],
  ),
  WallpaperApiGroup(
    id: 'sexy',
    sources: <WallpaperApiSource>[
      const WallpaperApiSource(
        id: 'sexy_black_stocking_xxapi',
        url: 'https://v2.xxapi.cn/api/heisi',
        kind: WallpaperApiKind.json,
      ),
      const WallpaperApiSource(
        id: 'sexy_white_stocking_xxapi',
        url: 'https://v2.xxapi.cn/api/baisi',
        kind: WallpaperApiKind.json,
      ),
      const WallpaperApiSource(id: 'sexy_jk_xxapi', url: 'https://v2.xxapi.cn/api/jk', kind: WallpaperApiKind.json),
      const WallpaperApiSource(id: 'sexy_girl_suyan', url: 'https://api.suyanw.cn/api/ksxjj.php'),
      const WallpaperApiSource(id: 'sexy_beauty_suyan', url: 'https://api.suyanw.cn/api/meinv.php'),
      const WallpaperApiSource(id: 'sexy_meizi_suyan', url: 'https://api.suyanw.cn/api/meizi.php'),
      const WallpaperApiSource(id: 'sexy_black_stocking_suyan', url: 'https://api.suyanw.cn/api/hs.php'),
      const WallpaperApiSource(
        id: 'sexy_meizi_xiaodu',
        url: 'https://openapi.dwo.cc/api/meinv?type=json',
        kind: WallpaperApiKind.json,
      ),
      const WallpaperApiSource(
        id: 'sexy_stocking_nonebot',
        url: 'https://api.nonebot.top/api/v1/random/wallpaper?type=meizi',
        kind: WallpaperApiKind.json,
      ),
      const WallpaperApiSource(id: 'sexy_pc_ltywl', url: 'https://pic.ltywl.top/mn/pc.php'),
      const WallpaperApiSource(id: 'sexy_pe_ltywl', url: 'https://pic.ltywl.top/mn/pe.php'),
      const WallpaperApiSource(
        id: 'sexy_beauty_apizero',
        url: 'https://v1.apizero.cn/api/wallpaper?category=美女&resolution=1920x1080&count=1',
        kind: WallpaperApiKind.json,
      ),
      const WallpaperApiSource(
        id: 'sexy_pc_nsuuu',
        url: 'https://v1.nsuuu.com/api/pcmeinvpic',
        kind: WallpaperApiKind.json,
      ),
      const WallpaperApiSource(
        id: 'sexy_white_stocking_nsuuu',
        url: 'https://v1.nsuuu.com/api/baisi',
        kind: WallpaperApiKind.json,
      ),
      const WallpaperApiSource(id: 'sexy_beauty_btstu', url: 'http://api.btstu.cn/sjbz/api.php?lx=meizi&format=images'),
      const WallpaperApiSource(
        id: 'sexy_anime_btstu',
        url: 'http://api.btstu.cn/sjbz/api.php?lx=dongman&format=images',
      ),
      const WallpaperApiSource(
        id: 'sexy_girl_kuaishou',
        url: 'http://api.nonebot.top/api/v1/random/wallpaper?type=kuaishou',
        kind: WallpaperApiKind.json,
      ),
      const WallpaperApiSource(
        id: 'sexy_cos_nonebot',
        url: 'http://api.nonebot.top/api/v1/random/wallpaper?type=cos',
        kind: WallpaperApiKind.json,
      ),
      const WallpaperApiSource(id: 'sexy_beauty_czl', url: 'https://random-api.czl.net/pic/ai'),
      const WallpaperApiSource(id: 'sexy_beauty_mioical', url: 'https://api.mioical.moe/img'),
    ],
  ),
];
