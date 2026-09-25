import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';
import 'package:path/path.dart' as p;

import 'src/apple.dart';
import 'src/bundles.dart';

void main(List<String> arguments) async {
  await build(arguments, (input, output) async {
    if (!input.config.buildCodeAssets) return;
    final os = input.config.code.targetOS;
    final architecture = input.config.code.targetArchitecture;
    final catalogFile = File.fromUri(
      input.packageRoot.resolve('hook/native_bundles.json'),
    );
    final catalog = await Bundle.read(catalogFile);
    output.dependencies.add(catalogFile.uri);
    final target = '${os.name}_${architecture.name}';
    final bundle = catalog[target];
    if (bundle == null) {
      throw UnsupportedError('No media-kit native bundle for $target');
    }

    final source = input.userDefines['source'] ?? 'bundled';
    if (source == 'system') {
      if (os != OS.linux && os != OS.windows) {
        throw UnsupportedError(
          'System libmpv is supported on Linux and Windows only',
        );
      }
      output.assets.code.add(
        CodeAsset(
          package: input.packageName,
          name: 'libmpv',
          linkMode: DynamicLoadingSystem(Uri(path: bundle.library)),
        ),
      );
    } else {
      final Directory directory;
      if (source == 'local') {
        final path = input.userDefines.path('library-directory');
        if (path == null) {
          throw ArgumentError('source: local requires library-directory');
        }
        directory = Directory.fromUri(path);
        await for (final entity in directory.list(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is File) output.dependencies.add(entity.uri);
        }
      } else if (source == 'bundled') {
        final cache = BundleCache(
          Directory.fromUri(
            input.userDefines.path('cache-directory') ??
                input.outputDirectoryShared.resolve('prebuilt/'),
          ),
        );
        final extracted = await cache.prepare(bundle);
        directory = bundle.root == null
            ? extracted
            : Directory(p.join(extracted.path, bundle.root));
      } else {
        throw ArgumentError('Unknown media-kit source: $source');
      }
      final libraries = bundle.xcframework
          ? await prepareAppleLibraries(
              directory,
              Directory.fromUri(input.outputDirectory.resolve('frameworks/')),
              os.name,
              architecture == Architecture.x64 ? 'x86_64' : 'arm64',
              simulator:
                  os == OS.iOS &&
                  input.config.code.iOS.targetSdk == IOSSdk.iPhoneSimulator,
            )
          : await selectLibraries(directory, bundle.library);
      if (os == OS.android &&
          !libraries.any(
            (file) => p.basename(file.path) == 'libmediakitandroidhelper.so',
          )) {
        throw StateError(
          'Android requires libmediakitandroidhelper.so alongside libmpv.so',
        );
      }
      for (final library in libraries) {
        final basename = p.basename(library.path);
        output.assets.code.add(
          CodeAsset(
            package: input.packageName,
            name: basename == bundle.library ? 'libmpv' : 'native/$basename',
            linkMode: DynamicLoadingBundled(),
            file: library.uri,
          ),
        );
        output.dependencies.add(library.uri);
      }
    }
    await CBuilder.library(
      name: 'media_kit_event_loop',
      assetName: 'src/player/native/core/native_event_loop_bindings.dart',
      sources: ['src/native_event_loop.c', 'src/native_library.c'],
      includes: [
        File(
          Platform.resolvedExecutable,
        ).parent.parent.uri.resolve('include/').toFilePath(),
      ],
      libraries: [
        if (os == OS.linux) ...['pthread', 'dl'],
        if (os == OS.android) 'dl',
      ],
    ).run(input: input, output: output);
  });
}
