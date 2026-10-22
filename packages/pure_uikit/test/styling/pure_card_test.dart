import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The plate the card paints, addressed by its contract key.
BoxDecoration _plate(WidgetTester tester) =>
    tester.widget<DecoratedBox>(find.byKey(const Key('PureCard.plate'), skipOffstage: false)).decoration
        as BoxDecoration;

/// The static foreground focus ring, always in the tree of an interactive
/// card; its stroke is the thing that changes with focus.
DecoratedBox _ring(WidgetTester tester) =>
    tester.widget<DecoratedBox>(find.byKey(const Key('PureCard.ring'), skipOffstage: false));

/// The resolved theme the card is drawing against — the tests assert the
/// language's plate is exactly the token surface it promises, never a copy of
/// another test's geometry.
PureTheme _theme(WidgetTester tester) => PureTheme.of(tester.element(find.byType(PureCard)));

/// The branch key the card hangs its grammar on.
Key _branch(PureDesignLanguage language) => ValueKey('PureCard.${language.name}');

Future<void> _pump(
  WidgetTester tester, {
  required PureDesignLanguage language,
  Widget child = const Text('card body'),
  VoidCallback? onTap,
  VoidCallback? onLongPress,
  bool selected = false,
  bool bordered = false,
  bool dense = false,
  EdgeInsetsGeometry? padding,
  FocusNode? focusNode,
  bool autofocus = false,
  Style? style,
  Brightness brightness = Brightness.light,
}) async {
  await tester.pumpWidget(
    PureConfigProvider(
      config: UiConfig(
        language: language,
        brightness: brightness == Brightness.dark ? UiBrightnessMode.dark : UiBrightnessMode.light,
      ),
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            // The harness gives width-only constraints, like the app shell.
            child: SizedBox(
              width: 320,
              child: PureCard(
                onTap: onTap,
                onLongPress: onLongPress,
                selected: selected,
                bordered: bordered,
                dense: dense,
                padding: padding,
                focusNode: focusNode,
                autofocus: autofocus,
                style: style,
                child: child,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// The nine languages with the corner each of them promises, in logical
/// pixels — the numbers this widget's own grammars draw.
const Map<PureDesignLanguage, double> _radius = {
  PureDesignLanguage.material: 12,
  PureDesignLanguage.cupertino: 10,
  PureDesignLanguage.macos: 8,
  PureDesignLanguage.fluent: 8,
  PureDesignLanguage.yaru: 16,
  PureDesignLanguage.forui: 12,
  PureDesignLanguage.glass: 16,
  PureDesignLanguage.neumorphic: 24,
  PureDesignLanguage.wind: 8,
};

/// The languages whose grammar rules its edge with a hairline at rest.
const Set<PureDesignLanguage> _haired = {
  PureDesignLanguage.macos,
  PureDesignLanguage.fluent,
  PureDesignLanguage.yaru,
  PureDesignLanguage.forui,
  PureDesignLanguage.glass,
  PureDesignLanguage.wind,
};

/// The languages that ship a strokeless plate until `bordered` asks.
const Set<PureDesignLanguage> _bare = {
  PureDesignLanguage.material,
  PureDesignLanguage.cupertino,
  PureDesignLanguage.neumorphic,
};

/// The row surface the grammar paints, addressed by its contract key.
BoxDecoration _rowPlate(WidgetTester tester) =>
    tester.widget<DecoratedBox>(find.byKey(const Key('PureListRow.plate'), skipOffstage: false)).decoration
        as BoxDecoration;

/// The static foreground focus ring of an interactive row.
DecoratedBox _rowRing(WidgetTester tester) =>
    tester.widget<DecoratedBox>(find.byKey(const Key('PureListRow.ring'), skipOffstage: false));

PureTheme _rowTheme(WidgetTester tester) => PureTheme.of(tester.element(find.byType(PureListRow)));

Key _rowBranch(PureDesignLanguage language) => ValueKey('PureListRow.${language.name}');

Future<void> _pumpRow(
  WidgetTester tester, {
  required PureDesignLanguage language,
  String title = 'Row title',
  String? subtitle,
  Widget? leading,
  Widget? trailing,
  VoidCallback? onTap,
  VoidCallback? onLongPress,
  bool selected = false,
  bool divided = true,
  FocusNode? focusNode,
  bool autofocus = false,
  Brightness brightness = Brightness.light,
}) async {
  await tester.pumpWidget(
    PureConfigProvider(
      config: UiConfig(
        language: language,
        brightness: brightness == Brightness.dark ? UiBrightnessMode.dark : UiBrightnessMode.light,
      ),
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            // The harness gives width-only constraints, like the card's.
            child: SizedBox(
              width: 320,
              child: PureListRow(
                title: title,
                subtitle: subtitle,
                leading: leading,
                trailing: trailing,
                onTap: onTap,
                onLongPress: onLongPress,
                selected: selected,
                divided: divided,
                focusNode: focusNode,
                autofocus: autofocus,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// The one-line / two-line tiers each grammar answers with.
const Map<PureDesignLanguage, (double, double)> _rowTiers = {
  PureDesignLanguage.material: (56, 72),
  PureDesignLanguage.cupertino: (44, 62),
  PureDesignLanguage.macos: (40, 56),
  PureDesignLanguage.fluent: (40, 56),
  PureDesignLanguage.yaru: (44, 60),
  PureDesignLanguage.forui: (48, 64),
  PureDesignLanguage.glass: (48, 64),
  PureDesignLanguage.neumorphic: (44, 64),
  PureDesignLanguage.wind: (48, 64),
};

/// The gap each grammar floats its row surface in; the rest are full-bleed.
const Map<PureDesignLanguage, double> _rowEdgeInset = {
  PureDesignLanguage.macos: 8,
  PureDesignLanguage.fluent: 4,
  PureDesignLanguage.neumorphic: 6,
  PureDesignLanguage.yaru: 6,
};

/// The fill selection paints, per grammar.
Color _rowSelectedFill(PureTheme theme, PureDesignLanguage language) => switch (language) {
  PureDesignLanguage.fluent || PureDesignLanguage.forui => theme.colors.fillSecondary,
  PureDesignLanguage.glass => theme.colors.white.withValues(alpha: 0.5),
  PureDesignLanguage.neumorphic => theme.colors.bgContainer,
  _ => theme.colors.primaryBg,
};

void main() {
  testWidgets('all nine grammars build and name their branch', (tester) async {
    for (final language in PureDesignLanguage.values) {
      await _pump(tester, language: language);
      expect(find.byKey(_branch(language)), findsOneWidget);
      expect(_plate(tester).borderRadius, isNotNull);
      // Self-painted: no borrowed card frame, no Material ink anywhere.
      expect(find.descendant(of: find.byType(PureCard), matching: find.byType(InkWell)), findsNothing);
      expect(find.descendant(of: find.byType(PureCard), matching: find.byType(Card)), findsNothing);
    }
  });

  testWidgets('each plate is the corner its language promises', (tester) async {
    for (final language in PureDesignLanguage.values) {
      await _pump(tester, language: language);
      expect((_plate(tester).borderRadius! as BorderRadius).topLeft.x, _radius[language], reason: language.name);
    }
  });

  testWidgets('the at-rest stroke follows the grammar table', (tester) async {
    for (final language in PureDesignLanguage.values) {
      await _pump(tester, language: language);
      final theme = _theme(tester);
      final border = _plate(tester).border;
      if (_haired.contains(language)) {
        expect(border, isNotNull, reason: language.name);
        expect(border!.top.width, theme.token.motion.lineWidth, reason: language.name);
      } else {
        expect(_bare.contains(language), isTrue, reason: language.name);
        expect(border, isNull, reason: language.name);
      }
    }
  });

  testWidgets('material elevates on the card token shadow; the flats do not', (tester) async {
    await _pump(tester, language: PureDesignLanguage.material);
    expect(_plate(tester).boxShadow, _theme(tester).card.shadow);

    for (final language in [
      PureDesignLanguage.cupertino,
      PureDesignLanguage.macos,
      PureDesignLanguage.yaru,
      PureDesignLanguage.forui,
      PureDesignLanguage.wind,
    ]) {
      await _pump(tester, language: language);
      expect(_plate(tester).boxShadow, isEmpty, reason: language.name);
    }
  });

  testWidgets('fluent casts the single soft WinUI card shadow', (tester) async {
    await _pump(tester, language: PureDesignLanguage.fluent);
    final shadows = _plate(tester).boxShadow!;
    expect(shadows, hasLength(1));
    expect(shadows.single.blurRadius, 8);
    expect(shadows.single.offset, const Offset(0, 2));
  });

  testWidgets('neumorphic extrudes with the twin cast and glow', (tester) async {
    await _pump(tester, language: PureDesignLanguage.neumorphic);
    final shadows = _plate(tester).boxShadow!;
    expect(shadows, hasLength(2));
    // Light from the top left, the cast to the bottom right.
    expect(shadows[0].offset, const Offset(4, 4));
    expect(shadows[1].offset, const Offset(-4, -4));
    expect(_plate(tester).color, _theme(tester).colors.bgContainer);
  });

  testWidgets('glass frosts: translucent sheet over a real backdrop blur', (tester) async {
    await _pump(tester, language: PureDesignLanguage.glass);
    final fill = _plate(tester).color!;
    expect(fill.a, lessThan(1.0));
    expect(fill, _theme(tester).colors.white.withValues(alpha: 0.55));
    expect(find.descendant(of: find.byType(PureCard), matching: find.byType(BackdropFilter)), findsOneWidget);
  });

  testWidgets('the glass language solidifies when blur is off', (tester) async {
    await tester.pumpWidget(
      const PureConfigProvider(
        config: UiConfig(language: PureDesignLanguage.glass, reduceTransparency: true),
        child: MaterialApp(
          home: Scaffold(
            body: Center(child: PureCard(child: Text('body'))),
          ),
        ),
      ),
    );
    expect(find.descendant(of: find.byType(PureCard), matching: find.byType(BackdropFilter)), findsNothing);
    expect(_plate(tester).color, _theme(tester).colors.bgContainer);
  });

  testWidgets('a tappable card fires, tints on hover and press, and means it', (tester) async {
    var taps = 0;
    await _pump(tester, language: PureDesignLanguage.fluent, onTap: () => taps++);
    final theme = _theme(tester);
    final idle = _plate(tester).color;
    expect(idle, theme.colors.bgContainer);

    final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await pointer.addPointer(location: Offset.zero);
    addTearDown(pointer.removePointer);
    await pointer.moveTo(tester.getCenter(find.byType(PureCard)));
    await tester.pump();
    expect(_plate(tester).color, isNot(idle), reason: 'hover blends the language tint');

    await pointer.down(tester.getCenter(find.byType(PureCard)));
    await tester.pump();
    expect(_plate(tester).color, Color.alphaBlend(theme.colors.fillSecondary, theme.colors.bgContainer));
    await pointer.up();
    await tester.pump();
    expect(taps, 1);

    // The card's own semantics node — a button that names its selection state.
    expect(
      find.descendant(
        of: find.byType(PureCard),
        matching: find.byWidgetPredicate((w) => w is Semantics && w.properties.button == true),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the focus ring is a static foreground box; focus only paints it', (tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    await _pump(tester, language: PureDesignLanguage.material, onTap: () {}, focusNode: node);
    final theme = _theme(tester);

    expect(_ring(tester).position, DecorationPosition.foreground);
    var ring = _ring(tester).decoration as BoxDecoration;
    expect(ring.border!.top.color, const Color(0x00000000));
    final treeBefore = find
        .descendant(of: find.byType(PureCard), matching: find.byType(DecoratedBox))
        .evaluate()
        .length;

    node.requestFocus();
    // The focus listeners run at the end of the frame; settle so the ring's
    // repaint lands in this test's read.
    await tester.pumpAndSettle();
    ring = _ring(tester).decoration as BoxDecoration;
    expect(ring.border!.top.color, theme.colors.primary);
    // Focusing never changes the tree shape — only the stroke colour moved.
    expect(
      find.descendant(of: find.byType(PureCard), matching: find.byType(DecoratedBox)).evaluate().length,
      treeBefore,
    );
  });

  testWidgets('space activates a focused card', (tester) async {
    var taps = 0;
    final node = FocusNode();
    addTearDown(node.dispose);
    await _pump(tester, language: PureDesignLanguage.yaru, onTap: () => taps++, focusNode: node, autofocus: true);
    await tester.pump();
    expect(node.hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(taps, 1);
  });

  testWidgets('a plain card takes no focus', (tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    await _pump(tester, language: PureDesignLanguage.material, focusNode: node, autofocus: true);
    expect(find.byKey(const Key('PureCard.ring'), skipOffstage: false), findsNothing);
    expect(node.hasPrimaryFocus, isFalse);
  });

  testWidgets('selected tints the plate and rules it, except the soft mould', (tester) async {
    for (final language in PureDesignLanguage.values) {
      await _pump(tester, language: language, selected: true);
      final theme = _theme(tester);
      expect(_plate(tester).color, theme.colors.primaryBg, reason: language.name);
      if (language == PureDesignLanguage.neumorphic) {
        // A neumorphic card is defined by its mould: the fill answers, no stroke.
        expect(_plate(tester).border, isNull);
      } else {
        expect(_plate(tester).border!.top.color, theme.colors.primaryBorder, reason: language.name);
      }
    }
  });

  testWidgets('bordered rules the strokeless grammars', (tester) async {
    await _pump(tester, language: PureDesignLanguage.material, bordered: true);
    expect(_plate(tester).border!.top.color, _theme(tester).colors.border);
  });

  testWidgets('long press fires on its own', (tester) async {
    var long = 0;
    await _pump(tester, language: PureDesignLanguage.cupertino, onLongPress: () => long++);
    await tester.longPress(find.text('card body'));
    await tester.pumpAndSettle();
    expect(long, 1);
  });

  testWidgets('padding: the token, the dense step, and the caller override', (tester) async {
    await _pump(tester, language: PureDesignLanguage.forui);
    final theme = _theme(tester);
    var pad = tester.widget<Padding>(find.descendant(of: find.byType(PureCard), matching: find.byType(Padding)).first);
    expect(pad.padding, EdgeInsets.all(theme.card.padding));

    await _pump(tester, language: PureDesignLanguage.forui, dense: true);
    pad = tester.widget<Padding>(find.descendant(of: find.byType(PureCard), matching: find.byType(Padding)).first);
    expect(pad.padding, EdgeInsets.all(theme.card.padding * 0.66));

    await _pump(tester, language: PureDesignLanguage.forui, padding: EdgeInsets.zero);
    pad = tester.widget<Padding>(find.descendant(of: find.byType(PureCard), matching: find.byType(Padding)).first);
    expect(pad.padding, EdgeInsets.zero);
  });

  testWidgets('the style override moves fill, stroke and corner', (tester) async {
    const fill = Color(0xFF123456);
    const edge = Color(0xFFABCDEF);
    await _pump(
      tester,
      language: PureDesignLanguage.wind,
      style: const Style(
        background: fill,
        borderColor: edge,
        borderWidth: 3,
        borderRadius: BorderRadius.all(Radius.circular(2)),
      ),
    );
    final plate = _plate(tester);
    expect(plate.color, fill);
    expect(plate.borderRadius, const BorderRadius.all(Radius.circular(2)));
    final side = plate.border!.top;
    expect(side.color, edge);
    expect(side.width, 3);
  });
  testWidgets('dark brightness keeps the promised token surface', (tester) async {
    await _pump(tester, language: PureDesignLanguage.material, brightness: Brightness.dark);
    final theme = _theme(tester);
    expect(theme.isDark, isTrue);
    expect(_plate(tester).color, theme.colors.bgContainer);
    // The card token drops its elevation shadow in the dark variant.
    expect(_plate(tester).boxShadow, theme.card.shadow);
  });

  // ---------------------------------------------------------------------------
  // PureListRow — the same file's row half, held to the same contract.
  // ---------------------------------------------------------------------------

  testWidgets('all nine row grammars build and borrow no tile', (tester) async {
    for (final language in PureDesignLanguage.values) {
      await _pumpRow(
        tester,
        language: language,
        subtitle: 'second line',
        leading: const Icon(Icons.tune, key: Key('row.lead')),
        trailing: const Text('value'),
        onTap: () {},
      );
      expect(find.byKey(_rowBranch(language)), findsOneWidget, reason: language.name);
      expect(find.byKey(const Key('PureListRow.plate'), skipOffstage: false), findsOneWidget, reason: language.name);
      expect(find.byKey(const Key('row.lead')), findsOneWidget, reason: language.name);
      expect(find.text('value'), findsOneWidget, reason: language.name);
      // Self-painted: no borrowed tile, no Material ink sheet anywhere below.
      expect(find.descendant(of: find.byType(PureListRow), matching: find.byType(ListTile)), findsNothing);
      expect(find.descendant(of: find.byType(PureListRow), matching: find.byType(Material)), findsNothing);
    }
  });

  testWidgets('each row wears the tier its language promises', (tester) async {
    for (final language in PureDesignLanguage.values) {
      await _pumpRow(tester, language: language);
      var height = tester.getSize(find.byKey(const Key('PureListRow.plate'), skipOffstage: false)).height;
      expect(height, _rowTiers[language]!.$1, reason: language.name);

      await _pumpRow(tester, language: language, subtitle: 'second line');
      height = tester.getSize(find.byKey(const Key('PureListRow.plate'), skipOffstage: false)).height;
      expect(height, _rowTiers[language]!.$2, reason: language.name);
    }
  });

  testWidgets('the chip grammars inset their surface from the list edge', (tester) async {
    for (final language in PureDesignLanguage.values) {
      await _pumpRow(tester, language: language, selected: true);
      final inset = _rowEdgeInset[language] ?? 0;
      final width = tester.getSize(find.byKey(const Key('PureListRow.plate'), skipOffstage: false)).width;
      expect(width, 320 - 2 * inset, reason: language.name);
    }
  });

  testWidgets('selection fills each grammar as its table promises', (tester) async {
    for (final language in PureDesignLanguage.values) {
      await _pumpRow(tester, language: language, selected: true);
      final theme = _rowTheme(tester);
      expect(_rowPlate(tester).color, _rowSelectedFill(theme, language), reason: language.name);
    }
  });

  testWidgets('macOS rules the chip; wind paints a one-sided accent edge', (tester) async {
    await _pumpRow(tester, language: PureDesignLanguage.macos, selected: true);
    final macos = _rowPlate(tester);
    expect((macos.borderRadius! as BorderRadius).topLeft.x, 6);
    expect(macos.border!.top.color, _rowTheme(tester).colors.primaryBorder);
    expect(macos.border!.bottom.color, _rowTheme(tester).colors.primaryBorder);

    await _pumpRow(tester, language: PureDesignLanguage.wind, selected: true);
    final wind = _rowPlate(tester);
    final border = wind.border! as Border;
    expect(border.left.color, _rowTheme(tester).colors.primary);
    expect(border.left.width, 2);
    expect(border.top.width, 0, reason: 'one edge only — legal at radius 0');
    expect(border.right.width, 0);
    expect(wind.borderRadius, isNull);
  });

  testWidgets('neumorphic sinks the selected row with the reversed twin shadows', (tester) async {
    await _pumpRow(tester, language: PureDesignLanguage.neumorphic, selected: true);
    final plate = _rowPlate(tester);
    final shadows = plate.boxShadow!;
    expect(shadows, hasLength(2));
    // The card extrudes with (+4,+4)/(−4,−4); the groove is exactly that pair
    // reversed — shade from the top left, glow to the bottom right.
    expect(shadows[0].offset, const Offset(-4, -4));
    expect(shadows[1].offset, const Offset(4, 4));
    expect(plate.border, isNull, reason: 'a soft surface speaks in depth, not strokes');
  });

  testWidgets('glass lights the row: translucent fill, lit hairlines, lit rule', (tester) async {
    await _pumpRow(tester, language: PureDesignLanguage.glass, selected: true);
    final theme = _rowTheme(tester);
    final plate = _rowPlate(tester);
    expect(plate.color, theme.colors.white.withValues(alpha: 0.5));
    expect(plate.color!.a, lessThan(1.0));
    final border = plate.border! as Border;
    expect(border.top.color, theme.colors.white.withValues(alpha: 0.75));
    expect(border.bottom.color, theme.colors.white.withValues(alpha: 0.75));
    expect(border.left.width, 0, reason: 'the lit row rules above and below');

    final divider = tester.widget<Container>(find.byKey(const ValueKey('PureListRow.divider')));
    expect(divider.color, theme.colors.white.withValues(alpha: 0.6));
  });

  testWidgets('the fluent marker slides in and the title goes semibold', (tester) async {
    await _pumpRow(tester, language: PureDesignLanguage.fluent, onTap: () {});
    var marker = tester.getSize(find.byKey(const ValueKey('PureListRow.marker')));
    expect(marker.width, 3);
    expect(marker.height, 0, reason: 'the pill is always in the tree, sized to nothing at rest');
    expect(tester.widget<Text>(find.text('Row title')).style!.fontWeight, isNot(FontWeight.w600));

    await _pumpRow(tester, language: PureDesignLanguage.fluent, onTap: () {}, selected: true);
    await tester.pumpAndSettle();
    marker = tester.getSize(find.byKey(const ValueKey('PureListRow.marker')));
    expect(marker.height, 16);
    expect(tester.widget<Text>(find.text('Row title')).style!.fontWeight, FontWeight.w600);
  });

  testWidgets('a row tints on hover and press, and the press outlasts the hover', (tester) async {
    var taps = 0;
    await _pumpRow(tester, language: PureDesignLanguage.material, onTap: () => taps++);
    final theme = _rowTheme(tester);
    expect(_rowPlate(tester).color, isNull, reason: 'the full-bleed row carries no fill at rest');

    final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await pointer.addPointer(location: Offset.zero);
    addTearDown(pointer.removePointer);
    await pointer.moveTo(tester.getCenter(find.byType(PureListRow)));
    await tester.pump();
    expect(_rowPlate(tester).color, Color.alphaBlend(theme.colors.fill, const Color(0x00000000)));

    await pointer.down(tester.getCenter(find.byType(PureListRow)));
    await tester.pump();
    expect(_rowPlate(tester).color, Color.alphaBlend(theme.colors.fillSecondary, const Color(0x00000000)));
    await pointer.up();
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('the row ring is a static foreground box; focus only paints it', (tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    await _pumpRow(tester, language: PureDesignLanguage.fluent, onTap: () {}, focusNode: node);
    final theme = _rowTheme(tester);

    expect(_rowRing(tester).position, DecorationPosition.foreground);
    var ring = _rowRing(tester).decoration as BoxDecoration;
    expect(ring.border!.top.color, const Color(0x00000000));
    final treeBefore = find
        .descendant(of: find.byType(PureListRow), matching: find.byType(DecoratedBox))
        .evaluate()
        .length;

    node.requestFocus();
    await tester.pumpAndSettle();
    ring = _rowRing(tester).decoration as BoxDecoration;
    expect(ring.border!.top.color, theme.colors.primary);
    expect(
      find.descendant(of: find.byType(PureListRow), matching: find.byType(DecoratedBox)).evaluate().length,
      treeBefore,
      reason: 'focusing never changes the tree shape',
    );
  });

  testWidgets('space activates a focused row', (tester) async {
    var taps = 0;
    final node = FocusNode();
    addTearDown(node.dispose);
    await _pumpRow(tester, language: PureDesignLanguage.yaru, onTap: () => taps++, focusNode: node, autofocus: true);
    await tester.pump();
    expect(node.hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(taps, 1);
  });

  testWidgets('an inert row takes no focus, no ring and no tint', (tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    await _pumpRow(tester, language: PureDesignLanguage.material, focusNode: node, autofocus: true);
    expect(find.byKey(const Key('PureListRow.ring'), skipOffstage: false), findsNothing);
    expect(node.hasPrimaryFocus, isFalse);

    final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await pointer.addPointer(location: Offset.zero);
    addTearDown(pointer.removePointer);
    await pointer.moveTo(tester.getCenter(find.byType(PureListRow)));
    await tester.pump();
    expect(_rowPlate(tester).color, isNull, reason: 'a row without callbacks does not wash');
  });

  testWidgets('cupertino adds its caret only to a tappable row with no trailing', (tester) async {
    Future<bool> hasCaret(PureDesignLanguage language, {Widget? trailing, VoidCallback? onTap}) async {
      await _pumpRow(tester, language: language, trailing: trailing, onTap: onTap);
      return find.byKey(const ValueKey('PureListRow.disclosure')).evaluate().isNotEmpty;
    }

    expect(await hasCaret(PureDesignLanguage.cupertino, onTap: () {}), isTrue);
    expect(await hasCaret(PureDesignLanguage.cupertino, onTap: () {}, trailing: const Text('value')), isFalse);
    expect(await hasCaret(PureDesignLanguage.cupertino), isFalse, reason: 'an inert row opens nothing');
    expect(await hasCaret(PureDesignLanguage.material, onTap: () {}), isFalse);
  });

  testWidgets('divided draws the rule and the inset grammars inset it', (tester) async {
    for (final (language, inset) in [
      (PureDesignLanguage.cupertino, 16.0),
      (PureDesignLanguage.material, 16.0),
      (PureDesignLanguage.wind, 0.0),
    ]) {
      await _pumpRow(tester, language: language);
      final divider = tester.widget<Container>(find.byKey(const ValueKey('PureListRow.divider')));
      expect(divider.margin, EdgeInsets.only(left: inset), reason: language.name);
      expect(divider.color, _rowTheme(tester).listTile.dividerColor, reason: language.name);
    }

    await _pumpRow(tester, language: PureDesignLanguage.material, divided: false);
    expect(find.byKey(const ValueKey('PureListRow.divider')), findsNothing);
  });

  testWidgets('a selected tappable row is a button in semantics', (tester) async {
    var taps = 0;
    await _pumpRow(tester, language: PureDesignLanguage.forui, onTap: () => taps++, selected: true);
    await tester.tap(find.text('Row title'));
    expect(taps, 1);
    expect(
      find.descendant(
        of: find.byType(PureListRow),
        matching: find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.button == true && w.properties.selected == true,
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('long press fires on its own', (tester) async {
    var long = 0;
    await _pumpRow(tester, language: PureDesignLanguage.cupertino, onLongPress: () => long++);
    await tester.longPress(find.text('Row title'));
    await tester.pumpAndSettle();
    expect(long, 1);
  });

  testWidgets('dark brightness keeps the row on its token surfaces', (tester) async {
    await _pumpRow(
      tester,
      language: PureDesignLanguage.material,
      subtitle: 'second line',
      selected: true,
      brightness: Brightness.dark,
    );
    final theme = _rowTheme(tester);
    expect(theme.isDark, isTrue);
    expect(_rowPlate(tester).color, theme.colors.primaryBg);
    expect(tester.widget<Text>(find.text('second line')).style!.color, theme.colors.textSecondary);
  });
}
