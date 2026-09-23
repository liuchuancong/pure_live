import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/modules/multiview/cells/multiview_frame_watchdog.dart';

void main() {
  testWidgets('no first frame and sustained progress never trigger a stall', (tester) async {
    final revision = ValueNotifier<int>(0);
    addTearDown(revision.dispose);
    var now = Duration.zero;
    var stalls = 0;
    final watchdog = MultiviewFrameWatchdog(
      revision: revision,
      timeout: const Duration(seconds: 10),
      elapsed: () => now,
      isEligible: () => true,
      onStall: () => stalls++,
    )..start();
    addTearDown(watchdog.dispose);

    now = const Duration(seconds: 30);
    await tester.pump(const Duration(seconds: 30));
    expect(stalls, 0);
    revision.value = 1;
    now = const Duration(seconds: 39);
    await tester.pump(const Duration(seconds: 9));
    revision.value = 2;
    now = const Duration(seconds: 40);
    await tester.pump(const Duration(seconds: 1));
    expect(stalls, 0);
    now = const Duration(seconds: 48);
    await tester.pump(const Duration(seconds: 8));
    expect(stalls, 0);
    now = const Duration(seconds: 50);
    await tester.pump(const Duration(seconds: 2));
    expect(stalls, 1);
  });

  testWidgets('hidden route gets a full visible grace interval; dispose cancels', (tester) async {
    final revision = ValueNotifier<int>(0);
    addTearDown(revision.dispose);
    var now = Duration.zero;
    var visible = true;
    var stalls = 0;
    final watchdog = MultiviewFrameWatchdog(
      revision: revision,
      timeout: const Duration(seconds: 10),
      hiddenPoll: const Duration(seconds: 1),
      elapsed: () => now,
      isEligible: () => visible,
      onStall: () => stalls++,
    )..start();
    revision.value = 1;
    visible = false;
    now = const Duration(seconds: 20);
    await tester.pump(const Duration(seconds: 20));
    expect(stalls, 0);
    visible = true;
    now = const Duration(seconds: 21);
    await tester.pump(const Duration(seconds: 1));
    expect(stalls, 0);
    now = const Duration(seconds: 30);
    await tester.pump(const Duration(seconds: 9));
    expect(stalls, 0);
    watchdog.dispose();
    now = const Duration(seconds: 60);
    await tester.pump(const Duration(seconds: 30));
    expect(stalls, 0);
  });
}
