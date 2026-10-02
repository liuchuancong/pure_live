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

/// One random-wallpaper API source.
///
/// Names are brand labels and stay untranslated on purpose.
class WallpaperApiSource {
  const WallpaperApiSource({required this.name, required this.url, this.kind = WallpaperApiKind.direct, this.apiKey});

  final String name;
  final String url;
  final WallpaperApiKind kind;

  /// Some JSON endpoints need a key appended as `type=json&apiKey=<key>`.
  final String? apiKey;

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
  const WallpaperApiGroup({required this.id, required this.name, required this.nameEn, required this.sources});

  final String id;
  final String name;
  final String nameEn;
  final List<WallpaperApiSource> sources;

  /// Display name for [languageCode], falling back to whichever is present.
  String localizedName(String languageCode) {
    if (languageCode == 'zh') return name.isNotEmpty ? name : nameEn;
    return nameEn.isNotEmpty ? nameEn : name;
  }
}

/// The groups, in the order the random-API page lists them.
final List<WallpaperApiGroup> kWallpaperApiGroups = <WallpaperApiGroup>[
  WallpaperApiGroup(
    id: 'bing',
    name: '必应壁纸',
    nameEn: 'Bing',
    sources: <WallpaperApiSource>[
      const WallpaperApiSource(
        name: '必应随机Biturl',
        url: 'https://bing.biturl.top/?resolution=1920x1080&format=image&index=random',
      ),
      const WallpaperApiSource(
        name: '必应随机Jason Zeng',
        url: 'https://bingw.jasonzeng.dev/?resolution=1920x1080&index=random',
      ),
      const WallpaperApiSource(
        name: '必应随机UAPI',
        url: 'https://uapis.cn/api/v1/image/bing-daily?random=true&resolution=1080',
      ),
      const WallpaperApiSource(name: '必应随机YingJoy', url: 'https://api.1314.cool/bingimg'),
      const WallpaperApiSource(name: '必应W3H5', url: 'https://bz.w3h5.com/img/rand_fhd'),
      const WallpaperApiSource(
        name: '无铭必应每日壁纸',
        url: 'https://jkapi.com/api/bing_img',
        kind: WallpaperApiKind.json,
        apiKey: '0f57c17bca42966996d6a8bc28594858',
      ),
    ],
  ),
  WallpaperApiGroup(
    id: 'alcy',
    name: '栗次元',
    nameEn: 'Alcy',
    sources: <WallpaperApiSource>[
      const WallpaperApiSource(name: '栗次元 · 随机', url: WallpaperApiSource.alcyBase, kind: WallpaperApiKind.alcy),
      for (final String category in WallpaperApiSource.alcyCategories)
        WallpaperApiSource(name: '栗次元 · $category', url: '${WallpaperApiSource.alcyBase}$category'),
    ],
  ),
  WallpaperApiGroup(
    id: 'wuming',
    name: '无铭 API',
    nameEn: 'Wuming API',
    sources: <WallpaperApiSource>[
      const WallpaperApiSource(
        name: '无铭随机美囡图片',
        url: 'https://jkapi.com/api/meinv_img',
        kind: WallpaperApiKind.json,
        apiKey: '872080c8858c40e6a1eb2ba86694d4d8',
      ),
      const WallpaperApiSource(
        name: '无铭随机黑丝图片',
        url: 'https://jkapi.com/api/heisi_img',
        kind: WallpaperApiKind.json,
        apiKey: '0c0c7a39e084db0e9c7cf2e25318f42c',
      ),
      const WallpaperApiSource(
        name: '抖音美女·无铭API',
        url: 'https://jkapi.com/api/dymm_img',
        kind: WallpaperApiKind.json,
        apiKey: '7b6c5500e52878bc46264cd140196699',
      ),
      const WallpaperApiSource(
        name: '无铭随机白丝图片',
        url: 'https://jkapi.com/api/baisi_img',
        kind: WallpaperApiKind.json,
        apiKey: '7605369407c689e9b2804bfc56a82ac7',
      ),
      const WallpaperApiSource(
        name: '无铭随机抖音美女图片',
        url: 'https://jkapi.com/api/dymm_img',
        kind: WallpaperApiKind.json,
        apiKey: '7b6c5500e52878bc46264cd140196699',
      ),
      const WallpaperApiSource(
        name: '无铭半次元cosplay',
        url: 'https://jkapi.com/api/bcy_cos',
        kind: WallpaperApiKind.json,
        apiKey: 'f5bce3b84b7409fbe8abb2246b46f4c8',
      ),
      const WallpaperApiSource(
        name: '无铭动漫壁纸',
        url: 'https://jkapi.com/api/dm_wallpaper',
        kind: WallpaperApiKind.json,
        apiKey: '95e3a0e608a8b1bed6d513346f929202',
      ),
      const WallpaperApiSource(
        name: '无铭随机唯美女生图片',
        url: 'https://jkapi.com/api/wm_girl',
        kind: WallpaperApiKind.json,
        apiKey: '0a7c2239bc57624cac60967937da8a1b',
      ),
    ],
  ),
  WallpaperApiGroup(
    id: 'uapi',
    name: 'UAPI 随机图',
    nameEn: 'UAPI',
    sources: <WallpaperApiSource>[
      const WallpaperApiSource(name: 'UAPI全部随机', url: 'https://uapis.cn/api/v1/random/image'),
      const WallpaperApiSource(name: 'UAPI二次元动漫', url: 'https://uapis.cn/api/v1/random/image?category=acg'),
      const WallpaperApiSource(name: 'UAPI二次元·电脑', url: 'https://uapis.cn/api/v1/random/image?category=acg&type=pc'),
      const WallpaperApiSource(name: 'UAPI二次元·手机', url: 'https://uapis.cn/api/v1/random/image?category=acg&type=mb'),
      const WallpaperApiSource(name: 'UAPI风景图', url: 'https://uapis.cn/api/v1/random/image?category=landscape'),
      const WallpaperApiSource(name: 'UAPI混合动漫', url: 'https://uapis.cn/api/v1/random/image?category=anime'),
      const WallpaperApiSource(name: 'UAPI电脑壁纸', url: 'https://uapis.cn/api/v1/random/image?category=pc_wallpaper'),
      const WallpaperApiSource(name: 'UAPI手机壁纸', url: 'https://uapis.cn/api/v1/random/image?category=mobile_wallpaper'),
      const WallpaperApiSource(name: 'UAPI动漫图', url: 'https://uapis.cn/api/v1/random/image?category=general_anime'),
      const WallpaperApiSource(name: 'UAPI福瑞', url: 'https://uapis.cn/api/v1/random/image?category=furry'),
      const WallpaperApiSource(name: 'UAPI福瑞·z4k', url: 'https://uapis.cn/api/v1/random/image?category=furry&type=z4k'),
      const WallpaperApiSource(
        name: 'UAPI福瑞·szs8k',
        url: 'https://uapis.cn/api/v1/random/image?category=furry&type=szs8k',
      ),
      const WallpaperApiSource(name: 'UAPI福瑞·s4k', url: 'https://uapis.cn/api/v1/random/image?category=furry&type=s4k'),
      const WallpaperApiSource(name: 'UAPI福瑞·4k', url: 'https://uapis.cn/api/v1/random/image?category=furry&type=4k'),
    ],
  ),
  WallpaperApiGroup(
    id: '360',
    name: '360壁纸',
    nameEn: '360 Wallpaper',
    sources: <WallpaperApiSource>[
      const WallpaperApiSource(
        name: '360壁纸美女',
        url: 'https://v1.apizero.cn/api/wallpaper?category=美女&resolution=1920x1080&count=1',
        kind: WallpaperApiKind.json,
      ),
      const WallpaperApiSource(
        name: '360壁纸风景',
        url: 'https://v1.apizero.cn/api/wallpaper?category=风景&resolution=1920x1080&count=1',
        kind: WallpaperApiKind.json,
      ),
      const WallpaperApiSource(
        name: '360壁纸游戏',
        url: 'https://v1.apizero.cn/api/wallpaper?category=游戏&resolution=1920x1080&count=1',
        kind: WallpaperApiKind.json,
      ),
      const WallpaperApiSource(
        name: '360壁纸影视',
        url: 'https://v1.apizero.cn/api/wallpaper?category=影视&resolution=1920x1080&count=1',
        kind: WallpaperApiKind.json,
      ),
      const WallpaperApiSource(
        name: '360壁纸时尚',
        url: 'https://v1.apizero.cn/api/wallpaper?category=时尚&resolution=1920x1080&count=1',
        kind: WallpaperApiKind.json,
      ),
      const WallpaperApiSource(
        name: '360壁纸明星',
        url: 'https://v1.apizero.cn/api/wallpaper?category=明星&resolution=1920x1080&count=1',
        kind: WallpaperApiKind.json,
      ),
      const WallpaperApiSource(
        name: '360壁纸汽车',
        url: 'https://v1.apizero.cn/api/wallpaper?category=汽车&resolution=1920x1080&count=1',
        kind: WallpaperApiKind.json,
      ),
      const WallpaperApiSource(
        name: '360壁纸萌宠',
        url: 'https://v1.apizero.cn/api/wallpaper?category=萌宠&resolution=1920x1080&count=1',
        kind: WallpaperApiKind.json,
      ),
      const WallpaperApiSource(
        name: '360壁纸清新',
        url: 'https://v1.apizero.cn/api/wallpaper?category=清新&resolution=1920x1080&count=1',
        kind: WallpaperApiKind.json,
      ),
      const WallpaperApiSource(
        name: '360壁纸体育',
        url: 'https://v1.apizero.cn/api/wallpaper?category=体育&resolution=1920x1080&count=1',
        kind: WallpaperApiKind.json,
      ),
      const WallpaperApiSource(
        name: '360壁纸萌娃',
        url: 'https://v1.apizero.cn/api/wallpaper?category=萌娃&resolution=1920x1080&count=1',
        kind: WallpaperApiKind.json,
      ),
      const WallpaperApiSource(
        name: '360壁纸军事',
        url: 'https://v1.apizero.cn/api/wallpaper?category=军事&resolution=1920x1080&count=1',
        kind: WallpaperApiKind.json,
      ),
      const WallpaperApiSource(
        name: '360壁纸动漫',
        url: 'https://v1.apizero.cn/api/wallpaper?category=动漫&resolution=1920x1080&count=1',
        kind: WallpaperApiKind.json,
      ),
      const WallpaperApiSource(
        name: '360壁纸日历',
        url: 'https://v1.apizero.cn/api/wallpaper?category=日历&resolution=1920x1080&count=1',
        kind: WallpaperApiKind.json,
      ),
      const WallpaperApiSource(
        name: '360壁纸爱情',
        url: 'https://v1.apizero.cn/api/wallpaper?category=爱情&resolution=1920x1080&count=1',
        kind: WallpaperApiKind.json,
      ),
      const WallpaperApiSource(
        name: '360壁纸格言',
        url: 'https://v1.apizero.cn/api/wallpaper?category=格言&resolution=1920x1080&count=1',
        kind: WallpaperApiKind.json,
      ),
    ],
  ),
  WallpaperApiGroup(
    id: 'misc',
    name: '其他图源',
    nameEn: 'Other sources',
    sources: <WallpaperApiSource>[
      const WallpaperApiSource(name: '小晓API', url: 'https://v2.xxapi.cn/api/wallpaper', kind: WallpaperApiKind.json),
      const WallpaperApiSource(name: 'mtyqx', url: 'https://api.mtyqx.cn/tapi/random.php'),
      const WallpaperApiSource(name: 'picsum', url: 'https://picsum.photos/1920/1080'),
      const WallpaperApiSource(name: 'dmoe', url: 'https://www.dmoe.cc/random.php'),
      const WallpaperApiSource(name: 'loliApi', url: 'https://www.loliapi.com/bg/'),
      const WallpaperApiSource(name: 'catvod', url: 'https://pictures.catvod.eu.org/'),
    ],
  ),
  WallpaperApiGroup(
    id: 'sexy',
    name: '性感美女',
    nameEn: 'Sexy',
    sources: <WallpaperApiSource>[
      const WallpaperApiSource(name: '随机黑丝·小小API', url: 'https://v2.xxapi.cn/api/heisi', kind: WallpaperApiKind.json),
      const WallpaperApiSource(name: '随机白丝·小小API', url: 'https://v2.xxapi.cn/api/baisi', kind: WallpaperApiKind.json),
      const WallpaperApiSource(name: '随机JK·小小API', url: 'https://v2.xxapi.cn/api/jk', kind: WallpaperApiKind.json),
      const WallpaperApiSource(name: '随机小姐姐·素颜API', url: 'https://api.suyanw.cn/api/ksxjj.php'),
      const WallpaperApiSource(name: '随机美女·素颜API', url: 'https://api.suyanw.cn/api/meinv.php'),
      const WallpaperApiSource(name: '随机妹子·素颜API', url: 'https://api.suyanw.cn/api/meizi.php'),
      const WallpaperApiSource(name: '随机黑丝·素颜API', url: 'https://api.suyanw.cn/api/hs.php'),
      const WallpaperApiSource(
        name: '随机妹子·小渡API',
        url: 'https://openapi.dwo.cc/api/meinv?type=json',
        kind: WallpaperApiKind.json,
      ),
      const WallpaperApiSource(
        name: '随机丝袜·Nonebot',
        url: 'https://api.nonebot.top/api/v1/random/wallpaper?type=meizi',
        kind: WallpaperApiKind.json,
      ),
      const WallpaperApiSource(name: 'PC美女壁纸·Ltywl', url: 'https://pic.ltywl.top/mn/pc.php'),
      const WallpaperApiSource(name: 'PE美女壁纸·Ltywl', url: 'https://pic.ltywl.top/mn/pe.php'),
      const WallpaperApiSource(
        name: '美女壁纸·极数本源',
        url: 'https://v1.apizero.cn/api/wallpaper?category=美女&resolution=1920x1080&count=1',
        kind: WallpaperApiKind.json,
      ),
      const WallpaperApiSource(
        name: '电脑端小姐姐·Nsuuu',
        url: 'https://v1.nsuuu.com/api/pcmeinvpic',
        kind: WallpaperApiKind.json,
      ),
      const WallpaperApiSource(name: '随机白丝·Nsuuu', url: 'https://v1.nsuuu.com/api/baisi', kind: WallpaperApiKind.json),
      const WallpaperApiSource(name: '随机美女·搏天API', url: 'http://api.btstu.cn/sjbz/api.php?lx=meizi&format=images'),
      const WallpaperApiSource(name: '随机二次元·搏天API', url: 'http://api.btstu.cn/sjbz/api.php?lx=dongman&format=images'),
      const WallpaperApiSource(
        name: '随机小姐姐·快手',
        url: 'http://api.nonebot.top/api/v1/random/wallpaper?type=kuaishou',
        kind: WallpaperApiKind.json,
      ),
      const WallpaperApiSource(
        name: '随机Cos·Nonebot',
        url: 'http://api.nonebot.top/api/v1/random/wallpaper?type=cos',
        kind: WallpaperApiKind.json,
      ),
      const WallpaperApiSource(name: '随机美女·CZL', url: 'https://random-api.czl.net/pic/ai'),
      const WallpaperApiSource(name: '随机美女·Mioical', url: 'https://api.mioical.moe/img'),
    ],
  ),
];

/// Every source across every group.
final List<WallpaperApiSource> kWallpaperApiSources = <WallpaperApiSource>[
  for (final WallpaperApiGroup group in kWallpaperApiGroups) ...group.sources,
];
