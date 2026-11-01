import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/music/controller/music_settings_store.dart';

/// The container a download is written in; [original] keeps whatever the
/// source already served (lx-music's 原格式).
enum MusicDownloadType {
  /// Keep the source container untouched; a segmented source falls back to
  /// the format its quality hints at.
  original,

  /// MP3.
  mp3,

  /// AAC in MP4/M4A.
  m4a,

  /// FLAC.
  flac,

  /// Vorbis in Ogg.
  ogg,

  /// Uncompressed PCM.
  wav;

  /// The engine's format, or null to keep the source's own.
  audio.MusicDownloadFormat? get format => switch (this) {
    MusicDownloadType.original => null,
    MusicDownloadType.mp3 => audio.MusicDownloadFormat.mp3,
    MusicDownloadType.m4a => audio.MusicDownloadFormat.m4a,
    MusicDownloadType.flac => audio.MusicDownloadFormat.flac,
    MusicDownloadType.ogg => audio.MusicDownloadFormat.ogg,
    MusicDownloadType.wav => audio.MusicDownloadFormat.wav,
  };

  /// The choice's words.
  String label(Translations t) => switch (this) {
    MusicDownloadType.original => t.music.downloadTypeOriginal,
    MusicDownloadType.mp3 => t.music.downloadTypeMp3,
    MusicDownloadType.m4a => t.music.downloadTypeM4a,
    MusicDownloadType.flac => t.music.downloadTypeFlac,
    MusicDownloadType.ogg => t.music.downloadTypeOgg,
    MusicDownloadType.wav => t.music.downloadTypeWav,
  };
}

/// The download half of the music module's preferences: where a finished
/// file goes, what is written into it, and how many may run at once.
@immutable
final class MusicDownloadSettings {
  /// Creates the download preferences.
  const MusicDownloadSettings({
    required this.downloadType,
    required this.downloadPattern,
    required this.downloadEmbedCover,
    required this.downloadEmbedLyric,
    required this.downloadIncludeTranslation,
    required this.downloadIncludeRomanization,
    required this.downloadWriteLyric,
    required this.downloadSkipExisting,
    required this.downloadUseOtherSource,
    required this.downloadGroupByList,
    required this.downloadMaxConcurrent,
  });

  /// The reference's defaults: downloads keep the source container and write
  /// a sidecar lyric.
  static const MusicDownloadSettings standard = MusicDownloadSettings(
    downloadType: MusicDownloadType.original,
    downloadPattern: '{artist} - {title}',
    downloadEmbedCover: false,
    downloadEmbedLyric: false,
    downloadIncludeTranslation: false,
    downloadIncludeRomanization: false,
    downloadWriteLyric: true,
    downloadSkipExisting: true,
    downloadUseOtherSource: false,
    downloadGroupByList: false,
    downloadMaxConcurrent: 1,
  );

  /// The container a download is written in.
  final MusicDownloadType downloadType;

  /// The file-name pattern a download uses.
  final String downloadPattern;

  /// Whether a download embeds the cover.
  final bool downloadEmbedCover;

  /// Whether a download embeds the lyric into the tags.
  final bool downloadEmbedLyric;

  /// Whether a download's lyric also carries the translation.
  final bool downloadIncludeTranslation;

  /// Whether a download's lyric also carries the romanization.
  final bool downloadIncludeRomanization;

  /// Whether a download writes a sidecar `.lrc`.
  final bool downloadWriteLyric;

  /// Whether a download skips a file that already exists.
  final bool downloadSkipExisting;

  /// Whether a download may leave the song's own platform when that platform
  /// refuses — the reference's `download.isUseOtherSource`. A remembered or
  /// manual swap still rides above this switch.
  final bool downloadUseOtherSource;

  /// Whether a download groups files by the list they came from.
  final bool downloadGroupByList;

  /// How many downloads may run at once, 1–5.
  final int downloadMaxConcurrent;

  /// A copy with selected fields replaced.
  MusicDownloadSettings copyWith({
    MusicDownloadType? downloadType,
    String? downloadPattern,
    bool? downloadEmbedCover,
    bool? downloadEmbedLyric,
    bool? downloadIncludeTranslation,
    bool? downloadIncludeRomanization,
    bool? downloadWriteLyric,
    bool? downloadSkipExisting,
    bool? downloadUseOtherSource,
    bool? downloadGroupByList,
    int? downloadMaxConcurrent,
  }) => MusicDownloadSettings(
    downloadType: downloadType ?? this.downloadType,
    downloadPattern: downloadPattern ?? this.downloadPattern,
    downloadEmbedCover: downloadEmbedCover ?? this.downloadEmbedCover,
    downloadEmbedLyric: downloadEmbedLyric ?? this.downloadEmbedLyric,
    downloadIncludeTranslation: downloadIncludeTranslation ?? this.downloadIncludeTranslation,
    downloadIncludeRomanization: downloadIncludeRomanization ?? this.downloadIncludeRomanization,
    downloadWriteLyric: downloadWriteLyric ?? this.downloadWriteLyric,
    downloadSkipExisting: downloadSkipExisting ?? this.downloadSkipExisting,
    downloadUseOtherSource: downloadUseOtherSource ?? this.downloadUseOtherSource,
    downloadGroupByList: downloadGroupByList ?? this.downloadGroupByList,
    downloadMaxConcurrent: downloadMaxConcurrent ?? this.downloadMaxConcurrent,
  );
}

const String _downloadTypeKey = 'music.download.type';
const String _downloadPatternKey = 'music.download.pattern';
const String _downloadEmbedCoverKey = 'music.download.embedCover';
const String _downloadEmbedLyricKey = 'music.download.embedLyric';
const String _downloadIncludeTranslationKey = 'music.download.includeTranslation';
const String _downloadIncludeRomanizationKey = 'music.download.includeRomanization';
const String _downloadWriteLyricKey = 'music.download.writeLyric';
const String _downloadSkipExistingKey = 'music.download.skipExisting';
const String _downloadUseOtherSourceKey = 'music.download.useOtherSource';
const String _downloadGroupByListKey = 'music.download.groupByList';
const String _downloadMaxConcurrentKey = 'music.download.maxConcurrent';

/// Owns the music module's download preferences.
final class MusicDownloadSettingsController extends Notifier<MusicDownloadSettings> {
  @override
  MusicDownloadSettings build() => MusicDownloadSettings(
    downloadType: _readDownloadType(),
    downloadPattern: readMusicPref(_downloadPatternKey) ?? MusicDownloadSettings.standard.downloadPattern,
    downloadEmbedCover: readMusicPrefBool(_downloadEmbedCoverKey) ?? false,
    downloadEmbedLyric: readMusicPrefBool(_downloadEmbedLyricKey) ?? false,
    downloadIncludeTranslation: readMusicPrefBool(_downloadIncludeTranslationKey) ?? false,
    downloadIncludeRomanization: readMusicPrefBool(_downloadIncludeRomanizationKey) ?? false,
    downloadWriteLyric: readMusicPrefBool(_downloadWriteLyricKey) ?? true,
    downloadSkipExisting: readMusicPrefBool(_downloadSkipExistingKey) ?? true,
    downloadUseOtherSource: readMusicPrefBool(_downloadUseOtherSourceKey) ?? false,
    downloadGroupByList: readMusicPrefBool(_downloadGroupByListKey) ?? false,
    downloadMaxConcurrent: (readMusicPrefInt(_downloadMaxConcurrentKey) ?? 1).clamp(1, 5),
  );

  static MusicDownloadType _readDownloadType() {
    final name = readMusicPref(_downloadTypeKey);
    for (final type in MusicDownloadType.values) {
      if (type.name == name) return type;
    }
    return MusicDownloadType.original;
  }

  /// Chooses the container a download is written in.
  Future<void> setDownloadType(MusicDownloadType type) async {
    state = state.copyWith(downloadType: type);
    await writeMusicPref(_downloadTypeKey, type.name);
  }

  /// Sets the download file-name pattern.
  Future<void> setDownloadPattern(String pattern) async {
    final trimmed = pattern.trim();
    final value = trimmed.isEmpty ? MusicDownloadSettings.standard.downloadPattern : trimmed;
    state = state.copyWith(downloadPattern: value);
    await writeMusicPref(_downloadPatternKey, value);
  }

  /// Embeds the cover into a download.
  Future<void> setDownloadEmbedCover({required bool value}) async {
    state = state.copyWith(downloadEmbedCover: value);
    await writeMusicPrefBool(_downloadEmbedCoverKey, value: value);
  }

  /// Embeds the lyric into a download's tags.
  Future<void> setDownloadEmbedLyric({required bool value}) async {
    state = state.copyWith(downloadEmbedLyric: value);
    await writeMusicPrefBool(_downloadEmbedLyricKey, value: value);
  }

  /// Includes the translation in a download's lyric.
  Future<void> setDownloadIncludeTranslation({required bool value}) async {
    state = state.copyWith(downloadIncludeTranslation: value);
    await writeMusicPrefBool(_downloadIncludeTranslationKey, value: value);
  }

  /// Includes the romanization in a download's lyric.
  Future<void> setDownloadIncludeRomanization({required bool value}) async {
    state = state.copyWith(downloadIncludeRomanization: value);
    await writeMusicPrefBool(_downloadIncludeRomanizationKey, value: value);
  }

  /// Writes a sidecar `.lrc` beside a download.
  Future<void> setDownloadWriteLyric({required bool value}) async {
    state = state.copyWith(downloadWriteLyric: value);
    await writeMusicPrefBool(_downloadWriteLyricKey, value: value);
  }

  /// Skips a file that already exists.
  Future<void> setDownloadSkipExisting({required bool value}) async {
    state = state.copyWith(downloadSkipExisting: value);
    await writeMusicPrefBool(_downloadSkipExistingKey, value: value);
  }

  /// Toggles cross-source downloading.
  Future<void> setDownloadUseOtherSource({required bool value}) async {
    state = state.copyWith(downloadUseOtherSource: value);
    await writeMusicPrefBool(_downloadUseOtherSourceKey, value: value);
  }

  /// Groups downloaded files by the list they came from.
  Future<void> setDownloadGroupByList({required bool value}) async {
    state = state.copyWith(downloadGroupByList: value);
    await writeMusicPrefBool(_downloadGroupByListKey, value: value);
  }

  /// How many downloads may run at once, 1–5.
  Future<void> setDownloadMaxConcurrent(int value) async {
    final clamped = value.clamp(1, 5);
    state = state.copyWith(downloadMaxConcurrent: clamped);
    await writeMusicPrefInt(_downloadMaxConcurrentKey, clamped);
  }
}

/// The music module's download preferences.
final musicDownloadSettingsProvider = NotifierProvider<MusicDownloadSettingsController, MusicDownloadSettings>(
  MusicDownloadSettingsController.new,
);
