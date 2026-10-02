// Opt-in public anchor lookup. No account, media fetch or native playback.
import 'dart:convert';
import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/network/http_client.dart';
import 'package:pure_live/domains/live/data/platforms/kilakila/kilakila_api.dart';

void main() {
  test(
    'public UID resolves to a matching current broadcast detail',
    () async {
      await io.HttpOverrides.runWithHttpOverrides(() async {
        final uid = io.Platform.environment['PURELIVE_KILAKILA_OWNER_UID']!;
        final previous = HttpClient.instance.dio;
        final dio = Dio(
          BaseOptions(connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 20)),
        )..httpClientAdapter = IOHttpClientAdapter(createHttpClient: () => io.HttpClient());
        HttpClient.instance.dio = dio;
        try {
          final api = KilakilaApi();
          final profile = await api.owner(uid);
          expect(
            profile.currentRoom,
            isNotNull,
            reason: 'Explicit sample is no longer advertising a current broadcast',
          );
          expect(profile.currentRoom!.userId, uid);
          expect(profile.currentRoom!.media, isEmpty);
          final room = await api.detailForOwner(uid);
          expect(room, isNotNull);
          expect(room!.userId, uid);
          expect(room.media, isNotEmpty);
          // A second public sample may have started again; record actual state
          // instead of freezing an earlier absence as a permanent offline fact.
          final oldUid = io.Platform.environment['PURELIVE_KILAKILA_PREVIOUS_OWNER_UID'];
          final old = oldUid == null ? null : await api.owner(oldUid);
          final result = {
            'utc': DateTime.now().toUtc().toIso8601String(),
            'ownerEndpoint': '${KilakilaApi.ownerOrigin}/Tg/personalH5',
            'ownerMatchedDetail': true,
            'currentRoomUnchangedBetweenRequests': profile.currentRoom!.roomId == room.roomId,
            'protocolIds': room.media.keys.toList(),
            'secondSampleHasAdvertisedBroadcast': old?.currentRoom != null,
            'secondSampleQueried': oldUid != null,
            'metadataSeparatedFromMedia': true,
            'realCrossBroadcastTransitionObserved': false,
            'opaqueShareDecoded': false,
            'nativePlaybackOrRecording': false,
            'mediaFetched': false,
            'routing': 'anonymous direct Dio; application proxy not exercised',
          };
          final output = io.Platform.environment['PURELIVE_KILAKILA_OWNER_OUTPUT'];
          if (output != null) {
            await io.File(output).writeAsString('${const JsonEncoder.withIndent('  ').convert(result)}\n');
          }
          // ignore: avoid_print
          print(jsonEncode(result));
        } finally {
          HttpClient.instance.dio = previous;
          dio.close(force: true);
        }
      }, _RealNetwork());
    },
    skip: io.Platform.environment['PURELIVE_KILAKILA_OWNER_UID'] == null,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

class _RealNetwork extends io.HttpOverrides {}
