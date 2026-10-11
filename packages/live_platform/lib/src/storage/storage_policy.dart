import 'dart:io';

import 'package:live_platform/src/contracts/storage_area.dart';
import 'package:live_platform/src/runtime/platform_runtime_info.dart';

/// Ordered candidate directories per storage area.
///
/// The resolver tries candidates in order and keeps the first one that
/// passes a real write probe. Implementations decide fallback order from
/// the deployment snapshot — e.g. a portable layout tries the `data/`
/// tree next to the executable first and the user-data directory second,
/// while an installed layout never offers the executable directory.
abstract interface class StoragePolicy {
  /// The candidate directories for [area], best first. May be empty; an
  /// empty list means "no acceptable location was planned" and the
  /// resolver reports it as such.
  List<Directory> candidatesFor(StorageArea area, PlatformRuntimeInfo runtime);
}

/// The standard PureLive layout.
///
/// Root directories come from the app shell (path_provider results, or
/// portable-mode detection): `portableRoot` is the `data/` tree next to
/// the executable, `userRoot` the OS application-support directory,
/// `cacheRoot` the OS cache directory, `tempRoot` the system temporary
/// directory.
final class DefaultStoragePolicy implements StoragePolicy {
  /// A policy over the four roots. Null roots are simply never offered
  /// as candidates.
  const new({this.portableRoot, this.userRoot, this.cacheRoot, this.tempRoot});

  /// The `data/` tree next to the executable (portable layouts only).
  final Directory? portableRoot;

  /// The OS per-user application-data directory.
  final Directory? userRoot;

  /// The OS cache directory.
  final Directory? cacheRoot;

  /// The system temporary directory.
  final Directory? tempRoot;

  @override
  List<Directory> candidatesFor(StorageArea area, PlatformRuntimeInfo runtime) {
    final persistent = switch (area) {
      StorageArea.data ||
      StorageArea.config ||
      StorageArea.extensions ||
      StorageArea.imports ||
      StorageArea.exports => true,
      StorageArea.cache || StorageArea.temporary => false,
    };
    if (persistent) {
      return [
        if (runtime.isPortable && portableRoot != null) Directory('${portableRoot!.path}/${_segment(area)}'),
        if (userRoot != null) Directory('${userRoot!.path}/${_segment(area)}'),
      ];
    }
    return switch (area) {
      StorageArea.cache => [
        if (runtime.isPortable && portableRoot != null) Directory('${portableRoot!.path}/cache'),
        if (cacheRoot != null) Directory('${cacheRoot!.path}/pure_live'),
        if (tempRoot != null) Directory('${tempRoot!.path}/pure_live_cache'),
      ],
      StorageArea.temporary => [
        if (runtime.isPortable && portableRoot != null) Directory('${portableRoot!.path}/temp'),
        if (tempRoot != null) Directory('${tempRoot!.path}/pure_live'),
      ],
      _ => const [],
    };
  }

  static String _segment(StorageArea area) => switch (area) {
    StorageArea.data => 'data',
    StorageArea.config => 'config',
    StorageArea.extensions => 'extensions',
    StorageArea.imports => 'imports',
    StorageArea.exports => 'exports',
    StorageArea.cache => 'cache',
    StorageArea.temporary => 'temp',
  };
}
