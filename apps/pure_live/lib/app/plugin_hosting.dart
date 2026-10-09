// Module: lib/app/plugin_hosting.dart
// Purpose: The shell side of the plugin system: adapt runtime services into a
// HostBridge, load installed plugins into the capability registry, and give
// settings the install/uninstall operations.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: docs/plugin/plugin-lifecycle.md and js-plugin.md. The shell is a host,
// not a source list: no site is compiled in, and everything on the home page
// arrives through install -> enable -> capability registry. The HostBridge
// adapter lives here because this is the one place allowed to see both the
// runtime's services and the plugin-sized vocabulary (AGENTS.md I9).

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:pure_live_capability/pure_live_capability.dart';
import 'package:pure_live_extension/pure_live_extension.dart';
import 'package:pure_live_external_tvbox/pure_live_external_tvbox.dart';
import 'package:pure_live_js_runtime/pure_live_js_runtime.dart';
import 'package:pure_live_permission/pure_live_permission.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_plugin_api/pure_live_plugin_api.dart';
import 'package:pure_live_music/pure_live_music.dart';
import 'package:pure_live_python_runtime/pure_live_python_runtime.dart';
import 'package:pure_live_plugin_host/pure_live_plugin_host.dart';

import 'runtime.dart';

/// The bridge one loaded plugin receives. Network goes through the same
/// permission-backed exit the gateway uses, so a plugin request is checked
/// against the grants exactly like an extension request. The gateway-side
/// services speak extension-shaped signatures, so thin adapters bind the
/// plugin's id into each call.
final class RuntimeHostBridge implements HostBridge {
  RuntimeHostBridge({required this.pluginId, required this.manifest, required PureLiveRuntime runtime})
    : network = _BridgeNetwork(PluginBackedExit(runtime: runtime, pluginId: pluginId)),
      kv = _BridgeKv(PersistentExtensionStorage(store: runtime.keyValueStore, extensionId: pluginId)),
      _runtime = runtime;

  final ExtensionId pluginId;
  @override
  final PluginManifest manifest;
  final PureLiveRuntime _runtime;

  @override
  final PluginNetwork network;
  @override
  final PluginKvStore kv;

  @override
  PluginCookieAccess get cookies => _BridgeCookies(runtime: _runtime, pluginId: pluginId);

  @override
  PluginEventSink get events => _BridgeEvents(runtime: _runtime, pluginId: pluginId);
}

/// The permission-backed exit, bound to one plugin.
final class PluginBackedExit {
  const PluginBackedExit({required this.runtime, required this.pluginId});

  final PureLiveRuntime runtime;
  final ExtensionId pluginId;

  Future<NetworkResponse> send(NetworkRequest request) {
    final exit = PolicyBackedExtensionNetwork(
      permissions: runtime.permissions,
      transport: NetworkClientTransport(client: runtime.network),
    );
    return exit.send(pluginId, request);
  }
}

final class _BridgeNetwork implements PluginNetwork {
  _BridgeNetwork(this._exit);

  final PluginBackedExit _exit;

  @override
  Future<NetworkResponse> send(NetworkRequest request) => _exit.send(request);
}

/// The plugin's own storage namespace, in plugin-sized method names.
final class _BridgeKv implements PluginKvStore {
  _BridgeKv(this._storage);

  final PersistentExtensionStorage _storage;

  @override
  Future<Object?> read(String key) => _storage.read(key);

  @override
  Future<void> write(String key, Object? value) => _storage.write(key, value);

  @override
  Future<void> remove(String key) => _storage.remove(key);

  @override
  Future<List<String>> keys() => _storage.keys();
}

/// Cookie access is per-plugin by construction (one jar per extension id) and
/// the permission check happens inside the store, so the adapter is thin. The
/// plugin-facing read takes the request Uri; the jar it reads from is already
/// this plugin's alone.
final class _BridgeCookies implements PluginCookieAccess {
  _BridgeCookies({required PureLiveRuntime runtime, required this.pluginId})
    : _store = PolicyBackedCookieStore(permissions: runtime.permissions, jar: runtime.cookies);

  final ExtensionId pluginId;
  final PolicyBackedCookieStore _store;

  @override
  Future<List<Cookie>> read(Uri uri) => _store.cookiesFor(pluginId, uri);

  @override
  Future<void> write(Cookie cookie) => _store.set(pluginId, cookie);

  @override
  Future<void> clear({String? host}) => _store.clear(pluginId, host: host);
}

final class _BridgeEvents implements PluginEventSink {
  _BridgeEvents({required this.runtime, required this.pluginId});

  final ExtensionId pluginId;
  final PureLiveRuntime runtime;

  @override
  void publish(String name, {Map<String, Object?> payload = const <String, Object?>{}}) {
    runtime.diagnostics.emit('plugin.$name', extensionId: pluginId, metadata: payload);
  }
}

/// Result of loading the enabled plugins at boot. Per-plugin outcomes are kept
/// instead of failing the whole boot: one broken script must not take the
/// shell down with it.
final class PluginLoadReport {
  final Map<String, PluginManifest> loaded = <String, PluginManifest>{};
  final Map<String, String> failed = <String, String>{};
}

/// Loads every installed-and-enabled plugin through the JS runtime and
/// registers its capability adapters on the registry. Called at boot and
/// again whenever the management page changes an enable switch.
Future<PluginLoadReport> loadEnabledPlugins(PureLiveRuntime runtime, PluginStore store) async {
  final report = PluginLoadReport();
  for (final installed in await store.list()) {
    if (!installed.enabled) {
      continue;
    }
    try {
      await _loadOne(runtime, store, installed);
      report.loaded[installed.id] = installed.manifest;
    } catch (error) {
      report.failed[installed.id] = '$error';
    }
  }
  return report;
}

Future<void> _loadOne(PureLiveRuntime runtime, PluginStore store, InstalledPlugin installed) async {
  final manifest = installed.manifest;
  if (manifest.runtime == PluginRuntimeKind.data) {
    await _loadDataPlugin(runtime, manifest, store, installed);
    return;
  }
  // A music-kind plugin is an lx user-api script: it is hosted directly (the
  // lx environment and the script are one evaluation), not
  // capability-registered - music resolve speaks its own vocabulary, which
  // the music feature consumes from runtime.musicHosts.
  if (manifest.capabilityNames.contains('music')) {
    final musicHost = await MusicSourceScriptHost.spawn(
      scriptId: manifest.id,
      name: manifest.name,
      source: await store.readSource(installed.id),
      bridge: RuntimeHostBridge(pluginId: manifest.id, manifest: manifest, runtime: runtime),
    );
    await musicHost.awaitInited();
    runtime.musicHosts[manifest.id] = musicHost;
    return;
  }
  final source = await store.readSource(installed.id);
  final pluginRuntime = JsPluginRuntime(
    source: source,
    onLog: (id, level, message) {
      runtime.diagnostics.emit(
        'plugin.log',
        extensionId: id,
        metadata: <String, Object?>{'level': level, 'message': message},
      );
    },
  );
  await pluginRuntime.load(manifest, RuntimeHostBridge(pluginId: manifest.id, manifest: manifest, runtime: runtime));
  await pluginRuntime.enable();

  final live = pluginRuntime.liveAdapter();
  final search = pluginRuntime.searchAdapter();
  final kinds = <CapabilityKind>{
    if (live != null) ...<CapabilityKind>[CapabilityKind.live, CapabilityKind.feed],
    if (search != null) CapabilityKind.search,
  };
  // (music-only plugins returned above)
  if (kinds.isEmpty || (live == null && search == null)) {
    throw StateError('plugin serves no capability this shell consumes');
  }
  runtime.capabilities.register(
    ProviderRegistration(
      sourceId: manifest.id,
      extensionId: manifest.id,
      provider: live ?? search!,
      capabilities: CapabilitySet(kinds),
    ),
  );
}

/// A data plugin serves straight from its config: M3U playlists and the live
/// groups of a TVBox repo become one playlist source; spider sites are named
/// as pending rather than registered unable to serve.
Future<void> _loadDataPlugin(
  PureLiveRuntime runtime,
  PluginManifest manifest,
  PluginStore store,
  InstalledPlugin installed,
) async {
  final content = await store.readContent(manifest.id);
  final Object parsed;
  if (content.trimLeft().startsWith('#EXTM3U')) {
    parsed = const M3uParser().parse(content);
  } else {
    parsed = const TvBoxConfigParser().parse(content);
  }
  final List<TvBoxChannel> channels;
  final sites = <TvBoxSite>[];
  final notes = <String>[];
  if (parsed is TvBoxSingleRepo) {
    channels = <TvBoxChannel>[for (final group in parsed.lives) ...group.channels];
    sites.addAll(parsed.sites);
  } else if (parsed is List<TvBoxChannel>) {
    channels = parsed;
  } else if (parsed is TvBoxMultiRepo) {
    // The multi-repo resolves here: one fetch per named repo, failures kept
    // per url, and whatever came back is merged as if the multi-repo had
    // inlined it.
    final result = await TvBoxRepoFetcher(client: runtime.network).fetch(parsed);
    for (final failure in result.failures) {
      notes.add('${failure.url} 失败:${failure.error}');
    }
    if (result.isAllFailed) {
      throw StateError('多仓里的仓库全部拉取失败');
    }
    channels = <TvBoxChannel>[];
    for (final fetched in result.repos) {
      final config = fetched.config;
      if (config is TvBoxSingleRepo) {
        channels.addAll([for (final group in config.lives) ...group.channels]);
        sites.addAll(config.sites);
      }
    }
    notes.add('已拉取 ${result.repos.length} 个仓库');
  } else {
    throw StateError('配置不是 M3U、单仓或多仓形态');
  }
  await _loadSpiderSites(runtime, manifest, sites, notes, originUrl: installed.originUrl);
  if (channels.isEmpty && notes.isEmpty) {
    throw StateError('配置里没有可播放的频道');
  }
  if (channels.isNotEmpty) {
    final built = playlistContent(manifest.id, channels);
    runtime.capabilities.register(
      ProviderRegistration(
        sourceId: manifest.id,
        extensionId: manifest.id,
        provider: built.provider,
        capabilities: const CapabilitySet(<CapabilityKind>{CapabilityKind.live, CapabilityKind.feed}),
      ),
    );
    notes.add(built.summary);
  }
  runtime.diagnostics.emit(
    'plugin.dataLoaded',
    extensionId: manifest.id,
    metadata: <String, Object?>{'summary': notes.join(' / ')},
  );
}

/// Loads a repo's spider sites: each site whose api names a fetchable .js or
/// .py file gets its spider running and a SpiderVodProvider on the registry.
/// Anything else - csp_ built-ins, jar members, relative paths with no base -
/// is named as pending: the framework registers what it can run, never what it
/// cannot.
Future<void> _loadSpiderSites(
  PureLiveRuntime runtime,
  PluginManifest manifest,
  List<TvBoxSite> sites,
  List<String> notes, {
  Uri? originUrl,
}) async {
  var loaded = 0;
  var pending = 0;
  for (final site in sites) {
    try {
      final provider = await _spawnSiteProvider(runtime, manifest, site, originUrl: originUrl);
      runtime.capabilities.register(
        ProviderRegistration(
          sourceId: provider.sourceId,
          extensionId: manifest.id,
          provider: provider,
          capabilities: const CapabilitySet(<CapabilityKind>{CapabilityKind.vod, CapabilityKind.search}),
        ),
      );
      loaded++;
    } catch (error) {
      pending++;
      runtime.diagnostics.emit(
        'plugin.spiderPending',
        extensionId: manifest.id,
        level: DiagnosticLevel.warning,
        metadata: <String, Object?>{'site': site.key, 'api': site.api, 'reason': '$error'},
      );
    }
  }
  if (sites.isNotEmpty) {
    notes.add('站点 $loaded 可用 / $pending 待接入');
  }
}

Future<SpiderVodProvider> _spawnSiteProvider(
  PureLiveRuntime runtime,
  PluginManifest manifest,
  TvBoxSite site, {
  Uri? originUrl,
}) async {
  final api = site.api.trim();
  final isJs = api.endsWith('.js');
  final isPy = api.endsWith('.py');
  if (!isJs && !isPy) {
    throw StateError('spider 代码不是可直接取用的 .js/.py(${api.isEmpty ? '空 api' : 'csp 内置或 jar 成员'})');
  }
  var uri = Uri.tryParse(api);
  if (uri == null) {
    throw StateError('spider 地址无法解析: $api');
  }
  if (uri.scheme.isEmpty) {
    // Relative to where the config came from; a file import without origin
    // cannot resolve one, which is named rather than guessed.
    if (originUrl == null) {
      throw StateError('spider 是相对路径且配置没有来源地址');
    }
    uri = originUrl.resolve(api);
  } else if (uri.scheme != 'http' && uri.scheme != 'https') {
    throw StateError('spider 地址必须是 http(s)');
  }
  final response = await runtime.network.get(api, headers: const <String, String>{'accept': '*/*'});
  final status = response.statusCode ?? 0;
  if (status < 200 || status >= 300) {
    throw StateError('spider 下载失败 status=$status');
  }
  final code = response.data ?? '';
  final siteRef = SpiderSite(key: site.key, name: site.name, extend: site.ext);
  if (isJs) {
    final bridge = RuntimeHostBridge(pluginId: '${manifest.id}.${site.key}', manifest: manifest, runtime: runtime);
    final SpiderHandle handle = looksLikeDrpyModule(code)
        ? await JsDrpySpiderHandle.spawn(key: site.key, source: code, bridge: bridge)
        : await JsSpiderHandle.spawn(key: site.key, source: code, bridge: bridge);
    return SpiderVodProvider(site: siteRef, handle: handle);
  }
  await PythonSpiderHost.installSpider(runtime.dataDirectory, site.key, code);
  final handle = await PythonSpiderHost.spawn(key: site.key, extend: site.ext, dataDirectory: runtime.dataDirectory);
  return SpiderVodProvider(site: siteRef, handle: handle);
}

/// Reads one imported file, validates it and stores it. Returns the install
/// record so the page can show what arrived. Disabled on install: the user
/// turns a plugin on deliberately, from the management page.
Future<InstalledPlugin> importPluginFile(PluginStore store, String path, {String? displayName}) async {
  final text = await File(path).readAsString();
  if (looksLikeLxMusicScript(text)) {
    return importLxMusicScript(store, text, displayName ?? path);
  }
  final bundle = const PluginBundleParser().parse(text);
  return store.install(bundle);
}

/// Imports a plugin or config from a URL - the common TVBox flow. The origin
/// is recorded so relative spider paths inside the config resolve later.
Future<InstalledPlugin> importPluginUrl(
  PureLiveRuntime runtime,
  PluginStore store,
  String url, {
  String? displayName,
}) async {
  final uri = Uri.parse(url.trim());
  final response = await runtime.network.get(uri.toString(), headers: const <String, String>{'accept': '*/*'});
  final status = response.statusCode ?? 0;
  if (status < 200 || status >= 300) {
    throw StateError('下载失败 status=$status');
  }
  final text = response.data ?? '';
  if (looksLikeLxMusicScript(text)) {
    return importLxMusicScript(store, text, displayName ?? uri.pathSegments.lastOrNull ?? uri.toString());
  }
  if (text.trimLeft().startsWith('#EXTM3U')) {
    final manifest = _deriveDataManifest(text, displayName ?? uri.pathSegments.lastOrNull ?? 'IPTV');
    return store.installData(manifest: manifest, content: text, originUrl: uri);
  }
  final bundle = const PluginBundleParser().parse(text);
  return store.install(bundle, originUrl: uri);
}

/// lx user-api scripts announce themselves by using the lx api surface; they
/// carry no manifest header, so the shell derives one. The name comes from the
/// file, the id from the content hash: re-importing is an idempotent upgrade.
bool looksLikeLxMusicScript(String text) {
  return text.contains('lx.on') && text.contains('EVENT_NAMES.request') ||
      text.contains('lx.send') && text.contains('lx.request');
}

Future<InstalledPlugin> importLxMusicScript(PluginStore store, String text, String displayName) async {
  final hash = crypto.md5.convert(utf8.encode(text)).toString().substring(0, 10);
  final manifest = PluginManifest(
    id: 'lx.$hash',
    name: displayName,
    version: '1.0.0',
    apiVersion: 1,
    runtime: PluginRuntimeKind.js,
    capabilityNames: const <String>{'music'},
    permissionNames: const <String>{'network'},
    origin: PluginOrigin.localFile,
  );
  return store.install(PluginBundle(manifest: manifest, source: text));
}

/// Installs a data plugin from an imported M3U or TVBox config file. The id
/// is the content hash, so re-importing the same file is an idempotent
/// upgrade, and the manifest is derived per data-plugin.md (no code, live
/// capability).
Future<InstalledPlugin> importDataFile(PluginStore store, String path, {required String name}) async {
  final content = await File(path).readAsString();
  return store.installData(manifest: _deriveDataManifest(content, name), content: content);
}

PluginManifest _deriveDataManifest(String content, String name) {
  final hash = crypto.md5.convert(utf8.encode(content)).toString().substring(0, 10);
  return PluginManifest(
    id: 'data.$hash',
    name: name,
    version: '1.0.0',
    apiVersion: 1,
    runtime: PluginRuntimeKind.data,
    capabilityNames: const <String>{'live'},
    permissionNames: const <String>{},
    origin: PluginOrigin.localFile,
  );
}

/// Disables a plugin and takes its registrations off the registry. Uninstall
/// (removing code) is a separate, deliberate step on the management page.
Future<void> disablePlugin(PureLiveRuntime runtime, PluginStore store, String pluginId) async {
  runtime.capabilities.unregister(pluginId);
  await store.setEnabled(pluginId, false);
}
