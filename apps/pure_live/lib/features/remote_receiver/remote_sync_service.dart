import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:live_library/live_library.dart';
import 'package:live_storage/live_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:pure_live/app/preferences/app_preferences.dart';
import 'package:pure_live/features/remote_receiver/remote_sync_device.dart';
import 'package:pure_live/features/remote_receiver/remote_sync_payload.dart';
import 'package:pure_live/features/remote_receiver/remote_sync_protocol.dart';

/// The LAN sync service, ported from the 3.x `RemoteSyncService`: it serves
/// this device's payload over HTTP, applies an incoming payload through this
/// app's real repositories, and sends/receives to a peer by address.
///
/// Wire behaviour is the 3.x one, so a 3.x build and this app interoperate:
/// the same envelope (`{code, msg, data}`), the same endpoints, the same
/// gate — every read or overwrite of this device's payload needs the
/// on-screen [confirmRequest] answer, and a page-less service refuses
/// everything.
///
/// One deviation: 3.x discovered peers over mDNS (bonsoir), a package this
/// app does not carry. Discovery runs over the protocol's own UDP broadcast
/// (`RemoteSyncProtocol.discoveryPacket` on
/// `RemoteSyncProtocol.discoveryPort`) instead, with the same packet fields
/// the 3.x mDNS TXT records carried. A 3.x peer is reached by address (typed
/// or QR); two of this app's builds also find each other by themselves.
final class RemoteSyncService extends ChangeNotifier {
  /// A service over this app's repositories.
  new({required this.follows, required this.history, required this.preferences}) : _inert = false;

  /// A service that never binds a port, never broadcasts and never opens a
  /// box — what the render tests hand the page so pumping it cannot touch
  /// the network or the storage layer.
  new inert({required this.follows, required this.history, required this.preferences}) : _inert = true;

  /// Where followed rooms and groups are applied and exported from.
  final FollowRepository follows;

  /// Where watch history is applied and exported from.
  final HistoryRepository history;

  /// Where the general preference groups are exported from and applied to —
  /// the store the settings pages edit.
  final AppPreferencesStore preferences;

  /// Whether this is the inert render-test shape.
  final bool _inert;

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  bool _isServerRunning = false;
  bool _isDiscovering = false;
  bool _isSyncing = false;
  bool _isApplying = false;

  String _localIp = '';
  int _localPort = RemoteSyncProtocol.defaultHttpPort;
  var _devices = <RemoteSyncDevice>[];

  /// Whether the HTTP sync server answers.
  bool get isServerRunning => _isServerRunning;

  /// Whether LAN discovery is listening and announcing.
  bool get isDiscovering => _isDiscovering;

  /// Whether a payload is being sent or applied right now.
  bool get isSyncing => _isSyncing;

  /// Whether an incoming payload is being applied right now.
  bool get isApplying => _isApplying;

  /// The LAN address the server picked, empty when none was found.
  String get localIp => _localIp;

  /// The port the server bound.
  int get localPort => _localPort;

  /// The devices currently on the LAN, in discovery order.
  List<RemoteSyncDevice> get devices => List.unmodifiable(_devices);

  /// Asks the user whether the remote address may read ('export') or
  /// overwrite ('import') this device's payload. Requests are refused
  /// without it.
  Future<bool> Function(String action, String remoteAddress)? confirmRequest;

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  /// The UDP announcement cadence; the 3.x mDNS TTL served the same role.
  static const Duration _announceInterval = Duration(seconds: 5);

  /// How long a device stays listed without an announcement.
  static const Duration _deviceTtl = Duration(seconds: 120);

  /// The preference document this feature owns (the appearance store's box,
  /// one document per group — the appearance_preferences idiom).
  static const String _prefsBox = 'settings.preferences';
  static const String _prefsDocument = 'preferences.remote_sync.v1';
  static const String _deviceIdKey = 'deviceId';

  /// The shield lists' box and keys — the shield page's own storage.
  static const String _shieldBox = 'settings.shield';
  static const String _shieldKeywordsKey = 'shield.keywords';
  static const String _shieldUsersKey = 'shield.users';

  final Set<String> _localIps = <String>{};
  String _deviceId = '';
  String _version = '1.0.0';

  HttpServer? _server;
  RawDatagramSocket? _discoverySocket;
  Timer? _announceTimer;
  Timer? _cleanupTimer;

  /// The shield lists' repository, opened once; null until [start] opened
  /// it or opening failed.
  HiveStorageRepository<List<String>>? _shieldRepository;
  Future<HiveStorageRepository<List<String>>>? _shieldOpening;
  bool _disposed = false;
  bool _running = false;

  // ---------------------------------------------------------------------------
  // Device information
  // ---------------------------------------------------------------------------

  /// This device's sync identity, persisted once and reused.
  String get deviceId => _deviceId;

  /// The display name, derived from the platform as in 3.x.
  String get deviceName => switch (Platform.operatingSystem) {
    'android' => 'PureLive Android',
    'ios' => 'PureLive iPhone',
    'windows' => 'PureLive Windows',
    'macos' => 'PureLive macOS',
    'linux' => 'PureLive Linux',
    _ => 'PureLive',
  };

  /// The operating system advertised to peers.
  String get platform => Platform.operatingSystem;

  /// The app version advertised to peers.
  String get version => _version;

  /// This device's `ip:port`, empty when no address was found.
  String get address => _localIp.isEmpty ? '' : '$_localIp:$_localPort';

  /// The QR payload of this device's sync endpoint, empty when no address.
  String get qrData =>
      _localIp.isEmpty ? '' : RemoteSyncProtocol.createQrUri(ip: _localIp, port: _localPort).toString();

  /// The mDNS-era broadcast name; the identity suffix keeps two devices of
  /// one user distinguishable in a peer's own list.
  String get broadcastName {
    final id = _deviceId.length > 6 ? _deviceId.substring(_deviceId.length - 6) : _deviceId;
    return 'PureLive-$id';
  }

  /// The sections this device exports, for the picker UI.
  List<String> exportSectionNames() => RemoteSyncPayload.sectionNames;

  /// The name the device behind [address] announced with, or null when it
  /// was never heard on discovery — what the confirmation dialog shows so
  /// the user answers to a name and not to a bare IP (3.x's `nameOf`).
  String? nameOf(String address) {
    final at = address.lastIndexOf(':');
    final ip = at > 0 ? address.substring(0, at) : address;
    for (final device in _devices) {
      if (device.ip == ip) {
        return device.name;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Starts the server and discovery; idempotent while running. The inert
  /// shape answers "started" without ever touching a socket or a box.
  Future<void> start() async {
    if (_disposed || _running || _inert) {
      return;
    }
    _running = true;
    try {
      await _loadDeviceId();
      await _openShieldRepository();
      await _refreshNetworkInfo();
      if (_disposed || _localIp.isEmpty) {
        return;
      }
      await _startServer();
      if (_disposed) {
        return;
      }
      await _startDiscovery();
    } finally {
      _running = false;
    }
  }

  /// Stops serving and discovery; [start] can resume.
  Future<void> stop() async {
    _announceTimer?.cancel();
    _announceTimer = null;
    _cleanupTimer?.cancel();
    _cleanupTimer = null;

    final socket = _discoverySocket;
    _discoverySocket = null;
    if (socket != null) {
      try {
        socket.close();
      } on Object {
        // Closing an already-closed socket is not a state the user can act on.
      }
    }
    _setDiscovering(false);

    final server = _server;
    _server = null;
    if (server != null) {
      try {
        await server.close(force: true);
      } on Object {
        // A server that died on its own needs no second close.
      }
    }
    _isServerRunning = false;

    _devices = const [];
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(stop());
    super.dispose();
  }

  Future<void> _loadDeviceId() async {
    if (_deviceId.isNotEmpty) {
      return;
    }
    try {
      final repository = HiveStorageRepository<Map<dynamic, dynamic>>(
        box: await StorageBoxManager().keyed<Map<dynamic, dynamic>>(_prefsBox),
      );
      final stored = repository.get(_prefsDocument)?[_deviceIdKey]?.toString() ?? '';
      _deviceId = stored.isNotEmpty ? stored : '${Platform.operatingSystem}-${DateTime.now().microsecondsSinceEpoch}';
      await repository.save(_prefsDocument, {_deviceIdKey: _deviceId});
    } on Object {
      // A read-only box still leaves the session usable: the identity just
      // does not survive the process.
      _deviceId = '${Platform.operatingSystem}-${DateTime.now().microsecondsSinceEpoch}';
    }
    try {
      _version = (await PackageInfo.fromPlatform()).version;
    } on Object {
      _version = '1.0.0';
    }
  }

  // ---------------------------------------------------------------------------
  // Network
  // ---------------------------------------------------------------------------

  Future<void> _refreshNetworkInfo() async {
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      final ips = <String>{};
      String? privateIp;
      String? fallbackIp;
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          final ip = address.address.trim();
          if (ip.isEmpty || ip.startsWith('127.') || ip.startsWith('169.254.') || !_isValidIpv4(ip)) {
            continue;
          }
          ips.add(ip);
          fallbackIp ??= ip;
          if (_isPrivateIpv4Address(ip) && (privateIp == null || _ipv4Priority(ip) > _ipv4Priority(privateIp))) {
            privateIp = ip;
          }
        }
      }
      _localIps
        ..clear()
        ..addAll(ips);
      _localIp = privateIp ?? fallbackIp ?? '';
    } on Object {
      _localIps.clear();
      _localIp = '';
    }
    _notify();
  }

  int _ipv4Priority(String ip) {
    if (ip.startsWith('192.168.')) {
      return 3;
    }
    if (ip.startsWith('10.')) {
      return 2;
    }
    final parts = ip.split('.');
    if (parts.length == 4 && parts[0] == '172') {
      final second = int.tryParse(parts[1]);
      if (second != null && second >= 16 && second <= 31) {
        return 1;
      }
    }
    return 0;
  }

  bool _isPrivateIpv4Address(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) {
      return false;
    }
    final a = int.tryParse(parts[0]);
    final b = int.tryParse(parts[1]);
    if (a == null || b == null) {
      return false;
    }
    return a == 10 || (a == 172 && b >= 16 && b <= 31) || (a == 192 && b == 168);
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

  // ---------------------------------------------------------------------------
  // HTTP server
  // ---------------------------------------------------------------------------

  Future<void> _startServer() async {
    if (_disposed || _isServerRunning) {
      return;
    }
    await _refreshNetworkInfo();
    if (_disposed) {
      return;
    }
    HttpServer? server;
    var port = RemoteSyncProtocol.defaultHttpPort;
    for (var i = 0; i < 100; i++) {
      try {
        server = await HttpServer.bind(InternetAddress.anyIPv4, port, shared: true);
        break;
      } on Object {
        port++;
      }
    }
    if (server == null || _disposed) {
      try {
        await server?.close(force: true);
      } on Object {
        // Nothing was served; a failed bind left nothing to close.
      }
      _isServerRunning = false;
      _notify();
      return;
    }
    _server = server;
    _localPort = port;
    _isServerRunning = true;
    _notify();
    server.listen(
      _handleRequest,
      onError: (Object _) {
        if (!_disposed) {
          _isServerRunning = false;
          _notify();
        }
      },
    );
    _startCleanupTimer();
  }

  Future<void> _handleRequest(HttpRequest request) async {
    if (_disposed) {
      try {
        await request.response.close();
      } on Object {
        // A disposed service owes nobody a response.
      }
      return;
    }
    final response = request.response;
    // No CORS headers: a web page in a browser on the network must not be
    // able to read this device's payload.
    response.headers.contentType = ContentType('application', 'json', charset: 'utf-8');
    try {
      switch (request.uri.path) {
        case RemoteSyncProtocol.apiStatus:
          await _handleStatus(request);
        case RemoteSyncProtocol.apiSettings:
          await _handleSettings(request);
        default:
          response.statusCode = HttpStatus.notFound;
          await _writeResponse(response, {'code': 404, 'msg': 'Not Found', 'data': false});
      }
    } on Object {
      try {
        response.statusCode = HttpStatus.internalServerError;
        await _writeResponse(response, {'code': 500, 'msg': 'Internal Server Error', 'data': false});
      } on Object {
        // Response may already be closed.
      }
    }
  }

  /// GET /status — only returns device information.
  Future<void> _handleStatus(HttpRequest request) async {
    if (request.method != 'GET') {
      await _writeMethodNotAllowed(request.response);
      return;
    }
    await _writeResponse(request.response, {
      'code': 200,
      'msg': 'ok',
      'data': {
        'id': _deviceId,
        'name': deviceName,
        'platform': platform,
        'version': version,
        'ip': _localIp,
        'port': _localPort,
      },
    });
  }

  /// /settings — GET exports, POST imports. Both need the on-screen confirm.
  Future<void> _handleSettings(HttpRequest request) async {
    final action = switch (request.method) {
      'GET' => 'export',
      'POST' => 'import',
      _ => null,
    };
    if (action != null && !await _confirm(action, request)) {
      request.response.statusCode = HttpStatus.forbidden;
      await _writeResponse(request.response, {'code': 403, 'msg': 'Rejected on the device', 'data': false});
      return;
    }
    switch (request.method) {
      case 'GET':
        await _handleGetSettings(request);
      case 'POST':
        await _handlePostSettings(request);
      default:
        await _writeMethodNotAllowed(request.response);
    }
  }

  /// GET /settings — this device's payload leaves it.
  Future<void> _handleGetSettings(HttpRequest request) async {
    try {
      final settings = buildLocalPayload();
      await _writeResponse(request.response, {'code': 200, 'msg': 'ok', 'data': settings});
    } on Object {
      request.response.statusCode = HttpStatus.internalServerError;
      await _writeResponse(request.response, {'code': 500, 'msg': 'Export settings failed', 'data': false});
    }
  }

  /// POST /settings — another device's payload arrives and is applied.
  Future<void> _handlePostSettings(HttpRequest request) async {
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
      if (body['type']?.toString() != RemoteSyncProtocol.syncType) {
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
      final sections = body['sections'];
      _isSyncing = true;
      _notify();
      final success = await applyRemoteSettings(
        Map<String, dynamic>.from(settings),
        sections: sections is List ? [for (final entry in sections) entry.toString()] : null,
      );
      _isSyncing = false;
      _notify();
      await _writeResponse(request.response, {
        'code': success ? 200 : 500,
        'msg': success ? 'ok' : 'apply settings failed',
        'data': success,
      });
    } on Object {
      _isSyncing = false;
      _notify();
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await _writeResponse(request.response, {'code': 500, 'msg': 'Internal Server Error', 'data': false});
      } on Object {
        // Response may already be closed.
      }
    }
  }

  Future<bool> _confirm(String action, HttpRequest request) async {
    final ask = confirmRequest;
    if (ask == null || _disposed) {
      return false;
    }
    final remote = request.connectionInfo?.remoteAddress.address ?? '';
    try {
      return await ask(action, remote);
    } on Object {
      return false;
    }
  }

  Future<void> _writeMethodNotAllowed(HttpResponse response) async {
    response.statusCode = HttpStatus.methodNotAllowed;
    await _writeResponse(response, {'code': 405, 'msg': 'Method Not Allowed', 'data': false});
  }

  Future<void> _writeResponse(HttpResponse response, Map<String, dynamic> data) async {
    response.write(jsonEncode(data));
    await response.close();
  }

  // ---------------------------------------------------------------------------
  // Export / apply
  // ---------------------------------------------------------------------------

  /// Reads this device's payload from its real stores, narrowed to
  /// [sections] when the picker ticked a subset.
  Map<String, dynamic> buildLocalPayload({Iterable<String>? sections}) {
    return RemoteSyncPayload.buildExport(
      preferences: preferences.value,
      follows: follows.rooms,
      groups: follows.groups,
      history: history.records,
      shieldKeywords: _shieldRepository?.get(_shieldKeywordsKey) ?? const <String>[],
      shieldUsers: _shieldRepository?.get(_shieldUsersKey) ?? const <String>[],
      sections: sections,
    );
  }

  /// Applies the received payload, narrowed to [sections] when the receiver
  /// ticked a subset on the module page.
  Future<bool> applyRemoteSettings(Map<String, dynamic> settings, {Iterable<String>? sections}) async {
    try {
      final repository = _shieldRepository ?? await _openShieldRepository();
      Future<void> sink(String key, List<String> values) => repository.save(key, values);
      return await RemoteSyncPayload.apply(
        settings,
        sections: sections,
        preferences: preferences,
        follows: follows,
        history: history,
        shield: sink,
      );
    } on Object {
      return false;
    }
  }

  /// Opens the shield box once; a failure keeps the payload working without
  /// the two shield lists.
  Future<HiveStorageRepository<List<String>>> _openShieldRepository() {
    final existing = _shieldRepository;
    if (existing != null) {
      return Future<HiveStorageRepository<List<String>>>.value(existing);
    }
    final opening = _shieldOpening ??= StorageBoxManager()
        .keyed<List<String>>(_shieldBox)
        .then((box) => HiveStorageRepository<List<String>>(box: box));
    return opening.then((repository) {
      _shieldRepository = repository;
      return repository;
    });
  }

  // ---------------------------------------------------------------------------
  // UDP discovery
  // ---------------------------------------------------------------------------

  Future<bool> _startDiscovery() async {
    if (_disposed) {
      return false;
    }
    if (_isDiscovering) {
      return true;
    }
    await _refreshNetworkInfo();
    if (_disposed || _localIp.isEmpty) {
      return false;
    }
    try {
      final oldSocket = _discoverySocket;
      _discoverySocket = null;
      if (oldSocket != null) {
        try {
          oldSocket.close();
        } on Object {
          // A dead discovery socket needs no second close.
        }
      }
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, RemoteSyncProtocol.discoveryPort);
      if (_disposed) {
        socket.close();
        return false;
      }
      socket.broadcastEnabled = true;
      socket.listen(
        (event) {
          if (event != RawSocketEvent.read) {
            return;
          }
          final datagram = socket.receive();
          if (datagram != null) {
            _handleDiscoveryPacket(datagram);
          }
        },
        onError: (Object _) {
          if (!_disposed) {
            _setDiscovering(false);
          }
        },
      );
      _discoverySocket = socket;
      _setDiscovering(true);
      unawaited(_announce());
      _announceTimer?.cancel();
      _announceTimer = Timer.periodic(_announceInterval, (_) {
        if (!_disposed) {
          unawaited(_announce());
        }
      });
      return true;
    } on Object {
      _setDiscovering(false);
      return false;
    }
  }

  /// Broadcasts this device's announcement to the general and the subnet
  /// broadcast addresses.
  Future<void> _announce() async {
    final socket = _discoverySocket;
    if (_disposed || socket == null) {
      return;
    }
    final packet = RemoteSyncProtocol.discoveryPacket(
      id: _deviceId,
      name: deviceName,
      ip: _localIp,
      port: _localPort,
      platform: platform,
      version: version,
    );
    final targets = <String>{'255.255.255.255', for (final ip in _localIps) '${_ipv4Prefix(ip) ?? ip}.255'};
    for (final target in targets) {
      try {
        socket.send(utf8.encode(jsonEncode(packet)), InternetAddress(target), RemoteSyncProtocol.discoveryPort);
      } on Object {
        // One unreachable broadcast address must not stop the others.
      }
    }
  }

  void _handleDiscoveryPacket(Datagram datagram) {
    if (_disposed) {
      return;
    }
    Map<String, dynamic> packet;
    try {
      final decoded = jsonDecode(utf8.decode(datagram.data));
      if (decoded is! Map<String, dynamic>) {
        return;
      }
      packet = decoded;
    } on Object {
      return;
    }
    if (packet['type']?.toString() != RemoteSyncProtocol.discoveryType) {
      return;
    }
    final id = packet['id']?.toString().trim() ?? '';
    if (id.isEmpty || id == _deviceId) {
      return;
    }
    final ip = packet['ip']?.toString().trim() ?? '';
    final address = ip.isNotEmpty && _isValidIpv4(ip) ? ip : datagram.address.address;
    if (!_isValidIpv4(address) || _localIps.contains(address)) {
      return;
    }
    final device = RemoteSyncDevice(
      id: id,
      name: packet['name']?.toString().trim().isNotEmpty == true ? packet['name']!.toString().trim() : 'PureLive',
      platform: packet['platform']?.toString() ?? '',
      version: packet['version']?.toString() ?? '',
      ip: address,
      port: int.tryParse(packet['port']?.toString() ?? '') ?? RemoteSyncProtocol.defaultHttpPort,
      lastSeen: DateTime.now(),
      bonsoirName: null,
    );
    final indexById = _devices.indexWhere((item) => item.id == device.id);
    if (indexById >= 0) {
      _devices[indexById] = device;
    } else {
      final indexByIp = _devices.indexWhere((item) => item.ip.trim() == device.ip.trim());
      if (indexByIp >= 0) {
        _devices[indexByIp] = device;
      } else {
        _devices = [..._devices, device];
      }
    }
    _notify();
  }

  void _startCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_disposed) {
        return;
      }
      final now = DateTime.now();
      final next = _devices.where((device) => now.difference(device.lastSeen) <= _deviceTtl).toList();
      if (next.length != _devices.length) {
        _devices = next;
        _notify();
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Send / receive
  // ---------------------------------------------------------------------------

  /// Sends this device's payload to [device], narrowed to [sections].
  Future<bool> syncToDevice(RemoteSyncDevice device, {List<String>? sections}) {
    return syncToAddress(device.ip, device.port, sections: sections);
  }

  /// Sends this device's payload to the [ip]:[port] endpoint.
  Future<bool> syncToAddress(String ip, int port, {List<String>? sections}) async {
    if (_disposed || _isSyncing) {
      return false;
    }
    _isSyncing = true;
    _notify();
    try {
      final payload = buildLocalPayload(sections: sections);
      final client = HttpClient();
      try {
        final request = await client.postUrl(Uri.parse('http://$ip:$port${RemoteSyncProtocol.apiSettings}'));
        request.headers.contentType = ContentType('application', 'json', charset: 'utf-8');
        request.write(jsonEncode(RemoteSyncProtocol.settingsPacket(settings: payload, sections: sections)));
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
    } on Object {
      return false;
    } finally {
      _isSyncing = false;
      _notify();
    }
  }

  /// Checks whether the remote device is reachable. It does NOT receive a
  /// payload — that is [getRemoteSettings] plus [applyRemoteSettings].
  Future<bool> receiveFromAddress(String ip, int port) async {
    if (_disposed || _isApplying) {
      return false;
    }
    _isApplying = true;
    _notify();
    try {
      final client = HttpClient();
      try {
        final request = await client.getUrl(Uri.parse('http://$ip:$port${RemoteSyncProtocol.apiStatus}'));
        final response = await request.close();
        await response.drain<void>();
        return response.statusCode == HttpStatus.ok;
      } finally {
        client.close(force: true);
      }
    } on Object {
      return false;
    } finally {
      _isApplying = false;
      _notify();
    }
  }

  /// Fetches another device's payload. This uses GET /settings, not GET
  /// /status — the remote device confirms the read on its own screen.
  Future<Map<String, dynamic>?> getRemoteSettings(String ip, int port) async {
    if (_disposed) {
      return null;
    }
    try {
      final client = HttpClient();
      try {
        final request = await client.getUrl(Uri.parse('http://$ip:$port${RemoteSyncProtocol.apiSettings}'));
        final response = await request.close();
        final body = await utf8.decoder.bind(response).join();
        if (response.statusCode != HttpStatus.ok) {
          return null;
        }
        final result = jsonDecode(body);
        if (result is! Map || result['code'] != 200) {
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
    } on Object {
      return null;
    }
  }

  /// Sends this device's payload to a typed `ip:port` or URL.
  Future<bool> syncByAddress(String value) {
    final parsed = RemoteSyncProtocol.parseHttpAddress(value);
    if (parsed == null) {
      return Future<bool>.value(false);
    }
    return syncToAddress(parsed.ip, parsed.port);
  }

  // ---------------------------------------------------------------------------
  // Notify
  // ---------------------------------------------------------------------------

  void _setDiscovering(bool value) {
    if (_isDiscovering != value) {
      _isDiscovering = value;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }
}
