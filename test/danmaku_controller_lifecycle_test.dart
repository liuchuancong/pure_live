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
    final room = LiveRoom(
      roomId: 'room-a',
      platform: 'test',
      danmakuData: const <String, dynamic>{},
    );
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
    final room = LiveRoom(
      roomId: 'room-b',
      platform: 'test',
      danmakuData: const <String, dynamic>{},
    );
    controller.initDanmaku(engine);
    await controller.connectRoom(room);
    expect(host.currentRoomId, 'room-b');

    await controller.stopDanmaku().timeout(const Duration(milliseconds: 200));

    expect(engine.stopCalls, 2, reason: 'pre-connect cleanup plus explicit teardown');
    expect(host.currentRoomId, isNull);
    expect(host.rendererClearCount, 1);
  });

  test('PiP recovery preserves a healthy matching transport and rendered messages', () async {
    final host = _TestDanmakuHost();
    final engine = _CountingDanmaku();
    final controller = DanmakuController(host, recoveryAllowed: (_) => true);
    final room = LiveRoom(
      roomId: 'room-pip',
      platform: 'test',
      danmakuData: const <String, dynamic>{},
    );
    controller.initDanmaku(engine);

    await controller.connectRoom(room);
    await controller.recoverRoomConnection(room);

    expect(engine.startCalls, 1);
    expect(engine.stopCalls, 1, reason: 'only the initial pre-connect cleanup is needed');
    expect(host.currentRoomId, 'room-pip');
    expect(host.rendererClearCount, 0);
    expect(controller.needReconnect(room), isFalse);
  });

  test('PiP recovery rebuilds only a disconnected matching transport', () async {
    final host = _TestDanmakuHost();
    final engine = _CountingDanmaku();
    final controller = DanmakuController(host, recoveryAllowed: (_) => true);
    final room = LiveRoom(
      roomId: 'room-pip-dead',
      platform: 'test',
      danmakuData: const <String, dynamic>{},
    );
    controller.initDanmaku(engine);

    await controller.connectRoom(room);
    engine.simulateDisconnect();
    expect(controller.needReconnect(room), isTrue);

    await controller.recoverRoomConnection(room);

    expect(engine.startCalls, 2);
    expect(engine.stopCalls, 2, reason: 'initial cleanup plus replacement of the dead socket');
    expect(host.currentRoomId, 'room-pip-dead');
    expect(
      host.rendererClearCount,
      0,
      reason: 'same-room recovery keeps the visible history intact',
    );
    expect(controller.needReconnect(room), isFalse);
  });

  test('PiP recovery does not interrupt a matching connection attempt', () async {
    final host = _TestDanmakuHost();
    final engine = _ConnectingDanmaku();
    final controller = DanmakuController(host, recoveryAllowed: (_) => true);
    final room = LiveRoom(
      roomId: 'room-pip-connecting',
      platform: 'test',
      danmakuData: const <String, dynamic>{},
    );
    controller.initDanmaku(engine);

    final connection = controller.connectRoom(room);
    await engine.started.future;
    await controller.recoverRoomConnection(room);
    engine.release.complete();
    await connection;

    expect(engine.startCalls, 1);
    expect(engine.stopCalls, 1);
    expect(host.currentRoomId, 'room-pip-connecting');
    expect(controller.needReconnect(room), isFalse);
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
    markDisconnected();
  }

  void simulateDisconnect() => markDisconnected();
}

class _ConnectingDanmaku extends LiveDanmaku {
  int startCalls = 0;
  int stopCalls = 0;
  final Completer<void> started = Completer<void>();
  final Completer<void> release = Completer<void>();

  @override
  Future<void> start(dynamic args) async {
    startCalls++;
    started.complete();
    await release.future;
    markConnected();
    onReady?.call();
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    markDisconnected();
  }
}
