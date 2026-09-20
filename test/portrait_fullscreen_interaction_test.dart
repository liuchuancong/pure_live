import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/modules/live_play/widgets/layout/portrait_fullscreen_interaction.dart';

void main() {
  group('portrait fullscreen entry gate', () {
    test('requires a mobile adaptive portrait source', () {
      expect(
        canEnterPortraitPanelFullscreen(
          isPortraitSource: true,
          adaptationEnabled: true,
          adaptiveHeightEnabled: true,
          compatibilityLayout: false,
          mobilePlatform: true,
        ),
        isTrue,
      );

      for (final blocked in <({bool portrait, bool adaptation, bool height, bool compatibility, bool mobile})>[
        (portrait: false, adaptation: true, height: true, compatibility: false, mobile: true),
        (portrait: true, adaptation: false, height: true, compatibility: false, mobile: true),
        (portrait: true, adaptation: true, height: false, compatibility: false, mobile: true),
        (portrait: true, adaptation: true, height: true, compatibility: true, mobile: true),
        (portrait: true, adaptation: true, height: true, compatibility: false, mobile: false),
      ]) {
        expect(
          canEnterPortraitPanelFullscreen(
            isPortraitSource: blocked.portrait,
            adaptationEnabled: blocked.adaptation,
            adaptiveHeightEnabled: blocked.height,
            compatibilityLayout: blocked.compatibility,
            mobilePlatform: blocked.mobile,
          ),
          isFalse,
        );
      }
    });

    test('commits only a deliberate distance or downward fling', () {
      expect(
        resolvePortraitPanelDragEnd(entryEnabled: true, dismissOffset: 96, panelHeight: 240, velocity: 0),
        PortraitPanelDragDisposition.enterFullscreen,
      );
      expect(
        resolvePortraitPanelDragEnd(entryEnabled: true, dismissOffset: 32, panelHeight: 240, velocity: 1100),
        PortraitPanelDragDisposition.enterFullscreen,
      );
      expect(
        resolvePortraitPanelDragEnd(entryEnabled: true, dismissOffset: 24, panelHeight: 240, velocity: 0),
        PortraitPanelDragDisposition.restorePanel,
      );
      expect(
        resolvePortraitPanelDragEnd(entryEnabled: false, dismissOffset: 240, panelHeight: 240, velocity: 1600),
        PortraitPanelDragDisposition.restorePanel,
      );
    });

    test('bottom-edge restore requires an upward intent', () {
      expect(shouldRestorePortraitPanelFromSwipe(upwardDistance: 72, velocity: 0), isTrue);
      expect(shouldRestorePortraitPanelFromSwipe(upwardDistance: 28, velocity: -1000), isTrue);
      expect(shouldRestorePortraitPanelFromSwipe(upwardDistance: 20, velocity: -1200), isFalse);
      expect(shouldRestorePortraitPanelFromSwipe(upwardDistance: 72, velocity: 800), isTrue);
    });
  });

  testWidgets('entry hint fades completely after its short display window', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: PortraitFullscreenEntryHint(visibleDuration: Duration(milliseconds: 400)),
        ),
      ),
    );

    AnimatedOpacity opacity() => tester.widget(find.byKey(const ValueKey('portrait-fullscreen-entry-hint-opacity')));
    expect(find.byKey(const ValueKey('portrait-fullscreen-entry-hint')), findsOneWidget);
    expect(opacity().opacity, 1);

    await tester.pump(const Duration(milliseconds: 400));
    expect(opacity().opacity, 0);
    await tester.pump(const Duration(milliseconds: 260));
    expect(opacity().opacity, 0);
  });

  testWidgets('visible bottom controls preserve the portrait restore drag and child taps', (tester) async {
    var restores = 0;
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 320,
            height: portraitFullscreenControlsHeight,
            child: PortraitFullscreenRestoreGestureRegion(
              enabled: true,
              onRestore: () => restores++,
              child: Material(
                child: Center(
                  child: TextButton(
                    key: const ValueKey('bottom-control'),
                    onPressed: () => taps++,
                    child: const Text('Action'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('bottom-control')));
    await tester.pump();
    expect(taps, 1);
    expect(restores, 0);

    final region = tester.getRect(find.byType(PortraitFullscreenRestoreGestureRegion));
    final gesture = await tester.startGesture(Offset(region.center.dx, region.bottom - 16));
    await gesture.moveBy(const Offset(0, -76));
    await gesture.up();
    await tester.pump();
    expect(restores, 1);
    expect(taps, 1);
  });

  testWidgets('entry guidance stays above the portrait controller bar', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: PortraitFullscreenEntryHint())));
    final hint = tester.getRect(find.byKey(const ValueKey('portrait-fullscreen-entry-hint')));
    expect(hint.bottom, lessThanOrEqualTo(800 - portraitFullscreenControlsHeight - 12));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('entry guidance wraps on narrow screens with larger system text', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.8)),
          child: child!,
        ),
        home: const Scaffold(body: PortraitFullscreenEntryHint()),
      ),
    );
    expect(tester.takeException(), isNull);
    final text = tester.widget<Text>(find.byKey(const ValueKey('portrait-fullscreen-entry-hint')));
    expect(text.style?.color, Colors.white);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('disabled bottom restore region leaves upward drags inert', (tester) async {
    var restores = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PortraitFullscreenRestoreGestureRegion(
          enabled: false,
          onRestore: () => restores++,
          child: const SizedBox.expand(),
        ),
      ),
    );

    final gesture = await tester.startGesture(const Offset(200, 700));
    await gesture.moveBy(const Offset(0, -120));
    await gesture.up();
    await tester.pump();
    expect(restores, 0);
  });
}
