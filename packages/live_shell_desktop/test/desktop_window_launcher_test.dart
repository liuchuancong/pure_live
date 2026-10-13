import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_shell/live_shell.dart';
import 'package:live_shell_desktop/live_shell_desktop.dart';

/// The launcher against faked `desktop_multi_window` channels.
///
/// Two different transports run under here, and telling them apart is the whole
/// content of this file:
///
/// * `WindowController.create` and `show`/`hide` talk to the **native plugin** on
///   `mixin.one/desktop_multi_window`, addressed by window id. Nothing needs the
///   other engine to be up, because the operating system already owns the window.
/// * `send()` goes over the **engine-to-engine bus**
///   (`mixin.one/desktop_multi_window/channels`), which only delivers once the
///   new isolate has registered its handler.
///
/// So the payload that decides what the new window even *is* — its role and route
/// — crosses the boundary in the creation call, and this is the one place the
/// shell's role rules can silently fail to arrive: a forgotten key here produces a
/// window that comes up as an unnamed main window, which looks like a bug in the
/// page rather than in the launch.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const plugin = MethodChannel('mixin.one/desktop_multi_window');
  const bus = MethodChannel('mixin.one/desktop_multi_window/channels');
  const windowId = 'win-7';

  final pluginCalls = <MethodCall>[];
  final busCalls = <MethodCall>[];

  Map<Object?, Object?> argsOf(MethodCall call) => call.arguments as Map<Object?, Object?>;
  MethodCall first(List<MethodCall> calls, String method) => calls.firstWhere((call) => call.method == method);

  // What the sub-window's isolate is handed at start-up; the test below changes
  // this to prove `currentWindowArguments` reads it and nothing else.
  var currentArgument = '';

  setUp(() {
    pluginCalls.clear();
    busCalls.clear();
    currentArgument = '';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(plugin, (call) async {
        pluginCalls.add(call);
        switch (call.method) {
          case 'createWindow':
            return windowId;
          case 'getWindowDefinition':
            return {'windowId': windowId, 'windowArgument': currentArgument};
          default:
            return null;
        }
      })
      ..setMockMethodCallHandler(bus, (call) async {
        busCalls.add(call);
        return null;
      });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(plugin, null)
      ..setMockMethodCallHandler(bus, null);
  });

  group('creation', () {
    test('the role and route travel as the launch arguments of the new window', () async {
      final window = await DesktopWindowLauncher().open(role: WindowRole.videoFloat, route: '/room/7');

      final created = argsOf(first(pluginCalls, 'createWindow'));
      final arrived = WindowArguments.fromRaw(created['arguments']! as String);

      expect(arrived.role, WindowRole.videoFloat);
      expect(arrived.route, '/room/7');
      expect(window.id, windowId);
    });

    test('a window is created hidden, so nothing flashes before its own first frame', () async {
      await DesktopWindowLauncher().open(role: WindowRole.panel);

      final created = argsOf(first(pluginCalls, 'createWindow'));

      expect(created['hiddenAtLaunch'], isTrue);
    });

    test('it is raised over the native transport, addressed by id', () async {
      await DesktopWindowLauncher().open(role: WindowRole.popup);

      final shown = first(pluginCalls, 'window_show');

      expect(argsOf(shown)['windowId'], windowId);
      expect(busCalls, isEmpty, reason: 'showing a window is not a message to its isolate');
    });

    test('every role arrives as itself, including the ones added last', () async {
      for (final role in WindowRole.values) {
        pluginCalls.clear();
        await DesktopWindowLauncher().open(role: role);

        final created = argsOf(first(pluginCalls, 'createWindow'));

        expect(
          WindowArguments.fromRaw(created['arguments']! as String).role,
          role,
          reason: 'a role that degrades to main on the way in opens the wrong window',
        );
      }
    });
  });

  group('messaging a live window', () {
    test('send crosses the engine bus under the channel named for the window', () async {
      final window = await DesktopWindowLauncher().open(role: WindowRole.panel);
      busCalls.clear();

      await window.send<void>('set_room', {'id': 42});

      final wrapped = argsOf(first(busCalls, 'invokeMethod'));
      expect(wrapped['channel'], 'mixin.one/window_controller/$windowId');
      expect(wrapped['method'], 'set_room');
      expect((wrapped['arguments']! as Map<Object?, Object?>)['id'], 42);
    });

    test('hide is native and does not depend on the other isolate answering', () async {
      final window = await DesktopWindowLauncher().open(role: WindowRole.videoFloat);
      pluginCalls.clear();
      busCalls.clear();

      await window.hide();

      expect(first(pluginCalls, 'window_hide').arguments, isNotNull);
      expect(busCalls, isEmpty);
    });
  });

  group('what the new isolate learns about itself', () {
    test('the launch payload is read back from the window definition', () async {
      currentArgument = const WindowArguments(role: WindowRole.popup, route: '/toast/1').encode();

      final arguments = await currentWindowArguments();

      expect(arguments.role, WindowRole.popup);
      expect(arguments.route, '/toast/1');
    });

    test('a payload from an older build still starts as the main window', () async {
      currentArgument = 'not our json';

      expect((await currentWindowArguments()).role, WindowRole.main);
    });

    test('an empty payload — the main window, which nobody launched — is main', () async {
      currentArgument = '';

      final arguments = await currentWindowArguments();

      expect(arguments.role, WindowRole.main);
      expect(arguments.entryPoint, 'main');
    });
  });
}
