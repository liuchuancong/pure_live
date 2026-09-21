import 'package:pure_live/core/site/niconico/niconico_link.dart';
import 'package:pure_live/core/site/weibo/weibo_link.dart';
import 'package:pure_live/core/site/tting/tting_link.dart';
import 'package:pure_live/core/site/xiaohongshu/xiaohongshu_link.dart';
import 'package:pure_live/core/site/openrec/openrec_api.dart';
import 'package:pure_live/core/site/openrec/openrec_link.dart';
import 'package:dio/dio.dart' as dio;
import 'package:pure_live/core/site/huajiao/huajiao_api.dart';
import 'package:pure_live/core/site/huajiao/huajiao_link.dart';
import 'package:pure_live/core/site/missevan/missevan_api.dart';
import 'package:pure_live/core/site/inke/inke_api.dart';
import 'package:pure_live/core/site/kilakila/kilakila_api.dart';
import 'package:pure_live/core/site/kilakila/kilakila_link.dart';
import 'package:pure_live/core/site/showroom/showroom_link.dart';
import 'package:pure_live/core/site/chzzk/chzzk_link.dart';
import 'package:pure_live/core/site/kick/kick_link.dart';
import 'package:pure_live/core/site/liveme/liveme_api.dart';
import 'package:pure_live/core/site/liveme/liveme_link.dart';
import 'package:pure_live/core/site/tiktok/tiktok_api.dart';
import 'package:pure_live/core/site/tiktok/tiktok_link.dart';
import 'package:pure_live/core/site/youtube/youtube_api.dart';
import 'package:pure_live/core/site/youtube/youtube_link.dart';
import 'package:pure_live/core/site/bigo/bigo_link.dart';
import 'package:pure_live/core/site/pandalive/pandalive_link.dart';
import 'package:pure_live/core/site/popkontv/popkontv_link.dart';
import 'package:pure_live/core/site/shopeelive/shopeelive_link.dart';
import 'package:pure_live/core/site/vkvideolive/vkvideolive_link.dart';
import 'package:pure_live/core/site/nimotv/nimotv_link.dart';
import 'package:pure_live/core/site/dailymotion/dailymotion_link.dart';
import 'package:pure_live/core/site/rumble/rumble_link.dart';
import 'package:pure_live/core/site/goodgame/goodgame_link.dart';
import 'package:pure_live/core/site/fc2live/fc2_link.dart';
import 'package:pure_live/core/site/steambroadcast/steam_broadcast_link.dart';
import 'package:pure_live/core/site/jdlive/jd_live_link.dart';
import 'package:pure_live/core/site/taobaolive/taobao_live_api.dart';
import 'package:pure_live/core/site/taobaolive/taobao_live_link.dart';
import 'package:pure_live/core/site/seventeenlive/seventeenlive_link.dart';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/utils/live_short_link_session.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/modules/live_play/dialogs/known_room_link_dialog.dart';
import 'package:pure_live/modules/toolbox/toolbox_direct_link_flow.dart';
import 'package:pure_live/modules/search/web_search_room_parser.dart';

class LiveUrlTool {
  /// Extract complete HTTP URLs before inspecting host/path. This also avoids
  /// treating an embedded www address in an FTP URL as a second HTTP link.
  static Iterable<Uri> sharedHttpUris(String text) => sharedHttpUrls(text).map(Uri.parse);

  // Preserve signed URL spelling before Uri normalizes percent escapes.
  static Iterable<String> sharedHttpUrls(String text) sync* {
    final urls = RegExp(r'(?:[a-z][a-z0-9+.-]*://|www\.)[^\s<>]+', caseSensitive: false);
    for (final match in urls.allMatches(text)) {
      var candidate = match.group(0)!;
      if (candidate.toLowerCase().startsWith('www.')) candidate = 'https://$candidate';
      // XHS and Weibo shares append Chinese prose without whitespace.
      // Keep percent-encoded punctuation and other platforms' URL spelling.
      if ({
        'xhslink.com',
        'www.xiaohongshu.com',
        'xiaohongshu.com',
        'weibo.com',
        'www.weibo.com',
      }.contains(Uri.tryParse(candidate)?.host)) {
        candidate = candidate.split(RegExp(r'[，。！？、；：）》」』”’]')).first;
        candidate = candidate.replaceFirst(RegExp(r'''[,!?;:)\]}"']+$'''), '');
        // A terminal dot path component is URL structure, not prose punctuation.
        if (!candidate.endsWith('/.') && !candidate.endsWith('/..')) {
          candidate = candidate.replaceFirst(RegExp(r'\.+$'), '');
        }
      } else {
        candidate = candidate.replaceFirst(RegExp(r'''[.,!?;:)\]}。！？、，；：）》」』”’"']+$'''), '');
      }
      final uri = Uri.tryParse(candidate);
      if (uri == null ||
          uri.userInfo.isNotEmpty ||
          uri.host.isEmpty ||
          (uri.scheme != 'http' && uri.scheme != 'https')) {
        continue;
      }
      yield candidate;
    }
  }

  static bool _hostIs(String host, String root) => host == root || host.endsWith('.$root');

  static bool containsSupportedLink(String text) {
    const roots = {
      'bilibili.com',
      'b23.tv',
      'douyu.com',
      'huya.com',
      'douyin.com',
      'webcast.amemv.com',
      'live.kuaishou.com',
      'live.kuaishou.cn',
      'cc.163.com',
      'twitch.tv',
      'sooplive.com',
      'sooplive.co.kr',
      'yy.com',
      'live.acfun.cn',
      'picarto.tv',
      'twitcasting.tv',
      'showroom-live.com',
      'chzzk.naver.com',
      'kick.com',
    };
    return sharedHttpUrls(text).any((raw) {
      if (WeiboLink.parse(raw) != null ||
          NiconicoLink.parse(raw) != null ||
          XiaohongshuLink.parse(raw) != null ||
          XiaohongshuLink.shortUri(raw) != null ||
          TtingLink.parse(raw) != null ||
          OpenrecLink.parse(raw) != null ||
          HuajiaoLink.parse(raw) != null ||
          KilakilaLink.parse(raw) != null) {
        return true;
      }
      if (ShowroomLink.parse(raw) != null) return true;
      if (ChzzkLink.parse(raw) != null) return true;
      if (KickLink.parse(raw) != null) return true;
      if (SeventeenLiveLink.parse(raw) != null) return true;
      if (LiveMeLink.parse(raw) != null) return true;
      if (TikTokLink.parse(raw) != null) return true;
      if (YouTubeLink.parse(raw) != null) return true;
      if (BigoLink.parse(raw) != null) return true;
      if (PandaLiveLink.parse(raw) != null) return true;
      if (PopkonLink.parse(raw) != null) return true;
      if (ShopeeLiveLink.parse(raw) != null) return true;
      if (VkVideoLiveLink.parse(raw) != null) return true;
      if (DailymotionLink.parseVideoId(raw) != null) return true;
      if (RumbleLink.parseVideoKey(raw) != null) return true;
      if (GoodGameLink.parse(raw) != null) return true;
      if (Fc2Link.parseChannelId(raw) != null) return true;
      if (SteamBroadcastLink.parseSteamId(raw) != null) return true;
      if (JdLiveLink.parseLiveId(raw) != null) return true;
      if (TaobaoLiveLink.parse(raw) != null || TaobaoLiveLink.shortUri(raw) != null) return true;
      final uri = Uri.parse(raw);
      return TikTokLink.isShortHost(uri.host) ||
          InkeApi.roomFromUri(uri) != null ||
          MissevanApi.roomFromUri(uri) != null ||
          roots.any((root) => _hostIs(uri.host.toLowerCase(), root));
    });
  }

  static Future<List<String>> parseLiveUrl(
    String text, {
    dio.Dio Function()? clientFactory,
    dio.CancelToken? cancelToken,
    KilakilaApi? kilakilaApi,
    HuajiaoApi? huajiaoApi,
    OpenrecApi? openrecApi,
    LiveMeApi? liveMeApi,
    TikTokApi? tiktokApi,
    YouTubeApi? youtubeApi,
    TaobaoLiveApi? taobaoLiveApi,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    if (cancelToken?.isCancelled ?? false) return [];
    final session = LiveShortLinkSession(timeout: timeout, clientFactory: clientFactory);
    final ownedCancel = dio.CancelToken();
    try {
      final parsing = _parseLiveUrl(
        text,
        session,
        kilakilaApi ?? KilakilaApi(),
        huajiaoApi ?? HuajiaoApi(),
        openrecApi ?? OpenrecApi(),
        liveMeApi ?? LiveMeApi(),
        tiktokApi ?? TikTokApi(),
        youtubeApi ?? YouTubeApi(),
        taobaoLiveApi ?? TaobaoLiveApi(),
        ownedCancel,
      );
      final result = cancelToken == null
          ? parsing
          : Future.any<List<String>>([parsing, cancelToken.whenCancel.then((_) => <String>[])]);
      return await result.timeout(
        timeout,
        onTimeout: () {
          session.close();
          return <String>[];
        },
      );
    } finally {
      ownedCancel.cancel();
      session.close();
    }
  }

  static Future<List<String>> _parseLiveUrl(
    String text,
    LiveShortLinkSession session,
    KilakilaApi kilakilaApi,
    HuajiaoApi huajiaoApi,
    OpenrecApi openrecApi,
    LiveMeApi liveMeApi,
    TikTokApi tiktokApi,
    YouTubeApi youtubeApi,
    TaobaoLiveApi taobaoLiveApi,
    dio.CancelToken cancel,
  ) async {
    for (final raw in sharedHttpUrls(text)) {
      final uri = Uri.parse(raw);
      if (session.isClosed) return [];
      final host = uri.host.toLowerCase();
      final realUrl = raw;
      final xiaohongshu = await XiaohongshuLink.resolve(raw, session: session);
      if (xiaohongshu != null) return [xiaohongshu, Sites.xiaohongshuSite];
      final tting = TtingLink.parse(raw);
      if (tting != null) return ['$tting', Sites.ttingSite];
      final openrec = OpenrecLink.parse(raw);
      if (openrec != null) {
        late final OpenrecRoomKey key;
        if (openrec.kind == OpenrecLinkKind.channel) {
          final owner = await openrecApi.channel(openrec.id, cancel: cancel);
          key = OpenrecRoomKey.create(owner.id, owner.numericId);
        } else {
          final movie = await openrecApi.movie(openrec.id, cancel: cancel);
          key = OpenrecRoomKey.create(movie.channelId, movie.numericChannelId);
        }
        if (session.isClosed || cancel.isCancelled) return [];
        return [key.value, Sites.openrecSite];
      }
      final huajiao = HuajiaoLink.parse(raw);
      if (huajiao != null) {
        if (huajiao.kind == HuajiaoLinkKind.owner) return [huajiao.id, Sites.huajiaoSite];
        final ownerId = await huajiaoApi.broadcastOwnerId(huajiao.id, cancel: cancel);
        if (session.isClosed || cancel.isCancelled) return [];
        return [ownerId, Sites.huajiaoSite];
      }
      final kilakila = KilakilaLink.parse(raw);
      if (kilakila != null) {
        if (kilakila.kind == KilakilaLinkKind.owner) return [kilakila.id, Sites.kilakilaSite];
        final owner = await kilakilaApi.ownerFromLink(raw, cancel: cancel);
        if (session.isClosed || cancel.isCancelled) return [];
        return [owner.userId, Sites.kilakilaSite];
      }
      final liveMe = LiveMeLink.parse(raw);
      if (liveMe != null) {
        final shortId = await liveMeApi.resolveReference(liveMe, cancel: cancel);
        if (session.isClosed || cancel.isCancelled) return [];
        return [shortId, Sites.liveMeSite];
      }
      final tiktok = TikTokLink.parse(raw);
      if (tiktok != null) {
        final username = await tiktokApi.resolveReference(tiktok, cancel: cancel);
        if (session.isClosed || cancel.isCancelled) return [];
        return [username, Sites.tiktokSite];
      }
      final youtube = YouTubeLink.parse(raw);
      if (youtube != null) {
        final videoId = await youtubeApi.resolveReference(youtube, cancel: cancel);
        if (session.isClosed || cancel.isCancelled) return [];
        return [videoId, Sites.youtubeSite];
      }
      final bigo = BigoLink.parse(raw);
      if (bigo != null) return [bigo, Sites.bigoSite];
      final pandaLive = PandaLiveLink.parse(raw);
      if (pandaLive != null) return [pandaLive, Sites.pandaLiveSite];
      final popkon = PopkonLink.parse(raw);
      if (popkon != null) return [popkon.storageKey, Sites.popkonSite];
      final shopeeLive = ShopeeLiveLink.parse(raw);
      if (shopeeLive != null) return [shopeeLive.storageKey, Sites.shopeeLiveSite];
      final vkVideoLive = VkVideoLiveLink.parse(raw);
      if (vkVideoLive != null) return [vkVideoLive.storageKey, Sites.vkVideoLiveSite];
      final nimoTv = NimoTvLink.parse(raw);
      if (nimoTv != null) return [nimoTv.storageKey, Sites.nimoTvSite];
      final dailymotion = DailymotionLink.parseVideoId(raw);
      if (dailymotion != null) return [dailymotion, Sites.dailymotionSite];
      final rumble = RumbleLink.parseVideoKey(raw);
      if (rumble != null) return [rumble, Sites.rumbleSite];
      final goodGame = GoodGameLink.parse(raw);
      if (goodGame != null) return [goodGame.storageKey, Sites.goodGameSite];
      final fc2Live = Fc2Link.parseChannelId(raw);
      if (fc2Live != null) return [fc2Live, Sites.fc2LiveSite];
      final steamBroadcast = SteamBroadcastLink.parseSteamId(raw);
      if (steamBroadcast != null) return [steamBroadcast, Sites.steamBroadcastSite];
      final jdLive = JdLiveLink.parseLiveId(raw);
      if (jdLive != null) return [jdLive, Sites.jdLiveSite];
      final taobaoLive = TaobaoLiveLink.parse(raw);
      if (taobaoLive != null) return [taobaoLive.storageKey, Sites.taobaoLiveSite];
      if (TaobaoLiveLink.shortUri(raw) != null) {
        final identity = await taobaoLiveApi.resolveReference(raw, cancel: cancel);
        if (session.isClosed || cancel.isCancelled) return [];
        return [identity.storageKey, Sites.taobaoLiveSite];
      }
      late List<String> segments;
      try {
        segments = uri.pathSegments.where((part) => part.isNotEmpty).toList(growable: false);
      } on FormatException {
        continue;
      }
      if (segments.isEmpty) continue;
      if (TikTokLink.isShortHost(host)) {
        final response = await session.get(uri);
        final location = LiveShortLinkSession.redirectTarget(uri, response);
        if (location == null) continue;
        final target = await _parseLiveUrl(
          location.toString(),
          session,
          kilakilaApi,
          huajiaoApi,
          openrecApi,
          liveMeApi,
          tiktokApi,
          youtubeApi,
          taobaoLiveApi,
          cancel,
        );
        if (target.isNotEmpty) return target;
        continue;
      }
      if (_hostIs(host, 'b23.tv')) {
        final response = await session.get(uri);
        final location = LiveShortLinkSession.redirectTarget(uri, response);
        if (location == null) continue;
        final target = await _parseLiveUrl(
          location.toString(),
          session,
          kilakilaApi,
          huajiaoApi,
          openrecApi,
          liveMeApi,
          tiktokApi,
          youtubeApi,
          taobaoLiveApi,
          cancel,
        );
        if (target.isNotEmpty) return target;
        continue;
      }
      if (host == 'v.douyin.com') {
        final id = await _getRealDouyinRoomId(uri, session);
        if (id.isNotEmpty) return [id, Sites.douyinSite];
        continue;
      }
      final target = WebSearchRoomParser.parse(realUrl);
      if (target != null) return [target.roomId, target.platform];
      // Preserve manual-tool aliases not exposed by the web-search parser.
      String? platform;
      String? id;
      var pattern = RegExp(r'^[a-zA-Z0-9_-]+$');
      if (_hostIs(host, 'bilibili.com')) {
        platform = Sites.bilibiliSite;
        id = segments.first;
        pattern = RegExp(r'^\d+$');
      } else if (_hostIs(host, 'douyu.com')) {
        platform = Sites.douyuSite;
        id = segments.first;
      } else if (host == 'www.douyin.com') {
        platform = Sites.douyinSite;
        id = segments.last;
      } else if (host == 'webcast.amemv.com') {
        platform = Sites.douyinSite;
        id = RegExp(r'(?:^|/)reflow/(\d+)(?:/|$)').firstMatch(uri.path)?.group(1);
      } else if (host == 'live.kuaishou.cn' && segments.length >= 2 && segments.first == 'u') {
        platform = Sites.kuaishouSite;
        id = segments[1];
      } else if (host == 'cc.163.com') {
        platform = Sites.ccSite;
        id = segments.first;
      } else if (_hostIs(host, 'sooplive.com')) {
        platform = Sites.soopSite;
        id = segments.first;
      }
      if (platform != null && id != null && WebSearchRoomParser.isRoomIdentifier(id, pattern)) {
        return [id, platform];
      }
    }
    return [];
  }

  static Future<String> _getRealDouyinRoomId(Uri uri, LiveShortLinkSession session) async {
    const headers = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      'Accept': '*/*',
      'Origin': 'https://live.douyin.com',
      'Referer': 'https://live.douyin.com/',
    };
    var current = uri;
    while (!session.isClosed) {
      final host = current.host.toLowerCase();
      if (host == 'live.douyin.com') {
        try {
          return WebSearchRoomParser.parse(current.toString())?.roomId ?? '';
        } on FormatException {
          return '';
        }
      }
      if (host != 'v.douyin.com' && host != 'www.douyin.com' && host != 'webcast.amemv.com') return '';
      final roomId = RegExp(r'(?:^|/)reflow/(\d+)(?:/|$)').firstMatch(current.path)?.group(1);
      if (roomId != null && host != 'v.douyin.com') {
        final info = await session.get(
          Uri.https('webcast.amemv.com', '/webcast/room/reflow/info/', {
            'room_id': roomId,
            'verifyFp': '',
            'type_id': '0',
            'live_id': '1',
            'sec_user_id': '',
            'app_id': '1128',
          }),
          json: true,
          headers: headers,
        );
        final payload = info?.data;
        if (info?.statusCode != 200 || payload is! Map) return '';
        final data = payload['data'];
        if (data is! Map) return '';
        final room = data['room'];
        if (room is! Map) return '';
        final owner = room['owner'];
        if (owner is! Map) return '';
        final raw = owner['web_rid'];
        if (raw is! String && raw is! int) return '';
        final id = raw.toString();
        return RegExp(r'^\d+$').hasMatch(id) ? id : '';
      }
      final response = await session.get(current, headers: headers);
      final target = LiveShortLinkSession.redirectTarget(current, response);
      if (target == null) return '';
      current = target;
    }
    return '';
  }

  static Future<void> getPlayUrlByRoomId({
    required BuildContext context,
    required String roomId,
    required String platform,
    LiveSite Function(String)? siteFor,
    bool Function()? isCurrentRoom,
    void Function(String)? notify,
  }) => _showKnownRoomAction(
    context: context,
    roomId: roomId,
    platform: platform,
    cast: false,
    siteFor: siteFor,
    isCurrentRoom: isCurrentRoom,
    notify: notify,
  );

  static Future<void> castPlayUrlByRoomId({
    required BuildContext context,
    required String roomId,
    required String platform,
    LiveSite Function(String)? siteFor,
    bool Function()? isCurrentRoom,
    void Function(String)? notify,
    Future<void> Function(String)? openCast,
  }) => _showKnownRoomAction(
    context: context,
    roomId: roomId,
    platform: platform,
    cast: true,
    siteFor: siteFor,
    isCurrentRoom: isCurrentRoom,
    notify: notify,
    openCast: openCast,
  );

  static Future<void> _showKnownRoomAction({
    required BuildContext context,
    required String roomId,
    required String platform,
    required bool cast,
    LiveSite Function(String)? siteFor,
    bool Function()? isCurrentRoom,
    void Function(String)? notify,
    Future<void> Function(String)? openCast,
  }) {
    if (!context.mounted) return Future.value();
    final showNotice = notify ?? ((String key) => ToastUtil.show(i18n(key)));
    roomId = roomId.trim();
    platform = platform.trim().toLowerCase();
    if (roomId.isEmpty || platform.isEmpty) {
      showNotice('toolbox_empty_link');
      return Future.value();
    }
    if (!Sites.isSupported(platform)) {
      showNotice('toolbox_parse_failed');
      return Future.value();
    }
    return KnownRoomLinkDialog.show(
      context: context,
      room: LiveRoom(roomId: roomId, platform: platform),
      cast: cast,
      flow: ToolBoxDirectLinkFlow(siteFor: siteFor),
      isCurrentRoom: isCurrentRoom ?? (() => true),
      notify: showNotice,
      openCast: openCast,
    );
  }
}

extension StringTrim on String {
  String trimEndChar(String char) {
    if (endsWith(char)) return substring(0, length - 1);
    return this;
  }
}
