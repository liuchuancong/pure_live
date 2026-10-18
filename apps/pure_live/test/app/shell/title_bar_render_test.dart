// The named private-class constructors cannot use the `new` shorthand.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'dart:io' show Directory;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:live_platform/live_platform.dart'
    show DesktopDistribution, FormFactor, PlatformCapabilities, PlatformEnvironment, PlatformKind, PlatformRuntimeInfo;
import 'package:pure_live/app/delegates.dart' show appLocalizationsDelegates, appSupportedLocales;
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/app/shell/desktop_title_frame.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/platforms/desktop/shell/shell_preferences.dart' show ShellWindowChrome;
import 'package:pure_live/platforms/desktop/shell/window_title_bar.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The window caption (the reference's `DesktopFrame`): one strip above the
/// whole navigator, in the design language's own look, driving the window
/// seam — on every page, not just the home tabs, and stood down while the
/// window is full screen.
void main() {
  for (final language in PureDesignLanguage.values) {
    testWidgets('the caption strip draws and drives the window under ${language.name}', (tester) async {
      final actions = _FakeChromeActions();
      final state = WindowChromeState.forTest();
      addTearDown(state.dispose);
      await _pump(tester, language: language, actions: actions, state: state, chrome: ShellWindowChrome.app);
      expect(tester.takeException(), isNull, reason: language.name);
      expect(find.byKey(const ValueKey('title-bar')), findsOneWidget, reason: language.name);
      // The buttons answer under every look; yaru's headerbar ships only a
      // close, like Ubuntu's.
      await tester.tap(find.byKey(const ValueKey('title-close')));
      await tester.pump();
      expect(actions.closed, 1, reason: language.name);
      if (language != PureDesignLanguage.yaru) {
        await tester.tap(find.byKey(const ValueKey('title-minimize')));
        await tester.pump();
        expect(actions.minimized, 1, reason: language.name);
        await tester.tap(find.byKey(const ValueKey('title-maximize')));
        await tester.pump();
        expect(actions.toggled, 1, reason: language.name);
      }
    });

    testWidgets('full screen stands the strip down under ${language.name}', (tester) async {
      final state = WindowChromeState.forTest(fullScreen: true);
      addTearDown(state.dispose);
      await _pump(
        tester,
        language: language,
        actions: _FakeChromeActions(),
        state: state,
        chrome: ShellWindowChrome.app,
      );
      expect(tester.takeException(), isNull, reason: language.name);
      // The video owns every pixel: no strip, the page fills the window.
      expect(find.byKey(const ValueKey('title-bar')), findsNothing, reason: language.name);
      expect(find.byKey(const ValueKey('page-under-caption')), findsOneWidget, reason: language.name);
    });

    testWidgets('the native caption keeps the strip away under ${language.name}', (tester) async {
      final state = WindowChromeState.forTest();
      addTearDown(state.dispose);
      await _pump(
        tester,
        language: language,
        actions: _FakeChromeActions(),
        state: state,
        chrome: ShellWindowChrome.system,
      );
      expect(tester.takeException(), isNull, reason: language.name);
      expect(find.byKey(const ValueKey('title-bar')), findsNothing, reason: language.name);
    });
  }

  testWidgets('the maximised state reaches the strip through the listener', (tester) async {
    const language = PureDesignLanguage.material;
    final state = WindowChromeState.forTest();
    addTearDown(state.dispose);
    await _pump(tester, language: language, actions: _FakeChromeActions(), state: state, chrome: ShellWindowChrome.app);
    // The Windows caption swaps its glyph when the window listener says the
    // window is maximised — the token strip draws `filter_none` then.
    state.maximized.value = true;
    await tester.pump();
    expect(find.byIcon(Icons.filter_none), findsOneWidget);
    state.maximized.value = false;
    await tester.pump();
    expect(find.byIcon(Icons.crop_square), findsOneWidget);
  });
}

class _FakeChromeActions implements WindowChromeActions {
  int minimized = 0;
  int toggled = 0;
  int closed = 0;
  int dragged = 0;

  @override
  Future<void> minimize() async => minimized++;

  @override
  Future<void> toggleMaximize() async => toggled++;

  @override
  Future<bool> isMaximized() async => false;

  @override
  Future<void> close() async => closed++;

  @override
  Future<void> startDragging() async => dragged++;
}

/// Pumps a route under the language's host with the caption frame mounted
/// where `app.dart` mounts it — inside the builder, above the navigator.
Future<void> _pump(
  WidgetTester tester, {
  required PureDesignLanguage language,
  required WindowChromeActions actions,
  required WindowChromeState state,
  required ShellWindowChrome chrome,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1200, 800);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        environmentProvider.overrideWithValue(const _DesktopEnvironment()),
        windowChromeProvider.overrideWithValue(chrome),
        windowChromeActionsProvider.overrideWithValue(actions),
        windowChromeStateProvider.overrideWithValue(state),
      ],
      child: PureConfigProvider(
        config: UiConfig(language: language),
        child: PureApp(
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const Scaffold(
                  body: KeyedSubtree(key: ValueKey('page-under-caption'), child: SizedBox.shrink()),
                ),
              ),
            ],
          ),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: appSupportedLocales,
          builder: (context, appChild) => TranslationProvider(child: DesktopTitleFrame(child: appChild!)),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// A desktop environment: the frame draws the caption only for a desktop
/// window's own chrome.
final class _DesktopEnvironment implements PlatformEnvironment {
  const _DesktopEnvironment();

  @override
  PlatformRuntimeInfo get runtime => PlatformRuntimeInfo(
    kind: PlatformKind.windows,
    formFactor: FormFactor.desktop,
    distribution: DesktopDistribution.values.first,
    isPackaged: false,
    executableRoot: Directory.current,
  );

  @override
  PlatformCapabilities get capabilities => PlatformCapabilities.none;
}
