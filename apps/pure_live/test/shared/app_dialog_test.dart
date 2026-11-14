import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/l10n/translations.g.dart';
import 'package:pure_live/shared/widgets/app_dialog.dart';
import 'package:pure_live/shared/widgets/app_panel.dart';

/// Pumps the app's dialog scaffold with a trigger: the route opens on a
/// press, the way the pages open theirs.
Future<void> pumpTrigger(WidgetTester tester, VoidCallback onTrigger) async {
  await tester.pumpWidget(
    TranslationProvider(
      child: DsScope(
        child: UncontrolledProviderScope(
          container: ProviderContainer(),
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: DsButton(variant: DsButtonVariant.secondary, onPressed: onTrigger, child: const Text('打开')),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a bare confirm still reads as a card, not a strip', (tester) async {
    late Future<bool> asked;
    await pumpTrigger(tester, () {
      final context = tester.state(find.byType(Scaffold)).context;
      asked = showAppConfirm(context: context, title: '删除房间？', confirmLabel: '删除', cancelLabel: '留着');
    });

    expect(find.text('删除房间？'), findsOneWidget);
    // The card: the floor under the words plus the title and the actions —
    // never the two text lines the old bare confirm collapsed to.
    final card = tester.getSize(find.byType(DsSurface));
    expect(card.height, greaterThanOrEqualTo(200), reason: 'the dialog keeps its floor');

    // The answer comes from the actions, not the route.
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(await asked, isTrue);
  });

  testWidgets('cancel answers no, and no icon disk rides above the title', (tester) async {
    late Future<bool> asked;
    await pumpTrigger(tester, () {
      final context = tester.state(find.byType(Scaffold)).context;
      asked = showAppConfirm(context: context, title: '清空历史？', confirmLabel: '清空', cancelLabel: '取消');
    });

    expect(find.byType(DsIcon), findsNothing, reason: 'the dialogs dropped the tone disk');
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(await asked, isFalse);
  });

  testWidgets('a short sheet keeps its floor; zero keeps the hug', (tester) async {
    // A narrow window: the sheet opens from the bottom, where the hug is.
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> openSheet(double minChildHeight) async {
      await pumpTrigger(tester, () {
        final context = tester.state(find.byType(Scaffold)).context;
        unawaited(
          showAppPanel<void>(
            context: context,
            builder: (context) => AppPanel(
              title: const Text('更多操作'),
              minChildHeight: minChildHeight,
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: DsSpace.s12,
                children: [Text('一行动作'), Text('再一行动作')],
              ),
            ),
          ),
        );
      });
      await tester.pumpAndSettle();
    }

    await openSheet(kAppPanelContentFloor);
    final floored = tester.getSize(find.byType(SingleChildScrollView));
    expect(floored.height, greaterThanOrEqualTo(kAppPanelContentFloor - 1), reason: 'the content keeps its floor');
    // Close via the route: a fresh sheet for the hug case.
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();

    await openSheet(0);
    final hugged = tester.getSize(find.byType(SingleChildScrollView));
    expect(hugged.height, lessThan(kAppPanelContentFloor), reason: 'zero keeps the kit’s own hug');
  });
}
