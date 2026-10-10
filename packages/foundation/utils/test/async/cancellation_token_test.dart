// Module: test/async/cancellation_token_test.dart
// Purpose: Pins the token's one-way flip, late-listener delivery and the
// throw helper.

import 'package:pure_live_utils/pure_live_utils.dart';
import 'package:test/test.dart';

void main() {
  test('test_cancellationToken_cancelFlipsOnce', () {
    var fired = 0;
    final token = CancellationToken()..addListener(() => fired++);
    expect(token.isCancelled, isFalse);

    token.cancel();
    token.cancel();
    expect(token.isCancelled, isTrue);
    expect(fired, 1);
  });

  test('test_cancellationToken_lateListenerFiresImmediately', () {
    final token = CancellationToken()..cancel();
    var fired = 0;
    token.addListener(() => fired++);
    expect(fired, 1);
  });

  test('test_cancellationToken_throwIfCancelled_throwsOnlyAfterCancel', () {
    final token = CancellationToken();
    expect(token.throwIfCancelled, returnsNormally);
    token.cancel();
    expect(token.throwIfCancelled, throwsA(isA<OperationCancelledException>()));
  });
}
