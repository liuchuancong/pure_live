import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/services/settings/backup_controller.dart';
import 'package:pure_live/common/services/settings/font_settings_controller.dart';
import 'package:pure_live/common/services/settings/log_controller.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/modules/auth/auth_controller.dart';
import 'package:pure_live/modules/backup/backup_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late FilePickerPlatform originalPicker;
  late _DirectoryPicker picker;
  late _BackupController backup;
  late Map<String, dynamic> translations;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('pure-live-backup-page-');
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    Hive.init(directory.path);
    await HivePrefUtil.init();
    translations = jsonDecode(await File('assets/translations/zh.json').readAsString()) as Map<String, dynamic>;
  });

  setUp(() {
    Get.testMode = true;
    originalPicker = FilePickerPlatform.instance;
    picker = _DirectoryPicker();
    FilePickerPlatform.instance = picker;
    backup = Get.put<BackupController>(_BackupController()) as _BackupController;
    Get.put<SettingsService>(_SettingsService());
    Get.put<LogController>(LogController());
    Get.put<AuthController>(_AuthController());
  });

  tearDown(() {
    FilePickerPlatform.instance = originalPicker;
    Get.deleteAll(force: true);
    Get.reset();
  });

  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Future<void> finish(WidgetTester tester) async {
    // Let the toast's own two-second timer finish inside the widget fake clock.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  Future<void> openPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('zh')],
        path: 'assets/translations',
        assetLoader: _MemoryAssetLoader(translations),
        child: Builder(
          builder: (context) => GetMaterialApp(
            locale: context.locale,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            builder: FlutterSmartDialog.init(),
            home: const BackupPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> createBackup(WidgetTester tester) async {
    await tester.tap(find.text('创建备份'));
    await tester.pumpAndSettle();
  }

  testWidgets('first backup opens one directory picker and cancellation keeps the empty preference', (tester) async {
    await openPage(tester);
    await createBackup(tester);
    expect(picker.initialDirectories, [null]);
    expect(backup.destinations, isEmpty);
    expect(backup.backupDirectory.value, isEmpty);
    await finish(tester);
  });

  testWidgets('first successful backup remembers the selected directory without a separate settings step', (
    tester,
  ) async {
    picker.result = directory.path;
    await openPage(tester);
    await createBackup(tester);
    expect(picker.initialDirectories, [null]);
    expect(backup.destinations, hasLength(1));
    expect(backup.destinations.single.parent.path, directory.path);
    expect(backup.backupDirectory.value, directory.path);
    await finish(tester);
  });

  testWidgets('favorites export has a distinct file and remembers its first directory', (tester) async {
    picker.result = directory.path;
    await openPage(tester);
    await tester.tap(find.text('仅导出关注列表'));
    await tester.pumpAndSettle();
    expect(backup.favoriteDestinations, hasLength(1));
    expect(backup.favoriteDestinations.single.path, contains('purelive_favorites_'));
    expect(backup.destinations, isEmpty);
    expect(backup.backupDirectory.value, directory.path);
    await finish(tester);
  });

  testWidgets('failed first export leaves the backup directory unset', (tester) async {
    picker.result = directory.path;
    backup.succeeds = false;
    await openPage(tester);
    await createBackup(tester);
    expect(picker.initialDirectories, [null]);
    expect(backup.destinations, hasLength(1));
    expect(backup.backupDirectory.value, isEmpty);
    await finish(tester);
  });

  testWidgets('existing directory is a picker hint and cancellation preserves it', (tester) async {
    backup.backupDirectory.value = directory.path;
    await openPage(tester);
    await createBackup(tester);
    expect(picker.initialDirectories, [directory.path]);
    expect(backup.destinations, isEmpty);
    expect(backup.backupDirectory.value, directory.path);
    await finish(tester);
  });
}

class _MemoryAssetLoader extends AssetLoader {
  _MemoryAssetLoader(this.data);
  final Map<String, dynamic> data;

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => data;
}

class _DirectoryPicker extends FilePickerPlatform {
  final initialDirectories = <String?>[];
  String? result;

  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    String? initialDirectory,
    AndroidOptions androidOptions = const AndroidOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    initialDirectories.add(initialDirectory);
    return result;
  }
}

// Observe the real page/service orchestration without file IO in a widget's
// fake clock. Real export payloads and persistence have separate roundtrip tests.
class _BackupController extends BackupController {
  final _directory = ''.obs;
  final destinations = <File>[];
  final favoriteDestinations = <File>[];
  bool succeeds = true;

  @override
  RxString get backupDirectory => _directory;

  @override
  Future<void> setBackupDirectoryDurably(String directory) async {
    _directory.value = directory;
  }

  @override
  Future<bool> backup(File file) async {
    destinations.add(file);
    return succeeds;
  }

  @override
  Future<bool> backupFavorites(File file) async {
    favoriteDestinations.add(file);
    return succeeds;
  }
}

class _SettingsService extends SettingsService {
  final _font = FontSettingsController();

  @override
  FontSettingsController get font => _font;

  @override
  // The page only needs the explicitly registered backup/log settings.
  // ignore: must_call_super
  void onInit() {}
}

class _AuthController extends AuthController {
  @override
  // Do not connect to a user's Firebase account from a widget fixture.
  // ignore: must_call_super
  void onInit() {}
}
