import 'dart:developer';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/services.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/routes/app_navigation.dart';

class ToolBoxController extends GetxController {
  final TextEditingController roomJumpToController = TextEditingController();
  final TextEditingController getUrlController = TextEditingController();

  void jumpToRoom(String e) async {
    if (e.isEmpty) {
      ToastUtil.show(i18n("toolbox_empty_link"));
      return;
    }
    var parseResult = await parse(e);
    if (parseResult.isEmpty || parseResult.first == "") {
      ToastUtil.show(i18n("toolbox_parse_failed"));
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();

    Future.delayed(const Duration(milliseconds: 200), () {
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
    });
  }

  void getPlayUrl(String e) async {
    if (e.isEmpty) {
      ToastUtil.show(i18n("toolbox_empty_link"));
      return;
    }
    var parseResult = await parse(e);
    if (parseResult.isEmpty && parseResult.first == "") {
      ToastUtil.show(i18n("toolbox_quality_failed"));
      return;
    }
    String platform = parseResult[1];
    try {
      SmartDialog.showLoading(msg: "");
      var detail = await Sites.of(platform).liveSite.getRoomDetail(roomId: parseResult.first, platform: platform);
      var qualites = await Sites.of(platform).liveSite.getPlayQualites(detail: detail);
      SmartDialog.dismiss(status: SmartStatus.loading);
      if (qualites.isEmpty) {
        ToastUtil.show(i18n("toolbox_quality_failed"));

        return;
      }
      var result = await Get.dialog(
        SimpleDialog(
          title: Text(i18n("toolbox_select_quality")),
          children: qualites
              .map(
                (e) => ListTile(
                  title: Text(e.quality, textAlign: TextAlign.center),
                  onTap: () {
                    Navigator.of(Get.context!).pop(e);
                  },
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
      await Get.dialog(
        SimpleDialog(
          title: Text(i18n("toolbox_select_line")),
          children: playUrls
              .map(
                (e) => ListTile(
                  title: Text(i18n("toolbox_line", args: {"index": "${playUrls.indexOf(e) + 1}"})),
                  subtitle: Text(e, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: e));
                    Navigator.of(Get.context!).pop();
                    ToastUtil.show(i18n("toolbox_copy_success"));
                  },
                ),
              )
              .toList(),
        ),
      );
    } catch (e) {
      ToastUtil.show(i18n("toolbox_get_url_failed"));
    } finally {
      SmartDialog.dismiss(status: SmartStatus.loading);
    }
  }

  Future<List> parse(String url) async {
    final urlRegExp = RegExp(
      r"((https?:www\.)|(https?:\/\/)|(www\.))[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9]{1,6}(\/[-a-zA-Z0-9()@:%_\+.~#?&\/=]*)?",
    );
    List<String?> urlMatches = urlRegExp.allMatches(url).map((m) => m.group(0)).toList();
    if (urlMatches.isEmpty) return [];
    String realUrl = urlMatches.first!;
    var id = "";
    realUrl = urlMatches.first!;
    if (realUrl.contains("bilibili.com")) {
      var regExp = RegExp(r"bilibili\.com/([\d|\w]+)");
      id = regExp.firstMatch(realUrl)?.group(1) ?? "";
      return [id, Sites.bilibiliSite];
    }

    if (realUrl.contains("b23.tv")) {
      var btvReg = RegExp(r"https?:\/\/b23.tv\/[0-9a-z-A-Z]+");
      var u = btvReg.firstMatch(realUrl)?.group(0) ?? "";
      var location = await getLocation(u);

      return await parse(location);
    }

    if (realUrl.contains("douyu.com")) {
      var regExp = RegExp(r"douyu\.com/([\d|\w]+)");
      id = regExp.firstMatch(realUrl)?.group(1) ?? "";
      if (realUrl.endsWith('/')) {
        realUrl = realUrl.substring(0, realUrl.length - 1);
      }
      return [id, Sites.douyuSite];
    }
    if (realUrl.contains("huya.com")) {
      var regExp = RegExp(r"huya\.com/([\d|\w]+)");
      if (realUrl.endsWith('/')) {
        realUrl = realUrl.substring(0, realUrl.length - 1);
      }
      id = regExp.firstMatch(realUrl)?.group(1) ?? "";

      return [id, Sites.huyaSite];
    }
    if (realUrl.contains("live.douyin.com")) {
      var regExp = RegExp(r"live\.douyin\.com/([\d|\w]+)");
      if (realUrl.endsWith('/')) {
        realUrl = realUrl.substring(0, realUrl.length - 1);
      }
      id = regExp.firstMatch(realUrl)?.group(1) ?? "";
      return [id, Sites.douyinSite];
    }
    if (realUrl.contains("www.douyin.com")) {
      realUrl = realUrl.split("?")[0];
      if (realUrl.endsWith('/')) {
        realUrl = realUrl.substring(0, realUrl.length - 1);
      }
      Uri uri = Uri.parse(realUrl);
      return [uri.pathSegments.last, Sites.douyinSite];
    }
    if (realUrl.contains("v.douyin.com")) {
      final id = await getRealDouyinUrl(realUrl);
      return [id, Sites.douyinSite];
    }
    if (url.contains("webcast.amemv.com")) {
      var regExp = RegExp(r"reflow/(\d+)");
      id = regExp.firstMatch(url)?.group(1) ?? "";
      return [id, Sites.douyinSite];
    }
    if (realUrl.contains("live.kuaishou.com")) {
      var regExp = RegExp(r"live\.kuaishou\.com/u/([a-zA-Z0-9]+)$");
      if (realUrl.endsWith('/')) {
        realUrl = realUrl.substring(0, realUrl.length - 1);
      }
      id = regExp.firstMatch(realUrl)?.group(1) ?? "";
      return [id, Sites.kuaishouSite];
    }
    if (realUrl.contains("live.kuaishou.cn")) {
      var regExp = RegExp(r"live\.kuaishou\.cn/u/([a-zA-Z0-9]+)$");
      if (realUrl.endsWith('/')) {
        realUrl = realUrl.substring(0, realUrl.length - 1);
      }
      id = regExp.firstMatch(realUrl)?.group(1) ?? "";
      return [id, Sites.kuaishouSite];
    }

    if (realUrl.contains("cc.163.com")) {
      var regExp = RegExp(r"cc\.163\.com/([a-zA-Z0-9]+)$");
      if (realUrl.endsWith('/')) {
        realUrl = realUrl.substring(0, realUrl.length - 1);
      }
      id = regExp.firstMatch(realUrl)?.group(1) ?? "";
      return [id, Sites.ccSite];
    }
    return [];
  }

  Future<String> getRealDouyinUrl(String url) async {
    final urlRegExp = RegExp(
      r"((https?:www\.)|(https?:\/\/)|(www\.))[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9]{1,6}(\/[-a-zA-Z0-9()@:%_\+.~#?&\/=]*)?",
    );
    List<String?> urlMatches = urlRegExp.allMatches(url).map((m) => m.group(0)).toList();
    String realUrl = urlMatches.first!;
    var headers = {
      "User-Agent":
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36",
      "Accept": "*/*",
      "Accept-Encoding": "gzip, deflate, br, zstd",
      "Origin": "https://live.douyin.com",
      "Referer": "https://live.douyin.com/",
      "Sec-Fetch-Site": "cross-site",
      "Sec-Fetch-Mode": "cors",
      "Sec-Fetch-Dest": "empty",
      "Accept-Language": "zh-CN,zh;q=0.9",
    };
    dio.Response response = await dio.Dio().get(
      realUrl,
      options: dio.Options(followRedirects: true, headers: headers, maxRedirects: 100),
    );
    final liveResponseRegExp = RegExp(r"/reflow/(\d+)");
    String reflow = liveResponseRegExp.firstMatch(response.realUri.toString())?.group(0) ?? "";
    var liveResponse = await dio.Dio().get(
      "https://webcast.amemv.com/webcast/room/reflow/info/",
      queryParameters: {
        "room_id": reflow.split("/").last.toString(),
        'verifyFp': '',
        'type_id': 0,
        'live_id': 1,
        'sec_user_id': '',
        'app_id': 1128,
        'msToken': '',
        'X-Bogus': '',
      },
    );
    var room = liveResponse.data['data']['room']['owner']['web_rid'];
    return room.toString();
  }

  Future<String> getLocation(String url) async {
    try {
      if (url.isEmpty) return "";
      await dio.Dio().get(url, options: dio.Options(followRedirects: false));
    } on dio.DioException catch (e) {
      if (e.response!.statusCode == 302) {
        var redirectUrl = e.response!.headers.value("Location");
        if (redirectUrl != null) {
          return redirectUrl;
        }
      }
    } catch (e) {
      log(e.toString(), name: "getLocation");
    }
    return "";
  }

  void autoCheckClipboard() async {
    ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    String? text = data?.text;
    if (text == null || text.isEmpty) return;

    // 简单的正则判断，是否包含常见的直播域名
    final bool isLiveUrl = RegExp(r"bilibili|huya|douyu|douyin|kuaishou|163").hasMatch(text);

    if (isLiveUrl) {
      // 自动填充两个输入框（或根据你逻辑选一个）
      roomJumpToController.text = text;
      getUrlController.text = text;

      Get.snackbar(
        i18n("toolbox_detect_link"),
        i18n("toolbox_auto_fill"),
        snackPosition: SnackPosition.bottom,
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.all(15),
      );
    }
  }
}
