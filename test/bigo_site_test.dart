import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/site/bigo/bigo_api.dart';
import 'package:pure_live/core/site/bigo/bigo_input_recipe.dart';
import 'package:pure_live/core/site/bigo/bigo_link.dart';
import 'package:pure_live/core/site/bigo/bigo_site.dart';
import 'package:pure_live/core/sites.dart';
import 'package:pure_live/player/core/live_input_playback_binding.dart';
import 'package:pure_live/recorder/services/live_input_recording_binding.dart';

void main() {
  test('official room links retain the public Bigo identity', () {
    expect(BigoLink.parse('https://www.bigo.tv/fixture_101'), 'fixture_101');
    expect(BigoLink.parse('https://www.bigo.tv/cn/fixture_101'), 'fixture_101');
    expect(BigoLink.parseOrSiteId('fixture_101'), 'fixture_101');
    expect(BigoLink.url('fixture_101'), 'https://www.bigo.tv/fixture_101');
    for (final invalid in [
      'https://www.bigo.tv/',
      'https://www.bigo.tv/search',
      'https://www.bigo.tv/search/fixture_101/more',
      'https://www.bigo.tv.evil.test/fixture_101',
      'https://www.bigo.tv:444/fixture_101',
    ]) {
      expect(BigoLink.parse(invalid), isNull);
    }
  });

  test('finite directory, exact search and owned live quality keep metrics separate', () async {
    final api = _BigoFixtureApi();
    final site = BigoSite(api: api);
    final page = await site.getDirectoryPage();
    expect(page.rooms, hasLength(1));
    expect(page.hasMore, isFalse);
    expect(page.rooms.single.roomId, 'fixture_101');
    expect(page.rooms.single.onlineViewers, '127');
    expect(page.rooms.single.totalViewers, isNull);
    expect(page.rooms.single.isLiveNow, isTrue);

    final searched = await site.searchRooms('https://www.bigo.tv/fixture_101');
    expect(searched.single.roomId, 'fixture_101');
    expect(searched.single.effectiveLiveStatus, LiveStatus.live);
    expect(await site.searchRooms('nickname words'), isEmpty);

    final detail = await site.getRoomDetail(roomId: 'fixture_101', platform: 'bigo');
    expect(detail.title, 'Fixture live');
    expect(detail.nick, 'Fixture owner');
    expect(detail.onlineViewers, isNull, reason: 'room detail has no verified concurrent field');
    final qualities = await site.getPlayQualites(detail: detail);
    expect(qualities.single.selectionId, 'live');
    final resolution = await site.resolvePlayUrlsRaw(detail: detail, quality: qualities.single);
    expect(resolution.urls, isEmpty);
    expect(resolution.inputRecipe, isA<BigoInputRecipe>());
    expect((resolution.inputRecipe as BigoInputRecipe).siteId, 'fixture_101');
    expect(await site.getPlayUrls(detail: detail, quality: qualities.single), isEmpty);
    expect(await site.getLiveStatus(platform: 'bigo', roomId: 'fixture_101'), isTrue);
  });

  test('keyword search filters the finite public snapshot while exact identity stays separate', () async {
    final api = _BigoFixtureApi();
    final site = BigoSite(api: api);
    final byName = (await site.searchRooms('Fixture')).single;
    expect(byName.roomId, 'fixture_101');
    expect(byName.onlineViewers, '127');
    expect(byName.data, isNull);
    expect((await site.searchRooms('live')).single.roomId, 'fixture_101');
    expect(await site.searchRooms('Fixture', page: 2), isEmpty);
    expect(await site.searchRooms('https://www.bigo.tv/search/music?tab=host'), isEmpty);
    expect((await site.searchRooms('fixture_101')).single.roomId, 'fixture_101');
    expect(api.directoryCalls, 1);
    expect(api.studioCalls, 1);
  });

  test('keyword search stops at cancellation after a directory response', () async {
    final token = CancelToken();
    final site = BigoSite(api: _BigoFixtureApi(cancelDuringDirectory: true));
    await expectLater(site.searchRoomsCancellable('Fixture', cancel: token), _failure(BigoFailure.cancelled));
    expect(token.isCancelled, isTrue);
  });

  test('gated detail remains unknown and never creates an owned media recipe', () async {
    final site = BigoSite(api: _BigoFixtureApi(access: BigoAccess.loginRequired));
    final detail = await site.getRoomDetail(roomId: 'fixture_101', platform: 'bigo');
    expect(detail.effectiveLiveStatus, LiveStatus.unknown);
    expect(detail.data, isNull);
    await expectLater(site.getLiveStatus(platform: 'bigo', roomId: 'fixture_101'), _failure(BigoFailure.unknownState));
    await expectLater(site.getPlayQualites(detail: detail), _failure(BigoFailure.mediaUnavailable));
  });

  test('registry exposes Bigo and both owned-input binders accept its recipe', () {
    expect(Sites.supportedSiteIds, contains(Sites.bigoSite));
    expect(Sites.of(Sites.bigoSite).liveSite, isA<BigoSite>());
    expect(Sites.supportSites.where((site) => site.id == Sites.bigoSite), hasLength(1));
    final recipe = BigoInputRecipe('fixture_101');
    expect(bindLiveInputForPlayback(recipe).identity, recipe.identity);
    expect(bindLiveInputForRecording(recipe).identity, recipe.identity);
  });
}

Matcher _failure(BigoFailure kind) => throwsA(isA<BigoException>().having((error) => error.kind, 'kind', kind));

final class _BigoFixtureApi extends BigoApi {
  _BigoFixtureApi({this.access = BigoAccess.public, this.cancelDuringDirectory = false})
    : super(request: (_, _, _, _) async => throw StateError('unused'));

  final BigoAccess access;
  final bool cancelDuringDirectory;
  int directoryCalls = 0;
  int studioCalls = 0;

  @override
  Future<List<BigoDirectoryCard>> directory({CancelToken? cancel}) async {
    directoryCalls++;
    if (cancelDuringDirectory) cancel?.cancel();
    return const [
      BigoDirectoryCard(
        siteId: 'fixture_101',
        ownerId: 101,
        broadcastId: '7000000000000000001',
        sid: 202,
        title: 'Fixture live',
        nickname: 'Fixture owner',
        cover: 'https://image.example/cover.jpg',
        reportedViewers: 127,
        locked: false,
        roomFlag: 1,
      ),
    ];
  }

  @override
  Future<BigoStudioRoom> studioRoom({required String siteId, int? expectedOwnerId, CancelToken? cancel}) async {
    studioCalls++;
    final public = access == BigoAccess.public;
    return BigoStudioRoom(
      status: BigoStudioStatus(
        requestedSiteId: siteId,
        ownerId: 101,
        canonicalSiteId: 'fixture_101',
        access: access,
        reportedAlive: public ? true : null,
        roomStatus: 0,
        roomType: '0',
      ),
      roomId: public ? '7000000000000000001' : null,
      nickname: 'Fixture owner',
      title: 'Fixture live',
      category: 'Music',
      avatar: 'https://image.example/avatar.jpg',
      hls: public ? Uri.parse('https://media.example/live/fixture.m3u8') : null,
    );
  }
}
