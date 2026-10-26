import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;

/// Whether the app shows its startup mark before the shell.
///
/// The choice is read at boot, so changing it applies on the next start; the
/// splash overlay is owned by the root and never delays the first frame.
final class SplashSettingsController extends Notifier<bool> {
  /// The persisted key.
  static const String prefsKey = 'ui.splash';

  @override
  bool build() {
    try {
      return StoragePrefs.getBool(prefsKey) ?? true;
    } on Object {
      return true;
    }
  }

  /// Whether the startup mark is shown.
  bool get enabled => state;

  /// Stores the choice.
  set enabled(bool value) {
    state = value;
    unawaited(StoragePrefs.setBool(prefsKey, value));
  }
}

/// The startup-splash preference.
final splashSettingsProvider = NotifierProvider<SplashSettingsController, bool>(SplashSettingsController.new);
