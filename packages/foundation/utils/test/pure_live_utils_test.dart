// Module: test/pure_live_utils_test.dart
// Purpose: Barrel-level smoke test: every module is reachable through the package import alone.
// Author: liuchuancong
// Created: 2026-10-10
//
// Per-module suites live in test/<module>/. This file only proves the public surface is exported, which is
// the part a rename or a dropped export breaks.

import 'package:pure_live_utils/pure_live_utils.dart';
import 'package:test/test.dart';

void main() {
  group('barrel', () {
    test('test_async_isExportedFromThePackageBarrel', () async {
      final flight = SingleFlight<int>();
      expect(await flight.run('k', () async => 1), 1);
      expect(AsyncMemoizer<int>().length, 0);
      final once = AsyncOnce<int>();
      expect(await once.run('k', () async => 1), 1);
      final cancellation = CancellationToken();
      expect(cancellation.isCancelled, isFalse);
      cancellation.cancel();
      expect(cancellation.isCancelled, isTrue);
      final disposable = Disposer()..add(() {});
      disposable.dispose();
      expect(disposable.isDisposed, isTrue);
      expect(OperationGuard().isRunning, isFalse);
    });

    test('test_collections_areExportedFromThePackageBarrel', () {
      expect(groupBy(<int>[1, 2, 3], (value) => value.isEven), {
        false: <int>[1, 3],
        true: <int>[2],
      });
      expect(<int>[1, 1, 2].uniqueBy((value) => value), <int>[1, 2]);
      expect(<int>[3, 1].head, 3);
    });

    test('test_conversion_isExportedFromThePackageBarrel', () {
      expect(intFrom('42'), 42);
      expect(doubleFrom('1.5'), 1.5);
      expect(boolFrom(1), isTrue);
      expect(stringFrom(null), '');
      expect(jsonMapFrom(<String, Object?>{'a': 1})?['a'], 1);
      expect(stringListFrom(<Object?>['a', 'b']), <String>['a', 'b']);
    });

    test('test_equality_isExportedFromThePackageBarrel', () {
      expect(
        sameFieldList(
          <Object?>[
            1,
            <int>[2],
          ],
          <Object?>[
            1,
            <int>[2],
          ],
        ),
        isTrue,
      );
      expect(deepHash(<int>[1, 2]), deepHash(<int>[1, 2]));
    });

    test('test_errors_areExportedFromThePackageBarrel', () {
      final failure = UnexpectedFailure.from(StateError('inner'), context: 'resolver');
      expect(failure.toString(), contains('resolver reported an untyped failure'));
      expect(failure.cause, isA<StateError>());
    });

    test('test_identifiers_areExportedFromThePackageBarrel', () {
      // A separator join would make these two collide.
      expect(identityKey(<Object?>['a', 'bc']) == identityKey(<Object?>['ab', 'c']), isFalse);
      expect(normalizeToken('  Pure  Live '), 'pure live');
      expect(sameToken('Huya', 'huya'), isTrue);
    });

    test('test_math_isExportedFromThePackageBarrel', () {
      expect(ClosedInterval(0, 100).fractionOf(25), 0.25);
      expect(ClosedInterval(0, 100).clamp(140), 100);
    });

    test('test_numbers_areExportedFromThePackageBarrel', () {
      expect(clampInt(9, lower: 1, upper: 5), 5);
      expect(clampDouble(0.5, lower: 0, upper: 1), 0.5);
      expect(lerpDouble(0, 10, 0.25), 2.5);
      expect(roundTo(1.2345, decimals: 2), 1.23);
      expect(percentOf(3, 12), 25);
      expect(ByteSize.mib(2).humanReadable, '2.0 MiB');
      expect(ByteSize(1024).fitsWithin(ByteSize.megabyte), isTrue);
    });

    test('test_result_isExportedFromThePackageBarrel', () async {
      final results = <Result<int, String>>[const Result.ok(1), const Result.err('bad')];
      expect(results.partition().isAllOk, isFalse);
      expect(results.collect().isErr, isTrue);
      expect(captureResult<int, String>(() => 1, onFailure: (error) => '$error').isOk, isTrue);
      final chained = await Future<Result<int, String>>.value(
        const Result.ok(2),
      ).andThen((value) async => Result<int, String>.ok(value + 1));
      expect(chained.requireValue(), 3);
      final recovered = await Future<Result<int, String>>.value(
        const Result.err('bad'),
      ).recover((error) async => Result<int, String>.ok(0));
      expect(recovered.requireValue(), 0);
      final settled = await <Future<Result<int, String>>>[
        Future<Result<int, String>>.value(const Result.ok(1)),
      ].waitAll();
      expect(settled.values, <int>[1]);
    });

    test('test_strings_areExportedFromThePackageBarrel', () {
      expect('   a   b  '.collapsedWhitespace, 'a b');
      expect(redactHeaders(<String, String>{'Cookie': 'x'})['Cookie'], redactedPlaceholder);
      expect(redactQuery('https://x/y?token=1', sensitiveKeys: const <String>{'token'}), contains('token=***'));
    });

    test('test_types_areExportedFromThePackageBarrel', () {
      expect(const Unit(), const Unit());
      expect((<Object?>['s']).first.asOrNull<String>(), 's');
      expect((<Object?>[1]).first.asOrNull<String>(), isNull);
      expect(<Object?>[null].first.or('fallback'), 'fallback');
    });

    test('test_time_isExportedFromThePackageBarrel', () {
      final clock = FixedClock(DateTime.utc(2026, 10, 10));
      clock.advance(const Duration(minutes: 2));
      expect(clock().minute, 2);
      expect(const Duration(hours: 1, minutes: 20).asCompact, '1h 20m');
    });

    test('test_validation_isExportedFromThePackageBarrel', () {
      expect(requireNonBlank('  key  ', name: 'key'), 'key');
      expect(requireInRange(3, lower: 1, upper: 5, name: 'page'), 3);
      expect(requireNonNull<int>(4, name: 'value'), 4);
      expect(() => requireNonBlank(' ', name: 'key'), throwsArgumentError);
    });
  });
}
