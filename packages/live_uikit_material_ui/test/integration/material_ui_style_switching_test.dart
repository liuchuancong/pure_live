import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/styling.dart';
import 'package:live_uikit_material_ui/live_uikit_material_ui.dart';
import 'package:material_ui/material_ui.dart' as mu;

/// §16 integration pass for `live_uikit_material_ui`.
///
/// Material UI and the core `material` token base are the pair §11 calls the most
/// error-prone to switch between: both are Material-shaped, so a stale fork theme
/// or a mis-imported SDK type survives a switch unnoticed. These tests drive the
/// real [LiveConfigProvider] → [LiveUiResolver] → adapter path in both
/// directions, keep one caller-owned controller across the switch, and check the
/// diagnostics a switch is expected to produce — and only those.
/// The downgrades this language is expected to report: every control the adapter
/// does not declare, each exactly once per language change (§15.5/§16.8).
void expectUndeclaredControls(List<LiveUiDiagnostic> sink) {
  expect(sink.map((diagnostic) => diagnostic.code).toSet(), {LiveUiDiagnosticCode.controlUnsupported});
  expect(sink.map((diagnostic) => diagnostic.control).toSet(), {LiveUiControl.select, LiveUiControl.tabBar});
  expect(sink, hasLength(2));
}

void main() {
  const registry = LanguageRegistry(
    adapters: {LiveDesignLanguage.materialUi: materialUiAdapter},
    fallback: SharedLanguageAdapter(),
  );
  const resolver = LiveUiResolver(registry: registry);

  UiConfig config(LiveDesignLanguage language, {UiBrightnessMode brightness = UiBrightnessMode.light, Color? accent}) =>
      UiConfig(language: language, brightness: brightness, accent: accent);

  /// Harness with the diagnostics sink wired, as §10 requires of the host.
  Widget harness(UiConfig ui, Widget child, List<LiveUiDiagnostic> sink) => LiveConfigProvider(
    config: ui,
    registry: registry,
    diagnostics: sink.add,
    child: MaterialApp(
      localizationsDelegates: const [...liveLocalizationsDelegates, ...materialUiLocalizationsDelegates],
      supportedLocales: const [Locale('en')],
      home: Scaffold(body: Center(child: child)),
    ),
  );

  group('the resolution surface (§16.3/§16.8)', () {
    test('eight controls resolve native, select and tabs through the shared renderer', () {
      for (final control in LiveUiControl.values) {
        final native = control != LiveUiControl.select && control != LiveUiControl.tabBar;
        final resolution = resolver.resolveControl(LiveDesignLanguage.materialUi, control);
        expect(
          resolution.implementation.kind,
          native ? LiveImplementationKind.adapterNative : LiveImplementationKind.shared,
          reason: '$control',
        );
        expect(
          resolution.diagnostic?.code,
          native ? isNull : LiveUiDiagnosticCode.controlUnsupported,
          reason: '$control must be the only kind of noise',
        );
      }
    });
  });

  group('runtime switching (§11)', () {
    testWidgets('Material UI ↔ core material replaces the theme scope both ways', (tester) async {
      final diagnostics = <LiveUiDiagnostic>[];
      final controller = TextEditingController(text: 'typed before the switch');
      addTearDown(controller.dispose);
      var tabs = 0;
      var selected = '';

      Widget page() => Column(
        children: [
          LiveTextField(controller: controller),
          LiveSwitch(value: true, onChanged: (_) {}),
          LiveTabs(
            tabs: const [
              LiveTab(label: 'One'),
              LiveTab(label: 'Two'),
            ],
            index: 0,
            onChanged: (i) => tabs = i,
          ),
          LiveSelect<String>(items: const ['a', 'b'], itemLabel: (s) => s, onChanged: (v) => selected = v),
        ],
      );

      // §16.7: the two controls Material UI serves through the shared renderer
      // must stay usable — and keep their typed selection — whichever language
      // is drawing the rest of the page.
      Future<void> useFallbackControls() async {
        tabs = -1;
        selected = '';
        await tester.tap(find.text('Two'));
        await tester.pump();
        expect(tabs, 1, reason: 'tabs still report the chosen index');
        await tester.tap(find.byType(LiveSelect<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('b').last);
        await tester.pumpAndSettle();
        expect(selected, 'b', reason: 'select must stay typed and callable');
      }

      await tester.pumpWidget(harness(config(LiveDesignLanguage.materialUi), page(), diagnostics));
      expect(find.byType(mu.TextField), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(mu.Switch), findsOneWidget);
      expect(find.byType(mu.Theme), findsWidgets);
      expectUndeclaredControls(diagnostics);
      await useFallbackControls();

      // Out to the core token base: the fork scope and the fork widgets must all
      // be gone, and the caller's text must be untouched by the re-render.
      await tester.pumpWidget(harness(config(LiveDesignLanguage.material), page(), diagnostics));
      expect(find.byType(mu.TextField), findsNothing);
      expect(find.byType(mu.Theme), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      expect(controller.text, 'typed before the switch');
      expect(
        diagnostics.map((diagnostic) => diagnostic.code),
        contains(LiveUiDiagnosticCode.adapterMissing),
        reason: 'the core base has no adapter of its own, so the gap is reported',
      );
      await useFallbackControls();

      // And back in: a fresh fork scope, not the stale one.
      diagnostics.clear();
      await tester.pumpWidget(harness(config(LiveDesignLanguage.materialUi), page(), diagnostics));
      expect(find.byType(mu.TextField), findsOneWidget);
      expect(find.byType(mu.Theme), findsWidgets);
      expect(controller.text, 'typed before the switch');
      expectUndeclaredControls(diagnostics);
      await useFallbackControls();
    });

    testWidgets('brightness and accent re-skin Material UI without a restart (§16.4)', (tester) async {
      final diagnostics = <LiveUiDiagnostic>[];
      mu.ThemeData? forkTheme;

      Widget probe(UiConfig ui) => harness(
        ui,
        Builder(
          builder: (context) {
            forkTheme = mu.Theme.of(context);
            return const SizedBox.shrink();
          },
        ),
        diagnostics,
      );

      await tester.pumpWidget(probe(config(LiveDesignLanguage.materialUi)));
      expect(forkTheme?.brightness, Brightness.light);
      final lightPrimary = forkTheme?.colorScheme.primary;

      await tester.pumpWidget(
        probe(
          config(LiveDesignLanguage.materialUi, brightness: UiBrightnessMode.dark, accent: const Color(0xFFAA0000)),
        ),
      );
      expect(forkTheme?.brightness, Brightness.dark);
      expect(forkTheme?.colorScheme.primary, isNot(lightPrimary));
      expectUndeclaredControls(diagnostics);
    });
  });
}
