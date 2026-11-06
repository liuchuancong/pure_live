import 'dart:async' show Timer, unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_cache/live_cache.dart' show ImageCacheCategories;
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/shared/shared.dart';

/// The cover-cache refresh: whether it runs, and how often.
typedef ThumbnailRefresh = ({bool enabled, int minutes});

/// The reference's fresh-install default: off, every 30 minutes when on.
const ThumbnailRefresh _thumbnailDefaults = (enabled: false, minutes: 30);

const int kThumbnailRefreshMin = 5;
const int kThumbnailRefreshMax = 360;

/// The reference's thumbnail interval choices (five minutes … six hours).
const List<int> kThumbnailRefreshIntervalChoices = [5, 10, 15, 30, 60, 120, 240, 360];

/// Periodically invalidates the live-room cover cache, so the next draw of a
/// cover asks the site again.
///
/// Only covers are touched: avatars, emotes, icons and wallpapers keep their
/// long TTLs, which is the point of the per-category cache. The timer is
/// process-wide and belongs to the primary window. Turning the choice off or
/// changing the interval reschedules it immediately.
final class ThumbnailRefreshController extends Notifier<ThumbnailRefresh> {
  Timer? _timer;
  bool _started = false;

  @override
  ThumbnailRefresh build() {
    ref.onDispose(_cancel);
    try {
      return (
        enabled: StoragePrefs.getBool('refresh.thumbnails.auto') ?? _thumbnailDefaults.enabled,
        minutes: _normalize(StoragePrefs.getInt('refresh.thumbnails.minutes')),
      );
    } on Object {
      return _thumbnailDefaults;
    }
  }

  static int _normalize(int? minutes) {
    if (minutes == null) return _thumbnailDefaults.minutes;
    return minutes.clamp(kThumbnailRefreshMin, kThumbnailRefreshMax);
  }

  /// Arms the timer from the current choice. Safe to call again after a
  /// backup restore re-creates this provider.
  void start() {
    _started = true;
    _schedule();
  }

  /// Flips the periodic cover cache refresh.
  Future<void> setEnabled({required bool value}) async {
    state = (enabled: value, minutes: state.minutes);
    _schedule();
    await _write(state);
  }

  /// Moves the cover cache interval.
  Future<void> setMinutes(int minutes) async {
    state = (enabled: state.enabled, minutes: _normalize(minutes));
    _schedule();
    await _write(state);
  }

  Future<void> _write(ThumbnailRefresh next) async {
    try {
      await StoragePrefs.setBool('refresh.thumbnails.auto', next.enabled);
      await StoragePrefs.setInt('refresh.thumbnails.minutes', next.minutes);
    } on Object {
      // The choice is a preference; a closed store loses it.
    }
  }

  void _schedule() {
    if (!_started) return;
    _cancel();
    if (!state.enabled) return;
    _timer = Timer.periodic(Duration(minutes: state.minutes), (_) => unawaited(_refresh()));
  }

  void _cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// Invalidates the room covers now (the settings pane's manual refresh).
  Future<void> refreshNow() => _refresh();

  Future<void> _refresh() async {
    try {
      final manager = installedLiveCacheManager;
      if (manager == null) {
        return;
      }
      await manager.image.invalidateByCategory(ImageCacheCategories.liveRoomCover);
    } on Object {
      // A cache that cannot be invalidated this round is retried next tick.
    }
  }
}

/// The cover cache refresh choice.
final thumbnailRefreshProvider = NotifierProvider<ThumbnailRefreshController, ThumbnailRefresh>(
  ThumbnailRefreshController.new,
);
