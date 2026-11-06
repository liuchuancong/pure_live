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

/// A platform whose search works differently from its coverage's usual
/// reading, so the scope panel explains it in its own words.
enum SearchCoverageNote { kuaishou, acfun, twitcasting, kilakila, weibo, youtube }

/// One platform's search abilities (the reference's `LiveSearchCapability`).
final class SearchCapability {
  /// Creates the abilities.
  const SearchCapability({
    required this.coverage,
    required this.paged,
    this.webSearch = false,
    this.anchors = false,
    this.note,
  });

  /// What keywords find.
  final SearchCoverage coverage;

  /// Whether a keyword can have more than one page.
  final bool paged;

  /// Whether the platform's web search can be opened.
  final bool webSearch;

  /// Whether the adapter searches streamers.
  final bool anchors;

  /// A platform-specific explanation, replacing the one of [coverage].
  final SearchCoverageNote? note;

  /// Whether the app can search the platform itself.
  bool get native => coverage != SearchCoverage.webOnly && coverage != SearchCoverage.unavailable;

  /// Whether results can include offline rooms.
  bool get mayIncludeOffline =>
      coverage == SearchCoverage.liveAndOffline ||
      coverage == SearchCoverage.channelLookup ||
      coverage == SearchCoverage.roomLookup;
}

/// The abilities of every platform, ported from the reference's table; a
/// platform outside it is unavailable, not silently searchable.
abstract final class SearchCapabilities {
  static const Map<String, SearchCapability> _byPlatform = {
    'bilibili': SearchCapability(coverage: SearchCoverage.liveAndOffline, paged: true, webSearch: true, anchors: true),
    'douyu': SearchCapability(coverage: SearchCoverage.liveAndOffline, paged: true, webSearch: true, anchors: true),
    'huya': SearchCapability(coverage: SearchCoverage.liveOnly, paged: true, webSearch: true, anchors: true),
    'douyin': SearchCapability(coverage: SearchCoverage.liveOnly, paged: true, webSearch: true),
    'kuaishou': SearchCapability(
      coverage: SearchCoverage.liveAndOffline,
      paged: true,
      webSearch: true,
      anchors: true,
      note: SearchCoverageNote.kuaishou,
    ),
    'twitch': SearchCapability(coverage: SearchCoverage.liveAndOffline, paged: true, webSearch: true),
    'soop': SearchCapability(coverage: SearchCoverage.liveOnly, paged: true, webSearch: true),
    'yy': SearchCapability(coverage: SearchCoverage.liveOnly, paged: true, webSearch: true, anchors: true),
    'acfun': SearchCapability(
      coverage: SearchCoverage.liveAndOffline,
      paged: true,
      webSearch: true,
      anchors: true,
      note: SearchCoverageNote.acfun,
    ),
    'picarto': SearchCapability(coverage: SearchCoverage.liveAndOffline, paged: true, webSearch: true),
    'twitcasting': SearchCapability(
      coverage: SearchCoverage.liveOnly,
      paged: true,
      webSearch: true,
      note: SearchCoverageNote.twitcasting,
    ),
    'missevan': SearchCapability(coverage: SearchCoverage.liveAndOffline, paged: true),
    'inke': SearchCapability(coverage: SearchCoverage.showcaseSnapshot, paged: true),
    'kilakila': SearchCapability(
      coverage: SearchCoverage.liveAndOffline,
      paged: true,
      webSearch: true,
      note: SearchCoverageNote.kilakila,
    ),
    'xiaohongshu': SearchCapability(coverage: SearchCoverage.roomLookup, paged: false),
    'niconico': SearchCapability(coverage: SearchCoverage.liveOnly, paged: true, webSearch: true),
    'weibo': SearchCapability(coverage: SearchCoverage.roomLookup, paged: false, note: SearchCoverageNote.weibo),
    'showroom': SearchCapability(coverage: SearchCoverage.liveOnly, paged: true),
    'chzzk': SearchCapability(coverage: SearchCoverage.liveAndOffline, paged: true),
    'kick': SearchCapability(coverage: SearchCoverage.liveAndOffline, paged: false, webSearch: true),
    'liveme': SearchCapability(coverage: SearchCoverage.liveAndOffline, paged: true),
    'tiktok': SearchCapability(coverage: SearchCoverage.channelLookup, paged: false, webSearch: true),
    'youtube': SearchCapability(
      coverage: SearchCoverage.liveOnly,
      paged: true,
      webSearch: true,
      note: SearchCoverageNote.youtube,
    ),
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

/// What [capability] finds on the platform named [siteName]: the scope line
/// and the unsupported state read it; a platform with a [SearchCapability.note]
/// gets its own words.
String searchCoverageText(Translations t, SearchCapability capability, String siteName) {
  final note = capability.note;
  if (note != null) {
    return switch (note) {
      SearchCoverageNote.kuaishou => t.search.noteKuaishou,
      SearchCoverageNote.acfun => t.search.noteAcfun,
      SearchCoverageNote.twitcasting => t.search.noteTwitcasting,
      SearchCoverageNote.kilakila => t.search.noteKilakila,
      SearchCoverageNote.weibo => t.search.noteWeibo,
      SearchCoverageNote.youtube => t.search.noteYoutube,
    };
  }
  return switch (capability.coverage) {
    SearchCoverage.liveOnly => t.search.coverageLiveOnly(site: siteName),
    SearchCoverage.liveAndOffline => t.search.coverageLiveAndOffline(site: siteName),
    SearchCoverage.channelLookup => t.search.coverageChannelLookup(site: siteName),
    SearchCoverage.roomLookup => t.search.coverageRoomLookup(site: siteName),
    SearchCoverage.showcaseSnapshot => t.search.coverageShowcaseSnapshot(site: siteName),
    SearchCoverage.localChannels => t.search.coverageLocalChannels(site: siteName),
    SearchCoverage.webOnly || SearchCoverage.unavailable => t.search.coverageUnavailable(site: siteName),
  };
}

/// What [capability] finds, without the platform's name: one line of the
/// scope panel's rows.
String searchCoverageShortText(Translations t, SearchCapability capability) {
  final note = capability.note;
  if (note != null) {
    return switch (note) {
      SearchCoverageNote.kuaishou => t.search.noteKuaishouShort,
      SearchCoverageNote.acfun => t.search.noteAcfunShort,
      SearchCoverageNote.twitcasting => t.search.noteTwitcastingShort,
      SearchCoverageNote.kilakila => t.search.noteKilakilaShort,
      SearchCoverageNote.weibo => t.search.noteWeiboShort,
      SearchCoverageNote.youtube => t.search.noteYoutubeShort,
    };
  }
  return switch (capability.coverage) {
    SearchCoverage.liveOnly => t.search.coverageShortLiveOnly,
    SearchCoverage.liveAndOffline => t.search.coverageShortLiveAndOffline,
    SearchCoverage.channelLookup => t.search.coverageShortChannelLookup,
    SearchCoverage.roomLookup => t.search.coverageShortRoomLookup,
    SearchCoverage.showcaseSnapshot => t.search.coverageShortShowcase,
    SearchCoverage.localChannels => t.search.coverageShortLocal,
    SearchCoverage.webOnly || SearchCoverage.unavailable => t.search.coverageShortUnavailable,
  };
}
