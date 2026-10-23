import 'dart:async';

import 'package:live_platform/live_platform.dart' show PlatformKind;
import 'package:live_shell/live_shell.dart';
import 'package:test/test.dart';

void main() {
  group('IdleWatcher', () {
    test('one idle period is reported once, however many polls see it', () async {
      var reports = 0;
      final watcher = IdleWatcher(
        read: () async => const Duration(minutes: 5),
        threshold: const Duration(minutes: 1),
        interval: const Duration(milliseconds: 10),
        onIdle: (_) => reports++,
      )..start();
      addTearDown(watcher.stop);

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(reports, 1, reason: 'a shell told twice would try to destroy the same window twice');
      expect(watcher.hasReported, isTrue);
    });

    test('activity in between arms the next crossing again', () async {
      var idle = const Duration(minutes: 5);
      var reports = 0;
      final watcher = IdleWatcher(
        read: () async => idle,
        threshold: const Duration(minutes: 1),
        interval: const Duration(milliseconds: 10),
        onIdle: (_) => reports++,
      )..start();
      addTearDown(watcher.stop);

      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(reports, 1);

      // The viewer comes back and leaves again: a second period, a second report.
      idle = Duration.zero;
      await Future<void>.delayed(const Duration(milliseconds: 60));
      idle = const Duration(minutes: 5);
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(reports, 2);
    });

    test('noteActivity re-arms without waiting to see a below-threshold read', () async {
      var reports = 0;
      final watcher = IdleWatcher(
        read: () async => const Duration(minutes: 5),
        threshold: const Duration(minutes: 1),
        interval: const Duration(milliseconds: 10),
        onIdle: (_) => reports++,
      )..start();
      addTearDown(watcher.stop);

      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(reports, 1);

      // The shell revealed the window: that is activity, even though the reader
      // (a keyboard/mouse clock we cannot reset) still reports the old idle span.
      watcher.noteActivity();
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(reports, 2);
    });

    test('a slow reader does not pile up one pending read per tick', () async {
      var reads = 0;
      var ticks = 0;
      // One read that outlives the whole observation window: the guard means the
      // second, third, … ticks must all be dropped, so `reads` stays at one
      // while `ticks` counts the polls that fired. A short delay would let two
      // reads complete and prove nothing about the overlap.
      final watcher = IdleWatcher(
        read: () async {
          reads++;
          await Future<void>.delayed(const Duration(milliseconds: 400));
          return const Duration(minutes: 5);
        },
        threshold: const Duration(minutes: 1),
        interval: const Duration(milliseconds: 10),
      )..start();
      addTearDown(watcher.stop);

      await Future<void>.delayed(const Duration(milliseconds: 150));
      ticks = (150 / 10).round();

      expect(reads, 1, reason: '$ticks ticks elapsed and only one read was allowed in flight');
    });

    test('a failed read is reported and retried, not fatal', () async {
      final errors = <Object>[];
      var attempt = 0;
      var reports = 0;
      final watcher = IdleWatcher(
        read: () async {
          attempt++;
          if (attempt == 1) {
            throw StateError('the idle query is unavailable on this session');
          }
          return const Duration(minutes: 5);
        },
        threshold: const Duration(minutes: 1),
        interval: const Duration(milliseconds: 10),
        onIdle: (_) => reports++,
        onError: (error, _) => errors.add(error),
      )..start();
      addTearDown(watcher.stop);

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(errors, hasLength(1));
      expect(reports, 1, reason: 'one bad poll must not disable reclaim for the rest of the session');
    });

    test('stop ends it', () async {
      var reports = 0;
      IdleWatcher(
          read: () async => const Duration(minutes: 5),
          threshold: const Duration(minutes: 1),
          interval: const Duration(milliseconds: 10),
          onIdle: (_) => reports++,
        )
        ..start()
        ..stop();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(reports, 0);
    });
  });

  group('DesktopShell with an idle reader', () {
    test('the clock reaching the threshold destroys a hidden, unfocused interface', () async {
      final window = _ShellWindow();
      final shell = DesktopShell(
        platform: PlatformKind.windows,
        window: window,
        tray: _WorkingTray(),
        settings: () => const ShellSettings(
          reclaimWhenIdle: true,
          idleReclaimAfter: Duration(milliseconds: 30),
          idlePollInterval: Duration(milliseconds: 10),
        ),
        exit: () async {},
        idle: () async => const Duration(hours: 1),
        rebuildWindow: () async {},
      );
      await shell.start();
      await shell.conceal();
      window
        ..focused = false
        ..calls.clear();

      await _until(() => shell.phase == ShellPhase.reclaimed);

      expect(window.calls, contains('destroy'));
      await shell.dispose();
    });

    test('the same clock does nothing while something is recording', () async {
      final window = _ShellWindow();
      final shell = DesktopShell(
        platform: PlatformKind.windows,
        window: window,
        tray: _WorkingTray(),
        settings: () => const ShellSettings(
          reclaimWhenIdle: true,
          idleReclaimAfter: Duration(milliseconds: 30),
          idlePollInterval: Duration(milliseconds: 10),
        ),
        exit: () async {},
        idle: () async => const Duration(hours: 1),
        busy: () => true,
        rebuildWindow: () async {},
      );
      await shell.start();
      await shell.conceal();
      window
        ..focused = false
        ..calls.clear();

      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(window.calls, isEmpty);
      expect(shell.phase, ShellPhase.hidden);
      await shell.dispose();
    });

    test('turning the setting off stops the clock, without a restart', () async {
      final window = _ShellWindow();
      var reclaim = true;
      final shell = DesktopShell(
        platform: PlatformKind.windows,
        window: window,
        tray: _WorkingTray(),
        settings: () => ShellSettings(
          reclaimWhenIdle: reclaim,
          idleReclaimAfter: const Duration(milliseconds: 30),
          idlePollInterval: const Duration(milliseconds: 10),
        ),
        exit: () async {},
        idle: () async => const Duration(hours: 1),
        rebuildWindow: () async {},
      );
      await shell.start();
      reclaim = false;
      await shell.applySettingsChanged();
      window
        ..focused = false
        ..calls.clear();

      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(window.calls, isNot(contains('destroy')));
      await shell.dispose();
    });
  });
}

Future<void> _until(bool Function() condition, {Duration timeout = const Duration(seconds: 2)}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  if (!condition()) {
    throw TimeoutException('the condition never became true');
  }
}

class _ShellWindow implements WindowHost {
  @override
  final WindowRole role = WindowRole.main;

  final List<String> calls = [];
  final StreamController<WindowEvent> _events = StreamController<WindowEvent>.broadcast();
  bool focused = true;
  bool alive = true;

  @override
  bool get isAlive => alive;

  @override
  Stream<WindowEvent> get events => _events.stream;

  @override
  Future<void> show({bool inactive = false}) async => calls.add('show');

  @override
  Future<void> hide() async => calls.add('hide');

  @override
  Future<void> minimize() async => calls.add('minimize');

  @override
  Future<void> restore() async => calls.add('restore');

  @override
  Future<bool> toggleMaximize() async => true;

  @override
  Future<bool> isMaximized() async => false;

  @override
  Future<void> setPreventClose({required bool enabled}) async {}

  @override
  Future<void> close() async => calls.add('close');

  @override
  Future<void> destroy() async {
    calls.add('destroy');
    alive = false;
  }

  @override
  Future<WindowGeometry> geometry() async => const WindowGeometry(frame: PixelRect(0, 0, 800, 600), maximized: false);

  @override
  Future<void> setGeometry(WindowGeometry geometry) async {}

  @override
  Future<void> center() async {}

  @override
  Future<void> setAlwaysOnTop({required bool value}) async {}

  @override
  Future<void> setResizable({required bool value}) async {}

  @override
  Future<void> setTitle(String value) async {}

  @override
  Future<void> startDragging() async {}

  @override
  Future<WindowState> snapshot() async => WindowState(
    geometry: const WindowGeometry(frame: PixelRect(0, 0, 800, 600), maximized: false),
    isVisible: true,
    isFocused: focused,
  );
}

class _WorkingTray implements TrayHost {
  final StreamController<String> _selections = StreamController<String>.broadcast();
  final StreamController<TrayPointer> _pointers = StreamController<TrayPointer>.broadcast();
  bool _created = false;

  @override
  bool get isCreated => _created;

  @override
  Stream<String> get selections => _selections.stream;

  @override
  Stream<TrayPointer> get pointers => _pointers.stream;

  @override
  Future<bool> create({TrayIconState state = TrayIconState.idle}) async => _created = true;

  @override
  Future<void> dispose() async => _created = false;

  @override
  Future<void> setIcon(TrayIconState state) async {}

  @override
  Future<void> setTooltip(String text) async {}

  @override
  Future<void> setMenu(List<TrayEntry> entries) async {}
}
