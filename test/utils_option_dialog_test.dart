import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/plugins/utils.dart';

void main() {
  setUp(() {
    Get.reset();
    Get.testMode = true;
  });

  tearDown(() {
    Get.reset();
    Get.testMode = false;
  });

  testWidgets('long options remain readable and selectable in a narrow large-text viewport', (tester) async {
    final options = List.generate(12, (index) => 'Detailed login method $index');
    String? result;
    await _pumpLauncher(
      tester,
      onPressed: () async {
        result = await Utils.showOptionDialog(options, options.first, title: 'Select method');
      },
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(Radio<String>), findsNWidgets(options.length));
    expect(tester.widget<RadioGroup<String>>(find.byType(RadioGroup<String>)).groupValue, options.first);

    final lastOption = find.text(options.last);
    await tester.scrollUntilVisible(lastOption, 120, scrollable: find.byType(Scrollable).last);
    expect(lastOption.hitTestable(), findsOneWidget);

    final lastRow = find.byKey(const ValueKey<String>('shared-option-11'));
    final rowRect = tester.getRect(lastRow);
    await tester.tapAt(Offset(rowRect.right - 8, rowRect.center.dy));
    await tester.pumpAndSettle();
    expect(result, options.last);
    expect(tester.takeException(), isNull);
  });

  testWidgets('system back dismisses the option dialog with a null result', (tester) async {
    String? result = 'pending';
    await _pumpLauncher(
      tester,
      onPressed: () async {
        result = await Utils.showOptionDialog(
          const ['SMS login', 'QR code login'],
          'SMS login',
          title: 'Select login method',
        );
      },
      textScale: 1,
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    expect(find.text('Select login method'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpLauncher(WidgetTester tester, {required VoidCallback onPressed, double textScale = 3}) async {
  tester.view.physicalSize = const Size(320, 480);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    GetMaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Center(
          child: FilledButton(onPressed: onPressed, child: const Text('Open dialog')),
        ),
      ),
    ),
  );
  await tester.pump();
  expect(tester.takeException(), isNull);
}
