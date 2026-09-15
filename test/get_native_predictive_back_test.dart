import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/style/theme.dart';
import 'package:pure_live/get/get.dart';

final TestWidgetsFlutterBinding _binding = TestWidgetsFlutterBinding.ensureInitialized();

Future<void> _sendBackGesture(MethodCall call) async {
  final ByteData message = const StandardMethodCodec().encodeMethodCall(call);
  await _binding.defaultBinaryMessenger.handlePlatformMessage('flutter/backgesture', message, (ByteData? _) {});
}

Future<void> _startAndUpdateBackGesture(WidgetTester tester) async {
  await _sendBackGesture(
    const MethodCall('startBackGesture', <String, dynamic>{
      'touchOffset': <double>[5.0, 300.0],
      'progress': 0.0,
      'swipeEdge': 0,
    }),
  );
  await tester.pump();

  await _sendBackGesture(
    const MethodCall('updateBackGestureProgress', <String, dynamic>{
      'touchOffset': <double>[100.0, 300.0],
      'progress': 0.35,
      'swipeEdge': 0,
    }),
  );
  await tester.pump();
}

Widget _getApp({PageTransitionsBuilder? androidTransitionBuilder}) {
  final PageTransitionsBuilder transitionBuilder =
      androidTransitionBuilder ?? const PredictiveBackPageTransitionsBuilder();

  return GetMaterialApp(
    initialRoute: '/home',
    defaultTransition: Transition.native,
    theme: ThemeData(
      platform: TargetPlatform.android,
      pageTransitionsTheme: PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{TargetPlatform.android: transitionBuilder},
      ),
    ),
    getPages: <GetPage<dynamic>>[
      GetPage<void>(
        name: '/home',
        page: () => Scaffold(
          body: Center(
            child: TextButton(onPressed: () => Get.toNamed<void>('/secondary'), child: const Text('open secondary')),
          ),
        ),
      ),
      GetPage<void>(
        name: '/secondary',
        page: () => const Scaffold(body: Center(child: Text('secondary page'))),
      ),
    ],
  );
}

Future<GetPageRoute<dynamic>> _openSettledSecondaryPage(
  WidgetTester tester, {
  PageTransitionsBuilder? androidTransitionBuilder,
}) async {
  await tester.pumpWidget(_getApp(androidTransitionBuilder: androidTransitionBuilder));
  await tester.pumpAndSettle();
  await tester.tap(find.text('open secondary'));
  await tester.pumpAndSettle();

  final BuildContext context = tester.element(find.text('secondary page'));
  final ModalRoute<dynamic>? route = ModalRoute.of(context);
  expect(route, isA<GetPageRoute<dynamic>>());
  expect(route!.isCurrent, isTrue);
  expect(route.animation!.isCompleted, isTrue);
  expect(route.popGestureEnabled, isTrue);
  return route as GetPageRoute<dynamic>;
}

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(() {
    Get.reset();
    Get.testMode = false;
  });

  testWidgets('settled GetPageRoute commits an Android predictive back gesture', (WidgetTester tester) async {
    final GetPageRoute<dynamic> route = await _openSettledSecondaryPage(
      tester,
      androidTransitionBuilder: const PredictiveBackPageTransitionsBuilder(),
    );

    await _startAndUpdateBackGesture(tester);
    expect(route.popGestureInProgress, isTrue);
    expect(route.animation!.value, lessThan(1.0));

    await _sendBackGesture(const MethodCall('commitBackGesture'));
    await tester.pumpAndSettle();

    expect(find.text('secondary page'), findsNothing);
    expect(find.text('open secondary'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('settled GetPageRoute restores after an Android predictive back cancellation', (
    WidgetTester tester,
  ) async {
    final GetPageRoute<dynamic> route = await _openSettledSecondaryPage(
      tester,
      androidTransitionBuilder: const PredictiveBackPageTransitionsBuilder(),
    );

    await _startAndUpdateBackGesture(tester);
    expect(route.popGestureInProgress, isTrue);
    expect(route.animation!.value, lessThan(1.0));

    await _sendBackGesture(const MethodCall('cancelBackGesture'));
    await tester.pumpAndSettle();

    expect(find.text('secondary page'), findsOneWidget);
    expect(find.text('open secondary'), findsNothing);
    expect(route.isCurrent, isTrue);
    expect(route.popGestureInProgress, isFalse);
    expect(route.animation!.isCompleted, isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('Transition.native uses the PageTransitionsTheme builder', (WidgetTester tester) async {
    var buildCount = 0;
    final _ProbePageTransitionsBuilder probe = _ProbePageTransitionsBuilder(onBuild: () => buildCount++);

    await tester.pumpWidget(_getApp(androidTransitionBuilder: probe));
    await tester.pumpAndSettle();
    buildCount = 0;
    await tester.tap(find.text('open secondary'));
    await tester.pumpAndSettle();

    final BuildContext context = tester.element(find.text('secondary page'));
    expect(Theme.of(context).pageTransitionsTheme.builders[TargetPlatform.android], same(probe));
    expect(buildCount, greaterThan(0));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  test('app Android transitions avoid the gesture-owned predictive builder', () {
    expect(appPageTransitionsTheme.builders[TargetPlatform.android], isA<FadeForwardsPageTransitionsBuilder>());
    expect(
      appPageTransitionsTheme.builders[TargetPlatform.android],
      isNot(isA<PredictiveBackPageTransitionsBuilder>()),
    );
    expect(appPageTransitionsTheme.builders[TargetPlatform.windows], isA<FadeForwardsPageTransitionsBuilder>());
  });

  testWidgets('app Android transition commits system back through the navigator fallback', (WidgetTester tester) async {
    final PageTransitionsBuilder transitionBuilder = appPageTransitionsTheme.builders[TargetPlatform.android]!;
    final GetPageRoute<dynamic> route = await _openSettledSecondaryPage(
      tester,
      androidTransitionBuilder: transitionBuilder,
    );

    await _startAndUpdateBackGesture(tester);
    expect(route.isCurrent, isTrue);
    expect(route.popGestureInProgress, isFalse);
    expect(route.animation!.isCompleted, isTrue);

    await _sendBackGesture(const MethodCall('commitBackGesture'));
    await tester.pumpAndSettle();

    expect(find.text('secondary page'), findsNothing);
    expect(find.text('open secondary'), findsOneWidget);

    await tester.tap(find.text('open secondary'));
    await tester.pumpAndSettle();
    expect(find.text('secondary page'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('app Android transition keeps the current route when system back is canceled', (
    WidgetTester tester,
  ) async {
    final PageTransitionsBuilder transitionBuilder = appPageTransitionsTheme.builders[TargetPlatform.android]!;
    final GetPageRoute<dynamic> route = await _openSettledSecondaryPage(
      tester,
      androidTransitionBuilder: transitionBuilder,
    );

    await _startAndUpdateBackGesture(tester);
    expect(route.isCurrent, isTrue);
    expect(route.popGestureInProgress, isFalse);

    await _sendBackGesture(const MethodCall('cancelBackGesture'));
    await tester.pumpAndSettle();

    expect(find.text('secondary page'), findsOneWidget);
    expect(find.text('open secondary'), findsNothing);
    expect(route.isCurrent, isTrue);
    expect(route.animation!.isCompleted, isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}

class _ProbePageTransitionsBuilder extends PageTransitionsBuilder {
  _ProbePageTransitionsBuilder({required this.onBuild});

  final VoidCallback onBuild;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    onBuild();
    return child;
  }
}
