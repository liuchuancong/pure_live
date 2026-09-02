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
}
