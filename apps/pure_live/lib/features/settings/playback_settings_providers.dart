import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
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

/// The reference's resolution tiers, best first. Sites spell their qualities
/// differently; [preferredQualityIndex] matches an exact label first and
/// otherwise lands on the nearest tier by position.
const List<String> kPreferredResolutionChoices = ['原画', '蓝光8M', '蓝光4M', '超清', '流畅'];

/// Normalizes a stored/legacy quality to one of [kPreferredResolutionChoices].
///
/// Old builds stored site labels (`蓝光`, `高清`, `标清`); they map onto the
/// nearest tier so a saved preference survives the switch.
String normalizePreferredResolution(String? value) {
  final raw = value?.trim();
  if (raw == null || raw.isEmpty) return kPreferredResolutionChoices.first;
  for (final tier in kPreferredResolutionChoices) {
    if (tier.toLowerCase() == raw.toLowerCase()) return tier;
  }
  return switch (raw.toLowerCase()) {
    '蓝光' => '蓝光8M',
    '高清' => '超清',
    '标清' => '流畅',
    _ => kPreferredResolutionChoices.first,
  };
}

/// The index in [labels] the viewer's preferred tier should play.
///
/// An exact label wins. Otherwise the tier's position is mapped across the
/// available list (the reference's ratio), so a site with three qualities
/// still honours "流畅" at the bottom and "原画" at the top.
int preferredQualityIndex(Iterable<String> labels, String? preferred) {
  final list = labels.toList(growable: false);
  if (list.isEmpty) return 0;
  final tier = normalizePreferredResolution(preferred);
  final exact = list.indexWhere((label) => label.trim().toLowerCase() == tier.toLowerCase());
  if (exact != -1) return exact;
  final level = kPreferredResolutionChoices.indexWhere((choice) => choice.toLowerCase() == tier.toLowerCase());
  final safeLevel = level < 0 ? 0 : level;
  final ratio = kPreferredResolutionChoices.length <= 1 ? 0.0 : safeLevel / (kPreferredResolutionChoices.length - 1);
  return (ratio * (list.length - 1)).round().clamp(0, list.length - 1);
}

/// The viewer's playback preferences: the quality a room starts on, the
/// audio it starts with, how the picture sits in its box, whether the flying
/// danmaku (and its small-window copy) draws, whether the engine decodes in
/// hardware, and whether leaving the app turns a playing room into a small
/// window.
typedef PlaybackSettings = ({
  String? preferredQuality,
  String? preferredQualityCellular,
  bool muted,
  bool globalMute,
  double mobileVolume,
  double desktopVolume,
  PlaybackFit fit,
  bool danmakuVisible,
  bool miniDanmakuVisible,
  bool hardwareDecoding,
  bool autoPipOnLeave,
});

const PlaybackSettings _defaults = (
  preferredQuality: '原画',
  preferredQualityCellular: '原画',
  muted: false,
  globalMute: false,
  mobileVolume: 0.5,
  desktopVolume: 1,
  fit: PlaybackFit.contain,
  danmakuVisible: true,
  miniDanmakuVisible: true,
  hardwareDecoding: true,
  autoPipOnLeave: false,
);

/// Whether this build's new players use the mobile volume default. TV
/// builds are Android and therefore mobile here, as in the reference.
bool get usesMobileVolumeDefault =>
    !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

/// Owns the playback preferences, persisted under `playback.*`; the room
/// controller applies them when a player handle arrives and the player
/// surface reads them live.
class PlaybackSettingsController extends Notifier<PlaybackSettings> {
  @override
  PlaybackSettings build() => _read();

  /// Reads the stored choices, the boot default on any failed read.
  PlaybackSettings _read() {
    try {
      // The reference keeps separate mobile and desktop defaults; older
      // installs of this app stored one `playback.volume`, which seeds both
      // until the viewer moves the current platform's slider.
      final legacy = _readVolume('playback.volume');
      return (
        preferredQuality: normalizePreferredResolution(_readString('playback.quality')),
        preferredQualityCellular: normalizePreferredResolution(_readString('playback.qualityCellular')),
        muted: StoragePrefs.getBool('playback.muted') ?? _defaults.muted,
        globalMute: StoragePrefs.getBool('playback.globalMute') ?? _defaults.globalMute,
        mobileVolume:
            _readVolume('playback.mobileVolume') ?? (usesMobileVolumeDefault ? legacy : null) ?? _defaults.mobileVolume,
        desktopVolume:
            _readVolume('playback.desktopVolume') ??
            (!usesMobileVolumeDefault ? legacy : null) ??
            _defaults.desktopVolume,
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

  /// Re-reads the store after another window's change. The window that
  /// made the write has already applied it; this is the mirror's landing.
  void reload() => state = _read();

  static String? _readString(String key) {
    try {
      return StoragePrefs.getString(key);
    } on Object {
      return null;
    }
  }

  static double? _readVolume(String key) {
    try {
      final value = StoragePrefs.getDouble(key);
      return value?.clamp(0.0, 1.0);
    } on Object {
      return null;
    }
  }

  PlaybackSettings _with({
    String? preferredQuality,
    String? preferredQualityCellular,
    bool? muted,
    bool? globalMute,
    double? mobileVolume,
    double? desktopVolume,
    PlaybackFit? fit,
    bool? danmakuVisible,
    bool? miniDanmakuVisible,
    bool? hardwareDecoding,
    bool? autoPipOnLeave,
  }) => (
    preferredQuality: preferredQuality ?? state.preferredQuality,
    preferredQualityCellular: preferredQualityCellular ?? state.preferredQualityCellular,
    muted: muted ?? state.muted,
    globalMute: globalMute ?? state.globalMute,
    mobileVolume: mobileVolume ?? state.mobileVolume,
    desktopVolume: desktopVolume ?? state.desktopVolume,
    fit: fit ?? state.fit,
    danmakuVisible: danmakuVisible ?? state.danmakuVisible,
    miniDanmakuVisible: miniDanmakuVisible ?? state.miniDanmakuVisible,
    hardwareDecoding: hardwareDecoding ?? state.hardwareDecoding,
    autoPipOnLeave: autoPipOnLeave ?? state.autoPipOnLeave,
  );

  /// The resolution tier a room starts on; normalized to the reference's
  /// five choices, so it is always set.
  String? get preferredQuality => state.preferredQuality;

  /// The tier used while the device reports a cellular interface.
  String? get preferredQualityCellular => state.preferredQualityCellular;

  /// The volume a new handle starts on: the reference's mobile default on
  /// phones/tablets and desktop default elsewhere.
  double get volume => usesMobileVolumeDefault ? state.mobileVolume : state.desktopVolume;

  /// The mobile/tablet default, regardless of the current platform.
  double get mobileVolume => state.mobileVolume;

  /// The desktop default, regardless of the current platform.
  double get desktopVolume => state.desktopVolume;

  /// Whether a new handle starts muted.
  bool get muted => state.muted;

  /// Whether every playback surface is silenced regardless of its own mute
  /// choice (the reference's `globalVolumeMute`).
  bool get globalMute => state.globalMute;

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

  /// Stores the starting resolution tier; null/unknown falls back to 原画
  /// rather than leaving an option the picker cannot show.
  Future<void> setPreferredQuality(String? label) async {
    final next = normalizePreferredResolution(label);
    state = _with(preferredQuality: next);
    await _write(() => StoragePrefs.setString('playback.quality', next));
  }

  /// Stores the tier used on cellular data; normalized like the main one.
  Future<void> setPreferredQualityCellular(String? label) async {
    final next = normalizePreferredResolution(label);
    state = _with(preferredQualityCellular: next);
    await _write(() => StoragePrefs.setString('playback.qualityCellular', next));
  }

  /// Flips the starting mute.
  Future<void> setMuted({required bool value}) async {
    state = _with(muted: value);
    await _write(() => StoragePrefs.setBool('playback.muted', value));
  }

  /// Silences every playback surface, or lets each keep its own choice.
  Future<void> setGlobalMute({required bool value}) async {
    state = _with(globalMute: value);
    await _write(() => StoragePrefs.setBool('playback.globalMute', value));
  }

  /// Moves the current platform's starting volume.
  ///
  /// The reference edits only the platform being used; the other platform's
  /// default is left alone. The old shared `playback.volume` is removed once
  /// a platform-specific value is written.
  Future<void> setVolume(double value) async {
    final clamped = value.clamp(0.0, 1.0);
    if (usesMobileVolumeDefault) {
      state = _with(mobileVolume: clamped);
      await _write(() async {
        await StoragePrefs.setDouble('playback.mobileVolume', clamped);
        await StoragePrefs.remove('playback.volume');
      });
      return;
    }
    state = _with(desktopVolume: clamped);
    await _write(() async {
      await StoragePrefs.setDouble('playback.desktopVolume', clamped);
      await StoragePrefs.remove('playback.volume');
    });
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
