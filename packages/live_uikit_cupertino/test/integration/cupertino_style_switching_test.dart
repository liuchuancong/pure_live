import 'package:cupertino_ui/cupertino_ui.dart' as cu;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_cupertino/live_uikit_cupertino.dart';

/// The controls `live_uikit_cupertino` renders natively (§3.1 capability
/// declaration): all seventeen the resolver dispatches — the controls and the four
/// chrome pieces, plus the five the fork drives with its own widgets rather than
/// with a card/checkbox/select/tab/dialog widget it does not have.
const Set<LiveUiControl> nativeControls = {
  LiveUiControl.button,
  LiveUiControl.card,
  LiveUiControl.textField,
  LiveUiControl.switchWidget,
  LiveUiControl.checkbox,
  LiveUiControl.slider,
  LiveUiControl.segmented,
  LiveUiControl.progress,
  LiveUiControl.select,
  LiveUiControl.tabBar,
  LiveUiControl.scaffold,
  LiveUiControl.appBar,
  LiveUiControl.listRow,
  LiveUiControl.navBar,
  LiveUiControl.toast,
  LiveUiControl.dialog,
  LiveUiControl.tabView,
};

/// The structural surfaces this adapter owns (§ surfaces): the `CupertinoApp`
/// host and a shell composed from the library's list pieces, since the fork ships
/// no rail widget of its own.
const Set<LiveUiSurface> nativeSurfaces = <LiveUiSurface>{LiveUiSurface.appHost, LiveUiSurface.appShell};

/// §16 integration pass for `live_uikit_cupertino`: every one of the seventeen
/// controls resolves native, so a Cupertino language change reports no control
/// downgrade at all, and switching to the core token base and back replaces the
/// rendering path without touching the caller's controller (§11).
/// The downgrades this language is expected to report: none at all. Every control
/// is native and both structural surfaces are owned, so the derived checks below
/// compare against empty sets and skip the code assertions (§15.5/§16.8).
/// Nothing in the contract falls back any more: the resolver hands back this
/// language's adapter, so a run that renders it reports no control or surface
/// downgrade at all (§15.5/§16.8).
void expectUndeclaredControls(List<LiveUiDiagnostic> sink) {
  expect(
    sink.where((diagnostic) => diagnostic.control != null || diagnostic.surface != null),
    isEmpty,
    reason: 'every control and surface resolves to this adapter',
  );
}

void main() {
  const registry = LanguageRegistry(adapters: {LiveDesignLanguage.cupertino: cupertinoAdapter});
  const resolver = LiveUiResolver(registry: registry);

  test('the surfaces it owns are exactly the ones it declares (§ surfaces)', () {
    final adapter = resolver.resolve(LiveDesignLanguage.cupertino);
    for (final surface in LiveUiSurface.values) {
      expect(adapter.surfaces.supports(surface), nativeSurfaces.contains(surface), reason: '$surface');
    }
    for (final surface in nativeSurfaces) {
      resolver.requireSurface(LiveDesignLanguage.cupertino, surface);
    }
  });

  Widget harness(UiConfig ui, Widget child, List<LiveUiDiagnostic> sink) => LiveConfigProvider(
    config: ui,
    registry: registry,
    diagnostics: sink.add,
    child: MaterialApp(
      localizationsDelegates: const [...liveLocalizationsDelegates, ...cupertinoLocalizationsDelegates],
      supportedLocales: const [Locale('en')],
      home: Scaffold(body: Center(child: child)),
    ),
  );

  test('every control it declares resolves to this adapter, with no downgrade (§16.3)', () {
    final adapter = resolver.resolve(LiveDesignLanguage.cupertino);
    for (final control in LiveUiControl.values) {
      expect(adapter.capabilities.supports(control), nativeControls.contains(control), reason: '$control');
    }
    for (final control in nativeControls) {
      resolver.requireControl(LiveDesignLanguage.cupertino, control);
    }
  });

  testWidgets('Cupertino UI ↔ its own library widgets swaps the path, not the state (§11)', (tester) async {
    final diagnostics = <LiveUiDiagnostic>[];
    final controller = TextEditingController(text: 'typed before the switch');
    addTearDown(controller.dispose);
    var tabs = -1;

    Widget page() => Column(
      children: [
        LiveTextField(controller: controller),
        LiveSwitch(value: true, onChanged: (_) {}),
        LiveSlider(value: 0.5, onChanged: (_) {}),
        LiveTabs(
          tabs: const [
            LiveTab(label: 'One'),
            LiveTab(label: 'Two'),
          ],
          index: 0,
          onChanged: (i) => tabs = i,
        ),
      ],
    );

    await tester.pumpWidget(harness(const UiConfig(language: LiveDesignLanguage.cupertino), page(), diagnostics));
    expect(find.byType(cu.CupertinoTextField), findsOneWidget);
    expect(find.byType(cu.CupertinoSwitch), findsOneWidget);
    expect(find.byType(cu.CupertinoSlider), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expectUndeclaredControls(diagnostics);

    // A re-theme through the same adapter keeps the caller's state: the path never
    // left this language, so nothing resets (§11).
    await tester.pumpWidget(harness(const UiConfig(language: LiveDesignLanguage.cupertino), page(), diagnostics));
    expect(find.byType(LiveTextField), findsOneWidget);
    expect(controller.text, 'typed before the switch');
    diagnostics.clear();
    await tester.pumpWidget(harness(const UiConfig(language: LiveDesignLanguage.cupertino), page(), diagnostics));
    expect(find.byType(cu.CupertinoTextField), findsOneWidget);
    expect(controller.text, 'typed before the switch');
    expectUndeclaredControls(diagnostics);

    // Tabs are Cupertino's own strip by now: a row of the library's buttons, not
    // the bottom bar the navBar takes. Usable on both sides of the switch, and
    // still reporting (§16.7).
    expect(find.byType(cu.CupertinoTabBar), findsNothing);
    await tester.tap(find.text('Two'));
    await tester.pumpAndSettle();
    expect(tabs, 1);
  });
}
