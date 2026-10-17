/// The LAN sync wire protocol, ported from the 3.x
/// `features/remote_receiver/remote_sync_protocol.dart` unchanged: the same
/// ports, paths, packet shapes and parsers, so this app and a 3.x build keep
/// addressing each other.
abstract final class RemoteSyncProtocol {
  /// The HTTP port a sync server opens first, then increments while busy.
  static const int defaultHttpPort = 39888;

  /// The UDP port discovery packets are broadcast on.
  static const int discoveryPort = 39889;

  /// The `type` of a UDP discovery packet.
  static const String discoveryType = 'pure_live_discovery';

  /// The `type` of a sync payload POSTed to the settings endpoint.
  static const String syncType = 'pure_live_sync';

  /// GET only: the receiving device's identity card.
  static const String apiStatus = '/api/remote-sync/status';

  /// GET exports the device's payload, POST imports one into it.
  static const String apiSettings = '/api/remote-sync/settings';

  /// QR code for this device's sync endpoint: address and port only.
  ///
  /// A 6-digit pairing code used to travel here as well. It is gone on
  /// purpose: the device that owns the settings authorizes each request with
  /// its own on-screen confirmation (see `RemoteSyncService.confirmRequest`),
  /// which is the same gate for a scanned QR and a typed address.
  static Uri createQrUri({required String ip, required int port}) {
    return Uri(scheme: 'purelive', host: ip, port: port, path: '/sync');
  }

  /// The UDP packet a device announces itself with: identity plus endpoint.
  ///
  /// The fields are the bonsoir TXT records of the 3.x service advertisement,
  /// carried one-to-one.
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

  /// The body POSTed to the settings endpoint. [sections], when given,
  /// narrows the payload the receiver applies to those module names.
  static Map<String, dynamic> settingsPacket({required Map<String, dynamic> settings, List<String>? sections}) {
    return {'type': syncType, 'version': 1, 'settings': settings, 'sections': ?sections};
  }

  /// Parses a typed `ip:port`, `http://ip:port` or host name into a sync
  /// endpoint; null when the text is not an address.
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
    } on Object {
      return null;
    }
  }

  /// Parses a sync QR code, or a bare `host:port` as an address.
  ///
  /// A QR produced by an older version carries an extra `code` query
  /// parameter; it is ignored, so both shapes of code scan into the same
  /// endpoint.
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
