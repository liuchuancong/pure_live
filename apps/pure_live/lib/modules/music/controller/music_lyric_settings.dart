import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/music/controller/music_settings_store.dart';

/// Where a lyric line sits inside the player's lyric panel — lx-music's
/// 播放详情 alignment.
enum MusicLyricAlignment {
  /// Flush left.
  left,

  /// Centred.
  center,

  /// Flush right.
  right;

  /// The choice's words.
  String label(Translations t) => switch (this) {
    MusicLyricAlignment.left => t.music.desktopLyricAlignLeft,
    MusicLyricAlignment.center => t.music.desktopLyricAlignCenter,
    MusicLyricAlignment.right => t.music.desktopLyricAlignRight,
  };
}

/// The lyric-panel half of the music module's preferences: what plays beside
/// a line, how the panel is laid out and how far the viewer may drive it.
/// The desktop overlay's own look lives in the desktop-lyric group.
@immutable
final class MusicLyricsSettings {
  /// Creates the lyric-panel preferences.
  const MusicLyricsSettings({
    required this.showTranslation,
    required this.showRomanization,
    required this.swapLyricSecondary,
    required this.traditionalizeLyric,
    required this.playWordLyrics,
    required this.lyricFontScale,
    required this.lyricAlignment,
    required this.lyricZoomActive,
    required this.lyricProgress,
    required this.lyricDragSeek,
    required this.lyricOffsetMs,
  });

  /// The reference's defaults: both secondary tracks shown, plain line-synced
  /// lyrics, a 140% panel scale and no viewer delay.
  static const MusicLyricsSettings standard = MusicLyricsSettings(
    showTranslation: true,
    showRomanization: true,
    swapLyricSecondary: false,
    traditionalizeLyric: false,
    playWordLyrics: true,
    lyricFontScale: 140,
    lyricAlignment: MusicLyricAlignment.center,
    lyricZoomActive: false,
    lyricProgress: false,
    lyricDragSeek: false,
    lyricOffsetMs: 0,
  );

  /// Whether a lyric's translation is shown beside the line.
  final bool showTranslation;

  /// Whether a lyric's romanization is shown beside the line.
  final bool showRomanization;

  /// Whether the translation and the romanization swap places under a line.
  final bool swapLyricSecondary;

  /// Whether lyric text is rewritten into traditional Chinese — the
  /// reference's `player.isS2t`.
  final bool traditionalizeLyric;

  /// Whether word-timed lyrics play word by word; off falls back to plain
  /// line-synced lyrics — the reference's `player.isPlayLxlrc` (lx-music
  /// disables it on macOS for its CPU cost).
  final bool playWordLyrics;

  /// The lyric panel's text scale in percent, 100–200.
  final int lyricFontScale;

  /// Where a lyric line sits in the panel.
  final MusicLyricAlignment lyricAlignment;

  /// Whether the line being sung is drawn larger than the rest.
  final bool lyricZoomActive;

  /// Whether the panel shows the song's playback progress.
  final bool lyricProgress;

  /// Whether the viewer can scrub by dragging the lyric panel — the
  /// reference's 允许通过拖拽歌词调整播放进度.
  final bool lyricDragSeek;

  /// The viewer's lyric delay in milliseconds; positive delays the highlight.
  final int lyricOffsetMs;

  /// A copy with selected fields replaced.
  MusicLyricsSettings copyWith({
    bool? showTranslation,
    bool? showRomanization,
    bool? swapLyricSecondary,
    bool? traditionalizeLyric,
    bool? playWordLyrics,
    int? lyricFontScale,
    MusicLyricAlignment? lyricAlignment,
    bool? lyricZoomActive,
    bool? lyricProgress,
    bool? lyricDragSeek,
    int? lyricOffsetMs,
  }) => MusicLyricsSettings(
    showTranslation: showTranslation ?? this.showTranslation,
    showRomanization: showRomanization ?? this.showRomanization,
    swapLyricSecondary: swapLyricSecondary ?? this.swapLyricSecondary,
    traditionalizeLyric: traditionalizeLyric ?? this.traditionalizeLyric,
    playWordLyrics: playWordLyrics ?? this.playWordLyrics,
    lyricFontScale: lyricFontScale ?? this.lyricFontScale,
    lyricAlignment: lyricAlignment ?? this.lyricAlignment,
    lyricZoomActive: lyricZoomActive ?? this.lyricZoomActive,
    lyricProgress: lyricProgress ?? this.lyricProgress,
    lyricDragSeek: lyricDragSeek ?? this.lyricDragSeek,
    lyricOffsetMs: lyricOffsetMs ?? this.lyricOffsetMs,
  );
}

const String _showTranslationKey = 'music.lyric.showTranslation';
const String _showRomanizationKey = 'music.lyric.showRomanization';
const String _swapLyricSecondaryKey = 'music.lyric.swapSecondary';
const String _traditionalizeKey = 'music.lyric.traditionalize';
const String _playWordLyricsKey = 'music.lyric.playWordTimed';
const String _lyricFontScaleKey = 'music.lyric.fontScale';
const String _lyricAlignmentKey = 'music.lyric.alignment';
const String _lyricZoomActiveKey = 'music.lyric.zoomActive';
const String _lyricProgressKey = 'music.lyric.progress';
const String _lyricDragSeekKey = 'music.lyric.dragSeek';
const String _lyricOffsetKey = 'music.lyric.offsetMs';

/// Owns the music module's lyric-panel preferences.
final class MusicLyricsSettingsController extends Notifier<MusicLyricsSettings> {
  @override
  MusicLyricsSettings build() => MusicLyricsSettings(
    showTranslation: readMusicPrefBool(_showTranslationKey) ?? true,
    showRomanization: readMusicPrefBool(_showRomanizationKey) ?? true,
    swapLyricSecondary: readMusicPrefBool(_swapLyricSecondaryKey) ?? false,
    traditionalizeLyric: readMusicPrefBool(_traditionalizeKey) ?? false,
    playWordLyrics: readMusicPrefBool(_playWordLyricsKey) ?? true,
    lyricFontScale: (readMusicPrefInt(_lyricFontScaleKey) ?? 140).clamp(100, 200),
    lyricAlignment: _readLyricAlignment(),
    lyricZoomActive: readMusicPrefBool(_lyricZoomActiveKey) ?? false,
    lyricProgress: readMusicPrefBool(_lyricProgressKey) ?? false,
    lyricDragSeek: readMusicPrefBool(_lyricDragSeekKey) ?? false,
    lyricOffsetMs: readMusicPrefInt(_lyricOffsetKey) ?? 0,
  );

  static MusicLyricAlignment _readLyricAlignment() {
    final name = readMusicPref(_lyricAlignmentKey);
    for (final alignment in MusicLyricAlignment.values) {
      if (alignment.name == name) return alignment;
    }
    return MusicLyricAlignment.center;
  }

  /// Shows a lyric's translation.
  Future<void> setShowTranslation({required bool value}) async {
    state = state.copyWith(showTranslation: value);
    await writeMusicPrefBool(_showTranslationKey, value: value);
  }

  /// Shows a lyric's romanization.
  Future<void> setShowRomanization({required bool value}) async {
    state = state.copyWith(showRomanization: value);
    await writeMusicPrefBool(_showRomanizationKey, value: value);
  }

  /// Swaps the translation and the romanization under a lyric line.
  Future<void> setSwapLyricSecondary({required bool value}) async {
    state = state.copyWith(swapLyricSecondary: value);
    await writeMusicPrefBool(_swapLyricSecondaryKey, value: value);
  }

  /// Switches traditional-Chinese lyric rendering.
  Future<void> setTraditionalizeLyric({required bool value}) async {
    state = state.copyWith(traditionalizeLyric: value);
    await writeMusicPrefBool(_traditionalizeKey, value: value);
  }

  /// Switches word-by-word lyric playback.
  Future<void> setPlayWordLyrics({required bool value}) async {
    state = state.copyWith(playWordLyrics: value);
    await writeMusicPrefBool(_playWordLyricsKey, value: value);
  }

  /// Sets the lyric panel's text scale, 100–200 percent.
  Future<void> setLyricFontScale(int value) async {
    final clamped = value.clamp(100, 200);
    state = state.copyWith(lyricFontScale: clamped);
    await writeMusicPrefInt(_lyricFontScaleKey, clamped);
  }

  /// Sets where a lyric line sits in the panel.
  Future<void> setLyricAlignment(MusicLyricAlignment value) async {
    state = state.copyWith(lyricAlignment: value);
    await writeMusicPref(_lyricAlignmentKey, value.name);
  }

  /// Draws the line being sung larger than the rest.
  Future<void> setLyricZoomActive({required bool value}) async {
    state = state.copyWith(lyricZoomActive: value);
    await writeMusicPrefBool(_lyricZoomActiveKey, value: value);
  }

  /// Shows the song's playback progress above the lyric panel.
  Future<void> setLyricProgress({required bool value}) async {
    state = state.copyWith(lyricProgress: value);
    await writeMusicPrefBool(_lyricProgressKey, value: value);
  }

  /// Lets the viewer scrub by dragging the lyric panel — the reference's
  /// 允许通过拖拽歌词调整播放进度.
  Future<void> setLyricDragSeek({required bool value}) async {
    state = state.copyWith(lyricDragSeek: value);
    await writeMusicPrefBool(_lyricDragSeekKey, value: value);
  }

  /// Sets the viewer's lyric delay.
  Future<void> setLyricOffsetMs(int value) async {
    final clamped = value.clamp(-60000, 60000);
    state = state.copyWith(lyricOffsetMs: clamped);
    await writeMusicPrefInt(_lyricOffsetKey, clamped);
  }
}

/// The music module's lyric-panel preferences.
final musicLyricsSettingsProvider = NotifierProvider<MusicLyricsSettingsController, MusicLyricsSettings>(
  MusicLyricsSettingsController.new,
);
