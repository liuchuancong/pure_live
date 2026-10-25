import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;

/// The shell's entry toggles (the reference's navigation-bar controls), persisted
/// under `nav.*` so the sidebar and the settings row agree from the first
/// frame.
final class ShowMultiviewController extends Notifier<bool> {
  @override
  bool build() {
    try {
      return StoragePrefs.getBool('nav.multiview') ?? true;
    } on Object {
      return true;
    }
  }

  /// Shows or hides the multi-view entry.
  Future<void> set({required bool value}) async {
    state = value;
    try {
      await StoragePrefs.setBool('nav.multiview', value);
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// Whether the sidebar offers the multi-view entry.
final showMultiviewProvider = NotifierProvider<ShowMultiviewController, bool>(ShowMultiviewController.new);
