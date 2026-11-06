import 'package:live_net/testing.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/pandalive/api/pandalive_endpoints.dart';
import 'package:live_sites/src/platforms/pandalive/api/pandalive_http.dart';
import 'package:live_sites/src/platforms/pandalive/pandalive_site.dart';
import 'package:test/test.dart';

const String _id = 'tester_1';

/// The `member/bj` form POST of [_id] (`userId`, `info=media`) and its
/// answers: `S04-member-adult` listed live in an adult broadcast,
/// `S04-member-offline` not listed.
const String _samples = 'test/fixtures/pandalive';

/// The transport under the site: [sample] answers, every request is recorded.
ReplayHttp _replay(String sample) => ReplayHttp.fixtures(_samples, [sample]);

/// The requests [http] saw, as method and path.
List<(String, String)> _sent(ReplayHttp http) => [
  for (final request in http.requests) (request.method, request.url.path),
];

void main() {
  group('the follow refresh', () {
    test('a broadcaster listed live refreshes to its broadcast, with its restriction', () async {
      final http = _replay('S04-member-adult');
      final site = PandaliveSite(http: PandaliveHttp(http));
      final room = await site.refreshRoom(_id);
      expect(room.roomId, _id);
      expect(room.broadcast.liveStatus, LiveStatus.live);
      expect(room.broadcast.restriction, LiveRestriction.adult);
      expect(room.content.notice, PandaliveEndpoints.adultNotice);
      expect(room.audience.onlineViewers, 30);
      expect(_sent(http), [('POST', PandaliveEndpoints.memberPath)], reason: 'the refresh is the member answer alone');
    });

    test('a broadcaster not listed refreshes to the offline profile room', () async {
      final http = _replay('S04-member-offline');
      final site = PandaliveSite(http: PandaliveHttp(http));
      final room = await site.refreshRoom(_id);
      expect(room.roomId, _id);
      expect(room.broadcast.liveStatus, LiveStatus.offline);
      expect(room.broadcast.restriction, isNull);
      expect(room.content.notice, PandaliveEndpoints.chatNotice);
      expect(_sent(http), [('POST', PandaliveEndpoints.memberPath)], reason: 'the refresh is the member answer alone');
    });
  });
}
