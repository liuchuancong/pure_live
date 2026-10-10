// Module: test/plugin_bundle_parser_test.dart
// Purpose: Pins "the manifest opens the file", the forward-only comment scan, and one refusal type.
// Author: liuchuancong
// Created: 2026-10-11
//
// The store had tests; the parser, which is the thing standing between an imported file and the sandbox, had
// none - and the defect this round fixed (the header search starting at index 0) was invisible without them.

import 'package:pure_live_plugin_host/pure_live_plugin_host.dart';
import 'package:test/test.dart';

const String _manifest = '''{"id":"com.demo.live","name":"Demo","version":"1.0.0","apiVersion":1,
  "runtime":"js","capabilities":["live"],"permissions":["network"]}''';

String _file({String before = '', String code = 'function home(){ return []; }'}) =>
    '$before/* $pluginManifestMarker\n$_manifest\n*/\n$code';

void main() {
  const parser = PluginBundleParser();

  group('test_pluginBundleParser', () {
    test('test_parse_readsTheManifestAndKeepsTheScript', () {
      final bundle = parser.parse(_file());

      expect(bundle.manifest.id, 'com.demo.live');
      expect(bundle.manifest.capabilityNames, <String>{'live'});
      expect(bundle.source, 'function home(){ return []; }');
    });

    test('test_parse_aCommentBeforeTheHeaderIsRefusedBecauseAPreambleIsAmbiguous', () {
      // The rule is "the manifest opens the file", and it has to be that strict: a preamble is only
      // recognisable as a preamble by parsing comments, and a script body that starts with `//` or `/*` is
      // then indistinguishable from one that merely *mentions* the marker - which is the hole that let a file
      // with no real header install anyway. Whitespace and a byte-order mark are the only permitted lead-in.
      expect(
        () => parser.parse(_file(before: '/* Copyright 2026 nobody */\n')),
        throwsA(isA<PluginBundleException>().having((e) => e.message, 'message', contains('must open with one'))),
      );
      expect(parser.parse('\uFEFF${_file()}').manifest.id, 'com.demo.live', reason: 'a BOM is not content');
      expect(parser.parse('  \t\n${_file()}').manifest.id, 'com.demo.live');
    });

    test('test_parse_aMarkerInsideTheScriptBodyIsNotAManifest', () {
      final sneaky = 'const note = "$pluginManifestMarker";\n/* $pluginManifestMarker\n$_manifest\n*/\nfunction h(){}';

      expect(() => parser.parse(sneaky), throwsA(isA<PluginBundleException>()));
    });

    test('test_parse_noHeaderAtAllIsRefused', () {
      expect(
        () => parser.parse('function home(){ return []; }'),
        throwsA(isA<PluginBundleException>().having((e) => e.message, 'message', contains('must open with one'))),
      );
    });

    test('test_parse_aHeaderWithNoJsonObjectIsRefused', () {
      expect(
        () => parser.parse('/* $pluginManifestMarker nothing here */\ncode()'),
        throwsA(isA<PluginBundleException>().having((e) => e.message, 'message', contains('no JSON object'))),
      );
    });

    test('test_parse_anUnclosedHeaderIsRefusedAsUnclosed', () {
      expect(
        () => parser.parse('/* $pluginManifestMarker\n$_manifest\ncode()'),
        throwsA(
          isA<PluginBundleException>().having(
            (e) => e.message,
            'message',
            contains('manifest header comment is not closed'),
          ),
        ),
      );
    });

    test('test_parse_invalidJsonIsAParseRefusalNotAFormatException', () {
      expect(
        () => parser.parse('/* $pluginManifestMarker\n{"id": }\n*/\ncode()'),
        throwsA(isA<PluginBundleException>().having((e) => e.message, 'message', contains('not valid JSON'))),
      );
    });

    test('test_parse_aManifestOfTheWrongShapeIsAParseRefusal', () {
      // No `id`: requireString throws inside the model, and the caller should still see one exception type.
      expect(
        () => parser.parse('/* $pluginManifestMarker\n{"name":"x"}\n*/\ncode()'),
        throwsA(isA<PluginBundleException>()),
      );
    });

    test('test_parse_aHeaderWithNoScriptAfterItIsRefused', () {
      expect(
        () => parser.parse('/* $pluginManifestMarker\n$_manifest\n*/\n   \n'),
        throwsA(isA<PluginBundleException>().having((e) => e.message, 'message', contains('declares no script'))),
      );
    });

    test('test_parse_aFileThatIsOnlyAHeaderIsRefused', () {
      expect(() => parser.parse('/* $pluginManifestMarker\n$_manifest\n*/'), throwsA(isA<PluginBundleException>()));
    });

    test('test_parse_nestedObjectsInTheManifestDoNotTruncateIt', () {
      final nested =
          '/* $pluginManifestMarker\n{"id":"com.demo.live","name":"Demo","version":"1",'
          '"apiVersion":1,"runtime":"js","metadata":{"author":"me","extra":{"k":1}}}\n*/\ncode()';

      final bundle = parser.parse(nested);
      expect(bundle.manifest.id, 'com.demo.live');
      expect(bundle.manifest.metadata.author, 'me');
      expect(bundle.manifest.metadata.extra['k'], 1);
    });

    test('test_renderToFileRoundTripsThroughTheParser', () {
      final bundle = parser.parse(_file());

      final reparsed = parser.parse(bundle.renderToFile());
      expect(reparsed.manifest.toJson(), bundle.manifest.toJson());
      expect(reparsed.source, bundle.source);
    });

    test('test_parse_anOversizedFileIsRefusedBeforeTheSubstrings', () {
      final huge =
          '/* $pluginManifestMarker\n{"id":"x","name":"y","version":"1","apiVersion":1,'
          '"runtime":"js","pad":"${'a' * (PluginBundleParser.kMaxBundleCharacters + 1)}"}\n*/\ncode()';

      expect(
        () => parser.parse(huge),
        throwsA(isA<PluginBundleException>().having((e) => e.message, 'message', contains('character ceiling'))),
      );
    });
  });
}
