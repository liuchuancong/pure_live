import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/features/room/widgets/room_bar_parts.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';

Widget _host(Widget child) => MaterialApp(
  home: MediaQuery(
    // The hint and the clock read the media text scale; pin the test one.
    data: const MediaQueryData(textScaler: TextScaler.noScaling),
    child: TranslationProvider(child: Scaffold(body: child)),
  ),
);

void main() {
  testWidgets('the clock says HH:mm and waits for the minute to turn', (tester) async {
    var now = DateTime(2026, 10, 19, 9, 7);
    await tester.pumpWidget(_host(PlayerClock(now: () => now)));
    expect(find.text('09:07'), findsOneWidget);
    now = DateTime(2026, 10, 19, 9, 8);
    // Nothing but its own scheduled tick redraws it; the timer fires past the
    // minute boundary.
    await tester.pump(const Duration(minutes: 1, milliseconds: 100));
    expect(find.text('09:08'), findsOneWidget);
  });

  testWidgets('the battery draws the level, and nothing where there is none', (tester) async {
    Future<int?> read() async => 72;
    await tester.pumpWidget(_host(PlayerBattery(read: read)));
    await tester.pump();
    expect(find.byKey(const ValueKey('live-play-battery')), findsOneWidget);
    expect(find.text('72'), findsOneWidget);

    Future<int?> none() async => null;
    await tester.pumpWidget(_host(PlayerBattery(key: UniqueKey(), read: none)));
    // The element keeps its state; the new read must land and redraw.
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('live-play-battery')), findsNothing);
  });

  testWidgets('a failing battery read is silent, not an error box', (tester) async {
    Future<int?> boom() async => throw StateError('no battery on this host');
    await tester.pumpWidget(_host(PlayerBattery(read: boom)));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('live-play-battery')), findsNothing);
  });

  testWidgets('the entry hint fades after its seconds', (tester) async {
    await tester.pumpWidget(const _Host(PortraitEntryHint(bottom: 40)));
    expect(find.byKey(const ValueKey('live-play-portrait-hint')), findsOneWidget);
    final fading = tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity).first);
    expect(fading.opacity, 1);
    await tester.pump(const Duration(seconds: 3, milliseconds: 400));
    expect(tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity).first).opacity, lessThan(1));
  });
}

/// The hint is positioned; it needs a Stack to live in.
final class _Host extends StatelessWidget {
  const new(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(),
      child: TranslationProvider(child: Scaffold(body: Stack(children: [child]))),
    ),
  );
}
