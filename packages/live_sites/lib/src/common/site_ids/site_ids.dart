/// Platform ids, shared by the models (identity, audience tables) and every
/// adapter. Kept free of any adapter dependency so the model layer can use it.
abstract final class SiteIds {
  /// Bilibili.
  static const String bilibili = 'bilibili';

  /// Douyu.
  static const String douyu = 'douyu';

  /// Huya.
  static const String huya = 'huya';

  /// Douyin.
  static const String douyin = 'douyin';

  /// Kuaishou.
  static const String kuaishou = 'kuaishou';

  /// NetEase CC.
  static const String cc = 'cc';

  /// Twitch.
  static const String twitch = 'twitch';

  /// SOOP.
  static const String soop = 'soop';

  /// YY.
  static const String yy = 'yy';

  /// AcFun.
  static const String acfun = 'acfun';

  /// Picarto.
  static const String picarto = 'picarto';

  /// TwitCasting.
  static const String twitcasting = 'twitcasting';

  /// Missevan.
  static const String missevan = 'missevan';

  /// Inke.
  static const String inke = 'inke';

  /// Kilakila.
  static const String kilakila = 'kilakila';

  /// Xiaohongshu.
  static const String xiaohongshu = 'xiaohongshu';

  /// niconico.
  static const String niconico = 'niconico';

  /// Weibo.
  static const String weibo = 'weibo';

  /// SHOWROOM.
  static const String showroom = 'showroom';

  /// CHZZK.
  static const String chzzk = 'chzzk';

  /// Kick.
  static const String kick = 'kick';

  /// LiveMe.
  static const String liveMe = 'liveme';

  /// TikTok LIVE.
  static const String tiktok = 'tiktok';

  /// YouTube Live.
  static const String youtube = 'youtube';

  /// Bigo Live.
  static const String bigo = 'bigo';

  /// PandaTV.
  static const String pandaLive = 'pandalive';

  /// FC2 Live.
  static const String fc2Live = 'fc2live';

  /// Steam Broadcasting.
  static const String steamBroadcast = 'steambroadcast';

  /// JD Live.
  static const String jdLive = 'jdlive';

  /// Kugou Live.
  static const String kugouLive = 'kugoulive';

  /// Baidu Live.
  static const String baiduLive = 'baidulive';

  /// Six Rooms.
  static const String sixRoom = 'sixroom';

  /// LOOK Live.
  static const String lookLive = 'looklive';

  /// 17LIVE.
  static const String seventeenLive = '17live';

  /// Custom IPTV sources.
  static const String iptv = 'iptv';

  /// The search page's all-platforms entry; not a platform.
  static const String all = 'all';

  /// Supported platforms, in display order.
  static const List<String> supported = [
    bilibili,
    douyu,
    huya,
    douyin,
    kuaishou,
    cc,
    twitch,
    soop,
    yy,
    acfun,
    picarto,
    twitcasting,
    missevan,
    inke,
    kilakila,
    xiaohongshu,
    niconico,
    weibo,
    showroom,
    chzzk,
    kick,
    liveMe,
    tiktok,
    youtube,
    bigo,
    pandaLive,
    fc2Live,
    steamBroadcast,
    jdLive,
    kugouLive,
    baiduLive,
    sixRoom,
    lookLive,
    seventeenLive,
    iptv,
  ];

  /// Voice platforms: the stream's video track is a placeholder or a plain
  /// background, so the room shows its cover instead.
  static const Set<String> voiceLive = {missevan, kilakila};

  /// Platforms retired in the reference (hard to maintain, niche or unusable).
  /// Stored follows, history and links for them stay readable and are shown as
  /// retired instead of failing as unknown.
  static const Set<String> retired = {
    'huajiao',
    'openrec',
    'ttinglive',
    'popkontv',
    'shopeelive',
    'vkvideolive',
    'nimotv',
    'dailymotion',
    'rumble',
    'goodgame',
    'taobaolive',
  };

  /// Web hosts of the retired platforms, so a shared link is answered with
  /// retired instead of being ignored as unrecognised text.
  static const Set<String> retiredHosts = {
    'huajiao.com',
    'openrec.tv',
    'flextv.co.kr',
    'ttinglive.com',
    'popkontv.com',
    'goodgame.ru',
    'vkvideo.ru',
    'vkplay.live',
    'dailymotion.com',
    'dai.ly',
    'rumble.com',
    'nimo.tv',
    'shopee.co.id',
    'taobao.com',
    'm.tb.cn',
  };

  /// Platforms whose room id is a user name the platform matches without regard
  /// to case, so room identity ignores case there. The room id keeps the
  /// spelling it was stored with; only comparisons fold it.
  static const Set<String> caseInsensitiveRoomIds = {
    twitch,
    soop,
    picarto,
    twitcasting,
    tiktok,
    pandaLive,
    douyu,
    kuaishou,
    bigo,
    kick,
  };

  /// Whether rooms of [platform] are identified without regard to the room id's
  /// case (see [caseInsensitiveRoomIds]).
  static bool ignoresRoomIdCase(String platform) => caseInsensitiveRoomIds.contains(platform.trim().toLowerCase());

  static final Set<String> _supported = supported.toSet();

  /// Whether [id] is a supported platform (case and spaces ignored).
  static bool isSupported(String id) => _supported.contains(id.trim().toLowerCase());

  /// Whether [id] is a retired platform.
  static bool isRetired(String id) => retired.contains(id.trim().toLowerCase());

  /// Whether [text] contains a link to a retired platform.
  static bool isRetiredLink(String text) {
    final scheme = RegExp('https?://');
    for (final word in text.split(RegExp(r'\s+'))) {
      if (!scheme.hasMatch(word)) continue;
      final host = Uri.tryParse(word)?.host.toLowerCase() ?? '';
      if (host.isNotEmpty && retiredHosts.any((root) => host == root || host.endsWith('.$root'))) return true;
    }
    return false;
  }
}
