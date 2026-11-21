import 'dart:convert' show jsonEncode, utf8;
import 'dart:typed_data' show Uint8List;

import 'package:desen_ui/desen_ui.dart' show DsSpinner;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_net/live_net.dart' show LiveHttp, LiveRequest, LiveResponse, LiveStreamedResponse;
import 'package:media_core/media_core.dart' show MediaPlayerView;
import 'package:pure_live/modules/hongguo/controller/hongguo_client.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_models.dart' show HongguoSeries;
import 'package:pure_live/modules/hongguo/official/hongguo_official.dart' show HongguoOfficialClient, HongguoRendition;
import 'package:pure_live/modules/hongguo/widgets/hongguo_series_preview.dart';

/// The hover preview: the tier it picks is the ladder's lowest, with h264
/// taking a tie, a ladder with nothing on it picks nothing, and a glance the
/// station cannot answer leaves the cover alone — no spinner left behind,
/// nothing played. The flight to the player's kernel is not in these tests:
/// the pick itself is what this widget decides.
void main() {
  group('the pick', () {
    test('the lowest tier wins', () {
      final ladder = [
        const HongguoRendition(quality: 1080, codec: 'h264', url: 'a'),
        const HongguoRendition(quality: 720, codec: 'h264', url: 'b'),
        const HongguoRendition(quality: 480, codec: 'h264', url: 'c'),
      ];
      expect(hongguoPreviewRendition(ladder)?.url, 'c'); // the glance, not the viewing
      // the ladder itself is left as it arrived
      expect(ladder.map((r) => r.url).toList(), ['a', 'b', 'c']);
    });

    test('a tie takes the tier every engine decodes', () {
      final ladder = [
        const HongguoRendition(quality: 480, codec: 'h265', url: 'hevc'),
        const HongguoRendition(quality: 480, codec: 'h264', url: 'avc'),
      ];
      expect(hongguoPreviewRendition(ladder)?.url, 'avc');

      final labelCase = [
        const HongguoRendition(quality: 480, codec: 'H264', url: 'upper'),
        const HongguoRendition(quality: 480, codec: 'h265', url: 'hevc'),
      ];
      expect(hongguoPreviewRendition(labelCase)?.url, 'upper'); // the label's case is its own
    });

    test('an empty ladder picks nothing', () {
      expect(hongguoPreviewRendition(const []), isNull);
    });
  });

  group('the glance on stage', () {
    Future<void> showPreview(WidgetTester tester, {required String Function(LiveRequest) detailAnswer}) async {
      final stub = _RouteStub()..routeFor('/detail', detailAnswer);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [hongguoClientProvider.overrideWithValue(HongguoOfficialClient(http: stub))],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 200,
                height: 300,
                child: HongguoSeriesPreview(
                  series: HongguoSeries(seriesId: '7100001', title: '剧'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('a series with no episodes leaves the cover alone', (tester) async {
      await showPreview(tester, detailAnswer: (request) => _detailPage(const []));

      expect(find.byType(DsSpinner), findsNothing); // nothing still asking
      expect(find.byType(MediaPlayerView), findsNothing); // and nothing played
    });

    testWidgets('a detail page that never answers leaves the cover alone', (tester) async {
      await showPreview(tester, detailAnswer: (request) => '<html>broken</html>');

      expect(find.byType(DsSpinner), findsNothing); // nothing still asking
      expect(find.byType(MediaPlayerView), findsNothing); // and nothing played
    });
  });
}

String _detailPage(List<String> vids) =>
    '<html><script>window._ROUTER_DATA = ${jsonEncode({
      'loaderData': {
        'detail_page': {
          'seriesDetail': {'series_name': '剧', 'vid_list': vids},
        },
      },
    })};</script></html>';

/// A transport answering by route fragment.
final class _RouteStub implements LiveHttp {
  final Map<String, String Function(LiveRequest)> _routes = {};

  void routeFor(String fragment, String Function(LiveRequest) answer) => _routes[fragment] = answer;

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    final entry = _routes.entries.firstWhere(
      (entry) => request.url.toString().contains(entry.key),
      orElse: () => throw StateError('no answer for ${request.url.path}'),
    );
    return LiveResponse(
      statusCode: 200,
      headers: const {'content-type': 'text/html'},
      bodyBytes: Uint8List.fromList(utf8.encode(entry.value(request))),
    );
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) => throw UnsupportedError('the client buffers');

  @override
  void close() {}
}
