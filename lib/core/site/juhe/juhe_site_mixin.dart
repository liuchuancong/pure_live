import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/interface/live_site_mixin.dart';
import 'package:pure_live/core/sites.dart';

mixin JuheSiteMixin on SiteAccount, SiteVideoHeaders, SiteOpen, SiteParse {
  var platform =  Sites.juheSite;
  /// ------------------ 登录
  @override
  bool isSupportLogin() => false;

  @override
  String getJumpToNativeUrl(LiveRoom liveRoom) {
    try {
      return "";
    } catch (e) {
      return "";
    }
  }

  @override
  String getJumpToWebUrl(LiveRoom liveRoom) {
    try {
      return "${liveRoom.link}";
    } catch (e) {
      return "";
    }
  }

  @override
  Future<SiteParseBean> parse(String url) async {
    String realUrl = getHttpUrl(url);
    var siteParseBean = emptySiteParseBean;
    if(realUrl.isEmpty) return siteParseBean;
    // 解析跳转
    List<RegExp> regExpJumpList = [
      // 网站 解析跳转
    ];
    siteParseBean = await parseJumpUrl(regExpJumpList, realUrl);
    if(siteParseBean.roomId.isNotEmpty) {
      return siteParseBean;
    }

    List<RegExp> regExpBeanList = [
    ];
    siteParseBean = await parseUrl(regExpBeanList, realUrl, platform);
    return siteParseBean;
  }
}
