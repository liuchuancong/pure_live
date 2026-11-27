import 'dart:async';
import 'dart:io';

import 'package:grpc/grpc.dart';
import 'package:live_vod/live_vod.dart';
import 'package:live_vod/src/grpc/gen/bilibili/app/playerunite/v1/playerunite.pb.dart' as unite;
import 'package:live_vod/src/grpc/gen/bilibili/app/playerunite/v1/playerunite.pbgrpc.dart' as unite_rpc;
import 'package:live_vod/src/grpc/gen/bilibili/pgc/gateway/player/v2/playurl.pb.dart' as pgc;
import 'package:live_vod/src/grpc/gen/bilibili/pgc/gateway/player/v2/playurl.pbgrpc.dart' as pgc_rpc;
import 'package:live_vod/src/grpc/gen/bilibili/playershared/playershared.pb.dart' as shared;
import 'package:test/test.dart';

void main() {
  test('an empty UGC ladder fails so the caller can use the web fallback', () async {
    final client = await _serve(_PlayerService(ugc: shared.VodInfo(quality: 80)));

    await expectLater(
      client.playUgc(aid: 1, cid: 2),
      throwsA(isA<VodFailure>().having((failure) => failure.message, 'message', contains('no playable video'))),
    );
  });

  test('an empty PGC ladder fails so the caller can use the web fallback', () async {
    final client = await _serve(_PgcService(pgcInfo: pgc.VideoInfo(quality: 80)));

    await expectLater(
      client.playPgc(epid: 3),
      throwsA(isA<VodFailure>().having((failure) => failure.message, 'message', contains('no playable video'))),
    );
  });

  test('invalid advanced audio URLs do not hide a silent video', () async {
    final client = await _serve(
      _PlayerService(
        ugc: shared.VodInfo(
          quality: 80,
          streamList: [
            shared.Stream(
              streamInfo: shared.StreamInfo(quality: 80),
              dashVideo: shared.DashVideo(baseUrl: 'https://cdn/video.m4s', codecid: 7),
            ),
          ],
          lossLessItem: shared.LossLessItem(audio: shared.DashItem(id: 1, baseUrl: '')),
          dolby: shared.DolbyItem(audio: [shared.DashItem(id: 2, baseUrl: 'file:///invalid.m4s')]),
        ),
      ),
    );

    final info = await client.playUgc(aid: 1, cid: 2);

    expect(info.videos.single.url, 'https://cdn/video.m4s');
    expect(info.audios, isEmpty);
    expect(info.flac, isNull);
    expect(info.dolby, isNull);
    expect(info.silent, isTrue);
  });
}

Future<BilibiliAppClient> _serve(Service service) async {
  final server = Server.create(services: [service]);
  await server.serve(address: InternetAddress.loopbackIPv4, port: 0);
  final client = BilibiliAppClient(
    accessKey: '',
    buvid: 'test',
    host: InternetAddress.loopbackIPv4.address,
    port: server.port!,
    credentials: const ChannelCredentials.insecure(),
  );
  addTearDown(() async {
    await client.close();
    await server.shutdown();
  });
  return client;
}

final class _PlayerService extends unite_rpc.PlayerServiceBase {
  // The unnamed constructor repeats the class name by Dart's syntax.
  // ignore: unnecessary_type_name_in_constructor
  _PlayerService({this.ugc});

  final shared.VodInfo? ugc;

  @override
  Future<unite.PlayViewUniteReply> playViewUnite(ServiceCall call, unite.PlayViewUniteReq request) async =>
      unite.PlayViewUniteReply(vodInfo: ugc ?? shared.VodInfo());
}

final class _PgcService extends pgc_rpc.PlayURLServiceBase {
  // The unnamed constructor repeats the class name by Dart's syntax.
  // ignore: unnecessary_type_name_in_constructor
  _PgcService({this.pgcInfo});

  final pgc.VideoInfo? pgcInfo;

  @override
  // The generated protocol spells this RPC with an underscore.
  // ignore: non_constant_identifier_names
  Future<pgc.PlayViewReply> playView_Pre(ServiceCall call, Future<pgc.PlayViewReq> request) async =>
      pgc.PlayViewReply(videoInfo: pgcInfo ?? pgc.VideoInfo());

  @override
  Future<pgc.PlayViewReply> playView(ServiceCall call, pgc.PlayViewReq request) async =>
      pgc.PlayViewReply(videoInfo: pgcInfo ?? pgc.VideoInfo());

  @override
  // The generated protocol spells this RPC with an underscore.
  // ignore: non_constant_identifier_names
  Future<pgc.PlayViewReply> playViewComic_Pre(ServiceCall call, Future<pgc.PlayViewReq> request) async =>
      pgc.PlayViewReply(videoInfo: pgcInfo ?? pgc.VideoInfo());

  @override
  Future<pgc.PlayViewReply> playViewComic(ServiceCall call, pgc.PlayViewReq request) async =>
      pgc.PlayViewReply(videoInfo: pgcInfo ?? pgc.VideoInfo());
}
