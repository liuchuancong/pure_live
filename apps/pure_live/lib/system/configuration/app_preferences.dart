// The app's general choices — the facade over the per-domain preference
// documents under `preferences/`. The storage format is unchanged: one flat
// JSON document, every key where it has always been, so existing data and
// backups decode as they stand. Each domain owns its fields, its codec and
// its equality under `preferences/<domain>_preferences.dart`; this class
// keeps the single constructor, the field getters the pages read, and the
// copyWith the settings pages write through.
//
// The `new` shorthand is reserved for the constructor name; the fromJson
// factory and [copyWith] spell the class name, which the lint otherwise
// asks to shorten.
// ignore_for_file: unnecessary_type_name_in_constructor

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:live_net/live_net.dart' show HttpProxyRoute, ProxyPolicy, ProxyRoute;
import 'package:live_storage/live_storage.dart' show StorageRepository;

import 'package:pure_live/system/configuration/preferences/danmaku_preferences.dart';
import 'package:pure_live/system/configuration/preferences/data_preferences.dart';
import 'package:pure_live/system/configuration/preferences/feed_preferences.dart';
import 'package:pure_live/system/configuration/preferences/general_preferences.dart';
import 'package:pure_live/system/configuration/preferences/local_interaction_preferences.dart';
import 'package:pure_live/system/configuration/preferences/network_preferences.dart';
import 'package:pure_live/system/configuration/preferences/player_preferences.dart';
import 'package:pure_live/system/configuration/preferences/portrait_preferences.dart';
import 'package:pure_live/system/configuration/preferences/shell_preferences.dart';
import 'package:pure_live/system/configuration/preferences/values.dart';

export 'preferences/shell_preferences.dart' show defaultShellBranches, legacyShellBranches;
export 'preferences/values.dart' show AppLaunchBranch, LoadingStyle, RoomCardCoverAspect, defaultRealOnlinePlatforms;

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

/// The app's general choices, one document.
@immutable
final class AppPreferences extends Equatable {
  /// The shipping defaults, one named argument per field.
  new({
    bool refreshOnResume = true,
    bool danmakuVisible = true,
    bool volumeMuted = false,
    bool backgroundPlay = false,
    bool screenKeepOn = true,
    double defaultMobileVolume = 0.5,
    double defaultDesktopVolume = 1,
    bool localInteractionEnabled = false,
    String localInteractionUserName = '',
    int localInteractionColor = 0xFFFFFFFF,
    int localInteractionExperience = 0,
    String localInteractionPreset = 'clean',
    bool localInteractionGiftBanner = true,
    double barrageFontSize = 15,
    double barrageOpacity = 1,
    double barrageArea = 1,
    double barrageTopArea = 0,
    double barrageBottomArea = 0,
    double barrageSpeed = 120,
    int barrageFontWeight = 600,
    bool barrageStroke = true,
    double barrageStrokeWidth = 3,
    bool barrageShowSender = true,
    int barrageMaxVisible = 48,
    int barrageFps = 30,
    bool barrageNoEmoji = false,
    bool barrageCollapse = false,
    int barrageCollapseWindow = 5,
    String barragePausedBehavior = 'pause',
    bool barrageAutoFps = true,
    String barrageFpsMode = 'powerSaving',
    bool barrageShowGifts = false,
    bool barrageTapAction = true,
    bool barrageLongPressAction = true,
    String barrageFontFamily = '',
    String backupDirectory = '',
    bool barrageHoldOnPress = false,
    double barrageListFontSize = 13,
    double barrageListLineSpacing = 4,
    String barrageListStyle = 'compact',
    String barrageTemplate = '',
    String preferResolution = '原画',
    String preferResolutionCellular = '原画',
    bool preferH264 = true,
    int videoFitIndex = 0,
    bool openRoomFullscreen = false,
    bool preferRealOnlineCounts = false,
    String preferredSiteId = '',
    bool showUnplayableInDiscover = false,
    List<String> realOnlinePlatforms = defaultRealOnlinePlatforms,
    bool portraitAdapt = true,
    bool portraitAdaptiveHeight = true,
    String portraitLayoutMode = 'balanced',
    String portraitFullscreenPolicy = 'followSource',
    String portraitDisplayMode = 'ambient',
    String portraitDanmakuMode = 'followGlobal',
    bool rememberPortraitRoomOverride = true,
    bool showPortraitDiagnostics = false,
    Map<String, String> portraitRoomOverrides = const {},
    bool pipAlwaysOnTop = false,
    bool miniRememberPosition = true,
    String miniWindowRect = '',
    bool pauseOnPipClose = false,
    bool showSplash = true,
    bool githubOnlyUpdates = false,
    bool detectClipboardRooms = true,
    bool startAtLogin = false,
    int cacheMaxMB = 1024,
    bool cacheAutoClear = false,
    int cacheKeepDays = 7,
    int cacheKeepCount = 500,
    bool autoRefreshThumbnails = false,
    int thumbnailRefreshMinutes = 30,
    bool thumbnailKeepOldFiles = false,
    bool playerProxyEnabled = false,
    String playerProxyHost = '127.0.0.1',
    int playerProxyPort = 7890,
    String audioOutputDriver = 'auto',
    String hardwareDecoder = 'auto',
    bool frameInterpolation = false,
    String scaler = 'auto',
    String deinterlace = 'auto',
    int streamCacheSeconds = 0,
    bool customPlayerOutput = false,
    String languageId = '',
    bool autoCheckUpdate = true,
    bool countdownCloseEnabled = false,
    int countdownCloseMinutes = 60,
    AppLaunchBranch launchBranch = AppLaunchBranch.follow,
    bool restoreLastTab = false,
    bool shellNavExpanded = true,
    double sidebarWidth = 180,
    int windowWidth = 0,
    int windowHeight = 0,
    int autoRefreshMinutes = 0,
    List<String> liveAlertTagIds = const [],
    int refreshResumeThresholdMinutes = 10,
    int refreshConcurrency = 4,
    bool proxyEnabled = false,
    String proxyHost = '127.0.0.1',
    int proxyPort = 7890,
    LoadingStyle loadingStyle = LoadingStyle.shimmer,
    double roomCardCornerRadius = 12,
    bool roomCardShowPlatform = true,
    bool roomCardShowAudience = true,
    bool roomCardShowAnchor = true,
    RoomCardCoverAspect roomCardAspect = RoomCardCoverAspect.sixteenByNine,
    double crossAxisSpacing = 6,
    double mainAxisSpacing = 6,
    List<String> shellBranches = defaultShellBranches,
    List<String> hiddenSiteIds = const [],
    List<String> siteOrder = const [],
    String logLevelId = '',
    int historyLimit = 50,
    int pageDefaultSize = 0,
    String pageSizeOptions = '',
    bool pageShowScrollTop = true,
    bool pageShowSizeSelector = true,
    bool pageShowGoto = true,
    String? lastBranchId,
  }) : general = GeneralPreferences(
         refreshOnResume: refreshOnResume,
         showSplash: showSplash,
         githubOnlyUpdates: githubOnlyUpdates,
         detectClipboardRooms: detectClipboardRooms,
         startAtLogin: startAtLogin,
         languageId: languageId,
         autoCheckUpdate: autoCheckUpdate,
         countdownCloseEnabled: countdownCloseEnabled,
         countdownCloseMinutes: countdownCloseMinutes,
         backupDirectory: backupDirectory,
         logLevelId: logLevelId,
         historyLimit: historyLimit,
       ),
       localInteraction = LocalInteractionPreferences(
         localInteractionEnabled: localInteractionEnabled,
         localInteractionUserName: localInteractionUserName,
         localInteractionColor: localInteractionColor,
         localInteractionExperience: localInteractionExperience,
         localInteractionPreset: localInteractionPreset,
         localInteractionGiftBanner: localInteractionGiftBanner,
       ),
       danmaku = DanmakuPreferences(
         danmakuVisible: danmakuVisible,
         barrageFontSize: barrageFontSize,
         barrageOpacity: barrageOpacity,
         barrageArea: barrageArea,
         barrageTopArea: barrageTopArea,
         barrageBottomArea: barrageBottomArea,
         barrageSpeed: barrageSpeed,
         barrageFontWeight: barrageFontWeight,
         barrageStroke: barrageStroke,
         barrageStrokeWidth: barrageStrokeWidth,
         barrageShowSender: barrageShowSender,
         barrageMaxVisible: barrageMaxVisible,
         barrageFps: barrageFps,
         barrageNoEmoji: barrageNoEmoji,
         barrageCollapse: barrageCollapse,
         barrageCollapseWindow: barrageCollapseWindow,
         barragePausedBehavior: barragePausedBehavior,
         barrageAutoFps: barrageAutoFps,
         barrageFpsMode: barrageFpsMode,
         barrageShowGifts: barrageShowGifts,
         barrageTapAction: barrageTapAction,
         barrageLongPressAction: barrageLongPressAction,
         barrageFontFamily: barrageFontFamily,
         barrageHoldOnPress: barrageHoldOnPress,
         barrageListFontSize: barrageListFontSize,
         barrageListLineSpacing: barrageListLineSpacing,
         barrageListStyle: barrageListStyle,
         barrageTemplate: barrageTemplate,
       ),
       player = PlayerPreferences(
         volumeMuted: volumeMuted,
         backgroundPlay: backgroundPlay,
         screenKeepOn: screenKeepOn,
         defaultMobileVolume: defaultMobileVolume,
         defaultDesktopVolume: defaultDesktopVolume,
         preferResolution: preferResolution,
         preferResolutionCellular: preferResolutionCellular,
         preferH264: preferH264,
         videoFitIndex: videoFitIndex,
         openRoomFullscreen: openRoomFullscreen,
         pipAlwaysOnTop: pipAlwaysOnTop,
         miniRememberPosition: miniRememberPosition,
         miniWindowRect: miniWindowRect,
         pauseOnPipClose: pauseOnPipClose,
         playerProxyEnabled: playerProxyEnabled,
         playerProxyHost: playerProxyHost,
         playerProxyPort: playerProxyPort,
         audioOutputDriver: audioOutputDriver,
         hardwareDecoder: hardwareDecoder,
         frameInterpolation: frameInterpolation,
         scaler: scaler,
         deinterlace: deinterlace,
         streamCacheSeconds: streamCacheSeconds,
         customPlayerOutput: customPlayerOutput,
       ),
       portrait = PortraitPreferences(
         portraitAdapt: portraitAdapt,
         portraitAdaptiveHeight: portraitAdaptiveHeight,
         portraitLayoutMode: portraitLayoutMode,
         portraitFullscreenPolicy: portraitFullscreenPolicy,
         portraitDisplayMode: portraitDisplayMode,
         portraitDanmakuMode: portraitDanmakuMode,
         rememberPortraitRoomOverride: rememberPortraitRoomOverride,
         showPortraitDiagnostics: showPortraitDiagnostics,
         portraitRoomOverrides: portraitRoomOverrides,
       ),
       data = DataPreferences(
         cacheMaxMB: cacheMaxMB,
         cacheAutoClear: cacheAutoClear,
         cacheKeepDays: cacheKeepDays,
         cacheKeepCount: cacheKeepCount,
         autoRefreshThumbnails: autoRefreshThumbnails,
         thumbnailRefreshMinutes: thumbnailRefreshMinutes,
         thumbnailKeepOldFiles: thumbnailKeepOldFiles,
       ),
       network = NetworkPreferences(proxyEnabled: proxyEnabled, proxyHost: proxyHost, proxyPort: proxyPort),
       shell = ShellPreferences(
         launchBranch: launchBranch,
         restoreLastTab: restoreLastTab,
         lastBranchId: lastBranchId,
         shellNavExpanded: shellNavExpanded,
         sidebarWidth: sidebarWidth,
         windowWidth: windowWidth,
         windowHeight: windowHeight,
         shellBranches: shellBranches,
       ),
       feed = FeedPreferences(
         autoRefreshMinutes: autoRefreshMinutes,
         liveAlertTagIds: liveAlertTagIds,
         refreshResumeThresholdMinutes: refreshResumeThresholdMinutes,
         refreshConcurrency: refreshConcurrency,
         loadingStyle: loadingStyle,
         roomCardCornerRadius: roomCardCornerRadius,
         roomCardShowPlatform: roomCardShowPlatform,
         roomCardShowAudience: roomCardShowAudience,
         roomCardShowAnchor: roomCardShowAnchor,
         roomCardAspect: roomCardAspect,
         crossAxisSpacing: crossAxisSpacing,
         mainAxisSpacing: mainAxisSpacing,
         pageDefaultSize: pageDefaultSize,
         pageSizeOptions: pageSizeOptions,
         pageShowScrollTop: pageShowScrollTop,
         pageShowSizeSelector: pageShowSizeSelector,
         pageShowGoto: pageShowGoto,
         preferRealOnlineCounts: preferRealOnlineCounts,
         preferredSiteId: preferredSiteId,
         showUnplayableInDiscover: showUnplayableInDiscover,
         realOnlinePlatforms: realOnlinePlatforms,
         hiddenSiteIds: hiddenSiteIds,
         siteOrder: siteOrder,
       );

  /// One instance per document — the private door the codec comes in
  /// through, so the flat constructor above stays the only public shape.
  const AppPreferences._({
    required this.general,
    required this.localInteraction,
    required this.danmaku,
    required this.player,
    required this.portrait,
    required this.data,
    required this.network,
    required this.shell,
    required this.feed,
  });

  /// Reads the document; unknown shapes decode to the defaults. Each domain
  /// reads its own keys from the same flat map the app has always stored.
  factory AppPreferences.fromJson(Map<String, Object?> json) => AppPreferences._(
    general: GeneralPreferences.fromJson(json),
    localInteraction: LocalInteractionPreferences.fromJson(json),
    danmaku: DanmakuPreferences.fromJson(json),
    player: PlayerPreferences.fromJson(json),
    portrait: PortraitPreferences.fromJson(json),
    data: DataPreferences.fromJson(json),
    network: NetworkPreferences.fromJson(json),
    shell: ShellPreferences.fromJson(json),
    feed: FeedPreferences.fromJson(json),
  );

  /// The general document.
  final GeneralPreferences general;

  /// The localInteraction document.
  final LocalInteractionPreferences localInteraction;

  /// The danmaku document.
  final DanmakuPreferences danmaku;

  /// The player document.
  final PlayerPreferences player;

  /// The portrait document.
  final PortraitPreferences portrait;

  /// The data document.
  final DataPreferences data;

  /// The network document.
  final NetworkPreferences network;

  /// The shell document.
  final ShellPreferences shell;

  /// The feed document.
  final FeedPreferences feed;

  /// The domain's keys as stored, flat.
  Map<String, Object?> toJson() => {
    ...general.toJson(),
    ...localInteraction.toJson(),
    ...danmaku.toJson(),
    ...player.toJson(),
    ...portrait.toJson(),
    ...data.toJson(),
    ...network.toJson(),
    ...shell.toJson(),
    ...feed.toJson(),
  };

  /// Whether a feed refreshes when the app comes back to the foreground.
  bool get refreshOnResume => general.refreshOnResume;

  /// Whether a room draws the barrage over its video. The reference's
  /// `danmaku.hideDanmaku`, inverted: the switch says what is on.
  bool get danmakuVisible => danmaku.danmakuVisible;

  /// Whether every room opens silenced, the reference's `vol.globalVolumeMute`.
  /// The level itself survives the mute; un-muting returns to it.
  bool get volumeMuted => player.volumeMuted;

  /// Whether playback carries on while the app is in the background.
  bool get backgroundPlay => player.backgroundPlay;

  /// Whether the screen stays awake while a room plays.
  bool get screenKeepOn => player.screenKeepOn;

  /// The volume a room starts at on a touch phone, 0..1 — the reference's
  /// `vol.defaultMobileVolume`, one of the two answers its volume dialog edits.
  double get defaultMobileVolume => player.defaultMobileVolume;

  /// The volume a room starts at on a desktop window, 0..1.
  double get defaultDesktopVolume => player.defaultDesktopVolume;

  /// Whether the room's local-interaction composer and bus are live — the
  /// reference's `localInteraction.enabled` gate on the same feature.
  bool get localInteractionEnabled => localInteraction.localInteractionEnabled;

  /// The name the local messages carry. Empty draws the localized "me".
  String get localInteractionUserName => localInteraction.localInteractionUserName;

  /// The colour local messages are drawn in, packed ARGB.
  int get localInteractionColor => localInteraction.localInteractionColor;

  /// The local experience the viewer's own lines and gifts accumulate.
  int get localInteractionExperience => localInteraction.localInteractionExperience;

  /// The local danmaku preset the viewer's own lines draw with.
  String get localInteractionPreset => localInteraction.localInteractionPreset;

  /// Whether a gift the viewer sends raises the banner over the picture.
  bool get localInteractionGiftBanner => localInteraction.localInteractionGiftBanner;

  /// The barrage text size, in logical pixels.
  double get barrageFontSize => danmaku.barrageFontSize;

  /// The barrage text opacity, 0..1.
  double get barrageOpacity => danmaku.barrageOpacity;

  /// The share of the video the flying barrage may use, 0..1 — the
  /// reference's `danmakuArea`.
  double get barrageArea => danmaku.barrageArea;

  /// The blank band kept under the top edge, in logical pixels
  /// (`danmakuTopArea`).
  double get barrageTopArea => danmaku.barrageTopArea;

  /// The blank band kept above the bottom edge, in logical pixels
  /// (`danmakuBottomArea`).
  double get barrageBottomArea => danmaku.barrageBottomArea;

  /// How fast a line crosses, in pixels per second (`danmakuSpeed`).
  double get barrageSpeed => danmaku.barrageSpeed;

  /// The barrage text weight, a CSS weight (100..900, `danmakuFontWeight`).
  int get barrageFontWeight => danmaku.barrageFontWeight;

  /// Whether the barrage text carries its dark outline (`enableDanmakuStroke`).
  bool get barrageStroke => danmaku.barrageStroke;

  /// The outline's blur radius, the stroke width (`danmakuFontBorder`).
  double get barrageStrokeWidth => danmaku.barrageStrokeWidth;

  /// Whether the sender's name rides in front of the line (`showChatNames`).
  bool get barrageShowSender => danmaku.barrageShowSender;

  /// How many lines may fly at once (`danmakuMaxVisibleCount`).
  int get barrageMaxVisible => danmaku.barrageMaxVisible;

  /// The repaint rate of the flying barrage, 25..240 FPS
  /// (`danmakuFps`; the automatic variant follows the display in the
  /// reference — this build drives the manual answer).
  int get barrageFps => danmaku.barrageFps;

  /// Whether emote-only chats are dropped (`noEmojiMode`).
  bool get barrageNoEmoji => danmaku.barrageNoEmoji;

  /// Whether an identical chat seen again inside [barrageCollapseWindow]
  /// keeps only its first copy (`collapseRepeatedDanmaku`).
  bool get barrageCollapse => danmaku.barrageCollapse;

  /// The collapse window in seconds, 1..30 (`repeatedDanmakuWindowSeconds`).
  int get barrageCollapseWindow => danmaku.barrageCollapseWindow;

  /// What the barrage does while the video is paused: `pause` holds every
  /// line in place, `fly` lets it cross on (`danmakuPausedBehavior`).
  String get barragePausedBehavior => danmaku.barragePausedBehavior;

  /// Whether the repaint clock follows the display instead of the manual
  /// number (the reference's danmakuAutoFps; true ships it there).
  bool get barrageAutoFps => danmaku.barrageAutoFps;

  /// What the automatic clock may reach: `powerSaving`/`balanced` cap at 60,
  /// `performance` lets the display's own maximum through (the reference's
  /// refreshRateMode trio).
  String get barrageFpsMode => danmaku.barrageFpsMode;

  /// Whether the platform's gift messages fly over the picture beside the
  /// chat (A08.12; off keeps the surface chat-only).
  bool get barrageShowGifts => danmaku.barrageShowGifts;

  /// Whether tapping a flying line opens its sender's card (画面弹幕交互).
  bool get barrageTapAction => danmaku.barrageTapAction;

  /// Whether long-pressing a flying line offers to block its sender.
  bool get barrageLongPressAction => danmaku.barrageLongPressAction;

  /// The danmaku font family registered from the font library; '' is the
  /// system default.
  String get barrageFontFamily => danmaku.barrageFontFamily;

  /// Where backups are written and listed: the reference's
  /// `Settings.backupDirectory`; '' takes the data area's own backups
  /// tree (the app's default folder).
  String get backupDirectory => general.backupDirectory;

  /// Whether pressing the picture holds the lines under the finger
  /// (`holdDanmakuOnPress`).
  bool get barrageHoldOnPress => danmaku.barrageHoldOnPress;

  /// The chat list's text size (`danmakuListFontSize`).
  double get barrageListFontSize => danmaku.barrageListFontSize;

  /// The chat list's line spacing (`danmakuListLineSpacing`).
  double get barrageListLineSpacing => danmaku.barrageListLineSpacing;

  /// The chat list's look: `compact` rows or `card` bubbles
  /// (`danmakuListStyle`).
  String get barrageListStyle => danmaku.barrageListStyle;

  /// The viewer's own saved barrage look, a `key=value;` string; empty when
  /// nothing was saved yet (`savedDanmakuTemplate`).
  String get barrageTemplate => danmaku.barrageTemplate;

  /// The quality name to open a room with on Wi-Fi — one of
  /// `playQualityNames`, matched against the platform's own quality labels
  /// (the reference's preferResolution).
  String get preferResolution => player.preferResolution;

  /// The same answer for a cellular connection; the reference keeps a
  /// separate one so a metered network can start lower.
  String get preferResolutionCellular => player.preferResolutionCellular;

  /// Whether an HEVC-labelled quality is passed over while the room offers
  /// anything else (the reference's "优先 H.264 编码"); HEVC stays one menu tap
  /// away either way.
  bool get preferH264 => player.preferH264;

  /// Index into the six viewport fits (default, crop, fill, height, width,
  /// scale-down) a room opens with; anything out of range reads 0.
  int get videoFitIndex => player.videoFitIndex;

  /// Whether the room walks itself into fullscreen once the stream starts
  /// playing (the reference's "自动全屏").
  bool get openRoomFullscreen => player.openRoomFullscreen;

  /// Whether a room on a trusted platform shows its concurrent-online figure
  /// as the headline audience number; off, the platform's own heat/popularity
  /// number leads (the reference's preferRealOnlineCounts).
  bool get preferRealOnlineCounts => feed.preferRealOnlineCounts;

  /// The platform the discovery pages open on; empty keeps the first.
  String get preferredSiteId => feed.preferredSiteId;

  /// Whether the discovery pages show rooms that cannot play here.
  bool get showUnplayableInDiscover => feed.showUnplayableInDiscover;

  /// The platforms whose online figure is trusted (the reference's
  /// realOnlinePlatforms); the audience row of the video settings edits it.
  List<String> get realOnlinePlatforms => feed.realOnlinePlatforms;

  /// Whether a decoded tall frame re-dresses the room for a vertical stream
  /// (the reference's 智能识别竖屏直播源); off, every source plays in the
  /// plain landscape stack.
  bool get portraitAdapt => portrait.portraitAdapt;

  /// Whether the sheet's ceiling follows the body — a tall source gets the
  /// bigger watch area while the chat list keeps its room (the reference's
  /// portraitAdaptiveHeight). Off, the panel sits fixed at the middle stop.
  bool get portraitAdaptiveHeight => portrait.portraitAdaptiveHeight;

  /// The normal-page shape for a vertical source: `balanced` (sheet over the
  /// full-bleed picture), `immersive` (same, opening at the lowest panel),
  /// `compatibility` (the plain letterboxed stack, like landscape rooms).
  String get portraitLayoutMode => portrait.portraitLayoutMode;

  /// Which direction a fullscreen entry takes for a vertical source:
  /// `followSource` keeps the picture upright (portrait fullscreen),
  /// `followSystem` defers to the device, `landscape` always turns the
  /// sideways room.
  String get portraitFullscreenPolicy => portrait.portraitFullscreenPolicy;

  /// The portrait-fullscreen canvas: `complete` (no backdrop, the fitted
  /// picture), `ambient` (blurred cover behind it — the reference's own
  /// default), `balanced` (ambient, lighter veil), `cover` (cropped to fill).
  String get portraitDisplayMode => portrait.portraitDisplayMode;

  /// How the flying barrage is bounded over a vertical source's picture:
  /// `followGlobal`, `upperQuarter` (top quarter only), `reduced` (half the
  /// rows), `hidden`; it bounds the overlay, never the global style numbers.
  String get portraitDanmakuMode => portrait.portraitDanmakuMode;

  /// Whether a direction picked by hand in the player is remembered for the
  /// room (the reference's portraitRoomOverrides).
  bool get rememberPortraitRoomOverride => portrait.rememberPortraitRoomOverride;

  /// Whether the picture shows the detection read-out — source size, ratio
  /// and the rule in force (the reference's 显示识别状态).
  bool get showPortraitDiagnostics => portrait.showPortraitDiagnostics;

  /// The per-room direction overrides: room key to `portrait`/`landscape`.
  Map<String, String> get portraitRoomOverrides => portrait.portraitRoomOverrides;

  /// Whether the desktop picture-in-picture tile stays above the other
  /// windows (the reference's 小窗始终置顶).
  bool get pipAlwaysOnTop => player.pipAlwaysOnTop;

  /// Whether the free-floating mini window re-opens where it was last left
  /// (the reference's rememberPipPosition). Off, every entry starts at the
  /// corner the driver chooses.
  bool get miniRememberPosition => player.miniRememberPosition;

  /// The last mini-window geometry as `x,y,w,h`; '' is never-left. Written
  /// only while [miniRememberPosition] is on.
  String get miniWindowRect => player.miniWindowRect;

  /// Whether closing the window while it is a PiP/mini tile pauses playback
  /// (the reference's pauseOnPipClose) instead of letting the stream run
  /// behind a hidden window.
  bool get pauseOnPipClose => player.pauseOnPipClose;

  /// Whether the start-up splash holds its two seconds of branding before it
  /// hands over (the reference's showSplashPage); off goes straight to the
  /// launch page.
  bool get showSplash => general.showSplash;

  /// Whether the update feed asks GitHub only (the reference's
  /// useGitHubOriginForUpdates); off races the release assets through the
  /// mirrors first, GitHub as the last door — the shape for networks where
  /// GitHub is the slow one.
  bool get githubOnlyUpdates => general.githubOnlyUpdates;

  /// Whether a room link found on the clipboard at resume is offered as a
  /// jump (the reference's detectClipboardRooms; 3.x always looked).
  bool get detectClipboardRooms => general.detectClipboardRooms;

  /// The stored answer behind the desktop 开机自启 row; the truth is read
  /// from the OS, and the row rewrites the store when the OS refuses.
  bool get startAtLogin => general.startAtLogin;

  /// The picture cache's ceiling in MB (the reference's currentCacheSize
  /// display pairs with it); 0 or negative means no cap.
  int get cacheMaxMB => data.cacheMaxMB;

  /// Whether the cache prunes itself when it crosses [cacheMaxMB] after a
  /// resume (the reference's automatic cache-clear answer).
  bool get cacheAutoClear => data.cacheAutoClear;

  /// How many days a pruned cache may keep pictures for (1..90).
  int get cacheKeepDays => data.cacheKeepDays;

  /// How many files a pruned cache may keep (100..2000).
  int get cacheKeepCount => data.cacheKeepCount;

  /// Whether room covers re-pull on a timer (the reference's
  /// autoRefreshThumbnails); off, a cover is fetched once and kept.
  bool get autoRefreshThumbnails => data.autoRefreshThumbnails;

  /// Minutes between cover re-pulls (5..360, the reference's
  /// thumbnailRefreshInterval); the bucket lands in the cover URL, so every
  /// window reads as a new address once and only once.
  int get thumbnailRefreshMinutes => data.thumbnailRefreshMinutes;

  /// Whether a cover refresh keeps the superseded pictures instead of
  /// letting the cache drop them (the reference's thumbnailKeepOldFiles).
  bool get thumbnailKeepOldFiles => data.thumbnailKeepOldFiles;

  /// The player's own proxy (the reference's 播放器代理): mpv pulls the live
  /// stream through `http://host:port`, separate from the app's own HTTP
  /// proxy because the two often want different doors.
  bool get playerProxyEnabled => player.playerProxyEnabled;

  /// The player proxy's host.
  String get playerProxyHost => player.playerProxyHost;

  /// The player proxy's port (1..65535 as the field page validates it).
  int get playerProxyPort => player.playerProxyPort;

  /// mpv `ao` — the audio output driver.
  String get audioOutputDriver => player.audioOutputDriver;

  /// mpv `hwdec` — the hardware decoder, `auto` letting mpv choose.
  String get hardwareDecoder => player.hardwareDecoder;

  /// mpv `interpolation` — frame blending; desktop only, the reference's
  /// own gate on the cost.
  bool get frameInterpolation => player.frameInterpolation;

  /// mpv `scale` — the upscaling filter; `auto` keeps mpv's default.
  String get scaler => player.scaler;

  /// mpv `deinterlace`.
  String get deinterlace => player.deinterlace;

  /// mpv `cache`/`cache-secs` — the streaming read-ahead in seconds; 0 leaves
  /// the adapter's own cache settings untouched.
  int get streamCacheSeconds => player.streamCacheSeconds;

  /// There is no video-output answer any more: media_kit renders through mpv's
  /// `libmpv` output, and writing any other value leaves the embedded surface
  /// with no frames at all.
  bool get customPlayerOutput => player.customPlayerOutput;

  /// The interface language: an empty id follows the system, otherwise a slang
  /// locale code (`zh`, `en`). Frozen at boot — the whole tree is translated by
  /// the delegate the app builds before the first frame.
  String get languageId => general.languageId;

  /// Whether the home page checks the release feed at start-up.
  bool get autoCheckUpdate => general.autoCheckUpdate;

  /// Whether a countdown runs that exits the app when it fires.
  bool get countdownCloseEnabled => general.countdownCloseEnabled;

  /// How long the countdown runs, in minutes.
  int get countdownCloseMinutes => general.countdownCloseMinutes;

  /// The branch the router starts on, unless [restoreLastTab] wins.
  AppLaunchBranch get launchBranch => shell.launchBranch;

  /// Whether the app starts on the branch it was last left on.
  bool get restoreLastTab => shell.restoreLastTab;

  /// Whether the wide column is drawn expanded (the labelled sidebar) or
  /// collapsed (the icon rail). The toggle in the column's head flips it, the
  /// choice survives restarts, and the width classes apply on top without
  /// ever rewriting it — a narrow window draws the rail whatever this says.
  bool get shellNavExpanded => shell.shellNavExpanded;

  /// The labelled sidebar's width, in logical pixels — what the drag handle
  /// between the panes writes and every boot restores. The shell clamps it
  /// before drawing, so a hand-edited document cannot stretch it absurdly.
  double get sidebarWidth => shell.sidebarWidth;

  /// The desktop window's stored width; 0 keeps the launch default.
  int get windowWidth => shell.windowWidth;

  /// The desktop window's stored height; 0 keeps the launch default.
  int get windowHeight => shell.windowHeight;

  /// The foreground feed refresh interval, in minutes; 0 is off.
  int get autoRefreshMinutes => feed.autoRefreshMinutes;

  /// The follow-tag ids 开播提醒 covers; empty covers every follow.
  List<String> get liveAlertTagIds => feed.liveAlertTagIds;

  /// How long the app must have been away, in minutes, before a resume
  /// counts as worth refreshing for.
  int get refreshResumeThresholdMinutes => feed.refreshResumeThresholdMinutes;

  /// How many followed rooms the refresh pass asks about at once.
  int get refreshConcurrency => feed.refreshConcurrency;

  /// Whether outgoing requests route through the user's proxy.
  bool get proxyEnabled => network.proxyEnabled;

  /// The proxy host name or IP.
  String get proxyHost => network.proxyHost;

  /// The proxy port.
  int get proxyPort => network.proxyPort;

  /// How a feed's first-load placeholder is drawn.
  LoadingStyle get loadingStyle => feed.loadingStyle;

  /// The room card's corner radius, in logical pixels.
  double get roomCardCornerRadius => feed.roomCardCornerRadius;

  /// Whether the room card draws its platform pill.
  bool get roomCardShowPlatform => feed.roomCardShowPlatform;

  /// Whether the room card draws its audience and status pills.
  bool get roomCardShowAudience => feed.roomCardShowAudience;

  /// Whether the room card draws its anchor line (avatar and name).
  bool get roomCardShowAnchor => feed.roomCardShowAnchor;

  /// The room card cover's shape.
  RoomCardCoverAspect get roomCardAspect => feed.roomCardAspect;

  /// The horizontal gap between the cards of one row, in logical pixels.
  double get crossAxisSpacing => feed.crossAxisSpacing;

  /// The vertical gap between the cards of one column, in logical pixels.
  double get mainAxisSpacing => feed.mainAxisSpacing;

  /// The visible shell branches, in display order; the home branch is the
  /// floor, so this is never empty.
  List<String> get shellBranches => shell.shellBranches;

  /// The platform ids the user hid from the platform list (3.x
  /// `Settings.hiddenSettingPlatforms`): hidden platforms are left out of
  /// popular, areas and search. An unknown id is simply never matched.
  List<String> get hiddenSiteIds => feed.hiddenSiteIds;

  /// The user's manual platform order (3.x `Settings.hotAreasList` order);
  /// ids not listed keep their registry position after the listed ones.
  List<String> get siteOrder => feed.siteOrder;

  /// The persisted log threshold — a `LogLevel.name`, empty for the
  /// build default the `AppLog` already opened with.
  String get logLevelId => general.logLevelId;

  /// How many watch-history entries are kept; 0 keeps everything (the
  /// reference's `Settings.historyLimit`, default 50).
  int get historyLimit => general.historyLimit;

  /// Rooms per desktop page; 0 picks the width answer (20 above 960 px,
  /// else 12) — the reference's `pageDefaultSize`.
  int get pageDefaultSize => feed.pageDefaultSize;

  /// The page-size choices as a comma-separated text; empty means the
  /// width rule (20/40/60/80 above 960 px, else 12/24/36/48) — the
  /// reference's `pageSizeOptions`.
  String get pageSizeOptions => feed.pageSizeOptions;

  /// Whether paged lists show the scroll-to-top/bottom buttons
  /// (`pageShowScrollTop`).
  bool get pageShowScrollTop => feed.pageShowScrollTop;

  /// Whether the page bar offers the rooms-per-page menu
  /// (`pageShowSizeSelector`).
  bool get pageShowSizeSelector => feed.pageShowSizeSelector;

  /// Whether the page bar offers 'go to page' (`pageShowGotoButton`).
  bool get pageShowGoto => feed.pageShowGoto;

  /// The shell branch id the app was last left on; null before the first
  /// tab switch.
  String? get lastBranchId => shell.lastBranchId;

  /// Returns a copy with the given fields replaced.
  AppPreferences copyWith({
    bool? refreshOnResume,
    bool? danmakuVisible,
    bool? volumeMuted,
    bool? backgroundPlay,
    bool? screenKeepOn,
    double? defaultMobileVolume,
    double? defaultDesktopVolume,
    bool? localInteractionEnabled,
    String? localInteractionUserName,
    int? localInteractionColor,
    int? localInteractionExperience,
    String? localInteractionPreset,
    bool? localInteractionGiftBanner,
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
    String? preferredSiteId,
    bool? showUnplayableInDiscover,
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
    bool? shellNavExpanded,
    double? sidebarWidth,
    int? windowWidth,
    int? windowHeight,
    int? autoRefreshMinutes,
    List<String>? liveAlertTagIds,
    int? refreshResumeThresholdMinutes,
    int? refreshConcurrency,
    bool? proxyEnabled,
    String? proxyHost,
    int? proxyPort,
    LoadingStyle? loadingStyle,
    double? roomCardCornerRadius,
    bool? roomCardShowPlatform,
    bool? roomCardShowAudience,
    bool? roomCardShowAnchor,
    RoomCardCoverAspect? roomCardAspect,
    double? crossAxisSpacing,
    double? mainAxisSpacing,
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
    backgroundPlay: backgroundPlay ?? this.backgroundPlay,
    screenKeepOn: screenKeepOn ?? this.screenKeepOn,
    defaultMobileVolume: defaultMobileVolume ?? this.defaultMobileVolume,
    defaultDesktopVolume: defaultDesktopVolume ?? this.defaultDesktopVolume,
    localInteractionEnabled: localInteractionEnabled ?? this.localInteractionEnabled,
    localInteractionUserName: localInteractionUserName ?? this.localInteractionUserName,
    localInteractionColor: localInteractionColor ?? this.localInteractionColor,
    localInteractionExperience: localInteractionExperience ?? this.localInteractionExperience,
    localInteractionPreset: localInteractionPreset ?? this.localInteractionPreset,
    localInteractionGiftBanner: localInteractionGiftBanner ?? this.localInteractionGiftBanner,
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
    preferredSiteId: preferredSiteId ?? this.preferredSiteId,
    showUnplayableInDiscover: showUnplayableInDiscover ?? this.showUnplayableInDiscover,
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
    shellNavExpanded: shellNavExpanded ?? this.shellNavExpanded,
    sidebarWidth: sidebarWidth ?? this.sidebarWidth,
    windowWidth: windowWidth ?? this.windowWidth,
    windowHeight: windowHeight ?? this.windowHeight,
    autoRefreshMinutes: autoRefreshMinutes ?? this.autoRefreshMinutes,
    liveAlertTagIds: List.unmodifiable(liveAlertTagIds ?? this.liveAlertTagIds),
    refreshResumeThresholdMinutes: refreshResumeThresholdMinutes ?? this.refreshResumeThresholdMinutes,
    refreshConcurrency: refreshConcurrency ?? this.refreshConcurrency,
    proxyEnabled: proxyEnabled ?? this.proxyEnabled,
    proxyHost: proxyHost ?? this.proxyHost,
    proxyPort: proxyPort ?? this.proxyPort,
    loadingStyle: loadingStyle ?? this.loadingStyle,
    roomCardCornerRadius: roomCardCornerRadius ?? this.roomCardCornerRadius,
    roomCardShowPlatform: roomCardShowPlatform ?? this.roomCardShowPlatform,
    roomCardShowAudience: roomCardShowAudience ?? this.roomCardShowAudience,
    roomCardShowAnchor: roomCardShowAnchor ?? this.roomCardShowAnchor,
    roomCardAspect: roomCardAspect ?? this.roomCardAspect,
    crossAxisSpacing: crossAxisSpacing ?? this.crossAxisSpacing,
    mainAxisSpacing: mainAxisSpacing ?? this.mainAxisSpacing,
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
  List<Object?> get props => [general, localInteraction, danmaku, player, portrait, data, network, shell, feed];
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

  AppPreferences _value = AppPreferences();
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
