import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;

/// Whether a playing room or channel keeps the display awake.
///
/// The reference defaults this on: a live stream is watched, not read, so the
/// OS should not dim during it. The wakelock itself comes from live_device's
/// `ScreenAwakeService`; this controller only owns the preference.
final class KeepScreenOnController extends Notifier<bool> {
  /// The persisted key.
  static const String prefsKey = 'playback.keepScreenOn';

  @override
  bool build() {
    try {
      return StoragePrefs.getBool(prefsKey) ?? true;
    } on Object {
      return true;
    }
  }

  /// Whether the setting is on.
  bool get enabled => state;

  /// Stores the choice; players read it before taking the wakelock.
  set enabled(bool value) {
    state = value;
    unawaited(StoragePrefs.setBool(prefsKey, value));
  }
}

/// The screen-awake preference.
final keepScreenOnProvider = NotifierProvider<KeepScreenOnController, bool>(KeepScreenOnController.new);
