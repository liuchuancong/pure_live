import 'dart:io' show Directory, File, FileSystemException;
import 'dart:typed_data' show Uint8List;
import 'dart:ui' show FontStyle, FontWeight;

import 'package:collection/collection.dart' show IterableExtension;
import 'package:crypto/crypto.dart' show sha256;
import 'package:dynamic_fonts/dynamic_fonts.dart' show DynamicFonts, DynamicFontsFile, DynamicFontsVariant;
import 'package:flutter/foundation.dart' show ChangeNotifier, setEquals;
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:live_net/live_net.dart' show CancelToken, LiveHttp, LiveRequest;
import 'package:path/path.dart' as p;

import 'package:pure_live/app/logging/app_log.dart' show appLog;
import 'package:pure_live/app/theme/fonts/font_catalog.dart'
    show
        FontFamily,
        fontFileItalic,
        fontFileWeight,
        fontManifestAsset,
        isFontFile,
        isSafeFontId,
        kCloudFontRepository,
        parseFontManifest,
        validFontFiles;

/// Why a cloud font download stopped.
enum FontDownloadFailure {
  /// Every mirror failed (network, server, bad answer).
  network,

  /// A downloaded file is not a font.
  corrupt,

  /// The files could not be written.
  disk,

  /// The viewer cancelled the download.
  cancelled,
}

/// A failed cloud font download.
final class FontDownloadException implements Exception {
  /// Creates the failure.
  const FontDownloadException(this.reason, [this.detail]);

  /// What went wrong.
  final FontDownloadFailure reason;

  /// Diagnostic detail.
  final String? detail;

  @override
  String toString() => 'FontDownloadException(${reason.name}${detail == null ? '' : ': $detail'})';
}

/// The ids the data folder holds, scanned once per engine at boot and kept
/// synchronously readable: the theme's stored family is validated against
/// this before the first frame, when the library itself is not built yet.
abstract final class CloudFontIds {
  static Set<String> _values = const {};

  /// The installed family ids.
  static Set<String> get values => _values;

  /// Whether [id] names an installed cloud family.
  static bool contains(String id) => _values.contains(id);

  /// Replaces the boot snapshot (called by both the primary and the clone
  /// boots right after the storage layout resolves).
  static void replace(Iterable<String> next) => _values = Set.unmodifiable(next);
}

/// The family name a pinned face registers under: the cloud family plus the
/// file it was locked to, so it never replaces the family's normal
/// weight-aware registration.
String lockedFontFamily(String id, String face) => '$id@$face';

/// One running download of the library.
final class _FontJob {
  _FontJob(this.total);

  final int total;
  final CancelToken cancel = CancelToken();
  int done = 0;
}

/// The cloud font library: the catalogue of `assets/fonts/fonts-manifest.json`,
/// the files this device holds under `<downloads>/fonts/<id>/`, and the bridge
/// to `dynamic_fonts`.
///
/// Downloads run through the app's own transport (proxy, timeout,
/// cancellation) and fall over the repository's mirrors in order; a family
/// lands in a staging folder and replaces its folder only when every file
/// arrived and looks like a font. Registration hands `dynamic_fonts` the
/// local bytes with their SHA-256 and length, so the package's
/// verify-then-cache pipeline runs on this device's own files — it never
/// reaches the network (the fetch client answers mirror URLs from the font
/// folder). `eager: true` puts every weight of the family under one base
/// family name, which is what the theme's `fontFamily` names.
final class FontLibrary extends ChangeNotifier {
  /// Creates the library over [root] (the fonts folder under the shared
  /// download directory) and the app's transport. [legacyRoot] is the
  /// earlier data-folder location: families downloaded before the shared
  /// folder existed keep working and move into [root] on their next
  /// download.
  FontLibrary({required Directory root, required Directory legacyRoot, required this.http})
    // The root follows the download-folder setting, so it cannot be a final
    // initializing formal.
    // ignore: prefer_initializing_formals
    : _root = root,
      // This one is final but private; a named parameter cannot use `this._`.
      // ignore: prefer_initializing_formals
      _legacyRoot = legacyRoot {
    DynamicFonts.config.httpClient ??= _LocalFontFileClient(this);
    _installed = _scanRoots();
    CloudFontIds.replace(_installed);
  }

  Directory _root;
  final Directory _legacyRoot;

  /// The fonts folder downloads land in.
  Directory get root => _root;

  /// The earlier per-data-folder fonts location, kept read-only.
  Directory get legacyRoot => _legacyRoot;

  /// Follows a changed shared download directory without building a second
  /// library: `dynamic_fonts` keeps the first library's file client for the
  /// process. A running download is cancelled; its staged files stay in the
  /// old folder as `.pending` and the next attempt cleans them up.
  void rebindRoot(Directory root) {
    if (p.equals(root.path, _root.path)) return;
    for (final job in _jobs.values) {
      job.cancel.cancel();
    }
    _root = root;
    _refreshInstalled();
    notifyListeners();
  }

  /// Transport of the downloads (the app's client, so the proxy applies).
  final LiveHttp http;

  List<FontFamily>? _catalog;
  final Map<String, _FontJob> _jobs = {};
  final Set<String> _registered = {};
  late Set<String> _installed;

  /// The family ids downloaded on this device (boot snapshot refreshed by
  /// downloads and deletes).
  Set<String> get installedIds => _installed;

  /// The ids registered with the font loader this session; Flutter cannot
  /// unload, so a deleted family may keep drawing until the app restarts.
  Set<String> get registeredIds => Set.unmodifiable(_registered);

  /// The cloud catalogue; empty when the bundled manifest cannot be read.
  Future<List<FontFamily>> catalog() async {
    final cached = _catalog;
    if (cached != null) return cached;
    try {
      return _catalog = parseFontManifest(await rootBundle.loadString(fontManifestAsset));
    } on Object catch (error) {
      appLog.forCategory('fonts').warning('the font catalogue could not be read', fields: {'error': '$error'});
      return _catalog = const [];
    }
  }

  /// The catalogue family [id], or null when the manifest has none.
  Future<FontFamily?> family(String id) async => (await catalog()).where((family) => family.id == id).firstOrNull;

  /// The shown name of a catalogue family from the cached manifest; null
  /// while the catalogue is unread or the id is not a cloud family.
  String? nameOf(String id) => _catalog?.where((family) => family.id == id).firstOrNull?.name;

  /// The folder of [id]: the download folder when it holds a font, the
  /// legacy data folder when the family predates the shared folder.
  Directory folderOf(String id) {
    final primary = Directory(p.join(_root.path, id));
    if (_folderHasFont(primary)) return primary;
    final legacy = Directory(p.join(_legacyRoot.path, id));
    if (_folderHasFont(legacy)) return legacy;
    return primary;
  }

  /// The font files of [id] on this device, sorted; empty when not here.
  List<File> filesOf(String id) {
    if (!isSafeFontId(id)) return const [];
    _finishInterrupted(id);
    final folder = folderOf(id);
    if (!folder.existsSync()) return const [];
    final files = [
      for (final entity in folder.listSync(followLinks: false))
        if (entity is File && isFontFile(entity)) entity,
    ]..sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  /// Whether [id] is downloaded.
  bool isDownloaded(String id) => filesOf(id).isNotEmpty;

  /// Whether [id] has a download running.
  bool isDownloading(String id) => _jobs.containsKey(id);

  /// The files done and the total of the running download of [id].
  ({int done, int total})? progressOf(String id) {
    final job = _jobs[id];
    return job == null ? null : (done: job.done, total: job.total);
  }

  /// Bytes of [id]'s folder, or null when not downloaded.
  int? sizeOf(String id) {
    final files = filesOf(id);
    if (files.isEmpty) return null;
    return files.fold<int>(0, (total, file) => total + file.lengthSync());
  }

  /// The ids whose folder holds at least one font file, read synchronously
  /// at boot (both the primary and the clones run this over the shared
  /// folder before the first frame).
  static Set<String> scanInstalled(Directory root) {
    if (!root.existsSync()) return const {};
    final ids = <String>{};
    try {
      for (final entity in root.listSync(followLinks: false)) {
        if (entity is! Directory) continue;
        final id = p.basename(entity.path);
        if (!isSafeFontId(id)) continue;
        if (_folderHasFont(entity)) ids.add(id);
      }
    } on FileSystemException {
      // A folder that vanished mid-scan says less, not nothing.
    }
    return Set.unmodifiable(ids);
  }

  /// The union of [roots]' installed family ids.
  static Set<String> scanInstalledRoots(Iterable<Directory> roots) {
    final ids = <String>{};
    for (final root in roots) {
      ids.addAll(scanInstalled(root));
    }
    return Set.unmodifiable(ids);
  }

  static bool _folderHasFont(Directory folder) {
    if (!folder.existsSync()) return false;
    try {
      return folder.listSync(followLinks: false).whereType<File>().any(isFontFile);
    } on FileSystemException {
      return false;
    }
  }

  Set<String> _scanRoots() => scanInstalledRoots([_root, _legacyRoot]);

  /// Registers [id]'s downloaded files with `dynamic_fonts` under the family
  /// name [id] (eager, so every weight lands in one base family) and arms
  /// the load. Safe to call on every boot and on every apply; a family
  /// already registered is left alone.
  ///
  /// A [face] (one file's basename) registers that single file under
  /// [lockedFontFamily] instead, so the viewer can pin one weight and have
  /// every surface use it regardless of the requested font weight.
  Future<void> ensureRegistered(String id, {String face = ''}) async {
    if (!isSafeFontId(id)) return;
    if (face.isNotEmpty) {
      await _registerLocked(id, face);
      return;
    }
    if (_registered.contains(id)) return;
    final files = filesOf(id);
    if (files.isEmpty) return;
    try {
      final variants = <DynamicFontsVariant, DynamicFontsFile>{};
      for (final file in files) {
        final name = p.basename(file.path);
        final bytes = await file.readAsBytes();
        if (!hasFontMagic(bytes)) continue;
        final variant = DynamicFontsVariant(
          fontWeight: fontFileWeight(name),
          fontStyle: fontFileItalic(name) ? FontStyle.italic : FontStyle.normal,
        );
        final digest = sha256.convert(bytes).toString();
        variants.putIfAbsent(variant, () => _CatalogueFile('$id/$name', digest, bytes.length));
      }
      if (variants.isEmpty) return;
      DynamicFonts.register(id, variants, eager: true);
      // The load itself fires from the style builder: one throwaway call
      // starts `dynamic_fonts`' verify-against-the-local-bytes pipeline for
      // every variant under the base family name the theme uses.
      DynamicFonts.getFont(id);
      _registered.add(id);
      notifyListeners();
    } on Object catch (error, stackTrace) {
      appLog
          .forCategory('fonts')
          .warning(
            'the cloud font could not be registered',
            fields: {'id': id, 'error': '$error', 'stack': '$stackTrace'},
          );
    }
  }

  /// Registers one downloaded file of [id] as a family of its own at the
  /// regular weight, so text always draws in that face.
  Future<void> _registerLocked(String id, String face) async {
    final family = lockedFontFamily(id, face);
    if (_registered.contains(family)) return;
    final file = filesOf(id).where((candidate) => p.basename(candidate.path) == face).firstOrNull;
    if (file == null) return;
    try {
      final bytes = await file.readAsBytes();
      if (!hasFontMagic(bytes)) return;
      final digest = sha256.convert(bytes).toString();
      DynamicFonts.register(family, {
        const DynamicFontsVariant(fontWeight: FontWeight.w400, fontStyle: FontStyle.normal): _CatalogueFile(
          '$id/$face',
          digest,
          bytes.length,
        ),
      }, eager: true);
      DynamicFonts.getFont(family);
      _registered.add(family);
      notifyListeners();
    } on Object catch (error, stackTrace) {
      appLog
          .forCategory('fonts')
          .warning(
            'the locked font face could not be registered',
            fields: {'id': id, 'face': face, 'error': '$error', 'stack': '$stackTrace'},
          );
    }
  }

  /// Downloads every file of [family] (files already on disk are kept) and
  /// replaces its folder when complete. Throws [FontDownloadException].
  Future<void> download(FontFamily family) async {
    if (_jobs.containsKey(family.id)) return;
    if (!isSafeFontId(family.id) || !validFontFiles(family.files)) {
      throw const FontDownloadException(FontDownloadFailure.corrupt, 'invalid manifest entry');
    }
    _finishInterrupted(family.id);
    final job = _FontJob(family.files.length);
    _jobs[family.id] = job;
    notifyListeners();
    // The download always lands in the shared folder, even when the family
    // currently resolves to the legacy data folder: re-downloading moves it.
    final folder = Directory(p.join(_root.path, family.id));
    final legacyFolder = Directory(p.join(_legacyRoot.path, family.id));
    final staged = Directory(p.join(_root.path, '.${family.id}.pending'));
    final previous = Directory(p.join(_root.path, '.${family.id}.previous'));
    try {
      if (staged.existsSync()) staged.deleteSync(recursive: true);
      staged.createSync(recursive: true);
      for (final (index, path) in family.files.indexed) {
        if (job.cancel.isCancelled) throw const FontDownloadException(FontDownloadFailure.cancelled);
        job.done = index;
        notifyListeners();
        final name = path.split('/').last;
        final existing = [
          File(p.join(folder.path, name)),
          File(p.join(legacyFolder.path, name)),
        ].where(isFontFile).firstOrNull;
        final target = File(p.join(staged.path, name));
        if (existing != null) {
          await existing.copy(target.path);
          continue;
        }
        await _fetchMirrors(path, target, job.cancel);
        if (!isFontFile(target)) {
          throw FontDownloadException(FontDownloadFailure.corrupt, name);
        }
      }
      job.done = job.total;
      final hadOld = folder.existsSync();
      if (hadOld) folder.renameSync(previous.path);
      try {
        staged.renameSync(folder.path);
      } on FileSystemException {
        if (hadOld && previous.existsSync() && !folder.existsSync()) previous.renameSync(folder.path);
        rethrow;
      }
      if (previous.existsSync()) previous.deleteSync(recursive: true);
    } on FileSystemException catch (error) {
      throw FontDownloadException(FontDownloadFailure.disk, error.message);
    } finally {
      _jobs.remove(family.id);
      _refreshInstalled();
      notifyListeners();
    }
  }

  /// Cancels the running download of [id] (the staged files are discarded).
  void cancelDownload(String id) => _jobs[id]?.cancel.cancel();

  /// Deletes [id]'s files from both the shared folder and the legacy data
  /// folder. A registered family keeps drawing until the app restarts —
  /// Flutter cannot unload fonts — but the folder is gone.
  Future<bool> delete(String id) async {
    if (!isSafeFontId(id)) return false;
    try {
      for (final folder in [
        Directory(p.join(_root.path, id)),
        Directory(p.join(_root.path, '.$id.pending')),
        Directory(p.join(_root.path, '.$id.previous')),
        Directory(p.join(_legacyRoot.path, id)),
      ]) {
        if (folder.existsSync()) folder.deleteSync(recursive: true);
      }
    } on FileSystemException catch (error) {
      appLog
          .forCategory('fonts')
          .warning('the cloud font was not deleted', fields: {'id': id, 'error': error.message});
      return false;
    }
    _refreshInstalled();
    notifyListeners();
    return true;
  }

  /// Tries every mirror of [path] in order and writes the first complete
  /// answer to [target].
  Future<void> _fetchMirrors(String path, File target, CancelToken cancel) async {
    Object? lastError;
    for (final url in kCloudFontRepository.mirrors(path)) {
      if (cancel.isCancelled) throw const FontDownloadException(FontDownloadFailure.cancelled);
      try {
        final response = await http.send(
          LiveRequest.get(
            url,
            headers: const {
              'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/151.0.0.0 Safari/537.36',
            },
            site: 'fonts',
            timeout: const Duration(seconds: 60),
            cancelToken: cancel,
          ),
        );
        if (!response.isOk) {
          lastError = 'status ${response.statusCode}';
          continue;
        }
        if (response.bodyBytes.isEmpty) {
          lastError = 'empty body';
          continue;
        }
        await target.writeAsBytes(response.bodyBytes, flush: true);
        return;
      } on Object catch (error) {
        if (cancel.isCancelled) throw const FontDownloadException(FontDownloadFailure.cancelled);
        lastError = error;
      }
    }
    throw FontDownloadException(FontDownloadFailure.network, '$lastError');
  }

  /// A download stopped between moving the old folder away and the new one
  /// in: the old one comes back.
  void _finishInterrupted(String id) {
    for (final root in [_root, _legacyRoot]) {
      final folder = Directory(p.join(root.path, id));
      final abandoned = Directory(p.join(root.path, '.$id.previous'));
      if (!abandoned.existsSync()) continue;
      try {
        if (folder.existsSync()) {
          abandoned.deleteSync(recursive: true);
        } else {
          abandoned.renameSync(folder.path);
        }
      } on FileSystemException {
        // Tried again next time.
      }
    }
  }

  void _refreshInstalled() {
    final next = _scanRoots();
    if (!setEquals(_installed, next)) {
      _installed = next;
      CloudFontIds.replace(next);
    }
  }

  @override
  void dispose() {
    for (final job in _jobs.values) {
      job.cancel.cancel();
    }
    super.dispose();
  }
}

/// Whether [bytes] start like a TrueType/OpenType font.
bool hasFontMagic(Uint8List bytes) {
  if (bytes.length < 12) return false;
  final tag = String.fromCharCodes(bytes.sublist(0, 4));
  return (bytes[0] == 0 && bytes[1] == 1 && bytes[2] == 0 && bytes[3] == 0) ||
      tag == 'OTTO' ||
      tag == 'true' ||
      tag == 'typ1' ||
      tag == 'ttcf';
}

/// One downloaded catalogue file: a mirror URL of the font repository whose
/// [DynamicFontsFile.url] the library's fetch client answers from the local
/// folder, verified against the SHA-256 and length of those very bytes.
final class _CatalogueFile extends DynamicFontsFile {
  _CatalogueFile(this.repoPath, String expectedFileHash, int expectedLength)
    : super(expectedFileHash, expectedLength);

  /// The path in the repository, `<folder>/<file>`.
  final String repoPath;

  @override
  String get url => kCloudFontRepository.rawUrl(repoPath).toString();
}

/// The fetch client `dynamic_fonts` is handed: every URL of the font
/// repository is answered from the local font folder, so registration and
/// the package's own device cache run fully offline. Anything else fails
/// fast — the library downloads through the app's transport, never here.
final class _LocalFontFileClient extends http.BaseClient {
  _LocalFontFileClient(this.library);

  final FontLibrary library;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.method != 'GET') throw Exception('unexpected font request method: ${request.method}');
    final relative = kCloudFontRepository.relativePath(request.url);
    if (relative == null) throw Exception('unexpected font fetch URL: ${request.url}');
    final segments = relative.split('/');
    if (segments.length < 2) throw Exception('unexpected font fetch path: $relative');
    final (id, name) = (segments.first, segments.last);
    if (!isSafeFontId(id)) throw Exception('unsafe font id: $id');
    final file = File(p.join(library.folderOf(id).path, name));
    if (!isFontFile(file)) throw Exception('the local font file is missing or unreadable: ${file.path}');
    final bytes = await file.readAsBytes();
    return http.StreamedResponse(
      http.ByteStream.fromBytes(bytes),
      200,
      contentLength: bytes.length,
      request: request,
      headers: const {'content-type': 'font/ttf'},
    );
  }
}
