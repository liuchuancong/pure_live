import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/bootstrap/splash_screen.dart';
import 'package:pure_uikit/pure_uikit.dart';

void main() {
  Future<int?> pumpSplash(WidgetTester tester, {required Future<void> Function() tap, Duration? duration}) async {
    var presses = 0;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      PureConfigProvider(
        config: const UiConfig(language: PureDesignLanguage.material),
        child: MaterialApp(
          home: SplashScreen(
            logo: const Icon(Icons.live_tv_rounded),
            showTextLogo: true,
            logoText: '欢迎使用',
            loaderType: LoaderType.progressBar,
            duration: duration ?? const Duration(milliseconds: 400),
            onNextPressed: () => presses++,
          ),
        ),
      ),
    );
    await tester.pump();
    await tap();
    return presses;
  }

  testWidgets('a tap hands over before the timer', (tester) async {
    final presses = await pumpSplash(
      tester,
      duration: const Duration(seconds: 1),
      tap: () async {
        await tester.tap(find.byKey(const ValueKey('splash')));
        await tester.pump();
      },
    );
    expect(presses, 1);
    // The timer, had it run, would not press a second time.
    await tester.pump(const Duration(seconds: 1, milliseconds: 100));
    expect(presses, 1);
  });

  testWidgets('no tap lets the duration hand over', (tester) async {
    var presses = 0;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      PureConfigProvider(
        config: const UiConfig(language: PureDesignLanguage.material),
        child: MaterialApp(
          home: SplashScreen(
            logo: const Icon(Icons.live_tv_rounded),
            loaderType: LoaderType.progressBar,
            duration: const Duration(milliseconds: 300),
            onNextPressed: () => presses++,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(presses, 1);
  });

  testWidgets('the pieces carry the reference keys', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      PureConfigProvider(
        config: const UiConfig(language: PureDesignLanguage.material),
        child: MaterialApp(
          home: SplashScreen(
            logo: const Icon(Icons.live_tv_rounded),
            showTextLogo: true,
            logoText: '欢迎使用',
            loaderType: LoaderType.progressBar,
            duration: const Duration(seconds: 1),
            onNextPressed: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('splash')), findsOneWidget);
    expect(find.byKey(const ValueKey('splash-background')), findsOneWidget);
    expect(find.byKey(const ValueKey('splash-logo')), findsOneWidget);
    expect(find.byKey(const ValueKey('splash-progress')), findsOneWidget);
  });
}
