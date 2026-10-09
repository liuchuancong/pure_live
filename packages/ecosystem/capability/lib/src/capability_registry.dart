// Module: lib/src/capability_registry.dart
// Purpose: Who serves what: the index of live providers by source, by capability and by interface.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: docs/contracts/provider-contract.md section 3 ("Provider 由 PluginRegistry 装载、CapabilityRegistry
// 按 capability 索引;查询方永远通过 CapabilityRegistry 发现 Provider 列表,不硬编码源"),
// docs/architecture/runtime.md section 2 (CapabilityRuntime) and docs/plugin/plugin-lifecycle.md's Enabled row
// ("对 CapabilityRegistry 可见,可被业务消费").

import 'package:pure_live_platform/pure_live_platform.dart';

import 'capabilities.dart';

/// One provider as the registry knows it.
///
/// [provider] is the implementation object, typed only as `Object`: the registry cannot know the interfaces a
/// third-party runtime implements, and [CapabilityRegistry.implementations] narrows by type at the query.
final class ProviderRegistration {
  const ProviderRegistration({
    required this.sourceId,
    required this.extensionId,
    required this.provider,
    required this.capabilities,
  });

  final SourceId sourceId;

  /// The extension that owns this source. Disabling or unloading an extension removes every source it owns in
  /// one call, which is what plugin-lifecycle.md's Enabled row means in practice.
  final ExtensionId extensionId;

  final Object provider;

  /// What the provider reported at registration.
  final CapabilitySet capabilities;

  bool serves(CapabilityKind kind) => capabilities.supports(kind);

  @override
  String toString() => 'ProviderRegistration($sourceId of $extensionId -> $capabilities)';
}

/// The index every query path (search, feed, home) reads instead of naming a source.
///
/// Two views, deliberately different: [providersFor] routes by what a provider *declared*, while
/// [implementations] routes by what an object *actually implements*. A query takes the typed one, so a source
/// that over-declares cannot hand its caller an object that would throw; the over-declaration itself is
/// `contract.declaration.missing_interface`, which the contract suite reports before installation
/// (provider-contract.md section 1 rule 5).
final class CapabilityRegistry {
  CapabilityRegistry([Iterable<ProviderRegistration> registrations = const <ProviderRegistration>[]])
    : _entries = <SourceId, ProviderRegistration>{
        for (final registration in registrations) registration.sourceId: registration,
      };

  final Map<SourceId, ProviderRegistration> _entries;

  /// Registered providers, in registration order.
  List<ProviderRegistration> get all => List<ProviderRegistration>.unmodifiable(_entries.values);

  int get length => _entries.length;

  bool get isEmpty => _entries.isEmpty;

  /// Adds a provider, replacing any already registered under the same source id.
  ///
  /// Replacement rather than refusal: a source is reloaded when its repository refreshes or its extension is
  /// re-enabled, and a registry that refused the second registration would leave the *old* object answering.
  /// The replacement keeps the original slot in [all], so a refresh does not silently reorder an aggregation.
  void register(ProviderRegistration registration) {
    _entries[registration.sourceId] = registration;
  }

  /// Removes one source; null means it was not registered.
  ProviderRegistration? unregister(SourceId sourceId) => _entries.remove(sourceId);

  /// Removes every source owned by [extensionId] and returns what went, oldest registration first.
  ///
  /// Bulk removal belongs here because the lifecycle event that triggers it names the extension, not its
  /// sources: an extension may own several repositories, and a caller that forgets one leaves a disabled
  /// plugin still answering queries.
  List<ProviderRegistration> unregisterExtension(ExtensionId extensionId) {
    final removed = <ProviderRegistration>[
      for (final entry in _entries.values)
        if (entry.extensionId == extensionId) entry,
    ];
    for (final entry in removed) {
      _entries.remove(entry.sourceId);
    }
    return removed;
  }

  ProviderRegistration? byId(SourceId sourceId) => _entries[sourceId];

  /// Sources that declared [kind], in registration order.
  List<ProviderRegistration> providersFor(CapabilityKind kind) => <ProviderRegistration>[
    for (final entry in _entries.values)
      if (entry.serves(kind)) entry,
  ];

  /// The providers that can actually answer a [T] call, in registration order.
  ///
  /// This is what an aggregation loop iterates: it never has to know which source ids exist, and it never
  /// receives an object that cannot serve the call.
  List<T> implementations<T>() => <T>[
    for (final entry in _entries.values)
      if (entry.provider is T) entry.provider as T,
  ];

  void clear() => _entries.clear();
}
