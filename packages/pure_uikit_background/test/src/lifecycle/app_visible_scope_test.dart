import 'package:flutter/material.dart' show Builder, MaterialApp, Scaffold, SizedBox, Widget;
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_uikit_background/pure_uikit_background.dart';

class _Probe {
  new({required this.wrapped});

  final bool wrapped;
  bool captured = false;

  Widget build() {
    final inner = Builder(
      builder: (context) {
        captured = AppVisibleScope.isVisibleOf(context);
        return const SizedBox.shrink();
      },
    );
    return MaterialApp(
      home: Scaffold(body: wrapped ? AppVisibilityObserver(child: inner) : inner),
    );
  }
}

void main() {
  group('AppVisibleScope', () {
    testWidgets('isVisibleOf defaults to true when no observer wraps the tree', (tester) async {
      final probe = _Probe(wrapped: false);
      await tester.pumpWidget(probe.build());
      expect(probe.captured, isTrue);
    });

    testWidgets('AppVisibilityObserver publishes the initial visible state', (tester) async {
      final probe = _Probe(wrapped: true);
      await tester.pumpWidget(probe.build());
      // The binding starts in `AppLifecycleState.resumed` during tests.
      expect(probe.captured, isTrue);
    });

    testWidgets('observed lifecycle transitions flip the scope value', (tester) async {
      final probe = _Probe(wrapped: true);
      await tester.pumpWidget(probe.build());
      expect(probe.captured, isTrue);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(probe.captured, isFalse);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(probe.captured, isTrue);
    });
  });
}
