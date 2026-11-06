import 'package:flutter/foundation.dart' show immutable;
import 'package:live_cache/live_cache.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;

/// How eager the image cache is to fetch a fresh copy.
enum CacheFreshness {
  /// Halve every TTL: covers follow a new poster sooner, traffic grows.
  fresh(0.5),

  /// The specification's TTLs as written.
  balanced(1),

  /// Double every TTL: fewer requests, older pictures.
  thrifty(2);

  CacheFreshness(this.ttlScale);

  /// The multiplier applied to a policy's TTL.
  final double ttlScale;
}

/// The cache choices the settings surface owns.
///
/// The manager's runtime counters and the pane's transient state stay
/// separate; this value is the stored policy only.
@immutable
final class LiveCacheSettings {
  /// Creates a settings value.
  const LiveCacheSettings({
    this.diskCacheEnabled = true,
    this.maxMb = defaultMaxMb,
    this.freshness = CacheFreshness.balanced,
    this.autoClean = true,
  });

  /// Reads the stored choices, migrating the retired "no limit" (0/null),
  /// the old 100 MB step and any other out-of-list value to a real cap.
  factory LiveCacheSettings.read() {
    try {
      final storedMb = StoragePrefs.getInt('cache.maxMB');
      return LiveCacheSettings(
        diskCacheEnabled: StoragePrefs.getBool('cache.images.enabled') ?? true,
        maxMb: _normalizeMb(storedMb),
        freshness: _readFreshness(StoragePrefs.getString('cache.images.freshness')),
        autoClean: StoragePrefs.getBool('cache.images.autoClean') ?? true,
      );
    } on Object {
      return const LiveCacheSettings();
    }
  }

  /// The capacity a fresh install uses; the specification requires a cap.
  static const int defaultMaxMb = 1024;

  /// The capacities the settings surface offers.
  static const List<int> limitChoices = [200, 500, 1024, 2048, 4096];

  /// Whether bytes are written to disk.
  final bool diskCacheEnabled;

  /// The disk cap in megabytes.
  final int maxMb;

  /// The TTL multiplier.
  final CacheFreshness freshness;

  /// Whether startup/idle cleanup prunes the cache.
  final bool autoClean;

  /// The settings with the named fields replaced.
  LiveCacheSettings copyWith({bool? diskCacheEnabled, int? maxMb, CacheFreshness? freshness, bool? autoClean}) =>
      LiveCacheSettings(
        diskCacheEnabled: diskCacheEnabled ?? this.diskCacheEnabled,
        maxMb: maxMb ?? this.maxMb,
        freshness: freshness ?? this.freshness,
        autoClean: autoClean ?? this.autoClean,
      );

  /// The cache configuration this value describes.
  LiveCacheConfig toConfig() => LiveCacheConfig(
    image: ImageCacheConfig(
      diskCacheEnabled: diskCacheEnabled,
      autoClean: autoClean,
      maxDiskBytes: maxMb * 1024 * 1024,
      ttlScale: freshness.ttlScale,
    ),
  );

  /// Persists the choices; a closed store loses a preference, never the app.
  Future<void> write() async {
    try {
      await StoragePrefs.setBool('cache.images.enabled', diskCacheEnabled);
      await StoragePrefs.setInt('cache.maxMB', maxMb);
      await StoragePrefs.setString('cache.images.freshness', freshness.name);
      await StoragePrefs.setBool('cache.images.autoClean', autoClean);
    } on Object {
      // The next boot reads the store's last good value.
    }
  }

  static int _normalizeMb(int? value) {
    if (value == null || value <= 0) {
      return defaultMaxMb;
    }
    if (value == 100) {
      return 200;
    }
    var best = limitChoices.first;
    for (final choice in limitChoices) {
      if ((choice - value).abs() < (best - value).abs()) {
        best = choice;
      }
    }
    return best;
  }

  static CacheFreshness _readFreshness(String? name) {
    for (final value in CacheFreshness.values) {
      if (value.name == name) {
        return value;
      }
    }
    return CacheFreshness.balanced;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LiveCacheSettings &&
          other.diskCacheEnabled == diskCacheEnabled &&
          other.maxMb == maxMb &&
          other.freshness == freshness &&
          other.autoClean == autoClean;

  @override
  int get hashCode => Object.hash(diskCacheEnabled, maxMb, freshness, autoClean);
}

/// The category groups the settings pane prints; the raw category slugs stay
/// an internal detail.
enum CacheCategoryGroup {
  /// Covers of rooms, videos, categories and topics.
  cover,

  /// Streamer and viewer portraits.
  avatar,

  /// Platform and channel icons.
  icon,

  /// Chat emoticons, badges and gifts.
  emote,

  /// Album and playlist artwork.
  album,

  /// Wallpapers and the chosen background.
  wallpaper,

  /// Search thumbnails and transient previews.
  preview,

  /// Anything a caller did not classify.
  other,
}

/// The group [category] belongs to.
CacheCategoryGroup cacheCategoryGroup(String category) => switch (category) {
  ImageCacheCategories.liveRoomCover ||
  ImageCacheCategories.liveRoomDetail ||
  ImageCacheCategories.videoCover ||
  ImageCacheCategories.categoryCover ||
  ImageCacheCategories.topicCover => CacheCategoryGroup.cover,
  ImageCacheCategories.avatar || ImageCacheCategories.userAvatar => CacheCategoryGroup.avatar,
  ImageCacheCategories.platformIcon || ImageCacheCategories.channelLogo => CacheCategoryGroup.icon,
  ImageCacheCategories.chatEmote => CacheCategoryGroup.emote,
  ImageCacheCategories.albumCover => CacheCategoryGroup.album,
  ImageCacheCategories.wallpaper || ImageCacheCategories.customBackground => CacheCategoryGroup.wallpaper,
  ImageCacheCategories.preview || ImageCacheCategories.searchThumbnail => CacheCategoryGroup.preview,
  _ => CacheCategoryGroup.other,
};
