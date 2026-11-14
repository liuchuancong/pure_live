part of 'room_page.dart';

// State members hosted by an extension: the receiver is the State, so
// its protected setState is safe to call here.
// ignore_for_file: invalid_use_of_protected_member

extension _RoomPageLifecycle on _RoomPageState {
  /// The page's own lifecycle plumbing (the reference's background rules): the
  /// write-after-frame seam, the orientation policy, the screen-wake hold, the
  /// app-lifecycle pauses, the picture-in-picture bookkeeping, the floating
  /// window arming, and the panel stack the room menu opens into.

  /// The route unmounts while the tree is being torn down, and Riverpod
  /// rejects a notification in that phase — it left the page half unmounted
  /// with the route transition reading a dead element. The write therefore
  /// rides the end of the frame, and it goes through a notifier captured
  /// while this page still existed, never through its own `ref`.
  void _writeAfterFrame(void Function() write) => unawaited(Future<void>.delayed(Duration.zero, write));

  /// The reference's `applyFullscreenOrientationPolicy`: on a phone the
  /// fullscreen orientation policy decides which way the device turns as
  /// the room goes system-fullscreen — upright for a portrait stream (or
  /// always, per the choice), sideways for the rest, or the lock released
  /// to follow the accelerometer. Desktop and web answer inert there. VOD and
  /// IPTV ask the same rule for themselves.
  void _applyFullscreenOrientation() {
    applyFullscreenOrientation(
      _screenOrientation,
      aspectRatio: ref.read(roomProvider).handle?.combinedSnapshot.geometry.aspectRatio ?? 0,
    );
  }

  void _watchSlow(RoomState room) {
    final connecting = room.room != null && room.handle == null && !room.playback.playing;
    if (connecting && _slowTimer == null) {
      _slowTimer = Timer(slowAfter, () {
        if (mounted) ref.read(roomSlowProvider.notifier).slow = true;
      });
    } else if (!connecting && _slowTimer != null) {
      _slowTimer?.cancel();
      _slowTimer = null;
      // The flag feeds the overlay this build reads; flipping it after the
      // frame avoids modifying a provider mid-build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(roomSlowProvider.notifier).slow = false;
      });
    }
  }

  /// The reference's auto-fullscreen: a room whose stream starts playing
  /// enters fullscreen once. A viewer already in another presentation mode
  /// (or one who leaves it) keeps their choice; a paused or failed room
  /// never asks.
  void _maybeAutoFullscreen(RoomState room, PresentationMode presentation) {
    if (_autoFullscreenDone) return;
    if (!_autoFullscreenArmed) return;
    final handle = room.handle;
    if (handle == null || !room.playback.playing) return;
    _autoFullscreenDone = true;
    if (presentation != PresentationMode.normal) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(roomPresentationProvider) != PresentationMode.normal) return;
      if (!ref.read(roomProvider).playback.playing) return;
      // The fullscreen verb follows the picture's shape: a portrait stream
      // opens onto the portrait full-screen surface, a landscape one into
      // the system's own fullscreen. A phone's portrait immersive room is
      // already the page's full-bleed layout — there is no fuller surface
      // under it, so the portrait branch has nothing to do there.
      final portrait = _pictureRatio(ref.read(roomProvider)) < 1;
      final formFactor = ref.read(platformRuntimeProvider).environment.runtime.formFactor;
      // 平板走桌面骨架：它的竖屏流没有沉浸式房间，照旧落竖屏全屏表面。
      final mobile = formFactor == FormFactor.phone || formFactor == FormFactor.tablet;
      final phoneImmersive =
          mobile &&
          !isTabletSized(MediaQuery.sizeOf(context)) &&
          MediaQuery.sizeOf(context).width < kRoomCompactBreakpoint;
      if (portrait && phoneImmersive) return;
      if (portrait) {
        _setPortraitFullscreen(true);
        return;
      }
      unawaited(ref.read(roomPresentationProvider.notifier).toggleFullscreen(handle.id));
    });
  }

  /// Holds the display awake exactly while frames are playing and the
  /// preference allows it: a paused room, a failed room, or the setting off
  /// lets the display sleep as usual.
  void _syncScreenWake(bool hold) {
    if (hold == _screenHeld) return;
    _screenHeld = hold;
    unawaited((hold ? _screenAwake.enable() : _screenAwake.disable()).catchError((Object _) {}));
  }

  /// The PiP window went away: pause only when the room would otherwise keep
  /// playing in the background, as the reference's "关闭画中画时暂停".
  ///
  /// On iOS the system window is the one that closes this way; on Android the
  /// switch lives next to background playback, which already keeps the app
  /// quiet when it is off.
  void _onPipChanged(bool active) {
    if (active) {
      _pipWasActive = true;
      return;
    }
    if (!_pipWasActive) return;
    _pipWasActive = false;
    final platform = defaultTargetPlatform;
    if (_appInForeground || kIsWeb || (platform != TargetPlatform.android && platform != TargetPlatform.iOS)) return;
    final settings = ref.read(playbackSettingsProvider);
    if (!settings.pauseOnPipClose) return;
    if (platform == TargetPlatform.android && !settings.backgroundPlay) return;
    final room = ref.read(roomProvider);
    if (room.handle == null || !room.playback.playing) return;
    _pausedByPipClose = true;
    unawaited(ref.read(roomProvider.notifier).pause());
  }

  void _resumeAfterPipClose() {
    if (!_pausedByPipClose) return;
    _pausedByPipClose = false;
    final room = ref.read(roomProvider);
    if (room.handle == null || room.playback.playing) return;
    unawaited(ref.read(roomProvider.notifier).togglePlayPause());
  }

  /// Android background playback may keep only the audio: the video decoder
  /// stops, the sound and the room's session stay, and the pre-background
  /// mode is remembered for the return.
  void _applyBackgroundAudioOnly() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final settings = ref.read(playbackSettingsProvider);
    if (!settings.backgroundPlay || !settings.backgroundAudioOnly) return;
    final room = ref.read(roomProvider);
    if (room.handle == null || !room.playback.playing || room.audioOnly) return;
    _audioOnlyBeforeBackground = room.audioOnly;
    _backgroundAudioOnlyApplied = true;
    unawaited(ref.read(roomProvider.notifier).setAudioOnly(value: true));
  }

  void _restoreBackgroundAudioOnly() {
    if (!_backgroundAudioOnlyApplied) return;
    _backgroundAudioOnlyApplied = false;
    if (_audioOnlyBeforeBackground) return;
    unawaited(ref.read(roomProvider.notifier).setAudioOnly(value: false));
  }

  /// Pauses the site's danmaku connection in the background when the viewer
  /// asked for it; the room's chat list keeps what it already has.
  void _pauseBackgroundDanmaku() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final settings = ref.read(playbackSettingsProvider);
    if (!settings.backgroundPlay || !settings.backgroundPauseDanmaku) return;
    if (_backgroundDanmakuPaused) return;
    _backgroundDanmakuPaused = true;
    unawaited(ref.read(roomProvider.notifier).pauseDanmakuConnection());
  }

  void _resumeBackgroundDanmaku() {
    if (!_backgroundDanmakuPaused) return;
    _backgroundDanmakuPaused = false;
    unawaited(ref.read(roomProvider.notifier).resumeDanmakuConnection());
  }

  /// The Android small window took the screen, or gave it back: while it shows,
  /// the room's floating player is the whole content of the window; with it
  /// gone, the page behind — still mounted and playing — is what the viewer
  /// sees again.
  void _onFloatingWindowChanged() {
    if (FloatingOverlay.active.value) {
      unawaited(FloatingRoomPlayer.show());
    } else {
      FloatingRoomPlayer.hide();
      // The window takes its arm with it when it closes itself; re-decide for
      // the next leave once the page draws again.
      _floatingArmed = false;
      _floatingArmedSize = null;
    }
    if (mounted) setState(() {});
  }

  /// "离开应用时自动小窗": keeps the small window armed while a room plays, so
  /// leaving the app (home, recents) shows the picture over the other apps.
  ///
  /// Armed here, ahead of the leave, because the native side decides in
  /// `onUserLeaveHint` — before any Dart call could run. Phones only, and only
  /// with the draw-over-other-apps grant: without it the app simply leaves.
  void _syncFloatingWindowArm(
    RoomState room, {
    required Size screen,
    required bool onTop,
    required bool autoSmallWindow,
    required FloatingWindowSettings floating,
  }) {
    if (!FloatingOverlay.supported) return;
    final wanted =
        onTop && autoSmallWindow && room.handle != null && room.playback.playing && !FloatingOverlay.active.value;
    final size = wanted ? _floatingWindowSize(_floatingWindowRatio(room), floating, screen) : Size.zero;
    if (wanted == _floatingArmed && (!wanted || size == _floatingArmedSize)) return;
    _floatingArmed = wanted;
    _floatingArmedSize = wanted ? size : null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!wanted) {
        unawaited(FloatingOverlay.disarm());
        return;
      }
      unawaited(_armFloatingWindow(size));
    });
  }

  Future<void> _armFloatingWindow(Size size) async {
    if (!await FloatingOverlay.refresh()) {
      // No grant yet: leave the arm open so the next build arms the window
      // once the viewer grants it (the setting's toggle asks for it).
      _floatingArmed = false;
      _floatingArmedSize = null;
      return;
    }
    if (!mounted || !_floatingArmed) return;
    await FloatingOverlay.arm(width: size.width, height: size.height);
  }

  /// The grant can arrive while the app is away (the system page) or after the
  /// page armed without it: re-run the arm decision.
  void _onFloatingWindowPermitted() {
    if (mounted) setState(() {});
  }

  /// The small window's size: the floating player's, for the picture's shape,
  /// kept inside [screen] the way the in-app window is.
  Size _floatingWindowSize(double ratio, FloatingWindowSettings floating, Size screen) {
    final portrait = ratio < 1;
    final base =
        kFloatingWindowBaseWidth *
        floatingWindowSizeFactor(floating.size) *
        (portrait ? floating.portraitScale : floating.landscapeScale);
    final maxWidth = math.min(screen.width - 16, math.max(220, (screen.height - 16) * ratio)).toDouble();
    final width = base.clamp(200, math.max(200, maxWidth)).toDouble();
    return Size(width, width / ratio);
  }

  double _floatingWindowRatio(RoomState room) {
    final detected = room.handle?.combinedSnapshot.geometry.aspectRatio ?? 0;
    return detected > 0 && detected.isFinite ? detected.clamp(kRoomFrameRatioMin, kRoomFrameRatioMax) : 16 / 9;
  }

  /// The panel state moved: sweep whatever panel route is up, then show
  /// the wanted one (or nothing). A close routes through here too, so the
  /// page's bookkeeping and the stack agree.
  void _onRoomPanelChanged() {
    final kind = _panels.value;
    if (kind == _openPanelKind) return;
    _rootNav?.popUntil((route) => !isRoomPanelRoute(route));
    _openPanelKind = kind;
    if (kind == null) return;
    unawaited(_showRoomPanel(kind));
  }

  Future<void> _showRoomPanel(RoomPanelKind kind) async {
    await showAppPanel<void>(
      context: context,
      routeSettings: RouteSettings(name: roomPanelRouteName(kind)),
      builder: (sheetContext) => roomPanelSheet(sheetContext, kind),
    );
    if (!mounted) return;
    // The sheet went away for good (its own close, the scrim, back): the
    // controller follows, quietly — a replaced panel has already been
    // swept by the open that displaced it.
    if (_panels.value == kind) {
      _openPanelKind = null;
      _panels.close();
    }
  }
}
