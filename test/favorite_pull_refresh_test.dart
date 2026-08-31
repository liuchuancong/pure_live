import 'dart:async';

import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/modules/favorite/room_grid_view.dart';

void main() {
  test('wide mobile tablets retain pull-to-refresh while wide desktop layouts do not', () {
    expect(shouldWrapFavoritePullToRefresh(viewportWidth: 1280, isMobilePlatform: true), isTrue);
    expect(shouldWrapFavoritePullToRefresh(viewportWidth: 1280, isMobilePlatform: false), isFalse);
    expect(shouldWrapFavoritePullToRefresh(viewportWidth: 600, isMobilePlatform: false), isTrue);
  });

  testWidgets('favorite platform page shows and triggers its vertical pull indicator', (tester) async {
    var refreshCount = 0;
    final refreshCompleter = Completer<void>();
    ScrollPhysics? installedPhysics;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: buildFavoritePullToRefresh(
            siteId: 'bilibili',
            onRefresh: () {
              refreshCount++;
              return refreshCompleter.future;
            },
            childBuilder: (context, physics) {
              installedPhysics = physics;
              return ListView(
                physics: physics,
                children: const [SizedBox(height: 120, child: Text('favourite'))],
              );
            },
          ),
        ),
      ),
    );

    final refresh = tester.widget<EasyRefresh>(find.byType(EasyRefresh));
    expect(refresh.key, const ValueKey('favorite_pull_to_refresh_bilibili'));
    expect(refresh.childBuilder, isNotNull);
    expect(installedPhysics, isNotNull, reason: 'the scrollable must use EasyRefresh-owned physics');

    final gesture = await tester.startGesture(tester.getCenter(find.byType(ListView)));
    for (var index = 0; index < 6; index++) {
      await gesture.moveBy(const Offset(0, 70));
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(find.byType(RefreshProgressIndicator), findsOneWidget);

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 500));

    expect(refreshCount, 1, reason: 'a real drag, rather than a direct callback invocation, must arm refresh');
    expect(find.byType(RefreshProgressIndicator), findsOneWidget);

    refreshCompleter.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
  });
}
