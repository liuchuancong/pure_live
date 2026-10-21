import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/system/configuration/app_preferences_providers.dart';

/// The shell's re-tap signal — the raw channel `goShellBranch` pulses and the
/// follow branch listens to. Its contract is tested directly; the navigation
/// call-site is one `reTapped(branch.name)` line and the follow page's
/// subscription is a `where` filter, both exercised in-app.
void main() {
  test('reTapped emits the branch id to every listener', () async {
    final signals = ShellReTapSignals();
    final seenA = <String>[];
    final seenB = <String>[];
    final a = signals.reTaps.listen(seenA.add);
    final b = signals.reTaps.listen(seenB.add);

    signals.reTapped('follow');
    await Future<void>.delayed(Duration.zero);
    expect(seenA, ['follow']);
    expect(seenB, ['follow']);

    await a.cancel();
    await b.cancel();
    await signals.dispose();
  });

  test('a re-tap after dispose is dropped, not thrown', () async {
    final signals = ShellReTapSignals();
    final seen = <String>[];
    final sub = signals.reTaps.listen(seen.add);
    await signals.dispose();

    signals.reTapped('follow'); // must not throw on the closed controller
    await Future<void>.delayed(Duration.zero);
    expect(seen, isEmpty);
    await sub.cancel();
  });
}
