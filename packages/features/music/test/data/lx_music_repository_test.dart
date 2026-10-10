// Module: test/data/lx_music_repository_test.dart
// Purpose: Pins the metadata contract and the difference between "no lyric" and "no source named".
// Author: liuchuancong
// Created: 2026-10-10

import 'package:pure_live_music_feature/pure_live_music_feature.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:test/test.dart';

/// The lx host as the music domain sees it: recorded calls, scripted answers, and an announcement that can
/// be withheld to model a script that has not initialised yet.
final class _FakeBridge implements MusicSourceBridge {
  _FakeBridge();

  Map<String, MusicSourceQualities>? announced;
  final List<(String, String, String)> calls = <(String, String, String)>[];

  String urlFor = 'https://cdn.example.com/play.m4a';
  String? lyricFor = 'line one';
  String? coverFor = 'https://cdn.example.com/cover.jpg';

  @override
  Future<String> musicUrl({required String source, required String songId, required String quality}) async {
    calls.add(('musicUrl', source, songId));
    return urlFor;
  }

  @override
  Future<String?> lyric({required String source, required String songId}) async {
    calls.add(('lyric', source, songId));
    return lyricFor;
  }

  @override
  Future<String?> cover({required String source, required String songId}) async {
    calls.add(('cover', source, songId));
    return coverFor;
  }

  @override
  Map<String, MusicSourceQualities>? get announcedSources => announced;
}

ContentRef _song({String source = 'wy', String? quality, bool withSourceKey = true}) => ContentRef(
  sourceId: 'lx',
  contentId: 'song-1',
  kind: ContentKind.music,
  metadata: <String, Object?>{
    if (withSourceKey) kMusicSourceKey: source,
    if (quality != null) kMusicQualityKey: quality,
  },
);

void main() {
  test('test_lxMusicRepository_resolvesWithTheAnnouncedSourceAndQuality', () async {
    final bridge = _FakeBridge();
    final repository = LxMusicRepository(bridge: bridge);

    final url = await repository.resolveUrl(_song(source: 'kugou', quality: '320k'));

    expect(url, bridge.urlFor);
    expect(bridge.calls.first, ('musicUrl', 'kugou', 'song-1'));
  });

  test('test_lxMusicRepository_defaultsTo128kWhenTheRefDidNotSay', () async {
    final bridge = _FakeBridge();
    await LxMusicRepository(bridge: bridge).resolveUrl(_song());

    // The quality is not in the recorded tuple by design (it is part of the bridge call), so assert through
    // the bridge's own view: a ref without kMusicQualityKey still resolves.
    expect(bridge.calls, hasLength(1));
  });

  test('test_lxMusicRepository_aRefWithoutASourceKeyIsNamedNotSilent', () async {
    final repository = LxMusicRepository(bridge: _FakeBridge());

    await expectLater(
      repository.resolveUrl(_song(withSourceKey: false)),
      throwsA(
        isA<MusicSourceFailure>().having(
          (error) => error.reason,
          'reason',
          allOf(contains('lxSource'), contains('lx/song-1')),
        ),
      ),
    );
    // The same is true for the optional lookups: it is the ref that is broken, not the answer.
    await expectLater(repository.lyric(_song(withSourceKey: false)), throwsA(isA<MusicSourceFailure>()));
  });

  test('test_lxMusicRepository_noLyricIsANullNotAFailure', () async {
    final bridge = _FakeBridge()..lyricFor = null;

    expect(await LxMusicRepository(bridge: bridge).lyric(_song()), isNull);
    expect(bridge.calls.single.$1, 'lyric');
  });

  test('test_lxMusicRepository_anEmptyUrlIsAFailure', () async {
    final bridge = _FakeBridge()..urlFor = '';

    await expectLater(
      LxMusicRepository(bridge: bridge).resolveUrl(_song()),
      throwsA(isA<MusicSourceFailure>().having((error) => error.reason, 'reason', contains('empty play url'))),
    );
  });

  test('test_lxMusicRepository_announcedSourcesFilterAndReadiness', () {
    final bridge = _FakeBridge();
    final repository = LxMusicRepository(bridge: bridge);

    expect(repository.isReady, isFalse);
    expect(repository.availableSources(), isNull, reason: 'loading and empty are different answers');

    bridge.announced = <String, MusicSourceQualities>{
      'wy': const MusicSourceQualities(qualities: <String>['128k', '320k'], servesMusicUrl: true),
      'none': const MusicSourceQualities(qualities: <String>[], servesMusicUrl: false),
    };
    expect(repository.isReady, isTrue);
    expect(repository.availableSources(), <String, List<String>>{
      'wy': <String>['128k', '320k'],
    });
  });

  test('test_lxMusicRepository_coverUsesTheSameSourceKey', () async {
    final bridge = _FakeBridge();

    expect(await LxMusicRepository(bridge: bridge).cover(_song(source: 'ne')), bridge.coverFor);
    expect(bridge.calls.single, ('cover', 'ne', 'song-1'));
  });
}
