import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;

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

/// The music module's preferences, read where the module plays and lists.
///
/// The reference's own rows, reduced to the ones this module can honour: the
/// source a song is asked from and the rendition it prefers, the two playback
/// behaviours, and how a list takes a new song and shows its source. The
/// desktop-only rows (tray, window size, hotkeys, desktop lyrics) belong to
/// the app-wide groups or to no page at all.
@immutable
final class MusicSettings {
  /// Creates the music preferences.
  const MusicSettings({
    required this.defaultSourceId,
    required this.quality,
    required this.skipOnError,
    required this.autoplay,
    required this.addToTop,
    required this.showSource,
  });

  /// The reference's defaults: the first available source, 320k, skip a
  /// source that fails, no autoplay, new songs at the bottom, sources shown.
  static const MusicSettings standard = MusicSettings(
    defaultSourceId: '',
    quality: MusicQuality.high,
    skipOnError: true,
    autoplay: false,
    addToTop: false,
    showSource: true,
  );

  /// The custom source songs are asked from; empty means the first enabled
  /// one in the source list's order.
  final String defaultSourceId;

  /// The rendition asked of a source.
  final MusicQuality quality;

  /// Whether a source that cannot answer is skipped rather than stopping
  /// the queue.
  final bool skipOnError;

  /// Whether opening the module resumes the last queue.
  final bool autoplay;

  /// Whether a song added to a list goes to its top rather than its end.
  final bool addToTop;

  /// Whether a list row names the source the song came from.
  final bool showSource;

  /// A copy with selected fields replaced.
  MusicSettings copyWith({
    String? defaultSourceId,
    MusicQuality? quality,
    bool? skipOnError,
    bool? autoplay,
    bool? addToTop,
    bool? showSource,
  }) => MusicSettings(
    defaultSourceId: defaultSourceId ?? this.defaultSourceId,
    quality: quality ?? this.quality,
    skipOnError: skipOnError ?? this.skipOnError,
    autoplay: autoplay ?? this.autoplay,
    addToTop: addToTop ?? this.addToTop,
    showSource: showSource ?? this.showSource,
  );
}

const String _sourceKey = 'music.source.default';
const String _qualityKey = 'music.play.quality';
const String _skipOnErrorKey = 'music.play.skipOnError';
const String _autoplayKey = 'music.play.autoplay';
const String _addToTopKey = 'music.list.addToTop';
const String _showSourceKey = 'music.list.showSource';

/// Owns the music module's preferences.
final class MusicSettingsController extends Notifier<MusicSettings> {
  @override
  MusicSettings build() => MusicSettings(
    defaultSourceId: _readString(_sourceKey) ?? '',
    quality: _readQuality(),
    skipOnError: _readBool(_skipOnErrorKey) ?? true,
    autoplay: _readBool(_autoplayKey) ?? false,
    addToTop: _readBool(_addToTopKey) ?? false,
    showSource: _readBool(_showSourceKey) ?? true,
  );

  static MusicQuality _readQuality() {
    final name = _readString(_qualityKey);
    for (final quality in MusicQuality.values) {
      if (quality.name == name) return quality;
    }
    return MusicQuality.high;
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

  /// Chooses the source songs are asked from; empty means the first
  /// enabled one.
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

  /// Back to the reference's defaults.
  Future<void> reset() async {
    state = MusicSettings.standard;
    await setDefaultSource('');
    await setQuality(MusicQuality.high);
    await setSkipOnError(value: true);
    await setAutoplay(value: false);
    await setAddToTop(value: false);
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
}

/// The music module's preferences.
final musicSettingsProvider = NotifierProvider<MusicSettingsController, MusicSettings>(MusicSettingsController.new);
