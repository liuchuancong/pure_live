import 'package:live_shell/live_shell.dart';
import 'package:test/test.dart';

/// Records every action the router took, in order, so the two ordering rules
/// documented on [LaunchRouter.route] can be asserted rather than admired.
class _Sink implements LaunchSink {
  new(this.log);

  final List<String> log;

  @override
  Future<void> showRoom(Uri link) async => log.add('room:$link');

  @override
  Future<void> importFile(String path) async => log.add('import:$path');

  @override
  Future<void> navigate(String route) async => log.add('navigate:$route');

  @override
  Future<void> showRecorder() async => log.add('recorder');
}

class _NullSecondary implements SecondaryWindow {
  @override
  final String id = 'secondary';

  @override
  final WindowRole role = WindowRole.panel;

  @override
  Future<void> show() async {}

  @override
  Future<void> hide() async {}

  @override
  Future<T?> send<T>(String method, [Object? arguments]) async => null;
}

class _RecordingLauncher implements WindowLauncher {
  int created = 0;
  final List<SecondaryWindow> _opened = [];

  @override
  Future<SecondaryWindow> open({required WindowRole role, String? route}) async {
    created++;
    _opened.add(_NullSecondary());
    return _opened.last;
  }
}

({LaunchRouter router, _RecordingLauncher launcher, List<String> actions}) build() {
  final launcher = _RecordingLauncher();
  final actions = <String>[];
  final router = LaunchRouter(
    windows: SecondaryWindows(launcher: launcher),
    revealMain: () async => actions.add('reveal'),
    sink: _Sink(actions),
  );
  return (router: router, launcher: launcher, actions: actions);
}

void main() {
  test('a room link raises the window before showing the room', () async {
    final h = build();

    await h.router.route(OpenRoomLink(Uri.parse('https://live.example/room/42')));

    expect(h.actions, ['reveal', 'room:https://live.example/room/42']);
  });

  test('a dropped-on file is imported only once the window is up', () async {
    final h = build();

    await h.router.route(const OpenFile(r'D:\lists\cctv.m3u'));

    expect(h.actions, ['reveal', r'import:D:\lists\cctv.m3u']);
  });

  test('a bare raise navigates nowhere', () async {
    final h = build();

    await h.router.route(const ShowMainWindow());

    expect(h.actions, ['reveal']);
  });

  test('a raise with a route navigates after the reveal', () async {
    final h = build();

    await h.router.route(const ShowMainWindow(route: '/recordings'));

    expect(h.actions, ['reveal', 'navigate:/recordings']);
  });

  test('the recorder request reaches the application', () async {
    final h = build();

    await h.router.route(const ShowRecorder());

    expect(h.actions, ['reveal', 'recorder']);
  });

  test('"open in a new window" does not touch the primary', () async {
    final h = build();

    await h.router.route(const NewWindow(route: '/cast'));

    expect(h.actions, isEmpty, reason: 'asking for another window is not asking to move this one');
    expect(h.launcher.created, 1);
  });
}
