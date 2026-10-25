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
    _hit(SettingsSection.general, s.crossSpacing, 'column gap spacing 列间距 网格'),
    _hit(SettingsSection.general, s.mainSpacing, 'row gap spacing 行间距 网格'),
    _hit(SettingsSection.general, s.audienceMetric, 'audience viewers metric 观众 在线 热度 累计'),
    _hit(SettingsSection.general, s.windowChrome, 'title bar caption 标题栏 窗口'),
    _hit(SettingsSection.general, s.closeAction, 'close window quit minimise tray 关闭 退出 最小化'),
    // Appearance.
    _hit(SettingsSection.appearance, s.themeMode, 'theme dark light system 主题 深色 浅色 跟随系统'),
    _hit(SettingsSection.appearance, s.themeSeed, 'accent seed color 主题色 取色 配色'),
    _hit(SettingsSection.appearance, s.corners, 'corner radius round 圆角 直角 胶囊'),
    _hit(SettingsSection.appearance, s.contrast, 'contrast border 对比度 边界'),
    _hit(SettingsSection.appearance, s.selectionStyle, 'selection highlight 选中 高亮'),
    _hit(SettingsSection.appearance, s.autoClash, 'clash danger success 撞色 避让 状态色'),
    _hit(SettingsSection.appearance, s.font, 'font typeface 字体 字型'),
    _hit(SettingsSection.appearance, s.language, 'language locale 语言 中文 english'),
    _hit(SettingsSection.appearance, s.density, 'density compact touch 密度 紧凑 触控'),
    _hit(SettingsSection.appearance, s.pureBlack, 'oled black dark 纯黑 深色'),
    // Background.
    _hit(SettingsSection.background, s.backgroundKind, 'background image video wallpaper 背景 图片 视频'),
    _hit(SettingsSection.background, s.backgroundImageAddress, 'image url 图片 地址'),
    _hit(SettingsSection.background, s.backgroundVideoAddress, 'video url 视频 地址'),
    _hit(SettingsSection.background, s.backgroundFit, 'fit fill cover 填充 裁切'),
    _hit(SettingsSection.background, s.backgroundMask, 'mask dim 遮罩 压暗'),
    _hit(SettingsSection.background, s.backgroundBlur, 'blur 模糊 高斯'),
    _hit(SettingsSection.background, s.backgroundSolid, 'solid color fill wallpaper 纯色 背景 颜色'),
    _hit(SettingsSection.background, s.backgroundGradient, 'gradient wallpaper 渐变 背景'),
    _hit(SettingsSection.background, s.backgroundGallery, 'wallpaper gallery 图库 壁纸 背景'),
    _hit(SettingsSection.background, s.backgroundLibraryBrowse, 'wallpaper library official wallhaven bing deepin 图库 壁纸 官方 必应'),
    _hit(SettingsSection.background, s.backgroundClear, 'remove background 清除 背景'),
    // Navigation.
    _hit(SettingsSection.nav, s.multiviewVisible, 'multiview 多画面 入口 侧栏'),
    _hit(SettingsSection.nav, s.toolsOrder, 'tool order sidebar 工具 排序 侧栏'),
    // Refresh.
    _hit(SettingsSection.refresh, s.followsAutoRefresh, 'auto refresh follows 自动刷新 关注'),
    _hit(SettingsSection.refresh, s.refreshInterval, 'interval 刷新 间隔'),
    _hit(SettingsSection.refresh, s.refreshOnResume, 'resume refresh 返回应用 刷新'),
    // Network.
    _hit(SettingsSection.network, s.proxy, 'proxy http 代理 网络'),
    _hit(SettingsSection.network, s.proxyHost, 'proxy host 主机 代理'),
    _hit(SettingsSection.network, s.proxyPort, 'proxy port 端口 代理'),
    // Video.
    _hit(SettingsSection.video, s.preferredQuality, 'quality resolution 画质 清晰度 分辨率'),
    _hit(SettingsSection.video, s.defaultMuted, 'mute audio 静音 声音'),
    _hit(SettingsSection.video, s.defaultVolume, 'volume audio 音量 声音'),
    _hit(SettingsSection.video, s.fit, 'fit aspect ratio 画面比例 铺法 黑边'),
    _hit(SettingsSection.video, s.autoPip, 'picture in picture pip background 画中画 小窗 后台'),
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
    _hit(SettingsSection.miniDanmaku, s.miniDanmakuVisible, 'pip danmaku 小窗 弹幕 画中画'),
    // Kernel.
    _hit(SettingsSection.kernel, s.engineTitle, 'player kernel mpv 播放内核'),
    _hit(SettingsSection.kernel, s.hardwareDecoding, 'hardware decoder hwdec gpu 硬件解码'),
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
    _hit(SettingsSection.sites, s.sitesDisplay, 'platform show hide 平台 显示 隐藏'),
    _hit(SettingsSection.sites, s.preferPlatform, 'preferred platform 首选 平台'),
    _hit(SettingsSection.sites, s.sitesOrderReset, 'platform order 平台 顺序 恢复'),
    _hit(SettingsSection.sites, t.account.cookieLogin, 'account cookie login 账号 登录 cookie'),
    _hit(SettingsSection.sites, t.account.signOut, 'logout account 退出 登录'),
    // Data.
    _hit(SettingsSection.data, s.historyLimit, 'history limit 历史 上限'),
    _hit(SettingsSection.data, s.dataClearHistory, 'clear history 清空 历史'),
    _hit(SettingsSection.data, s.dataExportFollows, 'export follows clipboard 导出 关注'),
    _hit(SettingsSection.data, s.dataImportFollows, 'import follows clipboard 导入 关注'),
    // Backup.
    _hit(SettingsSection.backup, t.backup.createTitle, 'backup create 备份 创建'),
    _hit(SettingsSection.backup, t.backup.createFollowsTitle, 'follows backup 关注 备份'),
    _hit(SettingsSection.backup, t.backup.folderTitle, 'backup folder 备份 文件夹'),
    _hit(SettingsSection.backup, t.backup.webdavConfigTitle, 'webdav server 服务器 同步'),
    _hit(SettingsSection.backup, t.backup.webdavUpload, 'webdav upload 上传 备份'),
    _hit(SettingsSection.backup, t.backup.webdavDownload, 'webdav download restore 下载 恢复'),
    // Cache.
    _hit(SettingsSection.cache, s.cacheSize, 'cache size 缓存 大小'),
    _hit(SettingsSection.cache, s.cacheClear, 'clear cache 清除 缓存'),
    _hit(SettingsSection.cache, s.cacheLimit, 'cache limit 缓存 上限'),
    // IPTV.
    _hit(SettingsSection.iptv, t.iptv.updateInterval, 'epg interval 节目单 更新 间隔'),
    _hit(SettingsSection.iptv, t.iptv.autoUpdate, 'epg auto update 节目单 自动更新'),
    _hit(SettingsSection.iptv, t.iptv.syncAll, 'sync all playlists 同步 全部 播放列表'),
    // VOD.
    _hit(SettingsSection.vod, s.vodQuality, 'bilibili quality 视频 清晰度'),
    _hit(SettingsSection.vod, t.account.cookieLogin, 'bilibili account login 账号 登录'),
    // About.
    _hit(SettingsSection.about, s.aboutVersion, 'version build 版本'),
    _hit(SettingsSection.about, s.checkUpdate, 'update latest 更新 检查'),
    _hit(SettingsSection.about, s.releaseHistory, 'release changelog 版本记录 更新内容'),
    _hit(SettingsSection.about, s.aboutProject, 'project github 项目 主页'),
    _hit(SettingsSection.about, s.aboutLicense, 'license open source 开源 许可'),
  ];
}

/// The catalogue's rows whose title or keywords contain [query] (already
/// trimmed and lower case), inside [sections] and its menu order.
List<SettingsSearchHit> settingsSearchHits(
  Translations t,
  String query,
  Iterable<SettingsSection> sections,
) {
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
