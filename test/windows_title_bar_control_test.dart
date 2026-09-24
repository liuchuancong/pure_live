import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/global/platform/desktop_manager.dart';

void main() {
  test('Windows title-bar controls own names, keyboard actions and async serialization', () {
    final source = File('lib/common/global/platform/desktop_manager.dart').readAsStringSync();

    expect(source, contains('required this.semanticLabel'));
    expect(source, isNot(contains('child: Tooltip(')));
    expect(source, contains('label: widget.semanticLabel'));
    expect(source, contains('Future<void> _runAction()'));
    expect(source, contains('enabled: !_busy'));
    expect(source, contains('ScaffoldMessenger.maybeOf(context)?.showSnackBar'));
    for (final key in ['window_minimize', 'window_maximize_restore', 'window_close']) {
      expect(source, contains("i18nOr('$key'"));
    }
  });

  test('Windows title-bar action names are localized in both bundled languages', () {
    final english = jsonDecode(File('assets/translations/en.json').readAsStringSync()) as Map<String, dynamic>;
    final chinese = jsonDecode(File('assets/translations/zh.json').readAsStringSync()) as Map<String, dynamic>;

    for (final key in ['window_minimize', 'window_maximize_restore', 'window_close']) {
      expect(english[key], isA<String>().having((value) => value.trim(), key, isNotEmpty));
      expect(chinese[key], isA<String>().having((value) => value.trim(), key, isNotEmpty));
    }
  });

  testWidgets('Windows title-bar control exposes its action and supports keyboard activation', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      var calls = 0;
      await tester.pumpWidget(_button(onPressed: () async => calls++));

      expect(find.bySemanticsLabel('Minimize window'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final decoration = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer)).decoration as BoxDecoration;
      expect(decoration.border, isNotNull);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(calls, 1);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('Windows title-bar control serializes repeated async actions and enables retry', (tester) async {
    final firstGate = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      _button(
        onPressed: () async {
          calls++;
          if (calls == 1) await firstGate.future;
        },
      ),
    );

    await tester.tap(find.byType(WindowControlButton));
    await tester.pump();
    expect(calls, 1);
    expect(tester.widget<InkWell>(find.byType(InkWell)).onTap, isNull);
    await tester.tap(find.byType(WindowControlButton));
    await tester.pump();
    expect(calls, 1);

    firstGate.complete();
    await tester.pump();
    expect(tester.widget<InkWell>(find.byType(InkWell)).onTap, isNotNull);
    await tester.tap(find.byType(WindowControlButton));
    await tester.pump();
    expect(calls, 2);
  });

  testWidgets('Windows title-bar control contains an action failure and stays retryable', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      _button(
        onPressed: () async {
          calls++;
          if (calls == 1) throw StateError('window fixture failure');
        },
      ),
    );

    await tester.tap(find.byType(WindowControlButton));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Window action failed'), findsOneWidget);
    await tester.tap(find.byType(WindowControlButton));
    await tester.pump();
    expect(calls, 2);
  });
}

Widget _button({required Future<void> Function() onPressed}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: WindowControlButton(
          semanticLabel: 'Minimize window',
          failureMessage: 'Window action failed',
          icon: Icons.remove,
          hoverColor: Colors.blue,
          iconColor: Colors.black,
          onPressed: onPressed,
        ),
      ),
    ),
  );
}
