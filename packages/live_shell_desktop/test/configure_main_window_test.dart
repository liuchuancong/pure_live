import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_platform/live_platform.dart' show PlatformKind;
import 'package:live_shell/live_shell.dart';
import 'package:live_shell_desktop/live_shell_desktop.dart';
import 'package:window_manager/window_manager.dart';

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
  const displaysChannel = MethodChannel('dev.leanflutter.plugins/screen_retriever');
  final calls = <MethodCall>[];

  // The shape `screen_retriever` decodes a Display from, at 100% on a 1920x1080
  // panel with a 40px taskbar.
  const primaryDisplay = <String, Object?>{
    'id': '1',
    'size': {'width': 1920.0, 'height': 1080.0},
    'visiblePosition': {'dx': 0.0, 'dy': 0.0},
    'visibleSize': {'width': 1920.0, 'height': 1040.0},
    'scaleFactor': 1.0,
  };

  MethodCall find(String method) => calls.firstWhere((call) => call.method == method);
  bool sent(String method) => calls.any((call) => call.method == method);
  Map<Object?, Object?> argsOf(MethodCall call) => call.arguments as Map<Object?, Object?>;

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      displaysChannel,
      (call) async => switch (call.method) {
        'getPrimaryDisplay' => primaryDisplay,
        // Wrapped, not a bare list: the plugin reads `result['displays']`.
        'getAllDisplays' => {
          'displays': [primaryDisplay],
        },
        // Reached while centring: the plugin builds an Offset from these two.
        'getCursorScreenPoint' => {'dx': 240.0, 'dy': 180.0},
        _ => null,
      },
    );
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(displaysChannel, null);
  });

  Future<void> configure({
    WindowRole role = WindowRole.main,
    PlatformKind platform = PlatformKind.windows,
    ChromeStage stage = ChromeStage.nativeFirst,
    RenderFallbacks fallbacks = const RenderFallbacks(),
    Color background = const Color(0xFF101418),
    TitleBarStyle? titleBarStyle,
    bool requestMaterial = false,
    WindowMaterialApplier? applyMaterial,
  }) => configureMainWindow(
    role: role,
    plan: primaryChromePlan(platform, stage: stage),
    fallbacks: fallbacks,
    title: 'Pure Live',
    background: background,
    titleBarStyle: titleBarStyle,
    requestMaterial: requestMaterial,
    applyMaterial: applyMaterial,
  );

  group('the chrome plan', () {
    test('a native caption keeps the system title bar and stays resizable', () async {
      await configure();

      expect(argsOf(find('setTitleBarStyle'))['titleBarStyle'], 'normal');
      expect(sent('setAsFrameless'), isFalse);
      expect(argsOf(find('setResizable'))['isResizable'], isTrue);
    });

    test('an explicit style outranks the mode-derived one, for the external frame helper', () async {
      // The bitsdojo arrangement: the helper strips the caption natively, so
      // the self-drawn mode's `hidden` would put two components over the same
      // non-client area. The override holds the window manager at normal.
      await configure(
        platform: PlatformKind.linux,
        stage: ChromeStage.seamlessSelfDrawn,
        titleBarStyle: TitleBarStyle.normal,
      );

      expect(argsOf(find('setTitleBarStyle'))['titleBarStyle'], 'normal');
    });

    test('a self-drawn strip that owns the edges goes frameless and stops being resizable by the system', () async {
      await configure(platform: PlatformKind.linux, stage: ChromeStage.seamlessSelfDrawn);

      expect(argsOf(find('setTitleBarStyle'))['titleBarStyle'], 'hidden');
      expect(sent('setAsFrameless'), isTrue);
      expect(
        argsOf(find('setResizable'))['isResizable'],
        isFalse,
        reason: 'both answering WM_GETMINMAXINFO and letting the system size the window is two answers',
      );
    });

    test('a strip we draw but the system still sizes keeps resizing', () async {
      // macOS at the first stage: hidden title bar, native resize.
      await configure(platform: PlatformKind.macos);

      expect(argsOf(find('setTitleBarStyle'))['titleBarStyle'], 'hidden');
      expect(sent('setAsFrameless'), isFalse);
      expect(argsOf(find('setResizable'))['isResizable'], isTrue);
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
