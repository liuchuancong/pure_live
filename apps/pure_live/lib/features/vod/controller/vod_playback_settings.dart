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
  doubleSpeed(2);

  VodSpeedChoice(this.value);

  /// The rate handed to the player.
  final double value;

  /// The menu's words.
  String label(Translations t) => value == 1 ? t.vod.speed : '${_trim(value)}x';

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

/// The station's playback choices: the rate a video opens with, what
/// happens when it ends, and whether the archive's details sit under the
/// picture.
@immutable
final class VodPlaybackSettings {
  /// Creates the playback choices.
  const VodPlaybackSettings({required this.speed, required this.finish, required this.showDetails});

  /// The reference's defaults: normal speed, the next part, details shown.
  static const VodPlaybackSettings standard = VodPlaybackSettings(
    speed: VodSpeedChoice.normal,
    finish: VodFinishAction.nextPart,
    showDetails: true,
  );

  /// The rate a video opens with.
  final VodSpeedChoice speed;

  /// What a finished part leads to.
  final VodFinishAction finish;

  /// Whether the uploader, the counts and the description are drawn.
  final bool showDetails;

  /// A copy with selected fields replaced.
  VodPlaybackSettings copyWith({VodSpeedChoice? speed, VodFinishAction? finish, bool? showDetails}) =>
      VodPlaybackSettings(
        speed: speed ?? this.speed,
        finish: finish ?? this.finish,
        showDetails: showDetails ?? this.showDetails,
      );
}

/// The keys the three choices are kept under.
const String kVodSpeedPrefsKey = 'vod.playback.speed';
const String kVodFinishPrefsKey = 'vod.playback.finish';
const String kVodShowDetailsPrefsKey = 'vod.playback.showDetails';

/// Owns the station's playback choices.
final class VodPlaybackSettingsController extends Notifier<VodPlaybackSettings> {
  @override
  VodPlaybackSettings build() =>
      VodPlaybackSettings(speed: _readSpeed(), finish: _readFinish(), showDetails: _readDetails());

  static VodSpeedChoice _readSpeed() {
    try {
      final value = StoragePrefs.getDouble(kVodSpeedPrefsKey);
      if (value != null && value.isFinite && value > 0) return VodSpeedChoice.nearest(value);
    } on Object {
      // A closed store keeps the default.
    }
    return VodSpeedChoice.normal;
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

  /// Back to the reference's defaults.
  Future<void> reset() async {
    state = VodPlaybackSettings.standard;
    await setSpeed(VodSpeedChoice.normal);
    await setFinish(VodFinishAction.nextPart);
    await setShowDetails(value: true);
  }
}

/// The station's playback choices.
final vodPlaybackSettingsProvider = NotifierProvider<VodPlaybackSettingsController, VodPlaybackSettings>(
  VodPlaybackSettingsController.new,
);
