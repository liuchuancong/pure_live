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

  group('network image headers', () {
    test('adds browser headers only for Bilibili CDN hosts', () {
      final headers = networkImageHeaders('https://i0.hdslb.com/bfs/live/example.jpg');
      expect(headers?['Referer'], 'https://live.bilibili.com/');
      expect(headers?['User-Agent'], contains('Mozilla/5.0'));
      expect(networkImageHeaders('https://example.com/live.png'), isNull);
    });
  });
}
