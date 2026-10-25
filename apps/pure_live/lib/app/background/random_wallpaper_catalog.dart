import 'package:pure_live/l10n/translations.dart';

/// How a random-picture API hands over its picture.
enum RandomWallpaperKind {
  /// The URL itself streams a picture, following redirects.
  direct,

  /// The URL answers JSON carrying the real picture address.
  json,

  /// t.alcy.cc style: the category is a path segment picked per request.
  alcy,
}

/// Categories the alcy host accepts as a path segment. Dead names are
/// left out: a 404 entry in the random pool only burns a request.
const List<String> randomAlcyCategories = ['ycy', 'moez', 'ysz', 'ys', 'mp', 'moemp', 'ysmp', 'tx', 'lai', 'xhl', 'bd'];

/// One random-picture source: a provider plus the request shape it uses.
final class RandomWallpaperSource {
  /// Creates a source.
  const RandomWallpaperSource({
    required this.id,
    required this.url,
    this.kind = RandomWallpaperKind.direct,
    this.apiKey,
  });

  /// Stable identity; the readable name lives in the wallpaper namespace.
  final String id;

  /// The request URL.
  final String url;

  /// How the answer carries the picture.
  final RandomWallpaperKind kind;

  /// Some JSON endpoints need `type=json&apiKey=<key>`.
  final String? apiKey;

  /// The host shown under the name.
  String get host => Uri.tryParse(url)?.host ?? url;

  /// The localized name.
  String label(Translations t) => switch (id) {
    'bing_biturl' => t.wallpaper.sourceBingBiturl,
    'bing_jason_zeng' => t.wallpaper.sourceBingJasonZeng,
    'bing_uapi' => t.wallpaper.sourceBingUapi,
    'bing_ying_joy' => t.wallpaper.sourceBingYingJoy,
    'bing_w3h5' => t.wallpaper.sourceBingW3h5,
    'bing_wuming_daily' => t.wallpaper.sourceBingWumingDaily,
    'alcy_random' => t.wallpaper.sourceAlcyRandom,
    'alcy_ycy' => t.wallpaper.sourceAlcyYcy,
    'alcy_moez' => t.wallpaper.sourceAlcyMoez,
    'alcy_ysz' => t.wallpaper.sourceAlcyYsz,
    'alcy_ys' => t.wallpaper.sourceAlcyYs,
    'alcy_mp' => t.wallpaper.sourceAlcyMp,
    'alcy_moemp' => t.wallpaper.sourceAlcyMoemp,
    'alcy_ysmp' => t.wallpaper.sourceAlcyYsmp,
    'alcy_tx' => t.wallpaper.sourceAlcyTx,
    'alcy_lai' => t.wallpaper.sourceAlcyLai,
    'alcy_xhl' => t.wallpaper.sourceAlcyXhl,
    'alcy_bd' => t.wallpaper.sourceAlcyBd,
    'wuming_girl' => t.wallpaper.sourceWumingGirl,
    'wuming_black_stocking' => t.wallpaper.sourceWumingBlackStocking,
    'wuming_douyin_girl' => t.wallpaper.sourceWumingDouyinGirl,
    'wuming_white_stocking' => t.wallpaper.sourceWumingWhiteStocking,
    'wuming_douyin_girl_alt' => t.wallpaper.sourceWumingDouyinGirlAlt,
    'wuming_bcy_cos' => t.wallpaper.sourceWumingBcyCos,
    'wuming_anime_wallpaper' => t.wallpaper.sourceWumingAnimeWallpaper,
    'wuming_aesthetic_girl' => t.wallpaper.sourceWumingAestheticGirl,
    'uapi_all' => t.wallpaper.sourceUapiAll,
    'uapi_acg' => t.wallpaper.sourceUapiAcg,
    'uapi_acg_pc' => t.wallpaper.sourceUapiAcgPc,
    'uapi_acg_mobile' => t.wallpaper.sourceUapiAcgMobile,
    'uapi_landscape' => t.wallpaper.sourceUapiLandscape,
    'uapi_anime' => t.wallpaper.sourceUapiAnime,
    'uapi_pc_wallpaper' => t.wallpaper.sourceUapiPcWallpaper,
    'uapi_mobile_wallpaper' => t.wallpaper.sourceUapiMobileWallpaper,
    'uapi_general_anime' => t.wallpaper.sourceUapiGeneralAnime,
    'uapi_furry' => t.wallpaper.sourceUapiFurry,
    'uapi_furry_z4k' => t.wallpaper.sourceUapiFurryZ4k,
    'uapi_furry_szs8k' => t.wallpaper.sourceUapiFurrySzs8k,
    'uapi_furry_s4k' => t.wallpaper.sourceUapiFurryS4k,
    'uapi_furry_4k' => t.wallpaper.sourceUapiFurry4k,
    '360_beauty' => t.wallpaper.source360Beauty,
    '360_landscape' => t.wallpaper.source360Landscape,
    '360_game' => t.wallpaper.source360Game,
    '360_movie' => t.wallpaper.source360Movie,
    '360_fashion' => t.wallpaper.source360Fashion,
    '360_star' => t.wallpaper.source360Star,
    '360_car' => t.wallpaper.source360Car,
    '360_pet' => t.wallpaper.source360Pet,
    '360_fresh' => t.wallpaper.source360Fresh,
    '360_sport' => t.wallpaper.source360Sport,
    '360_child' => t.wallpaper.source360Child,
    '360_military' => t.wallpaper.source360Military,
    '360_anime' => t.wallpaper.source360Anime,
    '360_calendar' => t.wallpaper.source360Calendar,
    '360_love' => t.wallpaper.source360Love,
    '360_motto' => t.wallpaper.source360Motto,
    'xxapi' => t.wallpaper.sourceXxapi,
    'mtyqx' => t.wallpaper.sourceMtyqx,
    'picsum' => t.wallpaper.sourcePicsum,
    'dmoe' => t.wallpaper.sourceDmoe,
    'loliapi' => t.wallpaper.sourceLoliapi,
    'catvod' => t.wallpaper.sourceCatvod,
    'sexy_black_stocking_xxapi' => t.wallpaper.sourceSexyBlackStockingXxapi,
    'sexy_white_stocking_xxapi' => t.wallpaper.sourceSexyWhiteStockingXxapi,
    'sexy_jk_xxapi' => t.wallpaper.sourceSexyJkXxapi,
    'sexy_girl_suyan' => t.wallpaper.sourceSexyGirlSuyan,
    'sexy_beauty_suyan' => t.wallpaper.sourceSexyBeautySuyan,
    'sexy_meizi_suyan' => t.wallpaper.sourceSexyMeiziSuyan,
    'sexy_black_stocking_suyan' => t.wallpaper.sourceSexyBlackStockingSuyan,
    'sexy_meizi_xiaodu' => t.wallpaper.sourceSexyMeiziXiaodu,
    'sexy_stocking_nonebot' => t.wallpaper.sourceSexyStockingNonebot,
    'sexy_pc_ltywl' => t.wallpaper.sourceSexyPcLtywl,
    'sexy_pe_ltywl' => t.wallpaper.sourceSexyPeLtywl,
    'sexy_beauty_apizero' => t.wallpaper.sourceSexyBeautyApizero,
    'sexy_pc_nsuuu' => t.wallpaper.sourceSexyPcNsuuu,
    'sexy_white_stocking_nsuuu' => t.wallpaper.sourceSexyWhiteStockingNsuuu,
    'sexy_beauty_btstu' => t.wallpaper.sourceSexyBeautyBtstu,
    'sexy_anime_btstu' => t.wallpaper.sourceSexyAnimeBtstu,
    'sexy_girl_kuaishou' => t.wallpaper.sourceSexyGirlKuaishou,
    'sexy_cos_nonebot' => t.wallpaper.sourceSexyCosNonebot,
    'sexy_beauty_czl' => t.wallpaper.sourceSexyBeautyCzl,
    'sexy_beauty_mioical' => t.wallpaper.sourceSexyBeautyMioical,
    _ => id,
  };
}

/// A family of random-picture sources.
final class RandomWallpaperGroup {
  /// Creates a group.
  const RandomWallpaperGroup({required this.id, required this.sources});

  /// Stable identity; the readable name lives in the wallpaper namespace.
  final String id;

  /// The sources, in display order.
  final List<RandomWallpaperSource> sources;

  /// The localized name.
  String label(Translations t) => switch (id) {
    'bing' => t.wallpaper.groupBing,
    'alcy' => t.wallpaper.groupAlcy,
    'wuming' => t.wallpaper.groupWuming,
    'uapi' => t.wallpaper.groupUapi,
    '360' => t.wallpaper.group360,
    'misc' => t.wallpaper.groupMisc,
    'sexy' => t.wallpaper.groupSexy,
    _ => id,
  };
}

/// The random-picture sources, grouped as the reference lists them.
const List<RandomWallpaperGroup> randomWallpaperGroups = [
  RandomWallpaperGroup(
    id: 'bing',
    sources: [
      RandomWallpaperSource(
        id: 'bing_biturl',
        url: 'https://bing.biturl.top/?resolution=1920x1080&format=image&index=random',
      ),
      RandomWallpaperSource(
        id: 'bing_jason_zeng',
        url: 'https://bingw.jasonzeng.dev/?resolution=1920x1080&index=random',
      ),
      RandomWallpaperSource(
        id: 'bing_uapi',
        url: 'https://uapis.cn/api/v1/image/bing-daily?random=true&resolution=1080',
      ),
      RandomWallpaperSource(id: 'bing_ying_joy', url: 'https://api.1314.cool/bingimg'),
      RandomWallpaperSource(id: 'bing_w3h5', url: 'https://bz.w3h5.com/img/rand_fhd'),
      RandomWallpaperSource(
        id: 'bing_wuming_daily',
        url: 'https://jkapi.com/api/bing_img',
        kind: RandomWallpaperKind.json,
        apiKey: '0f57c17bca42966996d6a8bc28594858',
      ),
    ],
  ),
  RandomWallpaperGroup(
    id: 'alcy',
    sources: [
      RandomWallpaperSource(id: 'alcy_random', url: 'https://t.alcy.cc/', kind: RandomWallpaperKind.alcy),
      RandomWallpaperSource(id: 'alcy_ycy', url: 'https://t.alcy.cc/ycy'),
      RandomWallpaperSource(id: 'alcy_moez', url: 'https://t.alcy.cc/moez'),
      RandomWallpaperSource(id: 'alcy_ysz', url: 'https://t.alcy.cc/ysz'),
      RandomWallpaperSource(id: 'alcy_ys', url: 'https://t.alcy.cc/ys'),
      RandomWallpaperSource(id: 'alcy_mp', url: 'https://t.alcy.cc/mp'),
      RandomWallpaperSource(id: 'alcy_moemp', url: 'https://t.alcy.cc/moemp'),
      RandomWallpaperSource(id: 'alcy_ysmp', url: 'https://t.alcy.cc/ysmp'),
      RandomWallpaperSource(id: 'alcy_tx', url: 'https://t.alcy.cc/tx'),
      RandomWallpaperSource(id: 'alcy_lai', url: 'https://t.alcy.cc/lai'),
      RandomWallpaperSource(id: 'alcy_xhl', url: 'https://t.alcy.cc/xhl'),
      RandomWallpaperSource(id: 'alcy_bd', url: 'https://t.alcy.cc/bd'),
    ],
  ),
  RandomWallpaperGroup(
    id: 'wuming',
    sources: [
      RandomWallpaperSource(
        id: 'wuming_girl',
        url: 'https://jkapi.com/api/meinv_img',
        kind: RandomWallpaperKind.json,
        apiKey: '872080c8858c40e6a1eb2ba86694d4d8',
      ),
      RandomWallpaperSource(
        id: 'wuming_black_stocking',
        url: 'https://jkapi.com/api/heisi_img',
        kind: RandomWallpaperKind.json,
        apiKey: '0c0c7a39e084db0e9c7cf2e25318f42c',
      ),
      RandomWallpaperSource(
        id: 'wuming_douyin_girl',
        url: 'https://jkapi.com/api/dymm_img',
        kind: RandomWallpaperKind.json,
        apiKey: '7b6c5500e52878bc46264cd140196699',
      ),
      RandomWallpaperSource(
        id: 'wuming_white_stocking',
        url: 'https://jkapi.com/api/baisi_img',
        kind: RandomWallpaperKind.json,
        apiKey: '7605369407c689e9b2804bfc56a82ac7',
      ),
      RandomWallpaperSource(
        id: 'wuming_douyin_girl_alt',
        url: 'https://jkapi.com/api/dymm_img',
        kind: RandomWallpaperKind.json,
        apiKey: '7b6c5500e52878bc46264cd140196699',
      ),
      RandomWallpaperSource(
        id: 'wuming_bcy_cos',
        url: 'https://jkapi.com/api/bcy_cos',
        kind: RandomWallpaperKind.json,
        apiKey: 'f5bce3b84b7409fbe8abb2246b46f4c8',
      ),
      RandomWallpaperSource(
        id: 'wuming_anime_wallpaper',
        url: 'https://jkapi.com/api/dm_wallpaper',
        kind: RandomWallpaperKind.json,
        apiKey: '95e3a0e608a8b1bed6d513346f929202',
      ),
      RandomWallpaperSource(
        id: 'wuming_aesthetic_girl',
        url: 'https://jkapi.com/api/wm_girl',
        kind: RandomWallpaperKind.json,
        apiKey: '0a7c2239bc57624cac60967937da8a1b',
      ),
    ],
  ),
  RandomWallpaperGroup(
    id: 'uapi',
    sources: [
      RandomWallpaperSource(id: 'uapi_all', url: 'https://uapis.cn/api/v1/random/image'),
      RandomWallpaperSource(id: 'uapi_acg', url: 'https://uapis.cn/api/v1/random/image?category=acg'),
      RandomWallpaperSource(id: 'uapi_acg_pc', url: 'https://uapis.cn/api/v1/random/image?category=acg&type=pc'),
      RandomWallpaperSource(id: 'uapi_acg_mobile', url: 'https://uapis.cn/api/v1/random/image?category=acg&type=mb'),
      RandomWallpaperSource(id: 'uapi_landscape', url: 'https://uapis.cn/api/v1/random/image?category=landscape'),
      RandomWallpaperSource(id: 'uapi_anime', url: 'https://uapis.cn/api/v1/random/image?category=anime'),
      RandomWallpaperSource(id: 'uapi_pc_wallpaper', url: 'https://uapis.cn/api/v1/random/image?category=pc_wallpaper'),
      RandomWallpaperSource(
        id: 'uapi_mobile_wallpaper',
        url: 'https://uapis.cn/api/v1/random/image?category=mobile_wallpaper',
      ),
      RandomWallpaperSource(
        id: 'uapi_general_anime',
        url: 'https://uapis.cn/api/v1/random/image?category=general_anime',
      ),
      RandomWallpaperSource(id: 'uapi_furry', url: 'https://uapis.cn/api/v1/random/image?category=furry'),
      RandomWallpaperSource(id: 'uapi_furry_z4k', url: 'https://uapis.cn/api/v1/random/image?category=furry&type=z4k'),
      RandomWallpaperSource(
        id: 'uapi_furry_szs8k',
        url: 'https://uapis.cn/api/v1/random/image?category=furry&type=szs8k',
      ),
      RandomWallpaperSource(id: 'uapi_furry_s4k', url: 'https://uapis.cn/api/v1/random/image?category=furry&type=s4k'),
      RandomWallpaperSource(id: 'uapi_furry_4k', url: 'https://uapis.cn/api/v1/random/image?category=furry&type=4k'),
    ],
  ),
  RandomWallpaperGroup(
    id: '360',
    sources: [
      RandomWallpaperSource(
        id: '360_beauty',
        url: 'https://v1.apizero.cn/api/wallpaper?category=美女&resolution=1920x1080&count=1',
        kind: RandomWallpaperKind.json,
      ),
      RandomWallpaperSource(
        id: '360_landscape',
        url: 'https://v1.apizero.cn/api/wallpaper?category=风景&resolution=1920x1080&count=1',
        kind: RandomWallpaperKind.json,
      ),
      RandomWallpaperSource(
        id: '360_game',
        url: 'https://v1.apizero.cn/api/wallpaper?category=游戏&resolution=1920x1080&count=1',
        kind: RandomWallpaperKind.json,
      ),
      RandomWallpaperSource(
        id: '360_movie',
        url: 'https://v1.apizero.cn/api/wallpaper?category=影视&resolution=1920x1080&count=1',
        kind: RandomWallpaperKind.json,
      ),
      RandomWallpaperSource(
        id: '360_fashion',
        url: 'https://v1.apizero.cn/api/wallpaper?category=时尚&resolution=1920x1080&count=1',
        kind: RandomWallpaperKind.json,
      ),
      RandomWallpaperSource(
        id: '360_star',
        url: 'https://v1.apizero.cn/api/wallpaper?category=明星&resolution=1920x1080&count=1',
        kind: RandomWallpaperKind.json,
      ),
      RandomWallpaperSource(
        id: '360_car',
        url: 'https://v1.apizero.cn/api/wallpaper?category=汽车&resolution=1920x1080&count=1',
        kind: RandomWallpaperKind.json,
      ),
      RandomWallpaperSource(
        id: '360_pet',
        url: 'https://v1.apizero.cn/api/wallpaper?category=萌宠&resolution=1920x1080&count=1',
        kind: RandomWallpaperKind.json,
      ),
      RandomWallpaperSource(
        id: '360_fresh',
        url: 'https://v1.apizero.cn/api/wallpaper?category=清新&resolution=1920x1080&count=1',
        kind: RandomWallpaperKind.json,
      ),
      RandomWallpaperSource(
        id: '360_sport',
        url: 'https://v1.apizero.cn/api/wallpaper?category=体育&resolution=1920x1080&count=1',
        kind: RandomWallpaperKind.json,
      ),
      RandomWallpaperSource(
        id: '360_child',
        url: 'https://v1.apizero.cn/api/wallpaper?category=萌娃&resolution=1920x1080&count=1',
        kind: RandomWallpaperKind.json,
      ),
      RandomWallpaperSource(
        id: '360_military',
        url: 'https://v1.apizero.cn/api/wallpaper?category=军事&resolution=1920x1080&count=1',
        kind: RandomWallpaperKind.json,
      ),
      RandomWallpaperSource(
        id: '360_anime',
        url: 'https://v1.apizero.cn/api/wallpaper?category=动漫&resolution=1920x1080&count=1',
        kind: RandomWallpaperKind.json,
      ),
      RandomWallpaperSource(
        id: '360_calendar',
        url: 'https://v1.apizero.cn/api/wallpaper?category=日历&resolution=1920x1080&count=1',
        kind: RandomWallpaperKind.json,
      ),
      RandomWallpaperSource(
        id: '360_love',
        url: 'https://v1.apizero.cn/api/wallpaper?category=爱情&resolution=1920x1080&count=1',
        kind: RandomWallpaperKind.json,
      ),
      RandomWallpaperSource(
        id: '360_motto',
        url: 'https://v1.apizero.cn/api/wallpaper?category=格言&resolution=1920x1080&count=1',
        kind: RandomWallpaperKind.json,
      ),
    ],
  ),
  RandomWallpaperGroup(
    id: 'misc',
    sources: [
      RandomWallpaperSource(id: 'xxapi', url: 'https://v2.xxapi.cn/api/wallpaper', kind: RandomWallpaperKind.json),
      RandomWallpaperSource(id: 'mtyqx', url: 'https://api.mtyqx.cn/tapi/random.php'),
      RandomWallpaperSource(id: 'picsum', url: 'https://picsum.photos/1920/1080'),
      RandomWallpaperSource(id: 'dmoe', url: 'https://www.dmoe.cc/random.php'),
      RandomWallpaperSource(id: 'loliapi', url: 'https://www.loliapi.com/bg/'),
      RandomWallpaperSource(id: 'catvod', url: 'https://pictures.catvod.eu.org/'),
    ],
  ),
  RandomWallpaperGroup(
    id: 'sexy',
    sources: [
      RandomWallpaperSource(
        id: 'sexy_black_stocking_xxapi',
        url: 'https://v2.xxapi.cn/api/heisi',
        kind: RandomWallpaperKind.json,
      ),
      RandomWallpaperSource(
        id: 'sexy_white_stocking_xxapi',
        url: 'https://v2.xxapi.cn/api/baisi',
        kind: RandomWallpaperKind.json,
      ),
      RandomWallpaperSource(id: 'sexy_jk_xxapi', url: 'https://v2.xxapi.cn/api/jk', kind: RandomWallpaperKind.json),
      RandomWallpaperSource(id: 'sexy_girl_suyan', url: 'https://api.suyanw.cn/api/ksxjj.php'),
      RandomWallpaperSource(id: 'sexy_beauty_suyan', url: 'https://api.suyanw.cn/api/meinv.php'),
      RandomWallpaperSource(id: 'sexy_meizi_suyan', url: 'https://api.suyanw.cn/api/meizi.php'),
      RandomWallpaperSource(id: 'sexy_black_stocking_suyan', url: 'https://api.suyanw.cn/api/hs.php'),
      RandomWallpaperSource(
        id: 'sexy_meizi_xiaodu',
        url: 'https://openapi.dwo.cc/api/meinv?type=json',
        kind: RandomWallpaperKind.json,
      ),
      RandomWallpaperSource(
        id: 'sexy_stocking_nonebot',
        url: 'https://api.nonebot.top/api/v1/random/wallpaper?type=meizi',
        kind: RandomWallpaperKind.json,
      ),
      RandomWallpaperSource(id: 'sexy_pc_ltywl', url: 'https://pic.ltywl.top/mn/pc.php'),
      RandomWallpaperSource(id: 'sexy_pe_ltywl', url: 'https://pic.ltywl.top/mn/pe.php'),
      RandomWallpaperSource(
        id: 'sexy_beauty_apizero',
        url: 'https://v1.apizero.cn/api/wallpaper?category=美女&resolution=1920x1080&count=1',
        kind: RandomWallpaperKind.json,
      ),
      RandomWallpaperSource(
        id: 'sexy_pc_nsuuu',
        url: 'https://v1.nsuuu.com/api/pcmeinvpic',
        kind: RandomWallpaperKind.json,
      ),
      RandomWallpaperSource(
        id: 'sexy_white_stocking_nsuuu',
        url: 'https://v1.nsuuu.com/api/baisi',
        kind: RandomWallpaperKind.json,
      ),
      RandomWallpaperSource(id: 'sexy_beauty_btstu', url: 'http://api.btstu.cn/sjbz/api.php?lx=meizi&format=images'),
      RandomWallpaperSource(id: 'sexy_anime_btstu', url: 'http://api.btstu.cn/sjbz/api.php?lx=dongman&format=images'),
      RandomWallpaperSource(
        id: 'sexy_girl_kuaishou',
        url: 'http://api.nonebot.top/api/v1/random/wallpaper?type=kuaishou',
        kind: RandomWallpaperKind.json,
      ),
      RandomWallpaperSource(
        id: 'sexy_cos_nonebot',
        url: 'http://api.nonebot.top/api/v1/random/wallpaper?type=cos',
        kind: RandomWallpaperKind.json,
      ),
      RandomWallpaperSource(id: 'sexy_beauty_czl', url: 'https://random-api.czl.net/pic/ai'),
      RandomWallpaperSource(id: 'sexy_beauty_mioical', url: 'https://api.mioical.moe/img'),
    ],
  ),
];
