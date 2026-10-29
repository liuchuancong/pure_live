import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/modules/music/controller/music_source_catalog.dart'
    show MusicCatalogFetchException, fetchCatalogScript, kMusicSourceCatalog, musicCatalogScriptUrls;
import 'package:pure_live/modules/music/controller/music_sources.dart';

void main() {
  group('MusicCustomSource.parse', () {
    const header = '/**\n * @name 测试源\n * @description 说明\n * @author 某人\n * @version 1.2.3\n */\n';

    test('accepts the plain lx.on contract', () {
      final source = MusicCustomSource.parse("$header\nlx.on('request', () => {});\n", id: 'a');
      expect(source, isNotNull);
      expect(source!.name, '测试源');
      expect(source.description, '说明');
      expect(source.author, '某人');
      expect(source.version, '1.2.3');
    });

    test('accepts a renamed destructure — on(n.request, …)', () {
      final source = MusicCustomSource.parse(
        '$header\nlet { EVENT_NAMES: n, request: b, on } = globalThis.lx;\non(n.request, () => {});\n',
        id: 'a',
      );
      expect(source, isNotNull);
    });

    test('accepts an obfuscated destructure with no visible handler call', () {
      const packed =
          "$header\nconst { EVENT_NAMES: _0x5e, on: _0x4f, send: _0x48 } = globalThis['lx'];\n_0x4f(_0x5e.request, h);\n";
      expect(MusicCustomSource.parse(packed, id: 'a'), isNotNull);
    });

    test('accepts a fully packed script — header and globalThis only', () {
      const packed = "$header\n;(function(a,b){return a^b})(1,2);\nglobalThis['SERVER_SCRIPT_CONFIG']={};\n";
      expect(MusicCustomSource.parse(packed, id: 'a'), isNotNull);
    });

    test('accepts the bang header — /*!', () {
      const script = '/*!\n * @name 测试源\n */\nconst { on } = globalThis.lx;\n';
      expect(MusicCustomSource.parse(script, id: 'a'), isNotNull);
    });

    test('rejects a bare address — no header', () {
      expect(MusicCustomSource.parse('https://example.com/latest.js', id: 'a'), isNull);
    });

    test('rejects an html page', () {
      const page = '<!doctype html>\n<html><body>404 not found</body></html>\n';
      expect(MusicCustomSource.parse(page, id: 'a'), isNull);
    });

    test('rejects a header without @name', () {
      const script = '/**\n * @author 某人\n */\nconst { on } = globalThis.lx;\n';
      expect(MusicCustomSource.parse(script, id: 'a'), isNull);
    });
  });

  group('kMusicSourceCatalog', () {
    test('holds the sixteen collection entries with unique ids', () {
      expect(kMusicSourceCatalog, hasLength(16));
      expect(kMusicSourceCatalog.map((entry) => entry.id).toSet(), hasLength(16));
    });

    test('every entry serves a latest.js script', () {
      for (final entry in kMusicSourceCatalog) {
        final urls = musicCatalogScriptUrls(entry);
        expect(urls.first.host, 'raw.githubusercontent.com');
        expect(urls.first.path, '/pdone/lx-music-source/main/${entry.id}/latest.js');
        expect(urls, hasLength(4));
        expect(urls.skip(1).map((uri) => uri.host), everyElement(isNot('raw.githubusercontent.com')));
      }
    });
  });

  group('fetchCatalogScript', () {
    test('returns the first body that answers', () async {
      final seen = <Uri>[];
      final body = await fetchCatalogScript(kMusicSourceCatalog.first, (uri) async {
        seen.add(uri);
        if (seen.length == 1) throw const FormatException('blocked');
        return '// script';
      });
      expect(body, '// script');
      expect(seen, hasLength(2));
    });

    test('skips empty bodies', () async {
      final body = await fetchCatalogScript(kMusicSourceCatalog.first, (uri) async => uri.host.contains('raw') ? ' ' : 'ok');
      expect(body, 'ok');
    });

    test('throws when every mirror fails', () async {
      await expectLater(
        fetchCatalogScript(kMusicSourceCatalog.first, (uri) async => throw StateError('down')),
        throwsA(isA<MusicCatalogFetchException>()),
      );
    });
  });
}
