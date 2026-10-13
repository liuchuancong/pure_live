/// Douyu endpoints, user agents and protocol constants (ARCHITECTURE.md §7.2:
/// endpoint shapes live here; signing lives in the signer).
abstract final class DouyuEndpoints {
  /// Desktop Chrome 128, the UA the web player sends with API and media
  /// requests.
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/128.0.0.0 Safari/537.36';

  /// The Edge 114 UA `betard` is sent with.
  static const String detailUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/114.0.0.0 Safari/537.36 Edg/114.0.1823.43';

  /// Origin of the web player.
  static const String origin = 'https://www.douyu.com';

  /// The only danmaku endpoint.
  static const String danmakuServer = 'wss://danmuproxy.douyu.com:8506';

  /// Where `betard`'s relative gift pictures (`pc_icon`) live (checked
  /// 2026-10-09: 火箭's `pc_icon` answers 200 here, 404 on the test host).
  static const String giftPictureBase = 'https://gfs-op.douyucdn.cn/dygift';

  /// Area groups.
  static Uri cateList() => Uri.https('m.douyu.com', '/api/cate/list');

  /// Area rooms, 120 a page.
  static Uri mixList(String areaId, int page) =>
      Uri.https('www.douyu.com', '/gapi/rkc/directory/mixList/2_$areaId/$page');

  /// Recommendations, 40 a page.
  static Uri recommend(int page) => Uri.https('www.douyu.com', '/japi/weblist/apinc/allpage/6/$page');

  /// Room search.
  static Uri searchShow(String keyword, int page, int pageSize) => Uri.https(
    'www.douyu.com',
    '/japi/search/api/searchShow',
    {'kw': keyword, 'page': '$page', 'pageSize': '$pageSize'},
  );

  /// Anchor search.
  static Uri searchUser(String keyword, int page, int pageSize) => Uri.https(
    'www.douyu.com',
    '/japi/search/api/searchUser',
    {'kw': keyword, 'page': '$page', 'pageSize': '$pageSize', 'filterType': '1'},
  );

  /// A room page by rid, 靓号 or alias.
  static Uri roomPage(String address) => Uri.https('www.douyu.com', '/$address');

  /// The room-detail payload (`betard`).
  static Uri roomDetail(String rid) => Uri.https('www.douyu.com', '/betard/$rid');

  /// The signed play endpoint.
  static Uri play(String rid) => Uri.https('www.douyu.com', '/lapi/live/getH5PlayV1/$rid');

  /// The play-request signing descriptor.
  static Uri encryption(String did) =>
      Uri.https('www.douyu.com', '/wgapi/livenc/liveweb/websec/getEncryption', {'did': did});

  /// The login renewal endpoint.
  static Uri passportRenewal() => Uri.https('passport.douyu.com', '/lapi/passport/iframe/safeAuth', {'client_id': '1'});

  /// A room's full gift list.
  /// A room's full gift list.
  static Uri giftList(String rid) =>
      Uri.parse('https://gift.douyucdn.cn/api/gift/v3/web/list').replace(queryParameters: {'rid': rid});

  /// The platform's prop (backpack gift) table, JSONP.
  /// The platform's prop (backpack gift) table, JSONP.
  static final Uri propGiftList = Uri.parse(
    'https://webconf.douyucdn.cn/resource/common/prop_gift_list/prop_gift_config.json',
  );
}
