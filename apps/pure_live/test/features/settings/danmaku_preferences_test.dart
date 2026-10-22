import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/system/configuration/preferences/danmaku_preferences.dart';

/// The chat-list switches travel in the danmaku document: a field missing
/// from `toJson`, `copyWith` or `props` returns to its default silently.
void main() {
  test('the shipping answers: gifts in the chat, no membership cards, Top chat', () {
    const preferences = DanmakuPreferences();
    expect(preferences.chatShowGifts, isTrue);
    expect(preferences.superChatIncludesMembership, isFalse);
    expect(preferences.youtubeAllChat, isFalse);
  });

  test('the three switches survive the document', () {
    const before = DanmakuPreferences(chatShowGifts: false, superChatIncludesMembership: true, youtubeAllChat: true);
    final read = DanmakuPreferences.fromJson(before.toJson());
    expect(read.chatShowGifts, isFalse);
    expect(read.superChatIncludesMembership, isTrue);
    expect(read.youtubeAllChat, isTrue);
  });

  test('copyWith keeps the fields it does not touch', () {
    const before = DanmakuPreferences(barrageShowSender: false, chatShowGifts: false);
    final after = before.copyWith(youtubeAllChat: true);
    expect(after.youtubeAllChat, isTrue);
    expect(after.chatShowGifts, isFalse);
    expect(after.barrageShowSender, isFalse);
  });

  test('props carries the switches, so a write reaches the store', () {
    expect(const DanmakuPreferences().copyWith(chatShowGifts: false), isNot(equals(const DanmakuPreferences())));
  });
}
