import 'dart:math';
import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:crypto/crypto.dart';
import 'package:pure_live/common/index.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:pure_live/model/live_category.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/core/tars/huya_user_id.dart';
import 'package:pure_live/model/live_anchor_item.dart';
import 'package:tars_dart/tars/net/base_tars_http.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/model/live_search_result.dart';
import 'package:pure_live/core/danmaku/huya_danmaku.dart';
import 'package:pure_live/model/live_category_result.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
import 'package:pure_live/core/tars/get_cdn_token_ex_req.dart';
import 'package:pure_live/core/tars/get_cdn_token_ex_resp.dart';

class HuyaSite implements LiveSite {
  @override
  String id = "huya";
  static const baseUrl = "https://m.huya.com/";
  @override
  String name = "虎牙直播";
  @override
  LiveDanmaku getDanmaku() => HuyaDanmaku();

  static String? playUserAgent;

  // ignore: constant_identifier_names
  static const String HYSDK_UA = "HYSDK(Windows,30000002)_APP(pc_exe&7070000&official)_SDK(trans&2.33.0.5678)";
  static Map<String, String> requestHeaders = {'Origin': baseUrl, 'Referer': baseUrl, 'User-Agent': HYSDK_UA};
  final BaseTarsHttp tupClient = BaseTarsHttp("http://wup.huya.com", "liveui", headers: requestHeaders);
  @override
  Future<List<LiveCategory>> getCategores(int page, int pageSize) async {
    List<LiveCategory> categories = [
      LiveCategory(id: "1", name: "网游", children: []),
      LiveCategory(id: "2", name: "单机", children: []),
      LiveCategory(id: "8", name: "娱乐", children: []),
      LiveCategory(id: "3", name: "手游", children: []),
    ];

    for (var item in categories) {
      var items = await getSubCategores(item);
      item.children.addAll(items);
    }
    return categories;
  }

  final String kUserAgent =
      "Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/102.0.0.0 Safari/537.36";

  final SettingsService settings = Get.find<SettingsService>();
  Future<List<LiveArea>> getSubCategores(LiveCategory liveCategory) async {
    var result = await HttpClient.instance.getJson(
      "https://live.cdn.huya.com/liveconfig/game/bussLive",
      queryParameters: {"bussType": liveCategory.id},
    );

    List<LiveArea> subs = [];
    for (var item in result["data"]) {
      var gid = (item["gid"])?.toInt().toString();
      var subCategory = LiveArea(
        areaId: gid!,
        areaName: item["gameFullName"].toString(),
        areaType: liveCategory.id,
        platform: Sites.huyaSite,
        areaPic: "https://huyaimg.msstatic.com/cdnimage/game/$gid-MS.jpg",
        typeName: liveCategory.name,
      );
      subs.add(subCategory);
    }

    return subs;
  }

  @override
  Future<LiveCategoryResult> getCategoryRooms(LiveArea category, {int page = 1}) async {
    var resultText = await HttpClient.instance.getJson(
      "https://www.huya.com/cache.php",
      queryParameters: {
        "m": "LiveList",
        "do": "getLiveListByPage",
        "tagAll": 0,
        "gameId": category.areaId,
        "page": page,
      },
      header: {"user-agent": kUserAgent, "Cookie": settings.huyaCookie.value},
    );
    var result = json.decode(resultText);
    var items = <LiveRoom>[];
    for (var item in result["data"]["datas"]) {
      var cover = item["screenshot"].toString();
      if (!cover.contains("?")) {
        cover += "?x-oss-process=style/w338_h190&";
      }
      var title = item["introduction"]?.toString() ?? "";
      if (title.isEmpty) {
        title = item["roomName"]?.toString() ?? "";
      }
      var roomItem = LiveRoom(
        roomId: item["profileRoom"].toString(),
        title: title,
        cover: cover,
        nick: item["nick"].toString(),
        watching: item["totalCount"].toString(),
        avatar: item["avatar180"],
        area: item["gameFullName"].toString(),
        liveStatus: LiveStatus.live,
        status: true,
        platform: Sites.huyaSite,
      );
      items.add(roomItem);
    }
    var hasMore = result["data"]["page"] < result["data"]["totalPage"];
    return LiveCategoryResult(hasMore: hasMore, items: items);
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom detail}) {
    List<LivePlayQuality> qualities = <LivePlayQuality>[];
    var urlData = detail.data as HuyaUrlDataModel;
    if (urlData.bitRates.isEmpty) {
      urlData.bitRates = [HuyaBitRateModel(name: "原画", bitRate: 0), HuyaBitRateModel(name: "高清", bitRate: 2000)];
    }
    for (var item in urlData.bitRates) {
      qualities.add(LivePlayQuality(data: {"urls": urlData.lines, "bitRate": item.bitRate}, quality: item.name));
    }

    return Future.value(qualities);
  }

  @override
  Future<List<String>> getPlayUrls({required LiveRoom detail, required LivePlayQuality quality}) async {
    var ls = <String>[];
    for (var element in quality.data["urls"]) {
      var line = element as HuyaLineModel;
      var url = await getPlayUrl(line, quality.data["bitRate"]);
      ls.add(url);
    }
    return ls;
  }

  List<String> uaList = [
    'https://raw.kkgithub.com/liuchuancong/pure_live/master/assets/play_config.json',
    'https://wget.la/https://raw.githubusercontent.com/liuchuancong/pure_live/master/assets/play_config.json',
    'https://hk.gh-proxy.org/https:/raw.githubusercontent.com/liuchuancong/pure_live/master/assets/play_config.json',
    'https://ghfast.top/https://raw.githubusercontent.com/liuchuancong/pure_live/master/assets/play_config.json',
    'https://gh.catmak.name/https://raw.githubusercontent.com/liuchuancong/pure_live/master/assets/play_config.json',
    'https://ghproxy.net/https://raw.githubusercontent.com/liuchuancong/pure_live/master/assets/play_config.json',
    'https://fastly.jsdelivr.net/gh/liuchuancong/pure_live@master/assets/play_config.json',
    'https://g.blfrp.cn/https://raw.githubusercontent.com/liuchuancong/pure_live/master/assets/play_config.json',
    'https://cdn.jsdelivr.net/gh/liuchuancong/pure_live@master/assets/play_config.json',
  ];
  // 每次访问播放虎牙都需要获取一次，不太合理，倾向于在客户端获取保存替换
  Future<String> getHuYaUA() async {
    // 1. 缓存拦截
    if (playUserAgent != null) {
      debugPrint("UA 获取成功，使用缓存");
      return playUserAgent!;
    }

    final cancelToken = CancelToken();
    final completer = Completer<String>();
    bool isAlreadySet = false;

    try {
      // 2. 启动并发请求（不等待它们完成）
      for (final url in uaList) {
        HttpClient.instance
            .getJson("$url?ts=${DateTime.now().millisecondsSinceEpoch}", cancel: cancelToken)
            .then((response) {
              // 只要有一个成功，立即处理
              if (isAlreadySet) return;

              final data = (response is String) ? json.decode(response) : response;
              final String? ua = data?['huya']?['user_agent'];

              if (ua != null && !isAlreadySet) {
                isAlreadySet = true;
                playUserAgent = ua;
                debugPrint("✅ 获胜线路: $url");
                if (!completer.isCompleted) completer.complete(ua);
                Future.microtask(() => cancelToken.cancel("done"));
              }
            })
            .catchError((_) {});
      }

      final result = await completer.future.timeout(const Duration(seconds: 5));
      return result;
    } catch (e) {
      debugPrint("⚠️ UA 获取失败，使用兜底值: $e");
      playUserAgent = HYSDK_UA;
      return HYSDK_UA;
    } finally {
      playUserAgent ??= HYSDK_UA;
    }
  }

  Future<String> getPlayUrl(HuyaLineModel line, int bitRate) async {
    var antiCode = await getCndTokenInfoEx(line.streamName);
    antiCode = buildAntiCode(line.streamName, line.presenterUid, antiCode);
    var url = '${line.line}/${line.streamName}.flv?$antiCode&codec=264';
    if (bitRate > 0) {
      url += "&ratio=$bitRate";
    }
    return url;
  }

  @override
  Future<LiveCategoryResult> getRecommendRooms({int page = 1, required String nick}) async {
    var resultText = await HttpClient.instance.getJson(
      "https://www.huya.com/cache.php",
      queryParameters: {"m": "LiveList", "do": "getLiveListByPage", "tagAll": 0, "page": page},
      header: {
        "user-agent": kUserAgent,
        "Cookie": settings.huyaCookie.value,
        "Origin": "https://www.huya.com",
        "Referer": "https://www.huya.com/",
      },
    );
    var result = json.decode(resultText);
    var items = <LiveRoom>[];
    for (var item in result["data"]["datas"]) {
      var cover = item["screenshot"].toString();
      if (!cover.contains("?")) {
        cover += "?x-oss-process=style/w338_h190&";
      }
      var title = item["introduction"]?.toString() ?? "";
      if (title.isEmpty) {
        title = item["roomName"]?.toString() ?? "";
      }
      var roomItem = LiveRoom(
        roomId: item["profileRoom"].toString(),
        title: title,
        cover: cover,
        area: item["gameFullName"].toString(),
        nick: item["nick"].toString(),
        avatar: item["avatar180"],
        watching: item["totalCount"].toString(),
        platform: Sites.huyaSite,
        liveStatus: LiveStatus.live,
        status: true,
      );
      items.add(roomItem);
    }
    var hasMore = result["data"]["page"] < result["data"]["totalPage"];
    return LiveCategoryResult(hasMore: hasMore, items: items);
  }

  @override
  Future<LiveRoom> getRoomDetail({required String platform, required String roomId}) async {
    var resultText = await HttpClient.instance.getText(
      'https://mp.huya.com/cache.php?m=Live&do=profileRoom&roomid=$roomId&showSecret=1',
      header: {
        'Accept': '*/*',
        'Origin': 'https://www.huya.com',
        'Referer': 'https://www.huya.com/',
        'Sec-Fetch-Dest': 'empty',
        'Sec-Fetch-Mode': 'cors',
        'Sec-Fetch-Site': 'same-site',
        "user-agent": kUserAgent,
        "Cookie": settings.huyaCookie.value,
      },
    );
    var result = json.decode(resultText);
    if (result['status'] == 200 && result['data']['stream'] != null) {
      dynamic data = result['data'];
      var topSid = 0;
      var subSid = 0;
      var huyaLines = <HuyaLineModel>[];
      var huyaBiterates = <HuyaBitRateModel>[];
      //读取可用线路

      var baseSteamInfoList = data['stream']['baseSteamInfoList'] as List<dynamic>;

      var flvLines = data['stream']['flv']['multiLine'];
      var hlsLines = data['stream']['hls']['multiLine'];
      if (flvLines != null) {
        for (var item in flvLines) {
          if ((item["url"]?.toString() ?? "").isNotEmpty) {
            var currentStream = baseSteamInfoList.firstWhere(
              (element) => element["sCdnType"] == item["cdnType"],
              orElse: () => null,
            );
            if (currentStream != null) {
              topSid = currentStream["lChannelId"].runtimeType == String
                  ? int.tryParse(currentStream["lChannelId"].toString()) ?? 0
                  : currentStream["lChannelId"];
              subSid = currentStream["lSubChannelId"].runtimeType == String
                  ? int.tryParse(currentStream["lSubChannelId"].toString()) ?? 0
                  : currentStream["lSubChannelId"];
              huyaLines.add(
                HuyaLineModel(
                  line: currentStream['sFlvUrl'],
                  lineType: HuyaLineType.flv,
                  flvAntiCode: currentStream["sFlvAntiCode"].toString(),
                  hlsAntiCode: currentStream["sHlsAntiCode"].toString(),
                  streamName: currentStream["sStreamName"].toString(),
                  cdnType: item["sCdnType"].toString(),
                  presenterUid: topSid,
                ),
              );
            }
          }
        }
      }

      if (hlsLines != null) {
        for (var item in hlsLines) {
          if ((item["url"]?.toString() ?? "").isNotEmpty) {
            var currentStream = baseSteamInfoList.firstWhere(
              (element) => element["sCdnType"] == item["cdnType"],
              orElse: () => null,
            );
            if (currentStream != null) {
              topSid = currentStream["lChannelId"].runtimeType == String
                  ? int.tryParse(currentStream["lChannelId"].toString()) ?? 0
                  : currentStream["lChannelId"];
              subSid = currentStream["lSubChannelId"].runtimeType == String
                  ? int.tryParse(currentStream["lSubChannelId"].toString()) ?? 0
                  : currentStream["lSubChannelId"];
              huyaLines.add(
                HuyaLineModel(
                  line: currentStream['sHlsUrl'],
                  lineType: HuyaLineType.hls,
                  flvAntiCode: currentStream["sFlvAntiCode"].toString(),
                  hlsAntiCode: currentStream["sHlsAntiCode"].toString(),
                  streamName: currentStream["sStreamName"].toString(),
                  cdnType: item["sCdnType"].toString(),
                  presenterUid: topSid,
                ),
              );
            }
          }
        }
      }
      //清晰度
      var biterates = data['liveData']['bitRateInfo'] != null
          ? jsonDecode(data['liveData']['bitRateInfo'])
          : data['stream']['flv']['rateArray'];
      for (var item in biterates) {
        var name = item["sDisplayName"].toString();
        if (huyaBiterates.map((e) => e.name).toList().every((element) => element != name)) {
          huyaBiterates.add(HuyaBitRateModel(bitRate: item["iBitRate"], name: name));
        }
      }
      bool isXingxiu = data['liveData']['gid'] == 1663;
      return LiveRoom(
        cover: data['liveData']?['screenshot'] ?? '',
        watching: data['liveData']?['userCount']?.toString() ?? '',
        roomId: roomId,
        area: data['liveData']?['gameFullName'] ?? '',
        title: data['liveData']?['introduction'] ?? '',
        nick: data['profileInfo']?['nick'] ?? '',
        avatar: data['profileInfo']?['avatar180'] ?? '',
        introduction: data['liveData']?['introduction'] ?? '',
        notice: data['welcomeText'] ?? '',
        status: data['liveStatus'] == "ON" || data['liveStatus'] == "REPLAY",
        liveStatus: data['liveStatus'] == "ON" || data['liveStatus'] == "REPLAY" ? LiveStatus.live : LiveStatus.offline,
        platform: Sites.huyaSite,
        data: HuyaUrlDataModel(url: "", lines: huyaLines, bitRates: huyaBiterates, uid: "", isXingxiu: isXingxiu),
        danmakuData: HuyaDanmakuArgs(ayyuid: data["profileInfo"]["yyid"] ?? 0, topSid: topSid, subSid: subSid),
        link: "https://www.huya.com/$roomId",
      );
    } else {
      LiveRoom liveRoom = settings.getLiveRoomByRoomId(roomId, platform);
      liveRoom.liveStatus = LiveStatus.offline;
      liveRoom.status = false;
      return liveRoom;
    }
  }

  String? findRoomId(List list, int targetUid, int targetYyid) {
    try {
      final matchingObject = list.firstWhere(
        (item) => item['uid'] == targetUid && item['yyid'] == targetYyid,
        orElse: () => throw StateError("No matching object found"), // 当找不到匹配项时抛出错误
      );
      return matchingObject["room_id"].toString();
    } catch (e) {
      return null;
    }
  }

  @override
  Future<LiveSearchRoomResult> searchRooms(String keyword, {int page = 1}) async {
    var resultText = await HttpClient.instance.getJson(
      "https://search.cdn.huya.com/",
      queryParameters: {
        "m": "Search",
        "do": "getSearchContent",
        "q": keyword,
        "uid": 0,
        "v": 4,
        "typ": -5,
        "livestate": 0,
        "rows": 20,
        "start": (page - 1) * 20,
      },
    );
    var result = json.decode(resultText);
    var items = <LiveRoom>[];
    var queryList = result["response"]["3"]["docs"] ?? [];
    var responseList = result["response"]["1"]["docs"] ?? [];
    for (var item in queryList) {
      var cover = item["game_screenshot"].toString();
      if (!cover.contains("?")) {
        cover += "?x-oss-process=style/w338_h190&";
      }

      var title = item["game_introduction"]?.toString() ?? "";
      if (title.isEmpty) {
        title = item["game_roomName"]?.toString() ?? "";
      }
      var roomId = findRoomId(responseList, item['uid'], item['yyid']);
      var roomItem = LiveRoom(
        roomId: roomId ?? item["room_id"].toString(),
        title: title,
        cover: cover,
        userId: item["yyid"].toString(),
        nick: item["game_nick"].toString(),
        area: item["gameName"].toString(),
        status: true,
        liveStatus: LiveStatus.live,
        avatar: item["game_imgUrl"].toString(),
        watching: item["game_total_count"].toString(),
        platform: Sites.huyaSite,
      );
      items.add(roomItem);
    }
    return LiveSearchRoomResult(hasMore: queryList.length > 0, items: items);
  }

  @override
  Future<LiveSearchAnchorResult> searchAnchors(String keyword, {int page = 1}) async {
    var resultText = await HttpClient.instance.getJson(
      "https://search.cdn.huya.com/",
      queryParameters: {
        "m": "Search",
        "do": "getSearchContent",
        "q": keyword,
        "uid": 0,
        "v": 1,
        "typ": -5,
        "livestate": 0,
        "rows": 20,
        "start": (page - 1) * 20,
      },
    );
    var result = json.decode(resultText);
    var items = <LiveAnchorItem>[];
    for (var item in result["response"]["1"]["docs"]) {
      var anchorItem = LiveAnchorItem(
        roomId: item["room_id"].toString(),
        avatar: item["game_avatarUrl180"].toString(),
        userName: item["game_nick"].toString(),
        liveStatus: item["gameLiveOn"],
      );
      items.add(anchorItem);
    }
    var hasMore = result["response"]["1"]["numFound"] > (page * 20);
    return LiveSearchAnchorResult(hasMore: hasMore, items: items);
  }

  @override
  Future<bool> getLiveStatus({required String platform, required String roomId}) async {
    var resultText = await HttpClient.instance.getText(
      "https://m.huya.com/$roomId",
      queryParameters: {},
      header: {
        "user-agent": kUserAgent,
        'Accept': '*/*',
        'Origin': 'https://www.huya.com',
        'Referer': 'https://www.huya.com/',
        'Sec-Fetch-Dest': 'empty',
        'Sec-Fetch-Mode': 'cors',
        'Sec-Fetch-Site': 'same-site',
      },
    );
    var text = RegExp(
      r"window\.HNF_GLOBAL_INIT.=.\{(.*?)\}.</script>",
      multiLine: false,
    ).firstMatch(resultText)?.group(1);
    var jsonObj = json.decode("{$text}");
    return jsonObj["roomInfo"]["eLiveStatus"] == 2;
  }

  /// 匿名登录获取uid
  Future<String> getAnonymousUid() async {
    var result = await HttpClient.instance.postJson(
      "https://udblgn.huya.com/web/anonymousLogin",
      data: {"appId": 5002, "byPass": 3, "context": "", "version": "2.4", "data": {}},
      header: {
        "user-agent": kUserAgent,
        'Accept': '*/*',
        'Origin': 'https://www.huya.com',
        'Referer': 'https://www.huya.com/',
        'Sec-Fetch-Dest': 'empty',
        'Sec-Fetch-Mode': 'cors',
        'Sec-Fetch-Site': 'same-site',
      },
    );
    return result["data"]["uid"].toString();
  }

  String getUUid(String cookie, String streamName) {
    return getUid(cookie, streamName).toString();
  }

  int getUid(String cookie, String streamName) {
    try {
      if (cookie.contains('yyuid=')) {
        final match = RegExp(r'yyuid=(\d+)').firstMatch(cookie);
        if (match != null && match.groupCount >= 1) {
          return int.parse(match.group(1)!);
        }
      }
      final parts = streamName.split('-');
      if (parts.isNotEmpty) {
        final anchorUid = int.tryParse(parts[0]);
        if (anchorUid != null && anchorUid > 0) {
          return anchorUid;
        }
      }
    } catch (e) {
      // 在这里可以选择打印错误信息或采取其他措施
      debugPrint('An error occurred: $e');
    }
    // 如果没有找到有效的UID，则生成一个随机数
    final random = Random();
    return 1400000000000 + random.nextInt(100000000000); // 生成范围内的随机整数
  }

  String processAnticode(String anticode, String streamName) {
    var query = Uri.splitQueryString(anticode);
    final uid = int.parse(getUUid(settings.huyaCookie.value, streamName));
    query["ctype"] = "huya_live";
    query["t"] = "100";

    final convertUid = (uid << 8 | uid >> 24) & 0xFFFFFFFF;
    final wsTime = query["wsTime"]!;

    final seqId = (DateTime.now().millisecondsSinceEpoch + uid).toString();
    int ct = ((int.parse(wsTime, radix: 16) + Random().nextDouble()) * 1000).toInt();
    final fm = utf8.decode(base64.decode(Uri.decodeComponent(query['fm']!)));
    final wsSecretPrefix = fm.split('_').first;
    final wsSecretHash = md5.convert(utf8.encode('$seqId|${query["ctype"]}|${query["t"]}')).toString();
    final wsSecret = md5
        .convert(utf8.encode('${wsSecretPrefix}_${convertUid}_${streamName}_${wsSecretHash}_$wsTime'))
        .toString();
    tz.initializeTimeZones();
    final location = tz.getLocation('Asia/Shanghai');
    final now = tz.TZDateTime.now(location);
    final formatter = DateFormat('yyyyMMddHH');
    final formatted = formatter.format(now);
    DateFormat timeStampFormat = DateFormat("yyyy-MM-dd_HH:mm:ss.SSS");

    // 格式化当前时间
    String formattedDate = timeStampFormat.format(now);
    return Uri(
      queryParameters: {
        "wsSecret": wsSecret,
        "wsTime": wsTime,
        "seqid": seqId,
        "ctype": query["ctype"]!,
        "ver": "1",
        "fs": query["fs"]!,
        "t": query["t"]!,
        "u": convertUid.toString(),
        "uuid": (((ct % 1e10 + Random().nextDouble()) * 1e3).toInt() & 0xFFFFFFFF).toString(),
        "sdk_sid": DateTime.now().millisecondsSinceEpoch.toString(),
        "codec": "264",
        "sv": formatted,
        "dMod": "mseh-0",
        "sdkPcdn": "1_1",
        "a_block": "0",
        "timeStamp": formattedDate,
      },
    ).query;
  }

  @override
  Future<List<LiveSuperChatMessage>> getSuperChatMessage({required String roomId}) {
    //尚不支持
    return Future.value([]);
  }

  // 构造 anticode, python转写
  /// [stream] streamname [presenterUid] 用户id [antiCode] 页面anti
  ///
  /// return ture anticode
  String buildAntiCode(String stream, int presenterUid, String antiCode) {
    var mapAnti = Uri(query: antiCode).queryParametersAll;
    if (!mapAnti.containsKey("fm")) {
      return antiCode;
    }

    var ctype = mapAnti["ctype"]?.first ?? "huya_pc_exe";
    var platformId = int.tryParse(mapAnti["t"]?.first ?? "0");

    bool isWap = platformId == 103;
    var clacStartTime = DateTime.now().millisecondsSinceEpoch;

    CoreLog.i("using $presenterUid | ctype-{$ctype} | platformId - {$platformId} | isWap - {$isWap} | $clacStartTime");

    var seqId = presenterUid + clacStartTime;
    final secretHash = md5.convert(utf8.encode('$seqId|$ctype|$platformId')).toString();

    final convertUid = rotl64(presenterUid);
    final calcUid = isWap ? presenterUid : convertUid;
    final fm = Uri.decodeComponent(mapAnti['fm']!.first);
    final secretPrefix = utf8.decode(base64.decode(fm)).split('_').first;
    var wsTime = mapAnti['wsTime']!.first;
    final secretStr = '${secretPrefix}_${calcUid}_${stream}_${secretHash}_$wsTime';

    final wsSecret = md5.convert(utf8.encode(secretStr)).toString();

    final rnd = Random();
    final ct = ((int.parse(wsTime, radix: 16) + rnd.nextDouble()) * 1000).toInt();
    final uuid = (((ct % 1e10) + rnd.nextDouble()) * 1e3 % 0xffffffff).toInt().toString();
    final Map<String, dynamic> antiCodeRes = {
      'wsSecret': wsSecret,
      'wsTime': wsTime,
      'seqid': seqId,
      'ctype': ctype,
      'ver': '1',
      'fs': mapAnti['fs']!.first,
      'fm': Uri.encodeComponent(mapAnti['fm']!.first),
      't': platformId,
    };
    if (isWap) {
      antiCodeRes.addAll({'uid': presenterUid, 'uuid': uuid});
    } else {
      antiCodeRes['u'] = convertUid;
    }

    return antiCodeRes.entries.map((e) => '${e.key}=${e.value}').join('&');
  }

  /// return sFlvToken
  Future<String> getCndTokenInfoEx(String stream) async {
    var func = "getCdnTokenInfoEx";
    var tid = HuyaUserId();
    tid.sHuYaUA = "pc_exe&7060000&official";
    var tReq = GetCdnTokenExReq();
    tReq.tId = tid;
    tReq.sStreamName = stream;
    var resp = await tupClient.tupRequest(func, tReq, GetCdnTokenExResp());
    return resp.sFlvToken;
  }

  int rotl64(int t) {
    final low = t & 0xFFFFFFFF;
    final rotatedLow = ((low << 8) | (low >> 24)) & 0xFFFFFFFF;
    final high = t & ~0xFFFFFFFF;
    return high | rotatedLow;
  }
}

class HuyaUrlDataModel {
  final String url;
  final String uid;
  List<HuyaLineModel> lines;
  List<HuyaBitRateModel> bitRates;
  final bool isXingxiu;
  HuyaUrlDataModel({
    required this.bitRates,
    required this.lines,
    required this.url,
    required this.uid,
    required this.isXingxiu,
  });
}

enum HuyaLineType { flv, hls }

class HuyaLineModel {
  final String line;
  final String cdnType;
  final String flvAntiCode;
  final String hlsAntiCode;
  final String streamName;
  final HuyaLineType lineType;
  final int presenterUid;
  int bitRate;
  HuyaLineModel({
    required this.line,
    required this.lineType,
    required this.flvAntiCode,
    required this.hlsAntiCode,
    required this.streamName,
    required this.cdnType,
    required this.presenterUid,
    this.bitRate = 0,
  });
  @override
  String toString() {
    return 'HuyaLineModel{line: $line, flvAntiCode: $flvAntiCode, hlsAntiCode: $hlsAntiCode, streamName: $streamName, lineType: $lineType, presenterUid: $presenterUid}';
  }
}

class HuyaBitRateModel {
  final String name;
  final int bitRate;
  HuyaBitRateModel({required this.bitRate, required this.name});
}
