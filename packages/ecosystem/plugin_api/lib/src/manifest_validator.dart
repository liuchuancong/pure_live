// Module: lib/src/manifest_validator.dart
// Purpose: Decides whether a plugin's Manifest may be installed, and turns it into a gateway descriptor.
// Author: liuchuancong
// Created: 2026-10-08
//
// Spec: docs/plugin/plugin-manifest.md section 3 and docs/contracts/plugin-contract.md section 2.
// The rule that matters is that a declaration is a ceiling, not a hint: an unknown capability or permission
// name, or an apiVersion outside the supported range, refuses the plugin rather than degrading it into
// whatever the platform happened to recognise.

import 'package:pure_live_platform/pure_live_platform.dart';

/// One reason a manifest was refused or downgraded.
final class PluginIssue {
  const PluginIssue({required this.code, required this.field, required this.message, this.isWarning = false});

  /// Stable key, for example `plugin.unknown_permission`.
  final String code;

  /// Which manifest field the issue is about; empty when it spans the whole document.
  final String field;
  final String message;

  /// A warning records something worth showing on the install page without refusing the plugin.
  final bool isWarning;

  Map<String, Object?> toJson() => <String, Object?>{
    'code': code,
    if (field.isNotEmpty) 'field': field,
    'message': message,
    if (isWarning) 'warning': true,
  };

  @override
  String toString() => '[$code] $field: $message';
}

/// The outcome of validating one manifest.
final class PluginValidationResult {
  const PluginValidationResult._({
    this.manifest,
    this.permissions = const <Permission>{},
    this.capabilities = const <ExtensionCapability>{},
    this.issues = const <PluginIssue>[],
  });

  const PluginValidationResult.rejected(List<PluginIssue> issues)
    : manifest = null,
      permissions = const <Permission>{},
      capabilities = const <ExtensionCapability>{},
      issues = issues;

  /// The manifest, when the declaration was accepted.
  final PluginManifest? manifest;

  /// The permission ceiling, resolved to the canonical enum.
  final Set<Permission> permissions;

  /// The coarse capability set the platform knows how to route; see [PluginManifestValidator] for how the
  /// fine-grained names map onto it.
  final Set<ExtensionCapability> capabilities;
  final List<PluginIssue> issues;

  bool get isAccepted => manifest != null;

  List<PluginIssue> get errors => issues.where((issue) => !issue.isWarning).toList(growable: false);

  List<PluginIssue> get warnings => issues.where((issue) => issue.isWarning).toList(growable: false);
}

/// Checks a Manifest against what this build supports.
final class PluginManifestValidator {
  PluginManifestValidator({
    Set<String>? knownCapabilities,
    Set<String>? knownPermissions,
    this.minApiVersion = 1,
    this.maxApiVersion = 1,
  }) : knownCapabilities = knownCapabilities ?? pluginCapabilityNames,
       knownPermissions = knownPermissions ?? _defaultPermissionNames;

  /// The names a plugin may declare. docs/plugin/plugin-manifest.md section 3 refuses an unknown capability
  /// name rather than ignoring it, so the set has to be explicit.
  ///
  /// This is the plugin-facing vocabulary of docs/contracts/capability-contract.md section 1, which is finer
  /// than the coarse ExtensionCapability routing set: `danmaku`, `comment` and `subtitle` are valid
  /// declarations that no routing table knows about yet. Each side pins its own list against the document
  /// (this package's test asserts the declared names, pure_live_capability's asserts CapabilityKind); there is
  /// no cross-package test, because plugin_api must not depend on capability to compare the two in code.
  final Set<String> knownCapabilities;
  final Set<String> knownPermissions;

  /// The supported plugin API range. Runtime decides compatibility by a min/max band
  /// (docs/contracts/plugin-contract.md section 2), not by string equality.
  final int minApiVersion;
  final int maxApiVersion;

  /// plugin-permission.md section 1 writes the cookie permission as `cookies`; the canonical enum name is
  /// `cookie`, so the alias is mapped here instead of forking the vocabulary.
  static const Map<String, String> permissionAliases = <String, String>{'cookies': 'cookie'};

  /// capability-contract.md section 1 says `lyric` while ExtensionCapability says `lyrics`; same capability,
  /// so the spelling difference is resolved here rather than in two enums.
  static const Map<String, String> capabilityAliases = <String, String>{'lyric': 'lyrics'};

  /// capability-contract.md section 1, in the document's own order.
  static const Set<String> pluginCapabilityNames = <String>{
    'live',
    'vod',
    'music',
    'iptv',
    'search',
    'feed',
    'danmaku',
    'subtitle',
    'lyric',
    'comment',
    'chapter',
    'quality',
    'line',
    'history',
    'favorite',
    'playlist',
    'metadata',
    'recommendation',
    'auth',
    'account',
    'epg',
    'repository',
  };

  static final Set<String> _defaultPermissionNames = Permission.values.map((p) => p.name).toSet();

  /// Parses and validates together, so a malformed document produces issues rather than an exception.
  PluginValidationResult validateJson(Map<String, Object?> json) {
    final PluginManifest manifest;
    try {
      manifest = PluginManifest.fromJson(json);
    } on FormatException catch (error) {
      return PluginValidationResult.rejected(<PluginIssue>[
        PluginIssue(code: 'plugin.manifest_invalid', field: '', message: error.message),
      ]);
    }
    return validate(manifest);
  }

  PluginValidationResult validate(PluginManifest manifest) {
    final issues = <PluginIssue>[];

    if (!_isReverseDomain(manifest.id)) {
      issues.add(
        PluginIssue(
          code: 'plugin.id_shape',
          field: 'id',
          message: '"${manifest.id}" is not a reverse-domain identifier (for example com.purelive.source.bilibili)',
        ),
      );
    }
    if (manifest.apiVersion < minApiVersion || manifest.apiVersion > maxApiVersion) {
      issues.add(
        PluginIssue(
          code: 'plugin.api_incompatible',
          field: 'apiVersion',
          message: 'requires plugin API ${manifest.apiVersion}; this build supports $minApiVersion-$maxApiVersion',
        ),
      );
    }
    if (manifest.capabilityNames.isEmpty) {
      issues.add(
        PluginIssue(
          code: 'plugin.no_capabilities',
          field: 'capabilities',
          message: 'a plugin that declares no capability cannot be consumed by anything',
        ),
      );
    }

    final capabilities = <ExtensionCapability>{};
    for (final name in manifest.capabilityNames) {
      if (!knownCapabilities.contains(name)) {
        issues.add(
          PluginIssue(
            code: 'plugin.unknown_capability',
            field: 'capabilities',
            message: '"$name" is not a capability this build knows',
          ),
        );
        continue;
      }
      // A name the platform recognises may still have no routing entry, which is not a refusal.
      final mapped = _capabilityOf(name);
      if (mapped != null) {
        capabilities.add(mapped);
      }
    }

    final permissions = <Permission>{};
    for (final name in manifest.permissionNames) {
      final canonical = permissionAliases[name] ?? name;
      if (!knownPermissions.contains(canonical)) {
        issues.add(
          PluginIssue(
            code: 'plugin.unknown_permission',
            field: 'permissions',
            message: '"$name" is not a permission this build can grant',
          ),
        );
        continue;
      }
      final resolved = _byName(Permission.values, canonical);
      if (resolved != null) {
        permissions.add(resolved);
      }
    }

    if (issues.any((issue) => !issue.isWarning)) {
      return PluginValidationResult.rejected(issues);
    }
    return PluginValidationResult._(
      manifest: manifest,
      permissions: permissions,
      capabilities: capabilities,
      issues: issues,
    );
  }

  /// The ExtensionDescriptor to register with the gateway, or null when the declaration was refused.
  ///
  /// This is the one place plugin vocabulary becomes platform vocabulary: the plugin's reverse-domain id is
  /// already the ContentRef sourceId, its permission list is the ceiling the gateway will enforce, and its
  /// apiVersion travels as platformApiVersion so the gateway's own gate can see it.
  ExtensionDescriptor? toDescriptor(PluginValidationResult result) {
    final manifest = result.manifest;
    if (manifest == null) {
      return null;
    }
    return ExtensionDescriptor(
      id: manifest.id,
      name: manifest.name,
      version: manifest.version,
      protocol: 'pure_live_plugin',
      protocolVersion: manifest.version,
      platformApiVersion: '${manifest.apiVersion}',
      type: ExtensionType.plugin,
      capabilities: result.capabilities,
      permissions: result.permissions,
      metadata: manifest.metadata,
    );
  }

  /// Maps a declared capability onto the coarse routing set, or null when the platform has no route for it
  /// yet. `danmaku`, `comment`, `subtitle`, `chapter` and the rest of the fine-grained names stay valid
  /// declarations (docs/contracts/platform-contracts.md section 5 has no entry for them), they simply do not
  /// appear in [PluginValidationResult.capabilities].
  static ExtensionCapability? _capabilityOf(String name) {
    final canonical = capabilityAliases[name] ?? name;
    return _byName(ExtensionCapability.values, canonical);
  }

  /// Reads an enum by its name. pure_live_platform keeps its own reader in a support file that is not part
  /// of the barrel, so a package outside it looks the name up here rather than widening that surface.
  static T? _byName<T extends Enum>(List<T> values, String name) {
    for (final value in values) {
      if (value.name == name) {
        return value;
      }
    }
    return null;
  }

  static bool _isReverseDomain(String id) {
    if (!id.contains('.') || id.startsWith('.') || id.endsWith('.')) {
      return false;
    }
    return !id.contains(RegExp(r'[\s/\\]'));
  }
}
