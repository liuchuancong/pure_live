import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/modules/search/search_controller.dart' as search;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });
  Future<void> pumpLocalized(
    WidgetTester tester, {
    required String locale,
    Size size = const Size(320, 480),
    double textScale = 3,
  }) async {
    await tester.pumpWidget(const SizedBox.shrink());
    Get.reset();
    Get.testMode = true;
    await tester.binding.setSurfaceSize(size);
    final navigatorKey = GlobalKey<NavigatorState>();
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: [Locale(locale)],
        startLocale: Locale(locale),
        fallbackLocale: Locale(locale),
        saveLocale: false,
        path: 'assets/translations',
        assetLoader: const _Loader(),
        child: Builder(
          builder: (context) => GetMaterialApp(
            navigatorKey: navigatorKey,
            locale: context.locale,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
            home: const Scaffold(body: SizedBox.expand()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final locale in ['zh', 'en']) {
    testWidgets('WebView2 missing dialog stays actionable at narrow three-times $locale text', (tester) async {
      await pumpLocalized(tester, locale: locale);
      final controller = search.SearchController(searchSites: const []);
      addTearDown(controller.onClose);

      controller.showWebView2MissingDialog();
      await tester.pumpAndSettle();

      final actionLabel = locale == 'zh' ? '打开下载页' : 'Open download page';
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, actionLabel).hitTestable(), findsOneWidget);
      expect(find.widgetWithText(TextButton, locale == 'zh' ? '取消' : 'Cancel').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.widgetWithText(TextButton, locale == 'zh' ? '取消' : 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });
  }

  testWidgets('WebView2 missing dialog is single-flight and reopens after dismissal', (tester) async {
    await pumpLocalized(tester, locale: 'en', size: const Size(800, 600), textScale: 1);
    final controller = search.SearchController(searchSites: const []);
    addTearDown(controller.onClose);

    controller.showWebView2MissingDialog();
    controller.showWebView2MissingDialog();
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);

    controller.showWebView2MissingDialog();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('closed search controller drops a pending download action', (tester) async {
    await pumpLocalized(tester, locale: 'en', size: const Size(800, 600), textScale: 1);
    final controller = search.SearchController(searchSites: const []);

    controller.showWebView2MissingDialog();
    await tester.pumpAndSettle();
    controller.onClose();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Open download page'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _Loader extends AssetLoader {
  const _Loader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('$path/${locale.languageCode}.json').readAsStringSync()) as Map<String, dynamic>;
}
