import 'package:flutter_test/flutter_test.dart';
import 'package:live_device/live_device.dart' show NetworkInterface;
import 'package:pure_live/app/providers/network/network_type_provider.dart';

void main() {
  NetworkTypeState reading(Set<NetworkInterface> interfaces, {bool ready = true}) =>
      (ready: ready, reportsCellular: true, interfaces: interfaces, error: '');

  group('the online reading', () {
    test('an exclusive "none" is the only offline report', () {
      expect(isOnlineReading(reading({NetworkInterface.none})), isFalse);
    });

    test('a live interface, or none mixed with one, counts as online', () {
      expect(isOnlineReading(reading({NetworkInterface.wifi})), isTrue);
      expect(isOnlineReading(reading({NetworkInterface.none, NetworkInterface.vpn})), isTrue);
    });

    test('an empty reading and a backend that has not answered are online', () {
      expect(isOnlineReading(reading(const {})), isTrue);
      expect(isOnlineReading(reading({NetworkInterface.none}, ready: false)), isTrue);
    });
  });
}
