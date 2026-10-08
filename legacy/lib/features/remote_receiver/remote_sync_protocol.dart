class RemoteSyncProtocol {
  static const int defaultHttpPort = 39888;
  static const int discoveryPort = 39889;

  static const String discoveryType = 'pure_live_discovery';
  static const String syncType = 'pure_live_sync';

  static const String apiStatus = '/api/remote-sync/status';
  static const String apiSettings = '/api/remote-sync/settings';

  /// QR code for this device's sync endpoint: address and port only.
  ///
  /// A 6-digit pairing code used to travel here as well. It is gone on purpose:
  /// the device that owns the settings authorizes each request with its own
  /// on-screen confirmation (see `RemoteSyncService.confirmRequest`), which is
  /// the same gate for a scanned QR and a typed address.
  static Uri createQrUri({required String ip, required int port}) {
    return Uri(scheme: 'purelive', host: ip, port: port, path: '/sync');
  }

  static Map<String, dynamic> discoveryPacket({
    required String id,
    required String name,
    required String ip,
    required int port,
    required String platform,
    required String version,
  }) {
    return {
      'type': discoveryType,
      'id': id,
      'name': name,
      'ip': ip,
      'port': port,
      'platform': platform,
      'version': version,
    };
  }

  static Map<String, dynamic> settingsPacket({required Map<String, dynamic> settings, List<String>? sections}) {
    return {'type': syncType, 'version': 1, 'settings': settings, 'sections': ?sections};
  }

  static ({String ip, int port})? parseHttpAddress(String value) {
    var text = value.trim();
    if (text.isEmpty) return null;
    if (!text.startsWith('http://') && !text.startsWith('https://')) text = 'http://$text';
    try {
      final uri = Uri.parse(text);
      final host = uri.host.trim();
      // IPv4 addresses and host names only; free text is not an address.
      if (!RegExp(r'^[A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?$').hasMatch(host)) return null;
      final port = uri.hasPort ? uri.port : defaultHttpPort;
      if (port < 1 || port > 65535) return null;
      return (ip: host, port: port);
    } catch (_) {
      return null;
    }
  }

  /// Parses a sync QR code, or a bare `host:port` as an address.
  ///
  /// A QR produced by an older version carries an extra `code` query parameter;
  /// it is ignored, so both shapes of code scan into the same endpoint.
  static ({String ip, int port})? parseQr(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;
    if (text.startsWith('purelive:')) {
      final uri = Uri.tryParse(text);
      if (uri == null || uri.host.isEmpty || !uri.hasPort) return null;
      return (ip: uri.host, port: uri.port);
    }
    // A bare "host:port" is not a valid URI on its own; read it as an address.
    final address = parseHttpAddress(text);
    return address == null ? null : (ip: address.ip, port: address.port);
  }
}
