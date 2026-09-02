import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/iptv/services/auto_sync_scheduler.dart';

void main() {
  test('simultaneous IPTV resource requests share one import', () async {
    final gate = IptvResourceLoadGate();
    final release = Completer<void>();
    var invocations = 0;

    Future<void> load() async {
      invocations++;
      await release.future;
    }

    final first = gate.run(load);
    final second = gate.run(load);
    expect(invocations, 1);

    release.complete();
    await Future.wait([first, second]);

    await gate.run(() async {
      invocations++;
    });
    expect(invocations, 2);
  });
}
