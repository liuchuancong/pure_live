import 'package:pure_live/core/sites.dart';

enum NativeSearchCoverage { liveOnly, liveAndOffline, localChannels, webOnly }

class LiveSearchCapability {
  const LiveSearchCapability({required this.coverage, required this.supportsPagination, this.supportsWebSearch = true});

  final NativeSearchCoverage coverage;
  final bool supportsPagination;
  final bool supportsWebSearch;

  bool get supportsNativeSearch => coverage != NativeSearchCoverage.webOnly;
  bool get mayIncludeOffline => coverage == NativeSearchCoverage.liveAndOffline;
}

class LiveSearchCapabilities {
  const LiveSearchCapabilities._();

  static const Map<String, LiveSearchCapability> _byPlatform = {
    Sites.bilibiliSite: LiveSearchCapability(coverage: NativeSearchCoverage.liveAndOffline, supportsPagination: true),
    Sites.douyuSite: LiveSearchCapability(coverage: NativeSearchCoverage.liveAndOffline, supportsPagination: true),
    Sites.huyaSite: LiveSearchCapability(coverage: NativeSearchCoverage.liveOnly, supportsPagination: true),
    Sites.yySite: LiveSearchCapability(coverage: NativeSearchCoverage.liveOnly, supportsPagination: true),
    Sites.douyinSite: LiveSearchCapability(coverage: NativeSearchCoverage.liveOnly, supportsPagination: true),
    Sites.kuaishouSite: LiveSearchCapability(coverage: NativeSearchCoverage.webOnly, supportsPagination: false),
    Sites.ccSite: LiveSearchCapability(coverage: NativeSearchCoverage.liveAndOffline, supportsPagination: true),
    Sites.twitchSite: LiveSearchCapability(coverage: NativeSearchCoverage.liveAndOffline, supportsPagination: true),
    Sites.soopSite: LiveSearchCapability(coverage: NativeSearchCoverage.liveOnly, supportsPagination: true),
    Sites.yySite: LiveSearchCapability(coverage: NativeSearchCoverage.liveAndOffline, supportsPagination: true),
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
