import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/global/platform/desktop_manager.dart';

void main() {
  test('Windows title-bar project link owns accessibility and external launch state', () {
    final source = File('lib/common/global/platform/desktop_manager.dart').readAsStringSync();
    final projectLinkSource = source.substring(
      source.indexOf('class TitleBarProjectLink extends StatefulWidget'),
      source.indexOf('class WindowControlButton extends StatefulWidget'),
    );

    expect(projectLinkSource, contains('link: true'));
    expect(projectLinkSource, contains('enabled: !_busy'));
    expect(projectLinkSource, contains('mode: LaunchMode.externalApplication'));
    expect(source, contains("'external_browser_not_opened'"));
  });

  testWidgets('project link exposes its purpose, focus and keyboard action', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final openedUris = <Uri>[];
      await tester.pumpWidget(
        _link(
          openExternalUrl: (uri) async {
            openedUris.add(uri);
            return true;
          },
        ),
      );

      expect(find.bySemanticsLabel('Project Homepage'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final decoration = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer)).decoration as BoxDecoration;
      expect(decoration.border, isNotNull);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(openedUris, [Uri.parse('https://example.test/project')]);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(openedUris, [Uri.parse('https://example.test/project'), Uri.parse('https://example.test/project')]);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('project link serializes launch, reports false and enables retry', (tester) async {
    final firstLaunch = Completer<bool>();
    var calls = 0;
    await tester.pumpWidget(
      _link(
        openExternalUrl: (_) {
          calls++;
          return calls == 1 ? firstLaunch.future : Future<bool>.value(true);
        },
      ),
    );

    await tester.tap(find.byType(TitleBarProjectLink));
    await tester.pump();
    expect(calls, 1);
    expect(tester.widget<InkWell>(find.byType(InkWell)).onTap, isNull);
    await tester.tap(find.byType(TitleBarProjectLink));
    await tester.pump();
    expect(calls, 1);

    firstLaunch.complete(false);
    await tester.pump();
    expect(find.text('Browser did not open'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(tester.widget<InkWell>(find.byType(InkWell)).onTap, isNotNull);

    await tester.tap(find.byType(TitleBarProjectLink));
    await tester.pump();
    expect(calls, 2);
  });

  testWidgets('project link contains a launcher exception and stays retryable', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      _link(
        openExternalUrl: (_) async {
          calls++;
          if (calls == 1) throw StateError('browser fixture failure');
          return true;
        },
      ),
    );

    await tester.tap(find.byType(TitleBarProjectLink));
    await tester.pump();
    expect(find.text('Browser did not open'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(TitleBarProjectLink));
    await tester.pump();
    expect(calls, 2);
  });

  testWidgets('project link fits long large text inside a narrow fixed title bar', (tester) async {
    await tester.pumpWidget(
      _link(
        width: 120,
        appName: 'PureLive project title repeated repeatedly',
        textStyle: const TextStyle(fontSize: 64, color: Colors.black),
        openExternalUrl: (_) async => true,
      ),
    );

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(TitleBarProjectLink)).width, lessThanOrEqualTo(120));
    expect(tester.getSize(find.byType(TitleBarProjectLink)).height, 32);
    expect(find.byType(TitleBarProjectLink).hitTestable(), findsOneWidget);
  });
}

Widget _link({
  required Future<bool> Function(Uri uri) openExternalUrl,
  double? width,
  String appName = 'PureLive',
  TextStyle textStyle = const TextStyle(color: Colors.black),
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: TitleBarProjectLink(
            semanticLabel: 'Project Homepage',
            failureMessage: 'Browser did not open',
            appName: appName,
            appNameStyle: textStyle,
            sizeTextStyle: textStyle,
            projectUri: Uri.parse('https://example.test/project'),
            iconColor: Colors.black,
            hoverColor: Colors.blue,
            currentSize: const Size(1280, 720),
            showSizeText: true,
            openExternalUrl: openExternalUrl,
          ),
        ),
      ),
    ),
  );
}
