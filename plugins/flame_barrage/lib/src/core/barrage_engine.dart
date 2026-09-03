import 'dart:ui';
import 'dart:collection';
import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flame_barrage/flame_barrage.dart';
import 'package:flame_barrage/src/core/engine_clock.dart';
import 'package:flame_barrage/src/model/barrage/engine_state.dart';

class _PendingBarrage {
  const _PendingBarrage(this.item, this.enqueuedAtMs);

  final BarrageItem item;
  final int enqueuedAtMs;
}

class BarrageEngine extends FlameGame with TapCallbacks {
  BarrageEngine({required BarrageConfig config, required this.emojiAtlas})
    : _config = config,
      _pictureCache = PictureCache(maxSize: config.pictureCacheMaxSize),
      _pool = BarragePool(maxSize: config.barragePoolMaxSize) {
    _parser = RichParser(atlas: emojiAtlas, maxCacheSize: config.textCacheMaxSize);
    _layout = MixedLayout(atlas: emojiAtlas, maxTextCacheSize: config.textCacheMaxSize);
    _renderer = const MixedRenderer();
    // A mounted Flame game otherwise owns a display-rate ticker even when the
    // room is silent. It also repaints at the display refresh rate even when
    // BarrageConfig.fps is lower, because skipping update() does not stop
    // GameRenderBox from painting. Keep Flame's ticker stopped and pulse the
    // engine only at the configured rate while there is visible work.
    pauseEngine();
  }

  BarrageConfig _config;
  BarrageConfig get config => _config;
  final EmojiAtlas emojiAtlas;

  late final RichParser _parser;
  late final MixedLayout _layout;
  late final MixedRenderer _renderer;

  final PictureCache _pictureCache;
  final TrackManager _trackManager = TrackManager();
  final TrackAllocator _trackAllocator = const TrackAllocator();
  final SpeedStrategy _speedStrategy = const SpeedStrategy();
  final BarragePool _pool;

  final Queue<_PendingBarrage> _waiting = Queue<_PendingBarrage>();
  final Queue<_PendingBarrage> _pausedBuffer = Queue<_PendingBarrage>();

  List<BarrageEntry> _activeEntries = [];
  List<BarrageEntry> _backbufferEntries = [];

  int _currentAliveCount = 0;

  double _emitTimer = 0.0;
  double _metricTimer = 0.0;
  double _cleanupTimer = 0.0;
  bool _initialized = false;
  bool _appActive = true;
  Ticker? _frameTicker;
  Duration? _lastVsyncElapsed;
  int _framePhaseMicros = 0;
  int _elapsedSinceStepMicros = 0;
  int? _scheduledFps;
  int _frameStepCount = 0;

  EngineState _state = EngineState.running;
  bool get isPaused => _state == EngineState.paused;
  final EngineClock clock = EngineClock();

  double _calculateAllowedHeight(double rawHeight) {
    final BuildContext? ctx = buildContext;
    double topInset = 0.0;
    double bottomInset = 0.0;
    if (ctx != null && _config.safeArea) {
      topInset = MediaQuery.paddingOf(ctx).top;
      bottomInset = MediaQuery.paddingOf(ctx).bottom;
    }
    final double finalTop = topInset + _config.topAreaDistance;
    final double finalBottom = bottomInset + _config.bottomAreaDistance;
    // TrackManager applies the configured area percentage. Returning an
    // already-scaled value here applied the percentage twice (20% became 4%)
    // and made lane availability change unexpectedly after rotation.
    return (rawHeight - finalTop - finalBottom).clamp(0.0, rawHeight).toDouble();
  }

  double _getTopOffset() {
    final BuildContext? ctx = buildContext;
    double topInset = 0.0;
    if (ctx != null && _config.safeArea) {
      topInset = MediaQuery.paddingOf(ctx).top;
    }
    return topInset + _config.topAreaDistance;
  }

  double _getBottomOffset() {
    final BuildContext? ctx = buildContext;
    double bottomInset = 0.0;
    if (ctx != null && _config.safeArea) {
      bottomInset = MediaQuery.paddingOf(ctx).bottom;
    }
    return bottomInset + _config.bottomAreaDistance;
  }

  void pause() {
    if (isPaused) return;
    _state = EngineState.paused;
    clock.pause();
    _stopFramePulses();
  }

  void resume() {
    if (!isPaused) return;
    clock.resume();
    _flushPausedBuffer();
    _state = EngineState.running;
    _resumeLoopIfNeeded();
  }

  void _resumeLoopIfNeeded() {
    if (!isPaused &&
        _appActive &&
        _initialized &&
        isAttached &&
        (_waiting.isNotEmpty || _currentAliveCount > 0)) {
      _startFramePulses();
    }
  }

  void _suspendLoopIfIdle() {
    if (_waiting.isEmpty && _currentAliveCount == 0) {
      _stopFramePulses();
    }
  }

  void _startFramePulses() {
    final targetFps = _config.fps.clamp(1, 240).toInt();
    if (_frameTicker?.isActive == true && _scheduledFps == targetFps) return;

    _stopFramePulses();
    // Flame must stay paused for stepEngine() to advance exactly one frame.
    // Timer.periodic is unrelated to display vsync and its wakeups drift or
    // coalesce under load. Ticker aligns every opportunity with Flutter's
    // frame scheduler; the accumulator below still honors lower configured
    // rates and naturally caps impossible values to the physical display.
    pauseEngine();
    _scheduledFps = targetFps;
    _lastVsyncElapsed = null;
    _framePhaseMicros = 0;
    _elapsedSinceStepMicros = 0;
    _frameTicker ??= Ticker(_onFrameTick, debugLabel: 'BarrageEngine.vsync');
    _frameTicker!.start();
  }

  void _onFrameTick(Duration elapsed) {
    if (isPaused ||
        !_appActive ||
        !_initialized ||
        !isAttached ||
        (_waiting.isEmpty && _currentAliveCount == 0)) {
      _stopFramePulses();
      return;
    }

    final previous = _lastVsyncElapsed;
    _lastVsyncElapsed = elapsed;
    if (previous == null) return;

    final targetFps = _scheduledFps ?? _config.fps.clamp(1, 240).toInt();
    final intervalMicros = (Duration.microsecondsPerSecond / targetFps).round();
    final rawDeltaMicros = (elapsed - previous).inMicroseconds;
    final deltaMicros = rawDeltaMicros.clamp(1, intervalMicros * 3).toInt();
    _framePhaseMicros += deltaMicros;
    _elapsedSinceStepMicros += deltaMicros;
    // A small tolerance avoids losing every other frame to integer rounding
    // at rates such as 59.94/119.88 Hz.
    if (_framePhaseMicros + 250 < intervalMicros) return;

    if (_framePhaseMicros < intervalMicros) {
      _framePhaseMicros = 0;
    } else {
      _framePhaseMicros %= intervalMicros;
    }
    final stepMicros = _elapsedSinceStepMicros.clamp(1, intervalMicros * 3).toInt();
    _elapsedSinceStepMicros = 0;
    _frameStepCount++;
    stepEngine(stepTime: stepMicros / Duration.microsecondsPerSecond);
  }

  void _stopFramePulses() {
    _frameTicker?.stop();
    _lastVsyncElapsed = null;
    _framePhaseMicros = 0;
    _elapsedSinceStepMicros = 0;
    _scheduledFps = null;
    pauseEngine();
  }

  void _flushPausedBuffer() {
    final maxPendingCount = _config.maxPendingCount.clamp(1, 10000);
    while (_pausedBuffer.isNotEmpty) {
      while (_waiting.length >= maxPendingCount) {
        _waiting.removeFirst();
      }
      _waiting.add(_pausedBuffer.removeFirst());
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    final clickPos = event.localPosition;
    final int len = _activeEntries.length;

    for (int i = len - 1; i >= 0; i--) {
      final entry = _activeEntries[i];
      if (!entry.active) continue;

      final double left = entry.x;
      final double top = entry.y;
      final double right = left + entry.width;
      final double bottom = top + entry.height;

      if (clickPos.x >= left && clickPos.x <= right && clickPos.y >= top && clickPos.y <= bottom) {
        event.handled = true;
        entry.item.onTapDown?.call();
        break;
      }
    }
  }

  /// Dispatches a Flutter-layer pointer to the top-most visible barrage item.
  /// This lets the video gesture surface keep swipe/double-tap handling while
  /// still supporting precise danmaku actions.
  bool triggerItemAt(double x, double y, {required bool longPress}) {
    for (var i = _activeEntries.length - 1; i >= 0; i--) {
      final entry = _activeEntries[i];
      if (!entry.active ||
          x < entry.x ||
          x > entry.x + entry.width ||
          y < entry.y ||
          y > entry.y + entry.height) {
        continue;
      }
      final callback = longPress ? entry.item.onLongTapDown : entry.item.onTapUp;
      if (callback == null) return false;
      callback();
      return true;
    }
    return false;
  }

  @override
  void onLongTapDown(TapDownEvent event) {
    final clickPos = event.localPosition;
    final int len = _activeEntries.length;
    for (int i = len - 1; i >= 0; i--) {
      final entry = _activeEntries[i];
      if (!entry.active) continue;
      if (clickPos.x >= entry.x &&
          clickPos.x <= entry.x + entry.width &&
          clickPos.y >= entry.y &&
          clickPos.y <= entry.y + entry.height) {
        event.handled = true;
        entry.item.onLongTapDown?.call();
        break;
      }
    }
  }

  @override
  void onTapUp(TapUpEvent event) {
    final clickPos = event.localPosition;
    final int len = _activeEntries.length;
    for (int i = len - 1; i >= 0; i--) {
      final entry = _activeEntries[i];
      if (!entry.active) continue;
      if (clickPos.x >= entry.x &&
          clickPos.x <= entry.x + entry.width &&
          clickPos.y >= entry.y &&
          clickPos.y <= entry.y + entry.height) {
        event.handled = true;
        entry.item.onTapUp?.call();
        break;
      }
    }
  }

  @override
  void onTapCancel(TapCancelEvent event) {
    final int len = _activeEntries.length;
    for (int i = 0; i < len; i++) {
      if (_activeEntries[i].active) {
        _activeEntries[i].item.onTapCancel?.call();
      }
    }
  }

  @override
  Color backgroundColor() => Colors.transparent;

  void updateConfig(BarrageConfig newConfig) {
    final oldConfig = _config;

    final speedChanged = oldConfig.baseSpeed != newConfig.baseSpeed;

    _config = newConfig;

    _parser.updateMaxCacheSize(newConfig.textCacheMaxSize);
    _layout.updateMaxTextCacheSize(newConfig.textCacheMaxSize);
    _pictureCache.updateMaxSize(newConfig.pictureCacheMaxSize);
    _pool.updateMaxSize(newConfig.barragePoolMaxSize);

    if (_initialized) {
      _trackManager.initialize(_config, _calculateAllowedHeight(size.y));
    }

    if (speedChanged) {
      _updateActiveBarrageSpeed();
    }

    if (oldConfig.fps != newConfig.fps && _frameTicker?.isActive == true) {
      _startFramePulses();
    }
  }

  void _updateActiveBarrageSpeed() {
    for (final entry in _activeEntries) {
      if (!entry.active) continue;
      if (entry.item.type != BarrageType.scroll) continue;

      entry.speed = _config.baseSpeed;
    }
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _trackManager.initialize(_config, _calculateAllowedHeight(size.y));
    _initialized = true;
    _resumeLoopIfNeeded();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _trackManager.initialize(_config, _calculateAllowedHeight(size.y));
    _initialized = true;
    _resumeLoopIfNeeded();
  }

  void pushMessage(BarrageItem item) {
    final pending = _PendingBarrage(item, DateTime.now().millisecondsSinceEpoch);
    final maxPendingCount = _config.maxPendingCount.clamp(1, 10000);
    while (_waiting.length + _pausedBuffer.length >= maxPendingCount) {
      if (_waiting.isNotEmpty) {
        _waiting.removeFirst();
      } else {
        _pausedBuffer.removeFirst();
      }
    }
    if (isPaused) {
      _pausedBuffer.add(pending);
    } else {
      _waiting.add(pending);
      _resumeLoopIfNeeded();
    }
  }

  @override
  void update(double dt) {
    if (!_initialized || isPaused) return;

    final targetFps = _config.fps.clamp(1, 240);
    final frameInterval = 1.0 / targetFps;
    final elapsed = dt.clamp(0.0, frameInterval * 3).toDouble();
    super.update(elapsed);

    clock.tick(elapsed);
    final int nowMs = clock.now();

    _emitTimer += elapsed;
    if (_emitTimer >= _config.emitInterval) {
      _emitTimer = 0.0;
      _dispatchWaiting(nowMs);
    }

    final int len = _activeEntries.length;

    for (int i = 0; i < len; i++) {
      final entry = _activeEntries[i];
      if (!entry.active) continue;

      if (entry.item.type == BarrageType.scroll) {
        final deltaMs = nowMs - entry.lastUpdateTime;
        entry.x -= entry.speed * deltaMs / 1000.0;
        entry.lastUpdateTime = nowMs;
        if (entry.x + entry.width < 0) {
          entry.active = false;
        }
      } else {
        if (nowMs >= entry.expireTime) {
          entry.active = false;
        }
      }
    }

    _cleanupTimer += elapsed;
    if (_cleanupTimer >= 0.5) {
      _cleanupTimer = 0.0;

      _backbufferEntries.clear();
      final int currentLen = _activeEntries.length;

      for (int i = 0; i < currentLen; i++) {
        final entry = _activeEntries[i];
        if (entry.active) {
          _backbufferEntries.add(entry);
        } else {
          _pool.recycle(entry);
          _currentAliveCount--;
        }
      }

      final List<BarrageEntry> temp = _activeEntries;
      _activeEntries = _backbufferEntries;
      _backbufferEntries = temp;
    }

    _metricTimer += elapsed;
    if (_metricTimer >= 0.032) {
      _metricTimer = 0.0;
      _updateTrackMetrics(nowMs);
    }

    _suspendLoopIfIdle();
  }

  void _dispatchWaiting(int now) {
    final wallNow = DateTime.now().millisecondsSinceEpoch;
    final maxAgeMs = _config.maxPendingAge.inMilliseconds.clamp(0, 600000);
    while (_waiting.isNotEmpty && wallNow - _waiting.first.enqueuedAtMs > maxAgeMs) {
      _waiting.removeFirst();
    }
    if (_waiting.isEmpty) return;
    if (_currentAliveCount >= _config.maxVisibleCount) return;
    final item = _waiting.first.item;
    final resolvedConfig = _config.copyWith(
      textColor: item.textColor,
      fontSize: item.fontSize,
      fontWeight: item.fontWeight,
      fontStyle: item.fontStyle,
      fontFamily: item.fontFamily,
      letterSpacing: item.letterSpacing,
      opacity: item.opacity,
      showStroke: item.showStroke,
      strokeColor: item.strokeColor,
      strokeWidth: item.strokeWidth,
      showShadow: item.showShadow,
      shadowColor: item.shadowColor,
      shadowBlur: item.shadowBlur,
      shadowOffset: item.shadowOffset,
      fixedDuration: item.fixedDuration,
      emojiSize: item.emojiSize,
      baseSpeed: item.baseSpeed,
      overlapSafeGap: item.overlapSafeGap,
    );
    _trackManager.initialize(resolvedConfig, _calculateAllowedHeight(size.y));
    if (_trackManager.tracks.isEmpty) return;
    final fragments = _parser.parse(item.content);
    final layoutResult = _layout.layout(fragments, item: item, config: resolvedConfig);
    final mockEntry = _pool.obtain(item: item, creationTime: now)
      ..width = layoutResult.width
      ..height = layoutResult.height
      ..lastUpdateTime = now
      ..spawnTime = now
      ..expireTime = now + resolvedConfig.fixedDurationMs;
    mockEntry.speed = item.type == BarrageType.scroll ? resolvedConfig.baseSpeed : 0.0;
    final trackIndex = _trackAllocator.allocate(
      tracks: _trackManager.tracks,
      current: mockEntry,
      screenWidth: size.x,
      config: resolvedConfig,
    );
    if (trackIndex == -1) {
      _pool.recycle(mockEntry);
      return;
    }
    _waiting.removeFirst();
    final track = _trackManager.tracks[trackIndex];
    if (item.type == BarrageType.scroll) {
      mockEntry.speed = _speedStrategy.calculate(
        mockEntry,
        size.x,
        resolvedConfig,
        targetTrack: track,
      );
    }
    track.lastLaunchTime = now;
    final cacheKey = buildCacheKey(item);
    Picture? picture = _pictureCache.get(cacheKey);
    if (picture == null) {
      picture = _renderer.buildPicture(layoutResult);
      _pictureCache.put(cacheKey, picture);
    }
    double startX = size.x;
    double startY =
        _getTopOffset() +
        (trackIndex * resolvedConfig.trackHeight) +
        (resolvedConfig.trackHeight - layoutResult.height) / 2;
    if (item.type != BarrageType.scroll) {
      track.locked = true;
      track.lockedUntil = mockEntry.expireTime;
      startX = (size.x - layoutResult.width) / 2;
      if (item.type == BarrageType.bottomFixed) {
        startY =
            size.y -
            _getBottomOffset() -
            ((trackIndex + 1) * resolvedConfig.trackHeight) +
            (resolvedConfig.trackHeight - layoutResult.height) / 2;
      }
    }
    mockEntry.track = trackIndex;
    mockEntry.x = startX;
    mockEntry.y = startY;
    mockEntry.picture = picture;
    mockEntry.active = true;
    track.lastRight = startX + layoutResult.width;
    track.lastEntry = mockEntry;
    track.activeCount++;
    _activeEntries.add(mockEntry);
    _currentAliveCount++;
  }

  void _updateTrackMetrics(int now) {
    final entryLen = _activeEntries.length;

    for (final track in _trackManager.tracks) {
      double totalSpeed = 0.0;
      int count = 0;
      BarrageEntry? youngestEntry;

      for (int i = 0; i < entryLen; i++) {
        final entry = _activeEntries[i];
        if (!entry.active) continue;
        if (entry.track == track.index) {
          totalSpeed += entry.speed;
          count++;
          if (youngestEntry == null || entry.x > youngestEntry.x) {
            youngestEntry = entry;
          }
        }
      }
      track.activeCount = count;
      track.avgSpeed = count == 0 ? 0.0 : totalSpeed / count;
      track.density = size.x > 0 ? (count * 150.0) / size.x : 0.0;
      if (youngestEntry != null) {
        track.lastRight = youngestEntry.x + youngestEntry.width;
        track.lastEntry = youngestEntry;
      } else {
        if (!track.locked) {
          track.lastRight = 0.0;
          track.lastEntry = null;
        }
        if (track.locked && now >= track.lockedUntil) {
          track.locked = false;
          track.lockedUntil = 0;
          track.lastRight = 0.0;
          track.lastEntry = null;
        }
      }
    }
  }

  void recycleComponent(BarrageEntry entry) {
    _pool.recycle(entry);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (!_initialized) return;
    final int len = _activeEntries.length;
    // Text/emoji/sprite alpha is baked into each cached Picture by
    // MixedLayout. The previous implementation created one offscreen
    // saveLayer per visible item, per display frame: up to 48 * 120 layers/s.
    for (int i = 0; i < len; i++) {
      final entry = _activeEntries[i];
      if (!entry.active || entry.picture == null) continue;
      canvas.save();
      canvas.translate(entry.x, entry.y);
      canvas.drawPicture(entry.picture!);
      canvas.restore();
    }
  }

  void clear() {
    _stopFramePulses();
    _waiting.clear();
    // 清空暂停缓存
    _pausedBuffer.clear();
    _pictureCache.clear();
    _parser.clearCache();
    _layout.clearCache();
    for (var e in _activeEntries) {
      _pool.recycle(e);
    }
    _activeEntries.clear();
    _backbufferEntries.clear();
    _pool.clear();
    _currentAliveCount = 0;
    _emitTimer = 0.0;
    _metricTimer = 0.0;
    _cleanupTimer = 0.0;
    clock.reset();
    for (final track in _trackManager.tracks) {
      track.lastRight = 0.0;
      track.lastEntry = null;
      track.activeCount = 0;
      track.locked = false;
      track.lockedUntil = 0;
    }
  }

  String buildCacheKey(BarrageItem item) {
    return [
      item.content,
      item.type.name,
      item.fontSize ?? _config.fontSize,
      (item.fontWeight ?? _config.fontWeight).toString(),
      (item.fontStyle ?? _config.fontStyle).name,
      (item.textColor ?? _config.textColor).toARGB32(),
      item.emojiSize ?? _config.emojiSize,
      item.fontFamily ?? _config.fontFamily ?? '',
      item.letterSpacing ?? _config.letterSpacing,
      item.showStroke ?? _config.showStroke,
      item.strokeWidth ?? _config.strokeWidth,
      (item.strokeColor ?? _config.strokeColor).toARGB32(),
      item.showShadow ?? _config.showShadow,
      (item.shadowColor ?? _config.shadowColor).toARGB32(),
      item.shadowBlur ?? _config.shadowBlur,
      item.shadowOffset ?? _config.shadowOffset,
      item.opacity ?? _config.opacity,
      item.fixedDuration ?? _config.fixedDuration,
      _config.noEmojiMode,
    ].join('|');
  }

  @override
  void onRemove() {
    clear();
    _frameTicker?.dispose();
    _frameTicker = null;
    super.onRemove();
  }

  @override
  void lifecycleStateChange(AppLifecycleState state) {
    // The custom pulse driver owns scheduling, so do not let Flame restart its
    // display-rate ticker when the app resumes.
    super.lifecycleStateChange(state);
    pauseEngine();
    _appActive = state == AppLifecycleState.resumed || state == AppLifecycleState.inactive;
    if (_appActive) {
      _resumeLoopIfNeeded();
    } else {
      _stopFramePulses();
    }
  }

  int get activeCacheSize => _pictureCache.size;
  int get activePoolSize => _pool.currentSize;
  int get pendingMessageCount => _waiting.length + _pausedBuffer.length;
  int get parserCacheSize => _parser.cacheCount;
  int get layoutCacheSize => _layout.cacheCount;
  bool get framePulseActive => _frameTicker?.isActive == true;
  int get frameStepCount => _frameStepCount;
}
