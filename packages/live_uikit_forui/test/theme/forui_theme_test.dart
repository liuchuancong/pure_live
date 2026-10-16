import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart' as forui;
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_forui/live_uikit_forui.dart';
import 'package:live_uikit_forui/src/theme/forui_theme_builder.dart';

/// §16 theme tests for `live_uikit_forui`: what the token can decide in forui's theme
/// (the palette variant, §8.1) and — asserted on purpose — what it cannot (the accent,
/// the fonts), plus the runtime re-skin through `LiveConfigProvider` → `wrap` (§8.3).
void main() {
  group('ForUI theme mapping (§8.1)', () {
    final light = DesignToken.derive(const SeedToken(), dark: false);
    final dark = DesignToken.derive(const SeedToken(), dark: true);

    test('the palette variant follows the resolved brightness', () {
      expect(ForuiThemeBuilder.build(light).colors.brightness, Brightness.light);
      expect(ForuiThemeBuilder.build(dark).colors.brightness, Brightness.dark);
      expect(ForuiThemeBuilder.build(light), same(forui.FTheme.neutral.light.touch));
      expect(ForuiThemeBuilder.build(dark), same(forui.FTheme.neutral.dark.touch));
    });

    test('the accent and the global font cannot be mapped, and the builder says so', () {
      // forui's `FThemeData` has a private constructor and its `copyWith` carries
      // `colors`/`typography`/`style` through unchanged, so a host has no field to write
      // a palette into. Pinning this here keeps the limitation honest: if the library ever
      // opens a colour entry point, this test is where the adapter starts mapping it.
      final themed = DesignToken.derive(
        const SeedToken(colorPrimary: Color(0xFFAA0000), fontFamily: 'Inter'),
        dark: false,
      );
      expect(ForuiThemeBuilder.build(themed).colors.primary, ForuiThemeBuilder.build(light).colors.primary);
      expect(ForuiThemeBuilder.build(themed), same(ForuiThemeBuilder.build(light)));
    });
  });

  group('runtime re-skin (§8.3)', () {
    const registry = LanguageRegistry(
      adapters: {LiveDesignLanguage.forui: foruiAdapter},
      fallback: SharedLanguageAdapter(),
    );

    Widget harness(UiConfig config, Widget child) => LiveConfigProvider(
      config: config,
      registry: registry,
      child: MaterialApp(
        localizationsDelegates: const [...liveLocalizationsDelegates, ...foruiLocalizationsDelegates],
        supportedLocales: const [Locale('en')],
        home: Scaffold(body: child),
      ),
    );

    testWidgets('forui controls read the theme the adapter installed', (tester) async {
      forui.FThemeData? seen;
      await tester.pumpWidget(
        harness(
          const UiConfig(language: LiveDesignLanguage.forui, brightness: UiBrightnessMode.light),
          Builder(
            builder: (context) {
              seen = forui.FTheme.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(seen?.colors.brightness, Brightness.light);

      // forui's `FTheme` builds an `_AnimatedTheme`, so a palette change interpolates
      // rather than snapping: the re-skin has to settle before the new brightness reads.
      await tester.pumpWidget(
        harness(
          const UiConfig(language: LiveDesignLanguage.forui, brightness: UiBrightnessMode.dark),
          Builder(
            builder: (context) {
              seen = forui.FTheme.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(seen?.colors.brightness, Brightness.dark, reason: 'the wrap re-derives on a token change');
      expect(tester.takeException(), isNull);
    });
  });
}
