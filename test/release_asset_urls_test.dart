import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/utils/version_util.dart';
import 'package:pure_live/modules/version/version_controller.dart';

void main() {
  test('maintained build reads updates and release assets from the same repository', () {
    expect(VersionUtil.projectUrl, 'https://github.com/wzgrx/pure_live');
    expect(VersionUtil.issuesUrl, '${VersionUtil.projectUrl}/issues');
    expect(VersionUtil.releaseUrl, contains('/repos/wzgrx/pure_live/releases'));
  });

  test('release URLs match locally produced artifact names', () {
    const urls = ReleaseAssetUrls(
      projectUrl: 'https://github.com/liuchuancong/pure_live',
      version: '2.1.4',
      buildNumber: 52,
    );

    expect(urls.androidArm64, endsWith('/PureLive-2.1.4-52-android-arm64-v8a-release.apk'));
    expect(urls.androidArmeabiV7a, endsWith('/PureLive-2.1.4-52-android-armeabi-v7a-release.apk'));
    expect(urls.androidX8664, endsWith('/PureLive-2.1.4-52-android-x86_64-release.apk'));
    expect(urls.windowsSetup, endsWith('/PureLive-2.1.4-52-windows-x64-setup.exe'));
    expect(urls.windowsMsix, endsWith('/PureLive-2.1.4-52-windows-x64.msix'));
    expect(urls.windowsPortable, endsWith('/PureLive-2.1.4-52-windows-x64-portable.zip'));
    expect(urls.macosUniversal, endsWith('/PureLive-2.1.4-52-macos-universal.zip'));
  });

  test('Android update links are limited to APK variants declared by the feed', () {
    expect(
      VersionUtil.selectAndroidAbis({
        'android_abis': ['arm64-v8a'],
      }),
      {'arm64-v8a'},
    );
    expect(
      VersionUtil.selectAndroidAbis({
        'android_abis': ['armeabi-v7a', 'arm64-v8a', 'x86_64', 'unsupported'],
      }),
      {'armeabi-v7a', 'arm64-v8a', 'x86_64'},
    );
    expect(VersionUtil.selectAndroidAbis({}), {'arm64-v8a'});
    expect(VersionUtil.selectAndroidAbis({'android_abis': []}), isEmpty);
    expect(
      VersionUtil.selectAndroidAbis({
        'android_abis': ['unsupported'],
      }),
      isEmpty,
    );
  });

  test('platform update feed does not announce an unpublished artifact to other platforms', () {
    final feed = <String, dynamic>{
      'version': '2.1.1',
      'build_number': 49,
      'platforms': {
        'windows': {'version': '2.1.2', 'build_number': 50, 'windows_msix_available': false},
      },
    };

    expect(VersionUtil.selectPlatformVersionData(feed, platform: 'windows')['version'], '2.1.2');
    expect(VersionUtil.selectPlatformVersionData(feed, platform: 'windows')['windows_msix_available'], isFalse);
    expect(VersionUtil.selectPlatformVersionData(feed, platform: 'android')['version'], '2.1.1');
  });
}
