import 'dart:io';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/widgets/download_apk_dialog.dart';
import 'package:pure_live/plugins/file_utils.dart';

Uri? updateDownloadUri(String rawUrl) {
  final uri = FileUtils.parseHttpUrl(rawUrl);
  return uri == null || uri.userInfo.isNotEmpty ? null : uri;
}

bool requiresInstallPackagesPermission({required bool isAndroid, required String fileName}) {
  return isAndroid && fileName.toLowerCase().endsWith('.apk');
}

Future<bool> requestStorageInstallPermission() async {
  if (await Permission.requestInstallPackages.isDenied) {
    final status = Permission.requestInstallPackages.request();
    return status.isGranted;
  }
  return true;
}

final List<String> mirrors = [
  'https://gh-proxy.org/',
  'https://gh.h233.eu.org/',
  'https://git.yylx.win/',
  'https://ghproxy.cc/',
  'https://cdn.gh-proxy.org/',
  'https://wget.la/',
  'https://github.ednovas.xyz/',
  'https://down.npee.cn/?',
  'https://slink.ltd/',
  'https://gitproxy.click/',
];

Future<void>? _activeDownloadDialog;

List<String> getMirrorUrls(String apkUrl, {bool githubOriginOnly = false}) {
  final uri = updateDownloadUri(apkUrl);
  if (uri == null) return const [];
  final normalizedUrl = uri.toString();
  if (githubOriginOnly) return [normalizedUrl];
  final mirrorsUrl = mirrors.map((e) => '$e$normalizedUrl').toList();
  mirrorsUrl.add(normalizedUrl);
  return mirrorsUrl.toSet().toList(growable: false);
}

Future<void> downloadAndInstallApk(String apkUrl, {String? fileName}) {
  final uri = updateDownloadUri(apkUrl);
  if (uri == null) {
    ToastUtil.show(i18n('download_failed'));
    return Future<void>.value();
  }
  final resolvedFileName = safeDownloadFileName(uri.toString(), suggestedName: fileName);

  final active = _activeDownloadDialog;
  if (active != null) return active;

  late final Future<void> tracked;
  tracked = _showDownloadDialog(uri, fileName: fileName, resolvedFileName: resolvedFileName).whenComplete(() {
    if (identical(_activeDownloadDialog, tracked)) _activeDownloadDialog = null;
  });
  _activeDownloadDialog = tracked;
  return tracked;
}

Future<void> _showDownloadDialog(Uri uri, {String? fileName, required String resolvedFileName}) async {
  if (requiresInstallPackagesPermission(isAndroid: Platform.isAndroid, fileName: resolvedFileName)) {
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
  ToastUtil.show(
    fileName == null
        ? i18n('downloading_apk', args: {'version': VersionUtil.latestVersion})
        : i18n('downloading_app', args: {'app': resolvedFileName}),
  );
  await Get.dialog<void>(
    DownloadApkDialog(
      apkUrl: uri.toString(),
      version: VersionUtil.latestVersion,
      fileName: fileName == null ? null : resolvedFileName,
    ),
    barrierDismissible: false,
  );
}
