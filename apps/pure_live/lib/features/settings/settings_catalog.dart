import 'package:pure_live/features/settings/settings_model.dart';

/// The settings search index (the reference's `settings_catalog.dart`,
/// trimmed to what this build backs).
///
/// The pages draw their own rows; this table is what the index's search box
/// matches against and reveals through: one entry per setting, naming its
/// page, its group on that page and its title, plus keywords in both
/// languages. Tapping a result opens its page — the reference's `opens`
/// behaviour, which is also what every row here does.
final List<SettingsEntry> settingsCatalog = [
  // ——— appearance ———
  SettingsEntry(
    id: 'theme_mode',
    section: SettingsSection.appearance,
    group: (t) => t.settings.sectionTheme,
    title: (t) => t.settings.themeMode,
    description: (t) => t.settings.themeModeSubtitle,
    keywords: const ['theme', 'dark', 'light', '深色', '浅色', '夜间'],
  ),
  SettingsEntry(
    id: 'design_language',
    section: SettingsSection.appearance,
    group: (t) => t.settings.sectionTheme,
    title: (t) => t.settings.designLanguage,
    description: (t) => t.settings.designLanguageSubtitle,
    keywords: const ['material', 'cupertino', 'fluent', '语言', '风格'],
  ),
  SettingsEntry(
    id: 'accent',
    section: SettingsSection.appearance,
    group: (t) => t.settings.sectionTheme,
    title: (t) => t.settings.accent,
    description: (t) => t.settings.accentSubtitle,
    keywords: const ['color', 'colour', '颜色', '强调色'],
  ),
  SettingsEntry(
    id: 'pure_black',
    section: SettingsSection.appearance,
    group: (t) => t.settings.sectionTheme,
    title: (t) => t.settings.pureBlack,
    description: (t) => t.settings.pureBlackSubtitle,
    keywords: const ['oled', 'black', '纯黑'],
  ),
  SettingsEntry(
    id: 'transparency',
    section: SettingsSection.appearance,
    group: (t) => t.settings.sectionTheme,
    title: (t) => t.settings.transparency,
    description: (t) => t.settings.transparencySubtitle,
    keywords: const ['acrylic', 'blur', '透明', '磨砂'],
  ),
  SettingsEntry(
    id: 'animations',
    section: SettingsSection.appearance,
    group: (t) => t.settings.sectionTheme,
    title: (t) => t.settings.animations,
    keywords: const ['motion', '动效', '动画'],
  ),
  SettingsEntry(
    id: 'font_family',
    section: SettingsSection.appearance,
    group: (t) => t.settings.groupFontFamily,
    title: (t) => t.settings.fonts,
    description: (t) => t.settings.fontsSubtitle,
    keywords: const ['font', '字体'],
  ),
  SettingsEntry(
    id: 'font_scale',
    section: SettingsSection.appearance,
    group: (t) => t.settings.groupTextSize,
    title: (t) => t.settings.fontScale,
    keywords: const ['text', 'size', '字号', '大小'],
  ),
  SettingsEntry(
    id: 'density',
    section: SettingsSection.appearance,
    group: (t) => t.settings.sectionTheme,
    title: (t) => t.settings.density,
    description: (t) => t.settings.densitySubtitle,
    keywords: const ['spacing', '紧凑', '密度'],
  ),
  SettingsEntry(
    id: 'loading_style',
    section: SettingsSection.appearance,
    group: (t) => t.settings.sectionFeedDisplay,
    title: (t) => t.settings.loadingStyle,
    description: (t) => t.settings.loadingStyleSubtitle,
    keywords: const ['shimmer', 'spinner', '加载'],
  ),
  SettingsEntry(
    id: 'room_card',
    section: SettingsSection.appearance,
    group: (t) => t.settings.sectionFeedDisplay,
    title: (t) => t.settings.roomCardSettings,
    description: (t) => t.settings.roomCardSettingsSubtitle,
    keywords: const ['card', '卡片', '封面'],
  ),
  SettingsEntry(
    id: 'wallpaper',
    section: SettingsSection.appearance,
    group: (t) => t.settings.sectionTheme,
    title: (t) => t.wallpaper.title,
    keywords: const ['background', '壁纸', '背景'],
  ),
  SettingsEntry(
    id: 'language',
    section: SettingsSection.appearance,
    group: (t) => t.settings.sectionTheme,
    title: (t) => t.settings.language,
    description: (t) => t.settings.languageSubtitle,
    keywords: const ['locale', '语言'],
  ),
  SettingsEntry(
    id: 'page_settings',
    section: SettingsSection.appearance,
    group: (t) => t.settings.sectionFeedDisplay,
    title: (t) => t.settings.pageSettings,
    description: (t) => t.settings.pageSettingsSubtitle,
    keywords: const ['pager', '分页'],
  ),

  // ——— navigation ———
  SettingsEntry(
    id: 'restore_last_tab',
    section: SettingsSection.navigation,
    group: (t) => t.settings.groupLaunch,
    title: (t) => t.settings.restoreLastTab,
    description: (t) => t.settings.restoreLastTabSubtitle,
    keywords: const ['resume', '恢复', '上次'],
  ),
  SettingsEntry(
    id: 'home_menus',
    section: SettingsSection.navigation,
    group: (t) => t.settings.groupVisibleBranches,
    title: (t) => t.settings.groupVisibleBranches,
    keywords: const ['tabs', '导航', '标签'],
  ),

  // ——— platforms ———
  SettingsEntry(
    id: 'platform_list',
    section: SettingsSection.platforms,
    group: (t) => t.settings.platformsTitle,
    title: (t) => t.hotAreas.title,
    description: (t) => t.hotAreas.note,
    keywords: const ['hot areas', '隐藏', '显示', '排序'],
  ),
  SettingsEntry(
    id: 'tags',
    section: SettingsSection.platforms,
    group: (t) => t.settings.platformsTitle,
    title: (t) => t.tags.title,
    keywords: const ['group', '分组', '标签'],
  ),
  SettingsEntry(
    id: 'accounts',
    section: SettingsSection.platforms,
    group: (t) => t.settings.platformsTitle,
    title: (t) => t.settings.sectionAccount,
    description: (t) => t.settings.accountSubtitle,
    keywords: const ['login', 'cookie', '账号', '登录'],
  ),

  // ——— refresh ———
  SettingsEntry(
    id: 'auto_refresh_interval',
    section: SettingsSection.refresh,
    group: (t) => t.settings.groupAutoRefresh,
    title: (t) => t.settings.autoRefreshInterval,
    keywords: const ['interval', '自动刷新', '间隔'],
  ),
  SettingsEntry(
    id: 'history_limit',
    section: SettingsSection.refresh,
    group: (t) => t.settings.groupAutoRefresh,
    title: (t) => t.settings.historyEntry,
    keywords: const ['history', 'limit', '历史', '上限'],
  ),
  SettingsEntry(
    id: 'refresh_on_resume',
    section: SettingsSection.refresh,
    group: (t) => t.settings.groupAutoRefresh,
    title: (t) => t.settings.refreshResumeThreshold,
    keywords: const ['resume', '后台', '恢复'],
  ),

  // ——— iptv ———
  SettingsEntry(
    id: 'iptv_sources',
    section: SettingsSection.iptv,
    group: (t) => t.iptv.title,
    title: (t) => t.iptv.addSource,
    description: (t) => t.settings.iptvDesc,
    keywords: const ['m3u', 'xtream', '订阅', '源'],
  ),

  // ——— video ———
  SettingsEntry(
    id: 'global_mute',
    section: SettingsSection.video,
    group: (t) => t.settings.groupAudio,
    title: (t) => t.room.globalMute,
    description: (t) => t.room.globalMuteSubtitle,
    keywords: const ['mute', '静音'],
  ),
  SettingsEntry(
    id: 'default_volume',
    section: SettingsSection.video,
    group: (t) => t.settings.groupAudio,
    title: (t) => t.settings.defaultVolume,
    description: (t) => t.settings.defaultVolumeSubtitle,
    keywords: const ['volume', '音量'],
  ),

  // ——— danmaku ———
  SettingsEntry(
    id: 'danmaku_visible',
    section: SettingsSection.danmaku,
    group: (t) => t.settings.groupDanmaku,
    title: (t) => t.settings.danmakuVisible,
    description: (t) => t.settings.danmakuVisibleSubtitle,
    keywords: const ['barrage', '弹幕', '显示'],
  ),
  SettingsEntry(
    id: 'barrage_font_size',
    section: SettingsSection.danmaku,
    group: (t) => t.settings.groupDanmaku,
    title: (t) => t.room.barrageFontSize,
    keywords: const ['size', '字号', '弹幕'],
  ),
  SettingsEntry(
    id: 'barrage_opacity',
    section: SettingsSection.danmaku,
    group: (t) => t.settings.groupDanmaku,
    title: (t) => t.room.barrageOpacity,
    keywords: const ['opacity', '透明度'],
  ),
  SettingsEntry(
    id: 'shield',
    section: SettingsSection.danmaku,
    group: (t) => t.settings.sectionDanmaku,
    title: (t) => t.shield.title,
    description: (t) => t.settings.shieldSubtitle,
    keywords: const ['block', 'keyword', '屏蔽', '关键词'],
  ),

  // ——— player ———
  SettingsEntry(
    id: 'mpv_output',
    section: SettingsSection.player,
    group: (t) => t.settings.mpvOutputSection,
    title: (t) => t.settings.mpvCustomOutput,
    description: (t) => t.settings.mpvCustomOutputSubtitle,
    keywords: const ['vo', 'ao', '输出'],
  ),
  SettingsEntry(
    id: 'mpv_hwdec',
    section: SettingsSection.player,
    group: (t) => t.settings.mpvDecodeSection,
    title: (t) => t.settings.mpvHardwareDecoder,
    keywords: const ['hardware', '解码', '硬解'],
  ),
  SettingsEntry(
    id: 'mpv_interpolation',
    section: SettingsSection.player,
    group: (t) => t.settings.mpvDecodeSection,
    title: (t) => t.settings.mpvInterpolation,
    keywords: const ['fps', '补帧'],
  ),
  SettingsEntry(
    id: 'mpv_cache',
    section: SettingsSection.player,
    group: (t) => t.settings.mpvCacheSection,
    title: (t) => t.settings.mpvCacheSeconds,
    keywords: const ['buffer', '缓存'],
  ),

  // ——— recording ———
  SettingsEntry(
    id: 'record_directory',
    section: SettingsSection.recording,
    group: (t) => t.settings.recordingTitle,
    title: (t) => t.recorder.outputDirectory,
    keywords: const ['folder', '目录', '保存'],
  ),
  SettingsEntry(
    id: 'record_segment',
    section: SettingsSection.recording,
    group: (t) => t.settings.recordingTitle,
    title: (t) => t.recorder.segmentLength,
    keywords: const ['segment', '分段'],
  ),

  // ——— general ———
  SettingsEntry(
    id: 'launch_branch',
    section: SettingsSection.general,
    group: (t) => t.settings.groupLaunch,
    title: (t) => t.settings.launchPage,
    keywords: const ['startup', '启动页'],
  ),
  SettingsEntry(
    id: 'auto_check_update',
    section: SettingsSection.general,
    group: (t) => t.settings.sectionGeneral,
    title: (t) => t.settings.autoCheckUpdate,
    description: (t) => t.settings.autoCheckUpdateSubtitle,
    keywords: const ['update', '更新'],
  ),
  SettingsEntry(
    id: 'countdown_close',
    section: SettingsSection.general,
    group: (t) => t.settings.sectionGeneral,
    title: (t) => t.settings.countdownClose,
    description: (t) => t.settings.countdownCloseSubtitle,
    keywords: const ['timer', 'exit', '定时退出'],
  ),
  SettingsEntry(
    id: 'window_size',
    section: SettingsSection.general,
    group: (t) => t.settings.sectionGeneral,
    title: (t) => t.settings.windowSize,
    keywords: const ['desktop', '窗口'],
  ),

  // ——— network ———
  SettingsEntry(
    id: 'app_proxy',
    section: SettingsSection.network,
    group: (t) => t.settings.proxyGroup,
    title: (t) => t.settings.proxyEnable,
    description: (t) => t.settings.proxyEnableSubtitle,
    keywords: const ['proxy', '代理'],
  ),
  SettingsEntry(
    id: 'proxy_endpoint',
    section: SettingsSection.network,
    group: (t) => t.settings.proxyGroup,
    title: (t) => t.settings.proxyEndpoint,
    keywords: const ['host', 'port', '地址', '端口'],
  ),

  // ——— local interaction ———
  SettingsEntry(
    id: 'local_interaction',
    section: SettingsSection.localInteraction,
    group: (t) => t.settings.groupLocalInteraction,
    title: (t) => t.settings.localInteraction,
    description: (t) => t.settings.localInteractionSubtitle,
    keywords: const ['danmaku', '本地'],
  ),
  SettingsEntry(
    id: 'local_interaction_name',
    section: SettingsSection.localInteraction,
    group: (t) => t.settings.groupLocalInteraction,
    title: (t) => t.settings.localInteractionName,
    keywords: const ['nickname', '昵称'],
  ),
  SettingsEntry(
    id: 'local_interaction_color',
    section: SettingsSection.localInteraction,
    group: (t) => t.settings.groupLocalInteraction,
    title: (t) => t.settings.localInteractionColor,
    keywords: const ['color', '颜色'],
  ),

  // ——— cache ———
  SettingsEntry(
    id: 'cache_clear',
    section: SettingsSection.cache,
    group: (t) => t.settings.cacheAndData,
    title: (t) => t.settings.cacheAndData,
    description: (t) => t.settings.cacheAndDataSubtitle,
    keywords: const ['clear', '清理', '缓存'],
  ),

  // ——— backup ———
  SettingsEntry(
    id: 'backup',
    section: SettingsSection.backup,
    group: (t) => t.backup.title,
    title: (t) => t.backup.title,
    description: (t) => t.settings.backupSubtitle,
    keywords: const ['restore', 'export', '备份', '恢复'],
  ),
  SettingsEntry(
    id: 'webdav',
    section: SettingsSection.backup,
    group: (t) => t.backup.title,
    title: (t) => t.webdav.title,
    keywords: const ['sync', 'cloud', '网盘'],
  ),

  // ——— config preview ———
  SettingsEntry(
    id: 'config_preview',
    section: SettingsSection.configPreview,
    group: (t) => t.settings.localConfig,
    title: (t) => t.settings.localConfig,
    description: (t) => t.settings.localConfigSubtitle,
    keywords: const ['json', '配置'],
  ),

  // ——— log ———
  SettingsEntry(
    id: 'log_level',
    section: SettingsSection.log,
    group: (t) => t.logs.title,
    title: (t) => t.logs.level,
    description: (t) => t.logs.levelHint,
    keywords: const ['debug', 'trace', '日志'],
  ),
  SettingsEntry(
    id: 'log_export',
    section: SettingsSection.log,
    group: (t) => t.logs.title,
    title: (t) => t.logs.export,
    keywords: const ['clipboard', '导出'],
  ),
];
