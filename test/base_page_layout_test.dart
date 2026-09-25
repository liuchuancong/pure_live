import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/base/base_controller.dart';
import 'package:pure_live/common/base/base_page_scroll_bone.dart';
import 'package:pure_live/common/base/base_page_view.dart';
import 'package:pure_live/common/base/desktop_components.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/plugins/locale_helper.dart';
import 'package:pure_live/common/widgets/app_status_view.dart';
import 'package:pure_live/get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Controller extends BasePageScrollAndStateBone<int> {
  _Controller({required this.notice});
  final bool notice;
  int retries = 0;
  int refreshes = 0;
  final jumps = <int>[];
  @override
  String? get pageNotice => notice ? i18n('xiaohongshu_directory_scope') : null;
  @override
  bool get showInlineError => true;
  @override
  Future<void> retryData() async {
    retries++;
  }

  @override
  Future<void> loadData() async {}
  @override
  Future<void> refreshData() async {
    refreshes++;
    easyRefreshController.finishRefresh(IndicatorResult.success);
  }

  @override
  Future<void> goToPage(int page) async {
    jumps.add(page);
  }

  @override
  void setPageSize(int? newSize) {
    if (newSize != null) pageSize.value = newSize;
  }
}

class _Loader extends AssetLoader {
  const _Loader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('$path/${locale.languageCode}.json').readAsStringSync()) as Map<String, dynamic>;
}

Future<_Controller> _mount(
  WidgetTester tester, {
  required String lang,
  required Size size,
  double scale = 2,
  bool headers = true,
  String state = 'content',
  bool refresh = true,
  bool paging = true,
  bool preserveEmpty = false,
  bool wrapRefresh = true,
  bool hasSnapshot = true,
  WidgetBuilder? notLoginBuilder,
  Widget Function(BuildContext, String)? errorBuilder,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  late _Controller c;
  var initialized = false;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    c.onClose();
    Get.reset();
  });
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: [Locale(lang)],
      startLocale: Locale(lang),
      fallbackLocale: Locale(lang),
      saveLocale: false,
      path: 'assets/translations',
      assetLoader: const _Loader(),
      child: Builder(
        builder: (context) => GetMaterialApp(
          locale: context.locale,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                if (!initialized) {
                  initialized = true;
                  Get.put(SettingsService(), permanent: true);
                  c = _Controller(notice: headers);
                  c.canLoadMore.value = true;
                  c.totalCount.value = hasSnapshot ? 100 : null;
                  c.errorMsg.value = List.filled(4, i18n('network_disconnected_msg')).join(' ');
                  if (state == 'content') {
                    c.list.assignAll(List.generate(30, (i) => i));
                    c.pageError.value = headers;
                    c.showCellularBanner.value = headers;
                  } else {
                    c.pageError.value = state == 'error';
                    c.pageEmpty.value = state == 'empty';
                    c.notLogin.value = state == 'login';
                  }
                }
                return BasePageView<_Controller, int>(
                  controller: c,
                  enableRefresh: refresh,
                  enableLoadMore: paging,
                  preserveContentWhenEmpty: preserveEmpty,
                  wrapMobileRefresh: wrapRefresh,
                  notLoginBuilder: notLoginBuilder,
                  errorBuilder: errorBuilder,
                  showScrollToTopBtn: false,
                  showPageSizeSelector: true,
                  pageSizeOptions: const [20, 40, 80],
                  contentBuilder: (context, rows, scrollController) => ListView.builder(
                    key: const ValueKey('retained-list'),
                    controller: scrollController,
                    itemExtent: 48,
                    itemCount: rows.length,
                    itemBuilder: (_, i) => Text('ROW ${rows[i]}'),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return c;
}

Future<void> _reveal(WidgetTester tester, Finder viewport, Finder target, {bool horizontal = false}) async {
  for (var i = 0; i < 80 && target.hitTestable().evaluate().isEmpty; i++) {
    await tester.drag(viewport, horizontal ? const Offset(-120, 0) : const Offset(0, -90));
    await tester.pumpAndSettle();
  }
  expect(target.hitTestable(), findsOneWidget);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    await Hive.openBox<dynamic>('app_settings', bytes: Uint8List(0));
    await HivePrefUtil.init();
  });
  setUp(() async {
    Get.testMode = true;
    Get.reset();
    await HivePrefUtil.clear();
    final old = BaseController.neverShowCellularBanner;
    BaseController.neverShowCellularBanner = false;
    addTearDown(() => BaseController.neverShowCellularBanner = old);
  });
  tearDownAll(Hive.close);
  for (final lang in ['zh', 'en']) {
    for (final size in [const Size(320, 640), const Size(640, 240), const Size(900, 320)]) {
      testWidgets('$lang $size stacked notices preserve list and reachable retry', (tester) async {
        final c = await _mount(tester, lang: lang, size: size);
        expect(tester.takeException(), null);
        final list = find.byKey(const ValueKey('retained-list'));
        expect(tester.getSize(list).height, greaterThan(0));
        final position = c.scrollController.position;
        c.scrollController.jumpTo(300);
        await tester.pumpAndSettle();
        final header = find.byKey(const ValueKey('base-page-notices'));
        final retry = find.descendant(of: find.byType(MaterialBanner), matching: find.text(c.retryActionLabel));
        await _reveal(tester, header, retry);
        await tester.tap(retry);
        await tester.pumpAndSettle();
        expect(c.retries, 1);
        expect(c.scrollController.offset, 300);
        expect(identical(c.scrollController.position, position), true);
        c.showCellularBanner.value = false;
        c.pageError.value = false;
        await tester.pumpAndSettle();
        expect(identical(c.scrollController.position, position), true);
        expect(c.scrollController.offset, 300);
        expect(c.scrollController.positions, hasLength(1));
        expect(tester.takeException(), null);
      });
    }
    for (final refresh in [false, true]) {
      for (final size in [const Size(320, 240), const Size(900, 200)]) {
        testWidgets('$lang $size refresh=$refresh full-page error scrolls to retry', (tester) async {
          final c = await _mount(tester, lang: lang, size: size, headers: false, state: 'error', refresh: refresh);
          expect(tester.takeException(), null);
          final button = find.descendant(of: find.byType(AppStatusView), matching: find.text(c.retryActionLabel));
          await _reveal(tester, find.byKey(const ValueKey('base-page-status')), button);
          await tester.tap(button);
          expect(c.retries, 1);
          expect(tester.takeException(), null);
        });
      }
    }
    testWidgets('$lang desktop pagination controls fit and stay operable at 700 px', (tester) async {
      final c = await _mount(tester, lang: lang, size: const Size(700, 320), headers: false);
      expect(tester.takeException(), null);
      final next = find.descendant(of: find.byType(DesktopPaginationBar), matching: find.text(i18n('next_page')));
      await _reveal(tester, find.byKey(const ValueKey('desktop-pagination-scroll')), next, horizontal: true);
      await tester.tap(next);
      expect(c.jumps, [2]);
      final viewport = find.byKey(const ValueKey('desktop-pagination-scroll'));
      final selector = find.byType(PopupMenuButton<int>);
      await _reveal(tester, viewport, selector, horizontal: true);
      await tester.tap(selector);
      await tester.pumpAndSettle();
      await tester.tap(find.byWidgetPredicate((w) => w is PopupMenuItem<int> && w.value == 40));
      await tester.pumpAndSettle();
      expect(c.pageSize.value, 40);
      final field = find.descendant(of: find.byType(DesktopPaginationBar), matching: find.byType(TextField));
      await _reveal(tester, viewport, field, horizontal: true);
      await tester.enterText(field, '999');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(c.jumps, [2, 3]); // 100 items at the selected page size of 40.
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
      expect(tester.takeException(), null);
    });
    testWidgets('$lang cellular dismissal remains reachable without refreshing or resetting list', (tester) async {
      final c = await _mount(tester, lang: lang, size: const Size(320, 320));
      final list = find.byKey(const ValueKey('retained-list'));
      final header = find.byKey(const ValueKey('base-page-notices'));
      expect(tester.getSize(header).height, lessThanOrEqualTo(160));
      expect(tester.getSize(list).height, greaterThanOrEqualTo(160));
      final position = c.scrollController.position;
      c.scrollController.jumpTo(400);
      await tester.pumpAndSettle();
      final dismiss = find.text(i18n('never_show'));
      await _reveal(tester, header, dismiss);
      await tester.tap(dismiss);
      await tester.pumpAndSettle();
      expect(BaseController.neverShowCellularBanner, true);
      expect(c.showCellularBanner.value, false);
      expect(c.refreshes, 0);
      expect(c.scrollController.offset, 400);
      expect(identical(c.scrollController.position, position), true);
      expect(tester.takeException(), null);
    });
    for (final state in ['empty', 'login']) {
      testWidgets('$lang $state remains scrollable with long notice and 3x text', (tester) async {
        await _mount(tester, lang: lang, size: const Size(320, 320), scale: 3, state: state);
        expect(tester.takeException(), null);
        final status = find.byType(AppStatusView);
        final title = tester.widget<AppStatusView>(status).title!;
        await _reveal(tester, find.byKey(const ValueKey('base-page-status')), find.text(title));
        expect(tester.takeException(), null);
      });
    }
  }
  testWidgets('no notices take no space and an empty preserved child retains its position', (tester) async {
    final c = await _mount(tester, lang: 'en', size: const Size(640, 320), headers: false, preserveEmpty: true);
    final header = find.byKey(const ValueKey('base-page-notices'));
    expect(tester.getSize(header).height, 0);
    final position = c.scrollController.position;
    c.list.clear();
    c.pageEmpty.value = true;
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('retained-list')), findsOneWidget);
    expect(identical(c.scrollController.position, position), true);
    c.list.assignAll([101, 102]);
    c.pageEmpty.value = false;
    await tester.pumpAndSettle();
    expect(find.text('ROW 101'), findsOneWidget);
    expect(identical(c.scrollController.position, position), true);
    expect(tester.takeException(), null);
  });
  testWidgets('mobile empty status retains refresh ownership and accepts a pull gesture', (tester) async {
    final c = await _mount(tester, lang: 'en', size: const Size(320, 480), headers: false, state: 'empty', scale: 1);
    final refresh = tester.widget<EasyRefresh>(find.byType(EasyRefresh));
    expect(identical(refresh.controller, c.easyRefreshController), true);
    expect(refresh.childBuilder, isNotNull);
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('base-page-status'))));
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(0, 70));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(c.refreshes, 1);
    await tester.pump(refresh.header!.processedDuration);
    await tester.pumpAndSettle();
    expect(tester.takeException(), null);
  });
  testWidgets('desktop empty first page hides paging and jump buttons until content arrives', (tester) async {
    final c = await _mount(tester, lang: 'en', size: const Size(900, 480), headers: false, state: 'empty');
    expect(c.list, isEmpty);
    expect(find.byType(DesktopPaginationBar), findsNothing);
    expect(c.showBackToBottom.value, isFalse);
    expect(c.showBackToTop.value, isFalse);
    c.list.assignAll(List.generate(60, (i) => i));
    c.pageEmpty.value = false;
    await tester.pumpAndSettle();
    expect(find.byType(DesktopPaginationBar), findsOneWidget);
    expect(tester.takeException(), null);
  });
  testWidgets('desktop paging opt-out leaves the whole content region available', (tester) async {
    await _mount(tester, lang: 'en', size: const Size(900, 320), headers: false, paging: false);
    expect(find.byType(DesktopPaginationBar), findsNothing);
    expect(tester.getSize(find.byKey(const ValueKey('retained-list'))).height, 320);
    expect(tester.takeException(), null);
  });

  for (final lang in ['zh', 'en']) {
    for (final width in [320.0, 900.0]) {
      for (final failure in ['error', 'login']) {
        testWidgets('$lang $width retained empty page exposes $failure without replacing content', (tester) async {
          final c = await _mount(
            tester,
            lang: lang,
            size: Size(width, 320),
            headers: false,
            state: 'empty',
            preserveEmpty: true,
          );
          final position = c.scrollController.position;
          c.pageError.value = failure == 'error';
          c.notLogin.value = failure == 'login';
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey('retained-list')), findsOneWidget);
          expect(identical(c.scrollController.position, position), true);
          final notices = find.byKey(const ValueKey('base-page-notices'));
          expect(tester.getSize(notices).height, lessThanOrEqualTo(160));
          final label = failure == 'error' ? c.retryActionLabel : i18n('go_to_login');
          await _reveal(tester, notices, find.text(label));
          if (failure == 'error') {
            await tester.tap(find.text(label));
            expect(c.retries, 1);
          }
          c.pageError.value = false;
          c.notLogin.value = false;
          await tester.pumpAndSettle();
          expect(tester.getSize(notices).height, 0);
          expect(identical(c.scrollController.position, position), true);
          expect(c.scrollController.positions, hasLength(1));
          expect(tester.takeException(), null);
        });
      }
    }
  }
  for (final failure in ['error', 'login']) {
    testWidgets('$failure without a successful snapshot keeps the full-page status', (tester) async {
      await _mount(
        tester,
        lang: 'en',
        size: const Size(320, 320),
        headers: false,
        state: failure,
        preserveEmpty: true,
        hasSnapshot: false,
      );
      expect(find.byKey(const ValueKey('retained-list')), findsNothing);
      expect(find.byKey(const ValueKey('base-page-status')), findsOneWidget);
      expect(tester.takeException(), null);
    });
    testWidgets('retained $failure honors the caller status builder and action', (tester) async {
      var actions = 0;
      String? receivedError;
      Widget custom(BuildContext _) => TextButton(onPressed: () => actions++, child: const Text('CUSTOM ACTION'));
      final c = await _mount(
        tester,
        lang: 'en',
        size: const Size(320, 320),
        headers: false,
        state: failure,
        preserveEmpty: true,
        wrapRefresh: false,
        notLoginBuilder: custom,
        errorBuilder: (context, message) {
          receivedError = message;
          return custom(context);
        },
      );
      expect(find.byKey(const ValueKey('retained-list')), findsOneWidget);
      expect(find.byType(EasyRefresh), findsNothing, reason: 'the nested caller retains refresh ownership');
      if (failure == 'error') expect(receivedError, c.errorMsg.value);
      await tester.tap(find.text('CUSTOM ACTION'));
      expect(actions, 1);
      expect(c.scrollController.positions, hasLength(1));
      expect(tester.takeException(), null);
    });
  }
}
