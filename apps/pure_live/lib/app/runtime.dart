// Module: lib/app/runtime.dart
// Purpose: The composition root's assembly of the v2 stack, in the order docs/architecture/runtime.md gives.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: docs/architecture/runtime.md section 1 (cold start) and section 2 (which runtime owns what);
// docs/contracts/platform-contracts.md section 19 (extensions reach services only through an
// ExtensionContext) and AGENTS.md's I9 (the app is the only composition root).
//
// This file is the one place that is allowed to know every layer. It assembles what exists today: the cache
// and storage namespaces, permissions, tasks, the extension gateway with its capability and resolver
// registries, the user-data services (favourites / history / playlists) and the two aggregators that read the
// capability registry. The media runtime is deliberately absent - no engine adapter is wired yet
// (w3-progress §4), so constructing a PlayerKernel here would assemble an object nothing can drive.

import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pure_live_capability/pure_live_capability.dart';
import 'package:pure_live_demo/pure_live_demo.dart';
import 'package:pure_live_extension/pure_live_extension.dart';
import 'package:pure_live_favorites/pure_live_favorites.dart';
import 'package:pure_live_feed/pure_live_feed.dart';
import 'package:pure_live_history/pure_live_history.dart';
import 'package:pure_live_huya/pure_live_huya.dart';
import 'package:pure_live_media/pure_live_media.dart';
import 'package:pure_live_network/pure_live_network.dart';
import 'package:pure_live_permission/pure_live_permission.dart';
import 'package:pure_live_playlist/pure_live_playlist.dart';
import 'package:pure_live_resolver/pure_live_resolver.dart';
import 'package:pure_live_search/pure_live_search.dart';
import 'package:pure_live_storage/pure_live_storage.dart';
import 'package:pure_live_task/pure_live_task.dart';

/// The wired services one app process owns.
final class PureLiveRuntime {
  PureLiveRuntime({
    required this.dataDirectory,
    required this.network,
    required this.keyValueStore,
    required this.permissions,
    required this.tasks,
    required this.diagnostics,
    required this.runtimes,
    required this.gateway,
    required this.media,
    required this.capabilities,
    required this.resolvers,
    required this.resolverChain,
    required this.favorites,
    required this.history,
    required this.playlists,
    required this.search,
    required this.feed,
  });

  /// Assembles the stack. [dataDirectory] is a parameter rather than a lookup so a test can boot into a
  /// temp directory and assert the same durability a device would get.
  ///
  /// [supportedApiVersions] is empty by default, which means the gateway checks no plugin's API revision -
  /// correct for a build with one API version, wrong as soon as a plugin can declare one
  /// (platform-contracts.md section 23).
  ///
  /// [permissionPrompt] defaults to [UnaskedPrompts] because grants are durable now: the placeholder that
  /// refuses outright ([RejectAllPrompts]) answers `denied`, and a stored denial is deliberately never
  /// re-asked, so a build without a prompt UI would record refusals no user made and keep them across every
  /// restart. The settings screen replaces this with the dialog that actually answers.
  static Future<PureLiveRuntime> boot({
    Directory? dataDirectory,
    Set<String> supportedApiVersions = const <String>{},
    PermissionPrompt permissionPrompt = const UnaskedPrompts(),
  }) async {
    final directory = dataDirectory ?? await _defaultDataDirectory();
    final store = FileKeyValueStore(filePath: '${directory.path}${Platform.pathSeparator}extensions.json');
    // A separate file from the extension rows: one corrupt record set must not take the other down with it,
    // and a platform grant is not an extension's data to clear.
    final permissions = PolicyPermissionManager(
      store: KeyValuePermissionStore(
        FileKeyValueStore(filePath: '${directory.path}${Platform.pathSeparator}permissions.json'),
      ),
      prompt: permissionPrompt,
    );
    final network = NetworkClient();
    final tasks = InMemoryTaskScheduler();
    final diagnostics = InMemoryDiagnosticTracer();
    final runtimes = RuntimeRegistry();

    final gateway = ManagedExtensionGateway(
      runtimes: runtimes,
      permissions: permissions,
      network: PolicyBackedExtensionNetwork(
        permissions: permissions,
        transport: NetworkClientTransport(client: network),
      ),
      cookies: PolicyBackedCookieStore(permissions: permissions, jar: InMemoryCookieJar()),
      tasks: tasks,
      diagnostics: diagnostics,
      supportedApiVersions: supportedApiVersions,
      cacheFactory: (descriptor) => PersistentExtensionCache(store: store, extensionId: descriptor.id),
      storageFactory: (descriptor) => PersistentExtensionStorage(store: store, extensionId: descriptor.id),
    );

    final capabilities = CapabilityRegistry();
    final resolvers = ResolverRegistry();

    // One file per user-data domain: that is the unit docs/migration/ migrates and the unit a backup/sync
    // export works on, so a corrupt favourites document cannot take the watch history down with it - and
    // neither one is an extension's data to clear.
    final favorites = FavoritesService(repository: KeyValueFavoriteRepository(_domainStore(directory, 'favorites')));
    // The default folder must exist before the first add; deciding when a service is ready for its user is
    // the root's job, because no package can know whether the host has finished booting.
    await favorites.initialize();
    final history = HistoryService(
      repository: KeyValueHistoryRepository(_domainStore(directory, 'history')),
      // Unthrottled on purpose: history.md names "进度节流" as a record point but gives no interval, and any
      // number this file invented would be a silent policy about how much progress a crash may lose.
      // w5-progress §4 keeps the choice with the host that can see the disk and the network.
    );
    final playlists = PlaylistsService(repository: KeyValuePlaylistRepository(_domainStore(directory, 'playlists')));

    final media = MediaKernelHost();

    return PureLiveRuntime(
      dataDirectory: directory,
      network: network,
      keyValueStore: store,
      permissions: permissions,
      tasks: tasks,
      diagnostics: diagnostics,
      gateway: gateway,
      media: media,
      capabilities: capabilities,
      runtimes: runtimes,
      resolvers: resolvers,
      resolverChain: ResolverChain(registry: resolvers),
      favorites: favorites,
      history: history,
      playlists: playlists,
      // Both aggregators read the registry above: a provider a plugin registers becomes searchable and
      // lands on the front page without a second list to keep in step.
      search: CapabilitySearchAggregator(providers: capabilities),
      feed: CapabilityFeedAggregator(providers: capabilities),
    );
  }

  /// The store one user-data domain owns. Named by domain rather than by service, because the file is the
  /// unit a migrator and a backup both address.
  static FileKeyValueStore _domainStore(Directory directory, String domain) =>
      FileKeyValueStore(filePath: '${directory.path}${Platform.pathSeparator}$domain.json');

  /// Where the runtime's files live. Named for the runtime rather than one feature so a second store does
  /// not scatter itself into its own directory.
  static Future<Directory> _defaultDataDirectory() async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory('${support.path}${Platform.pathSeparator}runtime');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  final Directory dataDirectory;

  /// Held so the root can close it; the transport borrows it and must not dispose a shared client.
  final NetworkClient network;
  final KeyValueStore keyValueStore;
  final PolicyPermissionManager permissions;
  final InMemoryTaskScheduler tasks;
  final InMemoryDiagnosticTracer diagnostics;
  final ManagedExtensionGateway gateway;

  /// The playback kernel with the media_kit backend. Opened from tickets; the app entry point runs
  /// [MediaKernelHost.ensureInitialized] before the first surface is built.
  final MediaKernelHost media;

  /// Discovery: provider registration lives here so a plugin's Enabled state has exactly one thing to
  /// toggle (provider-contract.md section 3).
  final CapabilityRegistry capabilities;

  /// Protocol families the gateway may host. Empty out of the box: the app is what decides which runtimes
  /// exist (a built-in plugin runtime, TVBox in W7), because a package may not name the composition root.
  final RuntimeRegistry runtimes;

  /// Content resolution candidates. Sources enter through `register`, and a chain walks them only when the
  /// request allows fallback.
  final ResolverRegistry resolvers;
  final ResolverChain resolverChain;

  /// The user's own content lists (docs/services/). Each one is durable on its own from the first write, so a
  /// restart is not a reason to lose a favourite, a queue or a position.
  final FavoritesService favorites;
  final HistoryService history;
  final PlaylistsService playlists;

  /// Aggregation over [capabilities]: the search page and Home both read the registry this root hands to
  /// plugins, so "a source is enabled" has exactly one meaning.
  final SearchAggregator search;
  final FeedAggregator feed;

  Future<void> dispose() async {
    await tasks.dispose();
    await media.dispose();
    network.close();
  }
}

/// Registers the content sources compiled into the app binary.
///
/// The composition root is the one place allowed to name a concrete source (AGENTS.md I9): a provider a
/// plugin loads goes through the gateway, but a built-in has no plugin, so the app itself puts it on the
/// registry. Tests boot [PureLiveRuntime] without this call, so their fixtures stay the only content.
PureLiveRuntime registerBuiltInSources(PureLiveRuntime runtime) {
  runtime.capabilities.register(
    ProviderRegistration(
      sourceId: demoSourceId,
      extensionId: 'built-in.demo',
      provider: const DemoLiveSource(),
      capabilities: const CapabilitySet(<CapabilityKind>{CapabilityKind.feed, CapabilityKind.live}),
    ),
  );
  // The first real site: recommend feed and anonymous HLS resolve. The source
  // is app-owned like every built-in, so its transport lives for the process.
  runtime.capabilities.register(
    ProviderRegistration(
      sourceId: huyaSourceId,
      extensionId: 'built-in.huya',
      provider: HuyaSource(),
      capabilities: const CapabilitySet(<CapabilityKind>{CapabilityKind.feed, CapabilityKind.live}),
    ),
  );
  return runtime;
}
