import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/live_uikit.dart';

/// §15.5: what a host is told about the language it asked for. The downgrades
/// this suite used to assert are gone — an unregistered language and an
/// undeclared capability are faults the resolver raises, so what is left for the
/// provider to report is the adapter it resolved and the theme it handed down.
class _StubAdapter implements LanguageAdapter {
  const new({required this.language, required this.id, required this.displayName});

  @override
  final LiveDesignLanguage language;

  @override
  final String id;

  @override
  final String displayName;

  @override
  LiveUiCapabilities get capabilities => const LiveUiCapabilities({LiveUiControl.button});

  @override
  LiveUiSurfaceCapabilities get surfaces => const LiveUiSurfaceCapabilities({LiveUiSurface.appHost});

  @override
  Widget wrap(BuildContext context, DesignToken token, Widget child) => child;

  @override
  Widget button(BuildContext context, LanguageButtonSpec spec) => const SizedBox.shrink();

  @override
  Widget card(BuildContext context, LanguageCardSpec spec) => spec.child;

  @override
  Widget textField(BuildContext context, LanguageTextFieldSpec spec) => const SizedBox.shrink();

  @override
  Widget switchWidget(BuildContext context, LanguageSwitchSpec spec) => const SizedBox.shrink();

  @override
  Widget checkbox(BuildContext context, LanguageCheckboxSpec spec) => const SizedBox.shrink();

  @override
  Widget slider(BuildContext context, LanguageSliderSpec spec) => const SizedBox.shrink();

  @override
  Widget segmented(BuildContext context, LanguageSegmentedSpec spec) => const SizedBox.shrink();

  @override
  Widget progress(BuildContext context, LanguageProgressSpec spec) => const SizedBox.shrink();

  @override
  Widget select<T>(BuildContext context, LanguageSelectSpec<T> spec) => const SizedBox.shrink();

  @override
  Widget tabBar(BuildContext context, LanguageTabsSpec spec) => const SizedBox.shrink();

  @override
  Widget scaffold(BuildContext context, LanguageScaffoldSpec spec) => spec.body;

  @override
  Widget appBar(BuildContext context, LanguageAppBarSpec spec) => const SizedBox.shrink();

  @override
  Widget listRow(BuildContext context, LanguageListRowSpec spec) => const SizedBox.shrink();

  @override
  Widget navBar(BuildContext context, LanguageNavBarSpec spec) => const SizedBox.shrink();

  @override
  Widget toast(BuildContext context, LanguageToastSpec spec) => const SizedBox.shrink();

  @override
  Widget dialog(BuildContext context, LanguageDialogSpec spec) => spec.content ?? const SizedBox.shrink();

  @override
  Widget tabView(BuildContext context, LanguageTabViewSpec spec) =>
      spec.pages.isEmpty ? const SizedBox.shrink() : spec.pages[spec.index];

  @override
  Widget appHost(BuildContext context, LanguageHostSpec spec) =>
      spec.builder?.call(context, const SizedBox.shrink()) ?? const SizedBox.shrink();

  @override
  Widget shell(BuildContext context, LanguageShellSpec spec) => spec.child;
}

void main() {
  const material = _StubAdapter(language: LiveDesignLanguage.material, id: 'material', displayName: 'Material');
  const wind = _StubAdapter(language: LiveDesignLanguage.wind, id: 'wind', displayName: 'Wind');
  const registry = LanguageRegistry(adapters: {LiveDesignLanguage.material: material, LiveDesignLanguage.wind: wind});

  Widget harness(UiConfig config, {LiveUiDiagnosticSink? diagnostics}) =>
      LiveConfigProvider(config: config, registry: registry, diagnostics: diagnostics, child: const SizedBox.shrink());

  /// Pumps [config] and hands back the theme the subtree reads.
  Future<LiveTheme> themeOf(UiConfig config, WidgetTester tester) async {
    late LiveTheme theme;
    await tester.pumpWidget(
      LiveConfigProvider(
        config: config,
        registry: registry,
        child: Builder(
          builder: (context) {
            theme = LiveTheme.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return theme;
  }

  testWidgets('the resolved theme carries the adapter registered for the language (§15.3)', (tester) async {
    final theme = await themeOf(const UiConfig(language: LiveDesignLanguage.material), tester);

    expect(theme.adapter, same(material));
    expect(theme.adapter.id, 'material');
    expect(theme.config.language, LiveDesignLanguage.material);
    expect(theme.supports(LiveUiControl.button), isTrue);
    expect(theme.supportsSurface(LiveUiSurface.appHost), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching language swaps the adapter under the same subtree', (tester) async {
    late LiveTheme theme;
    Widget app(UiConfig config) => LiveConfigProvider(
      config: config,
      registry: registry,
      child: Builder(
        builder: (context) {
          theme = LiveTheme.of(context);
          return const SizedBox.shrink();
        },
      ),
    );

    await tester.pumpWidget(app(const UiConfig(language: LiveDesignLanguage.material)));
    expect(theme.adapter, same(material));

    await tester.pumpWidget(app(const UiConfig(language: LiveDesignLanguage.wind)));
    expect(theme.adapter, same(wind), reason: 'a language change re-skins the tree, it does not rebuild the page');
    expect(theme.config.language, LiveDesignLanguage.wind);
  });

  testWidgets('a language with no adapter faults rather than paints a degraded tree (§7)', (tester) async {
    await tester.pumpWidget(harness(const UiConfig(language: LiveDesignLanguage.glass)));

    expect(tester.takeException(), isA<LiveUiResolutionException>());
  });

  testWidgets('an empty registry faults for whatever the config asked for', (tester) async {
    await tester.pumpWidget(
      const LiveConfigProvider(
        config: UiConfig(language: LiveDesignLanguage.material),
        registry: LanguageRegistry(adapters: {}),
        child: SizedBox.shrink(),
      ),
    );

    expect(tester.takeException(), isA<LiveUiResolutionException>());
  });

  testWidgets('a host without a sink, and a host with one, both render the same tree', (tester) async {
    // The sink is the device-capability channel (§3.10); whether the host listens
    // cannot change which adapter renders, so both wirings have to reach the
    // theme intact.
    final sink = <LiveUiDiagnostic>[];
    await tester.pumpWidget(harness(const UiConfig(language: LiveDesignLanguage.material), diagnostics: sink.add));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(harness(const UiConfig(language: LiveDesignLanguage.material)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('an effect the device cannot afford is reported once per verdict', (tester) async {
    // §15.3 tail: the config asked for a backdrop blur and the hardware says it
    // cannot do one. The window still renders, flatter — but the host hears that
    // it is not what was configured, exactly once.
    final sink = <LiveUiDiagnostic>[];
    Widget blurred({bool hardwareBlur = false}) => LiveConfigProvider(
      config: const UiConfig(language: LiveDesignLanguage.material, transparency: 0.8),
      registry: registry,
      hardwareBlur: hardwareBlur,
      diagnostics: sink.add,
      child: const SizedBox.shrink(),
    );

    await tester.pumpWidget(blurred());
    expect(sink.map((diagnostic) => diagnostic.code), [LiveUiDiagnosticCode.unsupportedEffect]);

    await tester.pumpWidget(blurred());
    expect(sink, hasLength(1), reason: 'the same verdict is not a new fact');

    await tester.pumpWidget(blurred(hardwareBlur: true));
    expect(sink, hasLength(1), reason: 'gaining the effect back is not a downgrade to report');
  });

  testWidgets('a nested provider re-themes its own subtree', (tester) async {
    late LiveTheme outer;
    late LiveTheme inner;
    await tester.pumpWidget(
      LiveConfigProvider(
        config: const UiConfig(language: LiveDesignLanguage.material),
        registry: registry,
        child: Builder(
          builder: (context) {
            outer = LiveTheme.of(context);
            return LiveConfigProvider(
              config: const UiConfig(language: LiveDesignLanguage.wind, density: UiDensity.compact),
              registry: registry,
              child: Builder(
                builder: (innerContext) {
                  inner = LiveTheme.of(innerContext);
                  return const SizedBox.shrink();
                },
              ),
            );
          },
        ),
      ),
    );

    expect(outer.adapter, same(material));
    expect(inner.adapter, same(wind));
    expect(inner.config.density, UiDensity.compact, reason: 'the inner choice wins below itself only');
    expect(outer.config.density, UiDensity.comfortable);
  });
}
