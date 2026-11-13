import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;

/// The chat list is no longer configurable: these are the fixed values the
/// product ships with, and the settings rows for them are gone.
const int kChatListFontSizeFixed = 15;
const String kChatListLineSpacingFixed = 'standard';
const double kChatPanelWidthFixed = 360;

/// Whether platform gifts get a line in the room's chat list (the
/// reference's `showChatGifts`).
const String kChatShowGiftsKey = 'danmaku.showChatGifts';

/// Owns the gift-line switch; on by default, the reference's value.
final class ChatShowGiftsController extends Notifier<bool> {
  @override
  bool build() {
    try {
      return StoragePrefs.getBool(kChatShowGiftsKey) ?? true;
    } on Object {
      return true;
    }
  }

  /// Shows or hides gift lines and writes through.
  Future<void> set({required bool value}) async {
    state = value;
    try {
      await StoragePrefs.setBool(kChatShowGiftsKey, value);
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// The room chat's gift-line switch.
final chatShowGiftsProvider = NotifierProvider<ChatShowGiftsController, bool>(ChatShowGiftsController.new);

/// Whether the chat list keeps only valuable gifts (the reference's
/// `chatGiftsAboveTier`): free and cheap gifts stay out, and a combo shows
/// once it adds up.
const String kChatGiftsAboveTierKey = 'danmaku.chatGiftsAboveTier';

/// Owns the valuable-gifts switch; off by default, the reference's value.
final class ChatGiftsAboveTierController extends Notifier<bool> {
  @override
  bool build() {
    try {
      return StoragePrefs.getBool(kChatGiftsAboveTierKey) ?? false;
    } on Object {
      return false;
    }
  }

  Future<void> set({required bool value}) async {
    state = value;
    try {
      await StoragePrefs.setBool(kChatGiftsAboveTierKey, value);
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// The chat list's valuable-gifts switch.
final chatGiftsAboveTierProvider = NotifierProvider<ChatGiftsAboveTierController, bool>(
  ChatGiftsAboveTierController.new,
);

/// The room page's chat column width bounds, in px.
const double kChatPanelWidthMin = 280;
const double kChatPanelWidthMax = 520;

const String _kChatPanelWidthKey = 'danmaku.chatPanelWidth';

/// The width the wide layout starts from, and the one the seam's double-tap
/// puts back.
const double kChatPanelWidthDefault = 340;

/// Owns the room page's chat column width: the wide room layout gives the
/// chat this many px instead of its proportional share.
base class ChatPanelWidthController extends Notifier<double> {
  @override
  double build() {
    try {
      return (StoragePrefs.getDouble(_kChatPanelWidthKey) ?? kChatPanelWidthDefault).clamp(
        kChatPanelWidthMin,
        kChatPanelWidthMax,
      );
    } on Object {
      return kChatPanelWidthDefault;
    }
  }

  /// Shows [value] while the seam is dragged, without the write a pointer
  /// move does not need; the drag's end stores it through [set].
  void preview(double value) {
    state = value.clamp(kChatPanelWidthMin, kChatPanelWidthMax);
  }

  /// Stores the width, clamped to the bounds.
  Future<void> set(double value) async {
    final next = value.clamp(kChatPanelWidthMin, kChatPanelWidthMax);
    state = next;
    try {
      await StoragePrefs.setDouble(_kChatPanelWidthKey, next);
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// The room page's chat column width.
final chatPanelWidthProvider = NotifierProvider<ChatPanelWidthController, double>(ChatPanelWidthController.new);

/// Whether the wide room's chat column is folded away; the choice is
/// remembered for the next room.
const String kChatCollapsedKey = 'danmaku.chatCollapsed';

/// Owns the chat column's fold switch. The preference used to live in the
/// global playback settings under `playback.chatCollapsed`; the first read of
/// an empty key adopts that value and retires the old one, the way the
/// storage folders took over their own rows.
final class ChatCollapsedController extends Notifier<bool> {
  @override
  bool build() {
    try {
      final stored = StoragePrefs.getBool(kChatCollapsedKey);
      if (stored != null) return stored;
      final legacy = StoragePrefs.getBool('playback.chatCollapsed');
      if (legacy == null) return false;
      unawaited(_adoptLegacyChoice(legacy));
      return legacy;
    } on Object {
      return false;
    }
  }

  /// Folds or unfolds the chat column and writes through.
  Future<void> set({required bool value}) async {
    state = value;
    try {
      await StoragePrefs.setBool(kChatCollapsedKey, value);
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  /// Writes the adopted value under the room's own key and drops the old
  /// global one, so the choice is read from one place from the next start on.
  Future<void> _adoptLegacyChoice(bool legacy) async {
    try {
      await StoragePrefs.setBool(kChatCollapsedKey, legacy);
      await StoragePrefs.remove('playback.chatCollapsed');
    } on Object {
      // A closed store leaves the legacy read to do the same thing next start.
    }
  }
}

/// The wide room's chat-column fold switch.
final chatCollapsedProvider = NotifierProvider<ChatCollapsedController, bool>(ChatCollapsedController.new);

/// The chat panel's last-open tab, remembered for the next room (the store
/// keeps the tab's name; the panel owns the enum).
const String kChatTabKey = 'danmaku.chatTab';

/// Reads the stored tab's name, or null when none is there.
String? readChatTabName() {
  try {
    return StoragePrefs.getString(kChatTabKey);
  } on Object {
    return null;
  }
}

/// Writes the tab's name through.
Future<void> writeChatTabName(String name) async {
  try {
    await StoragePrefs.setString(kChatTabKey, name);
  } on Object {
    // A preference; a closed store loses it.
  }
}
