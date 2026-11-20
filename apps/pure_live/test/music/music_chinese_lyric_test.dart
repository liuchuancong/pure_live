import 'dart:convert' show base64, base64Encode, jsonEncode, utf8;
import 'dart:io' show ZLibEncoder;
import 'dart:typed_data' show Uint8List;

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/modules/music/controller/sources/chinese_s2t.dart'
    show kChineseSimplifiedTraditional, traditionalize;
import 'package:pure_live/modules/music/controller/sources/lyric_decoders.dart'
    show decodeKrc, decodeQrc, parseQrc, parseYrc;

/// The music sources' pure layer: the simplified-to-traditional rewrite
/// that passes the untold characters through, the KRC lyric decode's full
/// round trip (the XOR-and-inflate payload, the head and the language
/// block, the millisecond stamps, the word tags), and the QRC decode's
/// refusals — its encrypt side lives on the server, so only what it
/// refuses is pinned here.
void main() {
  group('the simplified-to-traditional rewrite', () {
    test('the table pairs map, and everything else passes through', () {
      // The pairs the shipped table names.
      expect(traditionalize('万与东乐书为义云'), '萬與東樂書為義雲');
      // The untold: characters without a distinct form, latin, digits and
      // punctuation are untouched. (爱 is in the table — the lyric round
      // trip below uses it.)
      expect(traditionalize('我 music 123！'), '我 music 123！');
      expect(traditionalize(''), '');

      // The rewrite reads the same table that ships.
      for (final entry in kChineseSimplifiedTraditional.entries.take(50)) {
        expect(traditionalize(entry.key), entry.value);
      }
      // The traditional side is not keys of its own: rewriting twice stands.
      expect(traditionalize(traditionalize('万乐书')), traditionalize('万乐书'));
    });
  });

  group('the KRC decode', () {
    /// The payload a Kugou server sends: a four-byte header, then the zlib
    /// of the text XORed with the sixteen-byte key, base64-wrapped.
    String krcPayload(String text) {
      const key = [0x40, 0x47, 0x61, 0x77, 0x5e, 0x32, 0x74, 0x47, 0x51, 0x36, 0x31, 0x2d, 0xce, 0xd2, 0x6e, 0x69];
      final zlib = Uint8List.fromList(ZLibEncoder().convert(utf8.encode(text)));
      final out = Uint8List(4 + zlib.length)..setRange(0, 4, utf8.encode('krc1')); // the header the player skips
      for (var i = 0; i < zlib.length; i++) {
        out[4 + i] = zlib[i] ^ key[i % 16];
      }
      return base64.encode(out);
    }

    /// The language block's base64, as the payload carries it.
    String languageBlock(Map<String, Object?> json) => base64Encode(utf8.encode(jsonEncode(json)));

    test('the round trip stamps the lines, keeps the word tags and rides the languages', () {
      final text =
          '[id:\$12345]\r\n'
          '[language:${languageBlock({
            'content': [
              {
                'type': 1,
                'lyricContent': [
                  ['中译一'],
                  ['中译二'],
                ],
              },
              {
                'type': 0,
                'lyricContent': [
                  ['Roman one'],
                  ['Roman two'],
                ],
              },
            ],
          })}]\n'
          '[0,3000]我<1000,500,0>爱<500,500,0>你\n'
          '[3000,2000]第二行\n';
      final decoded = decodeKrc(krcPayload(text));

      expect(decoded, isNotNull);
      // The head and the language block are gone, the \r is gone, the
      // millisecond tags are the lyric's own stamps, and the word tags
      // dropped their third field.
      expect(decoded!.lyric, '[00:00.000]我<1000,500>爱<500,500>你\n[00:03.000]第二行\n');
      expect(decoded.translation, '[00:00.000]中译一\n[00:03.000]中译二');
      expect(decoded.romanization, '[00:00.000]Roman one\n[00:03.000]Roman two');
    });

    test('a payload without the language block answers the bare text', () {
      final decoded = decodeKrc(krcPayload('[id:\$1]\n[1500,1000]只有一行\n'));
      expect(decoded!.lyric, '[00:01.500]只有一行\n');
      expect(decoded.translation, isNull);
      expect(decoded.romanization, isNull);
    });

    test('an empty payload answers null, and a broken one throws', () {
      expect(decodeKrc(''), isNull);
      // Valid base64 of garbage: the inflate is the failure.
      expect(() => decodeKrc(base64Encode(utf8.encode('not a zlib stream'))), throwsA(isA<Object>()));
    });
  });

  group('the QRC decode', () {
    test('what it cannot read answers null, never a throw', () {
      expect(decodeQrc(null), isNull);
      expect(decodeQrc(''), isNull);
      expect(decodeQrc('abc'), isNull); // an odd number of hex digits
      expect(decodeQrc('zz'), isNull); // not hex at all
      // Hex that decrypts to something no zlib stream accepts.
      expect(decodeQrc('00112233445566778899001122334455'), isNull);
    });

    test('the decoded lines keep the bracketed stamp the lrc reader matches', () {
      // The payloads arrive decrypted: the line is `[start,dur](start,dur)word`.
      final decoded = parseQrc('[1000,2000](0,500)词(500,1500)标签', null, null);
      expect(decoded, isNotNull);
      // The line opens with a bracketed stamp — the player's lrc reader only
      // matches `[mm:ss.mmm]`, and the word tags ride in the lx form.
      expect(decoded!.lyric.startsWith('[00:01.000]'), isTrue, reason: decoded.lyric);
      expect(decoded.lyric, contains('<0,500>词'));
      expect(decoded.lyric, isNot(contains('(0,500)')));
    });
  });

  group('the YRC decode', () {
    test('the decoded lines carry the stamp and the lx word tags', () {
      // Netease's word tag is a three-part `(start,dur,0)`.
      final decoded = parseYrc('[1000,2000](0,500,0)一(500,1500,0)句', '[00:01.000]一句译文', null);
      expect(decoded, isNotNull);
      expect(decoded!.lyric.startsWith('[00:01.000]'), isTrue, reason: decoded.lyric);
      expect(decoded.lyric, contains('<0,500>一'));
      expect(decoded.lyric, isNot(contains('(0,500,0)')));
      expect(decoded.translation, '[00:01.000]一句译文');
    });

    test('a payload without a readable line answers null', () {
      expect(parseYrc(null, null, null), isNull);
      expect(parseYrc('   ', null, null), isNull);
      expect(parseYrc('no stamps here', null, null), isNull);
    });
  });
}
