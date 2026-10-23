import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_platform/live_platform.dart' show PlatformKind;
import 'package:live_shell/live_shell.dart';
import 'package:live_shell_desktop/live_shell_desktop.dart';

/// What the shell's decisions actually look like on the way to the operating
/// system.
///
/// [configureMainWindow] is the one place where a `ChromePlan`, a
/// `RenderFallbacks` and a `WindowRole` are turned into calls the window manager
/// performs. Until this file, the claim that a floating video window stays out of
/// alt-tab, or that switching translucency off produces an opaque surface, was
/// carried entirely by comments — and the interesting part of a fan-out like this
/// is which of its branches a given combination takes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('window_manager');

  final calls = <MethodCall>[];

  MethodCall find(String method) => calls.firstWhere((call) => call.method == method);
  bool sent(String method) => calls.any((call) => call.method == method);
  Map<Object?, Object?> argsOf(MethodCall call) => call.arguments as Map<Object?, Object?>;

  setUp(() {
    calls.clear();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      // The plugin asks these before applying options, and answering anything
      // other than "no" here would make every test depend on which recovery
      // step the plugin decides to run.
      if (call.method == 'isFullScreen' || call.method == 'isMaximized' || call.method == 'isMinimized') {
        return false;
      }
      if (call.method == 'getBounds') {
        return {'x': 0.0, 'y': 0.0, 'width': 1280.0, 'height': 800.0};
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  Future<void> configure({
    WindowRole role = WindowRole.main,
    PlatformKind platform = PlatformKind.windows,
    RenderFallbacks fallbacks = const RenderFallbacks(),
    Color background = const Color(0xFF101418),
    bool requestMaterial = false,
    WindowMaterialApplier? applyMaterial,
    // The plugin's own centering reads the display API through FFI handles, which
    // a unit test cannot answer, so every case here places the window by hand.
    WindowOriginReader? placeWindow,
  }) => configureMainWindow(
    role: role,
    plan: primaryChromePlan(platform),
    fallbacks: fallbacks,
    title: 'Pure Live',
    background: background,
    placeWindow: placeWindow ?? ((_) async => const Offset(320, 140)),
    requestMaterial: requestMaterial,
    applyMaterial: applyMaterial,
  );

  group('the chrome plan', () {
    test('windows 10 and 11 alike draw their own strip and keep the window resizable', () async {
      await configure();

      expect(argsOf(find('setTitleBarStyle'))['titleBarStyle'], 'hidden');
      expect(
        argsOf(find('setResizable'))['isResizable'],
        isTrue,
        reason: 'the self-drawn plan owns the edges, so the window must stay resizable',
      );
    });

    test('the caption is dressed before the window is placed', () async {
      // The plugin applies the title bar style inside `waitUntilReadyToShow`, so
      // nothing this function does afterwards, and nothing that carries the
      // frame, may come first.
      await configure(platform: PlatformKind.linux);

      final caption = calls.indexWhere((call) => call.method == 'setTitleBarStyle');
      final placed = calls.indexWhere((call) => call.method == 'setBounds');
      expect(caption, greaterThanOrEqualTo(0));
      expect(placed, greaterThan(caption));
    });

    test('a strip we draw but the system still sizes keeps its frame', () async {
      // macOS at the first stage: hidden title bar, traffic lights, native resize.
      await configure(platform: PlatformKind.macos);

      expect(argsOf(find('setTitleBarStyle'))['titleBarStyle'], 'hidden');
      expect(sent('setResizable'), isFalse);
    });
  });

  group('the role', () {
    test('the main window and a manage panel appear in alt-tab, a float and a toast do not', () async {
      await configure();
      expect(argsOf(find('setSkipTaskbar'))['isSkipTaskbar'], isFalse);

      calls.clear();
      await configure(role: WindowRole.panel);
      expect(argsOf(find('setSkipTaskbar'))['isSkipTaskbar'], isFalse);

      calls.clear();
      await configure(role: WindowRole.videoFloat);
      expect(argsOf(find('setSkipTaskbar'))['isSkipTaskbar'], isTrue);

      calls.clear();
      await configure(role: WindowRole.popup);
      expect(argsOf(find('setSkipTaskbar'))['isSkipTaskbar'], isTrue);
    });
  });

  group('placement', () {
    test('the origin the reader hands back is sent, and nothing shows yet', () async {
      await configure();

      // `setPosition` is a partial `setBounds` in this plugin: position only,
      // with the size keys absent so the window keeps what it was created with.
      // The last one, because applying the creation options issues its own
      // `setBounds` for the size first.
      final call = calls.lastWhere((entry) => entry.method == 'setBounds');
      expect(argsOf(call)['x'], 320.0);
      expect(argsOf(call)['y'], 140.0);
      expect(argsOf(call).containsKey('width'), isFalse);
      expect(argsOf(call).containsKey('height'), isFalse);
      // The order that matters is against `show`, not against the chrome calls:
      // `configureMainWindow` never shows the window — the host does, after this
      // returns — so a placement made here is already in place for the first frame.
      expect(sent('show'), isFalse);
    });

    test('a display that cannot be read leaves the window where the system put it', () async {
      await configure(placeWindow: (_) async => null);

      expect(sent('setPosition'), isFalse);
      expect(sent('setTitleBarStyle'), isTrue, reason: 'the rest of the plan still applies');
    });
  });

  group('the render fallbacks', () {
    test('translucency on without a material request still paints opaque', () async {
      // Windows 10 has no default compositor backdrop: a transparent surface
      // with nothing behind it shows the desktop through. Transparency is
      // earned by an applied material, not by the viewer's switch alone.
      await configure();

      final color = argsOf(find('setBackgroundColor'));
      expect(color['backgroundColorA'], 255);
    });

    test('a requested material that applies clears the surface afterwards', () async {
      AppliedWindowMaterial? asked;
      await configure(
        requestMaterial: true,
        applyMaterial: ({required dark}) async {
          asked = AppliedWindowMaterial.mica;
          return asked!;
        },
      );

      expect(asked, AppliedWindowMaterial.mica);
      final colours = calls.where((call) => call.method == 'setBackgroundColor').toList();
      expect(colours, hasLength(2), reason: 'the opaque option first, the clear surface after the material lands');
      final after = colours.last.arguments as Map<Object?, Object?>;
      expect(after['backgroundColorA'], 0);
    });

    test('a requested material that is refused leaves the opaque surface', () async {
      await configure(requestMaterial: true, applyMaterial: ({required dark}) async => AppliedWindowMaterial.none);

      final colour = argsOf(find('setBackgroundColor'));
      expect(colour['backgroundColorA'], 255);
    });

    test('translucency off never asks for a material', () async {
      var asked = false;
      await configure(
        fallbacks: const RenderFallbacks(effects: false),
        requestMaterial: true,
        applyMaterial: ({required dark}) async {
          asked = true;
          return AppliedWindowMaterial.mica;
        },
      );

      expect(asked, isFalse);
      final color = argsOf(find('setBackgroundColor'));
      expect(color['backgroundColorA'], 255);
      expect(color['backgroundColorR'], 0x10);
      expect(color['backgroundColorG'], 0x14);
      expect(color['backgroundColorB'], 0x18);
    });

    test('software rendering also forces an opaque surface', () async {
      await configure(fallbacks: const RenderFallbacks(hardwareAcceleration: false));

      expect(argsOf(find('setBackgroundColor'))['backgroundColorA'], 255);
    });
  });

  group('the size', () {
    test('a first start takes the single shared default', () async {
      await configure();

      final bounds = argsOf(find('setBounds'));
      expect(bounds['width'], defaultWindowSize.width);
      expect(bounds['height'], defaultWindowSize.height);
    });

    test('the minimum is sent, because a resizable window with no floor can be dragged to nothing', () async {
      await configure();

      // Its own channel method, not a `setBounds` variant: `setSize` folds through
      // setBounds while the floor is sent as `setMinimumSize`, so looking for it
      // among the size calls finds the wrong one and passes anyway.
      final minimum = argsOf(find('setMinimumSize'));

      expect(minimum['width'], 900);
      expect(minimum['height'], 600);
    });
  });
}
