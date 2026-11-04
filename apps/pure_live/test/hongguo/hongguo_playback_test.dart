// The ten-second regression, pinned: `/video/public/<vid>/360p.mp4` — the file
// the website hands its SEO page — is a teaser (measured: 1,680,490 bytes,
// mvhd duration 10.000 s) while the episode is 143.686 s. An anonymous session
// is refused by the app's player model, so the ladder must take the website's
// own fallback play info (a signed full-length URL) instead of that teaser.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:live_net/live_net.dart' show LiveHttp, LiveRequest, LiveResponse, LiveStreamedResponse;
import 'package:pure_live/modules/hongguo/official/hongguo_official.dart' show HongguoOfficialClient;

/// A transport that answers by route: the register call is refused (the
/// anonymous session this test stands for has no device), the player model
/// answers an empty envelope, and the web fallback names the full file.
final class _RouteStub implements LiveHttp {
  _RouteStub(this.fullUrl);

  final String fullUrl;
  final List<Uri> seen = [];

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    seen.add(request.url);
    final path = request.url.path;
    final body = switch (true) {
      _ when path.contains('device_register') => '{}',
      _ when path.contains('multi_video_model') => '{"Code":0,"data":{}}',
      _ when path.contains('fallback-play-info') => jsonEncode({
        'main_url': fullUrl,
        'url_expire': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
      }),
      _ => '{}',
    };
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

void main() {
  test('a refused model falls to the web play info, never the ten-second teaser', () async {
    const fullUrl = 'https://v3-hgweb.qznovelvod.com/full/episode.mp4';
    final stub = _RouteStub(fullUrl);
    final client = HongguoOfficialClient(http: stub);

    final ladder = await client.playbackLadder('7698309376561400856');

    expect(ladder, hasLength(1));
    expect(ladder.single.url, fullUrl);
    // Unknown height: the chosen file keeps its place whatever cap is set.
    expect(ladder.single.quality, 0);
    expect(stub.seen.map((uri) => uri.path).join('\n'), isNot(contains('video/public')));
    expect(stub.seen.map((uri) => uri.path).join('\n'), contains('fallback-play-info'));
  });
}
