import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart';

/// The repeated-danmaku collapse: whether a burst of identical text from
/// different viewers is reduced to its first message, and for how long the
/// window remembers it.
typedef DanmakuRepeatSettings = ({bool enabled, int windowSeconds});

/// The reference's defaults: off, five seconds.
const DanmakuRepeatSettings _defaults = (enabled: false, windowSeconds: 5);

/// The reference keeps the window inside 1–30 seconds.
const int kDanmakuRepeatWindowMin = 1;
const int kDanmakuRepeatWindowMax = 30;

/// Owns those two choices, persisted under `danmaku.repeat.*`.
final class DanmakuRepeatController extends Notifier<DanmakuRepeatSettings> {
  @override
  DanmakuRepeatSettings build() {
    try {
      final seconds = StoragePrefs.getInt('danmaku.repeat.windowSeconds');
      return (
        enabled: StoragePrefs.getBool('danmaku.repeat.collapse') ?? _defaults.enabled,
        windowSeconds: (seconds ?? _defaults.windowSeconds).clamp(kDanmakuRepeatWindowMin, kDanmakuRepeatWindowMax),
      );
    } on Object {
      return _defaults;
    }
  }

  /// Flips the collapse, writing through.
  Future<void> setEnabled({required bool value}) => _write((enabled: value, windowSeconds: state.windowSeconds));

  /// Moves the window, writing through.
  Future<void> setWindowSeconds(int value) =>
      _write((enabled: state.enabled, windowSeconds: value.clamp(kDanmakuRepeatWindowMin, kDanmakuRepeatWindowMax)));

  Future<void> _write(DanmakuRepeatSettings next) async {
    state = next;
    try {
      await StoragePrefs.setBool('danmaku.repeat.collapse', next.enabled);
      await StoragePrefs.setInt('danmaku.repeat.windowSeconds', next.windowSeconds);
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// The repeated-danmaku collapse choice.
final danmakuRepeatProvider = NotifierProvider<DanmakuRepeatController, DanmakuRepeatSettings>(
  DanmakuRepeatController.new,
);
