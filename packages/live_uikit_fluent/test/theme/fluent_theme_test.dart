import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/styling.dart';
import 'package:live_uikit_fluent/live_uikit_fluent.dart';
import 'package:live_uikit_fluent/src/theme/fluent_theme_builder.dart';

/// §16 theme tests for `live_uikit_fluent`: the pure §8.1 token mapping, and a
/// runtime re-skin driven through the real `LiveConfigProvider` → resolver →
/// `adapter.wrap` path so a token change is proven to reach `FluentThemeData`
/// without restarting the app (§8.3).
void main() {
  group('Fluent theme mapping (§8.1)', () {
    final light = DesignToken.derive(const SeedToken(fontFamily: 'Inter'), dark: false);
    final dark = DesignToken.derive(const SeedToken(fontFamily: 'Inter'), dark: true);
    final plain = DesignToken.derive(const SeedToken(), dark: false);
    final brand = DesignToken.derive(const SeedToken(colorPrimary: Color(0xFFAA0000)), dark: false);

    test('brightness follows the token', () {
      expect(FluentThemeBuilder.build(light).brightness, Brightness.light);
      expect(FluentThemeBuilder.build(dark).brightness, Brightness.dark);
    });

    test('the accent becomes Fluent accent color', () {
      expect(FluentThemeBuilder.build(brand).accentColor.normal, const Color(0xFFAA0000));
      expect(
        FluentThemeBuilder.build(brand).accentColor.normal,
        isNot(FluentThemeBuilder.build(plain).accentColor.normal),
        reason: 'a different accent must produce a different palette',
      );
    });

    test('a configured global font reaches the theme', () {
      expect(FluentThemeBuilder.build(light).typography.body?.fontFamily, 'Inter');
    });
  });

  group('Fluent runtime re-skin (§8.3)', () {
    testWidgets('changing brightness and accent re-skins the subtree in place', (tester) async {
      fluent.FluentThemeData? theme;
      LiveTheme? live;

      Widget harness(UiConfig config) => LiveConfigProvider(
        config: config,
        registry: const LanguageRegistry(
          adapters: {LiveDesignLanguage.fluent: fluentAdapter},
          fallback: SharedLanguageAdapter(),
        ),
        // No manual `FluentTheme`: `adapter.wrap` installs the scope, which is
        // exactly what this test is checking (§8.2/§8.3).
        child: Builder(
          builder: (context) {
            live = LiveTheme.of(context);
            theme = fluent.FluentTheme.of(context);
            return const SizedBox.shrink();
          },
        ),
      );

      await tester.pumpWidget(
        harness(const UiConfig(language: LiveDesignLanguage.fluent, brightness: UiBrightnessMode.light)),
      );
      expect(live!.adapter.id, 'fluent');
      expect(live!.implementationKind, LiveImplementationKind.adapterNative);
      expect(theme!.brightness, Brightness.light);

      await tester.pumpWidget(
        harness(
          const UiConfig(
            language: LiveDesignLanguage.fluent,
            brightness: UiBrightnessMode.dark,
            accent: Color(0xFFAA0000),
          ),
        ),
      );
      expect(live!.isDark, isTrue);
      expect(theme!.brightness, Brightness.dark);
      expect(theme!.accentColor.normal, const Color(0xFFAA0000));
    });
  });
}
