import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pure_live/common/utils/version_util.dart';
import 'package:pure_live/modules/version/version_controller.dart';

void main() {
  PackageInfo localPackage() =>
      PackageInfo(appName: 'Pure Live', packageName: 'com.example.pure_live', version: '3.1.8', buildNumber: '4121');

  setUp(() {
    VersionUtil.latestVersion = '';
    VersionUtil.latestBuildNumber = null;
    VersionUtil.latestUpdateLog = '';
    VersionUtil.latestAndroidAbis = const {};
    VersionUtil.latestWindowsMsixAvailable = false;
    VersionUtil.latestAssets = [];
  });

  test('failed update check always leaves a retryable terminal state', () async {
    var packageCalls = 0;
    final controller = VersionController(
      updateChecker: () async => false,
      packageInfoLoader: () async {
        packageCalls++;
        return localPackage();
      },
    );

    await controller.checkNewVersion();

    expect(controller.loading.value, isFalse);
    expect(controller.error.value, isTrue);
    expect(packageCalls, 0);
    expect(controller.windowsSetupUrl.value, isEmpty);
    expect(controller.androidArm64Url.value, isEmpty);
  });

  test('package metadata failures clear every generated release URL', () async {
    final controller =
        VersionController(
            updateChecker: () async => true,
            packageInfoLoader: () async => throw StateError('fixture package metadata failure'),
          )
          ..windowsSetupUrl.value = 'stale setup'
          ..androidArm64Url.value = 'stale apk';

    await controller.checkNewVersion();

    expect(controller.loading.value, isFalse);
    expect(controller.error.value, isTrue);
    expect(controller.windowsSetupUrl.value, isEmpty);
    expect(controller.androidArm64Url.value, isEmpty);
  });

  test('download links come only from assets the release actually published', () async {
    VersionUtil.latestVersion = '3.2.0';
    VersionUtil.latestBuildNumber = null;
    VersionUtil.latestAndroidAbis = const {'arm64-v8a'};
    final controller = VersionController(
      updateChecker: () async => true,
      packageInfoLoader: () async => localPackage(),
    );

    await controller.checkNewVersion();

    expect(controller.loading.value, isFalse);
    expect(controller.error.value, isFalse);
    expect(controller.hasNewVersion.value, isTrue);
    expect(controller.androidArm64Url.value, isEmpty, reason: 'no asset list, no guessed file name');
    expect(controller.windowsSetupUrl.value, isEmpty);
  });

  test('valid update data compares against the package loaded by this controller', () async {
    const base = 'https://github.com/wzgrx/pure_live/releases/download/v3.2.0';
    VersionUtil.latestVersion = '3.2.0';
    VersionUtil.latestBuildNumber = 5000;
    VersionUtil.latestUpdateLog = '# Pure Live 3.2.0';
    VersionUtil.latestAndroidAbis = const {'arm64-v8a'};
    VersionUtil.latestAssets = [
      {'name': 'android-arm64-v8a', 'url': '$base/PureLive-3.2.0-5000-debug-signed-android-arm64-v8a-release.apk'},
      {'name': 'android-armeabi-v7a', 'url': '$base/PureLive-3.2.0-5000-android-armeabi-v7a-release.apk'},
      {'name': 'windows-x64-setup.exe', 'url': '$base/PureLive-3.2.0-5000-windows-x64-setup.exe'},
    ];
    final controller = VersionController(
      updateChecker: () async => true,
      packageInfoLoader: () async => localPackage(),
    );

    await controller.checkNewVersion();

    expect(controller.loading.value, isFalse);
    expect(controller.error.value, isFalse);
    expect(controller.hasNewVersion.value, isTrue);
    expect(controller.updateLog.value, '# Pure Live 3.2.0');
    expect(controller.androidArm64Url.value, endsWith('-debug-signed-android-arm64-v8a-release.apk'));
    expect(controller.androidArmeabiV7aUrl.value, isEmpty, reason: 'the feed does not declare armeabi-v7a');
    expect(controller.windowsSetupUrl.value, endsWith('/PureLive-3.2.0-5000-windows-x64-setup.exe'));
  });

  test('version comparison handles prefixes, build metadata and malformed values', () {
    expect(VersionUtil.isNewerVersion('v3.2.0+5000', '3.1.8+4121'), isTrue);
    expect(VersionUtil.isNewerVersion('3.1.8', 'v3.1.8+4121'), isFalse);
    expect(VersionUtil.isNewerVersion('3.1.7', '3.1.8'), isFalse);
    expect(VersionUtil.isNewerVersion('latest', '3.1.8'), isFalse);
  });
}
