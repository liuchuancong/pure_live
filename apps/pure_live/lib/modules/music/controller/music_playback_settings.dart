import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/music/controller/music_settings_store.dart';

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

/// The step an lx script id names — [MusicQuality.scriptName]'s reverse.
///
/// Null for a tier the module's four steps do not cover (192K, 自动, a source's
/// own id), so callers say nothing rather than guess at a rendition they cannot
/// ask for.
MusicQuality? musicQualityByScriptName(String id) {
  for (final quality in MusicQuality.values) {
    if (quality.scriptName == id) return quality;
  }
  return null;
}

/// How a platform's name is worded in the module's lists — lx-music's
/// `common.sourceNameType`: the stage names by default, the real ones on
/// demand.
enum MusicSourceNameType {
  /// The reference's playful aliases (小蜗音乐…).
  alias,

  /// The platforms' own names.
  real;

  /// The choice's words.
  String label(Translations t) => switch (this) {
    MusicSourceNameType.alias => t.music.sourceNameTypeAlias,
    MusicSourceNameType.real => t.music.sourceNameTypeReal,
  };
}

/// The stage name a built-in platform is shown under — the reference's
/// `source_alias_*` words; null leaves the platform its real name.
String? musicSourceAliasName(Translations t, String id) => switch (id) {
  'kw' => t.music.sourceAliasKw,
  'kg' => t.music.sourceAliasKg,
  'tx' => t.music.sourceAliasTx,
  'wy' => t.music.sourceAliasWy,
  'mg' => t.music.sourceAliasMg,
  _ => null,
};

/// The words a source is listed under: the alias when [type] asks for one
/// and the platform has it, its real name otherwise.
String musicSourceDisplayName(Translations t, MusicSourceNameType type, String id, String name) =>
    type == MusicSourceNameType.alias ? musicSourceAliasName(t, id) ?? name : name;

/// The playback half of the music module's preferences: the source songs are
/// asked from and how the module's lists name things, the rendition and the
/// queue behaviours, and what a list row shows. The lyric, desktop-lyric and
/// download halves live in their own groups beside this one.
@immutable
final class MusicPlaybackSettings {
  /// Creates the playback preferences.
  const MusicPlaybackSettings({
    required this.defaultSourceId,
    required this.sourceNameType,
    required this.quality,
    required this.skipOnError,
    required this.autoplay,
    required this.rememberProgress,
    required this.volume,
    required this.playbackRate,
    required this.preservesPitch,
    required this.autoCleanPlayedList,
    required this.addToTop,
    required this.showSource,
    required this.showHotSearches,
    required this.audioCacheLimitMb,
  });

  /// The reference's defaults: no source until one is imported, 128k, skip a
  /// source that fails, the last song resumed and playing, new songs at the
  /// top, sources shown.
  static const MusicPlaybackSettings standard = MusicPlaybackSettings(
    defaultSourceId: '',
    sourceNameType: MusicSourceNameType.alias,
    quality: MusicQuality.standard,
    skipOnError: true,
    autoplay: true,
    rememberProgress: true,
    volume: 1,
    playbackRate: 1,
    preservesPitch: true,
    autoCleanPlayedList: false,
    addToTop: true,
    showSource: true,
    showHotSearches: true,
    audioCacheLimitMb: 512,
  );

  /// The custom source songs are asked from; empty until one is imported.
  /// One source is active at a time — the reference has no per-source
  /// switches.
  final String defaultSourceId;

  /// How a platform's name is worded in the module's lists.
  final MusicSourceNameType sourceNameType;

  /// The rendition asked of a source.
  final MusicQuality quality;

  /// Whether a source that cannot answer is skipped rather than stopping
  /// the queue.
  final bool skipOnError;

  /// Whether opening the module restores the last queue — the song it
  /// stopped on, its position (when [rememberProgress]) — and keeps playing.
  final bool autoplay;

  /// Whether a song opened again resumes at its last position.
  final bool rememberProgress;

  /// The playback volume, kept across runs — the reference's `player.volume`.
  final double volume;

  /// The playback speed, kept across runs — the reference's
  /// `player.playbackRate`.
  final double playbackRate;

  /// Whether a changed speed keeps the song's pitch — the reference's
  /// `player.preservesPitch`, mpv's `audio-pitch-correction`.
  final bool preservesPitch;

  /// Whether picking a song from the list already playing clears the played
  /// list, letting every song re-enter the random pool — the reference's
  /// `player.isAutoCleanPlayedList`.
  final bool autoCleanPlayedList;

  /// Whether a song added to a list goes to its top rather than its end.
  final bool addToTop;

  /// Whether a list row names the source the song came from.
  final bool showSource;

  /// Whether the empty search page offers the source's top searches.
  final bool showHotSearches;

  /// How many megabytes of songs the audio cache may keep — a song heard
  /// once plays from disk instead of its expiring CDN link. Zero turns the
  /// cache off.
  final int audioCacheLimitMb;

  /// A copy with selected fields replaced.
  MusicPlaybackSettings copyWith({
    String? defaultSourceId,
    MusicSourceNameType? sourceNameType,
    MusicQuality? quality,
    bool? skipOnError,
    bool? autoplay,
    bool? rememberProgress,
    double? volume,
    double? playbackRate,
    bool? preservesPitch,
    bool? autoCleanPlayedList,
    bool? addToTop,
    bool? showSource,
    bool? showHotSearches,
    int? audioCacheLimitMb,
  }) => MusicPlaybackSettings(
    defaultSourceId: defaultSourceId ?? this.defaultSourceId,
    sourceNameType: sourceNameType ?? this.sourceNameType,
    quality: quality ?? this.quality,
    skipOnError: skipOnError ?? this.skipOnError,
    autoplay: autoplay ?? this.autoplay,
    rememberProgress: rememberProgress ?? this.rememberProgress,
    volume: volume ?? this.volume,
    playbackRate: playbackRate ?? this.playbackRate,
    preservesPitch: preservesPitch ?? this.preservesPitch,
    autoCleanPlayedList: autoCleanPlayedList ?? this.autoCleanPlayedList,
    addToTop: addToTop ?? this.addToTop,
    showSource: showSource ?? this.showSource,
    showHotSearches: showHotSearches ?? this.showHotSearches,
    audioCacheLimitMb: audioCacheLimitMb ?? this.audioCacheLimitMb,
  );
}

const String _sourceKey = 'music.source.default';
const String _sourceNameTypeKey = 'music.source.nameType';
const String _qualityKey = 'music.play.quality';
const String _skipOnErrorKey = 'music.play.skipOnError';
const String _autoplayKey = 'music.play.autoplay';
const String _rememberProgressKey = 'music.play.rememberProgress';
const String _volumeKey = 'music.play.volume';
const String _rateKey = 'music.play.rate';
const String _preservesPitchKey = 'music.play.preservesPitch';
const String _autoCleanPlayedListKey = 'music.play.autoCleanPlayedList';
const String _addToTopKey = 'music.list.addToTop';
const String _showSourceKey = 'music.list.showSource';
const String _showHotSearchesKey = 'music.search.hot';
const String _audioCacheLimitKey = 'music.play.audioCacheLimitMb';

/// Owns the music module's playback preferences.
final class MusicPlaybackSettingsController extends Notifier<MusicPlaybackSettings> {
  @override
  MusicPlaybackSettings build() => MusicPlaybackSettings(
    defaultSourceId: readMusicPref(_sourceKey) ?? '',
    sourceNameType: _readSourceNameType(),
    quality: _readQuality(),
    skipOnError: readMusicPrefBool(_skipOnErrorKey) ?? true,
    autoplay: readMusicPrefBool(_autoplayKey) ?? true,
    rememberProgress: readMusicPrefBool(_rememberProgressKey) ?? true,
    volume: readMusicPrefDouble(_volumeKey) ?? 1,
    playbackRate: readMusicPrefDouble(_rateKey) ?? 1,
    preservesPitch: readMusicPrefBool(_preservesPitchKey) ?? true,
    autoCleanPlayedList: readMusicPrefBool(_autoCleanPlayedListKey) ?? false,
    addToTop: readMusicPrefBool(_addToTopKey) ?? true,
    showSource: readMusicPrefBool(_showSourceKey) ?? true,
    showHotSearches: readMusicPrefBool(_showHotSearchesKey) ?? true,
    audioCacheLimitMb: readMusicPrefInt(_audioCacheLimitKey) ?? 512,
  );

  static MusicSourceNameType _readSourceNameType() {
    final name = readMusicPref(_sourceNameTypeKey);
    for (final type in MusicSourceNameType.values) {
      if (type.name == name) return type;
    }
    return MusicSourceNameType.alias;
  }

  static MusicQuality _readQuality() {
    final name = readMusicPref(_qualityKey);
    for (final quality in MusicQuality.values) {
      if (quality.name == name) return quality;
    }
    return MusicQuality.standard;
  }

  /// Chooses the source songs are asked from; empty means none.
  Future<void> setDefaultSource(String id) async {
    state = state.copyWith(defaultSourceId: id);
    await writeMusicPref(_sourceKey, id);
  }

  /// Chooses how a platform's name is worded in the module's lists.
  Future<void> setSourceNameType(MusicSourceNameType type) async {
    state = state.copyWith(sourceNameType: type);
    await writeMusicPref(_sourceNameTypeKey, type.name);
  }

  /// Chooses the rendition asked of a source.
  Future<void> setQuality(MusicQuality quality) async {
    state = state.copyWith(quality: quality);
    await writeMusicPref(_qualityKey, quality.name);
  }

  /// Skips or stops on a source that cannot answer.
  Future<void> setSkipOnError({required bool value}) async {
    state = state.copyWith(skipOnError: value);
    await writeMusicPrefBool(_skipOnErrorKey, value: value);
  }

  /// Resumes the last queue when the module opens.
  Future<void> setAutoplay({required bool value}) async {
    state = state.copyWith(autoplay: value);
    await writeMusicPrefBool(_autoplayKey, value: value);
  }

  /// Remembers where each song stopped.
  Future<void> setRememberProgress({required bool value}) async {
    state = state.copyWith(rememberProgress: value);
    await writeMusicPrefBool(_rememberProgressKey, value: value);
  }

  /// Adds new songs to the top of a list.
  Future<void> setAddToTop({required bool value}) async {
    state = state.copyWith(addToTop: value);
    await writeMusicPrefBool(_addToTopKey, value: value);
  }

  /// Chooses the audio cache's size; zero turns it off.
  Future<void> setAudioCacheLimit(int megabytes) async {
    state = state.copyWith(audioCacheLimitMb: megabytes);
    await writeMusicPrefInt(_audioCacheLimitKey, megabytes);
  }

  /// Shows the source beside a song in a list.
  Future<void> setShowSource({required bool value}) async {
    state = state.copyWith(showSource: value);
    await writeMusicPrefBool(_showSourceKey, value: value);
  }

  /// Offers the source's top searches on the empty search page.
  Future<void> setShowHotSearches({required bool value}) async {
    state = state.copyWith(showHotSearches: value);
    await writeMusicPrefBool(_showHotSearchesKey, value: value);
  }

  /// Keeps the playback volume across runs.
  Future<void> setVolume(double value) async {
    state = state.copyWith(volume: value.clamp(0.0, 1.0));
    await writeMusicPrefDouble(_volumeKey, value);
  }

  /// Keeps the playback speed across runs.
  Future<void> setPlaybackRate(double value) async {
    state = state.copyWith(playbackRate: value);
    await writeMusicPrefDouble(_rateKey, value);
  }

  /// Switches pitch compensation for a changed playback speed.
  Future<void> setPreservesPitch({required bool value}) async {
    state = state.copyWith(preservesPitch: value);
    await writeMusicPrefBool(_preservesPitchKey, value: value);
  }

  /// Switches the played-list auto clean.
  Future<void> setAutoCleanPlayedList({required bool value}) async {
    state = state.copyWith(autoCleanPlayedList: value);
    await writeMusicPrefBool(_autoCleanPlayedListKey, value: value);
  }

  /// Back to the source, playback and list defaults this group owns.
  Future<void> reset() async {
    state = state.copyWith(
      defaultSourceId: '',
      quality: MusicQuality.standard,
      skipOnError: true,
      autoplay: true,
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
}

/// The music module's playback preferences.
final musicPlaybackSettingsProvider = NotifierProvider<MusicPlaybackSettingsController, MusicPlaybackSettings>(
  MusicPlaybackSettingsController.new,
);
