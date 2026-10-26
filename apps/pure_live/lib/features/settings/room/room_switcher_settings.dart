import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;

/// How the room switcher shows its rooms (the reference's `roomSwitcherLayout`,
/// written from the panel's style button): small cards in a grid (3.x's
/// default) or rows with a 16:9 cover.
enum RoomSwitcherLayout {
  grid('grid'),
  list('list');

  RoomSwitcherLayout(this.id);

  /// The stored value.
  final String id;

  /// The layout stored as [id]; the grid for anything else.
  static RoomSwitcherLayout of(String? value) => value == list.id ? list : grid;
}

const String _layoutKey = 'playback.roomSwitcherLayout';
const String _swipeKey = 'playback.portraitFullscreenSwipeSwitch';

/// Owns the switcher's layout choice.
final class RoomSwitcherLayoutController extends Notifier<RoomSwitcherLayout> {
  @override
  RoomSwitcherLayout build() {
    try {
      return RoomSwitcherLayout.of(StoragePrefs.getString(_layoutKey));
    } on Object {
      return RoomSwitcherLayout.grid;
    }
  }

  /// Writes [layout]; the panel rebuilds on the next frame.
  Future<void> set(RoomSwitcherLayout layout) async {
    state = layout;
    try {
      await StoragePrefs.setString(_layoutKey, layout.id);
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  /// Flips between the two styles, as the panel's button does.
  Future<void> toggle() => set(state == RoomSwitcherLayout.grid ? RoomSwitcherLayout.list : RoomSwitcherLayout.grid);
}

/// The switcher's layout choice.
final roomSwitcherLayoutProvider = NotifierProvider<RoomSwitcherLayoutController, RoomSwitcherLayout>(
  RoomSwitcherLayoutController.new,
);

/// Owns the portrait-fullscreen swipe switch (the reference's
/// `portraitFullscreenSwipeSwitch`, off by default).
final class PortraitSwipeSwitchController extends Notifier<bool> {
  @override
  bool build() {
    try {
      return StoragePrefs.getBool(_swipeKey) ?? false;
    } on Object {
      return false;
    }
  }

  /// Writes the switch through.
  Future<void> set({required bool value}) async {
    state = value;
    try {
      await StoragePrefs.setBool(_swipeKey, value);
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// The portrait-fullscreen swipe switch.
final portraitSwipeSwitchProvider = NotifierProvider<PortraitSwipeSwitchController, bool>(
  PortraitSwipeSwitchController.new,
);
