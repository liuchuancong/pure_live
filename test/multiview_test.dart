import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/modules/multiview/cells/multiview_cell_player.dart';
import 'package:pure_live/modules/multiview/models/multiview_models.dart';
import 'package:pure_live/modules/multiview/multiview_controller.dart';

/// 记录调用序列的假单格播放器。
///
/// 所有操作按「名称:动作」写入共享日志，用于断言释放顺序与静音互斥。
/// 音量模型与真实实现一致：会话音量（sessionVolume）与静音标志（muted）
/// 相互独立，[volume] 暴露实际输出音量（muted ? 0 : sessionVolume）。
class _RecordingPlayer implements MultiviewCellPlayerHandle {
  _RecordingPlayer(this._log, this.name);

  final List<String> _log;
  final String name;

  /// 会话音量（setVolume 的目标值）。
  double sessionVolume = 1.0;

  /// 静音标志（起播默认静音）。
  bool muted = true;

  /// 实际输出音量，兼容既有断言。
  @override
  double volume = 0.0;

  /// 播放状态（start/open/resume 置 true，pause/dispose 置 false）。
  bool playing = false;

  int startCalls = 0;
  int openCalls = 0;
  int resumeCalls = 0;
  Object? startError;

  /// 非空时 pause 挂起直至门闩完成，模拟慢速原生释放。
  Completer<void>? pauseGate;

  /// 非空时 pause 抛出，验证销毁仍执行。
  Object? pauseError;

  /// 非空时静音切换挂起，模拟原生音频调用乱序风险。
  Completer<void>? muteGate;

  /// 非空时 disposePlayer 抛出，模拟原生销毁失败。
  Object? disposeError;

  final StreamController<bool> _playingController = StreamController<bool>.broadcast();

  @override
  VideoController? get videoController => null;

  @override
  bool get isPlaying => playing;

  @override
  Stream<bool> get playingStream => _playingController.stream;

  void _setPlaying(bool value) {
    playing = value;
    _playingController.add(value);
  }

  @override
  Future<void> start({required String url, required Map<String, String> headers}) async {
    _log.add('$name:start');
    startCalls++;
    // 契约：一律静音起播。
    muted = true;
    volume = 0.0;
    final error = startError;
    if (error != null) throw error;
    _setPlaying(true);
  }

  @override
  Future<void> open({required String url, required Map<String, String> headers}) async {
    _log.add('$name:open:$url');
    openCalls++;
    _setPlaying(true);
  }

  @override
  Future<void> setMuted(bool muted) async {
    _log.add('$name:mute:${muted ? 'on' : 'off'}');
    final gate = muteGate;
    if (gate != null) await gate.future;
    this.muted = muted;
    volume = muted ? 0.0 : sessionVolume;
  }

  @override
  Future<void> resume() async {
    _log.add('$name:resume');
    resumeCalls++;
    _setPlaying(true);
  }

  @override
  Future<void> setVolume(double v) async {
    _log.add('$name:volume:${v.toStringAsFixed(2)}');
    sessionVolume = v.clamp(0.0, 1.0);
    if (!muted) {
      volume = sessionVolume;
    }
  }

  @override
  Future<void> pause() async {
    _log.add('$name:pause');
    _setPlaying(false);
    final gate = pauseGate;
    if (gate != null) {
      await gate.future;
    }
    final error = pauseError;
    if (error != null) throw error;
  }

  @override
  Future<void> disposePlayer() async {
    _log.add('$name:pDispose');
    _setPlaying(false);
    final error = disposeError;
    if (error != null) throw error;
  }
}

/// 记录调用的假弹幕引擎。
class _FakeDanmaku extends LiveDanmaku {
  _FakeDanmaku(this.log, this.name);

  final List<String> log;
  final String name;

  @override
  Future<void> start(dynamic args) async {
    log.add('$name:start');
    markConnected();
  }

  @override
  Future<void> stop() async {
    log.add('$name:stop');
    markDisconnected();
  }
}

/// 测试装配体：假工厂 + 假解析器 + 可控的解析门闩。
class _Harness {
  _Harness({int? maxCellCount}) {
    controller = MultiviewController(
      playerFactory: _factory,
      streamResolver: _resolver,
      pauseGlobalPlayback: () async => globalPauseCalls++,
      danmakuEngineFactory: _danmakuFactory,
      roomVolumeLoader: (room) => savedRoomVolumes[_volumeKey(room)] ?? 1.0,
      roomVolumeSaver: (room, volume) async {
        savedRoomVolumes[_volumeKey(room)] = volume;
      },
      maxCellCount: maxCellCount,
    );
  }

  final List<String> log = <String>[];
  final List<_RecordingPlayer> players = <_RecordingPlayer>[];
  final List<(int, int)> requestedSizes = <(int, int)>[];
  final Map<String, Completer<void>> gates = <String, Completer<void>>{};
  final Set<String> resolveFailures = <String>{};
  final Set<String> resolvedOfflineRooms = <String>{};
  final Map<String, bool> resolvePreferences = <String, bool>{};
  final Map<String, Completer<void>> qualityGates = <String, Completer<void>>{};
  final Set<String> qualityLoadFailures = <String>{};
  final Map<String, _FakeDanmaku> danmakuEngines = <String, _FakeDanmaku>{};
  final Map<String, double> savedRoomVolumes = <String, double>{};
  int globalPauseCalls = 0;
  int playerSeq = 0;
  int danmakuSeq = 0;

  /// 下一个工厂产物的起播异常（消费一次）。
  Object? nextStartError;

  late final MultiviewController controller;

  String _volumeKey(LiveRoom room) => '${room.platform}/${room.roomId}';

  MultiviewCellPlayerHandle _factory({required int renderWidth, required int renderHeight}) {
    requestedSizes.add((renderWidth, renderHeight));
    final player = _RecordingPlayer(log, 'p${playerSeq++}');
    final error = nextStartError;
    if (error != null) {
      player.startError = error;
      nextStartError = null;
    }
    players.add(player);
    return player;
  }

  Future<MultiviewStreamSource> _resolver(LiveRoom room, {required bool preferLowest}) async {
    final id = room.roomId!;
    if (resolvedOfflineRooms.contains(id)) {
      throw MultiviewRoomOffline(room.copyWith(status: false, liveStatus: LiveStatus.offline, isRecord: false));
    }
    if (resolveFailures.contains(id)) {
      throw StateError('resolver boom for $id');
    }
    final gate = gates[id];
    if (gate != null) {
      await gate.future;
    }
    resolvePreferences[id] = preferLowest;
    // 约定首项最高档、末项最低档，与站点适配器排序一致。
    final qualities = [LivePlayQuality(quality: '原画'), LivePlayQuality(quality: '流畅')];
    final index = preferLowest ? qualities.length - 1 : 0;
    // 线路 0 保持与旧断言兼容的 URL 形态；线路 1 为查询参数变体。
    final lines = [
      'https://stream/$id/${qualities[index].quality}',
      'https://stream/$id/${qualities[index].quality}?line=1',
    ];
    return MultiviewStreamSource(
      url: lines[0],
      headers: const {'user-agent': 'test'},
      qualities: qualities,
      qualityIndex: index,
      qualityLoader: (quality) async {
        if (qualityLoadFailures.contains('$id:${quality.quality}')) {
          throw StateError('load boom for ${quality.quality}');
        }
        final loadGate = qualityGates[id];
        if (loadGate != null) {
          await loadGate.future;
        }
        final nextLines = ['https://stream/$id/${quality.quality}', 'https://stream/$id/${quality.quality}?line=1'];
        return MultiviewStreamSource(url: nextLines[0], headers: const {'user-agent': 'test'}, lines: nextLines);
      },
      lines: lines,
    );
  }

  LiveDanmaku _danmakuFactory(LiveRoom room) {
    final engine = _FakeDanmaku(log, 'dm${danmakuSeq++}');
    danmakuEngines[room.roomId!] = engine;
    return engine;
  }

  /// 让事件循环排空微任务，使后台释放/静音序列完成。
  Future<void> pump() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }
}

LiveRoom _room(String id) => LiveRoom(
  roomId: id,
  platform: 'bilibili',
  status: true,
  liveStatus: LiveStatus.live,
  danmakuData: <String, dynamic>{'id': id},
);

void main() {
  test('offline and failed multiview cells remain picker targets', () {
    expect(isMultiviewCellAssignable(MultiviewCellStatus.empty), isTrue);
    expect(isMultiviewCellAssignable(MultiviewCellStatus.offline), isTrue);
    expect(isMultiviewCellAssignable(MultiviewCellStatus.error), isTrue);
    expect(isMultiviewCellAssignable(MultiviewCellStatus.resolving), isFalse);
    expect(isMultiviewCellAssignable(MultiviewCellStatus.playing), isFalse);
  });

  group('MultiviewController', () {
    test('assignRoom 走 empty→resolving→playing 并自动成为音频焦点', () async {
      final harness = _Harness();
      final controller = harness.controller;
      final gate = Completer<void>();
      harness.gates['r1'] = gate;

      final assigning = controller.assignRoom(0, _room('r1'));
      await harness.pump();
      expect(controller.cells[0].status, MultiviewCellStatus.resolving);

      gate.complete();
      await assigning;

      expect(controller.cells[0].status, MultiviewCellStatus.playing);
      expect(controller.cells[0].errorKind, isNull);
      expect(controller.cells[0].errorDetail, isNull);
      expect(controller.cells[0].room?.roomId, 'r1');
      expect(controller.audioFocusIndex, 0);
      // 静音起播后因获得焦点而恢复音量。
      expect(harness.players[0].volume, 1.0);

      // 第二格成功后抢占焦点，第一格被静音。
      await controller.assignRoom(1, _room('r2'));
      expect(controller.audioFocusIndex, 1);
      expect(harness.players[0].volume, 0.0);
      expect(harness.players[1].volume, 1.0);
    });

    test('已知未开播房间进入业务空态且不解析、不创建播放器', () async {
      final harness = _Harness();
      final controller = harness.controller;
      final room = LiveRoom(
        roomId: 'offline-known',
        platform: 'bilibili',
        nick: '未开播主播',
        status: false,
        liveStatus: LiveStatus.offline,
      );

      await controller.assignRoom(0, room);

      expect(controller.cells[0].status, MultiviewCellStatus.offline);
      expect(controller.cells[0].errorKind, isNull);
      expect(controller.cells[0].errorDetail, isNull);
      expect(controller.cells[0].room?.nick, '未开播主播');
      expect(harness.resolvePreferences, isEmpty);
      expect(harness.players, isEmpty);
    });

    test('严格解析后确认未开播与传输解析失败分流', () async {
      final harness = _Harness();
      final controller = harness.controller;
      harness.resolvedOfflineRooms.add('offline-after-refresh');

      await controller.assignRoom(0, _room('offline-after-refresh'));

      expect(controller.cells[0].status, MultiviewCellStatus.offline);
      expect(controller.cells[0].errorKind, isNull);
      expect(harness.players, isEmpty);

      harness.resolveFailures.add('transport-error');
      await controller.assignRoom(1, _room('transport-error'));

      expect(controller.cells[1].status, MultiviewCellStatus.error);
      expect(controller.cells[1].errorKind, MultiviewCellErrorKind.resolveFailure);
      expect(controller.cells[1].errorDetail, contains('resolver boom'));
    });

    test('assignRoom 按布局均分结果固定每格渲染分辨率', () async {
      final harness = _Harness();
      final controller = harness.controller;

      // 初始布局 quad：无窗口上下文时基线 1280x720 → 每格 640x360。
      await controller.assignRoom(0, _room('r1'));
      expect(harness.requestedSizes.last, (640, 360));

      await controller.setLayout(MultiviewLayout.dual);
      await controller.assignRoom(1, _room('r2'));
      // dual（1 行 x 2 列）：640x720。
      expect(harness.requestedSizes.last, (640, 720));
    });

    test('setAudioFocus 切换后新旧格静音状态互斥', () async {
      final harness = _Harness();
      final controller = harness.controller;
      await controller.assignRoom(0, _room('r1'));
      await controller.assignRoom(1, _room('r2'));
      expect(controller.audioFocusIndex, 1);

      controller.setAudioFocus(0);
      await harness.pump();

      expect(controller.audioFocusIndex, 0);
      expect(harness.players[0].volume, 1.0);
      expect(harness.players[1].volume, 0.0);
      expect(harness.log.where((e) => e == 'p0:mute:off'), isNotEmpty);
      expect(harness.log.where((e) => e == 'p1:mute:on'), isNotEmpty);
    });

    test('连续切换音频焦点时最后一次选择胜出', () async {
      final harness = _Harness();
      final controller = harness.controller;
      await controller.assignRoom(0, _room('r1'));
      await controller.assignRoom(1, _room('r2'));
      await harness.pump();

      final gate = Completer<void>();
      harness.players[1].muteGate = gate;
      controller.setAudioFocus(0);
      controller.setAudioFocus(1);
      expect(controller.audioFocusIndex, 1);

      gate.complete();
      await harness.pump();

      expect(harness.players[0].muted, isTrue);
      expect(harness.players[1].muted, isFalse);
      expect(harness.players[0].volume, 0.0);
      expect(harness.players[1].volume, 1.0);
    });

    test('removeCell 按严格顺序释放并回到 empty', () async {
      final harness = _Harness();
      final controller = harness.controller;
      await controller.assignRoom(0, _room('r1'));
      await controller.assignRoom(1, _room('r2'));
      harness.log.clear();

      controller.removeCell(0);
      await harness.pump();

      final releaseOrder = harness.log.where((e) => e.startsWith('p0:')).toList();
      expect(releaseOrder, ['p0:pause', 'p0:pDispose']);
      expect(controller.cells[0].status, MultiviewCellStatus.empty);
      expect(controller.cells[0].videoController, isNull);
      // 焦点从被移除的格转移到仍在播放的格。
      expect(controller.audioFocusIndex, 1);
    });

    test('setLayout quad→dual 保留前两格播放状态并释放第三/四格', () async {
      final harness = _Harness();
      final controller = harness.controller;
      for (var i = 0; i < 4; i++) {
        await controller.assignRoom(i, _room('r$i'));
      }
      harness.log.clear();

      await controller.setLayout(MultiviewLayout.dual);

      expect(controller.layout.value, MultiviewLayout.dual);
      expect(controller.cells.length, MultiviewLayout.dual.capacity);
      expect(controller.cells[0].status, MultiviewCellStatus.playing);
      expect(controller.cells[0].room?.roomId, 'r0');
      expect(controller.cells[1].status, MultiviewCellStatus.playing);
      expect(controller.cells[1].room?.roomId, 'r1');
      for (final name in ['p2', 'p3']) {
        final order = harness.log.where((e) => e.startsWith('$name:')).toList();
        expect(order, ['$name:pause', '$name:pDispose']);
      }
      expect(controller.audioFocusIndex, lessThan(2));
    });

    test('disposeAll 释放全部格且 cells 回到 empty', () async {
      final harness = _Harness();
      final controller = harness.controller;
      await controller.assignRoom(0, _room('r1'));
      await controller.assignRoom(2, _room('r2'));

      await controller.disposeAll();

      expect(controller.cells.length, MultiviewLayout.quad.capacity);
      for (final cell in controller.cells) {
        expect(cell.status, MultiviewCellStatus.empty);
        expect(cell.room, isNull);
      }
      for (final player in harness.players) {
        final order = harness.log.where((e) => e.startsWith('${player.name}:')).toList();
        final releaseStart = order.indexOf('${player.name}:pause');
        expect(releaseStart, greaterThan(0), reason: '${player.name} 应先起播再释放');
        expect(order.sublist(releaseStart), ['${player.name}:pause', '${player.name}:pDispose']);
      }
      expect(controller.audioFocusIndex, 0);
    });

    test('assignRoom 解析失败置 error 且不创建播放器', () async {
      final harness = _Harness();
      final controller = harness.controller;
      harness.resolveFailures.add('bad');

      await controller.assignRoom(0, _room('bad'));

      expect(controller.cells[0].status, MultiviewCellStatus.error);
      expect(controller.cells[0].errorKind, MultiviewCellErrorKind.resolveFailure);
      expect(controller.cells[0].errorDetail, contains('resolver boom for bad'));
      expect(harness.players, isEmpty);
    });

    test('assignRoom 起播失败置 error 并按序释放已创建的播放器', () async {
      final harness = _Harness();
      final controller = harness.controller;
      harness.nextStartError = StateError('open boom');

      await controller.assignRoom(0, _room('r1'));

      expect(controller.cells[0].status, MultiviewCellStatus.error);
      expect(controller.cells[0].errorKind, MultiviewCellErrorKind.startFailure);
      expect(controller.cells[0].errorDetail, contains('open boom'));
      final order = harness.log.where((e) => e.startsWith('p0:')).toList();
      expect(order, ['p0:start', 'p0:pause', 'p0:pDispose']);
      // 失败后该格不持有播放器句柄，可重新分配。
      await controller.assignRoom(0, _room('r2'));
      expect(controller.cells[0].status, MultiviewCellStatus.playing);
      expect(controller.cells[0].errorKind, isNull);
    });

    test('向已占用格重复 assignRoom 先按序释放旧播放器', () async {
      final harness = _Harness();
      final controller = harness.controller;
      await controller.assignRoom(0, _room('r1'));
      harness.log.clear();

      await controller.assignRoom(0, _room('r2'));

      final order = harness.log.where((e) => e.startsWith('p0:')).toList();
      expect(order, ['p0:pause', 'p0:pDispose']);
      expect(controller.cells[0].status, MultiviewCellStatus.playing);
      expect(controller.cells[0].room?.roomId, 'r2');
      expect(harness.players.length, 2);
    });

    test('onInit 暂停全局播放器恰好一次', () async {
      final harness = _Harness();
      final controller = harness.controller;

      controller.onInit();

      await harness.pump();
      expect(harness.globalPauseCalls, 1);
    });

    test('focus 布局容量为 4 且渲染均分复用 quad 的 2x2 数学', () {
      expect(MultiviewLayout.focus.capacity, 4);
      expect(MultiviewLayout.focus.columns, 2);
      expect(MultiviewLayout.focus.rows, 2);
    });

    test('promoteCell 更新大画面格并互斥切换音频焦点', () async {
      final harness = _Harness();
      final controller = harness.controller;
      await controller.assignRoom(0, _room('r1'));
      await controller.assignRoom(1, _room('r2'));
      expect(controller.audioFocusIndex, 1);

      await controller.setLayout(MultiviewLayout.focus);
      await controller.promoteCell(0);
      await harness.pump();

      expect(controller.focusedCellIndex.value, 0);
      expect(controller.audioFocusIndex, 0);
      expect(harness.players[0].volume, 1.0);
      expect(harness.players[1].volume, 0.0);
      // 聚焦模型：晋升不迁移、不重建播放器实例。
      expect(harness.log.where((e) => e.startsWith('p0:start')), hasLength(1));
      expect(harness.log.where((e) => e.startsWith('p1:start')), hasLength(1));
    });

    test('setLayout quad→focus→dual 钳制越界的 focusedCellIndex', () async {
      final harness = _Harness();
      final controller = harness.controller;
      await controller.setLayout(MultiviewLayout.focus);
      await controller.promoteCell(3);
      expect(controller.focusedCellIndex.value, 3);

      await controller.setLayout(MultiviewLayout.dual);

      expect(controller.focusedCellIndex.value, 1);
    });

    test('disposeAll 后 focusedCellIndex 归零', () async {
      final harness = _Harness();
      final controller = harness.controller;
      await controller.assignRoom(2, _room('r2'));
      await controller.promoteCell(2);
      expect(controller.focusedCellIndex.value, 2);

      await controller.disposeAll();

      expect(controller.focusedCellIndex.value, 0);
    });

    test('进入 focus 布局时显示焦点同步为音频焦点格', () async {
      final harness = _Harness();
      final controller = harness.controller;
      await controller.assignRoom(0, _room('r1'));
      await controller.assignRoom(2, _room('r2'));
      expect(controller.audioFocusIndex, 2);

      await controller.setLayout(MultiviewLayout.focus);

      // 视觉跟随既有声源，音频零扰动。
      expect(controller.focusedCellIndex.value, 2);
      expect(controller.audioFocusIndex, 2);
    });

    test('focus 下向非大格选台不抢声源，晋升后才出声', () async {
      final harness = _Harness();
      final controller = harness.controller;
      await controller.setLayout(MultiviewLayout.focus);
      await controller.assignRoom(0, _room('r1'));
      expect(controller.audioFocusIndex, 0);

      await controller.assignRoom(2, _room('r2'));

      // 新格 playing 但保持静音，大格仍是唯一声源。
      final bigPlayer = harness.players.first;
      final smallPlayer = harness.players.last;
      expect(controller.cells[2].status, MultiviewCellStatus.playing);
      expect(controller.audioFocusIndex, 0);
      expect(controller.focusedCellIndex.value, 0);
      expect(bigPlayer.volume, 1.0);
      expect(smallPlayer.volume, 0.0);

      // 用户点击晋升后声音才跟随大画面。
      await controller.promoteCell(2);
      await harness.pump();
      expect(controller.focusedCellIndex.value, 2);
      expect(controller.audioFocusIndex, 2);
      expect(bigPlayer.volume, 0.0);
      expect(smallPlayer.volume, 1.0);
    });

    test('removeCell 关闭大格后显示焦点转移到第一个播放中的格', () async {
      final harness = _Harness();
      final controller = harness.controller;
      await controller.setLayout(MultiviewLayout.focus);
      await controller.assignRoom(0, _room('r1'));
      await controller.assignRoom(1, _room('r2'));
      await controller.assignRoom(2, _room('r3'));
      await controller.promoteCell(1);
      expect(controller.focusedCellIndex.value, 1);

      controller.removeCell(1);

      expect(controller.cells[1].status, MultiviewCellStatus.empty);
      expect(controller.focusedCellIndex.value, 0);
      // 音频焦点同样已转移到第一个播放中的格。
      expect(controller.audioFocusIndex, 0);
    });

    test('disposeAll 同步前置清空全部格状态，后台销毁不阻塞', () async {
      final harness = _Harness();
      final controller = harness.controller;
      await controller.assignRoom(0, _room('r1'));
      await controller.assignRoom(2, _room('r2'));
      await controller.promoteCell(2);

      // 第一个句柄的 pause 挂起，模拟慢速原生释放。
      final gate = Completer<void>();
      harness.players.first.pauseGate = gate;

      final disposing = controller.disposeAll();

      // 未 await 完成：渲染引用与格子状态必须已同步摘除，
      // 保证 pop 动画期间仍在树中的 Video widget 不会读到已销毁的 notifier。
      for (final cell in controller.cells) {
        expect(cell.status, MultiviewCellStatus.empty);
        expect(cell.videoController, isNull);
        expect(cell.room, isNull);
      }
      expect(controller.focusedCellIndex.value, 0);
      expect(controller.audioFocusIndex, 0);

      gate.complete();
      await disposing;

      // 后台串行销毁仍按 pause → disposePlayer 两步完成。
      expect(harness.log.where((e) => e.endsWith(':pDispose')), hasLength(2));
    });

    test('disposeAll 单句柄销毁异常不中断其余销毁', () async {
      final harness = _Harness();
      final controller = harness.controller;
      await controller.assignRoom(0, _room('r1'));
      await controller.assignRoom(1, _room('r2'));
      harness.players.first.disposeError = StateError('dispose boom');

      await controller.disposeAll();

      // 第一个句柄抛异常后循环继续，第二个句柄仍被完整销毁。
      expect(harness.log.where((e) => e.endsWith(':pDispose')), hasLength(2));
      expect(controller.cells.every((cell) => cell.status == MultiviewCellStatus.empty), isTrue);
    });

    test('pause 异常时 teardown 仍销毁播放器', () async {
      final harness = _Harness();
      final controller = harness.controller;
      await controller.assignRoom(0, _room('r1'));
      harness.players.first.pauseError = StateError('pause boom');

      await controller.disposeAll();

      expect(harness.log.where((e) => e == 'p0:pause'), hasLength(1));
      expect(harness.log.where((e) => e == 'p0:pDispose'), hasLength(1));
    });

    test('focus 下 addCell 动态增长至 maxCells 上限', () async {
      final harness = _Harness();
      final controller = harness.controller;
      await controller.setLayout(MultiviewLayout.focus);
      expect(controller.canAddCell, isTrue);

      while (controller.canAddCell) {
        await controller.addCell();
      }

      expect(controller.cells.length, MultiviewController.maxCells);
      expect(controller.canAddCell, isFalse);
      await expectLater(controller.addCell(), throwsStateError);
    });

    test('移动端配置的四路上限阻止额外解码器', () async {
      final harness = _Harness(maxCellCount: 4);
      final controller = harness.controller;
      await controller.setLayout(MultiviewLayout.focus);

      expect(controller.canAddCell, isFalse);
      expect(controller.cells, hasLength(4));
      await expectLater(controller.addCell(), throwsStateError);
    });

    test('非 focus 布局调用 addCell Fail Fast', () async {
      final harness = _Harness();
      final controller = harness.controller;
      expect(controller.layout.value, MultiviewLayout.quad);
      expect(controller.canAddCell, isFalse);

      await expectLater(controller.addCell(), throwsStateError);
      expect(controller.cells.length, MultiviewLayout.quad.capacity);
    });

    test('setCellQuality 同 Player 换流并更新档位', () async {
      final harness = _Harness();
      final controller = harness.controller;
      await controller.assignRoom(0, _room('r1'));
      final player = harness.players.first;
      expect(player.startCalls, 1);

      await controller.setCellQuality(0, 1);

      // 不重建播放器：start 计数不变，走同实例 open 换流。
      expect(player.startCalls, 1);
      expect(player.openCalls, 1);
      expect(harness.log.lastWhere((entry) => entry.startsWith('p0:open')), contains('流畅'));
      expect(controller.cells[0].qualityIndex, 1);
      expect(controller.cells[0].status, MultiviewCellStatus.playing);

      // 同档重复设置幂等短路。
      await controller.setCellQuality(0, 1);
      expect(player.openCalls, 1);
    });

    test('setCellQuality 竞态防护：换流期间重新分配则丢弃迟到结果', () async {
      final harness = _Harness();
      final controller = harness.controller;
      await controller.assignRoom(0, _room('r1'));
      final gate = Completer<void>();
      harness.qualityGates['r1'] = gate;

      final switching = controller.setCellQuality(0, 1);
      await harness.pump();
      // 换流挂起期间该格被重新分配（纪元推进）。
      await controller.assignRoom(0, _room('r9'));
      gate.complete();
      await switching;

      // 迟到的档位更新不得覆盖新分配的状态。
      expect(controller.cells[0].qualityIndex, 0);
      expect(controller.cells[0].room?.roomId, 'r9');
      expect(controller.cells[0].status, MultiviewCellStatus.playing);
    });

    test('setCellQuality 取流失败置 error', () async {
      final harness = _Harness();
      final controller = harness.controller;
      harness.qualityLoadFailures.add('r1:流畅');
      await controller.assignRoom(0, _room('r1'));

      await controller.setCellQuality(0, 1);

      expect(controller.cells[0].status, MultiviewCellStatus.error);
      expect(controller.cells[0].errorKind, MultiviewCellErrorKind.resolveFailure);
      expect(controller.cells[0].errorDetail, contains('load boom'));
    });

    test('降质联动开启：小格取最低档，晋升/降格自动换档', () async {
      final harness = _Harness();
      final controller = harness.controller;
      controller.smallCellsLowQuality.value = true;
      await controller.setLayout(MultiviewLayout.focus);
      await controller.assignRoom(0, _room('r1'));
      await controller.assignRoom(1, _room('r2'));

      // 大格最高档、小格最低档。
      expect(harness.resolvePreferences['r1'], isFalse);
      expect(harness.resolvePreferences['r2'], isTrue);
      expect(controller.cells[0].qualityIndex, 0);
      expect(controller.cells[1].qualityIndex, 1);

      await controller.promoteCell(1);

      // 晋升格切最高档、原大格降最低档；均同实例换流不重建。
      expect(controller.focusedCellIndex.value, 1);
      expect(controller.audioFocusIndex, 1);
      expect(controller.cells[1].qualityIndex, 0);
      expect(controller.cells[0].qualityIndex, 1);
      expect(harness.players[0].startCalls, 1);
      expect(harness.players[1].startCalls, 1);
      expect(harness.players[1].openCalls, 1);
      expect(harness.players[0].openCalls, 1);
    });

    test('降质联动关闭：晋升不触发任何换流', () async {
      final harness = _Harness();
      final controller = harness.controller;
      await controller.setLayout(MultiviewLayout.focus);
      await controller.assignRoom(0, _room('r1'));
      await controller.assignRoom(1, _room('r2'));

      await controller.promoteCell(1);

      expect(harness.resolvePreferences['r1'], isFalse);
      expect(harness.resolvePreferences['r2'], isFalse);
      expect(controller.cells[0].qualityIndex, 0);
      expect(controller.cells[1].qualityIndex, 0);
      expect(harness.players.map((player) => player.openCalls), everyElement(0));
    });

    test('弹幕会话跟随页级开关、大画面切换与房间变化', () async {
      final harness = _Harness();
      final controller = harness.controller;
      controller.onInit();
      await controller.setLayout(MultiviewLayout.focus);
      await controller.assignRoom(0, _room('r1'));
      await controller.assignRoom(1, _room('r2'));

      // 开关开启：建立大画面会话。
      controller.danmakuEnabled.value = true;
      await harness.pump();
      expect(harness.danmakuEngines['r1']!.log, contains('dm0:start'));

      // 晋升另一格：旧会话断开、新会话建立。
      await controller.promoteCell(1);
      await harness.pump();
      expect(harness.danmakuEngines['r1']!.log, contains('dm0:stop'));
      expect(harness.danmakuEngines['r2']!.log, contains('dm1:start'));

      // 大画面房间变化：重连新房间。
      await controller.assignRoom(1, _room('r3'));
      await harness.pump();
      expect(harness.danmakuEngines['r2']!.log, contains('dm1:stop'));
      expect(harness.danmakuEngines['r3']!.log, contains('dm2:start'));

      // 关闭开关断开会话。
      controller.danmakuEnabled.value = false;
      await harness.pump();
      expect(harness.danmakuEngines['r3']!.log, contains('dm2:stop'));
    });

    test('非 focus 布局弹幕跟随当前声音来源格', () async {
      final harness = _Harness();
      final controller = harness.controller;
      controller.onInit();
      await controller.assignRoom(0, _room('r1'));
      await controller.assignRoom(1, _room('r2'));

      // quad 下后分配的格取得声音来源；页级弹幕开关应连接该格，
      // 不能像旧实现一样因为不是 focus 布局而保持无效。
      expect(controller.layout.value, MultiviewLayout.quad);
      expect(controller.audioFocusIndex, 1);
      controller.danmakuEnabled.value = true;
      await harness.pump();
      expect(harness.danmakuEngines['r2']!.log, contains('dm0:start'));

      await controller.setAudioFocus(0);
      await harness.pump();
      expect(harness.danmakuEngines['r2']!.log, contains('dm0:stop'));
      expect(harness.danmakuEngines['r1']!.log, contains('dm1:start'));
    });

    test('例外平台大画面不建立弹幕会话', () async {
      final harness = _Harness();
      final controller = harness.controller;
      controller.onInit();
      await controller.setLayout(MultiviewLayout.focus);
      await controller.assignRoom(0, LiveRoom(roomId: 'ks1', platform: 'kuaishou'));

      controller.danmakuEnabled.value = true;
      await harness.pump();

      expect(harness.danmakuEngines, isEmpty);
    });

    test('assignRoom 解析失败后错误态不残留旧清晰度上下文', () async {
      final harness = _Harness();
      final controller = harness.controller;
      await controller.assignRoom(0, _room('r1'));
      expect(controller.cells[0].qualities, isNotEmpty);

      // 同格换新房间且解析失败：resolving 阶段必须已清空旧清晰度状态。
      harness.resolveFailures.add('r9');
      await controller.assignRoom(0, _room('r9'));

      final cell = controller.cells[0];
      expect(cell.status, MultiviewCellStatus.error);
      expect(cell.room?.roomId, 'r9');
      expect(cell.qualities, isEmpty);
      expect(cell.qualityIndex, 0);
      expect(cell.qualityLoader, isNull);
    });

    test('降质开关切换即时 reconcile 在播小格', () async {
      final harness = _Harness();
      final controller = harness.controller;
      controller.onInit();
      await controller.setLayout(MultiviewLayout.focus);
      await controller.assignRoom(0, _room('r1'));
      await controller.assignRoom(1, _room('r2'));
      // 开关关闭时小格为最高档。
      expect(controller.cells[1].qualityIndex, 0);

      // 开启：在播小格立即降到最低档（大画面不动）。
      controller.smallCellsLowQuality.value = true;
      await harness.pump();
      expect(controller.cells[1].qualityIndex, 1);
      expect(controller.cells[0].qualityIndex, 0);
      expect(harness.players[1].openCalls, 1);

      // 关闭：在播小格立即回升最高档。
      controller.smallCellsLowQuality.value = false;
      await harness.pump();
      expect(controller.cells[1].qualityIndex, 0);
      expect(harness.players[1].startCalls, 1, reason: 'reconcile 走同实例换流，不重建播放器');
    });

    test('大画面解析失败触发弹幕会话同步', () async {
      final harness = _Harness();
      final controller = harness.controller;
      controller.onInit();
      await controller.setLayout(MultiviewLayout.focus);
      await controller.assignRoom(0, _room('r1'));
      controller.danmakuEnabled.value = true;
      await harness.pump();
      expect(harness.danmakuEngines['r1']!.log, contains('dm0:start'));

      // 大画面重新选台失败：失败路径同步会话——旧房间断开、按当前大画面房间重连。
      harness.resolveFailures.add('r9');
      await controller.assignRoom(0, _room('r9'));
      await harness.pump();

      expect(controller.cells[0].status, MultiviewCellStatus.error);
      expect(harness.danmakuEngines['r1']!.log, contains('dm0:stop'));
      expect(harness.danmakuEngines['r9'], isNotNull);
      expect(harness.danmakuEngines['r9']!.log, contains('dm1:start'));
    });

    test('toggleCellPlayPause 临时暂停与恢复并翻转播放标志', () async {
      final harness = _Harness();
      final controller = harness.controller;
      await controller.assignRoom(0, _room('r1'));
      expect(controller.playingFlags[0], isTrue);
      expect(harness.players[0].playing, isTrue);

      await controller.toggleCellPlayPause(0);
      expect(controller.playingFlags[0], isFalse);
      expect(harness.players[0].playing, isFalse);
      // 临时暂停不得触发释放流程：句柄仍在、格状态保持 playing，
      // 且不产生任何换流（open 计数不变，重建才会走 start）。
      expect(controller.cells[0].status, MultiviewCellStatus.playing);
      expect(harness.players[0].openCalls, 0);

      await controller.toggleCellPlayPause(0);
      expect(controller.playingFlags[0], isTrue);
      expect(harness.players[0].playing, isTrue);
      expect(harness.players[0].resumeCalls, 1);
    });

    test('toggleCellPlayPause 对非 playing 格 Fail Fast', () async {
      final harness = _Harness();
      final controller = harness.controller;
      expect(() => controller.toggleCellPlayPause(0), throwsStateError);
    });

    test('setCellVolume 会话音量与静音独立且越界钳制', () async {
      final harness = _Harness();
      final controller = harness.controller;
      await controller.assignRoom(0, _room('r1'));
      final player = harness.players[0];

      // 焦点格（未静音）：连续音量直接生效。
      await controller.setCellVolume(0, 0.3);
      expect(player.sessionVolume, 0.3);
      expect(player.volume, 0.3);

      // 越界钳制。
      await controller.setCellVolume(0, 1.5);
      expect(player.sessionVolume, 1.0);
      expect(player.volume, 1.0);

      // 静音后设置音量：目标值更新，实际输出保持 0；
      // 取消静音后按目标值生效（音量/静音相互独立）。
      await player.setMuted(true);
      await controller.setCellVolume(0, 0.5);
      expect(player.sessionVolume, 0.5);
      expect(player.volume, 0.0);
      await player.setMuted(false);
      expect(player.volume, 0.5);
    });

    test('房间音量跨格子重建恢复并写入共用存储', () async {
      final harness = _Harness();
      final controller = harness.controller;
      await controller.assignRoom(0, _room('r1'));

      await controller.setCellVolume(0, 0.28);
      expect(harness.savedRoomVolumes['bilibili/r1'], 0.28);

      controller.removeCell(0);
      await harness.pump();
      await controller.assignRoom(0, _room('r1'));

      final replacement = harness.players.last;
      expect(replacement.sessionVolume, 0.28);
      expect(replacement.volume, 0.28, reason: '重新选择同房间后应按持久化房间音量出声');
      expect(controller.cellVolume(0), 0.28);
    });

    test('setCellLine 同实例换线路并更新下标', () async {
      final harness = _Harness();
      final controller = harness.controller;
      await controller.assignRoom(0, _room('r1'));
      final player = harness.players[0];
      final openCallsBefore = player.openCalls;

      expect(controller.cells[0].lines.length, 2);
      await controller.setCellLine(0, 1);

      expect(controller.cells[0].lineIndex, 1);
      expect(player.openCalls, openCallsBefore + 1);
      expect(harness.log.last, contains('?line=1'));
    });

    test('setCellLine 空线路列表与越界下标 Fail Fast', () async {
      final harness = _Harness();
      final controller = harness.controller;
      await controller.assignRoom(0, _room('r1'));
      expect(() => controller.setCellLine(0, 5), throwsRangeError);
      // 清空线路后（模拟不支持换线路的解析器）同样 Fail Fast。
      controller.cells[0] = controller.cells[0].copyWith(clearQuality: true);
      expect(() => controller.setCellLine(0, 0), throwsStateError);
    });

    test('换清晰度保持当前线路', () async {
      final harness = _Harness();
      final controller = harness.controller;
      await controller.assignRoom(0, _room('r1'));
      await controller.setCellLine(0, 1);
      expect(controller.cells[0].lineIndex, 1);

      // 切到流畅档：线路下标保持 1，URL 为流畅档的线路 1。
      await controller.setCellQuality(0, 1);
      expect(controller.cells[0].qualityIndex, 1);
      expect(controller.cells[0].lineIndex, 1);
      expect(controller.cells[0].lines.length, 2);
      expect(harness.log.last, contains('流畅?line=1'));
    });
  });
}
