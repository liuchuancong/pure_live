import 'package:pure_live/core/sites.dart';

enum NativeSearchCoverage { liveOnly, liveAndOffline, channelLookup, roomLookup, localChannels, webOnly, unavailable }

class LiveSearchCapability {
  const LiveSearchCapability({required this.coverage, required this.supportsPagination, this.supportsWebSearch = true});

  final NativeSearchCoverage coverage;
  final bool supportsPagination;
  final bool supportsWebSearch;

  bool get supportsNativeSearch =>
      coverage != NativeSearchCoverage.webOnly && coverage != NativeSearchCoverage.unavailable;
  bool get mayIncludeOffline =>
      coverage == NativeSearchCoverage.liveAndOffline ||
      coverage == NativeSearchCoverage.channelLookup ||
      coverage == NativeSearchCoverage.roomLookup;
}

class LiveSearchCapabilities {
  const LiveSearchCapabilities._();

  static const Map<String, LiveSearchCapability> _byPlatform = {
    Sites.weiboSite: LiveSearchCapability(
      coverage: NativeSearchCoverage.roomLookup,
      supportsPagination: false,
      supportsWebSearch: false,
    ),
    Sites.niconicoSite: LiveSearchCapability(coverage: NativeSearchCoverage.liveOnly, supportsPagination: true),
    Sites.showroomSite: LiveSearchCapability(
      coverage: NativeSearchCoverage.liveOnly,
      supportsPagination: true,
      supportsWebSearch: false,
    ),
    Sites.chzzkSite: LiveSearchCapability(
      coverage: NativeSearchCoverage.liveAndOffline,
      supportsPagination: true,
      supportsWebSearch: false,
    ),
    Sites.kickSite: LiveSearchCapability(
      coverage: NativeSearchCoverage.liveAndOffline,
      supportsPagination: false,
      supportsWebSearch: false,
    ),
    Sites.seventeenLiveSite: LiveSearchCapability(
      coverage: NativeSearchCoverage.roomLookup,
      supportsPagination: false,
      supportsWebSearch: false,
    ),
    Sites.liveMeSite: LiveSearchCapability(
      coverage: NativeSearchCoverage.liveAndOffline,
      supportsPagination: true,
      supportsWebSearch: false,
    ),
    Sites.tiktokSite: LiveSearchCapability(
      coverage: NativeSearchCoverage.channelLookup,
      supportsPagination: false,
      supportsWebSearch: false,
    ),
    Sites.youtubeSite: LiveSearchCapability(
      coverage: NativeSearchCoverage.channelLookup,
      supportsPagination: false,
      supportsWebSearch: false,
    ),
    Sites.bigoSite: LiveSearchCapability(
      coverage: NativeSearchCoverage.roomLookup,
      supportsPagination: false,
      supportsWebSearch: false,
    ),
    Sites.pandaLiveSite: LiveSearchCapability(
      coverage: NativeSearchCoverage.channelLookup,
      supportsPagination: false,
      supportsWebSearch: false,
    ),
    Sites.xiaohongshuSite: LiveSearchCapability(
      coverage: NativeSearchCoverage.roomLookup,
      supportsPagination: false,
      supportsWebSearch: false,
    ),
    Sites.ttingSite: LiveSearchCapability(
      coverage: NativeSearchCoverage.channelLookup,
      supportsPagination: false,
      supportsWebSearch: false,
    ),
    Sites.bilibiliSite: LiveSearchCapability(coverage: NativeSearchCoverage.liveAndOffline, supportsPagination: true),
    Sites.douyuSite: LiveSearchCapability(coverage: NativeSearchCoverage.liveAndOffline, supportsPagination: true),
    Sites.huyaSite: LiveSearchCapability(coverage: NativeSearchCoverage.liveOnly, supportsPagination: true),
    Sites.douyinSite: LiveSearchCapability(coverage: NativeSearchCoverage.liveOnly, supportsPagination: true),
    Sites.kuaishouSite: LiveSearchCapability(coverage: NativeSearchCoverage.webOnly, supportsPagination: false),
    Sites.ccSite: LiveSearchCapability(coverage: NativeSearchCoverage.liveAndOffline, supportsPagination: true),
    Sites.twitchSite: LiveSearchCapability(coverage: NativeSearchCoverage.liveAndOffline, supportsPagination: true),
    Sites.soopSite: LiveSearchCapability(coverage: NativeSearchCoverage.liveOnly, supportsPagination: true),
    Sites.yySite: LiveSearchCapability(coverage: NativeSearchCoverage.liveAndOffline, supportsPagination: true),
    Sites.acfunSite: LiveSearchCapability(coverage: NativeSearchCoverage.liveAndOffline, supportsPagination: true),
    Sites.picartoSite: LiveSearchCapability(coverage: NativeSearchCoverage.webOnly, supportsPagination: false),
    Sites.twitcastingSite: LiveSearchCapability(coverage: NativeSearchCoverage.webOnly, supportsPagination: false),
    Sites.missevanSite: LiveSearchCapability(
      coverage: NativeSearchCoverage.unavailable,
      supportsPagination: false,
      supportsWebSearch: false,
    ),
    Sites.openrecSite: LiveSearchCapability(
      coverage: NativeSearchCoverage.unavailable,
      supportsPagination: false,
      supportsWebSearch: false,
    ),
    Sites.huajiaoSite: LiveSearchCapability(
      coverage: NativeSearchCoverage.unavailable,
      supportsPagination: false,
      supportsWebSearch: false,
    ),
    Sites.kilakilaSite: LiveSearchCapability(
      coverage: NativeSearchCoverage.unavailable,
      supportsPagination: false,
      supportsWebSearch: false,
    ),
    Sites.inkeSite: LiveSearchCapability(
      coverage: NativeSearchCoverage.unavailable,
      supportsPagination: false,
      supportsWebSearch: false,
    ),
    Sites.iptvSite: LiveSearchCapability(
      coverage: NativeSearchCoverage.localChannels,
      supportsPagination: false,
      supportsWebSearch: false,
    ),
  };

  static const LiveSearchCapability _unknown = LiveSearchCapability(
    coverage: NativeSearchCoverage.webOnly,
    supportsPagination: false,
  );

  static LiveSearchCapability forPlatform(String id) => _byPlatform[id.toLowerCase()] ?? _unknown;
}
