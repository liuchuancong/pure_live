import 'package:live_storage/live_storage.dart';

/// The settings subset the backup document carries: the simple prefs a
/// restore writes back through `StoragePrefs`' typed setters.
///
/// The list is the current keys at the time of writing; a new surface that
/// adds a pref adds it here and every older backup keeps restoring (the
/// document's `settings` section is read per key, absent keys stay
/// untouched). The danmaku shield, playback, IPTV, recording, follow tags
/// and per-room orientation all carry their prefs here.
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
/// and writer speak; `dart run tool/prefs_manifest_check.dart` fails on a key
/// that is absent, on a kind no call site uses, and on a backed-up key whose
/// provider is missing from `kSettingsProviders`. The one deliberate
/// exception is `recorder.saveDir`: a legacy value `recorder.dir` upgraded
/// from, read only as a fallback and never written, so its live value
/// already travels under the current key.
///
/// A key that later disappears is harmless — capture simply finds no value;
/// a new surface adds its pref here so its first backup carries it. Restoring
/// only ever writes keys the document carries, so an older backup never resets
/// a newer pref.
const List<BackupPrefEntry> kBackedUpPrefs = [
  // Browsing: which site each surface opens on, which module leads, the
  // grid's card/page measure, the tools' order, the search history.
  ('browse.site', BackupPrefKind.string),
  ('browse.module', BackupPrefKind.string),
  ('browse.popular.site', BackupPrefKind.string),
  ('browse.areas.site', BackupPrefKind.string),
  ('browse.search.site', BackupPrefKind.string),
  ('browse.layout', BackupPrefKind.string),
  ('browse.denseFavorites', BackupPrefKind.boolean),
  ('interface.roomCard.mobile', BackupPrefKind.string),
  ('interface.roomCard.desktop', BackupPrefKind.string),
  ('browse.showUnplayable', BackupPrefKind.boolean),
  ('browse.pageSize', BackupPrefKind.integer),
  ('page.showSizeSelector', BackupPrefKind.boolean),
  ('page.showGotoButton', BackupPrefKind.boolean),
  ('page.showScrollToTop', BackupPrefKind.boolean),
  ('page.pageSizeOptions', BackupPrefKind.string),
  ('browse.cardExtent', BackupPrefKind.floating),
  ('browse.crossSpacing', BackupPrefKind.floating),
  ('browse.mainSpacing', BackupPrefKind.floating),
  ('browse.audienceMetric', BackupPrefKind.string),
  ('browse.preferRealOnline', BackupPrefKind.boolean),
  ('browse.realOnlinePlatforms', BackupPrefKind.stringList),
  ('display.refreshRateMode', BackupPrefKind.string),
  ('display.matchVideoFrameRate', BackupPrefKind.boolean),
  ('updates.autoCheck', BackupPrefKind.boolean),
  ('window.width', BackupPrefKind.integer),
  ('window.height', BackupPrefKind.integer),
  ('exit.autoShutdown.enabled', BackupPrefKind.boolean),
  ('exit.autoShutdown.minutes', BackupPrefKind.integer),
  ('nav.multiview', BackupPrefKind.boolean),
  ('nav.menuIds', BackupPrefKind.stringList),
  ('tools.order', BackupPrefKind.stringList),
  ('shell.closeAction', BackupPrefKind.string),
  ('shell.dontAskExit', BackupPrefKind.boolean),
  ('shell.roomWindows', BackupPrefKind.boolean),
  ('ui.splash', BackupPrefKind.boolean),
  ('search.history', BackupPrefKind.stringList),
  // The platform display and its order/preference.
  ('sites.display', BackupPrefKind.stringList),
  ('sites.display.order', BackupPrefKind.stringList),
  ('sites.display.preferred', BackupPrefKind.string),
  ('sites.twitch.languages', BackupPrefKind.stringList),
  ('sites.youtube.allChat', BackupPrefKind.boolean),
  ('app.detectClipboardRooms', BackupPrefKind.boolean),
  ('sites.huya.preferH264', BackupPrefKind.boolean),
  ('sites.douyu.forceRenew', BackupPrefKind.boolean),
  ('sides.tv.menuAlwaysExpanded', BackupPrefKind.boolean),
  ('sides.tv.focusZoom', BackupPrefKind.boolean),
  // Follows refresh and the history cap.
  ('refresh.follows.auto', BackupPrefKind.boolean),
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
  ('theme.pureBlack', BackupPrefKind.boolean),
  ('theme.liquidGlass', BackupPrefKind.boolean),
  ('theme.loadingStyle', BackupPrefKind.string),
  ('theme.loadingColor', BackupPrefKind.string),
  ('theme.seed', BackupPrefKind.string),
  ('theme.corners', BackupPrefKind.string),
  ('theme.density', BackupPrefKind.string),
  ('theme.contrast', BackupPrefKind.string),
  ('theme.selection', BackupPrefKind.string),
  ('theme.autoClash', BackupPrefKind.boolean),
  ('theme.font', BackupPrefKind.string),
  ('theme.fontFace', BackupPrefKind.string),
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
  ('background.mask', BackupPrefKind.floating),
  ('background.blur', BackupPrefKind.floating),
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
  ('playback.portraitAdaptation', BackupPrefKind.boolean),
  ('playback.portraitAdaptiveHeight', BackupPrefKind.boolean),
  ('playback.portraitLayoutMode', BackupPrefKind.string),
  ('playback.portraitFullscreenPolicy', BackupPrefKind.string),
  ('playback.portraitFullscreenDisplayMode', BackupPrefKind.string),
  ('playback.portraitDanmakuMode', BackupPrefKind.string),
  ('playback.rememberPortraitRoomOverride', BackupPrefKind.boolean),
  ('playback.showPortraitDiagnostics', BackupPrefKind.boolean),
  ('playback.portraitRoomOverrides', BackupPrefKind.string),
  ('player.backend', BackupPrefKind.string),
  ('player.superResolution', BackupPrefKind.string),
  ('player.tuning', BackupPrefKind.string),
  ('player.proxy', BackupPrefKind.string),
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
  ('danmaku.style.fontFace', BackupPrefKind.string),
  ('danmaku.style.template', BackupPrefKind.string),
  ('danmaku.pip.autoScale', BackupPrefKind.boolean),
  ('danmaku.pip.scale', BackupPrefKind.floating),
  ('danmaku.chatNames', BackupPrefKind.boolean),
  ('danmaku.showChatGifts', BackupPrefKind.boolean),
  ('danmaku.chatGiftsAboveTier', BackupPrefKind.boolean),
  ('danmaku.giftValueInYuan', BackupPrefKind.boolean),
  ('danmaku.superChatIncludesMembership', BackupPrefKind.boolean),
  ('danmaku.showGifts', BackupPrefKind.boolean),
  ('danmaku.list.style', BackupPrefKind.string),
  ('danmaku.list.fontSize', BackupPrefKind.integer),
  ('danmaku.list.lineSpacing', BackupPrefKind.string),
  ('danmaku.pausedBehavior', BackupPrefKind.string),
  ('danmaku.interaction.tap', BackupPrefKind.boolean),
  ('danmaku.interaction.longPress', BackupPrefKind.boolean),
  ('danmaku.holdOnPress', BackupPrefKind.boolean),
  // The network and the danmaku shield.
  ('proxy.enabled', BackupPrefKind.boolean),
  ('proxy.host', BackupPrefKind.string),
  ('proxy.port', BackupPrefKind.integer),
  ('danmaku.block.enabled', BackupPrefKind.boolean),
  ('danmaku.block.users', BackupPrefKind.stringList),
  ('danmaku.block.keywords', BackupPrefKind.stringList),
  ('danmaku.filter.similarity', BackupPrefKind.boolean),
  ('danmaku.filter.similarityThreshold', BackupPrefKind.integer),
  ('danmaku.filter.similarityCacheSeconds', BackupPrefKind.integer),
  ('danmaku.filter.similarityMaxCacheSize', BackupPrefKind.integer),
  ('danmaku.repeat.collapse', BackupPrefKind.boolean),
  ('danmaku.repeat.windowSeconds', BackupPrefKind.integer),
  // The local interaction: its identity, economy, history and look.
  ('localInteraction.enabled', BackupPrefKind.boolean),
  ('localInteraction.userName', BackupPrefKind.string),
  ('localInteraction.title', BackupPrefKind.string),
  ('localInteraction.showAsDanmaku', BackupPrefKind.boolean),
  ('localInteraction.showPlatformBadge', BackupPrefKind.boolean),
  ('localInteraction.showLevelBadge', BackupPrefKind.boolean),
  ('localInteraction.enableGiftEffects', BackupPrefKind.boolean),
  ('localInteraction.giftEffectLevel', BackupPrefKind.string),
  ('localInteraction.replayOnEnter', BackupPrefKind.boolean),
  ('localInteraction.phrases', BackupPrefKind.stringList),
  ('localInteraction.growthEnabled', BackupPrefKind.boolean),
  ('localInteraction.growthDay', BackupPrefKind.string),
  ('localInteraction.roomChats', BackupPrefKind.string),
  ('localInteraction.previewPlatform', BackupPrefKind.string),
  ('localInteraction.coins', BackupPrefKind.integer),
  ('localInteraction.experience', BackupPrefKind.integer),
  ('localInteraction.history', BackupPrefKind.stringList),
  ('localInteraction.danmakuPreset', BackupPrefKind.string),
  ('localInteraction.danmakuColor', BackupPrefKind.integer),
  ('localInteraction.danmakuFontSize', BackupPrefKind.floating),
  ('localInteraction.danmakuSpeed', BackupPrefKind.floating),
  ('localInteraction.danmakuFontWeight', BackupPrefKind.integer),
  ('localInteraction.danmakuShowStroke', BackupPrefKind.boolean),
  ('localInteraction.danmakuStrokeWidth', BackupPrefKind.floating),
  ('localInteraction.danmakuPlacement', BackupPrefKind.string),
  ('localInteraction.danmakuFontFamily', BackupPrefKind.string),
  ('localInteraction.danmakuItalic', BackupPrefKind.boolean),
  ('localInteraction.danmakuOpacity', BackupPrefKind.floating),
  ('localInteraction.danmakuLetterSpacing', BackupPrefKind.floating),
  ('localInteraction.danmakuStrokeColor', BackupPrefKind.integer),
  ('localInteraction.danmakuShowShadow', BackupPrefKind.boolean),
  ('localInteraction.danmakuShadowColor', BackupPrefKind.integer),
  ('localInteraction.danmakuShadowBlur', BackupPrefKind.floating),
  ('localInteraction.danmakuShadowOffset', BackupPrefKind.floating),
  ('localInteraction.danmakuFixedDurationMs', BackupPrefKind.integer),
  ('danmaku.filter.emoteOnly', BackupPrefKind.boolean),
  ('danmaku.filter.blockLong', BackupPrefKind.boolean),
  ('danmaku.filter.blockLongLength', BackupPrefKind.integer),
  ('danmaku.filter.douyuSuspected', BackupPrefKind.boolean),
  // The image cache's cap and the shared download folder (empty = default).
  ('cache.maxMB', BackupPrefKind.integer),
  ('storage.downloadDirectory', BackupPrefKind.string),
  // IPTV: the schedule, the active guide and the source order.
  ('iptv.update.hours', BackupPrefKind.integer),
  ('iptv.autoSync', BackupPrefKind.boolean),
  ('iptv.guide.active', BackupPrefKind.string),
  ('iptv.sources.order', BackupPrefKind.stringList),
  ('iptv.userAgent', BackupPrefKind.string),
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
  ('recorder.cacheLimitEnabled', BackupPrefKind.boolean),
  ('recorder.cacheLimitMb', BackupPrefKind.integer),
  ('recorder.liveCheckSeconds', BackupPrefKind.integer),
  ('recorder.checkBackoffEnabled', BackupPrefKind.boolean),
  ('recorder.maxCheckSeconds', BackupPrefKind.integer),
  ('recorder.autoStartOnBoot', BackupPrefKind.boolean),
  ('recorder.pollingEnabled', BackupPrefKind.boolean),
  // Local follow tags and per-room picture orientation.
  ('follow.tags', BackupPrefKind.string),
  ('room.orientation', BackupPrefKind.string),
  // The default Bilibili quality number.
  ('vod.quality.qn', BackupPrefKind.integer),
  // The log surface.
  ('log.level', BackupPrefKind.string),
  ('log.file', BackupPrefKind.boolean),
  // The backup surface's own choices; the WebDAV password is a secret and
  // never enters the document.
  ('backup.dir', BackupPrefKind.string),
  ('backup.webdav.url', BackupPrefKind.string),
  ('backup.webdav.user', BackupPrefKind.string),
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
    final value = snapshot[key];
    if (value == null) continue;
    try {
      switch (kind) {
        case BackupPrefKind.string:
          if (value is String) await StoragePrefs.setString(key, value);
        case BackupPrefKind.boolean:
          if (value is bool) await StoragePrefs.setBool(key, value);
        case BackupPrefKind.integer:
          if (value is int) await StoragePrefs.setInt(key, value);
        case BackupPrefKind.floating:
          if (value is num) await StoragePrefs.setDouble(key, value.toDouble());
        case BackupPrefKind.stringList:
          if (value is List && value.every((entry) => entry is String)) {
            await StoragePrefs.setStringList(key, List<String>.from(value));
          }
      }
    } on Object {
      // One unwritable key loses itself; the rest still land.
    }
  }
}
