import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/system/configuration/preferences/feed_preferences.dart';

/// The feed document's round trip and its copy, at the field level: a field
/// missing from `toJson`, `copyWith` or `props` loses the viewer's answer
/// silently, because the document then reads as the default.
void main() {
  test('the grid gaps survive the document', () {
    final stored = const FeedPreferences(crossAxisSpacing: 14, mainAxisSpacing: 2).toJson();
    final read = FeedPreferences.fromJson(stored);
    expect(read.crossAxisSpacing, 14);
    expect(read.mainAxisSpacing, 2);
  });

  test('a document without the gaps reads the reference default', () {
    final read = FeedPreferences.fromJson(const {});
    expect(read.crossAxisSpacing, 6);
    expect(read.mainAxisSpacing, 6);
  });

  test('copyWith keeps the fields it does not touch', () {
    const before = FeedPreferences(
      liveAlertTagIds: ['tag-a'],
      preferredSiteId: 'douyu',
      showUnplayableInDiscover: true,
      refreshConcurrency: 6,
    );
    final after = before.copyWith(crossAxisSpacing: 10);
    expect(after.crossAxisSpacing, 10);
    expect(after.liveAlertTagIds, ['tag-a']);
    expect(after.preferredSiteId, 'douyu');
    expect(after.showUnplayableInDiscover, isTrue);
    expect(after.refreshConcurrency, 6);
  });

  test('props carries the gaps, so a write reaches the store', () {
    expect(const FeedPreferences().copyWith(mainAxisSpacing: 9), isNot(equals(const FeedPreferences())));
  });
}
