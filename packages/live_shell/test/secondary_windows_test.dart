import 'package:live_shell/live_shell.dart';
import 'package:test/test.dart';

class _FakeSecondary implements SecondaryWindow {
  new(this.id, this.role);

  @override
  final String id;

  @override
  final WindowRole role;

  final List<String> calls = [];

  @override
  Future<void> show() async => calls.add('show');

  @override
  Future<void> hide() async => calls.add('hide');

  @override
  Future<T?> send<T>(String method, [Object? arguments]) async {
    calls.add(method);
    return null;
  }
}

class _FakeLauncher implements WindowLauncher {
  int created = 0;

  @override
  Future<SecondaryWindow> open({required WindowRole role, String? route, String? businessKey}) async {
    created++;
    return _FakeSecondary('w$created', role);
  }
}

void main() {
  group('SecondaryWindows', () {
    test('a second request for the float raises the one that exists', () async {
      final launcher = _FakeLauncher();
      final windows = SecondaryWindows(launcher: launcher);

      final first = await windows.open(role: WindowRole.videoFloat);
      final second = await windows.open(role: WindowRole.videoFloat);

      expect(launcher.created, 1, reason: 'two floats of one session is always a bug');
      expect(second.id, first.id);
      expect((first as _FakeSecondary).calls, contains('show'));
      expect(windows.countOf(WindowRole.videoFloat), 1);
    });

    test('panels are allowed to multiply', () async {
      final launcher = _FakeLauncher();
      final windows = SecondaryWindows(launcher: launcher);

      await windows.open(role: WindowRole.panel, route: '/logs');
      await windows.open(role: WindowRole.panel, route: '/cast');

      expect(launcher.created, 2);
      expect(windows.countOf(WindowRole.panel), 2);
      expect(windows.opened.length, 2);
    });

    test('a window that closed on its own frees its slot', () async {
      final launcher = _FakeLauncher();
      final windows = SecondaryWindows(launcher: launcher);
      final first = await windows.open(role: WindowRole.videoFloat);

      windows.noteGone(first.id);
      final second = await windows.open(role: WindowRole.videoFloat);

      expect(launcher.created, 2, reason: 'otherwise the float button dies for the session');
      expect(second.id, isNot(first.id));
      expect(windows.lone(WindowRole.videoFloat)?.id, second.id);
    });

    test('dismissRole leaves the other roles alone', () async {
      final launcher = _FakeLauncher();
      final windows = SecondaryWindows(launcher: launcher);
      final float = await windows.open(role: WindowRole.videoFloat);
      final panelA = await windows.open(role: WindowRole.panel);
      final panelB = await windows.open(role: WindowRole.panel);

      await windows.dismissRole(WindowRole.panel);

      expect((panelA as _FakeSecondary).calls, contains('shell_dismiss'));
      expect((panelB as _FakeSecondary).calls, contains('shell_dismiss'));
      expect((float as _FakeSecondary).calls, isEmpty);
      expect(windows.countOf(WindowRole.panel), 0);
      expect(windows.countOf(WindowRole.videoFloat), 1);
    });

    test('dismissAll empties the set, so nothing can hold the process open', () async {
      final launcher = _FakeLauncher();
      final windows = SecondaryWindows(launcher: launcher);
      final float = await windows.open(role: WindowRole.videoFloat);
      final panel = await windows.open(role: WindowRole.panel);

      await windows.dismissAll();

      expect(windows.opened, isEmpty);
      expect((float as _FakeSecondary).calls, contains('shell_dismiss'));
      expect((panel as _FakeSecondary).calls, contains('shell_dismiss'));
    });

    test('raiseAll is what a reactivation looks like with panels still open', () async {
      final launcher = _FakeLauncher();
      final windows = SecondaryWindows(launcher: launcher);
      final panel = await windows.open(role: WindowRole.panel);
      windows.noteGone('no-such-id'); // forgetting a window that never existed is a no-op

      await windows.raiseAll();

      expect((panel as _FakeSecondary).calls, contains('show'));
    });

    test('the singleton table is per role', () {
      expect(SecondaryWindows.isSingleton(WindowRole.videoFloat), isTrue);
      expect(SecondaryWindows.isSingleton(WindowRole.popup), isTrue);
      expect(SecondaryWindows.isSingleton(WindowRole.panel), isFalse);
    });
  });
}
