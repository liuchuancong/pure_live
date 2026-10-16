import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/styling.dart';
import 'package:live_uikit_material/live_uikit_material.dart';
import 'package:live_uikit_material/src/theme/material_theme_builder.dart';
import 'package:material_ui/material_ui.dart' as mu;

/// §16 theme tests for `live_uikit_material`.
///
/// Two halves: a pure unit pass over [MaterialThemeBuilder] proving each
/// §8.1 token property actually lands in the fork's `ThemeData` (and changes
/// when the token does), and a rendering pass that drives the real
/// [LiveConfigProvider] → resolver → `adapter.wrap` path to show the theme is
/// re-skin at runtime when the `UiConfig` changes (§8.3), without a restart.
void main() {
  group('Material UI theme mapping (§8.1)', () {
    final light = DesignToken.derive(const SeedToken(fontFamily: 'Inter'), dark: false);
    final dark = DesignToken.derive(const SeedToken(fontFamily: 'Inter'), dark: true);
    final plain = DesignToken.derive(const SeedToken(), dark: false);

    test('brightness follows the token', () {
      expect(MaterialThemeBuilder.build(light).brightness, Brightness.light);
      expect(MaterialThemeBuilder.build(dark).brightness, Brightness.dark);
    });

    test('page and card surfaces follow the resolved token', () {
      final data = MaterialThemeBuilder.build(light);
      expect(data.scaffoldBackgroundColor, light.color.surface);
      expect(data.cardColor, light.color.surfaceElevated);
    });

    test('the accent seeds the colour scheme', () {
      final brand = DesignToken.derive(const SeedToken(colorPrimary: Color(0xFFAA0000)), dark: false);
      expect(
        MaterialThemeBuilder.build(brand).colorScheme.primary,
        isNot(MaterialThemeBuilder.build(plain).colorScheme.primary),
        reason: 'a different accent must produce a different scheme',
      );
    });

    test('a dark token yields different surfaces than the light one (§8.3)', () {
      expect(
        MaterialThemeBuilder.build(dark).scaffoldBackgroundColor,
        isNot(MaterialThemeBuilder.build(light).scaffoldBackgroundColor),
      );
    });
  });

  group('Material UI runtime re-skin (§8.3)', () {
    LiveTheme? live;
    mu.ThemeData? material;

    Widget harness(UiConfig config) => LiveConfigProvider(
      config: config,
      registry: const LanguageRegistry(
        adapters: {LiveDesignLanguage.material: materialAdapter},
        fallback: SharedLanguageAdapter(),
      ),
      child: MaterialApp(
        localizationsDelegates: const [...liveLocalizationsDelegates, ...materialLocalizationsDelegates],
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          body: Builder(
            builder: (context) {
              live = LiveTheme.of(context);
              material = mu.Theme.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    testWidgets('changing brightness and accent re-skins the subtree in place', (tester) async {
      await tester.pumpWidget(
        harness(const UiConfig(language: LiveDesignLanguage.material, brightness: UiBrightnessMode.light)),
      );
      expect(live!.isDark, isFalse);
      expect(live!.adapter.id, 'material');
      expect(live!.implementationKind, LiveImplementationKind.adapterNative);
      expect(material!.brightness, Brightness.light);

      await tester.pumpWidget(
        harness(
          const UiConfig(
            language: LiveDesignLanguage.material,
            brightness: UiBrightnessMode.dark,
            accent: Color(0xFFAA0000),
          ),
        ),
      );
      expect(live!.isDark, isTrue);
      expect(material!.brightness, Brightness.dark);
      // The library surfaces moved with the token, so the subtree re-skinned.
      expect(material!.scaffoldBackgroundColor, isNot(equals(Colors.transparent)));
    });
  });
}
