import 'package:cupertino_ui/cupertino_ui.dart' as cu;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/styling.dart';
import 'package:live_uikit_cupertino_ui/live_uikit_cupertino_ui.dart';

/// §16 integration pass for `live_uikit_cupertino_ui`: the four declared controls
/// resolve native and the six others resolve shared, and switching to the core
/// token base and back replaces the rendering path without touching the caller's
/// controller or the fallback controls' behaviour (§11).
/// The downgrades this language is expected to report: every control the adapter
/// does not declare, each exactly once per language change (§15.5/§16.8).
void expectUndeclaredControls(List<LiveUiDiagnostic> sink) {
  expect(sink.map((diagnostic) => diagnostic.code).toSet(), {LiveUiDiagnosticCode.controlUnsupported});
  expect(sink.map((diagnostic) => diagnostic.control).toSet(), {
    LiveUiControl.card,
    LiveUiControl.checkbox,
    LiveUiControl.segmented,
    LiveUiControl.progress,
    LiveUiControl.select,
    LiveUiControl.tabBar,
  });
  expect(sink, hasLength(6));
}

void main() {
  const registry = LanguageRegistry(
    adapters: {LiveDesignLanguage.cupertinoUi: cupertinoUiAdapter},
    fallback: SharedLanguageAdapter(),
  );
  const resolver = LiveUiResolver(registry: registry);

  const nativeControls = {
    LiveUiControl.button,
    LiveUiControl.textField,
    LiveUiControl.switchWidget,
    LiveUiControl.slider,
  };

  Widget harness(UiConfig ui, Widget child, List<LiveUiDiagnostic> sink) => LiveConfigProvider(
    config: ui,
    registry: registry,
    diagnostics: sink.add,
    child: MaterialApp(
      localizationsDelegates: const [...liveLocalizationsDelegates, ...cupertinoUiLocalizationsDelegates],
      supportedLocales: const [Locale('en')],
      home: Scaffold(body: Center(child: child)),
    ),
  );

  test('the four declared controls resolve native, the rest shared (§16.3)', () {
    for (final control in LiveUiControl.values) {
      final native = nativeControls.contains(control);
      final resolution = resolver.resolveControl(LiveDesignLanguage.cupertinoUi, control);
      expect(
        resolution.implementation.kind,
        native ? LiveImplementationKind.adapterNative : LiveImplementationKind.shared,
        reason: '$control',
      );
      expect(
        resolution.diagnostic?.code,
        native ? isNull : LiveUiDiagnosticCode.controlUnsupported,
        reason: '$control',
      );
    }
  });

  testWidgets('Cupertino UI ↔ core material swaps the path, not the state (§11)', (tester) async {
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

    await tester.pumpWidget(harness(const UiConfig(language: LiveDesignLanguage.cupertinoUi), page(), diagnostics));
    expect(find.byType(cu.CupertinoTextField), findsOneWidget);
    expect(find.byType(cu.CupertinoSwitch), findsOneWidget);
    expect(find.byType(cu.CupertinoSlider), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expectUndeclaredControls(diagnostics);

    // `UiConfig()` defaults to the core `material` token base.
    await tester.pumpWidget(harness(const UiConfig(), page(), diagnostics));
    expect(find.byType(cu.CupertinoTextField), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    expect(controller.text, 'typed before the switch');
    expect(
      diagnostics.map((diagnostic) => diagnostic.code),
      contains(LiveUiDiagnosticCode.adapterMissing),
      reason: 'the core base has no adapter of its own, so the gap is reported',
    );

    diagnostics.clear();
    await tester.pumpWidget(harness(const UiConfig(language: LiveDesignLanguage.cupertinoUi), page(), diagnostics));
    expect(find.byType(cu.CupertinoTextField), findsOneWidget);
    expect(controller.text, 'typed before the switch');
    expectUndeclaredControls(diagnostics);

    // Tabs are a shared-fallback control in this language: usable on both sides
    // of the switch, and still typed (§16.7).
    await tester.tap(find.text('Two'));
    await tester.pump();
    expect(tabs, 1);
  });
}
