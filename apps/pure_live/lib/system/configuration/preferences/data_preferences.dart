import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show immutable;

/// The cache and thumbnail housekeeping: the cache ceiling and clearing policy, and how room thumbnails refresh — the reference's `data` section.
// ignore_for_file: unnecessary_type_name_in_constructor
@immutable
final class DataPreferences extends Equatable {
  /// The shipping defaults.
  const new({
    this.cacheMaxMB = 1024,
    this.cacheAutoClear = false,
    this.cacheKeepDays = 7,
    this.cacheKeepCount = 500,
    this.autoRefreshThumbnails = false,
    this.thumbnailRefreshMinutes = 30,
    this.thumbnailKeepOldFiles = false,
  });

  /// Reads the domain's keys from the flat document; unknown shapes decode
  /// to the defaults.
  factory DataPreferences.fromJson(Map<String, Object?> json) {
    return DataPreferences(
      cacheMaxMB: (json['cacheMaxMB'] as num?)?.toInt() ?? 1024,
      cacheAutoClear: json['cacheAutoClear'] as bool? ?? false,
      cacheKeepDays: (json['cacheKeepDays'] as num?)?.toInt() ?? 7,
      cacheKeepCount: (json['cacheKeepCount'] as num?)?.toInt() ?? 500,
      autoRefreshThumbnails: json['autoRefreshThumbnails'] as bool? ?? false,
      thumbnailRefreshMinutes: (json['thumbnailRefreshMinutes'] as num?)?.toInt() ?? 30,
      thumbnailKeepOldFiles: json['thumbnailKeepOldFiles'] as bool? ?? false,
    );
  }

  /// The picture cache's ceiling in MB (the reference's currentCacheSize
  /// display pairs with it); 0 or negative means no cap.
  final int cacheMaxMB;

  /// Whether the cache prunes itself when it crosses [cacheMaxMB] after a
  /// resume (the reference's automatic cache-clear answer).
  final bool cacheAutoClear;

  /// How many days a pruned cache may keep pictures for (1..90).
  final int cacheKeepDays;

  /// How many files a pruned cache may keep (100..2000).
  final int cacheKeepCount;

  /// Whether room covers re-pull on a timer (the reference's
  /// autoRefreshThumbnails); off, a cover is fetched once and kept.
  final bool autoRefreshThumbnails;

  /// Minutes between cover re-pulls (5..360, the reference's
  /// thumbnailRefreshInterval); the bucket lands in the cover URL, so every
  /// window reads as a new address once and only once.
  final int thumbnailRefreshMinutes;

  /// Whether a cover refresh keeps the superseded pictures instead of
  /// letting the cache drop them (the reference's thumbnailKeepOldFiles).
  final bool thumbnailKeepOldFiles;

  /// The domain's keys as stored, flat.
  Map<String, Object?> toJson() => {
    'cacheMaxMB': cacheMaxMB,
    'cacheAutoClear': cacheAutoClear,
    'cacheKeepDays': cacheKeepDays,
    'cacheKeepCount': cacheKeepCount,
    'autoRefreshThumbnails': autoRefreshThumbnails,
    'thumbnailRefreshMinutes': thumbnailRefreshMinutes,
    'thumbnailKeepOldFiles': thumbnailKeepOldFiles,
  };

  /// Returns a copy with the given fields replaced.
  DataPreferences copyWith({
    int? cacheMaxMB,
    bool? cacheAutoClear,
    int? cacheKeepDays,
    int? cacheKeepCount,
    bool? autoRefreshThumbnails,
    int? thumbnailRefreshMinutes,
    bool? thumbnailKeepOldFiles,
  }) => DataPreferences(
    cacheMaxMB: cacheMaxMB ?? this.cacheMaxMB,
    cacheAutoClear: cacheAutoClear ?? this.cacheAutoClear,
    cacheKeepDays: cacheKeepDays ?? this.cacheKeepDays,
    cacheKeepCount: cacheKeepCount ?? this.cacheKeepCount,
    autoRefreshThumbnails: autoRefreshThumbnails ?? this.autoRefreshThumbnails,
    thumbnailRefreshMinutes: thumbnailRefreshMinutes ?? this.thumbnailRefreshMinutes,
    thumbnailKeepOldFiles: thumbnailKeepOldFiles ?? this.thumbnailKeepOldFiles,
  );

  @override
  /// Every field, in declaration order.
  List<Object?> get props => [
    cacheMaxMB,
    cacheAutoClear,
    cacheKeepDays,
    cacheKeepCount,
    autoRefreshThumbnails,
    thumbnailRefreshMinutes,
    thumbnailKeepOldFiles,
  ];
}
