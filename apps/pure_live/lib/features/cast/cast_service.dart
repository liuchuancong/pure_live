import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show ChangeNotifier, kIsWeb;
import 'package:media_core/media_core.dart'
    show CastController, CastDevice, CastMedia, CastPosition, CastTransportState;
import 'package:media_core_cast_dlna/media_core_cast_dlna.dart' show DlnaCastBackend;

/// App-wide DLNA casting (the user's own media_core `casting` + `cast_dlna`).
///
/// The backend is pure `dart:io` — SSDP multicast discovery plus SOAP over
/// HTTP, no plugin, no method channel — so casting answers on Windows/macOS/
/// Linux out of the box and on Android once the host holds the multicast lock
/// (a manifest permission, not code here). It never runs on the web.
///
/// Discovery is started lazily on first use and kept for the process: a TV
/// that leaves the network drops out on its own through the backend's
/// cache-age expiry, so the picker never lists a sleeping device.
final class CastService extends ChangeNotifier {
  /// Creates the service over a fresh DLNA backend and controller.
  new() {
    _controller.addListener(notifyListeners);
  }

  final DlnaCastBackend _backend = DlnaCastBackend();
  late final CastController _controller = CastController(backend: _backend);
  bool _discovering = false;
  bool _disposed = false;

  /// Whether this platform can cast at all (never the web).
  bool get supported => !kIsWeb;

  /// The renderers currently on the network, in discovery order.
  List<CastDevice> get devices => _controller.devices;

  /// The device a session is live on, null when not casting.
  CastDevice? get device => _controller.device;

  /// The item loaded on [device].
  CastMedia? get media => _controller.media;

  /// Whether a cast session is running right now.
  bool get isCasting => _controller.isCasting;

  /// The receiver's transport state.
  CastTransportState get transportState => _controller.transportState;

  /// The receiver's latest playhead reading.
  CastPosition get position => _controller.position;

  /// Begins LAN discovery; idempotent.
  Future<void> startDiscovery() async {
    if (_disposed || _discovering || !supported) {
      return;
    }
    _discovering = true;
    await _backend.startDiscovery();
  }

  /// Sends [media] to [target] and starts it. The controller stops any prior
  /// device, so switching is a single call.
  Future<void> castTo(CastDevice target, CastMedia media) async {
    await startDiscovery();
    await _controller.cast(target, media);
  }

  /// Ends the session; the device stays listed.
  Future<void> stop() => _controller.stopCasting();

  /// Re-reads the receiver's state (the sheet pulls it when it opens).
  Future<void> refresh() => _controller.refresh();

  @override
  void dispose() {
    _disposed = true;
    _controller.removeListener(notifyListeners);
    unawaited(_controller.dispose());
    unawaited(_backend.dispose());
    super.dispose();
  }
}
