import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/widgets/pure_live_scroll_physics.dart';
import 'package:pure_live/modules/search/search_page.dart';
import 'package:pure_live/modules/search/search_platform_strip.dart';

void main() {
  test('search platform strip uses clamped boundaries', () {
    expect(searchPlatformStripPhysics, isA<ClampingScrollPhysics>());
  });

  testWidgets('search platform strip cannot move beyond either edge', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 120));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchPlatformStrip(
            labels: List<String>.generate(12, (index) => 'Platform $index'),
            selectedIndex: 0,
            onSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final list = tester.widget<ListView>(find.byKey(const ValueKey('search-platform-strip')));
    final scrollController = list.controller!;

    await tester.drag(find.byKey(const ValueKey('search-platform-strip')), const Offset(-4000, 0));
    await tester.pumpAndSettle();
    expect(scrollController.position.pixels, closeTo(scrollController.position.maxScrollExtent, 0.01));

    final maxExtent = scrollController.position.maxScrollExtent;
    await tester.drag(find.byKey(const ValueKey('search-platform-strip')), const Offset(-4000, 0));
    await tester.pumpAndSettle();
    expect(scrollController.position.pixels, closeTo(maxExtent, 0.01));

    await tester.drag(find.byKey(const ValueKey('search-platform-strip')), const Offset(4000, 0));
    await tester.pumpAndSettle();
    expect(scrollController.position.pixels, closeTo(scrollController.position.minScrollExtent, 0.01));
  });

  test('search results rebound on touch platforms and retain desktop policy', () {
    expect(resolveSearchResultScrollPhysics(TargetPlatform.android), isA<BouncingScrollPhysics>());
    expect(resolveSearchResultScrollPhysics(TargetPlatform.iOS), isA<BouncingScrollPhysics>());
    expect(resolveSearchResultScrollPhysics(TargetPlatform.windows), isA<PureLiveScrollPhysics>());
    expect(resolveSearchResultScrollPhysics(TargetPlatform.linux), isA<PureLiveScrollPhysics>());
  });
}
