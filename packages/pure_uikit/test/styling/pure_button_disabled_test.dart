// Two disabled faces the libraries cannot state themselves, pinned: macOS
// routes its quarter-alpha foreground through `DefaultTextStyle`, which a glyph
// never reads, and wind's `WButton` has no class that reaches its plate.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluttersdk_wind/fluttersdk_wind.dart' as wind;
import 'package:macos_ui/macos_ui.dart' as macos;
import 'package:pure_uikit/pure_uikit.dart';
import 'package:pure_uikit/src/styling/adapters/macos_theme_adapter.dart';
import 'package:pure_uikit/src/styling/adapters/wind_theme_adapter.dart';

void main() {
  group('macOS dims the glyph with the label', () {
    testWidgets('a disabled button hands its icon theme the quarter alpha', (tester) async {
      await _pump(tester, PureDesignLanguage.macos, const Key('b'), onPressed: null);
      final glyph = find.descendant(of: find.byKey(const Key('b')), matching: find.byType(Icon)).first;
      final color = IconTheme.of(tester.element(glyph)).color;
      expect(color, isNotNull);
      expect(color!.a, closeTo(0.25, 0.001));
    });

    testWidgets('an enabled button keeps the library its own foreground', (tester) async {
      await _pump(tester, PureDesignLanguage.macos, const Key('b'), onPressed: () {});
      final glyph = find.descendant(of: find.byKey(const Key('b')), matching: find.byType(Icon)).first;
      expect(IconTheme.of(tester.element(glyph)).color?.a, 1.0);
    });

    testWidgets('a disabled icon button dims too', (tester) async {
      await tester.pumpWidget(
        _host(PureDesignLanguage.macos, const PureIconButton(key: Key('i'), icon: Icons.bolt, tooltip: 'Off')),
      );
      final glyph = find.descendant(of: find.byKey(const Key('i')), matching: find.byType(Icon)).first;
      expect(IconTheme.of(tester.element(glyph)).color?.a, closeTo(0.25, 0.001));
    });
  });

  group('wind sinks the plate the fork cannot state in a class', () {
    testWidgets('a disabled button is wrapped at half opacity', (tester) async {
      await _pump(tester, PureDesignLanguage.wind, const Key('b'), onPressed: null);
      expect(_sunk(tester, find.byKey(const Key('b'))), isNotNull);
    });

    testWidgets('loading is the fork own ring and stays at full strength', (tester) async {
      await tester.pumpWidget(
        _host(PureDesignLanguage.wind, PureButton(key: const Key('b'), label: 'Copy', loading: true, onPressed: () {})),
      );
      expect(_sunk(tester, find.byKey(const Key('b'))), isNull);
    });

    testWidgets('an enabled button is not sunk', (tester) async {
      await _pump(tester, PureDesignLanguage.wind, const Key('b'), onPressed: () {});
      expect(_sunk(tester, find.byKey(const Key('b'))), isNull);
    });
  });
}

/// The `Opacity` the wind arm wraps its plate in, if it wrapped one. It is
/// inside the keyed widget, since the arm builds it.
Opacity? _sunk(WidgetTester tester, Finder button) {
  final sinks = find.descendant(
    of: button,
    matching: find.byWidgetPredicate((widget) => widget is Opacity && widget.opacity < 1.0),
  );
  return sinks.evaluate().isEmpty ? null : tester.widget<Opacity>(sinks.first);
}

/// The theme the language's own host would install — `PushButton` asserts
/// without `MacosTheme`, `WButton` resolves its classes without `WindTheme`.
Widget _themed(PureTheme theme, PureDesignLanguage language, Widget child) => switch (language) {
  PureDesignLanguage.macos => macos.MacosTheme(data: const MacosThemeAdapter().resolve(theme), child: child),
  PureDesignLanguage.wind => wind.WindTheme(data: const WindThemeAdapter().resolve(theme), child: child),
  _ => child,
};

Future<void> _pump(WidgetTester tester, PureDesignLanguage language, Key key, {required VoidCallback? onPressed}) {
  return tester.pumpWidget(_host(language, PureButton(key: key, label: 'Copy', icon: Icons.add, onPressed: onPressed)));
}

Widget _host(PureDesignLanguage language, Widget page) {
  return PureConfigProvider(
    config: UiConfig(language: language),
    child: Builder(
      builder: (context) => MaterialApp(
        home: Scaffold(body: Center(child: _themed(PureTheme.of(context), language, page))),
      ),
    ),
  );
}
