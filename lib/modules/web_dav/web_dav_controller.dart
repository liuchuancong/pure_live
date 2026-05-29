import 'dart:convert';
import 'package:pure_live/common/index.dart';
import 'package:date_format/date_format.dart';
import 'package:pure_live/plugins/utils.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;
import 'package:pure_live/modules/web_dav/webdav_config.dart';
import 'package:pure_live/modules/web_dav/webdav_service.dart';
import 'package:pure_live/common/services/settings/backup_controller.dart';
import 'package:pure_live/common/services/settings/web_dav_controller.dart';

class WebDavPageController extends GetxController {
  final RxList<WebDAVConfig> configs = <WebDAVConfig>[].obs;
  final Rx<WebDAVConfig?> currentConfig = Rx<WebDAVConfig?>(null);
  final RxList<webdav.File> files = <webdav.File>[].obs;
  final RxBool isLoading = true.obs;
  final RxString errorMessage = ''.obs;
  final RxString dirPath = '/'.obs;
  final RxList<String> breadcrumbParts = <String>[].obs;
  final RxBool isFromBreadcrumb = false.obs;

  late WebDAVService _webdavService;

  final WebDavController _webDavController = Get.find<WebDavController>();
  final BackupController _backupController = Get.find<BackupController>();

  @override
  void onInit() {
    super.onInit();
    // 从全局 WebDavController 读取配置
    configs.assignAll(_webDavController.webDavConfigs.v);
    if (_webDavController.currentWebDavConfig.v.isNotEmpty) {
      currentConfig.value = WebDAVConfig.fromJson(jsonDecode(_webDavController.currentWebDavConfig.v));
      initializeWebDAV();
    }

    // 监听同步到全局
    configs.listen((_) {
      _webDavController.webDavConfigs.v = List.from(configs);
      _webDavController.webDavConfigs.rx.refresh();
    });

    currentConfig.listen((config) {
      if (config != null) {
        _webDavController.currentWebDavConfig.v = jsonEncode(config.toJson());
      } else {
        _webDavController.currentWebDavConfig.v = '';
      }
    });
  }

  void initializeWebDAV() {
    if (currentConfig.value != null) {
      _webdavService = WebDAVService(
        url: currentConfig.value!.fullUrl,
        username: currentConfig.value!.username,
        password: currentConfig.value!.password,
      );
      loadFiles();
    }
  }

  Future<void> saveCurrentConfig(String configName) async {
    if (currentConfig.value != null) {
      _webDavController.currentWebDavConfig.v = jsonEncode(currentConfig.value!.toJson());
    }
  }

  Future<void> loadFiles() async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final loadedFiles = await _webdavService.readDirectory(dirPath.value);
      files.assignAll(loadedFiles);
      isLoading.value = false;
    } catch (e) {
      isLoading.value = false;
      errorMessage.value = '${i18n("webdav_load_dir_failed")}: $e';
      Get.showSnackbar(
        GetSnackBar(
          message: '${i18n("webdav_load_failed")}: $e',
          duration: const Duration(seconds: 2),
          backgroundColor: Get.theme.colorScheme.error,
        ),
      );
    }
  }

  String buildPath(String fileName) {
    final cleanPath = dirPath.value.replaceAll(RegExp(r'/+'), '/');
    return cleanPath.endsWith('/') ? '$cleanPath$fileName/' : '$cleanPath/$fileName/';
  }

  void goToParentDirectory() {
    if (dirPath.value != '/') {
      final cleanPath = dirPath.value.endsWith('/')
          ? dirPath.value.substring(0, dirPath.value.length - 1)
          : dirPath.value;
      final newPath = cleanPath.substring(0, cleanPath.lastIndexOf('/') + 1);
      dirPath.value = newPath.isEmpty ? '/' : newPath;
      isFromBreadcrumb.value = true;
      triggerBreadcrumbScroll();
      loadFiles();
    } else {
      Navigator.pop(Get.context!);
    }
  }

  void deleteConfig(WebDAVConfig config) {
    configs.removeWhere((c) => c.name == config.name);
    if (currentConfig.value?.name == config.name) {
      currentConfig.value = null;
      dirPath.value = '/';
      initializeWebDAV();
    }
    Navigator.pop(Get.context!);
  }

  void rebuildBreadcrumb() {
    final cleanPath = dirPath.value.replaceAll(RegExp(r'/+'), '/').replaceAll(RegExp(r'^/|/$'), '');
    breadcrumbParts.assignAll(cleanPath.split('/'));
    if (dirPath.value == '/' || cleanPath.isEmpty) breadcrumbParts.clear();
  }

  void updateBreadcrumbParts() {
    if (!isFromBreadcrumb.value) {
      String path = dirPath.value;
      if (path.startsWith('/')) path = path.substring(1);
      if (path.endsWith('/')) path = path.substring(0, path.length - 1);
      breadcrumbParts.assignAll(path.isEmpty ? [] : path.split('/'));
    }
  }

  void triggerBreadcrumbScroll() {}

  void onConfigSelected(WebDAVConfig config) {
    currentConfig.value = config;
    dirPath.value = '/';
    breadcrumbParts.clear();
    saveCurrentConfig(config.name);
    initializeWebDAV();
    rebuildBreadcrumb();
    Navigator.pop(Get.context!);
  }

  void onFileTap(webdav.File file) {
    if (file.isDir ?? false) {
      final newPath = buildPath(file.name!);
      dirPath.value = newPath;
      isFromBreadcrumb.value = false;
      updateBreadcrumbParts();
      triggerBreadcrumbScroll();
      loadFiles();
    }
  }

  /// 上传配置到 WebDAV（走新备份系统）
  void uploadConfigSettings() async {
    try {
      final dateStr = formatDate(DateTime.now(), [yyyy, '-', mm, '-', dd, 'T', HH, '_', nn, '_', ss]);
      final fileName = 'purelive_$dateStr.txt';

      // 备份所有配置
      final data = _backupController.exportAllSettings();
      final content = jsonEncode(data);
      final bytes = utf8.encode(content);

      if (dirPath.value == '/') {
        SnackBarUtil.error(i18n("webdav_select_dir_first"));
        return;
      }

      final remotePath = '${dirPath.value}$fileName';
      await _webdavService.client.write(remotePath, bytes);

      SnackBarUtil.success(i18n("webdav_upload_success"));
      loadFiles();
    } catch (e) {
      SnackBarUtil.error('${i18n("webdav_upload_failed")}: $e');
    }
  }

  void deleteFile(webdav.File file) async {
    final result = await Utils.showAlertDialog(i18n("webdav_confirm_delete"), title: i18n("webdav_delete"));
    if (result) {
      try {
        await _webdavService.client.remove(file.path!);
        loadFiles();
        SnackBarUtil.success(i18n("webdav_delete_success"));
      } catch (e) {
        SnackBarUtil.error('${i18n("webdav_delete_failed")}: $e');
      }
    }
  }

  /// 下载并恢复配置（走新备份系统）
  void downloadFile(webdav.File file) async {
    try {
      final bytes = await _webdavService.client.read(file.path!);
      final data = jsonDecode(utf8.decode(bytes));
      _backupController.importAllSettings(data);
      SnackBarUtil.success(i18n("webdav_sync_success"));
    } catch (e) {
      SnackBarUtil.error('${i18n("webdav_download_failed")}: $e');
    }
  }
}
