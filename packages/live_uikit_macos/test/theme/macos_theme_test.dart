import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_macos/live_uikit_macos.dart';
import 'package:live_uikit_macos/src/theme/macos_theme_builder.dart';

/// §16 theme tests for `live_uikit_macos`: pure mapping over [MacosThemeBuilder]
/// plus a runtime re-skin through the real [LiveConfigProvider] → `adapter.wrap`
/// path (§8.3).
void main() {
  group('macOS theme mapping (§8.1)', () {
    final light = DesignToken.derive(const SeedToken(), dark: false);
    final dark = DesignToken.derive(const SeedToken(), dark: true);

    test('brightness, accent and canvas follow the token', () {
      final data = MacosThemeBuilder.build(light);
      expect(data.brightness, Brightness.light);
      expect(data.primaryColor, light.color.primary);
      expect(data.canvasColor, light.color.surface);
      expect(MacosThemeBuilder.build(dark).brightness, Brightness.dark);
    });

    test('a dark token yields a different canvas than the light one (§8.3)', () {
      expect(MacosThemeBuilder.build(dark).canvasColor, isNot(MacosThemeBuilder.build(light).canvasColor));
    });
  });

  group('macOS runtime re-skin (§8.3)', () {
    LiveTheme? live;

    Widget harness(UiConfig config) => LiveConfigProvider(
      config: config,
      registry: const LanguageRegistry(
        adapters: {LiveDesignLanguage.macos: macosAdapter},
        fallback: SharedLanguageAdapter(),
      ),
      child: MaterialApp(
        localizationsDelegates: liveLocalizationsDelegates,
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) {
                live = LiveTheme.of(context);
                return const LiveButton(label: 'OK');
              },
            ),
          ),
        ),
      ),
    );

    testWidgets('toggling brightness re-skins through the macOS wrap', (tester) async {
      await tester.pumpWidget(
        harness(const UiConfig(language: LiveDesignLanguage.macos, brightness: UiBrightnessMode.light)),
      );
      expect(live!.adapter.id, 'macos');
      expect(live!.implementationKind, LiveImplementationKind.adapterNative);
      expect(live!.isDark, isFalse);
      expect(find.byType(LiveButton), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        harness(const UiConfig(language: LiveDesignLanguage.macos, brightness: UiBrightnessMode.dark)),
      );
      expect(live!.isDark, isTrue);
      expect(find.byType(LiveButton), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
