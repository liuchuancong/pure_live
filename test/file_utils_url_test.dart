import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/plugins/file_utils.dart';

void main() {
  group('structured HTTP URL parsing', () {
    test('accepts exact public, long-TLD, loopback and IPv6 URLs', () {
      final cases = <String>[
        'https://example.com/list.m3u?token=a%2Fb#channel',
        'https://example.technology/guide.xml',
        'http://localhost:8080/list.m3u',
        'http://127.0.0.1:8080/list.m3u',
        'http://[::1]:8080/list.m3u',
        ' HTTPS://Example.COM/live/list.m3u8 ',
      ];

      for (final value in cases) {
        expect(FileUtils.parseHttpUrl(value), isNotNull, reason: value);
        expect(FileUtils.isValidUrl(value), isTrue, reason: value);
        expect(FileUtils.isHostUrl(value), isTrue, reason: value);
      }
    });

    test('rejects embedded, schemeless, unsupported and malformed targets', () {
      final cases = <String>[
        'prefix https://example.com/list.m3u',
        'https://example.com/list.m3u suffix',
        'www.example.com/list.m3u',
        'ftp://example.com/list.m3u',
        'file:///tmp/list.m3u',
        'javascript:alert(1)',
        'https://',
        'https://example.com:70000/list.m3u',
        'https://example.com/list.m3u\nnext',
        r'C:\fixtures\https://example.com\list.m3u',
      ];

      for (final value in cases) {
        expect(FileUtils.parseHttpUrl(value), isNull, reason: value);
        expect(FileUtils.isValidUrl(value), isFalse, reason: value);
        expect(FileUtils.isHostUrl(value), isFalse, reason: value);
      }
    });

    test('returns a trimmed URI with normalized HTTP scheme and exact components', () {
      final uri = FileUtils.parseHttpUrl('  HTTPS://Example.COM:8443/a%20b?q=x%2Fy#z  ');

      expect(uri, isNotNull);
      expect(uri!.scheme, 'https');
      expect(uri.host, 'example.com');
      expect(uri.port, 8443);
      expect(uri.path, '/a%20b');
      expect(uri.query, 'q=x%2Fy');
      expect(uri.fragment, 'z');
    });
  });
}
