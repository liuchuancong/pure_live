/// The stable site ids and id-grouping helpers.
///
/// Ids are lowercase program identifiers; they are the registry keys and
/// the `platform` field of every `LiveRoom`.
abstract final class SiteIds {
  /// Bilibili.
  static const String bilibili = 'bilibili';

  /// Douyin.
  static const String douyin = 'douyin';

  /// Douyu.
  static const String douyu = 'douyu';

  /// Huya.
  static const String huya = 'huya';

  /// NetEase CC.
  static const String cc = 'cc';

  /// AcFun.
  static const String acfun = 'acfun';

  /// Baidu Live.
  static const String baiduLive = 'baidulive';

  /// Kuaishou.
  static const String kuaishou = 'kuaishou';

  /// Kugou Live.
  static const String kugouLive = 'kugoulive';

  /// JD Live.
  static const String jdLive = 'jdlive';

  /// YY.
  static const String yy = 'yy';

  /// Missevan.
  static const String missevan = 'missevan';

  /// Inke.
  static const String inke = 'inke';

  /// LiveMe.
  static const String liveme = 'liveme';

  /// LookLive.
  static const String looklive = 'looklive';

  /// Weibo Live.
  static const String weibo = 'weibo';

  /// Xiaohongshu Live.
  static const String xiaohongshu = 'xiaohongshu';

  /// Niconico.
  static const String niconico = 'niconico';

  /// FC2 Live.
  static const String fc2Live = 'fc2live';

  /// SHOWROOM.
  static const String showroom = 'showroom';

  /// TwitCasting.
  static const String twitcasting = 'twitcasting';

  /// KilaKila.
  static const String kilakila = 'kilakila';

  /// SixRoom.
  static const String sixroom = 'sixroom';

  /// CHZZK.
  static const String chzzk = 'chzzk';

  /// Pandalive.
  static const String pandalive = 'pandalive';

  /// SOOP.
  static const String soop = 'soop';

  /// Twitch.
  static const String twitch = 'twitch';

  /// YouTube Live.
  static const String youtube = 'youtube';

  /// Kick.
  static const String kick = 'kick';

  /// Picarto.
  static const String picarto = 'picarto';

  /// Bigo Live.
  static const String bigo = 'bigo';

  /// Steam Broadcast.
  static const String steamBroadcast = 'steambroadcast';

  /// TikTok Live.
  static const String tiktok = 'tiktok';

  /// IPTV (synthetic platform served by the IPTV module).
  static const String iptv = 'iptv';

  /// Sites whose room ids compare case-insensitively.
  static const Set<String> caseInsensitiveRoomIds = {twitch, kick};

  /// All supported ids.
  static const List<String> supported = [
    bilibili,
    douyin,
    douyu,
    huya,
    cc,
    acfun,
    baiduLive,
    kuaishou,
    kugouLive,
    jdLive,
    yy,
    missevan,
    inke,
    liveme,
    looklive,
    weibo,
    xiaohongshu,
    niconico,
    fc2Live,
    showroom,
    twitcasting,
    kilakila,
    sixroom,
    chzzk,
    pandalive,
    soop,
    twitch,
    youtube,
    kick,
    picarto,
    bigo,
    steamBroadcast,
    tiktok,
    iptv,
  ];
}
