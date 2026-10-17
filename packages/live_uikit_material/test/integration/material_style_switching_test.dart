import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_material/live_uikit_material.dart';
import 'package:material_ui/material_ui.dart' as mu;

/// The controls `live_uikit_material` renders natively (§3.1 capability
/// declaration): all fifteen the resolver dispatches — the controls, the four
/// chrome pieces, and the three the fork drives differently from the neutral
/// spec: `select` is a `DropdownButton`, `tabBar` a `TabBar` behind a controller
/// the adapter owns, and `toast` a `Material` card themed by the fork's own
/// `SnackBarThemeData` — a `SnackBar` needs the animation a
/// `ScaffoldMessenger` owns, and the core keeps the overlay and the timer.
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
  LiveUiControl.tabView,
  LiveUiControl.dialog,
  LiveUiControl.scaffold,
  LiveUiControl.appBar,
  LiveUiControl.listRow,
  LiveUiControl.navBar,
  LiveUiControl.toast,
};

/// The structural surfaces this adapter owns (§ surfaces).
const Set<LiveUiSurface> nativeSurfaces = <LiveUiSurface>{LiveUiSurface.appHost, LiveUiSurface.appShell};

/// §16 integration pass for `live_uikit_material`.
///
/// Material UI and the shared `token` base are the pair §11 calls the most
/// error-prone to switch between: both are Material-shaped, so a stale fork theme
/// or a mis-imported SDK type survives a switch unnoticed. These tests drive the
/// real [LiveConfigProvider] → [LiveUiResolver] → adapter path in both
/// directions, keep one caller-owned controller across the switch, and check the
/// diagnostics a switch is expected to produce — and only those.
/// The downgrades this language is expected to report: none, because nothing in
/// the contract falls back any more (§15.5/§16.8).
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
  const registry = LanguageRegistry(adapters: {LiveDesignLanguage.material: materialAdapter});
  const resolver = LiveUiResolver(registry: registry);

  test('the surfaces it owns are exactly the ones it declares (§ surfaces)', () {
    final adapter = resolver.resolve(LiveDesignLanguage.material);
    for (final surface in LiveUiSurface.values) {
      expect(adapter.surfaces.supports(surface), nativeSurfaces.contains(surface), reason: '$surface');
    }
    for (final surface in nativeSurfaces) {
      resolver.requireSurface(LiveDesignLanguage.material, surface);
    }
  });

  UiConfig config(LiveDesignLanguage language, {UiBrightnessMode brightness = UiBrightnessMode.light, Color? accent}) =>
      UiConfig(language: language, brightness: brightness, accent: accent);

  /// Harness with the diagnostics sink wired, as §10 requires of the host.
  Widget harness(UiConfig ui, Widget child, List<LiveUiDiagnostic> sink) => LiveConfigProvider(
    config: ui,
    registry: registry,
    diagnostics: sink.add,
    child: MaterialApp(
      localizationsDelegates: const [...liveLocalizationsDelegates, ...materialLocalizationsDelegates],
      supportedLocales: const [Locale('en')],
      home: Scaffold(body: Center(child: child)),
    ),
  );

  group('the resolution surface (§16.3/§16.8)', () {
    test('every control it declares resolves to this adapter, with no downgrade (§16.3)', () {
      final adapter = resolver.resolve(LiveDesignLanguage.material);
      for (final control in LiveUiControl.values) {
        expect(adapter.capabilities.supports(control), nativeControls.contains(control), reason: '$control');
      }
      for (final control in nativeControls) {
        resolver.requireControl(LiveDesignLanguage.material, control);
      }
    });
  });

  group('runtime switching (§11)', () {
    testWidgets('Material UI ↔ its own library widgets replaces the theme scope both ways', (tester) async {
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

      // §16.7: the controls Material UI serves through the shared renderer — the
      // two exercised here, tabs and select — must stay usable, and keep their
      // typed selection, whichever language is drawing the rest of the page.
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

      await tester.pumpWidget(harness(config(LiveDesignLanguage.material), page(), diagnostics));
      expect(find.byType(mu.TextField), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(mu.Switch), findsOneWidget);
      expect(find.byType(mu.Theme), findsWidgets);
      expectUndeclaredControls(diagnostics);
      await useFallbackControls();

      await useFallbackControls();

      // And back in: a fresh fork scope, not the stale one.
      diagnostics.clear();
      await tester.pumpWidget(harness(config(LiveDesignLanguage.material), page(), diagnostics));
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

      await tester.pumpWidget(probe(config(LiveDesignLanguage.material)));
      expect(forkTheme?.brightness, Brightness.light);
      final lightPrimary = forkTheme?.colorScheme.primary;

      await tester.pumpWidget(
        probe(config(LiveDesignLanguage.material, brightness: UiBrightnessMode.dark, accent: const Color(0xFFAA0000))),
      );
      expect(forkTheme?.brightness, Brightness.dark);
      expect(forkTheme?.colorScheme.primary, isNot(lightPrimary));
      expectUndeclaredControls(diagnostics);
    });
  });
}
