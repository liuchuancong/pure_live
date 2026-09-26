import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

import 'package:media_kit/src/player/native/core/native_event_loop.dart';
import 'package:media_kit_lifecycle_test/fixture.dart' as fixture;
import 'package:test/test.dart';

Future<void> waitUntil(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Native teardown did not finish');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

Future<void> abandonedPlayer((SendPort, int) args) async {
  final loop = await NativeEventLoop.create(fixture.openFixture(), (_) async {
    if (args.$2 == 2) {
      args.$1.send(true);
      await Completer<void>().future;
    }
  });
  fixture.startStress(loop.handle.cast());
  if (args.$2 == 1) unawaited(loop.dispose());
  if (args.$2 != 2) args.$1.send(true);
  // The parent kills this isolate. No Dart finally/dispose gets to run.
}

void main() {
  tearDown(() {
    fixture.blockDestroy(0);
    expect(fixture.violations(), 0);
  });

  test('async event borrows remain valid until handler completes', () async {
    final entered = Completer<void>();
    final resume = Completer<void>();
    final before = fixture.destroyed();
    final loop = await NativeEventLoop.create(fixture.openFixture(), (
      event,
    ) async {
      final value = event.ref.data.cast<Int32>().value;
      entered.complete();
      await resume.future;
      expect(event.ref.data.cast<Int32>().value, value);
    });
    fixture.emit(loop.handle.cast());
    await entered.future;
    final polls = fixture.waits(loop.handle.cast());
    fixture.emit(loop.handle.cast());
    final done = loop.dispose();
    expect(identical(done, loop.dispose()), isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(fixture.waits(loop.handle.cast()), polls);
    expect(fixture.destroyed(), before);
    resume.complete();
    await done;
    expect(fixture.destroyed(), before + 1);
  });

  test('dispose waits for native destruction acknowledgement', () async {
    fixture.blockDestroy(1);
    final before = fixture.destroyed();
    final loop = await NativeEventLoop.create(
      fixture.openFixture(),
      (_) async {},
    );
    var complete = false;
    final done = loop.dispose().then((_) => complete = true);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(complete, isFalse);
    expect(fixture.destroyed(), before);
    fixture.blockDestroy(0);
    await done;
    expect(fixture.destroyed(), before + 1);
  });

  test('initialization failure destroys its acquired native handle', () async {
    final before = fixture.destroyed();
    await expectLater(
      NativeEventLoop.create(
        fixture.openFixture(),
        (_) async {},
        options: {'fail-initialize': 'yes'},
      ),
      throwsStateError,
    );
    expect(fixture.destroyed(), before + 1);
  });

  for (final mode in [0, 1, 2]) {
    test('isolate exit finalizes native ownership (mode=$mode)', () async {
      for (var iteration = 0; iteration < 50; iteration++) {
        final before = fixture.destroyed();
        fixture.blockDestroy(1);
        final ready = ReceivePort();
        final exited = ReceivePort();
        final errors = ReceivePort();
        final errorsSeen = <dynamic>[];
        final subscription = errors.listen(errorsSeen.add);
        final isolate = await Isolate.spawn(
          abandonedPlayer,
          (ready.sendPort, mode),
          onExit: exited.sendPort,
          onError: errors.sendPort,
          errorsAreFatal: true,
        );
        await ready.first.timeout(const Duration(seconds: 10));
        isolate.kill(priority: Isolate.immediate);
        await exited.first.timeout(const Duration(seconds: 10));
        fixture.blockDestroy(0);
        await waitUntil(() => fixture.destroyed() == before + 1);
        await subscription.cancel();
        ready.close();
        exited.close();
        errors.close();
        expect(errorsSeen, isEmpty);
        // Recreate a player in the surviving process, as on engine restart.
        final next = await NativeEventLoop.create(
          fixture.openFixture(),
          (_) async {},
        );
        fixture.startStress(next.handle.cast());
        await next.dispose();
        expect(fixture.destroyed(), before + 2);
      }
    });
  }
}
