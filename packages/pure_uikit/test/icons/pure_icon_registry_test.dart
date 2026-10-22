import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_uikit/pure_uikit.dart';

enum _TestKey implements PureIconKey {
  heart,
  book,
  missing;

  @override
  String get id => name;
}

void main() {
  setUp(PureIconRegistry.resetInstalledForTest);
  test('the four tiers answer in priority order', () {
    final registry = PureIconRegistry()
      ..registerLanguage(
        PureDesignLanguage.fluent,
        const PureIconMapping({_TestKey.book: PureIconGlyph(Icons.book_outlined)}),
      )
      ..registerPlatformOverride(
        TargetPlatform.windows,
        PureDesignLanguage.fluent,
        const PureIconMapping({_TestKey.book: PureIconGlyph(Icons.menu_book)}),
      )
      ..setGlobal(const PureIconMapping({_TestKey.heart: PureIconGlyph(Icons.favorite)}));

    final onWindows = registry.resolve(
      _TestKey.book,
      platform: TargetPlatform.windows,
      language: PureDesignLanguage.fluent,
    );
    expect(onWindows.tier, PureIconTier.platformOverride);
    expect(onWindows.diagnostic, isNull);

    final onLinux = registry.resolve(
      _TestKey.book,
      platform: TargetPlatform.linux,
      language: PureDesignLanguage.fluent,
    );
    expect(onLinux.tier, PureIconTier.language);

    final heart = registry.resolve(_TestKey.heart, platform: TargetPlatform.android, language: PureDesignLanguage.yaru);
    expect(heart.tier, PureIconTier.global);

    final missing = registry.resolve(
      _TestKey.missing,
      platform: TargetPlatform.iOS,
      language: PureDesignLanguage.cupertino,
    );
    expect(missing.tier, PureIconTier.fallback);
    expect(missing.diagnostic, contains('missing'));
    expect(PureIconFallback.isFallback(missing.source), isTrue);
  });

  test('the fallback resolution is reported once through onDiagnostic', () {
    final notes = <String>[];
    final registry = PureIconRegistry(onDiagnostic: (resolution) => notes.add(resolution.diagnostic!))
      ..setGlobal(const PureIconMapping({_TestKey.heart: PureIconGlyph(Icons.favorite)}))
      ..resolve(_TestKey.missing, platform: TargetPlatform.macOS, language: PureDesignLanguage.material);
    expect(notes, hasLength(1));
    registry.resolve(_TestKey.heart, platform: TargetPlatform.macOS, language: PureDesignLanguage.material);
    expect(notes, hasLength(1), reason: 'a registered key must not raise the diagnostic');
  });

  testWidgets('a PureIcon draw takes the language size, the theme colour and the state rule', (tester) async {
    final registry = PureIconRegistry()
      ..registerLanguage(
        PureDesignLanguage.cupertino,
        const PureIconMapping({_TestKey.heart: PureIconGlyph(Icons.favorite)}),
      )
      ..setGlobal(const PureIconMapping({_TestKey.book: PureIconGlyph(Icons.book)}));
    PureIconRegistry.install(registry);

    await tester.pumpWidget(
      const PureConfigProvider(
        config: UiConfig(language: PureDesignLanguage.cupertino),
        child: MaterialApp(
          home: Scaffold(body: Center(child: PureIcon(_TestKey.heart))),
        ),
      ),
    );
    var icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.icon, Icons.favorite);
    expect(icon.size, PureIconTokens.defaultSize(PureDesignLanguage.cupertino));
    expect(icon.color, isNotNull);

    await tester.pumpWidget(
      const PureConfigProvider(
        config: UiConfig(language: PureDesignLanguage.fluent),
        child: MaterialApp(
          home: Scaffold(
            body: Center(child: PureIcon(_TestKey.book, state: PureIconState.disabled)),
          ),
        ),
      ),
    );
    icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.icon, Icons.book, reason: 'tier 3 (global) answers when the language table does not');
    expect(icon.size, 16);
  });

  testWidgets('a preserve-role custom source is not tinted and gets the themed context', (tester) async {
    final registry = PureIconRegistry()
      ..setGlobal(
        PureIconMapping({
          _TestKey.heart: PureIconWidget(
            (context, renderContext) => Text('${renderContext.key.id}-${renderContext.style.size}'),
          ),
        }),
      );
    PureIconRegistry.install(registry);
    await tester.pumpWidget(
      const PureConfigProvider(
        config: UiConfig(language: PureDesignLanguage.material),
        child: MaterialApp(
          home: Scaffold(
            body: Center(child: PureIcon(_TestKey.heart, role: PureIconColorRole.preserve)),
          ),
        ),
      ),
    );
    expect(find.text('heart-24.0'), findsOneWidget);
  });
}
