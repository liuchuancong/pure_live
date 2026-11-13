import 'package:flutter/foundation.dart' show listEquals;
import 'package:live_storage/live_storage.dart';

/// The settings subset the backup document carries: the simple prefs a
/// restore writes back through `StoragePrefs`' typed setters.
///
/// The list is the current keys at the time of writing; a new surface that
/// adds a pref adds it here and every older backup keeps restoring (the
/// document's `settings` section is read per key, absent keys stay
/// untouched). The danmaku shield, playback, IPTV, recording, follow tags
/// all carry their prefs here.
enum BackupPrefKind {
  /// A string value.
  string,

  /// A boolean value.
  boolean,

  /// An integer value.
  integer,

  /// A floating-point value.
  floating,

  /// A list of strings.
  stringList,
}

/// One backed-up pref: its key and the kind its reader and writer speak.
typedef BackupPrefEntry = (String key, BackupPrefKind kind);

/// The backed-up keys, grouped as the settings surface presents them.
///
/// Every pref the app reads or writes belongs here with the kind its reader
/// and writer speak; `tool/check_prefs_manifest.ps1` fails on a key that is
/// absent, on a kind no call site uses, and on a backed-up key whose provider
/// is missing from `kSettingsProviders`. The folders the 存储位置 page moves are
/// the one thing it cannot check: their keys are built per folder
/// (`storage.folder.<name>` from `StorageFolder.prefKey`), so no call site
/// spells one, and they stay out of the document on purpose — a folder that
/// does not exist on the machine a backup is restored to would only fail
/// there, and the device's own answer is the right fallback.
///
/// `log.directory`, `recorder.dir` and `recorder.saveDir` are read by nothing
/// but the one-time adoption in `storage_folder_provider.dart`, which moves an
/// old choice under `storage.folder.logs` / `storage.folder.recordings` and
/// drops them; they stay backed up so a document from before that move still
/// carries the viewer's folders. `playback.chatCollapsed` is the same deal —
/// the wide room's fold switch now lives at `danmaku.chatCollapsed` and the
/// one-time adoption in `chat_display_settings.dart` retires the old key.
///
/// A key that later disappears is harmless — capture simply finds no value;
/// a new surface adds its pref here so its first backup carries it. Restoring
/// only ever writes keys the document carries, so an older backup never resets
/// a newer pref.
const List<BackupPrefEntry> kBackedUpPrefs = [
  // Browsing: which site each surface opens on, which module leads, the
  // grid's card/page measure, the tools' order, the search history.
  ('browse.module', BackupPrefKind.string),
  ('browse.popular.site', BackupPrefKind.string),
  ('browse.areas.site', BackupPrefKind.string),
  ('browse.search.site', BackupPrefKind.string),
  ('browse.layout', BackupPrefKind.string),
  ('interface.roomCard', BackupPrefKind.string),
  // Older builds kept one set per device; the single set is read from these
  // when it is absent, so a restore still carries an appearance over.
  ('interface.roomCard.mobile', BackupPrefKind.string),
  ('interface.roomCard.desktop', BackupPrefKind.string),
  ('interface.hongguoCard', BackupPrefKind.string),
  ('interface.vodCard', BackupPrefKind.string),
  ('interface.musicUi', BackupPrefKind.string),
  ('browse.showUnplayable', BackupPrefKind.boolean),
  ('browse.crossSpacing', BackupPrefKind.floating),
  ('browse.mainSpacing', BackupPrefKind.floating),
  ('browse.gridColumns', BackupPrefKind.string),
  ('browse.audienceMetric', BackupPrefKind.string),
  ('browse.preferRealOnline', BackupPrefKind.boolean),
  ('browse.realOnlinePlatforms', BackupPrefKind.stringList),
  // The areas page's own column count (the grid override).
  ('areas.layout', BackupPrefKind.string),
  ('display.refreshRateMode', BackupPrefKind.string),
  ('display.matchVideoFrameRate', BackupPrefKind.boolean),
  ('updates.autoCheck', BackupPrefKind.boolean),
  ('window.width', BackupPrefKind.integer),
  ('window.height', BackupPrefKind.integer),
  ('exit.autoShutdown.enabled', BackupPrefKind.boolean),
  ('exit.autoShutdown.minutes', BackupPrefKind.integer),
  ('nav.menuOrder', BackupPrefKind.stringList),
  ('nav.hiddenMenuIds', BackupPrefKind.stringList),
  ('tools.menuOrder', BackupPrefKind.stringList),
  ('shell.closeAction', BackupPrefKind.string),
  ('shell.dontAskExit', BackupPrefKind.boolean),
  ('shell.roomWindows', BackupPrefKind.boolean),
  ('ui.splash', BackupPrefKind.boolean),
  ('search.history', BackupPrefKind.stringList),
  // The search's excluded platforms are one JSON string, not a string list:
  // `SearchExcludedController` encodes the set itself.
  ('search.allExcluded', BackupPrefKind.string),
  // The platform display and its order/preference.
  ('sites.display', BackupPrefKind.stringList),
  ('sites.display.hidden', BackupPrefKind.stringList),
  ('sites.display.order', BackupPrefKind.stringList),
  ('sites.display.preferred', BackupPrefKind.string),
  ('sites.twitch.languages', BackupPrefKind.stringList),
  ('sites.youtube.allChat', BackupPrefKind.boolean),
  ('app.detectClipboardRooms', BackupPrefKind.boolean),
  ('sites.huya.preferH264', BackupPrefKind.boolean),
  ('sites.douyu.forceRenew', BackupPrefKind.boolean),
  ('sites.douyu.cookieSavedAt', BackupPrefKind.integer),
  ('sides.tv.menuAlwaysExpanded', BackupPrefKind.boolean),
  // Follows refresh and the history cap.
  ('refresh.follows.auto', BackupPrefKind.boolean),
  // The room auto-switch scheduler's switch.
  ('playback.autoSwitchLiveFollows', BackupPrefKind.boolean),
  ('refresh.follows.minutes', BackupPrefKind.integer),
  ('refresh.follows.onResume', BackupPrefKind.boolean),
  ('refresh.liveAlerts.enabled', BackupPrefKind.boolean),
  ('refresh.liveAlerts.tags', BackupPrefKind.stringList),
  ('refresh.maxConcurrent', BackupPrefKind.integer),
  ('refresh.thumbnails.auto', BackupPrefKind.boolean),
  ('refresh.thumbnails.minutes', BackupPrefKind.integer),
  ('history.limit', BackupPrefKind.integer),
  // Appearance.
  ('theme.mode', BackupPrefKind.string),
  ('theme.dynamicColor', BackupPrefKind.boolean),
  ('theme.seed', BackupPrefKind.string),
  ('theme.corners', BackupPrefKind.string),
  ('theme.density', BackupPrefKind.string),
  ('theme.contrast', BackupPrefKind.string),
  ('theme.selection', BackupPrefKind.string),
  ('theme.autoClash', BackupPrefKind.boolean),
  ('theme.font', BackupPrefKind.string),
  ('theme.textScale', BackupPrefKind.floating),
  ('app.locale', BackupPrefKind.string),
  // The wallpaper: its kind and every source it can hold.
  ('background.kind', BackupPrefKind.string),
  ('background.imageUrl', BackupPrefKind.string),
  ('background.imagePath', BackupPrefKind.string),
  ('background.videoUrl', BackupPrefKind.string),
  ('background.videoPath', BackupPrefKind.string),
  ('background.solid', BackupPrefKind.string),
  ('background.gradient', BackupPrefKind.string),
  ('background.fit', BackupPrefKind.string),
  ('background.scrimMode', BackupPrefKind.string),
  ('background.mask', BackupPrefKind.floating),
  ('background.followTone', BackupPrefKind.boolean),
  ('background.overlayBlur', BackupPrefKind.floating),
  ('background.glassMode', BackupPrefKind.string),
  ('background.glassFloating', BackupPrefKind.floating),
  ('background.glassSurface', BackupPrefKind.floating),
  // Playback and the flying layer's own look.
  ('playback.quality', BackupPrefKind.string),
  ('playback.qualityCellular', BackupPrefKind.string),
  ('playback.muted', BackupPrefKind.boolean),
  ('playback.globalMute', BackupPrefKind.boolean),
  ('playback.floatPlay', BackupPrefKind.boolean),
  ('playback.floatWindowSize', BackupPrefKind.string),
  ('playback.floatWindowLandscapeScale', BackupPrefKind.floating),
  ('playback.floatWindowPortraitScale', BackupPrefKind.floating),
  ('playback.windowsPipAlwaysOnTop', BackupPrefKind.boolean),
  ('playback.rememberPipPosition', BackupPrefKind.boolean),
  ('playback.windowsPipBaseSize', BackupPrefKind.floating),
  ('playback.windowsPipMinWidth', BackupPrefKind.floating),
  ('playback.windowsPipMinHeight', BackupPrefKind.floating),
  ('playback.windowsPipFreeAspect', BackupPrefKind.boolean),
  ('window.pip.landscape', BackupPrefKind.string),
  ('window.pip.portrait', BackupPrefKind.string),
  ('playback.background', BackupPrefKind.boolean),
  ('playback.backgroundAudioOnly', BackupPrefKind.boolean),
  ('playback.pauseOnPipClose', BackupPrefKind.boolean),
  ('playback.backgroundPauseDanmaku', BackupPrefKind.boolean),
  ('playback.chatCollapsed', BackupPrefKind.boolean),
  ('playback.controlsAutoHide', BackupPrefKind.integer),
  ('playback.volumeWheelStep', BackupPrefKind.integer),
  ('playback.roomSwitcherLayout', BackupPrefKind.string),
  ('playback.portraitFullscreenSwipeSwitch', BackupPrefKind.boolean),
  ('playback.asmrSleep', BackupPrefKind.boolean),
  ('playback.asmrMinutes', BackupPrefKind.integer),
  ('playback.mobileVolume', BackupPrefKind.floating),
  ('playback.desktopVolume', BackupPrefKind.floating),
  // The pre-split shared volume; read as a fallback for older backups.
  ('playback.volume', BackupPrefKind.floating),
  ('playback.fit', BackupPrefKind.string),
  ('playback.danmaku', BackupPrefKind.boolean),
  ('playback.miniDanmaku', BackupPrefKind.boolean),
  ('playback.hwdec', BackupPrefKind.boolean),
  ('playback.autoPip', BackupPrefKind.boolean),
  ('playback.keepScreenOn', BackupPrefKind.boolean),
  ('playback.fullscreenDefault', BackupPrefKind.boolean),
  ('playback.portraitLayoutMode', BackupPrefKind.string),
  ('player.backend', BackupPrefKind.string),
  ('player.tuning', BackupPrefKind.string),
  ('danmaku.style.fontSize', BackupPrefKind.floating),
  ('danmaku.style.fontWeight', BackupPrefKind.integer),
  ('danmaku.style.letterSpacing', BackupPrefKind.floating),
  ('danmaku.style.fps', BackupPrefKind.integer),
  ('danmaku.style.autoFps', BackupPrefKind.boolean),
  ('danmaku.style.baseSpeed', BackupPrefKind.floating),
  ('danmaku.style.area', BackupPrefKind.floating),
  ('danmaku.style.opacity', BackupPrefKind.floating),
  ('danmaku.style.topMargin', BackupPrefKind.floating),
  ('danmaku.style.bottomMargin', BackupPrefKind.floating),
  ('danmaku.style.showStroke', BackupPrefKind.boolean),
  ('danmaku.style.strokeWidth', BackupPrefKind.floating),
  ('danmaku.style.noEmoji', BackupPrefKind.boolean),
  ('danmaku.style.maxVisibleCount', BackupPrefKind.integer),
  ('danmaku.style.massMode', BackupPrefKind.boolean),
  ('danmaku.style.fontFamily', BackupPrefKind.string),
  ('danmaku.style.shadowColor', BackupPrefKind.integer),
  ('danmaku.style.strokeColor', BackupPrefKind.integer),
  ('danmaku.style.textColor', BackupPrefKind.integer),
  ('danmaku.style.italic', BackupPrefKind.boolean),
  ('danmaku.style.showShadow', BackupPrefKind.boolean),
  ('danmaku.style.shadowBlur', BackupPrefKind.floating),
  ('danmaku.style.shadowOffsetX', BackupPrefKind.floating),
  ('danmaku.style.shadowOffsetY', BackupPrefKind.floating),
  ('danmaku.style.emojiSize', BackupPrefKind.floating),
  ('danmaku.style.trackHeight', BackupPrefKind.floating),
  ('danmaku.style.overlapSafeGap', BackupPrefKind.floating),
  ('danmaku.style.safeArea', BackupPrefKind.boolean),
  ('danmaku.style.rasterize', BackupPrefKind.boolean),
  ('danmaku.style.rasterCacheMb', BackupPrefKind.integer),
  ('danmaku.style.textCacheMaxSize', BackupPrefKind.integer),
  ('danmaku.style.pictureCacheMaxSize', BackupPrefKind.integer),
  ('danmaku.style.maxPendingAge', BackupPrefKind.floating),
  ('danmaku.style.maxPendingCount', BackupPrefKind.integer),
  ('danmaku.style.emitInterval', BackupPrefKind.floating),
  ('danmaku.style.barragePoolMaxSize', BackupPrefKind.integer),
  ('danmaku.pip.autoScale', BackupPrefKind.boolean),
  ('danmaku.pip.scale', BackupPrefKind.floating),
  ('danmaku.chatNames', BackupPrefKind.boolean),
  ('danmaku.showChatGifts', BackupPrefKind.boolean),
  ('danmaku.chatGiftsAboveTier', BackupPrefKind.boolean),
  ('danmaku.superChatIncludesMembership', BackupPrefKind.boolean),
  ('danmaku.showGifts', BackupPrefKind.boolean),
  ('danmaku.list.fontSize', BackupPrefKind.integer),
  ('danmaku.list.lineSpacing', BackupPrefKind.string),
  ('danmaku.chatPanelWidth', BackupPrefKind.floating),
  ('danmaku.chatCollapsed', BackupPrefKind.boolean),
  ('danmaku.interaction.tap', BackupPrefKind.boolean),
  ('danmaku.interaction.longPress', BackupPrefKind.boolean),
  ('danmaku.holdOnPress', BackupPrefKind.boolean),
  ('danmaku.fixed.top', BackupPrefKind.boolean),
  ('danmaku.fixed.bottom', BackupPrefKind.boolean),
  ('danmaku.fixed.duration', BackupPrefKind.floating),
  ('danmaku.saveFormats', BackupPrefKind.string),
  // The network and the danmaku shield.
  // The mode is the truth now; the boolean is the pre-mode store a first run
  // still migrates from, and a backup has to carry it for that read to mean
  // anything on another machine.
  ('proxy.mode', BackupPrefKind.string),
  ('proxy.enabled', BackupPrefKind.boolean),
  ('proxy.host', BackupPrefKind.string),
  ('proxy.port', BackupPrefKind.integer),
  // The proxy's user name travels; its password lives in the secret vault
  // and never enters the document, so a restored machine asks for it again.
  ('proxy.username', BackupPrefKind.string),
  // The GitHub accelerator: the route, the viewer's own endpoints and the
  // published list they were fetched with.
  ('proxy.githubMirror.mode', BackupPrefKind.string),
  ('proxy.githubMirror.url', BackupPrefKind.string),
  ('proxy.githubMirror.custom', BackupPrefKind.string),
  ('proxy.githubMirror.remote', BackupPrefKind.string),
  ('proxy.githubMirror.added', BackupPrefKind.string),
  ('proxy.githubMirror.hidden', BackupPrefKind.string),
  ('proxy.githubMirror.updatedAt', BackupPrefKind.string),
  ('danmaku.block.enabled', BackupPrefKind.boolean),
  ('danmaku.block.users', BackupPrefKind.stringList),
  ('danmaku.block.keywords', BackupPrefKind.stringList),
  ('danmaku.filter.similarity', BackupPrefKind.boolean),
  ('danmaku.filter.similarityThreshold', BackupPrefKind.integer),
  ('danmaku.filter.similarityCacheSeconds', BackupPrefKind.integer),
  ('danmaku.filter.similarityMaxCacheSize', BackupPrefKind.integer),
  ('danmaku.repeat.collapse', BackupPrefKind.boolean),
  ('danmaku.repeat.windowSeconds', BackupPrefKind.integer),
  ('danmaku.filter.emoteOnly', BackupPrefKind.boolean),
  ('danmaku.filter.blockLong', BackupPrefKind.boolean),
  ('danmaku.filter.blockLongLength', BackupPrefKind.integer),
  ('danmaku.filter.douyuSuspected', BackupPrefKind.boolean),
  // The cache's cap, switches and freshness. The moved folders stay out, as
  // above.
  ('cache.maxMB', BackupPrefKind.integer),
  ('cache.images.enabled', BackupPrefKind.boolean),
  ('cache.images.freshness', BackupPrefKind.string),
  ('cache.images.autoClean', BackupPrefKind.boolean),
  // IPTV: the schedule, the active guide and the source order.
  ('iptv.update.hours', BackupPrefKind.integer),
  ('iptv.autoSync', BackupPrefKind.boolean),
  ('iptv.guide.active', BackupPrefKind.string),
  ('iptv.sources.order', BackupPrefKind.stringList),
  ('iptv.userAgent', BackupPrefKind.string),
  ('iptv.browse.channelNumber', BackupPrefKind.boolean),
  ('iptv.browse.channelReversal', BackupPrefKind.boolean),
  ('iptv.browse.clock', BackupPrefKind.boolean),
  ('iptv.browse.programmeLine', BackupPrefKind.boolean),
  ('iptv.recent', BackupPrefKind.string),
  ('iptv.reminders', BackupPrefKind.string),
  // The recorder's 15 tunables (and the old gigabyte cap for upgrades).
  ('recorder.dir', BackupPrefKind.string),
  ('recorder.defaultQuality', BackupPrefKind.string),
  ('recorder.recordDanmaku', BackupPrefKind.boolean),
  ('recorder.naming', BackupPrefKind.string),
  ('recorder.maxSizeMb', BackupPrefKind.integer),
  ('recorder.maxSizeGb', BackupPrefKind.floating),
  ('recorder.segment', BackupPrefKind.integer),
  ('recorder.rwTimeout', BackupPrefKind.integer),
  ('recorder.queue', BackupPrefKind.integer),
  ('recorder.preferBest', BackupPrefKind.boolean),
  ('recorder.keepAlive', BackupPrefKind.boolean),
  ('recorder.verify', BackupPrefKind.boolean),
  ('recorder.restartLimit', BackupPrefKind.integer),
  ('recorder.restartBackoff', BackupPrefKind.integer),
  ('recorder.stallTimeout', BackupPrefKind.integer),
  ('recorder.diskWatermark', BackupPrefKind.integer),
  ('recorder.maxTasks', BackupPrefKind.integer),
  ('recorder.container', BackupPrefKind.string),
  ('recorder.combine', BackupPrefKind.boolean),
  ('recorder.combineDeleteOriginals', BackupPrefKind.boolean),
  ('recorder.transcode', BackupPrefKind.boolean),
  ('recorder.transcodeBitrate', BackupPrefKind.integer),
  ('recorder.tlsVerify', BackupPrefKind.boolean),
  ('recorder.chatGifts', BackupPrefKind.boolean),
  ('recorder.customCa', BackupPrefKind.string),
  ('recorder.cacheLimitEnabled', BackupPrefKind.boolean),
  ('recorder.cacheLimitMb', BackupPrefKind.integer),
  ('recorder.liveCheckSeconds', BackupPrefKind.integer),
  ('recorder.checkBackoffEnabled', BackupPrefKind.boolean),
  ('recorder.maxCheckSeconds', BackupPrefKind.integer),
  ('recorder.autoStartOnBoot', BackupPrefKind.boolean),
  ('recorder.pollingEnabled', BackupPrefKind.boolean),
  // Local follow tags.
  ('follow.tags', BackupPrefKind.string),
  // The default Bilibili quality number and the station's playback choices.
  ('vod.quality.qn', BackupPrefKind.integer),
  ('vod.playback.speed', BackupPrefKind.floating),
  ('vod.playback.finish', BackupPrefKind.string),
  ('vod.playback.showDetails', BackupPrefKind.boolean),
  // Whether the station's feed opens with its header picture.
  ('vod.feed.banner', BackupPrefKind.boolean),
  ('vod.favourites', BackupPrefKind.string),
  ('vod.download.maxConcurrent', BackupPrefKind.integer),
  ('vod.download.qn', BackupPrefKind.integer),
  ('vod.download.danmaku', BackupPrefKind.boolean),
  ('vod.download.retryAttempts', BackupPrefKind.integer),
  ('vod.download.retryDelaySeconds', BackupPrefKind.integer),
  // The music module's source choice, rendition, list behaviour and the
  // imported scripts themselves.
  ('music.source.default', BackupPrefKind.string),
  ('music.play.quality', BackupPrefKind.string),
  ('music.play.skipOnError', BackupPrefKind.boolean),
  ('music.play.autoplay', BackupPrefKind.boolean),
  ('music.play.rememberProgress', BackupPrefKind.boolean),
  ('music.play.volume', BackupPrefKind.floating),
  ('music.play.rate', BackupPrefKind.floating),
  ('music.eq', BackupPrefKind.string),
  ('music.list.addToTop', BackupPrefKind.boolean),
  ('music.list.showSource', BackupPrefKind.boolean),
  ('music.search.hot', BackupPrefKind.boolean),
  ('music.playerMode', BackupPrefKind.string),
  ('music.source.nameType', BackupPrefKind.string),
  ('music.source.swaps', BackupPrefKind.string),
  ('music.hotkeys', BackupPrefKind.string),
  ('music.eq.customPresets', BackupPrefKind.string),
  ('music.play.audioDevice', BackupPrefKind.string),
  ('music.play.autoCleanPlayedList', BackupPrefKind.boolean),
  ('music.play.preservesPitch', BackupPrefKind.boolean),
  ('music.download.useOtherSource', BackupPrefKind.boolean),
  ('music.lyric.dragSeek', BackupPrefKind.boolean),
  ('music.lyric.desktop.boldLine', BackupPrefKind.boolean),
  ('music.lyric.desktop.boldExtended', BackupPrefKind.boolean),
  ('music.lyric.desktop.vertical', BackupPrefKind.boolean),
  ('music.lyric.desktop.lineGap', BackupPrefKind.integer),
  // The open API and the sync pair: the endpoints a restore reopens and
  // the rules it shares. The shared secrets stay out (see the gate's
  // exclusion list), so a restored sync gate starts with a freshly
  // minted code the viewer shares again.
  ('music.openapi.enabled', BackupPrefKind.boolean),
  ('music.openapi.lan', BackupPrefKind.boolean),
  ('music.openapi.port', BackupPrefKind.integer),
  ('music.sync.mode', BackupPrefKind.string),
  ('music.sync.host', BackupPrefKind.string),
  ('music.sync.hostHistory', BackupPrefKind.string),
  ('music.sync.dislikeRules', BackupPrefKind.string),
  ('music.sync.server.enabled', BackupPrefKind.boolean),
  ('music.sync.server.lan', BackupPrefKind.boolean),
  ('music.sync.server.port', BackupPrefKind.integer),
  ('music.sync.server.id', BackupPrefKind.string),
  // The lyric display choices, including the desktop overlay's style.
  ('music.lyric.showTranslation', BackupPrefKind.boolean),
  ('music.lyric.showRomanization', BackupPrefKind.boolean),
  ('music.lyric.swapSecondary', BackupPrefKind.boolean),
  ('music.lyric.traditionalize', BackupPrefKind.boolean),
  ('music.lyric.playWordTimed', BackupPrefKind.boolean),
  ('music.lyric.fontScale', BackupPrefKind.integer),
  ('music.lyric.alignment', BackupPrefKind.string),
  ('music.lyric.zoomActive', BackupPrefKind.boolean),
  ('music.lyric.progress', BackupPrefKind.boolean),
  ('music.lyric.offsetMs', BackupPrefKind.integer),
  ('music.lyric.desktop.enabled', BackupPrefKind.boolean),
  ('music.lyric.desktop.locked', BackupPrefKind.boolean),
  ('music.lyric.desktop.fontSize', BackupPrefKind.floating),
  ('music.lyric.desktop.opacity', BackupPrefKind.floating),
  ('music.lyric.desktop.textColor', BackupPrefKind.integer),
  ('music.lyric.desktop.strokeColor', BackupPrefKind.integer),
  ('music.lyric.desktop.strokeWidth', BackupPrefKind.floating),
  ('music.lyric.desktop.alignment', BackupPrefKind.string),
  // The download post-processing choices.
  ('music.download.type', BackupPrefKind.string),
  ('music.download.pattern', BackupPrefKind.string),
  ('music.download.embedCover', BackupPrefKind.boolean),
  ('music.download.embedLyric', BackupPrefKind.boolean),
  ('music.download.includeTranslation', BackupPrefKind.boolean),
  ('music.download.includeRomanization', BackupPrefKind.boolean),
  ('music.download.writeLyric', BackupPrefKind.boolean),
  ('music.download.skipExisting', BackupPrefKind.boolean),
  ('music.download.groupByList', BackupPrefKind.boolean),
  ('music.download.maxConcurrent', BackupPrefKind.integer),
  // The lists the reference's backup carries too: playlists, collection,
  // trial list, dislike rules and the metadata that travels with them.
  ('music.customSources', BackupPrefKind.string),
  ('music.favourites', BackupPrefKind.string),
  ('music.recent', BackupPrefKind.string),
  ('music.playlists', BackupPrefKind.string),
  ('music.dislikes', BackupPrefKind.string),
  ('music.lyric.overrides', BackupPrefKind.string),
  ('music.search.history', BackupPrefKind.string),
  ('music.local.roots', BackupPrefKind.string),
  ('music.queue', BackupPrefKind.string),
  // The hongguo station's rendition, learned decoder notes and the viewer's
  // own shelves.
  ('hongguo.quality', BackupPrefKind.string),
  // Whether 首页 draws its first pick at head size above the shelves.
  ('hongguo.danmaku', BackupPrefKind.string),
  ('hongguo.decoderFailures', BackupPrefKind.stringList),
  ('hongguo.library.favorites', BackupPrefKind.string),
  ('hongguo.library.history', BackupPrefKind.string),
  ('hongguo.library.favoriteUpdates', BackupPrefKind.string),
  ('hongguo.search.history', BackupPrefKind.string),
  // The station's download lane count and rendition; its queue itself points
  // at files this machine holds (see the gate's exclusion list).
  ('hongguo.download.maxConcurrent', BackupPrefKind.integer),
  ('hongguo.download.quality', BackupPrefKind.string),
  ('hongguo.download.retryAttempts', BackupPrefKind.integer),
  ('hongguo.download.retryDelaySeconds', BackupPrefKind.integer),
  // The log surface.
  ('log.level', BackupPrefKind.string),
  ('log.file', BackupPrefKind.boolean),
  ('log.fileMaxBytes', BackupPrefKind.integer),
  ('log.filesKept', BackupPrefKind.integer),
  ('log.fileName', BackupPrefKind.string),
  ('log.exportFormat', BackupPrefKind.string),
  ('log.directory', BackupPrefKind.string),
  // The backup surface's own choices; the WebDAV password is a secret and
  // enters the document only through the secrets section, behind the
  // includeSecrets switch.
  ('backup.dir', BackupPrefKind.string),
  ('backup.includeSecrets', BackupPrefKind.boolean),
  // The LAN sync's user choices. Its device id, sequence and trust records
  // are this device's identity and never enter a document.
  ('lan_sync.enabled', BackupPrefKind.boolean),
  ('lan_sync.deviceName', BackupPrefKind.string),
  ('lan_sync.conflictPolicy', BackupPrefKind.string),
  ('lan_sync.scopes', BackupPrefKind.stringList),
  // The account list is one JSON pref; the two url/user keys below stay listed
  // because the first read of an older store migrates from them.
  ('backup.webdav.accounts', BackupPrefKind.string),
  ('backup.webdav.selected', BackupPrefKind.string),
  ('backup.webdav.url', BackupPrefKind.string),
  ('backup.webdav.user', BackupPrefKind.string),
  // The scheduled WebDAV backup's choices. Its run record —
  // `backup.webdav.auto.lastSuccess`, `.lastAttempt`, `.failures`,
  // `.lastTarget` — is this device's own history and stays out, like the
  // LAN sync's identity keys above.
  ('backup.webdav.auto.enabled', BackupPrefKind.boolean),
  ('backup.webdav.auto.hours', BackupPrefKind.integer),
  ('backup.webdav.auto.scope', BackupPrefKind.string),
  ('backup.webdav.auto.folder', BackupPrefKind.string),
  ('backup.webdav.auto.keep', BackupPrefKind.integer),
  ('backup.webdav.auto.includeSecrets', BackupPrefKind.boolean),
];

/// Reads every backed-up pref that currently has a value.
///
/// A closed store answers an empty snapshot — capture runs where a
/// failure means "back up the stores only", not "the export fails".
Map<String, Object?> captureSettingsSnapshot() {
  final snapshot = <String, Object?>{};
  for (final (key, kind) in kBackedUpPrefs) {
    try {
      final value = switch (kind) {
        BackupPrefKind.string => StoragePrefs.getString(key),
        BackupPrefKind.boolean => StoragePrefs.getBool(key),
        BackupPrefKind.integer => StoragePrefs.getInt(key),
        BackupPrefKind.floating => StoragePrefs.getDouble(key),
        BackupPrefKind.stringList => StoragePrefs.getStringList(key),
      };
      if (value != null) snapshot[key] = value;
    } on Object {
      // One unreadable key loses itself; the rest still go in.
    }
  }
  return snapshot;
}

/// Writes [snapshot]'s known keys back through the typed setters.
///
/// Keys the snapshot does not carry stay as they are (an older backup
/// must not reset a newer app's new prefs); a value of the wrong shape is
/// skipped. A closed store loses the restore, like every pref write.
Future<void> applySettingsSnapshot(Map<String, Object?> snapshot) async {
  for (final (key, kind) in kBackedUpPrefs) {
    final value = restorablePrefValue(kind, snapshot[key]);
    if (value == null) continue;
    try {
      switch (kind) {
        case BackupPrefKind.string:
          await StoragePrefs.setString(key, value as String);
        case BackupPrefKind.boolean:
          await StoragePrefs.setBool(key, value as bool);
        case BackupPrefKind.integer:
          await StoragePrefs.setInt(key, value as int);
        case BackupPrefKind.floating:
          await StoragePrefs.setDouble(key, value as double);
        case BackupPrefKind.stringList:
          await StoragePrefs.setStringList(key, value as List<String>);
      }
    } on Object {
      // One unwritable key loses itself; the rest still land.
    }
  }
}

/// The value a restore writes for a pref of [kind] from a document's
/// [value], in the shape its typed setter takes; null when there is none or
/// it is of the wrong shape, and the key is skipped.
///
/// [applySettingsSnapshot] writes through this gate and the restore's
/// preview counts through it, so the two never disagree on a key.
Object? restorablePrefValue(BackupPrefKind kind, Object? value) => switch (kind) {
  BackupPrefKind.string => value is String ? value : null,
  BackupPrefKind.boolean => value is bool ? value : null,
  BackupPrefKind.integer => value is int ? value : null,
  BackupPrefKind.floating => value is num ? value.toDouble() : null,
  BackupPrefKind.stringList =>
    value is List && value.every((entry) => entry is String) ? List<String>.from(value) : null,
};

/// What [applySettingsSnapshot] would do with [snapshot] on this device:
/// the known keys it writes, how many of those differ from the stored
/// value (one with no stored value differs), and how many it skips for
/// their shape. Keys this build does not know are neither: the restore
/// ignores them, as it ignores a newer writer's prefs.
({int written, int changed, int skipped}) settingsSnapshotChanges(Map<String, Object?> snapshot) {
  final current = captureSettingsSnapshot();
  var written = 0;
  var changed = 0;
  var skipped = 0;
  for (final (key, kind) in kBackedUpPrefs) {
    final raw = snapshot[key];
    if (raw == null) continue;
    final value = restorablePrefValue(kind, raw);
    if (value == null) {
      skipped++;
      continue;
    }
    written++;
    final now = current[key];
    final same = value is List<String> && now is List ? listEquals(value, now) : value == now;
    if (!same) changed++;
  }
  return (written: written, changed: changed, skipped: skipped);
}
