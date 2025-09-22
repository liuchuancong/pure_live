import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/interface/live_site_mixin.dart';
import 'package:pure_live/core/sites.dart';

mixin SiteMixin on SiteAccount, SiteVideoHeaders, SiteOpen, SiteParse {
  var platform =  Sites.iptvSite;
  /// ------------------ 登录
  @override
  bool isSupportLogin() => false;

  @override
  String getJumpToNativeUrl(LiveRoom liveRoom) {
    try {
      return "${liveRoom.roomId}";
    } catch (e) {
      return "";
    }
  }

  @override
  String getJumpToWebUrl(LiveRoom liveRoom) {
    try {
      return "${liveRoom.roomId}";
    } catch (e) {
      return "";
    }
  }

  @override
  Future<SiteParseBean> parse(String url) async {
    String realUrl = getHttpUrl(url);
    var siteParseBean = emptySiteParseBean;
    if(realUrl.isEmpty) return siteParseBean;
    var playUrlRegExp = RegExp(r"(\.m3u8(\?.*)?$|\.flv(\?.*)?$|\.mp4(\?.*)?$)");
    List<String?> urlMatches = playUrlRegExp.allMatches(realUrl).map((m) => m.group(0)).toList();
    if (urlMatches.isEmpty) return emptySiteParseBean;
    siteParseBean = SiteParseBean(roomId: realUrl, platform: platform);
    return siteParseBean;
  }
}
