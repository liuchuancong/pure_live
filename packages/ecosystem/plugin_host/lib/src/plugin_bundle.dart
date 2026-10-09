// Module: lib/src/plugin_bundle.dart
// Purpose: Parses an imported plugin file into a validated-shape bundle before any code runs.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: docs/plugin/plugin-manifest.md section 3 - a manifest that fails to
// parse refuses the plugin. The single-file format puts a JSON manifest in a
// leading comment block so installation can read the declaration without
// executing the script: validation always precedes load, which is what makes
// "the manifest is a ceiling" enforceable rather than honour-system.

import 'dart:convert';

import 'package:pure_live_platform/pure_live_platform.dart';

/// The marker opening the manifest comment block.
const String pluginManifestMarker = 'PureLive-Plugin-Manifest';

/// One imported plugin: its parsed manifest and the script it shipped with.
final class PluginBundle {
  const PluginBundle({required this.manifest, required this.source});

  final PluginManifest manifest;
  final String source;
}

/// Why a plugin file could not be read as a bundle.
final class PluginBundleException implements Exception {
  const PluginBundleException(this.message);

  final String message;

  @override
  String toString() => 'PluginBundleException($message)';
}

/// Parses plugin file text. Static and side-effect free: no evaluation happens
/// anywhere near this class.
final class PluginBundleParser {
  const PluginBundleParser();

  PluginBundle parse(String fileText) {
    final header = _manifestHeader(fileText);
    if (header == null) {
      throw const PluginBundleException(
        'no $pluginManifestMarker comment header found; a plugin file must open with one',
      );
    }
    final manifest = PluginManifest.fromJson(header);
    return PluginBundle(manifest: manifest, source: _codeAfterHeader(fileText));
  }

  /// The JSON object inside the first `/* PureLive-Plugin-Manifest ... */`
  /// block, or null when the file carries none. A later marker is ignored: the
  /// header is an opening declaration, not a data field.
  Map<String, Object?>? _manifestHeader(String fileText) {
    final opener = '/* $pluginManifestMarker';
    final start = fileText.indexOf(opener);
    if (start < 0) {
      return null;
    }
    final jsonStart = fileText.indexOf('{', start);
    final commentEnd = fileText.indexOf('*/', start);
    if (jsonStart < 0 || (commentEnd >= 0 && jsonStart > commentEnd)) {
      throw const PluginBundleException('manifest header carries no JSON object');
    }
    final jsonEnd = fileText.lastIndexOf('}', commentEnd < 0 ? fileText.length : commentEnd);
    if (jsonEnd <= jsonStart) {
      throw const PluginBundleException('manifest header JSON is truncated');
    }
    final decoded = jsonDecode(fileText.substring(jsonStart, jsonEnd + 1));
    if (decoded is! Map) {
      throw const PluginBundleException('manifest header JSON is not an object');
    }
    return Map<String, Object?>.fromEntries(decoded.entries.map((entry) => MapEntry('${entry.key}', entry.value)));
  }

  /// Everything after the header comment is the script, kept byte-for-byte:
  /// the sandbox runs what was installed, not a re-serialised copy.
  String _codeAfterHeader(String fileText) {
    final commentEnd = fileText.indexOf('*/');
    if (commentEnd < 0 || commentEnd + 2 > fileText.length) {
      throw const PluginBundleException('manifest header comment is not closed');
    }
    return fileText.substring(commentEnd + 2).trim();
  }
}
