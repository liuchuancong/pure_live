import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/styling.dart';
import 'package:live_uikit_glass/live_uikit_glass.dart';
import 'package:live_uikit_glass/src/theme/glass_theme_builder.dart';

/// §16 theme tests for `live_uikit_glass`: pure mapping over [GlassThemeBuilder]
/// (the panel tint / radius / shadow now follow the token, §8.1) plus a runtime
/// re-skin through the real [LiveConfigProvider] → `adapter.wrap` path (§8.3).
void main() {
  group('Glass theme mapping (§8.1)', () {
    final light = DesignToken.derive(const SeedToken(), dark: false);
    final dark = DesignToken.derive(const SeedToken(), dark: true);

    test('panel tint, radius and shadow follow the token', () {
      final data = GlassThemeBuilder.build(light);
      expect(data.color, light.color.bgContainer);
      expect(data.borderRadius, light.scale.radii.lg);
      expect(data.shadowColor, light.color.shadowBase);
    });

    test('the blur is a fixed effect, not token-driven (documented §8.1)', () {
      expect(GlassThemeBuilder.build(light).blur, 16);
    });

    test('a dark token yields a different panel tint than the light one (§8.3)', () {
      expect(
        GlassThemeBuilder.build(dark).color,
        isNot(GlassThemeBuilder.build(light).color),
      );
    });
  });

  group('Glass runtime re-skin (§8.3)', () {
    LiveTheme? live;

    Widget harness(UiConfig config) => LiveConfigProvider(
      config: config,
      registry: const LanguageRegistry(
        adapters: {LiveDesignLanguage.glass: glassUiAdapter},
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

    testWidgets('toggling brightness re-skins through the Glass wrap', (tester) async {
      await tester.pumpWidget(
        harness(const UiConfig(language: LiveDesignLanguage.glass, brightness: UiBrightnessMode.light)),
      );
      expect(live!.adapter.id, 'glass');
      expect(live!.isDark, isFalse);
      expect(find.byType(LiveButton), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        harness(const UiConfig(language: LiveDesignLanguage.glass, brightness: UiBrightnessMode.dark)),
      );
      expect(live!.isDark, isTrue);
      expect(find.byType(LiveButton), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
