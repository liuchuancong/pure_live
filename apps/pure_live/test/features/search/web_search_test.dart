import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:live_net/live_net.dart' show DioFactory;
import 'package:live_sites/live_sites.dart';

import 'package:pure_live/app/composition/sites.dart' show AppSites;
import 'package:pure_live/app/delegates.dart' show appLocalizationsDelegates, appSupportedLocales;
import 'package:pure_live/app/providers/app_providers.dart' show sitesProvider;
import 'package:pure_live/app/routing/app_router.dart';
import 'package:pure_live/features/search/web_search_url.dart';
import 'package:pure_live/features/search/web_search_view.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/in_app_web.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The page host: translations, the design language and a one-route router.
Future<void> pumpWithRoute(WidgetTester tester, Widget page) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(900, 2000);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sitesProvider.overrideWithValue(
          AppSites(factory: DioFactory(), http: DioFactory().create(), registry: LiveSiteRegistry(const [])),
        ),
      ],
      child: PureConfigProvider(
        config: const UiConfig(language: PureDesignLanguage.material),
        child: PureApp(
          routerConfig: GoRouter(
            routes: [GoRoute(path: '/', builder: (context, state) => page)],
          ),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: appSupportedLocales,
          locale: const Locale('zh'),
          builder: (context, appChild) => TranslationProvider(child: appChild!),
        ),
      ),
    ),
  );
  await tester.pump();
}

WebSearchRequest? query(Map<String, String?> values) => WebSearchRequest.fromQuery(values);

void main() {
  group('WebSearchRequest', () {
    test('a plain http(s) address with a platform parses', () {
      final request = query({
        'url': 'https://www.douyu.com/search?kw=%E6%90%9C',
        'platform': 'DouYu',
        'keyword': '  搜索  ',
      });
      expect(request, isNotNull);
      expect(request!.platform, 'douyu');
      expect(request.keyword, '搜索');
      expect(request.uri.host, 'www.douyu.com');
    });

    test('anything else answers null', () {
      expect(query({'url': 'file:///c:/x.html', 'platform': 'douyu'}), isNull);
      expect(query({'url': 'https://user@pw@x.com/', 'platform': 'douyu'}), isNull);
      expect(query({'url': 'https://x.com/', 'platform': '  '}), isNull);
      expect(query({'url': 'javascript:alert(1)', 'platform': 'douyu'}), isNull);
      expect(query(<String, String?>{}), isNull);
    });
  });

  group('webSearchUrl', () {
    test('the known platforms get their live-search page', () {
      expect(webSearchUrl('douyu', '张三')?.toString(), 'https://www.douyu.com/search?kw=%E5%BC%A0%E4%B8%89');
      expect(webSearchUrl('bilibili', 'x')?.path, '/live');
      expect(webSearchUrl('twitch', 'x')?.host, 'www.twitch.tv');
    });

    test('an unknown platform or blank words answer null', () {
      expect(webSearchUrl('iptv', 'x'), isNull);
      expect(webSearchUrl('douyu', '   '), isNull);
    });
  });

  group('WebSearchView states', () {
    testWidgets('bad arguments show the invalid state', (tester) async {
      await pumpWithRoute(tester, const WebSearchView(request: null, inApp: false));
      expect(find.byKey(const ValueKey('web-search-invalid')), findsOne);
    });

    testWidgets('without a WebView the search goes to the system browser at once', (tester) async {
      final opened = <Uri>[];
      final request = query({'url': 'https://www.douyu.com/search?kw=abc', 'platform': 'douyu', 'keyword': 'abc'})!;
      await pumpWithRoute(
        tester,
        WebSearchView(
          request: request,
          inApp: false,
          openExternal: (uri) async {
            opened.add(uri);
            return true;
          },
        ),
      );
      await tester.pump();
      expect(opened, hasLength(1));
      expect(find.byKey(const ValueKey('web-search-system-browser')), findsOne);
      expect(find.text('www.douyu.com'), findsOne);
      // Without a WebView there is no in-app page, hence no swap button in
      // the bar either.
      expect(find.byKey(const ValueKey('web-search-external')), findsNothing);
    });

    testWidgets('the external button answers the failure toast when nothing opens', (tester) async {
      final request = query({'url': 'https://x.com/s', 'platform': 'douyu'})!;
      await pumpWithRoute(tester, WebSearchView(request: request, inApp: false, openExternal: (uri) async => false));
      await tester.pump();
      // The auto-open on entry already failed once (its toast); the button
      // adds a second failure the user can see.
      expect(find.text(t.search.externalBrowserNotOpened), findsOne);
      await tester.tap(find.byKey(const ValueKey('web-search-open-external')));
      await tester.pump();
      expect(find.text(t.search.externalBrowserNotOpened), findsNWidgets(2));
    });
  });

  group('room bar', () {
    testWidgets('it names the room and offers 进入 / ✕', (tester) async {
      var entered = 0;
      var dismissed = 0;
      final bar = WebSearchRoomBar(
        platform: '斗鱼',
        roomId: '123',
        onEnter: () => entered++,
        onDismiss: () => dismissed++,
      );
      await pumpWithRoute(
        tester,
        Scaffold(
          body: LayoutBuilder(
            builder: (context, constraints) => Stack(children: [WebSearchRoomBar.place(width: 500, bar: bar)]),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('web-search-room-bar')), findsOne);
      expect(find.text('这是一个直播间'), findsOne);
      await tester.tap(find.byKey(const ValueKey('web-search-room-enter')));
      await tester.tap(find.byKey(const ValueKey('web-search-room-dismiss')));
      expect(entered, 1);
      expect(dismissed, 1);
    });
  });

  test('isWebPage refuses everything but http(s)', () {
    expect(isWebPage(Uri.parse('https://x.com')), isTrue);
    expect(isWebPage(Uri.parse('http://x.com')), isTrue);
    expect(isWebPage(Uri.parse('file:///x')), isFalse);
    expect(isWebPage(Uri.parse('javascript:alert(1)')), isFalse);
    expect(isWebPage(null), isFalse);
  });

  test('the route round-trips through the search address table', () {
    final uri = webSearchUrl('huya', 'abc')!;
    final route = WebSearchRoute(url: uri.toString(), platform: 'huya', keyword: 'abc');
    final parsed = query({'url': route.url, 'platform': route.platform, 'keyword': route.keyword});
    expect(parsed?.uri, uri);
  });
}
