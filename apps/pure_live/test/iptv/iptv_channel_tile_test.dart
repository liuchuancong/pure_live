import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_iptv/live_iptv.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/iptv/views/iptv_panels.dart' show IptvChannelTile;

void main() {
  final channel = IptvChannel.of(
    id: 'one',
    entry: IptvEntry.of(name: '测试频道', url: 'http://stream/one', group: '测试分组'),
  );

  Future<void> pumpTile(
    WidgetTester tester, {
    required VoidCallback onPlay,
    required VoidCallback onToggleFavourite,
    VoidCallback? onOpenGuide,
    double width = 320,
  }) async {
    await tester.binding.setSurfaceSize(Size(width, 240));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      TranslationProvider(
        child: DsScope(
          child: MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  child: IptvChannelTile(
                    channel: channel,
                    slot: null,
                    selected: false,
                    onPlay: onPlay,
                    onOpenGuide: onOpenGuide,
                    onToggleFavourite: onToggleFavourite,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('a tap dispatches the row play action', (tester) async {
    var plays = 0;
    await pumpTile(tester, onPlay: () => plays++, onToggleFavourite: () {});

    await tester.tap(find.text(channel.entry.name));
    await tester.pump();

    expect(plays, 1);
    expect(find.byType(DsMenu), findsNothing);
  });

  testWidgets('a long press opens guide and favourite actions without playing', (tester) async {
    var plays = 0;
    var guides = 0;
    var favourites = 0;
    await pumpTile(tester, onPlay: () => plays++, onOpenGuide: () => guides++, onToggleFavourite: () => favourites++);

    await tester.longPress(find.text(channel.entry.name));
    await tester.pumpAndSettle();

    expect(plays, 0);
    expect(find.byType(DsMenu), findsOneWidget);
    await tester.tap(find.text(t.iptv.guideTitle));
    await tester.pumpAndSettle();
    expect(guides, 1);

    await tester.longPress(find.text(channel.entry.name));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.iptv.favouriteAction));
    await tester.pumpAndSettle();
    expect(favourites, 1);
    expect(plays, 0);
  });

  testWidgets('the channel row stays within a 320 pixel viewport', (tester) async {
    await pumpTile(tester, onPlay: () {}, onToggleFavourite: () {});

    expect(tester.takeException(), isNull);
    final row = find.byType(DsListRow);
    final rect = tester.getRect(row);
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(320));
  });
}
