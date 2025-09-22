import 'dart:convert';
import 'dart:math';

import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:pure_live/common/models/live_area.dart';
import 'package:pure_live/common/models/live_message.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/core/iptv/src/general_utils_object_extension.dart';
import 'package:pure_live/core/site/douyu/douyu_danmaku.dart';
import 'package:pure_live/core/sites.dart';
import 'package:pure_live/model/live_anchor_item.dart';
import 'package:pure_live/model/live_category.dart';
import 'package:pure_live/model/live_category_result.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/model/live_play_quality_play_url_info.dart';
import 'package:pure_live/model/live_search_result.dart';

import '../../../common/utils/js_engine.dart';
import 'douyu_site_mixin.dart';

class DouyuSite extends LiveSite with DouyuSiteMixin {
  @override
  String get id => "douyu";

  @override
  String get name => "斗鱼直播";

  @override
  LiveDanmaku getDanmaku() => DouyuDanmaku();

  @override
  Future<List<LiveCategory>> getCategores(int page, int pageSize) async {
    List<LiveCategory> categories = [];
    var result = await HttpClient.instance.getJson("https://m.douyu.com/api/cate/list");
    var subCateList = result["data"]["cate2Info"] as List;
    for (var item in result["data"]["cate1Info"]) {
      var cate1Id = item["cate1Id"];
      var cate1Name = item["cate1Name"];
      List<LiveArea> subCategories = [];
      subCateList.where((x) => x["cate1Id"] == cate1Id).forEach((element) {
        subCategories.add(LiveArea(
          areaPic: element["icon"].toString(),
          areaId: element["cate2Id"].toString(),
          typeName: cate1Name.toString(),
          areaType: cate1Id.toString(),
          platform: Sites.douyuSite,
          areaName: element["cate2Name"].toString(),
        ));
      });
      categories.add(
        LiveCategory(
          id: cate1Id.toString(),
          name: cate1Name.toString(),
          children: subCategories,
        ),
      );
    }
    // 根据ID排序
    categories.sort((a, b) => int.parse(a.id).compareTo(int.parse(b.id)));
    return categories;
  }

  Future<List<LiveArea>> getSubCategories(LiveCategory liveCategory) async {
    var result = await HttpClient.instance.getJson(
        "https://www.douyu.com/japi/weblist/apinc/getC2List",
        queryParameters: {
          "shortName": liveCategory.name,
          "customClassId": liveCategory.id,
          "offset": 0,
          "limit": 200
        });

    List<LiveArea> subs = [];
    for (var item in result["data"]["list"]) {
      subs.add(LiveArea(
        areaPic: item["squareIconUrlW"].toString(),
        areaId: item["cid2"].toString(),
        typeName: liveCategory.name,
        areaType: liveCategory.id,
        platform: Sites.douyuSite,
        areaName: item["cname2"].toString(),
      ));
    }

    return subs;
  }

  @override
  Future<LiveCategoryResult> getCategoryRooms(LiveArea category,
      {int page = 1}) async {
    var result = await HttpClient.instance.getJson(
      "https://www.douyu.com/gapi/rkc/directory/mixList/2_${category.areaId}/$page",
      queryParameters: {},
    );

    var items = <LiveRoom>[];
    for (var item in result['data']['rl']) {
      if (item["type"] != 1) {
        continue;
      }
      var avatar = item['av'].toString();
      if (avatar.isNotEmpty) {
        if (!avatar.contains("https://")) {
          avatar = "https://apic.douyucdn.cn/upload/${avatar}_big.jpg";
        }
      } else {
        avatar = "";
      }
      var roomItem = LiveRoom(
        cover: item['rs16'].toString(),
        watching: item['ol'].toString(),
        roomId: item['rid'].toString(),
        title: item['rn'].toString(),
        nick: item['nn'].toString(),
        area: item['c2name'].toString(),
        liveStatus: LiveStatus.live,
        avatar: avatar,
        status: true,
        platform: Sites.douyuSite,
      );
      items.add(roomItem);
    }
    var hasMore = page < result['data']['pgcnt'];
    return LiveCategoryResult(hasMore: hasMore, items: items);
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites(
      {required LiveRoom detail}) async {
    var data = detail.data.toString();
    data += "&cdn=&rate=-1&ver=Douyu_223061205&iar=1&ive=1&hevc=0&fa=0";
    List<LivePlayQuality> qualities = [];
    var result = await HttpClient.instance.postJson(
      "https://www.douyu.com/lapi/live/getH5Play/${detail.roomId}",
      data: data,
      formUrlEncoded: true,
    );

    var cdns = <String>[];
    for (var item in result["data"]["cdnsWithName"]) {
      cdns.add(item["cdn"].toString());
    }
    // 如果cdn以scdn开头，将其放到最后
    cdns.sort((a, b) {
      if (a.startsWith("scdn") && !b.startsWith("scdn")) {
        return 1;
      } else if (!a.startsWith("scdn") && b.startsWith("scdn")) {
        return -1;
      }
      return 0;
    });
    for (var item in result["data"]["multirates"]) {
      qualities.add(LivePlayQuality(
        quality: item["name"].toString(),
        data: DouyuPlayData(item["rate"], cdns),
        bitRate: item["bit"] ?? 0,
      ));
    }
    return qualities;
  }

  @override
  Future<List<LivePlayQualityPlayUrlInfo>> getPlayUrls(
      {required LiveRoom detail, required LivePlayQuality quality}) async {
    var args = detail.data.toString();
    var data = quality.data as DouyuPlayData;

    List<LivePlayQualityPlayUrlInfo> urls = [];
    var futureList = <Future<LivePlayQualityPlayUrlInfo>>[];
    for (var item in data.cdns) {
      futureList.add(getPlayUrl(detail.roomId!, args, data.rate, item));
    }
    var waits = await Future.wait(futureList);
    for (var url in waits) {
      if (url.playUrl.isNotEmpty) {
        urls.add(url);
      }
    }
    return urls;
  }

  Future<LivePlayQualityPlayUrlInfo> getPlayUrl(
      String roomId, String args, int rate, String cdn) async {
    args += "&cdn=$cdn&rate=$rate";
    var result = await HttpClient.instance.postJson(
      "https://www.douyu.com/lapi/live/getH5Play/$roomId",
      data: args,
      header: {
        'referer': 'https://www.douyu.com/$roomId',
        'user-agent':
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36 Edg/114.0.1823.43"
      },
      formUrlEncoded: true,
    );
    //CoreLog.d("getPlayUrl ${jsonEncode(result)}");
    return LivePlayQualityPlayUrlInfo(
        playUrl: "${result["data"]["rtmp_url"]}/${HtmlUnescape().convert(result["data"]["rtmp_live"].toString())}",
        info: "($cdn)"
    );
  }

  @override
  Future<LiveCategoryResult> getRecommendRooms(
      {int page = 1, required String nick}) async {
    var result = await HttpClient.instance.getJson(
      "https://www.douyu.com/japi/weblist/apinc/allpage/6/$page",
      queryParameters: {},
    );

    var items = <LiveRoom>[];
    for (var item in result['data']['rl']) {
      if (item["type"] != 1) {
        continue;
      }
      var avatar = item['av'].toString();
      if (avatar.isNotEmpty) {
        if (!avatar.contains("https://")) {
          avatar = "https://apic.douyucdn.cn/upload/${avatar}_big.jpg";
        }
      } else {
        avatar = "";
      }
      var roomItem = LiveRoom(
        cover: item['rs16'].toString(),
        watching: item['ol'].toString(),
        roomId: item['rid'].toString(),
        title: item['rn'].toString(),
        nick: item['nn'].toString(),
        area: item['c2name'].toString(),
        avatar: avatar,
        platform: Sites.douyuSite,
        status: true,
        liveStatus: LiveStatus.live,
      );
      items.add(roomItem);
    }
    var hasMore = page < result['data']['pgcnt'];
    return LiveCategoryResult(hasMore: hasMore, items: items);
  }

  @override
  Future<LiveRoom> getRoomDetail({required LiveRoom detail}) async {
    var roomId = detail.roomId ?? "";
    try {
      var roomData = getSignByHome(roomId);
      var result = await HttpClient.instance.getJson(
          "https://www.douyu.com/betard/$roomId",
          queryParameters: {},
          header: {
            'referer': 'https://www.douyu.com/$roomId',
            'user-agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36 Edg/114.0.1823.43',
          });
      Map roomInfo;
      if (result is String) {
        roomInfo = json.decode(result)["room"];
      } else {
        roomInfo = result["room"];
      }

      // CoreLog.d("result: ${json.encode(result)}");
      return LiveRoom(
        cover: roomInfo["room_pic"].toString(),
        watching: roomInfo["room_biz_all"]["hot"].toString(),
        roomId: roomId,
        title: roomInfo["room_name"].toString(),
        nick: roomInfo["owner_name"].toString(),
        userId: roomInfo["up_id"].toString(),
        avatar: roomInfo["owner_avatar"].toString(),
        introduction: roomInfo["show_details"].toString(),
        area: roomInfo["second_lvl_name"]?.toString() ?? '',
        notice: "",
        liveStatus:
            roomInfo["show_status"] == 1 ? LiveStatus.live : LiveStatus.offline,
        status: roomInfo["show_status"] == 1,
        danmakuData: roomInfo["room_id"].toString(),
        data: await roomData,
        platform: Sites.douyuSite,
        link: "https://www.douyu.com/$roomId",
        isRecord: roomInfo["videoLoop"] == 1,
      );
    } catch (e) {
      CoreLog.error(e);
      return getLiveRoomWithError(detail);
    }
  }

  @override
  Future<LiveSearchRoomResult> searchRooms(String keyword,
      {int page = 1}) async {
    var did = generateRandomString(32);
    var result = await HttpClient.instance.getJson(
      "https://www.douyu.com/japi/search/api/searchShow",
      queryParameters: {
        "kw": keyword,
        "page": page,
        "pageSize": 20,
      },
      header: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36 Edg/114.0.1823.51',
        'referer': 'https://www.douyu.com/search/',
        'Cookie': 'dy_did=$did;acf_did=$did'
      },
    );
    if (result['error'] != 0) {
      throw Exception(result['msg']);
    }
    var items = <LiveRoom>[];

    var queryList = result["data"]["relateShow"] ?? [];
    for (var item in queryList) {
      var liveStatus = (int.tryParse(item["isLive"].toString()) ?? 0) == 1;
      var roomType = (int.tryParse(item["roomType"].toString()) ?? 0);
      var roomItem = LiveRoom(
        roomId: item["rid"].toString(),
        title: item["roomName"].toString(),
        cover: item["roomSrc"].toString(),
        area: item["cateName"].toString(),
        avatar: item["avatar"].toString(),
        liveStatus:
            liveStatus && roomType == 0 ? LiveStatus.live : LiveStatus.offline,
        status: liveStatus && roomType == 0,
        nick: item["nickName"].toString(),
        platform: Sites.douyuSite,
        watching: item["hot"].toString(),
      );
      items.add(roomItem);
    }
    return LiveSearchRoomResult(hasMore: queryList.length > 0, items: items);
  }

  //生成指定长度的16进制随机字符串
  String generateRandomString(int length) {
    var random = Random.secure();
    var values = List<int>.generate(length, (i) => random.nextInt(16));
    StringBuffer stringBuffer = StringBuffer();
    for (var item in values) {
      stringBuffer.write(item.toRadixString(16));
    }
    return stringBuffer.toString();
  }

  @override
  Future<LiveSearchAnchorResult> searchAnchors(String keyword,
      {int page = 1}) async {
    var did = generateRandomString(32);
    var result = await HttpClient.instance.getJson(
      "https://www.douyu.com/japi/search/api/searchUser",
      queryParameters: {
        "kw": keyword,
        "page": page,
        "pageSize": 20,
        "filterType": 1,
      },
      header: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36 Edg/114.0.1823.51',
        'referer': 'https://www.douyu.com/search/',
        'Cookie': 'dy_did=$did;acf_did=$did'
      },
    );

    var items = <LiveAnchorItem>[];
    for (var item in result["data"]["relateUser"]) {
      var liveStatus =
          (int.tryParse(item["anchorInfo"]["isLive"].toString()) ?? 0) == 1;
      var roomType =
          (int.tryParse(item["anchorInfo"]["roomType"].toString()) ?? 0);
      var roomItem = LiveAnchorItem(
        roomId: item["anchorInfo"]["rid"].toString(),
        avatar: item["anchorInfo"]["avatar"].toString(),
        userName: item["anchorInfo"]["nickName"].toString(),
        liveStatus: liveStatus && roomType == 0,
      );
      items.add(roomItem);
    }
    var hasMore = result["data"]["relateUser"].isNotEmpty;
    return LiveSearchAnchorResult(hasMore: hasMore, items: items);
  }

  Future<String> getPlayArgs(String roomId) async {

    var jsEncResult = await HttpClient.instance.getText(
        "https://www.douyu.com/swf_api/homeH5Enc?rids=$roomId",
        queryParameters: {},
        header: {
          'referer': 'https://www.douyu.com/$roomId',
          'user-agent':
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36 Edg/114.0.1823.43"
        });
    var oldHtml = json.decode(jsEncResult)["data"]["room$roomId"].toString();

    //取加密的js
    var html = RegExp(
                r"(vdwdae325w_64we[\s\S]*function ub98484234[\s\S]*?)function",
                multiLine: true)
            .firstMatch(oldHtml)
            ?.group(1) ??
        "";
    html = html.replaceAll(RegExp(r"eval.*?;}"), "strc;}");

    var result = await HttpClient.instance.postJson(
        "http://alive.nsapps.cn/api/AllLive/DouyuSign",
        data: {"html": html, "rid": roomId});

    if (result["code"] == 0) {
      return result["data"].toString();
    }
    return "";
  }

  /// 通过主页获取签名
  Future<String> getSignByHome(String rid) async {
    String roomUrl = "https://www.douyu.com/$rid";
    String response = (await HttpClient.instance.get(roomUrl)).data;

    String realRid = response.substring(
        response.indexOf("\$ROOM.room_id =") + ("\$ROOM.room_id =").length);
    realRid = realRid.substring(0, realRid.indexOf(";")).trim();
    if (rid != realRid) {
      roomUrl = "https://www.douyu.com/$realRid";
      response = (await HttpClient.instance.get(roomUrl)).data;
    }

    //取加密的js
    var result = RegExp(
        r"(vdwdae325w_64we[\s\S]*function ub98484234[\s\S]*?)function", multiLine: true)
        .firstMatch(response)
        ?.group(1) ??
        "";
    String homeJs = result.replaceAll(RegExp(r"eval.*?;"), "strc;");
    await JsEngine.init();

    var res = JsEngine.evaluate("$homeJs;;ub98484234()").toString();
    // SmartDialog.showToast(res);
    var funcSign = res.replaceAll(RegExp('return rt;}\\);?'), 'return rt;}')
        .replaceAll('(function (', 'function sign(');

    // SmartDialog.showToast(funcSign);

    String ub9 = funcSign;
    final tt = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    // ub9 = ub9.substring(0, ub9.lastIndexOf('function'));
    var functionName = RegExp(r"function\s*([\s\S]*?)\s*\(", multiLine: true)
        .firstMatch(ub9)
        ?.group(1) ??
        "";

    // SmartDialog.showToast(functionName);

    final params = JsEngine.evaluate(
        '$ub9;;$functionName(\'$rid\', \'10000000000000000000000000001501\', \'$tt\')')
        .toString();

    // SmartDialog.showToast(params);
    return params;

  }

  int parseHotNum(String hn) {
    try {
      var num = double.parse(hn.replaceAll("万", ""));
      if (hn.contains("万")) {
        num *= 10000;
      }
      return num.round();
    } catch (_) {
      return -999;
    }
  }

  @override
  Future<List<LiveSuperChatMessage>> getSuperChatMessage(
      {required String roomId}) {
    //尚不支持
    return Future.value([]);
  }

  @override
  bool isSupportBatchUpdateLiveStatus() {
    return true;
  }

  @override
  Future<List<LiveRoom>> getLiveRoomDetailList(
      {required List<LiveRoom> list}) async {
    if (list.isNullOrEmpty) {
      return list;
    }

    /// 分页获取，每页 20 个
    var size = 20;
    var futureList = <Future<List<LiveRoom>>>[];
    for (var i = 0; i < list.length; i += size) {
      var end = min(i + size, list.length);
      var subList = list.sublist(i, end);
      var future = getLiveRoomDetailListPart(list: subList);
      futureList.add(future);
    }
    final rooms = await Future.wait(futureList);
    return rooms.expand((e) => e).toList();
  }

  Future<List<LiveRoom>> getLiveRoomDetailListPart(
      {required List<LiveRoom> list}) async {
    if (list.isNullOrEmpty) {
      return list;
    }
    var idList = list.map((room) => room.roomId!).toList();
    // , (urlencode == >) %2C
    var rids = idList.join(",");

    try {
      var result = await HttpClient.instance.postJson(
          "https://apiv2.douyucdn.cn/Livenc/UserRelation/getFollowRoomListByRid",
          queryParameters: {},
          data: {"rids": rids},
          formUrlEncoded: true,
          header: {
            'referer': 'https://www.douyu.com/',
            'content-type': 'application/x-www-form-urlencoded',
            'user-agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36 Edg/114.0.1823.43',
          });

      // SmartDialog.showToast(result, displayTime: const Duration(seconds: 45));
      // SmartDialog.showToast(result);
      List roomList;
      if (result is String) {
        roomList = json.decode(result)["data"]["room_list"];
      } else {
        roomList = result["data"]["room_list"];
      }

      List<LiveRoom> rsList = [];
      // DateTime now = DateTime.now();

      // 格式化日期为 "年月日" 240917
      // String formattedDate = DateFormat('yyMMdd').format(now);

      /// https://rpic.douyucdn.cn/asrpic/240917/9999_src_1453.avif/dy1
      // RegExp exp = RegExp(r'/asrpic/(\d{6})/');

      for (var roomInfo in roomList) {
        var isLiving = roomInfo["show_status"] == 1;

        bool isRecord = false;
        // if (isLiving) {
        //   /// 通过图片日期判断是否录播
        //   isRecord = true;
        //   var roomSrc = roomInfo["room_src"].toString();
        //   var allMatches = exp.allMatches(roomSrc);
        //   for (var value in allMatches) {
        //     var picDate = value.group(1);
        //     if (formattedDate == picDate) {
        //       isRecord = false;
        //     }
        //   }
        // }

        var tmp = LiveRoom(
          cover: roomInfo["room_src"].toString(),
          watching: roomInfo["hn"].toString(),
          roomId: roomInfo["room_id"].toString(),
          title: roomInfo["room_name"].toString(),
          nick: roomInfo["nickname"].toString(),
          avatar: roomInfo["avatar"].toString(),
          introduction: roomInfo["close_notice"].toString(),
          area: roomInfo["cate2_name"]?.toString() ?? '',
          notice: roomInfo["close_notice"]?.toString() ?? "",
          liveStatus: isLiving ? LiveStatus.live : LiveStatus.offline,
          status: roomInfo["show_status"] == 1,
          danmakuData: roomInfo["room_id"].toString(),
          // data: await getPlayArgs(crptext, roomInfo["room_id"].toString()),
          platform: Sites.douyuSite,
          link: "https://www.douyu.com/${roomInfo["room_id"].toString()}",
          // isRecord: roomInfo["videoLoop"] == 1,
          isRecord: isRecord,
        );
        rsList.add(tmp);
      }
      return rsList;
    } catch (e) {
      CoreLog.error(e);
      SmartDialog.showToast(e.toString());
      for (var liveRoom in list) {
        liveRoom.liveStatus = LiveStatus.offline;
        liveRoom.status = false;
      }
      return list;
    }
  }
}

class DouyuPlayData {
  final int rate;
  final List<String> cdns;

  DouyuPlayData(this.rate, this.cdns);
}
