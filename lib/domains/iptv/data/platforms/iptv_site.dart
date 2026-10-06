import 'dart:developer';

import 'package:pure_live/core/index.dart';
import 'package:pure_live/domains/iptv/data/local/db_service.dart';
import 'package:pure_live/core/platform/file_utils.dart';
import 'package:pure_live/core/models/live_category.dart';
import 'package:pure_live/core/models/live_anchor_item.dart';
import 'package:pure_live/core/models/live_play_quality.dart';
import 'package:pure_live/domains/iptv/data/local/database.dart';
import 'package:pure_live/shared/platforms/live_site.dart';
import 'package:pure_live/domains/iptv/data/iptv_repository.dart';
import 'package:pure_live/domains/iptv/domain/fuzzy_match.dart';
import 'package:pure_live/shared/platforms/empty_danmaku.dart';
import 'package:pure_live/shared/platforms/live_danmaku.dart';
import 'package:pure_live/domains/iptv/data/services/auto_sync_scheduler.dart';
import 'package:pure_live/core/network/http_header_policy.dart';
import 'package:pure_live/domains/iptv/data/iptv_settings_controller.dart';
import 'package:pure_live/core/consts/platform_ids.dart';
import 'package:pure_live/shared/platforms/live_danmaku_capability.dart';
import 'package:pure_live/domains/iptv/data/platforms/iptv_danmaku_capability.dart';

class IptvSite
    with LiveDanmakuCapabilityDefaults, IptvDanmakuCapability
    implements LiveSite, LiveSiteRecordRoomResolver, LivePlayStreamFacts {
  @override
  String id = PlatformIds.iptv;

  @override
  String name = '网络';

  String defaultAvatar =
      "https://img95.699pic.com/xsj/0q/x6/7p.jpg%21/fw/700/watermark/url/L3hzai93YXRlcl9kZXRhaWwyLnBuZw/align/southeast";

  @override
  Future<List<LiveCategory>> getCategores(int page, int pageSize) async {
    final db = Get.find<DbService>().db;
    final providers = await db.getAllProviders();

    final categoryTypes = <LiveCategory>[];

    for (final provider in providers) {
      if (provider.id == FileUtils.systemHotProviderId || provider.name == 'hot') {
        continue;
      } else {
        final channels = await db.getChannelsForProvider(provider.id);

        final subs = <LiveArea>[];
        for (final ch in channels) {
          subs.add(
            LiveArea(
              areaId: ch.id,
              areaName: ch.name,
              areaPic: ch.tvgLogo ?? '',
              typeName: provider.name,
              areaType: provider.id,
              platform: PlatformIds.iptv,
            ),
          );
        }

        categoryTypes.add(LiveCategory(id: provider.id, name: provider.name, children: subs));
      }
    }
    return categoryTypes;
  }

  // =========================================================
  // =========================================================

  @override
  Future<List<LiveRoom>> getCategoryRooms(LiveArea category, {int page = 1, int pageSize = 30}) async {
    final db = Get.find<DbService>().db;
    final items = <LiveRoom>[];

    final ch = await db.getChannelById(category.areaId!);
    if (ch == null) return [];

    final epgId = await _resolveEpgChannelId(ch, IptvSettingsController.to.selectedSourceId.v);
    EpgProgramme? nowProg;
    if (epgId != null) {
      final nowList = await db.getNowPlaying([epgId]);
      if (nowList.isNotEmpty) nowProg = nowList.first;
    }

    items.add(
      LiveRoom(
        roomId: ch.id,
        title: ch.name,
        nick: ch.groupTitle ?? '',
        cover: ch.tvgLogo ?? '',
        area: ch.groupTitle ?? '',
        watching: '',
        avatar: defaultAvatar,
        status: true,
        liveStatus: LiveStatus.live,
        platform: PlatformIds.iptv,
        link: ch.streamUrl,
        data: ch.streamUrl,
        epgId: epgId,
        currentProgramme: nowProg?.title,
        currentProgrammeDescription: nowProg?.description,
        catchUpMode: ch.catchupMode,
        catchUpSource: ch.catchupSource,
        catchUpDays: ch.catchupDays,
        catchUpCorrectionHours: ch.catchupCorrectionHours,
        httpHeaders: HttpHeaderPolicy.decode(ch.httpHeadersJson),
      ),
    );

    return items;
  }

  // =========================================================
  // =========================================================

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom liveroom) async {
    if (liveroom.detailIdentity == null) return liveroom;
    final fresh = await _loadDetail(liveroom.roomId!);
    // Pad response gaps from the room the caller already holds. fillFromDetail
    // covers nick/avatar/area; the cover is padded explicitly because a blank
    // cover is the most visible symptom of a partial profile response.
    final padded = fresh.fillFromDetail(liveroom);
    final existingCover = liveroom.cover ?? '';
    if ((padded.cover == null || padded.cover!.isEmpty) && existingCover.isNotEmpty) {
      return padded.copyWith(cover: existingCover);
    }
    return padded;
  }

  Future<LiveRoom> _loadDetail(String roomId) async {
    final db = Get.find<DbService>().db;
    final channel = await db.getChannelById(roomId);
    if (channel == null) {
      if (channel == null) {
        return LiveRoom(
          cover: '',
          watching: '',
          roomId: roomId,
          area: '',
          title: '',
          nick: '',
          avatar: defaultAvatar,
          introduction: '',
          notice: '',
          status: true,
          liveStatus: LiveStatus.live,
          platform: PlatformIds.iptv,
          link: roomId,
          data: roomId,
        );
      }
    }
    final finalEpgChannelId = await _resolveEpgChannelId(channel, IptvSettingsController.to.selectedSourceId.v);

    EpgProgramme? nowProg;
    if (finalEpgChannelId != null) {
      final list = await db.getNowPlaying([finalEpgChannelId]);
      if (list.isNotEmpty) nowProg = list.first;
    }

    return _buildLiveRoom(channel, nowProg, epgId: finalEpgChannelId);
  }

  @override
  Future<LiveRoom> getRoomDetailForRecording(LiveRoom liveroom) async {
    if (liveroom.detailIdentity == null) return liveroom;
    // Imported channels already store their playback URL as room data. The
    // database lookup is authoritative and does not use a presentation
    // fallback, so the same loader is the strict recording contract.
    return _loadDetail(liveroom.roomId!);
  }

  Future<String?> _resolveEpgChannelId(Channel channel, String currentEpgSourceId) async {
    final db = Get.find<DbService>().db;
    String? finalEpgChannelId;

    if (currentEpgSourceId.isEmpty) {
      return null;
    }

    EpgMapping? existingMapping = await db.getMappingByChannelId(channel.id, providerId: channel.providerId);
    if (existingMapping != null && existingMapping.epgSourceId == currentEpgSourceId) {
      final mapped = await db.resolveEpgChannelId(currentEpgSourceId, existingMapping.epgChannelId);
      if (mapped != null || existingMapping.locked) return mapped;
    }
    final dbChannels = await db.getEpgChannelsForSource(currentEpgSourceId);

    log(dbChannels.length.toString());
    if (dbChannels.isNotEmpty) {
      final cleanTvgId = channel.tvgId?.trim().toLowerCase();
      if (cleanTvgId != null && cleanTvgId.isNotEmpty) {
        final matchedTvg = dbChannels.firstWhereOrNull((dbCh) {
          return dbCh.channelId.trim().toLowerCase() == cleanTvgId;
        });
        if (matchedTvg != null) {
          finalEpgChannelId = matchedTvg.id;
        }
      }
      if (finalEpgChannelId == null) {
        final cleanRegex = RegExp(r'[^a-zA-Z0-9\u4e00-\u9fa5]');
        final suffixRegex = RegExp(r'(综合|高清|超清|中央|电视台|频道|hd)', caseSensitive: false);

        String targetClean = channel.name.trim().split(' ').first;
        targetClean = targetClean.toLowerCase().replaceAll(cleanRegex, '');
        targetClean = targetClean.replaceAll(suffixRegex, '').trim();

        var matchedList = dbChannels.where((dbCh) {
          String dbClean = dbCh.displayName.trim().split(' ').first;
          dbClean = dbClean.toLowerCase().replaceAll(cleanRegex, '');
          dbClean = dbClean.replaceAll(suffixRegex, '').trim();

          return targetClean.contains(dbClean) || dbClean.contains(targetClean);
        }).toList();

        if (matchedList.isNotEmpty) {
          matchedList.sort((a, b) {
            String aClean = a.displayName
                .trim()
                .split(' ')
                .first
                .toLowerCase()
                .replaceAll(cleanRegex, '')
                .replaceAll(suffixRegex, '')
                .trim();
            String bClean = b.displayName
                .trim()
                .split(' ')
                .first
                .toLowerCase()
                .replaceAll(cleanRegex, '')
                .replaceAll(suffixRegex, '')
                .trim();

            final aPerfect = aClean == targetClean;
            final bPerfect = bClean == targetClean;

            if (aPerfect && !bPerfect) return -1;
            if (bPerfect && !aPerfect) return 1;
            if (aPerfect && bPerfect) return 0;

            final scoreA = fuzzyMatch(channel.name, [a.displayName]);
            final scoreB = fuzzyMatch(channel.name, [b.displayName]);
            return scoreB.compareTo(scoreA);
          });

          finalEpgChannelId = matchedList.first.id;
        }
      }
    }

    return finalEpgChannelId;
  }

  LiveRoom _buildLiveRoom(Channel channel, EpgProgramme? prog, {String? epgId}) {
    return LiveRoom(
      roomId: channel.id,
      title: channel.name,
      nick: channel.tvgName ?? channel.name,
      cover: channel.tvgLogo ?? '',
      area: channel.groupTitle ?? '',
      watching: '',
      avatar: defaultAvatar,
      status: true,
      liveStatus: LiveStatus.live,
      platform: PlatformIds.iptv,
      link: channel.streamUrl,
      data: channel.streamUrl,
      epgId: epgId,
      currentProgramme: prog?.title,
      currentProgrammeDescription: prog?.description,
      catchUpMode: channel.catchupMode,
      catchUpSource: channel.catchupSource,
      catchUpDays: channel.catchupDays,
      catchUpCorrectionHours: channel.catchupCorrectionHours,
      httpHeaders: HttpHeaderPolicy.decode(channel.httpHeadersJson),
    );
  }

  // =========================================================
  // =========================================================

  @override
  Future<List<LiveRoom>> getRecommendRooms({int page = 1, int pageSize = 30}) async {
    var channels = await IptvRepository().getChannels(FileUtils.systemHotProviderId);
    if (channels.isEmpty) {
      await AutoSyncScheduler.instance.loadHotResources();
    }
    channels = await IptvRepository().getChannels(FileUtils.systemHotProviderId);
    final items = <LiveRoom>[];
    for (final ch in channels) {
      items.add(
        LiveRoom(
          roomId: ch.id,
          title: ch.name,
          nick: '',
          cover: ch.tvgLogo ?? '',
          area: ch.groupTitle ?? '',
          watching: '',
          avatar: defaultAvatar,
          introduction: ch.name,
          notice: '',
          status: true,
          liveStatus: LiveStatus.live,
          platform: PlatformIds.iptv,
          link: ch.streamUrl,
          data: ch.streamUrl,
          catchUpMode: ch.catchupMode,
          catchUpSource: ch.catchupSource,
          catchUpDays: ch.catchupDays,
          catchUpCorrectionHours: ch.catchupCorrectionHours,
          httpHeaders: ch.httpHeaders,
        ),
      );
    }

    return items;
  }

  // =========================================================
  // =========================================================

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom liveroom}) async {
    final url = liveroom.data?.toString().trim() ?? '';
    if (url.isEmpty) return const <LivePlayQuality>[];
    return [
      LivePlayQuality(quality: '默认', id: 'default', sort: 1, data: <String>[url]),
    ];
  }

  // =========================================================
  // =========================================================

  @override
  Future<List<String>> getPlayUrls({required LiveRoom liveroom, required LivePlayQuality quality}) async {
    final data = quality.data;
    if (data is! List) return const <String>[];
    return data.map((item) => item.toString().trim()).where((url) => url.isNotEmpty).toList(growable: false);
  }

  @override
  Map<String, LiveStreamFacts> declareStreamFacts(List<String> urls) {
    final facts = <String, LiveStreamFacts>{};
    for (final url in urls) {
      final format = iptvStreamFormat(url);
      if (format != null) {
        facts[url] = (format: format, codec: null, unresolvedChildren: false);
      }
    }
    return facts;
  }

  // =========================================================
  // =========================================================

  @override
  LiveDanmaku getDanmaku() => EmptyDanmaku();

  // =========================================================
  // =========================================================

  @override
  Future<List<LiveSuperChatMessage>> getSuperChatMessage({required LiveRoom liveroom}) async {
    return [];
  }

  // =========================================================
  // =========================================================

  @override
  Future<List<LiveAnchorItem>> searchAnchors(String keyword, {int page = 1, int pageSize = 30}) async {
    return [];
  }

  // =========================================================
  // =========================================================

  @override
  Future<List<LiveRoom>> searchRooms(String keyword, {int page = 1, int pageSize = 30}) async {
    final db = Get.find<DbService>().db;
    if (keyword.trim().isEmpty) return [];
    final matched = await db.searchChannelsByName(keyword);
    final items = matched.map((ch) {
      return LiveRoom(
        roomId: ch.id,
        title: ch.name,
        nick: ch.groupTitle ?? '',
        cover: ch.tvgLogo ?? '',
        area: ch.groupTitle ?? '',
        watching: '',
        avatar: defaultAvatar,
        status: true,
        liveStatus: LiveStatus.live,
        platform: PlatformIds.iptv,
        link: ch.streamUrl,
        data: ch.streamUrl,
        catchUpMode: ch.catchupMode,
        catchUpSource: ch.catchupSource,
        catchUpDays: ch.catchupDays,
        catchUpCorrectionHours: ch.catchupCorrectionHours,
        httpHeaders: HttpHeaderPolicy.decode(ch.httpHeadersJson),
      );
    }).toList();
    return items;
  }
}

LiveStreamFormat? iptvStreamFormat(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return null;
  final scheme = uri.scheme.toLowerCase();
  if (scheme == 'rtp' || scheme == 'udp' || scheme == 'rtsp') return LiveStreamFormat.other;
  final path = uri.path.toLowerCase();
  if (path.endsWith('.m3u8') || path.endsWith('.m3u')) return LiveStreamFormat.hls;
  if (path.endsWith('.ts') || path.contains('/udp/')) return LiveStreamFormat.other;
  return null;
}
