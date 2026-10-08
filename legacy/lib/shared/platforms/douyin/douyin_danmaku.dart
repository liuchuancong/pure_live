import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:meta/meta.dart';

import 'proto/douyin.pb.dart';

import 'package:crypto/crypto.dart';
import 'package:pure_live/shared/platforms/douyin/douyin_xbogus.dart';
import 'package:pure_live/core/logging/core_log.dart';
import 'package:pure_live/core/models/live_message.dart';
import 'package:pure_live/core/models/live_room.dart';
import 'package:pure_live/core/network/web_socket_util.dart';
import 'package:pure_live/shared/platforms/live_danmaku.dart';
import 'package:pure_live/shared/platforms/douyin/douyin_request_params.dart';

class DouyinDanmakuArgs {
  final String webRid;
  final String roomId;
  final String userId;
  final String cookie;

  DouyinDanmakuArgs({required this.webRid, required this.roomId, required this.userId, required this.cookie});

  @override
  String toString() {
    return json.encode({
      "webRid": webRid,
      "roomId": roomId,
      "userId": userId,
      // This object is included in lifecycle diagnostics. Never put an
      // authenticated session into logs or exception text.
      "cookie": cookie.isEmpty ? "" : "<redacted>",
    });
  }
}

class DouyinDanmaku implements LiveDanmaku {
  @override
  int heartbeatTime = 10 * 1000;
  bool _connected = false;

  @override
  bool get isConnected => _connected;

  @override
  void markConnected() {
    _connected = true;
  }

  @override
  void markDisconnected() {
    _connected = false;
  }

  @override
  Function(LiveMessage msg)? onMessage;
  @override
  Function(String msg)? onReconnect;
  @override
  Function(String msg)? onClose;
  @override
  Function()? onReady;
  static const String _webSocketPath = "/webcast/im/push/v2/";
  static const List<String> _webSocketHosts = <String>[
    // Current web rooms are distributed between the low- and high-latency
    // webcast100 pools. A single hard-coded pool made otherwise healthy rooms
    // appear to have no danmaku whenever that edge rejected the handshake.
    "webcast100-ws-web-lq.douyin.com",
    "webcast100-ws-web-hl.douyin.com",
  ];
  String serverUrl = "wss://${_webSocketHosts.first}$_webSocketPath";
  late DouyinDanmakuArgs danmakuArgs;
  WebScoketUtils? webScoketUtils;
  int _generation = 0;

  @override
  Future start(dynamic args) async {
    final generation = ++_generation;
    await webScoketUtils?.close();
    webScoketUtils = null;
    if (generation != _generation) return;
    danmakuArgs = args as DouyinDanmakuArgs;
    markDisconnected();
    var ts = DateTime.now().millisecondsSinceEpoch;
    var uri = Uri.parse(serverUrl).replace(
      scheme: "wss",
      queryParameters: {
        "app_name": "douyin_web",
        "version_code": DouyinRequestParams.versionCodeValue,
        "webcast_sdk_version": DouyinRequestParams.sdkVersion,
        "update_version_code": DouyinRequestParams.sdkVersion,
        "compress": "gzip",
        // "internal_ext":
        //     "internal_src:dim|wss_push_room_id:${danmakuArgs.roomId}|wss_push_did:${danmakuArgs.userId}|dim_log_id:20230626152702E8F63662383A350588E1|fetch_time:1687764422114|seq:1|wss_info:0-1687764422114-0-0|wrds_kvs:WebcastRoomRankMessage-1687764036509597990_InputPanelComponentSyncData-1687736682345173033_WebcastRoomStatsMessage-1687764414427812578",
        "cursor": "h-1_t-${ts}_r-1_d-1_u-1",
        "host": "https://live.douyin.com",
        "aid": "6383",
        "live_id": "1",
        "did_rule": "3",
        "debug": "false",
        "maxCacheMessageNumber": "20",
        "endpoint": "live_pc",
        "support_wrds": "1",
        "im_path": "/webcast/im/fetch/",
        "user_unique_id": danmakuArgs.userId,
        "device_platform": "web",
        "cookie_enabled": "true",
        "screen_width": "1920",
        "screen_height": "1080",
        "browser_language": "zh-CN",
        "browser_platform": "Win32",
        "browser_name": "Mozilla",
        "browser_version": DouyinRequestParams.browserVersion,
        "browser_online": "true",
        "tz_name": "Asia/Shanghai",
        "identity": "audience",
        "room_id": danmakuArgs.roomId,
        "need_persist_msg_count": "15",
        "heartbeatDuration": "0",
        //"signature": "00000000"
      },
    );

    var sign = await getSignature(danmakuArgs.roomId, danmakuArgs.userId);
    if (generation != _generation) return;

    final serverUrls = buildServerUrls(uri, signature: sign);
    final requestHeaders = buildHandshakeHeaders(danmakuArgs);
    webScoketUtils = WebScoketUtils(
      url: serverUrls.first,
      serverUrls: serverUrls,
      headers: requestHeaders,
      heartBeatTime: heartbeatTime,
      inactivityTimeout: const Duration(seconds: 45),
      onMessage: (e) {
        if (generation != _generation) return;
        try {
          decodeMessage(e);
        } catch (e) {
          CoreLog.error("douyin_danmaku_error$e");
        }
      },
      onReady: () {
        if (generation != _generation) return;
        markConnected();
        onReady?.call();
        joinRoom(args);
      },
      onHeartBeat: () {
        heartbeat();
      },
      onReconnect: () {
        if (generation != _generation) return;
        markDisconnected();
        onReconnect?.call("与服务器断开连接，正在尝试重连");
      },
      onClose: (e) {
        if (generation != _generation) return;
        markDisconnected();
        onClose?.call("服务器连接失败$e");
      },
    );
    await webScoketUtils?.connect();
  }

  /// Builds equivalent signed URLs for every current web IM edge.
  ///
  /// The signature alphabet contains `+` and `/`. Appending it as a raw string
  /// changed `+` into a query-space on some HTTP stacks, so failures depended
  /// on the random signature generated for that particular room attempt.
  @visibleForTesting
  static List<String> buildServerUrls(Uri baseUri, {required String signature}) {
    final signed = baseUri.replace(
      path: _webSocketPath,
      queryParameters: <String, String>{...baseUri.queryParameters, "signature": signature},
    );
    return List<String>.unmodifiable(
      _webSocketHosts.map((host) => signed.replace(scheme: "wss", host: host).toString()),
    );
  }

  @visibleForTesting
  static Map<String, dynamic> buildHandshakeHeaders(DouyinDanmakuArgs args) {
    return <String, dynamic>{
      "User-Agent": DouyinRequestParams.kDefaultUserAgent,
      if (args.cookie.trim().isNotEmpty) "Cookie": args.cookie,
      "Origin": "https://live.douyin.com",
      "Referer": "https://live.douyin.com/${args.webRid}",
    };
  }

  @override
  void heartbeat() {
    var obj = PushFrame();
    obj.payloadType = 'hb';
    webScoketUtils?.sendMessage(obj.writeToBuffer());
  }

  void decodeMessage(List<int> args) {
    // CoreLog.i(args.toString());

    var wssPackage = PushFrame.fromBuffer(args);

    var logId = wssPackage.logId;
    final encodedPayload = wssPackage.payload;
    final isGzip =
        wssPackage.payloadEncoding.toLowerCase() == 'gzip' ||
        (encodedPayload.length >= 2 && encodedPayload[0] == 0x1f && encodedPayload[1] == 0x8b);
    var decompressed = isGzip ? gzip.decode(encodedPayload) : encodedPayload;
    var payloadPackage = Response.fromBuffer(decompressed);
    if (payloadPackage.needAck) {
      sendAck(logId, payloadPackage.internalExt);
      //return;
    }
    for (var msg in payloadPackage.messagesList) {
      if (msg.method == 'WebcastChatMessage') {
        unPackWebcastChatMessage(msg.payload, envelopeMessageId: msg.msgId.toString());
      } else if (msg.method == 'WebcastRoomUserSeqMessage') {
        unPackWebcastRoomUserSeqMessage(msg.payload);
      }
    }
  }

  void unPackWebcastChatMessage(List<int> payload, {String envelopeMessageId = ''}) {
    var chatMessage = ChatMessage.fromBuffer(payload);
    final commonRoomId = chatMessage.hasCommon() ? chatMessage.common.roomId.toString() : '';
    if (commonRoomId.isNotEmpty && commonRoomId != '0' && commonRoomId != danmakuArgs.roomId) return;
    final commonMessageId = chatMessage.hasCommon() ? chatMessage.common.msgId.toString() : '';
    final resolvedMessageId = commonMessageId.isNotEmpty && commonMessageId != '0'
        ? commonMessageId
        : (envelopeMessageId == '0' ? '' : envelopeMessageId);
    final commonTime = chatMessage.hasCommon() ? chatMessage.common.createTime.toInt() : 0;
    final rawCreateTime = commonTime > 0 ? commonTime : chatMessage.eventTime.toInt();
    final sentAt = rawCreateTime <= 0
        ? null
        : DateTime.fromMillisecondsSinceEpoch(rawCreateTime > 100000000000 ? rawCreateTime : rawCreateTime * 1000);
    onMessage?.call(
      LiveMessage(
        type: LiveMessageType.chat,
        color: LiveMessageColor.white,
        // color: chatMessage.common.fullScreenTextColor.
        //     ? LiveMessageColor.white
        //     : LiveMessageColor.numberToColor(color),
        message: chatMessage.content,
        userName: chatMessage.user.nickName,
        userId: chatMessage.user.id.toString(),
        messageId: resolvedMessageId.isEmpty ? '' : 'douyin:$resolvedMessageId',
        sentAt: sentAt,
      ),
    );
  }

  void unPackWebcastRoomUserSeqMessage(List<int> payload) {
    var roomUserSeqMessage = RoomUserSeqMessage.fromBuffer(payload);
    final exactTotal = roomUserSeqMessage.total.toInt();
    final int online;
    if (exactTotal > 0) {
      online = exactTotal;
    } else {
      final onlineText = roomUserSeqMessage.onlineUserForAnchor;
      if (!RegExp(r'[0-9]').hasMatch(onlineText)) return;
      online = LiveRoom.parseAudienceNumber(onlineText);
    }

    onMessage?.call(
      LiveMessage(
        type: LiveMessageType.online,
        data: LiveAudienceUpdate(kind: LiveAudienceMetricKind.onlineViewers, value: online),
        color: LiveMessageColor.white,
        message: "",
        userName: "",
      ),
    );
  }

  void sendAck(dynamic logId, String internalExt) {
    var obj = PushFrame();
    obj.payloadType = 'ack';
    obj.logId = logId;
    obj.payload = utf8.encode(internalExt);
    webScoketUtils?.sendMessage(obj.writeToBuffer());
  }

  void joinRoom(dynamic args) {
    var obj = PushFrame();
    obj.payloadType = 'hb';
    webScoketUtils?.sendMessage(obj.writeToBuffer());
  }

  @override
  Future stop() async {
    _generation++;
    markDisconnected();
    onMessage = null;
    onReconnect = null;
    onClose = null;
    onReady = null;
    await webScoketUtils?.close();
    webScoketUtils = null;
  }

  Future<String> getSignature(String roomId, String uniqueId) async {
    try {
      Map<String, dynamic> params = {
        "live_id": "1",
        "aid": "6383",
        "version_code": DouyinRequestParams.versionCodeValue,
        "webcast_sdk_version": DouyinRequestParams.sdkVersion,
        "room_id": roomId,
        "sub_room_id": "",
        "sub_channel_id": "",
        "did_rule": "3",
        "user_unique_id": uniqueId,
        "device_platform": "web",
        "device_type": "",
        "ac": "",
        "identity": "audience",
      };
      String sigParam = params.entries.map((entry) => '${entry.key}=${entry.value}').join(',');
      var md5SigParam = md5.convert(utf8.encode(sigParam)).toString();
      var signature = generateXBogus(
        md5SigParam,
        1, // counter
      );
      return signature;
    } catch (e) {
      CoreLog.error(e);
      return "";
    } finally {}
  }
}
