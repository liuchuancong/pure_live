import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/services/settings/room_card_settings_controller.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/get/get.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('pure-live-room-card-settings-');
    Hive.init(directory.path);
    await HivePrefUtil.init();
  });

  setUp(() async {
    Get.testMode = true;
    Get.reset();
    await HivePrefUtil.clear();
  });

  tearDown(() async {
    Get.reset();
    await HivePrefUtil.flush();
  });

  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('mobile and desktop presets remain independent and persist canonical config', () async {
    final controller = Get.put(RoomCardSettingsController());

    controller.applyPreset(RoomCardViewport.mobile, RoomCardPreset.compact);
    controller.applyPreset(RoomCardViewport.desktop, RoomCardPreset.detailed);

    expect(controller.configFor(RoomCardViewport.mobile), RoomCardAppearance.compact);
    expect(controller.configFor(RoomCardViewport.desktop), RoomCardAppearance.detailed);
    expect(controller.presetFor(RoomCardViewport.mobile), RoomCardPreset.compact);
    expect(controller.presetFor(RoomCardViewport.desktop), RoomCardPreset.detailed);

    await Future<void>.delayed(Duration.zero);
    await HivePrefUtil.flush();
    expect(HivePrefUtil.getString('room_card_mobile_preset'), 'compact');
    expect(HivePrefUtil.getString('room_card_desktop_preset'), 'rich');
    expect(jsonDecode(HivePrefUtil.getString('room_card_mobile_config')!), RoomCardAppearance.compact.toJson());
  });

  test('individual changes become custom and normalize the radius', () {
    final controller = Get.put(RoomCardSettingsController());
    final changed = controller.configFor(RoomCardViewport.mobile).copyWith(showPlatformBadge: true, cornerRadius: 100);

    controller.updateConfig(RoomCardViewport.mobile, changed);

    expect(controller.presetFor(RoomCardViewport.mobile), RoomCardPreset.custom);
    expect(controller.configFor(RoomCardViewport.mobile).showPlatformBadge, isTrue);
    expect(controller.configFor(RoomCardViewport.mobile).cornerRadius, RoomCardAppearance.maxCornerRadius);
  });

  test('existing 3.1.2 room card values migrate through compatible storage keys', () async {
    await HivePrefUtil.setString('room_card_mobile_preset', 'custom');
    await HivePrefUtil.setString(
      'room_card_mobile_config',
      jsonEncode({
        'showAvatar': false,
        'showSubtitle': true,
        'showPlatform': true,
        'showAudience': false,
        'showRecordBadge': false,
        'cardBorderRadius': 27,
      }),
    );

    final controller = Get.put(RoomCardSettingsController());
    final mobile = controller.configFor(RoomCardViewport.mobile);

    expect(mobile.showAvatar, isFalse);
    expect(mobile.showAnchorName, isTrue);
    expect(mobile.showPlatformBadge, isTrue);
    expect(mobile.showAudience, isFalse);
    expect(mobile.showReplayBadge, isFalse);
    expect(mobile.cornerRadius, 27);
    expect(controller.presetFor(RoomCardViewport.mobile), RoomCardPreset.custom);
  });

  test('backup parsing supports current and flattened legacy shapes with strict nested types', () {
    final current = RoomCardSettingsController.parseConfig({'mobilePreset': 'compact', 'desktopPreset': 'rich'});
    expect(current['mobileConfig'], RoomCardAppearance.compact);
    expect(current['desktopConfig'], RoomCardAppearance.detailed);

    final legacy = RoomCardSettingsController.extractConfig({
      'room_card_mobile_preset': 'custom',
      'room_card_mobile_config': jsonEncode({'showAvatar': false, 'showSubtitle': false, 'cardBorderRadius': 8}),
    });
    expect(legacy['mobileConfig']['showAvatar'], isFalse);
    expect(legacy['mobileConfig']['showAnchorName'], isFalse);
    expect(legacy['mobileConfig']['cornerRadius'], 8);

    expect(
      () => RoomCardSettingsController.parseConfig({
        'mobileConfig': {'showAvatar': 'yes'},
      }),
      throwsFormatException,
    );
    expect(
      () => RoomCardSettingsController.parseConfig({
        'desktopConfig': {'cornerRadius': double.infinity},
      }),
      throwsFormatException,
    );
  });
}
