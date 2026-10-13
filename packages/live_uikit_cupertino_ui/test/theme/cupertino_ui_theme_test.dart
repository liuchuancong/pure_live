import 'package:cupertino_ui/cupertino_ui.dart' as cu;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/styling.dart';
import 'package:live_uikit_cupertino_ui/live_uikit_cupertino_ui.dart';
import 'package:live_uikit_cupertino_ui/src/theme/cupertino_ui_theme_builder.dart';

/// §16 theme tests for `live_uikit_cupertino_ui`: a pure pass over
/// [CupertinoUiThemeBuilder] (§8.1 mapping lands in the fork's theme data) and a
/// rendering pass that drives the real [LiveConfigProvider] → `adapter.wrap`
/// path to show the Cupertino UI theme re-skins at runtime (§8.3).
void main() {
  group('Cupertino UI theme mapping (§8.1)', () {
    final light = DesignToken.derive(const SeedToken(), dark: false);
    final dark = DesignToken.derive(const SeedToken(), dark: true);

    test('brightness and accent follow the token', () {
      expect(CupertinoUiThemeBuilder.build(light).brightness, Brightness.light);
      expect(CupertinoUiThemeBuilder.build(dark).brightness, Brightness.dark);
      expect(CupertinoUiThemeBuilder.build(light).primaryColor, light.color.primary);
    });

    test('the surface and on-accent colours follow the token', () {
      final data = CupertinoUiThemeBuilder.build(light);
      expect(data.scaffoldBackgroundColor, light.color.surface);
      expect(data.primaryContrastingColor, light.color.onPrimary);
    });

    test('a dark token yields different surfaces than the light one (§8.3)', () {
      expect(
        CupertinoUiThemeBuilder.build(dark).scaffoldBackgroundColor,
        isNot(CupertinoUiThemeBuilder.build(light).scaffoldBackgroundColor),
      );
    });
  });

  group('Cupertino UI runtime re-skin (§8.3)', () {
    LiveTheme? live;
    Brightness? cuBrightness;

    Widget harness(UiConfig config) => LiveConfigProvider(
      config: config,
      registry: const LanguageRegistry(
        adapters: {LiveDesignLanguage.cupertinoUi: cupertinoUiAdapter},
        fallback: SharedLanguageAdapter(),
      ),
      child: MaterialApp(
        localizationsDelegates: const [...liveLocalizationsDelegates, ...cupertinoUiLocalizationsDelegates],
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
        harness(const UiConfig(language: LiveDesignLanguage.cupertinoUi, brightness: UiBrightnessMode.light)),
      );
      expect(live!.isDark, isFalse);
      expect(live!.adapter.id, 'cupertinoUi');
      expect(cuBrightness, Brightness.light);

      await tester.pumpWidget(
        harness(const UiConfig(language: LiveDesignLanguage.cupertinoUi, brightness: UiBrightnessMode.dark)),
      );
      expect(live!.isDark, isTrue);
      expect(cuBrightness, Brightness.dark);
    });
  });
}
