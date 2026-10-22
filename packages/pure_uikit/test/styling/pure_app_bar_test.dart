import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The branch key the public bar hangs on its plate: the language whose
/// geometry a bar is drawing is addressable in tests and diagnostics.
Key _branch(PureDesignLanguage language) => ValueKey('PureAppBar.${language.name}');

/// The one plate the bar paints this frame; its colour, cast and rule are the
/// contract the language answers with.
final Finder _plate = find.descendant(
  of: find.byType(PureAppBar),
  matching: find.byKey(const ValueKey('PureAppBar.plate')),
);

/// The frost layer the blurred languages put behind the plate, when any.
final Finder _frost = find.descendant(of: find.byType(PureAppBar), matching: find.byType(BackdropFilter));

/// The header semantics node every language puts on its title cell.
final Finder _header = find.descendant(
  of: find.byType(PureAppBar),
  matching: find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.header == true),
);

/// The plate's decoration, read back from the widget the bar built.
BoxDecoration _plateDecoration(WidgetTester tester) => tester.widget<DecoratedBox>(_plate).decoration as BoxDecoration;

/// The title size each language's own header grammar draws.
const Map<PureDesignLanguage, double> _titleSize = {
  PureDesignLanguage.fluent: 28,
  PureDesignLanguage.macos: 13,
  PureDesignLanguage.cupertino: 17,
  PureDesignLanguage.glass: 17,
  PureDesignLanguage.wind: 18,
  PureDesignLanguage.forui: 18,
  PureDesignLanguage.material: 22,
  PureDesignLanguage.yaru: 15,
  PureDesignLanguage.neumorphic: 18,
};

/// The languages that centre the bare title when the caller says nothing.
const Set<PureDesignLanguage> _centred = {
  PureDesignLanguage.macos,
  PureDesignLanguage.cupertino,
  PureDesignLanguage.yaru,
  PureDesignLanguage.neumorphic,
};

/// The languages whose plate casts by default.
const Set<PureDesignLanguage> _elevatedByDefault = {
  PureDesignLanguage.macos,
  PureDesignLanguage.material,
  PureDesignLanguage.neumorphic,
};

/// The languages whose plate frosts by default, where the device affords it.
const Set<PureDesignLanguage> _frostedByDefault = {PureDesignLanguage.cupertino, PureDesignLanguage.glass};

/// Pumps [bar] under [language]. The control is given a width and
/// never a fixed tight height — its own row states its height, and flattening
/// that with a tight box would make every geometry assertion a lie.
Future<void> _pump(
  WidgetTester tester,
  PureAppBar bar, {
  PureDesignLanguage language = PureDesignLanguage.material,
  Brightness brightness = Brightness.light,
  double width = 420,
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
            child: SizedBox(width: width, child: bar),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// A bare bar under [language]: width 420 centred in the 800-wide test view,
/// so the bar spans dx 190..610 and its centre is 400.
Future<void> _pumpBare(
  WidgetTester tester, {
  required PureDesignLanguage language,
  String title = 'Rooms',
  Widget? bottom,
  double? height,
  bool? centerTitle,
  bool? elevation,
  bool? blur,
  Color? background,
  Brightness brightness = Brightness.light,
}) => _pump(
  tester,
  PureAppBar(
    title: title,
    bottom: bottom,
    height: height,
    centerTitle: centerTitle,
    elevation: elevation,
    blur: blur,
    background: background,
  ),
  language: language,
  brightness: brightness,
);

void main() {
  group('branches', () {
    testWidgets('every design language draws its own bar', (tester) async {
      for (final language in PureDesignLanguage.values) {
        await _pumpBare(tester, language: language);
        expect(tester.takeException(), isNull, reason: '$language failed to build');
        expect(find.byKey(_branch(language)), findsOneWidget, reason: '$language lost its branch');
        expect(_plate, findsOneWidget, reason: '$language lost its plate');
        expect(find.text('Rooms'), findsOneWidget, reason: '$language dropped its title');
      }
    });

    testWidgets("every bar wears its language's own title size", (tester) async {
      for (final language in PureDesignLanguage.values) {
        await _pumpBare(tester, language: language);
        final style = tester.widget<Text>(find.text('Rooms')).style;
        expect(style!.fontSize, _titleSize[language], reason: '$language re-picked its ramp');
      }
    });

    testWidgets('the dark ramp keeps the title geometry', (tester) async {
      for (final language in PureDesignLanguage.values) {
        await _pumpBare(tester, language: language, brightness: Brightness.dark);
        expect(tester.takeException(), isNull, reason: '$language failed in dark');
        expect(tester.widget<Text>(find.text('Rooms')).style!.fontSize, _titleSize[language]);
      }
    });

    testWidgets('the title widget replaces the title text in every language', (tester) async {
      for (final language in PureDesignLanguage.values) {
        await _pump(
          tester,
          const PureAppBar(
            title: 'text title',
            titleWidget: Row(children: [Text('widget title')]),
          ),
          language: language,
        );
        expect(tester.takeException(), isNull, reason: '$language failed on a widget title');
        expect(find.text('widget title'), findsOneWidget, reason: '$language dropped the title widget');
        expect(find.text('text title'), findsNothing, reason: '$language rendered both titles');
      }
    });

    testWidgets('the height knob sizes the row in every language', (tester) async {
      for (final language in PureDesignLanguage.values) {
        await _pumpBare(tester, language: language, height: 72);
        final plate = tester.getRect(find.byKey(_branch(language)));
        expect(plate.height, 72, reason: '$language ignored the height it was handed');
      }
    });
  });

  group('slots', () {
    testWidgets('leading takes the start and actions the end, in every language', (tester) async {
      for (final language in PureDesignLanguage.values) {
        await _pump(
          tester,
          const PureAppBar(
            title: 'Rooms',
            leading: SizedBox(key: ValueKey('lead'), width: 24, height: 24),
            actions: [
              SizedBox(key: ValueKey('a1'), width: 20, height: 20),
              SizedBox(key: ValueKey('a2'), width: 20, height: 20),
            ],
          ),
          language: language,
        );
        final lead = tester.getRect(find.byKey(const ValueKey('lead')));
        final title = tester.getRect(find.text('Rooms'));
        final first = tester.getRect(find.byKey(const ValueKey('a1')));
        final last = tester.getRect(find.byKey(const ValueKey('a2')));
        expect(lead.center.dx, lessThan(title.center.dx), reason: '$language put the title before the lead');
        expect(title.right, lessThanOrEqualTo(first.left), reason: '$language ran the title into the actions');
        expect(first.center.dx, lessThan(last.center.dx), reason: '$language reordered its actions');
      }
    });

    testWidgets('a bare title lands by the language grammar', (tester) async {
      for (final language in PureDesignLanguage.values) {
        await _pumpBare(tester, language: language);
        final title = tester.getRect(find.text('Rooms'));
        final bar = tester.getRect(find.byKey(_branch(language)));
        if (_centred.contains(language)) {
          expect(
            title.center.dx,
            closeTo(bar.center.dx, 0.5),
            reason: '$language claims a centred title but drew it off-centre',
          );
        } else {
          expect(title.center.dx, lessThan(bar.center.dx), reason: '$language drifted a started title right');
        }
      }
    });

    testWidgets('centerTitle overrides the language grammar both ways', (tester) async {
      // A start language centres when told to...
      await _pumpBare(tester, language: PureDesignLanguage.material, centerTitle: true);
      var title = tester.getRect(find.text('Rooms'));
      final bar = tester.getRect(find.byKey(_branch(PureDesignLanguage.material)));
      expect(title.center.dx, closeTo(bar.center.dx, 0.5), reason: 'material refused the asked-for centre');

      // ...and a centring language starts when told to (web_search_view's shape).
      await _pumpBare(tester, language: PureDesignLanguage.yaru, centerTitle: false);
      title = tester.getRect(find.text('Rooms'));
      expect(title.center.dx, lessThan(tester.getRect(find.byKey(_branch(PureDesignLanguage.yaru))).center.dx));
    });

    testWidgets('the bottom strip lands under the row and grows the reserved size', (tester) async {
      const strip = PreferredSize(
        preferredSize: Size.fromHeight(40),
        child: SizedBox(height: 40, child: Center(child: Text('strip'))),
      );
      for (final language in PureDesignLanguage.values) {
        await _pumpBare(tester, language: language, bottom: strip);
        expect(tester.takeException(), isNull, reason: '$language failed on a bottom strip');
        expect(find.text('strip'), findsOneWidget, reason: '$language dropped the strip');
        final row = tester.getRect(find.text('Rooms'));
        final laid = tester.getRect(find.text('strip'));
        expect(laid.top, greaterThanOrEqualTo(row.bottom), reason: '$language drew the strip over the row');
        final reserved = tester.widget<PureAppBar>(find.byType(PureAppBar)).preferredSize;
        expect(reserved.height, 56 + 40, reason: '$language did not reserve the strip');
      }
    });

    testWidgets('a strip with no stated height renders but reserves nothing', (tester) async {
      await _pumpBare(
        tester,
        language: PureDesignLanguage.material,
        bottom: const SizedBox(height: 30, child: Center(child: Text('plain strip'))),
      );
      final reserved = tester.widget<PureAppBar>(find.byType(PureAppBar)).preferredSize;
      expect(reserved.height, 56);
      expect(find.text('plain strip'), findsOneWidget);
      expect(tester.getRect(find.text('plain strip')).top, greaterThan(tester.getRect(find.text('Rooms')).bottom));
    });
  });

  group('plate', () {
    testWidgets('the plate carries the background colour in every language', (tester) async {
      for (final language in PureDesignLanguage.values) {
        await _pumpBare(tester, language: language, background: Colors.teal);
        expect(_plateDecoration(tester).color, Colors.teal, reason: '$language painted over the caller colour');
      }
    });

    testWidgets('elevation adds and removes the cast against the language default', (tester) async {
      for (final language in PureDesignLanguage.values) {
        await _pumpBare(tester, language: language);
        final shadows = _plateDecoration(tester).boxShadow;
        final hasCast = shadows != null && shadows.isNotEmpty;
        expect(hasCast, _elevatedByDefault.contains(language), reason: '$language cast the wrong default');

        await _pumpBare(tester, language: language, elevation: !hasCast);
        final toggled = _plateDecoration(tester).boxShadow;
        if (hasCast) {
          expect(toggled, anyOf(isNull, isEmpty), reason: '$language kept its cast against elevation: false');
        } else {
          expect(toggled, isNotNull, reason: '$language ignored elevation: true');
          expect(toggled, isNotEmpty);
        }
      }
    });

    testWidgets('blur frosts the plate where the device affords it', (tester) async {
      for (final language in PureDesignLanguage.values) {
        await _pumpBare(tester, language: language);
        expect(
          _frost,
          _frostedByDefault.contains(language) ? findsOneWidget : findsNothing,
          reason: '$language frosted the wrong default',
        );

        // An explicit true frosts anywhere the device can; false never does.
        await _pumpBare(tester, language: language, blur: true);
        expect(_frost, findsOneWidget, reason: '$language skipped an asked-for frost');

        await _pumpBare(tester, language: language, blur: false);
        expect(_frost, findsNothing, reason: '$language kept a refused frost');
      }
    });

    testWidgets('a frosted plate reads through translucent, an opaque one does not', (tester) async {
      await _pumpBare(tester, language: PureDesignLanguage.glass);
      final frosted = _plateDecoration(tester).color!;
      expect(frosted.a, lessThan(1), reason: 'the glass plate frosted but painted itself opaque');

      await _pumpBare(tester, language: PureDesignLanguage.glass, blur: false);
      expect(_plateDecoration(tester).color!.a, 1, reason: 'the flat glass plate stayed translucent');
    });
  });

  group('contract', () {
    testWidgets('every language names its title as a header for screen readers', (tester) async {
      for (final language in PureDesignLanguage.values) {
        await _pumpBare(tester, language: language);
        expect(_header, findsOneWidget, reason: '$language lost its header semantics');
      }
    });

    testWidgets('a poppable route implies the back affordance and it pops', (tester) async {
      await tester.pumpWidget(
        const PureConfigProvider(
          config: UiConfig(language: PureDesignLanguage.macos),
          child: MaterialApp(
            home: Scaffold(
              body: Center(child: PureAppBar(title: 'First')),
            ),
          ),
        ),
      );
      await tester.pump();
      // The root route cannot pop: no affordance is implied.
      expect(find.byIcon(Icons.arrow_back), findsNothing);

      tester
          .state<NavigatorState>(find.byType(Navigator))
          .push(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(
                body: Center(child: PureAppBar(title: 'Second')),
              ),
            ),
          );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget, reason: 'the pushed page lost its back affordance');
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('First'), findsOneWidget, reason: 'the back affordance did not pop');
      expect(tester.takeException(), isNull);
    });

    testWidgets('an explicit leading replaces the implied back affordance', (tester) async {
      await tester.pumpWidget(
        PureConfigProvider(
          config: const UiConfig(language: PureDesignLanguage.cupertino),
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const Scaffold(
                            body: Center(
                              child: PureAppBar(
                                title: 'Second',
                                leading: SizedBox(key: ValueKey('own lead'), width: 24, height: 24),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    child: const Text('push'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('push'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('own lead')), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsNothing, reason: 'the caller leading was kept beside an implied back');
    });

    testWidgets('the call shapes the app pages use all build', (tester) async {
      // main_page_frame's home-tab shape: leading, widget title, shell
      // actions and a PreferredSize tab strip; plus settings_chrome's plain
      // title + actions and the about page's bare title.
      for (final language in PureDesignLanguage.values) {
        await _pump(
          tester,
          const PureAppBar(
            leading: SizedBox(key: ValueKey('menu'), width: 40, height: 40),
            title: 'Follow',
            titleWidget: Text('follow tabs'),
            actions: [SizedBox(width: 32, height: 32), SizedBox(width: 32, height: 32)],
            bottom: PreferredSize(preferredSize: Size.fromHeight(48), child: SizedBox(height: 48)),
          ),
          language: language,
        );
        expect(tester.takeException(), isNull, reason: '$language failed on the shell shape');
        expect(find.byKey(_branch(language)), findsOneWidget);
        expect(find.text('follow tabs'), findsOneWidget);

        await _pumpBare(tester, language: language);
        expect(find.byKey(_branch(language)), findsOneWidget, reason: '$language failed on the plain shape');
      }
    });
  });
}
