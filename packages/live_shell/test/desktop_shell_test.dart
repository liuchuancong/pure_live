import 'dart:async';

import 'package:live_platform/live_platform.dart' show PlatformKind;
import 'package:live_shell/live_shell.dart';
import 'package:test/test.dart';

/// A window that remembers what was asked of it.
class _FakeWindow implements WindowHost {
  new();

  @override
  final WindowRole role = WindowRole.main;

  final List<String> calls = [];
  final StreamController<WindowEvent> _events = StreamController<WindowEvent>.broadcast();

  bool preventClose = false;
  bool alive = true;
  bool focused = true;
  WindowGeometry lastSet = const WindowGeometry(frame: PixelRect(0, 0, 800, 600), maximized: false);

  @override
  bool get isAlive => alive;

  @override
  Stream<WindowEvent> get events => _events.stream;

  void emit(WindowEvent event) => _events.add(event);

  @override
  Future<void> show({bool inactive = false}) async {
    calls.add(inactive ? 'show(inactive)' : 'show');
  }

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
  Future<void> setPreventClose({required bool enabled}) async {
    preventClose = enabled;
    calls.add('preventClose=$enabled');
  }

  @override
  Future<void> close() async => calls.add('close');

  @override
  Future<void> destroy() async {
    calls.add('destroy');
    alive = false;
  }

  @override
  Future<WindowGeometry> geometry() async => lastSet;

  @override
  Future<void> setGeometry(WindowGeometry geometry) async {
    lastSet = geometry;
    calls.add('setGeometry');
  }

  @override
  Future<void> center() async => calls.add('center');

  @override
  Future<void> setAlwaysOnTop({required bool value}) async => calls.add('alwaysOnTop=$value');

  @override
  Future<void> setResizable({required bool value}) async => calls.add('resizable=$value');

  @override
  Future<void> setTitle(String value) async => calls.add('title');

  @override
  Future<void> startDragging() async => calls.add('drag');

  @override
  Future<WindowState> snapshot() async => WindowState(geometry: lastSet, isVisible: true, isFocused: focused);
}

/// A tray that can be told to fail, which is the case that matters.
class _FakeTray implements TrayHost {
  new({this.works = true});

  final bool works;
  final List<String> calls = [];
  final StreamController<String> _selections = StreamController<String>.broadcast();
  final StreamController<TrayPointer> _pointers = StreamController<TrayPointer>.broadcast();

  bool _created = false;

  @override
  bool get isCreated => _created;

  @override
  Stream<String> get selections => _selections.stream;

  @override
  Stream<TrayPointer> get pointers => _pointers.stream;

  void select(String id) => _selections.add(id);

  void point(TrayPointer pointer) => _pointers.add(pointer);

  @override
  Future<bool> create({TrayIconState state = TrayIconState.idle}) async {
    calls.add('create');
    _created = works;
    return works;
  }

  @override
  Future<void> dispose() async => calls.add('dispose');

  @override
  Future<void> setIcon(TrayIconState state) async => calls.add('icon=${state.name}');

  @override
  Future<void> setTooltip(String text) async => calls.add('tooltip');

  @override
  Future<void> setMenu(List<TrayEntry> entries) async => calls.add('menu=${entries.length}');
}

final List<String> _exits = [];

DesktopShell _buildShell({
  required _FakeWindow window,
  PlatformKind platform = PlatformKind.windows,
  _FakeTray? tray,
  ShellSettings settings = const ShellSettings(),
  Future<void> Function()? rebuildWindow,
  bool Function()? busy,
  ReclaimCircuit? reclaim,
}) => DesktopShell(
  platform: platform,
  window: window,
  tray: tray,
  settings: () => settings,
  busy: busy ?? _notBusy,
  rebuildWindow: rebuildWindow,
  reclaim: reclaim,
  exit: () async {
    _exits.add('exit');
  },
  stateStore: WindowStateStore(save: (_) async {}, load: () async => null),
);

bool _notBusy() => false;

void main() {
  setUp(_exits.clear);

  group('start', () {
    test('arms interception before the window is ever shown, and creates the tray', () async {
      final window = _FakeWindow();
      final tray = _FakeTray();
      final shell = _buildShell(window: window, tray: tray);

      await shell.start();

      expect(window.preventClose, isTrue);
      expect(tray.calls, contains('create'));
      expect(window.calls, contains('show'));
      expect(shell.phase, ShellPhase.visible);
    });

    test('a hidden start builds nothing to look at', () async {
      final window = _FakeWindow();
      final shell = _buildShell(window: window, settings: const ShellSettings(startHidden: true));

      await shell.start();

      expect(window.calls, isNot(contains('show')));
      expect(
        window.calls,
        contains('hide'),
        reason: 'the runner already showed the window; not showing it again is not hiding it',
      );
      expect(shell.phase, ShellPhase.hidden);
    });

    test('a restored session overrides the hidden setting', () async {
      final window = _FakeWindow();
      final shell = _buildShell(window: window, settings: const ShellSettings(startHidden: true));

      await shell.start(restoredSession: true);

      expect(window.calls, contains('show'));
    });

    test('the operating system launching us hidden is its own reason', () async {
      final window = _FakeWindow();
      final shell = _buildShell(window: window);

      // macOS records "open hidden" in its own Login Items state and a Linux
      // autostart entry carries `--hidden`; neither is a setting the viewer
      // changed in this app, so `settings.startHidden` being false says nothing
      // about whether a window was asked for.
      await shell.start(openedHiddenBySystem: true);

      expect(window.calls, isNot(contains('show')));
      expect(window.calls, contains('hide'), reason: 'the window the runner mapped has to be taken away');
      expect(shell.phase, ShellPhase.hidden);
    });
  });

  group('the close button', () {
    test('hides rather than destroying when the tray is there to bring it back', () async {
      final window = _FakeWindow();
      final shell = _buildShell(window: window, tray: _FakeTray());

      await shell.start();
      window.calls.clear();
      await shell.handleClose();

      expect(window.calls, ['hide']);
      expect(shell.phase, ShellPhase.hidden);
    });

    test('quits when hiding would strand a process with no icon to wake it', () async {
      final window = _FakeWindow();
      final shell = _buildShell(window: window, tray: _FakeTray(works: false));

      await shell.start();
      await shell.handleClose();

      expect(_exits, contains('exit'), reason: 'hideToTray without a tray must fall back to quitting');
    });

    test('macOS destroys the window and stays running', () async {
      final window = _FakeWindow();
      final shell = _buildShell(window: window, platform: PlatformKind.macos);

      await shell.start();
      window.calls.clear();
      await shell.handleClose();

      expect(window.calls, contains('destroy'));
      expect(_exits, isEmpty);
      await shell.handleLastWindowClosed();
      expect(_exits, isEmpty, reason: 'a Mac stays alive with no windows');
    });

    test('an explicit quit flushes and disposes the tray before leaving', () async {
      final window = _FakeWindow();
      final tray = _FakeTray();
      final shell = _buildShell(
        window: window,
        tray: tray,
        settings: const ShellSettings(closeAction: CloseAction.quit),
      );

      await shell.start();
      await shell.handleClose();

      expect(tray.calls, contains('dispose'));
      expect(window.calls, containsAllInOrder(['close']));
      expect(_exits, contains('exit'));
    });

    test('one press runs the policy exactly once', () async {
      final window = _FakeWindow();
      final shell = _buildShell(window: window, tray: _FakeTray());
      await shell.start();
      window.calls.clear();

      window.emit(WindowEvent.closeRequested);
      await _settle();

      expect(window.calls.where((call) => call == 'hide'), hasLength(1));
    });
  });

  group('the tray', () {
    test('a click brings a hidden window back on Windows', () async {
      final window = _FakeWindow();
      final tray = _FakeTray();
      final shell = _buildShell(window: window, tray: tray);
      await shell.start();
      await shell.handleClose();
      window.calls.clear();

      tray.point(TrayPointer.click);
      await _settle();

      // A main window coming back is allowed to take focus — it was the viewer
      // who asked for it. Only popups are raised without stealing the keyboard.
      expect(window.calls, containsAllInOrder(['show']));
      expect(shell.phase, ShellPhase.visible);
    });

    test('macOS leaves the click to the menu', () async {
      final window = _FakeWindow();
      final tray = _FakeTray();
      final shell = _buildShell(window: window, platform: PlatformKind.macos, tray: tray);
      await shell.start();
      window.calls.clear();

      tray.point(TrayPointer.click);
      await _settle();

      expect(window.calls, isEmpty);
    });

    test('a menu id the shell does not own is handed back to the app', () async {
      final window = _FakeWindow();
      final tray = _FakeTray();
      final seen = <String>[];
      final shell = DesktopShell(
        platform: PlatformKind.windows,
        window: window,
        tray: tray,
        settings: () => const ShellSettings(),
        exit: () async {},
        onMenuAction: (id) async => seen.add(id),
      );
      await shell.start();

      tray.select('record:next');
      await _settle();

      expect(seen, ['record:next']);
    });
  });

  group('reclaiming', () {
    test('idle never takes the interface from a recording', () async {
      final window = _FakeWindow();
      final shell = _buildShell(
        window: window,
        tray: _FakeTray(),
        settings: const ShellSettings(reclaimWhenIdle: true),
        rebuildWindow: () async {},
        busy: () => true,
      );
      await shell.start();
      await shell.handleClose();
      window.calls.clear();

      await shell.noteIdle(idleLongEnough: true);

      expect(window.calls, isEmpty, reason: 'work in progress outranks the memory saving');
    });

    test("a window under the viewer's eyes is not idle, however long the machine waited", () async {
      final window = _FakeWindow();
      final shell = _buildShell(
        window: window,
        tray: _FakeTray(),
        settings: const ShellSettings(reclaimWhenIdle: true),
        rebuildWindow: () async {},
      );
      await shell.start();
      await shell.conceal();
      window.calls.clear();

      await shell.noteIdle(idleLongEnough: true);

      expect(window.calls, isEmpty, reason: 'the fake still reports focus; they may be reading');

      window.focused = false;
      await shell.noteIdle(idleLongEnough: true);

      expect(window.calls, contains('destroy'));
      expect(shell.phase, ShellPhase.reclaimed);
    });

    test('a destroyed window is not pretended back when nothing can rebuild it', () async {
      final window = _FakeWindow();
      final shell = _buildShell(window: window, platform: PlatformKind.macos, tray: _FakeTray());
      await shell.start();
      await shell.handleClose();
      expect(shell.phase, ShellPhase.reclaimed);
      window.calls.clear();

      await shell.reveal();

      expect(window.calls, isEmpty, reason: 'show on a destroyed window only lies about having worked');
      expect(shell.phase, ShellPhase.reclaimed);
    });

    test('a reclaimed window is rebuilt when the app knows how', () async {
      final window = _FakeWindow();
      var rebuilt = 0;
      final shell = _buildShell(
        window: window,
        tray: _FakeTray(),
        settings: const ShellSettings(reclaimWhenIdle: true),
        rebuildWindow: () async => rebuilt++,
      );
      await shell.start();
      await shell.conceal();
      expect(shell.phase, ShellPhase.hidden);
      window.focused = false;

      await shell.noteIdle(idleLongEnough: true);
      expect(shell.phase, ShellPhase.reclaimed);

      await shell.reveal();

      expect(rebuilt, 1);
      expect(shell.phase, ShellPhase.visible);
    });

    test('a tripped circuit stops the automatic destroy', () async {
      final window = _FakeWindow();
      final circuit = ReclaimCircuit();
      final now = DateTime.now();
      for (var attempt = 0; attempt < 3; attempt++) {
        circuit.recordFailure(now);
      }
      final shell = _buildShell(
        window: window,
        settings: const ShellSettings(reclaimWhenIdle: true, closeAction: CloseAction.minimise),
        rebuildWindow: () async {},
        reclaim: circuit,
      );
      await shell.start();
      await shell.conceal();
      window.focused = false;
      window.calls.clear();

      // The viewer asked three times and the application failed three times. The
      // shell's own conclusion is that destroying this window may be
      // unrecoverable, so it stops doing that on a timer.
      await shell.noteIdle(idleLongEnough: true);

      expect(window.calls, isNot(contains('destroy')));
      expect(shell.phase, ShellPhase.hidden);
    });

    test('the same shell with a healthy circuit does destroy, so the gate is what stopped it', () async {
      final window = _FakeWindow();
      final shell = _buildShell(
        window: window,
        settings: const ShellSettings(reclaimWhenIdle: true, closeAction: CloseAction.minimise),
        rebuildWindow: () async {},
        reclaim: ReclaimCircuit(),
      );
      await shell.start();
      await shell.conceal();
      window.focused = false;
      window.calls.clear();

      await shell.noteIdle(idleLongEnough: true);

      expect(window.calls, contains('destroy'));
    });

    test('a rebuild that throws is counted, and the window is not marked visible', () async {
      final window = _FakeWindow();
      final circuit = ReclaimCircuit();
      final shell = _buildShell(
        window: window,
        settings: const ShellSettings(reclaimWhenIdle: true, closeAction: CloseAction.minimise),
        rebuildWindow: () async => throw StateError('the app cannot start a window again'),
        reclaim: circuit,
      );
      await shell.start();
      await shell.conceal();
      window.focused = false;
      await shell.noteIdle(idleLongEnough: true);
      expect(shell.phase, ShellPhase.reclaimed);

      await expectLater(shell.reveal(), throwsA(isA<StateError>()));

      expect(circuit.failureCount, 1);
      expect(
        shell.phase,
        ShellPhase.reclaimed,
        reason: 'a failed repair that leaves the phase visible starts saving frames for a window that is gone',
      );
    });

    test('a rebuild that works clears the count', () async {
      final window = _FakeWindow();
      final circuit = ReclaimCircuit()..recordFailure(DateTime.now());
      final shell = _buildShell(
        window: window,
        settings: const ShellSettings(reclaimWhenIdle: true, closeAction: CloseAction.minimise),
        rebuildWindow: () async {},
        reclaim: circuit,
      );
      await shell.start();
      await shell.conceal();
      window.focused = false;
      await shell.noteIdle(idleLongEnough: true);
      expect(circuit.failureCount, 1);

      await shell.reveal();

      expect(circuit.failureCount, 0, reason: 'a machine that just repaired itself should not stay marked');
      expect(shell.phase, ShellPhase.visible);
    });
  });

  group('geometry', () {
    test('a remembered frame is read back and applied at start', () async {
      final window = _FakeWindow();
      final shell = DesktopShell(
        platform: PlatformKind.windows,
        window: window,
        settings: () => const ShellSettings(),
        exit: () async {},
        stateStore: WindowStateStore(
          save: (_) async {},
          load: () async =>
              const WindowGeometry(frame: PixelRect(120, 80, 1000, 640), maximized: false, displayId: 'eDP-1'),
        ),
        readDisplays: () async => const [
          DisplayFrame(id: 'eDP-1', bounds: PixelRect(0, 0, 1920, 1080), workArea: PixelRect(0, 0, 1920, 1040)),
        ],
      );

      await shell.start();

      expect(window.calls, contains('setGeometry'));
      expect(window.lastSet.frame.left, 120);
    });

    test('remembering switched off reads nothing and writes nothing', () async {
      final window = _FakeWindow();
      final shell = DesktopShell(
        platform: PlatformKind.windows,
        window: window,
        settings: () => const ShellSettings(rememberBounds: false),
        exit: () async {},
        stateStore: WindowStateStore(save: (_) async {}, load: () async => null),
      );

      await shell.start();
      window.emit(WindowEvent.moved);
      await _settle();

      expect(window.calls, isNot(contains('setGeometry')));
    });

    test('a drag is throttled and the settled position is the one recorded', () async {
      final window = _FakeWindow();
      final writes = <WindowGeometry>[];
      final shell = DesktopShell(
        platform: PlatformKind.windows,
        window: window,
        settings: () => const ShellSettings(),
        exit: () async {},
        stateStore: WindowStateStore(
          save: (record) async => writes.add(record),
          load: () async => null,
          debounce: const Duration(milliseconds: 10),
        ),
      );
      await shell.start();

      window.emit(WindowEvent.moved);
      // The event arrives through a broadcast stream, so the shell has not seen
      // it yet on this same turn: reading the gate before yielding would test
      // the subscription's scheduling rather than the throttle.
      await Future<void>.delayed(Duration.zero);
      expect(shell.allowsUiWork, isFalse, reason: 'the drag is in flight');
      window.emit(WindowEvent.moved);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(shell.allowsUiWork, isTrue);
      expect(writes, hasLength(1), reason: 'one write for the whole drag');
    });
  });

  group('secondary windows', () {
    test('quitting dismisses them, so a stray panel cannot hold the process open', () async {
      final window = _FakeWindow();
      final windows = SecondaryWindows(launcher: _FakeLauncher());
      final panel = await windows.open(role: WindowRole.panel);
      final shell = DesktopShell(
        platform: PlatformKind.windows,
        window: window,
        tray: _FakeTray(),
        settings: () => const ShellSettings(),
        windows: windows,
        exit: () async => _exits.add('exit'),
      );
      await shell.start();

      await shell.prepareToQuit();

      expect((panel as _FakeSecondaryWindow).sent, contains('shell_dismiss'));
      expect(windows.opened, isEmpty);
    });

    test('hiding to the tray leaves them exactly where they were', () async {
      final window = _FakeWindow();
      final windows = SecondaryWindows(launcher: _FakeLauncher());
      final panel = await windows.open(role: WindowRole.panel);
      final shell = DesktopShell(
        platform: PlatformKind.windows,
        window: window,
        tray: _FakeTray(),
        settings: () => const ShellSettings(),
        windows: windows,
        exit: () async {},
      );
      await shell.start();

      await shell.handleClose();

      expect((panel as _FakeSecondaryWindow).sent, isEmpty, reason: 'the viewer did not ask to close their panel');
      expect(windows.opened, hasLength(1));
    });
  });
}

class _FakeSecondaryWindow implements SecondaryWindow {
  new(this.id);

  @override
  final String id;

  @override
  WindowRole get role => WindowRole.panel;

  final List<String> sent = [];

  @override
  Future<void> show() async {}

  @override
  Future<void> hide() async {}

  @override
  Future<T?> send<T>(String method, [Object? arguments]) async {
    sent.add(method);
    return null;
  }
}

class _FakeLauncher implements WindowLauncher {
  int _n = 0;

  @override
  Future<SecondaryWindow> open({required WindowRole role, String? route, String? businessKey}) async {
    _n++;
    return _FakeSecondaryWindow('panel-$_n');
  }
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 30));
