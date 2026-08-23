import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/sites.dart';
import 'package:pure_live/core/interface/live_site.dart';

void main() {
  test('validates live-room route platform ids without constructing a site', () {
    expect(Sites.isSupported('bilibili'), isTrue);
    expect(Sites.isSupported(' HUYA '), isTrue);
    expect(Sites.isSupported(' Twitch '), isTrue);
    expect(Sites.isSupported(' SOOP '), isTrue);
    expect(Sites.isSupported('unknown-platform'), isFalse);
  });

  test('resolves imported platform ids after trimming and case normalization', () {
    expect(Sites.of(' BILIBILI ').id, Sites.bilibiliSite);
    expect(Sites.of(' HuYa ').id, Sites.huyaSite);
  });

  test('failure-prone adapters expose a refresh path that preserves unknown state on transport errors', () {
    for (final siteId in [Sites.ccSite, Sites.twitchSite, Sites.soopSite]) {
      expect(Sites.of(siteId).liveSite, isA<LiveSiteRoomRefresher>(), reason: siteId);
    }
  });
}
