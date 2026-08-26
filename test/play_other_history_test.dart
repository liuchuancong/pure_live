import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/modules/live_play/dialogs/play_other.dart';

void main() {
  test('watch history card formats a complete local date and time', () {
    final watched = DateTime(2026, 8, 26, 4, 5);
    expect(formatHistoryWatchedAt(watched.millisecondsSinceEpoch), '2026-08-26 04:05');
  });
}
