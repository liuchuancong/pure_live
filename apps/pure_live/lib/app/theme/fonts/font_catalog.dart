import 'dart:convert' show jsonDecode;
import 'dart:io' show File, FileSystemException;
import 'dart:ui' show FontWeight;

import 'package:flutter/foundation.dart' show immutable;

/// One cloud family of `assets/fonts/fonts-manifest.json` (the 3.x font
/// catalogue): the folder name and registered family name ([id]), the shown
/// name, the font files in the repository, a description, the official page
/// and the license.
@immutable
final class FontFamily {
  /// Creates the family.
  const FontFamily({
    required this.id,
    required this.name,
    required this.files,
    this.description = '',
    this.official = '',
    this.license = '',
    this.licenseUrl = '',
  });

  /// Reads one manifest entry.
  factory FontFamily.fromJson(Map<String, Object?> json) {
    final license = json['license'];
    return FontFamily(
      id: '${json['id'] ?? ''}'.trim(),
      name: '${json['name'] ?? ''}'.trim(),
      files: [for (final file in json['files'] as List<Object?>? ?? const <Object?>[]) '$file'],
      description: '${json['desc'] ?? ''}',
      official: '${json['official'] ?? ''}',
      license: license is Map ? '${license['name'] ?? ''}' : '',
      licenseUrl: license is Map ? '${license['url'] ?? ''}' : '',
    );
  }

  /// The id: the folder name and the family `dynamic_fonts` registers under.
  final String id;

  /// The shown name.
  final String name;

  /// Paths in the font repository, `<folder>/<file>.ttf|otf`.
  final List<String> files;

  /// One sentence about the font.
  final String description;

  /// The font's home page.
  final String official;

  /// The licence name.
  final String license;

  /// The licence page.
  final String licenseUrl;

  /// The file names (last path segment) of [files].
  List<String> get fileNames => [for (final file in files) file.split('/').last];
}

/// The bundled cloud font catalogue; the files themselves are fetched at
/// runtime through `dynamic_fonts` and cached under the data folder.
const String fontManifestAsset = 'assets/fonts/fonts-manifest.json';

/// Reads the catalogue; entries with unsafe ids or file paths are dropped.
List<FontFamily> parseFontManifest(String json) {
  final decoded = jsonDecode(json);
  if (decoded is! List) return const [];
  return List.unmodifiable([
    for (final item in decoded)
      if (item is Map<String, Object?>)
        if (FontFamily.fromJson(item) case final family when isSafeFontId(family.id) && validFontFiles(family.files))
          family,
  ]);
}

/// Whether [id] can be a folder name on every platform.
bool isSafeFontId(String id) => id.isNotEmpty && id != '.' && id != '..' && RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(id);

/// Whether every path is `segments/name.ttf|otf` without `..`, backslashes
/// or repeated names.
bool validFontFiles(List<String> files) {
  if (files.isEmpty) return false;
  final names = <String>{};
  for (final path in files) {
    final parts = path.split('/');
    final name = parts.last;
    final lower = name.toLowerCase();
    if (path.contains(r'\') ||
        parts.any((part) => part.isEmpty || part == '.' || part == '..') ||
        RegExp(r'''[<>:"/\\|?*\x00-\x1F]''').hasMatch(name) ||
        !(lower.endsWith('.ttf') || lower.endsWith('.otf')) ||
        !names.add(name)) {
      return false;
    }
  }
  return true;
}

/// Whether [file] starts like a TrueType/OpenType font; a truncated or wrong
/// download never reaches the font loader.
bool isFontFile(File file) {
  try {
    if (!file.existsSync() || file.lengthSync() < 12) return false;
    final handle = file.openSync();
    try {
      final head = handle.readSync(4);
      if (head.length != 4) return false;
      final tag = String.fromCharCodes(head);
      return (head[0] == 0 && head[1] == 1 && head[2] == 0 && head[3] == 0) ||
          tag == 'OTTO' ||
          tag == 'true' ||
          tag == 'typ1' ||
          tag == 'ttcf';
    } finally {
      handle.closeSync();
    }
  } on FileSystemException {
    return false;
  }
}

/// The cloud font repository (3.x's `GitHubMirror(owner: 'liuchuancong',
/// repo: 'fonts')`) and the mirrors a file path can be fetched from: the
/// raw host, the gh-proxy prefix list, kkgithub and the jsDelivr CDNs.
@immutable
final class FontRepository {
  /// Creates the repository descriptor.
  const FontRepository({required this.owner, required this.repo, this.branch = 'master'});

  /// The GitHub owner.
  final String owner;

  /// The GitHub repository.
  final String repo;

  /// The branch every mirror serves.
  final String branch;

  /// The raw GitHub URL of [filePath].
  Uri rawUrl(String filePath) => Uri.parse('https://raw.githubusercontent.com/$owner/$repo/$branch/$filePath');

  /// The jsDelivr CDN URL of [filePath].
  Uri jsdelivr(String filePath) => Uri.parse('https://cdn.jsdelivr.net/gh/$owner/$repo@$branch/$filePath');

  /// The jsDelivr Fastly CDN URL of [filePath].
  Uri jsdelivrFastly(String filePath) => Uri.parse('https://fastly.jsdelivr.net/gh/$owner/$repo@$branch/$filePath');

  /// The accelerator prefixes 3.x raced in front of the raw URL.
  static const List<String> _rawPrefixes = [
    'https://cdn.gh-proxy.org/',
    'https://edgeone.gh-proxy.org/',
    'https://hk.gh-proxy.org/',
    'https://gh.noki.eu.org/',
    'https://gh-proxy.com/',
    'https://slink.ltd/',
    'https://ghproxy.link/',
    'https://gh-proxy.net/',
    'https://gitproxy.click/',
    'https://v6.gh-proxy.org/',
    'https://ghproxy.net/',
    'https://wget.la/',
    'https://gh.catmak.name/',
    'https://g.blfrp.cn/',
  ];

  /// Every source [filePath] can be tried on, in preference order.
  List<Uri> mirrors(String filePath) {
    final raw = rawUrl(filePath);
    final rawText = raw.toString();
    return List.unmodifiable([
      raw,
      for (final prefix in _rawPrefixes) Uri.parse('$prefix$rawText'),
      Uri.parse('https://raw.kkgithub.com/$owner/$repo/$branch/$filePath'),
      jsdelivr(filePath),
      jsdelivrFastly(filePath),
    ]);
  }

  /// The repository-relative path a mirror URL of this repository maps to,
  /// or null when [url] belongs to another repository (or another host).
  ///
  /// The font library's local fetch adapter uses this to answer a mirror URL
  /// from the already-downloaded file, so `dynamic_fonts` never hits the
  /// network for a family this device holds.
  String? relativePath(Uri url) {
    final path = url.path;
    final cdnPrefix = '/gh/$owner/$repo@$branch/';
    if (path.startsWith(cdnPrefix)) return path.substring(cdnPrefix.length);
    final rawPrefix = '/$owner/$repo/$branch/';
    if (path.startsWith(rawPrefix)) return path.substring(rawPrefix.length);
    // gh-proxy style mirrors: the raw URL rides along as a suffix of the
    // request URL (`https://<proxy>/<raw url>`).
    final rawText = 'https://raw.githubusercontent.com$rawPrefix';
    final full = url.toString();
    if (full.startsWith(rawText)) return full.substring(rawText.length);
    final index = full.indexOf(rawText);
    if (index > 0) return full.substring(index + rawText.length);
    return null;
  }
}

/// The single catalogue repository the app reads.
const FontRepository kCloudFontRepository = FontRepository(owner: 'liuchuancong', repo: 'fonts');

/// The weight token a font file name carries, case-insensitively, mirroring
/// the Google Fonts filename grammar `dynamic_fonts` itself parses (3.x
/// shipped the same names). Unknown tokens stay Regular: the engine then
/// synthesises, exactly as with the bundled presets.
FontWeight fontFileWeight(String fileName) {
  final name = fileName.toLowerCase();
  if (name.contains('extralight')) return FontWeight.w200;
  if (name.contains('thin')) return FontWeight.w100;
  if (name.contains('light')) return FontWeight.w300;
  if (name.contains('semibold') || name.contains('demibold')) return FontWeight.w600;
  if (name.contains('extrabold')) return FontWeight.w800;
  if (name.contains('bold')) return FontWeight.w700;
  if (name.contains('medium')) return FontWeight.w500;
  if (name.contains('heavy') || name.contains('black')) return FontWeight.w900;
  return FontWeight.w400; // Regular, Text and unweighted files.
}

/// Whether [fileName] names an italic face.
bool fontFileItalic(String fileName) => fileName.toLowerCase().contains('italic');
