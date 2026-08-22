import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/app_refresh_rate_mode.dart';
import 'package:pure_live/common/widgets/adaptive_refresh_rate_scope.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('high refresh is bounded to the interaction burst', (tester) async {
    const channel = MethodChannel('pure_live/display_mode');
    final requests = <bool>[];
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'setHighRefreshRate') {
        final enabled = (call.arguments as Map<dynamic, dynamic>)['enabled'] == true;
        requests.add(enabled);
        return <String, Object>{
          'enabled': enabled,
          'currentRefreshRate': enabled ? 120.0 : 60.0,
          'maxRefreshRate': 120.0,
          'preferredRefreshRate': enabled ? 120.0 : 60.0,
          'supportedRefreshRates': <double>[60, 120],
        };
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await tester.pumpWidget(
      const MaterialApp(
        home: AdaptiveRefreshRateScope(
          mode: AppRefreshRateMode.balanced,
          child: Scaffold(body: SizedBox.expand()),
        ),
      ),
    );
    await tester.pump();

    final gesture = await tester.startGesture(const Offset(100, 100));
    await tester.pump();
    expect(AdaptiveRefreshRateController.requestedHigh, isTrue);
    await gesture.up();
    await tester.pump(AdaptiveRefreshRateController.settleDelay + const Duration(milliseconds: 1));
    await tester.pump();

    expect(AdaptiveRefreshRateController.requestedHigh, isFalse);
    expect(requests, contains(true));
    expect(requests.last, isFalse);
  });

  testWidgets('power-saving mode ignores interaction bursts', (tester) async {
    AdaptiveRefreshRateController.setMode(AppRefreshRateMode.powerSaving);
    await tester.pumpWidget(
      const MaterialApp(
        home: AdaptiveRefreshRateScope(
          mode: AppRefreshRateMode.powerSaving,
          child: Scaffold(body: SizedBox.expand()),
        ),
      ),
    );

    final gesture = await tester.startGesture(const Offset(100, 100));
    await tester.pump();
    expect(AdaptiveRefreshRateController.requestedHigh, isFalse);
    await gesture.up();
  });

  testWidgets('performance mode stays high in foreground and releases in background', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AdaptiveRefreshRateScope(
          mode: AppRefreshRateMode.performance,
          child: Scaffold(body: SizedBox.expand()),
        ),
      ),
    );
    await tester.pump();
    expect(AdaptiveRefreshRateController.requestedHigh, isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(AdaptiveRefreshRateController.requestedHigh, isFalse);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(AdaptiveRefreshRateController.requestedHigh, isTrue);
  });
}
