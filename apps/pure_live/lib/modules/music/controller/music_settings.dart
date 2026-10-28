import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/l10n/translations.dart';

/// The rendition a custom source is asked for — lx-music's own four steps,
/// which its scripts answer through the `musicUrl` request.
enum MusicQuality {
  /// 128 kbps mp3.
  standard,

  /// 320 kbps mp3.
  high,

  /// FLAC.
  lossless,

  /// 24-bit FLAC.
  hiRes;

  /// The script-side name lx-music uses in its `info.quality` field.
  String get scriptName => switch (this) {
    MusicQuality.standard => '128k',
    MusicQuality.high => '320k',
    MusicQuality.lossless => 'flac',
    MusicQuality.hiRes => 'flac24bit',
  };

  /// The choice's words.
  String label(Translations t) => switch (this) {
    MusicQuality.standard => t.music.qualityStandard,
    MusicQuality.high => t.music.qualityHigh,
    MusicQuality.lossless => t.music.qualityLossless,
    MusicQuality.hiRes => t.music.qualityHiRes,
  };
}

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

/// The music module's preferences, read where the module plays, lists and
/// downloads.
///
/// The reference's own rows, reduced to the ones this module can honour: the
/// source a song is asked from and the rendition it prefers, the playback
/// behaviours, the lyric display, and the download post-processing. The
/// desktop-only rows (tray, window size, hotkeys) belong to the app-wide
/// groups or to no page at all.
@immutable
final class MusicSettings {
  /// Creates the music preferences.
  const MusicSettings({
    required this.defaultSourceId,
    required this.quality,
    required this.skipOnError,
    required this.autoplay,
    required this.rememberProgress,
    required this.addToTop,
    required this.showSource,
    required this.showTranslation,
    required this.showRomanization,
    required this.lyricOffsetMs,
    required this.desktopLyrics,
    required this.desktopLyricLocked,
    required this.desktopLyricFontSize,
    required this.desktopLyricOpacity,
    required this.desktopLyricTextColor,
    required this.desktopLyricStrokeColor,
    required this.desktopLyricStrokeWidth,
    required this.desktopLyricAlignment,
    required this.downloadType,
    required this.downloadPattern,
    required this.downloadEmbedCover,
    required this.downloadEmbedLyric,
    required this.downloadWriteLyric,
    required this.downloadSkipExisting,
    required this.downloadGroupByList,
  });

  /// The reference's defaults: no source until one is imported, 128k, skip a
  /// source that fails, no autoplay, new songs at the top, sources shown;
  /// lyrics show both secondary tracks, downloads keep the source container
  /// and write a sidecar lyric.
  static const MusicSettings standard = MusicSettings(
    defaultSourceId: '',
    quality: MusicQuality.standard,
    skipOnError: true,
    autoplay: false,
    rememberProgress: true,
    addToTop: true,
    showSource: true,
    showTranslation: true,
    showRomanization: true,
    lyricOffsetMs: 0,
    desktopLyrics: false,
    desktopLyricLocked: false,
    desktopLyricFontSize: 40,
    desktopLyricOpacity: 1,
    desktopLyricTextColor: 0xFFFFFFFF,
    desktopLyricStrokeColor: 0xFF000000,
    desktopLyricStrokeWidth: 2,
    desktopLyricAlignment: audio.DesktopLyricAlignment.center,
    downloadType: MusicDownloadType.original,
    downloadPattern: '{artist} - {title}',
    downloadEmbedCover: false,
    downloadEmbedLyric: false,
    downloadWriteLyric: true,
    downloadSkipExisting: true,
    downloadGroupByList: false,
  );

  /// The custom source songs are asked from; empty until one is imported.
  /// One source is active at a time — the reference has no per-source
  /// switches.
  final String defaultSourceId;

  /// The rendition asked of a source.
  final MusicQuality quality;

  /// Whether a source that cannot answer is skipped rather than stopping
  /// the queue.
  final bool skipOnError;

  /// Whether opening the module resumes the last queue.
  final bool autoplay;

  /// Whether a song opened again resumes at its last position.
  final bool rememberProgress;

  /// Whether a song added to a list goes to its top rather than its end.
  final bool addToTop;

  /// Whether a list row names the source the song came from.
  final bool showSource;

  /// Whether a lyric's translation is shown beside the line.
  final bool showTranslation;

  /// Whether a lyric's romanization is shown beside the line.
  final bool showRomanization;

  /// The viewer's lyric delay in milliseconds; positive delays the highlight.
  final int lyricOffsetMs;

  /// Whether the desktop lyric overlay was left on.
  final bool desktopLyrics;

  /// Whether the overlay ignores pointer input.
  final bool desktopLyricLocked;

  /// The overlay's font size in logical pixels.
  final double desktopLyricFontSize;

  /// The overlay's opacity, 0.0–1.0.
  final double desktopLyricOpacity;

  /// The overlay's text colour as 0xAARRGGBB.
  final int desktopLyricTextColor;

  /// The overlay's outline colour as 0xAARRGGBB.
  final int desktopLyricStrokeColor;

  /// The overlay's outline width in logical pixels; 0 turns it off.
  final double desktopLyricStrokeWidth;

  /// The overlay's horizontal anchoring.
  final audio.DesktopLyricAlignment desktopLyricAlignment;

  /// The container a download is written in.
  final MusicDownloadType downloadType;

  /// The file-name pattern a download uses.
  final String downloadPattern;

  /// Whether a download embeds the cover.
  final bool downloadEmbedCover;

  /// Whether a download embeds the lyric into the tags.
  final bool downloadEmbedLyric;

  /// Whether a download writes a sidecar `.lrc`.
  final bool downloadWriteLyric;

  /// Whether a download skips a file that already exists.
  final bool downloadSkipExisting;

  /// Whether a download groups files by the list they came from.
  final bool downloadGroupByList;

  /// A copy with selected fields replaced.
  MusicSettings copyWith({
    String? defaultSourceId,
    MusicQuality? quality,
    bool? skipOnError,
    bool? autoplay,
    bool? rememberProgress,
    bool? addToTop,
    bool? showSource,
    bool? showTranslation,
    bool? showRomanization,
    int? lyricOffsetMs,
    bool? desktopLyrics,
    bool? desktopLyricLocked,
    double? desktopLyricFontSize,
    double? desktopLyricOpacity,
    int? desktopLyricTextColor,
    int? desktopLyricStrokeColor,
    double? desktopLyricStrokeWidth,
    audio.DesktopLyricAlignment? desktopLyricAlignment,
    MusicDownloadType? downloadType,
    String? downloadPattern,
    bool? downloadEmbedCover,
    bool? downloadEmbedLyric,
    bool? downloadWriteLyric,
    bool? downloadSkipExisting,
    bool? downloadGroupByList,
  }) => MusicSettings(
    defaultSourceId: defaultSourceId ?? this.defaultSourceId,
    quality: quality ?? this.quality,
    skipOnError: skipOnError ?? this.skipOnError,
    autoplay: autoplay ?? this.autoplay,
    rememberProgress: rememberProgress ?? this.rememberProgress,
    addToTop: addToTop ?? this.addToTop,
    showSource: showSource ?? this.showSource,
    showTranslation: showTranslation ?? this.showTranslation,
    showRomanization: showRomanization ?? this.showRomanization,
    lyricOffsetMs: lyricOffsetMs ?? this.lyricOffsetMs,
    desktopLyrics: desktopLyrics ?? this.desktopLyrics,
    desktopLyricLocked: desktopLyricLocked ?? this.desktopLyricLocked,
    desktopLyricFontSize: desktopLyricFontSize ?? this.desktopLyricFontSize,
    desktopLyricOpacity: desktopLyricOpacity ?? this.desktopLyricOpacity,
    desktopLyricTextColor: desktopLyricTextColor ?? this.desktopLyricTextColor,
    desktopLyricStrokeColor: desktopLyricStrokeColor ?? this.desktopLyricStrokeColor,
    desktopLyricStrokeWidth: desktopLyricStrokeWidth ?? this.desktopLyricStrokeWidth,
    desktopLyricAlignment: desktopLyricAlignment ?? this.desktopLyricAlignment,
    downloadType: downloadType ?? this.downloadType,
    downloadPattern: downloadPattern ?? this.downloadPattern,
    downloadEmbedCover: downloadEmbedCover ?? this.downloadEmbedCover,
    downloadEmbedLyric: downloadEmbedLyric ?? this.downloadEmbedLyric,
    downloadWriteLyric: downloadWriteLyric ?? this.downloadWriteLyric,
    downloadSkipExisting: downloadSkipExisting ?? this.downloadSkipExisting,
    downloadGroupByList: downloadGroupByList ?? this.downloadGroupByList,
  );
}

const String _sourceKey = 'music.source.default';
const String _qualityKey = 'music.play.quality';
const String _skipOnErrorKey = 'music.play.skipOnError';
const String _autoplayKey = 'music.play.autoplay';
const String _rememberProgressKey = 'music.play.rememberProgress';
const String _addToTopKey = 'music.list.addToTop';
const String _showSourceKey = 'music.list.showSource';
const String _showTranslationKey = 'music.lyric.showTranslation';
const String _showRomanizationKey = 'music.lyric.showRomanization';
const String _lyricOffsetKey = 'music.lyric.offsetMs';
const String _desktopLyricsKey = 'music.lyric.desktop.enabled';
const String _desktopLyricLockedKey = 'music.lyric.desktop.locked';
const String _desktopLyricFontSizeKey = 'music.lyric.desktop.fontSize';
const String _desktopLyricOpacityKey = 'music.lyric.desktop.opacity';
const String _desktopLyricTextColorKey = 'music.lyric.desktop.textColor';
const String _desktopLyricStrokeColorKey = 'music.lyric.desktop.strokeColor';
const String _desktopLyricStrokeWidthKey = 'music.lyric.desktop.strokeWidth';
const String _desktopLyricAlignmentKey = 'music.lyric.desktop.alignment';
const String _downloadTypeKey = 'music.download.type';
const String _downloadPatternKey = 'music.download.pattern';
const String _downloadEmbedCoverKey = 'music.download.embedCover';
const String _downloadEmbedLyricKey = 'music.download.embedLyric';
const String _downloadWriteLyricKey = 'music.download.writeLyric';
const String _downloadSkipExistingKey = 'music.download.skipExisting';
const String _downloadGroupByListKey = 'music.download.groupByList';

/// Owns the music module's preferences.
final class MusicSettingsController extends Notifier<MusicSettings> {
  @override
  MusicSettings build() => MusicSettings(
    defaultSourceId: _readString(_sourceKey) ?? '',
    quality: _readQuality(),
    skipOnError: _readBool(_skipOnErrorKey) ?? true,
    autoplay: _readBool(_autoplayKey) ?? false,
    rememberProgress: _readBool(_rememberProgressKey) ?? true,
    addToTop: _readBool(_addToTopKey) ?? true,
    showSource: _readBool(_showSourceKey) ?? true,
    showTranslation: _readBool(_showTranslationKey) ?? true,
    showRomanization: _readBool(_showRomanizationKey) ?? true,
    lyricOffsetMs: _readInt(_lyricOffsetKey) ?? 0,
    desktopLyrics: _readBool(_desktopLyricsKey) ?? false,
    desktopLyricLocked: _readBool(_desktopLyricLockedKey) ?? false,
    desktopLyricFontSize: _readDouble(_desktopLyricFontSizeKey) ?? 40,
    desktopLyricOpacity: _readDouble(_desktopLyricOpacityKey) ?? 1,
    desktopLyricTextColor: _readInt(_desktopLyricTextColorKey) ?? 0xFFFFFFFF,
    desktopLyricStrokeColor: _readInt(_desktopLyricStrokeColorKey) ?? 0xFF000000,
    desktopLyricStrokeWidth: _readDouble(_desktopLyricStrokeWidthKey) ?? 2,
    desktopLyricAlignment: _readAlignment(),
    downloadType: _readDownloadType(),
    downloadPattern: _readString(_downloadPatternKey) ?? MusicSettings.standard.downloadPattern,
    downloadEmbedCover: _readBool(_downloadEmbedCoverKey) ?? false,
    downloadEmbedLyric: _readBool(_downloadEmbedLyricKey) ?? false,
    downloadWriteLyric: _readBool(_downloadWriteLyricKey) ?? true,
    downloadSkipExisting: _readBool(_downloadSkipExistingKey) ?? true,
    downloadGroupByList: _readBool(_downloadGroupByListKey) ?? false,
  );

  static MusicQuality _readQuality() {
    final name = _readString(_qualityKey);
    for (final quality in MusicQuality.values) {
      if (quality.name == name) return quality;
    }
    return MusicQuality.standard;
  }

  static MusicDownloadType _readDownloadType() {
    final name = _readString(_downloadTypeKey);
    for (final type in MusicDownloadType.values) {
      if (type.name == name) return type;
    }
    return MusicDownloadType.original;
  }

  static audio.DesktopLyricAlignment _readAlignment() {
    final name = _readString(_desktopLyricAlignmentKey);
    for (final alignment in audio.DesktopLyricAlignment.values) {
      if (alignment.name == name) return alignment;
    }
    return audio.DesktopLyricAlignment.center;
  }

  static String? _readString(String key) {
    try {
      return StoragePrefs.getString(key);
    } on Object {
      // A closed store keeps the default.
      return null;
    }
  }

  static bool? _readBool(String key) {
    try {
      return StoragePrefs.getBool(key);
    } on Object {
      return null;
    }
  }

  static int? _readInt(String key) {
    try {
      return StoragePrefs.getInt(key);
    } on Object {
      return null;
    }
  }

  static double? _readDouble(String key) {
    try {
      return StoragePrefs.getDouble(key);
    } on Object {
      return null;
    }
  }

  /// Chooses the source songs are asked from; empty means none.
  Future<void> setDefaultSource(String id) async {
    state = state.copyWith(defaultSourceId: id);
    await _writeString(_sourceKey, id);
  }

  /// Chooses the rendition asked of a source.
  Future<void> setQuality(MusicQuality quality) async {
    state = state.copyWith(quality: quality);
    await _writeString(_qualityKey, quality.name);
  }

  /// Skips or stops on a source that cannot answer.
  Future<void> setSkipOnError({required bool value}) async {
    state = state.copyWith(skipOnError: value);
    await _writeBool(_skipOnErrorKey, value);
  }

  /// Resumes the last queue when the module opens.
  Future<void> setAutoplay({required bool value}) async {
    state = state.copyWith(autoplay: value);
    await _writeBool(_autoplayKey, value);
  }

  /// Remembers where each song stopped.
  Future<void> setRememberProgress({required bool value}) async {
    state = state.copyWith(rememberProgress: value);
    await _writeBool(_rememberProgressKey, value);
  }

  /// Adds new songs to the top of a list.
  Future<void> setAddToTop({required bool value}) async {
    state = state.copyWith(addToTop: value);
    await _writeBool(_addToTopKey, value);
  }

  /// Shows the source beside a song in a list.
  Future<void> setShowSource({required bool value}) async {
    state = state.copyWith(showSource: value);
    await _writeBool(_showSourceKey, value);
  }

  /// Shows a lyric's translation.
  Future<void> setShowTranslation({required bool value}) async {
    state = state.copyWith(showTranslation: value);
    await _writeBool(_showTranslationKey, value);
  }

  /// Shows a lyric's romanization.
  Future<void> setShowRomanization({required bool value}) async {
    state = state.copyWith(showRomanization: value);
    await _writeBool(_showRomanizationKey, value);
  }

  /// Sets the viewer's lyric delay.
  Future<void> setLyricOffsetMs(int value) async {
    final clamped = value.clamp(-60000, 60000);
    state = state.copyWith(lyricOffsetMs: clamped);
    await _writeInt(_lyricOffsetKey, clamped);
  }

  /// Remembers whether the desktop lyric overlay is on.
  Future<void> setDesktopLyrics({required bool visible}) async {
    state = state.copyWith(desktopLyrics: visible);
    await _writeBool(_desktopLyricsKey, visible);
  }

  /// Locks or unlocks the desktop lyric overlay's click-through mode.
  Future<void> setDesktopLyricLocked({required bool locked}) async {
    state = state.copyWith(desktopLyricLocked: locked);
    await _writeBool(_desktopLyricLockedKey, locked);
  }

  /// Sets the overlay's font size, within the window's usable range.
  Future<void> setDesktopLyricFontSize(double value) async {
    final clamped = value.clamp(18.0, 72.0);
    state = state.copyWith(desktopLyricFontSize: clamped);
    await _writeDouble(_desktopLyricFontSizeKey, clamped);
  }

  /// Sets the overlay's opacity, within the range that stays readable.
  Future<void> setDesktopLyricOpacity(double value) async {
    final clamped = value.clamp(0.2, 1.0);
    state = state.copyWith(desktopLyricOpacity: clamped);
    await _writeDouble(_desktopLyricOpacityKey, clamped);
  }

  /// Sets the overlay's text colour as 0xAARRGGBB.
  Future<void> setDesktopLyricTextColor(int value) async {
    state = state.copyWith(desktopLyricTextColor: value);
    await _writeInt(_desktopLyricTextColorKey, value);
  }

  /// Sets the overlay's outline colour as 0xAARRGGBB.
  Future<void> setDesktopLyricStrokeColor(int value) async {
    state = state.copyWith(desktopLyricStrokeColor: value);
    await _writeInt(_desktopLyricStrokeColorKey, value);
  }

  /// Sets the overlay's outline width; 0 turns the outline off.
  Future<void> setDesktopLyricStrokeWidth(double value) async {
    final clamped = value.clamp(0.0, 6.0);
    state = state.copyWith(desktopLyricStrokeWidth: clamped);
    await _writeDouble(_desktopLyricStrokeWidthKey, clamped);
  }

  /// Sets the overlay's horizontal anchoring.
  Future<void> setDesktopLyricAlignment(audio.DesktopLyricAlignment value) async {
    state = state.copyWith(desktopLyricAlignment: value);
    await _writeString(_desktopLyricAlignmentKey, value.name);
  }

  /// Chooses the container a download is written in.
  Future<void> setDownloadType(MusicDownloadType type) async {
    state = state.copyWith(downloadType: type);
    await _writeString(_downloadTypeKey, type.name);
  }

  /// Sets the download file-name pattern.
  Future<void> setDownloadPattern(String pattern) async {
    final trimmed = pattern.trim();
    final value = trimmed.isEmpty ? MusicSettings.standard.downloadPattern : trimmed;
    state = state.copyWith(downloadPattern: value);
    await _writeString(_downloadPatternKey, value);
  }

  /// Embeds the cover into a download.
  Future<void> setDownloadEmbedCover({required bool value}) async {
    state = state.copyWith(downloadEmbedCover: value);
    await _writeBool(_downloadEmbedCoverKey, value);
  }

  /// Embeds the lyric into a download's tags.
  Future<void> setDownloadEmbedLyric({required bool value}) async {
    state = state.copyWith(downloadEmbedLyric: value);
    await _writeBool(_downloadEmbedLyricKey, value);
  }

  /// Writes a sidecar `.lrc` beside a download.
  Future<void> setDownloadWriteLyric({required bool value}) async {
    state = state.copyWith(downloadWriteLyric: value);
    await _writeBool(_downloadWriteLyricKey, value);
  }

  /// Skips a file that already exists.
  Future<void> setDownloadSkipExisting({required bool value}) async {
    state = state.copyWith(downloadSkipExisting: value);
    await _writeBool(_downloadSkipExistingKey, value);
  }

  /// Groups downloaded files by the list they came from.
  Future<void> setDownloadGroupByList({required bool value}) async {
    state = state.copyWith(downloadGroupByList: value);
    await _writeBool(_downloadGroupByListKey, value);
  }

  /// Back to the source, playback and list defaults this page owns.
  Future<void> reset() async {
    state = state.copyWith(
      defaultSourceId: '',
      quality: MusicQuality.standard,
      skipOnError: true,
      autoplay: false,
      rememberProgress: true,
      addToTop: true,
      showSource: true,
    );
    await setDefaultSource('');
    await setQuality(MusicQuality.standard);
    await setSkipOnError(value: true);
    await setAutoplay(value: false);
    await setRememberProgress(value: true);
    await setAddToTop(value: true);
    await setShowSource(value: true);
  }

  static Future<void> _writeString(String key, String value) async {
    try {
      await StoragePrefs.setString(key, value);
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  static Future<void> _writeBool(String key, bool value) async {
    try {
      await StoragePrefs.setBool(key, value);
    } on Object {
      // Same as above.
    }
  }

  static Future<void> _writeInt(String key, int value) async {
    try {
      await StoragePrefs.setInt(key, value);
    } on Object {
      // Same as above.
    }
  }

  static Future<void> _writeDouble(String key, double value) async {
    try {
      await StoragePrefs.setDouble(key, value);
    } on Object {
      // Same as above.
    }
  }
}

/// The music module's preferences.
final musicSettingsProvider = NotifierProvider<MusicSettingsController, MusicSettings>(MusicSettingsController.new);
