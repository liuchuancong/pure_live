// The forui mapping's font half: the library keeps the family on its typefaces
// rather than on the text styles, and `FThemeData.copyWith` refuses a typography
// argument — so this is the seam where a chosen font could silently go missing.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart' as forui;
import 'package:pure_uikit/pure_uikit.dart';
import 'package:pure_uikit/src/styling/adapters/forui_theme_adapter.dart';

void main() {
  testWidgets('the chosen family reaches forui itself', (tester) async {
    final data = await _resolve(tester, const UiConfig(language: PureDesignLanguage.forui, fontFamily: 'ImportedFont'));

    expect(data.typography.body.fontFamily, 'ImportedFont');
    expect(data.typography.display.fontFamily, 'ImportedFont');
  });

  testWidgets('no family keeps the library default', (tester) async {
    final data = await _resolve(tester, const UiConfig(language: PureDesignLanguage.forui));

    expect(data.typography.body.fontFamily, forui.FTypeface.defaultFontFamily);
  });

  testWidgets('the palette variant still follows the brightness', (tester) async {
    final light = await _resolve(tester, const UiConfig(language: PureDesignLanguage.forui, brightness: UiBrightnessMode.light));
    final dark = await _resolve(tester, const UiConfig(language: PureDesignLanguage.forui, brightness: UiBrightnessMode.dark));

    expect(light.colors, isNot(dark.colors));
  });
}

/// Resolves the adapter against a theme built from [config] — the same object
/// the host installs above the routed tree.
Future<forui.FThemeData> _resolve(WidgetTester tester, UiConfig config) async {
  late forui.FThemeData data;
  await tester.pumpWidget(
    PureConfigProvider(
      config: config,
      child: Builder(
        builder: (context) {
          data = const ForuiThemeAdapter().resolve(PureTheme.of(context));
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return data;
}
