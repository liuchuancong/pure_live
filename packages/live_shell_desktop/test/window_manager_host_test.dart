import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_shell/live_shell.dart';
import 'package:live_shell_desktop/live_shell_desktop.dart';

/// The host against a faked `window_manager` channel.
///
/// These are the contracts that exist nowhere else: the maximised state comes
/// from the window manager rather than from the button press, and closing is
/// *offered* to the shell instead of happening behind its back. Both are about
/// what the platform tells us, so a pure-Dart test in `live_shell` cannot reach
/// them — and no real window is needed either, because the plugin speaks a
/// method channel and a channel can be answered.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('window_frame_kit');
  const displays = [
    DisplayFrame(id: 'eDP-1', bounds: PixelRect(0, 0, 1920, 1080), workArea: PixelRect(0, 0, 1920, 1040)),
  ];

  final calls = <MethodCall>[];
  late Map<String, Object? Function(MethodCall)> answers;
  // The fake has to remember, not just reply: a responder that always says
  // "not maximised" would let a host that never asked the plugin still pass.
  var maximised = false;
  var minimised = false;

  Object? none(MethodCall call) => null;

  Future<void> emit(String eventName) =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(MethodCall('onEvent', {'eventName': eventName})),
        (_) {},
      );

  WindowManagerHost hostWith({WindowRole role = WindowRole.main}) {
    final host = WindowManagerHost(role: role, readDisplays: () async => displays)..attach();
    addTearDown(host.dispose);
    return host;
  }

  // `MethodCall.arguments` is dynamic; reading it directly spreads untyped
  // accesses through the file.
  Map<Object?, Object?> argsOf(MethodCall call) => call.arguments as Map<Object?, Object?>;

  setUp(() {
    calls.clear();
    maximised = false;
    minimised = false;
    answers = {
      'isMaximized': (_) => maximised,
      'isMinimized': (_) => minimised,
      'isVisible': (_) => true,
      'isFocused': (_) => true,
      'maximize': (_) {
        maximised = true;
        return null;
      },
      'unmaximize': (_) {
        maximised = false;
        return null;
      },
      'getBounds': (_) => {'x': 100.0, 'y': 60.0, 'width': 1200.0, 'height': 700.0},
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return (answers[call.method] ?? none)(call);
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  List<String> sentMethods() => calls.map((call) => call.method).toList();

  group('maximised state', () {
    test('toggling asks for the state it did not have, and reports the result', () async {
      final host = hostWith();

      expect(await host.toggleMaximize(), isTrue);
      expect(sentMethods(), contains('maximize'));
      expect(sentMethods(), isNot(contains('unmaximize')));

      expect(await host.toggleMaximize(), isFalse);
      expect(sentMethods(), contains('unmaximize'));
    });

    test('a remembered maximised window is maximised, not measured', () async {
      final host = hostWith();

      await host.setGeometry(const WindowGeometry(frame: PixelRect(0, 0, 1920, 1040), maximized: true));

      expect(sentMethods(), contains('maximize'));
      expect(sentMethods(), isNot(contains('setBounds')), reason: 'sizing it leaves the OS outside its own state');
    });

    test('a restored frame is placed with its own coordinates', () async {
      final host = hostWith();

      await host.setGeometry(const WindowGeometry(frame: PixelRect(120, 80, 1200, 700), maximized: false));

      final bounds = calls.lastWhere((call) => call.method == 'setBounds');
      expect(argsOf(bounds)['x'], 120);
      expect(argsOf(bounds)['y'], 80);
      expect(argsOf(bounds)['width'], 1200);
      expect(argsOf(bounds)['height'], 700);
      expect(sentMethods(), isNot(contains('maximize')));
    });

    test('the window manager reporting a maximise reaches the shell as an event', () async {
      final host = hostWith();
      final seen = <WindowEvent>[];
      host.events.listen(seen.add);

      // Double-clicking the strip, dragging to the top edge or Win+up all change
      // this state without the app asking, so the icon must follow the event.
      await emit('maximize');
      await emit('unmaximize');

      expect(seen, [WindowEvent.maximised, WindowEvent.unmaximised]);
    });

    test('a move is heard whether the platform reports the start or the settle', () async {
      // This is the bug the plugin's no-op listener defaults hide: mapping only
      // `move` means that on a platform which debounces and sends `moved`, the
      // window's new place is never recorded, and the viewer's window returns to
      // the old one every start with no error anywhere to explain it.
      final host = hostWith();
      final seen = <WindowEvent>[];
      host.events.listen(seen.add);

      await emit('move');
      await emit('moved');
      await emit('resize');
      await emit('resized');

      expect(seen, [WindowEvent.moved, WindowEvent.moved, WindowEvent.resized, WindowEvent.resized]);
    });
  });

  group('closing', () {
    test('a close from the platform is a request, never a completed close', () async {
      final host = hostWith();
      final seen = <WindowEvent>[];
      host.events.listen(seen.add);

      await emit('close');

      expect(seen, [WindowEvent.closeRequested]);
      expect(seen, isNot(contains(WindowEvent.closed)), reason: 'the policy still has to decide what close means');
    });

    test('interception is armed through the plugin', () async {
      final host = hostWith();

      await host.setPreventClose(enabled: true);

      final call = calls.lastWhere((entry) => entry.method == 'setPreventClose');
      expect(argsOf(call)['isPreventClose'], isTrue);
    });

    test('destroying marks the window gone and says so once', () async {
      final host = hostWith();
      final seen = <WindowEvent>[];
      host.events.listen(seen.add);

      await host.destroy();

      expect(host.isAlive, isFalse);
      expect(sentMethods(), contains('destroy'));
      await pumpEventQueue();
      expect(seen, [WindowEvent.closed]);
    });
  });

  group('focus', () {
    test('the main window may take focus when shown, a popup may not', () async {
      final main = hostWith();
      final popup = hostWith(role: WindowRole.popup);

      calls.clear();
      await main.show();
      expect(calls.map((call) => call.method), contains('focus'));
      expect(argsOf(calls.firstWhere((call) => call.method == 'show'))['inactive'], isFalse);

      calls.clear();
      await popup.show();
      expect(calls.map((call) => call.method), isNot(contains('focus')));
      // The role decides this, not the caller: a popup that can steal the
      // keyboard is a toast that interrupts typing.
      expect(argsOf(calls.firstWhere((call) => call.method == 'show'))['inactive'], isTrue);
    });
  });

  group('listeners', () {
    test('attaching twice does not deliver every event twice', () async {
      // The close policy is not idempotent: two deliveries mean two destroys,
      // two quit records and two exits, so the guard belongs to the host and not
      // to whatever the plugin's listener collection happens to be.
      final host = WindowManagerHost(role: WindowRole.main, readDisplays: () async => displays)
        ..attach()
        ..attach();
      addTearDown(host.dispose);
      final seen = <WindowEvent>[];
      host.events.listen(seen.add);

      await emit('close');

      expect(seen, [WindowEvent.closeRequested]);
    });

    test('a disposed host stops hearing the window manager', () async {
      final host = hostWith();
      final seen = <WindowEvent>[];
      host.events.listen(seen.add);

      await host.dispose();
      await emit('close');
      await pumpEventQueue();

      expect(seen, isEmpty);
    });
  });

  group('geometry reading', () {
    test('the plugin rectangle becomes logical pixel bounds with a display id', () async {
      final host = hostWith();

      final geometry = await host.geometry();

      expect(geometry.frame, const PixelRect(100, 60, 1200, 700));
      expect(geometry.maximized, isFalse);
      expect(geometry.displayId, 'eDP-1');
    });

    test('a remembered maximised window reports itself as maximised', () async {
      final host = hostWith();
      await host.toggleMaximize();

      expect((await host.geometry()).maximized, isTrue);
    });
  });
}
