import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/models/live_area.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/modules/areas/widgets/area_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Hive.openBox<dynamic>('app_settings', bytes: Uint8List(0));
    await HivePrefUtil.init();
  });

  setUp(() {
    Get.testMode = true;
    Get.reset();
    Get.put(SettingsService(), permanent: true);
  });

  tearDown(Get.reset);
  tearDownAll(Hive.close);

  for (final textScale in [1.0, 2.0, 3.0]) {
    testWidgets('narrow three-column area card fits at ${textScale}x text', (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final area = LiveArea(
        platform: 'fixture',
        areaId: '1',
        areaName: 'A long category label',
        typeName: 'A long parent category',
        areaPic: '',
      );

      await tester.pumpWidget(
        GetMaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(
            body: LayoutBuilder(
              builder: (context, constraints) {
                const columns = 3;
                const spacing = 8.0;
                final itemWidth = (constraints.maxWidth - 12 - spacing * (columns - 1)) / columns;
                return GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: spacing,
                    mainAxisExtent: areaCardGridMainAxisExtent(context, itemWidth),
                  ),
                  itemCount: 1,
                  itemBuilder: (_, _) => AreaCard(category: area),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AreaCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
