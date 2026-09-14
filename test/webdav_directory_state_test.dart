import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/services/settings/backup_controller.dart';
import 'package:pure_live/common/services/settings/web_dav_controller.dart';
import 'package:pure_live/common/services/utils/hive_rx.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/modules/web_dav/web_dav_controller.dart';
import 'package:pure_live/modules/web_dav/webdav_config.dart';
import 'package:pure_live/modules/web_dav/webdav_service.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;

const config = WebDAVConfig(name: 'fixture', address: 'http://127.0.0.1', username: '', password: '');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory hiveDirectory;
  late WebDavPageController controller;
  late List<_Service> services;
  late _BackupController backup;
  late Completer<bool> confirmation;
  late List<WebDAVConfig> connectedConfigs;
  late int confirmationCount;
  late List<String> feedback;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('webdav-directory-state-');
    Hive.init(hiveDirectory.path);
    await HivePrefUtil.init();
  });

  setUp(() {
    Get.testMode = true;
    Get.put(WebDavController());
    backup = _BackupController();
    Get.put<BackupController>(backup);
    confirmation = Completer<bool>();
    services = [];
    connectedConfigs = [];
    confirmationCount = 0;
    feedback = [];
    controller = WebDavPageController(
      feedback: (message, {isError = false}) => feedback.add(message),
      serviceFactory: (selected) {
        connectedConfigs.add(selected);
        final service = _Service();
        services.add(service);
        return service;
      },
    );
  });

  Future<bool> confirmDelete() {
    confirmationCount++;
    return confirmation.future;
  }

  Future<bool> allowRestore() async => true;

  tearDown(() async {
    controller.onClose();
    if (!confirmation.isCompleted) confirmation.complete(false);
    for (final service in services) {
      for (final read in service.reads) {
        if (!read.isCompleted) read.complete([]);
      }
      service.client.c.close(force: true);
    }
    await Future<void>.delayed(Duration.zero);
    Get.deleteAll(force: true);
    Get.reset();
    await Future<void>.delayed(Duration.zero);
    await Hive.box('app_settings').clear();
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  _Service connect() {
    controller.currentConfig.value = config;
    controller.initializeWebDAV();
    return services.last;
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  Future<void> seed(String selection, List<WebDAVConfig> entries) async {
    final settings = Get.find<WebDavController>();
    settings.webDavConfigs.v = entries;
    settings.currentWebDavConfig.v = selection;
    await settle();
  }

  test('configuration mutations do not depend on a global navigation context', () {
    controller.configs.assignAll([config]);

    expect(() => controller.onConfigSelected(config), returnsNormally);
    expect(controller.currentConfig.value, same(config));
    expect(services, hasLength(1));

    expect(() => controller.deleteConfig(config), returnsNormally);
    expect(controller.configs, isEmpty);
    expect(controller.currentConfig.value, isNull);
    expect(controller.dirPath.value, '/');
  });

  for (final raw in ['{broken', 'null', '[]', '42', '{"name":7}', '{}']) {
    test('invalid stored selection $raw preserves data and opens without a connection', () async {
      await seed(raw, [config]);
      expect(controller.onInit, returnsNormally);
      await settle();
      expect(controller.currentConfig.value, isNull);
      expect(controller.configs, [config]);
      expect(services, isEmpty);
      expect(Get.find<WebDavController>().currentWebDavConfig.v, raw);
      expect(Hive.box('app_settings').get('currentWebDavConfig'), raw);
      expect(controller.configurationIssueKey.value, isNotEmpty);
      await controller.loadFiles();
      expect(controller.configurationIssueKey.value, isNotEmpty);
      expect(services, isEmpty);
    });
  }

  test('orphaned stored selection never connects or rewrites persistent data', () async {
    final raw = jsonEncode(config.toJson());
    await seed(raw, []);
    controller.onInit();
    await settle();
    expect(controller.currentConfig.value, isNull);
    expect(services, isEmpty);
    expect(Get.find<WebDavController>().currentWebDavConfig.v, raw);
    expect(Get.find<WebDavController>().webDavConfigs.v, isEmpty);
  });

  test('stored selection resolves to the authoritative list object including anonymous credentials', () async {
    const stale = WebDAVConfig(name: 'fixture', address: 'https://old.example.test', username: 'old', password: 'old');
    final raw = jsonEncode(stale.toJson());
    await seed(raw, [config]);
    controller.onInit();
    await settle();
    expect(controller.currentConfig.value, same(config));
    expect(connectedConfigs.single, same(config));
    expect(Get.find<WebDavController>().currentWebDavConfig.v, raw);
  });

  test('invalid saved address remains editable and refresh never creates a service', () async {
    const invalid = WebDAVConfig(name: 'fixture', address: 'file:///tmp/dav', username: '', password: '');
    await seed(jsonEncode(invalid.toJson()), [invalid]);
    controller.onInit();
    expect(services, isEmpty);
    expect(controller.configs.single, same(invalid));
    await controller.loadFiles();
    expect(services, isEmpty);
    // A user may select the invalid list entry again before editing it.
    controller.currentConfig.value = invalid;
    controller.initializeWebDAV();
    expect(controller.errorMessage.value, isNotEmpty);
    await controller.loadFiles();
    expect(controller.errorMessage.value, isNotEmpty);
    expect(services, isEmpty);
  });

  test('ambiguous duplicate names require an explicit selection', () async {
    await seed(jsonEncode(config.toJson()), [config, config]);
    controller.onInit();
    expect(controller.currentConfig.value, isNull);
    expect(controller.configurationIssueKey.value, isNotEmpty);
    expect(services, isEmpty);
  });

  test('selection snapshot fields other than the name do not override the list', () async {
    await seed('{"name":"fixture","address":7,"password":null}', [config]);
    controller.onInit();
    expect(connectedConfigs.single, same(config));
    expect(controller.configurationIssueKey.value, isEmpty);
  });

  test('refresh without a selected configuration keeps the creation state', () async {
    await controller.loadFiles();
    expect(services, isEmpty);
    expect(controller.errorMessage.value, isEmpty);
    expect(controller.isLoading.value, isFalse);
    expect(controller.files, isEmpty);
  });

  test('late previous directory success does not replace the current directory', () async {
    controller.dirPath.value = '/first/';
    final service = connect();
    controller.dirPath.value = '/second/';
    final second = controller.loadFiles();
    service.reads[1].complete([webdav.File(name: 'second.txt')]);
    await second;
    service.reads[0].complete([webdav.File(name: 'first.txt')]);
    await settle();
    expect(controller.files.single.name, 'second.txt');
    expect(service.paths, ['/first/', '/second/']);
  });

  test('previous completion does not stop the current loading indicator', () async {
    final service = connect();
    final second = controller.loadFiles();
    service.reads[0].complete([]);
    await settle();
    expect(controller.isLoading.value, isTrue);
    service.reads[1].complete([]);
    await second;
    expect(controller.isLoading.value, isFalse);
  });

  test('clearing configuration clears files and fences the pending request', () async {
    final service = connect();
    controller.files.add(webdav.File(name: 'previous.txt'));
    controller.errorMessage.value = 'previous error';
    controller.breadcrumbParts.assignAll(['previous']);
    controller.currentConfig.value = null;
    controller.initializeWebDAV();
    service.reads.single.complete([webdav.File(name: 'late.txt')]);
    await settle();
    expect(controller.files, isEmpty);
    expect(controller.errorMessage.value, isEmpty);
    expect(controller.breadcrumbParts, isEmpty);
    expect(controller.isLoading.value, isFalse);
  });

  test('switching service fences the old configuration response', () async {
    final firstService = connect();
    controller.currentConfig.value = const WebDAVConfig(
      name: 'second',
      address: 'http://127.0.0.2',
      username: '',
      password: '',
    );
    controller.initializeWebDAV();
    services.last.reads.single.complete([webdav.File(name: 'current.txt')]);
    await settle();
    firstService.reads.single.complete([webdav.File(name: 'old-account.txt')]);
    await settle();
    expect(controller.files.single.name, 'current.txt');
  });

  test('closing the page prevents pending directory results from publishing', () async {
    final service = connect();
    controller.onClose();
    service.reads.single.complete([webdav.File(name: 'late.txt')]);
    await settle();
    expect(controller.files, isEmpty);
    expect(service.closeCount, 1);
    await controller.loadFiles();
    controller.initializeWebDAV();
    expect(service.reads, hasLength(1));
  });

  test('obsolete directory error leaves the newer success intact', () async {
    final service = connect();
    final second = controller.loadFiles();
    service.reads[1].complete([webdav.File(name: 'current.txt')]);
    await second;
    service.reads[0].completeError(StateError('obsolete'));
    await settle();
    expect(controller.files.single.name, 'current.txt');
    expect(controller.errorMessage.value, isEmpty);
    expect(controller.isLoading.value, isFalse);
  });

  test('current directory failure is visible and a retry clears it', () async {
    final service = connect();
    service.reads.single.completeError(StateError('fixture failure'));
    await settle();
    expect(controller.errorMessage.value, contains('fixture failure'));
    expect(controller.isLoading.value, isFalse);
    final retry = controller.loadFiles();
    expect(controller.errorMessage.value, isEmpty);
    service.reads.last.complete([]);
    await retry;
    expect(controller.files, isEmpty);
    expect(controller.isLoading.value, isFalse);
  });

  test('ancestor navigation rebuilds breadcrumbs and hides the previous files', () async {
    controller.dirPath.value = '/first/second/';
    final service = connect();
    service.reads.single.complete([webdav.File(name: 'previous.txt')]);
    await settle();
    expect(controller.goToParentDirectory(), isTrue);
    expect(controller.breadcrumbParts, ['first']);
    expect(controller.files, isEmpty);
    expect(service.paths.last, '/first/');
  });

  test('root parent request reports page ownership without reading or navigating', () async {
    final service = connect();
    service.reads.single.complete([]);
    await settle();

    expect(controller.goToParentDirectory(), isFalse);
    expect(controller.dirPath.value, '/');
    expect(controller.breadcrumbParts, isEmpty);
    expect(service.paths, ['/']);
  });

  test('nameless directory uses its server path instead of throwing', () async {
    final service = connect();
    service.reads.single.complete([]);
    await settle();

    expect(() => controller.onFileTap(webdav.File(path: '/folder', isDir: true)), returnsNormally);
    expect(controller.dirPath.value, '/folder/');
    expect(service.paths.last, '/folder/');
  });

  test('directory without a name or path is ignored', () async {
    final service = connect();
    service.reads.single.complete([]);
    await settle();

    expect(() => controller.onFileTap(webdav.File(isDir: true)), returnsNormally);
    expect(controller.dirPath.value, '/');
    expect(service.paths, ['/']);
  });

  test('relative directory path is resolved from the current directory without duplicate separators', () async {
    controller.dirPath.value = '/parent/';
    final service = connect();
    service.reads.single.complete([]);
    await settle();

    controller.onFileTap(webdav.File(path: 'child//', isDir: true));
    expect(controller.dirPath.value, '/parent/child/');
    expect(service.paths.last, '/parent/child/');
  });

  for (final action in ['clear', 'switch', 'close']) {
    test('download completed after $action does not start local restore', () async {
      final service = connect();
      final download = controller.downloadFile(
        webdav.File(path: '/backup.txt', isDir: false),
        confirmRestore: allowRestore,
      );
      await settle();
      expect(service.downloadPaths, ['/backup.txt']);
      if (action == 'close') {
        controller.onClose();
      } else {
        controller.currentConfig.value = action == 'clear' ? null : config;
        controller.initializeWebDAV();
      }
      service.download.complete(utf8.encode('{"backupVersion":3}'));
      await download;
      expect(backup.restores, isEmpty);
      expect(service.closeCount, 1);
    });
  }

  test('download completed after a directory change does not start local restore', () async {
    final service = connect();
    final download = controller.downloadFile(
      webdav.File(path: '/backup.txt', isDir: false),
      confirmRestore: allowRestore,
    );
    await settle();
    expect(service.downloadPaths, ['/backup.txt']);

    controller.dirPath.value = '/other/';
    service.download.complete(utf8.encode('{"backupVersion":3}'));
    await download;

    expect(backup.restores, isEmpty);
    expect(feedback, isEmpty);
  });

  test('upload completion after switching service does not refresh the new service', () async {
    controller.dirPath.value = '/backups/';
    final service = connect();
    final upload = controller.uploadConfigSettings();
    expect(service.uploadPaths.single, startsWith('/backups/purelive_'));
    expect(jsonDecode(utf8.decode(service.uploadBytes.single)), {'backupVersion': 3});
    controller.initializeWebDAV();
    service.upload.complete();
    await upload;
    expect(services.last.reads, hasLength(1));
  });

  test('controller suppresses duplicate uploads even before the button rebuilds', () async {
    final service = connect();
    final first = controller.uploadConfigSettings();
    await controller.uploadConfigSettings();
    expect(service.uploadPaths, hasLength(1));
    expect(controller.isUploading.value, isTrue);
    controller.onClose();
    service.upload.complete();
    await first;
  });

  test('old upload completion does not release the new service upload state', () async {
    final firstService = connect();
    final first = controller.uploadConfigSettings();
    controller.initializeWebDAV();
    final secondService = services.last;
    final second = controller.uploadConfigSettings();
    firstService.upload.complete();
    await first;
    expect(controller.isUploading.value, isTrue);
    expect(secondService.uploadPaths, hasLength(1));
    controller.onClose();
    secondService.upload.complete();
    await second;
  });

  test('delete confirmed after service replacement never removes from either service', () async {
    final service = connect();
    final deletion = controller.deleteFile(webdav.File(path: '/backup.txt'), confirmDelete: confirmDelete);
    controller.initializeWebDAV();
    confirmation.complete(true);
    await deletion;
    expect(service.removals, isEmpty);
    expect(services.last.removals, isEmpty);
  });

  test('delete cancellation leaves the server unchanged', () async {
    final service = connect();
    final deletion = controller.deleteFile(webdav.File(path: '/backup.txt'), confirmDelete: confirmDelete);
    confirmation.complete(false);
    await deletion;
    expect(service.removals, isEmpty);
  });

  test('restore cancellation leaves the server and local settings unchanged', () async {
    final service = connect();

    await controller.downloadFile(webdav.File(path: '/backup.txt'), confirmRestore: () async => false);

    expect(service.downloadPaths, isEmpty);
    expect(backup.restores, isEmpty);
    expect(controller.fileActionLabelKey.value, isEmpty);
  });

  test('restore confirmed after service replacement never reads or changes local settings', () async {
    final service = connect();
    final restoreConfirmation = Completer<bool>();
    final restore = controller.downloadFile(
      webdav.File(path: '/backup.txt'),
      confirmRestore: () => restoreConfirmation.future,
    );
    expect(controller.fileActionLabelKey.value, 'webdav_restoring');

    controller.initializeWebDAV();
    restoreConfirmation.complete(true);
    await restore;

    expect(service.downloadPaths, isEmpty);
    expect(services.last.downloadPaths, isEmpty);
    expect(backup.restores, isEmpty);
    expect(controller.fileActionLabelKey.value, isEmpty);
  });

  test('restore confirmed after changing directory never reads or changes local settings', () async {
    final service = connect();
    final restoreConfirmation = Completer<bool>();
    final restore = controller.downloadFile(
      webdav.File(path: '/backup.txt'),
      confirmRestore: () => restoreConfirmation.future,
    );
    controller.dirPath.value = '/other/';
    restoreConfirmation.complete(true);
    await restore;

    expect(service.downloadPaths, isEmpty);
    expect(backup.restores, isEmpty);
    expect(controller.fileActionLabelKey.value, isEmpty);
  });

  test('repeated restore clicks start only one download', () async {
    final service = connect();
    final first = controller.downloadFile(webdav.File(path: '/backup.txt'), confirmRestore: allowRestore);
    final second = controller.downloadFile(webdav.File(path: '/backup.txt'), confirmRestore: allowRestore);
    await settle();
    final requests = service.downloadPaths.length;
    controller.onClose();
    service.download.complete(utf8.encode('{"backupVersion":3}'));
    await Future.wait([first, second]);
    expect(requests, 1);
  });

  test('repeated delete clicks open only one confirmation', () async {
    connect();
    final first = controller.deleteFile(webdav.File(path: '/backup.txt'), confirmDelete: confirmDelete);
    final second = controller.deleteFile(webdav.File(path: '/backup.txt'), confirmDelete: confirmDelete);
    confirmation.complete(false);
    await Future.wait([first, second]);
    expect(confirmationCount, 1);
    expect(controller.canStartFileAction, isTrue);
  });

  test('confirmation failure releases the operation without deleting anything', () async {
    final service = connect();
    final deletion = controller.deleteFile(webdav.File(path: '/backup.txt'), confirmDelete: confirmDelete);
    confirmation.completeError(StateError('confirmation fixture'));
    await deletion;
    expect(service.removals, isEmpty);
    expect(controller.fileActionLabelKey.value, isEmpty);
    expect(controller.canUpload, isTrue);
    expect(feedback.single, contains('confirmation fixture'));
  });

  test('changing configuration does not allow exporting during a pending local restore', () async {
    final service = connect();
    backup.pendingRestore = Completer<void>();
    final download = controller.downloadFile(webdav.File(path: '/backup.txt'), confirmRestore: allowRestore);
    service.download.complete(utf8.encode('{"backupVersion":3}'));
    await settle();
    expect(backup.restores, hasLength(1));
    controller.initializeWebDAV();
    await controller.uploadConfigSettings();
    expect(services.last.uploadPaths, isEmpty);
    expect(controller.canUpload, isFalse);
    backup.pendingRestore!.complete();
    await download;
    expect(controller.canUpload, isTrue);
  });

  test('an in-flight upload prevents a conflicting restore download', () async {
    final service = connect();
    final upload = controller.uploadConfigSettings();
    final download = controller.downloadFile(webdav.File(path: '/backup.txt'), confirmRestore: allowRestore);
    final downloads = service.downloadPaths.length;
    controller.onClose();
    service.upload.complete();
    service.download.complete(utf8.encode('{"backupVersion":3}'));
    await Future.wait([upload, download]);
    expect(downloads, 0);
  });

  test('an in-flight restore prevents exporting a new backup', () async {
    final service = connect();
    final download = controller.downloadFile(webdav.File(path: '/backup.txt'), confirmRestore: allowRestore);
    final upload = controller.uploadConfigSettings();
    final uploads = service.uploadPaths.length;
    controller.onClose();
    service.upload.complete();
    service.download.complete(utf8.encode('{"backupVersion":3}'));
    await Future.wait([download, upload]);
    expect(uploads, 0);
  });

  test('directory items never start a backup download', () async {
    final service = connect();
    await controller.downloadFile(webdav.File(path: '/folder/', isDir: true), confirmRestore: allowRestore);
    expect(service.downloadPaths, isEmpty);
    expect(backup.restores, isEmpty);
  });
}

class _Service extends WebDAVService {
  _Service() : super(url: 'http://127.0.0.1', username: '', password: '');
  final reads = <Completer<List<webdav.File>>>[];
  final paths = <String>[];
  int closeCount = 0;
  final downloadPaths = <String>[];
  final download = Completer<List<int>>();
  final uploadPaths = <String>[];
  final uploadBytes = <List<int>>[];
  final upload = Completer<void>();
  final removals = <String>[];

  @override
  void close() {
    closeCount++;
    super.close();
  }

  @override
  Future<List<int>> readFile(String path) {
    downloadPaths.add(path);
    return download.future;
  }

  @override
  Future<void> writeFile(String path, List<int> bytes) {
    uploadPaths.add(path);
    uploadBytes.add(bytes);
    return upload.future;
  }

  @override
  Future<void> removeFile(String path) async => removals.add(path);

  @override
  Future<List<webdav.File>> readDirectory(String path) {
    paths.add(path);
    final pending = Completer<List<webdav.File>>();
    reads.add(pending);
    return pending.future;
  }
}

class _BackupController extends BackupController {
  final restores = <Map<String, dynamic>>[];
  Completer<void>? pendingRestore;

  @override
  Map<String, dynamic> exportAllSettings({bool includeSensitiveData = false}) => {'backupVersion': 3};

  @override
  Future<void> restoreAllSettings(Map<String, dynamic> data) async {
    restores.add(data);
    await pendingRestore?.future;
  }
}
