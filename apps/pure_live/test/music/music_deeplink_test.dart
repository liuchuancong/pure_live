import 'dart:convert' show jsonEncode;

import 'package:flutter_test/flutter_test.dart';
import 'package:media_core_audio/media_core_audio.dart' as audio;
import 'package:pure_live/modules/music/controller/music_deeplink.dart';

void main() {
  group('parseMusicDeeplink', () {
    test('search by path keyword', () {
      final action = parseMusicDeeplink('lxmusic://music/search/周杰伦/稻香') as MusicDeeplinkSearch;
      expect(action.keywords, '稻香');
    });

    test('search by keywords param and 128-character cap', () {
      final action = parseMusicDeeplink('lxmusic://music/search?keywords=${Uri.encodeComponent('稻香')}')
          as MusicDeeplinkSearch;
      expect(action.keywords, '稻香');

      final long = 'a' * 200;
      final capped = parseMusicDeeplink('lxmusic://music/search?keywords=$long') as MusicDeeplinkSearch;
      expect(capped.keywords.length, 128);
    });

    test('search without a keyword is rejected', () {
      expect(() => parseMusicDeeplink('lxmusic://music/search'), throwsA(isA<MusicDeeplinkException>()));
    });

    test('play builds a kw track from data', () {
      final data = jsonEncode({
        'source': 'kw',
        'songmid': 'abc123',
        'name': '稻香',
        'singer': '周杰伦',
        'albumName': '魔杰座',
        'albumId': '139009',
        'img': 'https://img.example/cover.jpg',
        'interval': '03:42',
        'types': [
          {'type': '128k'},
          {'type': 'flac'},
        ],
      });
      final action = parseMusicDeeplink('lxmusic://music/play?data=${Uri.encodeComponent(data)}')
          as MusicDeeplinkPlay;
      final track = action.track;
      expect(track.id, 'abc123');
      expect(track.sourceId, 'kw');
      expect(track.title, '稻香');
      expect(track.artist, '周杰伦');
      expect(track.album, '魔杰座');
      expect(track.albumId, '139009');
      expect(track.coverUri, Uri.parse('https://img.example/cover.jpg'));
      expect(track.duration, const Duration(minutes: 3));
      expect(track.qualities, [audio.MusicQuality.k128, audio.MusicQuality.flac]);
    });

    test('play keeps tx strMediaMid in metadata', () {
      final data = jsonEncode({
        'source': 'tx',
        'songmid': '0039MnYb0qxYhV',
        'strMediaMid': '0039MnYb0qxYhV_mid',
        'name': '晴天',
      });
      final action = parseMusicDeeplink('lxmusic://music/play?data=${Uri.encodeComponent(data)}')
          as MusicDeeplinkPlay;
      expect(action.track.metadata['strMediaMid'], '0039MnYb0qxYhV_mid');
    });

    test('play rejects unknown source and missing id', () {
      final unknown = jsonEncode({'source': 'xx', 'songmid': '1', 'name': 'x'});
      expect(
        () => parseMusicDeeplink('lxmusic://music/play?data=${Uri.encodeComponent(unknown)}'),
        throwsA(isA<MusicDeeplinkException>()),
      );
      final noId = jsonEncode({'source': 'kw', 'name': 'x'});
      expect(
        () => parseMusicDeeplink('lxmusic://music/play?data=${Uri.encodeComponent(noId)}'),
        throwsA(isA<MusicDeeplinkException>()),
      );
    });

    test('play without data or with broken JSON is rejected', () {
      expect(() => parseMusicDeeplink('lxmusic://music/play'), throwsA(isA<MusicDeeplinkException>()));
      expect(
        () => parseMusicDeeplink('lxmusic://music/play?data=%7Bbroken'),
        throwsA(isA<MusicDeeplinkException>()),
      );
    });

    test('searchPlay splits name - singer from the path', () {
      final action = parseMusicDeeplink('lxmusic://music/searchPlay/${Uri.encodeComponent('稻香 - 周杰伦')}')
          as MusicDeeplinkSearchPlay;
      expect(action.name, '稻香');
      expect(action.singer, '周杰伦');
      expect(action.playLater, isFalse);
    });

    test('searchPlay reads playLater from data', () {
      final data = jsonEncode({'name': '稻香', 'singer': '周杰伦', 'playLater': true});
      final action = parseMusicDeeplink(
        'lxmusic://music/searchPlay?data=${Uri.encodeComponent(data)}',
      ) as MusicDeeplinkSearchPlay;
      expect(action.name, '稻香');
      expect(action.singer, '周杰伦');
      expect(action.playLater, isTrue);
    });

    test('songlist open/play from data, url standing in for id', () {
      final data = jsonEncode({'source': 'kg', 'id': '123'});
      final open = parseMusicDeeplink('lxmusic://songlist/open?data=${Uri.encodeComponent(data)}')
          as MusicDeeplinkOpenSonglist;
      expect(open.sourceId, 'kg');
      expect(open.id, '123');

      final playData = jsonEncode({'source': 'kg', 'url': 'https://h5.kg.com/456', 'index': 2});
      final play = parseMusicDeeplink('lxmusic://songlist/play?data=${Uri.encodeComponent(playData)}')
          as MusicDeeplinkPlaySonglist;
      expect(play.id, 'https://h5.kg.com/456');
      expect(play.index, 2);
    });

    test('songlist from bare paths', () {
      final play = parseMusicDeeplink('lxmusic://songlist/play/kg/123/1') as MusicDeeplinkPlaySonglist;
      expect(play.sourceId, 'kg');
      expect(play.id, '123');
      expect(play.index, 1);
    });

    test('songlist without an id is rejected', () {
      expect(() => parseMusicDeeplink('lxmusic://songlist/open'), throwsA(isA<MusicDeeplinkException>()));
      expect(
        () => parseMusicDeeplink('lxmusic://songlist/open?data=${Uri.encodeComponent(jsonEncode({'source': 'kg'}))}'),
        throwsA(isA<MusicDeeplinkException>()),
      );
    });

    test('every player command parses', () {
      for (final command in MusicDeeplinkPlayerCommand.values) {
        final action = parseMusicDeeplink('lxmusic://player/${command.name}') as MusicDeeplinkPlayer;
        expect(action.command, command);
      }
    });

    test('unknown type, action and player action are rejected', () {
      expect(() => parseMusicDeeplink('lxmusic://other/play'), throwsA(isA<MusicDeeplinkException>()));
      expect(() => parseMusicDeeplink('lxmusic://music/bogus'), throwsA(isA<MusicDeeplinkException>()));
      expect(() => parseMusicDeeplink('lxmusic://player/bogus'), throwsA(isA<MusicDeeplinkException>()));
      expect(() => parseMusicDeeplink('https://example.com'), throwsA(isA<MusicDeeplinkException>()));
    });
  });
}
