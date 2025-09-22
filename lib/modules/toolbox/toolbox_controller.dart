import 'package:dio/dio.dart' as dio;
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/routes/app_navigation.dart';

class ToolBoxController extends GetxController {
  final TextEditingController roomJumpToController = TextEditingController();
  final TextEditingController getUrlController = TextEditingController();

  void jumpToRoom(String e) async {
    if (e.isEmpty) {
      SmartDialog.showToast(S.current.link_empty);
      return;
    }
    var parseResult = await parse(e);
    if (parseResult.isEmpty || parseResult.first == "") {
      SmartDialog.showToast(S.current.live_room_link_parse_failed);
      return;
    }
    String platform = parseResult[1];

    AppNavigator.toLiveRoomDetail(
      liveRoom: LiveRoom(
        roomId: parseResult.first,
        platform: platform,
        title: "",
        cover: '',
        nick: "",
        watching: '',
        avatar: "",
        area: '',
        liveStatus: LiveStatus.live,
        status: true,
        data: '',
        danmakuData: '',
      ),
    );
  }

  void getPlayUrl(String e) async {
    if (e.isEmpty) {
      SmartDialog.showToast(S.current.link_empty);
      return;
    }
    var parseResult = await parse(e);
    if (parseResult.isEmpty && parseResult.first == "") {
      SmartDialog.showToast(S.current.live_room_link_parse_failed);
      return;
    }
    String platform = parseResult[1];
    try {
      SmartDialog.showLoading(msg: "");
      var detail = LiveRoom(roomId: parseResult.first, platform: platform);
      detail = await Sites.of(platform).liveSite.getRoomDetail(detail: detail);
      var qualites = await Sites.of(platform).liveSite.getPlayQualites(detail: detail);
      SmartDialog.dismiss(status: SmartStatus.loading);
      if (qualites.isEmpty) {
        SmartDialog.showToast(S.current.live_room_clarity_parse_failed);

        return;
      }
      var result = await Get.dialog(SimpleDialog(
        title: Text(S.current.live_room_clarity_select),
        children: qualites
            .map(
              (e) => ListTile(
                title: Text(
                  e.quality,
                  textAlign: TextAlign.center,
                ),
              )
              .toList(),
        ),
      );
      if (result == null) {
        return;
      }
      SmartDialog.showLoading(msg: "");
      var playUrls = await Sites.of(platform).liveSite.getPlayUrls(detail: detail, quality: result);
      SmartDialog.dismiss(status: SmartStatus.loading);
      await Get.dialog(SimpleDialog(
        title: Text(S.current.live_room_clarity_line_select),
        children: playUrls
            .map(
              (e) => ListTile(
                title: Text(
                  "${S.current.live_room_clarity_line} ${playUrls.indexOf(e) + 1}",
                ),
                subtitle: Text(
                  e.playUrl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: e.playUrl));
                  Navigator.of(Get.context!).pop();
                  SmartDialog.showToast(S.current.live_room_link_direct_copied);
                },
              ),
            )
            .toList(),
      ));
    } catch (e) {
      CoreLog.error(e);
      SmartDialog.showToast(S.current.live_room_link_direct_read_failed);
    } finally {
      SmartDialog.dismiss(status: SmartStatus.loading);
    }
  }

  Future<List> parse(String url) async {
    final urlRegExp = RegExp(r"((https?:www\.)|(https?:\/\/)|(www\.))[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9]{1,6}(\/[-a-zA-Z0-9()@:%_\+.~#?&\/=]*)?");
    List<String?> urlMatches = urlRegExp.allMatches(url).map((m) => m.group(0)).toList();
    if (urlMatches.isEmpty) return [];
    String realUrl = urlMatches.first!;
    realUrl = urlMatches.first!;

    for(var site in Sites.supportSites) {
      var liveSite = site.liveSite;
      var parse = await liveSite.parse(realUrl);
      if(parse.roomId.isNotEmpty) {
        return [parse.roomId, parse.platform];
      }
    }
    return [];
  }



  Future<String> getLocation(String url) async {
    try {
      if (url.isEmpty) return "";
      await dio.Dio().get(url, options: dio.Options(followRedirects: false));
    } on dio.DioException catch (e) {
      CoreLog.error(e);
      if (e.response!.statusCode == 302) {
        var redirectUrl = e.response!.headers.value("Location");
        if (redirectUrl != null) {
          return redirectUrl;
        }
      }
    } catch (e) {
      CoreLog.error(e);
    }
    return "";
  }
}

class RegExpBean {
  late RegExp regExp;
  late String siteType;

  RegExpBean({
    required this.regExp,
    required this.siteType,
  });
}
