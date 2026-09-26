import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fvp/mdk.dart' as mdk;
import 'package:rxdart/rxdart.dart';

import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/player/core/flv_legacy_hevc_relay.dart';
import 'package:pure_live/player/core/playback_proxy_policy.dart';
import 'package:pure_live/player/core/player_error_classifier.dart';
import 'package:pure_live/player/interface/unified_player_interface.dart';
import 'package:pure_live/player/models/player_engine.dart';
import 'package:pure_live/player/models/player_error_type.dart';
import 'package:pure_live/player/models/player_exception.dart';
import 'package:pure_live/player/models/player_state.dart';

/// libmdk engine through fvp's `mdk.Player` API.
///
/// mdk ships a current FFmpeg, so it reads codec-id-12 HEVC FLV and other
/// streams the older engines drop, and it prefers platform hardware decoders
/// (MediaCodec / VideoToolbox) with FFmpeg and dav1d as software fallbacks.
class FvpAdapter
    implements
        UnifiedPlayer,
        VideoFitAwarePlayer,
        SourceTransitionAwarePlayer,
        AudioOutputSuppressionAwarePlayer,
        PrivateInputAwarePlayer {
  mdk.Player? _player;
  bool _initialized = false;
  bool _disposed = false;
  bool _audioOnly = false;
  bool _audioOutputSuppressed = false;
  bool _acceptSourceEvents = false;
  bool _privateInput = false;
  bool _hardwareDecoding = true;
  String? _currentUrl;
  double _volume = 1.0;
  BoxFit _fit = BoxFit.contain;
  int _generation = 0;

  final _stateSubject = BehaviorSubject<PlayerState>.seeded(PlayerState.idle);
  final _playingSubject = BehaviorSubject<bool>.seeded(false);
  final _loadingSubject = BehaviorSubject<bool>.seeded(false);
  final _errorSubject = PublishSubject<PlayerException>();
  final _completeSubject = BehaviorSubject<bool>.seeded(false);
  final _widthSubject = BehaviorSubject<int?>.seeded(null);
  final _heightSubject = BehaviorSubject<int?>.seeded(null);
  final _sizeNotifier = ValueNotifier<Size?>(null);
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  @override
  PlayerEngine get engine => PlayerEngine.fvp;

  /// Hardware first, then FFmpeg and dav1d; software only when the user turned
  /// hardware decoding off.
  static List<String> videoDecoders({required bool hardware}) {
    if (!hardware) return const ['FFmpeg', 'dav1d'];
    if (Platform.isAndroid) return const ['AMediaCodec', 'FFmpeg', 'dav1d'];
    if (Platform.isIOS || Platform.isMacOS) return const ['VT', 'FFmpeg', 'dav1d'];
    if (Platform.isWindows) return const ['MFT:d3d=11', 'D3D11', 'DXVA', 'FFmpeg', 'dav1d'];
    return const ['VAAPI', 'VDPAU', 'FFmpeg', 'dav1d'];
  }

  /// Android: OpenSL first. mdk's AAudio output crashes on dispose ("pure
  /// virtual function called", fvp#376), stutters on coarse-clock devices
  /// (fvp#384) and dies on output routing changes (fvp#386); OpenSL does not.
  static List<String>? audioBackends({bool? android}) =>
      (android ?? Platform.isAndroid) ? const ['OpenSL', 'AudioTrack', 'AAudio'] : null;

  /// Legacy codec-id-12 HEVC FLV (Shopee Live, some 17LIVE) is rejected by
  /// some Android hardware decoders ("Unsupported input buffer": audio plays,
  /// every video frame is dropped) without an error that would advance mdk to
  /// the next decoder, so decode it in software there.
  static List<String> videoDecodersFor(String url, {required bool hardware, bool? android}) {
    if ((android ?? Platform.isAndroid) && FlvLegacyHevcRelay.appliesTo(url)) return const ['FFmpeg', 'dav1d'];
    return videoDecoders(hardware: hardware);
  }

  /// `avio.headers` takes CRLF-terminated lines; reject values that would
  /// inject extra header lines.
  static String encodeHeaders(Map<String, String> headers) {
    final buffer = StringBuffer();
    headers.forEach((name, value) {
      if (name.isEmpty || RegExp(r'[\r\n:]').hasMatch(name) || RegExp(r'[\r\n]').hasMatch(value)) return;
      buffer.write('$name: $value\r\n');
    });
    return buffer.toString();
  }

  @override
  Future<void> init({bool audioOnly = false}) async {
    if (_initialized || _disposed) return;
    _audioOnly = audioOnly;
    final player = mdk.Player();
    _player = player;
    var hardware = true;
    try {
      hardware = SettingsService.to.player.enableCodec.value;
    } catch (_) {}
    _hardwareDecoding = hardware;
    player.videoDecoders = videoDecoders(hardware: hardware);
    final backends = audioBackends();
    if (backends != null) player.audioBackends = backends;
    // Live-stream defaults mirroring fvp's own video_player backend.
    player.setProperty('avformat.strict', 'experimental');
    player.setProperty('avformat.safe', '0');
    player.setProperty('avio.reconnect', '1');
    player.setProperty('avio.reconnect_delay_max', '7');
    player.setProperty('avformat.extension_picky', '0');
    player.setProperty('avformat.allowed_segment_extensions', 'ALL');
    player.setProperty('avio.protocol_whitelist', 'file,http,https,tls,tcp,udp,crypto,httpproxy,data');
    _bind(player);
    _initialized = true;
    _stateSubject.add(PlayerState.initialized);
  }

  void _bind(mdk.Player player) {
    _subscriptions.add(
      player.onStateChanged.listen((event) {
        if (_disposed || !_acceptSourceEvents) return;
        switch (event.newValue) {
          case mdk.PlaybackState.playing:
            _playingSubject.add(true);
            _stateSubject.add(PlayerState.playing);
          case mdk.PlaybackState.paused:
            _playingSubject.add(false);
            _stateSubject.add(PlayerState.paused);
          case mdk.PlaybackState.stopped:
          case mdk.PlaybackState.notRunning:
            _playingSubject.add(false);
          case mdk.PlaybackState.running:
            break;
        }
      }),
    );
    _subscriptions.add(
      player.onMediaStatus.listen((event) {
        if (_disposed || !_acceptSourceEvents) return;
        final status = event.newValue;
        if (status.test(mdk.MediaStatus.invalid)) {
          _fail('fvp: invalid or unsupported media', PlayerErrorType.source);
          return;
        }
        if (status.test(mdk.MediaStatus.end) && !event.oldValue.test(mdk.MediaStatus.end)) {
          _playingSubject.add(false);
          _completeSubject.add(true);
          _stateSubject.add(PlayerState.completed);
          return;
        }
        final buffering = status.test(mdk.MediaStatus.buffering) || status.test(mdk.MediaStatus.loading);
        if (buffering != _loadingSubject.value) {
          _loadingSubject.add(buffering);
          if (buffering) _stateSubject.add(PlayerState.buffering);
        }
      }),
    );
    // mdk reports a failed decoder open (e.g. a subtitle or hardware
    // decoder) as a negative onEvent and then tries the next decoder in the
    // list, so those events are not terminal; MediaStatus.invalid is.
  }

  void _fail(String message, PlayerErrorType fallbackType) {
    final classification = PlayerErrorClassifier.classify(message);
    final type = classification.type == PlayerErrorType.unknown ? fallbackType : classification.type;
    _playingSubject.add(false);
    _loadingSubject.add(false);
    _stateSubject.add(PlayerState.error);
    if (!_errorSubject.isClosed) {
      _errorSubject.add(PlayerException(message: message, type: type, code: classification.code));
    }
  }

  @override
  void setAudioOutputSuppressed(bool suppressed) => _audioOutputSuppressed = suppressed;

  @override
  void setPrivateInput(bool value, {String? sourceIdentity}) => _privateInput = value;

  @override
  void beginSourceTransition() {
    if (_disposed) return;
    _acceptSourceEvents = false;
    _playingSubject.add(false);
    _loadingSubject.add(true);
    _completeSubject.add(false);
    _widthSubject.add(null);
    _heightSubject.add(null);
    _sizeNotifier.value = null;
  }

  @override
  Future<void> setDataSource(
    String url,
    List<String> playUrls,
    Map<String, String> headers, {
    LiveRoom? room,
    bool audioOnly = false,
  }) async {
    final player = _player;
    if (player == null || _disposed) throw StateError('fvp player is not initialized');
    final generation = ++_generation;
    beginSourceTransition();
    _audioOnly = audioOnly;
    player.state = mdk.PlaybackState.stopped;
    player.videoDecoders = videoDecodersFor(url, hardware: _hardwareDecoding);
    player.setProperty('avio.headers', encodeHeaders(headers));
    // FFmpeg's http/tls option; an empty value (local relay, no proxy) is
    // ignored because FFmpeg only uses an http:// proxy URL.
    player.setProperty('avio.http_proxy', PlaybackProxyPolicy.currentNativeUrl(privateInput: _privateInput));
    player.setActiveTracks(mdk.MediaType.video, audioOnly ? const [] : const [0]);
    player.volume = _audioOutputSuppressed ? 0.0 : _volume;
    player.media = url;
    _currentUrl = url;
    _acceptSourceEvents = true;
    _stateSubject.add(PlayerState.preparing);
    final result = await player.prepare();
    if (generation != _generation || _disposed) return;
    if (result < 0) {
      final exception = PlayerException(
        message: 'fvp prepare failed ($result)',
        type: PlayerErrorType.source,
        code: 'fvp_prepare_$result',
      );
      _fail(exception.message, PlayerErrorType.source);
      throw exception;
    }
    player.state = mdk.PlaybackState.playing;
    _stateSubject.add(PlayerState.ready);
    if (!audioOnly) unawaited(_attachTexture(player, generation));
  }

  Future<void> _attachTexture(mdk.Player player, int generation, {bool retried = false}) async {
    final size = await player.textureSize;
    if (generation != _generation || _disposed) return;
    if (size == null) {
      // fvp settles the video size as null when a live stream stalls or reports
      // invalid while still loading, and never revisits it, so no texture is
      // created and decoded frames are dropped (audio only). Re-prepare once.
      final url = _currentUrl;
      if (retried || url == null || _audioOnly) return;
      player.state = mdk.PlaybackState.stopped;
      player.media = url;
      final result = await player.prepare();
      if (generation != _generation || _disposed || result < 0) return;
      player.state = mdk.PlaybackState.playing;
      return _attachTexture(player, generation, retried: true);
    }
    _widthSubject.add(size.width.toInt());
    _heightSubject.add(size.height.toInt());
    _sizeNotifier.value = size;
    await player.updateTexture();
  }

  @override
  Widget getVideoWidget({BoxFit? fit}) {
    if (fit != null) _fit = fit;
    final player = _player;
    if (player == null || _audioOnly) return const SizedBox.shrink();
    return ValueListenableBuilder<int?>(
      valueListenable: player.textureId,
      builder: (context, textureId, _) {
        final size = _sizeNotifier.value;
        if (textureId == null || size == null || size.isEmpty) return const SizedBox.expand();
        return ClipRect(
          child: SizedBox.expand(
            child: FittedBox(
              fit: _fit,
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: Texture(textureId: textureId),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void setVideoFit(BoxFit fit) => _fit = fit;

  @override
  Future<void> play() async {
    if (_disposed) return;
    _player?.state = mdk.PlaybackState.playing;
  }

  @override
  Future<void> pause() async {
    if (_disposed) return;
    _player?.state = mdk.PlaybackState.paused;
  }

  @override
  Future<void> stop() async {
    if (_disposed) return;
    _acceptSourceEvents = false;
    _player?.state = mdk.PlaybackState.stopped;
    _playingSubject.add(false);
    _stateSubject.add(PlayerState.stopped);
  }

  @override
  Future<void> softStop() async {
    if (_disposed) return;
    _player?.volume = 0.0;
    await stop();
  }

  @override
  Future<void> setAudioOnly(bool audioOnly) async {
    if (_disposed || _audioOnly == audioOnly) return;
    _audioOnly = audioOnly;
    final player = _player;
    if (player == null) return;
    player.setActiveTracks(mdk.MediaType.video, audioOnly ? const [] : const [0]);
    if (audioOnly) {
      await player.updateTexture(width: -1);
    } else {
      unawaited(_attachTexture(player, _generation));
    }
  }

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    if (_disposed) return;
    _player?.volume = _volume;
  }

  @override
  Future<void> hardDispose() async {
    if (_disposed) return;
    _disposed = true;
    _initialized = false;
    _acceptSourceEvents = false;
    _generation++;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    final player = _player;
    _player = null;
    if (player != null) {
      player.volume = 0.0;
      player.dispose();
    }
    _stateSubject.add(PlayerState.disposed);
    _sizeNotifier.dispose();
    await Future.wait([
      _stateSubject.close(),
      _playingSubject.close(),
      _loadingSubject.close(),
      _errorSubject.close(),
      _completeSubject.close(),
      _widthSubject.close(),
      _heightSubject.close(),
    ]);
  }

  @override
  bool get isInitialized => _initialized;
  @override
  bool get isPlayingNow => _playingSubject.value;
  @override
  bool get isReusable => true;
  @override
  Stream<PlayerState> get onStateChanged => _stateSubject.stream;
  @override
  Stream<bool> get onPlaying => _playingSubject.stream;
  @override
  Stream<PlayerException> get onError => _errorSubject.stream;
  @override
  Stream<bool> get onLoading => _loadingSubject.stream;
  @override
  Stream<bool> get onComplete => _completeSubject.stream;
  @override
  Stream<int?> get width => _widthSubject.stream;
  @override
  Stream<int?> get height => _heightSubject.stream;
}
