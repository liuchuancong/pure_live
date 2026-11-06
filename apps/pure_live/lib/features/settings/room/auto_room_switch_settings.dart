import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;

/// The stored key under `playback.autoSwitchLiveFollows`.
const String _autoSwitchKey = 'playback.autoSwitchLiveFollows';

/// Owns 「当前房间不可看时自动换到下一个关注」: when the room page or a
/// multi-view pane's playback fails with a failure the platform itself
/// stated (a broadcast that ended, content it refuses to serve), the surface
/// walks the follows for the next live room. Off is the default — a viewer
/// who picked a room picked that room.
///
/// The preference is read per evaluation and watched by the surfaces, so a
/// flip in the settings page bites the very next failure without a reopen.
final class AutoRoomSwitchController extends Notifier<bool> {
  @override
  bool build() {
    try {
      return StoragePrefs.getBool(_autoSwitchKey) ?? false;
    } on Object {
      return false;
    }
  }

  /// Stores the choice, writing it through.
  Future<void> set({required bool value}) async {
    state = value;
    try {
      await StoragePrefs.setBool(_autoSwitchKey, value);
    } on Object {
      // The choice is a preference; a closed store loses it.
    }
  }
}

/// Whether an unwatchable room automatically moves to the next live follow.
final autoRoomSwitchProvider = NotifierProvider<AutoRoomSwitchController, bool>(AutoRoomSwitchController.new);
