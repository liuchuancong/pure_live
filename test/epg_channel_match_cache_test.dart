import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/iptv/services/channel_detail_controller.dart';

void main() {
  test('EPG match cache isolates identical channel names by source', () {
    final cache = EpgChannelMatchCache(maxEntries: 4);
    cache.put('source-a', 'CCTV-1', 'a-1');
    cache.put('source-b', 'CCTV-1', 'b-1');

    expect(cache.get('source-a', 'CCTV-1'), 'a-1');
    expect(cache.get('source-b', 'CCTV-1'), 'b-1');
  });

  test('EPG match cache evicts oldest entries at its bound', () {
    final cache = EpgChannelMatchCache(maxEntries: 2);
    cache.put('source', 'one', '1');
    cache.put('source', 'two', '2');
    cache.put('source', 'three', '3');

    expect(cache.length, 2);
    expect(cache.get('source', 'one'), isNull);
    expect(cache.get('source', 'two'), '2');
    expect(cache.get('source', 'three'), '3');
  });
}
