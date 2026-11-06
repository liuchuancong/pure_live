import 'dart:async' show unawaited;
import 'dart:io' show Directory, File, FileSystemException, Platform;

import 'package:live_net/live_net.dart' show CancelToken, LiveHttp, LiveRequest;
import 'package:media_core_audio/media_core_audio.dart' as audio;

/// A file in the cache directory.
typedef CachedAudioFile = ({String name, int size, DateTime modified});

/// The file operations the cache needs, on its own directory. The app
/// implements it with `dart:io` under the cache root; tests use a map.
abstract interface class MusicCacheFiles {
  /// Every file in the directory.
  Future<List<CachedAudioFile>> list();

  /// Size of [name], or null when it does not exist.
  Future<int?> sizeOf(String name);

  /// Renames [from] to [to], replacing [to].
  Future<void> rename(String from, String to);

  /// Deletes [name]; a missing file is not an error.
  Future<void> delete(String name);
}

/// Cache keys: one file per track and quality tier, the reference's shape
/// (`{bvid}_{cid}`) carried over to track ids.
abstract final class MusicAudioCacheKey {
  static final RegExp _unsafe = RegExp('[^A-Za-z0-9_-]');

  /// The key of a track's audio in [quality]; null quality shares the auto
  /// slot, since the source may downgrade the tier anyway.
  static String of(audio.MusicTrack track, audio.MusicQuality? quality) =>
      '${track.sourceId.replaceAll(_unsafe, '')}_${track.id.replaceAll(_unsafe, '')}_${quality?.id ?? 'auto'}';

  /// The finished file of [key].
  static String fileOf(String key) => '$key.audio';

  /// The download in progress of [key]; renamed to [fileOf] only when the
  /// response was written whole, so a partial file is never played.
  static String partOf(String key) => '$key.audio.part';
}

/// What the cache needs from its host, read fresh on every use: the limit
/// changes take effect without a restart, and the transport follows the
/// app's proxy policy like every other network call.
typedef MusicCacheEnvironment = ({Directory directory, int limitMb, LiveHttp http});

/// Persistent audio cache of the music module: a song heard once plays from
/// disk, so it no longer depends on CDN links that expire within minutes.
///
/// At most [maxBytes] is kept, evicting the least recently played files
/// first and never the ones in `keep` (the song playing). Downloads write a
/// `.part` file that becomes the cached file only once the response was
/// written whole.
final class MusicAudioCache {
  /// Creates the cache over [files].
  MusicAudioCache(this.files, {this.maxBytes = 512 * 1024 * 1024, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  /// The directory.
  final MusicCacheFiles files;

  /// Size limit.
  int maxBytes;

  final DateTime Function() _now;
  final Map<String, _CacheEntry> _entries = {};
  final Set<String> _downloading = {};

  /// Bytes in finished files.
  int get totalBytes => _entries.values.fold(0, (sum, entry) => sum + entry.size);

  /// Keys of finished files, least recently used first.
  List<String> get keys =>
      ([..._entries.entries]..sort((a, b) => a.value.used.compareTo(b.value.used))).map((entry) => entry.key).toList();

  /// Reads the directory: finished files join the index (last use = their
  /// modification time), leftover partial files are deleted.
  Future<void> load() async {
    _entries.clear();
    for (final file in await files.list()) {
      if (file.name.endsWith('.part')) {
        await files.delete(file.name);
      } else if (file.name.endsWith('.audio')) {
        _entries[file.name.substring(0, file.name.length - '.audio'.length)] = _CacheEntry(file.size, file.modified);
      }
    }
  }

  /// The file of [key] when it is cached (and marks it used), else null.
  String? lookup(String key) {
    final entry = _entries[key];
    if (entry == null) return null;
    entry.used = _now();
    return MusicAudioCacheKey.fileOf(key);
  }

  /// Whether [key] is downloading.
  bool isDownloading(String key) => _downloading.contains(key);

  /// Starts a download of [key]: the partial file name to write, or null
  /// when it is cached or already downloading.
  String? begin(String key) {
    if (_entries.containsKey(key) || !_downloading.add(key)) return null;
    return MusicAudioCacheKey.partOf(key);
  }

  /// The download of [key] finished: the partial file becomes the cached
  /// file (an empty one is dropped), then the cache is trimmed. [keep] is
  /// never evicted.
  Future<void> commit(String key, {Set<String> keep = const {}}) async {
    _downloading.remove(key);
    final part = MusicAudioCacheKey.partOf(key);
    final size = await files.sizeOf(part) ?? 0;
    if (size <= 0) {
      await files.delete(part);
      return;
    }
    await files.rename(part, MusicAudioCacheKey.fileOf(key));
    _entries[key] = _CacheEntry(size, _now());
    await trim(keep: {...keep, key});
  }

  /// The download of [key] failed or was cancelled: its partial file goes.
  Future<void> abort(String key) async {
    _downloading.remove(key);
    await files.delete(MusicAudioCacheKey.partOf(key));
  }

  /// Evicts least recently used files until the cache fits [maxBytes];
  /// [keep] is never evicted.
  Future<void> trim({Set<String> keep = const {}}) async {
    var total = totalBytes;
    for (final key in keys) {
      if (total <= maxBytes) break;
      if (keep.contains(key)) continue;
      total -= _entries.remove(key)!.size;
      await files.delete(MusicAudioCacheKey.fileOf(key));
    }
  }

  /// Empties the cache (downloads in progress finish into it).
  Future<void> clear() async {
    final keys = [..._entries.keys];
    _entries.clear();
    for (final key in keys) {
      await files.delete(MusicAudioCacheKey.fileOf(key));
    }
  }
}

final class _CacheEntry {
  _CacheEntry(this.size, this.used);

  final int size;
  DateTime used;
}

/// The `dart:io` [MusicCacheFiles] over [root].
final class DirectoryMusicCacheFiles implements MusicCacheFiles {
  /// Serves the cache under [root].
  DirectoryMusicCacheFiles(this.root);

  /// The cache's own folder.
  final Directory root;

  /// The absolute path of a cache file name.
  String pathOf(String name) => '${root.path}${Platform.pathSeparator}$name';

  @override
  Future<List<CachedAudioFile>> list() async {
    if (!root.existsSync()) return const [];
    final found = <CachedAudioFile>[];
    for (final entity in root.listSync(followLinks: false)) {
      if (entity is! File) continue;
      try {
        final stat = entity.statSync();
        found.add((name: entity.uri.pathSegments.last, size: stat.size, modified: stat.modified));
      } on FileSystemException {
        continue;
      }
    }
    return found;
  }

  @override
  Future<int?> sizeOf(String name) async {
    final file = File(pathOf(name));
    if (!file.existsSync()) return null;
    return file.statSync().size;
  }

  @override
  Future<void> rename(String from, String to) async {
    await Future<void>(() => File(pathOf(from)).renameSync(pathOf(to)));
  }

  @override
  Future<void> delete(String name) async {
    await Future<void>(() {
      final file = File(pathOf(name));
      if (file.existsSync()) file.deleteSync();
    });
  }
}

/// The music sources wearing the audio cache: a resolve first asks the
/// disk, and a resolve that reached the network is written into the cache
/// while it plays. Heard-once songs then survive their CDN link expiring.
final class CachedTrackSource extends audio.MusicSource {
  /// Wraps [inner] with the cache; [environment] read fresh on every
  /// resolve, and a null (no folder, limit 0) leaves the cache off.
  CachedTrackSource(this.inner, {required this.environment});

  /// The platform source the calls ride on.
  final audio.MusicSource inner;

  /// The cache's host facts, read per resolve.
  final MusicCacheEnvironment? Function() environment;

  Future<MusicAudioCache?>? _loading;
  MusicAudioCache? _loaded;
  int _loadedLimitMb = -1;

  /// The cache for the environment in force, rebuilt when the limit moves;
  /// null when the cache is off.
  Future<MusicAudioCache?> _cacheNow() {
    final env = environment();
    if (env == null || env.limitMb <= 0) return Future<MusicAudioCache?>.value();
    if (_loaded != null && _loadedLimitMb == env.limitMb) return Future<MusicAudioCache?>.value(_loaded);
    return _loading ??= () async {
      try {
        final files = DirectoryMusicCacheFiles(Directory('${env.directory.path}${Platform.pathSeparator}music-audio'));
        final cache = MusicAudioCache(files, maxBytes: env.limitMb * 1024 * 1024);
        await files.root.create(recursive: true);
        await cache.load();
        _loaded = cache;
        _loadedLimitMb = env.limitMb;
        return cache;
      } on Object {
        return null;
      } finally {
        _loading = null;
      }
    }();
  }

  @override
  String get id => inner.id;

  @override
  String get name => inner.name;

  @override
  Future<audio.MusicSourcePage<audio.MusicTrack>> search(String keyword, {int page = 1, int pageSize = 30}) =>
      inner.search(keyword, page: page, pageSize: pageSize);

  @override
  Future<audio.MusicTrack> trackDetail(audio.MusicTrack track) => inner.trackDetail(track);

  @override
  Future<List<audio.MusicQuality>> qualities(audio.MusicTrack track) => inner.qualities(track);

  @override
  Future<audio.TrackSource> resolveTrackSource(audio.MusicTrack track, {audio.MusicQuality? quality}) async {
    final cache = await _cacheNow();
    if (cache == null) return await inner.resolveTrackSource(track, quality: quality);
    final key = MusicAudioCacheKey.of(track, quality);
    final file = cache.lookup(key);
    if (file != null) {
      final path = (cache.files as DirectoryMusicCacheFiles).pathOf(file);
      return audio.TrackSource(uri: Uri.file(path), isLocal: true, quality: quality);
    }
    final source = await inner.resolveTrackSource(track, quality: quality);
    if (!source.isLocal && (source.uri.isScheme('http') || source.uri.isScheme('https'))) {
      unawaited(_download(cache, key, source));
    }
    return source;
  }

  /// Writes [source]'s body into the cache while the song plays; a failure
  /// only costs the copy, never the playback.
  Future<void> _download(MusicAudioCache cache, String key, audio.TrackSource source) async {
    final part = cache.begin(key);
    if (part == null) return;
    final env = environment();
    if (env == null) {
      await cache.abort(key);
      return;
    }
    final files = cache.files as DirectoryMusicCacheFiles;
    final token = CancelToken();
    try {
      final response = await env.http.open(
        LiveRequest.custom(method: 'GET', url: source.uri, headers: source.headers, cancelToken: token),
      );
      if (response.statusCode != 200) {
        throw StateError('HTTP ${response.statusCode}');
      }
      final sink = File(files.pathOf(part)).openWrite();
      try {
        await response.stream.forEach(sink.add);
      } finally {
        await sink.close();
      }
      await cache.commit(key);
    } on Object {
      token.cancel();
      await cache.abort(key);
    }
  }

  @override
  Future<audio.MusicLyricPayload?> resolveLyric(audio.MusicTrack track) => inner.resolveLyric(track);

  @override
  Future<List<audio.MusicCatalog>> catalogs() => inner.catalogs();

  @override
  Future<audio.MusicSourcePage<audio.MusicTrack>> catalogItems(audio.MusicCatalog catalog, {int page = 1}) =>
      inner.catalogItems(catalog, page: page);
}

/// The process's one audio cache, once the playback wiring has armed it:
/// the settings read the usage and clear it. Null until a music module
/// with a usable folder ran.
final class MusicAudioCacheBox {
  MusicAudioCacheBox._();

  /// The one box.
  static final MusicAudioCacheBox instance = MusicAudioCacheBox._();

  CachedTrackSource? _wearing;

  /// Arms the box with the first decorated source the playback builds.
  void arm(CachedTrackSource wearing) => _wearing ??= wearing;

  /// Bytes the cache holds, or null while it is off.
  Future<int?> usageBytes() async {
    final cache = await _wearing?._cacheNow();
    return cache?.totalBytes;
  }

  /// Empties the cache.
  Future<void> clear() async {
    final cache = await _wearing?._cacheNow();
    await cache?.clear();
  }
}
