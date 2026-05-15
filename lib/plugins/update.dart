import 'dart:io';
import 'package:get/get.dart';
import 'package:pure_live/plugins/locale_helper.dart';
import 'package:pure_live/common/utils/toast_util.dart';
import 'package:pure_live/common/utils/version_util.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pure_live/common/widgets/download_apk_dialog.dart';

Future<bool> requestStorageInstallPermission() async {
  if (await Permission.requestInstallPackages.isDenied) {
    final status = Permission.requestInstallPackages.request();
    return status.isGranted;
  }
  return true;
}

final List<String> mirrors = [
  'https://gh.llkk.cc/',
  'https://cdn.crashmc.com/',
  'https://wget.la/',
  'https://gh.xxooo.cf/',
  'https://gh-proxy.com/',
  'https://down.npee.cn/?',
  'https://ghproxy.com/',
];

List<String> getMirrorUrls(String apkUrl) {
  final mirrorsUrl = mirrors.map((e) => '$e$apkUrl').toList();
  mirrorsUrl.add(apkUrl);
  return mirrorsUrl;
}

Future<void> downloadAndInstallApk(String apkUrl) async {
  if (Platform.isAndroid) {
    try {
      final hasInstallPermission = await requestStorageInstallPermission();
      if (!hasInstallPermission) {
        ToastUtil.show(i18n("grant_install_permission"));
        openAppSettings();
        return;
      }
    } catch (e) {
      ToastUtil.show('${i18n("request_install_permission_failed")}${e.toString()}');
    }
  }
  ToastUtil.show(i18n("downloading_apk", args: {
    "version": VersionUtil.latestVersion
  }));

  Get.dialog(
    DownloadApkDialog(
      apkUrl: apkUrl,
      version: VersionUtil.latestVersion,
    ),
    barrierDismissible: false,
  );
}