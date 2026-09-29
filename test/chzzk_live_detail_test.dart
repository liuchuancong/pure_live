import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/core/site/chzzk/chzzk_api.dart';
import 'package:pure_live/core/site/chzzk/chzzk_site.dart';
import 'package:pure_live/get/get.dart';

const _id = 'edc8e365ad55fb67f7a58297f80aaf3d';

Map<String, dynamic> _channel() => {
  'channelId': _id,
  'channelName': 'fixture',
  'channelImageUrl': 'https://nng-phinf.pstatic.net/fixture.png',
  'followerCount': 10,
  'openLive': true,
};

void main() {
  setUpAll(() async {
    await Hive.openBox<dynamic>('app_settings', bytes: Uint8List(0));
    await HivePrefUtil.init();
    Get.put(SettingsService(), permanent: true);
  });
  tearDownAll(Hive.close);

  test('an overseas-restricted live opens as a region notice instead of failing', () async {
    final paths = <String>[];
    final api = ChzzkApi(
      request: (uri, cancel) async {
        paths.add(uri.path);
        if (uri.path == '/service/v1/channels/$_id') {
          return (status: 200, body: jsonEncode({'code': 200, 'content': _channel()}));
        }
        if (uri.path == '/service/v2/channels/$_id/live-detail') {
          // What CHZZK returns for these lives since 2026-09.
          return (status: 500, body: jsonEncode({'code': 9004, 'message': '해외 시청 불가능한 컨텐츠 입니다.'}));
        }
        if (uri.path == '/service/v3.1/channels/$_id/live-detail') {
          return (
            status: 200,
            body: jsonEncode({
              'code': 200,
              'content': {
                'liveId': 21307904,
                'liveTitle': 'Asian Games marathon',
                'status': 'OPEN',
                'adult': false,
                'krOnlyViewing': true,
                'timeMachineActive': false,
                'livePlaybackJson': null,
                'concurrentUserCount': 1200,
                'channel': _channel(),
              },
            }),
          );
        }
        return (status: 404, body: '{}');
      },
    );

    final room = await ChzzkSite(api: api).getRoomDetail(roomId: _id, platform: 'chzzk');

    expect(paths, contains('/service/v3.1/channels/$_id/live-detail'));
    expect(paths, isNot(contains('/service/v2/channels/$_id/live-detail')));
    expect(room.title, 'Asian Games marathon');
    expect(room.notice, isNotEmpty);
    expect(room.data, isNull, reason: 'no playback is offered for a restricted live');
  });
}
