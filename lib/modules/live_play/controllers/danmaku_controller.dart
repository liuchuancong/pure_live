import 'dart:async';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
import 'package:pure_live/modules/live_play/controllers/danmaku_message_gate.dart';
import 'package:pure_live/modules/live_play/controllers/danmaku_session_host.dart';
import 'package:pure_live/modules/live_play/controllers/danmaku_similarity_filter.dart';
import 'package:pure_live/modules/live_play/controllers/repeated_danmaku_filter.dart';
import 'package:pure_live/modules/live_play/states/live_play_state.dart';

/// Owns exactly one room-bound danmaku session.
///
/// Room switches, setting changes, player reloads and floating-window teardown
/// can arrive in the same event-loop turn. Every transition is serialized and
/// every callback carries a session token, so an old socket can never append a
/// packet to the newly opened room.
class DanmakuController extends GetxController {
  DanmakuController(
    this._main, {
    this.startTimeout = const Duration(seconds: 20),
    this.stopTimeout = const Duration(seconds: 5),
    this.recoveryAllowed,
  });

  final DanmakuSessionHost _main;
  final Duration startTimeout;
  final Duration stopTimeout;
  final bool Function(LiveRoom room)? recoveryAllowed;
  final DanmakuMessageGate _messageGate = DanmakuMessageGate();
  final RepeatedDanmakuFilter _repeatedMessageFilter = RepeatedDanmakuFilter();
  final DanmakuSimilarityFilter _similarityFilter = DanmakuSimilarityFilter();

  LiveDanmaku? _liveDanmaku;
  Future<void> _operationTail = Future<void>.value();
  Worker? _settingsWorker;
  Worker? _filterWorker;
  Worker? _similarityFilterWorker;

  int _requestEpoch = 0;
  int _sessionToken = 0;
  String? _sessionKey;
  String? _connectingKey;
  String? _gateRoomKey;
  String? _lastStatusText;
  DateTime? _lastStatusAt;
  bool _maskedNameNoticeShown = false;
  Set<String> _blockedUsers = const <String>{};
  List<String> _blockedKeywords = const <String>[];

  LivePlayState get _state => _main.state.value;
  bool get _initialized => _liveDanmaku != null;
  LiveDanmaku get liveDanmaku => _liveDanmaku!;

  @override
  void onInit() {
    super.onInit();
    final settings = SettingsService.to;
    _settingsWorker = everAll([
      settings.danmaku.enableDanmakuDisplay,
      settings.danmaku.enablePipDanmaku,
    ], (_) => unawaited(_syncConnectionForSettings()));
    _filterWorker = everAll([settings.fav.blockedDanmakuUsers, settings.fav.shieldList], (_) => _refreshFilters());
    final dm = settings.danmaku;
    _similarityFilterWorker = everAll([
      dm.enableDanmakuSimilarityFilter,
      dm.danmakuSimilarityThreshold,
      dm.danmakuSimilarityCacheDuration,
      dm.danmakuSimilarityMaxCacheSize,
    ], (_) => _updateSimilarityFilterConfig());
    _updateSimilarityFilterConfig();
    _refreshFilters();
  }

  /// Initial engine installation is synchronous so room initialization cannot
  /// race ahead of dependency setup.
  void initDanmaku(LiveDanmaku danmaku) {
    if (_liveDanmaku == null) {
      _liveDanmaku = danmaku;
      return;
    }
    unawaited(replaceDanmaku(danmaku));
  }

  Future<void> replaceDanmaku(LiveDanmaku danmaku) {
    final request = ++_requestEpoch;
    return _serialize(() async {
      if (request != _requestEpoch) return;
      await _disconnectInternal(clearRenderer: true);
      if (request != _requestEpoch) return;
      _liveDanmaku = danmaku;
      _messageGate.clear();
      _repeatedMessageFilter.clear();
      _similarityFilter.clear();
      _gateRoomKey = null;
    });
  }

  bool needReconnect(LiveRoom room) {
    if (!_initialized) return true;
    final key = _roomKey(room);
    if (_connectingKey == key) return false;
    return _sessionKey != key || !liveDanmaku.isConnected;
  }

  /// Connects the room, optionally rebuilding its transport.
  ///
  /// A matching, connected session survives presentation-only changes such as
  /// Android PiP. A matching but disconnected session is rebuilt without
  /// clearing the already-rendered history. This avoids creating a guaranteed
  /// packet gap by tearing down a healthy websocket on every PiP return.
  Future<void> connectRoom(LiveRoom room, {bool force = false}) {
    final key = _roomKey(room);
    if (!_initialized) return Future<void>.value();
    final healthyMatchingSession = _sessionKey == key && liveDanmaku.isConnected;
    // This fast path is deliberately before the request epoch increment. A
    // duplicate lifecycle/PiP request must not invalidate an already-running
    // handshake merely to discover the same key again in the serialized body.
    if (!force && (healthyMatchingSession || _connectingKey == key)) {
      return Future<void>.value();
    }

    final request = ++_requestEpoch;
    return _serialize(() async {
      if (request != _requestEpoch || !_initialized) return;
      final stillHealthy = _sessionKey == key && liveDanmaku.isConnected;
      if (!force && (stillHealthy || _connectingKey == key)) return;

      final previousKey = _sessionKey ?? _connectingKey;
      await _disconnectInternal(clearRenderer: previousKey != null && previousKey != key);
      if (request != _requestEpoch || !_initialized) return;

      if (_gateRoomKey != key) {
        _messageGate.clear();
        _repeatedMessageFilter.clear();
        _similarityFilter.clear();
        _gateRoomKey = key;
      }

      final engine = liveDanmaku;
      final token = ++_sessionToken;
      _maskedNameNoticeShown = false;
      _connectingKey = key;
      _installCallbacks(engine, room, key, token);

      if (room.isRecord == true) _addStatusMessage(i18n('recording_mode_notice'));
      _addStatusMessage(i18n('connect_danmaku_server'));

      try {
        await engine.start(room.danmakuData).timeout(startTimeout);
      } catch (error, stackTrace) {
        CoreLog.e(error.toString(), stackTrace);
        if (_acceptsCallback(engine, key, token)) {
          _connectingKey = null;
          _sessionKey = null;
          _main.updateDanmakuRoomId(null);
        }
        _detachCallbacks(engine);
        await _stopEngine(engine);
        if (error is TimeoutException) _addStatusMessage(i18n('danmaku_connection_timeout'));
        return;
      }

      if (request != _requestEpoch || !_acceptsCallback(engine, key, token)) {
        _detachCallbacks(engine);
        await _stopEngine(engine);
      }
    });
  }

  Future<void> stopDanmaku({bool clearRenderer = true}) {
    final request = ++_requestEpoch;
    return _serialize(() async {
      if (request != _requestEpoch) return;
      await _disconnectInternal(clearRenderer: clearRenderer);
    });
  }

  void _installCallbacks(LiveDanmaku engine, LiveRoom room, String key, int token) {
    engine.onMessage = (msg) {
      if (!_acceptsCallback(engine, key, token)) return;
      if (msg.type == LiveMessageType.chat) {
        if (!_messageGate.accepts(msg) || _isBlocked(msg)) return;
        final danmakuSettings = SettingsService.to.danmaku;
        if (!_repeatedMessageFilter.accepts(
          msg,
          enabled: danmakuSettings.collapseRepeatedDanmaku.v,
          window: Duration(seconds: danmakuSettings.repeatedDanmakuWindowSeconds.v.clamp(1, 30)),
        )) {
          return;
        }
        if (!msg.isLocal &&
            danmakuSettings.enableDanmakuSimilarityFilter.v &&
            !_similarityFilter.shouldDisplay(msg.message)) {
          return;
        }
        if (!_maskedNameNoticeShown &&
            room.platform == Sites.bilibiliSite &&
            RegExp(r'\*{2,}|＊{2,}').hasMatch(msg.userName)) {
          _maskedNameNoticeShown = true;
          _addStatusMessage(i18n('bilibili_guest_name_masked'));
        }
        _main.addDanmakuMessage(msg);
        _state.player.videoController?.sendDanmaku(msg);
      } else if (msg.type == LiveMessageType.online) {
        _main.updateRuntimeAudience(msg.data);
      }
    };

    engine.onClose = (msg) {
      if (!_acceptsCallback(engine, key, token)) return;
      _addStatusMessage(msg);
      // Transient reconnect notices retain ownership of this session. A final
      // failure releases the room key so a manual refresh creates a fresh
      // transport instead of remaining attached to a dead socket.
      if (!msg.contains('正在尝试重连')) {
        _sessionKey = null;
        _connectingKey = null;
        _main.updateDanmakuRoomId(null);
      }
    };

    engine.onReady = () {
      if (!_acceptsCallback(engine, key, token)) return;
      _connectingKey = null;
      _sessionKey = key;
      _main.updateDanmakuRoomId(room.roomId?.toString());
      _addStatusMessage(i18n('danmaku_connected'));
    };
  }

  bool _acceptsCallback(LiveDanmaku engine, String key, int token) {
    return token == _sessionToken && identical(_liveDanmaku, engine) && (_sessionKey == key || _connectingKey == key);
  }

  bool _isBlocked(LiveMessage message) {
    final user = message.userName.trim().toLowerCase();
    if (user.isNotEmpty && _blockedUsers.contains(user)) return true;
    final text = message.message.toLowerCase();
    return _blockedKeywords.any(text.contains);
  }

  void _refreshFilters() {
    final favorite = SettingsService.to.fav;
    _blockedUsers = favorite.blockedDanmakuUsers
        .map((user) => user.trim().toLowerCase())
        .where((user) => user.isNotEmpty)
        .toSet();
    _blockedKeywords = favorite.shieldList
        .map((keyword) => keyword.trim().toLowerCase())
        .where((keyword) => keyword.isNotEmpty)
        .toList(growable: false);
  }

  void _updateSimilarityFilterConfig() {
    final settings = SettingsService.to.danmaku;
    if (!settings.enableDanmakuSimilarityFilter.v) {
      _similarityFilter.clear();
      return;
    }
    _similarityFilter.updateConfig(
      similarityThreshold: settings.danmakuSimilarityThreshold.v,
      cacheDuration: Duration(seconds: settings.danmakuSimilarityCacheDuration.v),
      maxCacheSize: settings.danmakuSimilarityMaxCacheSize.v,
    );
  }

  void _addStatusMessage(String text) {
    final now = DateTime.now();
    if (_lastStatusText == text &&
        _lastStatusAt != null &&
        now.difference(_lastStatusAt!) < const Duration(seconds: 3)) {
      return;
    }
    _lastStatusText = text;
    _lastStatusAt = now;
    _main.addSystemMessage(text);
  }

  Future<void> _disconnectInternal({required bool clearRenderer}) async {
    final engine = _liveDanmaku;
    _sessionToken++;
    _sessionKey = null;
    _connectingKey = null;
    _main.updateDanmakuRoomId(null);
    if (clearRenderer) _main.clearRenderedDanmaku();
    if (engine == null) return;
    _detachCallbacks(engine);
    await _stopEngine(engine);
  }

  Future<void> _stopEngine(LiveDanmaku engine) async {
    try {
      await engine.stop().timeout(stopTimeout);
    } catch (error, stackTrace) {
      CoreLog.e(error.toString(), stackTrace);
    }
  }

  void _detachCallbacks(LiveDanmaku engine) {
    engine.onMessage = null;
    engine.onClose = null;
    engine.onReady = null;
  }

  Future<void> _syncConnectionForSettings() async {
    if (!_initialized) return;
    final room = _state.room.detail;
    if (room == null) return;
    const except = [Sites.kuaishouSite, Sites.iptvSite, Sites.ccSite];
    final settings = SettingsService.to.danmaku;
    try {
      if (except.contains(room.platform) || (!settings.enableDanmakuDisplay.v && !settings.enablePipDanmaku.v)) {
        await stopDanmaku();
      } else {
        await connectRoom(room);
      }
    } catch (error, stackTrace) {
      CoreLog.e(error.toString(), stackTrace);
    }
  }

  /// Repairs a room connection after a native presentation/lifecycle change.
  /// Settings and platform exclusions remain authoritative, so this cannot
  /// accidentally open a socket when danmaku is disabled.
  Future<void> recoverRoomConnection(LiveRoom room) async {
    if (!_initialized) return;
    if (!_isRecoveryAllowed(room)) {
      await stopDanmaku();
      return;
    }
    await connectRoom(room);
  }

  bool _isRecoveryAllowed(LiveRoom room) {
    final override = recoveryAllowed;
    if (override != null) return override(room);
    const except = [Sites.kuaishouSite, Sites.iptvSite, Sites.ccSite];
    final settings = SettingsService.to.danmaku;
    return !except.contains(room.platform) && (settings.enableDanmakuDisplay.v || settings.enablePipDanmaku.v);
  }

  String _roomKey(LiveRoom room) => '${room.platform ?? ''}:${room.roomId ?? ''}';

  Future<void> _serialize(Future<void> Function() operation) {
    final next = _operationTail.then((_) => operation());
    _operationTail = next.catchError((Object error, StackTrace stackTrace) {
      CoreLog.e(error.toString(), stackTrace);
    });
    return next;
  }

  @override
  void onClose() {
    _settingsWorker?.dispose();
    _filterWorker?.dispose();
    _similarityFilterWorker?.dispose();
    _messageGate.clear();
    _repeatedMessageFilter.clear();
    _similarityFilter.clear();
    _requestEpoch++;
    _sessionToken++;
    final engine = _liveDanmaku;
    if (engine != null) {
      _detachCallbacks(engine);
      unawaited(_stopEngine(engine));
    }
    _main.updateDanmakuRoomId(null);
    _main.clearRenderedDanmaku();
    super.onClose();
  }
}
