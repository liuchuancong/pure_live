import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/core/storage/hive_pref_util.dart';
import 'package:pure_live/domains/recorder/data/consts/recorder_config.dart';
import 'package:pure_live/domains/recorder/data/record_settings_controller.dart';
import 'package:pure_live/get/get.dart';

/// The Android public-directory pick must not persist a path the app cannot
/// actually write. Before this, `pickRecordDir` probed the fresh path without
/// ever requesting storage access, so an ungranted `MANAGE_EXTERNAL_STORAGE`
/// turned every public-directory choice into a bare "path or permission" error.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (call) async => call.method == 'getAll' ? <String, Object>{} : true,
    );
    await EasyLocalization.ensureInitialized();
    await Hive.openBox<dynamic>('app_settings', bytes: Uint8List(0));
    await HivePrefUtil.init();
    Get.testMode = true;
  });

  tearDownAll(() async {
    await Hive.close();
  });

  test('denied storage access leaves the recording path unchanged', () async {
    const picked = '/storage/emulated/0/Download';
    var permissionRequested = false;
    final controller = RecordSettingsController(
      directoryPicker: () async => picked,
      storagePermission: () async {
        permissionRequested = true;
        return false;
      },
    );

    await controller.pickRecordDir();

    expect(permissionRequested, isTrue, reason: 'the pick must request access before writing');
    expect(controller.recordSavePath.value, isNot(picked), reason: 'a denied pick must not be adopted');
    expect(RecorderConfig.recordSavePath, isNot(picked), reason: 'a denied pick must not be persisted');
  });
}
