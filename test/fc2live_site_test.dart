import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/site/fc2live/fc2_api.dart';
import 'package:pure_live/core/site/fc2live/fc2_input_recipe.dart';
import 'package:pure_live/core/site/fc2live/fc2_link.dart';
import 'package:pure_live/core/site/fc2live/fc2_site.dart';
import 'package:pure_live/core/sites.dart';
import 'package:pure_live/player/core/live_input_playback_binding.dart';
import 'package:pure_live/recorder/services/live_input_recording_binding.dart';

void main() {
  test('official channel links retain a numeric durable identity', () {
    expect(Fc2Link.parseChannelId('10608314'), '10608314');
    expect(Fc2Link.parseChannelId('https://live.fc2.com/10608314/'), '10608314');
    expect(Fc2Link.parseChannelId('https://live.fc2.com/en/10608314/'), '10608314');
    expect(Fc2Link.channelUrl('10608314'), 'https://live.fc2.com/10608314/');
    for (final invalid in [
      '0',
      'https://live.fc2.com/',
      'https://live.fc2.com/rank/',
      'https://live.fc2.com/10608314/archive',
      'https://live.fc2.com.evil.test/10608314/',
      'https://user@live.fc2.com/10608314/',
    ]) {
      expect(Fc2Link.parseChannelId(invalid), isNull, reason: invalid);
    }
  });

  test('directory parser separates current and cumulative audience values', () {
    final directory = Fc2Api.parseDirectory(_directoryPayload());
    expect(directory.rooms, hasLength(2), reason: 'open-chat entries are not public media rooms');
    final public = directory.rooms.first;
    expect(public.channelId, '10608314');
    expect(public.currentViewers, 61);
    expect(public.totalViewers, 1727);
    expect(public.categoryName, 'Idle Chat');
    expect(public.state, Fc2State.live);
    expect(directory.rooms.last.state, Fc2State.restricted);
  });

  test('member and control payloads preserve explicit state and validated seat identity', () {
    final member = Fc2Api.parseMember(_memberPayload(), expectedChannelId: '10608314');
    expect(member.room.userName, 'Fixture owner');
    expect(member.room.state, Fc2State.live);
    expect(member.room.currentViewers, 61);
    expect(member.version, 'fixture-version');

    final grant = Fc2Api.parseControlGrant(_controlPayload(), expectedChannelId: '10608314');
    expect(grant.webSocket.host, 'us-west-1-media-worker1077.live.fc2.com');
    expect(grant.webSocket.path, '/control/channels/10608314');
    expect(grant.controlToken, 'fixture-control-token');
  });

  test('finite catalogue, category, exact lookup and owned input keep one identity', () async {
    final site = Fc2Site(api: _Fc2FixtureApi());
    final categories = (await site.getCategores(1, 30)).single.children;
    final all = await site.getDirectoryPage(category: categories.first);
    expect(all.rooms, hasLength(2));
    expect(all.rooms.first.onlineViewers, '61');
    expect(all.rooms.first.totalViewers, '1727');
    expect(all.rooms.first.audienceMetricType, AudienceMetricType.onlineViewers);

    final audio = categories.singleWhere((area) => area.areaId == '9');
    expect((await site.getDirectoryPage(category: audio)).rooms.single.roomId, '11916060');

    final exact = await site.searchRooms('https://live.fc2.com/10608314/');
    expect(exact.single.roomId, '10608314');
    final generic = await site.searchRooms('kitten');
    expect(generic.single.roomId, '11916060');

    final detail = await site.getRoomDetail(roomId: '10608314', platform: Sites.fc2LiveSite);
    final quality = (await site.getPlayQualites(detail: detail)).single;
    expect(quality.selectionId, 'auto');
    final resolution = await site.resolvePlayUrlsRaw(detail: detail, quality: quality);
    expect(resolution.urls, isEmpty);
    expect(resolution.inputRecipe, isA<Fc2InputRecipe>());
    expect((resolution.inputRecipe as Fc2InputRecipe).channelId, '10608314');
  });

  test('registry and playback/recording binders expose FC2 once', () {
    expect(Sites.supportedSiteIds, contains(Sites.fc2LiveSite));
    expect(Sites.of(Sites.fc2LiveSite).liveSite, isA<Fc2Site>());
    expect(Sites.supportSites.where((site) => site.id == Sites.fc2LiveSite), hasLength(1));
    final recipe = Fc2InputRecipe('10608314');
    expect(bindLiveInputForPlayback(recipe).identity, recipe.identity);
    expect(bindLiveInputForRecording(recipe).identity, recipe.identity);
  });
}

Map<String, dynamic> _directoryPayload() => {
  'time': 1789980977,
  'channel': [
    {
      'id': '10608314',
      'type': 1,
      'category': 1,
      'name': 'Fixture owner',
      'title': 'Fixture game stream',
      'image': 'https://live-storage.fc2.com/thumb/10608314/thumb.jpg?fixture=1',
      'start_time': 1789885361806,
      'pay': 0,
      'login': 0,
      'tid': 0,
      'count': 61,
      'total': 1727,
    },
    {
      'id': '11916060',
      'type': 1,
      'category': 9,
      'name': 'Kitten radio',
      'title': '24/7 Kitten audio',
      'image': 'https://live-storage.fc2.com/thumb/11916060/thumb.png',
      'start_time': 1789449587689,
      'pay': 0,
      'login': 0,
      'tid': 0,
      'count': 3,
      'total': 1279,
    },
    {
      'id': '12000001',
      'type': 1,
      'category': 5,
      'name': 'Ticket room',
      'title': 'Ticket room',
      'image': '',
      'start_time': 1789449587689,
      'pay': 0,
      'login': 0,
      'tid': 7,
      'count': 4,
      'total': 20,
    },
    {
      'id': '1',
      'type': 0,
      'category': 1,
      'name': 'Open chat',
      'title': '',
      'image': '',
      'start_time': 1789449587689,
      'pay': 0,
      'login': 0,
      'tid': 0,
      'count': 1,
      'total': 1,
    },
  ],
};

Map<String, dynamic> _memberPayload() => {
  'status': 1,
  'data': {
    'channel_data': {
      'channelid': '10608314',
      'adult': 0,
      'title': 'Fixture game stream',
      'info': 'Fixture description',
      'image': 'https://live-storage.fc2.com/thumb/10608314/thumb.jpg',
      'login_only': 0,
      'fee': 0,
      'ticketid': 0,
      'ticket_only': 0,
      'is_limited': 0,
      'category': 1,
      'category_name': 'Idle Chat',
      'count': 61,
      'total': 1727,
      'is_publish': 1,
      'start': 1789885361806,
      'version': 'fixture-version',
      'tname': '',
    },
    'profile_data': {'name': 'Fixture owner'},
  },
};

Map<String, dynamic> _controlPayload() => {
  'url': 'wss://us-west-1-media-worker1077.live.fc2.com/control/channels/10608314',
  'orz_raw': 'fixture_orz-token',
  'control_token': 'fixture-control-token',
  'status': 0,
};

final class _Fc2FixtureApi extends Fc2Api {
  _Fc2FixtureApi() : super(request: (_, _, _, _) async => throw StateError('unused'));

  @override
  Future<Fc2Directory> directory({CancelToken? cancel}) async => Fc2Api.parseDirectory(_directoryPayload());

  @override
  Future<Fc2Room> room(String rawChannelId, {CancelToken? cancel}) async {
    final id = Fc2Link.requireChannelId(rawChannelId);
    if (id == '10608314') return Fc2Api.parseMember(_memberPayload(), expectedChannelId: id).room;
    return Fc2Room(
      channelId: id,
      userName: 'Kitten radio',
      title: '24/7 Kitten audio',
      description: '',
      cover: 'https://live-storage.fc2.com/thumb/$id/thumb.png',
      categoryId: 9,
      categoryName: 'Audio',
      currentViewers: 3,
      totalViewers: 1279,
      state: Fc2State.live,
      isAdult: false,
      startedAt: DateTime.utc(2026, 9, 15),
    );
  }
}
