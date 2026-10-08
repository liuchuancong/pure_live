import 'dart:async';
import 'package:pure_live/core/index.dart';
import 'package:pure_live/core/logging/core_log.dart';
import 'package:media_core_danmaku/media_core_danmaku.dart';
import 'package:pure_live/shared/platforms/live_danmaku.dart';
import 'package:pure_live/shared/platforms/empty_danmaku.dart';
import 'package:pure_live/domains/live/data/platforms/sites.dart';
import 'package:pure_live/domains/live/data/platforms/danmaku_emote_loader.dart';
import 'package:pure_live/domains/live/domain/global_player_service.dart';
import 'package:pure_live/domains/live/data/favorite_room_controller.dart';
import 'package:pure_live/core/player/core/live_message_normalization.dart';
import 'package:pure_live/domains/live/presentation/playback/states/live_play_state.dart';
import 'package:pure_live/domains/live/presentation/playback/controllers/danmaku_session_host.dart';

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
  final bool Function(LiveRoom liveroom)? recoveryAllowed;
  final DanmakuMessageGate _messageGate = DanmakuMessageGate();
  final DanmakuRepeatedFilter _repeatedMessageFilter = DanmakuRepeatedFilter();
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
    _settingsWorker = everAll([settings.danmaku.hideDanmaku], (_) => unawaited(_syncConnectionForSettings()));
    _filterWorker = everAll([
      FavoriteRoomController.to.blockedDanmakuUsers,
      FavoriteRoomController.to.shieldList,
    ], (_) => _refreshFilters());
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

  bool needReconnect(LiveRoom liveroom) {
    if (!_initialized) return true;
    final key = _roomKey(liveroom);
    if (_connectingKey == key) return false;
    return _sessionKey != key || !_sessionSettled;
  }

  // An unsupported transport has a settled local session, not a connected
  // remote socket. Presentation changes must not keep retrying an empty engine.
  bool get _sessionSettled => liveDanmaku is EmptyDanmaku || liveDanmaku.isConnected;

  /// Connects the room, optionally rebuilding its transport.
  ///
  /// A matching, connected session survives presentation-only changes such as
  /// Android PiP. A matching but disconnected session is rebuilt without
  /// clearing the already-rendered history. This avoids creating a guaranteed
  /// packet gap by tearing down a healthy websocket on every PiP return.
  Future<void> connectRoom(LiveRoom liveroom, {bool force = false}) {
    final key = _roomKey(liveroom);
    if (!_initialized) return Future<void>.value();
    final healthyMatchingSession = _sessionKey == key && _sessionSettled;
    // This fast path is deliberately before the request epoch increment. A
    // duplicate lifecycle/PiP request must not invalidate an already-running
    // handshake merely to discover the same key again in the serialized body.
    if (!force && (healthyMatchingSession || _connectingKey == key)) {
      return Future<void>.value();
    }

    final request = ++_requestEpoch;
    return _serialize(() async {
      if (request != _requestEpoch || !_initialized) return;
      final stillHealthy = _sessionKey == key && _sessionSettled;
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
      if (engine is EmptyDanmaku) {
        _connectingKey = null;
        _sessionKey = key;
        _main.updateDanmakuRoomId(null);
        _addStatusMessage(i18n('remote_danmaku_not_integrated'));
        return;
      }
      final token = ++_sessionToken;
      _maskedNameNoticeShown = false;
      _connectingKey = key;
      _installCallbacks(engine, liveroom, key, token);

      if (liveroom.isRecord == true) _addStatusMessage(i18n('recording_mode_notice'));
      _addStatusMessage(i18n('connect_danmaku_server'));

      try {
        await engine.start(liveroom.danmakuData).timeout(startTimeout);
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

  void _installCallbacks(LiveDanmaku engine, LiveRoom liveroom, String key, int token) {
    final danmakuCapability = Sites.danmakuCapability(liveroom.platform);
    engine.onMessage = (msg) {
      if (!_acceptsCallback(engine, key, token)) return;
      if (msg.type == LiveMessageType.chat) {
        if (!_messageGate.accepts(normalizeLiveMessage(msg)) || _isBlocked(msg)) return;
        final danmakuSettings = SettingsService.to.danmaku;
        if (!_repeatedMessageFilter.accepts(
          normalizeLiveMessage(msg),
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
        if (!_maskedNameNoticeShown) {
          final userNameNoticeKey = danmakuCapability?.danmakuUserNameNoticeKey(msg.userName);
          if (userNameNoticeKey != null) {
            _maskedNameNoticeShown = true;
            _addStatusMessage(i18n(userNameNoticeKey));
          }
        }
        _main.addDanmakuMessage(msg);
        if (msg.emotes.isNotEmpty) DanmakuEmoteLoader.instance.ensureRegistered(msg.emotes);
        // The room's surface and PiP render from the room controller's own pools;
        // the in-app small window renders the facade's pool and is fed here, so it
        // keeps showing danmaku whether or not the room's controller still exists.
        _state.player.videoController?.sendDanmaku(msg);
        GlobalPlayerService.instance.player.sendFloatingDanmaku(msg);
      } else if (msg.type == LiveMessageType.online) {
        _main.updateRuntimeAudience(msg.data);
      } else if (msg.type == LiveMessageType.superChat) {
        _main.addAddSuperChat(msg);
      } else if (msg.type == LiveMessageType.gift) {
        if (_isBlocked(msg)) return;
        _main.addDanmakuMessage(msg);
      } else if (msg.type == LiveMessageType.notice) {
        if (msg.message.isNotEmpty) _main.addSystemMessage(msg.message);
      } else if (msg.type == LiveMessageType.retraction) {
        final target = msg.data;
        if (target is LiveRetraction) _main.removeRetractedMessages(target);
      }
    };

    engine.onReconnect = (msg) {
      if (!_acceptsCallback(engine, key, token)) return;
      _addStatusMessage(msg);
    };

    engine.onClose = (msg) {
      if (!_acceptsCallback(engine, key, token)) return;
      _addStatusMessage(msg);
      // A terminal failure releases the room key so a manual refresh creates
      // a fresh transport instead of remaining attached to a dead socket.
      _sessionKey = null;
      _connectingKey = null;
      _main.updateDanmakuRoomId(null);
    };

    engine.onReady = () {
      if (!_acceptsCallback(engine, key, token)) return;
      _connectingKey = null;
      _sessionKey = key;
      _main.updateDanmakuRoomId(liveroom.roomId?.toString());
      _addStatusMessage(i18n('danmaku_connected'));
    };
  }

  bool _acceptsCallback(LiveDanmaku engine, String key, int token) {
    return token == _sessionToken && identical(_liveDanmaku, engine) && (_sessionKey == key || _connectingKey == key);
  }

  static final RegExp _maskedName = RegExp(r'\*{2,}|＊{2,}');

  bool get sawMaskedName => _maskedNameNoticeShown;

  bool _isBlocked(LiveMessage message) {
    final user = message.userName.trim().toLowerCase();
    if (user.isNotEmpty && !_maskedName.hasMatch(user) && _blockedUsers.contains(user)) return true;
    final text = message.message.toLowerCase();
    return _blockedKeywords.any(text.contains);
  }

  void _refreshFilters() {
    final favorite = FavoriteRoomController.to;
    _blockedUsers = favorite.blockedDanmakuUsers
        .map((user) => user.trim().toLowerCase())
        .where((user) => user.isNotEmpty)
        .where((user) => !_maskedName.hasMatch(user))
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
    engine.onReconnect = null;
    engine.onClose = null;
    engine.onReady = null;
  }

  Future<void> _syncConnectionForSettings() async {
    if (!_initialized) return;
    final room = _state.room.detail;
    if (room == null) return;
    final settings = SettingsService.to.danmaku;
    try {
      if (!_connectsDanmaku(room.platform) || settings.hideDanmaku.v) {
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
  Future<void> recoverRoomConnection(LiveRoom liveroom) async {
    if (!_initialized) return;
    if (!_isRecoveryAllowed(liveroom)) {
      await stopDanmaku();
      return;
    }
    await connectRoom(liveroom);
  }

  bool _connectsDanmaku(String? platform) => Sites.danmakuCapability(platform)?.connectsDanmakuOnRoomEntry ?? true;

  bool _isRecoveryAllowed(LiveRoom liveroom) {
    final override = recoveryAllowed;
    if (override != null) return override(liveroom);
    final settings = SettingsService.to.danmaku;
    return _connectsDanmaku(liveroom.platform) && !settings.hideDanmaku.v;
  }

  String _roomKey(LiveRoom liveroom) => '${liveroom.platform ?? ''}:${liveroom.roomId ?? ''}';

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
    // The small window keeps the video running after the room's route is gone,
    // and GetX deletes this route-bound controller on that pop. Tearing the
    // session down here — or even only bumping the epochs, which invalidates
    // every installed engine callback — left the window with a picture and no
    // danmaku at all. The host asks for the session to be kept here, and
    // LivePlayController.disposeAppFloatingResources stops it when the window is
    // closed for real.
    if (!_main.keepsDanmakuForFloating) {
      _requestEpoch++;
      _sessionToken++;
      final engine = _liveDanmaku;
      if (engine != null) {
        _detachCallbacks(engine);
        unawaited(_stopEngine(engine));
      }
      _main.updateDanmakuRoomId(null);
      _main.clearRenderedDanmaku();
    }
    super.onClose();
  }
}
