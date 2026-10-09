import 'dart:math';

import 'huya_vip_room_id.dart';
import 'huya_request_params.dart';

import 'package:pure_live/core/tars/types.dart';
import 'package:pure_live/core/models/live_message.dart';
import 'package:pure_live/core/tars/base_tars_http.dart';
import 'package:pure_live/core/tars/game_event_message_board_panel.dart';
import 'package:pure_live/core/tars/get_game_event_message_board_rsp.dart';
import 'package:pure_live/core/tars/get_game_event_message_board_req.dart';

int rotl64(int t) {
  final low = t & 0xFFFFFFFF;
  final rotatedLow = ((low << 8) | (low >> 24)) & 0xFFFFFFFF;
  final high = t & ~0xFFFFFFFF;
  return high | rotatedLow;
}

bool isVipRoom(String roomId) => huyaVipRoomIds.contains(roomId);

BaseTarsHttp createHuyaMessageBoardClient() {
  // This endpoint is auxiliary to playback. Do not inherit the legacy TARS
  // timeout (60000 seconds) or let one retry retain another retry's socket.
  final client = BaseTarsHttp('https://wup.huya.com', 'wupui', timeOut: 2, headers: HuyaRequestParams.requestHeaders);
  client.dio.options.sendTimeout = const Duration(seconds: 2);
  client.dio.options.receiveTimeout = const Duration(seconds: 2);
  return client;
}

/// Both initial room load and WebSocket reconciliation request full snapshots
/// with [first]; the latter deduplicates by event ID in its current session.
/// The compatibility single-item path chooses the newest start time, not price.
/// Each call owns the client supplied by [clientFactory] and always closes it.
Future<List<LiveSuperChatMessage>> getHuyaSuperChatMessageList({
  required int lPid,
  bool first = false,
  BaseTarsHttp Function()? clientFactory,
}) async {
  final messageBoardClient = (clientFactory ?? createHuyaMessageBoardClient)();
  var userId = HuyaUserId()..sHuYaUA = HuyaRequestParams.hysdkUa;
  var req = GetGameEventMessageBoardReq()
    ..lPid = lPid
    ..tId = userId
    ..iMessageBoardScope = 0
    ..iPageSize = 50;
  final GetGameEventMessageBoardRsp rsp;
  try {
    rsp = await messageBoardClient
        .tupRequest('getHeadLineMessageBoard', req, GetGameEventMessageBoardRsp())
        .timeout(const Duration(seconds: 3));
  } finally {
    // Future.timeout only stops waiting. Closing the actual transport here
    // prevents outstanding HTTP requests from accumulating on repeated SCs.
    messageBoardClient.dio.close(force: true);
  }
  final messages = huyaSuperChatsFromPanel(rsp.tMessageBoardPanel);
  // 最新在前(按 startTime 逆序);上游注释:虎牙按 money→level→countDown
  // 排序,这里统一调整为时间序,见 dart_simple_live #157 的说明。
  messages.sort((a, b) => b.startTime.compareTo(a.startTime));
  if (first) {
    // 首次拉起只保留最新 10 条,避免一次铺满弹幕区。
    return messages.length > 10 ? messages.sublist(0, 10) : messages;
  }
  return messages.isEmpty ? messages : [messages.first];
}

List<LiveSuperChatMessage> huyaSuperChatsFromPanel(GameEventMessageBoardPanel panel, {DateTime? now}) {
  final at = now ?? DateTime.now();
  final List<LiveSuperChatMessage> messages = [];
  for (final item in panel.vGameEventMessageBoardInfo) {
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

    final endTime = at.add(Duration(seconds: remainSec));
    final startTime = endTime.subtract(Duration(seconds: totalSeconds));

    messages.add(
      LiveSuperChatMessage(
        messageId: item.lMessageId > 0 ? 'huya:${item.lMessageId}' : '',
        backgroundBottomColor: "#246488",
        backgroundColor: "#ffffff",
        endTime: endTime,
        face: item.tMessageUser.sAvatar,
        message: content,
        price: price,
        startTime: startTime,
        userName: item.tMessageUser.sNick.trim(),
      ),
    );
  }
  return messages;
}
