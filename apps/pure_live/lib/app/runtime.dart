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
// registries. The media runtime is deliberately absent - no engine adapter is wired yet (w3-progress §4), so
// constructing a PlayerKernel here would assemble an object nothing can drive.

import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pure_live_capability/pure_live_capability.dart';
import 'package:pure_live_extension/pure_live_extension.dart';
import 'package:pure_live_network/pure_live_network.dart';
import 'package:pure_live_permission/pure_live_permission.dart';
import 'package:pure_live_resolver/pure_live_resolver.dart';
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
    required this.capabilities,
    required this.resolvers,
    required this.resolverChain,
  });

  /// Assembles the stack. [dataDirectory] is a parameter rather than a lookup so a test can boot into a
  /// temp directory and assert the same durability a device would get.
  ///
  /// [supportedApiVersions] is empty by default, which means the gateway checks no plugin's API revision -
  /// correct for a build with one API version, wrong as soon as a plugin can declare one
  /// (platform-contracts.md section 23).
  static Future<PureLiveRuntime> boot({
    Directory? dataDirectory,
    Set<String> supportedApiVersions = const <String>{},
  }) async {
    final directory = dataDirectory ?? await _defaultDataDirectory();
    final store = FileKeyValueStore(filePath: '${directory.path}${Platform.pathSeparator}extensions.json');
    final permissions = PolicyPermissionManager(store: InMemoryPermissionStore());
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

    final resolvers = ResolverRegistry();
    return PureLiveRuntime(
      dataDirectory: directory,
      network: network,
      keyValueStore: store,
      permissions: permissions,
      tasks: tasks,
      diagnostics: diagnostics,
      gateway: gateway,
      capabilities: CapabilityRegistry(),
      runtimes: runtimes,
      resolvers: resolvers,
      resolverChain: ResolverChain(registry: resolvers),
    );
  }

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

  Future<void> dispose() async {
    await tasks.dispose();
    network.close();
  }
}
