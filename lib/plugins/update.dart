import 'package:pure_live/common/index.dart';
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
  ToastUtil.show(i18n("downloading_apk", args: {"version": VersionUtil.latestVersion}));
  Get.dialog(DownloadApkDialog(apkUrl: apkUrl, version: VersionUtil.latestVersion), barrierDismissible: false);
}
