import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/live_uikit.dart';

import 'stub_router.dart';

/// The chrome controls are dispatched like every other control, so the spec that
/// reaches the adapter is the contract a page's call site is held to: a field a
/// page sets and the adapter never sees is a field that silently stops working.
///
/// There is no shared floor to forward to any more, so every member of the
/// contract is written out here. Each one records the spec it was handed and
/// then draws a neutral placeholder — what it paints is irrelevant to these
/// tests, that it is *asked* at all is the subject.
class _RecordingAdapter implements LanguageAdapter {
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
  Widget wrap(BuildContext context, DesignToken token, Widget child) => child;

  @override
  Widget button(BuildContext context, LanguageButtonSpec spec) {
    captured.add(spec);
    return Text(spec.label, textDirection: TextDirection.ltr);
  }

  @override
  Widget card(BuildContext context, LanguageCardSpec spec) {
    captured.add(spec);
    return Material(type: MaterialType.transparency, child: spec.child);
  }

  @override
  Widget textField(BuildContext context, LanguageTextFieldSpec spec) {
    captured.add(spec);
    return Text(spec.placeholder ?? '', textDirection: TextDirection.ltr);
  }

  @override
  Widget switchWidget(BuildContext context, LanguageSwitchSpec spec) {
    captured.add(spec);
    return const SizedBox.shrink();
  }

  @override
  Widget checkbox(BuildContext context, LanguageCheckboxSpec spec) {
    captured.add(spec);
    return spec.label == null ? const SizedBox.shrink() : Text(spec.label!, textDirection: TextDirection.ltr);
  }

  @override
  Widget slider(BuildContext context, LanguageSliderSpec spec) {
    captured.add(spec);
    return const SizedBox.shrink();
  }

  @override
  Widget segmented(BuildContext context, LanguageSegmentedSpec spec) {
    captured.add(spec);
    return Row(
      children: [for (final label in spec.labels) Expanded(child: Text(label, textDirection: TextDirection.ltr))],
    );
  }

  @override
  Widget progress(BuildContext context, LanguageProgressSpec spec) {
    captured.add(spec);
    return const SizedBox.shrink();
  }

  @override
  Widget select<T>(BuildContext context, LanguageSelectSpec<T> spec) {
    captured.add(spec);
    return Text(
      spec.value == null ? (spec.placeholder ?? '') : spec.itemLabel(spec.value as T),
      textDirection: TextDirection.ltr,
    );
  }

  @override
  Widget tabBar(BuildContext context, LanguageTabsSpec spec) {
    captured.add(spec);
    return Row(
      children: [for (final tab in spec.tabs) Expanded(child: Text(tab.label, textDirection: TextDirection.ltr))],
    );
  }

  @override
  Widget scaffold(BuildContext context, LanguageScaffoldSpec spec) {
    captured.add(spec);
    return Column(
      children: [
        if (spec.appBar != null) spec.appBar!,
        Expanded(child: spec.body),
        if (spec.bottomBar != null) spec.bottomBar!,
      ],
    );
  }

  @override
  Widget appBar(BuildContext context, LanguageAppBarSpec spec) {
    captured.add(spec);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (spec.leading != null) spec.leading!,
            Flexible(child: Text(spec.title, textDirection: TextDirection.ltr)),
            ...spec.actions,
          ],
        ),
        if (spec.bottom != null) spec.bottom!,
      ],
    );
  }

  @override
  Widget listRow(BuildContext context, LanguageListRowSpec spec) {
    captured.add(spec);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (spec.leading != null) spec.leading!,
        Text(spec.title, textDirection: TextDirection.ltr),
        if (spec.subtitle != null) Text(spec.subtitle!, textDirection: TextDirection.ltr),
        if (spec.trailing != null) spec.trailing!,
      ],
    );
  }

  @override
  Widget navBar(BuildContext context, LanguageNavBarSpec spec) {
    captured.add(spec);
    return Row(
      children: [for (final item in spec.items) Expanded(child: Text(item.label, textDirection: TextDirection.ltr))],
    );
  }

  @override
  Widget toast(BuildContext context, LanguageToastSpec spec) {
    captured.add(spec);
    return Text(spec.message, textDirection: TextDirection.ltr);
  }

  @override
  Widget dialog(BuildContext context, LanguageDialogSpec spec) {
    captured.add(spec);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (spec.title != null) Text(spec.title!, textDirection: TextDirection.ltr),
        if (spec.content != null) spec.content!,
        Wrap(alignment: WrapAlignment.end, children: spec.actions),
      ],
    );
  }

  @override
  Widget tabView(BuildContext context, LanguageTabViewSpec spec) {
    captured.add(spec);
    if (spec.pages.isEmpty) return const SizedBox.shrink();
    return spec.pages[spec.index];
  }

  @override
  Widget appHost(BuildContext context, LanguageHostSpec spec) {
    captured.add(spec);
    return MaterialApp.router(
      routerConfig: spec.routerConfig,
      title: spec.title,
      onGenerateTitle: spec.onGenerateTitle,
      localizationsDelegates: spec.localizationsDelegates,
      supportedLocales: spec.supportedLocales,
      locale: spec.locale,
      builder: spec.builder,
      debugShowCheckedModeBanner: spec.debugShowCheckedModeBanner,
    );
  }

  @override
  Widget shell(BuildContext context, LanguageShellSpec spec) {
    captured.add(spec);
    return Column(
      children: [
        for (final destination in spec.destinations) Text(destination.label, textDirection: TextDirection.ltr),
        Expanded(child: spec.child),
        if (spec.trailing != null) spec.trailing!,
      ],
    );
  }
}

void main() {
  late List<Object?> captured;
  late LanguageRegistry registry;

  setUp(() {
    captured = [];
    final adapter = _RecordingAdapter(captured);
    registry = LanguageRegistry(adapters: {LiveDesignLanguage.fluent: adapter});
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

  group('the capability declaration is what an adapter claims', () {
    testWidgets('a language declares exactly the chrome it renders natively', (tester) async {
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
      expect(
        theme.supports(LiveUiControl.slider),
        isFalse,
        reason: 'a control the adapter does not list is not claimed for it (§17)',
      );
      // The surfaces are a separate declaration: this adapter owns the app host
      // and not the shell, and owning one says nothing about the other.
      expect(theme.supportsSurface(LiveUiSurface.appHost), isTrue);
      expect(theme.supportsSurface(LiveUiSurface.appShell), isFalse);
    });

    testWidgets('every control still reaches the adapter, declared or not', (tester) async {
      // Dispatch no longer reads the declaration — there is nothing to fall
      // through to — so an undeclared control is the adapter's problem to draw,
      // and the declaration is only what it claims about itself.
      await tester.pumpWidget(harness(LiveSlider(value: 0.5, onChanged: (_) {})));

      expect(captured.whereType<LanguageSliderSpec>(), isNotEmpty);
      expect(LiveTheme.of(tester.element(find.byType(LiveSlider))).supports(LiveUiControl.slider), isFalse);
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

    testWidgets('a null callback reaches the adapter as an inert bar', (tester) async {
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
      expect(spec.enabled, isTrue, reason: 'the flag says the bar was built interactive; the callback is the gate');
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
      // overlay entry goes with it — the overlay and the timer are the core's,
      // whichever widget drew the message.
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

  group('the dialog and the tab view', () {
    testWidgets('a dialog forwards its surface and keeps the route in the core', (tester) async {
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

      unawaited(
        showLiveDialog<void>(
          context: inside,
          title: 'Restore',
          child: const Text('This overwrites the library'),
          actions: (_) => const [Text('Cancel'), Text('Restore')],
        ),
      );
      await tester.pumpAndSettle();

      final spec = captured.whereType<LanguageDialogSpec>().single;
      expect(spec.title, 'Restore');
      expect(spec.actions, hasLength(2));
      expect(spec.dismissible, isTrue);
      expect(find.text('This overwrites the library'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a tab view forwards the caller-owned index', (tester) async {
      var index = 0;
      await tester.pumpWidget(
        harness(
          StatefulBuilder(
            builder: (context, setState) => LiveTabView(
              pages: const [Text('first'), Text('second')],
              index: index,
              onIndexChanged: (i) => setState(() => index = i),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final spec = captured.whereType<LanguageTabViewSpec>().last;
      expect(spec.pages, hasLength(2));
      expect(spec.index, 0);
      expect(find.text('first'), findsOneWidget);
      expect(tester.takeException(), isNull);
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
      expect(find.text('page'), findsOneWidget);
    });

    testWidgets('a shell the adapter does not own is still drawn by that adapter', (tester) async {
      // The surfaces declaration no longer routes anything: it states what the
      // adapter claims to do with its own library, and the page still gets the
      // one adapter the language resolved to — so the shell, like every control,
      // arrives as a spec.
      await tester.pumpWidget(
        shellHarness(
          LiveAppShell(
            destinations: destinations,
            selectedId: 'home',
            onSelected: (_) {},
            placement: LiveShellPlacement.bottom,
            child: const Text('page'),
          ),
        ),
      );

      expect(captured.whereType<LanguageShellSpec>(), isNotEmpty);
      expect(captured.whereType<LanguageNavBarSpec>(), isEmpty, reason: 'the shell is one dispatch, not a bar inside');
      expect(find.text('page'), findsOneWidget);
    });

    testWidgets('a shell with no destinations is asked for none', (tester) async {
      await tester.pumpWidget(shellHarness(const LiveAppShell(child: Text('page'))));

      final spec = captured.whereType<LanguageShellSpec>().single;
      expect(spec.destinations, isEmpty);
      expect(spec.selectedId, isNull);
      expect(spec.onSelected, isNull);
      expect(spec.placement, LiveShellPlacement.adaptive);
      expect(find.text('page'), findsOneWidget);
    });

    testWidgets('placement.none is forwarded as asked, not reinterpreted', (tester) async {
      await tester.pumpWidget(
        shellHarness(
          const LiveAppShell(destinations: destinations, placement: LiveShellPlacement.none, child: Text('page')),
        ),
      );

      expect(captured.whereType<LanguageShellSpec>().single.placement, LiveShellPlacement.none);
    });
  });
}
