import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/utils/network_image_url.dart';

void main() {
  group('network image URL normalization', () {
    test('adds HTTPS to protocol-relative platform images', () {
      expect(
        normalizeNetworkImageUrl('//i0.hdslb.com/bfs/live/example.jpg'),
        'https://i0.hdslb.com/bfs/live/example.jpg',
      );
    });

    test('preserves absolute image URLs', () {
      expect(normalizeNetworkImageUrl('http://example.com/live.png'), 'http://example.com/live.png');
      expect(normalizeNetworkImageUrl('https://example.com/live.png'), 'https://example.com/live.png');
    });

    test('rejects blank and malformed values', () {
      expect(normalizeNetworkImageUrl(' null '), isEmpty);
      expect(normalizeNetworkImageUrl('"'), isEmpty);
      expect(normalizeNetworkImageUrl('https://'), isEmpty);
      expect(normalizeNetworkImageUrl('not an image url'), isEmpty);
    });
  });
}
