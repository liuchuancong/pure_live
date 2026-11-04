// The Bilibili app interface for playback: the gRPC services the official
// client calls (PlayerUnite for UGC, PGC PlayView for the cinema), over the
// metadata headers it sends. The web interface's REST answers stay in
// BilibiliVodClient; this file is the "App" side of the interface switch.
import 'dart:convert' show base64Encode;

import 'package:fixnum/fixnum.dart';
import 'package:grpc/grpc.dart';

import 'package:live_vod/src/grpc/gen/bilibili/app/playerunite/v1/playerunite.pbgrpc.dart' as unite;
import 'package:live_vod/src/grpc/gen/bilibili/app/view/v1/view.pbgrpc.dart' as view;
import 'package:live_vod/src/grpc/gen/bilibili/metadata/device/device.pb.dart' as device;
import 'package:live_vod/src/grpc/gen/bilibili/metadata/locale/locale.pb.dart' as locale;
import 'package:live_vod/src/grpc/gen/bilibili/metadata/metadata.pb.dart' as metadata;
import 'package:live_vod/src/grpc/gen/bilibili/metadata/network/network.pb.dart' as network;
import 'package:live_vod/src/grpc/gen/bilibili/pgc/gateway/player/v2/playurl.pbgrpc.dart' as pgc;
import 'package:live_vod/src/grpc/gen/bilibili/playershared/playershared.pb.dart' as shared;
import 'package:live_vod/src/vod_models.dart';

/// The app client identity, as the official Android HD build sends it.
const String _mobiApp = 'android_hd';
const String _appChannel = 'yingyongbao';
const int _appBuild = 2020100;
const int _appId = 5;

/// Quality labels the app interface reports by number, since its streams
/// carry no display names.
const Map<int, String> _kQualityLabels = {
  127: '8K 超高清',
  126: '杜比视界',
  125: 'HDR 真彩',
  120: '4K 超清',
  116: '1080P60 高帧率',
  112: '1080P+ 高码率',
  80: '1080P 高清',
  74: '720P60 高帧率',
  64: '720P 准高清',
  32: '480P 清晰',
  16: '360P 流畅',
};

/// One video essence as either service reports it, before the module's model.
typedef _VideoRow = ({
  int quality,
  String url,
  List<String> backup,
  int codecId,
  int bandwidth,
  int width,
  int height,
  String frameRate,
});

/// One audio essence as either service reports it.
typedef _AudioRow = ({int id, String url, int bandwidth, List<String> backup});

/// The Bilibili app playback interface.
///
/// [accessKey] is the app login's token; an empty one still reaches the free
/// definitions the platform serves anonymously, and a logged-in one unlocks
/// the login-gated ladder.
final class BilibiliAppClient {
  /// Creates the client over the app's gRPC host.
  // The initializer list's channel type reads as a repeated type name to the
  // lint; the declaration is the class's own constructor.
  // ignore: unnecessary_type_name_in_constructor
  BilibiliAppClient({
    required this.accessKey,
    required this.buvid,
    String host = 'grpc.biliapi.net',
    int port = 443,
    ChannelCredentials? credentials,
  }) : _channel = ClientChannel(
         host,
         port: port,
         // ChannelCredentials.secure() is a factory, not a const expression.
         // ignore: prefer_const_constructors
         options: ChannelOptions(credentials: credentials ?? ChannelCredentials.secure()),
       );

  /// The app login's access token; empty for an anonymous session.
  final String accessKey;

  /// The device fingerprint the app's own client sends with every call.
  final String buvid;

  final ClientChannel _channel;

  /// The call options every service shares: the login token and the device
  /// fingerprint the app's own client sends as metadata.
  CallOptions get _options => CallOptions(
    timeout: const Duration(seconds: 20),
    metadata: {
      'authorization': 'identify_v1 $accessKey',
      'x-bili-metadata-bin': _metadataHeader(),
      'x-bili-device-bin': _deviceHeader(),
      'x-bili-local-bin': base64Encode(locale.Locale(timezone: 'Asia/Shanghai').writeToBuffer()),
      'x-bili-network-bin': base64Encode(network.Network(type: network.NetworkType.WIFI).writeToBuffer()),
    },
  );

  String _metadataHeader() => base64Encode(
    metadata.Metadata(
      accessKey: accessKey,
      mobiApp: _mobiApp,
      build: _appBuild,
      channel: _appChannel,
      buvid: buvid,
      platform: 'android',
    ).writeToBuffer(),
  );

  String _deviceHeader() => base64Encode(
    device.Device(
      appId: _appId,
      mobiApp: _mobiApp,
      build: _appBuild,
      channel: _appChannel,
      buvid: buvid,
      platform: 'android',
    ).writeToBuffer(),
  );

  /// One archive part's play data over the app's unified player service.
  Future<VodPlayInfo> playUgc({required int aid, required int cid, int qn = 127}) async {
    final client = unite.PlayerClient(_channel, options: _options);
    final reply = await client.playViewUnite(
      unite.PlayViewUniteReq(
        vod: shared.VideoVod(
          aid: Int64(aid),
          cid: Int64(cid),
          qn: Int64(qn),
          fnver: 0,
          fnval: 4048,
          fourk: true,
          forceHost: 2,
          preferCodecType: shared.CodeType.CODE264,
        ),
      ),
    );
    return _infoOf(reply.vodInfo);
  }

  /// One cinema episode's play data over the app's PGC player service.
  Future<VodPlayInfo> playPgc({required int epid, int? cid, int qn = 127}) async {
    final client = pgc.PlayURLClient(_channel, options: _options);
    final reply = await client.playView(
      pgc.PlayViewReq(
        epid: Int64(epid),
        cid: cid == null ? null : Int64(cid),
        qn: Int64(qn),
        fnver: 0,
        fnval: 4048,
        fourk: true,
        preferCodecType: pgc.CodeType.CODE264,
      ),
    );
    return _pgcInfoOf(reply.videoInfo);
  }

  /// One archive's detail over the app's view service — the same record the
  /// web's `view` endpoint answers, from the app's own model.
  Future<VodDetail> detail({int? aid, String? bvid}) async {
    final client = view.ViewClient(_channel, options: _options);
    final reply = await client.view(view.ViewReq(aid: aid == null ? null : Int64(aid), bvid: bvid ?? ''));
    if (!reply.hasArc()) throw const VodFailure('the app returned no detail');
    final arc = reply.arc;
    final owner = arc.hasAuthor() ? arc.author : null;
    final stat = arc.hasStat() ? arc.stat : null;
    final parts = [
      for (final page in reply.pages)
        if (page.hasPage())
          VodPart(
            cid: page.page.cid.toInt(),
            page: page.page.page,
            title: page.page.part,
            duration: page.page.duration > 0 ? Duration(seconds: page.page.duration.toInt()) : null,
          ),
    ];
    return VodDetail(
      bvid: reply.bvid.isNotEmpty ? reply.bvid : (bvid ?? ''),
      aid: arc.aid.toInt(),
      title: arc.title,
      coverUrl: arc.pic.isEmpty ? null : _https(arc.pic),
      description: arc.desc,
      uploader: owner == null || owner.name.isEmpty ? null : owner.name,
      uploaderMid: owner == null || owner.mid == 0 ? null : owner.mid.toInt(),
      uploaderAvatar: owner == null || owner.face.isEmpty ? null : _https(owner.face),
      playCount: stat?.view ?? 0,
      danmakuCount: stat?.danmaku ?? 0,
      likeCount: stat?.like ?? 0,
      coinCount: stat?.coin ?? 0,
      favoriteCount: stat?.fav ?? 0,
      duration: arc.duration > 0 ? Duration(seconds: arc.duration.toInt()) : null,
      parts: parts,
      publishedAt: arc.pubdate > 0 ? DateTime.fromMillisecondsSinceEpoch(arc.pubdate.toInt() * 1000) : null,
    );
  }

  /// The `.5.`-less scheme a protocol-relative address needs.
  static String _https(String value) {
    final trimmed = value.trim();
    if (trimmed.startsWith('//')) return 'https:$trimmed';
    return trimmed;
  }

  /// Closes the channel. The instance is unusable afterwards.
  Future<void> close() => _channel.shutdown();

  VodPlayInfo _infoOf(shared.VodInfo info) => _assemble(
    quality: info.quality,
    videos: [
      for (final stream in info.streamList)
        if (stream.hasDashVideo())
          (
            quality: stream.streamInfo.quality,
            url: stream.dashVideo.baseUrl,
            backup: stream.dashVideo.backupUrl.toList(),
            codecId: stream.dashVideo.codecid,
            bandwidth: stream.dashVideo.bandwidth,
            width: stream.dashVideo.width,
            height: stream.dashVideo.height,
            frameRate: stream.dashVideo.frameRate,
          ),
    ],
    audios: [
      for (final audio in info.dashAudio)
        (id: audio.id, url: audio.baseUrl, bandwidth: audio.bandwidth, backup: audio.backupUrl.toList()),
    ],
    flac: info.hasLossLessItem() && info.lossLessItem.audio.id != 0
        ? (
            id: info.lossLessItem.audio.id,
            url: info.lossLessItem.audio.baseUrl,
            bandwidth: info.lossLessItem.audio.bandwidth,
            backup: info.lossLessItem.audio.backupUrl.toList(),
          )
        : null,
    dolby: info.hasDolby() && info.dolby.audio.isNotEmpty && info.dolby.audio.first.id != 0
        ? (
            id: info.dolby.audio.first.id,
            url: info.dolby.audio.first.baseUrl,
            bandwidth: info.dolby.audio.first.bandwidth,
            backup: info.dolby.audio.first.backupUrl.toList(),
          )
        : null,
  );

  VodPlayInfo _pgcInfoOf(pgc.VideoInfo info) => _assemble(
    quality: info.quality,
    videos: [
      for (final stream in info.streamList)
        if (stream.hasDashVideo())
          (
            quality: stream.info.quality,
            url: stream.dashVideo.baseUrl,
            backup: stream.dashVideo.backupUrl.toList(),
            codecId: stream.dashVideo.codecid,
            bandwidth: stream.dashVideo.bandwidth,
            width: stream.dashVideo.width,
            height: stream.dashVideo.height,
            frameRate: stream.dashVideo.frameRate,
          ),
    ],
    audios: [
      for (final audio in info.dashAudio)
        (id: audio.id, url: audio.baseUrl, bandwidth: audio.bandwidth, backup: audio.backupUrl.toList()),
    ],
    flac: null,
    dolby: info.hasDolby() && info.dolby.audio.id != 0
        ? (
            id: info.dolby.audio.id,
            url: info.dolby.audio.baseUrl,
            bandwidth: info.dolby.audio.bandwidth,
            backup: info.dolby.audio.backupUrl.toList(),
          )
        : null,
  );

  /// Turns either service's answer into the module's play model.
  VodPlayInfo _assemble({
    required int quality,
    required List<_VideoRow> videos,
    required List<_AudioRow> audios,
    required _AudioRow? flac,
    required _AudioRow? dolby,
  }) {
    final tracks = <VodDashVideo>[
      for (final row in videos)
        if (row.url.startsWith('http'))
          VodDashVideo(
            id: row.quality,
            url: row.url,
            quality: row.quality,
            codecId: row.codecId,
            width: row.width <= 0 ? null : row.width,
            height: row.height <= 0 ? null : row.height,
            frameRate: double.tryParse(row.frameRate),
            bandwidth: row.bandwidth <= 0 ? null : row.bandwidth,
            backupUrls: row.backup,
          ),
    ]..sort((a, b) {
      final byQuality = b.quality.compareTo(a.quality);
      return byQuality != 0 ? byQuality : (b.bandwidth ?? 0).compareTo(a.bandwidth ?? 0);
    });
    final qns = <int>{for (final video in tracks) video.quality}.toList()..sort((a, b) => b.compareTo(a));
    return VodPlayInfo(
      url: '',
      quality: _kQualityLabels[quality],
      qualities: [
        for (final qn in qns) VodQuality(qn: qn, label: _kQualityLabels[qn] ?? '${qn}P'),
      ],
      servedQuality: quality,
      videos: tracks,
      audios: [
        for (final row in audios)
          if (row.url.startsWith('http'))
            VodDashAudio(id: row.id, url: row.url, bandwidth: row.bandwidth, backupUrls: row.backup),
      ],
      flac: flac == null ? null : VodDashAudio(id: flac.id, url: flac.url, bandwidth: flac.bandwidth, backupUrls: flac.backup),
      dolby: dolby == null
          ? null
          : VodDashAudio(id: dolby.id, url: dolby.url, bandwidth: dolby.bandwidth, backupUrls: dolby.backup),
      silent: tracks.isNotEmpty && audios.isEmpty && flac == null && dolby == null,
    );
  }
}
