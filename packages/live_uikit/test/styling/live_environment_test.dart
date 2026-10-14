import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/styling.dart';

/// The environment is live_uikit's third axis — next to the design language and
/// the tokens: the same page laid out for a phone, a window or a remote (§12). It
/// is data, so the tests are about what it resolves *from* and about who is told
/// when it changes.
void main() {
  final token = DesignToken.derive(const SeedToken(), dark: false);

  Geometry geometryFor(LiveLayoutMode mode, {DesignToken? from}) => Geometry.forTokens(from ?? token, mode);

  /// The test surface is 800 logical pixels wide by default, which would clamp any
  /// stage below it and quietly turn every "window" case into the same width.
  void bigView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// A [width]-wide stage: `Align` so the box keeps its own width instead of being
  /// stretched to the screen.
  Widget stage(double width, Widget child) => Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: width, height: 900, child: child),
  );

  group('the breakpoints resolve the mode', () {
    test('a phone width is mobile, a window is desktop, a TV is always tv', () {
      const breakpoints = LiveBreakpoints.standard;
      expect(breakpoints.resolve(360, isTv: false), LiveLayoutMode.mobile);
      expect(breakpoints.resolve(719, isTv: false), LiveLayoutMode.mobile);
      expect(breakpoints.resolve(720, isTv: false), LiveLayoutMode.desktop, reason: 'a tablet gets desktop chrome');
      expect(breakpoints.resolve(1024, isTv: false), LiveLayoutMode.desktop);
      expect(breakpoints.resolve(360, isTv: true), LiveLayoutMode.tv, reason: 'the form factor outranks the width');
    });

    test('a host can move the thresholds', () {
      const tight = LiveBreakpoints(mobileMax: 500, desktopMin: 900);
      expect(tight.resolve(600, isTv: false), LiveLayoutMode.desktop);
      expect(tight.resolve(499, isTv: false), LiveLayoutMode.mobile);
    });

    test('the environment reports the mode through its own flags', () {
      final mobile = LiveEnvironment.compute(width: 360, isTv: false, token: token);
      expect(mobile.mode, LiveLayoutMode.mobile);
      expect(mobile.isMobile, isTrue);
      expect(mobile.isTvMode, isFalse);
      expect(mobile.isTv, isFalse);

      final tv = LiveEnvironment.compute(width: 1920, isTv: true, token: token);
      expect(tv.isTvMode, isTrue);
      expect(tv.isMobile, isFalse);
      expect(tv.geometry.mode, LiveLayoutMode.tv, reason: 'the geometry knows which mode it was built for');
    });
  });

  group('the geometry follows the mode and the tokens', () {
    test('each mode gets its own page margin, icon size and gaps', () {
      expect(geometryFor(LiveLayoutMode.mobile).pagePadding, 16);
      expect(geometryFor(LiveLayoutMode.desktop).pagePadding, 24);
      expect(geometryFor(LiveLayoutMode.tv).pagePadding, 48);
      expect(geometryFor(LiveLayoutMode.mobile).iconSize, 18);
      expect(geometryFor(LiveLayoutMode.desktop).iconSize, 20);
      expect(geometryFor(LiveLayoutMode.tv).iconSize, 28);
      expect(geometryFor(LiveLayoutMode.tv).sectionGap, 32);
      expect(geometryFor(LiveLayoutMode.tv).iconGap, 12);
    });

    test('TV trades the rail for a taller nav bar and a wider canvas', () {
      final tv = geometryFor(LiveLayoutMode.tv);
      expect(tv.railWidth, 0, reason: 'a remote has no hover rail');
      expect(tv.navBarHeight, 96);
      expect(tv.contentMaxWidth, 1920);
      expect(tv.cardElevation, greaterThan(geometryFor(LiveLayoutMode.desktop).cardElevation));
    });

    test('the radii come from the token, so a reseed moves the layout', () {
      expect(geometryFor(LiveLayoutMode.desktop).controlRadius, token.scale.radii.base);
      expect(geometryFor(LiveLayoutMode.desktop).cardRadius, token.scale.radii.lg);

      final round = DesignToken.derive(const SeedToken(borderRadius: 16), dark: false);
      expect(geometryFor(LiveLayoutMode.desktop, from: round).controlRadius, 16);
      expect(geometryFor(LiveLayoutMode.desktop, from: round).cardRadius, 16);
    });

    test('a dialog is wider on a window than on a phone or a TV', () {
      expect(geometryFor(LiveLayoutMode.desktop).dialogMaxWidth, 520);
      expect(geometryFor(LiveLayoutMode.mobile).dialogMaxWidth, 420);
      expect(geometryFor(LiveLayoutMode.tv).dialogMaxWidth, 420);
    });

    test('the chrome numbers agree with the static scale the app reads', () {
      // `Geometry` and `LiveSizing` are two spellings of the same numbers; only the
      // per-mode sizes are allowed to differ.
      expect(geometryFor(LiveLayoutMode.mobile).navBarHeight, LiveSizing.navBarHeight);
      expect(geometryFor(LiveLayoutMode.desktop).navBarHeight, LiveSizing.navBarHeight);
      expect(geometryFor(LiveLayoutMode.mobile).railWidth, LiveSizing.railWidth);
      expect(geometryFor(LiveLayoutMode.desktop).railWidth, LiveSizing.railWidth);
    });
  });

  group('two geometries that differ anywhere are different geometries', () {
    test('every field participates in equality', () {
      // `LiveEnvironmentScope.updateShouldNotify` compares `Geometry` objects. A
      // field left out of `==` is a field whose change silently leaves the subtree
      // laid out with the old numbers.
      final desktop = geometryFor(LiveLayoutMode.desktop);
      final variants = <String, Geometry>{
        'mode': geometryFor(LiveLayoutMode.tv),
        'pagePadding': _copy(desktop, pagePadding: 1),
        'sectionGap': _copy(desktop, sectionGap: 1),
        'iconGap': _copy(desktop, iconGap: 1),
        'iconSize': _copy(desktop, iconSize: 1),
        'controlRadius': _copy(desktop, controlRadius: 1),
        'cardRadius': _copy(desktop, cardRadius: 1),
        'cardElevation': _copy(desktop, cardElevation: 1),
        'navBarHeight': _copy(desktop, navBarHeight: 1),
        'railWidth': _copy(desktop, railWidth: 1),
        'contentMaxWidth': _copy(desktop, contentMaxWidth: 1),
        'dialogMaxWidth': _copy(desktop, dialogMaxWidth: 1),
      };
      for (final entry in variants.entries) {
        expect(entry.value, isNot(desktop), reason: 'a change to ${entry.key} must be visible');
        expect(entry.value.hashCode, isNot(desktop.hashCode), reason: 'a change to ${entry.key} must reach hashCode');
      }
      expect(geometryFor(LiveLayoutMode.desktop), desktop);
      expect(geometryFor(LiveLayoutMode.desktop).hashCode, desktop.hashCode);
    });
  });

  group('the scope publishes what the window implies', () {
    Widget shell(Widget child, {SeedToken Function(SeedToken base)? seed}) => LiveConfigProvider(
      config: const UiConfig(),
      seed: seed,
      child: MaterialApp(home: stage(1400, child)),
    );

    testWidgets('a builder under the scope reads the resolved mode', (tester) async {
      bigView(tester);
      LiveEnvironment? seen;
      await tester.pumpWidget(
        shell(
          LiveLayoutBuilder(
            isTv: false,
            builder: (context, environment) {
              seen = environment;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(seen?.mode, LiveLayoutMode.desktop);
      expect(seen?.geometry.contentMaxWidth, 1100);
    });

    testWidgets('a narrow window re-resolves the same builder', (tester) async {
      bigView(tester);
      LiveEnvironment? seen;
      Widget app(double width) => LiveConfigProvider(
        config: const UiConfig(),
        child: MaterialApp(
          home: stage(
            width,
            LiveLayoutBuilder(
              isTv: false,
              builder: (context, environment) {
                seen = environment;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      await tester.pumpWidget(app(1400));
      expect(seen?.mode, LiveLayoutMode.desktop);
      await tester.pumpWidget(app(400));
      expect(seen?.mode, LiveLayoutMode.mobile, reason: 'the window, not the platform, decides');
    });

    testWidgets('a declared TV build ignores the width entirely', (tester) async {
      bigView(tester);
      LiveEnvironment? seen;
      await tester.pumpWidget(
        shell(
          LiveLayoutBuilder(
            isTv: true,
            builder: (context, environment) {
              seen = environment;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(seen?.mode, LiveLayoutMode.tv);
      expect(seen?.geometry.navBarHeight, 96);
    });

    testWidgets('a const consumer is re-notified when only the radius moves', (tester) async {
      bigView(tester);
      // The mode, the page padding and the icon size are unchanged here, so the
      // subtree rebuild depends entirely on `Geometry` noticing the new radius.
      Widget app(double radius) => shell(
        LiveLayoutBuilder(isTv: false, builder: (context, environment) => const _CardRadiusReader()),
        seed: (base) => base.copyWith(borderRadius: radius),
      );

      await tester.pumpWidget(app(6));
      expect(find.text('8.0'), findsOneWidget, reason: 'borderRadius 6 derives radii.lg = 8');

      await tester.pumpWidget(app(12));
      await tester.pump();
      expect(find.text('14.0'), findsOneWidget, reason: 'borderRadius 12 derives radii.lg = 14');
    });

    testWidgets('outside any builder there is no environment to read', (tester) async {
      bigView(tester);
      await tester.pumpWidget(
        LiveConfigProvider(
          config: const UiConfig(),
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                expect(LiveEnvironmentScope.maybeOf(context), isNull);
                expect(() => LiveEnvironmentScope.of(context), throwsA(isA<TypeError>()));
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
    });
  });

  group('the state views work with and without a scope', () {
    testWidgets('inside a TV scope they use the TV margins', (tester) async {
      bigView(tester);
      await tester.pumpWidget(
        LiveConfigProvider(
          config: const UiConfig(),
          child: MaterialApp(
            home: stage(
              1600,
              LiveLayoutBuilder(
                isTv: true,
                builder: (context, environment) => const LiveLoading(compact: true, message: 'connecting'),
              ),
            ),
          ),
        ),
      );
      expect(_loadingPadding(tester), const EdgeInsets.all(48));
    });

    testWidgets('outside one they fall back to the desktop geometry', (tester) async {
      bigView(tester);
      await tester.pumpWidget(
        const LiveConfigProvider(
          config: UiConfig(),
          child: MaterialApp(home: LiveLoading(compact: true, message: 'connecting')),
        ),
      );
      expect(_loadingPadding(tester), const EdgeInsets.all(24));
    });
  });

  group('the content grid lays out from the geometry', () {
    Widget grid(double width) => LiveConfigProvider(
      config: const UiConfig(),
      child: MaterialApp(
        home: stage(
          width,
          LiveLayoutBuilder(
            isTv: false,
            builder: (context, environment) => LiveContentGrid(
              itemCount: 12,
              itemBuilder: (context, index) => Text('tile $index', textDirection: TextDirection.ltr),
            ),
          ),
        ),
      ),
    );

    testWidgets('the same widget gives a phone two columns and a window many', (tester) async {
      bigView(tester);
      await tester.pumpWidget(grid(420));
      final firstRowTop = tester.getTopLeft(find.text('tile 0')).dy;
      expect(tester.getTopLeft(find.text('tile 1')).dy, firstRowTop);
      expect(tester.getTopLeft(find.text('tile 1')).dx, greaterThan(tester.getTopLeft(find.text('tile 0')).dx));
      expect(tester.getTopLeft(find.text('tile 2')).dy, greaterThan(firstRowTop), reason: 'two across on a phone');

      await tester.pumpWidget(grid(1400));
      final windowTop = tester.getTopLeft(find.text('tile 0')).dy;
      for (final index in [1, 2, 3, 4]) {
        expect(tester.getTopLeft(find.text('tile $index')).dy, windowTop, reason: 'tile $index is still row one');
      }
      expect(tester.getTopLeft(find.text('tile 5')).dy, greaterThan(windowTop));
    });

    testWidgets('the gap is the geometry gap doubled, never a literal', (tester) async {
      bigView(tester);
      await tester.pumpWidget(
        LiveConfigProvider(
          config: const UiConfig(),
          child: MaterialApp(
            home: stage(
              420,
              LiveLayoutBuilder(
                isTv: false,
                builder: (context, environment) => const LiveContentGrid(itemCount: 4, itemBuilder: _emptyTile),
              ),
            ),
          ),
        ),
      );
      final delegate =
          tester.widget<GridView>(find.byType(GridView)).gridDelegate as SliverGridDelegateWithMaxCrossAxisExtent;
      final phoneGap = geometryFor(LiveLayoutMode.mobile).iconGap;
      expect(delegate.crossAxisSpacing, phoneGap * 2);
      expect(delegate.mainAxisSpacing, phoneGap * 2);
      expect(delegate.maxCrossAxisExtent, 260);
    });
  });

  group('the static scale stays a scale', () {
    test('the ladder is ordered and the remote beats the thumb', () {
      expect(LiveSizing.iconXs, lessThan(LiveSizing.iconSm));
      expect(LiveSizing.iconSm, lessThan(LiveSizing.iconMd));
      expect(LiveSizing.iconMd, lessThan(LiveSizing.iconLg));
      expect(LiveSizing.iconLg, lessThan(LiveSizing.iconXl));
      expect(LiveSizing.controlHeightCompact, lessThan(LiveSizing.controlHeight));
      expect(LiveSizing.controlHeight, lessThan(LiveSizing.controlHeightTv));
      expect(LiveSizing.minTouchTarget, lessThan(LiveSizing.minRemoteTarget));
    });
  });
}

EdgeInsetsGeometry _loadingPadding(WidgetTester tester) =>
    tester.widget<Padding>(find.descendant(of: find.byType(LiveLoading), matching: find.byType(Padding))).padding;

Widget _emptyTile(BuildContext context, int index) => const SizedBox.shrink();

/// A const leaf that only rebuilds if the inherited environment reports a change.
class _CardRadiusReader extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final geometry = LiveEnvironmentScope.of(context).geometry;
    return Text('${geometry.cardRadius}', textDirection: TextDirection.ltr);
  }
}

Geometry _copy(
  Geometry base, {
  double? pagePadding,
  double? sectionGap,
  double? iconGap,
  double? iconSize,
  double? controlRadius,
  double? cardRadius,
  double? cardElevation,
  double? navBarHeight,
  double? railWidth,
  double? contentMaxWidth,
  double? dialogMaxWidth,
}) => Geometry(
  mode: base.mode,
  pagePadding: pagePadding ?? base.pagePadding,
  sectionGap: sectionGap ?? base.sectionGap,
  iconGap: iconGap ?? base.iconGap,
  iconSize: iconSize ?? base.iconSize,
  controlRadius: controlRadius ?? base.controlRadius,
  cardRadius: cardRadius ?? base.cardRadius,
  cardElevation: cardElevation ?? base.cardElevation,
  navBarHeight: navBarHeight ?? base.navBarHeight,
  railWidth: railWidth ?? base.railWidth,
  contentMaxWidth: contentMaxWidth ?? base.contentMaxWidth,
  dialogMaxWidth: dialogMaxWidth ?? base.dialogMaxWidth,
);
