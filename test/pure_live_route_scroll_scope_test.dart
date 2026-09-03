import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/widgets/pure_live_scroll_controller.dart';
import 'package:scroll_animator/scroll_animator.dart';

void main() {
  testWidgets('Windows route provides an animated primary scroll controller', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      ScrollController? inherited;

      await tester.pumpWidget(
        MaterialApp(
          home: PureLiveRouteScrollScope(
            child: Builder(
              builder: (context) {
                inherited = PrimaryScrollController.maybeOf(context);
                return ListView(children: const [SizedBox(height: 2000)]);
              },
            ),
          ),
        ),
      );

      expect(inherited, isA<AnimatedScrollController>());
      expect(inherited!.hasClients, isTrue);

      inherited!.position.pointerScroll(120);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(inherited!.offset, inExclusiveRange(0, 120));
      await tester.pumpAndSettle();
      expect(inherited!.offset, closeTo(120, 1));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('an explicitly controlled list does not attach to the route controller', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      final explicit = ScrollController();
      addTearDown(explicit.dispose);
      ScrollController? inherited;

      await tester.pumpWidget(
        MaterialApp(
          home: PureLiveRouteScrollScope(
            child: Builder(
              builder: (context) {
                inherited = PrimaryScrollController.maybeOf(context);
                return ListView(controller: explicit, children: const [SizedBox(height: 2000)]);
              },
            ),
          ),
        ),
      );

      expect(explicit.hasClients, isTrue);
      expect(inherited, isA<AnimatedScrollController>());
      expect(inherited!.hasClients, isFalse);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('non-Windows routes keep the platform scroll controller hierarchy', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      ScrollController? inherited;

      await tester.pumpWidget(
        MaterialApp(
          home: PureLiveRouteScrollScope(
            child: Builder(
              builder: (context) {
                inherited = PrimaryScrollController.maybeOf(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(inherited, isNot(isA<AnimatedScrollController>()));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
