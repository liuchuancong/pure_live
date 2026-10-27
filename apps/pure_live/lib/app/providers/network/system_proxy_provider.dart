import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_device/live_device.dart';

/// The proxy the operating system itself is configured to use.
///
/// The reading is a probe of the machine, not of a store: it is taken once when
/// something first asks and re-taken when the network page is opened or the
/// user says so, because a proxy client that starts or stops while the app runs
/// is exactly the case this mode is for. Callers never wait for it — the first
/// answer is [SystemProxyStatus.probing], and anything built on it rebuilds
/// when the real value lands.
final class SystemProxyController extends Notifier<SystemProxyEndpoint> {
  bool _disposed = false;

  @override
  SystemProxyEndpoint build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    unawaited(refresh());
    return const SystemProxyEndpoint(status: SystemProxyStatus.probing);
  }

  /// Re-reads the platform, replacing [state] with whatever it answers.
  Future<void> refresh() async {
    final endpoint = await const PlatformSystemProxyService().read();
    // A window closed while the probe ran has nobody left to tell.
    if (_disposed) return;
    state = endpoint;
  }
}

/// The system proxy reading.
final systemProxyProvider = NotifierProvider<SystemProxyController, SystemProxyEndpoint>(SystemProxyController.new);
