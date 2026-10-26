import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;

/// Whether the TV shell always shows the sidebar's names instead of the
/// icon rail (the reference's `tvMenuAlwaysExpanded`). Off by default.
const String kTvMenuExpandedKey = 'sides.tv.menuAlwaysExpanded';

/// Owns the TV menu switch.
final class TvMenuExpandedController extends Notifier<bool> {
  @override
  bool build() {
    try {
      return StoragePrefs.getBool(kTvMenuExpandedKey) ?? false;
    } on Object {
      return false;
    }
  }

  Future<void> set({required bool value}) async {
    state = value;
    try {
      await StoragePrefs.setBool(kTvMenuExpandedKey, value);
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// The TV menu's always-expanded switch.
final tvMenuExpandedProvider = NotifierProvider<TvMenuExpandedController, bool>(
  TvMenuExpandedController.new,
);
