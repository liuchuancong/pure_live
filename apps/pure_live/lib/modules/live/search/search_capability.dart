import 'package:pure_live/l10n/translations.dart';

/// What a platform's search can find (the reference's `NativeSearchCoverage`).
enum SearchCoverage {
  /// Keywords find rooms that are live now.
  liveOnly,

  /// Keywords find live rooms and some offline ones.
  liveAndOffline,

  /// Only an exact channel id or link; finds offline channels too.
  channelLookup,

  /// Only an exact room id or live link.
  roomLookup,

  /// Exact ids and links, otherwise a nickname filter over the platform's
  /// current showcase.
  showcaseSnapshot,

  /// The channels imported on this device.
  localChannels,

  /// No search in the app; the platform's web search only.
  webOnly,

  /// No search at all.
  unavailable,
}

/// One platform's search abilities (the reference's `LiveSearchCapability`).
final class SearchCapability {
  /// Creates the abilities.
  const SearchCapability({required this.coverage, required this.paged, this.webSearch = false, this.anchors = false});

  /// What keywords find.
  final SearchCoverage coverage;

  /// Whether a keyword can have more than one page.
  final bool paged;

  /// Whether the platform's web search can be opened.
  final bool webSearch;

  /// Whether the adapter searches streamers.
  final bool anchors;

  /// Whether the app can search the platform itself.
  bool get native => coverage != SearchCoverage.webOnly && coverage != SearchCoverage.unavailable;
}

/// The abilities of every platform, ported from the reference's table; a
/// platform outside it is unavailable, not silently searchable.
abstract final class SearchCapabilities {
  static const Map<String, SearchCapability> _byPlatform = {
    'bilibili': SearchCapability(coverage: SearchCoverage.liveAndOffline, paged: true, webSearch: true, anchors: true),
    'douyu': SearchCapability(coverage: SearchCoverage.liveAndOffline, paged: true, webSearch: true, anchors: true),
    'huya': SearchCapability(coverage: SearchCoverage.liveOnly, paged: true, webSearch: true, anchors: true),
    'douyin': SearchCapability(coverage: SearchCoverage.liveOnly, paged: true, webSearch: true),
    'kuaishou': SearchCapability(coverage: SearchCoverage.liveAndOffline, paged: true, webSearch: true, anchors: true),
    'twitch': SearchCapability(coverage: SearchCoverage.liveAndOffline, paged: true, webSearch: true),
    'soop': SearchCapability(coverage: SearchCoverage.liveOnly, paged: true, webSearch: true),
    'yy': SearchCapability(coverage: SearchCoverage.liveOnly, paged: true, webSearch: true, anchors: true),
    'acfun': SearchCapability(coverage: SearchCoverage.liveAndOffline, paged: true, webSearch: true, anchors: true),
    'picarto': SearchCapability(coverage: SearchCoverage.liveAndOffline, paged: true, webSearch: true),
    'twitcasting': SearchCapability(coverage: SearchCoverage.liveOnly, paged: true, webSearch: true),
    'missevan': SearchCapability(coverage: SearchCoverage.liveAndOffline, paged: true),
    'inke': SearchCapability(coverage: SearchCoverage.showcaseSnapshot, paged: true),
    'kilakila': SearchCapability(coverage: SearchCoverage.liveAndOffline, paged: true, webSearch: true),
    'xiaohongshu': SearchCapability(coverage: SearchCoverage.roomLookup, paged: false),
    'niconico': SearchCapability(coverage: SearchCoverage.liveOnly, paged: true, webSearch: true),
    'weibo': SearchCapability(coverage: SearchCoverage.roomLookup, paged: false),
    'showroom': SearchCapability(coverage: SearchCoverage.liveOnly, paged: true),
    'chzzk': SearchCapability(coverage: SearchCoverage.liveAndOffline, paged: true),
    'kick': SearchCapability(coverage: SearchCoverage.liveAndOffline, paged: false),
    'liveme': SearchCapability(coverage: SearchCoverage.liveAndOffline, paged: true),
    'tiktok': SearchCapability(coverage: SearchCoverage.channelLookup, paged: false),
    'youtube': SearchCapability(coverage: SearchCoverage.liveOnly, paged: true),
    'bigo': SearchCapability(coverage: SearchCoverage.showcaseSnapshot, paged: false),
    'pandalive': SearchCapability(coverage: SearchCoverage.liveAndOffline, paged: true),
    'fc2live': SearchCapability(coverage: SearchCoverage.liveAndOffline, paged: true),
    'steambroadcast': SearchCapability(coverage: SearchCoverage.liveAndOffline, paged: true),
    'jdlive': SearchCapability(coverage: SearchCoverage.liveAndOffline, paged: true),
    'kugoulive': SearchCapability(coverage: SearchCoverage.liveAndOffline, paged: true),
    'baidulive': SearchCapability(coverage: SearchCoverage.roomLookup, paged: false),
    'sixroom': SearchCapability(coverage: SearchCoverage.liveAndOffline, paged: false),
    '17live': SearchCapability(coverage: SearchCoverage.liveOnly, paged: false),
    'iptv': SearchCapability(coverage: SearchCoverage.localChannels, paged: false),
  };

  static const SearchCapability _unknown = SearchCapability(coverage: SearchCoverage.unavailable, paged: false);

  /// The abilities of [platform] (case ignored); unknown platforms cannot be
  /// searched.
  static SearchCapability of(String platform) => _byPlatform[platform.trim().toLowerCase()] ?? _unknown;
}

/// One line on what [capability] finds; the scope panel and the scope line
/// both read it.
String searchCoverageText(Translations t, SearchCapability capability) => switch (capability.coverage) {
  SearchCoverage.liveOnly => t.search.coverageLiveOnly,
  SearchCoverage.liveAndOffline => t.search.coverageLiveAndOffline,
  SearchCoverage.channelLookup => t.search.coverageChannelLookup,
  SearchCoverage.roomLookup => t.search.coverageRoomLookup,
  SearchCoverage.showcaseSnapshot => t.search.coverageShowcaseSnapshot,
  SearchCoverage.localChannels => t.search.coverageLocalChannels,
  SearchCoverage.webOnly => t.search.coverageWebOnly,
  SearchCoverage.unavailable => t.search.coverageUnavailable,
};
