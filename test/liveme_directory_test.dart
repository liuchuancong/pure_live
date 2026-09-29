import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/site/liveme/liveme_api.dart';

Map<String, Object?> _video(String shortId, String userId) => {
  'ushortid': shortId,
  'userid': userId,
  'vid': '17902858417547954418',
  'uname': 'Anchor $shortId',
  'title': '',
  'online': 1,
  'status': 0,
  'roomstate': 0,
  'playnumber': 120,
  'countryCode': 'US',
};

LiveMeApi _api(List<Map<String, Object?>> rows) => LiveMeApi(
  request: ({required method, required uri, required headers, form, cancel}) async => (
    status: 200,
    body: jsonEncode({
      'status': '200',
      'msg': 'complete',
      'data': {'video_info': rows, 'next_page': 0},
    }),
  ),
);

void main() {
  test('a featured row without a short id is skipped instead of failing the directory', () async {
    // Production (2026-09-25): one featurelist row (with union_room_id) has no
    // ushortid; the app keys LiveMe rooms by short id, so it is unusable.
    final unionRow = _video('0', '2093485386708749313')
      ..remove('ushortid')
      ..['union_room_id'] = 'fixture';
    final page = await _api([
      _video('12345678', '1234567890123456789'),
      unionRow,
      _video('23456789', '2234567890123456789'),
    ]).directory();

    expect(page.rooms.map((room) => room.shortId), ['12345678', '23456789']);
  });

  test('a row with a malformed short id is still rejected', () async {
    await expectLater(_api([_video('12', '1234567890123456789')]).directory(), throwsA(isA<LiveMeException>()));
  });
}
