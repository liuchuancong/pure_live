import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/common/proxy_routing.dart' as proxy_routing;
import 'package:pure_live/common/services/local_network_access.dart';

class ProxySettingsController extends GetxController {
  static const int defaultProxyPort = proxy_routing.defaultProxyPort;

  final RxBool enableProxy = hiveBool('enableProxy', false);
  final RxString proxyHost = hiveString('proxyHost', '');
  final RxInt proxyPort = hiveInt('proxyPort', defaultProxyPort);

  // app proxy settings
  final RxBool enableAppProxy = hiveBool('enableAppProxy', false);
  final RxString appProxyHost = hiveString('appProxyHost', '');
  final RxInt appProxyPort = hiveInt('appProxyPort', defaultProxyPort);
  @override
  void onInit() {
    super.onInit();

    final normalizedAppHost = proxy_routing.normalizeProxyHost(appProxyHost.v);
    if (normalizedAppHost != appProxyHost.v) appProxyHost.v = normalizedAppHost;
    final normalizedAppPort = proxy_routing.normalizeStoredProxyPort(appProxyPort.v);
    if (normalizedAppPort != appProxyPort.v) appProxyPort.v = normalizedAppPort;
    final normalizedPlayerHost = proxy_routing.normalizeProxyHost(proxyHost.v);
    if (normalizedPlayerHost != proxyHost.v) proxyHost.v = normalizedPlayerHost;
    final normalizedPlayerPort = proxy_routing.normalizeStoredProxyPort(proxyPort.v);
    if (normalizedPlayerPort != proxyPort.v) proxyPort.v = normalizedPlayerPort;

    ever<bool>(enableAppProxy, (_) => _refreshDioConnections());
    ever<String>(appProxyHost, (_) => _refreshDioConnections());
    ever<int>(appProxyPort, (_) => _refreshDioConnections());

    // Hosts are saved per keystroke; ask for local-network access once the
    // user has stopped typing, and at start-up for an existing LAN proxy.
    const settle = Duration(seconds: 1);
    debounce<bool>(enableProxy, (_) => _ensureLocalNetworkAccess(), time: settle);
    debounce<String>(proxyHost, (_) => _ensureLocalNetworkAccess(), time: settle);
    debounce<bool>(enableAppProxy, (_) => _ensureLocalNetworkAccess(), time: settle);
    debounce<String>(appProxyHost, (_) => _ensureLocalNetworkAccess(), time: settle);
    Future<void>.delayed(const Duration(seconds: 2), _ensureLocalNetworkAccess);
  }

  Future<void> _ensureLocalNetworkAccess() {
    if (isClosed) return Future<void>.value();
    return LocalNetworkAccess.ensureForProxies([
      (enabled: enableAppProxy.v, host: appProxyHost.v),
      (enabled: enableProxy.v, host: proxyHost.v),
    ]);
  }

  void _refreshDioConnections() {
    try {
      HttpClient.instance.rebuildDio();
    } catch (_) {}
  }

  Map<String, dynamic> toJson() {
    return {
      'enableProxy': enableProxy.v,
      'proxyHost': proxy_routing.normalizeProxyHost(proxyHost.v),
      'proxyPort': proxy_routing.normalizeStoredProxyPort(proxyPort.v),
      'enableAppProxy': enableAppProxy.v,
      'appProxyHost': proxy_routing.normalizeProxyHost(appProxyHost.v),
      'appProxyPort': proxy_routing.normalizeStoredProxyPort(appProxyPort.v),
    };
  }

  /// Parse the complete section without notifying observers or persisting values.
  static Map<String, dynamic> parseConfig(Map<String, dynamic> json) {
    return {
      'enableProxy': (json['enableProxy'] ?? false) as bool,
      'proxyHost': proxy_routing.normalizeProxyHost((json['proxyHost'] ?? '') as String),
      'proxyPort': proxy_routing.normalizeStoredProxyPort((json['proxyPort'] ?? defaultProxyPort) as int),
      'enableAppProxy': (json['enableAppProxy'] ?? false) as bool,
      'appProxyHost': proxy_routing.normalizeProxyHost((json['appProxyHost'] ?? '') as String),
      'appProxyPort': proxy_routing.normalizeStoredProxyPort((json['appProxyPort'] ?? defaultProxyPort) as int),
    };
  }

  void fromJson(Map<String, dynamic> json) {
    final parsed = parseConfig(json);
    enableProxy.v = parsed['enableProxy'];
    proxyHost.v = parsed['proxyHost'];
    proxyPort.v = parsed['proxyPort'];
    enableAppProxy.v = parsed['enableAppProxy'];
    appProxyHost.v = parsed['appProxyHost'];
    appProxyPort.v = parsed['appProxyPort'];
  }

  static Map<String, dynamic> extractConfig(Map<String, dynamic>? rootConfig) {
    final proxy = rootConfig?['proxy'] as Map<String, dynamic>? ?? {};
    return {
      'enableProxy': proxy['enableProxy'] ?? false,
      'proxyHost': proxy_routing.normalizeProxyHost((proxy['proxyHost'] ?? '') as String),
      'proxyPort': proxy_routing.normalizeStoredProxyPort((proxy['proxyPort'] ?? defaultProxyPort) as int),
      'enableAppProxy': proxy['enableAppProxy'] ?? false,
      'appProxyHost': proxy_routing.normalizeProxyHost((proxy['appProxyHost'] ?? '') as String),
      'appProxyPort': proxy_routing.normalizeStoredProxyPort((proxy['appProxyPort'] ?? defaultProxyPort) as int),
    };
  }

  static Map<String, dynamic> mergeConfig(Map<String, dynamic> rootConfig, Map<String, dynamic> updateFields) {
    final proxy = Map<String, dynamic>.from(rootConfig['proxy'] ?? {});
    updateFields.forEach((k, v) => proxy[k] = v);
    rootConfig['proxy'] = proxy;
    return rootConfig;
  }
}
