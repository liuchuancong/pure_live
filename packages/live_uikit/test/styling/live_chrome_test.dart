import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/styling.dart';

import 'stub_router.dart';

/// The chrome controls are dispatched like every other control, so the spec that
/// reaches the adapter is the contract a page's call site is held to: a field a
/// page sets and the adapter never sees is a field that silently stops working
/// the moment a language draws the frame itself.
class _RecordingAdapter extends SharedLanguageAdapter {
  new(this.captured);

  final List<Object?> captured;

  @override
  LiveDesignLanguage get language => LiveDesignLanguage.fluent;

  @override
  String get id => 'recording';

  @override
  String get displayName => 'Recording';

  @override
  LiveUiCapabilities get capabilities => const LiveUiCapabilities({
    LiveUiControl.scaffold,
    LiveUiControl.appBar,
    LiveUiControl.listRow,
    LiveUiControl.navBar,
    LiveUiControl.toast,
  });

  @override
  LiveUiSurfaceCapabilities get surfaces => const LiveUiSurfaceCapabilities({LiveUiSurface.appHost});

  @override
  Widget scaffold(BuildContext context, LanguageScaffoldSpec spec) {
    captured.add(spec);
    return super.scaffold(context, spec);
  }

  @override
  Widget appBar(BuildContext context, LanguageAppBarSpec spec) {
    captured.add(spec);
    return super.appBar(context, spec);
  }

  @override
  Widget listRow(BuildContext context, LanguageListRowSpec spec) {
    captured.add(spec);
    return super.listRow(context, spec);
  }

  @override
  Widget navBar(BuildContext context, LanguageNavBarSpec spec) {
    captured.add(spec);
    return super.navBar(context, spec);
  }

  @override
  Widget toast(BuildContext context, LanguageToastSpec spec) {
    captured.add(spec);
    return super.toast(context, spec);
  }

  @override
  Widget appHost(BuildContext context, LanguageHostSpec spec) {
    captured.add(spec);
    return super.appHost(context, spec);
  }

  @override
  Widget shell(BuildContext context, LanguageShellSpec spec) {
    captured.add(spec);
    return super.shell(context, spec);
  }
}

void main() {
  late List<Object?> captured;
  late LanguageRegistry registry;

  setUp(() {
    captured = [];
    final adapter = _RecordingAdapter(captured);
    registry = LanguageRegistry(adapters: {LiveDesignLanguage.fluent: adapter}, fallback: adapter);
  });

  Widget harness(Widget child) => LiveConfigProvider(
    config: const UiConfig(language: LiveDesignLanguage.fluent),
    registry: registry,
    child: MaterialApp(home: child),
  );

  group('the chrome forwards its spec', () {
    testWidgets('the frame carries its bars, action and layout flags', (tester) async {
      await tester.pumpWidget(
        harness(
          const SizedBox(
            height: 400,
            child: LiveScaffold(
              body: Text('body'),
              appBar: LiveAppBar(title: 'bar'),
              bottomBar: LiveListRow(title: 'bottom'),
              floatingActionButton: Icon(Icons.add),
              extendBodyBehindAppBar: true,
              avoidKeyboard: false,
            ),
          ),
        ),
      );

      final spec = captured.whereType<LanguageScaffoldSpec>().single;
      expect(spec.extendBodyBehindAppBar, isTrue);
      expect(spec.avoidKeyboard, isFalse);
      expect(spec.appBar, isA<LiveAppBar>());
      expect(spec.bottomBar, isA<LiveListRow>());
      expect(spec.floatingActionButton, isA<Icon>());
      expect(spec.background, isNull);
    });

    testWidgets('the bar carries title, leading, actions, strip and geometry', (tester) async {
      await tester.pumpWidget(
        harness(
          LiveAppBar(
            title: 'Rooms',
            leading: const Icon(Icons.menu),
            actions: const [Icon(Icons.search)],
            bottom: LiveTabs(
              tabs: const [LiveTab(label: 'a')],
              index: 0,
              onChanged: (_) {},
            ),
            centerTitle: true,
            height: 64,
          ),
        ),
      );

      final spec = captured.whereType<LanguageAppBarSpec>().single;
      expect(spec.title, 'Rooms');
      expect(spec.leading, isA<Icon>());
      expect(spec.actions, hasLength(1));
      expect(spec.bottom, isA<LiveTabs>());
      expect(spec.centerTitle, isTrue);
      expect(spec.height, 64);
    });

    testWidgets('the row carries both press handlers and its state', (tester) async {
      await tester.pumpWidget(
        harness(
          LiveListRow(
            title: 'Followed',
            subtitle: '3 rooms',
            leading: const Icon(Icons.star),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
            onLongPress: () {},
            selected: true,
            divided: false,
          ),
        ),
      );

      final spec = captured.whereType<LanguageListRowSpec>().single;
      expect(spec.title, 'Followed');
      expect(spec.subtitle, '3 rooms');
      expect(spec.onTap, isNotNull);
      expect(spec.onLongPress, isNotNull);
      expect(spec.selected, isTrue);
      expect(spec.divided, isFalse, reason: 'the page asked for no divider and got none');
    });
  });

  group('the capability declaration is the dispatch decision', () {
    testWidgets('a language that declares the chrome renders it natively', (tester) async {
      late LiveTheme theme;
      await tester.pumpWidget(
        harness(
          Builder(
            builder: (context) {
              theme = LiveTheme.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(theme.supports(LiveUiControl.scaffold), isTrue);
      expect(theme.supports(LiveUiControl.appBar), isTrue);
      expect(theme.supports(LiveUiControl.listRow), isTrue);
      expect(theme.supports(LiveUiControl.navBar), isTrue);
      expect(theme.supports(LiveUiControl.toast), isTrue);
      expect(theme.supports(LiveUiControl.slider), isFalse, reason: 'unclaimed controls stay shared');
      // The surfaces are a separate declaration: this adapter owns the app host
      // and not the shell, and owning one says nothing about the other.
      expect(theme.supportsSurface(LiveUiSurface.appHost), isTrue);
      expect(theme.supportsSurface(LiveUiSurface.appShell), isFalse);
    });

    testWidgets('the token base claims none of them', (tester) async {
      const base = SharedLanguageAdapter();
      for (final control in [
        LiveUiControl.scaffold,
        LiveUiControl.appBar,
        LiveUiControl.listRow,
        LiveUiControl.navBar,
        LiveUiControl.toast,
      ]) {
        expect(base.capabilities.supports(control), isFalse, reason: '$control is not native to the token base');
      }
      for (final surface in LiveUiSurface.values) {
        expect(base.surfaces.supports(surface), isFalse, reason: '$surface is not native to the token base');
      }
    });
  });

  group('the chrome still hosts Material descendants', () {
    // The token frame replaced Material's, and Material's frame was also what
    // gave a page its `Material` ancestor. Without one, an `InkWell` a caller
    // left in a card's content, text selection and tooltips throw — so the
    // chrome installs it itself and this asserts it stays installed.
    testWidgets('a card gives its content a Material ancestor', (tester) async {
      await tester.pumpWidget(
        harness(
          LiveCard(
            child: InkWell(
              onTap: () {},
              child: const SizedBox(height: 40, child: Center(child: Text('room'))),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(
        Material.maybeOf(tester.element(find.text('room'))),
        isNotNull,
        reason: 'the ink host has to come from the card, not from an ancestor page',
      );
    });

    testWidgets('the frame hosts Material for the whole page', (tester) async {
      await tester.pumpWidget(
        harness(
          const SizedBox(
            height: 300,
            child: LiveScaffold(body: Center(child: Text('page'))),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(Material.maybeOf(tester.element(find.text('page'))), isNotNull);
    });
  });

  group('the navigation bar', () {
    testWidgets('items, index and callbacks travel to the adapter', (tester) async {
      await tester.pumpWidget(
        harness(
          LiveNavBar(
            items: const [
              LiveNavBarItem(label: 'Home', icon: Icons.home),
              LiveNavBarItem(label: 'Set', icon: Icons.settings),
            ],
            index: 1,
            onChanged: (_) {},
          ),
        ),
      );

      final spec = captured.whereType<LanguageNavBarSpec>().single;
      expect(spec.items, hasLength(2));
      expect(spec.items.first.label, 'Home');
      expect(spec.index, 1);
      expect(spec.onChanged, isNotNull);
      expect(spec.enabled, isTrue);
    });

    testWidgets('a tap reports the destination that was hit', (tester) async {
      var chosen = -1;
      await tester.pumpWidget(
        harness(
          LiveNavBar(
            items: const [
              LiveNavBarItem(label: 'Home', icon: Icons.home),
              LiveNavBarItem(label: 'Set', icon: Icons.settings),
            ],
            index: 0,
            onChanged: (index) => chosen = index,
          ),
        ),
      );

      await tester.tap(find.text('Set'));
      await tester.pump();
      expect(chosen, 1);

      // The selected destination says so to a screen reader; the colour alone
      // is not a statement anyone else can read.
      expect(find.bySemanticsLabel('Home'), findsOneWidget);
    });

    testWidgets('a null callback makes the whole bar inert', (tester) async {
      await tester.pumpWidget(
        harness(
          const LiveNavBar(
            items: [LiveNavBarItem(label: 'Home', icon: Icons.home)],
            index: 0,
          ),
        ),
      );

      final spec = captured.whereType<LanguageNavBarSpec>().single;
      expect(spec.onChanged, isNull);
      expect(find.byType(TokenNavBar), findsOneWidget);
    });
  });

  group('the toast', () {
    testWidgets('showing one routes its surface through the adapter', (tester) async {
      late BuildContext inside;
      await tester.pumpWidget(
        harness(
          Builder(
            builder: (context) {
              inside = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      LiveToast.show(inside, 'Saved', type: LiveToastType.success, duration: const Duration(milliseconds: 100));
      await tester.pump();

      final spec = captured.whereType<LanguageToastSpec>().single;
      expect(spec.message, 'Saved');
      expect(spec.type, LiveToastType.success);
      expect(spec.duration, const Duration(milliseconds: 100));
      expect(spec.icon, isNull, reason: 'the glyph default belongs to the renderer, not the caller');
      expect(find.text('Saved'), findsOneWidget);

      // And it leaves on its own: the timer reverses the entrance and the
      // overlay entry goes with it.
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsNothing);
    });

    testWidgets('a context with no overlay above it drops the call', (tester) async {
      await tester.pumpWidget(
        LiveConfigProvider(
          config: const UiConfig(language: LiveDesignLanguage.fluent),
          registry: registry,
          child: Builder(
            builder: (context) {
              LiveToast.show(context, 'nowhere to go');
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(captured.whereType<LanguageToastSpec>(), isEmpty);
    });
  });

  group('the host', () {
    // No outer `MaterialApp` here on purpose: the host under test is the app
    // widget, and a Material host wrapped inside another one would pass while a
    // real page never looks like that.
    Widget hostHarness(Widget child) => LiveConfigProvider(
      config: const UiConfig(language: LiveDesignLanguage.fluent),
      registry: registry,
      child: child,
    );

    testWidgets('the router, the strings and the wrap travel to the adapter', (tester) async {
      final router = stubRouterConfig();
      var wrapped = 0;
      await tester.pumpWidget(
        hostHarness(
          LiveApp(
            routerConfig: router,
            title: 'Rooms',
            localizationsDelegates: liveLocalizationsDelegates,
            supportedLocales: const [Locale('en'), Locale('zh')],
            locale: const Locale('zh'),
            builder: (context, child) {
              wrapped++;
              return child!;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final spec = captured.whereType<LanguageHostSpec>().single;
      expect(spec.routerConfig, same(router));
      expect(spec.title, 'Rooms');
      expect(spec.localizationsDelegates, same(liveLocalizationsDelegates));
      expect(spec.supportedLocales, hasLength(2));
      expect(spec.locale, const Locale('zh'));
      expect(spec.builder, isNotNull);
      expect(wrapped, greaterThan(0), reason: 'the host runs the wrap above its routes');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a language that declares the host still gets the Material frame from the base', (tester) async {
      await tester.pumpWidget(hostHarness(LiveApp(routerConfig: stubRouterConfig())));
      await tester.pumpAndSettle();

      // The recording adapter forwards to `super.host`, which is the token
      // renderer — the same fall-through a control gets.
      expect(find.byType(TokenApp), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('the shell', () {
    const destinations = [
      LiveShellDestination(id: 'home', label: 'Home', icon: Icons.home),
      LiveShellDestination(id: 'follow', label: 'Follow', icon: Icons.favorite),
      LiveShellDestination(id: 'locked', label: 'Locked', icon: Icons.lock, enabled: false),
    ];

    // A shell fills a window, so it is pumped inside a bounded box: the rail and
    // the strip both expand into the space the page leaves, which an unbounded
    // `Center` does not have.
    Widget shellHarness(Widget child) => LiveConfigProvider(
      config: const UiConfig(language: LiveDesignLanguage.fluent),
      registry: registry,
      child: MaterialApp(
        home: Scaffold(body: SizedBox(width: 600, height: 400, child: child)),
      ),
    );

    testWidgets('the destinations, the selection and the intent travel to the adapter', (tester) async {
      var chosen = '';
      await tester.pumpWidget(
        shellHarness(
          LiveAppShell(
            destinations: destinations,
            selectedId: 'follow',
            onSelected: (id) => chosen = id,
            placement: LiveShellPlacement.rail,
            trailing: const Text('settings'),
            child: const Text('page'),
          ),
        ),
      );

      final spec = captured.whereType<LanguageShellSpec>().single;
      expect(spec.destinations, hasLength(3));
      expect(spec.destinations.first.id, 'home');
      expect(spec.destinations.last.enabled, isFalse);
      expect(spec.selectedId, 'follow');
      expect(spec.onSelected, isNotNull);
      expect(spec.placement, LiveShellPlacement.rail);
      expect(spec.trailing, isNotNull);
      expect(chosen, '', reason: 'building the shell reports nothing');
    });

    testWidgets('a language that owns no shell draws the token shell, and its own bar', (tester) async {
      var chosen = '';
      await tester.pumpWidget(
        shellHarness(
          LiveAppShell(
            destinations: destinations,
            selectedId: 'home',
            onSelected: (id) => chosen = id,
            placement: LiveShellPlacement.bottom,
            child: const Text('page'),
          ),
        ),
      );

      // The adapter declares `appHost` but not `appShell`, so the shell is the
      // token's — while the strip inside it is dispatched, and this adapter does
      // declare `navBar`. That is the layering the surfaces exist for.
      expect(find.byType(TokenAppShell), findsOneWidget);
      expect(find.byType(TokenNavBar), findsOneWidget);
      expect(find.text('page'), findsOneWidget);

      await tester.tap(find.text('Follow'));
      await tester.pump();
      expect(chosen, 'follow');
    });

    // `none` is not in this list: it draws no navigation at all, which the next
    // test asserts — there is no cell here to tap.
    for (final placement in [LiveShellPlacement.rail, LiveShellPlacement.bottom, LiveShellPlacement.adaptive]) {
      testWidgets('a disabled destination is inert in the ${placement.name} form', (tester) async {
        var chosen = '';
        await tester.pumpWidget(
          shellHarness(
            LiveAppShell(
              destinations: destinations,
              selectedId: 'home',
              onSelected: (id) => chosen = id,
              placement: placement,
              child: const SizedBox.shrink(),
            ),
          ),
        );

        await tester.tap(find.text('Locked'));
        await tester.pump();
        expect(chosen, '', reason: '${placement.name} must refuse a disabled destination');

        await tester.tap(find.text('Follow'));
        await tester.pump();
        expect(chosen, 'follow', reason: '${placement.name} still reaches a live destination');
      });
    }

    testWidgets('a shell with nothing to choose, or asked for no navigation, draws the page alone', (tester) async {
      await tester.pumpWidget(shellHarness(const LiveAppShell(child: Text('page'))));
      expect(find.text('Follow'), findsNothing);
      expect(find.text('page'), findsOneWidget);

      await tester.pumpWidget(
        shellHarness(
          const LiveAppShell(destinations: destinations, placement: LiveShellPlacement.none, child: Text('page')),
        ),
      );
      expect(find.text('Home'), findsNothing, reason: 'placement.none asks for a frame, not a navigation');
      expect(find.text('page'), findsOneWidget);
    });
  });
}
