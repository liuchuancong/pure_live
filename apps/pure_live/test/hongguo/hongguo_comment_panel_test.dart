import 'dart:async' show Completer;
import 'dart:convert' show jsonEncode, utf8;
import 'dart:io' show Directory;
import 'dart:typed_data' show Uint8List;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_cache/live_cache.dart' show LiveCacheManager;
import 'package:live_net/live_net.dart'
    show ClientProfile, DioFactory, LiveHttp, LiveRequest, LiveResponse, LiveStreamedResponse;
import 'package:live_platform/live_platform.dart' show DesktopDistribution, FormFactor, PlatformBootstrap;
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/app/providers/boot/environment_providers.dart' show platformRuntimeProvider;
import 'package:pure_live/l10n/translations.g.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_social.dart';
import 'package:pure_live/modules/hongguo/official/hongguo_comments.dart' show HongguoCommentClient;
import 'package:pure_live/modules/hongguo/official/hongguo_public_reviews.dart' show HongguoPublicReviewsClient;
import 'package:pure_live/modules/hongguo/widgets/hongguo_comment_panel.dart';
import 'package:pure_live/shared/images/app_image_cache.dart' show installLiveCacheManager;

/// The comment panel on stage: the episode tab's rows with their likes, the
/// empty word where nothing came, the error line and its retry, the next
/// page only through its footer button, the reviews tab's score hint, and
/// the swap rule the controller promises — the old pair's rows leave the
/// stage the moment another episode is asked for.
void main() {
  setUpAll(() {
    final root = Directory.systemTemp.createTempSync('hongguo-panel-test');
    addTearDown(() => root.deleteSync(recursive: true));
    installLiveCacheManager(
      LiveCacheManager(
        directory: root,
        http: DioFactory().create(profile: ClientProfile.media),
      ),
    );
  });

  late StorageStores stores;

  setUp(() async {
    stores = await StorageStores.openInMemory();
    await StoragePrefs.init();
  });

  tearDown(() => stores.close());

  Map<String, Object?> commentRow(String id, String text, {int likes = 3, String group = '7100002'}) => {
    'comment_id': id,
    'stat': {'digg_count': likes},
    'comment': {
      'common': {
        'group_id': group,
        'status': 1,
        'content': {'text': text},
        'user_info': {
          'base_info': {'user_name': '甲', 'user_avatar': 'https://p3.example/a.jpg'},
        },
        'create_timestamp': 1700000000,
      },
      'expand': <String, Object?>{},
    },
  };

  String commentPage(List<Map<String, Object?>> rows, {required bool hasMore, String cursor = 'c2'}) => jsonEncode({
    'code': 0,
    'data': {
      'common_list_info': {'has_more': hasMore, 'cursor': cursor, 'total': rows.length},
      'data_list': rows,
    },
  });

  String reviewsHtml(Map<String, Object?> node) =>
      '<html><script>window._ROUTER_DATA = ${jsonEncode({
        'loaderData': {'loader': node},
      })};</script></html>';

  String playerHtml(String vid, List<Map<String, Object?>> reviews) => reviewsHtml({
    'seriesDetail': {'series_id': '7100001'},
    'vid': vid,
    'episodeSocialInfo': {
      'reviews': {'reviews': reviews, 'total_count': 7},
    },
  });

  String detailHtml(List<Map<String, Object?>> reviews) => reviewsHtml({
    'seriesDetail': {'series_id': '7100001'},
    'seriesSocialInfo': {
      'reviews': {'reviews': reviews, 'total_count': 88},
      'rating': 8.7,
      'rating_count': 120,
    },
  });

  Map<String, Object?> reviewRow(String text) => {
    'content': text,
    'user_name': '乙',
    'user_avatar': 'https://cdn.example/a.jpg',
    'create_time': 1700000000,
    'digg_count': 4,
    'rating': 9.0,
  };

  Future<void> showPanel(WidgetTester tester, {required _RouteStub stub, String episodeVid = '7100002'}) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final runtime = PlatformBootstrap.init(
      appNamespace: 'pure_live',
      declaredDistribution: DesktopDistribution.unknown,
      formFactor: FormFactor.desktop,
      debug: true,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          platformRuntimeProvider.overrideWithValue(runtime),
          hongguoCommentClientProvider.overrideWith((ref) => HongguoCommentClient(http: stub)),
          hongguoPublicReviewsClientProvider.overrideWith((ref) => HongguoPublicReviewsClient(http: stub)),
        ],
        child: TranslationProvider(
          child: DsScope(
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: HongguoCommentPanel(seriesId: '7100001', episodeVid: episodeVid),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Translations tOf(WidgetTester tester) => tester.element(find.byType(HongguoCommentPanel)).t;

  testWidgets('the episode tab lands its rows and its footer', (tester) async {
    final stub = _RouteStub()
      ..routeFor(
        'comment/list/7100002',
        (request) => commentPage([commentRow('c1', '前排', likes: 12), commentRow('c2', '赞一个', likes: 1)], hasMore: true),
      );
    await showPanel(tester, stub: stub);

    expect(find.text('前排'), findsOneWidget);
    expect(find.text('12'), findsOneWidget); // the likes ride the row
    expect(find.text(t.hongguo.loadMore), findsOneWidget); // the footer is the pagination
    expect(find.byType(DsSpinner), findsNothing); // nothing still loading
    expect(find.textContaining('8.7'), findsNothing); // the reviews tab is not on stage
  });

  testWidgets('an empty list says so', (tester) async {
    final stub = _RouteStub()..routeFor('comment/list/7100002', (request) => commentPage(const [], hasMore: false));
    await showPanel(tester, stub: stub);
    final t = tOf(tester);

    expect(find.text(t.hongguo.commentsEmpty), findsOneWidget);
    expect(find.text(t.hongguo.loadMore), findsNothing);
  });

  testWidgets('a blank episode asks nothing and says nothing', (tester) async {
    final stub = _RouteStub();
    await showPanel(tester, stub: stub, episodeVid: '');
    final t = tOf(tester);

    expect(stub.seen, isEmpty); // no episode, no ask
    expect(find.text(t.hongguo.commentsEmpty), findsNothing);
    expect(find.text(t.hongguo.loadMore), findsNothing);
  });

  testWidgets('a failure shows its line and the retry reads again', (tester) async {
    var attempt = 0;
    final stub = _RouteStub()
      ..routeFor('comment/list/7100002', (request) {
        attempt += 1;
        if (attempt == 1) return '{"code":500,"message":"挂了"}';
        return commentPage([commentRow('c9', '恢复')], hasMore: false);
      });
    await showPanel(tester, stub: stub);
    await tester.pump();
    final t = tOf(tester);

    expect(find.text('评论接口未返回成功数据'), findsOneWidget); // the failure's own words
    expect(find.text(t.common.retry), findsOneWidget);

    await tester.tap(find.text(t.common.retry));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('恢复'), findsOneWidget); // the retry landed
    expect(find.text(t.common.retry), findsNothing);
  });

  testWidgets('the swap leaves the old rows behind while the new pair loads', (tester) async {
    final gate = Completer<String>();
    final stub = _RouteStub()
      ..routeFor('comment/list/7100002', (request) => commentPage([commentRow('c1', '旧集的行')], hasMore: false))
      ..routeFor('comment/list/7100009', (request) => 'unreached')
      ..hold('comment/list/7100009', gate);
    // One container across both mounts: the swap is the host's own widget
    // update, the controller keeps its held pair — a fresh scope would be a
    // fresh controller, not the swap this pins.
    final runtime = PlatformBootstrap.init(
      appNamespace: 'pure_live',
      declaredDistribution: DesktopDistribution.unknown,
      formFactor: FormFactor.desktop,
      debug: true,
    );
    final container = ProviderContainer(
      overrides: [
        platformRuntimeProvider.overrideWithValue(runtime),
        hongguoCommentClientProvider.overrideWith((ref) => HongguoCommentClient(http: stub)),
        hongguoPublicReviewsClientProvider.overrideWith((ref) => HongguoPublicReviewsClient(http: stub)),
      ],
    );
    addTearDown(container.dispose);
    Future<void> mount(String episodeVid) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TranslationProvider(
            child: DsScope(
              child: MaterialApp(
                home: Scaffold(
                  body: SingleChildScrollView(
                    child: HongguoCommentPanel(seriesId: '7100001', episodeVid: episodeVid),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    await mount('7100002');
    expect(find.text('旧集的行'), findsOneWidget);

    await mount('7100009'); // the host moves to another episode; the ask stalls on the gate
    expect(find.text('旧集的行'), findsNothing); // the old pair left the stage
    expect(find.byType(DsSpinner), findsOneWidget); // the new pair's ask is showing

    gate.complete(commentPage([commentRow('c9', '新集的行', group: '7100009')], hasMore: false));
    await tester.idle(); // the stalled answer's chain runs out
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200)); // the spinner's own clock
    expect(find.text('新集的行'), findsOneWidget);
  });

  testWidgets("the reviews tab carries the score and the series' words", (tester) async {
    final stub = _RouteStub()
      ..routeFor('comment/list/7100002', (request) => commentPage(const [], hasMore: false))
      ..routeFor('/player/7100001/7100002', (request) => playerHtml('7100002', [reviewRow('本集剧评')]))
      ..routeFor('/detail', (request) => detailHtml([reviewRow('全剧的评语')]));
    await showPanel(tester, stub: stub);
    final t = tOf(tester);

    await tester.tap(find.text(t.hongguo.reviewsSeries));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('本集剧评'), findsNothing); // the episode's list is off stage
    expect(find.text('全剧的评语'), findsOneWidget); // the series' own list
    expect(find.textContaining('8.7'), findsOneWidget); // the score rides the heading
    expect(find.text('7'), findsNothing); // the platform's own count stays off the heading
  });
}

/// A transport answering by route fragment, each route free to read the ask.
final class _RouteStub implements LiveHttp {
  final Map<String, String Function(LiveRequest)> _routes = {};
  final List<LiveRequest> seen = [];
  final Map<String, Completer<String>> _gates = {};

  void routeFor(String fragment, String Function(LiveRequest) answer) => _routes[fragment] = answer;

  void hold(String fragment, Completer<String> gate) => _gates[fragment] = gate;

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    seen.add(request);
    final entry = _routes.entries.firstWhere(
      (entry) => request.url.path.contains(entry.key),
      orElse: () => throw StateError('no answer for ${request.url.path}'),
    );
    final gate = _gates[entry.key];
    final body = gate == null ? entry.value(request) : await gate.future;
    return LiveResponse(
      statusCode: 200,
      headers: const {'content-type': 'application/json'},
      bodyBytes: Uint8List.fromList(utf8.encode(body)),
    );
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) => throw UnsupportedError('the client buffers');

  @override
  void close() {}
}
