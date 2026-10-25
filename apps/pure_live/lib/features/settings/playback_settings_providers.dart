import 'package:flutter/widgets.dart' show BoxFit;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;

/// How the picture fills its box (the reference's picture fit).
enum PlaybackFit {
  /// The whole frame, letterboxed when the shapes differ.
  contain,

  /// The frame fills the box, cropping the overflow.
  cover,

  /// The frame is stretched to the box.
  fill;

  /// The box fitting this choice.
  BoxFit get boxFit => switch (this) {
    PlaybackFit.contain => BoxFit.contain,
    PlaybackFit.cover => BoxFit.cover,
    PlaybackFit.fill => BoxFit.fill,
  };
}

/// The viewer's playback preferences: the quality a room starts on, the
/// audio it starts with, how the picture sits in its box, whether the flying
/// danmaku (and its small-window copy) draws, whether the engine decodes in
/// hardware, and whether leaving the app turns a playing room into a small
/// window.
typedef PlaybackSettings = ({
  String? preferredQuality,
  bool muted,
  double volume,
  PlaybackFit fit,
  bool danmakuVisible,
  bool miniDanmakuVisible,
  bool hardwareDecoding,
  bool autoPipOnLeave,
});

const PlaybackSettings _defaults = (
  preferredQuality: null,
  muted: false,
  volume: 1,
  fit: PlaybackFit.contain,
  danmakuVisible: true,
  miniDanmakuVisible: true,
  hardwareDecoding: true,
  autoPipOnLeave: false,
);

/// Owns the playback preferences, persisted under `playback.*`; the room
/// controller applies them when a player handle arrives and the player
/// surface reads them live.
final class PlaybackSettingsController extends Notifier<PlaybackSettings> {
  @override
  PlaybackSettings build() {
    try {
      return (
        preferredQuality: _readString('playback.quality'),
        muted: StoragePrefs.getBool('playback.muted') ?? _defaults.muted,
        volume: (StoragePrefs.getDouble('playback.volume') ?? _defaults.volume).clamp(0.0, 1.0),
        fit: PlaybackFit.values.asNameMap()[_readString('playback.fit')] ?? _defaults.fit,
        danmakuVisible: StoragePrefs.getBool('playback.danmaku') ?? _defaults.danmakuVisible,
        miniDanmakuVisible: StoragePrefs.getBool('playback.miniDanmaku') ?? _defaults.miniDanmakuVisible,
        hardwareDecoding: StoragePrefs.getBool('playback.hwdec') ?? _defaults.hardwareDecoding,
        autoPipOnLeave: StoragePrefs.getBool('playback.autoPip') ?? _defaults.autoPipOnLeave,
      );
    } on Object {
      return _defaults;
    }
  }

  static String? _readString(String key) {
    try {
      return StoragePrefs.getString(key);
    } on Object {
      return null;
    }
  }

  PlaybackSettings _with({
    String? preferredQuality,
    bool clearQuality = false,
    bool? muted,
    double? volume,
    PlaybackFit? fit,
    bool? danmakuVisible,
    bool? miniDanmakuVisible,
    bool? hardwareDecoding,
    bool? autoPipOnLeave,
  }) => (
    preferredQuality: clearQuality ? null : preferredQuality ?? state.preferredQuality,
    muted: muted ?? state.muted,
    volume: volume ?? state.volume,
    fit: fit ?? state.fit,
    danmakuVisible: danmakuVisible ?? state.danmakuVisible,
    miniDanmakuVisible: miniDanmakuVisible ?? state.miniDanmakuVisible,
    hardwareDecoding: hardwareDecoding ?? state.hardwareDecoding,
    autoPipOnLeave: autoPipOnLeave ?? state.autoPipOnLeave,
  );

  /// The quality label a room starts on; null means the site's first line.
  String? get preferredQuality => state.preferredQuality;

  /// The volume a new handle starts on.
  double get volume => state.volume;

  /// Whether a new handle starts muted.
  bool get muted => state.muted;

  /// How the picture sits in its box.
  PlaybackFit get fit => state.fit;

  /// Whether the flying danmaku draws.
  bool get danmakuVisible => state.danmakuVisible;

  /// Whether the flying danmaku also draws while the window is in PiP.
  bool get miniDanmakuVisible => state.miniDanmakuVisible;

  /// Whether the engine decodes in hardware.
  bool get hardwareDecoding => state.hardwareDecoding;

  /// Whether leaving the app while playing enters picture-in-picture.
  bool get autoPipOnLeave => state.autoPipOnLeave;

  /// Stores the app-leave PiP choice.
  Future<void> setAutoPipOnLeave({required bool value}) async {
    state = _with(autoPipOnLeave: value);
    await _write(() => StoragePrefs.setBool('playback.autoPip', value));
  }

  /// Stores the starting quality; null returns to the site's first.
  Future<void> setPreferredQuality(String? label) async {
    state = _with(preferredQuality: label, clearQuality: label == null);
    await _write(
      () => label == null ? StoragePrefs.remove('playback.quality') : StoragePrefs.setString('playback.quality', label),
    );
  }

  /// Flips the starting mute.
  Future<void> setMuted({required bool value}) async {
    state = _with(muted: value);
    await _write(() => StoragePrefs.setBool('playback.muted', value));
  }

  /// Moves the starting volume.
  Future<void> setVolume(double value) async {
    final clamped = value.clamp(0.0, 1.0);
    state = _with(volume: clamped);
    await _write(() => StoragePrefs.setDouble('playback.volume', clamped));
  }

  /// Chooses how the picture fits.
  Future<void> setFit(PlaybackFit fit) async {
    state = _with(fit: fit);
    await _write(() => StoragePrefs.setString('playback.fit', fit.name));
  }

  /// Shows or hides the flying danmaku.
  Future<void> setDanmakuVisible({required bool value}) async {
    state = _with(danmakuVisible: value);
    await _write(() => StoragePrefs.setBool('playback.danmaku', value));
  }

  /// Shows or hides the flying danmaku in the small window.
  Future<void> setMiniDanmakuVisible({required bool value}) async {
    state = _with(miniDanmakuVisible: value);
    await _write(() => StoragePrefs.setBool('playback.miniDanmaku', value));
  }

  /// Turns hardware decoding on or off for the next handle.
  Future<void> setHardwareDecoding({required bool value}) async {
    state = _with(hardwareDecoding: value);
    await _write(() => StoragePrefs.setBool('playback.hwdec', value));
  }

  Future<void> _write(Future<void> Function() write) async {
    try {
      await write();
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// The viewer's playback preferences.
final playbackSettingsProvider = NotifierProvider<PlaybackSettingsController, PlaybackSettings>(
  PlaybackSettingsController.new,
);
