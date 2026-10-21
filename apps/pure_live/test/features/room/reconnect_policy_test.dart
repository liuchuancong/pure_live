// The auto-reconnect ladder, pinned: the wait doubles from the first delay,
// stops at the ceiling, and the attempt budget is bounded.
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/features/room/reconnect_policy.dart';

void main() {
  const policy = ReconnectPolicy();

  test('the first attempt waits the first delay', () {
    expect(policy.delayFor(1), const Duration(seconds: 2));
  });

  test('the wait doubles per attempt', () {
    expect(policy.delayFor(2), const Duration(seconds: 4));
    expect(policy.delayFor(3), const Duration(seconds: 8));
    expect(policy.delayFor(4), const Duration(seconds: 16));
  });

  test('the wait stops at the ceiling', () {
    expect(policy.delayFor(5), const Duration(seconds: 30));
    expect(policy.delayFor(9), const Duration(seconds: 30));
  });

  test('the budget is bounded and 1-based', () {
    expect(policy.allows(0), isFalse);
    expect(policy.allows(1), isTrue);
    expect(policy.allows(policy.maxAttempts), isTrue);
    expect(policy.allows(policy.maxAttempts + 1), isFalse);
  });

  test('a custom ladder keeps its own numbers', () {
    const custom = ReconnectPolicy(maxAttempts: 2, firstDelay: Duration(seconds: 5), maxDelay: Duration(seconds: 6));
    expect(custom.delayFor(1), const Duration(seconds: 5));
    expect(custom.delayFor(2), const Duration(seconds: 6));
    expect(custom.allows(3), isFalse);
  });
}
