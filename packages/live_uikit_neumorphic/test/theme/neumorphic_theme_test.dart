import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/styling.dart';
import 'package:live_uikit_neumorphic/live_uikit_neumorphic.dart';
import 'package:live_uikit_neumorphic/src/theme/neumorphic_theme_builder.dart';

/// §16 theme tests for `live_uikit_neumorphic`: pure mapping over
/// [NeumorphicThemeBuilder] plus a runtime re-skin through the real
/// [LiveConfigProvider] → `adapter.wrap` path (§8.3).
void main() {
  group('Neumorphic theme mapping (§8.1)', () {
    final light = DesignToken.derive(const SeedToken(), dark: false);
    final dark = DesignToken.derive(const SeedToken(), dark: true);

    test('surface, accent and radius follow the token', () {
      final data = NeumorphicThemeBuilder.build(light);
      expect(data.baseColor, light.color.bgLayout);
      expect(data.accentColor, light.color.primary);
      expect(data.borderRadius, BorderRadius.all(Radius.circular(light.scale.radii.lg)));
      expect(data.customShadowColor, light.color.shadowBase);
    });

    test('a dark token yields a different base surface than the light one (§8.3)', () {
      expect(NeumorphicThemeBuilder.build(dark).baseColor, isNot(NeumorphicThemeBuilder.build(light).baseColor));
    });
  });

  group('Neumorphic runtime re-skin (§8.3)', () {
    LiveTheme? live;

    Widget harness(UiConfig config) => LiveConfigProvider(
      config: config,
      registry: const LanguageRegistry(
        adapters: {LiveDesignLanguage.neumorphic: neumorphicAdapter},
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

    testWidgets('toggling brightness re-skins through the Neumorphic wrap', (tester) async {
      await tester.pumpWidget(
        harness(const UiConfig(language: LiveDesignLanguage.neumorphic, brightness: UiBrightnessMode.light)),
      );
      expect(live!.adapter.id, 'neumorphic');
      expect(live!.isDark, isFalse);
      expect(find.byType(LiveButton), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        harness(const UiConfig(language: LiveDesignLanguage.neumorphic, brightness: UiBrightnessMode.dark)),
      );
      expect(live!.isDark, isTrue);
      expect(find.byType(LiveButton), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
