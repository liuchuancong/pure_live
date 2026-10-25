import 'dart:async' show Future, StreamSubscription, Timer, unawaited;

import 'package:desktop_multi_window/desktop_multi_window.dart' show WindowController, onWindowsChanged;
import 'package:flutter/services.dart' show MethodCall;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_log/live_log.dart' show LiveLog;
import 'package:live_sites/live_sites.dart' show LiveRoom, LiveRoomIdentity;
import 'package:media_core/media_core.dart'
    show KernelAudioDriver, PlayerHandle, PlayerHandlePlayback, PlayerSource, PlayerTransportState;
import 'package:media_core_mediasession/media_core_mediasession.dart';
import 'package:pure_live/app/logging/app_log.dart' show appLog;
import 'package:pure_live/app/providers/player_providers.dart' show playerKernelProvider;
import 'package:pure_live/app/providers/window_providers.dart'
    show isPrimaryWindowProvider, windowIdProvider, windowInvokePrimaryProvider;
import 'package:pure_live/features/room/room_controller.dart' show RoomState, roomProvider;

/// The methods the clone media reporter and the primary's one system media
/// session speak over the window channel.
abstract final class WindowMediaMethods {
  /// Clone → primary: this window now owns a playback worth showing.
  static const String claim = 'media.claim';

  /// Clone → primary: the owner's metadata or transport changed.
  static const String update = 'media.update';

  /// Clone → primary: the owner has no playback to show any more.
  static const String release = 'media.release';

  /// Primary → clone: a system control button was pressed.
  static const String control = 'media.control';

  /// Whether [method] belongs to the media bridge rather than the stores.
  static bool isMedia(String method) =>
      method == claim || method == update || method == release || method == control;
}

/// The primary's one system media session, shared by every window.
///
/// The platform (SMTC, MPRIS, the lock screen) has exactly one media surface
/// per app, and `audio_service` cannot be initialized a second time in the
/// same process. The primary therefore owns the driver and presents the
/// window that most recently claimed playback; that window receives the
/// transport buttons over the window channel.
///
/// One window owns the surface at a time. A new claim (a room starts playing
/// in a window) takes it; the owner's updates refresh it; a release falls
/// back to the most recently claimed other session, or back to the primary's
/// own player when none is left.
final class WindowMediaSessionHub {
  /// Creates the hub for one engine.
  WindowMediaSessionHub(this._ref) {
    if (_ref.read(isPrimaryWindowProvider)) {
      // A window that closes without saying goodbye (its native X, a crash)
      // must not leave a control bar describing a player nobody owns.
      _windowSub = onWindowsChanged.listen((_) => unawaited(_pruneWindows()));
    }
  }

  final Ref _ref;
  final Map<String, _RemoteSession> _sessions = {};
  final List<String> _claims = [];
  StreamSubscription<void>? _windowSub;
  Timer? _reconcileTimer;
  String? _owner;
  String? _presentedOwner;

  /// Dispatches one media method. The primary serves claims/updates/releases;
  /// a clone serves transport buttons.
  Future<Object?> handle(MethodCall call) async {
    final primary = _ref.read(isPrimaryWindowProvider);
    final arguments = _argumentsOf(call.arguments);

    switch (call.method) {
      case WindowMediaMethods.claim:
        if (primary) _claim(arguments);
        return true;
      case WindowMediaMethods.update:
        if (primary) _update(arguments);
        return true;
      case WindowMediaMethods.release:
        if (primary) {
          final windowId = _windowIdOf(arguments);
          if (windowId != null) _drop(windowId);
        }
        return true;
      case WindowMediaMethods.control:
        if (!primary) return await _control(arguments);
        return true;
      default:
        return null;
    }
  }

  /// Releases a window's session, for the close path and window pruning.
  void releaseWindow(String windowId) => _drop(windowId);

  /// Releases the subscription.
  Future<void> dispose() async {
    _reconcileTimer?.cancel();
    _reconcileTimer = null;
    await _windowSub?.cancel();
    _windowSub = null;
  }

  // ---------------------------------------------------------------------------
  // Primary: ownership
  // ---------------------------------------------------------------------------

  void _claim(Map<String, Object?> arguments) {
    final session = _sessionOf(arguments);
    if (session == null) return;

    final windowId = session.windowId;
    _sessions[windowId] = session;
    _claims
      ..remove(windowId)
      ..add(windowId);
    _owner = windowId;
    _present(session);
    _ensureReconcile();
  }

  void _update(Map<String, Object?> arguments) {
    final session = _sessionOf(arguments);
    if (session == null) return;

    final windowId = session.windowId;
    final previous = _sessions[windowId];
    if (previous == null) {
      // A lost claim (a window that started playing while the bridge was
      // arming) still deserves the surface when it reports playing.
      if (session.state.playing) _claim(arguments);
      return;
    }

    _sessions[windowId] = session;
    if (_owner != windowId) return;

    final driver = MediaSessionBootstrap.current;
    if (driver == null) return;
    if (!driver.hasRemoteSession) {
      // Either the surface was never presented (the driver was still
      // initializing at claim time) or a local player took it over. A playing
      // local player keeps its surface; otherwise a playing window may take
      // the bar back, and a paused one only when it was the last owner.
      final local = driver.active;
      if (local?.playback.isPlaying == true) return;
      if (session.state.playing || (local == null && _presentedOwner != windowId)) {
        _present(session);
      }
      return;
    }

    if (!_sameItem(previous.item, session.item)) {
      driver.updateRemoteItem(session.item);
    }
    driver.updateRemoteState(session.state);
  }

  void _drop(String windowId) {
    final wasOwner = _owner == windowId;
    _sessions.remove(windowId);
    _claims.remove(windowId);
    if (_sessions.isEmpty) {
      _reconcileTimer?.cancel();
      _reconcileTimer = null;
    }
    if (!wasOwner) return;

    _owner = null;
    _presentedOwner = null;
    final driver = MediaSessionBootstrap.current;
    // A local player may have taken the surface after this window claimed;
    // releasing the window must not take it back from that player.
    if (driver == null || !driver.hasRemoteSession) return;

    final next = _nextSession();
    if (next != null) {
      _owner = next.windowId;
      _present(next);
      return;
    }

    driver.clearRemote();
    _reconcileTimer?.cancel();
    _reconcileTimer = null;
  }

  _RemoteSession? _nextSession() {
    for (final windowId in _claims.reversed) {
      final session = _sessions[windowId];
      if (session?.state.playing == true) return session;
    }
    if (_claims.isEmpty) return null;
    return _sessions[_claims.last];
  }

  /// Re-presents a playing window after the primary's own player pauses or
  /// stops, and after the media driver finished initializing behind a claim.
  ///
  /// A playing local player always keeps the surface; a paused or absent one
  /// yields to a window that is still playing.
  void _reconcile() {
    if (_sessions.isEmpty) return;
    final driver = MediaSessionBootstrap.current;
    if (driver == null || driver.hasRemoteSession) return;

    final local = driver.active;
    if (local?.playback.isPlaying == true) return;

    final next = _nextSession();
    if (next == null) return;
    if (!next.state.playing && local != null) return;

    _owner = next.windowId;
    _present(next);
  }

  void _ensureReconcile() {
    _reconcileTimer ??= Timer.periodic(const Duration(seconds: 1), (_) => _reconcile());
  }

  void _present(_RemoteSession session) {
    final driver = MediaSessionBootstrap.current;
    if (driver == null) return;

    driver.presentRemote(
      sessionId: _sessionIdOf(session.windowId),
      item: session.item,
      state: session.state,
      target: _RemoteTarget(this, session.windowId, canSeek: session.canSeek),
    );
    _presentedOwner = session.windowId;
  }

  Future<void> _pruneWindows() async {
    if (_sessions.isEmpty) return;
    final List<WindowController> windows;
    try {
      windows = await WindowController.getAll();
    } on Object {
      return;
    }
    final live = {for (final window in windows) window.windowId};
    for (final windowId in _sessions.keys.toList()) {
      if (!live.contains(windowId)) _drop(windowId);
    }
  }

  // ---------------------------------------------------------------------------
  // Clone: transport buttons
  // ---------------------------------------------------------------------------

  Future<Object?> _control(Map<String, Object?> arguments) async {
    final action = arguments['action'];
    if (action is! String) return true;
    final milliseconds = _intOf(arguments['positionMs']);
    await _ref.read(windowMediaReporterProvider.notifier).control(
      action,
      milliseconds == null || milliseconds < 0 ? null : Duration(milliseconds: milliseconds),
    );
    return true;
  }

  // ---------------------------------------------------------------------------
  // Arguments
  // ---------------------------------------------------------------------------

  _RemoteSession? _sessionOf(Map<String, Object?> arguments) {
    final windowId = _windowIdOf(arguments);
    if (windowId == null) return null;

    final title = switch (arguments['title']) {
      final String value when value.trim().isNotEmpty => value.trim(),
      _ => 'Pure Live',
    };
    final artist = switch (arguments['artist']) {
      final String value => value,
      _ => '',
    };
    final album = switch (arguments['album']) {
      final String value => value,
      _ => '',
    };
    final artUri = _artUriOf(arguments['artUri']);
    final position = Duration(milliseconds: _intOf(arguments['positionMs']) ?? 0);
    final durationMs = _intOf(arguments['durationMs']) ?? 0;
    final duration = durationMs > 0 ? Duration(milliseconds: durationMs) : Duration.zero;

    return _RemoteSession(
      windowId: windowId,
      item: MediaSessionItem(
        id: _sessionIdOf(windowId),
        title: title,
        artist: artist,
        album: album,
        duration: duration > Duration.zero ? duration : null,
        artUri: artUri,
      ),
      state: MediaSessionState(
        playing: arguments['playing'] == true,
        position: position,
        duration: duration,
        speed: _doubleOf(arguments['speed']) ?? 1,
        phase: _phaseOf(arguments['phase']),
      ),
      canSeek: arguments['seekable'] == true || duration > Duration.zero,
    );
  }

  static String? _windowIdOf(Map<String, Object?> arguments) {
    return switch (arguments['windowId']) {
      final String value when value.isNotEmpty => value,
      _ => null,
    };
  }

  static int? _intOf(Object? value) => value is int ? value : (value is num ? value.toInt() : null);

  static double? _doubleOf(Object? value) => value is num ? value.toDouble() : null;

  static Uri? _artUriOf(Object? value) {
    if (value is! String) return null;
    final text = value.trim();
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text.startsWith('//') ? 'https:$text' : text);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https') ? uri : null;
  }

  static MediaSurfacePhase _phaseOf(Object? value) => switch (value) {
    'loading' => MediaSurfacePhase.loading,
    'buffering' => MediaSurfacePhase.buffering,
    'completed' => MediaSurfacePhase.completed,
    'idle' => MediaSurfacePhase.idle,
    _ => MediaSurfacePhase.ready,
  };

  static bool _sameItem(MediaSessionItem a, MediaSessionItem b) =>
      a.id == b.id &&
      a.title == b.title &&
      a.artist == b.artist &&
      a.album == b.album &&
      a.duration == b.duration &&
      a.artUri == b.artUri;

  static String _sessionIdOf(String windowId) => 'window/$windowId';

  static Map<String, Object?> _argumentsOf(Object? value) => switch (value) {
    final Map<Object?, Object?> map => {for (final entry in map.entries) '${entry.key}': entry.value},
    _ => const <String, Object?>{},
  };
}

/// One window's playback, as the primary presents it.
final class _RemoteSession {
  const _RemoteSession({
    required this.windowId,
    required this.item,
    required this.state,
    required this.canSeek,
  });

  final String windowId;
  final MediaSessionItem item;
  final MediaSessionState state;
  final bool canSeek;
}

/// Transport buttons routed from the primary's driver to the owning window.
final class _RemoteTarget implements MediaSessionRemoteTarget {
  const _RemoteTarget(this._hub, this.windowId, {required this.canSeek});

  final WindowMediaSessionHub _hub;
  final String windowId;

  @override
  final bool canSeek;

  @override
  Future<void> play() => _hub._sendControl(windowId, 'play');

  @override
  Future<void> pause() => _hub._sendControl(windowId, 'pause');

  @override
  Future<void> stop() => _hub._sendControl(windowId, 'stop');

  @override
  Future<void> seek(Duration position) => _hub._sendControl(windowId, 'seek', position);
}

extension on WindowMediaSessionHub {
  /// Sends one button to [windowId]'s clone. A window that cannot answer is
  /// gone; its session must not keep the surface.
  Future<void> _sendControl(String windowId, String action, [Duration? position]) async {
    try {
      await WindowController.fromWindowId(windowId).invokeMethod<Object>(
        WindowMediaMethods.control,
        {
          'action': action,
          if (position != null) 'positionMs': position.inMilliseconds,
        },
      );
    } on Object catch (error) {
      appLog.forCategory('window media').warning(
        'a media control did not reach its window',
        fields: {'window': windowId, 'action': action, 'error': '$error'},
      );
      _drop(windowId);
    }
  }
}

/// Reports this clone's active player to the primary's one media session.
///
/// The kernel's active handle is the source of truth for every player the
/// clone owns — a live room, VOD, a follow-up engine. `roomProvider` only
/// enriches the metadata when the handle belongs to the room page: its title,
/// streamer and cover are what a viewer recognises in the system bar.
///
/// A claim is sent when a handle starts (or resumes) playing, updates while it
/// owns the surface, and a release when it stops or the window goes away. A
/// short release delay keeps a line switch from blinking the bar away.
final class WindowMediaReporter extends Notifier<bool> {
  final LiveLog _log = appLog.forCategory('window media');
  PlayerHandle? _active;
  StreamSubscription<PlayerTransportState>? _playback;
  Timer? _releaseTimer;
  DateTime? _lastPublish;
  Future<void> _queue = Future<void>.value();
  bool _sent = false;
  bool _wasPlaying = false;
  String? _signature;
  String? _roomKey;

  @override
  bool build() {
    if (ref.read(isPrimaryWindowProvider)) return false;

    final kernel = ref.watch(playerKernelProvider);
    // The same kernel is detached in the disposal below; the lint reads the
    // two uses as one receiver and asks for a cascade that spans the closure.
    // ignore: cascade_invocations
    kernel.attachAudio(_WindowKernelRelay(this));
    ref.listen(roomProvider, (_, next) => _onRoom(next), fireImmediately: true);
    ref.onDispose(() {
      try {
        kernel.detachAudio();
      } on Object {
        // The kernel is already gone.
      }
      unawaited(_playback?.cancel());
      _playback = null;
      _releaseTimer?.cancel();
      _releaseTimer = null;
      _releaseNow();
    });
    return false;
  }

  /// Drops the system surface for this window, if it holds it.
  ///
  /// Completes when the release has reached the primary, so a window that is
  /// about to close can say goodbye before its channel goes away.
  Future<void> release() {
    _releaseNow();
    return _queue;
  }

  /// Runs one system transport button against the active player.
  Future<bool> control(String action, Duration? position) async {
    final handle = _active;
    if (handle == null) return false;

    final room = ref.read(roomProvider);
    final isRoom = room.handle != null && identical(room.handle, handle);

    switch (action) {
      case 'play':
        if (isRoom) {
          if (!room.playback.playing) await ref.read(roomProvider.notifier).togglePlayPause();
        } else {
          await handle.play();
        }
      case 'pause':
        if (isRoom) {
          if (room.playback.playing) await ref.read(roomProvider.notifier).pause();
        } else {
          await handle.pause();
        }
      case 'stop':
        if (isRoom) {
          if (room.playback.playing) await ref.read(roomProvider.notifier).pause();
        } else {
          await handle.stop();
        }
        await release();
      case 'seek':
        if (position != null) await handle.seek(position);
    }
    return true;
  }

  void _activated(PlayerHandle handle) {
    if (identical(handle, _active)) return;

    _releaseTimer?.cancel();
    _releaseTimer = null;
    unawaited(_playback?.cancel());
    _active = handle;
    _wasPlaying = handle.playback.isPlaying;
    _lastPublish = null;
    _roomKey = null;
    _playback = handle.playbackStream.listen(_onTransport, onError: (_) {});
    // A handle can be active but not yet playing (a paused resume from a
    // previous window); the surface should still say what it is.
    _publish(claim: true);
  }

  void _deactivated() {
    if (_active == null) return;
    // A line switch detaches one engine before the next activates; keeping the
    // bar briefly avoids a blink, while a real close still clears it.
    _releaseTimer ??= Timer(const Duration(milliseconds: 900), () {
      _releaseTimer = null;
      _active = null;
      _roomKey = null;
      unawaited(_playback?.cancel());
      _playback = null;
      _releaseNow();
    });
  }

  void _onTransport(PlayerTransportState transport) {
    if (_active == null) return;
    final playing = transport.isPlaying;
    if (playing != _wasPlaying) {
      // A pause and a resume are the two edges the system bar must show at
      // once; position drift is what the throttle below is for.
      _wasPlaying = playing;
      _publish(claim: playing);
      return;
    }
    _publishThrottled();
  }

  void _onRoom(RoomState room) {
    final handle = _active;
    final live = room.room;
    if (handle == null || live == null || room.handle == null || !identical(room.handle, handle)) return;

    final key = live.identityKey;
    final switched = _roomKey != null && _roomKey != key;
    _roomKey = key;
    _publish(claim: switched || (room.playback.playing && !_wasPlaying));
  }

  void _publishThrottled() {
    final now = DateTime.now();
    final last = _lastPublish;
    if (last != null && now.difference(last) < const Duration(seconds: 1)) return;
    _lastPublish = now;
    _publish(claim: false);
  }

  void _publish({required bool claim}) {
    final handle = _active;
    if (handle == null) return;
    final payload = _payload(handle);
    if (payload == null) return;

    final playing = payload['playing'] == true;
    final signature = _signatureOf(payload);
    if (claim || (playing && !_sent)) {
      _sent = true;
      _send(WindowMediaMethods.claim, payload);
    } else if (_sent && signature != _signature) {
      _send(WindowMediaMethods.update, payload);
    }

    _signature = signature;
    _wasPlaying = playing;
  }

  Map<String, Object?>? _payload(PlayerHandle handle) {
    final windowId = ref.read(windowIdProvider);
    if (windowId == null || windowId.isEmpty) return null;

    final room = ref.read(roomProvider);
    final live = room.room;
    final fromRoom = live != null && room.handle != null && identical(room.handle, handle);
    final source = handle.source;

    final title = fromRoom ? _roomTitle(live) : _sourceTitle(source);
    final artist = fromRoom ? (live.anchor?.name.trim() ?? '') : _metadataText(source?.metadata['artist']);
    final album = fromRoom ? '' : _metadataText(source?.metadata['album']);
    final artwork = fromRoom
        ? _artUriOf(live.content.coverUrl)
        : _artUriOf(_metadataText(source?.metadata['artUri']));

    final playback = handle.playback;
    return <String, Object?>{
      'windowId': windowId,
      'title': title,
      'artist': artist,
      'album': album,
      'artUri': artwork?.toString(),
      'playing': playback.isPlaying,
      'phase': _phaseOf(playback),
      'positionMs': playback.position.inMilliseconds,
      'durationMs': playback.duration > Duration.zero ? playback.duration.inMilliseconds : null,
      'seekable': playback.duration > Duration.zero,
      'speed': playback.rate,
    };
  }

  void _releaseNow() {
    _releaseTimer?.cancel();
    _releaseTimer = null;
    if (!_sent) return;

    _sent = false;
    _wasPlaying = false;
    _signature = null;
    _roomKey = null;

    final windowId = ref.read(windowIdProvider);
    if (windowId == null || windowId.isEmpty) return;
    _send(WindowMediaMethods.release, {'windowId': windowId});
  }

  void _send(String method, Map<String, Object?> arguments) {
    final invoke = ref.read(windowInvokePrimaryProvider);
    if (invoke == null) return;
    _queue = _queue.then((_) async {
      try {
        await invoke(method, arguments);
      } on Object catch (error) {
        _log.warning('a media report did not reach the primary', fields: {'method': method, 'error': '$error'});
      }
    });
  }

  static String _roomTitle(LiveRoom live) {
    final title = live.content.title.trim();
    if (title.isNotEmpty) return title;
    final anchor = live.anchor?.name.trim() ?? '';
    return anchor.isNotEmpty ? anchor : live.roomId;
  }

  static String _sourceTitle(PlayerSource? source) {
    final title = source?.title?.trim() ?? '';
    if (title.isNotEmpty) return title;
    final segments = source?.uri.pathSegments ?? const <String>[];
    if (segments.isNotEmpty && segments.last.isNotEmpty) return segments.last;
    return 'Pure Live';
  }

  static String _metadataText(Object? value) => value is String ? value.trim() : '';

  static String _phaseOf(PlayerTransportState playback) {
    if (playback.isIdle || playback.isStopped) return 'idle';
    if (playback.isLoading) return 'loading';
    if (playback.isBuffering) return 'buffering';
    if (!playback.isPlaying && playback.hasDuration && playback.position >= playback.duration) return 'completed';
    return 'ready';
  }

  static Uri? _artUriOf(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text.startsWith('//') ? 'https:$text' : text);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https') ? uri : null;
  }

  static String _signatureOf(Map<String, Object?> payload) {
    return [
      payload['title'],
      payload['artist'],
      payload['album'],
      payload['artUri'],
      payload['playing'],
      payload['phase'],
      payload['durationMs'],
      payload['positionMs'],
    ].join('|');
  }
}

/// The kernel's active-player door, forwarded to the reporter.
final class _WindowKernelRelay implements KernelAudioDriver {
  _WindowKernelRelay(this._reporter);

  final WindowMediaReporter _reporter;

  @override
  void onPlayerActivated(PlayerHandle handle) => _reporter._activated(handle);

  @override
  void onPlayerDeactivated() => _reporter._deactivated();
}

/// The clone's playback reporter. Read once per desktop engine; the primary
/// builds it as a no-op.
final windowMediaReporterProvider = NotifierProvider<WindowMediaReporter, bool>(WindowMediaReporter.new);
