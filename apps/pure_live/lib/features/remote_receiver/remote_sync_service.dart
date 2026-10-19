import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:live_library/live_library.dart';
import 'package:live_storage/live_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:pure_live/app/preferences/app_preferences.dart';
import 'package:pure_live/features/remote_receiver/remote_sync_device.dart';
import 'package:pure_live/features/remote_receiver/remote_sync_parts.dart';
import 'package:pure_live/features/remote_receiver/remote_sync_payload.dart';
import 'package:pure_live/features/remote_receiver/remote_sync_protocol.dart';

/// Asks the user whether the remote address may read ('export') or
/// overwrite ('import') this device's payload. Requests are refused
/// without it.
typedef RemoteSyncConfirm = Future<bool> Function(String action, String remoteAddress);

/// Asks the user which parts of the payload [remoteAddress] POSTs to apply
/// here; null (or an empty pick) refuses them all. When set it answers
/// imports instead of the flat [RemoteSyncConfirm].
typedef RemoteSyncChooseImport = Future<Set<RemoteSyncPart>?> Function(
  String remoteAddress,
  Map<String, dynamic> settings,
);

/// The LAN sync service, ported from the 3.x `RemoteSyncService`: it serves
/// this device's payload over HTTP, applies an incoming payload through this
/// app's real repositories, and sends/receives to a peer by address.
///
/// Wire behaviour is the 3.x one, so a 3.x build and this app interoperate:
/// the same envelope (`{code, msg, data}`), the same endpoints, and the same
/// pairing gate — every read or overwrite of this device's payload must
/// carry the six-digit [pairingCode] shown on this device's screen (header
/// `x-purelive-pairing`) AND the on-screen [confirmRequest] / [chooseImport]
/// answer; a page-less service refuses everything, and [maxWrongCodes] wrong
/// codes roll the code over.
///
/// Two deviations, both honest: 3.x discovered peers over mDNS (bonsoir, a
/// native-socket package this desktop-first build does not carry), so
/// discovery runs over the protocol's own UDP broadcast; and the payload is
/// this app's own section document (see [RemoteSyncPayload]) rather than the
/// 3.x backup file — the 3.x-side importer reads the parts it knows.
final class RemoteSyncService extends ChangeNotifier {
  /// A service over this app's repositories. The sensitive-section thunks
  /// ([webdavExport]/[accountsExport]/[webdavApply]/[accountsApply]) are the
  /// composition root's bridges to the WebDAV store and the login
  /// repositories; without them "同步账号 Cookie" ships and applies nothing.
  new({
    required this.follows,
    required this.history,
    required this.preferences,
    this.webdavExport,
    this.accountsExport,
    this.webdavApply,
    this.accountsApply,
  }) : _inert = false;

  /// A service that never binds a port, never broadcasts and never opens a
  /// box — what the render tests hand the page so pumping it cannot touch
  /// the network or the storage layer.
  new inert({required this.follows, required this.history, required this.preferences})
    : webdavExport = null,
      accountsExport = null,
      webdavApply = null,
      accountsApply = null,
      _inert = true;

  /// Where followed rooms and groups are applied and exported from.
  final FollowRepository follows;

  /// Where watch history is applied and exported from.
  final HistoryRepository history;

  /// Where the general preference groups are exported from and applied to —
  /// the store the settings pages edit.
  final AppPreferencesStore preferences;

  /// Reads this device's WebDAV servers (with their vault passwords) for a
  /// sensitive send; null means there is nothing sensitive to ship.
  final Future<List<Map<String, dynamic>>> Function()? webdavExport;

  /// Reads this device's platform sign-ins for a sensitive send.
  final Future<List<Map<String, dynamic>>> Function()? accountsExport;

  /// Stores one incoming WebDAV server through the WebDAV store.
  final WebDavServerSink? webdavApply;

  /// Stores one incoming platform credential through the login side.
  final AccountCredentialSink? accountsApply;

  /// Whether this is the inert render-test shape.
  final bool _inert;

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  bool _isServerRunning = false;
  bool _isDiscovering = false;
  bool _isSyncing = false;

  String _localIp = '';
  int _localPort = RemoteSyncProtocol.defaultHttpPort;
  var _devices = <RemoteSyncDevice>[];
  int _wrongCodes = 0;
  bool _includeAccounts = false;

  /// Whether the server answers requests.
  bool get isServerRunning => _isServerRunning;

  /// Whether LAN discovery is listening and announcing.
  bool get isDiscovering => _isDiscovering;

  /// Whether a payload is being sent, received or applied right now.
  bool get isSyncing => _isSyncing;

  /// The LAN address the server picked, empty when none was found.
  String get localIp => _localIp;

  /// The port the server bound.
  int get localPort => _localPort;

  /// The devices currently on the LAN, in discovery order.
  List<RemoteSyncDevice> get devices => List.unmodifiable(_devices);

  /// The six-digit code another device must present with every settings
  /// request; empty while the server is stopped (3.x).
  String pairingCode = '';

  /// Wrong pairing codes before the code rolls over — guessing a six-digit
  /// code takes many tries, and a new code stops the guessing (3.x).
  static const int maxWrongCodes = 10;

  /// Whether account cookies and WebDAV passwords travel (off by default,
  /// 3.x); the sensitive sections are exported and applied only with it.
  bool get includeAccounts => _includeAccounts;

  set includeAccounts(bool value) {
    if (_includeAccounts == value) {
      return;
    }
    _includeAccounts = value;
    _notify();
  }

  /// How long a send or receive waits (the other device asks its user
  /// first).
  Duration requestTimeout = const Duration(minutes: 2);

  /// Asks the user whether the remote address may read ('export') or
  /// overwrite ('import') this device's payload. Requests are refused
  /// without it.
  RemoteSyncConfirm? confirmRequest;

  /// Asks the user which parts of an incoming payload to apply; when set it
  /// answers imports instead of [confirmRequest].
  RemoteSyncChooseImport? chooseImport;

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

  /// The QR payload of this device's sync endpoint — address, port and the
  /// pairing code — empty until the server runs on a real address.
  String get qrData => _localIp.isEmpty || pairingCode.isEmpty
      ? ''
      : RemoteSyncProtocol.createQrUri(ip: _localIp, port: _localPort, code: pairingCode).toString();

  /// The mDNS-era broadcast name; the identity suffix keeps two devices of
  /// one user distinguishable in a peer's own list.
  String get broadcastName {
    final id = _deviceId.length > 6 ? _deviceId.substring(_deviceId.length - 6) : _deviceId;
    return 'PureLive-$id';
  }

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
      pairingCode = RemoteSyncProtocol.newPairingCode();
      _wrongCodes = 0;
      await _startDiscovery();
    } finally {
      _running = false;
    }
  }

  /// Stops serving and discovery; [start] can resume. The pairing code goes
  /// with the server — a stopped device answers nothing.
  Future<void> stop() async {
    pairingCode = '';
    _wrongCodes = 0;
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
      handleRequest,
      onError: (Object _) {
        if (!_disposed) {
          _isServerRunning = false;
          _notify();
        }
      },
    );
    _startCleanupTimer();
  }

  /// Answers one request (public for tests; [start] wires it to the server).
  @visibleForTesting
  Future<void> handleRequest(HttpRequest request) async {
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
        // Senders leave parts out only for a device that says this (J05.1).
        RemoteSyncProtocol.partsKey: [for (final part in RemoteSyncPart.values) part.wireName],
      },
    });
  }

  /// /settings — GET exports, POST imports. Both first need the pairing
  /// code shown on this device (settings hold the payload, so being on the
  /// same network is not enough, 3.x); after it passes, the user answers —
  /// an import through the part picker ([chooseImport]) when the page
  /// offers one, the plain confirm otherwise.
  Future<void> _handleSettings(HttpRequest request) async {
    final response = request.response;
    if (!RemoteSyncProtocol.pairingCodesMatch(pairingCode, request.headers.value(RemoteSyncProtocol.pairingHeader))) {
      // Guessing a six-digit code takes many tries: a new code stops it.
      if (++_wrongCodes >= maxWrongCodes) {
        _wrongCodes = 0;
        pairingCode = RemoteSyncProtocol.newPairingCode();
        _notify();
      }
      response.statusCode = HttpStatus.forbidden;
      await _writeResponse(response, {'code': 403, 'msg': 'Pairing code required', 'data': false});
      return;
    }
    final action = switch (request.method) {
      'GET' => 'export',
      'POST' => 'import',
      _ => null,
    };
    if (action == null) {
      await _writeMethodNotAllowed(response);
      return;
    }
    // Read the body before asking: a bad packet is refused without a prompt.
    Map<String, dynamic>? incoming;
    if (action == 'import') {
      incoming = await _readSyncPacket(request);
      if (incoming == null) {
        response.statusCode = HttpStatus.badRequest;
        await _writeResponse(response, {'code': 400, 'msg': 'Invalid sync packet', 'data': false});
        return;
      }
    }
    Set<RemoteSyncPart>? parts;
    var allowed = false;
    final choose = chooseImport;
    if (incoming != null && choose != null) {
      try {
        parts = _disposed ? null : await choose(request.connectionInfo?.remoteAddress.address ?? '', incoming);
        allowed = parts != null && parts.isNotEmpty;
      } on Object {
        allowed = false;
      }
    } else {
      allowed = await _confirm(action, request);
    }
    if (!allowed) {
      response.statusCode = HttpStatus.forbidden;
      await _writeResponse(response, {'code': 403, 'msg': 'Rejected on the device', 'data': false});
      return;
    }
    if (incoming == null) {
      try {
        final settings = await outgoing();
        await _writeResponse(response, {'code': 200, 'msg': 'ok', 'data': settings});
      } on Object {
        response.statusCode = HttpStatus.internalServerError;
        await _writeResponse(response, {'code': 500, 'msg': 'Export settings failed', 'data': false});
      }
      return;
    }
    _isSyncing = true;
    _notify();
    final success = await applyRemoteSettings(onlySyncParts(incoming, parts));
    _isSyncing = false;
    _notify();
    await _writeResponse(response, {
      'code': success ? 200 : 500,
      'msg': success ? 'ok' : 'apply settings failed',
      'data': success,
    });
  }

  /// The POSTed sync packet, narrowed to the sections it lists (a whole
  /// backup without a list); null when the body is not a sync packet at all.
  Future<Map<String, dynamic>?> _readSyncPacket(HttpRequest request) async {
    try {
      final content = await utf8.decoder.bind(request).join();
      if (content.trim().isEmpty) {
        return null;
      }
      final body = jsonDecode(content);
      if (body is! Map || body['type']?.toString() != RemoteSyncProtocol.syncType || body['settings'] is! Map) {
        return null;
      }
      final settings = Map<String, dynamic>.from(body['settings']! as Map);
      final rawSections = body['sections'];
      return withinSyncSections(
        settings,
        rawSections is List ? [for (final entry in rawSections) entry.toString()] : null,
      );
    } on Object {
      return null;
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
  /// [sections] when the picker ticked a subset. With [includeAccounts] the
  /// sensitive sections (WebDAV servers with their passwords, platform
  /// sign-ins) ride along — through the composition root's thunks, so a
  /// build without them ships without them.
  Future<Map<String, dynamic>> buildLocalPayload({Iterable<String>? sections}) async {
    List<Map<String, dynamic>>? webdavServers;
    List<Map<String, dynamic>>? accountCredentials;
    if (_includeAccounts) {
      if (webdavExport != null) {
        try {
          webdavServers = await webdavExport!.call();
        } on Object {
          // A store that will not open simply has nothing sensitive to ship.
          webdavServers = const [];
        }
      }
      if (accountsExport != null) {
        try {
          accountCredentials = await accountsExport!.call();
        } on Object {
          accountCredentials = const [];
        }
      }
    }
    return RemoteSyncPayload.buildExport(
      preferences: preferences.value,
      follows: follows.rooms,
      groups: follows.groups,
      history: history.records,
      shieldKeywords: _shieldRepository?.get(_shieldKeywordsKey) ?? const <String>[],
      shieldUsers: _shieldRepository?.get(_shieldUsersKey) ?? const <String>[],
      webdavServers: webdavServers,
      accountCredentials: accountCredentials,
      sections: sections,
    );
  }

  /// What a send carries: this device's whole payload, sensitive sections
  /// included only while [includeAccounts] is on.
  Future<Map<String, dynamic>> outgoing() => buildLocalPayload();

  /// This device's own answer for the preference sections, in the wire
  /// shape — what the receive preview compares the incoming settings
  /// against to say how many items would actually change.
  Map<String, dynamic> localSettingsSections() => RemoteSyncPayload.buildExport(
    preferences: preferences.value,
    follows: const [],
    groups: const [],
    history: const [],
    shieldKeywords: const [],
    shieldUsers: const [],
    sections: RemoteSyncPayload.preferenceSectionNames,
  );

  /// Applies the received payload through the real repositories; the two
  /// sensitive sections only run through their sinks when they exist.
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
        webdav: webdavApply,
        accounts: accountsApply,
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

  /// Whether the device at `ip:port` takes parts on their own (its status
  /// answer lists [RemoteSyncProtocol.partsKey]). False for 3.x devices,
  /// older builds and when nothing answers — they get whole sends. Needs no
  /// code and asks nothing on the other device.
  Future<bool> takesParts(String ip, int port) => _busy(() async {
    final answer = await _request(
      'GET',
      ip,
      port,
      null,
      null,
      path: RemoteSyncProtocol.apiStatus,
    ).timeout(const Duration(seconds: 5));
    return answer is Map && RemoteSyncProtocol.takesParts(answer['data']);
  });

  /// Sends this device's payload to `ip:port` with the other device's
  /// pairing [code]; true when it applied the payload. With [parts] that
  /// leave something out, only those parts travel and the packet lists its
  /// sections — send them only to a device that [takesParts].
  Future<bool> send(String ip, int port, String code, {Set<RemoteSyncPart>? parts}) => _busy(() async {
    final settings = await outgoing();
    final partial = syncPartsLeaveOut(settings, parts);
    final body = partial ? pickSyncParts(settings, parts!) : settings;
    final answer = await _request(
      'POST',
      ip,
      port,
      code,
      RemoteSyncProtocol.settingsPacket(settings: body, sections: partial ? syncSectionsOf(body) : null),
    );
    return answer is Map && answer['data'] == true;
  });

  /// Reads `ip:port`'s payload with [code] without applying it (the page
  /// previews what it changes first); null when the other device refused or
  /// did not answer.
  Future<Map<String, dynamic>?> fetch(String ip, int port, String code) async {
    Map<String, dynamic>? settings;
    await _busy(() async {
      final answer = await _request('GET', ip, port, code, null);
      if (answer is! Map || answer['code'] != 200 || answer['data'] is! Map) {
        return false;
      }
      settings = Map<String, dynamic>.from(answer['data']! as Map);
      return true;
    });
    return settings;
  }

  /// Applies a payload [fetch] read — only [parts] of them when given, the
  /// rest stays as it is; true on success.
  Future<bool> apply(Map<String, dynamic> settings, {Set<RemoteSyncPart>? parts}) =>
      _busy(() async => await applyRemoteSettings(onlySyncParts(settings, parts)));

  Future<bool> _busy(Future<bool> Function() work) async {
    if (_disposed || _isSyncing) {
      return false;
    }
    _isSyncing = true;
    _notify();
    try {
      return await work().timeout(requestTimeout);
    } on Object {
      return false;
    } finally {
      _isSyncing = false;
      _notify();
    }
  }

  Future<Object?> _request(
    String method,
    String ip,
    int port,
    String? code,
    Object? body, {
    String path = RemoteSyncProtocol.apiSettings,
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client.openUrl(method, Uri(scheme: 'http', host: ip, port: port, path: path));
      if (code != null) {
        request.headers.set(RemoteSyncProtocol.pairingHeader, RemoteSyncProtocol.normalizePairingCode(code));
      }
      if (body != null) {
        request.headers.contentType = ContentType('application', 'json', charset: 'utf-8');
        request.write(jsonEncode(body));
      }
      final response = await request.close();
      final text = await utf8.decoder.bind(response).join();
      if (response.statusCode != HttpStatus.ok) {
        return null;
      }
      return jsonDecode(text);
    } finally {
      client.close(force: true);
    }
  }

  /// Lists [device] as heard on the network (tests; the UDP discovery calls
  /// the same shape).
  @visibleForTesting
  void heard(RemoteSyncDevice device) {
    final index = _devices.indexWhere((item) => item.id == device.id);
    if (index >= 0) {
      _devices[index] = device;
    } else {
      _devices = [..._devices, device];
    }
    _notify();
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
