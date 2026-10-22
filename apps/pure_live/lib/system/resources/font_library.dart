// The named fromJson factory cannot use the `new` shorthand.
// ignore_for_file: unnecessary_type_name_in_constructor

import 'dart:async';
import 'dart:io';
import 'dart:typed_data' show ByteData;

import 'package:flutter/services.dart' show FontLoader;
import 'package:live_net/live_net.dart';
import 'package:path/path.dart' as p;
import 'package:pure_live/system/theme/font_recommendations.dart';

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

  /// A family the user imported from their own disk: no manifest entry to read
  /// it from, so the id and the shown name are derived from the file name.
  const new imported({required this.id, required this.name, required this.files}) : description = '';

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

  /// The extensions an import accepts, without the dot. The engine reads all
  /// three through `FontLoader`, so a user's `.otf` is as usable as a
  /// manifest `.ttf`.
  static const List<String> importExtensions = ['ttf', 'otf', 'ttc'];

  /// The prefix naming an imported family. It is what tells an import apart
  /// from a manifest family without asking the network — the manifest may not
  /// have loaded, or may have gone away entirely.
  static const String importedPrefix = 'local-';

  /// Whether [id] is an imported family rather than a manifest one.
  static bool isImported(String id) => id.startsWith(importedPrefix);

  /// The id a chosen file becomes: [importedPrefix] plus the file's stem with
  /// everything a folder name cannot hold folded to `-`. A stem written in
  /// another language survives — it is only the reserved Windows and POSIX
  /// characters that have to go.
  static String idForImport(String path) {
    final stem = p.basenameWithoutExtension(path).trim();
    final folded = stem.replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
    return '$importedPrefix${folded.isEmpty ? 'font' : folded}';
  }

  /// The shown name of an imported family: its id read back with the word
  /// separators as spaces.
  static String nameForImport(String id) => id.substring(importedPrefix.length).replaceAll(RegExp('[-_]+'), ' ');

  /// Copies the chosen font [source] into the tree under [idForImport] and
  /// registers it live, so picking it needs no restart. Re-importing the same
  /// file name replaces the previous copy. Returns the family id, which is what
  /// the appearance's `fontFamily` stores.
  Future<String> importFile(File source) async {
    final extension = p.extension(source.path).replaceFirst('.', '').toLowerCase();
    if (!importExtensions.contains(extension)) {
      throw StateError('unsupported font file: $extension');
    }
    if (!source.existsSync()) {
      throw StateError('font file is gone');
    }
    final id = idForImport(source.path);
    final folder = folderOf(id);
    final staged = Directory(p.join(root.path, '.$id.pending'));
    if (staged.existsSync()) {
      staged.deleteSync(recursive: true);
    }
    staged.createSync(recursive: true);
    try {
      await File(p.join(staged.path, 'font.$extension')).writeAsBytes(await source.readAsBytes(), flush: true);
      if (folder.existsSync()) {
        folder.deleteSync(recursive: true);
      }
      staged.renameSync(folder.path);
      await _register(id, filesOf(id));
      return id;
    } on Object {
      if (staged.existsSync()) {
        staged.deleteSync(recursive: true);
      }
      rethrow;
    }
  }

  /// The families on disk that came from an import, sorted by shown name. The
  /// page lists these without reading the manifest, so an offline host still
  /// shows the fonts the user brought.
  List<FontFamily> importedFamilies() => installedFamilies(importedOnly: true);

  /// Every family on disk that holds font files — the imports AND the
  /// official faces installed outside the manifest (SF Pro, Roboto, Inter,
  /// Ubuntu under their family ids) — sorted by shown name. The page lists
  /// these so a font that lives in the tree is visible and selectable even
  /// when the cloud manifest never heard of it.
  List<FontFamily> installedFamilies({bool importedOnly = false}) {
    if (!root.existsSync()) {
      return const [];
    }
    final families = [
      for (final entity in root.listSync())
        if (entity is Directory &&
            filesOf(p.basename(entity.path)).isNotEmpty &&
            (!importedOnly || isImported(p.basename(entity.path))))
          FontFamily.imported(
            id: p.basename(entity.path),
            name: displayName(p.basename(entity.path)),
            files: [for (final file in filesOf(p.basename(entity.path))) file.path],
          ),
    ];
    return families..sort((a, b) => a.name.compareTo(b.name));
  }

  /// The shown name of the on-disk family [id]: an import reads its file
  /// stem back; the official faces installed under their family ids answer
  /// with the name the recommendation table carries ('SFPro' → SF Pro),
  /// and anything else shows its id.
  static String displayName(String id) {
    if (isImported(id)) {
      return nameForImport(id);
    }
    for (final recommended in kRecommendedFonts.values) {
      if (recommended.family == id) {
        return recommended.name;
      }
    }
    return id;
  }

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
        if (entity is File && importExtensions.contains(p.extension(entity.path).replaceFirst('.', '').toLowerCase()))
          entity,
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
