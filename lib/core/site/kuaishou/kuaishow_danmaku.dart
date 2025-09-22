import 'dart:async';
import 'dart:math' as math;

import 'package:fixnum/fixnum.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/utils/color_util.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/core/common/web_socket_util.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
import 'package:pure_live/core/site/kuaishou/kuaishou_site.dart';
import 'package:pure_live/plugins/fake_useragent.dart';

import './proto/ks.pb.dart';
// ignore_for_file: no_leading_underscores_for_local_identifiers

class KuaishowDanmakuArgs {
  String url;
  String token;
  String liveStreamId;
  String expTag;

  KuaishowDanmakuArgs({
    required this.url,
    required this.token,
    required this.liveStreamId,
    required this.expTag,
  });

  KuaishowDanmakuArgs.fromJson(Map<String, dynamic> json)
      : url = json['url'] ?? '',
        token = json['token'] ?? '',
        liveStreamId = json['liveStreamId'] ?? '',
        expTag = json['expTag'] ?? '';

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'url': url,
      'token': token,
      'liveStreamId': liveStreamId,
      'expTag': expTag,
    };
  }
}

class KuaishowDanmaku implements LiveDanmaku {
  @override
  int heartbeatTime = 20 * 1000;

  @override
  Function(LiveMessage msg)? onMessage;
  @override
  Function(String msg)? onClose;
  @override
  Function()? onReady;
  String serverUrl = "wss://cdnws.api.huya.com";

  WebScoketUtils? webScoketUtils;
  late KuaishowDanmakuArgs danmakuArgs;

  @override
  Future start(dynamic args) async {
    CoreLog.d("start");
    if (args == null) {
      onClose?.call("服务器连接失败");
      return;
    }
    danmakuArgs = args as KuaishowDanmakuArgs;
    var kuaishouSite = Sites.of(Sites.kuaishouSite);
    var kuaishowSite = kuaishouSite.liveSite as KuaishowSite;
    kuaishowSite.headers['cookie'] = kuaishowSite.cookie;
    var mHeaders = kuaishowSite.headers;
    var fakeUseragent = FakeUserAgent.getRandomUserAgent();
    mHeaders['User-Agent'] = fakeUseragent['userAgent'];
    mHeaders['sec-ch-ua'] = 'Google Chrome;v=${fakeUseragent['v']}, Chromium;v=${fakeUseragent['v']}, Not=A?Brand;v=24';
    mHeaders['sec-ch-ua-platform'] = fakeUseragent['device'];
    mHeaders['sec-fetch-dest'] = 'document';
    mHeaders['sec-fetch-mode'] = 'navigate';
    mHeaders['sec-fetch-site'] = 'same-origin';
    mHeaders['sec-fetch-user'] = '?1';
    // mHeaders['origin'] = 'https://live.kuaishou.com';
    // mHeaders['sec-websocket-key'] = 'E95v8n0Z1sq1GKVru6zacw==';
    // mHeaders['sec-websocket-version'] = '13';
    // mHeaders['sec-websocket-extensions'] = 'permessage-deflate; client_max_window_bits';
    mHeaders['accept'] = 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9';
    webScoketUtils = WebScoketUtils(
      url: danmakuArgs.url,
      heartBeatTime: heartbeatTime,
      headers: mHeaders,
      onMessage: (e) {
        try {
          if (e.runtimeType == String) {
            return decodeMessageStr(e);
          }
          return decodeMessage(e);
        } catch (err) {
          CoreLog.w("$e");
          CoreLog.error(err);
        }
      },
      onReady: () {
        onReady?.call();
        joinRoom(danmakuArgs);
      },
      onHeartBeat: () {
        heartbeat();
      },
      onReconnect: () {
        onClose?.call("与服务器断开连接，正在尝试重连");
      },
      onClose: (e) {
        onClose?.call("服务器连接失败$e");
      },
    );
    webScoketUtils?.connect();
  }

  void joinRoom(dynamic joinData) {
    danmakuArgs = joinData as KuaishowDanmakuArgs;
    var csWebEnterRoom = CSWebEnterRoom();
    var payload = CSWebEnterRoom_Payload();
    payload.liveStreamId = danmakuArgs.liveStreamId;
    payload.token = danmakuArgs.token;
    payload.expTag = danmakuArgs.expTag;

    /// 设置 pageId
    var charset = "bjectSymhasOwnProp-0123456789ABCDEFGHIJKLMNQRTUVWXYZ_dfgiklquvxz";
    var splits = charset.split("");
    var pageId = "";
    for (var i = 0; i < 16; i++) {
      pageId += splits[math.Random().nextInt(splits.length)];
    }
    var dateTime = DateTime.now().millisecondsSinceEpoch;
    pageId += "_$dateTime";

    payload.pageId = pageId;
    csWebEnterRoom.payloadType = Int64.parseInt(PayloadType.CS_ENTER_ROOM.value.toString());
    csWebEnterRoom.payload = payload;
    webScoketUtils?.sendMessage(csWebEnterRoom.writeToBuffer());
  }

  @override
  void heartbeat() {
    var csWebHeartbeat = CSWebHeartbeat();
    var csWebHeartbeatPayload = CSWebHeartbeat_Payload();
    csWebHeartbeatPayload.timestamp = Int64.parseInt(DateTime.now().millisecondsSinceEpoch.toString());
    csWebHeartbeat.payloadType = Int64.parseInt(PayloadType.CS_HEARTBEAT.value.toString());
    csWebHeartbeat.payload = csWebHeartbeatPayload;
    webScoketUtils?.sendMessage(csWebHeartbeat.writeToBuffer());
  }

  @override
  Future stop() async {
    onMessage = null;
    onClose = null;
    webScoketUtils?.close();
  }

  void decodeMessageStr(String data) {
    CoreLog.w("decodeMessageStr: $data");
  }

  void decodeMessage(List<int> data) {
    var socketMessage = SocketMessage.fromBuffer(data);
    // var compressionType = socketMessage.compressionType;

    PayloadType payloadType = socketMessage.payloadType;
    // CoreLog.d(socketMessage.toString());
    // SC_FEED_PUSH 只获取推送信息
    if (payloadType != PayloadType.SC_FEED_PUSH) {
      return;
    }
    var payload = socketMessage.payload;
    var scWebFeedPush = SCWebFeedPush.fromBuffer(payload);
    // CoreLog.d(scWebFeedPush.toString());
    // 在线人数
    //    displayWatchingCount: 3.5万  在线观众
    //    displayLikeCount: 14.7万   总点赞数
    var displayWatchingCount = scWebFeedPush.displayWatchingCount;
    // var displayLikeCount = scWebFeedPush.displayLikeCount;
    // var likeCount = readableCountStrToNum(displayLikeCount);
    var commentFeeds = scWebFeedPush.commentFeeds;

    var online = readableCountStrToNum(displayWatchingCount);
    // CoreLog.d("online num:  $online \t likeCount num:  $likeCount");
    // CoreLog.d("$scWebFeedPush");

    onMessage?.call(
      LiveMessage(
        type: LiveMessageType.online,
        data: online,
        color: Colors.white,
        message: "",
        userName: "",
      ),
    );

    for (var commentFeed in commentFeeds) {
      var user = commentFeed.user;
      var userName = user.userName;
      var color = commentFeed.color;
      var content = commentFeed.content;
      // 赞了这个直播
      var showType = commentFeed.showType;
      if (showType != WebCommentFeedShowType.FEED_SHOW_NORMAL) {
        continue;
      }
      // log(commentFeed.toString(), name: runtimeType.toString());
      // log("color: $color", name: runtimeType.toString());
      // color: #FF8BA7
      var messageColor = ColorUtil.hexToColor(color);

      var fansLevel = "";
      var fansName = "";
      var senderState = commentFeed.senderState;
      var liveFansGroupState = senderState.liveFansGroupState;
      var intimacyLevel = liveFansGroupState.intimacyLevel;
      fansLevel = intimacyLevel.toString();
      fansName = "荣誉";
      // CoreLog.d("liveAudienceState11 ${commentFeed.senderState.liveAudienceState11}");
      var liveAudienceStateList = commentFeed.senderState.liveAudienceState11;
      for (var liveAudienceState in liveAudienceStateList) {
        try {
          var liveAudienceState111 = liveAudienceState.liveAudienceState111;
          // CoreLog.d("liveAudienceState111: ${liveAudienceState111}");
          var badgeIcon = liveAudienceState111.badgeIcon;
          // CoreLog.d("badgeIcon: ${badgeIcon} hasfans: ${badgeIcon.contains("fans")}");
          if (badgeIcon.contains("fans")) {
            var badgeName = liveAudienceState111.badgeName;
            fansName = badgeName;
            // CoreLog.d("fansName: ${fansName}");
          } else if (badgeIcon.contains("level")) {
            var text = RegExp(r"/level_(\d+).png;", multiLine: false).firstMatch(badgeIcon)?.group(1);
            if (text != null) {
              fansLevel = text;
              // CoreLog.d("fansLevel: ${fansLevel}");
            }
          }
        } catch (e) {
          CoreLog.w("$e");
        }
      }

      onMessage?.call(LiveMessage(
        type: LiveMessageType.chat,
        color: messageColor,
        message: content,
        userName: userName,
        fansLevel: fansLevel,
        fansName: fansName,
      ));
    }
  }
}
