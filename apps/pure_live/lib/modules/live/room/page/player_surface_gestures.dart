part of 'player_surface.dart';

// State members hosted by an extension: the receiver is the State, so
// its protected setState is safe to call here.
// ignore_for_file: invalid_use_of_protected_member

extension _PlayerSurfacePictureGestures on _PlayerSurfaceState {
  /// The picture's own gestures and the layers they feed: the tap and the

  /// them back whatever it hit; a message opens its actions only while the
  /// bars already show, and not on a picture that is stopped — there the tap
  /// is the way back to play.
  Future<void> _onPictureTap() async {
    // Locked, the picture answers nothing: a tap must neither open the
    // message under the finger nor bring the bars back.
    if (_locked) return;
    if (_openPicker != null) {
      // The catalogue is the thing the viewer is done with; a tap on the
      // picture closes it the way tapping anywhere else would.
      _hidePicker();
      return;
    }
    final shownBefore = _controlsVisible;
    if (!ref.read(danmakuTapInteractionProvider)) {
      _releaseDanmaku();
      _toggleControls();
      return;
    }
    final item = _takeHeldDanmaku();
    if (item == null || !shownBefore || !widget.roomState.playback.playing) {
      // The message was frozen on pointer-down; this tap was never going to
      // open it, so it flies on and the bars take the tap instead.
      if (item != null) widget.barrage?.resumeAllPaused();
      _toggleControls();
      return;
    }
    await _showDanmakuActions(item);
  }

  /// A long press pins the message under the finger and opens the same
  /// actions as a tap; empty space keeps the normal controls behaviour.
  Future<void> _onPictureLongPress() async {
    if (_locked) return;
    if (!ref.read(danmakuLongPressInteractionProvider)) {
      _releaseDanmaku();
      return;
    }
    final item = _takeHeldDanmaku();
    if (item == null) return;
    await _showDanmakuActions(item);
  }

  BarrageItem? _takeHeldDanmaku() {
    var item = _heldDanmaku;
    final press = _pressLocal;
    if (item == null && !ref.read(danmakuHoldProvider) && press != null) {
      // Holding is off, so the message was not frozen on pointer-down; find
      // it under the press now, just before the panel opens.
      item = widget.barrage?.pauseItemAt(press.dx, press.dy);
    }
    _heldDanmaku = null;
    _holdOrigin = null;
    _pressLocal = null;
    return item;
  }

  Future<void> _showDanmakuActions(BarrageItem item) async {
    try {
      await showRoomMessageActions(
        context,
        ref,
        text: item.content,
        userName: item.userName ?? '',
        // The viewer's own echo is the only local message on the flying
        // layer; it carries no platform identity to block.
        isLocal: item.id?.startsWith('local-') ?? false,
      );
    } finally {
      widget.barrage?.resumeAllPaused();
    }
  }

  /// Pins the flying danmaku under a finger the moment it goes down, so the
  /// actions target the message the tap started on rather than the one that
  /// has flown there by the time the gesture resolves. Either interaction
  /// switch may own the press: a long press still targets its message with
  /// tap actions off.
  void _holdDanmaku(PointerDownEvent event) {
    if (_locked) return;
    if (_holdOrigin != null) return;
    if (!ref.read(danmakuTapInteractionProvider) && !ref.read(danmakuLongPressInteractionProvider)) return;
    _holdOrigin = event.position;
    _pressLocal = event.localPosition;
    if (!ref.read(danmakuHoldProvider)) return;
    final item = widget.barrage?.pauseItemAt(event.localPosition.dx, event.localPosition.dy);
    if (item != null) _heldDanmaku = item;
  }

  /// A finger that moves past the touch slop is a drag, not a press: the
  /// message flies on and the release wakes or dismisses the bars instead.
  void _releaseDanmakuOnMove(PointerMoveEvent event) {
    final origin = _holdOrigin;
    if (origin != null && (event.position - origin).distance > kTouchSlop) _releaseDanmaku();
  }

  /// Lets a held message fly on when the gesture turned out not to be its
  /// tap (a double tap enters or leaves fullscreen, a drag sets the volume).
  void _releaseDanmaku() {
    _holdOrigin = null;
    _pressLocal = null;
    if (_heldDanmaku == null) return;
    _heldDanmaku = null;
    widget.barrage?.resumeAllPaused();
  }

  /// Shows the figure the picture's gesture is setting; [brightness] says which
  /// one it is, so the glyph and the number always agree.
  void _showAdjust(double value, {bool brightness = false}) {
    _volumeHudTimer?.cancel();
    setState(() {
      _volumeHud = value.clamp(0.0, 1.0);
      _hudIsBrightness = brightness;
    });
    _volumeHudTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _volumeHud = null);
    });
  }

  /// A vertical drag takes the volume from where it is: up is louder, the
  /// whole picture is the track (no brightness half to confuse the pinch).
  /// A vertical drag on the picture: the right half is the volume, the left half
  /// the screen's brightness — the arrangement every video surface the viewer
  /// already knows uses. The brightness half exists only where the display will
  /// take the write; elsewhere the whole picture is the volume, so no half is
  /// ever a gesture that does nothing.
  void _beginPictureDrag(double dx, double width) {
    _dragIsBrightness = _brightnessWritable == true && dx < width / 2;
    if (_dragIsBrightness) {
      _dragBrightness = _brightness.toDouble();
      _showAdjust(_brightness / 100, brightness: true);
      return;
    }
    _dragVolume = ref.read(roomProvider.notifier).volume;
    _showAdjust(_dragVolume);
  }

  void _dragPictureBy(double delta) {
    if (_dragIsBrightness) {
      // The same travel as the volume: a full-height drag crosses the range.
      final next = (_dragBrightness - delta / 2.2).clamp(0.0, 100.0);
      _dragBrightness = next;
      _showAdjust(next / 100, brightness: true);
      // A native write only when the whole percent actually moved — a drag
      // reports a delta per frame, and the display takes one value per percent.
      if (next.round() != _brightness) {
        _brightness = next.round();
        unawaited(
          _screenBrightness.setBrightness(_brightness, scope: _brightnessScope).catchError((Object _) => _brightness),
        );
      }
      return;
    }
    final next = (_dragVolume - delta / 220).clamp(0.0, 1.0);
    _dragVolume = next;
    _showAdjust(next);
    unawaited(ref.read(roomProvider.notifier).setVolume(next));
  }

  /// A wheel step takes the viewer's chosen share of the range (the
  /// 画质与音频 setting), so a desktop mouse has a usable granularity
  /// without a slider.
  void _wheelVolume(double delta) {
    final step = ref.read(playbackSettingsProvider).volumeWheelStepPercent / 100;
    final next = (ref.read(roomProvider.notifier).volume + (delta > 0 ? -step : step)).clamp(0.0, 1.0);
    _showAdjust(next);
    unawaited(ref.read(roomProvider.notifier).setVolume(next));
  }

  /// The band along the portrait full screen's bottom edge an upward swipe
  /// restores the page's layout from (the reference's `portraitRestoreZone`):
  /// the bottom bar and as much again over it.
  static const double _restoreZone = 96;

  /// The bottom band an Android phone keeps for going home when the system
  /// reports none (the reference's `androidGestureFallback`): HyperOS reports
  /// only its top band while its bottom edge still goes home.
  static const double _androidGestureFallback = 32;

  /// What a vertical drag that went down at [down] and read as a drag at
  /// [start] does (the reference's gesture layer).
  ///
  /// The portrait full screen's restore band is asked first, so the way back to
  /// the chat is never read as a volume change. A drag that began on a system
  /// gesture edge is the system's and changes nothing here. In the portrait
  /// full screen the middle third switches rooms where the page offers it, as
  /// it always has; the halves set the volume and the brightness everywhere.
  _PictureDrag? _pictureDragAt(DragDownDetails? down, DragStartDetails start) {
    if (_locked) return null;
    final size = context.size ?? MediaQuery.sizeOf(context);
    final origin = down?.localPosition ?? start.localPosition;
    if (widget.onPortraitRestore != null && origin.dy >= size.height - _restoreZone) return _PictureDrag.restore;
    if (_onSystemGestureEdge(down?.globalPosition.dy ?? start.globalPosition.dy)) return null;
    final dx = start.localPosition.dx;
    final middleThird = dx >= size.width / 3 && dx <= size.width * 2 / 3;
    if (widget.portraitFullscreen && widget.onPortraitSwipe != null && middleThird) return _PictureDrag.switchRoom;
    return _PictureDrag.adjust;
  }

  /// Whether a drag that went down [globalY] down the window began in the
  /// system's own gesture band at its bottom or top edge (the reference's
  /// A07.15): going home, or pulling the status bar down, must not also change
  /// the volume, the brightness or the room. Global, because the picture need
  /// not fill the window. The side edges are Back's, a sideways gesture no
  /// vertical drag competes with, and are left alone. A desktop reports no
  /// bands, so every drag there stays as it was.
  bool _onSystemGestureEdge(double globalY) {
    final insets = MediaQuery.systemGestureInsetsOf(context);
    final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final fallback = android ? _androidGestureFallback : 0.0;
    final bottom = insets.bottom > 0 ? insets.bottom : fallback;
    final height = MediaQuery.sizeOf(context).height;
    return (bottom > 0 && globalY >= height - bottom) || (insets.top > 0 && globalY < insets.top);
  }

  /// The flying layer's config from the live look; a compact surface passes
  /// its scaled geometry and the reference's smaller pending queue/caches,
  /// everything else comes from the one main configuration.
  BarrageConfig _barrageConfig(
    DanmakuStyle style,
    int fps, {
    String? family,
    double? area,
    CompactDanmakuMetrics? compact,
  }) => playerBarrageConfig(
    style,
    fps,
    family: family,
    area: area,
    fixedDuration: Duration(milliseconds: (ref.read(danmakuFixedDurationProvider) * 1000).round()),
    compact: compact,
  );
}
