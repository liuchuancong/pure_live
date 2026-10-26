import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;

/// Whether the platform's valuable gifts fly over the picture (the
/// reference's `danmakuShowGifts`). Off by default; separate from the chat
/// list's gift switch.
const String kDanmakuShowGiftsKey = 'danmaku.showGifts';

/// Owns the flying-gift switch.
final class DanmakuShowGiftsController extends Notifier<bool> {
  @override
  bool build() {
    try {
      return StoragePrefs.getBool(kDanmakuShowGiftsKey) ?? false;
    } on Object {
      return false;
    }
  }

  Future<void> set({required bool value}) async {
    state = value;
    try {
      await StoragePrefs.setBool(kDanmakuShowGiftsKey, value);
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// The flying gifts switch.
final danmakuShowGiftsProvider = NotifierProvider<DanmakuShowGiftsController, bool>(DanmakuShowGiftsController.new);
