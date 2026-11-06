/// Temporary-resource cache for Pure Live.
///
/// One clearable tree for re-fetchable images and temporary files, with
/// category policies, a disk cache behind an `ImageProvider`, an optional
/// in-memory API cache and the statistics/cleanup surface a settings page
/// needs. Persistent data — downloads, recordings, favourites, user
/// wallpapers — never belongs here.
///
/// The host application constructs one `LiveCacheManager` at its composition
/// root and injects the cache directory, HTTP client and configuration; the
/// package creates no global singletons and reads no settings.
library;

export 'src/image/image.dart';
export 'src/management/management.dart';
export 'src/memory/memory.dart';
export 'src/models/models.dart';
export 'src/storage/storage.dart';
