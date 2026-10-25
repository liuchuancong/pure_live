import 'package:pure_live/features/settings/settings_sections.dart' show SettingsSection;
import 'package:pure_live/l10n/translations.dart';

/// One searchable row of the settings surface: the section it lives in, its
/// own words, and the words a viewer might type for it. The catalogue is
/// the search's memory of rows — the panes themselves stay widgets, so a
/// row that exists here is a row the viewer can be taken to.
typedef SettingsSearchHit = ({SettingsSection section, String title, String keywords});

SettingsSearchHit _hit(SettingsSection section, String title, String keywords) =>
    (section: section, title: title, keywords: keywords);

/// Every row the settings search knows, in section order.
///
/// This is a curated index rather than a reflection of the widgets: a row
/// is added when its control is added, and its keywords carry the words
/// the label itself does not (English names, synonyms, the thing being
/// configured). The search result opens the row's section; the exact-row
/// jump waits for the panes to expose row keys.
List<SettingsSearchHit> settingsSearchCatalog(Translations t) {
  final s = t.settings;
  return [
    // Browsing and window.
    _hit(SettingsSection.general, s.cardExtent, 'card width grid 卡片 宽度 每排'),
    _hit(SettingsSection.general, s.pageSize, 'page size rows 每页 数量 分页'),
    _hit(SettingsSection.general, s.favoritesDense, 'dense compact favorites follows large card grid 紧凑 关注 卡片 密度 大卡片'),
    _hit(SettingsSection.general, s.crossSpacing, 'column gap spacing 列间距 网格'),
    _hit(SettingsSection.general, s.mainSpacing, 'row gap spacing 行间距 网格'),
    _hit(SettingsSection.general, s.audienceMetric, 'audience viewers metric 观众 在线 热度 累计'),
    _hit(SettingsSection.general, s.windowSize, 'window size resolution 1920 1080 窗口 尺寸 分辨率 宽度 高度'),
    _hit(SettingsSection.general, s.windowChrome, 'title bar caption 标题栏 窗口'),
    _hit(
      SettingsSection.general,
      s.refreshRateMode,
      'refresh rate hz monitor display high refresh power saving 刷新率 高刷 显示器 节能',
    ),
    _hit(SettingsSection.general, s.closeAction, 'close window quit minimise tray 关闭 退出 最小化'),
    _hit(SettingsSection.general, s.noExitConfirm, 'exit confirm ask close dialog dont ask 不再询问 退出 确认 关闭 对话框'),
    _hit(SettingsSection.general, s.autoCheckUpdate, 'auto update check release new version 自动检查 更新 新版本'),
    // Appearance.
    _hit(SettingsSection.appearance, s.themeMode, 'theme dark light system 主题 深色 浅色 跟随系统'),
    _hit(SettingsSection.appearance, s.themeSeed, 'accent seed color custom hex picker palette 主题色 取色 配色 自定义 色盘 十六进制'),
    _hit(
      SettingsSection.appearance,
      s.dynamicColor,
      'dynamic color monet material you wallpaper system accent 动态取色 壁纸 系统取色 莫奈',
    ),
    _hit(
      SettingsSection.appearance,
      s.loadingStyle,
      'loading spinner animation style ring pulse wave 加载 动画 样式 圆环 脉冲 波浪',
    ),
    _hit(
      SettingsSection.appearance,
      s.loadingColor,
      'loading spinner color tint accent hex 加载 动画 颜色 取色 强调色',
    ),
    _hit(SettingsSection.appearance, s.corners, 'corner radius round 圆角 直角 胶囊'),
    _hit(SettingsSection.appearance, s.contrast, 'contrast border 对比度 边界'),
    _hit(SettingsSection.appearance, s.selectionStyle, 'selection highlight 选中 高亮'),
    _hit(SettingsSection.appearance, s.autoClash, 'clash danger success 撞色 避让 状态色'),
    _hit(SettingsSection.appearance, s.font, 'font typeface 字体 字型'),
    _hit(
      SettingsSection.appearance,
      s.textScale,
      'text size scale factor typography accessibility zoom 文本 字号 缩放 大小 倍率',
    ),
    _hit(SettingsSection.appearance, s.language, 'language locale 语言 中文 english'),
    _hit(SettingsSection.appearance, s.density, 'density compact touch 密度 紧凑 触控'),
    // Background.
    _hit(
      SettingsSection.backgroundImages,
      s.backgroundImagesTitle,
      'wallpaper library image official wallhaven bing deepin 图库 壁纸 在线图片',
    ),
    _hit(
      SettingsSection.backgroundRandom,
      s.navRandomWallpaper,
      'random wallpaper api wuming uapi 360 bing alcy sexy picsum 随机图 图源 必应 360 栗次元 无铭',
    ),
    _hit(SettingsSection.backgroundVideos, s.backgroundVideosTitle, 'video wallpaper itab live 动态壁纸 在线视频'),
    _hit(SettingsSection.backgroundColors, s.backgroundSolid, 'solid color fill palette 纯色 颜色 调色板'),
    _hit(SettingsSection.backgroundColors, s.backgroundGradient, 'gradient 渐变 背景'),
    _hit(SettingsSection.backgroundDevice, s.backgroundImageAddress, 'image url upload local file 图片 地址 上传 本机'),
    _hit(SettingsSection.backgroundDevice, s.backgroundVideoAddress, 'video url upload local file 视频 地址 上传 本机'),
    _hit(SettingsSection.background, s.backgroundFit, 'fit fill cover 填充 裁切'),
    _hit(SettingsSection.background, s.backgroundMask, 'mask dim 遮罩 压暗'),
    _hit(SettingsSection.background, s.backgroundBlur, 'blur 模糊 高斯'),
    _hit(SettingsSection.background, s.backgroundClear, 'remove background 清除 背景'),
    // Navigation.
    _hit(SettingsSection.nav, s.multiviewVisible, 'multiview 多画面 入口 侧栏'),
    _hit(SettingsSection.nav, s.toolsOrder, 'tool order sidebar 工具 排序 侧栏'),
    // Refresh.
    _hit(SettingsSection.sources, s.followsAutoRefresh, 'auto refresh follows 自动刷新 关注'),
    _hit(SettingsSection.sources, s.refreshInterval, 'interval 刷新 间隔'),
    _hit(SettingsSection.sources, s.refreshOnResume, 'resume refresh 返回应用 刷新'),
    _hit(SettingsSection.sources, s.maxConcurrentRefresh, 'concurrency parallel queue 并发 刷新 队列'),
    _hit(SettingsSection.sources, s.refreshThumbnails, 'thumbnail cover image cache 封面 图片 缓存 刷新'),
    _hit(SettingsSection.sources, s.thumbnailRefreshInterval, 'thumbnail interval 封面 间隔'),
    // Network.
    _hit(SettingsSection.network, s.proxy, 'proxy http 代理 网络'),
    _hit(SettingsSection.network, s.proxyHost, 'proxy host 主机 代理'),
    _hit(SettingsSection.network, s.proxyPort, 'proxy port 端口 代理'),
    _hit(SettingsSection.nodes, t.toolbox.toolNetworkTitle, 'platform node probe latency 平台 节点 测速 延迟 网络'),
    _hit(SettingsSection.logs, t.toolbox.toolLogsTitle, 'logs diagnostics level 日志 诊断'),
    // Video.
    _hit(SettingsSection.video, s.preferredQuality, 'quality resolution 画质 清晰度 分辨率'),
    _hit(
      SettingsSection.video,
      s.preferredQualityCellular,
      'cellular mobile data quality 蜂窝 移动网络 流量 画质 清晰度',
    ),
    _hit(SettingsSection.video, s.defaultMuted, 'mute audio 静音 声音'),
    _hit(SettingsSection.video, s.defaultVolume, 'volume audio mobile desktop 音量 声音 手机 桌面 默认'),
    _hit(SettingsSection.video, s.globalMute, 'mute all global audio silence 全局静音 所有 声音'),
    _hit(SettingsSection.video, s.fit, 'fit aspect ratio 画面比例 铺法 黑边'),
    _hit(SettingsSection.video, s.autoPip, 'picture in picture pip background 画中画 小窗 后台'),
    _hit(SettingsSection.video, s.keepScreenOn, 'keep screen awake wakelock 屏幕常亮 不熄屏'),
    // Danmaku.
    _hit(SettingsSection.danmaku, t.shield.enabled, 'shield block danmaku 屏蔽 弹幕'),
    _hit(SettingsSection.danmaku, t.shield.keywordsTitle, 'keyword block 屏蔽 关键词'),
    _hit(SettingsSection.danmaku, t.shield.usersTitle, 'user block 屏蔽 用户'),
    _hit(SettingsSection.danmaku, s.styleFontSize, 'font size 字号 弹幕'),
    _hit(SettingsSection.danmaku, s.styleSpeed, 'speed 速度 弹幕'),
    _hit(SettingsSection.danmaku, s.styleArea, 'area screen 显示区域 弹幕'),
    _hit(SettingsSection.danmaku, s.styleOpacity, 'opacity 透明 弹幕'),
    _hit(SettingsSection.danmaku, s.styleStroke, 'stroke outline 描边 弹幕'),
    _hit(SettingsSection.danmaku, s.styleReset, 'reset default 恢复默认 弹幕'),
    _hit(SettingsSection.danmaku, s.miniDanmakuVisible, 'pip danmaku 小窗 弹幕 画中画'),
    // Kernel.
    _hit(SettingsSection.kernel, s.engineTitle, 'player kernel mpv 播放内核'),
    _hit(SettingsSection.kernel, s.hardwareDecoding, 'hardware decoder hwdec gpu 硬件解码'),
    _hit(SettingsSection.kernel, s.superResolution, 'super resolution anime4k upscale shader 超分 超分辨率 画质增强'),
    _hit(SettingsSection.kernel, s.playerPresets, 'preset balanced compat rtx low latency network 预设 均衡 兼容 低配 弱网 低延迟'),
    _hit(SettingsSection.kernel, s.playerProxy, 'player proxy player network 播放器 代理'),
    _hit(SettingsSection.kernel, s.hardwareDecoder, 'hwdec decoder 硬件 解码器'),
    _hit(SettingsSection.kernel, s.customOutput, 'vo ao custom output 自定义 输出 驱动'),
    _hit(SettingsSection.kernel, s.videoOutput, 'vo video output 视频输出'),
    _hit(SettingsSection.kernel, s.audioOutput, 'ao audio output 音频输出'),
    _hit(SettingsSection.kernel, s.videoSync, 'video sync 视频同步'),
    _hit(SettingsSection.kernel, s.interpolation, 'interpolation 插帧'),
    _hit(SettingsSection.kernel, s.scaleKernel, 'scale scaler kernel 缩放 算法'),
    _hit(SettingsSection.kernel, s.deinterlace, 'deinterlace 反交错'),
    _hit(SettingsSection.kernel, s.hwdecCodecs, 'hwdec codecs 硬件解码 格式'),
    _hit(SettingsSection.kernel, s.audioExclusive, 'audio exclusive wasapi 独占 音频'),
    _hit(SettingsSection.kernel, s.forceDestroy, 'force destroy player 强制 销毁 播放器'),
    _hit(SettingsSection.kernel, s.mpvReset, 'reset mpv 恢复 默认'),
    _hit(SettingsSection.kernel, s.playerGuide, 'player guide manual 播放器 指南 文档'),
    // Recording.
    _hit(SettingsSection.recording, t.recorder.saveDirTitle, 'recording folder directory 录制 目录 文件夹'),
    _hit(SettingsSection.recording, t.recorder.namingTitle, 'recording name template 录制 命名 模板'),
    _hit(SettingsSection.recording, t.recorder.maxSizeTitle, 'recording size cap 录制 大小 上限'),
    _hit(SettingsSection.recording, t.recorder.segmentTitle, 'segment duration 录制 分段 时长'),
    _hit(SettingsSection.recording, t.recorder.readTimeoutTitle, 'read timeout 录制 超时'),
    _hit(SettingsSection.recording, t.recorder.restartTitle, 'retry reconnect 录制 重试 重连'),
    _hit(SettingsSection.recording, t.recorder.backoffTitle, 'retry delay 录制 重试 间隔'),
    _hit(SettingsSection.recording, t.recorder.stallTitle, 'stall 卡流 录制'),
    _hit(SettingsSection.recording, t.recorder.preferBestTitle, 'best stream audio video 录制 首路'),
    _hit(SettingsSection.recording, t.recorder.verifyTitle, 'verify 录制 校验 文件'),
    _hit(SettingsSection.recording, t.recorder.containerTitle, 'container ts mp4 录制 格式'),
    _hit(SettingsSection.recording, t.recorder.keepAliveTitle, 'background keep alive 录制 后台'),
    _hit(SettingsSection.recording, t.recorder.queueTitle, 'queue 录制 队列'),
    _hit(SettingsSection.recording, t.recorder.maxTasksTitle, 'concurrent tasks 录制 并发 任务'),
    _hit(SettingsSection.recording, t.recorder.watermarkTitle, 'disk space 录制 磁盘 余量'),
    // Sites and accounts.
    _hit(SettingsSection.sources, s.sitesDisplay, 'platform show hide 平台 显示 隐藏'),
    _hit(SettingsSection.sources, s.preferPlatform, 'preferred platform 首选 平台'),
    _hit(SettingsSection.sources, s.sitesOrderReset, 'platform order 平台 顺序 恢复'),
    _hit(SettingsSection.sources, t.account.cookieLogin, 'account cookie login 账号 登录 cookie'),
    _hit(SettingsSection.sources, t.account.signOut, 'logout account 退出 登录'),
    // Data.
    _hit(SettingsSection.dataCache, s.historyLimit, 'history limit 历史 上限'),
    _hit(SettingsSection.dataCache, s.dataClearHistory, 'clear history 清空 历史'),
    _hit(SettingsSection.dataCache, s.dataExportFollows, 'export follows clipboard 导出 关注'),
    _hit(SettingsSection.dataCache, s.dataImportFollows, 'import follows clipboard 导入 关注'),
    // Backup.
    _hit(SettingsSection.backup, t.backup.createTitle, 'backup create 备份 创建'),
    _hit(SettingsSection.backup, t.backup.createFollowsTitle, 'follows backup 关注 备份'),
    _hit(SettingsSection.backup, t.backup.folderTitle, 'backup folder 备份 文件夹'),
    _hit(SettingsSection.backup, t.backup.webdavConfigTitle, 'webdav server 服务器 同步'),
    _hit(SettingsSection.backup, t.backup.webdavUpload, 'webdav upload 上传 备份'),
    _hit(SettingsSection.backup, t.backup.webdavDownload, 'webdav download restore 下载 恢复'),
    // Cache.
    _hit(SettingsSection.dataCache, s.cacheSize, 'cache size 缓存 大小'),
    _hit(SettingsSection.dataCache, s.cacheClear, 'clear cache 清除 缓存'),
    _hit(SettingsSection.dataCache, s.cacheLimit, 'cache limit 缓存 上限'),
    // IPTV.
    _hit(SettingsSection.iptv, t.iptv.updateInterval, 'epg interval 节目单 更新 间隔'),
    _hit(SettingsSection.iptv, t.iptv.autoUpdate, 'epg auto update 节目单 自动更新'),
    _hit(SettingsSection.iptv, t.iptv.syncAll, 'sync all playlists 同步 全部 播放列表'),
    _hit(SettingsSection.iptv, t.iptv.customUserAgent, 'user agent ua header 请求头 自定义'),
    // VOD.
    _hit(SettingsSection.vod, s.vodQuality, 'bilibili quality 视频 清晰度'),
    _hit(SettingsSection.vod, t.account.cookieLogin, 'bilibili account login 账号 登录'),
    // About.
    _hit(SettingsSection.about, s.aboutVersion, 'version build 版本'),
    _hit(SettingsSection.about, s.checkUpdate, 'update latest 更新 检查'),
    _hit(SettingsSection.about, s.releaseHistory, 'release changelog 版本记录 更新内容'),
    _hit(SettingsSection.about, s.configPreview, 'config json backup export 配置 预览 导出 json'),
    _hit(SettingsSection.about, s.aboutProject, 'project github 项目 主页'),
    _hit(SettingsSection.about, s.aboutLicense, 'license open source 开源 许可'),
  ];
}

/// The catalogue's rows whose title or keywords contain [query] (already
/// trimmed and lower case), inside [sections] and its menu order.
List<SettingsSearchHit> settingsSearchHits(Translations t, String query, Iterable<SettingsSection> sections) {
  if (query.isEmpty) return const [];
  final allowed = sections.toSet();
  final seen = <String>{};
  return [
    for (final hit in settingsSearchCatalog(t))
      if (allowed.contains(hit.section) &&
          (hit.title.toLowerCase().contains(query) || hit.keywords.toLowerCase().contains(query)) &&
          seen.add('${hit.section.name}\u0000${hit.title}'))
        hit,
  ];
}
