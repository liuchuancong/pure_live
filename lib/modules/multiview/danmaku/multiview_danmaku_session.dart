import 'dart:async';
import 'dart:developer' as developer;

import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
import 'package:pure_live/modules/live_play/controllers/danmaku_message_gate.dart';
import 'package:pure_live/modules/live_play/controllers/danmaku_similarity_filter.dart';
import 'package:pure_live/modules/live_play/controllers/repeated_danmaku_filter.dart';

/// 弹幕引擎工厂：按房间创建对应站点的 LiveDanmaku 实例。
///
/// 生产环境绑定站点适配器的 getDanmaku()；测试注入记录调用的假引擎。
typedef MultiviewDanmakuEngineFactory = LiveDanmaku Function(LiveRoom room);

/// multiview 大画面弹幕会话管理器（精简自建）。
///
/// 不复用 DanmakuController 的原因：其与 DanmakuSessionHost/LivePlayState
/// 深度耦合（房间详情、超级留言、音频模式等直播间语义），multiview 无这些
/// 宿主概念。本类只保留「引擎创建 → connectRoom → 消息过滤 → stopDanmaku」
/// 最小闭环；过滤逻辑复用 live_play 既有实现（门禁/去重/相似度），
/// 保证弹幕体验一致。
///
/// 可靠性约定：会话内部任何异常只记日志并标记会话失效，绝不向调用方抛出，
/// 弹幕故障不得影响播放主链路；Fail Fast 仅限会话自身状态（未连接时
/// 查询活跃键等编程错误仍抛出）。
class MultiviewDanmakuSession {
  MultiviewDanmakuSession({
    required this.engineFactory,
    this.startTimeout = const Duration(seconds: 20),
    this.stopTimeout = const Duration(seconds: 5),
    this.onChatMessage,
  });

  final MultiviewDanmakuEngineFactory engineFactory;
  final Duration startTimeout;
  final Duration stopTimeout;

  /// 过滤后的聊天消息出口，由控制器桥接到渲染层（BarrageController）。
  final void Function(LiveMessage message)? onChatMessage;

  final DanmakuMessageGate _messageGate = DanmakuMessageGate();
  final RepeatedDanmakuFilter _repeatedFilter = RepeatedDanmakuFilter();
  final DanmakuSimilarityFilter _similarityFilter = DanmakuSimilarityFilter();

  LiveDanmaku? _engine;
  int _epoch = 0;
  String? _sessionKey;
  Future<void> _tail = Future<void>.value();

  /// 当前会话绑定的房间键（platform:roomId）；未连接为 null。
  String? get sessionKey => _sessionKey;

  /// 平台例外表：与 live_play 的弹幕门禁保持一致（kuaishou/iptv/cc 不连）。
  static bool isSupportedPlatform(String? platform) {
    const except = [Sites.kuaishouSite, Sites.iptvSite, Sites.ccSite];
    return platform != null && !except.contains(platform);
  }

  /// 房间是否具备建会话的最小条件（平台支持且携带弹幕连接参数）。
  static bool supportsRoom(LiveRoom room) {
    if (!isSupportedPlatform(room.platform)) return false;
    final data = room.danmakuData;
    if (data == null) return false;
    if (data is String && data.isEmpty) return false;
    return true;
  }

  /// 建立或切换到 [room] 的会话；同键且健康时幂等返回。
  Future<void> connect(LiveRoom room) {
    final key = '${room.platform ?? ''}:${room.roomId ?? ''}';
    if (_sessionKey == key && (_engine?.isConnected ?? false)) {
      return Future<void>.value();
    }
    final request = ++_epoch;
    return _serialize(() async {
      if (request != _epoch) return;
      if (_sessionKey == key && (_engine?.isConnected ?? false)) return;

      await _disconnectInternal();
      if (request != _epoch) return;

      final engine = engineFactory(room);
      // 立即登记为当前引擎：后续切换/断开才能正确停止它。
      _engine = engine;
      final token = request;
      _installCallbacks(engine, room, key, token);
      try {
        await engine.start(room.danmakuData).timeout(startTimeout);
      } catch (error, stackTrace) {
        developer.log(
          'MultiviewDanmakuSession: connect failed for $key',
          name: 'MultiviewDanmakuSession',
          error: error,
          stackTrace: stackTrace,
        );
        // 会话自身状态回滚：迟到回调一律拒绝，引擎尽力停止。
        if (token == _epoch) {
          _sessionKey = null;
        }
        await _stopEngineQuietly(engine);
        if (identical(_engine, engine)) {
          _engine = null;
        }
        return;
      }
      if (token == _epoch) {
        _sessionKey = key;
      } else {
        // 会话已被更新的请求取代：停止这个迟到的引擎。
        await _stopEngineQuietly(engine);
        if (identical(_engine, engine)) {
          _engine = null;
        }
      }
    });
  }

  /// 断开当前会话（幂等）。
  Future<void> disconnect() {
    final request = ++_epoch;
    return _serialize(() async {
      if (request != _epoch) return;
      await _disconnectInternal();
    });
  }

  Future<void> _disconnectInternal() async {
    _sessionKey = null;
    final engine = _engine;
    _engine = null;
    if (engine == null) return;
    engine.onMessage = null;
    engine.onClose = null;
    engine.onReady = null;
    await _stopEngineQuietly(engine);
  }

  void _installCallbacks(LiveDanmaku engine, LiveRoom room, String key, int token) {
    _messageGate.clear();
    _repeatedFilter.clear();
    _similarityFilter.clear();

    engine.onMessage = (msg) {
      // 迟到回调守卫：会话已被更新请求取代或引擎已更换时直接丢弃。
      if (token != _epoch || !identical(_engine, engine)) return;
      try {
        _handleChatMessage(msg);
      } catch (error, stackTrace) {
        // 单条消息处理失败（含设置读取）只丢弃该条，绝不拖垮会话与播放链路。
        developer.log(
          'MultiviewDanmakuSession: message handling failed',
          name: 'MultiviewDanmakuSession',
          error: error,
          stackTrace: stackTrace,
        );
      }
    };

    engine.onClose = (reason) {
      // 重连耗尽等传输关闭目前无 UI 提示事务，会话层留痕便于排查；
      // 区分当前会话与已被取代的迟到回调。
      developer.log(
        'MultiviewDanmakuSession: transport closed for $key '
        '(${token == _epoch ? 'current' : 'stale'} session): $reason',
        name: 'MultiviewDanmakuSession',
      );
    };

    engine.onReady = () {
      if (token != _epoch) return;
      _sessionKey = key;
    };
  }

  void _handleChatMessage(LiveMessage msg) {
    if (msg.type != LiveMessageType.chat) return;
    if (!_messageGate.accepts(msg)) return;
    final favorite = SettingsService.to.fav;
    final user = msg.userName.trim().toLowerCase();
    if (user.isNotEmpty && favorite.blockedDanmakuUsers.v.contains(user)) return;
    final text = msg.message.toLowerCase();
    if (favorite.shieldList.v.any(text.contains)) return;
    final danmakuSettings = SettingsService.to.danmaku;
    if (!_repeatedFilter.accepts(
      msg,
      enabled: danmakuSettings.collapseRepeatedDanmaku.v,
      window: Duration(seconds: danmakuSettings.repeatedDanmakuWindowSeconds.v.clamp(1, 30)),
    )) {
      return;
    }
    // 相似度过滤配置每条消息实时读取：与屏蔽列表一致地即时生效，
    // 避免连接期一次性快照错过设置变更。
    if (!danmakuSettings.enableDanmakuSimilarityFilter.v) {
      _similarityFilter.clear();
    } else {
      _similarityFilter.updateConfig(
        similarityThreshold: danmakuSettings.danmakuSimilarityThreshold.v,
        cacheDuration: Duration(seconds: danmakuSettings.danmakuSimilarityCacheDuration.v),
        maxCacheSize: danmakuSettings.danmakuSimilarityMaxCacheSize.v,
      );
    }
    if (!msg.isLocal &&
        danmakuSettings.enableDanmakuSimilarityFilter.v &&
        !_similarityFilter.shouldDisplay(msg.message)) {
      return;
    }
    onChatMessage?.call(msg);
  }

  Future<void> _stopEngineQuietly(LiveDanmaku engine) async {
    try {
      await engine.stop().timeout(stopTimeout);
    } catch (error, stackTrace) {
      developer.log(
        'MultiviewDanmakuSession: engine stop failed',
        name: 'MultiviewDanmakuSession',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _serialize(Future<void> Function() operation) {
    final next = _tail.then((_) => operation());
    _tail = next.catchError((Object error, StackTrace stackTrace) {
      // 序列化队列兜底日志：operation 内部已各自容错，此处防御未知异常外泄。
      developer.log(
        'MultiviewDanmakuSession: serialized operation failed',
        name: 'MultiviewDanmakuSession',
        error: error,
        stackTrace: stackTrace,
      );
    });
    return next;
  }
}
