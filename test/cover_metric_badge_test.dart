import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/widgets/room_card.dart';

void main() {
  testWidgets('cover metric is compact, transparent, and keeps its semantic label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CoverMetricBadge(icon: Icons.people_alt_rounded, value: '3.2万', semanticLabel: '真实在线人数 3.2万'),
        ),
      ),
    );

    expect(find.byType(Card), findsNothing);
    expect(find.text('3.2万'), findsOneWidget);
    expect(
      find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.label == '真实在线人数 3.2万'),
      findsOneWidget,
    );
    expect(tester.getSize(find.byType(CoverMetricBadge)).width, lessThan(100));
  });
}
