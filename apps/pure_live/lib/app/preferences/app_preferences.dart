import 'dart:async';

import 'package:flutter/foundation.dart' show immutable;
import 'package:live_net/live_net.dart' show HttpProxyRoute, ProxyPolicy, ProxyRoute;
import 'package:live_storage/live_storage.dart' show StorageRepository;

/// Where the general-preferences document is persisted.
///
/// One document per preference group in the shared `settings.preferences` box,
/// versioned in its key — the same discipline the appearance and shell
/// documents follow, so a reshaped document resets only its own group.
abstract final class AppPreferenceKeys {
  /// The box every preference group document lives in (`settings.preferences`).
  static const String box = 'settings.preferences';

  /// The general-preferences group key.
  static const String document = 'preferences.app.v1';
}

/// The branch the router starts on, when the last visited one is not asked
/// for (`restoreLastTab` off).
enum AppLaunchBranch {
  /// The followed streamers' grid — the shipping default, the reference's
  /// first tab.
  follow,

  /// The popular / super-deal grid.
  popular,

  /// The areas catalogue.
  areas,

  /// The recording centre.
  record;

  /// Resolves a stored identifier. A document written before the shell took
  /// the reference's tab set (which named a `home` launcher and a `history`
  /// branch) lands on the favorites branch rather than losing the choice.
  static AppLaunchBranch fromId(String? id) => switch (id) {
    'popular' => AppLaunchBranch.popular,
    'areas' => AppLaunchBranch.areas,
    'record' => AppLaunchBranch.record,
    _ => AppLaunchBranch.follow,
  };

  /// The stable identifier persisted in the document.
  String get id => name;
}

/// How a list feed's first-load placeholder is drawn.
enum LoadingStyle {
  /// The bone grid, shimmering (the shipping default).
  shimmer,

  /// A centred spinner.
  spinner,

  /// Nothing — the page stays blank until content arrives.
  none;

  /// Resolves a stored identifier; an unknown one falls back to [shimmer].
  static LoadingStyle fromId(String? id) => switch (id) {
    'spinner' => LoadingStyle.spinner,
    'none' => LoadingStyle.none,
    _ => LoadingStyle.shimmer,
  };

  /// The stable identifier persisted in the document.
  String get id => name;
}

/// The room-card cover's shape.
enum RoomCardCoverAspect {
  /// 16:9 — the shipping default, one video frame tall.
  sixteenByNine(16 / 9),

  /// 4:3 — a taller, closer cover.
  fourByThree(4 / 3),

  /// 1:1 — the square cover.
  square(1);

  new(this.ratio);

  /// The aspect as width / height, what `AspectRatio` and the grid metrics
  /// consume.
  final double ratio;

  /// The [RoomCardCoverAspect] whose ratio is closest to [ratio] — how a
  /// stored double round-trips through the chooser.
  static RoomCardCoverAspect of(double ratio) =>
      values.reduce((best, aspect) => (aspect.ratio - ratio).abs() < (best.ratio - ratio).abs() ? aspect : best);

  /// Resolves a stored identifier; an unknown one falls back to
  /// [sixteenByNine].
  static RoomCardCoverAspect fromId(String? id) => switch (id) {
    'fourByThree' => RoomCardCoverAspect.fourByThree,
    'square' => RoomCardCoverAspect.square,
    _ => RoomCardCoverAspect.sixteenByNine,
  };

  /// The stable identifier persisted in the document.
  String get id => name;
}

/// The shell branches, in the order the chromes render them — the visible
/// subset. The home branch is the floor: a shell with no destination cannot
/// be walked, so every writer keeps at least one id.
const List<String> defaultShellBranches = ['follow', 'popular', 'areas', 'record'];

/// The platforms whose concurrent-online figure is trusted, as the reference
/// `Settings.realOnlinePlatforms` ships them (3.x's audience audit); the
/// audience settings row starts here and every check-box rewrites it.
const List<String> defaultRealOnlinePlatforms = [
  'douyin',
  'kuaishou',
  'cc',
  'twitch',
  'soop',
  'acfun',
  'picarto',
  'twitcasting',
];

/// The app's general choices — general, refresh, page, navigation, proxy,
/// loading and room-card preferences — as one persisted document.
///
/// Plain fields, like the shell document: the shape is closed, an unknown
/// stored value decodes to its enum's default, and [copyWith] is written by
/// hand so a rename fails to compile instead of regenerating silently.
///
/// The `new` shorthand is reserved for the constructor name; the fromJson
/// factory and [copyWith] spell the class name, which the lint otherwise
/// asks to shorten.
// ignore_for_file: unnecessary_type_name_in_constructor
@immutable
final class AppPreferences {
  /// The shipping defaults.
  const new({
    this.refreshOnResume = true,
    this.danmakuVisible = true,
    this.volumeMuted = false,
    this.defaultMobileVolume = 0.5,
    this.defaultDesktopVolume = 1,
    this.localInteractionEnabled = false,
    this.localInteractionUserName = '',
    this.localInteractionColor = 0xFFFFFFFF,
    this.barrageFontSize = 15,
    this.barrageOpacity = 1,
    this.barrageArea = 1,
    this.barrageTopArea = 0,
    this.barrageBottomArea = 0,
    this.barrageSpeed = 120,
    this.barrageFontWeight = 600,
    this.barrageStroke = true,
    this.barrageStrokeWidth = 3,
    this.barrageShowSender = true,
    this.barrageMaxVisible = 48,
    this.barrageFps = 30,
    this.barrageNoEmoji = false,
    this.barrageCollapse = false,
    this.barrageCollapseWindow = 5,
    this.barragePausedBehavior = 'pause',
    this.barrageAutoFps = true,
    this.barrageFpsMode = 'powerSaving',
    this.barrageShowGifts = false,
    this.barrageTapAction = true,
    this.barrageLongPressAction = true,
    this.barrageFontFamily = '',
    this.backupDirectory = '',
    this.barrageHoldOnPress = false,
    this.barrageListFontSize = 13,
    this.barrageListLineSpacing = 4,
    this.barrageListStyle = 'compact',
    this.barrageTemplate = '',
    this.preferResolution = '原画',
    this.preferResolutionCellular = '原画',
    this.preferH264 = true,
    this.videoFitIndex = 0,
    this.openRoomFullscreen = false,
    this.preferRealOnlineCounts = false,
    this.realOnlinePlatforms = defaultRealOnlinePlatforms,
    this.portraitAdapt = true,
    this.portraitAdaptiveHeight = true,
    this.portraitLayoutMode = 'balanced',
    this.portraitFullscreenPolicy = 'followSource',
    this.portraitDisplayMode = 'ambient',
    this.portraitDanmakuMode = 'followGlobal',
    this.rememberPortraitRoomOverride = true,
    this.showPortraitDiagnostics = false,
    this.portraitRoomOverrides = const {},
    this.pipAlwaysOnTop = false,
    this.miniRememberPosition = true,
    this.miniWindowRect = '',
    this.pauseOnPipClose = false,
    this.showSplash = true,
    this.githubOnlyUpdates = false,
    this.detectClipboardRooms = true,
    this.startAtLogin = false,
    this.cacheMaxMB = 1024,
    this.cacheAutoClear = false,
    this.cacheKeepDays = 7,
    this.cacheKeepCount = 500,
    this.autoRefreshThumbnails = false,
    this.thumbnailRefreshMinutes = 30,
    this.thumbnailKeepOldFiles = false,
    this.playerProxyEnabled = false,
    this.playerProxyHost = '127.0.0.1',
    this.playerProxyPort = 7890,
    this.audioOutputDriver = 'auto',
    this.hardwareDecoder = 'auto',
    this.frameInterpolation = false,
    this.scaler = 'auto',
    this.deinterlace = 'auto',
    this.streamCacheSeconds = 0,
    this.customPlayerOutput = false,
    this.languageId = '',
    this.autoCheckUpdate = true,
    this.countdownCloseEnabled = false,
    this.countdownCloseMinutes = 60,
    this.launchBranch = AppLaunchBranch.follow,
    this.restoreLastTab = false,
    this.lastBranchId,
    this.windowWidth = 0,
    this.windowHeight = 0,
    this.autoRefreshMinutes = 0,
    this.refreshResumeThresholdMinutes = 10,
    this.proxyEnabled = false,
    this.proxyHost = '127.0.0.1',
    this.proxyPort = 7890,
    this.loadingStyle = LoadingStyle.shimmer,
    this.roomCardCornerRadius = 12,
    this.roomCardShowPlatform = true,
    this.roomCardShowAudience = true,
    this.roomCardShowAnchor = true,
    this.roomCardAspect = RoomCardCoverAspect.sixteenByNine,
    this.shellBranches = defaultShellBranches,
    this.hiddenSiteIds = const [],
    this.siteOrder = const [],
    this.logLevelId = '',
    this.historyLimit = 50,
    this.pageDefaultSize = 0,
    this.pageSizeOptions = '',
    this.pageShowScrollTop = true,
    this.pageShowSizeSelector = true,
    this.pageShowGoto = true,
  });

  /// Reads the document; unknown shapes decode to the defaults.
  factory AppPreferences.fromJson(Map<String, Object?> json) {
    final branches = (json['shellBranches'] as List<Object?>?)?.whereType<String>().toList();
    // The one volume field a pre-split document stored seeds both answers;
    // after that the mobile and desktop levels are kept apart, the way the
    // reference's volume dialog edits and reads them.
    final legacyVolume = (json['defaultVolume'] as num?)?.toDouble();
    return AppPreferences(
      refreshOnResume: json['refreshOnResume'] as bool? ?? true,
      danmakuVisible: json['danmakuVisible'] as bool? ?? true,
      volumeMuted: json['volumeMuted'] as bool? ?? false,
      defaultMobileVolume: (json['defaultMobileVolume'] as num?)?.toDouble() ?? legacyVolume ?? 0.5,
      defaultDesktopVolume: (json['defaultDesktopVolume'] as num?)?.toDouble() ?? legacyVolume ?? 1,
      localInteractionEnabled: json['localInteractionEnabled'] as bool? ?? false,
      localInteractionUserName: json['localInteractionUserName'] as String? ?? '',
      localInteractionColor: (json['localInteractionColor'] as num?)?.toInt() ?? 0xFFFFFFFF,
      barrageFontSize: (json['barrageFontSize'] as num?)?.toDouble() ?? 15,
      barrageOpacity: (json['barrageOpacity'] as num?)?.toDouble() ?? 1,
      barrageArea: (json['barrageArea'] as num?)?.toDouble() ?? 1,
      barrageTopArea: (json['barrageTopArea'] as num?)?.toDouble() ?? 0,
      barrageBottomArea: (json['barrageBottomArea'] as num?)?.toDouble() ?? 0,
      barrageSpeed: (json['barrageSpeed'] as num?)?.toDouble() ?? 120,
      barrageFontWeight: (json['barrageFontWeight'] as num?)?.toInt() ?? 600,
      barrageStroke: json['barrageStroke'] as bool? ?? true,
      barrageStrokeWidth: (json['barrageStrokeWidth'] as num?)?.toDouble() ?? 3,
      barrageShowSender: json['barrageShowSender'] as bool? ?? true,
      barrageMaxVisible: (json['barrageMaxVisible'] as num?)?.toInt() ?? 48,
      barrageFps: (json['barrageFps'] as num?)?.toInt() ?? 30,
      barrageNoEmoji: json['barrageNoEmoji'] as bool? ?? false,
      barrageCollapse: json['barrageCollapse'] as bool? ?? false,
      barrageCollapseWindow: (json['barrageCollapseWindow'] as num?)?.toInt() ?? 5,
      barragePausedBehavior: json['barragePausedBehavior'] as String? ?? 'pause',
      barrageAutoFps: json['barrageAutoFps'] as bool? ?? true,
      barrageFpsMode: json['barrageFpsMode'] as String? ?? 'powerSaving',
      barrageShowGifts: json['barrageShowGifts'] as bool? ?? false,
      barrageTapAction: json['barrageTapAction'] as bool? ?? true,
      barrageLongPressAction: json['barrageLongPressAction'] as bool? ?? true,
      barrageFontFamily: json['barrageFontFamily'] as String? ?? '',
      backupDirectory: json['backupDirectory'] as String? ?? '',
      barrageHoldOnPress: json['barrageHoldOnPress'] as bool? ?? false,
      barrageListFontSize: (json['barrageListFontSize'] as num?)?.toDouble() ?? 13,
      barrageListLineSpacing: (json['barrageListLineSpacing'] as num?)?.toDouble() ?? 4,
      barrageListStyle: json['barrageListStyle'] as String? ?? 'compact',
      barrageTemplate: json['barrageTemplate'] as String? ?? '',
      preferResolution: json['preferResolution'] as String? ?? '原画',
      preferResolutionCellular: json['preferResolutionCellular'] as String? ?? '原画',
      preferH264: json['preferH264'] as bool? ?? true,
      videoFitIndex: (json['videoFitIndex'] as num?)?.toInt() ?? 0,
      openRoomFullscreen: json['openRoomFullscreen'] as bool? ?? false,
      preferRealOnlineCounts: json['preferRealOnlineCounts'] as bool? ?? false,
      realOnlinePlatforms:
          (json['realOnlinePlatforms'] as List<Object?>?)?.whereType<String>().toList() ?? defaultRealOnlinePlatforms,
      // The mpv tuning answers. The defaults are what the engine did before
      // this page existed — auto for everything, no interpolation, the
      // adapter's own cache — so an existing document keeps behaving the same.
      audioOutputDriver: json['audioOutputDriver'] as String? ?? 'auto',
      hardwareDecoder: json['hardwareDecoder'] as String? ?? 'auto',
      frameInterpolation: json['frameInterpolation'] as bool? ?? false,
      scaler: json['scaler'] as String? ?? 'auto',
      deinterlace: json['deinterlace'] as String? ?? 'auto',
      streamCacheSeconds: (json['streamCacheSeconds'] as num?)?.toInt() ?? 0,
      customPlayerOutput: json['customPlayerOutput'] as bool? ?? false,
      languageId: json['languageId'] as String? ?? '',
      autoCheckUpdate: json['autoCheckUpdate'] as bool? ?? true,
      countdownCloseEnabled: json['countdownCloseEnabled'] as bool? ?? false,
      countdownCloseMinutes: json['countdownCloseMinutes'] as int? ?? 60,
      launchBranch: AppLaunchBranch.fromId(json['launchBranch'] as String?),
      restoreLastTab: json['restoreLastTab'] as bool? ?? false,
      lastBranchId: json['lastBranchId'] as String?,
      windowWidth: json['windowWidth'] as int? ?? 0,
      windowHeight: json['windowHeight'] as int? ?? 0,
      autoRefreshMinutes: json['autoRefreshMinutes'] as int? ?? 0,
      refreshResumeThresholdMinutes: json['refreshResumeThresholdMinutes'] as int? ?? 10,
      proxyEnabled: json['proxyEnabled'] as bool? ?? false,
      proxyHost: json['proxyHost'] as String? ?? '127.0.0.1',
      proxyPort: json['proxyPort'] as int? ?? 7890,
      loadingStyle: LoadingStyle.fromId(json['loadingStyle'] as String?),
      roomCardCornerRadius: (json['roomCardCornerRadius'] as num?)?.toDouble() ?? 12,
      roomCardShowPlatform: json['roomCardShowPlatform'] as bool? ?? true,
      roomCardShowAudience: json['roomCardShowAudience'] as bool? ?? true,
      roomCardShowAnchor: json['roomCardShowAnchor'] as bool? ?? true,
      roomCardAspect: RoomCardCoverAspect.fromId(json['roomCardAspect'] as String?),
      shellBranches: branches == null || branches.isEmpty ? defaultShellBranches : branches,
      hiddenSiteIds: (json['hiddenSiteIds'] as List<Object?>?)?.whereType<String>().toList() ?? const [],
      siteOrder: (json['siteOrder'] as List<Object?>?)?.whereType<String>().toList() ?? const [],
      logLevelId: json['logLevelId'] as String? ?? '',
      historyLimit: (json['historyLimit'] as num?)?.toInt() ?? 50,
      pageDefaultSize: (json['pageDefaultSize'] as num?)?.toInt() ?? 0,
      pageSizeOptions: json['pageSizeOptions'] as String? ?? '',
      pageShowScrollTop: json['pageShowScrollTop'] as bool? ?? true,
      pageShowSizeSelector: json['pageShowSizeSelector'] as bool? ?? true,
      pageShowGoto: json['pageShowGoto'] as bool? ?? true,
    );
  }

  /// Whether a feed refreshes when the app comes back to the foreground.
  final bool refreshOnResume;

  /// Whether a room draws the barrage over its video. The reference's
  /// `danmaku.hideDanmaku`, inverted: the switch says what is on.
  final bool danmakuVisible;

  /// The volume a room starts at on a touch phone, 0..1 — the reference's
  /// `vol.defaultMobileVolume`, one of the two answers its volume dialog edits.
  final double defaultMobileVolume;

  /// The volume a room starts at on a desktop window, 0..1.
  final double defaultDesktopVolume;

  /// Whether every room opens silenced, the reference's `vol.globalVolumeMute`.
  /// The level itself survives the mute; un-muting returns to it.
  final bool volumeMuted;

  /// Whether the room's local-interaction composer and bus are live — the
  /// reference's `localInteraction.enabled` gate on the same feature.
  final bool localInteractionEnabled;

  /// The name the local messages carry. Empty draws the localized "me".
  final String localInteractionUserName;

  /// The colour local messages are drawn in, packed ARGB.
  final int localInteractionColor;

  /// The barrage text size, in logical pixels.
  final double barrageFontSize;

  /// The barrage text opacity, 0..1.
  final double barrageOpacity;

  /// The share of the video the flying barrage may use, 0..1 — the
  /// reference's `danmakuArea`.
  final double barrageArea;

  /// The blank band kept under the top edge, in logical pixels
  /// (`danmakuTopArea`).
  final double barrageTopArea;

  /// The blank band kept above the bottom edge, in logical pixels
  /// (`danmakuBottomArea`).
  final double barrageBottomArea;

  /// How fast a line crosses, in pixels per second (`danmakuSpeed`).
  final double barrageSpeed;

  /// The barrage text weight, a CSS weight (100..900, `danmakuFontWeight`).
  final int barrageFontWeight;

  /// Whether the barrage text carries its dark outline (`enableDanmakuStroke`).
  final bool barrageStroke;

  /// The outline's blur radius, the stroke width (`danmakuFontBorder`).
  final double barrageStrokeWidth;

  /// Whether the sender's name rides in front of the line (`showChatNames`).
  final bool barrageShowSender;

  /// How many lines may fly at once (`danmakuMaxVisibleCount`).
  final int barrageMaxVisible;

  /// The repaint rate of the flying barrage, 25..240 FPS
  /// (`danmakuFps`; the automatic variant follows the display in the
  /// reference — this build drives the manual answer).
  final int barrageFps;

  /// Whether emote-only chats are dropped (`noEmojiMode`).
  final bool barrageNoEmoji;

  /// Whether an identical chat seen again inside [barrageCollapseWindow]
  /// keeps only its first copy (`collapseRepeatedDanmaku`).
  final bool barrageCollapse;

  /// The collapse window in seconds, 1..30 (`repeatedDanmakuWindowSeconds`).
  final int barrageCollapseWindow;

  /// What the barrage does while the video is paused: `pause` holds every
  /// line in place, `fly` lets it cross on (`danmakuPausedBehavior`).
  final String barragePausedBehavior;

  /// Whether the repaint clock follows the display instead of the manual
  /// number (the reference's danmakuAutoFps; true ships it there).
  final bool barrageAutoFps;

  /// What the automatic clock may reach: `powerSaving`/`balanced` cap at 60,
  /// `performance` lets the display's own maximum through (the reference's
  /// refreshRateMode trio).
  final String barrageFpsMode;

  /// Whether the platform's gift messages fly over the picture beside the
  /// chat (A08.12; off keeps the surface chat-only).
  final bool barrageShowGifts;

  /// Whether tapping a flying line opens its sender's card (画面弹幕交互).
  final bool barrageTapAction;

  /// Whether long-pressing a flying line offers to block its sender.
  final bool barrageLongPressAction;

  /// The danmaku font family registered from the font library; '' is the
  /// system default.
  final String barrageFontFamily;

  /// Where backups are written and listed: the reference's
  /// `Settings.backupDirectory`; '' takes the data area's own backups
  /// tree (the app's default folder).
  final String backupDirectory;

  /// Whether pressing the picture holds the lines under the finger
  /// (`holdDanmakuOnPress`).
  final bool barrageHoldOnPress;

  /// The chat list's text size (`danmakuListFontSize`).
  final double barrageListFontSize;

  /// The chat list's line spacing (`danmakuListLineSpacing`).
  final double barrageListLineSpacing;

  /// The chat list's look: `compact` rows or `card` bubbles
  /// (`danmakuListStyle`).
  final String barrageListStyle;

  /// The viewer's own saved barrage look, a `key=value;` string; empty when
  /// nothing was saved yet (`savedDanmakuTemplate`).
  final String barrageTemplate;

  /// The quality name to open a room with on Wi-Fi — one of
  /// `playQualityNames`, matched against the platform's own quality labels
  /// (the reference's preferResolution).
  final String preferResolution;

  /// The same answer for a cellular connection; the reference keeps a
  /// separate one so a metered network can start lower.
  final String preferResolutionCellular;

  /// Whether an HEVC-labelled quality is passed over while the room offers
  /// anything else (the reference's "优先 H.264 编码"); HEVC stays one menu tap
  /// away either way.
  final bool preferH264;

  /// Index into the six viewport fits (default, crop, fill, height, width,
  /// scale-down) a room opens with; anything out of range reads 0.
  final int videoFitIndex;

  /// Whether the room walks itself into fullscreen once the stream starts
  /// playing (the reference's "自动全屏").
  final bool openRoomFullscreen;

  /// Whether a room on a trusted platform shows its concurrent-online figure
  /// as the headline audience number; off, the platform's own heat/popularity
  /// number leads (the reference's preferRealOnlineCounts).
  final bool preferRealOnlineCounts;

  /// The platforms whose online figure is trusted (the reference's
  /// realOnlinePlatforms); the audience row of the video settings edits it.
  final List<String> realOnlinePlatforms;

  /// Whether a decoded tall frame re-dresses the room for a vertical stream
  /// (the reference's 智能识别竖屏直播源); off, every source plays in the
  /// plain landscape stack.
  final bool portraitAdapt;

  /// Whether the sheet's ceiling follows the body — a tall source gets the
  /// bigger watch area while the chat list keeps its room (the reference's
  /// portraitAdaptiveHeight). Off, the panel sits fixed at the middle stop.
  final bool portraitAdaptiveHeight;

  /// The normal-page shape for a vertical source: `balanced` (sheet over the
  /// full-bleed picture), `immersive` (same, opening at the lowest panel),
  /// `compatibility` (the plain letterboxed stack, like landscape rooms).
  final String portraitLayoutMode;

  /// Which direction a fullscreen entry takes for a vertical source:
  /// `followSource` keeps the picture upright (portrait fullscreen),
  /// `followSystem` defers to the device, `landscape` always turns the
  /// sideways room.
  final String portraitFullscreenPolicy;

  /// The portrait-fullscreen canvas: `complete` (no backdrop, the fitted
  /// picture), `ambient` (blurred cover behind it — the reference's own
  /// default), `balanced` (ambient, lighter veil), `cover` (cropped to fill).
  final String portraitDisplayMode;

  /// How the flying barrage is bounded over a vertical source's picture:
  /// `followGlobal`, `upperQuarter` (top quarter only), `reduced` (half the
  /// rows), `hidden`; it bounds the overlay, never the global style numbers.
  final String portraitDanmakuMode;

  /// Whether a direction picked by hand in the player is remembered for the
  /// room (the reference's portraitRoomOverrides).
  final bool rememberPortraitRoomOverride;

  /// Whether the picture shows the detection read-out — source size, ratio
  /// and the rule in force (the reference's 显示识别状态).
  final bool showPortraitDiagnostics;

  /// The per-room direction overrides: room key to `portrait`/`landscape`.
  final Map<String, String> portraitRoomOverrides;

  /// Whether the desktop picture-in-picture tile stays above the other
  /// windows (the reference's 小窗始终置顶).
  final bool pipAlwaysOnTop;

  /// Whether the free-floating mini window re-opens where it was last left
  /// (the reference's rememberPipPosition). Off, every entry starts at the
  /// corner the driver chooses.
  final bool miniRememberPosition;

  /// The last mini-window geometry as `x,y,w,h`; '' is never-left. Written
  /// only while [miniRememberPosition] is on.
  final String miniWindowRect;

  /// Whether closing the window while it is a PiP/mini tile pauses playback
  /// (the reference's pauseOnPipClose) instead of letting the stream run
  /// behind a hidden window.
  final bool pauseOnPipClose;

  /// Whether the start-up splash holds its two seconds of branding before it
  /// hands over (the reference's showSplashPage); off goes straight to the
  /// launch page.
  final bool showSplash;

  /// Whether the update feed asks GitHub only (the reference's
  /// useGitHubOriginForUpdates); off races the release assets through the
  /// mirrors first, GitHub as the last door — the shape for networks where
  /// GitHub is the slow one.
  final bool githubOnlyUpdates;

  /// Whether a room link found on the clipboard at resume is offered as a
  /// jump (the reference's detectClipboardRooms; 3.x always looked).
  final bool detectClipboardRooms;

  /// The stored answer behind the desktop 开机自启 row; the truth is read
  /// from the OS, and the row rewrites the store when the OS refuses.
  final bool startAtLogin;

  /// The picture cache's ceiling in MB (the reference's currentCacheSize
  /// display pairs with it); 0 or negative means no cap.
  final int cacheMaxMB;

  /// Whether the cache prunes itself when it crosses [cacheMaxMB] after a
  /// resume (the reference's automatic cache-clear answer).
  final bool cacheAutoClear;

  /// How many days a pruned cache may keep pictures for (1..90).
  final int cacheKeepDays;

  /// How many files a pruned cache may keep (100..2000).
  final int cacheKeepCount;

  /// Whether room covers re-pull on a timer (the reference's
  /// autoRefreshThumbnails); off, a cover is fetched once and kept.
  final bool autoRefreshThumbnails;

  /// Minutes between cover re-pulls (5..360, the reference's
  /// thumbnailRefreshInterval); the bucket lands in the cover URL, so every
  /// window reads as a new address once and only once.
  final int thumbnailRefreshMinutes;

  /// Whether a cover refresh keeps the superseded pictures instead of
  /// letting the cache drop them (the reference's thumbnailKeepOldFiles).
  final bool thumbnailKeepOldFiles;

  /// The player's own proxy (the reference's 播放器代理): mpv pulls the live
  /// stream through `http://host:port`, separate from the app's own HTTP
  /// proxy because the two often want different doors.
  final bool playerProxyEnabled;

  /// The player proxy's host.
  final String playerProxyHost;

  /// The player proxy's port (1..65535 as the field page validates it).
  final int playerProxyPort;

  /// Whether the stored audio output driver is used at all; off, the engine's
  /// own platform default answers — the reference's `customPlayerOutput` gate.
  ///
  /// There is no video-output answer any more: media_kit renders through mpv's
  /// `libmpv` output, and writing any other value leaves the embedded surface
  /// with no frames at all.
  final bool customPlayerOutput;

  /// mpv `ao` — the audio output driver.
  final String audioOutputDriver;

  /// mpv `hwdec` — the hardware decoder, `auto` letting mpv choose.
  final String hardwareDecoder;

  /// mpv `interpolation` — frame blending; desktop only, the reference's
  /// own gate on the cost.
  final bool frameInterpolation;

  /// mpv `scale` — the upscaling filter; `auto` keeps mpv's default.
  final String scaler;

  /// mpv `deinterlace`.
  final String deinterlace;

  /// mpv `cache`/`cache-secs` — the streaming read-ahead in seconds; 0 leaves
  /// the adapter's own cache settings untouched.
  final int streamCacheSeconds;

  /// The interface language: an empty id follows the system, otherwise a slang
  /// locale code (`zh`, `en`). Frozen at boot — the whole tree is translated by
  /// the delegate the app builds before the first frame.
  final String languageId;

  /// Whether the home page checks the release feed at start-up.
  final bool autoCheckUpdate;

  /// Whether a countdown runs that exits the app when it fires.
  final bool countdownCloseEnabled;

  /// How long the countdown runs, in minutes.
  final int countdownCloseMinutes;

  /// The branch the router starts on, unless [restoreLastTab] wins.
  final AppLaunchBranch launchBranch;

  /// Whether the app starts on the branch it was last left on.
  final bool restoreLastTab;

  /// The shell branch id the app was last left on; null before the first
  /// tab switch.
  final String? lastBranchId;

  /// The desktop window's stored width; 0 keeps the launch default.
  final int windowWidth;

  /// The desktop window's stored height; 0 keeps the launch default.
  final int windowHeight;

  /// The foreground feed refresh interval, in minutes; 0 is off.
  final int autoRefreshMinutes;

  /// How long the app must have been away, in minutes, before a resume
  /// counts as worth refreshing for.
  final int refreshResumeThresholdMinutes;

  /// Whether outgoing requests route through the user's proxy.
  final bool proxyEnabled;

  /// The proxy host name or IP.
  final String proxyHost;

  /// The proxy port.
  final int proxyPort;

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

  /// The visible shell branches, in display order; the home branch is the
  /// floor, so this is never empty.
  final List<String> shellBranches;

  /// The platform ids the user hid from the platform list (3.x
  /// `Settings.hiddenSettingPlatforms`): hidden platforms are left out of
  /// popular, areas and search. An unknown id is simply never matched.
  final List<String> hiddenSiteIds;

  /// The user's manual platform order (3.x `Settings.hotAreasList` order);
  /// ids not listed keep their registry position after the listed ones.
  final List<String> siteOrder;

  /// The persisted log threshold — a `LogLevel.name`, empty for the
  /// build default the `AppLog` already opened with.
  final String logLevelId;

  /// How many watch-history entries are kept; 0 keeps everything (the
  /// reference's `Settings.historyLimit`, default 50).
  final int historyLimit;

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

  /// Writes the document.
  Map<String, Object?> toJson() => {
    'refreshOnResume': refreshOnResume,
    'danmakuVisible': danmakuVisible,
    'volumeMuted': volumeMuted,
    'defaultMobileVolume': defaultMobileVolume,
    'defaultDesktopVolume': defaultDesktopVolume,
    'localInteractionEnabled': localInteractionEnabled,
    'localInteractionUserName': localInteractionUserName,
    'localInteractionColor': localInteractionColor,
    'barrageFontSize': barrageFontSize,
    'barrageOpacity': barrageOpacity,
    'barrageArea': barrageArea,
    'barrageTopArea': barrageTopArea,
    'barrageBottomArea': barrageBottomArea,
    'barrageSpeed': barrageSpeed,
    'barrageFontWeight': barrageFontWeight,
    'barrageStroke': barrageStroke,
    'barrageStrokeWidth': barrageStrokeWidth,
    'barrageShowSender': barrageShowSender,
    'barrageMaxVisible': barrageMaxVisible,
    'barrageFps': barrageFps,
    'barrageNoEmoji': barrageNoEmoji,
    'barrageCollapse': barrageCollapse,
    'barrageCollapseWindow': barrageCollapseWindow,
    'barragePausedBehavior': barragePausedBehavior,
    'barrageAutoFps': barrageAutoFps,
    'barrageFpsMode': barrageFpsMode,
    'barrageShowGifts': barrageShowGifts,
    'barrageTapAction': barrageTapAction,
    'barrageLongPressAction': barrageLongPressAction,
    'barrageFontFamily': barrageFontFamily,
    'backupDirectory': backupDirectory,
    'barrageHoldOnPress': barrageHoldOnPress,
    'barrageListFontSize': barrageListFontSize,
    'barrageListLineSpacing': barrageListLineSpacing,
    'barrageListStyle': barrageListStyle,
    'barrageTemplate': barrageTemplate,
    'preferResolution': preferResolution,
    'preferResolutionCellular': preferResolutionCellular,
    'preferH264': preferH264,
    'videoFitIndex': videoFitIndex,
    'openRoomFullscreen': openRoomFullscreen,
    'preferRealOnlineCounts': preferRealOnlineCounts,
    'realOnlinePlatforms': realOnlinePlatforms,
    'portraitAdapt': portraitAdapt,
    'portraitAdaptiveHeight': portraitAdaptiveHeight,
    'portraitLayoutMode': portraitLayoutMode,
    'portraitFullscreenPolicy': portraitFullscreenPolicy,
    'portraitDisplayMode': portraitDisplayMode,
    'portraitDanmakuMode': portraitDanmakuMode,
    'rememberPortraitRoomOverride': rememberPortraitRoomOverride,
    'showPortraitDiagnostics': showPortraitDiagnostics,
    'portraitRoomOverrides': portraitRoomOverrides,
    'pipAlwaysOnTop': pipAlwaysOnTop,
    'miniRememberPosition': miniRememberPosition,
    'miniWindowRect': miniWindowRect,
    'pauseOnPipClose': pauseOnPipClose,
    'showSplash': showSplash,
    'githubOnlyUpdates': githubOnlyUpdates,
    'detectClipboardRooms': detectClipboardRooms,
    'startAtLogin': startAtLogin,
    'cacheMaxMB': cacheMaxMB,
    'cacheAutoClear': cacheAutoClear,
    'cacheKeepDays': cacheKeepDays,
    'cacheKeepCount': cacheKeepCount,
    'autoRefreshThumbnails': autoRefreshThumbnails,
    'thumbnailRefreshMinutes': thumbnailRefreshMinutes,
    'thumbnailKeepOldFiles': thumbnailKeepOldFiles,
    'playerProxyEnabled': playerProxyEnabled,
    'playerProxyHost': playerProxyHost,
    'playerProxyPort': playerProxyPort,
    'customPlayerOutput': customPlayerOutput,
    'audioOutputDriver': audioOutputDriver,
    'hardwareDecoder': hardwareDecoder,
    'frameInterpolation': frameInterpolation,
    'scaler': scaler,
    'deinterlace': deinterlace,
    'streamCacheSeconds': streamCacheSeconds,
    'languageId': languageId,
    'autoCheckUpdate': autoCheckUpdate,
    'countdownCloseEnabled': countdownCloseEnabled,
    'countdownCloseMinutes': countdownCloseMinutes,
    'launchBranch': launchBranch.id,
    'restoreLastTab': restoreLastTab,
    if (lastBranchId != null) 'lastBranchId': lastBranchId,
    'windowWidth': windowWidth,
    'windowHeight': windowHeight,
    'autoRefreshMinutes': autoRefreshMinutes,
    'refreshResumeThresholdMinutes': refreshResumeThresholdMinutes,
    'proxyEnabled': proxyEnabled,
    'proxyHost': proxyHost,
    'proxyPort': proxyPort,
    'loadingStyle': loadingStyle.id,
    'roomCardCornerRadius': roomCardCornerRadius,
    'roomCardShowPlatform': roomCardShowPlatform,
    'roomCardShowAudience': roomCardShowAudience,
    'roomCardShowAnchor': roomCardShowAnchor,
    'roomCardAspect': roomCardAspect.id,
    'shellBranches': shellBranches,
    'hiddenSiteIds': hiddenSiteIds,
    'siteOrder': siteOrder,
    'logLevelId': logLevelId,
    'historyLimit': historyLimit,
    'pageDefaultSize': pageDefaultSize,
    'pageSizeOptions': pageSizeOptions,
    'pageShowScrollTop': pageShowScrollTop,
    'pageShowSizeSelector': pageShowSizeSelector,
    'pageShowGoto': pageShowGoto,
  };

  /// Returns a copy with the given fields replaced. [shellBranches] never
  /// takes an empty list — a shell with no destination cannot be walked.
  AppPreferences copyWith({
    bool? refreshOnResume,
    bool? danmakuVisible,
    bool? volumeMuted,
    double? defaultMobileVolume,
    double? defaultDesktopVolume,
    bool? localInteractionEnabled,
    String? localInteractionUserName,
    int? localInteractionColor,
    double? barrageFontSize,
    double? barrageOpacity,
    double? barrageArea,
    double? barrageTopArea,
    double? barrageBottomArea,
    double? barrageSpeed,
    int? barrageFontWeight,
    bool? barrageStroke,
    double? barrageStrokeWidth,
    bool? barrageShowSender,
    int? barrageMaxVisible,
    int? barrageFps,
    bool? barrageNoEmoji,
    bool? barrageCollapse,
    int? barrageCollapseWindow,
    String? barragePausedBehavior,
    bool? barrageAutoFps,
    String? barrageFpsMode,
    bool? barrageShowGifts,
    bool? barrageTapAction,
    bool? barrageLongPressAction,
    String? barrageFontFamily,
    String? backupDirectory,
    bool? barrageHoldOnPress,
    double? barrageListFontSize,
    double? barrageListLineSpacing,
    String? barrageListStyle,
    String? barrageTemplate,
    String? preferResolution,
    String? preferResolutionCellular,
    bool? preferH264,
    int? videoFitIndex,
    bool? openRoomFullscreen,
    bool? preferRealOnlineCounts,
    List<String>? realOnlinePlatforms,
    bool? portraitAdapt,
    bool? portraitAdaptiveHeight,
    String? portraitLayoutMode,
    String? portraitFullscreenPolicy,
    String? portraitDisplayMode,
    String? portraitDanmakuMode,
    bool? rememberPortraitRoomOverride,
    bool? showPortraitDiagnostics,
    Map<String, String>? portraitRoomOverrides,
    bool? pipAlwaysOnTop,
    bool? miniRememberPosition,
    String? miniWindowRect,
    bool? pauseOnPipClose,
    bool? showSplash,
    bool? githubOnlyUpdates,
    bool? detectClipboardRooms,
    bool? startAtLogin,
    int? cacheMaxMB,
    bool? cacheAutoClear,
    int? cacheKeepDays,
    int? cacheKeepCount,
    bool? autoRefreshThumbnails,
    int? thumbnailRefreshMinutes,
    bool? thumbnailKeepOldFiles,
    bool? playerProxyEnabled,
    String? playerProxyHost,
    int? playerProxyPort,
    bool? customPlayerOutput,
    String? audioOutputDriver,
    String? hardwareDecoder,
    bool? frameInterpolation,
    String? scaler,
    String? deinterlace,
    int? streamCacheSeconds,
    String? languageId,
    bool? autoCheckUpdate,
    bool? countdownCloseEnabled,
    int? countdownCloseMinutes,
    AppLaunchBranch? launchBranch,
    bool? restoreLastTab,
    String? lastBranchId,
    bool clearLastBranchId = false,
    int? windowWidth,
    int? windowHeight,
    int? autoRefreshMinutes,
    int? refreshResumeThresholdMinutes,
    bool? proxyEnabled,
    String? proxyHost,
    int? proxyPort,
    LoadingStyle? loadingStyle,
    double? roomCardCornerRadius,
    bool? roomCardShowPlatform,
    bool? roomCardShowAudience,
    bool? roomCardShowAnchor,
    RoomCardCoverAspect? roomCardAspect,
    List<String>? shellBranches,
    List<String>? hiddenSiteIds,
    List<String>? siteOrder,
    String? logLevelId,
    int? historyLimit,
    int? pageDefaultSize,
    String? pageSizeOptions,
    bool? pageShowScrollTop,
    bool? pageShowSizeSelector,
    bool? pageShowGoto,
  }) => AppPreferences(
    refreshOnResume: refreshOnResume ?? this.refreshOnResume,
    danmakuVisible: danmakuVisible ?? this.danmakuVisible,
    volumeMuted: volumeMuted ?? this.volumeMuted,
    defaultMobileVolume: defaultMobileVolume ?? this.defaultMobileVolume,
    defaultDesktopVolume: defaultDesktopVolume ?? this.defaultDesktopVolume,
    localInteractionEnabled: localInteractionEnabled ?? this.localInteractionEnabled,
    localInteractionUserName: localInteractionUserName ?? this.localInteractionUserName,
    localInteractionColor: localInteractionColor ?? this.localInteractionColor,
    barrageFontSize: barrageFontSize ?? this.barrageFontSize,
    barrageOpacity: barrageOpacity ?? this.barrageOpacity,
    barrageArea: barrageArea ?? this.barrageArea,
    barrageTopArea: barrageTopArea ?? this.barrageTopArea,
    barrageBottomArea: barrageBottomArea ?? this.barrageBottomArea,
    barrageSpeed: barrageSpeed ?? this.barrageSpeed,
    barrageFontWeight: barrageFontWeight ?? this.barrageFontWeight,
    barrageStroke: barrageStroke ?? this.barrageStroke,
    barrageStrokeWidth: barrageStrokeWidth ?? this.barrageStrokeWidth,
    barrageShowSender: barrageShowSender ?? this.barrageShowSender,
    barrageMaxVisible: barrageMaxVisible ?? this.barrageMaxVisible,
    barrageFps: barrageFps ?? this.barrageFps,
    barrageNoEmoji: barrageNoEmoji ?? this.barrageNoEmoji,
    barrageCollapse: barrageCollapse ?? this.barrageCollapse,
    barrageCollapseWindow: barrageCollapseWindow ?? this.barrageCollapseWindow,
    barragePausedBehavior: barragePausedBehavior ?? this.barragePausedBehavior,
    barrageAutoFps: barrageAutoFps ?? this.barrageAutoFps,
    barrageFpsMode: barrageFpsMode ?? this.barrageFpsMode,
    barrageShowGifts: barrageShowGifts ?? this.barrageShowGifts,
    barrageTapAction: barrageTapAction ?? this.barrageTapAction,
    barrageLongPressAction: barrageLongPressAction ?? this.barrageLongPressAction,
    barrageFontFamily: barrageFontFamily ?? this.barrageFontFamily,
    backupDirectory: backupDirectory ?? this.backupDirectory,
    barrageHoldOnPress: barrageHoldOnPress ?? this.barrageHoldOnPress,
    barrageListFontSize: barrageListFontSize ?? this.barrageListFontSize,
    barrageListLineSpacing: barrageListLineSpacing ?? this.barrageListLineSpacing,
    barrageListStyle: barrageListStyle ?? this.barrageListStyle,
    barrageTemplate: barrageTemplate ?? this.barrageTemplate,
    preferResolution: preferResolution ?? this.preferResolution,
    preferResolutionCellular: preferResolutionCellular ?? this.preferResolutionCellular,
    preferH264: preferH264 ?? this.preferH264,
    videoFitIndex: videoFitIndex ?? this.videoFitIndex,
    openRoomFullscreen: openRoomFullscreen ?? this.openRoomFullscreen,
    preferRealOnlineCounts: preferRealOnlineCounts ?? this.preferRealOnlineCounts,
    realOnlinePlatforms: List.unmodifiable(realOnlinePlatforms ?? this.realOnlinePlatforms),
    portraitAdapt: portraitAdapt ?? this.portraitAdapt,
    portraitAdaptiveHeight: portraitAdaptiveHeight ?? this.portraitAdaptiveHeight,
    portraitLayoutMode: portraitLayoutMode ?? this.portraitLayoutMode,
    portraitFullscreenPolicy: portraitFullscreenPolicy ?? this.portraitFullscreenPolicy,
    portraitDisplayMode: portraitDisplayMode ?? this.portraitDisplayMode,
    portraitDanmakuMode: portraitDanmakuMode ?? this.portraitDanmakuMode,
    rememberPortraitRoomOverride: rememberPortraitRoomOverride ?? this.rememberPortraitRoomOverride,
    showPortraitDiagnostics: showPortraitDiagnostics ?? this.showPortraitDiagnostics,
    portraitRoomOverrides: Map.unmodifiable(portraitRoomOverrides ?? this.portraitRoomOverrides),
    pipAlwaysOnTop: pipAlwaysOnTop ?? this.pipAlwaysOnTop,
    miniRememberPosition: miniRememberPosition ?? this.miniRememberPosition,
    miniWindowRect: miniWindowRect ?? this.miniWindowRect,
    pauseOnPipClose: pauseOnPipClose ?? this.pauseOnPipClose,
    showSplash: showSplash ?? this.showSplash,
    githubOnlyUpdates: githubOnlyUpdates ?? this.githubOnlyUpdates,
    detectClipboardRooms: detectClipboardRooms ?? this.detectClipboardRooms,
    startAtLogin: startAtLogin ?? this.startAtLogin,
    cacheMaxMB: cacheMaxMB ?? this.cacheMaxMB,
    cacheAutoClear: cacheAutoClear ?? this.cacheAutoClear,
    cacheKeepDays: cacheKeepDays ?? this.cacheKeepDays,
    cacheKeepCount: cacheKeepCount ?? this.cacheKeepCount,
    autoRefreshThumbnails: autoRefreshThumbnails ?? this.autoRefreshThumbnails,
    thumbnailRefreshMinutes: thumbnailRefreshMinutes ?? this.thumbnailRefreshMinutes,
    thumbnailKeepOldFiles: thumbnailKeepOldFiles ?? this.thumbnailKeepOldFiles,
    playerProxyEnabled: playerProxyEnabled ?? this.playerProxyEnabled,
    playerProxyHost: playerProxyHost ?? this.playerProxyHost,
    playerProxyPort: playerProxyPort ?? this.playerProxyPort,
    customPlayerOutput: customPlayerOutput ?? this.customPlayerOutput,
    audioOutputDriver: audioOutputDriver ?? this.audioOutputDriver,
    hardwareDecoder: hardwareDecoder ?? this.hardwareDecoder,
    frameInterpolation: frameInterpolation ?? this.frameInterpolation,
    scaler: scaler ?? this.scaler,
    deinterlace: deinterlace ?? this.deinterlace,
    streamCacheSeconds: streamCacheSeconds ?? this.streamCacheSeconds,
    languageId: languageId ?? this.languageId,
    autoCheckUpdate: autoCheckUpdate ?? this.autoCheckUpdate,
    countdownCloseEnabled: countdownCloseEnabled ?? this.countdownCloseEnabled,
    countdownCloseMinutes: countdownCloseMinutes ?? this.countdownCloseMinutes,
    launchBranch: launchBranch ?? this.launchBranch,
    restoreLastTab: restoreLastTab ?? this.restoreLastTab,
    lastBranchId: clearLastBranchId ? null : (lastBranchId ?? this.lastBranchId),
    windowWidth: windowWidth ?? this.windowWidth,
    windowHeight: windowHeight ?? this.windowHeight,
    autoRefreshMinutes: autoRefreshMinutes ?? this.autoRefreshMinutes,
    refreshResumeThresholdMinutes: refreshResumeThresholdMinutes ?? this.refreshResumeThresholdMinutes,
    proxyEnabled: proxyEnabled ?? this.proxyEnabled,
    proxyHost: proxyHost ?? this.proxyHost,
    proxyPort: proxyPort ?? this.proxyPort,
    loadingStyle: loadingStyle ?? this.loadingStyle,
    roomCardCornerRadius: roomCardCornerRadius ?? this.roomCardCornerRadius,
    roomCardShowPlatform: roomCardShowPlatform ?? this.roomCardShowPlatform,
    roomCardShowAudience: roomCardShowAudience ?? this.roomCardShowAudience,
    roomCardShowAnchor: roomCardShowAnchor ?? this.roomCardShowAnchor,
    roomCardAspect: roomCardAspect ?? this.roomCardAspect,
    shellBranches: (shellBranches == null || shellBranches.isEmpty)
        ? this.shellBranches
        : List.unmodifiable(shellBranches),
    hiddenSiteIds: List.unmodifiable(hiddenSiteIds ?? this.hiddenSiteIds),
    siteOrder: List.unmodifiable(siteOrder ?? this.siteOrder),
    logLevelId: logLevelId ?? this.logLevelId,
    historyLimit: historyLimit ?? this.historyLimit,
    pageDefaultSize: pageDefaultSize ?? this.pageDefaultSize,
    pageSizeOptions: pageSizeOptions ?? this.pageSizeOptions,
    pageShowScrollTop: pageShowScrollTop ?? this.pageShowScrollTop,
    pageShowSizeSelector: pageShowSizeSelector ?? this.pageShowSizeSelector,
    pageShowGoto: pageShowGoto ?? this.pageShowGoto,
  );

  @override
  bool operator ==(Object other) =>
      other is AppPreferences &&
      other.refreshOnResume == refreshOnResume &&
      other.danmakuVisible == danmakuVisible &&
      other.volumeMuted == volumeMuted &&
      other.defaultMobileVolume == defaultMobileVolume &&
      other.defaultDesktopVolume == defaultDesktopVolume &&
      other.localInteractionEnabled == localInteractionEnabled &&
      other.localInteractionUserName == localInteractionUserName &&
      other.localInteractionColor == localInteractionColor &&
      other.barrageFontSize == barrageFontSize &&
      other.barrageOpacity == barrageOpacity &&
      other.barrageArea == barrageArea &&
      other.barrageTopArea == barrageTopArea &&
      other.barrageBottomArea == barrageBottomArea &&
      other.barrageSpeed == barrageSpeed &&
      other.barrageFontWeight == barrageFontWeight &&
      other.barrageStroke == barrageStroke &&
      other.barrageStrokeWidth == barrageStrokeWidth &&
      other.barrageShowSender == barrageShowSender &&
      other.barrageMaxVisible == barrageMaxVisible &&
      other.barrageFps == barrageFps &&
      other.barrageNoEmoji == barrageNoEmoji &&
      other.barrageCollapse == barrageCollapse &&
      other.barrageCollapseWindow == barrageCollapseWindow &&
      other.barragePausedBehavior == barragePausedBehavior &&
      other.barrageAutoFps == barrageAutoFps &&
      other.barrageFpsMode == barrageFpsMode &&
      other.barrageShowGifts == barrageShowGifts &&
      other.barrageTapAction == barrageTapAction &&
      other.barrageLongPressAction == barrageLongPressAction &&
      other.barrageFontFamily == barrageFontFamily &&
      other.backupDirectory == backupDirectory &&
      other.barrageHoldOnPress == barrageHoldOnPress &&
      other.barrageListFontSize == barrageListFontSize &&
      other.barrageListLineSpacing == barrageListLineSpacing &&
      other.barrageListStyle == barrageListStyle &&
      other.barrageTemplate == barrageTemplate &&
      other.preferResolution == preferResolution &&
      other.preferResolutionCellular == preferResolutionCellular &&
      other.preferH264 == preferH264 &&
      other.videoFitIndex == videoFitIndex &&
      other.openRoomFullscreen == openRoomFullscreen &&
      other.preferRealOnlineCounts == preferRealOnlineCounts &&
      _listEquals(other.realOnlinePlatforms, realOnlinePlatforms) &&
      other.portraitAdapt == portraitAdapt &&
      other.portraitAdaptiveHeight == portraitAdaptiveHeight &&
      other.portraitLayoutMode == portraitLayoutMode &&
      other.portraitFullscreenPolicy == portraitFullscreenPolicy &&
      other.portraitDisplayMode == portraitDisplayMode &&
      other.portraitDanmakuMode == portraitDanmakuMode &&
      other.rememberPortraitRoomOverride == rememberPortraitRoomOverride &&
      other.showPortraitDiagnostics == showPortraitDiagnostics &&
      _mapEquals(other.portraitRoomOverrides, portraitRoomOverrides) &&
      other.pipAlwaysOnTop == pipAlwaysOnTop &&
      other.miniRememberPosition == miniRememberPosition &&
      other.miniWindowRect == miniWindowRect &&
      other.pauseOnPipClose == pauseOnPipClose &&
      other.showSplash == showSplash &&
      other.githubOnlyUpdates == githubOnlyUpdates &&
      other.detectClipboardRooms == detectClipboardRooms &&
      other.startAtLogin == startAtLogin &&
      other.cacheMaxMB == cacheMaxMB &&
      other.cacheAutoClear == cacheAutoClear &&
      other.cacheKeepDays == cacheKeepDays &&
      other.cacheKeepCount == cacheKeepCount &&
      other.autoRefreshThumbnails == autoRefreshThumbnails &&
      other.thumbnailRefreshMinutes == thumbnailRefreshMinutes &&
      other.thumbnailKeepOldFiles == thumbnailKeepOldFiles &&
      other.playerProxyEnabled == playerProxyEnabled &&
      other.playerProxyHost == playerProxyHost &&
      other.playerProxyPort == playerProxyPort &&
      other.customPlayerOutput == customPlayerOutput &&
      other.audioOutputDriver == audioOutputDriver &&
      other.hardwareDecoder == hardwareDecoder &&
      other.frameInterpolation == frameInterpolation &&
      other.scaler == scaler &&
      other.deinterlace == deinterlace &&
      other.streamCacheSeconds == streamCacheSeconds &&
      other.languageId == languageId &&
      other.autoCheckUpdate == autoCheckUpdate &&
      other.countdownCloseEnabled == countdownCloseEnabled &&
      other.countdownCloseMinutes == countdownCloseMinutes &&
      other.launchBranch == launchBranch &&
      other.restoreLastTab == restoreLastTab &&
      other.lastBranchId == lastBranchId &&
      other.windowWidth == windowWidth &&
      other.windowHeight == windowHeight &&
      other.autoRefreshMinutes == autoRefreshMinutes &&
      other.refreshResumeThresholdMinutes == refreshResumeThresholdMinutes &&
      other.proxyEnabled == proxyEnabled &&
      other.proxyHost == proxyHost &&
      other.proxyPort == proxyPort &&
      other.loadingStyle == loadingStyle &&
      other.roomCardCornerRadius == roomCardCornerRadius &&
      other.roomCardShowPlatform == roomCardShowPlatform &&
      other.roomCardShowAudience == roomCardShowAudience &&
      other.roomCardShowAnchor == roomCardShowAnchor &&
      other.roomCardAspect == roomCardAspect &&
      _listEquals(other.shellBranches, shellBranches) &&
      _listEquals(other.hiddenSiteIds, hiddenSiteIds) &&
      _listEquals(other.siteOrder, siteOrder) &&
      other.logLevelId == logLevelId &&
      other.historyLimit == historyLimit &&
      other.pageDefaultSize == pageDefaultSize &&
      other.pageSizeOptions == pageSizeOptions &&
      other.pageShowScrollTop == pageShowScrollTop &&
      other.pageShowSizeSelector == pageShowSizeSelector &&
      other.pageShowGoto == pageShowGoto;

  @override
  int get hashCode => Object.hash(
    refreshOnResume,
    autoCheckUpdate,
    countdownCloseEnabled,
    countdownCloseMinutes,
    launchBranch,
    restoreLastTab,
    lastBranchId,
    windowWidth,
    windowHeight,
    autoRefreshMinutes,
    refreshResumeThresholdMinutes,
    proxyEnabled,
    proxyHost,
    proxyPort,
    loadingStyle,
    roomCardCornerRadius,
    roomCardShowPlatform,
    roomCardShowAudience,
    roomCardShowAnchor,
    Object.hash(
      roomCardAspect,
      Object.hashAll(shellBranches),
      danmakuVisible,
      volumeMuted,
      defaultMobileVolume,
      defaultDesktopVolume,
      localInteractionEnabled,
      localInteractionUserName,
      localInteractionColor,
      // The barrage block hashed as one list: `Object.hash` caps at 20
      // positional parts and the danmaku settings alone pass that.
      Object.hashAll(<Object?>[
        barrageFontSize,
        barrageOpacity,
        barrageArea,
        barrageTopArea,
        barrageBottomArea,
        barrageSpeed,
        barrageFontWeight,
        barrageStroke,
        barrageStrokeWidth,
        barrageShowSender,
        barrageMaxVisible,
        barrageFps,
        barrageNoEmoji,
        barrageCollapse,
        barrageCollapseWindow,
        barragePausedBehavior,
        barrageAutoFps,
        barrageFpsMode,
        barrageShowGifts,
        barrageTapAction,
        barrageLongPressAction,
        barrageFontFamily,
        backupDirectory,
        barrageHoldOnPress,
        barrageListFontSize,
        barrageListLineSpacing,
        barrageListStyle,
        barrageTemplate,
        preferResolution,
        preferResolutionCellular,
        preferH264,
        videoFitIndex,
        openRoomFullscreen,
        preferRealOnlineCounts,
        Object.hashAll(realOnlinePlatforms),
        portraitAdapt,
        portraitAdaptiveHeight,
        portraitLayoutMode,
        portraitFullscreenPolicy,
        portraitDisplayMode,
        portraitDanmakuMode,
        rememberPortraitRoomOverride,
        showPortraitDiagnostics,
        Object.hashAllUnordered(portraitRoomOverrides.entries),
        pipAlwaysOnTop,
        miniRememberPosition,
        miniWindowRect,
        pauseOnPipClose,
        showSplash,
        githubOnlyUpdates,
        detectClipboardRooms,
        startAtLogin,
        cacheMaxMB,
        cacheAutoClear,
        cacheKeepDays,
        cacheKeepCount,
        autoRefreshThumbnails,
        thumbnailRefreshMinutes,
        thumbnailKeepOldFiles,
        playerProxyEnabled,
        playerProxyHost,
        playerProxyPort,
      ]),
      customPlayerOutput,
      audioOutputDriver,
      hardwareDecoder,
      frameInterpolation,
      scaler,
      deinterlace,
      streamCacheSeconds,
      Object.hash(
        languageId,
        logLevelId,
        historyLimit,
        pageDefaultSize,
        pageSizeOptions,
        pageShowScrollTop,
        pageShowSizeSelector,
        pageShowGoto,
        Object.hashAll(hiddenSiteIds),
        Object.hashAll(siteOrder),
      ),
    ),
  );

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  static bool _mapEquals(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) {
      return false;
    }
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }
}

/// What a [AppPreferencesStore.load] or write found wrong.
///
/// The same shape as the appearance and shell stores' failures: a broken
/// document keeps its defaults and the fact is reported, never thrown.
enum AppPreferencesFailure {
  /// The box read threw.
  read,

  /// A document was stored but is not a JSON object.
  shape,

  /// A JSON object was stored but did not decode.
  decode,

  /// A document was built but could not be written.
  write,
}

/// The app's general choices: one in-memory [AppPreferences], persisted as
/// one JSON document through a storage repository.
///
/// Reading is synchronous — every reader sees [value] and watches [changes] —
/// so the router, the shells and the proxy policy resolve before the first
/// frame. Writing goes through [update], which applies the change to [value]
/// immediately and returns a future that completes once the change is
/// durable; writes are debounced and serialized, so dragging the room-card
/// radius slider across its range costs one document write, not one per
/// frame.
final class AppPreferencesStore {
  /// A store persisting through [repository].
  new({required this.repository, this.saveDebounce = const Duration(milliseconds: 400), this.onError});

  /// The repository the document is persisted in.
  final StorageRepository<Map<dynamic, dynamic>> repository;

  /// How long a change waits for company before the document is written.
  final Duration saveDebounce;

  /// Reports every failed read or write; null swallows them, and the
  /// composition root installs a logger.
  final void Function(AppPreferencesFailure failure, Object error, StackTrace stack)? onError;
  final StreamController<AppPreferences> _controller = StreamController<AppPreferences>.broadcast();

  AppPreferences _value = const AppPreferences();
  Timer? _debounce;
  Future<void> _writeChain = Future<void>.value();
  Completer<void>? _batch;
  Map<String, Object?>? _pending;
  bool _pendingDelete = false;
  bool _disposed = false;

  /// The current preferences: the shipping defaults until [load] runs.
  AppPreferences get value => _value;

  /// What the last [load] found wrong, empty when it found nothing.
  List<AppPreferencesFailure> get failures => List<AppPreferencesFailure>.unmodifiable(_failures);
  final List<AppPreferencesFailure> _failures = [];

  /// Emits on every applied change, including [load].
  Stream<AppPreferences> get changes => _controller.stream;

  /// Reads the stored document, applying it when it decodes.
  ///
  /// A document that cannot be read or decoded leaves [value] as it is and is
  /// recorded in [failures]; a missing document is not a failure, it is simply
  /// the first run.
  Future<AppPreferences> load() async {
    _checkNotDisposed();
    _failures.clear();
    final Map<dynamic, dynamic>? raw;
    try {
      raw = repository.get(AppPreferenceKeys.document);
    } on Object catch (error, stack) {
      _report(AppPreferencesFailure.read, error, stack);
      return _value;
    }
    if (raw == null) {
      return _value;
    }
    final AppPreferences loaded;
    try {
      loaded = AppPreferences.fromJson(Map<String, Object?>.from(raw));
    } on Object catch (error, stack) {
      _report(AppPreferencesFailure.decode, error, stack);
      return _value;
    }
    if (loaded != _value) {
      _value = loaded;
      _emit();
    }
    return loaded;
  }

  /// Applies [transform] to the preferences and persists the result.
  ///
  /// The returned future completes once the change is durable.
  Future<void> update(AppPreferences Function(AppPreferences preferences) transform) {
    _checkNotDisposed();
    final fresh = transform(_value);
    if (fresh == _value) {
      return Future<void>.value();
    }
    _value = fresh;
    _emit();
    _pending = fresh.toJson();
    _pendingDelete = false;
    return _debounced();
  }

  /// Writes the pending document now instead of waiting for the debounce:
  /// before the app exits.
  Future<void> flush() {
    _debounce?.cancel();
    _debounce = null;
    return _drain();
  }

  /// Flushes any pending write and closes the store; later [load] and
  /// [update] throw, [value] and [changes] stay readable.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await flush();
    await _controller.close();
  }

  /// Arms the debounce and answers with the durability future of the batch
  /// this change belongs to.
  Future<void> _debounced() {
    _debounce?.cancel();
    _debounce = Timer(saveDebounce, () => unawaited(_drain()));
    return (_batch ??= Completer<void>()).future;
  }

  /// Serializes whatever is pending behind any write already in flight.
  Future<void> _drain() {
    if (_pending == null && !_pendingDelete) {
      return Future<void>.value();
    }
    final batch = _batch ??= Completer<void>();
    _writeChain = _writeChain.then((_) async {
      final document = _pending;
      _pending = null;
      try {
        if (document != null) {
          await repository.save(AppPreferenceKeys.document, document);
        }
      } on Object catch (error, stack) {
        _report(AppPreferencesFailure.write, error, stack);
      }
    });
    return _writeChain.whenComplete(() {
      if (!batch.isCompleted) {
        batch.complete();
      }
      _batch = null;
    });
  }

  void _report(AppPreferencesFailure failure, Object error, StackTrace stack) {
    _failures.add(failure);
    onError?.call(failure, error, stack);
  }

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(_value);
    }
  }

  void _checkNotDisposed() {
    if (_disposed) {
      throw StateError('AppPreferencesStore was disposed');
    }
  }
}

/// The proxy route outgoing requests take, as the user configured it.
///
/// The dio factory consults a [ProxyPolicy] per request; this one answers
/// from the preferences store's in-memory value — cheap, side-effect free —
/// so flipping the proxy in settings reroutes new connections without a
/// restart. When the user's proxy is off, the decision falls through to
/// [fallback] (the build-time or system route).
final class PreferenceProxyPolicy implements ProxyPolicy {
  /// A policy reading [store], falling back to [fallback] while disabled.
  const new({required this.store, required this.fallback});

  /// The preferences the enabled flag, host and port come from.
  final AppPreferencesStore store;

  /// The route taken while the user's proxy is disabled.
  final ProxyPolicy fallback;

  @override
  ProxyRoute? routeFor(Uri url, {String? site}) {
    final preferences = store.value;
    if (!preferences.proxyEnabled) {
      return fallback.routeFor(url, site: site);
    }
    return HttpProxyRoute(
      host: preferences.proxyHost.trim().isEmpty ? '127.0.0.1' : preferences.proxyHost.trim(),
      port: preferences.proxyPort <= 0 || preferences.proxyPort > 65535 ? 7890 : preferences.proxyPort,
    );
  }
}
