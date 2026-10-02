import 'dart:convert';
import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/network/http_client.dart';
import 'package:pure_live/domains/wallpaper/domain/wallpaper_catalog.dart';
import 'package:pure_live/domains/wallpaper/data/local_wallpapers.dart';
import 'package:pure_live/domains/wallpaper/data/wallpaper_repository.dart';

/// Live check of the iTab wallpaper endpoints the background browser reads.
///
/// The requests are replayed from the extension's own traffic, including the
/// `mode`/`version`/`fp` headers the server gates on, so a silent change there
/// shows up here rather than as an empty grid in the settings page.
void main() {
  test(
    'iTab wallpaper endpoints answer and parse for every paged source',
    () async {
      await io.HttpOverrides.runWithHttpOverrides(() async {
        final previous = HttpClient.instance.dio;
        final dio = Dio(
          BaseOptions(connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 20)),
        )..httpClientAdapter = IOHttpClientAdapter(createHttpClient: () => io.HttpClient());
        final hosts = <String>{};
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              hosts.add(options.uri.host);
              handler.next(options);
            },
          ),
        );
        HttpClient.instance.dio = dio;

        final repository = WallpaperRepository.instance;
        final catalog = repository.loadCatalog();
        final results = <Map<String, Object?>>[];
        try {
          for (final sourceId in [
            WallpaperSourceIds.official,
            WallpaperSourceIds.wallhaven,
            WallpaperSourceIds.bing,
            WallpaperSourceIds.video,
          ]) {
            final source = catalog.sourceById(sourceId)!;
            final group = source.visibleGroups.first;
            final size = repository.serverPageSize(sourceId);
            final items = await repository.fetchPage(source: source, group: group, page: 1, size: size);
            results.add(<String, Object?>{
              'source': sourceId,
              'group': group.id,
              'asked': size,
              'returned': items.length,
              'allAbsoluteUrls': items.every((item) => item.file.startsWith('https://')),
              'withThumb': items.where((item) => (item.thumb ?? '').isNotEmpty).length,
              'withPoster': items.where((item) => (item.poster ?? '').isNotEmpty).length,
              'sample': items.isEmpty ? null : items.first.file,
            });
            expect(items, isNotEmpty, reason: '$sourceId answered no rows');
            expect(items.every((item) => item.file.startsWith('https://')), isTrue, reason: '$sourceId gave a bad url');
          }

          // Bing rows are swapped to the 4K original; if the URL shape changes
          // the swap silently stops applying and the grid serves 1080p again.
          final bing = await repository.fetchPage(
            source: catalog.sourceById(WallpaperSourceIds.bing)!,
            group: catalog.sourceById(WallpaperSourceIds.bing)!.visibleGroups.first,
            page: 1,
            size: 4,
          );
          expect(bing.first.file, contains('UHD.jpg'));

          // The compiled-in sets must not need the network at all.
          expect(LocalWallpapers.of(WallpaperSourceIds.solidColor).length, 151);
          expect(LocalWallpapers.of(WallpaperSourceIds.deepin).length, 26);
          final deepinUrl = LocalWallpapers.of(WallpaperSourceIds.deepin).first.file;
          expect(cdnThumb(deepinUrl), contains('x-oss-process'));

          final head = await dio.get<ResponseBody>(
            deepinUrl,
            options: Options(responseType: ResponseType.stream, headers: {'Range': 'bytes=0-1023'}),
          );
          final bytes = <int>[];
          await for (final chunk in head.data!.stream) {
            bytes.addAll(chunk);
          }
          expect(bytes.length, greaterThan(0), reason: 'deepin CDN returned nothing');

          final result = <String, Object?>{
            'pages': results,
            'hosts': hosts.toList(),
            'bingUhd': bing.first.file,
            'deepinBytes': bytes.length,
          };
          final output = io.Platform.environment['PURELIVE_ITAB_WALLPAPER_PROBE_OUTPUT'];
          if (output != null && output.isNotEmpty) {
            final file = io.File(output);
            await file.parent.create(recursive: true);
            await file.writeAsString('${const JsonEncoder.withIndent('  ').convert(result)}\n');
          }
          // ignore: avoid_print
          print(jsonEncode(result));
        } finally {
          HttpClient.instance.dio = previous;
          dio.close(force: true);
        }
      }, _RealNetwork());
    },
    skip: io.Platform.environment['PURELIVE_ITAB_WALLPAPER_PROBE'] != '1',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

class _RealNetwork extends io.HttpOverrides {}
