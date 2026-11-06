import 'dart:io';

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_cache/live_cache.dart';
import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.g.dart';
import 'package:pure_live/modules/live/popular/room_card.dart';
import 'package:pure_live/shared/images/app_image_cache.dart';

/// The view renders from the values its caller hands it — no store, no
/// provider — so these run bare: a resolver never stands between the test
/// and the pixels.
void main() {
  setUpAll(() {
    // The card's cover goes through the app's image cache; a throwaway
    // manager over a temp folder keeps the test bare of the boot.
    final root = Directory.systemTemp.createTempSync('room-card-view-test');
    addTearDown(() => root.deleteSync(recursive: true));
    installLiveCacheManager(
      LiveCacheManager(
        directory: root,
        http: DioFactory().create(profile: ClientProfile.media),
      ),
    );
  });
  LiveRoom room(String title) => LiveRoom.normalized(
    platform: 'douyu',
    roomId: '1',
    content: RoomContent.of(title: title),
    anchor: LiveAnchor.of(name: 'Streamer'),
  );

  Future<void> show(WidgetTester tester, RoomCardView card) async {
    await tester.binding.setSurfaceSize(const Size(400, 560));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      TranslationProvider(
        child: DsScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(child: SizedBox(width: 320, child: card)),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the grid draws the title and the followed heart it is told about', (tester) async {
    await show(
      tester,
      RoomCardView(
        room: room('An evening of quiet games'),
        visibility: RoomCardVisibility.standard,
        figure: 1234,
        followed: true,
        platformIcon: const SizedBox.shrink(),
        platformName: 'Douyu',
      ),
    );
    expect(find.text('An evening of quiet games'), findsOneWidget);
    expect(find.text('1234'), findsOneWidget);
    expect(find.text('Douyu'), findsOneWidget);
  });

  testWidgets('the visibility the caller passes decides what the grid shows', (tester) async {
    final bare = RoomCardVisibility.hiding(const [RoomCardElement.audience]);
    await show(
      tester,
      RoomCardView(
        room: room('Hidden figure'),
        visibility: bare,
        figure: 1234,
        followed: false,
        platformIcon: const SizedBox.shrink(),
        platformName: 'Douyu',
      ),
    );
    expect(find.text('Hidden figure'), findsOneWidget);
    expect(find.text('1234'), findsNothing);
  });

  testWidgets('the list row leads with the streamer and takes the ✕', (tester) async {
    await show(
      tester,
      RoomCardView(
        room: room('Row room'),
        visibility: RoomCardVisibility.standard,
        figure: 8,
        followed: false,
        platformIcon: const SizedBox.shrink(),
        platformName: 'Douyu',
        listRow: true,
        onRemove: () {},
        removeLabel: 'remove',
      ),
    );
    expect(find.text('Row room'), findsOneWidget);
    expect(find.text('Streamer'), findsOneWidget);
    expect(find.bySemanticsLabel('remove'), findsOneWidget);
  });
}
