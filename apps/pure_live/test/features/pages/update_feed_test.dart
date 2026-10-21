// The release feed's addresses: which doors it knocks on, in which order, and
// what shape those addresses have. Both were wrong at least once — a mirror
// asked for a path it only serves for raw files, and the "GitHub" door was
// spelled github.com/repos/…, which is a 404 page and not the release JSON.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:live_net/live_net.dart';
import 'package:pure_live/features/about/update_feed.dart';

/// A transport that records every address and answers with one release list —
/// or with [status], so a test can walk the whole ordered list of doors.
final class _FeedHttp implements LiveHttp {
  new({this.status = 200});

  final int status;
  final List<Uri> asked = [];

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    asked.add(request.url);
    return LiveResponse(
      statusCode: status,
      headers: const {},
      bodyBytes: Uint8List.fromList(utf8.encode(jsonEncode(_releases))),
    );
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) async => throw UnimplementedError();

  @override
  void close() {}
}

const List<Object?> _releases = [
  {
    'tag_name': 'v9.9.9',
    'name': 'Test release',
    'body': 'notes',
    'prerelease': false,
    'draft': false,
    'published_at': '2026-10-21T00:00:00Z',
    'assets': [
      {
        'name': 'pure_live-windows.zip',
        'browser_download_url': 'https://github.com/x/y/releases/download/v9.9.9/pure_live-windows.zip',
        'size': 1,
      },
    ],
  },
];

void main() {
  group('UpdateFeed.fetch', () {
    test('githubOnly asks the api host and nothing else', () async {
      final http = _FeedHttp();
      final releases = await UpdateFeed(http: http).fetch(limit: 3);
      expect(releases.single.tag, 'v9.9.9');
      expect(http.asked, hasLength(1));
      expect(http.asked.single.host, 'api.github.com');
      expect(http.asked.single.path, '/repos/$updateOwner/$updateRepo/releases');
      expect(http.asked.single.queryParameters['per_page'], '3');
    });

    test('with mirrors on, every address is the api releases document, prefixed or not', () async {
      // Nothing answers, so the whole ordered list of doors gets knocked on.
      final http = _FeedHttp(status: 500);
      await expectLater(UpdateFeed(http: http, githubOnly: false).fetch(), throwsA(isA<FeedUnavailable>()));
      expect(http.asked.length, greaterThan(1));
      // github.com is the repository's own site: it has no /repos/… path, so
      // asking it for the release JSON is a request for a 404 page.
      expect(http.asked.where((uri) => uri.host == 'github.com'), isEmpty);
      for (final uri in http.asked) {
        expect('$uri', contains('api.github.com/repos/$updateOwner/$updateRepo/releases'));
      }
      // The mirrors go first and the origin itself is the last door.
      expect(http.asked.last.host, 'api.github.com');
      expect('$http.asked.first', isNot('$http.asked.last'));
    });
  });
}
