// The live-alert coverage rule, pinned: no chosen tag covers every follow,
// a chosen tag covers only the follows carrying one of them.
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/features/follow/live_alert_rules.dart';

void main() {
  test('no chosen tag covers every follow', () {
    expect(alertCoversRoom(const [], const []), isTrue);
    expect(alertCoversRoom(const [], const ['group-a']), isTrue);
  });

  test('a covered tag raises the notice', () {
    expect(alertCoversRoom(const ['group-a'], const ['group-a', 'group-b']), isTrue);
  });

  test('a follow without a covered tag stays quiet', () {
    expect(alertCoversRoom(const ['group-a'], const ['group-b']), isFalse);
    expect(alertCoversRoom(const ['group-a'], const []), isFalse);
  });
}
