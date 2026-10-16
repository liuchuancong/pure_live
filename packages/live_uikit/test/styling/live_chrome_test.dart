import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/styling.dart';

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
}
