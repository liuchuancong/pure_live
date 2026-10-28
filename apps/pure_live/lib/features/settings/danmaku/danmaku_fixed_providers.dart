import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;

/// The engine keeps a top- and a bottom-pinned lane (`BarrageType.topFixed` /
/// `bottomFixed`) beside the scrolling one. These answer which of the two
/// pinned lanes the flying layer draws, and how long a pinned message stays.

/// Whether a platform's top-pinned messages fly over the picture. Off, they
/// still land in the chat list.
const String kDanmakuFixedTopKey = 'danmaku.fixed.top';

/// Whether a platform's bottom-pinned messages fly over the picture.
const String kDanmakuFixedBottomKey = 'danmaku.fixed.bottom';

/// How long a pinned message stays, in seconds.
const String kDanmakuFixedDurationKey = 'danmaku.fixed.duration';

/// The stay's range, in seconds: the engine's fixed lane keeps a message up
/// long enough to read and short enough not to block the picture.
const double kDanmakuFixedDurationMin = 2;
const double kDanmakuFixedDurationMax = 10;
const double kDanmakuFixedDurationDefault = 4;

/// Owns the top-pinned lane's switch.
final class DanmakuFixedTopController extends Notifier<bool> {
  @override
  bool build() {
    try {
      return StoragePrefs.getBool(kDanmakuFixedTopKey) ?? true;
    } on Object {
      return true;
    }
  }

  Future<void> set({required bool value}) async {
    state = value;
    try {
      await StoragePrefs.setBool(kDanmakuFixedTopKey, value);
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  /// Back to the default: the lane drawn.
  Future<void> reset() => set(value: true);
}

/// Owns the bottom-pinned lane's switch.
final class DanmakuFixedBottomController extends Notifier<bool> {
  @override
  bool build() {
    try {
      return StoragePrefs.getBool(kDanmakuFixedBottomKey) ?? true;
    } on Object {
      return true;
    }
  }

  Future<void> set({required bool value}) async {
    state = value;
    try {
      await StoragePrefs.setBool(kDanmakuFixedBottomKey, value);
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  /// Back to the default: the lane drawn.
  Future<void> reset() => set(value: true);
}

/// Owns how long a pinned message stays.
final class DanmakuFixedDurationController extends Notifier<double> {
  @override
  double build() {
    try {
      return (StoragePrefs.getDouble(kDanmakuFixedDurationKey) ?? kDanmakuFixedDurationDefault).clamp(
        kDanmakuFixedDurationMin,
        kDanmakuFixedDurationMax,
      );
    } on Object {
      return kDanmakuFixedDurationDefault;
    }
  }

  /// Moves the stay to [seconds], rounded to whole seconds.
  Future<void> set(double seconds) async {
    final value = seconds.roundToDouble().clamp(kDanmakuFixedDurationMin, kDanmakuFixedDurationMax);
    state = value;
    try {
      await StoragePrefs.setDouble(kDanmakuFixedDurationKey, value);
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  /// Back to the default stay.
  Future<void> reset() => set(kDanmakuFixedDurationDefault);
}

/// The top-pinned lane's switch.
final danmakuFixedTopProvider = NotifierProvider<DanmakuFixedTopController, bool>(DanmakuFixedTopController.new);

/// The bottom-pinned lane's switch.
final danmakuFixedBottomProvider = NotifierProvider<DanmakuFixedBottomController, bool>(
  DanmakuFixedBottomController.new,
);

/// How long a pinned message stays.
final danmakuFixedDurationProvider = NotifierProvider<DanmakuFixedDurationController, double>(
  DanmakuFixedDurationController.new,
);
