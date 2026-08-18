import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/utils/version_util.dart';
import 'package:pure_live/modules/version/version_controller.dart';

void main() {
  test('release URLs match locally produced artifact names', () {
    const urls = ReleaseAssetUrls(
      projectUrl: 'https://github.com/liuchuancong/pure_live',
      version: '2.1.4',
      buildNumber: 52,
    );

    expect(urls.androidArm64, endsWith('/PureLive-2.1.4-52-arm64-v8a-release.apk'));
    expect(urls.windowsSetup, endsWith('/PureLive-2.1.4-windows-x64-setup.exe'));
    expect(urls.windowsPortable, endsWith('/PureLive-2.1.4-52-windows-x64-portable.zip'));
    expect(urls.macosUniversal, endsWith('/PureLive-2.1.4-52-macos-universal.zip'));
  });

  test('platform update feed does not announce an unpublished artifact to other platforms', () {
    final feed = <String, dynamic>{
      'version': '2.1.1',
      'build_number': 49,
      'platforms': {
        'windows': {'version': '2.1.2', 'build_number': 50},
      },
    };

    expect(VersionUtil.selectPlatformVersionData(feed, platform: 'windows')['version'], '2.1.2');
    expect(VersionUtil.selectPlatformVersionData(feed, platform: 'android')['version'], '2.1.1');
  });
}
