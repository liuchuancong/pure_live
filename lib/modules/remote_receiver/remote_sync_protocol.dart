import 'dart:math';

class RemoteSyncProtocol {
  static const int defaultHttpPort = 39888;
  static const int discoveryPort = 39889;

  static const String discoveryType = 'pure_live_discovery';
  static const String syncType = 'pure_live_sync';

  static const String apiStatus = '/api/remote-sync/status';
  static const String apiSettings = '/api/remote-sync/settings';

  /// Every settings request carries the pairing code shown on the target
  /// device; without it the target answers 403. Settings include login
  /// cookies, so being on the same network must not be enough.
  static const String pairingHeader = 'x-purelive-pairing';
  static const int pairingCodeLength = 6;

  static String newPairingCode([Random? random]) {
    final generator = random ?? Random.secure();
    return List.generate(pairingCodeLength, (_) => generator.nextInt(10)).join();
  }

  static String normalizePairingCode(String? value) => (value ?? '').replaceAll(RegExp(r'\s'), '');

  /// Constant-time comparison so response timing does not leak the code.
  static bool pairingCodesMatch(String? expected, String? provided) {
    final a = normalizePairingCode(expected);
    final b = normalizePairingCode(provided);
    if (a.length != pairingCodeLength || b.length != a.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  static Uri createQrUri({required String ip, required int port, required String code}) {
    return Uri(scheme: 'purelive', host: ip, port: port, path: '/sync', queryParameters: {'code': code});
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

  static Map<String, dynamic> settingsPacket({required Map<String, dynamic> settings}) {
    return {'type': syncType, 'version': 1, 'settings': settings};
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

  /// Parses a sync QR code; its pairing code is null for a bare address.
  static ({String ip, int port, String? code})? parseQr(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;
    if (text.startsWith('purelive:')) {
      final uri = Uri.tryParse(text);
      if (uri == null || uri.host.isEmpty || !uri.hasPort) return null;
      final code = normalizePairingCode(uri.queryParameters['code']);
      return (ip: uri.host, port: uri.port, code: code.length == pairingCodeLength ? code : null);
    }
    // A bare "host:port" is not a valid URI on its own; read it as an address.
    final address = parseHttpAddress(text);
    return address == null ? null : (ip: address.ip, port: address.port, code: null);
  }
}
