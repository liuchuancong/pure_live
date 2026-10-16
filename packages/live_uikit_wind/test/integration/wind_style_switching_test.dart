import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluttersdk_wind/fluttersdk_wind.dart' as wind;
import 'package:live_uikit/styling.dart';
import 'package:live_uikit_wind/live_uikit_wind.dart';

/// The controls `live_uikit_wind` renders natively (§3.1 capability
/// declaration): six of the thirteen the resolver dispatches.
const Set<LiveUiControl> nativeControls = {
  LiveUiControl.button,
  LiveUiControl.card,
  LiveUiControl.textField,
  LiveUiControl.switchWidget,
  LiveUiControl.checkbox,
  LiveUiControl.select,
};

/// §16/§11 integration pass for `live_uikit_wind`.
///
/// Wind renders six of the thirteen controls natively, so a switch is the moment the
/// other seven — `slider`, `segmented`, `progress`, `tabBar` and the page trio
/// `scaffold`, `appBar`, `listRow` that no adapter maps yet — have to keep working
/// through the shared token renderer — and the
/// moment a caller-owned controller has to prove it survives the re-render. Both
/// directions run against the production registry and resolver types.
/// The downgrades this language is expected to report: every control the adapter
/// does not declare, each exactly once per language change (§15.5/§16.8).
void expectUndeclaredControls(List<LiveUiDiagnostic> sink) {
  expect(sink.map((diagnostic) => diagnostic.code).toSet(), {LiveUiDiagnosticCode.controlUnsupported});
  expect(sink.map((diagnostic) => diagnostic.control).toSet(), LiveUiControl.values.toSet().difference(nativeControls));
  expect(sink, hasLength(LiveUiControl.values.length - nativeControls.length));
}

void main() {
  const registry = LanguageRegistry(
    adapters: {LiveDesignLanguage.wind: windUiAdapter},
    fallback: SharedLanguageAdapter(),
  );
  const resolver = LiveUiResolver(registry: registry);

  Widget harness(UiConfig ui, Widget child, List<LiveUiDiagnostic> sink) => LiveConfigProvider(
    config: ui,
    registry: registry,
    diagnostics: sink.add,
    child: MaterialApp(
      localizationsDelegates: liveLocalizationsDelegates,
      supportedLocales: const [Locale('en')],
      home: Scaffold(body: Center(child: child)),
    ),
  );

  test('the six declared controls resolve native, the rest shared (§16.3)', () {
    for (final control in LiveUiControl.values) {
      final native = nativeControls.contains(control);
      final resolution = resolver.resolveControl(LiveDesignLanguage.wind, control);
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

  testWidgets('Wind ↔ core material swaps the rendering path, not the state (§11)', (tester) async {
    final diagnostics = <LiveUiDiagnostic>[];
    final controller = TextEditingController(text: 'typed before the switch');
    addTearDown(controller.dispose);

    Widget page() => Column(
      children: [
        LiveTextField(controller: controller),
        LiveCard(onTap: () {}, child: const Text('card body')),
        LiveSwitch(value: true, onChanged: (_) {}),
        LiveSlider(value: 0.5, onChanged: (_) {}),
        const LiveProgress(value: 0.5),
        LiveSelect<String>(items: const ['a'], itemLabel: (item) => item, value: 'a', onChanged: (_) {}),
      ],
    );

    await tester.pumpWidget(harness(const UiConfig(language: LiveDesignLanguage.wind), page(), diagnostics));
    expect(find.byType(wind.WInput), findsOneWidget);
    expect(find.byType(wind.WCard), findsOneWidget);
    expect(find.byType(wind.WSwitch), findsOneWidget);
    expect(find.byType(wind.WSelect<String>), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    // Slider and progress are not native to Wind: they render through the token
    // base, which is the declared, reported fallback — not a gap.
    expect(find.byType(LiveSlider), findsOneWidget);
    expectUndeclaredControls(diagnostics);

    await tester.pumpWidget(harness(const UiConfig(), page(), diagnostics));
    expect(find.byType(wind.WInput), findsNothing);
    expect(find.byType(wind.WCard), findsNothing);
    expect(find.byType(wind.WSelect<String>), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    expect(controller.text, 'typed before the switch');
    expect(
      diagnostics.map((diagnostic) => diagnostic.code),
      contains(LiveUiDiagnosticCode.adapterMissing),
      reason: 'the core base has no adapter of its own, so the gap is reported',
    );

    diagnostics.clear();
    await tester.pumpWidget(harness(const UiConfig(language: LiveDesignLanguage.wind), page(), diagnostics));
    expect(find.byType(wind.WInput), findsOneWidget);
    expect(find.byType(wind.WSelect<String>), findsOneWidget);
    expect(controller.text, 'typed before the switch');
    expectUndeclaredControls(diagnostics);
  });
}
