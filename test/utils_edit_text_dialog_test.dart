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

  testWidgets('shared text editor owns its controller through the exit transition', (tester) async {
    String? result;

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await Utils.showEditTextDialog(
                  'initial',
                  title: 'Edit value',
                  confirm: 'Save',
                  cancel: 'Cancel',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(TextButton), findsOneWidget);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'updated value');
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(result, 'updated value');
  });

  testWidgets('shared text editor keeps its field and actions reachable in a narrow large-text window', (tester) async {
    String? result = 'pending';
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
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await Utils.showEditTextDialog(
                  'initial',
                  title: 'Edit a long configuration value',
                  confirm: 'Save',
                  cancel: 'Cancel',
                );
              },
              child: const Text('Open editor'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(TextButton), findsOneWidget);

    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(tester.getRect(find.text('Cancel')).bottom, lessThanOrEqualTo(480));
    expect(tester.getRect(find.text('Save')).bottom, lessThanOrEqualTo(480));

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(result, isNull);
  });
}
