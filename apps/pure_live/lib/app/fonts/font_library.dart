// The named fromJson factory cannot use the `new` shorthand.
// ignore_for_file: unnecessary_type_name_in_constructor

import 'dart:async';
import 'dart:io';
import 'dart:typed_data' show ByteData;

import 'package:flutter/services.dart' show FontLoader;
import 'package:live_net/live_net.dart';
import 'package:path/path.dart' as p;

/// The cloud font families of the `liuchuancong/fonts` repository
/// (`fonts-manifest.json` at its root): files, a description, the official
/// page and the license.
final class FontFamily {
  /// Reads one manifest entry.
  factory FontFamily.fromJson(Map<Object?, Object?> json) {
    return FontFamily._(
      id: '${json['id'] ?? ''}'.trim(),
      name: '${json['name'] ?? ''}'.trim(),
      files: [for (final file in json['files'] as List<Object?>? ?? const <Object?>[]) '$file'],
      description: '${json['desc'] ?? ''}',
    );
  }

  const FontFamily._({required this.id, required this.name, required this.files, this.description = ''});

  /// The id: the folder name and the registered family name.
  final String id;

  /// The shown name.
  final String name;

  /// Paths in the font repository, `<folder>/<file>.ttf`.
  final List<String> files;

  /// One sentence about the font.
  final String description;

  /// Whether [id] is a folder name safe to place under the fonts root.
  bool get isSafe => id.isNotEmpty && !id.contains('..') && !id.contains('/') && !id.contains(r'\');
}

/// The app's font library: the cloud manifest, downloads into
/// `<data>/fonts/<id>/` and the [FontLoader] registration that makes a
/// downloaded family live.
///
/// Downloads try the mirror list in order (the fonts repository's files
/// are served by GitHub's CDN, whose availability differs per host).
/// Registration happens live — `FontLoader` teaches the engine a family
/// without a restart — and again at every boot for the families already
/// on disk, before the first frame renders.
final class FontLibrary {
  /// A library rooted at [root] (the data area's `fonts` tree), downloading
  /// through [http] at [commit].
  FontLibrary({required this.root, required this.http, required this.commit});

  /// The fonts tree beneath the data area.
  final Directory root;

  /// The download transport.
  final LiveHttp http;

  /// The fonts repository commit everything is pinned to.
  final String commit;

  /// The mirrors, in try order; the commit completes each.
  static const List<String> _mirrors = [
    'https://cdn.jsdelivr.net/gh/liuchuancong/fonts@',
    'https://fastly.jsdelivr.net/gh/liuchuancong/fonts@',
    'https://raw.githubusercontent.com/liuchuancong/fonts/',
  ];

  final Set<String> _registered = {};

  /// Family ids registered with the engine this process.
  Set<String> get registered => Set.unmodifiable(_registered);

  /// The file URL for [path] at [mirrorBase].
  Uri _fileUrl(String mirrorBase, String path) => Uri.parse('$mirrorBase/$path');

  /// Fetches and parses the manifest, trying every mirror. Throws when all
  /// mirrors fail — the page renders that and offers a retry.
  Future<List<FontFamily>> fetchManifest() async {
    Object? last;
    for (final mirror in _mirrors) {
      try {
        final response = await http
            .send(LiveRequest.get(_fileUrl(mirror, 'fonts-manifest.json')))
            .timeout(const Duration(seconds: 20));
        if (response.statusCode != 200) {
          last = 'mirror answered ${response.statusCode}';
          continue;
        }
        final decoded = response.json;
        if (decoded is! List) {
          last = 'unexpected manifest payload';
          continue;
        }
        return [
          for (final entry in decoded)
            if (entry is Map<Object?, Object?> && '${entry['id'] ?? ''}'.trim().isNotEmpty) FontFamily.fromJson(entry),
        ];
      } on Object catch (error) {
        last = error;
      }
    }
    throw StateError('font manifest unavailable: $last');
  }

  /// The folder of [id].
  Directory folderOf(String id) => Directory(p.join(root.path, id));

  /// The downloaded font files of [id], sorted; empty when not downloaded.
  List<File> filesOf(String id) {
    if (!isSafeFontId(id)) {
      return const [];
    }
    final folder = folderOf(id);
    if (!folder.existsSync()) {
      return const [];
    }
    return [
      for (final entity in folder.listSync())
        if (entity is File && entity.path.toLowerCase().endsWith('.ttf')) entity,
    ]..sort((a, b) => a.path.compareTo(b.path));
  }

  /// Whether [id] is downloaded.
  bool isDownloaded(String id) => filesOf(id).isNotEmpty;

  /// Registers every downloaded family with the engine. Called once at
  /// boot, before the first frame.
  Future<void> registerDownloaded() async {
    if (!root.existsSync()) {
      return;
    }
    for (final folder in root.listSync()) {
      if (folder is! Directory) {
        continue;
      }
      final id = p.basename(folder.path);
      final files = filesOf(id);
      if (files.isNotEmpty) {
        await _register(id, files);
      }
    }
  }

  Future<void> _register(String id, List<File> files) async {
    if (_registered.contains(id)) {
      return;
    }
    final loader = FontLoader(id);
    for (final file in files) {
      loader.addFont(_bytesOf(file));
    }
    await loader.load();
    _registered.add(id);
  }

  /// Downloads [family]'s files into the tree and registers the family
  /// live. Throws on failure; the page renders it and offers a retry.
  Future<void> download(FontFamily family) async {
    if (!family.isSafe) {
      throw StateError('invalid manifest entry');
    }
    final folder = folderOf(family.id);
    final staged = Directory(p.join(root.path, '.${family.id}.pending'));
    if (staged.existsSync()) {
      staged.deleteSync(recursive: true);
    }
    staged.createSync(recursive: true);
    final bases = [for (final mirror in _mirrors) '$mirror$commit'];
    try {
      for (final path in family.files) {
        final name = path.split('/').last;
        final target = File(p.join(staged.path, name));
        Object? last;
        var ok = false;
        for (final base in bases) {
          try {
            final response = await http
                .send(LiveRequest.get(_fileUrl(base, path)))
                .timeout(const Duration(seconds: 60));
            if (response.statusCode != 200 || response.bodyBytes.length < 1024) {
              last = 'mirror answered ${response.statusCode}';
              continue;
            }
            await target.writeAsBytes(response.bodyBytes, flush: true);
            ok = true;
            break;
          } on Object catch (error) {
            last = error;
          }
        }
        if (!ok) {
          throw StateError('font file unavailable: $last');
        }
      }
      if (folder.existsSync()) {
        folder.deleteSync(recursive: true);
      }
      staged.renameSync(folder.path);
      await _register(family.id, filesOf(family.id));
    } on Object {
      if (staged.existsSync()) {
        staged.deleteSync(recursive: true);
      }
      rethrow;
    }
  }

  /// Deletes [id]'s downloaded files. A selected family should be
  /// deselected first (the page owns that rule).
  Future<void> delete(String id) async {
    final folder = folderOf(id);
    if (folder.existsSync()) {
      folder.deleteSync(recursive: true);
    }
    _registered.remove(id);
  }
}

/// Reads a font file as the [ByteData] `FontLoader.addFont` wants.
Future<ByteData> _bytesOf(File file) async => ByteData.view((await file.readAsBytes()).buffer);

/// The fonts repository commit the manifest and files download from.
const String kFontCommit = 'e1d021e47b4fc2f98dee5b2f4020d92b88d20c81';

/// Whether [id] is a folder name safe to place under the fonts root.
bool isSafeFontId(String id) => id.isNotEmpty && !id.contains('..') && !id.contains('/') && !id.contains(r'\');
