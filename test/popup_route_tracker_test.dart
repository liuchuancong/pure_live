import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_floating/flutter_floating.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/player/utils/popup_route_tracker.dart';

void main() {
  testWidgets('a popup opened after the floating overlay is not covered by it', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    var floatingTaps = 0;
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: [PopupRouteTracker.instance],
        home: const Scaffold(body: SizedBox.expand()),
      ),
    );

    // Same wiring as the app floating player: a manual entry in the
    // navigator's overlay, positioned where a later menu will appear.
    final floating = OverlayEntry(
      builder: (_) => Positioned(
        left: 0,
        top: 0,
        width: 300,
        height: 300,
        child: PopupAwareVisibility(
          child: GestureDetector(
            key: const Key('floating'),
            behavior: HitTestBehavior.opaque,
            onTap: () => floatingTaps++,
            child: const ColoredBox(color: Colors.black),
          ),
        ),
      ),
    );
    navigatorKey.currentState!.overlay!.insert(floating);
    await tester.pump();

    showMenu<String>(
      context: navigatorKey.currentContext!,
      position: const RelativeRect.fromLTRB(10, 10, 10, 10),
      items: const [PopupMenuItem(value: 'search', child: Text('search'))],
    ).then((value) => selected = value);
    await tester.pumpAndSettle();
    expect(PopupRouteTracker.openPopups.value, 1);

    await tester.tap(find.text('search'));
    await tester.pumpAndSettle();
    expect(selected, 'search');
    expect(floatingTaps, 0, reason: 'the menu, not the floating window, received the tap');

    expect(PopupRouteTracker.openPopups.value, 0);
    final opacity = tester.widget<AnimatedOpacity>(
      find.ancestor(of: find.byKey(const Key('floating')), matching: find.byType(AnimatedOpacity)),
    );
    expect(opacity.opacity, 1);
    await tester.tap(find.byKey(const Key('floating')));
    expect(floatingTaps, 1, reason: 'the floating window is interactive again after the popup closes');

    floating.remove();
  });

  testWidgets('the real floating overlay lets a menu underneath it receive taps', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: [PopupRouteTracker.instance],
        home: const Scaffold(body: SizedBox.expand()),
      ),
    );

    // flutter_floating wraps the child in an opaque drag detector, so fading
    // the child alone left an invisible window swallowing the menu's taps.
    final floating = FloatingOverlay(
      const PopupAwareVisibility(
        child: SizedBox(width: 300, height: 300, child: ColoredBox(color: Colors.black)),
      ),
      slideType: FloatingEdgeType.onLeftAndTop,
      left: 0,
      top: 0,
    );
    floating.open(tester.element(find.byType(Scaffold)));
    final subscription = hideFloatingWhilePopupsOpen(floating);
    await _settleFrames(tester);

    showMenu<String>(
      context: navigatorKey.currentContext!,
      position: const RelativeRect.fromLTRB(10, 10, 10, 10),
      items: const [PopupMenuItem(value: 'search', child: Text('search'))],
    ).then((value) => selected = value);
    await _settleFrames(tester);

    await tester.tap(find.text('search'));
    await _settleFrames(tester);
    expect(selected, 'search');
    expect(floating.isHidden, isFalse, reason: 'the floating window returns once the menu closes');

    unawaited(subscription.cancel());
    floating.close();
    floating.dispose();
    await _settleFrames(tester);
  });
}

// The floating view keeps scheduling frames, so pumpAndSettle never returns.
Future<void> _settleFrames(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}
