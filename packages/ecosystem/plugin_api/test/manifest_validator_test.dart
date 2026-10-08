// Module: test/manifest_validator_test.dart
// Purpose: Verify the manifest rules that decide whether a plugin may be installed at all.
// Author: liuchuancong
// Created: 2026-10-08
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_plugin_api/pure_live_plugin_api.dart';
import 'package:test/test.dart';

void main() {
  final validator = PluginManifestValidator(minApiVersion: 1, maxApiVersion: 2);

  Map<String, Object?> manifestJson({
    String id = 'com.purelive.source.bilibili',
    int apiVersion = 1,
    List<Object> capabilities = const <Object>['live', 'vod', 'search'],
    List<Object> permissions = const <Object>['network', 'cookies'],
    String runtime = 'native',
  }) {
    return <String, Object?>{
      'id': id,
      'name': 'Bilibili',
      'version': '1.0.0',
      'apiVersion': apiVersion,
      'runtime': runtime,
      'capabilities': capabilities,
      'permissions': permissions,
      'author': 'PureLive',
    };
  }

  group('accepted declarations', () {
    test('test_validate_documentedExample_isAccepted', () {
      // The example in docs/plugin/plugin-manifest.md section 1 has to install, or the validator disagrees
      // with the document it is enforcing.
      final result = validator.validateJson(<String, Object?>{
        'id': 'com.purelive.source.bilibili',
        'name': 'Bilibili',
        'version': '1.0.0',
        'apiVersion': 1,
        'author': 'PureLive',
        'capabilities': <String>['live', 'vod', 'search', 'feed', 'comment', 'danmaku', 'subtitle', 'auth'],
        'permissions': <String>['network', 'cookies', 'account'],
      });

      expect(result.isAccepted, isTrue, reason: '${result.errors}');
      expect(result.errors, isEmpty);
      // `cookies` is the plugin-facing spelling; the ceiling the gateway sees is the canonical enum.
      expect(result.permissions, <Permission>{Permission.network, Permission.cookie, Permission.account});
      expect(result.manifest?.capabilityNames, contains('danmaku'));
    });

    test('test_validate_coarseCapabilitiesAreMappedAndFineGrainedNamesAreNotRefused', () {
      final result = validator.validateJson(manifestJson(capabilities: <String>['live', 'danmaku', 'lyric']));

      expect(result.isAccepted, isTrue);
      // ExtensionCapability has no danmaku entry (platform-contracts.md section 5), so it is a valid
      // declaration with no routing entry, while lyric aliases onto lyrics.
      expect(result.capabilities, <ExtensionCapability>{ExtensionCapability.live, ExtensionCapability.lyrics});
    });

    test('test_validate_dataPluginWithoutCode_isAccepted', () {
      final result = validator.validateJson(
        manifestJson(runtime: 'data', capabilities: <String>['vod'], permissions: <String>['network']),
      );

      expect(result.isAccepted, isTrue);
      expect(result.manifest?.hasCode, isFalse);
    });

    test('test_validate_permissionListFromThePluginDocument_allResolve', () {
      // plugin-permission.md section 1 lists the names a plugin may write; each must resolve to a canonical
      // Permission or the document and the enum have drifted.
      const declared = <String>[
        'network',
        'cookies',
        'account',
        'storage',
        'filesystem',
        'clipboard',
        'notification',
        'background',
        'media',
        'location',
      ];

      final unresolved = declared
          .map((name) => PluginManifestValidator.permissionAliases[name] ?? name)
          .where((name) => !Permission.values.map((p) => p.name).contains(name))
          .toList(growable: false);

      expect(unresolved, isEmpty);
    });

    test('test_validate_capabilityNameList_isTheDocumentedVocabulary', () {
      expect(PluginManifestValidator.pluginCapabilityNames, <String>{
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
      });
    });

    test('test_toDescriptor_carriesTheCeilingTheGatewayWillEnforce', () {
      final result = validator.validateJson(manifestJson());
      final descriptor = validator.toDescriptor(result)!;

      expect(descriptor.id, 'com.purelive.source.bilibili');
      expect(descriptor.type, ExtensionType.plugin);
      expect(descriptor.protocol, 'pure_live_plugin');
      expect(descriptor.platformApiVersion, '1');
      expect(descriptor.permissions, <Permission>{Permission.network, Permission.cookie});
      expect(descriptor.capabilities, <ExtensionCapability>{
        ExtensionCapability.live,
        ExtensionCapability.vod,
        ExtensionCapability.search,
      });
    });

    test('test_toDescriptor_forARejectedManifest_returnsNull', () {
      final result = validator.validateJson(manifestJson(capabilities: <String>['teleportation']));

      expect(validator.toDescriptor(result), isNull);
    });
  });

  group('refusals', () {
    test('test_validate_unknownCapability_isRefused', () {
      final result = validator.validateJson(manifestJson(capabilities: <String>['hologram']));

      expect(result.isAccepted, isFalse);
      expect(result.errors.map((issue) => issue.code), contains('plugin.unknown_capability'));
    });

    test('test_validate_unknownPermission_isRefused', () {
      // An undeclarable permission must not become a silent no-op: the ceiling is what the gateway enforces.
      final result = validator.validateJson(manifestJson(permissions: <String>['root']));

      expect(result.isAccepted, isFalse);
      expect(result.errors.map((issue) => issue.code), contains('plugin.unknown_permission'));
    });

    test('test_validate_apiVersionOutsideTheBand_isRefused', () {
      final result = validator.validateJson(manifestJson(apiVersion: 7));

      expect(result.errors.map((issue) => issue.code), contains('plugin.api_incompatible'));
      expect(result.errors.single.message, contains('1-2'));
    });

    test('test_validate_idThatIsNotReverseDomain_isRefused', () {
      for (final id in <String>['bilibili', '.leading', 'trailing.', 'has space']) {
        final result = validator.validateJson(manifestJson(id: id));
        expect(result.errors.map((issue) => issue.code), contains('plugin.id_shape'), reason: id);
      }
    });

    test('test_validate_missingField_isReportedNotThrown', () {
      final json = manifestJson()..remove('version');
      final result = validator.validateJson(json);

      expect(result.isAccepted, isFalse);
      expect(result.errors.single.code, 'plugin.manifest_invalid');
    });

    test('test_validate_declaringNoCapability_isRefused', () {
      final result = validator.validateJson(manifestJson(capabilities: <String>[]));

      expect(result.errors.map((issue) => issue.code), contains('plugin.no_capabilities'));
    });

    test('test_validate_knownCapabilitiesFromTheHostOverrideTheDefault', () {
      // A build that only ships live sources decides what is known; the validator does not.
      final narrow = PluginManifestValidator(
        knownCapabilities: const <String>{'live'},
        knownPermissions: const <String>{'network'},
      );

      expect(
        narrow.validateJson(manifestJson(capabilities: <String>['live'], permissions: <String>['network'])).isAccepted,
        isTrue,
      );
      expect(
        narrow.validateJson(manifestJson(capabilities: <String>['vod'])).errors.map((i) => i.code),
        contains('plugin.unknown_capability'),
      );
      // A host that only knows `network` also refuses a plugin asking for cookies, alias or not.
      expect(
        narrow.validateJson(manifestJson(permissions: <String>['cookies'])).errors.map((i) => i.code),
        contains('plugin.unknown_permission'),
      );
    });
  });

  group('manifest model', () {
    test('test_manifest_jsonRoundTrip_keepsTheDeclaration', () {
      final original = PluginManifest.fromJson(manifestJson());
      final decoded = PluginManifest.fromJson(original.toJson());

      expect(decoded, original);
      expect(decoded.id, 'com.purelive.source.bilibili');
      expect(decoded.origin, PluginOrigin.builtin);
      expect('$decoded', contains('api1'));
    });

    test('test_manifest_duplicateNamesCollapseToOne', () {
      final manifest = PluginManifest.fromJson(
        manifestJson(capabilities: <String>['live', 'live', 'vod'], permissions: <String>['network', 'network']),
      );

      expect(manifest.capabilityNames, <String>{'live', 'vod'});
      expect(manifest.permissionNames, <String>{'network'});
    });

    test('test_manifest_changedDeclarationIsADifferentBuild', () {
      final before = PluginManifest.fromJson(manifestJson());
      final after = PluginManifest.fromJson(manifestJson(permissions: <String>['network', 'account']));

      expect(before, isNot(after));
    });
  });

  group('issue reporting', () {
    test('test_issue_toJson_carriesCodeFieldAndWarningFlag', () {
      const issue = PluginIssue(code: 'plugin.id_shape', field: 'id', message: 'bad id', isWarning: true);

      expect(issue.toJson(), <String, Object?>{
        'code': 'plugin.id_shape',
        'field': 'id',
        'message': 'bad id',
        'warning': true,
      });
      expect('$issue', contains('plugin.id_shape'));
    });
  });
}
