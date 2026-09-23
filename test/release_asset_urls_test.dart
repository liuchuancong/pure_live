import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/utils/version_util.dart';
import 'package:pure_live/modules/version/version_page.dart';
import 'package:pure_live/modules/version/version_controller.dart';

void main() {
  test('maintained build reads updates and release assets from the same repository', () {
    expect(VersionUtil.projectUrl, 'https://github.com/liuchuancong/pure_live');
    expect(VersionUtil.issuesUrl, '${VersionUtil.projectUrl}/issues');
    expect(VersionUtil.releaseUrl, contains('/repos/liuchuancong/pure_live/releases'));
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

  test('incomplete release identity never produces broken download links', () {
    const missingVersion = ReleaseAssetUrls(
      projectUrl: 'https://github.com/liuchuancong/pure_live',
      version: '',
      buildNumber: 52,
    );
    const missingBuild = ReleaseAssetUrls(
      projectUrl: 'https://github.com/liuchuancong/pure_live',
      version: '3.2.0',
      buildNumber: 0,
    );
    const unsafeVersion = ReleaseAssetUrls(
      projectUrl: 'https://github.com/liuchuancong/pure_live',
      version: '3.2.0/../../fixture',
      buildNumber: 52,
    );

    expect(missingVersion.androidArm64, isEmpty);
    expect(missingVersion.windowsSetup, isEmpty);
    expect(missingBuild.androidArm64, isEmpty);
    expect(missingBuild.windowsPortable, isEmpty);
    expect(unsafeVersion.androidArm64, isEmpty);
  });

  test('download actions accept only absolute web URLs', () {
    expect(versionDownloadUri('https://example.test/release.apk'), isNotNull);
    expect(versionDownloadUri('http://127.0.0.1/release.apk'), isNotNull);
    expect(versionDownloadUri('release.apk'), isNull);
    expect(versionDownloadUri('file:///tmp/release.apk'), isNull);
    expect(versionDownloadUri('javascript:alert(1)'), isNull);
  });

  test('update failure and download feedback are translated in both locales', () {
    final english = jsonDecode(File('assets/translations/en.json').readAsStringSync()) as Map<String, dynamic>;
    final chinese = jsonDecode(File('assets/translations/zh.json').readAsStringSync()) as Map<String, dynamic>;
    const keys = {'version_update_download_failed', 'version_update_failed_subtitle', 'version_update_failed_title'};

    for (final key in keys) {
      expect(english[key], isA<String>().having((value) => value.trim(), key, isNotEmpty));
      expect(chinese[key], isA<String>().having((value) => value.trim(), key, isNotEmpty));
    }
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
