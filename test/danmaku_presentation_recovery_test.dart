import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/modules/live_play/controllers/danmaku_presentation_recovery.dart';

void main() {
  test('PiP return recovery waits until compact presentation has actually ended', () async {
    var blocked = true;
    var recoveries = 0;
    final coordinator = DanmakuPresentationRecovery(
      isBlocked: () => blocked,
      canRecover: () => true,
      recover: () async {
        recoveries++;
      },
      settleDelay: const Duration(milliseconds: 2),
      retryDelay: const Duration(milliseconds: 3),
    );
    addTearDown(coordinator.dispose);

    coordinator.request();
    await Future<void>.delayed(const Duration(milliseconds: 8));
    expect(recoveries, 0, reason: 'a native PiP transition must not consume and lose the recovery request');

    blocked = false;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(recoveries, 1);
  });

  test('multiple return signals before the settle delay coalesce into one reconnect', () async {
    var recoveries = 0;
    final coordinator = DanmakuPresentationRecovery(
      isBlocked: () => false,
      canRecover: () => true,
      recover: () async {
        recoveries++;
      },
      settleDelay: const Duration(milliseconds: 5),
      retryDelay: const Duration(milliseconds: 2),
    );
    addTearDown(coordinator.dispose);

    coordinator.request();
    coordinator.request();
    await Future<void>.delayed(const Duration(milliseconds: 12));

    expect(recoveries, 1);
  });

  test('a new PiP return during reconnect is replayed after the active operation', () async {
    final firstRecovery = Completer<void>();
    var recoveries = 0;
    final coordinator = DanmakuPresentationRecovery(
      isBlocked: () => false,
      canRecover: () => true,
      recover: () {
        recoveries++;
        return recoveries == 1 ? firstRecovery.future : Future<void>.value();
      },
      settleDelay: const Duration(milliseconds: 2),
      retryDelay: const Duration(milliseconds: 2),
    );
    addTearDown(coordinator.dispose);

    coordinator.request();
    await Future<void>.delayed(const Duration(milliseconds: 6));
    expect(recoveries, 1);

    coordinator.request();
    await Future<void>.delayed(const Duration(milliseconds: 6));
    expect(recoveries, 1, reason: 'socket stop/start operations must stay serialized');

    firstRecovery.complete();
    await Future<void>.delayed(const Duration(milliseconds: 8));
    expect(recoveries, 2, reason: 'the second presentation return must not be dropped');
  });
}
