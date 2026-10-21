import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:pure_live/system/configuration/preferences/values.dart';

/// How the feeds draw and refresh: the loading placeholder, the room card, the pager controls, the refresh interval and resume threshold, and the platform visibility and order — the reference's `page` and `roomCard` sections.
// ignore_for_file: unnecessary_type_name_in_constructor
@immutable
final class FeedPreferences extends Equatable {
  /// The shipping defaults.
  const new({
    this.autoRefreshMinutes = 0,
    this.liveAlertTagIds = const [],
    this.refreshResumeThresholdMinutes = 10,
    this.refreshConcurrency = 4,
    this.loadingStyle = LoadingStyle.shimmer,
    this.roomCardCornerRadius = 12,
    this.roomCardShowPlatform = true,
    this.roomCardShowAudience = true,
    this.roomCardShowAnchor = true,
    this.roomCardAspect = RoomCardCoverAspect.sixteenByNine,
    this.crossAxisSpacing = 6,
    this.mainAxisSpacing = 6,
    this.pageDefaultSize = 0,
    this.pageSizeOptions = '',
    this.pageShowScrollTop = true,
    this.pageShowSizeSelector = true,
    this.pageShowGoto = true,
    this.preferRealOnlineCounts = false,
    this.preferredSiteId = '',
    this.showUnplayableInDiscover = false,
    this.realOnlinePlatforms = defaultRealOnlinePlatforms,
    this.hiddenSiteIds = const [],
    this.siteOrder = const [],
  });

  /// Reads the domain's keys from the flat document; unknown shapes decode
  /// to the defaults.
  factory FeedPreferences.fromJson(Map<String, Object?> json) {
    return FeedPreferences(
      autoRefreshMinutes: json['autoRefreshMinutes'] as int? ?? 0,
      liveAlertTagIds: (json['liveAlertTagIds'] as List<Object?>?)?.whereType<String>().toList() ?? const [],
      refreshResumeThresholdMinutes: json['refreshResumeThresholdMinutes'] as int? ?? 10,
      refreshConcurrency: (json['refreshConcurrency'] as num?)?.toInt() ?? 4,
      loadingStyle: LoadingStyle.fromId(json['loadingStyle'] as String?),
      roomCardCornerRadius: (json['roomCardCornerRadius'] as num?)?.toDouble() ?? 12,
      roomCardShowPlatform: json['roomCardShowPlatform'] as bool? ?? true,
      roomCardShowAudience: json['roomCardShowAudience'] as bool? ?? true,
      roomCardShowAnchor: json['roomCardShowAnchor'] as bool? ?? true,
      roomCardAspect: RoomCardCoverAspect.fromId(json['roomCardAspect'] as String?),
      crossAxisSpacing: (json['crossAxisSpacing'] as num?)?.toDouble() ?? 6,
      mainAxisSpacing: (json['mainAxisSpacing'] as num?)?.toDouble() ?? 6,
      pageDefaultSize: (json['pageDefaultSize'] as num?)?.toInt() ?? 0,
      pageSizeOptions: json['pageSizeOptions'] as String? ?? '',
      pageShowScrollTop: json['pageShowScrollTop'] as bool? ?? true,
      pageShowSizeSelector: json['pageShowSizeSelector'] as bool? ?? true,
      pageShowGoto: json['pageShowGoto'] as bool? ?? true,
      preferRealOnlineCounts: json['preferRealOnlineCounts'] as bool? ?? false,
      preferredSiteId: json['preferredSiteId'] as String? ?? '',
      showUnplayableInDiscover: json['showUnplayableInDiscover'] as bool? ?? false,
      realOnlinePlatforms:
          (json['realOnlinePlatforms'] as List<Object?>?)?.whereType<String>().toList() ?? defaultRealOnlinePlatforms,
      hiddenSiteIds: (json['hiddenSiteIds'] as List<Object?>?)?.whereType<String>().toList() ?? const [],
      siteOrder: (json['siteOrder'] as List<Object?>?)?.whereType<String>().toList() ?? const [],
    );
  }

  /// The foreground feed refresh interval, in minutes; 0 is off.
  final int autoRefreshMinutes;

  /// The follow-tag ids 开播提醒 covers; empty covers every follow. A room
  /// that carries none of these tags never raises a notice.
  final List<String> liveAlertTagIds;

  /// How long the app must have been away, in minutes, before a resume
  /// counts as worth refreshing for.
  final int refreshResumeThresholdMinutes;

  /// How many followed rooms the refresh pass asks about at once (1–8);
  /// the reference's 首页并发刷新任务.
  final int refreshConcurrency;

  /// How a feed's first-load placeholder is drawn.
  final LoadingStyle loadingStyle;

  /// The room card's corner radius, in logical pixels.
  final double roomCardCornerRadius;

  /// Whether the room card draws its platform pill.
  final bool roomCardShowPlatform;

  /// Whether the room card draws its audience and status pills.
  final bool roomCardShowAudience;

  /// Whether the room card draws its anchor line (avatar and name).
  final bool roomCardShowAnchor;

  /// The room card cover's shape.
  final RoomCardCoverAspect roomCardAspect;

  /// The horizontal gap between the cards of one row, in logical pixels
  /// (3.x `crossAxisSpacing`, 0–64).
  final double crossAxisSpacing;

  /// The vertical gap between the cards of one column, in logical pixels
  /// (3.x `mainAxisSpacing`, 0–64).
  final double mainAxisSpacing;

  /// Rooms per desktop page; 0 picks the width answer (20 above 960 px,
  /// else 12) — the reference's `pageDefaultSize`.
  final int pageDefaultSize;

  /// The page-size choices as a comma-separated text; empty means the
  /// width rule (20/40/60/80 above 960 px, else 12/24/36/48) — the
  /// reference's `pageSizeOptions`.
  final String pageSizeOptions;

  /// Whether paged lists show the scroll-to-top/bottom buttons
  /// (`pageShowScrollTop`).
  final bool pageShowScrollTop;

  /// Whether the page bar offers the rooms-per-page menu
  /// (`pageShowSizeSelector`).
  final bool pageShowSizeSelector;

  /// Whether the page bar offers 'go to page' (`pageShowGotoButton`).
  final bool pageShowGoto;

  /// Whether a room on a trusted platform shows its concurrent-online figure
  /// as the headline audience number; off, the platform's own heat/popularity
  /// number leads (the reference's preferRealOnlineCounts).
  final bool preferRealOnlineCounts;

  /// The platform the discovery pages open on (the reference's 首选直播平台);
  /// empty keeps the first visible one.
  final String preferredSiteId;

  /// Whether the discovery pages show rooms that cannot play here — a
  /// carousel, or a restriction this client cannot pass (login, payment,
  /// members-only, region). Off hides them, as the reference does.
  final bool showUnplayableInDiscover;

  /// The platforms whose online figure is trusted (the reference's
  /// realOnlinePlatforms); the audience row of the video settings edits it.
  final List<String> realOnlinePlatforms;

  /// The platform ids the user hid from the platform list (3.x
  /// `Settings.hiddenSettingPlatforms`): hidden platforms are left out of
  /// popular, areas and search. An unknown id is simply never matched.
  final List<String> hiddenSiteIds;

  /// The user's manual platform order (3.x `Settings.hotAreasList` order);
  /// ids not listed keep their registry position after the listed ones.
  final List<String> siteOrder;

  /// The domain's keys as stored, flat.
  Map<String, Object?> toJson() => {
    'autoRefreshMinutes': autoRefreshMinutes,
    'liveAlertTagIds': liveAlertTagIds,
    'refreshResumeThresholdMinutes': refreshResumeThresholdMinutes,
    'refreshConcurrency': refreshConcurrency,
    'loadingStyle': loadingStyle.id,
    'roomCardCornerRadius': roomCardCornerRadius,
    'roomCardShowPlatform': roomCardShowPlatform,
    'roomCardShowAudience': roomCardShowAudience,
    'roomCardShowAnchor': roomCardShowAnchor,
    'roomCardAspect': roomCardAspect.id,
    'crossAxisSpacing': crossAxisSpacing,
    'mainAxisSpacing': mainAxisSpacing,
    'pageDefaultSize': pageDefaultSize,
    'pageSizeOptions': pageSizeOptions,
    'pageShowScrollTop': pageShowScrollTop,
    'pageShowSizeSelector': pageShowSizeSelector,
    'pageShowGoto': pageShowGoto,
    'preferRealOnlineCounts': preferRealOnlineCounts,
    'preferredSiteId': preferredSiteId,
    'showUnplayableInDiscover': showUnplayableInDiscover,
    'realOnlinePlatforms': realOnlinePlatforms,
    'hiddenSiteIds': hiddenSiteIds,
    'siteOrder': siteOrder,
  };

  /// Returns a copy with the given fields replaced.
  FeedPreferences copyWith({
    int? autoRefreshMinutes,
    List<String>? liveAlertTagIds,
    int? refreshResumeThresholdMinutes,
    int? refreshConcurrency,
    LoadingStyle? loadingStyle,
    double? roomCardCornerRadius,
    bool? roomCardShowPlatform,
    bool? roomCardShowAudience,
    bool? roomCardShowAnchor,
    RoomCardCoverAspect? roomCardAspect,
    double? crossAxisSpacing,
    double? mainAxisSpacing,
    int? pageDefaultSize,
    String? pageSizeOptions,
    bool? pageShowScrollTop,
    bool? pageShowSizeSelector,
    bool? pageShowGoto,
    bool? preferRealOnlineCounts,
    String? preferredSiteId,
    bool? showUnplayableInDiscover,
    List<String>? realOnlinePlatforms,
    List<String>? hiddenSiteIds,
    List<String>? siteOrder,
  }) => FeedPreferences(
    autoRefreshMinutes: autoRefreshMinutes ?? this.autoRefreshMinutes,
    liveAlertTagIds: liveAlertTagIds ?? this.liveAlertTagIds,
    refreshResumeThresholdMinutes: refreshResumeThresholdMinutes ?? this.refreshResumeThresholdMinutes,
    refreshConcurrency: refreshConcurrency ?? this.refreshConcurrency,
    loadingStyle: loadingStyle ?? this.loadingStyle,
    roomCardCornerRadius: roomCardCornerRadius ?? this.roomCardCornerRadius,
    roomCardShowPlatform: roomCardShowPlatform ?? this.roomCardShowPlatform,
    roomCardShowAudience: roomCardShowAudience ?? this.roomCardShowAudience,
    roomCardShowAnchor: roomCardShowAnchor ?? this.roomCardShowAnchor,
    roomCardAspect: roomCardAspect ?? this.roomCardAspect,
    crossAxisSpacing: crossAxisSpacing ?? this.crossAxisSpacing,
    mainAxisSpacing: mainAxisSpacing ?? this.mainAxisSpacing,
    pageDefaultSize: pageDefaultSize ?? this.pageDefaultSize,
    pageSizeOptions: pageSizeOptions ?? this.pageSizeOptions,
    pageShowScrollTop: pageShowScrollTop ?? this.pageShowScrollTop,
    pageShowSizeSelector: pageShowSizeSelector ?? this.pageShowSizeSelector,
    pageShowGoto: pageShowGoto ?? this.pageShowGoto,
    preferRealOnlineCounts: preferRealOnlineCounts ?? this.preferRealOnlineCounts,
    preferredSiteId: preferredSiteId ?? this.preferredSiteId,
    showUnplayableInDiscover: showUnplayableInDiscover ?? this.showUnplayableInDiscover,
    realOnlinePlatforms: realOnlinePlatforms ?? this.realOnlinePlatforms,
    hiddenSiteIds: hiddenSiteIds ?? this.hiddenSiteIds,
    siteOrder: siteOrder ?? this.siteOrder,
  );

  @override
  /// Every field, in declaration order.
  List<Object?> get props => [
    autoRefreshMinutes,
    liveAlertTagIds,
    refreshResumeThresholdMinutes,
    refreshConcurrency,
    loadingStyle,
    roomCardCornerRadius,
    roomCardShowPlatform,
    roomCardShowAudience,
    roomCardShowAnchor,
    roomCardAspect,
    crossAxisSpacing,
    mainAxisSpacing,
    pageDefaultSize,
    pageSizeOptions,
    pageShowScrollTop,
    pageShowSizeSelector,
    pageShowGoto,
    preferRealOnlineCounts,
    preferredSiteId,
    showUnplayableInDiscover,
    realOnlinePlatforms,
    hiddenSiteIds,
    siteOrder,
  ];
}
