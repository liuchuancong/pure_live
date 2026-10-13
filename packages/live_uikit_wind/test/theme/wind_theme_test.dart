import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/styling.dart';
import 'package:live_uikit_wind/live_uikit_wind.dart';
import 'package:live_uikit_wind/src/theme/wind_theme_builder.dart';

/// §16 theme tests for `live_uikit_wind`: pure mapping over [WindThemeBuilder]
/// plus a runtime re-skin through the real [LiveConfigProvider] → `adapter.wrap`
/// path (§8.3).
void main() {
  group('Wind theme mapping (§8.1)', () {
    final plain = DesignToken.derive(const SeedToken(), dark: false);
    final brand = DesignToken.derive(const SeedToken(colorPrimary: Color(0xFFAA0000)), dark: false);
    final serifed = DesignToken.derive(const SeedToken(fontFamily: 'Inter'), dark: false);

    test('brightness follows the token and system sync is forced off (§8.3)', () {
      expect(WindThemeBuilder.build(plain).brightness, Brightness.light);
      expect(WindThemeBuilder.build(DesignToken.derive(const SeedToken(), dark: true)).brightness, Brightness.dark);
      expect(WindThemeBuilder.build(plain).syncWithSystem, isFalse);
    });

    test('the accent overrides the primary colour and a configured font lands in the sans scale', () {
      expect(
        WindThemeBuilder.build(brand).colors['primary'],
        isNot(WindThemeBuilder.build(plain).colors['primary']),
      );
      expect(WindThemeBuilder.build(serifed).fontFamilies['sans'], 'Inter');
    });
  });

  group('Wind runtime re-skin (§8.3)', () {
    LiveTheme? live;

    Widget harness(UiConfig config) => LiveConfigProvider(
      config: config,
      registry: const LanguageRegistry(
        adapters: {LiveDesignLanguage.wind: windUiAdapter},
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

    testWidgets('toggling brightness re-skins through the Wind wrap', (tester) async {
      await tester.pumpWidget(
        harness(const UiConfig(language: LiveDesignLanguage.wind, brightness: UiBrightnessMode.light)),
      );
      expect(live!.adapter.id, 'wind');
      expect(live!.isDark, isFalse);
      expect(find.byType(LiveButton), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        harness(const UiConfig(language: LiveDesignLanguage.wind, brightness: UiBrightnessMode.dark)),
      );
      expect(live!.isDark, isTrue);
      expect(find.byType(LiveButton), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
