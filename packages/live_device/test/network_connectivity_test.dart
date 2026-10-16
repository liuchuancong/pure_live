import 'package:connectivity_plus/connectivity_plus.dart' as plugin;
import 'package:flutter/foundation.dart' show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter_test/flutter_test.dart';
import 'package:live_device/src/network/connectivity/network_connectivity.dart';
import 'package:live_device/src/network/connectivity/network_connectivity_capabilities.dart';
import 'package:live_device/src/network/connectivity/network_connectivity_exception.dart';
import 'package:live_device/src/network/connectivity/network_connectivity_service.dart';
import 'package:live_device/src/network/connectivity/network_interface.dart';
import 'package:live_device/src/network/connectivity/platform_network_connectivity_service.dart';

NetworkConnectivity _reading(List<NetworkInterface> interfaces) => NetworkConnectivity(interfaces: interfaces);

NetworkConnectivityCapabilities _capabilities({
  bool canRead = true,
  bool canObserve = true,
  bool reportsCellular = false,
  bool reportsWifi = true,
}) => NetworkConnectivityCapabilities(
  canRead: canRead,
  canObserve: canObserve,
  reportsCellular: reportsCellular,
  reportsWifi: reportsWifi,
  platformName: 'test',
);

Matcher _isConnectivityFailure(String code) =>
    isA<NetworkConnectivityException>().having((error) => error.code, 'code', code);

/// The complete translation table the connectivity backend is expected to obey,
/// keyed by the values the hidden plugin can report.
const Map<plugin.ConnectivityResult, NetworkInterface> _expectedInterfaces =
    <plugin.ConnectivityResult, NetworkInterface>{
      plugin.ConnectivityResult.bluetooth: NetworkInterface.bluetooth,
      plugin.ConnectivityResult.wifi: NetworkInterface.wifi,
      plugin.ConnectivityResult.ethernet: NetworkInterface.ethernet,
      plugin.ConnectivityResult.mobile: NetworkInterface.cellular,
      plugin.ConnectivityResult.none: NetworkInterface.none,
      plugin.ConnectivityResult.vpn: NetworkInterface.vpn,
      plugin.ConnectivityResult.satellite: NetworkInterface.satellite,
      plugin.ConnectivityResult.other: NetworkInterface.other,
    };

void main() {
  group('interface mapping', () {
    test('translates every reported value into exactly one neutral interface', () {
      for (final entry in _expectedInterfaces.entries) {
        expect(networkInterfacesFromResults(<plugin.ConnectivityResult>[entry.key]), <NetworkInterface>{
          entry.value,
        }, reason: '${entry.key.name} must become ${entry.value.name}');
      }

      expect(
        _expectedInterfaces.length,
        plugin.ConnectivityResult.values.length,
        reason: 'a new backend value needs a rule before it reaches callers',
      );
      expect(_expectedInterfaces.values.toSet().length, _expectedInterfaces.length);
    });

    test('renames the mobile transport to cellular and keeps none as none', () {
      expect(NetworkInterface.values.map((interface) => interface.name), isNot(contains('mobile')));
      expect(NetworkInterface.cellular.name, 'cellular');
      expect(
        networkInterfacesFromResults(plugin.ConnectivityResult.values),
        NetworkInterface.values.toSet(),
        reason: 'the neutral enum must be reachable without inventing or losing a value',
      );
    });

    test('de-duplicates a report that names the same interface twice', () {
      expect(
        networkInterfacesFromResults(<plugin.ConnectivityResult>[
          plugin.ConnectivityResult.wifi,
          plugin.ConnectivityResult.wifi,
          plugin.ConnectivityResult.vpn,
        ]),
        <NetworkInterface>{NetworkInterface.wifi, NetworkInterface.vpn},
      );
      expect(networkInterfacesFromResults(<plugin.ConnectivityResult>[]), isEmpty);
    });
  });

  group('NetworkConnectivity', () {
    test('treats only an exclusive none report as offline', () {
      expect(_reading(const <NetworkInterface>[NetworkInterface.none]).isOnline, isFalse);
      expect(_reading(const <NetworkInterface>[]).isOnline, isTrue, reason: 'an empty report is not a none report');
      expect(
        _reading(const <NetworkInterface>[NetworkInterface.none, NetworkInterface.vpn]).isOnline,
        isTrue,
        reason: 'a named interface is up even when none is also listed',
      );
      expect(
        _reading(const <NetworkInterface>[NetworkInterface.cellular, NetworkInterface.satellite]).isOnline,
        isTrue,
      );
    });

    test('keeps an unmodifiable copy that later changes cannot reach', () {
      final reported = <NetworkInterface>{NetworkInterface.wifi};
      final reading = NetworkConnectivity(interfaces: reported);

      reported.add(NetworkInterface.ethernet);

      expect(reading.interfaces, <NetworkInterface>{NetworkInterface.wifi});
      expect(() => reading.interfaces.add(NetworkInterface.ethernet), throwsUnsupportedError);
    });
  });

  group('NetworkConnectivityCapabilities', () {
    test('offers connectivity as soon as either reading path works', () {
      expect(_capabilities().canOfferConnectivity, isTrue);
      expect(_capabilities(canRead: false).canOfferConnectivity, isTrue);
      expect(_capabilities(canObserve: false).canOfferConnectivity, isTrue);
      expect(_capabilities(canRead: false, canObserve: false).canOfferConnectivity, isFalse);
    });

    test('describes radios independently of the reading paths', () {
      final capabilities = _capabilities(reportsCellular: true);
      expect(capabilities.reportsCellular, isTrue);
      expect(capabilities.reportsWifi, isTrue);
      expect(capabilities.platformName, 'test');
    });
  });

  group('NetworkConnectivityException', () {
    test('prints its stable code and defaults to no details', () {
      const failure = NetworkConnectivityException(
        code: 'unsupported_on_platform',
        message: 'No connectivity backend is available here.',
      );
      expect(failure, _isConnectivityFailure('unsupported_on_platform'));
      expect(failure.toString(), contains('unsupported_on_platform'));
      expect(failure.message, 'No connectivity backend is available here.');
      expect(failure.details, isEmpty);
      expect(failure.cause, isNull);
    });

    test('keeps structured details and the original cause for diagnostics', () {
      final failure = NetworkConnectivityException(
        code: 'network_connectivity_operation_failed',
        message: 'The network-connectivity operation failed.',
        details: <String, Object?>{'errorType': 'StateError'},
        cause: StateError('native failure'),
      );
      expect(failure.details, <String, Object?>{'errorType': 'StateError'});
      expect(failure.cause, isA<StateError>());
      expect(failure.toString(), isNot(contains('errorType')));
    });
  });

  group('PlatformNetworkConnectivityService', () {
    const service = PlatformNetworkConnectivityService();

    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('implements the connectivity contract', () {
      expect(service, isA<NetworkConnectivityService>());
    });

    test('reports cellular only where the backend can name a mobile network', () async {
      const cellularPlatforms = <TargetPlatform>{TargetPlatform.android, TargetPlatform.iOS};

      for (final platform in <TargetPlatform>[
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.linux,
        TargetPlatform.macOS,
        TargetPlatform.windows,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        final capabilities = await service.getCapabilities();

        expect(capabilities.canRead, isTrue, reason: 'unexpected reading support on ${platform.name}');
        expect(capabilities.canObserve, isTrue, reason: 'unexpected event support on ${platform.name}');
        expect(capabilities.canOfferConnectivity, isTrue, reason: 'unexpected support on ${platform.name}');
        expect(capabilities.reportsWifi, isTrue, reason: 'wi-fi is nameable on ${platform.name}');
        expect(capabilities.reportsCellular, cellularPlatforms.contains(platform), reason: '${platform.name} radio');
        expect(capabilities.platformName, platform.name);
      }
    });

    test('gives up on fuchsia, where no connectivity backend is registered', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
      final capabilities = await service.getCapabilities();

      expect(capabilities.canRead, isFalse);
      expect(capabilities.canObserve, isFalse);
      expect(capabilities.canOfferConnectivity, isFalse);
      expect(capabilities.reportsCellular, isFalse);
      expect(capabilities.reportsWifi, isFalse);
      expect(capabilities.platformName, TargetPlatform.fuchsia.name);
    });
  });
}
