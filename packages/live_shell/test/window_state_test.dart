import 'package:live_shell/live_shell.dart';
import 'package:test/test.dart';

void main() {
  const frame = WindowGeometry(frame: PixelRect(400, 200, 1200, 700), maximized: false, displayId: 'eDP-1');
  const maximised = WindowGeometry(frame: PixelRect(0, 0, 1920, 1040), maximized: true, displayId: 'eDP-1');

  group('WindowStateStore', () {
    test('writes are debounced into one', () async {
      final written = <WindowGeometry>[];
      WindowStateStore(
          save: (record) async => written.add(record),
          load: () async => null,
          debounce: const Duration(milliseconds: 40),
        )
        ..note(frame)
        ..note(frame.copyWith(frame: const PixelRect(410, 200, 1200, 700)))
        ..note(frame.copyWith(frame: const PixelRect(420, 200, 1200, 700)));
      expect(written, isEmpty, reason: 'a dragged border must not hit the disk per pixel');

      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(written, hasLength(1));
      expect(written.single.frame.left, 420, reason: 'the newest place wins');
    });

    test('a maximised frame is stored with the restore size, not the outer frame', () async {
      final written = <WindowGeometry>[];
      WindowStateStore(
          save: (record) async => written.add(record),
          load: () async => null,
          debounce: const Duration(milliseconds: 10),
        )
        ..note(frame)
        ..note(maximised);
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(written.last.maximized, isTrue);
      expect(
        written.last.frame,
        frame.frame,
        reason: 'the size the viewer dragged to survives; the next start must not open at 1920 wide',
      );
    });

    test('flush writes at once, and leaves nothing pending', () async {
      final written = <WindowGeometry>[];
      final store = WindowStateStore(
        save: (record) async => written.add(record),
        load: () async => null,
        debounce: const Duration(seconds: 30),
      )..note(frame);
      expect(written, isEmpty, reason: 'nothing is written before the quiet period ends');
      await store.flush();

      expect(written, hasLength(1));
      await store.flush();
      expect(written, hasLength(1), reason: 'nothing new to write');
    });

    test('a disabled store forgets what it had queued', () async {
      final written = <WindowGeometry>[];
      WindowStateStore(
          save: (record) async => written.add(record),
          load: () async => null,
          debounce: const Duration(milliseconds: 10),
        )
        ..note(frame)
        ..pause();
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(written, isEmpty, reason: 'a teardown resize is not worth remembering');
    });

    test("restore validates the remembered frame against today's displays", () async {
      final store = WindowStateStore(
        save: (_) async {},
        load: () async =>
            const WindowGeometry(frame: PixelRect(3000, 900, 1200, 700), maximized: false, displayId: 'DP-2'),
      );
      const builtIn = DisplayFrame(
        id: 'eDP-1',
        bounds: PixelRect(0, 0, 1920, 1080),
        workArea: PixelRect(0, 0, 1920, 1040),
      );

      final restored = await store.restore([builtIn]);

      expect(restored!.displayId, 'eDP-1');
      expect(isOnSomeDisplay(restored, [builtIn]), isTrue);
    });
  });

  group('background policy', () {
    test('revealing costs what the state says it costs', () {
      expect(resolveReveal(SurfaceState.visible), SurfaceAction.none);
      expect(resolveReveal(SurfaceState.hidden), SurfaceAction.reveal);
      expect(resolveReveal(SurfaceState.reclaimed), SurfaceAction.rebuild);
      expect(resolveReveal(SurfaceState.absent), SurfaceAction.rebuild);
    });

    test('a window on screen is hidden, never reclaimed', () {
      expect(resolveConceal(state: SurfaceState.visible, allowReclaim: true), SurfaceAction.hide);
      expect(resolveConceal(state: SurfaceState.hidden, allowReclaim: true), SurfaceAction.reclaim);
      expect(resolveConceal(state: SurfaceState.hidden, allowReclaim: false), SurfaceAction.none);
      expect(resolveConceal(state: SurfaceState.reclaimed, allowReclaim: true), SurfaceAction.none);
    });

    test('idle alone does not license reclaiming', () {
      bool reclaim({bool focused = false, bool busy = false, SurfaceState state = SurfaceState.hidden}) =>
          shouldReclaimForIdle(enabled: true, idleThresholdReached: true, focused: focused, busy: busy, state: state);

      expect(reclaim(), isTrue);
      expect(reclaim(focused: true), isFalse, reason: 'the viewer may be reading with the mouse still');
      expect(reclaim(busy: true), isFalse, reason: 'a recording in progress outranks the memory saving');
      expect(reclaim(state: SurfaceState.visible), isFalse);
    });

    test('a headless start builds nothing, and a restored session does not stay hidden', () {
      expect(resolveStartState(headless: true, startHidden: false, openedHiddenBySystem: false), SurfaceState.absent);
      expect(
        resolveStartState(headless: true, startHidden: false, openedHiddenBySystem: false, restoredSession: true),
        SurfaceState.absent,
        reason: 'a version print must not open a window on a machine with no display',
      );
      expect(resolveStartState(headless: false, startHidden: true, openedHiddenBySystem: false), SurfaceState.absent);
      expect(
        resolveStartState(headless: false, startHidden: true, openedHiddenBySystem: false, restoredSession: true),
        SurfaceState.visible,
      );
      expect(resolveStartState(headless: false, startHidden: false, openedHiddenBySystem: true), SurfaceState.absent);
    });
  });

  group('ReclaimCircuit', () {
    test('repairs are allowed up to the limit, then stop', () {
      final circuit = ReclaimCircuit(limit: 2);
      final now = DateTime(2026, 10, 12, 9);

      expect(circuit.allows(now), isTrue);
      circuit
        ..recordFailure(now)
        ..recordFailure(now.add(const Duration(seconds: 5)));

      expect(circuit.isTripped(now.add(const Duration(seconds: 6))), isTrue);
      expect(circuit.allows(now), isFalse);
    });

    test('failures age out, and a good rebuild clears the count', () {
      final circuit = ReclaimCircuit(limit: 2);
      final now = DateTime(2026, 10, 12, 9);
      circuit
        ..recordFailure(now)
        ..recordFailure(now);

      expect(circuit.allows(now.add(const Duration(minutes: 2))), isTrue, reason: 'the window moved on');
      circuit
        ..recordFailure(now)
        ..noteRecovered();

      expect(circuit.failureCount, 0);
      expect(circuit.allows(now), isTrue);
    });
  });

  group('anchorToCorner', () {
    const workArea = PixelRect(0, 0, 1920, 1040);

    test('a Mac popup sits under the menu bar, a Windows one above the taskbar', () {
      expect(
        anchorToCorner(workArea: workArea, width: 380, height: 200, topEdge: true),
        const PixelRect(1920 - 16 - 380, 16, 380, 200),
      );
      expect(
        anchorToCorner(workArea: workArea, width: 380, height: 200, topEdge: false),
        const PixelRect(1920 - 16 - 380, 1040 - 16 - 200, 380, 200),
      );
    });

    test("the height changing with the popup's phase keeps the same corner", () {
      final short = anchorToCorner(workArea: workArea, width: 380, height: 120, topEdge: false);
      final tall = anchorToCorner(workArea: workArea, width: 380, height: 300, topEdge: false);

      expect(short.right, tall.right);
      expect(short.bottom, tall.bottom);
    });
  });

  group('RenderFallbacks', () {
    test('defaults keep both the material and the GPU', () {
      const fallbacks = RenderFallbacks();

      expect(fallbacks.needsOpaqueSurface, isFalse);
      expect(fallbacks.engineArguments, isEmpty);
    });

    test('software rendering implies an opaque surface and the embedder switch', () {
      const fallbacks = RenderFallbacks(hardwareAcceleration: false);

      expect(fallbacks.needsOpaqueSurface, isTrue);
      expect(fallbacks.engineArguments, ['--enable-software-rendering']);
    });
  });
}
