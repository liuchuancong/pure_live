class RemoteSyncProtocol {
  static const int defaultHttpPort = 39888;
  static const int discoveryPort = 39889;

  static const String discoveryType = 'pure_live_discovery';
  static const String syncType = 'pure_live_sync';

  static const String apiStatus = '/api/remote-sync/status';
  static const String apiSettings = '/api/remote-sync/settings';

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

  static Map<String, dynamic> settingsPacket({required Map<String, dynamic> settings}) {
    return {'type': syncType, 'version': 1, 'settings': settings};
  }

  static ({String ip, int port})? parseHttpAddress(String value) {
    var text = value.trim();

    if (text.isEmpty) {
      return null;
    }

    if (!text.startsWith('http://') && !text.startsWith('https://')) {
      text = 'http://$text';
    }

    try {
      final uri = Uri.parse(text);

      final host = uri.host.trim();

      if (host.isEmpty) {
        return null;
      }

      final port = uri.hasPort ? uri.port : 80;

      if (port < 1 || port > 65535) {
        return null;
      }

      return (ip: host, port: port);
    } catch (_) {
      return null;
    }
  }

  static ({String ip, int port})? parseQr(String value) {
    final text = value.trim();

    if (text.isEmpty) {
      return null;
    }

    try {
      final uri = Uri.parse(text);

      if (uri.scheme == 'purelive') {
        if (uri.host.isEmpty || !uri.hasPort) {
          return null;
        }

        return (ip: uri.host, port: uri.port);
      }

      return parseHttpAddress(text);
    } catch (_) {
      return null;
    }
  }
}
