// Opt-in production parsers + official anonymous endpoints; no media, user
// profiles, HTML bodies, visitor credentials or signed URLs are persisted.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/domains/live/data/platforms/acfun/acfun_api.dart';
import 'package:pure_live/domains/live/data/platforms/acfun/acfun_search.dart';
import 'package:pure_live/domains/live/data/platforms/acfun/acfun_site.dart';

void main() {
  test(
    'AcFun directory, official categories, author pagination and explicit empty search',
    () async {
      await HttpOverrides.runWithHttpOverrides(() async {
        final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
        final proxy = Platform.environment['PURELIVE_PROBE_PROXY'];
        if (proxy?.isNotEmpty == true) {
          final address = Uri.parse(proxy!);
          client.findProxy = (_) => 'PROXY ${address.host}:${address.port}';
        }
        Future<String> read(Uri uri, Map<String, dynamic> headers) async {
          final request = await client.getUrl(uri);
          headers.forEach((name, value) => request.headers.set(name, value));
          final response = await request.close().timeout(const Duration(seconds: 15));
          if (response.statusCode != 200) throw const FormatException('Non-success status');
          final buffer = BytesBuilder(copy: false);
          await for (final bytes in response.timeout(const Duration(seconds: 15))) {
            buffer.add(bytes);
            if (buffer.length > 1024 * 1024) throw const FormatException('Oversized response');
          }
          return utf8.decode(buffer.takeBytes());
        }

        var stage = 'initialization';
        try {
          final api = AcfunApi(
            request: (method, url, {query, body, headers}) async {
              expect(method, 'GET');
              final uri = Uri.parse(url).replace(queryParameters: query?.map((k, v) => MapEntry(k, '$v')));
              return jsonDecode(await read(uri, headers ?? AcfunApi.playHeaders));
            },
          );
          final site = AcfunSite(
            api: api,
            search: AcfunSearchClient(
              request: (uri, _) =>
                  read(uri, {'User-Agent': AcfunApi.userAgent, 'Referer': 'https://www.acfun.cn/search'}),
            ),
          );
          stage = 'directory-first-page';
          final first = await site.getRecommendRooms(pageSize: 2);
          expect(first, isNotEmpty);
          stage = 'category-catalog';
          final categories = (await site.getCategores(1, 30)).single.children;
          expect(categories, isNotEmpty);
          stage = 'directory-second-page';
          final second = await site.getRecommendRooms(page: 2, pageSize: 2);
          expect(second, isNotEmpty);
          expect(second.map((r) => r.roomId), isNot(orderedEquals(first.map((r) => r.roomId))));
          final category = categories.firstWhere((c) => c.areaId == '1');
          stage = 'category-rooms';
          final filtered = await site.getCategoryRooms(category, pageSize: 2);
          stage = 'search-first-page';
          final results = await site.searchRooms('游戏', page: 1, pageSize: 20);
          stage = 'search-second-page';
          results.addAll(await site.searchRooms('游戏', page: 2, pageSize: 20));
          expect(results, hasLength(40));
          final pageSizes = [20, 20];
          for (var page = 3; page <= 10; page++) {
            stage = 'search-page-$page';
            final rows = await site.searchRooms('游戏', page: page, pageSize: 20);
            results.addAll(rows);
            pageSizes.add(rows.length);
            if (rows.length < 20) break;
          }
          expect(pageSizes.last, lessThan(20));
          expect(results.map((r) => r.roomId).toSet(), hasLength(results.length));
          expect(results.every((r) => r.onlineViewers?.isEmpty == true), isTrue);
          stage = 'empty-search';
          final empty = await site.searchRooms('qzxv7319deadbeef9502ffdba762884a33ffff');
          expect(empty, isEmpty);
          // ignore: avoid_print
          print(
            jsonEncode({
              'probe': 'production-acfun-navigation',
              'directoryPages': [first.length, second.length],
              'categories': categories.map((c) => {'type': c.areaType, 'id': c.areaId, 'name': c.areaName}).toList(),
              'filteredRooms': filtered.length,
              'searchUniqueCount': results.length,
              'searchPageSizes': pageSizes,
              'explicitEmpty': true,
              'proxyConfigured': proxy?.isNotEmpty == true,
              'credentialsPersisted': false,
              'evidenceLayer': 'official-interface-and-production-parser-not-device-or-recording',
            }),
          );
        } catch (error, stack) {
          final safeError = error is AcfunApiException ? error.toString() : '${error.runtimeType}';
          final frames = stack.toString().split('\n').where((s) => s.contains('.dart:')).take(4).join('\n');
          fail('AcFun navigation probe failed at $stage ($safeError)\n$frames');
        } finally {
          client.close(force: true);
        }
      }, _RealNetwork());
    },
    skip: Platform.environment['PURELIVE_ACFUN_NAVIGATION_PROBE'] != '1',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

class _RealNetwork extends HttpOverrides {}
