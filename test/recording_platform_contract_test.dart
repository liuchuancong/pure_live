import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/core/sites.dart';

void main() {
  test('every built-in platform exposes strict playback-complete recording metadata', () {
    expect(Sites.supportedSiteIds, hasLength(10));
    for (final siteId in Sites.supportedSiteIds) {
      expect(Sites.of(siteId).liveSite, isA<LiveSiteRecordRoomResolver>(), reason: siteId);
    }
  });
}
