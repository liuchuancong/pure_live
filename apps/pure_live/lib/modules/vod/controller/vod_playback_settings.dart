import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;

import 'package:pure_live/l10n/translations.dart';

/// The speeds the station offers, the reference's own list (0.5×–2×).
enum VodSpeedChoice {
  /// Half speed.
  half(0.5),

  /// Three quarters.
  threeQuarters(0.75),

  /// Normal speed.
  normal(1),

  /// One and a quarter.
  oneAndQuarter(1.25),

  /// One and a half.
  oneAndHalf(1.5),

  /// Double speed.
  doubleSpeed(2),

  /// Two and a half.
  twoAndHalf(2.5),

  /// Triple speed, the rate a held picture asks for; past it the words stop
  /// being worth reading.
  triple(3);

  VodSpeedChoice(this.value);

  /// The rate handed to the player.
  final double value;

  /// The menu's words: the rate itself, never the category's name — a 1×
  /// row reading "倍速" beside a panel titled 倍速 says nothing about which
  /// choice is in force.
  String get label => '${_trim(value)}x';

  /// The nearest choice for a stored rate; [normal] for a damaged value.
  static VodSpeedChoice nearest(double value) {
    var best = VodSpeedChoice.normal;
    for (final choice in VodSpeedChoice.values) {
      if ((choice.value - value).abs() < (best.value - value).abs()) best = choice;
    }
    return best;
  }

  static String _trim(double value) {
    final text = value.toStringAsFixed(2);
    return text.replaceFirst(RegExp(r'\.?0+$'), '');
  }
}

/// What the page does when a part reaches its end — the reference's
/// 播放结束动作.
enum VodFinishAction {
  /// Stays on the last frame; the viewer decides.
  pause,

  /// Opens the next part of a multi-part archive.
  nextPart,

  /// Leaves the player.
  exit,

  /// Opens the first related archive.
  playRelated;

  /// The menu's words.
  String label(Translations t) => switch (this) {
    VodFinishAction.pause => t.vod.finishPause,
    VodFinishAction.nextPart => t.vod.finishNextPart,
    VodFinishAction.exit => t.vod.finishExit,
    VodFinishAction.playRelated => t.vod.finishRelated,
  };
}

/// Which interface the station's playback asks: the site's REST player or
/// the official client's gRPC channel.
enum VodApiType {
  /// The web player's REST answers; no sign-in needed.
  web,

  /// The app's gRPC channel; the higher tiers need the app sign-in.
  app;

  /// The row's own word.
  String get label => switch (this) {
    VodApiType.web => 'Web',
    VodApiType.app => 'App',
  };
}

/// The station's playback choices: the rate a video opens with, what
/// happens when it ends, whether the archive's details sit under the
/// picture, which interface its playback asks, and the three things a video
/// surface does that a stream cannot: step over its opening, answer a held
/// picture with a faster rate, and show a frame under the pointer.
@immutable
final class VodPlaybackSettings {
  /// Creates the playback choices.
  const VodPlaybackSettings({
    required this.speed,
    required this.finish,
    required this.showDetails,
    required this.apiType,
    this.skipHeadTail = true,
    this.longPressSpeed = VodSpeedChoice.triple,
    this.seekPreview = true,
  });

  /// The reference's defaults: normal speed, the next part, details shown,
  /// the web interface, the openings stepped over, a held picture at 3× and
  /// the pointer's frame shown.
  static const VodPlaybackSettings standard = VodPlaybackSettings(
    speed: VodSpeedChoice.normal,
    finish: VodFinishAction.nextPart,
    showDetails: true,
    apiType: VodApiType.web,
  );

  /// The rate a video opens with.
  final VodSpeedChoice speed;

  /// What a finished part leads to.
  final VodFinishAction finish;

  /// Whether the uploader, the counts and the description are drawn.
  final bool showDetails;

  /// The interface playback asks.
  final VodApiType apiType;

  /// Whether the picture steps over its own opening and ending on its own.
  /// The points themselves belong to the archive and are set from the player;
  /// this only says whether the player uses them without being asked.
  final bool skipHeadTail;

  /// The rate a held picture runs at.
  final VodSpeedChoice longPressSpeed;

  /// Whether the seek line's bubble shows a picture as well as the time.
  final bool seekPreview;

  /// A copy with selected fields replaced.
  VodPlaybackSettings copyWith({
    VodSpeedChoice? speed,
    VodFinishAction? finish,
    bool? showDetails,
    VodApiType? apiType,
    bool? skipHeadTail,
    VodSpeedChoice? longPressSpeed,
    bool? seekPreview,
  }) => VodPlaybackSettings(
    speed: speed ?? this.speed,
    finish: finish ?? this.finish,
    showDetails: showDetails ?? this.showDetails,
    apiType: apiType ?? this.apiType,
    skipHeadTail: skipHeadTail ?? this.skipHeadTail,
    longPressSpeed: longPressSpeed ?? this.longPressSpeed,
    seekPreview: seekPreview ?? this.seekPreview,
  );
}

/// The keys the choices are kept under.
const String kVodSpeedPrefsKey = 'vod.playback.speed';
const String kVodFinishPrefsKey = 'vod.playback.finish';
const String kVodShowDetailsPrefsKey = 'vod.playback.showDetails';
const String kVodApiTypePrefsKey = 'vod.playback.apiType';
const String kVodSkipHeadTailPrefsKey = 'vod.playback.skipHeadTail';
const String kVodLongPressSpeedPrefsKey = 'vod.playback.longPressSpeed';
const String kVodSeekPreviewPrefsKey = 'vod.playback.seekPreview';

/// Owns the station's playback choices.
final class VodPlaybackSettingsController extends Notifier<VodPlaybackSettings> {
  @override
  VodPlaybackSettings build() => VodPlaybackSettings(
    speed: _readSpeed(),
    finish: _readFinish(),
    showDetails: _readDetails(),
    apiType: _readApiType(),
    skipHeadTail: _readSkip(),
    longPressSpeed: _readLongPressSpeed(),
    seekPreview: _readSeekPreview(),
  );

  static double? _readRate(String key) {
    try {
      final value = StoragePrefs.getDouble(key);
      if (value != null && value.isFinite && value > 0) return value;
    } on Object {
      // A closed store keeps the default.
    }
    return null;
  }

  static VodSpeedChoice _readSpeed() => VodSpeedChoice.nearest(_readRate(kVodSpeedPrefsKey) ?? 1);

  static VodSpeedChoice _readLongPressSpeed() => VodSpeedChoice.nearest(_readRate(kVodLongPressSpeedPrefsKey) ?? 3);

  static bool _readSkip() {
    try {
      return StoragePrefs.getBool(kVodSkipHeadTailPrefsKey) ?? true;
    } on Object {
      return true;
    }
  }

  static bool _readSeekPreview() {
    try {
      return StoragePrefs.getBool(kVodSeekPreviewPrefsKey) ?? true;
    } on Object {
      return true;
    }
  }

  static VodFinishAction _readFinish() {
    try {
      final name = StoragePrefs.getString(kVodFinishPrefsKey);
      for (final action in VodFinishAction.values) {
        if (action.name == name) return action;
      }
    } on Object {
      // A closed store keeps the default.
    }
    return VodFinishAction.nextPart;
  }

  static VodApiType _readApiType() {
    try {
      final name = StoragePrefs.getString(kVodApiTypePrefsKey);
      for (final type in VodApiType.values) {
        if (type.name == name) return type;
      }
    } on Object {
      // A closed store keeps the default.
    }
    return VodApiType.web;
  }

  static bool _readDetails() {
    try {
      return StoragePrefs.getBool(kVodShowDetailsPrefsKey) ?? true;
    } on Object {
      return true;
    }
  }

  /// Sets the rate a video opens with.
  Future<void> setSpeed(VodSpeedChoice speed) async {
    state = state.copyWith(speed: speed);
    try {
      await StoragePrefs.setDouble(kVodSpeedPrefsKey, speed.value);
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  /// Sets what a finished part leads to.
  Future<void> setFinish(VodFinishAction finish) async {
    state = state.copyWith(finish: finish);
    try {
      await StoragePrefs.setString(kVodFinishPrefsKey, finish.name);
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  /// Shows or hides the archive's details under the picture.
  Future<void> setShowDetails({required bool value}) async {
    state = state.copyWith(showDetails: value);
    try {
      await StoragePrefs.setBool(kVodShowDetailsPrefsKey, value);
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  /// Sets the interface playback asks.
  Future<void> setApiType(VodApiType type) async {
    state = state.copyWith(apiType: type);
    try {
      await StoragePrefs.setString(kVodApiTypePrefsKey, type.name);
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  /// Sets whether the picture steps over its own opening and ending.
  Future<void> setSkipHeadTail({required bool value}) async {
    state = state.copyWith(skipHeadTail: value);
    try {
      await StoragePrefs.setBool(kVodSkipHeadTailPrefsKey, value);
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  /// Sets the rate a held picture runs at.
  Future<void> setLongPressSpeed(VodSpeedChoice speed) async {
    state = state.copyWith(longPressSpeed: speed);
    try {
      await StoragePrefs.setDouble(kVodLongPressSpeedPrefsKey, speed.value);
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  /// Sets whether the seek line's bubble shows a frame.
  Future<void> setSeekPreview({required bool value}) async {
    state = state.copyWith(seekPreview: value);
    try {
      await StoragePrefs.setBool(kVodSeekPreviewPrefsKey, value);
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  /// Back to the reference's defaults.
  Future<void> reset() async {
    state = VodPlaybackSettings.standard;
    await setSpeed(VodSpeedChoice.normal);
    await setFinish(VodFinishAction.nextPart);
    await setShowDetails(value: true);
    await setApiType(VodApiType.web);
    await setSkipHeadTail(value: true);
    await setLongPressSpeed(VodSpeedChoice.triple);
    await setSeekPreview(value: true);
  }
}

/// The station's playback choices.
final vodPlaybackSettingsProvider = NotifierProvider<VodPlaybackSettingsController, VodPlaybackSettings>(
  VodPlaybackSettingsController.new,
);
