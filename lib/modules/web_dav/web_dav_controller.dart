import 'dart:async';
import 'dart:convert';

import 'package:pure_live/common/index.dart';
import 'package:date_format/date_format.dart';
import 'package:uuid/uuid.dart';
import 'package:pure_live/plugins/utils.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;
import 'package:pure_live/modules/web_dav/webdav_config.dart';
import 'package:pure_live/modules/web_dav/webdav_service.dart';
import 'package:pure_live/common/services/settings/backup_controller.dart';
import 'package:pure_live/common/services/settings/web_dav_controller.dart';

class WebDavPageController extends GetxController {
  WebDavPageController({
    WebDAVService Function(WebDAVConfig)? serviceFactory,
    Future<bool> Function()? confirmDelete,
    DateTime Function()? now,
    void Function(String message, {bool isError})? feedback,
  }) : _serviceFactory = serviceFactory ?? _createService,
       _confirmDelete = confirmDelete ?? _showDeleteConfirmation,
       _now = now ?? DateTime.now,
       _feedback = feedback ?? _showTransferFeedback;

  final WebDAVService Function(WebDAVConfig) _serviceFactory;
  final Future<bool> Function() _confirmDelete;
  final DateTime Function() _now;
  final void Function(String message, {bool isError}) _feedback;

  static Future<bool> _showDeleteConfirmation() =>
      Utils.showAlertDialog(i18n("webdav_confirm_delete"), title: i18n("webdav_delete"));

  static WebDAVService _createService(WebDAVConfig config) =>
      WebDAVService(url: config.fullUrl, username: config.username, password: config.password);

  static void _showTransferFeedback(String message, {bool isError = false}) {
    final context = Get.context;
    if (context == null) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final colors = Theme.of(context).colorScheme;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: isError ? colors.onErrorContainer : colors.onSurfaceVariant)),
        backgroundColor: isError ? colors.errorContainer : colors.surfaceContainerHighest,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  final RxList<WebDAVConfig> configs = <WebDAVConfig>[].obs;
  final Rx<WebDAVConfig?> currentConfig = Rx<WebDAVConfig?>(null);
  final RxList<webdav.File> files = <webdav.File>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isUploading = false.obs;
  // Retained across service changes until download/restore or deletion settles.
  // A local restore already committing must finish before exporting a backup.
  final RxString fileActionLabelKey = ''.obs;
  final RxString errorMessage = ''.obs;
  final RxString configurationIssueKey = ''.obs;
  final RxString dirPath = '/'.obs;
  final RxList<String> breadcrumbParts = <String>[].obs;
  final RxBool isFromBreadcrumb = false.obs;

  WebDAVService? _webdavService;
  WebDAVConfig? _serviceConfig;
  int _serviceEpoch = 0;
  int _loadEpoch = 0;
  bool _disposed = false;

  final WebDavController _webDavController = Get.find<WebDavController>();
  final BackupController _backupController = Get.find<BackupController>();
  StreamSubscription<List<WebDAVConfig>>? _configsSubscription;
  StreamSubscription<WebDAVConfig?>? _currentConfigSubscription;

  bool get canUpload {
    final selected = currentConfig.value;
    final busy = isUploading.value || fileActionLabelKey.value.isNotEmpty;
    return !_disposed && selected != null && !busy && _webdavService != null && identical(selected, _serviceConfig);
  }

  bool get canStartFileAction => canUpload;

  @override
  void onInit() {
    super.onInit();
    // 从全局 WebDavController 读取配置
    configs.assignAll(_webDavController.webDavConfigs.v);
    _restoreSelection();

    // 监听同步到全局
    _configsSubscription = configs.listen((_) {
      _webDavController.webDavConfigs.v = List.from(configs);
      _webDavController.webDavConfigs.refresh();
    });

    _currentConfigSubscription = currentConfig.listen((config) {
      if (config != null) {
        _webDavController.currentWebDavConfig.v = jsonEncode(config.toJson());
      } else {
        _webDavController.currentWebDavConfig.v = '';
      }
    });
  }

  void _restoreSelection() {
    final raw = _webDavController.currentWebDavConfig.v;
    if (raw.isEmpty) return;
    // The saved snapshot identifies a selection, not a second source of
    // connection credentials. Opening the page must not rewrite damaged data.
    configurationIssueKey.value = 'webdav_saved_selection_invalid';
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return;
    }
    if (decoded is! Map<String, dynamic>) return;
    final name = decoded['name'];
    if (name is! String || name.trim().isEmpty) return;
    final matches = configs.where((config) => config.name == name).toList();
    if (matches.length != 1) return;
    final selected = matches.single;
    if (!WebDAVConfig.isValidAddress(selected.address)) {
      configurationIssueKey.value = 'webdav_saved_address_invalid';
      return;
    }
    currentConfig.value = selected;
    initializeWebDAV();
  }

  @override
  void onClose() {
    if (_disposed) return;
    _disposed = true;
    _serviceEpoch++;
    _loadEpoch++;
    _webdavService?.close();
    _webdavService = null;
    _configsSubscription?.cancel();
    _currentConfigSubscription?.cancel();
    super.onClose();
  }

  void initializeWebDAV() {
    if (_disposed) return;
    _serviceEpoch++;
    _loadEpoch++;
    _webdavService?.close();
    _webdavService = null;
    _serviceConfig = currentConfig.value;
    isUploading.value = false;
    files.clear();
    errorMessage.value = '';
    configurationIssueKey.value = '';
    isLoading.value = false;
    if (_serviceConfig == null) {
      dirPath.value = '/';
      breadcrumbParts.clear();
      return;
    }
    rebuildBreadcrumb();
    if (!WebDAVConfig.isValidAddress(_serviceConfig!.address)) {
      errorMessage.value = i18n('webdav_saved_address_invalid');
      return;
    }
    _webdavService = _serviceFactory(_serviceConfig!);
    unawaited(loadFiles());
  }

  bool _ownsService(WebDAVService service, int epoch) =>
      !_disposed &&
      epoch == _serviceEpoch &&
      identical(service, _webdavService) &&
      identical(currentConfig.value, _serviceConfig);

  Future<void> saveCurrentConfig(String configName) async {
    if (currentConfig.value != null) {
      _webDavController.currentWebDavConfig.v = jsonEncode(currentConfig.value!.toJson());
    }
  }

  Future<void> loadFiles() async {
    if (_disposed) return;
    final request = ++_loadEpoch;
    final service = _webdavService;
    final epoch = _serviceEpoch;
    if (service == null || !_ownsService(service, epoch)) {
      files.clear();
      if (currentConfig.value == null) errorMessage.value = '';
      isLoading.value = false;
      return;
    }
    final path = dirPath.value;
    bool isCurrent() => _ownsService(service, epoch) && request == _loadEpoch && path == dirPath.value;
    isLoading.value = true;
    errorMessage.value = '';
    files.clear();
    rebuildBreadcrumb();
    try {
      final loadedFiles = await service.readDirectory(path);
      if (!isCurrent()) return;
      files.assignAll(loadedFiles);
    } catch (e) {
      if (!isCurrent()) return;
      // The page owns the persistent error and retry action. No detached toast
      // should outlive a directory selection or the page itself.
      errorMessage.value = '${i18n("webdav_load_dir_failed")}: $e';
    } finally {
      if (isCurrent()) isLoading.value = false;
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
  }

  void rebuildBreadcrumb() {
    final cleanPath = dirPath.value.replaceAll(RegExp(r'/+'), '/').replaceAll(RegExp(r'^/|/$'), '');
    breadcrumbParts.assignAll(cleanPath.split('/'));
    if (dirPath.value == '/' || cleanPath.isEmpty) breadcrumbParts.clear();
  }

  void updateBreadcrumbParts() {
    rebuildBreadcrumb();
  }

  void triggerBreadcrumbScroll() {}

  void onConfigSelected(WebDAVConfig config) {
    currentConfig.value = config;
    dirPath.value = '/';
    breadcrumbParts.clear();
    saveCurrentConfig(config.name);
    initializeWebDAV();
    rebuildBreadcrumb();
  }

  void onFileTap(webdav.File file) {
    if (file.isDir != true) return;
    final newPath = _directoryPathFor(file);
    if (newPath == null) return;
    dirPath.value = newPath;
    isFromBreadcrumb.value = false;
    updateBreadcrumbParts();
    triggerBreadcrumbScroll();
    loadFiles();
  }

  String? _directoryPathFor(webdav.File file) {
    final serverPath = file.path?.trim();
    if (serverPath != null && serverPath.isNotEmpty && !serverPath.contains(RegExp(r'[\\?#]'))) {
      final normalized = serverPath.replaceAll(RegExp(r'/+'), '/');
      final candidate = normalized.startsWith('/') ? normalized : buildPath(normalized);
      final absolute = candidate.replaceAll(RegExp(r'/+'), '/');
      return absolute.endsWith('/') ? absolute : '$absolute/';
    }
    final name = file.name?.trim();
    if (name == null || name.isEmpty || name.contains(RegExp(r'[/\\?#]'))) return null;
    return buildPath(name);
  }

  /// 上传配置到 WebDAV（走新备份系统）
  Future<void> uploadConfigSettings() async {
    final service = _webdavService;
    final epoch = _serviceEpoch;
    if (service == null || !_ownsService(service, epoch) || !canUpload) return;
    final path = dirPath.value;
    isUploading.value = true;
    try {
      final dateStr = formatDate(_now(), [yyyy, '-', mm, '-', dd, 'T', HH, '_', nn, '_', ss]);
      // Timestamp-only names overwrite earlier backups within the same second.
      final fileName = 'purelive_${dateStr}_${const Uuid().v4()}.txt';

      // 备份所有配置
      final data = _backupController.exportAllSettings();
      final content = jsonEncode(data);
      final bytes = utf8.encode(content);

      final remotePath = '${path.endsWith('/') ? path : '$path/'}$fileName';
      await service.writeFile(remotePath, bytes);
      if (!_ownsService(service, epoch)) return;

      _feedback(i18n("webdav_upload_success"));
      if (dirPath.value == path) await loadFiles();
    } catch (e) {
      if (!_ownsService(service, epoch)) return;
      _feedback('${i18n("webdav_upload_failed")}: $e', isError: true);
    } finally {
      if (_ownsService(service, epoch)) isUploading.value = false;
    }
  }

  Future<void> deleteFile(webdav.File file) async {
    final service = _webdavService;
    final epoch = _serviceEpoch;
    final path = dirPath.value;
    final remotePath = file.path;
    if (service == null || !_ownsService(service, epoch) || remotePath == null || !canStartFileAction) return;
    fileActionLabelKey.value = 'webdav_deleting';
    try {
      final result = await _confirmDelete();
      if (!result || !_ownsService(service, epoch) || dirPath.value != path) return;
      await service.removeFile(remotePath);
      if (!_ownsService(service, epoch)) return;
      _feedback(i18n("webdav_delete_success"));
      if (dirPath.value == path) await loadFiles();
    } catch (e) {
      if (!_ownsService(service, epoch)) return;
      _feedback('${i18n("webdav_delete_failed")}: $e', isError: true);
    } finally {
      if (!_disposed) fileActionLabelKey.value = '';
    }
  }

  /// 下载并恢复配置（走新备份系统）
  Future<void> downloadFile(webdav.File file) async {
    final service = _webdavService;
    final epoch = _serviceEpoch;
    final remotePath = file.path;
    if (service == null ||
        !_ownsService(service, epoch) ||
        remotePath == null ||
        file.isDir == true ||
        !canStartFileAction) {
      return;
    }
    fileActionLabelKey.value = 'webdav_restoring';
    try {
      final bytes = await service.readFile(remotePath);
      // Fence before local mutation, not only before its success notification.
      if (!_ownsService(service, epoch)) return;
      final data = jsonDecode(utf8.decode(bytes));
      await _backupController.restoreAllSettings(Map<String, dynamic>.from(data as Map));
      if (!_ownsService(service, epoch)) return;
      _feedback(i18n("webdav_sync_success"));
    } catch (e) {
      if (!_ownsService(service, epoch)) return;
      _feedback('${i18n("webdav_download_failed")}: $e', isError: true);
    } finally {
      if (!_disposed) fileActionLabelKey.value = '';
    }
  }
}
