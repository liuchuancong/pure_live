import 'dart:io';
import 'package:get/get.dart';
import 'package:pure_live/common/utils/version_util.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
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
        SmartDialog.showToast('请授予安装权限后再尝试下载安装');
        openAppSettings();
        return;
      }
    } catch (e) {
      SmartDialog.showToast('请求安装权限失败，${e.toString()}');
    }
  }
  SmartDialog.showToast('正在下载 纯粹直播v${VersionUtil.latestVersion}...');

  Get.dialog(
    DownloadApkDialog(
      apkUrl: apkUrl,
      version: VersionUtil.latestVersion, // 你的版本号
    ),
    barrierDismissible: false, // 禁止点击遮罩关闭（可选）
  );
}
