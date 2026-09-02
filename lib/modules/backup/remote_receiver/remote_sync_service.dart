import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:bonsoir/bonsoir.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/global/platform_utils.dart';
import 'package:pure_live/common/services/settings/backup_controller.dart';
import 'package:pure_live/modules/backup/remote_receiver/remote_sync_device.dart';
import 'package:pure_live/modules/backup/remote_receiver/remote_sync_protocol.dart';

class RemoteSyncService extends GetxService {
  static RemoteSyncService get to => Get.find<RemoteSyncService>();

  final RxBool isServerRunning = false.obs;
  final RxBool isDiscovering = false.obs;
  final RxBool isSyncing = false.obs;
  final RxBool isApplying = false.obs;

  final RxString localIp = ''.obs;
  final RxInt localPort = RemoteSyncProtocol.defaultHttpPort.obs;

  final Set<String> _localIps = <String>{};

  final RxList<RemoteSyncDevice> devices = <RemoteSyncDevice>[].obs;

  HttpServer? _server;

  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;
  StreamSubscription<BonsoirDiscoveryEvent>? _discoverySubscription;

  Timer? _broadcastTimer;
  Timer? _cleanupTimer;

  final String _deviceId = '${Platform.operatingSystem}-${DateTime.now().microsecondsSinceEpoch}';

  static const String _mdnsServiceType = '_purelive._tcp';

  String get deviceName {
    switch (Platform.operatingSystem) {
      case 'android':
        return 'PureLive Android';
      case 'ios':
        return 'PureLive iPhone';
      case 'windows':
        return 'PureLive Windows';
      case 'macos':
        return 'PureLive macOS';
      case 'linux':
        return 'PureLive Linux';
      default:
        return 'PureLive';
    }
  }

  String get platform {
    return Platform.operatingSystem;
  }

  String get version {
    return '1.0.0';
  }

  String get address {
    if (localIp.value.isEmpty) {
      return '';
    }

    return '${localIp.value}:${localPort.value}';
  }

  String get qrData {
    if (localIp.value.isEmpty) {
      return '';
    }

    return RemoteSyncProtocol.createQrUri(ip: localIp.value, port: localPort.value).toString();
  }

  bool get isMobile {
    return Platform.isAndroid || Platform.isIOS;
  }

  bool get isDesktop {
    return PlatformUtils.isDesktop;
  }

  @override
  void onInit() {
    super.onInit();
    start();
  }

  Future<void> start() async {
    await _resolveLocalIp();

    if (localIp.value.isEmpty) {
      return;
    }

    await startServer();
    await startDiscovery();
  }

  Future<void> stop() async {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;

    _cleanupTimer?.cancel();
    _cleanupTimer = null;

    await _discoverySubscription?.cancel();
    _discoverySubscription = null;

    if (_discovery != null) {
      try {
        await _discovery!.stop();
      } catch (_) {}
    }

    _discovery = null;

    if (_broadcast != null) {
      try {
        await _broadcast!.stop();
      } catch (_) {}
    }

    _broadcast = null;

    await _server?.close(force: true);
    _server = null;

    devices.clear();

    isServerRunning.value = false;
    isDiscovering.value = false;
  }

  Future<void> _resolveLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false);

      final ips = <String>{};

      String? privateIp;
      String? fallbackIp;

      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          final ip = address.address.trim();

          if (ip.isEmpty) {
            continue;
          }

          if (ip.startsWith('127.')) {
            continue;
          }

          if (ip.startsWith('169.254.')) {
            continue;
          }

          ips.add(ip);

          fallbackIp ??= ip;

          if (_isPrivateIpv4(ip)) {
            privateIp ??= ip;
          }
        }
      }

      _localIps
        ..clear()
        ..addAll(ips);

      localIp.value = privateIp ?? fallbackIp ?? '';
    } catch (_) {
      _localIps.clear();
      localIp.value = '';
    }
  }

  bool _isPrivateIpv4(String ip) {
    final parts = ip.split('.');

    if (parts.length != 4) {
      return false;
    }

    final a = int.tryParse(parts[0]);
    final b = int.tryParse(parts[1]);

    if (a == null || b == null) {
      return false;
    }

    if (a == 10) {
      return true;
    }

    if (a == 172 && b >= 16 && b <= 31) {
      return true;
    }

    if (a == 192 && b == 168) {
      return true;
    }

    return false;
  }

  Future<void> startServer() async {
    if (isServerRunning.value) {
      return;
    }

    await _resolveLocalIp();

    HttpServer? server;
    var port = RemoteSyncProtocol.defaultHttpPort;

    for (var i = 0; i < 100; i++) {
      try {
        server = await HttpServer.bind(InternetAddress.anyIPv4, port, shared: true);

        break;
      } catch (_) {
        port++;
      }
    }

    if (server == null) {
      isServerRunning.value = false;
      return;
    }

    _server = server;
    localPort.value = port;
    isServerRunning.value = true;

    _server!.listen(_handleRequest);

    _startCleanupTimer();
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final response = request.response;

    response.headers.contentType = ContentType('application', 'json', charset: 'utf-8');

    response.headers.set('Access-Control-Allow-Origin', '*');

    response.headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');

    response.headers.set('Access-Control-Allow-Headers', 'Content-Type');

    if (request.method == 'OPTIONS') {
      response.statusCode = HttpStatus.ok;
      await response.close();
      return;
    }

    try {
      switch (request.uri.path) {
        case RemoteSyncProtocol.apiStatus:
          await _handleStatus(request);
          return;

        case RemoteSyncProtocol.apiSettings:
          await _handleSettings(request);
          return;

        default:
          response.statusCode = HttpStatus.notFound;

          await _writeResponse(response, {'code': 404, 'msg': 'Not Found', 'data': false});
      }
    } catch (_) {
      response.statusCode = HttpStatus.internalServerError;

      await _writeResponse(response, {'code': 500, 'msg': 'Internal Server Error', 'data': false});
    }
  }

  Future<void> _handleStatus(HttpRequest request) async {
    await _writeResponse(request.response, {
      'code': 200,
      'msg': 'ok',
      'data': {
        'id': _deviceId,
        'name': deviceName,
        'platform': platform,
        'version': version,
        'ip': localIp.value,
        'port': localPort.value,
      },
    });
  }

  Future<void> _handleSettings(HttpRequest request) async {
    if (request.method != 'POST') {
      request.response.statusCode = HttpStatus.methodNotAllowed;

      await _writeResponse(request.response, {'code': 405, 'msg': 'Method Not Allowed', 'data': false});

      return;
    }

    try {
      final content = await utf8.decoder.bind(request).join();

      if (content.trim().isEmpty) {
        request.response.statusCode = HttpStatus.badRequest;

        await _writeResponse(request.response, {'code': 400, 'msg': 'Empty request', 'data': false});

        return;
      }

      final body = jsonDecode(content);

      if (body is! Map<String, dynamic>) {
        request.response.statusCode = HttpStatus.badRequest;

        await _writeResponse(request.response, {'code': 400, 'msg': 'Invalid request', 'data': false});

        return;
      }

      final type = body['type']?.toString();

      if (type != RemoteSyncProtocol.syncType) {
        request.response.statusCode = HttpStatus.badRequest;

        await _writeResponse(request.response, {'code': 400, 'msg': 'Invalid sync type', 'data': false});

        return;
      }

      final settings = body['settings'];

      if (settings is! Map) {
        request.response.statusCode = HttpStatus.badRequest;

        await _writeResponse(request.response, {'code': 400, 'msg': 'Settings is empty', 'data': false});

        return;
      }

      isSyncing.value = true;

      final success = await _applyRemoteSettings(Map<String, dynamic>.from(settings));

      isSyncing.value = false;

      await _writeResponse(request.response, {
        'code': success ? 200 : 500,
        'msg': success ? 'ok' : 'apply settings failed',
        'data': success,
      });
    } catch (_) {
      isSyncing.value = false;

      request.response.statusCode = HttpStatus.internalServerError;

      await _writeResponse(request.response, {'code': 500, 'msg': 'Internal Server Error', 'data': false});
    }
  }

  Future<bool> _applyRemoteSettings(Map<String, dynamic> settings) async {
    try {
      final backup = Get.find<BackupController>();

      backup.importAllSettings(settings);

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _writeResponse(HttpResponse response, Map<String, dynamic> data) async {
    response.write(jsonEncode(data));
    await response.close();
  }

  Future<bool> startDiscovery() async {
    if (isDiscovering.value) {
      return true;
    }

    await _resolveLocalIp();

    if (localIp.value.isEmpty) {
      return false;
    }

    try {
      await _discoverySubscription?.cancel();
      _discoverySubscription = null;

      if (_discovery != null) {
        try {
          await _discovery!.stop();
        } catch (_) {}
      }

      _discovery = null;

      final discovery = BonsoirDiscovery(type: _mdnsServiceType);

      _discovery = discovery;

      await discovery.initialize();

      final eventStream = discovery.eventStream;

      if (eventStream == null) {
        isDiscovering.value = false;
        return false;
      }

      _discoverySubscription = eventStream.listen(
        (event) {
          unawaited(_handleDiscoveryEvent(event, discovery));
        },
        onError: (_) {
          isDiscovering.value = false;
        },
      );

      await discovery.start();

      isDiscovering.value = true;

      await _startBroadcast();

      return true;
    } catch (_) {
      isDiscovering.value = false;
      return false;
    }
  }

  Future<void> _handleDiscoveryEvent(BonsoirDiscoveryEvent event, BonsoirDiscovery discovery) async {
    switch (event) {
      case BonsoirDiscoveryServiceFoundEvent():
        final service = event.service;
        if (_isSelfService(service)) {
          return;
        }
        try {
          await service.resolve(discovery.serviceResolver);
        } catch (_) {}
      case BonsoirDiscoveryServiceResolvedEvent():
        final service = event.service;
        if (_isSelfService(service)) {
          return;
        }
        _addOrUpdateDevice(service);
      case BonsoirDiscoveryServiceUpdatedEvent():
        final service = event.service;
        if (_isSelfService(service)) {
          return;
        }
        _addOrUpdateDevice(service);
      case BonsoirDiscoveryServiceLostEvent():
        final service = event.service;
        _removeDevice(service);
      default:
        break;
    }
  }

  bool _isSelfService(BonsoirService service) {
    final attributes = service.attributes;

    final id = attributes['id'];

    if (id != null && id == _deviceId) {
      return true;
    }

    for (final address in service.hostAddresses) {
      if (_localIps.contains(address)) {
        return true;
      }

      if (address == localIp.value) {
        return true;
      }
    }

    return false;
  }

  void _addOrUpdateDevice(BonsoirService service) {
    final attributes = service.attributes;

    final id = attributes['id']?.trim() ?? '';

    if (id.isEmpty) {
      return;
    }

    if (id == _deviceId) {
      return;
    }

    final name = attributes['name']?.trim().isNotEmpty == true ? attributes['name']!.trim() : service.name;

    final devicePlatform = attributes['platform'] ?? '';
    final deviceVersion = attributes['version'] ?? '';

    final ip = _resolveServiceIp(service);

    if (ip == null || ip.isEmpty) {
      return;
    }

    final port = service.port;

    if (port <= 0) {
      return;
    }

    final device = RemoteSyncDevice(
      id: id,
      name: name,
      platform: devicePlatform,
      version: deviceVersion,
      ip: ip,
      port: port,
      lastSeen: DateTime.now(),
    );

    final indexById = devices.indexWhere((item) => item.id == device.id);

    if (indexById >= 0) {
      devices[indexById] = device;
      return;
    }

    final indexByIp = devices.indexWhere((item) => item.ip.trim() == device.ip.trim());

    if (indexByIp >= 0) {
      devices[indexByIp] = device;
      return;
    }

    devices.add(device);
  }

  void _removeDevice(BonsoirService service) {
    final id = service.attributes['id'];

    if (id == null || id.isEmpty) {
      return;
    }

    devices.removeWhere((device) => device.id == id);
  }

  String? _resolveServiceIp(BonsoirService service) {
    final addresses = service.hostAddresses;

    final ipv4 = addresses.where(_isValidIpv4).toList();

    if (ipv4.isEmpty) {
      return null;
    }

    if (localIp.value.isNotEmpty) {
      final localPrefix = _ipv4Prefix(localIp.value);

      if (localPrefix != null) {
        for (final ip in ipv4) {
          if (_ipv4Prefix(ip) == localPrefix) {
            return ip;
          }
        }
      }
    }

    for (final ip in ipv4) {
      if (_isPrivateIpv4(ip)) {
        return ip;
      }
    }

    return ipv4.first;
  }

  bool _isValidIpv4(String ip) {
    final parts = ip.split('.');

    if (parts.length != 4) {
      return false;
    }

    for (final part in parts) {
      final value = int.tryParse(part);

      if (value == null || value < 0 || value > 255) {
        return false;
      }
    }

    return true;
  }

  String? _ipv4Prefix(String ip) {
    final parts = ip.split('.');

    if (parts.length != 4) {
      return null;
    }

    return '${parts[0]}.${parts[1]}.${parts[2]}';
  }

  Future<void> _startBroadcast() async {
    if (localPort.value <= 0) {
      return;
    }

    if (_broadcast != null) {
      try {
        await _broadcast!.stop();
      } catch (_) {}

      _broadcast = null;
    }

    final service = BonsoirService(
      name: 'PureLive-${_deviceId.hashCode.abs()}',
      type: _mdnsServiceType,
      port: localPort.value,
      attributes: {'id': _deviceId, 'name': deviceName, 'platform': platform, 'version': version, 'ip': localIp.value},
    );

    final broadcast = BonsoirBroadcast(service: service);

    _broadcast = broadcast;

    await broadcast.initialize();
    await broadcast.start();
  }

  void _startCleanupTimer() {
    _cleanupTimer?.cancel();

    _cleanupTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      final now = DateTime.now();

      devices.removeWhere((device) {
        return now.difference(device.lastSeen).inSeconds > 8;
      });
    });
  }

  Future<bool> syncToDevice(RemoteSyncDevice device) {
    return syncToAddress(device.ip, device.port);
  }

  Future<bool> syncToAddress(String ip, int port) async {
    if (isSyncing.value) {
      return false;
    }

    isSyncing.value = true;

    try {
      final backup = Get.find<BackupController>();

      final settings = backup.exportAllSettings(includeSensitiveData: true);

      final client = HttpClient();

      try {
        final request = await client.postUrl(
          Uri.parse(
            'http://$ip:$port'
            '${RemoteSyncProtocol.apiSettings}',
          ),
        );

        request.headers.contentType = ContentType('application', 'json', charset: 'utf-8');

        request.write(jsonEncode(RemoteSyncProtocol.settingsPacket(settings: settings)));

        final response = await request.close();

        final responseBody = await utf8.decoder.bind(response).join();

        if (response.statusCode != HttpStatus.ok) {
          return false;
        }

        final result = jsonDecode(responseBody);

        return result is Map && result['data'] == true;
      } finally {
        client.close(force: true);
      }
    } catch (_) {
      return false;
    } finally {
      isSyncing.value = false;
    }
  }

  Future<bool> receiveFromAddress(String ip, int port) async {
    if (isApplying.value) {
      return false;
    }

    isApplying.value = true;

    try {
      final client = HttpClient();

      try {
        final request = await client.getUrl(
          Uri.parse(
            'http://$ip:$port'
            '${RemoteSyncProtocol.apiStatus}',
          ),
        );

        final response = await request.close();

        if (response.statusCode != HttpStatus.ok) {
          return false;
        }

        return true;
      } finally {
        client.close(force: true);
      }
    } catch (_) {
      return false;
    } finally {
      isApplying.value = false;
    }
  }

  Future<Map<String, dynamic>?> getRemoteSettings(String ip, int port) async {
    try {
      final client = HttpClient();

      try {
        final request = await client.getUrl(
          Uri.parse(
            'http://$ip:$port'
            '${RemoteSyncProtocol.apiStatus}',
          ),
        );

        final response = await request.close();

        if (response.statusCode != HttpStatus.ok) {
          return null;
        }

        final body = await utf8.decoder.bind(response).join();

        final result = jsonDecode(body);

        if (result is! Map) {
          return null;
        }

        final data = result['data'];

        if (data is! Map) {
          return null;
        }

        return Map<String, dynamic>.from(data);
      } finally {
        client.close(force: true);
      }
    } catch (_) {
      return null;
    }
  }

  Future<bool> syncByAddress(String value) async {
    final parsed = RemoteSyncProtocol.parseHttpAddress(value);

    if (parsed == null) {
      return false;
    }

    return syncToAddress(parsed.ip, parsed.port);
  }

  Future<bool> syncByQr(String value) async {
    final parsed = RemoteSyncProtocol.parseQr(value);

    if (parsed == null) {
      return false;
    }

    return syncToAddress(parsed.ip, parsed.port);
  }

  Future<bool> receiveByQr(String value) async {
    final parsed = RemoteSyncProtocol.parseQr(value);

    if (parsed == null) {
      return false;
    }

    return receiveFromAddress(parsed.ip, parsed.port);
  }

  @override
  void onClose() {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;

    _cleanupTimer?.cancel();
    _cleanupTimer = null;

    _discoverySubscription?.cancel();
    _discoverySubscription = null;

    _discovery?.stop();
    _discovery = null;

    _broadcast?.stop();
    _broadcast = null;

    _server?.close(force: true);
    _server = null;

    isServerRunning.value = false;
    isDiscovering.value = false;

    super.onClose();
  }
}
