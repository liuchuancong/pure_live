import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;

/// Whether the room's chat list names who sent each line (the reference's
/// `showChatNames`). Off, only the message itself is drawn; the long-press
/// actions still know the sender.
const String kChatNamesKey = 'danmaku.chatNames';

/// Owns that switch.
final class ChatNamesController extends Notifier<bool> {
  @override
  bool build() {
    try {
      return StoragePrefs.getBool(kChatNamesKey) ?? true;
    } on Object {
      return true;
    }
  }

  /// Flips the sender names and writes through.
  Future<void> set({required bool value}) async {
    state = value;
    try {
      await StoragePrefs.setBool(kChatNamesKey, value);
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// The room chat's sender-name switch.
final chatNamesProvider = NotifierProvider<ChatNamesController, bool>(ChatNamesController.new);

/// The room chat list's look: compact lines or one card per message.
const String kChatListStyleKey = 'danmaku.list.style';

/// Owns the list style.
final class ChatListStyleController extends Notifier<String> {
  @override
  String build() {
    try {
      final value = StoragePrefs.getString(kChatListStyleKey);
      return value == 'card' ? 'card' : 'compact';
    } on Object {
      return 'compact';
    }
  }

  Future<void> set(String value) async {
    final next = value == 'card' ? 'card' : 'compact';
    state = next;
    try {
      await StoragePrefs.setString(kChatListStyleKey, next);
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// The room chat's list style.
final chatListStyleProvider = NotifierProvider<ChatListStyleController, String>(ChatListStyleController.new);

/// The room chat's font size; 0 follows the theme.
const String kChatListFontSizeKey = 'danmaku.list.fontSize';

/// Owns the list font size.
final class ChatListFontSizeController extends Notifier<int> {
  @override
  int build() {
    try {
      final value = StoragePrefs.getInt(kChatListFontSizeKey) ?? 0;
      return value >= 12 && value <= 22 ? value : 0;
    } on Object {
      return 0;
    }
  }

  Future<void> set(int value) async {
    final next = value >= 12 && value <= 22 ? value : 0;
    state = next;
    try {
      await StoragePrefs.setInt(kChatListFontSizeKey, next);
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// The room chat's font size.
final chatListFontSizeProvider = NotifierProvider<ChatListFontSizeController, int>(
  ChatListFontSizeController.new,
);

/// The room chat's line spacing: compact / standard / loose.
const String kChatListLineSpacingKey = 'danmaku.list.lineSpacing';

/// Owns the line spacing.
final class ChatListLineSpacingController extends Notifier<String> {
  @override
  String build() {
    try {
      final value = StoragePrefs.getString(kChatListLineSpacingKey);
      return const {'compact', 'standard', 'loose'}.contains(value) ? value! : 'standard';
    } on Object {
      return 'standard';
    }
  }

  Future<void> set(String value) async {
    final next = const {'compact', 'standard', 'loose'}.contains(value) ? value : 'standard';
    state = next;
    try {
      await StoragePrefs.setString(kChatListLineSpacingKey, next);
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// The room chat's line spacing.
final chatListLineSpacingProvider = NotifierProvider<ChatListLineSpacingController, String>(
  ChatListLineSpacingController.new,
);

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
