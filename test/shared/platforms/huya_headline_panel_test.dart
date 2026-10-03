import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/tars/game_event_message_board_info.dart';
import 'package:pure_live/core/tars/game_event_message_board_panel.dart';
import 'package:pure_live/core/tars/types.dart';
import 'package:pure_live/shared/platforms/huya/huya_danmaku.dart';

/// 用本仓自己的 Tars 写入器拼出一块留言板面板（字段与生成类一致），于是测试不依赖
/// 上游的 fixture 文件：`uri 2001314` 的消息体就是这块面板。
Uint8List panelBytes(List<GameEventMessageBoardInfo> entries) =>
    (GameEventMessageBoardPanel()..vGameEventMessageBoardInfo = entries).toByteArray();

GameEventMessageBoardInfo entryBytes({
  required String nick,
  required String text,
  int cost = 0,
  int totalSec = 0,
  int countdown = 0,
  int messageId = 0,
  int costPay = 0,
}) {
  final user = MessageUser()..sNick = nick;
  return GameEventMessageBoardInfo()
    ..tMessageUser = user
    ..sContent = text
    ..iCost = cost
    ..iTotalSec = totalSec
    ..iCountDown = countdown
    ..lMessageId = messageId
    ..iCostPay = costPay;
}

void main() {
  final now = DateTime.utc(2026, 10, 4, 12);

  test('C-9：通知自带的面板按上游字段解出醒目留言', () {
    final chats = HuyaDanmaku.superChatsFromPanel(
      panelBytes([entryBytes(nick: '观众A', text: '加油', cost: 30, totalSec: 60, countdown: 45, messageId: 31)]),
      now: now,
    );

    expect(chats, isNotNull);
    expect(chats!.length, 1);
    final chat = chats.single;
    expect(chat.messageId, 'huya:31');
    expect(chat.userName, '观众A');
    expect(chat.message, '加油');
    expect(chat.price, 30);
    // 倒计时 45 秒结束，整条按 60 秒算，于是起点在"现在"之前 15 秒。
    expect(chat.endTime.difference(now).inSeconds, 45);
    expect(chat.startTime.difference(now).inSeconds, -15);
  });

  test('C-9：空面板表示留言板已空（不是"不是面板"）', () {
    final chats = HuyaDanmaku.superChatsFromPanel(panelBytes([]), now: now);

    expect(chats, isNotNull);
    expect(chats, isEmpty);
  });

  test('C-9：不是面板的消息体返回 null，调用方照旧后台补拉', () {
    expect(HuyaDanmaku.superChatsFromPanel(const <int>[]), isNull);
    expect(HuyaDanmaku.superChatsFromPanel(Uint8List.fromList(<int>[1, 2, 3, 4, 5])), isNull);
  });

  test('C-9：没有文本、倒计时与累计都为 0 的条目不算一条留言', () {
    final chats = HuyaDanmaku.superChatsFromPanel(
      panelBytes([
        entryBytes(nick: '观众A', text: '   ', cost: 30, totalSec: 60, countdown: 45, messageId: 7),
        entryBytes(nick: '观众B', text: '还在', cost: 0, totalSec: 0, countdown: 0, messageId: 8),
      ]),
      now: now,
    );

    expect(chats, isNotNull);
    expect(chats, isEmpty);
  });

  test('C-9：付费字段（iCostPay）在没有 iCost 时按分换算', () {
    final chats = HuyaDanmaku.superChatsFromPanel(
      panelBytes([entryBytes(nick: '观众C', text: '打赏', totalSec: 30, countdown: 10, costPay: 12500, messageId: 9)]),
      now: now,
    );

    expect(chats!.single.price, 125);
  });
}
