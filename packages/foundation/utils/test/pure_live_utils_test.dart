// Module: test/pure_live_utils_test.dart
// Purpose: Barrel-level smoke test: the five modules are reachable through the package import alone.
// Author: liuchuancong
// Created: 2026-10-10
//
// Per-module suites live in test/<module>/. This file only proves the public surface is exported, which is
// the part a rename breaks.

import 'package:pure_live_utils/pure_live_utils.dart';
import 'package:test/test.dart';

void main() {
  group('barrel', () {
    test('test_async_tools_areExportedFromThePackageBarrel', () async {
      final flight = SingleFlight<int>();
      expect(await flight.run('k', () async => 1), 1);
      expect(const AsyncMemoizer<int>().length, 0);
    });

    test('test_collections_areExportedFromThePackageBarrel', () {
      expect(groupBy(<int>[1, 2, 3], (value) => value.isEven), {false: <int>[1, 3], true: <int>[2]});
      expect(<int>[1, 1, 2].uniqueBy((value) => value), <int>[1, 2]);
    });

    test('test_result_isExportedFromThePackageBarrel', () {
      final results = <Result<int, String>>[const Result.ok(1), const Result.err('bad')];
      expect(results.partition().isAllOk, isFalse);
    });

    test('test_strings_areExportedFromThePackageBarrel', () {
      expect('   a   b  '.collapsedWhitespace, 'a b');
      expect(redactHeaders(<String, String>{'Cookie': 'x'})['Cookie'], redactedPlaceholder);
    });

    test('test_time_isExportedFromThePackageBarrel', () {
      final clock = FixedClock(DateTime.utc(2026, 10, 10));
      clock.advance(const Duration(minutes: 2));
      expect(clock().minute, 2);
      expect(const Duration(hours: 1, minutes: 20).asCompact, '1h 20m');
    });
  });
}
