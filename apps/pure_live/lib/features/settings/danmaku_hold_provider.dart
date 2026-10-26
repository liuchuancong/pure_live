import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;

/// Whether a press holds the flying message under the finger until the
/// gesture resolves (the reference's `holdDanmakuOnPress`). Off, a tap or
/// long press still opens the message's actions; only the hold-freeze while
/// the finger is down goes away.
const String kDanmakuHoldKey = 'danmaku.holdOnPress';

/// Owns the hold switch.
final class DanmakuHoldController extends Notifier<bool> {
  @override
  bool build() {
    try {
      return StoragePrefs.getBool(kDanmakuHoldKey) ?? true;
    } on Object {
      return true;
    }
  }

  Future<void> set({required bool value}) async {
    state = value;
    try {
      await StoragePrefs.setBool(kDanmakuHoldKey, value);
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// The hold-to-freeze switch.
final danmakuHoldProvider = NotifierProvider<DanmakuHoldController, bool>(DanmakuHoldController.new);
