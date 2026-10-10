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
//
// "Leading" is enforced, not assumed. Scanning the whole file for the marker meant a script that mentions the
// marker anywhere - in a comment, in a string, in its own source - was read as declaring a manifest there,
// and everything before that point became "the script" with the real header still inside it.

import 'dart:convert';

import 'package:pure_live_platform/pure_live_platform.dart';

/// The marker opening the manifest comment block.
const String pluginManifestMarker = 'PureLive-Plugin-Manifest';

/// How many bytes of leading whitespace a plugin file may put before its header comment.
///
/// Bounded because "the header opens the file" is the rule; a parser that skips an unlimited preamble is
/// back to finding the marker in the body by another route.
const int kPluginMaxHeaderPreambleBytes = 512;

/// One imported plugin: its parsed manifest and the script it shipped with.
final class PluginBundle {
  const PluginBundle({required this.manifest, required this.source});

  final PluginManifest manifest;
  final String source;

  /// The file this bundle came from is never re-derived here: [source] is what the sandbox must run.
  String renderToFile() => '/* $pluginManifestMarker\n${jsonEncode(manifest.toJson())}\n*/\n$source';
}

/// Why a plugin file could not be read as a bundle.
final class PluginBundleException implements Exception {
  const PluginBundleException(this.message);

  final String message;

  @override
  String toString() => 'PluginBundleException($message)';
}

/// Parses plugin file text. Static and side-effect free: no evaluation happens anywhere near this class.
final class PluginBundleParser {
  const PluginBundleParser();

  /// The largest file this parser will read: 4 MiB of UTF-16 code units, matched to the store's script
  /// ceiling.
  ///
  /// The count is code units, not bytes, so it is a ceiling on the *parse* (which builds substring copies of
  /// the file on its way out), not a byte accounting - the exact byte limit stays `PluginStore`'s, because
  /// that is where the file is opened. A caller that read a 500 MB "plugin file" into a String has already
  /// paid; this refuses to pay again.
  static const int kMaxBundleCharacters = 4 * 1024 * 1024;

  PluginBundle parse(String fileText) {
    if (fileText.length > kMaxBundleCharacters) {
      throw PluginBundleException(
        'the plugin file is ${fileText.length} characters, over the $kMaxBundleCharacters character ceiling',
      );
    }
    final headerStart = _headerStart(fileText);
    if (headerStart < 0) {
      throw const PluginBundleException(
        'no $pluginManifestMarker comment header found; a plugin file must open with one',
      );
    }
    // One forward scan, shared by the manifest and the script cut: searching the two boundaries separately is
    // how an earlier version could close the header at a comment that came before it.
    final commentEnd = fileText.indexOf('*/', headerStart);
    if (commentEnd < 0) {
      throw const PluginBundleException('manifest header comment is not closed');
    }
    final manifest = _decodeManifest(_manifestHeader(fileText, headerStart, commentEnd));
    final body = fileText.length <= commentEnd + 2 ? '' : fileText.substring(commentEnd + 2).trim();
    if (body.trim().isEmpty) {
      throw PluginBundleException('${manifest.id} declares no script after its manifest header');
    }
    return PluginBundle(manifest: manifest, source: body);
  }

  /// The index of the marker when the file opens with it, or -1.
  ///
  /// Only whitespace and a byte-order mark may come first, and only within [kPluginMaxHeaderPreambleBytes].
  int _headerStart(String fileText) {
    final opener = '/* $pluginManifestMarker';
    final limit = fileText.length < kPluginMaxHeaderPreambleBytes ? fileText.length : kPluginMaxHeaderPreambleBytes;
    for (var index = 0; index < limit; index++) {
      final character = fileText[index];
      if (character != ' ' && character != '\t' && character != '\n' && character != '\r' && character != '\uFEFF') {
        return fileText.startsWith(opener, index) ? index : -1;
      }
    }
    return -1;
  }

  /// The JSON object inside the header block bounded by [headerStart] and [commentEnd].
  ///
  /// Every boundary is searched *from the marker*, so a comment earlier in the file cannot be mistaken for the
  /// end of the header.
  Map<String, Object?> _manifestHeader(String fileText, int headerStart, int commentEnd) {
    final jsonStart = fileText.indexOf('{', headerStart);
    if (jsonStart < 0) {
      throw const PluginBundleException('manifest header carries no JSON object');
    }
    if (jsonStart > commentEnd) {
      throw const PluginBundleException('manifest header comment closes before its JSON object');
    }
    final jsonEnd = fileText.lastIndexOf('}', commentEnd);
    if (jsonEnd <= jsonStart) {
      throw const PluginBundleException('manifest header JSON is truncated');
    }
    final decoded = _decodeJson(fileText.substring(jsonStart, jsonEnd + 1));
    if (decoded is! Map) {
      throw const PluginBundleException('manifest header JSON is not an object');
    }
    return Map<String, Object?>.fromEntries(decoded.entries.map((entry) => MapEntry('${entry.key}', entry.value)));
  }

  PluginManifest _decodeManifest(Map<String, Object?> header) {
    try {
      return PluginManifest.fromJson(header);
    } on PluginBundleException {
      rethrow;
    } catch (error) {
      // A manifest of the wrong shape is a refusal, in the same currency as every other parse failure; the
      // caller has one exception type to handle, not one per field the validator disagreed about.
      throw PluginBundleException('the manifest header is not a valid plugin declaration: $error');
    }
  }

  Object? _decodeJson(String text) {
    try {
      return jsonDecode(text);
    } on FormatException catch (error) {
      throw PluginBundleException('the manifest header is not valid JSON: ${error.message}');
    }
  }
}
