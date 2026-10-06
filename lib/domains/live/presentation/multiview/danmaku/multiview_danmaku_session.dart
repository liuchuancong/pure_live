import 'dart:developer' as developer;
import 'dart:async';

import 'package:media_core_danmaku/media_core_danmaku.dart';
import 'package:pure_live/core/player/core/live_message_normalization.dart';
import 'package:pure_live/core/index.dart';
import 'package:pure_live/shared/platforms/live_danmaku.dart';
import 'package:pure_live/domains/live/data/platforms/sites.dart';
import 'package:pure_live/domains/live/data/favorite_room_controller.dart';

typedef MultiviewDanmakuEngineFactory = LiveDanmaku Function(LiveRoom liveroom);

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

  final void Function(LiveMessage message)? onChatMessage;

  final DanmakuMessageGate _messageGate = DanmakuMessageGate();
  final DanmakuRepeatedFilter _repeatedFilter = DanmakuRepeatedFilter();
  final DanmakuSimilarityFilter _similarityFilter = DanmakuSimilarityFilter();

  LiveDanmaku? _engine;
  int _epoch = 0;
  String? _sessionKey;
  Future<void> _tail = Future<void>.value();

  String? get sessionKey => _sessionKey;

  /// Empty/unsupported remote transports never create a multiview chat session.
  static bool isSupportedPlatform(String? platform) => Sites.supportsDanmakuTransport(platform);

  static bool supportsRoom(LiveRoom liveroom) {
    if (!isSupportedPlatform(liveroom.platform)) return false;
    final data = liveroom.danmakuData;
    if (data == null) return false;
    if (data is String && data.isEmpty) return false;
    return true;
  }

  Future<void> connect(LiveRoom liveroom) {
    final key = '${liveroom.platform ?? ''}:${liveroom.roomId ?? ''}';
    if (_sessionKey == key && (_engine?.isConnected ?? false)) {
      return Future<void>.value();
    }
    final request = ++_epoch;
    return _serialize(() async {
      if (request != _epoch) return;
      if (_sessionKey == key && (_engine?.isConnected ?? false)) return;

      await _disconnectInternal();
      if (request != _epoch) return;

      final engine = engineFactory(liveroom);
      _engine = engine;
      final token = request;
      _installCallbacks(engine, liveroom, key, token);
      try {
        await engine.start(liveroom.danmakuData).timeout(startTimeout);
      } catch (error, stackTrace) {
        developer.log(
          'MultiviewDanmakuSession: connect failed for $key',
          name: 'MultiviewDanmakuSession',
          error: error,
          stackTrace: stackTrace,
        );
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
        await _stopEngineQuietly(engine);
        if (identical(_engine, engine)) {
          _engine = null;
        }
      }
    });
  }

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
    engine.onReconnect = null;
    engine.onClose = null;
    engine.onReady = null;
    await _stopEngineQuietly(engine);
  }

  void _installCallbacks(LiveDanmaku engine, LiveRoom liveroom, String key, int token) {
    _messageGate.clear();
    _repeatedFilter.clear();
    _similarityFilter.clear();

    engine.onMessage = (msg) {
      if (token != _epoch || !identical(_engine, engine)) return;
      try {
        _handleChatMessage(msg);
      } catch (error, stackTrace) {
        developer.log(
          'MultiviewDanmakuSession: message handling failed',
          name: 'MultiviewDanmakuSession',
          error: error,
          stackTrace: stackTrace,
        );
      }
    };

    engine.onReconnect = (reason) {
      developer.log(
        'MultiviewDanmakuSession: transport reconnecting for $key '
        '(${token == _epoch ? 'current' : 'stale'} session): $reason',
        name: 'MultiviewDanmakuSession',
      );
    };

    engine.onClose = (reason) {
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
    if (!_messageGate.accepts(normalizeLiveMessage(msg))) return;
    final favorite = FavoriteRoomController.to;
    final user = msg.userName.trim().toLowerCase();
    if (user.isNotEmpty && favorite.blockedDanmakuUsers.v.contains(user)) return;
    final text = msg.message.toLowerCase();
    if (favorite.shieldList.v.any(text.contains)) return;
    final danmakuSettings = SettingsService.to.danmaku;
    if (!_repeatedFilter.accepts(
      normalizeLiveMessage(msg),
      enabled: danmakuSettings.collapseRepeatedDanmaku.v,
      window: Duration(seconds: danmakuSettings.repeatedDanmakuWindowSeconds.v.clamp(1, 30)),
    )) {
      return;
    }
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
