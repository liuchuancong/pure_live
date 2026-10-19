import 'dart:math';

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

  /// The header with the pairing code shown on the target device; settings
  /// hold login cookies, so being on the same network is not enough (3.x).
  static const String pairingHeader = 'x-purelive-pairing';

  /// Digits of a pairing code.
  static const int pairingCodeLength = 6;

  /// A new random pairing code.
  static String newPairingCode([Random? random]) {
    final generator = random ?? Random.secure();
    return List.generate(pairingCodeLength, (_) => generator.nextInt(10)).join();
  }

  /// [value] without white space.
  static String normalizePairingCode(String? value) => (value ?? '').replaceAll(RegExp(r'\s'), '');

  /// Compares codes in constant time, so timing does not leak the code.
  static bool pairingCodesMatch(String? expected, String? provided) {
    final a = normalizePairingCode(expected);
    final b = normalizePairingCode(provided);
    if (a.length != pairingCodeLength || b.length != a.length) {
      return false;
    }
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  /// QR code for this device's sync endpoint: address, port and the pairing
  /// code shown next to it, so scanning needs no retyping.
  static Uri createQrUri({required String ip, required int port, required String code}) {
    return Uri(scheme: 'purelive', host: ip, port: port, path: '/sync', queryParameters: {'code': code});
  }

  /// The key of the status answer that lists the parts a device takes on
  /// their own (new in v4, J05.1): only such a device gets a packet with
  /// some parts left out. 3.x resets every section a packet lacks, so a
  /// device that does not answer this key always gets everything.
  static const String partsKey = 'syncParts';

  /// Whether a status answer's [data] says the device takes parts on their
  /// own ([partsKey]).
  static bool takesParts(Object? data) => data is Map && data[partsKey] is List;

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

  /// The `sections` of a settings packet: null when it has none (a whole
  /// backup) or when it is not a list of names.
  static List<String>? sectionsOf(Map<Object?, Object?> packet) {
    final sections = packet['sections'];
    if (sections is! List || sections.isEmpty) {
      return null;
    }
    final names = sections.whereType<String>().toList(growable: false);
    return names.length == sections.length ? names : null;
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

  /// A sync QR code's text or a typed address; the pairing code is null for
  /// a plain address and carried by a scanned (or pasted) sync code.
  static ({String ip, int port, String? code})? parseQr(String value) {
    final text = value.trim();
    if (text.isEmpty) {
      return null;
    }
    if (text.startsWith('purelive:')) {
      final uri = Uri.tryParse(text);
      if (uri == null || uri.host.isEmpty || !uri.hasPort) {
        return null;
      }
      final code = normalizePairingCode(uri.queryParameters['code']);
      return (ip: uri.host, port: uri.port, code: code.length == pairingCodeLength ? code : null);
    }
    final address = parseHttpAddress(text);
    return address == null ? null : (ip: address.ip, port: address.port, code: null);
  }
}
