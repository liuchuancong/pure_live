import 'dart:math';

import 'huya_request_params.dart';

import 'package:pure_live/core/tars/types.dart';
import 'package:pure_live/common/models/live_message.dart';
import 'package:pure_live/pkg/tars/net/base_tars_http.dart';
import 'package:pure_live/core/tars/get_game_event_message_board_rsp.dart';
import 'package:pure_live/core/tars/get_game_event_message_board_req.dart';

int rotl64(int t) {
  final low = t & 0xFFFFFFFF;
  final rotatedLow = ((low << 8) | (low >> 24)) & 0xFFFFFFFF;
  final high = t & ~0xFFFFFFFF;
  return high | rotatedLow;
}

// 这里会有一个复用，当taf-websocket监听到 type=2001314 重新拉起huya-sc-list
// 为了符合各个平台接口数据统一直通前端的需求，从site.getSuperMessage 标记首次拉起全量返回
// 从 danmaku.websocket拉起，则只返回最后一个，实现增量SC
// WebSocket 通知可能早于留言板写入；调用方会执行有界补偿拉取。
// lPid--s = a.lPresenterUid == topSid
Future<List<LiveSuperChatMessage>> getHuyaSuperChatMessageList({required int lPid, bool first = false}) async {
  final BaseTarsHttp messageBoardClient = BaseTarsHttp(
    "http://wup.huya.com",
    "wupui",
    headers: HuyaRequestParams.requestHeaders,
  );
  var userId = HuyaUserId()..sHuYaUA = HuyaRequestParams.hysdkUa;
  var req = GetGameEventMessageBoardReq()
    ..lPid = lPid
    ..tId = userId
    ..iMessageBoardScope = 0
    ..iPageSize = 50;
  var rsp = await messageBoardClient.tupRequest("getHeadLineMessageBoard", req, GetGameEventMessageBoardRsp());
  final now = DateTime.now();
  final List<LiveSuperChatMessage> messages = [];
  for (final item in rsp.tMessageBoardPanel.vGameEventMessageBoardInfo) {
    final content = item.sContent.trim();
    if (content.isEmpty) {
      continue;
    }
    // start_time---cur--->end_time
    final remainSec = item.iCountDown > 0 ? item.iCountDown : item.iTotalSec;
    if (remainSec <= 0) {
      continue;
    }

    final totalSeconds = item.iTotalSec > 0 ? item.iTotalSec : remainSec;

    var price = item.iCost;
    if (price <= 0 && item.iCostPay > 0) {
      price = max(1, (item.iCostPay / 100).round());
    }

    final endTime = now.add(Duration(seconds: remainSec));
    final startTime = endTime.subtract(Duration(seconds: totalSeconds));

    final message = LiveSuperChatMessage(
      messageId: item.lMessageId > 0 ? 'huya:${item.lMessageId}' : '',
      backgroundBottomColor: "#246488",
      backgroundColor: "#ffffff",
      endTime: endTime,
      face: item.tMessageUser.sAvatar,
      message: content,
      price: price,
      startTime: startTime,
      userName: item.tMessageUser.sNick.trim(),
    );

    messages.add(message);
  }
  // https://github.com/SlotSun/dart_simple_live/issues/157#issuecomment-5479457055
  // huya 按 money->level->countDown 排序 调整为 startTime 逆序 最新的在最前面
  messages.sort((a, b) => b.startTime.compareTo(a.startTime));
  if (first) {
    return messages.length > 10 ? messages.sublist(0, 10) : messages;
  } else {
    return [messages.first];
  }
}

class RequestIdGenerator {
  static int _counter = 0;

  static int next() {
    return _counter++;
  }

  static void reset([int value = 0]) {
    _counter = value;
  }
}
