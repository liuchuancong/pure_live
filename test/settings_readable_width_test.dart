import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/common/widgets/widget_extensions.dart';
import 'package:pure_live/get/get.dart';

void main() {
  setUpAll(() async {
    Hive.init('.dart_tool/test_hive_readable_width');
    await Hive.openBox<dynamic>('app_settings', bytes: Uint8List(0));
    await HivePrefUtil.init();
  });
  tearDownAll(Hive.close);

  Future<Rect> cardRect(WidgetTester tester, double width) async {
    if (!Get.isRegistered<SettingsService>()) Get.put(SettingsService(), permanent: true);
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ListView(
              children: [
                context.buildGroupTitle('Group'),
                context.buildModernCard([const ListTile(key: ValueKey('row'), title: Text('Row'))]),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester.getRect(find.byKey(const ValueKey('row')));
  }

  testWidgets('settings cards are capped and centred on wide windows', (tester) async {
    final rect = await cardRect(tester, 1800);
    expect(rect.width, settingsContentMaxWidth);
    expect(rect.center.dx, closeTo(900, 1));
    expect(tester.getRect(find.text('Group')).left, greaterThanOrEqualTo(rect.left));
  });

  testWidgets('settings cards still fill narrow windows', (tester) async {
    final rect = await cardRect(tester, 400);
    expect(rect.width, 400);
  });
}
