import 'dart:io';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/file_utils.dart';
import 'package:pure_live/common/widgets/download_apk_dialog.dart';
import 'package:pure_live/common/widgets/download_directory_dialog.dart';
import 'package:pure_live/common/services/settings/cache_controller.dart';

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
  // 🟢 最佳：api=200 + asset=206（支持断点续传）
  'https://cdn.gh-proxy.org/',
  'https://edgeone.gh-proxy.org/',
  'https://hk.gh-proxy.org/',
  'https://gh.noki.eu.org/',
  'https://gh-proxy.com/',
  'https://slink.ltd/',

  // 🟡 可用：api=200 + asset=200
  'https://gh.con.sh/',
  'https://ghp.keleyaa.com/',
  'https://ghproxy.cxkpro.top/',
  'https://ghproxy.link/',
  'https://gh-proxy.net/',
  'https://gh-proxy.org/',
  'https://gh-proxy.pages.dev/',
  'https://ghpxy.hwinzniej.top/',
  'https://gitproxy.click/',
  'https://tvv.tw/',
  'https://v6.gh-proxy.org/',

  // 🟠 仅下载可用：asset 正常，API 被限
  'https://fastgit.cc/',
  'https://gh.catmak.name/',
  'https://ghfile.geekertao.top/',
  'https://ghproxy.monkeyray.net/',
  'https://github.ednovas.xyz/',
  'https://proxy.gitwarp.top/',
  'https://g.blfrp.cn/',
  'https://gh.ddlc.top/',
  'https://gh.xxooo.cf/',
  'https://ghm.078465.xyz/',
  'https://ghproxy.imciel.com/',
  'https://ghproxy.net/',
  'https://git.yylx.win/',
  'https://github.geekery.cn/',
  'https://gitproxy.mrhjx.cn/',
  'https://wget.la/',
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
      return;
    }
  }
  if (!await _ensureDownloadDirectorySelected()) return;
  ToastUtil.show(
    fileName == null
        ? i18n('downloading_apk', args: {'version': VersionUtil.latestVersion})
        : i18n('downloading_app', args: {'app': resolvedFileName}),
  );
  final cache = Get.find<CacheController>();
  await Get.dialog<void>(
    DownloadApkDialog(
      apkUrl: uri.toString(),
      version: VersionUtil.latestVersion,
      fileName: fileName == null ? null : resolvedFileName,
      downloadDirectoryProvider: CacheController.resolveDownloadDirectory,
      showOpenFolder: cache.hasCustomDownloadDirectory,
    ),
    barrierDismissible: false,
  );
}

/// Resolves where the update package is stored before the download dialog
/// opens.
///
/// When no usable download directory exists the user picks either a custom
/// folder or the platform default. Declining the prompt cancels the update.
Future<bool> _ensureDownloadDirectorySelected() async {
  final cache = Get.find<CacheController>();
  if (!await cache.needsDownloadDirectoryPrompt() && await _ensureDownloadDirectoryAccess(cache)) {
    return true;
  }

  final defaultPath = (await CacheController.defaultDownloadDirectory()).path;
  final choice = await showDownloadDirectoryChoiceDialog(defaultDirectoryPath: defaultPath);
  if (choice == null) return false;

  if (choice == DownloadDirectoryChoice.useDefault) {
    await cache.useDefaultDownloadDirectory();
    return true;
  }

  final selected = await FileUtils.pickDirectory();
  if (selected == null || selected.trim().isEmpty) {
    ToastUtil.show(i18n('download_directory_not_selected'));
    return false;
  }

  await cache.setDownloadDirectory(selected);
  if (await _ensureDownloadDirectoryAccess(cache)) return true;

  ToastUtil.show(i18n('download_directory_permission_hint'));
  if (Platform.isAndroid) openAppSettings();
  return false;
}

/// 动态申请写入所选下载目录的权限，并确认该目录真的可以写入。
///
/// 应用专属的默认目录位于应用沙箱内，不需要任何权限；只有用户自选的公共目录
/// （例如 `/storage/emulated/0/Download/...`）才会触发系统权限申请。
Future<bool> _ensureDownloadDirectoryAccess(CacheController cache) async {
  if (!cache.hasCustomDownloadDirectory) return true;
  if (await CacheController.isCustomDownloadDirectoryUsable()) return true;

  await FileUtils.requestStoragePermission();
  return CacheController.isCustomDownloadDirectoryUsable();
}
