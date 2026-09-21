import 'package:pure_live/core/site/niconico/niconico_link.dart';
import 'package:pure_live/core/site/weibo/weibo_link.dart';
import 'package:pure_live/core/sites.dart';
import 'package:pure_live/core/site/huajiao/huajiao_link.dart';
import 'package:pure_live/core/site/picarto/picarto_api.dart';
import 'package:pure_live/core/site/twitcasting/twitcasting_api.dart';
import 'package:pure_live/core/site/missevan/missevan_api.dart';
import 'package:pure_live/core/site/inke/inke_api.dart';
import 'package:pure_live/core/site/kilakila/kilakila_link.dart';
import 'package:pure_live/core/site/showroom/showroom_link.dart';
import 'package:pure_live/core/site/chzzk/chzzk_link.dart';
import 'package:pure_live/core/site/kick/kick_link.dart';
import 'package:pure_live/core/site/liveme/liveme_link.dart';
import 'package:pure_live/core/site/tiktok/tiktok_link.dart';
import 'package:pure_live/core/site/youtube/youtube_link.dart';
import 'package:pure_live/core/site/bigo/bigo_link.dart';
import 'package:pure_live/core/site/seventeenlive/seventeenlive_link.dart';

class WebSearchRoomTarget {
  const WebSearchRoomTarget({required this.platform, required this.roomId});

  final String platform;
  final String roomId;

  String get key => '$platform:$roomId';
}

/// Converts a supported platform room URL into the adapter identity used by
/// native playback. Search/category/account URLs are deliberately ignored.
class WebSearchRoomParser {
  const WebSearchRoomParser._();

  static const Set<String> _reservedSegments = {
    'search',
    'category',
    'categories',
    'directory',
    'directories',
    'game',
    'games',
    'video',
    'videos',
    'user',
    'users',
    'index',
    'topic',
    'topics',
    'downloads',
    'settings',
    'login',
    'signup',
  };

  static WebSearchRoomTarget? parse(String rawUrl) {
    final niconico = NiconicoLink.parse(rawUrl);
    if (niconico != null) return WebSearchRoomTarget(platform: Sites.niconicoSite, roomId: niconico);
    // Broadcast shares need asynchronous owner lookup in LiveUrlTool. Only
    // verified owner links can be mapped synchronously to a durable app ID.
    final huajiao = HuajiaoLink.parse(rawUrl);
    if (huajiao?.kind == HuajiaoLinkKind.owner) {
      return WebSearchRoomTarget(platform: Sites.huajiaoSite, roomId: huajiao!.id);
    }
    final kilakila = KilakilaLink.parse(rawUrl.trim());
    if (kilakila?.kind == KilakilaLinkKind.owner) {
      return WebSearchRoomTarget(platform: Sites.kilakilaSite, roomId: kilakila!.id);
    }
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) return null;
    // Bare composite IDs belong to exact search, not web navigation. Preserve
    // the raw URL for the adapter's structural dot-segment checks.
    final weibo = WeiboLink.parse(rawUrl);
    if (weibo != null) return WebSearchRoomTarget(platform: Sites.weiboSite, roomId: weibo);
    final missevan = MissevanApi.roomFromUri(uri);
    final inke = InkeApi.roomFromUri(uri);
    if (inke != null) return WebSearchRoomTarget(platform: Sites.inkeSite, roomId: inke);
    if (missevan != null) return WebSearchRoomTarget(platform: Sites.missevanSite, roomId: missevan);
    final picarto = PicartoApi.channelFromUri(uri);
    if (picarto != null) return WebSearchRoomTarget(platform: Sites.picartoSite, roomId: picarto);
    final twitcasting = TwitcastingApi.channelFromUri(uri);
    if (twitcasting != null) return WebSearchRoomTarget(platform: Sites.twitcastingSite, roomId: twitcasting);
    final showroom = ShowroomLink.parse(rawUrl);
    if (showroom != null) return WebSearchRoomTarget(platform: Sites.showroomSite, roomId: showroom);
    final chzzk = ChzzkLink.parse(rawUrl);
    if (chzzk != null) return WebSearchRoomTarget(platform: Sites.chzzkSite, roomId: chzzk);
    final kick = KickLink.parse(rawUrl);
    if (kick != null) return WebSearchRoomTarget(platform: Sites.kickSite, roomId: kick);
    final seventeenLive = SeventeenLiveLink.parse(rawUrl);
    if (seventeenLive != null) {
      return WebSearchRoomTarget(platform: Sites.seventeenLiveSite, roomId: seventeenLive);
    }
    final liveMe = LiveMeLink.parseDurableRoomId(rawUrl);
    if (liveMe != null) return WebSearchRoomTarget(platform: Sites.liveMeSite, roomId: liveMe);
    final tiktok = TikTokLink.parseDurableUsername(rawUrl);
    if (tiktok != null) return WebSearchRoomTarget(platform: Sites.tiktokSite, roomId: tiktok);
    final youtube = YouTubeLink.parseDurableVideoId(rawUrl);
    if (youtube != null) return WebSearchRoomTarget(platform: Sites.youtubeSite, roomId: youtube);
    final bigo = BigoLink.parse(rawUrl);
    if (bigo != null) return WebSearchRoomTarget(platform: Sites.bigoSite, roomId: bigo);
    final host = uri.host.toLowerCase();
    final segments = uri.pathSegments.where((segment) => segment.trim().isNotEmpty).toList(growable: false);

    if (_matchesHost(host, 'huya.com')) {
      return _firstSegment(segments, Sites.huyaSite, RegExp(r'^[a-zA-Z0-9_-]+$'));
    }
    if (host == 'live.douyin.com') {
      return _firstSegment(segments, Sites.douyinSite, RegExp(r'^\d+$'));
    }
    if (_matchesHost(host, 'douyu.com')) {
      return _firstSegment(segments, Sites.douyuSite, RegExp(r'^\d+$'));
    }
    if (host == 'live.kuaishou.com') {
      if (segments.length < 2 || segments.first.toLowerCase() != 'u') return null;
      return _target(Sites.kuaishouSite, segments[1], RegExp(r'^[a-zA-Z0-9_-]+$'));
    }
    if (host == 'cc.163.com') {
      return _firstSegment(segments, Sites.ccSite, RegExp(r'^\d+$'));
    }
    if (host == 'live.bilibili.com') {
      return _firstSegment(segments, Sites.bilibiliSite, RegExp(r'^\d+$'));
    }
    if (_matchesHost(host, 'twitch.tv')) {
      return _firstSegment(segments, Sites.twitchSite, RegExp(r'^[a-zA-Z0-9_]+$'));
    }
    if (_matchesHost(host, 'sooplive.co.kr')) {
      return _firstSegment(segments, Sites.soopSite, RegExp(r'^[a-zA-Z0-9_-]+$'));
    }
    if (_matchesHost(host, 'yy.com')) {
      return _firstSegment(segments, Sites.yySite, RegExp(r'^\d+$'));
    }
    if (host == 'live.acfun.cn' && uri.userInfo.isEmpty && segments.length == 2 && segments.first == 'live') {
      return _target(Sites.acfunSite, segments[1], RegExp(r'^[1-9][0-9]{0,19}$'));
    }
    return null;
  }

  static bool _matchesHost(String host, String root) => host == root || host.endsWith('.$root');

  static WebSearchRoomTarget? _firstSegment(List<String> segments, String platform, RegExp pattern) {
    if (segments.isEmpty) return null;
    return _target(platform, segments.first, pattern);
  }

  static bool isRoomIdentifier(String roomId, RegExp pattern) =>
      roomId.isNotEmpty && !_reservedSegments.contains(roomId.toLowerCase()) && pattern.hasMatch(roomId);

  static WebSearchRoomTarget? _target(String platform, String rawRoomId, RegExp pattern) {
    final roomId = rawRoomId.trim();
    if (!isRoomIdentifier(roomId, pattern)) return null;
    return WebSearchRoomTarget(platform: platform, roomId: roomId);
  }
}
