import 'dart:convert' show base64Decode, jsonEncode, utf8;
import 'dart:typed_data' show Uint8List;

import 'package:crypto/crypto.dart' show md5;
import 'package:flutter_test/flutter_test.dart';
import 'package:media_core_audio/media_core_audio.dart' as audio;
import 'package:pointycastle/export.dart' show KeyParameter, PaddedBlockCipher, PaddedBlockCipherParameters;
import 'package:pure_live/modules/music/controller/sources/music_source_match.dart';
import 'package:pure_live/modules/music/controller/sources/wy_crypto.dart';

/// The cross-source matching ladder and the Netease request crypto: the
/// name normalizer that strips the decorations two sites never spell alike,
/// the strict concession ladder 换源 walks, the lenient reading the lyric
/// walk takes (the singers as a set, a 重制版's drift tolerated), and the
/// weapi/eapi forms — eapi decrypted back by an independent path, weapi
/// checked by its shape since its second key rides RSA.
void main() {
  audio.MusicTrack track(String sourceId, String title, {String artist = '', String album = '', Duration? duration}) =>
      audio.MusicTrack(
        id: '$sourceId|$title|$artist',
        sourceId: sourceId,
        title: title,
        artist: artist,
        album: album,
        duration: duration,
      );

  group('the name normalizer', () {
    test('the decorations two sites never spell alike are dropped', () {
      expect(normalizeSongName('晴天 (Live)'), '晴天');
      expect(normalizeSongName('晴天（Live）'), '晴天');
      expect(normalizeSongName('晴天 live'), '晴天');
      expect(normalizeSongName('晴天(Remix)'), '晴天'); // the bracketed suffix
      expect(normalizeSongName('晴天-Remix'), '晴天remix'); // the hyphen form lowercases only
      expect(normalizeSongName('晴天（feat. 周杰伦）'), '晴天'); // bracketed extras go whole
      expect(normalizeSongName('A、B — duet'), 'abduet'); // separators and spaces
      expect(normalizeSongName('  晴&nbsp;天  '), '晴天');
      expect(normalizeSongName('晴天'), '晴天');
      expect(normalizeSongName('   '), '');
    });
  });

  group('the strict same-song rule', () {
    const duration = Duration(seconds: 269);

    test('name, singer and album agree, and the duration sits within five seconds', () {
      final target = track('wy', '晴天', artist: '周杰伦', album: '叶惠美', duration: duration);
      expect(isSameSong(target, track('kw', '晴天 (Live)', artist: '周杰伦', album: '叶惠美', duration: duration)), isTrue);
      expect(isSameSong(target, track('kw', '晴天', artist: '另一个歌手', album: '叶惠美', duration: duration)), isFalse);
      // The album is only compared when both sides carry one.
      expect(isSameSong(target, track('kw', '晴天', artist: '周杰伦', duration: duration)), isTrue);
      // Five seconds is the gate.
      expect(
        isSameSong(
          target,
          track('kw', '晴天', artist: '周杰伦', album: '叶惠美', duration: duration + const Duration(seconds: 4)),
        ),
        isTrue,
      );
      expect(
        isSameSong(
          target,
          track('kw', '晴天', artist: '周杰伦', album: '叶惠美', duration: duration + const Duration(seconds: 6)),
        ),
        isFalse,
      );
      // A missing duration has nothing to contradict.
      expect(isSameSong(target, track('kw', '晴天', artist: '周杰伦', album: '叶惠美')), isTrue);
    });
  });

  group('the strict ladder 换源 walks', () {
    final target = track('wy', '晴天', artist: '周杰伦', album: '叶惠美', duration: const Duration(seconds: 269));

    test('the strictest pass wins, then one concession at a time', () {
      // The strict reading: everything agrees.
      final strict = track('kw', '晴天', artist: '周杰伦', album: '叶惠美', duration: const Duration(seconds: 269));
      expect(findSameSong(target, [strict])?.id, strict.id);

      // One concession: the album went missing on the other site.
      final noAlbum = track('tx', '晴天', artist: '周杰伦', duration: const Duration(seconds: 269));
      expect(findSameSong(target, [noAlbum])?.id, noAlbum.id);

      // The singer written differently — the reading that still finds the
      // song, name and duration held.
      final oddSinger = track('kg', '晴天', artist: 'Jay Chou', duration: const Duration(seconds: 269));
      expect(findSameSong(target, [oddSinger])?.id, oddSinger.id);

      // The duration contradicts: no pass may take it.
      final drifted = track('kg', '晴天', artist: '周杰伦', album: '叶惠美', duration: const Duration(seconds: 299));
      expect(findSameSong(target, [drifted]), isNull);
    });

    test("the track's own source never matches itself, and the ranked first wins", () {
      final same = track('wy2', '晴天', artist: '周杰伦', album: '叶惠美', duration: const Duration(seconds: 269));
      final self = track('wy', '晴天', artist: '周杰伦', album: '叶惠美', duration: const Duration(seconds: 269));
      expect(findSameSong(target, [self, same])?.id, same.id); // the self row skipped
      expect(findSameSong(target, [self]), isNull); // nothing left to take

      final first = track('kg', '晴天', artist: '周杰伦', album: '叶惠美', duration: const Duration(seconds: 269));
      final second = track('kw', '晴天', artist: '周杰伦', album: '叶惠美', duration: const Duration(seconds: 269));
      expect(findSameSong(target, [first, second])?.id, first.id); // the search's own order wins
    });
  });

  group('the lenient reading the lyric walk takes', () {
    final target = track('wy', '晴天', artist: '周杰伦、阿信', duration: const Duration(seconds: 269));

    test("the singers are a set, and a 重制版's drift still counts", () {
      final reordered = track('kw', '晴天', artist: '阿信、周杰伦', duration: const Duration(seconds: 280));
      expect(findSameSongLenient(target, [reordered])?.id, reordered.id); // eleven seconds in

      final feat = track('tx', '晴天', artist: '周杰伦 feat. 阿信', duration: const Duration(seconds: 269));
      expect(findSameSongLenient(target, [feat])?.id, feat.id); // a feat. is a credit, not a new song

      // Thirteen seconds is a different recording, even for a lyric.
      final drifted = track('kg', '晴天', artist: '周杰伦', duration: const Duration(seconds: 282));
      expect(findSameSongLenient(target, [drifted]), isNull);

      // The name is still the hard gate here too.
      final otherSong = track('kg', '彩虹', artist: '周杰伦', duration: const Duration(seconds: 269));
      expect(findSameSongLenient(target, [otherSong]), isNull);
    });
  });

  group('the Netease request crypto', () {
    test('eapi decrypts back to the string it built, digest included', () {
      const url = 'https://interface.music.163.com/api/song/detail';
      const object = {'id': 42, 'limit': 1};
      final form = eapi(url, object);

      // The form is one uppercase hex string under 'params'.
      final params = form['params']!;
      expect(params, matches(RegExp(r'^[0-9A-F]+$')));
      final encrypted = [for (var i = 0; i < params.length; i += 2) int.parse(params.substring(i, i + 2), radix: 16)];

      // The independent read: the same fixed key decrypts.
      final cipher = PaddedBlockCipher('AES/ECB/PKCS7')
        ..init(false, PaddedBlockCipherParameters(KeyParameter(utf8.encode('e82ckenh8dichen8')), null));
      final plain = utf8.decode(cipher.process(Uint8List.fromList(encrypted)));

      final text = jsonEncode(object);
      final digest = md5.convert(utf8.encode('nobody${url}use${text}md5forencrypt')).toString();
      expect(plain, '$url-36cd479b6b5-$text-36cd479b6b5-$digest');
    });

    test('weapi carries the payload twice, and the secret never repeats', () {
      final object = {'id': 42};
      final (form, text) = weapi(object);

      expect(text, jsonEncode(object)); // the caller logs what it asked
      final encSecKey = form['encSecKey']!;
      expect(encSecKey, matches(RegExp(r'^[0-9a-f]{256}$'))); // the RSA block, 128 bytes
      final params = base64Decode(form['params']!);
      expect(params.length % 16, 0); // two AES-CBC rounds stay in blocks

      // The second round's key is fresh per call.
      final (form2, _) = weapi(object);
      expect(form2['params'], isNot(form['params']));
      expect(form2['encSecKey'], isNot(encSecKey));
    });
  });
}
