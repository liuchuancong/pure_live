import 'package:cupertino_ui/cupertino_ui.dart' as cu;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_cupertino/live_uikit_cupertino.dart';
import 'package:live_uikit_cupertino/src/theme/cupertino_theme_builder.dart';

/// §16 theme tests for `live_uikit_cupertino`: a pure pass over
/// [CupertinoThemeBuilder] (§8.1 mapping lands in the fork's theme data) and a
/// rendering pass that drives the real [LiveConfigProvider] → `adapter.wrap`
/// path to show the Cupertino UI theme re-skins at runtime (§8.3).
void main() {
  group('Cupertino UI theme mapping (§8.1)', () {
    final light = DesignToken.derive(const SeedToken(), dark: false);
    final dark = DesignToken.derive(const SeedToken(), dark: true);

    test('brightness and accent follow the token', () {
      expect(CupertinoThemeBuilder.build(light).brightness, Brightness.light);
      expect(CupertinoThemeBuilder.build(dark).brightness, Brightness.dark);
      expect(CupertinoThemeBuilder.build(light).primaryColor, light.color.primary);
    });

    test('the surface and on-accent colours follow the token', () {
      final data = CupertinoThemeBuilder.build(light);
      expect(data.scaffoldBackgroundColor, light.color.surface);
      expect(data.primaryContrastingColor, light.color.onPrimary);
    });

    test('a dark token yields different surfaces than the light one (§8.3)', () {
      expect(
        CupertinoThemeBuilder.build(dark).scaffoldBackgroundColor,
        isNot(CupertinoThemeBuilder.build(light).scaffoldBackgroundColor),
      );
    });
  });

  group('Cupertino UI runtime re-skin (§8.3)', () {
    LiveTheme? live;
    Brightness? cuBrightness;

    Widget harness(UiConfig config) => LiveConfigProvider(
      config: config,
      registry: const LanguageRegistry(adapters: {LiveDesignLanguage.cupertino: cupertinoAdapter}),
      child: MaterialApp(
        localizationsDelegates: const [...liveLocalizationsDelegates, ...cupertinoLocalizationsDelegates],
        supportedLocales: const [Locale('en')],
        home: Builder(
          builder: (context) {
            live = LiveTheme.of(context);
            cuBrightness = cu.CupertinoTheme.of(context).brightness;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    testWidgets('changing brightness re-skins the subtree in place', (tester) async {
      await tester.pumpWidget(
        harness(const UiConfig(language: LiveDesignLanguage.cupertino, brightness: UiBrightnessMode.light)),
      );
      expect(live!.isDark, isFalse);
      expect(live!.adapter.id, 'cupertino');
      expect(cuBrightness, Brightness.light);

      await tester.pumpWidget(
        harness(const UiConfig(language: LiveDesignLanguage.cupertino, brightness: UiBrightnessMode.dark)),
      );
      expect(live!.isDark, isTrue);
      expect(cuBrightness, Brightness.dark);
    });
  });
}
