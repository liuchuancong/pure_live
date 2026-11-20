import 'dart:convert' show utf8;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_net/live_net.dart' show LiveResponse;
import 'package:live_storage/live_storage.dart';
import 'package:live_vod/live_vod.dart' show HuyaMaterialApi, HuyaMaterialChannel;
import 'package:pure_live/modules/huya/controller/huya_material.dart';

import 'stub_http.dart' show StubHttp;

/// The material library's controller, argued over a stub transport: the
/// stands and the landing page load together, a stand, a search and the
/// way back each own the stage in turn, a stale answer lands nowhere, and
/// a failed shelf answers the retry ask.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StorageStores stores;

  setUp(() async {
    stores = await StorageStores.openInMemory();
    await StoragePrefs.init();
  });

  tearDown(() => stores.close());

  test('the stands and the landing page load, and a re-entry asks nothing', () async {
    final http = StubHttp()
      ..route(r'material$', _page(_card('11'), _card('12')))
      ..route('channel/list', _standsPage());
    final container = ProviderContainer(
      overrides: [huyaMaterialApiProvider.overrideWith((ref) => HuyaMaterialApi(http))],
    );
    addTearDown(container.dispose);
    container.listen(huyaMaterialProvider, (_, _) {});
    final controller = container.read(huyaMaterialProvider.notifier);

    await controller.open();
    final loaded = container.read(huyaMaterialProvider);
    expect(loaded.channels.map((channel) => channel.id), ['vhuyalol', 'vhuyawzry']);
    expect(loaded.videos.map((video) => video.id), ['11', '12']);
    expect(loaded.loading, isFalse);
    expect(loaded.error, isNull);

    final card = loaded.videos.first; // the card is the row shape the page renders
    expect(card.title, '第一集 & 花絮'); // the page's entities decoded
    expect(card.duration, const Duration(minutes: 1, seconds: 23));
    expect(card.uploaderId, '777');
    expect(card.uploaderName, '主播甲');
    expect(card.channelId, 'vhuyalol');

    await controller.open();
    expect(http.calls, hasLength(2)); // the shelves stand: nothing asked again
  });

  test('a stand, a search and the way back each own the stage', () async {
    final http = StubHttp()
      ..route(r'material$', _page(_card('1')))
      ..route('channel/list', _standsPage())
      ..route('channel/index/vhuyawzry', _page(_card('22')))
      ..route('material/search', _page(_card('33')));
    final container = ProviderContainer(
      overrides: [huyaMaterialApiProvider.overrideWith((ref) => HuyaMaterialApi(http))],
    );
    addTearDown(container.dispose);
    container.listen(huyaMaterialProvider, (_, _) {});
    final controller = container.read(huyaMaterialProvider.notifier);

    final stands = await _openForStands(container, controller);

    await controller.select(stands[1]);
    var state = container.read(huyaMaterialProvider);
    expect(state.channelId, 'vhuyawzry');
    expect(state.word, isEmpty); // any search left behind
    expect(state.videos.single.id, '22');

    await controller.search('新皮肤');
    state = container.read(huyaMaterialProvider);
    expect(state.word, '新皮肤');
    expect(state.channelId, 'vhuyawzry'); // the stand stays chosen
    expect(state.videos.single.id, '33');

    await controller.backToHot();
    state = container.read(huyaMaterialProvider);
    expect(state.channelId, isEmpty);
    expect(state.word, isEmpty);
    expect(state.videos.single.id, '1'); // the landing page again
  });

  test('a stale answer lands nowhere', () async {
    final http = StubHttp()
      ..route(r'material$', _page(_card('1')))
      ..route('channel/list', _standsPage())
      ..route('channel/index/vhuyalol', _page(_card('10')))
      ..route('channel/index/vhuyawzry', _page(_card('22')));
    final first = http.hold('channel/index/vhuyalol');
    final container = ProviderContainer(
      overrides: [huyaMaterialApiProvider.overrideWith((ref) => HuyaMaterialApi(http))],
    );
    addTearDown(container.dispose);
    container.listen(huyaMaterialProvider, (_, _) {});
    final controller = container.read(huyaMaterialProvider.notifier);

    final stands = await _openForStands(container, controller);
    final leaving = controller.select(stands[0]); // its page is held mid-flight
    await pumpEventQueue();
    await controller.select(stands[1]); // the viewer moved on
    await pumpEventQueue();
    expect(container.read(huyaMaterialProvider).videos.single.id, '22');

    first.complete(); // the stale page answers at last
    await leaving;
    await pumpEventQueue();
    final state = container.read(huyaMaterialProvider);
    expect(state.videos.single.id, '22'); // it landed nowhere
    expect(state.loading, isFalse);
  });

  test('a failed shelf shows its words and answers the retry ask', () async {
    var refuse = true;
    final http = StubHttp()
      ..route(r'material$', _page(_card('1')))
      ..route('channel/list', _standsPage())
      ..route('channel/index/vhuyalol', (url) async {
        if (refuse) return _fail();
        return await _pageSingle(_card('12'))(url);
      });
    final container = ProviderContainer(
      overrides: [huyaMaterialApiProvider.overrideWith((ref) => HuyaMaterialApi(http))],
    );
    addTearDown(container.dispose);
    container.listen(huyaMaterialProvider, (_, _) {});
    final controller = container.read(huyaMaterialProvider.notifier);

    final stands = await _openForStands(container, controller);
    await controller.select(stands[0]);
    var state = container.read(huyaMaterialProvider);
    expect(state.error, isNotNull);
    expect(state.videos, isEmpty);
    expect(state.loading, isFalse);

    refuse = false;
    await controller.retry();
    state = container.read(huyaMaterialProvider);
    expect(state.error, isNull);
    expect(state.videos.single.id, '12');
    expect(http.calls.where((uri) => uri.path.contains('channel/index/vhuyalol')), hasLength(2));
  });
}

LiveResponse _ok(String body) => LiveResponse(statusCode: 200, headers: const {}, bodyBytes: utf8.encode(body));

LiveResponse _fail() => LiveResponse(statusCode: 500, headers: const {}, bodyBytes: utf8.encode('no'));

/// One card as the library renders it: a play link, a lazy cover, a
/// length, a name and the uploader.
String _card(String vid, {String title = '第一集 &amp; 花絮', String length = '01:23'}) =>
    '<li class="video-card-wrap"> '
    '<a href="https://www.huya.com/material/play/$vid"></a> '
    '<img data-original="https://cover.example/$vid.jpg"> '
    '<span class="tag bottom-right">$length</span> '
    '<h3>$title</h3> '
    '<a href="https://www.huya.com/material/profile/index/777" class="name"> '
    '<i class="v"></i>主播甲</a> '
    '<a href="https://www.huya.com/material/channel/index/vhuyalol?type=vhuyalol"></a> '
    '</li>';

/// A page answering [card] and [second] — the same card twice when
/// [second] is left out, so the repeated vid argues the reader's dedupe.
Future<LiveResponse> Function(Uri) _page(String card, [String? second]) =>
    (url) => Future<LiveResponse>.value(_ok('<html> $card ${second ?? card} </html>'));

Future<LiveResponse> Function(Uri) _pageSingle(String card) =>
    (url) => Future<LiveResponse>.value(_ok('<html> $card </html>'));

/// The stands' page: two title-and-link pairs, as the strip reads them.
Future<LiveResponse> Function(Uri) _standsPage() =>
    (url) => Future<LiveResponse>.value(
      _ok(
        '<html> '
        '<a title="英雄联盟" href="https://www.huya.com/material/channel/index/vhuyalol"></a> '
        '<a title="王者荣耀" href="https://www.huya.com/material/channel/index/vhuyawzry"></a> '
        '</html>',
      ),
    );

/// The controller's opening walk, settled so the strip's stands answer.
Future<List<HuyaMaterialChannel>> _openForStands(ProviderContainer container, HuyaMaterialController controller) async {
  await controller.open();
  return container.read(huyaMaterialProvider).channels;
}
