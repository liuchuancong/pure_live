import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/release/release_asset_urls.dart';

void main() {
  Map<String, dynamic> asset(String name) {
    return {'name': name, 'browser_download_url': 'https://github.com/example/pure_live/releases/download/v1/$name'};
  }

  List<Map<String, dynamic>> fullReleaseAssets() {
    return [
      asset('PureLive-3.1.18-android-arm64-v8a-release.apk'),
      asset('PureLive-3.1.18-windows-x64-setup.exe'),
      asset('PureLive-3.1.18-windows-x64-portable.zip'),
      asset('PureLive-3.1.18-macos-universal.zip'),
      asset('PureLive-3.1.18-linux-x64.tar.gz'),
      asset('PureLive-3.1.18-linux-x64.zip'),
      asset('PureLive-3.1.18-linux-x64.deb'),
    ];
  }

  group('ReleaseAssetUrls Linux packages', () {
    test('resolves every Linux package format for x64', () {
      final urls = ReleaseAssetUrls(assets: fullReleaseAssets());

      expect(urls.linuxX64, contains('linux-x64.tar.gz'));
      expect(urls.linuxX64Zip, contains('linux-x64.zip'));
      expect(urls.linuxX64Deb, contains('linux-x64.deb'));

      final all = urls.all;
      expect(all['linux-x64.tar.gz'], contains('linux-x64.tar.gz'));
      expect(all['linux-x64.zip'], contains('linux-x64.zip'));
      expect(all['linux-x64.deb'], contains('linux-x64.deb'));
    });

    test('does not match arm64 Linux assets as x64', () {
      final urls = ReleaseAssetUrls(
        assets: [asset('PureLive-3.1.18-linux-arm64.deb'), asset('PureLive-3.1.18-linux-arm64.zip')],
      );

      expect(urls.linuxX64Deb, isNull);
      expect(urls.linuxX64Zip, isNull);
      expect(urls.linuxX64, isNull);
    });

    test('does not pick Windows portable ZIP as a Linux package', () {
      final urls = ReleaseAssetUrls(assets: [asset('PureLive-3.1.18-windows-x64-portable.zip')]);

      expect(urls.linuxX64Zip, isNull);
    });

    test('stays null when a format is missing from the release', () {
      final urls = ReleaseAssetUrls(assets: [asset('PureLive-3.1.18-linux-x64.tar.gz')]);

      expect(urls.linuxX64Deb, isNull);
      expect(urls.linuxX64Zip, isNull);
    });

    test('rejects non-https asset URLs', () {
      final urls = ReleaseAssetUrls(
        assets: <Map<String, dynamic>>[
          {'name': 'PureLive-3.1.18-linux-x64.deb', 'browser_download_url': 'http://example.com/a.deb'},
        ],
      );

      expect(urls.linuxX64Deb, isNull);
    });
  });
}
