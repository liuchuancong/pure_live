import 'package:flutter_test/flutter_test.dart';
import 'package:media_core_audio/media_core_audio.dart' as audio;
import 'package:pure_live/modules/music/controller/sources/lx_script_runtime.dart';

/// The lx script protocol's pure half: what a script may advertise kept down
/// to what the host routes (a source of its own invention, an action or a
/// tier beyond the protocol's list is advertising, not ability), and the
/// musicInfo payload a URL ask carries, built from the track's row and
/// metadata with nothing invented.
void main() {
  group('the source capabilities', () {
    test('a source the protocol does not route is nothing at all', () {
      expect(lxScriptSourceCaps('xm', ['musicUrl'], ['128k']), isNull);
      expect(lxScriptSourceCaps('local2', ['musicUrl'], ['128k']), isNull);
    });

    test('a platform keeps only the actions and tiers the protocol names, in its own order', () {
      final caps = lxScriptSourceCaps('kw', ['getMusicUrl', 'musicUrl', 'lyric'], ['320k', '999k', '128k', 'flac']);
      expect(caps, isNotNull);
      expect(caps!.id, 'kw');
      expect(caps.actions, ['musicUrl']); // lyric is the local source's, the rest is not lx's
      expect(caps.qualitys, ['320k', '128k', 'flac']); // the declared order, the protocol's set
      expect(caps.canResolve, isTrue);
    });

    test('the local source rides its own actions and no tiers', () {
      final caps = lxScriptSourceCaps('local', ['musicUrl', 'lyric', 'pic', 'fs'], ['128k', 'flac']);
      expect(caps, isNotNull);
      expect(caps!.actions, ['musicUrl', 'lyric', 'pic']);
      expect(caps.qualitys, isEmpty); // files play, tiers are not theirs to name
      expect(caps.canResolve, isTrue);
    });

    test('a script without the url action cannot resolve, whatever else it keeps', () {
      final caps = lxScriptSourceCaps('wy', ['lyric'], ['128k']);
      expect(caps, isNotNull);
      expect(caps!.actions, isEmpty); // lyric is not the online platforms' to declare
      expect(caps.canResolve, isFalse);
    });
  });

  group('the musicInfo payload', () {
    test('a row builds the ask: both ids, the credits and the tier list', () {
      const track = audio.MusicTrack(
        id: '977',
        sourceId: 'kw',
        title: '晴天',
        artist: '周杰伦',
        album: '叶惠美',
        albumId: '9001',
        duration: Duration(seconds: 269),
        metadata: {
          'hash': 'h128',
          'hashes': {'128k': 'h128', '320k': 'h320'},
          'mediaMid': 'mm1',
          'songId': '977',
          'artistId': '31', // not one of the four keys the ask names
        },
      );

      final info = lxMusicInfo(track, qualitys: const ['128k', '320k']);
      expect(info['songmid'], '977');
      expect(info['songId'], '977');
      expect(info['name'], '晴天');
      expect(info['singer'], '周杰伦');
      expect(info['albumName'], '叶惠美');
      expect(info['source'], 'kw');
      expect(info['albumId'], '9001');
      expect(info['hash'], 'h128');
      expect(info['hashes'], {'128k': 'h128', '320k': 'h320'});
      expect(info['mediaMid'], 'mm1');
      expect(info.containsKey('artistId'), isFalse); // the ask carries no key it did not name
      expect(info['interval'], 269);
      expect(info['types'], [
        {'type': '128k', 'hash': 'h128'},
        {'type': '320k', 'hash': 'h320'},
      ]);
    });

    test('an empty row invents nothing: no hash, no album, no interval, bare tiers', () {
      const track = audio.MusicTrack(id: '1', sourceId: 'tx', title: '夜曲', artist: '周杰伦');
      final info = lxMusicInfo(track, qualitys: const ['128k']);
      expect(info.containsKey('albumId'), isFalse);
      expect(info.containsKey('hash'), isFalse);
      expect(info.containsKey('hashes'), isFalse);
      expect(info.containsKey('interval'), isFalse);
      expect(info['types'], [
        {'type': '128k'}, // no hash to carry
      ]);
    });
  });
}
