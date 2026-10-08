// Module: test/text_and_time_test.dart
// Purpose: Verify the string, URL, redaction and clock helpers from lib/src/strings.dart and lib/src/time.dart.
// Author: liuchuancong
// Created: 2026-10-08
import 'package:pure_live_utils/pure_live_utils.dart';
import 'package:test/test.dart';

void main() {
  group('StringExtras', () {
    test('test_nullIfBlank_emptyString_returnsNull', () {
      expect(''.nullIfBlank, isNull);
      expect('   '.nullIfBlank, isNull);
    });

    test('test_nullIfBlank_realValue_returnsItUnchanged', () {
      expect(' cctv '.nullIfBlank, ' cctv ');
    });

    test('test_collapsedWhitespace_multipleRuns_collapseToOneSpace', () {
      expect('  a\t\tb \n c  '.collapsedWhitespace, 'a b c');
    });

    test('test_truncate_longerThanLimit_addsEllipsisWithinBudget', () {
      expect('abcdefghij'.truncate(5), 'abcd…');
      expect('abc'.truncate(5), 'abc');
    });

    test('test_truncate_limitShorterThanEllipsis_cutsHard', () {
      // Boundary: a limit that cannot fit the ellipsis must still return exactly limit characters.
      expect('abcdefghij'.truncate(1), 'a');
      expect('abcdefghij'.truncate(0), 'abcdefghij');
      expect('abcdefghij'.truncate(-3), 'abcdefghij');
    });
  });

  group('urls', () {
    test('test_isHttpUrl_validAndInvalid_agree', () {
      expect(isHttpUrl('https://example.com/a'), isTrue);
      expect(isHttpUrl('http://example.com'), isTrue);
      expect(isHttpUrl('ftp://example.com'), isFalse);
      expect(isHttpUrl('example.com'), isFalse);
      expect(isHttpUrl('https://'), isFalse);
      expect(isHttpUrl('not a url'), isFalse);
    });

    test('test_hostOf_mixedCase_returnsLowerCase', () {
      expect(hostOf('https://API.Example.COM/path'), 'api.example.com');
      expect(hostOf('relative/path'), isNull);
    });
  });

  group('redaction', () {
    test('test_redactHeaders_sensitiveNamesCaseInsensitive_areMasked', () {
      final redacted = redactHeaders(<String, String>{
        'Authorization': 'Bearer secret',
        'cookie': 'a=1',
        'X-API-KEY': 'k',
        'Referer': 'https://example.com/',
      });

      expect(redacted['Authorization'], redactedPlaceholder);
      expect(redacted['cookie'], redactedPlaceholder);
      expect(redacted['X-API-KEY'], redactedPlaceholder);
      expect(redacted['Referer'], 'https://example.com/');
    });

    test('test_redactHeaders_emptyInput_returnsEmpty', () {
      expect(redactHeaders(<String, String>{}), isEmpty);
    });

    test('test_redactQuery_signedUrl_hidesTokenKeepsExpiry', () {
      final clean = redactQuery('https://example.com/v.m3u8?token=abc&expires=170');

      expect(clean, contains('token=***'));
      expect(clean, isNot(contains('abc')));
      expect(clean, contains('expires=170'));
    });

    test('test_redactQuery_urlWithoutQuery_isReturnedUnchanged', () {
      expect(redactQuery('https://example.com/live'), 'https://example.com/live');
    });
  });

  group('clock and durations', () {
    test('test_fixedClock_advance_movesTimeOnlyWhenTold', () {
      final clock = FixedClock(DateTime.utc(2026, 10, 8, 12));

      expect(clock(), DateTime.utc(2026, 10, 8, 12));
      clock.advance(const Duration(minutes: 5));
      expect(clock.now, DateTime.utc(2026, 10, 8, 12, 5));
    });

    test('test_fixedClock_setToLocalValue_isNormalizedToUtc', () {
      final local = DateTime(2026, 10, 8, 6);
      final clock = FixedClock(local);

      expect(clock.now.isUtc, isTrue);
      expect(clock.now, local.toUtc());
    });

    test('test_clock_typedef_acceptsPlainFunction', () {
      final Clock reading = systemClock;

      expect(reading().isUtc, isTrue);
    });

    test('test_formatDurationHms_underOneHour_omitsHours', () {
      expect(formatDurationHms(const Duration(minutes: 4, seconds: 5)), '4:05');
      expect(formatDurationHms(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
      expect(formatDurationHms(Duration.zero), '0:00');
    });

    test('test_formatDurationCompact_twoDigitsDropsSeconds', () {
      expect(formatDurationCompact(const Duration(hours: 1, minutes: 20)), '1h 20m');
      expect(formatDurationCompact(const Duration(seconds: 45)), '45s');
      expect(formatDurationCompact(Duration.zero), '0s');
    });
  });
}
