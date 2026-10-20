import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_uikit/pure_uikit.dart';
import 'package:yaru/yaru.dart' as yaru;

void main() {
  // The strip's own metrics are taller and wider than a host theme's icon
  // button cap: yaru's IconButtonTheme clamps every icon button to
  // kYaruButtonHeight (34) square, and an uncapped minimum over that themed
  // cap resolved to min > max — the button threw before its first frame.
  // The widget declares both bounds itself, so the host theme cannot split
  // them, and the yaru metrics (42x37) are the widest case.
  testWidgets('the caption button keeps its size under a capping host theme', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: yaru.createYaruLightTheme(primaryColor: const Color(0xFFE95420)),
        home: Scaffold(
          body: PureTitleBarCaptionButton(
            icon: Icons.close,
            tooltip: 'close',
            onPressed: () {},
            buttonKey: const Key('close'),
            width: 42,
            height: 37,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byKey(const Key('close'))), const Size(42, 37));
  });
}
