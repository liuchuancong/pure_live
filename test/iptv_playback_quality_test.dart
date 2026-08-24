import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/site/iptv/iptv_site.dart';

void main() {
  test('IPTV exposes one stable default quality only for a non-empty source', () async {
    final site = IptvSite();
    final qualities = await site.getPlayQualites(detail: LiveRoom(data: '  udp://239.0.0.1:1234  '));

    expect(qualities, hasLength(1));
    expect(qualities.single.selectionId, 'default');
    expect(await site.getPlayUrls(detail: LiveRoom(), quality: qualities.single), ['udp://239.0.0.1:1234']);
    expect(await site.getPlayQualites(detail: LiveRoom(data: '   ')), isEmpty);
  });
}
