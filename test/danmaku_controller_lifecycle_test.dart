import 'dart:async';

import 'package:pure_live/get/get.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/common/models/live_message.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
import 'package:pure_live/modules/live_play/states/live_play_state.dart';
import 'package:pure_live/modules/live_play/controllers/danmaku_controller.dart';
import 'package:pure_live/modules/live_play/controllers/danmaku_session_host.dart';

void main() {
  test('a stalled transport start is bounded, stopped and available for reconnect', () async {
    final host = _TestDanmakuHost();
    final engine = _StalledStartDanmaku();
    final controller = DanmakuController(
      host,
      startTimeout: const Duration(milliseconds: 20),
      stopTimeout: const Duration(milliseconds: 20),
    );
    final room = LiveRoom(roomId: 'room-a', platform: 'test', danmakuData: const <String, dynamic>{});
    controller.initDanmaku(engine);

    await controller.connectRoom(room).timeout(const Duration(milliseconds: 200));

    expect(engine.startCalls, 1);
    expect(engine.stopCalls, 2, reason: 'pre-connect cleanup plus timeout cleanup');
    expect(controller.needReconnect(room), isTrue);
    expect(host.currentRoomId, isNull);
  });

  test('a stalled transport stop does not block room teardown forever', () async {
    final host = _TestDanmakuHost();
    final engine = _StalledStopDanmaku();
    final controller = DanmakuController(
      host,
      startTimeout: const Duration(milliseconds: 20),
      stopTimeout: const Duration(milliseconds: 20),
    );
    final room = LiveRoom(roomId: 'room-b', platform: 'test', danmakuData: const <String, dynamic>{});
    controller.initDanmaku(engine);
    await controller.connectRoom(room);
    expect(host.currentRoomId, 'room-b');

    await controller.stopDanmaku().timeout(const Duration(milliseconds: 200));

    expect(engine.stopCalls, 2, reason: 'pre-connect cleanup plus explicit teardown');
    expect(host.currentRoomId, isNull);
    expect(host.rendererClearCount, 1);
  });

  test('PiP recovery rebuilds a matching room transport without clearing rendered messages', () async {
    final host = _TestDanmakuHost();
    final engine = _CountingDanmaku();
    final controller = DanmakuController(host);
    final room = LiveRoom(roomId: 'room-pip', platform: 'test', danmakuData: const <String, dynamic>{});
    controller.initDanmaku(engine);

    await controller.connectRoom(room);
    await controller.connectRoom(room, force: true);

    expect(engine.startCalls, 2);
    expect(engine.stopCalls, 2, reason: 'initial cleanup plus same-room PiP transport replacement');
    expect(host.currentRoomId, 'room-pip');
    expect(host.rendererClearCount, 0, reason: 'same-room recovery keeps the visible barrage intact');
  });
}

class _TestDanmakuHost implements DanmakuSessionHost {
  @override
  final Rx<LivePlayState> state = const LivePlayState().obs;

  String? currentRoomId;
  int rendererClearCount = 0;
  final List<String> systemMessages = <String>[];

  @override
  void addDanmakuMessage(LiveMessage message, {bool immediate = false}) {}

  @override
  void updateRuntimeAudience(dynamic value) {}

  @override
  void addSystemMessage(String text) => systemMessages.add(text);

  @override
  void updateDanmakuRoomId(String? roomId) => currentRoomId = roomId;

  @override
  void clearRenderedDanmaku() => rendererClearCount++;

  @override
  void addAddSuperChat(LiveMessage msg) {}
}

class _StalledStartDanmaku extends LiveDanmaku {
  int startCalls = 0;
  int stopCalls = 0;
  final Completer<void> _start = Completer<void>();

  @override
  Future<void> start(dynamic args) {
    startCalls++;
    return _start.future;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }
}

class _StalledStopDanmaku extends LiveDanmaku {
  int stopCalls = 0;
  final Completer<void> _stop = Completer<void>();

  @override
  Future<void> start(dynamic args) async {
    markConnected();
    onReady?.call();
  }

  @override
  Future<void> stop() {
    stopCalls++;
    return _stop.future;
  }
}

class _CountingDanmaku extends LiveDanmaku {
  int startCalls = 0;
  int stopCalls = 0;

  @override
  Future<void> start(dynamic args) async {
    startCalls++;
    markConnected();
    onReady?.call();
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }
}
