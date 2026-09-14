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

  testWidgets('confirmation content scrolls while both decisions remain reachable at large text', (tester) async {
    bool? result;
    await _pumpLauncher(
      tester,
      onPressed: () async {
        result = await Utils.showAlertDialog(
          List.filled(12, 'This action has important details that must stay readable.').join('\n'),
          title: 'Confirm action',
          confirm: 'Confirm',
          cancel: 'Cancel',
          selectable: true,
        );
      },
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(SelectableText), findsOneWidget);
    expect(find.text('Cancel').hitTestable(), findsOneWidget);
    expect(find.text('Confirm').hitTestable(), findsOneWidget);
    expect(tester.getRect(find.text('Cancel')).bottom, lessThanOrEqualTo(480));
    expect(tester.getRect(find.text('Confirm')).bottom, lessThanOrEqualTo(480));

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('single-action message keeps its acknowledgement reachable at large text', (tester) async {
    bool? result;
    await _pumpLauncher(
      tester,
      onPressed: () async {
        result = await Utils.showMessageDialog(
          List.filled(12, 'A detailed result remains available without covering the action.').join('\n'),
          title: 'Operation result',
          confirm: 'OK',
        );
      },
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('OK').hitTestable(), findsOneWidget);
    expect(tester.getRect(find.text('OK')).bottom, lessThanOrEqualTo(480));

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpLauncher(WidgetTester tester, {required VoidCallback onPressed}) async {
  tester.view.physicalSize = const Size(320, 480);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    GetMaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(3)),
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
