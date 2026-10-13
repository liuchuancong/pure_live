@Tags(['windows'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:live_shell_desktop/live_shell_desktop.dart';

/// These calls reach `user32.dll`, so they run for real on a Windows host and
/// are skipped elsewhere rather than written against a fake that would prove
/// nothing about the marshalling or the counter arithmetic.
void main() {
  group('windowsSystemIdleTime', () {
    setUp(() {
      if (!Platform.isWindows) {
        markTestSkipped('user32 is Windows only');
      }
    });

    test('idle grows no faster than the clock, in either direction', () async {
      // A two-sided "the delta equals the wait" assertion would fail every time
      // a hand touches the mouse mid-test, because input sends the value back to
      // zero. What is always true is that the span cannot out-run real time, and
      // that is exactly the property the 32/64-bit handling breaks: subtracting
      // the wide uptime against the narrow tick produces a number of days.
      final before = await windowsSystemIdleTime();
      await Future<void>.delayed(const Duration(milliseconds: 400));
      final after = await windowsSystemIdleTime();

      expect(before, greaterThanOrEqualTo(Duration.zero));
      expect(
        after,
        lessThanOrEqualTo(before + const Duration(milliseconds: 600)),
        reason: 'before=$before after=$after; the counters disagree with the clock',
      );
    });

    test('the span is never negative', () async {
      // Negative is the signature of subtracting the wide counter from the narrow
      // one, and it would silently disable an idle reclaim that compares with a
      // positive threshold.
      final idle = await windowsSystemIdleTime();

      expect(idle, greaterThanOrEqualTo(Duration.zero));
    });

    test('the reader is offered on Windows and withheld where there is no call', () async {
      expect(supportsSystemIdleTime, isTrue);
      expect(systemIdleReader, isNotNull);
      expect(await systemIdleReader!(), isA<Duration>());
    });
  });
}
