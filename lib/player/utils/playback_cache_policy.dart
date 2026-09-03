import 'dart:async';

import 'package:media_kit/media_kit.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/common/log.dart';
import 'package:pure_live/common/services/settings/metered_network_service.dart';

class PlaybackCachePolicy {
  PlaybackCachePolicy({required this.isLocalPlayback, required this.currentPlayer});

  static const int lowMemoryBufferSize = 64 * 1024 * 1024;
  static const int defaultBufferSize = 1500 * 1024 * 1024;

  static const int lowMemoryBackBufferSize = 16 * 1024 * 1024;
  static const int defaultBackBufferSize = 256 * 1024 * 1024;

  static const int lowMemoryReadaheadSeconds = 10;
  static const int defaultReadaheadSeconds = 60;

  final bool Function() isLocalPlayback;
  final Player? Function() currentPlayer;

  StreamSubscription<bool>? _meteredSubscription;
  StreamSubscription<dynamic>? _lowMemorySubscription;

  bool _watching = false;
  bool _prefetchSuspended = false;

  Future<void> _pending = Future.value();

  bool get userEnabled => SettingsService.to.player.lowMemoryMode.v;

  bool get networkForced =>
      !userEnabled && !isLocalPlayback() && MeteredNetworkService.to.isMetered;

  bool get enabled => userEnabled || networkForced;

  int get bufferSize => enabled ? lowMemoryBufferSize : defaultBufferSize;

  int get readaheadSeconds => enabled ? lowMemoryReadaheadSeconds : defaultReadaheadSeconds;

  void startWatching() {
    if (_watching) {
      return;
    }

    _watching = true;

    _meteredSubscription = MeteredNetworkService.to.metered.listen((_) {
      unawaited(apply());
    });

    _lowMemorySubscription = SettingsService.to.player.lowMemoryMode.listen((_) {
      unawaited(apply());
    });

    unawaited(apply());
  }

  Future<void> apply() {
    _pending = _pending.then((_) => _apply());
    return _pending;
  }

  Future<void> _apply() async {
    final player = currentPlayer();

    if (player == null) {
      return;
    }

    if (player.platform is! NativePlayer) {
      return;
    }

    final native = player.platform as NativePlayer;

    try {
      await native.waitForPlayerInitialization;

      if (!identical(currentPlayer(), player)) {
        return;
      }

      final cacheSize = _prefetchSuspended ? 0 : bufferSize;

      final readahead = _prefetchSuspended ? 0 : readaheadSeconds;

      await native.setProperty('demuxer-max-bytes', cacheSize.toString());

      await native.setProperty('demuxer-max-back-bytes', cacheSize.toString());

      await native.setProperty('demuxer-readahead-secs', readahead.toString());

      Log.d(
        'PlaybackCachePolicy: '
        'lowMemory=$userEnabled, '
        'metered=${MeteredNetworkService.to.isMetered}, '
        'forced=$networkForced, '
        'suspended=$_prefetchSuspended, '
        'cache=$cacheSize, '
        'readahead=$readahead',
      );
    } catch (e, s) {
      Log.e('PlaybackCachePolicy: failed to apply cache policy', s);
    }
  }

  void setPrefetchSuspended(bool suspended) {
    if (_prefetchSuspended == suspended) {
      return;
    }

    _prefetchSuspended = suspended;

    unawaited(apply());
  }

  Future<void> stopWatching() async {
    if (!_watching) {
      return;
    }

    _watching = false;

    await _meteredSubscription?.cancel();
    _meteredSubscription = null;

    await _lowMemorySubscription?.cancel();
    _lowMemorySubscription = null;
  }

  Future<void> dispose() async {
    await stopWatching();
  }
}
