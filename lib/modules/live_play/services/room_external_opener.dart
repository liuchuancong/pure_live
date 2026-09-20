import 'package:pure_live/core/site/niconico/niconico_link.dart';
import 'package:pure_live/core/site/weibo/weibo_api.dart';
import 'package:pure_live/core/site/weibo/weibo_link.dart';
import 'package:pure_live/core/site/niconico/niconico_watch.dart';
import 'package:pure_live/core/site/tting/tting_link.dart';
import 'package:pure_live/core/site/xiaohongshu/xiaohongshu_link.dart';
import 'package:pure_live/core/site/openrec/openrec_link.dart';
import 'package:pure_live/core/site/openrec/openrec_api.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/danmaku/douyin_danmaku.dart';
import 'package:pure_live/core/danmaku/huya_danmaku.dart';
import 'package:pure_live/core/site/inke/inke_site.dart';
import 'package:pure_live/core/site/kilakila/kilakila_site.dart';
import 'package:pure_live/core/sites.dart';
import 'package:pure_live/core/site/huajiao/huajiao_link.dart';
import 'package:pure_live/core/site/showroom/showroom_link.dart';
import 'package:pure_live/core/site/chzzk/chzzk_link.dart';
import 'package:pure_live/core/site/kick/kick_link.dart';
import 'package:pure_live/core/site/liveme/liveme_link.dart';
import 'package:pure_live/core/site/tiktok/tiktok_link.dart';
import 'package:pure_live/core/site/seventeenlive/seventeenlive_link.dart';
import 'package:url_launcher/url_launcher_string.dart';

enum RoomExternalOpenResult { opened, unavailable, failed, cancelled }

/// Resolved once per user action. Never passes a relative/empty URL to the OS.
class RoomExternalTarget {
  const RoomExternalTarget({required this.web, this.native});
  final String web;
  final String? native;
}

typedef RoomExternalLauncher = Future<bool> Function(String url);

class RoomExternalOpener {
  static String? _id(String? value) {
    final id = value?.trim();
    if (id == null || id.isEmpty || id == '.' || id == '..' || RegExp(r'[\s\x00-\x1f/\\?#%]').hasMatch(id)) {
      return null;
    }
    return id;
  }

  static RoomExternalTarget? resolve(String site, LiveRoom room) {
    if (site == Sites.inkeSite) {
      // Preserve Inke's verified UID/broadcast link and official-home fallback.
      return RoomExternalTarget(web: InkeSite.externalRoomUrl(room));
    }
    final id = _id(room.roomId);
    if (id == null) return null;
    final path = Uri.encodeComponent(id);
    switch (site) {
      case Sites.weiboSite:
        try {
          return RoomExternalTarget(web: WeiboLink.url(id));
        } on WeiboException {
          return null;
        }
      case Sites.niconicoSite:
        try {
          return RoomExternalTarget(web: NiconicoLink.url(id));
        } on NiconicoException {
          return null;
        }
      case Sites.showroomSite:
        try {
          return RoomExternalTarget(web: ShowroomLink.roomUrl(id));
        } on FormatException {
          return null;
        }
      case Sites.chzzkSite:
        try {
          return RoomExternalTarget(web: ChzzkLink.url(id));
        } on FormatException {
          return null;
        }
      case Sites.kickSite:
        try {
          return RoomExternalTarget(web: KickLink.url(id));
        } on FormatException {
          return null;
        }
      case Sites.seventeenLiveSite:
        try {
          return RoomExternalTarget(web: SeventeenLiveLink.url(id));
        } on FormatException {
          return null;
        }
      case Sites.liveMeSite:
        try {
          return RoomExternalTarget(web: LiveMeLink.url(id));
        } on FormatException {
          return null;
        }
      case Sites.tiktokSite:
        try {
          return RoomExternalTarget(web: TikTokLink.url(id));
        } on FormatException {
          return null;
        }
      case Sites.xiaohongshuSite:
        final broadcast = XiaohongshuLink.parse(id);
        return broadcast == null ? null : RoomExternalTarget(web: XiaohongshuLink.url(broadcast));
      case Sites.ttingSite:
        final channel = TtingLink.parse(id);
        return channel == null ? null : RoomExternalTarget(web: TtingLink.url(channel));
      case Sites.openrecSite:
        try {
          return RoomExternalTarget(web: OpenrecRoomKey.parse(id).url);
        } on OpenrecException {
          return null;
        }
      case Sites.huajiaoSite:
        if (!HuajiaoLink.validId(id)) return null;
        return RoomExternalTarget(web: HuajiaoLink.ownerUrl(id));
      case Sites.kilakilaSite:
        if (!RegExp(r'^[1-9][0-9]{0,31}$').hasMatch(id)) return null;
        return RoomExternalTarget(web: KilakilaSite.ownerUrl(id));
      case Sites.yySite:
        if (!RegExp(r'^[0-9]+$').hasMatch(id)) return null;
        return RoomExternalTarget(web: 'https://www.yy.com/$path');
      case Sites.bilibiliSite:
        return RoomExternalTarget(web: 'https://live.bilibili.com/$path', native: 'bilibili://live/$path');
      case Sites.douyinSite:
        final args = room.danmakuData;
        final webId = args is DouyinDanmakuArgs ? _id(args.webRid) ?? id : id;
        final nativeId = args is DouyinDanmakuArgs ? _id(args.roomId) : null;
        return RoomExternalTarget(
          web: 'https://live.douyin.com/${Uri.encodeComponent(webId)}',
          native: nativeId == null ? null : 'snssdk1128://webcast_room?room_id=${Uri.encodeComponent(nativeId)}',
        );
      case Sites.huyaSite:
        final args = room.danmakuData;
        return RoomExternalTarget(
          web: 'https://www.huya.com/$path',
          // Keep the existing native protocol mapping; missing optional chat
          // metadata must not prevent the independent official webpage action.
          native: args is HuyaDanmakuArgs && args.subSid > 0
              ? 'yykiwi://homepage/index.html?banneraction=https%3A%2F%2Fdiy-front.cdn.huya.com%2Fzt%2Ffrontpage%2Fcc%2Fupdate.html%3Fhyaction%3Dlive%26channelid%3D${args.subSid}%26subid%3D${args.subSid}%26liveuid%3D${args.subSid}%26screentype%3D1%26sourcetype%3D0%26fromapp%3Dhuya_wap%252Fclick%252Fopen_app_guide%26&fromapp=huya_wap/click/open_app_guide'
              : null,
        );
      case Sites.douyuSite:
        return RoomExternalTarget(
          web: 'https://www.douyu.com/$path',
          native: 'douyulink://?type=90001&schemeUrl=douyuapp%3A%2F%2Froom%3FliveType%3D0%26rid%3D$path',
        );
      case Sites.ccSite:
        final user = _id(room.userId);
        return RoomExternalTarget(
          web: 'https://cc.163.com/$path',
          native: user == null ? null : 'cc://join-room/$path/${Uri.encodeComponent(user)}/',
        );
      case Sites.twitchSite:
        return RoomExternalTarget(web: 'https://www.twitch.tv/$path');
      case Sites.soopSite:
        return RoomExternalTarget(web: 'https://play.sooplive.co.kr/$path');
      case Sites.picartoSite:
        return RoomExternalTarget(web: 'https://picarto.tv/$path');
      case Sites.twitcastingSite:
        return RoomExternalTarget(web: 'https://twitcasting.tv/$path');
      case Sites.missevanSite:
        return RoomExternalTarget(web: 'https://fm.missevan.com/live/$path');
      case Sites.acfunSite:
        return RoomExternalTarget(web: 'https://live.acfun.cn/live/$path');
      case Sites.kuaishouSite:
        final stream = room.link?.trim() ?? '';
        final encoded = Uri.encodeQueryComponent(stream);
        return RoomExternalTarget(
          web: 'https://live.kuaishou.com/u/$path',
          native: stream.isEmpty
              ? null
              : 'kwai://liveaggregatesquare?liveStreamId=$encoded&recoStreamId=$encoded&recoLiveStreamId=$encoded&liveSquareSource=28&path=/rest/n/live/feed/sharePage/slide/more&mt_product=H5_OUTSIDE_CLIENT_SHARE',
        );
      default:
        // IPTV has media locations, not an official room webpage. Never forward
        // an arbitrary imported link or an empty string as a shell target.
        return null;
    }
  }

  static Future<bool> _launch(String url) => launchUrlString(url, mode: LaunchMode.externalApplication);

  static Future<RoomExternalOpenResult> open({
    required String site,
    required LiveRoom room,
    required bool android,
    RoomExternalLauncher? launch,
    bool Function()? isCurrent,
    void Function()? onBrowserFallback,
  }) async {
    bool current() => isCurrent?.call() ?? true;
    if (!current()) return RoomExternalOpenResult.cancelled;
    final target = resolve(site, room);
    if (target == null) return RoomExternalOpenResult.unavailable;
    final launcher = launch ?? _launch;
    Future<bool> attempt(String url) async {
      try {
        return await launcher(url);
      } catch (_) {
        // Never log targets; they may include platform share parameters.
        return false;
      }
    }

    final native = android ? target.native : null;
    if (native != null && native != target.web) {
      final opened = await attempt(native);
      if (!current()) return RoomExternalOpenResult.cancelled;
      if (opened) return RoomExternalOpenResult.opened;
      onBrowserFallback?.call();
      if (!current()) return RoomExternalOpenResult.cancelled;
    }
    final opened = await attempt(target.web);
    if (!current()) return RoomExternalOpenResult.cancelled;
    return opened ? RoomExternalOpenResult.opened : RoomExternalOpenResult.failed;
  }
}
