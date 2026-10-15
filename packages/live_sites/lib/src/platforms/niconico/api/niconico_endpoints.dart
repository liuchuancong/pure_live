/// Niconico live endpoints, headers and identity constants (ARCHITECTURE.md
/// §7.2: endpoint shapes and the room-id grammar live here; parsing lives in
/// `parsers/`).
abstract final class NiconicoEndpoints {
  /// The desktop user agent every page, list and media request is sent with.
  static const String userAgent = 'Mozilla/5.0';

  /// Pages and the API answer from here.
  static const String origin = 'https://live.nicovideo.jp';

  /// The seat WebSocket host.
  static const String seatHost = 'a.live2.nicovideo.jp';

  /// The media (HLS) host.
  static const String mediaHost = 'livedelivery.dlive.nicovideo.jp';

  /// The headers of every page and list request (anonymous: no cookie).
  static const Map<String, String> headers = {'referer': '$origin/', 'user-agent': userAgent};

  /// The seat WebSocket handshake headers.
  static const Map<String, String> seatHeaders = {'origin': origin};

  /// The comment server's request headers: the page and list headers with the
  /// site's origin added, as the web player sends them.
  static const Map<String, String> danmakuHeaders = {'referer': '$origin/', 'user-agent': userAgent, 'origin': origin};

  /// Rows of a recent-programs page.
  static const int recentPageSize = 70;

  /// Rows of a search page.
  static const int searchPageSize = 40;

  /// The longest search keyword niconico answers; a longer one is the
  /// caller's mistake, not something to send.
  static const int maxKeywordLength = 500;

  /// The recent-programs tabs, in the platform's order. `live` is the game
  /// tab, not "every live program".
  static const List<String> tabs = ['common', 'try', 'live', 'req', 'face', 'totu', 'vtuber'];

  /// The tab names (the interface re-translates them by area id).
  static const Map<String, String> tabNames = {
    'common': '综合',
    'try': '创作与挑战',
    'live': '游戏',
    'req': '视频介绍',
    'face': '露脸直播',
    'totu': '连麦互动',
    'vtuber': 'VTuber',
  };

  /// The area type of the tabs.
  static const String areaType = 'recent';

  /// The single area id niconico is browsed by.
  static const String areaId = 'niconico';

  static final RegExp _programId = RegExp(r'^lv[1-9][0-9]{0,17}$');
  static final RegExp _userRoomId = RegExp(r'^user/[1-9][0-9]{0,18}$');
  static final RegExp _channelRoomId = RegExp(r'^ch[1-9][0-9]{0,18}$');
  static final RegExp _userId = RegExp(r'^[1-9][0-9]{0,18}$');

  /// Whether [id] is a program id (`lv` and up to 18 digits, no leading 0).
  static bool isProgramId(String id) => _programId.hasMatch(id);

  /// Whether [id] is a user's room (`user/<id>`).
  static bool isUserRoomId(String id) => _userRoomId.hasMatch(id);

  /// Whether [id] is a channel's room (`ch<n>`).
  static bool isChannelRoomId(String id) => _channelRoomId.hasMatch(id);

  /// Whether [id] is a broadcaster's room: a user or a channel.
  static bool isBroadcasterRoomId(String id) => isUserRoomId(id) || isChannelRoomId(id);

  /// Whether [id] is a room: a broadcaster or a program.
  static bool isRoomId(String id) => isProgramId(id) || isBroadcasterRoomId(id);

  /// The watch page of a room (a broadcaster's latest program, or the
  /// program itself).
  static Uri watchPage(String roomId) => Uri.parse('$origin/watch/${roomId.trim()}');

  /// The room of a program: a user's program (provider type `community` or
  /// `user`) is `user/<id>`; a channel's program (`channel`, [channelId] its
  /// social group `ch<n>`) is the channel; anything else, an official program
  /// included, is the program itself ([programId]).
  static String roomIdOf({required String programId, Object? providerType, Object? userId, Object? channelId}) {
    final user = userId is int ? '$userId' : (userId is String ? userId : '');
    if ((providerType == 'community' || providerType == 'user') && _userId.hasMatch(user)) return 'user/$user';
    if (providerType == 'channel' && channelId is String && isChannelRoomId(channelId)) return channelId;
    return programId;
  }

  /// The recent-programs page of [tab], page [page] (offset = page − 1).
  static Uri recentPrograms(String tab, int page) => Uri.https(
    'live.nicovideo.jp',
    '/front/api/pages/recent/v1/programs',
    {'tab': tab, 'offset': '${page - 1}', 'sortOrder': 'recentDesc'},
  );

  /// The on-air search for [keyword], page [page].
  static Uri searchPrograms(String keyword, int page) => Uri.https(
    'live.nicovideo.jp',
    '/front/api/pages/search/v1/programs',
    {'keyword': keyword, 'column': 'main', 'status': 'onair', 'page': '$page', 'disableGrouping': 'true'},
  );
}
