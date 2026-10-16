import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluttersdk_wind/fluttersdk_wind.dart' as wind;
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_wind/live_uikit_wind.dart';

/// The controls `live_uikit_wind` renders natively (§3.1 capability
/// declaration): all fifteen the resolver dispatches — the six the fork has a
/// widget for, and the nine it does not (the rail, the segmented track, the bar,
/// the tab strip, the page frame, the top bar, the list row, the bottom bar and
/// the toast surface), which are composed out of the fork's own parts.
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
};

/// The structural surfaces this adapter owns (§ surfaces): the app host, not the
/// shell.
const Set<LiveUiSurface> nativeSurfaces = <LiveUiSurface>{LiveUiSurface.appHost};

/// §16/§11 integration pass for `live_uikit_wind`.
///
/// Wind renders the whole control contract and hosts the app itself, so a switch
/// into it replaces every rendering path at once; the only downgrade left is the
/// shell, which this build does not claim. Switching to the core token base and
/// back still has to prove a caller-owned controller survives the re-render (§11).
/// The downgrades this language is expected to report: none for the controls,
/// because nothing in the contract falls back any more, and none for the app host
/// — this library has no application widget, so the host is the app's own
/// `WidgetsApp` under a `WindTheme` scope. Only the shell falls back, once per
/// language change (§15.5/§16.8).
void expectUndeclaredControls(List<LiveUiDiagnostic> sink) {
  // The controls fall back not at all and the surfaces only in part: the host is
  // this adapter's, the shell is still the core's — two kinds of downgrade with
  // two codes (§ surfaces).
  final controls = sink.where((diagnostic) => diagnostic.control != null);
  final surfaces = sink.where((diagnostic) => diagnostic.surface != null);
  // A language that renders every control reports no control downgrade at all,
  // so the code check only applies when something actually fell back.
  final expectedControls = LiveUiControl.values.toSet().difference(nativeControls);
  expect(controls.map((diagnostic) => diagnostic.control).toSet(), expectedControls);
  if (expectedControls.isNotEmpty) {
    expect(controls.map((diagnostic) => diagnostic.code).toSet(), {LiveUiDiagnosticCode.controlUnsupported});
  }
  final expectedSurfaces = LiveUiSurface.values.toSet().difference(nativeSurfaces);
  expect(surfaces.map((diagnostic) => diagnostic.surface).toSet(), expectedSurfaces);
  if (expectedSurfaces.isNotEmpty) {
    expect(surfaces.map((diagnostic) => diagnostic.code).toSet(), {LiveUiDiagnosticCode.surfaceUnsupported});
  }
  expect(
    sink,
    hasLength(
      LiveUiControl.values.length + LiveUiSurface.values.length - nativeControls.length - nativeSurfaces.length,
    ),
  );
}

void main() {
  const registry = LanguageRegistry(
    adapters: {LiveDesignLanguage.wind: windAdapter},
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

  test('every control resolves native, because this language declares the whole contract (§16.3)', () {
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
    expect(nativeControls, LiveUiControl.values.toSet());
  });

  testWidgets('Wind ↔ the token base swaps the rendering path, not the state (§11)', (tester) async {
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
    // Slider and progress are the fork's own parts now — a rail and a run drawn
    // as `WDiv`s — so no token renderer stands in for them inside a Wind page.
    expect(find.byType(TokenSlider), findsNothing);
    expect(find.byType(TokenProgress), findsNothing);
    expect(find.byWidgetPredicate((widget) => widget.runtimeType.toString().startsWith('Token')), findsNothing);
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
