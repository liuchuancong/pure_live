import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/styling.dart';

/// §14/§15.5: every downgrade the runtime decides must reach the host's sink, not
/// only the language-wide one. These tests drive a real [LiveConfigProvider] with
/// a deliberately partial adapter, so the per-control `controlUnsupported` facts the
/// specs promise a composition root are asserted where they are produced.
class _ButtonOnlyAdapter extends SharedLanguageAdapter {
  const new();

  @override
  LiveDesignLanguage get language => LiveDesignLanguage.material;

  @override
  String get id => 'buttonOnly';

  @override
  String get displayName => 'Button Only';

  @override
  LiveUiCapabilities get capabilities => const LiveUiCapabilities({LiveUiControl.button});
}

/// A second language, so a switch can be shown to re-report rather than leak state.
class _QuietAdapter extends SharedLanguageAdapter {
  const new();

  @override
  LiveDesignLanguage get language => LiveDesignLanguage.wind;

  @override
  String get id => 'quiet';

  @override
  String get displayName => 'Quiet';

  @override
  LiveUiCapabilities get capabilities => const LiveUiCapabilities({LiveUiControl.button});
}

void main() {
  const registry = LanguageRegistry(
    adapters: {LiveDesignLanguage.material: _ButtonOnlyAdapter(), LiveDesignLanguage.wind: _QuietAdapter()},
    fallback: SharedLanguageAdapter(),
  );

  Widget harness(UiConfig config, List<LiveUiDiagnostic> sink) =>
      LiveConfigProvider(config: config, registry: registry, diagnostics: sink.add, child: const SizedBox.shrink());

  testWidgets('a registered adapter reports each undeclared control and surface once (§15.5)', (tester) async {
    final sink = <LiveUiDiagnostic>[];
    await tester.pumpWidget(harness(const UiConfig(language: LiveDesignLanguage.material), sink));

    // The adapter declares one control and no surface, so the report is the rest
    // of the control set plus both structural surfaces — two kinds of downgrade
    // with two codes, and the host learns which window frame it is actually in.
    final controls = sink.where((diagnostic) => diagnostic.control != null);
    final surfaces = sink.where((diagnostic) => diagnostic.surface != null);
    expect(controls.map((diagnostic) => diagnostic.code).toSet(), {LiveUiDiagnosticCode.controlUnsupported});
    expect(
      controls.map((diagnostic) => diagnostic.control).toSet(),
      LiveUiControl.values.toSet().difference(const {LiveUiControl.button}),
    );
    expect(surfaces.map((diagnostic) => diagnostic.code).toSet(), {LiveUiDiagnosticCode.surfaceUnsupported});
    expect(surfaces.map((diagnostic) => diagnostic.surface).toSet(), LiveUiSurface.values.toSet());
    expect(sink, hasLength(LiveUiControl.values.length - 1 + LiveUiSurface.values.length));
    expect(sink.every((diagnostic) => diagnostic.language == LiveDesignLanguage.material), isTrue);

    // Rebuilds with the same language report nothing new: the facts are per
    // language change, not per frame (§10 "fired once per language change").
    await tester.pumpWidget(harness(const UiConfig(language: LiveDesignLanguage.material), sink));
    expect(sink, hasLength(LiveUiControl.values.length - 1 + LiveUiSurface.values.length));
  });

  testWidgets('switching language re-reports for the new adapter', (tester) async {
    final sink = <LiveUiDiagnostic>[];
    await tester.pumpWidget(harness(const UiConfig(language: LiveDesignLanguage.material), sink));
    final firstCount = sink.length;

    await tester.pumpWidget(harness(const UiConfig(language: LiveDesignLanguage.wind), sink));
    expect(sink.length, greaterThan(firstCount));
    expect(
      sink.where((diagnostic) => diagnostic.language == LiveDesignLanguage.wind).length,
      LiveUiControl.values.length - 1 + LiveUiSurface.values.length,
      reason: 'the new language reports its own set once',
    );
    expect(sink.where((diagnostic) => diagnostic.language == LiveDesignLanguage.material).length, firstCount);
  });

  testWidgets('a language with no adapter reports adapterMissing, not the control set', (tester) async {
    final sink = <LiveUiDiagnostic>[];
    // `glass` is configured but not registered here: the whole language falls back,
    // and that single fact is what a host needs — the per-control list would be noise.
    await tester.pumpWidget(harness(const UiConfig(language: LiveDesignLanguage.glass), sink));

    expect(sink.map((diagnostic) => diagnostic.code).toSet(), {LiveUiDiagnosticCode.adapterMissing});
    expect(sink, hasLength(1));
  });

  testWidgets('a host without a sink stays quiet under the same decisions', (tester) async {
    await tester.pumpWidget(
      const LiveConfigProvider(
        config: UiConfig(language: LiveDesignLanguage.material),
        registry: registry,
        child: SizedBox.shrink(),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a fail-fast policy faults even without a sink (§7)', (tester) async {
    await tester.pumpWidget(
      const LiveConfigProvider(
        config: UiConfig(language: LiveDesignLanguage.material),
        registry: registry,
        fallbackPolicy: LiveUiFallbackPolicy(onUnsupportedControl: LiveUiFallbackAction.failFast),
        child: SizedBox.shrink(),
      ),
    );
    expect(tester.takeException(), isA<LiveUiResolutionException>());
  });
}
