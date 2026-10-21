import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pure_live/app/app_delegates.dart' show appLocalizationsDelegates, appSupportedLocales;
import 'package:pure_live/features/room/paging.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/system/configuration/app_preferences.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The shared paging system (the reference's `shared/rooms/paging.dart`):
/// the size rules are plain arithmetic the pages read, and the bar and the
/// jump buttons must render and respond under every design language the app
/// dispatches to — the same contract the page sweeps hold for whole pages.
void main() {
  group('pageSizesOf', () {
    final auto = AppPreferences();

    test('the wide window answer is 20 of 20/40/60/80', () {
      final of = pageSizesOf(auto, 1200);
      expect(of.size, 20);
      expect(of.options, [20, 40, 60, 80]);
    });

    test('the narrower desktop window answers 12 of 12/24/36/48', () {
      final of = pageSizesOf(auto, 800);
      expect(of.size, 12);
      expect(of.options, [12, 24, 36, 48]);
    });

    test('a stored default sizes the bar when it is a choice', () {
      final of = pageSizesOf(auto.copyWith(pageDefaultSize: 40), 1200);
      expect(of.size, 40);
      expect(of.options, [20, 40, 60, 80]);
    });

    test('a stored default outside the choices falls back to the first', () {
      final of = pageSizesOf(auto.copyWith(pageDefaultSize: 30), 1200);
      expect(of.size, 20);
      expect(of.options, [20, 40, 60, 80]);
    });

    test('the stored option text overrides the width rule', () {
      // The reference's exact answer: the override replaces the choices and
      // the width default joins them as the size.
      final of = pageSizesOf(auto.copyWith(pageSizeOptions: '50,10,50'), 1200);
      expect(of.size, 20);
      expect(of.options, [10, 20, 50]);
    });

    test('the paging line is wider than 680 and never a phone', () {
      expect(phonePageSize, 20);
      expect(usesDesktopPages(681, isPhone: false), isTrue);
      expect(usesDesktopPages(680, isPhone: false), isFalse);
      expect(usesDesktopPages(1200, isPhone: true), isFalse);
    });

    test('option parsing keeps 1..100 only, unique and ascending', () {
      expect(parsePageSizeOptions('7,101,0,7,abc,42'), [7, 42]);
    });
  });

  group('the controls', () {
    for (final language in PureDesignLanguage.values) {
      testWidgets('the pager renders and answers taps under ${language.name}', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(1440, 900);
        addTearDown(tester.view.reset);
        int? jumped;
        var refreshed = 0;
        await _pump(
          tester,
          language: language,
          child: PureScaffold(
            body: Column(
              children: [
                const Expanded(child: SizedBox.shrink()),
                PurePaginationBar(
                  page: 4,
                  lastPage: 9,
                  canNext: true,
                  busy: false,
                  pageSize: 20,
                  pageSizes: const [20, 40, 60, 80],
                  showGoto: true,
                  onPage: (page) => jumped = page,
                  onPageSize: (_) {},
                  onRefresh: () => refreshed++,
                ),
              ],
            ),
          ),
        );
        expect(tester.takeException(), isNull, reason: language.name);
        expect(find.byKey(const ValueKey('pager')), findsOneWidget, reason: language.name);
        // 1, the sliding window around 4 and the last page — the reference's
        // number rule with the dots between.
        for (final page in [1, 3, 4, 5, 9]) {
          expect(find.byKey(ValueKey('pager-page-$page')), findsOneWidget, reason: '${language.name} / $page');
        }
        expect(find.byKey(const ValueKey('pager-page-2')), findsNothing, reason: language.name);
        await tester.tap(find.byKey(const ValueKey('pager-page-5')));
        await tester.pump();
        expect(jumped, 5, reason: language.name);
        await tester.tap(find.byKey(const ValueKey('pager-goto')));
        await tester.enterText(find.byKey(const ValueKey('pager-goto')), '7');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
        expect(jumped, 7, reason: language.name);
      });

      testWidgets('the jump buttons show once the list scrolls under ${language.name}', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(900, 700);
        addTearDown(tester.view.reset);
        final controller = ScrollController();
        addTearDown(controller.dispose);
        await _pump(
          tester,
          language: language,
          child: PureScaffold(
            body: Stack(
              children: [
                Positioned.fill(
                  child: ListView.builder(
                    controller: controller,
                    itemCount: 200,
                    itemBuilder: (context, index) => SizedBox(height: 40, child: Text('$index')),
                  ),
                ),
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: PureJumpButtons(controller: controller, heroTag: 'x'),
                ),
              ],
            ),
          ),
        );
        expect(tester.takeException(), isNull, reason: language.name);
        // Past the threshold both buttons answer; "to top" walks the list back.
        await tester.drag(find.byType(ListView), const Offset(0, -600));
        // The buttons scale in; the tap needs them at full size.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        expect(tester.takeException(), isNull, reason: language.name);
        await tester.tap(find.byKey(const ValueKey('jump-x-top')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
        expect(controller.offset, lessThan(50), reason: language.name);
      });
    }
  });
}

/// Pumps [child] as the host's only route under [language] — the shape the
/// pages read: a [PureScaffold] under the language's real app widget with
/// the translations above it.
Future<void> _pump(WidgetTester tester, {required PureDesignLanguage language, required Widget child}) async {
  await tester.pumpWidget(
    PureConfigProvider(
      config: UiConfig(language: language),
      child: PureApp(
        routerConfig: GoRouter(
          routes: [GoRoute(path: '/', builder: (context, state) => child)],
        ),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        builder: (context, appChild) => TranslationProvider(child: appChild!),
      ),
    ),
  );
  await tester.pump();
}
