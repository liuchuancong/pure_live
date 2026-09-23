import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/search/web_search_controller.dart';
import 'package:pure_live/modules/search/web_search_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, dynamic> english;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    english = jsonDecode(await File('assets/translations/en.json').readAsString()) as Map<String, dynamic>;
  });

  setUp(() {
    Get.testMode = true;
    Get.reset();
  });

  tearDown(() {
    Get.reset();
    Get.testMode = false;
  });

  test('launch arguments accept one normalized HTTP(S) target', () {
    final request = parseWebSearchLaunchRequest({
      'url': '  https://example.com/search?q=live  ',
      'platform': ' BILIBILI ',
    });

    expect(request?.uri.toString(), 'https://example.com/search?q=live');
    expect(request?.platform, 'bilibili');
  });

  test('launch arguments reject malformed, credentialed, and non-web targets', () {
    for (final arguments in <Object?>[
      null,
      const <String, Object?>{},
      {'url': 7, 'platform': 'bilibili'},
      {'url': 'javascript:alert("http")', 'platform': 'bilibili'},
      {'url': 'https:///missing-host', 'platform': 'bilibili'},
      {'url': 'https://user:secret@example.com', 'platform': 'bilibili'},
      {'url': 'https://example.com', 'platform': '   '},
    ]) {
      expect(parseWebSearchLaunchRequest(arguments), isNull, reason: '$arguments');
    }
  });

  test('invalid launch state is terminal without constructing a browser', () {
    final controller = Get.put(
      WebSearchController(initialArguments: const {'url': 'file:///tmp/search', 'platform': 'bilibili'}),
    );

    expect(controller.hasValidLaunchRequest, isFalse);
    expect(controller.showWebView.value, isFalse);
    expect(controller.viewStatus.value, WebSearchViewStatus.failed);
    expect(controller.errorMessageKey.value, 'web_search_invalid_address');
  });

  test('external-browser attempts coalesce and report a rejected launch once', () async {
    final launchResult = Completer<bool>();
    final notices = <String>[];
    var launchCalls = 0;
    final controller = Get.put(
      WebSearchController(
        initialArguments: _validArguments,
        useExternalBrowser: true,
        launchExternal: (uri) {
          launchCalls++;
          return launchResult.future;
        },
        notice: notices.add,
      ),
    );

    final first = controller.openExternalBrowser();
    final second = controller.openExternalBrowser();
    expect(first, same(second));
    expect(controller.isOpeningExternal.value, isTrue);
    expect(launchCalls, 1);

    launchResult.complete(false);
    await Future.wait([first, second]);
    expect(controller.isOpeningExternal.value, isFalse);
    expect(notices, ['external_browser_not_opened']);
  });

  test('external-browser exceptions become the same visible failure', () async {
    final notices = <String>[];
    final controller = Get.put(
      WebSearchController(
        initialArguments: _validArguments,
        useExternalBrowser: true,
        launchExternal: (_) => Future<bool>.error(StateError('fixture launch failure')),
        notice: notices.add,
      ),
    );

    await controller.openExternalBrowser();
    expect(notices, ['external_browser_not_opened']);
  });

  test('back first consumes browser history and only then closes the page', () async {
    final browser = _FixtureBrowser(canGoBackResult: true);
    final controller = Get.put(WebSearchController(initialArguments: _validArguments, useExternalBrowser: false));
    await controller.attachBrowser(browser);

    expect(await controller.requestBack(), WebSearchBackDisposition.stayOnPage);
    expect(browser.goBackCalls, 1);
    expect(browser.disposeCalls, 0);

    browser.canGoBackResult = false;
    expect(await controller.requestBack(), WebSearchBackDisposition.closePage);
    expect(browser.stopCalls, 1);
    expect(browser.disposeCalls, 1);
    expect(controller.showWebView.value, isFalse);
  });

  test('rapid close requests release the browser exactly once', () async {
    final stopResult = Completer<void>();
    final browser = _FixtureBrowser(stopResult: stopResult);
    final controller = Get.put(WebSearchController(initialArguments: _validArguments, useExternalBrowser: false));
    await controller.attachBrowser(browser);

    final first = controller.closeWebSearch();
    final second = controller.closeWebSearch();
    expect(first, same(second));
    expect(browser.stopCalls, 1);
    stopResult.complete();
    await Future.wait([first, second]);
    expect(browser.disposeCalls, 1);
  });

  test('recreated webview releases its predecessor before loading the replacement', () async {
    final first = _FixtureBrowser();
    final second = _FixtureBrowser();
    final controller = Get.put(WebSearchController(initialArguments: _validArguments, useExternalBrowser: false));

    await controller.attachBrowser(first);
    await controller.attachBrowser(second);

    expect(first.stopCalls, 1);
    expect(first.disposeCalls, 1);
    expect(second.loadedUris, [Uri.parse(_validUrl)]);
  });

  test('a newer detected room waits behind one dialog and opens the latest target', () async {
    final confirmations = <Completer<bool?>>[Completer<bool?>(), Completer<bool?>()];
    final promptedTargets = <String>[];
    final openedRooms = <LiveRoom>[];
    final controller = Get.put(
      WebSearchController(
        initialArguments: _validArguments,
        useExternalBrowser: false,
        confirmRoom: (target) {
          promptedTargets.add(target.key);
          return confirmations[promptedTargets.length - 1].future;
        },
        openRoom: (room) async => openedRooms.add(room),
      ),
    );

    final first = controller.observeUrl('https://live.bilibili.com/100');
    final second = controller.observeUrl('https://www.huya.com/second_room');
    expect(first, same(second));
    expect(promptedTargets, ['bilibili:100']);

    confirmations[0].complete(false);
    await _flushAsync();
    expect(promptedTargets, ['bilibili:100', 'huya:second_room']);
    confirmations[1].complete(true);
    await Future.wait([first, second]);

    expect(openedRooms, hasLength(1));
    expect(openedRooms.single.platform, 'huya');
    expect(openedRooms.single.roomId, 'second_room');
  });

  test('leaving a detected room before confirmation drops the stale room', () async {
    final confirmation = Completer<bool?>();
    final openedRooms = <LiveRoom>[];
    final controller = Get.put(
      WebSearchController(
        initialArguments: _validArguments,
        useExternalBrowser: false,
        confirmRoom: (_) => confirmation.future,
        openRoom: (room) async => openedRooms.add(room),
      ),
    );

    final detection = controller.observeUrl('https://live.bilibili.com/100');
    await controller.observeUrl('https://www.bilibili.com/search?keyword=live');
    confirmation.complete(true);
    await detection;

    expect(openedRooms, isEmpty);
    expect(controller.showWebView.value, isTrue);
  });

  test('confirming an older room after a newer navigation opens only the newer room', () async {
    final confirmations = <Completer<bool?>>[Completer<bool?>(), Completer<bool?>()];
    final promptedTargets = <String>[];
    final openedRooms = <LiveRoom>[];
    final controller = Get.put(
      WebSearchController(
        initialArguments: _validArguments,
        useExternalBrowser: false,
        confirmRoom: (target) {
          promptedTargets.add(target.key);
          return confirmations[promptedTargets.length - 1].future;
        },
        openRoom: (room) async => openedRooms.add(room),
      ),
    );

    final first = controller.observeUrl('https://live.bilibili.com/100');
    final second = controller.observeUrl('https://www.huya.com/second_room');
    confirmations[0].complete(true);
    await _flushAsync();
    expect(promptedTargets, ['bilibili:100', 'huya:second_room']);
    expect(openedRooms, isEmpty);

    confirmations[1].complete(true);
    await Future.wait([first, second]);
    expect(openedRooms.map((room) => '${room.platform}:${room.roomId}'), ['huya:second_room']);
  });

  test('closing while a room dialog is pending drops its late confirmation', () async {
    final confirmation = Completer<bool?>();
    final openedRooms = <LiveRoom>[];
    final controller = Get.put(
      WebSearchController(
        initialArguments: _validArguments,
        useExternalBrowser: false,
        confirmRoom: (_) => confirmation.future,
        openRoom: (room) async => openedRooms.add(room),
      ),
    );

    final detection = controller.observeUrl('https://live.bilibili.com/100');
    await controller.closeWebSearch();
    confirmation.complete(true);
    await detection;

    expect(openedRooms, isEmpty);
  });

  test('initial load and retry expose deterministic failure state', () async {
    final browser = _FixtureBrowser(loadError: StateError('fixture load failure'));
    final controller = Get.put(WebSearchController(initialArguments: _validArguments, useExternalBrowser: false));

    await controller.attachBrowser(browser);
    expect(controller.viewStatus.value, WebSearchViewStatus.failed);
    expect(controller.errorMessageKey.value, 'web_search_load_failed');

    browser.loadError = null;
    browser.reloadError = StateError('fixture reload failure');
    await controller.retry();
    expect(browser.reloadCalls, 1);
    expect(controller.viewStatus.value, WebSearchViewStatus.failed);
  });

  testWidgets('external-browser fallback stays scrollable at narrow 3x English text', (tester) async {
    final controller = Get.put(
      WebSearchController(
        initialArguments: _validArguments,
        useExternalBrowser: true,
        launchExternal: (_) async => true,
      ),
    );
    await _pumpLocalized(tester, english, const WebSearchPage(showDeveloperTools: false));

    final button = find.byKey(const ValueKey('web-search-open-external'));
    await tester.scrollUntilVisible(button, 120, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(button.hitTestable(), findsOneWidget);
    expect(tester.getRect(button).right, lessThanOrEqualTo(320));
    expect(find.byIcon(Icons.bug_report), findsNothing);
    expect(controller.isOpeningExternal.value, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid launch renders a localized reachable terminal state', (tester) async {
    Get.put(WebSearchController(initialArguments: const {'url': 'about:blank', 'platform': 'bilibili'}));
    await _pumpLocalized(tester, english, const WebSearchPage(showDeveloperTools: false));

    expect(find.byKey(const ValueKey('web-search-failure')), findsOneWidget);
    expect(find.text(english['web_search_invalid_address'] as String), findsOneWidget);
    final close = find.text(english['close'] as String);
    await tester.scrollUntilVisible(close, 120, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(close.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

const _validUrl = 'https://example.com/search?q=live';
const _validArguments = {'url': _validUrl, 'platform': 'bilibili'};

class _FixtureBrowser implements WebSearchBrowser {
  _FixtureBrowser({this.canGoBackResult = false, this.stopResult, this.loadError});

  bool canGoBackResult;
  final Completer<void>? stopResult;
  Object? loadError;
  Object? reloadError;
  final loadedUris = <Uri>[];
  int reloadCalls = 0;
  int goBackCalls = 0;
  int stopCalls = 0;
  int disposeCalls = 0;
  int devToolsCalls = 0;

  @override
  Future<void> load(Uri uri) async {
    loadedUris.add(uri);
    final error = loadError;
    if (error != null) throw error;
  }

  @override
  Future<void> reload() async {
    reloadCalls++;
    final error = reloadError;
    if (error != null) throw error;
  }

  @override
  Future<bool> canGoBack() async => canGoBackResult;

  @override
  Future<void> goBack() async {
    goBackCalls++;
  }

  @override
  Future<void> stopLoading() {
    stopCalls++;
    return stopResult?.future ?? Future.value();
  }

  @override
  Future<void> openDevTools() async {
    devToolsCalls++;
  }

  @override
  void dispose() {
    disposeCalls++;
  }
}

Future<void> _pumpLocalized(WidgetTester tester, Map<String, dynamic> labels, Widget home) async {
  tester.view.physicalSize = const Size(320, 480);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('en')],
      startLocale: const Locale('en'),
      saveLocale: false,
      path: 'assets/translations',
      assetLoader: _Labels(labels),
      child: Builder(
        builder: (context) => GetMaterialApp(
          locale: context.locale,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(3)),
            child: child!,
          ),
          home: home,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _Labels extends AssetLoader {
  const _Labels(this.labels);

  final Map<String, dynamic> labels;

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => labels;
}

Future<void> _flushAsync() async {
  for (var index = 0; index < 6; index++) {
    await Future<void>.delayed(Duration.zero);
  }
}
