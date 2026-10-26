import 'dart:async' show unawaited;
import 'dart:io' show Directory;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_net/live_net.dart' show ClientProfile;
import 'package:path/path.dart' as p;

import 'package:pure_live/app/providers/download_directory_provider.dart'
    show DownloadDirectory, DownloadDirectoryPaths, downloadDirectoryProvider;
import 'package:pure_live/app/providers/network_providers.dart' show networkFactoryProvider;
import 'package:pure_live/app/providers/storage_providers.dart' show storagePathsProvider;
import 'package:pure_live/app/theme/fonts/font_library.dart' show FontLibrary;

/// The cloud font library: the manifest catalogue, the fonts folder under
/// the shared download directory and the `dynamic_fonts` bridge. One per
/// engine — a clone registers the stored family from the shared folder for
/// its own isolate.
final fontLibraryProvider = Provider<FontLibrary>((ref) {
  final paths = ref.watch(storagePathsProvider);
  final factory = ref.watch(networkFactoryProvider);
  final downloads = ref.read(downloadDirectoryProvider);
  final library = FontLibrary(
    root: downloads.fontsRoot,
    legacyRoot: Directory(p.join(paths.data.path, 'fonts')),
    http: factory.create(profile: ClientProfile.api),
  );
  // The download folder is a setting: switching it rebinds the one library
  // instead of building a second one, because `dynamic_fonts` keeps the
  // first library's local-file client for the process.
  ref.listen<DownloadDirectory>(downloadDirectoryProvider, (_, next) => library.rebindRoot(next.fontsRoot));
  // Warm the catalogue so `nameOf` answers during the first settings paint.
  unawaited(library.catalog());
  ref.onDispose(library.dispose);
  return library;
});
