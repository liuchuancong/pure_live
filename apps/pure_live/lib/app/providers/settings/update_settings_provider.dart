import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;

/// Whether the app checks the release feed once at start.
///
/// The check is silent: its result lands in `versionCheckProvider`, which the
/// About page already renders. A failed automatic check never interrupts the
/// viewer; the About page keeps the manual check available.
final class UpdateSettingsController extends Notifier<bool> {
  /// The persisted key.
  static const String prefsKey = 'updates.autoCheck';

  @override
  bool build() {
    try {
      return StoragePrefs.getBool(prefsKey) ?? true;
    } on Object {
      return true;
    }
  }

  /// Whether the automatic check is on.
  bool get enabled => state;

  /// Stores the choice.
  set enabled(bool value) {
    state = value;
    unawaited(StoragePrefs.setBool(prefsKey, value));
  }
}

/// The automatic update-check preference.
final updateSettingsProvider = NotifierProvider<UpdateSettingsController, bool>(UpdateSettingsController.new);
