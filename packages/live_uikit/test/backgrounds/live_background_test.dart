import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/live_uikit.dart';

/// §12's blur rule, asserted where it is applied: `LiveBackground` reads the one
/// environment fact it owns (`LiveTheme.canBlur`) and degrades the frosted
/// treatment instead of paying for an effect the user's accessibility setting or the
/// device ruled out. The same flag gates the image blur layer in the same `build`.
///
/// The blur is the core's own decision, so the adapter below only has to let the
/// provider resolve a language — there is none to claim, and `wrap` hands the
/// subtree back as it came.
class _PassthroughAdapter implements LanguageAdapter {
  const new();

  @override
  LiveDesignLanguage get language => LiveDesignLanguage.material;

  @override
  String get id => 'passthrough';

  @override
  String get displayName => 'Passthrough';

  @override
  LiveUiCapabilities get capabilities => const LiveUiCapabilities.none();

  @override
  LiveUiSurfaceCapabilities get surfaces => const LiveUiSurfaceCapabilities.none();

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

const _registry = LanguageRegistry(adapters: {LiveDesignLanguage.material: _PassthroughAdapter()});

void main() {
  const surface = Color(0x80102030);
  const language = LiveDesignLanguage.material;

  Widget harness(UiConfig? config, Widget child) {
    const style = LiveBackgroundStyle.glass(color: surface);
    final background = LiveBackground(style: style, child: child);
    if (config == null) {
      return Directionality(textDirection: TextDirection.ltr, child: background);
    }
    return LiveConfigProvider(
      config: config,
      registry: _registry,
      child: Directionality(textDirection: TextDirection.ltr, child: background),
    );
  }

  testWidgets('a frosted surface blurs while the theme allows it (§12)', (tester) async {
    await tester.pumpWidget(harness(const UiConfig(language: language), const Text('content')));
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.text('content'), findsOneWidget);
  });

  testWidgets('reduceTransparency drops the filter and keeps the fill (§12)', (tester) async {
    await tester.pumpWidget(
      harness(const UiConfig(language: language, reduceTransparency: true), const Text('content')),
    );
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.text('content'), findsOneWidget);
    final decorated = tester.widget<DecoratedBox>(find.byType(DecoratedBox).first);
    expect((decorated.decoration as BoxDecoration).color, surface);
  });

  testWidgets('an unaffordable host is enough on its own', (tester) async {
    await tester.pumpWidget(
      const LiveConfigProvider(
        config: UiConfig(language: language),
        registry: _registry,
        hardwareBlur: false,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: LiveBackground(
            style: LiveBackgroundStyle.glass(color: surface),
            child: Text('content'),
          ),
        ),
      ),
    );
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('outside a provider the style is honoured as written (§12)', (tester) async {
    await tester.pumpWidget(harness(null, const Text('content')));
    expect(find.byType(BackdropFilter), findsOneWidget);
  });
}
