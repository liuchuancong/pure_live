import 'dart:io' show OSError;

import 'package:live_lan_sync/live_lan_sync.dart';
import 'package:test/test.dart';

void main() {
  group('NetworkMonitor', () {
    test('baseline does not emit; a change emits; the same set is silent', () async {
      var addresses = <String>{'192.168.1.5'};
      final monitor = NetworkMonitor(pollInterval: null, addressProvider: () async => addresses);
      final events = <void>[];
      final subscription = monitor.changes.listen(events.add);
      addTearDown(subscription.cancel);

      await monitor.start();
      expect(events, isEmpty, reason: 'the first poll only sets the baseline');

      addresses = {'192.168.1.5', '10.8.0.2'};
      await monitor.checkNow();
      await Future<void>.delayed(Duration.zero);
      expect(events, hasLength(1), reason: 'a vpn or wifi change must be reported');

      await monitor.checkNow();
      await Future<void>.delayed(Duration.zero);
      expect(events, hasLength(1), reason: 'an unchanged set stays silent');
      await monitor.dispose();
    });

    test('a failing interface list does not kill the monitor', () async {
      var fail = true;
      var addresses = <String>{'192.168.1.5'};
      final monitor = NetworkMonitor(
        pollInterval: null,
        addressProvider: () async {
          if (fail) throw const OSError('interface list unavailable');
          return addresses;
        },
      );
      final events = <void>[];
      final subscription = monitor.changes.listen(events.add);
      addTearDown(subscription.cancel);

      await monitor.start();
      expect(events, isEmpty);

      fail = false;
      addresses = {'192.168.1.9'};
      await monitor.checkNow();
      await Future<void>.delayed(Duration.zero);
      expect(events, isEmpty, reason: 'the first successful poll re-baselines silently');

      addresses = {'192.168.1.10'};
      await monitor.checkNow();
      await Future<void>.delayed(Duration.zero);
      expect(events, hasLength(1), reason: 'a later change is reported as usual');
      await monitor.dispose();
    });

    test('stop forgets the baseline so start re-baselines', () async {
      var addresses = <String>{'192.168.1.5'};
      final monitor = NetworkMonitor(pollInterval: null, addressProvider: () async => addresses);
      final events = <void>[];
      final subscription = monitor.changes.listen(events.add);
      addTearDown(subscription.cancel);

      await monitor.start();
      await monitor.stop();
      addresses = {'192.168.1.9'};
      await monitor.start();
      await Future<void>.delayed(Duration.zero);
      expect(events, isEmpty, reason: 'after a stop, the next start re-baselines silently');
      await monitor.dispose();
    });
  });
}
