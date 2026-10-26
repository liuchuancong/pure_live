import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/widgets.dart' show BoxFit;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;

import 'package:pure_live/l10n/translations.dart' show Translations;

/// How the picture fills its box (the reference's `videoFits`, six entries
/// stored as `videoFitIndex`; the names are ours, the order is the
/// reference's).
enum PlaybackFit {
  /// The whole frame, letterboxed when the shapes differ.
  contain,

  /// The frame fills the box, cropping the overflow.
  cover,

  /// The frame is stretched to the box.
  fill,

  /// The frame's height matches the box; the width follows the ratio.
  fitHeight,

  /// The frame's width matches the box; the height follows the ratio.
  fitWidth,

  /// Like [contain], but a smaller frame is never enlarged.
  scaleDown;

  /// The box fitting this choice.
  BoxFit get boxFit => switch (this) {
    PlaybackFit.contain => BoxFit.contain,
    PlaybackFit.cover => BoxFit.cover,
    PlaybackFit.fill => BoxFit.fill,
    PlaybackFit.fitHeight => BoxFit.fitHeight,
    PlaybackFit.fitWidth => BoxFit.fitWidth,
    PlaybackFit.scaleDown => BoxFit.scaleDown,
  };
}

/// The fit stored under `playback.fit`.
///
/// A name is what the current build writes; the first builds stored one of
/// three choices, so a bare number is read as the reference's index into
/// [PlaybackFit.values] (its `videoFitIndex`). Anything unknown — a stale
/// name or an out-of-range index — falls back to 默认比例, as the
/// reference's `normalizeVideoFitIndex` does.
PlaybackFit normalizePlaybackFit(String? stored) {
  final word = stored?.trim();
  if (word == null || word.isEmpty) return PlaybackFit.contain;
  final byName = PlaybackFit.values.asNameMap()[word];
  if (byName != null) return byName;
  final index = int.tryParse(word);
  if (index != null && index >= 0 && index < PlaybackFit.values.length) return PlaybackFit.values[index];
  return PlaybackFit.contain;
}

/// The fit choices' words, in [PlaybackFit]'s order: the room's control bar
/// and the picture page draw from here so both name a choice the same way.
List<String> fitLabels(Translations t) => [
  t.settings.fitContain,
  t.settings.fitCover,
  t.settings.fitFill,
  t.settings.fitHeight,
  t.settings.fitWidth,
  t.settings.fitScaleDown,
];

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
  bool backgroundPlay,
  bool backgroundAudioOnly,
  bool backgroundPauseDanmaku,
  bool chatCollapsed,
  double mobileVolume,
  double desktopVolume,
  PlaybackFit fit,
  bool danmakuVisible,
  bool miniDanmakuVisible,
  bool hardwareDecoding,
  bool autoPipOnLeave,
  bool floatPlay,
  bool fullscreenDefault,
  bool windowsPipAlwaysOnTop,
  bool rememberPipPosition,
  double windowsPipBaseSize,
  double windowsPipMinWidth,
  double windowsPipMinHeight,
  bool windowsPipFreeAspect,
  bool asmrSleepMode,
  int asmrSleepMinutes,
});

const PlaybackSettings _defaults = (
  preferredQuality: '原画',
  preferredQualityCellular: '原画',
  muted: false,
  globalMute: false,
  backgroundPlay: false,
  backgroundAudioOnly: false,
  backgroundPauseDanmaku: false,
  chatCollapsed: false,
  mobileVolume: 0.5,
  desktopVolume: 1,
  fit: PlaybackFit.contain,
  danmakuVisible: true,
  miniDanmakuVisible: true,
  hardwareDecoding: true,
  autoPipOnLeave: false,
  floatPlay: false,
  fullscreenDefault: false,
  windowsPipAlwaysOnTop: false,
  rememberPipPosition: true,
  windowsPipBaseSize: 360,
  windowsPipMinWidth: 140,
  windowsPipMinHeight: 90,
  windowsPipFreeAspect: false,
  asmrSleepMode: false,
  asmrSleepMinutes: 60,
);

/// The reference's compact-window base-size bounds.
const double kWindowsPipBaseSizeMin = 200;
const double kWindowsPipBaseSizeMax = 720;

/// The reference's compact-window floor bounds.
const double kWindowsPipMinWidthMin = 100;
const double kWindowsPipMinWidthMax = 320;
const double kWindowsPipMinHeightMin = 60;
const double kWindowsPipMinHeightMax = 240;

/// The reference's ASMR sleep-timer bounds.
const int kAsmrSleepMinutesMin = 15;
const int kAsmrSleepMinutesMax = 1440;

/// The reference's duration presets.
const List<int> kAsmrSleepMinuteChoices = [15, 30, 45, 60, 90, 120, 240, 480, 720, 1440];

/// A sleep duration in the reference's words: minutes below an hour, whole
/// hours above, half hours as a decimal.
String asmrSleepDurationLabel(int minutes) {
  if (minutes < 60) return '$minutes min';
  if (minutes % 60 == 0) return '${minutes ~/ 60} h';
  if (minutes % 30 == 0) return '${(minutes / 60).toStringAsFixed(1)} h';
  return '$minutes min';
}

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
        backgroundPlay: StoragePrefs.getBool('playback.background') ?? _defaults.backgroundPlay,
        backgroundAudioOnly:
            StoragePrefs.getBool('playback.backgroundAudioOnly') ?? _defaults.backgroundAudioOnly,
        backgroundPauseDanmaku:
            StoragePrefs.getBool('playback.backgroundPauseDanmaku') ?? _defaults.backgroundPauseDanmaku,
        chatCollapsed: StoragePrefs.getBool('playback.chatCollapsed') ?? _defaults.chatCollapsed,
        mobileVolume:
            _readVolume('playback.mobileVolume') ?? (usesMobileVolumeDefault ? legacy : null) ?? _defaults.mobileVolume,
        desktopVolume:
            _readVolume('playback.desktopVolume') ??
            (!usesMobileVolumeDefault ? legacy : null) ??
            _defaults.desktopVolume,
        fit: normalizePlaybackFit(_readString('playback.fit')),
        danmakuVisible: StoragePrefs.getBool('playback.danmaku') ?? _defaults.danmakuVisible,
        miniDanmakuVisible: StoragePrefs.getBool('playback.miniDanmaku') ?? _defaults.miniDanmakuVisible,
        hardwareDecoding: StoragePrefs.getBool('playback.hwdec') ?? _defaults.hardwareDecoding,
        autoPipOnLeave: StoragePrefs.getBool('playback.autoPip') ?? _defaults.autoPipOnLeave,
        floatPlay: StoragePrefs.getBool('playback.floatPlay') ?? _defaults.floatPlay,
        fullscreenDefault: StoragePrefs.getBool('playback.fullscreenDefault') ?? _defaults.fullscreenDefault,
        windowsPipAlwaysOnTop:
            StoragePrefs.getBool('playback.windowsPipAlwaysOnTop') ?? _defaults.windowsPipAlwaysOnTop,
        rememberPipPosition: StoragePrefs.getBool('playback.rememberPipPosition') ?? _defaults.rememberPipPosition,
        windowsPipBaseSize: (StoragePrefs.getDouble('playback.windowsPipBaseSize') ?? _defaults.windowsPipBaseSize)
            .clamp(kWindowsPipBaseSizeMin, kWindowsPipBaseSizeMax),
        windowsPipMinWidth: (StoragePrefs.getDouble('playback.windowsPipMinWidth') ?? _defaults.windowsPipMinWidth)
            .clamp(kWindowsPipMinWidthMin, kWindowsPipMinWidthMax),
        windowsPipMinHeight: (StoragePrefs.getDouble('playback.windowsPipMinHeight') ?? _defaults.windowsPipMinHeight)
            .clamp(kWindowsPipMinHeightMin, kWindowsPipMinHeightMax),
        windowsPipFreeAspect: StoragePrefs.getBool('playback.windowsPipFreeAspect') ?? _defaults.windowsPipFreeAspect,
        asmrSleepMode: StoragePrefs.getBool('playback.asmrSleep') ?? _defaults.asmrSleepMode,
        asmrSleepMinutes: (StoragePrefs.getInt('playback.asmrMinutes') ?? _defaults.asmrSleepMinutes).clamp(
          kAsmrSleepMinutesMin,
          kAsmrSleepMinutesMax,
        ),
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
    bool? backgroundPlay,
    bool? backgroundAudioOnly,
    bool? backgroundPauseDanmaku,
    bool? chatCollapsed,
    double? mobileVolume,
    double? desktopVolume,
    PlaybackFit? fit,
    bool? danmakuVisible,
    bool? miniDanmakuVisible,
    bool? hardwareDecoding,
    bool? autoPipOnLeave,
    bool? floatPlay,
    bool? fullscreenDefault,
    bool? windowsPipAlwaysOnTop,
    bool? rememberPipPosition,
    double? windowsPipBaseSize,
    double? windowsPipMinWidth,
    double? windowsPipMinHeight,
    bool? windowsPipFreeAspect,
    bool? asmrSleepMode,
    int? asmrSleepMinutes,
  }) => (
    preferredQuality: preferredQuality ?? state.preferredQuality,
    preferredQualityCellular: preferredQualityCellular ?? state.preferredQualityCellular,
    muted: muted ?? state.muted,
    globalMute: globalMute ?? state.globalMute,
    backgroundPlay: backgroundPlay ?? state.backgroundPlay,
    backgroundAudioOnly: backgroundAudioOnly ?? state.backgroundAudioOnly,
    backgroundPauseDanmaku: backgroundPauseDanmaku ?? state.backgroundPauseDanmaku,
    chatCollapsed: chatCollapsed ?? state.chatCollapsed,
    mobileVolume: mobileVolume ?? state.mobileVolume,
    desktopVolume: desktopVolume ?? state.desktopVolume,
    fit: fit ?? state.fit,
    danmakuVisible: danmakuVisible ?? state.danmakuVisible,
    miniDanmakuVisible: miniDanmakuVisible ?? state.miniDanmakuVisible,
    hardwareDecoding: hardwareDecoding ?? state.hardwareDecoding,
    autoPipOnLeave: autoPipOnLeave ?? state.autoPipOnLeave,
    floatPlay: floatPlay ?? state.floatPlay,
    fullscreenDefault: fullscreenDefault ?? state.fullscreenDefault,
    windowsPipAlwaysOnTop: windowsPipAlwaysOnTop ?? state.windowsPipAlwaysOnTop,
    rememberPipPosition: rememberPipPosition ?? state.rememberPipPosition,
    windowsPipBaseSize: windowsPipBaseSize ?? state.windowsPipBaseSize,
    windowsPipMinWidth: windowsPipMinWidth ?? state.windowsPipMinWidth,
    windowsPipMinHeight: windowsPipMinHeight ?? state.windowsPipMinHeight,
    windowsPipFreeAspect: windowsPipFreeAspect ?? state.windowsPipFreeAspect,
    asmrSleepMode: asmrSleepMode ?? state.asmrSleepMode,
    asmrSleepMinutes: asmrSleepMinutes ?? state.asmrSleepMinutes,
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

  /// Whether Android playback continues after the app leaves the foreground
  /// (the reference's `enableBackgroundPlay`).
  bool get backgroundPlay => state.backgroundPlay;

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

  /// Whether leaving a live room hands its picture to the floating player.
  bool get floatPlay => state.floatPlay;

  /// Whether a room enters fullscreen once its stream starts playing.
  bool get fullscreenDefault => state.fullscreenDefault;

  /// Whether the Windows compact PiP window stays above other windows.
  bool get windowsPipAlwaysOnTop => state.windowsPipAlwaysOnTop;

  /// Whether the compact window reopens where the viewer left it.
  bool get rememberPipPosition => state.rememberPipPosition;

  /// The compact window's base long side in logical pixels.
  double get windowsPipBaseSize => state.windowsPipBaseSize;

  /// The compact window's width floor.
  double get windowsPipMinWidth => state.windowsPipMinWidth;

  /// The compact window's height floor.
  double get windowsPipMinHeight => state.windowsPipMinHeight;

  /// Whether the compact window may be reshaped freely.
  bool get windowsPipFreeAspect => state.windowsPipFreeAspect;

  /// Whether Android rooms start in audio-only mode with a sleep timer.
  bool get asmrSleepMode => state.asmrSleepMode;

  /// The ASMR sleep-timer duration in minutes.
  int get asmrSleepMinutes => state.asmrSleepMinutes;

  /// Stores the app-leave PiP choice.
  Future<void> setAutoPipOnLeave({required bool value}) async {
    state = _with(autoPipOnLeave: value);
    await _write(() => StoragePrefs.setBool('playback.autoPip', value));
  }

  /// Keeps a live room in the floating player after leaving its page.
  Future<void> setFloatPlay({required bool value}) async {
    state = _with(floatPlay: value);
    await _write(() => StoragePrefs.setBool('playback.floatPlay', value));
  }

  /// Enters fullscreen automatically once a room's stream plays.
  Future<void> setFullscreenDefault({required bool value}) async {
    state = _with(fullscreenDefault: value);
    await _write(() => StoragePrefs.setBool('playback.fullscreenDefault', value));
  }

  /// Keeps the Windows compact PiP window above the other windows.
  Future<void> setWindowsPipAlwaysOnTop({required bool value}) async {
    state = _with(windowsPipAlwaysOnTop: value);
    await _write(() => StoragePrefs.setBool('playback.windowsPipAlwaysOnTop', value));
  }

  /// Remembers the compact window's size and position for the next entry.
  Future<void> setRememberPipPosition({required bool value}) async {
    state = _with(rememberPipPosition: value);
    await _write(() => StoragePrefs.setBool('playback.rememberPipPosition', value));
  }

  /// Moves the compact window's base long side, clamped to 200–720.
  Future<void> setWindowsPipBaseSize(double value) async {
    final next = value.clamp(kWindowsPipBaseSizeMin, kWindowsPipBaseSizeMax);
    state = _with(windowsPipBaseSize: next);
    await _write(() => StoragePrefs.setDouble('playback.windowsPipBaseSize', next));
  }

  /// Moves the compact window's width floor, clamped to 100–320.
  Future<void> setWindowsPipMinWidth(double value) async {
    final next = value.clamp(kWindowsPipMinWidthMin, kWindowsPipMinWidthMax);
    state = _with(windowsPipMinWidth: next);
    await _write(() => StoragePrefs.setDouble('playback.windowsPipMinWidth', next));
  }

  /// Moves the compact window's height floor, clamped to 60–240.
  Future<void> setWindowsPipMinHeight(double value) async {
    final next = value.clamp(kWindowsPipMinHeightMin, kWindowsPipMinHeightMax);
    state = _with(windowsPipMinHeight: next);
    await _write(() => StoragePrefs.setDouble('playback.windowsPipMinHeight', next));
  }

  /// Lets the compact window be reshaped freely, or keeps the video's ratio.
  Future<void> setWindowsPipFreeAspect({required bool value}) async {
    state = _with(windowsPipFreeAspect: value);
    await _write(() => StoragePrefs.setBool('playback.windowsPipFreeAspect', value));
  }

  /// Starts Android rooms in audio-only mode with a sleep timer.
  Future<void> setAsmrSleepMode({required bool value}) async {
    state = _with(asmrSleepMode: value);
    await _write(() => StoragePrefs.setBool('playback.asmrSleep', value));
  }

  /// Stores the ASMR sleep-timer duration, clamped to 15…1440 minutes.
  Future<void> setAsmrSleepMinutes(int value) async {
    final next = value.clamp(kAsmrSleepMinutesMin, kAsmrSleepMinutesMax);
    state = _with(asmrSleepMinutes: next);
    await _write(() => StoragePrefs.setInt('playback.asmrMinutes', next));
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

  /// Keeps Android playback alive after the app leaves the foreground.
  Future<void> setBackgroundPlay({required bool value}) async {
    state = _with(backgroundPlay: value);
    await _write(() => StoragePrefs.setBool('playback.background', value));
  }

  /// Whether background playback keeps only the audio.
  Future<void> setBackgroundAudioOnly({required bool value}) async {
    state = _with(backgroundAudioOnly: value);
    await _write(() => StoragePrefs.setBool('playback.backgroundAudioOnly', value));
  }

  /// Whether the room's danmaku connection pauses in the background.
  Future<void> setBackgroundPauseDanmaku({required bool value}) async {
    state = _with(backgroundPauseDanmaku: value);
    await _write(() => StoragePrefs.setBool('playback.backgroundPauseDanmaku', value));
  }

  /// Remembers whether the wide room's chat column is folded away.
  Future<void> setChatCollapsed({required bool value}) async {
    state = _with(chatCollapsed: value);
    await _write(() => StoragePrefs.setBool('playback.chatCollapsed', value));
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
