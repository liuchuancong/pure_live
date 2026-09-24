import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/global/platform/desktop_manager.dart';

void main() {
  testWidgets('desktop builder title controls remain usable outside navigator overlay', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => Column(
          children: [
            Row(
              children: [
                TitleBarProjectLink(
                  semanticLabel: 'Project Homepage',
                  failureMessage: 'Browser did not open',
                  appName: 'PureLive',
                  appNameStyle: const TextStyle(color: Colors.black),
                  sizeTextStyle: const TextStyle(color: Colors.black),
                  projectUri: Uri.parse('https://example.test/project'),
                  iconColor: Colors.black,
                  hoverColor: Colors.blue,
                  currentSize: const Size(1280, 720),
                  showSizeText: false,
                  openExternalUrl: (_) async => true,
                ),
                WindowControlButton(
                  semanticLabel: 'Minimize window',
                  failureMessage: 'Window action failed',
                  icon: Icons.remove,
                  hoverColor: Colors.blue,
                  iconColor: Colors.black,
                  onPressed: () async {},
                ),
              ],
            ),
            Expanded(child: child ?? const SizedBox.shrink()),
          ],
        ),
        home: const Scaffold(body: Center(child: Text('Page'))),
      ),
    );

    expect(tester.takeException(), isNull);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: tester.getCenter(find.byType(TitleBarProjectLink)));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    await mouse.moveTo(tester.getCenter(find.byType(WindowControlButton)));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });
}
