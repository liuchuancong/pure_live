import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/modules/live_play/widgets/layout/live_play_back_scope.dart';

void main() {
  late GlobalKey<NavigatorState> navigatorKey;

  setUp(() {
    navigatorKey = GlobalKey<NavigatorState>();
  });

  Widget app() {
    return MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: Text('home')),
    );
  }

  Future<void> openRoom(
    WidgetTester tester, {
    required ValueNotifier<bool> presentationActive,
    required VoidCallback onExitPresentation,
  }) async {
    await tester.pumpWidget(app());
    navigatorKey.currentState!.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ValueListenableBuilder<bool>(
          valueListenable: presentationActive,
          builder: (_, active, _) => LivePlayBackScope(
            presentationActive: active,
            onExitPresentation: onExitPresentation,
            child: const Scaffold(body: Text('room')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('normal room system back pops the route', (tester) async {
    final presentationActive = ValueNotifier<bool>(false);
    addTearDown(presentationActive.dispose);
    await openRoom(
      tester,
      presentationActive: presentationActive,
      onExitPresentation: () => fail('normal room must not intercept system back'),
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('room'), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('fullscreen back restores normal presentation before route pop', (tester) async {
    final presentationActive = ValueNotifier<bool>(true);
    addTearDown(presentationActive.dispose);
    var exitCount = 0;
    await openRoom(
      tester,
      presentationActive: presentationActive,
      onExitPresentation: () {
        exitCount++;
        presentationActive.value = false;
      },
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(exitCount, 1);
    expect(find.text('room'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(exitCount, 1);
    expect(find.text('room'), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('dialog receives system back before the live room', (tester) async {
    final presentationActive = ValueNotifier<bool>(true);
    addTearDown(presentationActive.dispose);
    var exitCount = 0;
    await openRoom(
      tester,
      presentationActive: presentationActive,
      onExitPresentation: () => exitCount++,
    );
    showDialog<void>(
      context: navigatorKey.currentContext!,
      builder: (_) => const AlertDialog(title: Text('menu')),
    );
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('menu'), findsNothing);
    expect(find.text('room'), findsOneWidget);
    expect(exitCount, 0);
  });
}
