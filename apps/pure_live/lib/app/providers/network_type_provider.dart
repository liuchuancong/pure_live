import 'dart:async' show StreamSubscription, unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_device/live_device.dart'
    show
        NetworkConnectivity,
        NetworkConnectivityException,
        NetworkConnectivityService,
        NetworkInterface,
        PlatformNetworkConnectivityService;

/// What the active network interfaces report, plus whether this platform can
/// ever identify a cellular link.
typedef NetworkTypeState = ({
  bool ready,
  bool reportsCellular,
  Set<NetworkInterface> interfaces,
  String error,
});

const NetworkTypeState _initial = (
  ready: false,
  reportsCellular: false,
  interfaces: <NetworkInterface>{},
  error: '',
);

/// Keeps a live reading of the device's network interfaces for the quality
/// policy and the settings capability gate.
///
/// All platform work stays in live_device; this controller only remembers the
/// latest normalized reading. The reference asks the same question when a
/// room opens: is the device on a cellular interface right now?
final class NetworkTypeController extends Notifier<NetworkTypeState> {
  static const NetworkConnectivityService _service = PlatformNetworkConnectivityService();

  StreamSubscription<NetworkConnectivity>? _watch;
  bool _started = false;

  @override
  NetworkTypeState build() {
    ref.onDispose(() {
      unawaited(_watch?.cancel());
      _watch = null;
    });
    return _initial;
  }

  /// Reads capabilities and the current interfaces once, then follows
  /// changes while the window lives. Called from the app root after the
  /// first frame; a second call is free.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      final capabilities = await _service.getCapabilities();
      if (!ref.mounted) return;
      state = (
        ready: true,
        reportsCellular: capabilities.reportsCellular,
        interfaces: state.interfaces,
        error: '',
      );
      if (!capabilities.canRead) return;
      final reading = await _service.read();
      if (!ref.mounted) return;
      state = (
        ready: true,
        reportsCellular: capabilities.reportsCellular,
        interfaces: reading.interfaces,
        error: '',
      );
      if (capabilities.canObserve) _listen(capabilities.reportsCellular);
    } on NetworkConnectivityException catch (error) {
      if (!ref.mounted) return;
      state = (
        ready: true,
        reportsCellular: state.reportsCellular,
        interfaces: state.interfaces,
        error: error.message,
      );
    } on Object catch (error) {
      if (!ref.mounted) return;
      state = (
        ready: true,
        reportsCellular: state.reportsCellular,
        interfaces: state.interfaces,
        error: '$error',
      );
    }
  }

  void _listen(bool reportsCellular) {
    try {
      _watch = _service.watch().listen(
        (reading) {
          if (!ref.mounted) return;
          state = (
            ready: true,
            reportsCellular: reportsCellular,
            interfaces: reading.interfaces,
            error: '',
          );
        },
        onError: (Object _) {
          // A missed change leaves the last reading; the next explicit read
          // can recover.
        },
      );
    } on Object {
      // Observation is optional; the one-shot reading still works.
    }
  }

  /// Whether the latest reading names a cellular interface. This follows the
  /// reference's set semantics: a VPN over cellular, or Wi-Fi and cellular
  /// both present, still counts as cellular.
  bool get usesCellular => state.interfaces.contains(NetworkInterface.cellular);
}

/// The current network-interface reading and its platform capability.
final networkTypeProvider = NotifierProvider<NetworkTypeController, NetworkTypeState>(NetworkTypeController.new);
