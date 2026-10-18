///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

part of 'strings.g.dart';

// Path: <root>
typedef TranslationsZh = Translations; // ignore: unused_element
class Translations with BaseTranslations<AppLocale, Translations> {
	/// Returns the current translations of the given [context].
	///
	/// Usage:
	/// final t = Translations.of(context);
	static Translations of(BuildContext context) => InheritedLocaleData.of<AppLocale, Translations>(context).translations;

	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	Translations({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.zh,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ) {
		_meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <zh>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	/// Access flat map
	dynamic operator[](String key) => _meta.getTranslation(key);

	late final Translations _root = this; // ignore: unused_field

	Translations $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => Translations(meta: meta ?? this.$meta);

	// Translations
	late final Translations$app$zh app = Translations$app$zh.internal(_root);
	late final Translations$splash$zh splash = Translations$splash$zh.internal(_root);
	late final Translations$home$zh home = Translations$home$zh.internal(_root);
	late final Translations$common$zh common = Translations$common$zh.internal(_root);
	late final Translations$tray$zh tray = Translations$tray$zh.internal(_root);
	late final Translations$login$zh login = Translations$login$zh.internal(_root);
	late final Translations$account$zh account = Translations$account$zh.internal(_root);
	late final Translations$settings$zh settings = Translations$settings$zh.internal(_root);
	late final Translations$hotAreas$zh hotAreas = Translations$hotAreas$zh.internal(_root);
	late final Translations$tags$zh tags = Translations$tags$zh.internal(_root);
	late final Translations$logs$zh logs = Translations$logs$zh.internal(_root);
	late final Translations$recorder$zh recorder = Translations$recorder$zh.internal(_root);
	late final Translations$theme$zh theme = Translations$theme$zh.internal(_root);
	late final Translations$design$zh design = Translations$design$zh.internal(_root);
	late final Translations$history$zh history = Translations$history$zh.internal(_root);
	late final Translations$iptv$zh iptv = Translations$iptv$zh.internal(_root);
	late final Translations$fonts$zh fonts = Translations$fonts$zh.internal(_root);
	late final Translations$follow$zh follow = Translations$follow$zh.internal(_root);
	late final Translations$toolbox$zh toolbox = Translations$toolbox$zh.internal(_root);
	late final Translations$backup$zh backup = Translations$backup$zh.internal(_root);
	late final Translations$about$zh about = Translations$about$zh.internal(_root);
	late final Translations$shield$zh shield = Translations$shield$zh.internal(_root);
	late final Translations$multiview$zh multiview = Translations$multiview$zh.internal(_root);
	late final Translations$search$zh search = Translations$search$zh.internal(_root);
	late final Translations$room$zh room = Translations$room$zh.internal(_root);
	late final Translations$areas$zh areas = Translations$areas$zh.internal(_root);
	late final Translations$popular$zh popular = Translations$popular$zh.internal(_root);
	late final Translations$remoteSync$zh remoteSync = Translations$remoteSync$zh.internal(_root);
	late final Translations$errors$zh errors = Translations$errors$zh.internal(_root);
	late final Translations$tabs$zh tabs = Translations$tabs$zh.internal(_root);
	late final Translations$window$zh window = Translations$window$zh.internal(_root);
	late final Translations$closePrompt$zh closePrompt = Translations$closePrompt$zh.internal(_root);
	late final Translations$shellSettings$zh shellSettings = Translations$shellSettings$zh.internal(_root);
	late final Translations$webdav$zh webdav = Translations$webdav$zh.internal(_root);
	late final Translations$wallpaper$zh wallpaper = Translations$wallpaper$zh.internal(_root);
}

// Path: app
class Translations$app$zh {
	Translations$app$zh.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh: 'Pure Live'
	String get title => 'Pure Live';
}

// Path: splash
class Translations$splash$zh {
	Translations$splash$zh.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh: '欢迎使用'
	String get welcome => '欢迎使用';
}

// Path: home
class Translations$home$zh {
	Translations$home$zh.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh: '推荐流'
	String get recommended => '推荐流';
}

// Path: common
class Translations$common$zh {
	Translations$common$zh.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh: '确定'
	String get confirm => '确定';

	/// zh: '取消'
	String get cancel => '取消';

	/// zh: '立即重启'
	String get restartNow => '立即重启';

	/// zh: '稍后'
	String get restartLater => '稍后';

	/// zh: '重试'
	String get retry => '重试';

	/// zh: '关闭'
	String get close => '关闭';

	/// zh: '保存'
	String get save => '保存';

	/// zh: '清空'
	String get clear => '清空';

	/// zh: '加载中'
	String get loading => '加载中';

	/// zh: '暂无内容'
	String get empty => '暂无内容';

	/// zh: '第 {page: int} / {total: int} 页'
	String pageOf({required int page, required int total}) => '第 ${page} / ${total} 页';

	/// zh: '返回'
	String get back => '返回';

	/// zh: '菜单'
	String get menu => '菜单';

	/// zh: '更多'
	String get more => '更多';

	/// zh: '关闭'
	String get off => '关闭';

	/// zh: '刷新'
	String get refresh => '刷新';

	/// zh: '上一页'
	String get prevPage => '上一页';

	/// zh: '下一页'
	String get nextPage => '下一页';

	/// zh: '每页'
	String get perPage => '每页';

	/// zh: '跳转至'
	String get goTo => '跳转至';

	/// zh: '页'
	String get pageUnit => '页';

	/// zh: '回到顶部'
	String get toTop => '回到顶部';

	/// zh: '到底部'
	String get toBottom => '到底部';

	/// zh: '添加'
	String get addOne => '添加';
}

// Path: tray
class Translations$tray$zh {
	Translations$tray$zh.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh: '显示主界面'
	String get show => '显示主界面';

	/// zh: '退出'
	String get quit => '退出';
}

// Path: login
class Translations$login$zh {
	Translations$login$zh.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh: '扫码登录'
	String get title => '扫码登录';

	/// zh: '生成二维码中'
	String get generating => '生成二维码中';

	/// zh: '等待扫描'
	String get waitingScan => '等待扫描';

	/// zh: '打开 bilibili App 扫描二维码并确认登录'
	String get scanHint => '打开 bilibili App 扫描二维码并确认登录';

	/// zh: '登录成功'
	String get success => '登录成功';

	/// zh: '欢迎，{name: String}'
	String welcome({required String name}) => '欢迎，${name}';

	/// zh: '二维码已过期'
	String get expired => '二维码已过期';

	/// zh: '刷新二维码'
	String get refreshQr => '刷新二维码';

	/// zh: '登录未能完成'
	String get failed => '登录未能完成';

	/// zh: '完成'
	String get done => '完成';

	/// zh: '当前构建未启用 bilibili 登录'
	String get unsupported => '当前构建未启用 bilibili 登录';

	/// zh: 'bilibili 扫码'
	String get platformBilibili => 'bilibili 扫码';

	/// zh: '斗鱼 Cookie'
	String get platformDouyu => '斗鱼 Cookie';

	/// zh: '虎牙 Cookie'
	String get platformHuya => '虎牙 Cookie';

	/// zh: 'Cookie: a=b; c=d ...'
	String get cookiePlaceholder => 'Cookie: a=b; c=d ...';

	/// zh: '验证并登录'
	String get verify => '验证并登录';

	/// zh: '在浏览器网络面板中复制已登录 www.douyu.com 请求的 Cookie 头，粘贴到此处。'
	String get douyuCookieHint => '在浏览器网络面板中复制已登录 www.douyu.com 请求的 Cookie 头，粘贴到此处。';

	/// zh: '在浏览器网络面板中复制已登录 www.huya.com 请求的 Cookie 头，粘贴到此处。'
	String get huyaCookieHint => '在浏览器网络面板中复制已登录 www.huya.com 请求的 Cookie 头，粘贴到此处。';

	/// zh: '当前构建未启用 {site: String} 登录'
	String unsupportedSite({required String site}) => '当前构建未启用 ${site} 登录';
}

// Path: account
class Translations$account$zh {
	Translations$account$zh.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh: '账号'
	String get title => '账号';

	/// zh: '未登录'
	String get notSignedIn => '未登录';

	/// zh: '登录后，直播相关请求将携带你的账号信息。'
	String get notSignedInHint => '登录后，直播相关请求将携带你的账号信息。';

	/// zh: '退出登录'
	String get signOut => '退出登录';

	/// zh: '退出 {site: String} 登录？'
	String signOutConfirm({required String site}) => '退出 ${site} 登录？';

	/// zh: '本机保存的登录凭据将被移除。'
	String get signOutHint => '本机保存的登录凭据将被移除。';

	/// zh: 'ID {id: String}'
	String userId({required String id}) => 'ID ${id}';

	/// zh: 'bilibili 账号'
	String get platformBilibili => 'bilibili 账号';

	/// zh: '斗鱼账号'
	String get platformDouyu => '斗鱼账号';

	/// zh: '虎牙账号'
	String get platformHuya => '虎牙账号';

	/// zh: '这个构建还没有可登录的平台'
	String get noAuthSites => '这个构建还没有可登录的平台';

	/// zh: '清除全部账号'
	String get clearAllAccounts => '清除全部账号';

	/// zh: '退出所有平台并删除已存的登录信息'
	String get clearAllAccountsHint => '退出所有平台并删除已存的登录信息';
}

// Path: settings
class Translations$settings$zh {
	Translations$settings$zh.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh: '外观'
	String get appearance => '外观';

	/// zh: '字体管理'
	String get fonts => '字体管理';

	/// zh: '主题模式'
	String get themeMode => '主题模式';

	/// zh: '设计语言'
	String get designLanguage => '设计语言';

	/// zh: '强调色'
	String get accent => '强调色';

	/// zh: '纯黑模式'
	String get pureBlack => '纯黑模式';

	/// zh: '密度'
	String get density => '密度';

	/// zh: '字体大小'
	String get fontScale => '字体大小';

	/// zh: '透明度'
	String get transparency => '透明度';

	/// zh: '减少透明效果'
	String get reduceTransparency => '减少透明效果';

	/// zh: '动画'
	String get animations => '动画';

	/// zh: '焦点轮廓'
	String get focusOutline => '焦点轮廓';

	/// zh: '主题与外观'
	String get sectionTheme => '主题与外观';

	/// zh: 'IPTV'
	String get sectionIptv => 'IPTV';

	/// zh: '弹幕'
	String get sectionDanmaku => '弹幕';

	/// zh: '数据'
	String get sectionData => '数据';

	/// zh: '备份'
	String get sectionBackup => '备份';

	/// zh: '主题模式、色彩、密度与动效'
	String get appearanceSubtitle => '主题模式、色彩、密度与动效';

	/// zh: '下载并应用云端字体'
	String get fontsSubtitle => '下载并应用云端字体';

	/// zh: '管理播放源与频道'
	String get iptvSubtitle => '管理播放源与频道';

	/// zh: '按关键词、用户或正则屏蔽弹幕'
	String get shieldSubtitle => '按关键词、用户或正则屏蔽弹幕';

	/// zh: '账号'
	String get sectionAccount => '账号';

	/// zh: '登录平台账号'
	String get scanToLogin => '登录平台账号';

	/// zh: '平台账号与登录态'
	String get accountSubtitle => '平台账号与登录态';

	/// zh: '缓存与数据'
	String get cacheAndData => '缓存与数据';

	/// zh: '观看历史与本地数据'
	String get cacheAndDataSubtitle => '观看历史与本地数据';

	/// zh: '备份与恢复本地数据'
	String get backupSubtitle => '备份与恢复本地数据';

	/// zh: '主题'
	String get groupTheme => '主题';

	/// zh: '字体'
	String get groupFontFamily => '字体';

	/// zh: '文字大小'
	String get groupTextSize => '文字大小';

	/// zh: '跟随系统，或始终浅色、始终深色'
	String get themeModeSubtitle => '跟随系统，或始终浅色、始终深色';

	/// zh: '整个应用绘制所用的设计语言'
	String get designLanguageSubtitle => '整个应用绘制所用的设计语言';

	/// zh: '切换设计语言'
	String get designLanguageRestartTitle => '切换设计语言';

	/// zh: '设计语言决定应用使用哪套宿主，只在下次启动生效。本次仍使用「{current: String}」绘制。现在重启应用？'
	String designLanguageRestartConfirm({required String current}) => '设计语言决定应用使用哪套宿主，只在下次启动生效。本次仍使用「${current}」绘制。现在重启应用？';

	/// zh: '重启后切换为 {name: String}'
	String designLanguagePending({required String name}) => '重启后切换为 ${name}';

	/// zh: '控件着色所用的颜色'
	String get accentSubtitle => '控件着色所用的颜色';

	/// zh: '布局的紧凑程度'
	String get densitySubtitle => '布局的紧凑程度';

	/// zh: '深色表面绘制为纯黑，适合 OLED 屏幕'
	String get pureBlackSubtitle => '深色表面绘制为纯黑，适合 OLED 屏幕';

	/// zh: '玻璃与遮罩透明度的倍率'
	String get transparencySubtitle => '玻璃与遮罩透明度的倍率';

	/// zh: '强制不透明表面并禁用模糊'
	String get reduceTransparencySubtitle => '强制不透明表面并禁用模糊';

	/// zh: '是否开启动效'
	String get animationsSubtitle => '是否开启动效';

	/// zh: '聚焦控件显示可见轮廓'
	String get focusOutlineSubtitle => '聚焦控件显示可见轮廓';

	/// zh: '所有字体大小的倍率'
	String get fontScaleSubtitle => '所有字体大小的倍率';

	/// zh: '千里之行，始于足下'
	String get previewText => '千里之行，始于足下';

	/// zh: '当前：{name: String}'
	String fontFamilyCurrent({required String name}) => '当前：${name}';

	/// zh: '默认'
	String get defaultOption => '默认';

	/// zh: '观看历史'
	String get historyEntry => '观看历史';

	/// zh: '{count: int} 条记录'
	String historyCount({required int count}) => '${count} 条记录';

	/// zh: '清空观看历史'
	String get clearHistory => '清空观看历史';

	/// zh: '删除本机全部观看记录'
	String get clearHistorySubtitle => '删除本机全部观看记录';

	/// zh: '观看历史已清空'
	String get historyCleared => '观看历史已清空';

	/// zh: '通用'
	String get general => '通用';

	/// zh: '刷新、启动、倒计时关闭与窗口'
	String get generalSubtitle => '刷新、启动、倒计时关闭与窗口';

	/// zh: '通用'
	String get sectionGeneral => '通用';

	/// zh: '刷新'
	String get refreshSettings => '刷新';

	/// zh: '前台刷新间隔与恢复阈值'
	String get refreshSettingsSubtitle => '前台刷新间隔与恢复阈值';

	/// zh: '页面设置'
	String get pageSettings => '页面设置';

	/// zh: '显示哪些页签及其顺序'
	String get pageSettingsSubtitle => '显示哪些页签及其顺序';

	/// zh: '导航'
	String get navigationSettings => '导航';

	/// zh: '应用启动位置'
	String get navigationSettingsSubtitle => '应用启动位置';

	/// zh: '列表显示'
	String get sectionFeedDisplay => '列表显示';

	/// zh: '加载样式'
	String get loadingStyle => '加载样式';

	/// zh: '加载占位的呈现方式'
	String get loadingStyleSubtitle => '加载占位的呈现方式';

	/// zh: '房间卡片'
	String get roomCardSettings => '房间卡片';

	/// zh: '圆角、封面比例与信息行'
	String get roomCardSettingsSubtitle => '圆角、封面比例与信息行';

	/// zh: '网络'
	String get sectionNetwork => '网络';

	/// zh: '网络代理'
	String get proxySettings => '网络代理';

	/// zh: '通过代理转发请求'
	String get proxySettingsSubtitle => '通过代理转发请求';

	/// zh: '回到前台时刷新'
	String get refreshOnResume => '回到前台时刷新';

	/// zh: '离开足够久后回到应用时刷新列表'
	String get refreshOnResumeSubtitle => '离开足够久后回到应用时刷新列表';

	/// zh: '启动时检查更新'
	String get autoCheckUpdate => '启动时检查更新';

	/// zh: '从发布源检查新版本；关于页随时可以手动检查'
	String get autoCheckUpdateSubtitle => '从发布源检查新版本；关于页随时可以手动检查';

	/// zh: '倒计时退出'
	String get countdownClose => '倒计时退出';

	/// zh: '倒计时结束后退出应用'
	String get countdownCloseSubtitle => '倒计时结束后退出应用';

	/// zh: '倒计时时长'
	String get countdownDuration => '倒计时时长';

	/// zh: '{minutes: int} 分钟'
	String minutesValue({required int minutes}) => '${minutes} 分钟';

	/// zh: '离开 {minutes: int} 分钟后'
	String minutesAway({required int minutes}) => '离开 ${minutes} 分钟后';

	/// zh: '启动页'
	String get launchPage => '启动页';

	/// zh: '应用启动所在的页签。导航设置可以让上次访问的页签优先。'
	String get launchPageHint => '应用启动所在的页签。导航设置可以让上次访问的页签优先。';

	/// zh: '窗口大小'
	String get windowSize => '窗口大小';

	/// zh: '启动默认'
	String get windowSizeDefault => '启动默认';

	/// zh: '立即生效，并在下次启动时沿用。'
	String get windowSizeHint => '立即生效，并在下次启动时沿用。';

	/// zh: '自动刷新'
	String get groupAutoRefresh => '自动刷新';

	/// zh: '前台刷新间隔'
	String get autoRefreshInterval => '前台刷新间隔';

	/// zh: '当前列表自动刷新的间隔。默认关闭。'
	String get autoRefreshIntervalHint => '当前列表自动刷新的间隔。默认关闭。';

	/// zh: '恢复刷新阈值'
	String get refreshResumeThreshold => '恢复刷新阈值';

	/// zh: '离开多久后才值得在回到前台时刷新。'
	String get refreshResumeThresholdHint => '离开多久后才值得在回到前台时刷新。';

	/// zh: '关闭'
	String get refreshOff => '关闭';

	/// zh: '每次回到前台'
	String get refreshEveryResume => '每次回到前台';

	/// zh: '显示的页签'
	String get groupVisibleBranches => '显示的页签';

	/// zh: '隐藏的页签'
	String get groupHiddenBranches => '隐藏的页签';

	/// zh: '在外壳中显示此页签'
	String get showBranchSubtitle => '在外壳中显示此页签';

	/// zh: '拖动排序。至少保留一个页签。'
	String get pageSettingsHint => '拖动排序。至少保留一个页签。';

	/// zh: '至少需要保留一个页签'
	String get atLeastOneBranch => '至少需要保留一个页签';

	/// zh: '启动'
	String get groupLaunch => '启动';

	/// zh: '回到上次的位置'
	String get restoreLastTab => '回到上次的位置';

	/// zh: '启动时回到上次访问的页签'
	String get restoreLastTabSubtitle => '启动时回到上次访问的页签';

	/// zh: '启动时回到上次访问的页签（上次：{branch: String}）'
	String restoreLastTabOn({required String branch}) => '启动时回到上次访问的页签（上次：${branch}）';

	/// zh: '决定启动页跳转的目标；更改在下次启动生效。'
	String get navigationHint => '决定启动页跳转的目标；更改在下次启动生效。';

	/// zh: '代理'
	String get proxyGroup => '代理';

	/// zh: '使用代理'
	String get proxyEnable => '使用代理';

	/// zh: '通过下方代理转发请求'
	String get proxyEnableSubtitle => '通过下方代理转发请求';

	/// zh: '代理地址'
	String get proxyEndpoint => '代理地址';

	/// zh: '地址'
	String get proxyHost => '地址';

	/// zh: '端口'
	String get proxyPort => '端口';

	/// zh: '端口需在 1-65535 之间'
	String get proxyPortInvalid => '端口需在 1-65535 之间';

	/// zh: '对新连接立即生效，无需重启。'
	String get proxyHint => '对新连接立即生效，无需重启。';

	/// zh: '预览'
	String get loadingPreview => '预览';

	/// zh: '微光骨架'
	String get loadingShimmer => '微光骨架';

	/// zh: '加载圈'
	String get loadingSpinner => '加载圈';

	/// zh: '无'
	String get loadingNone => '无';

	/// zh: '预览'
	String get roomCardPreview => '预览';

	/// zh: '外观'
	String get roomCardAppearance => '外观';

	/// zh: '圆角半径'
	String get roomCardRadius => '圆角半径';

	/// zh: '封面比例'
	String get roomCardAspect => '封面比例';

	/// zh: '16:9'
	String get aspectSixteenByNine => '16:9';

	/// zh: '4:3'
	String get aspectFourByThree => '4:3';

	/// zh: '1:1'
	String get aspectSquare => '1:1';

	/// zh: '显示内容'
	String get roomCardContent => '显示内容';

	/// zh: '平台角标'
	String get roomCardShowPlatform => '平台角标';

	/// zh: '封面上方的平台角标'
	String get roomCardShowPlatformSubtitle => '封面上方的平台角标';

	/// zh: '人气与状态'
	String get roomCardShowAudience => '人气与状态';

	/// zh: '观看人数、回放与离线角标'
	String get roomCardShowAudienceSubtitle => '观看人数、回放与离线角标';

	/// zh: '主播行'
	String get roomCardShowAnchor => '主播行';

	/// zh: '头像与主播名'
	String get roomCardShowAnchorSubtitle => '头像与主播名';

	/// zh: '作用于推荐、分区、关注与搜索的卡片网格。'
	String get roomCardScopeHint => '作用于推荐、分区、关注与搜索的卡片网格。';

	/// zh: '局域网同步'
	String get remoteSync => '局域网同步';

	/// zh: '将播放同步到同一网络下的其他设备'
	String get remoteSyncSubtitle => '将播放同步到同一网络下的其他设备';

	/// zh: '录制'
	String get sectionRecorder => '录制';

	/// zh: '监听房间，开播自动录制'
	String get recorderSubtitle => '监听房间，开播自动录制';

	/// zh: '粘贴 Cookie 登录'
	String get pasteCookie => '粘贴 Cookie 登录';

	/// zh: '已登录 {count: int} 个平台'
	String accountSignedInCount({required int count}) => '已登录 ${count} 个平台';

	/// zh: '视频与弹幕'
	String get sectionVideo => '视频与弹幕';

	/// zh: '视频与弹幕'
	String get video => '视频与弹幕';

	/// zh: '房间打开时的声音与弹幕'
	String get videoSubtitle => '房间打开时的声音与弹幕';

	/// zh: '弹幕'
	String get groupDanmaku => '弹幕';

	/// zh: '声音'
	String get groupAudio => '声音';

	/// zh: '弹幕外观'
	String get groupAppearance => '弹幕外观';

	/// zh: '本地互动'
	String get groupLocalInteraction => '本地互动';

	/// zh: '本地互动'
	String get localInteraction => '本地互动';

	/// zh: '开启后房间出现输入框，发送的弹幕只在自己画面显示'
	String get localInteractionSubtitle => '开启后房间出现输入框，发送的弹幕只在自己画面显示';

	/// zh: '本地昵称'
	String get localInteractionName => '本地昵称';

	/// zh: '默认显示弹幕'
	String get danmakuVisible => '默认显示弹幕';

	/// zh: '新房间打开时是否在画面上叠加弹幕'
	String get danmakuVisibleSubtitle => '新房间打开时是否在画面上叠加弹幕';

	/// zh: '默认音量'
	String get defaultVolume => '默认音量';

	/// zh: '下一个房间开始播放时的音量'
	String get defaultVolumeSubtitle => '下一个房间开始播放时的音量';

	/// zh: '界面语言'
	String get language => '界面语言';

	/// zh: '跟随系统，或指定一种语言'
	String get languageSubtitle => '跟随系统，或指定一种语言';

	/// zh: '跟随系统'
	String get languageSystem => '跟随系统';

	/// zh: '播放器调校'
	String get mpvTuning => '播放器调校';

	/// zh: 'libmpv 的输出、解码与缓存选项'
	String get mpvTuningSubtitle => 'libmpv 的输出、解码与缓存选项';

	/// zh: '输出'
	String get mpvOutputSection => '输出';

	/// zh: '自定义输出驱动'
	String get mpvCustomOutput => '自定义输出驱动';

	/// zh: '关闭时引擎使用平台默认输出;打开后驱动选择才会写入'
	String get mpvCustomOutputSubtitle => '关闭时引擎使用平台默认输出;打开后驱动选择才会写入';

	/// zh: '需先打开"自定义输出驱动"'
	String get mpvNeedsCustomOutput => '需先打开"自定义输出驱动"';

	/// zh: '视频输出 (vo)'
	String get mpvVideoOutput => '视频输出 (vo)';

	/// zh: '音频输出 (ao)'
	String get mpvAudioOutput => '音频输出 (ao)';

	/// zh: '解码与渲染'
	String get mpvDecodeSection => '解码与渲染';

	/// zh: '硬件解码 (hwdec)'
	String get mpvHardwareDecoder => '硬件解码 (hwdec)';

	/// zh: '去隔行 (deinterlace)'
	String get mpvDeinterlace => '去隔行 (deinterlace)';

	/// zh: '帧插值 (interpolation)'
	String get mpvInterpolation => '帧插值 (interpolation)';

	/// zh: '补帧更流畅,GPU 开销更高;仅桌面'
	String get mpvInterpolationSubtitle => '补帧更流畅,GPU 开销更高;仅桌面';

	/// zh: '缩放算法 (scale)'
	String get mpvScaler => '缩放算法 (scale)';

	/// zh: '缓存'
	String get mpvCacheSection => '缓存';

	/// zh: '流缓存秒数'
	String get mpvCacheSeconds => '流缓存秒数';

	/// zh: '0 表示不改引擎的默认缓存'
	String get mpvCacheSecondsSubtitle => '0 表示不改引擎的默认缓存';

	/// zh: '恢复默认'
	String get mpvReset => '恢复默认';

	/// zh: '清空本页全部调校选项'
	String get mpvResetSubtitle => '清空本页全部调校选项';

	/// zh: '生效方式'
	String get mpvEffectiveNote => '生效方式';

	/// zh: '视频/音频输出与硬件解码在下一次打开流时生效;其余选项即时应用到正在播放的房间。'
	String get mpvEffectiveNoteBody => '视频/音频输出与硬件解码在下一次打开流时生效;其余选项即时应用到正在播放的房间。';

	/// zh: '本地配置预览'
	String get localConfig => '本地配置预览';

	/// zh: '只读展示当前保存的设置文档'
	String get localConfigSubtitle => '只读展示当前保存的设置文档';

	/// zh: '本页只读;要修改请回到对应的设置项。'
	String get localConfigNote => '本页只读;要修改请回到对应的设置项。';

	/// zh: '复制该文档'
	String get localConfigCopy => '复制该文档';

	/// zh: '通用偏好'
	String get localConfigApp => '通用偏好';

	/// zh: '外观'
	String get localConfigAppearance => '外观';

	/// zh: '界面'
	String get areaInterface => '界面';

	/// zh: '内容来源'
	String get areaSources => '内容来源';

	/// zh: '播放'
	String get areaPlayback => '播放';

	/// zh: '通用'
	String get areaGeneral => '通用';

	/// zh: '数据'
	String get areaData => '数据';

	/// zh: '搜索设置'
	String get searchHint => '搜索设置';

	/// zh: '没有找到相关设置'
	String get searchEmpty => '没有找到相关设置';

	/// zh: '换个关键词试试'
	String get searchEmptyHint => '换个关键词试试';

	/// zh: '平台'
	String get platformsTitle => '平台';

	/// zh: '平台显示、排序与账号'
	String get platformsDesc => '平台显示、排序与账号';

	/// zh: '弹幕'
	String get danmakuTitle => '弹幕';

	/// zh: '弹幕显示、字号、透明度与屏蔽'
	String get danmakuDesc => '弹幕显示、字号、透明度与屏蔽';

	/// zh: '录制'
	String get recordingTitle => '录制';

	/// zh: '输出目录与分段时长'
	String get recordingDesc => '输出目录与分段时长';

	/// zh: '播放器'
	String get playerTitle => '播放器';

	/// zh: '解码、输出与缓存调优'
	String get playerDesc => '解码、输出与缓存调优';

	/// zh: '日志'
	String get logTitle => '日志';

	/// zh: '日志级别与导出'
	String get logDesc => '日志级别与导出';

	/// zh: '本地弹幕身份与开关'
	String get localInteractionDesc => '本地弹幕身份与开关';

	/// zh: '弹幕颜色'
	String get localInteractionColor => '弹幕颜色';

	/// zh: '导航栏显示与启动页'
	String get navigationDesc => '导航栏显示与启动页';

	/// zh: '音量、清晰度与后台播放'
	String get videoDesc => '音量、清晰度与后台播放';

	/// zh: '自动刷新与开播提醒'
	String get refreshDesc => '自动刷新与开播提醒';

	/// zh: '启动、更新与窗口'
	String get generalDesc => '启动、更新与窗口';

	/// zh: '应用与播放器代理'
	String get proxyDesc => '应用与播放器代理';

	/// zh: '缓存大小与清理'
	String get cacheDesc => '缓存大小与清理';

	/// zh: '备份与恢复本地数据'
	String get backupDesc => '备份与恢复本地数据';

	/// zh: '管理播放源与频道'
	String get iptvDesc => '管理播放源与频道';

	/// zh: '分页与翻页方式'
	String get pageDesc => '分页与翻页方式';

	/// zh: '分页条（电脑）'
	String get pagerGroup => '分页条（电脑）';

	/// zh: '默认每页条数'
	String get pageDefaultSize => '默认每页条数';

	/// zh: '进入列表时每页显示多少条；分页条上也能临时改'
	String get pageDefaultSizeHint => '进入列表时每页显示多少条；分页条上也能临时改';

	/// zh: '自动'
	String get pageSizeAuto => '自动';

	/// zh: '条/页'
	String get itemsPerPage => '条/页';

	/// zh: '单页可选数量列表'
	String get pageSizeOptionsTitle => '单页可选数量列表';

	/// zh: '恢复推荐'
	String get pageSizeRestore => '恢复推荐';

	/// zh: '输入 1–100'
	String get pageSizeInputHint => '输入 1–100';

	/// zh: '请输入 1 至 100 的整数'
	String get pageSizeRangeError => '请输入 1 至 100 的整数';

	/// zh: '该单页数量已在列表中'
	String get pageSizeDuplicateError => '该单页数量已在列表中';

	/// zh: '当前已启用的可选项'
	String get pageSizeCurrent => '当前已启用的可选项';

	/// zh: '显示一键置顶按钮'
	String get pageShowScrollTop => '显示一键置顶按钮';

	/// zh: '列表滑动超过设定距离后在右下角悬浮置顶按钮'
	String get pageShowScrollTopSubtitle => '列表滑动超过设定距离后在右下角悬浮置顶按钮';

	/// zh: '显示单页数量选择器'
	String get pageShowSizeSelector => '显示单页数量选择器';

	/// zh: '在列表控制条显示每页显示行数下拉选单'
	String get pageShowSizeSelectorSubtitle => '在列表控制条显示每页显示行数下拉选单';

	/// zh: '显示页码跳转按钮'
	String get pageShowGoto => '显示页码跳转按钮';

	/// zh: '开启后支持手动输入页码进行快速跳转'
	String get pageShowGotoSubtitle => '开启后支持手动输入页码进行快速跳转';

	/// zh: '只读展示当前保存的设置'
	String get configPreviewDesc => '只读展示当前保存的设置';
}

// Path: hotAreas
class Translations$hotAreas$zh {
	Translations$hotAreas$zh.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh: '平台显示'
	String get title => '平台显示';

	/// zh: '隐藏的平台不会出现在热门、分区与搜索中。'
	String get note => '隐藏的平台不会出现在热门、分区与搜索中。';

	/// zh: '拖动调整平台的显示顺序。'
	String get orderNote => '拖动调整平台的显示顺序。';

	/// zh: '显示'
	String get visible => '显示';

	/// zh: '隐藏'
	String get hidden => '隐藏';

	/// zh: '恢复默认'
	String get restore => '恢复默认';

	/// zh: '至少保留一个平台'
	String get keepAtLeastOne => '至少保留一个平台';
}

// Path: tags
class Translations$tags$zh {
	Translations$tags$zh.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh: '标签管理'
	String get title => '标签管理';

	/// zh: '新建标签'
	String get add => '新建标签';

	/// zh: '标签名称'
	String get name => '标签名称';

	/// zh: '重命名'
	String get rename => '重命名';

	/// zh: '删除'
	String get delete => '删除';

	/// zh: '删除标签「{name}」？标签内的房间仍会被关注。'
	String deleteConfirm({required Object name}) => '删除标签「${name}」？标签内的房间仍会被关注。';

	/// zh: '置顶'
	String get pin => '置顶';

	/// zh: '取消置顶'
	String get unpin => '取消置顶';

	/// zh: '已置顶'
	String get pinned => '已置顶';

	/// zh: '还没有标签'
	String get empty => '还没有标签';

	/// zh: '在关注页长按房间可以加入标签。'
	String get emptyHint => '在关注页长按房间可以加入标签。';

	/// zh: '{count: int} 个标签'
	String countValue({required int count}) => '${count} 个标签';

	/// zh: '名称不能为空'
	String get nameEmpty => '名称不能为空';

	/// zh: '已有同名标签'
	String get nameTaken => '已有同名标签';
}

// Path: logs
class Translations$logs$zh {
	Translations$logs$zh.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh: '日志'
	String get title => '日志';

	/// zh: '日志级别'
	String get level => '日志级别';

	/// zh: '级别越低记录越多；保存后每次启动都会沿用。'
	String get levelHint => '级别越低记录越多；保存后每次启动都会沿用。';

	/// zh: '全部（trace）'
	String get levelTrace => '全部（trace）';

	/// zh: '详细（debug）'
	String get levelDebug => '详细（debug）';

	/// zh: '常规（info）'
	String get levelInfo => '常规（info）';

	/// zh: '警告（warning）'
	String get levelWarning => '警告（warning）';

	/// zh: '错误（error）'
	String get levelError => '错误（error）';

	/// zh: '严重（fatal）'
	String get levelFatal => '严重（fatal）';

	/// zh: '关闭'
	String get levelOff => '关闭';

	/// zh: '跟随构建默认值'
	String get levelDefault => '跟随构建默认值';

	/// zh: '导出最近日志'
	String get export => '导出最近日志';

	/// zh: '已复制 {count: int} 条日志到剪贴板'
	String exportDone({required int count}) => '已复制 ${count} 条日志到剪贴板';

	/// zh: '内存里还没有日志'
	String get exportEmpty => '内存里还没有日志';

	/// zh: '打开日志目录'
	String get openFolder => '打开日志目录';

	/// zh: '日志文件保存在数据目录的 logs 下，会滚动清理。'
	String get note => '日志文件保存在数据目录的 logs 下，会滚动清理。';
}

// Path: recorder
class Translations$recorder$zh {
	Translations$recorder$zh.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh: '录播'
	String get title => '录播';

	/// zh: '添加房间'
	String get addRoom => '添加房间';

	/// zh: '平台'
	String get platform => '平台';

	/// zh: '房间号'
	String get roomId => '房间号';

	/// zh: '开始监听'
	String get startWatching => '开始监听';

	/// zh: '已开始监听，开播后自动录制'
	String get watchStarted => '已开始监听，开播后自动录制';

	/// zh: '监听失败：{error:String}'
	String watchFailed({required String error}) => '监听失败：${error}';

	/// zh: '没有支持房间查询的平台'
	String get noSites => '没有支持房间查询的平台';

	/// zh: '打开输出目录'
	String get openFolder => '打开输出目录';

	/// zh: '无法打开文件夹'
	String get folderNotOpened => '无法打开文件夹';

	/// zh: '输出目录'
	String get outputDirectory => '输出目录';

	/// zh: '应用的录制目录'
	String get outputDirectoryDefault => '应用的录制目录';

	/// zh: '选择录制目录'
	String get chooseDirectory => '选择录制目录';

	/// zh: '分段时长'
	String get segmentLength => '分段时长';

	/// zh: '{minutes:int} 分钟'
	String minutesValue({required int minutes}) => '${minutes} 分钟';

	/// zh: '{count:int} 个分段'
	String segmentsValue({required int count}) => '${count} 个分段';

	/// zh: '正在恢复上次未完成的录制…'
	String get restoring => '正在恢复上次未完成的录制…';

	/// zh: '录制引擎启动失败：{error:String}'
	String engineFailed({required String error}) => '录制引擎启动失败：${error}';

	/// zh: '全部'
	String get filterAll => '全部';

	/// zh: '进行中'
	String get filterActive => '进行中';

	/// zh: '等待中'
	String get filterWaiting => '等待中';

	/// zh: '已保存'
	String get filterSaved => '已保存';

	/// zh: '失败'
	String get filterFailed => '失败';

	/// zh: '录制设置'
	String get recordSettings => '录制设置';

	/// zh: '已结束'
	String get filterFinished => '已结束';

	/// zh: '还没有监听的房间'
	String get emptyTitle => '还没有监听的房间';

	/// zh: '添加一个房间，开播后自动录制'
	String get emptySubtitle => '添加一个房间，开播后自动录制';

	/// zh: '没有待合并的分段'
	String get nothingToJoin => '没有待合并的分段';

	/// zh: '停止'
	String get actionStop => '停止';

	/// zh: '立即合并'
	String get actionFinishNow => '立即合并';

	/// zh: '重新录制'
	String get actionRestart => '重新录制';

	/// zh: '排队中'
	String get statusQueued => '排队中';

	/// zh: '解析中'
	String get statusResolving => '解析中';

	/// zh: '录制中'
	String get statusRecording => '录制中';

	/// zh: '重连中'
	String get statusRetrying => '重连中';

	/// zh: '合并中'
	String get statusMerging => '合并中';

	/// zh: '已完成'
	String get statusCompleted => '已完成';

	/// zh: '失败'
	String get statusFailed => '失败';

	/// zh: '已停止'
	String get statusStopped => '已停止';

	/// zh: '已中断'
	String get statusInterrupted => '已中断';

	/// zh: '未查询'
	String get roomUnknown => '未查询';

	/// zh: '等待开播'
	String get roomWaiting => '等待开播';

	/// zh: '正在直播'
	String get roomLive => '正在直播';

	/// zh: '直播已结束'
	String get roomEnded => '直播已结束';

	/// zh: '信号停滞'
	String get roomStalled => '信号停滞';

	/// zh: '房间不可用'
	String get roomUnavailable => '房间不可用';
}

// Path: theme
class Translations$theme$zh {
	Translations$theme$zh.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh: '跟随系统'
	String get system => '跟随系统';

	/// zh: '深色'
	String get dark => '深色';

	/// zh: '浅色'
	String get light => '浅色';
}

// Path: design
class Translations$design$zh {
	Translations$design$zh.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh: '默认（Fluent）'
	String get defaultLanguage => '默认（Fluent）';
}

// Path: history
class Translations$history$zh {
	Translations$history$zh.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh: '{count: int} / {limit: int} 条'
	String countOfLimit({required int count, required int limit}) => '${count} / ${limit} 条';

	/// zh: '{count: int} 条记录'
	String countUnlimited({required int count}) => '${count} 条记录';

	/// zh: '筛选'
	String get filterOpen => '筛选';

	/// zh: '关闭筛选'
	String get filterClose => '关闭筛选';

	/// zh: '按标题或主播筛选'
	String get filterHint => '按标题或主播筛选';

	/// zh: '{count: int} 条匹配'
	String filterMatches({required int count}) => '${count} 条匹配';

	/// zh: '没有匹配的观看记录'
	String get filterEmpty => '没有匹配的观看记录';

	/// zh: '刷新观看状态'
	String get refreshStatus => '刷新观看状态';

	/// zh: '已刷新 {count: int} 条记录'
	String refreshDone({required int count}) => '已刷新 ${count} 条记录';

	/// zh: '{failed: int} 条刷新失败（共 {count: int} 条）'
	String refreshPartial({required int failed, required int count}) => '${failed} 条刷新失败（共 ${count} 条）';

	/// zh: '刷新结果保存失败'
	String get refreshSaveFailed => '刷新结果保存失败';

	/// zh: '记录上限'
	String get limitTitle => '记录上限';

	/// zh: '0 表示不限制；超出的旧记录会被删除。'
	String get limitHint => '0 表示不限制；超出的旧记录会被删除。';

	/// zh: '已移除该记录'
	String get removed => '已移除该记录';

	/// zh: '已清空 {count: int} 条记录'
	String cleared({required int count}) => '已清空 ${count} 条记录';

	/// zh: '清空记录'
	String get clear => '清空记录';

	/// zh: '继续播放'
	String get resume => '继续播放';

	/// zh: '清空全部观看记录？此操作不可撤销。'
	String get clearConfirm => '清空全部观看记录？此操作不可撤销。';

	/// zh: '还没有观看记录'
	String get empty => '还没有观看记录';

	/// zh: '今天'
	String get today => '今天';

	/// zh: '昨天'
	String get yesterday => '昨天';

	/// zh: '本周'
	String get thisWeek => '本周';

	/// zh: '本月'
	String get thisMonth => '本月';

	/// zh: '更早'
	String get earlier => '更早';

	/// zh: '删除记录'
	String get remove => '删除记录';

	/// zh: '删除这条观看记录？'
	String get removeConfirm => '删除这条观看记录？';
}

// Path: iptv
class Translations$iptv$zh {
	Translations$iptv$zh.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh: '节目单'
	String get epgTitle => '节目单';

	/// zh: 'IPTV'
	String get title => 'IPTV';

	/// zh: '添加源'
	String get addSource => '添加源';

	/// zh: '源名称'
	String get sourceName => '源名称';

	/// zh: '播放列表地址（M3U/TXT）'
	String get sourceUrl => '播放列表地址（M3U/TXT）';

	/// zh: '删除该源？频道一并移除'
	String get deleteSource => '删除该源？频道一并移除';

	/// zh: '已导入 {count: int} 个频道'
	String imported({required int count}) => '已导入 ${count} 个频道';

	/// zh: '全部分组'
	String get allGroups => '全部分组';

	/// zh: '收藏'
	String get favorite => '收藏';

	/// zh: '还没有导入任何源'
	String get empty => '还没有导入任何源';

	/// zh: '搜索频道'
	String get search => '搜索频道';

	/// zh: '只看收藏'
	String get favoritesOnly => '只看收藏';

	/// zh: '没有匹配的频道'
	String get noMatch => '没有匹配的频道';

	/// zh: '频道列表'
	String get channels => '频道列表';

	/// zh: '切换频道'
	String get switchChannel => '切换频道';

	/// zh: '数字选台'
	String get dialPad => '数字选台';

	/// zh: '没有 {number: int} 号频道'
	String noNumber({required int number}) => '没有 ${number} 号频道';

	/// zh: '从文件导入'
	String get importFromFile => '从文件导入';

	/// zh: '导入失败'
	String get importFailed => '导入失败';

	/// zh: '线路 {index: int}/{total: int}'
	String lineOf({required int index, required int total}) => '线路 ${index}/${total}';

	/// zh: 'M3U / TXT'
	String get kindPlaylist => 'M3U / TXT';

	/// zh: 'Xtream'
	String get kindXtream => 'Xtream';

	/// zh: '服务器地址（http://host:port）'
	String get xtreamServer => '服务器地址（http://host:port）';

	/// zh: '用户名'
	String get xtreamUsername => '用户名';

	/// zh: '密码'
	String get xtreamPassword => '密码';

	/// zh: 'EPG 地址（可选）'
	String get epgUrl => 'EPG 地址（可选）';

	/// zh: '服务器拒绝了这组账号信息'
	String get xtreamAuthFailed => '服务器拒绝了这组账号信息';

	/// zh: '刷新该源'
	String get refreshSource => '刷新该源';

	/// zh: '当前节目'
	String get epgNow => '当前节目';

	/// zh: '接下来'
	String get epgNext => '接下来';

	/// zh: '刷新节目单'
	String get refreshEpg => '刷新节目单';

	/// zh: '热门频道'
	String get hotChannels => '热门频道';

	/// zh: '查看全部'
	String get viewAll => '查看全部';

	/// zh: '正在直播'
	String get liveNow => '正在直播';

	/// zh: '上一频道'
	String get prevChannel => '上一频道';

	/// zh: '频道列表'
	String get channelList => '频道列表';

	/// zh: '播放设置'
	String get playbackSettings => '播放设置';

	/// zh: '选择线路'
	String get lineSelect => '选择线路';

	/// zh: '数字选台'
	String get numberPad => '数字选台';

	/// zh: '刷新节目单'
	String get refreshGuide => '刷新节目单';
}

// Path: fonts
class Translations$fonts$zh {
	Translations$fonts$zh.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh: '字体管理'
	String get fonts => '字体管理';

	/// zh: '系统默认'
	String get system => '系统默认';

	/// zh: '使用系统自带字体'
	String get systemDesc => '使用系统自带字体';

	/// zh: '下载'
	String get download => '下载';

	/// zh: '删除'
	String get delete => '删除';

	/// zh: '出厂默认'
	String get factoryDefault => '出厂默认';

	/// zh: '云端字体'
	String get cloudFonts => '云端字体';
}

// Path: follow
class Translations$follow$zh {
	Translations$follow$zh.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh: '全部'
	String get all => '全部';

	/// zh: '还没有关注任何房间'
	String get empty => '还没有关注任何房间';

	/// zh: '关注'
	String get follow => '关注';

	/// zh: '取消关注'
	String get unfollow => '取消关注';

	/// zh: '不再关注「{name: String}」？'
	String unfollowConfirm({required String name}) => '不再关注「${name}」？';

	/// zh: '直播'
	String get liveRoom => '直播';

	/// zh: '回放'
	String get replayRoom => '回放';

	/// zh: '离线'
	String get offlineRoom => '离线';

	/// zh: '没有正在直播的关注'
	String get emptyLive => '没有正在直播的关注';

	/// zh: '没有可看回放的关注'
	String get emptyReplay => '没有可看回放的关注';

	/// zh: '没有离线的关注'
	String get emptyOffline => '没有离线的关注';

	/// zh: '查看离线'
	String get showOffline => '查看离线';

	/// zh: '{count: int} 个房间刷新失败'
	String refreshFailed({required int count}) => '${count} 个房间刷新失败';

	/// zh: '新建分组'
	String get newGroup => '新建分组';

	/// zh: '管理分组'
	String get manageGroups => '管理分组';

	/// zh: '重命名分组'
	String get renameGroup => '重命名分组';

	/// zh: '删除分组'
	String get deleteGroup => '删除分组';

	/// zh: '删除分组不影响已关注的房间。确认删除？'
	String get deleteGroupConfirm => '删除分组不影响已关注的房间。确认删除？';

	/// zh: '移动到分组'
	String get assign => '移动到分组';

	/// zh: '分组名称'
	String get groupName => '分组名称';
}

// Path: toolbox
class Translations$toolbox$zh {
	Translations$toolbox$zh.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh: '工具箱'
	String get title => '工具箱';

	/// zh: '粘贴直播间链接'
	String get hint => '粘贴直播间链接';

	/// zh: '读取剪贴板'
	String get readClipboard => '读取剪贴板';

	/// zh: '解析'
	String get resolve => '解析';

	/// zh: '没有平台识别该链接'
	String get failed => '没有平台识别该链接';

	/// zh: '打开房间'
	String get openRoom => '打开房间';

	/// zh: '直播间跳转'
	String get roomJump => '直播间跳转';

	/// zh: '链接跳转'
	String get linkJump => '链接跳转';

	/// zh: '获取直链'
	String get directLink => '获取直链';

	/// zh: '获取解析'
	String get parse => '获取解析';

	/// zh: '请在此处粘贴平台链接...'
	String get inputHint => '请在此处粘贴平台链接...';

	/// zh: '支持解析列表'
	String get supportList => '支持解析列表';

	/// zh: '支持以下类型的链接解析： 哔哩哔哩： https://live.bilibili.com/xxxxx https://www.bilibili.com/xxxxx https://b23.tv/xxxxx 虎牙直播： https://www.huya.com/xxxxx 斗鱼直播： https://www.douyu.com/xxxxx 抖音直播/视频： https://live.douyin.com/xxxxx https://www.douyin.com/xxxxx https://v.douyin.com/xxxxx https://webcast.amemv.com/douyin/webcast/reflow/xxxxx 快手直播： https://live.kuaishou.com/u/xxxxx https://live.kuaishou.cn/u/xxxxx 网易CC直播： https://cc.163.com/xxxxx Twitch直播： https://www.twitch.tv/xxxxx https://twitch.tv/xxxxx SOOP直播： https://www.sooplive.com/xxxxx https://sooplive.com/xxxxx https://play.sooplive.com/xxxxx https://www.sooplive.co.kr/xxxxx https://sooplive.co.kr/xxxxx https://play.sooplive.co.kr/xxxxx YY直播： https://www.yy.com/xxxxx https://yy.com/xxxxx https://www.yy.com/xxxxx/xxxxx?tempId=xxxxx https://yy.com/xxxxx/xxxxx?tempId=xxxxx AcFun直播: https://live.acfun.cn/live/123456 Picarto: https://picarto.tv/ChannelName TwitCasting: https://twitcasting.tv/ChannelName https://twitcasting.tv/c:ChannelName CHZZK: https://chzzk.naver.com/live/0123456789abcdef0123456789abcdef Kick: https://kick.com/ChannelName 17LIVE: https://17.live/en/live/1234567'
	String get supportContent => '支持以下类型的链接解析：\n\n哔哩哔哩：\nhttps://live.bilibili.com/xxxxx\nhttps://www.bilibili.com/xxxxx\nhttps://b23.tv/xxxxx\n\n虎牙直播：\nhttps://www.huya.com/xxxxx\n\n斗鱼直播：\nhttps://www.douyu.com/xxxxx\n\n抖音直播/视频：\nhttps://live.douyin.com/xxxxx\nhttps://www.douyin.com/xxxxx\nhttps://v.douyin.com/xxxxx\nhttps://webcast.amemv.com/douyin/webcast/reflow/xxxxx\n\n快手直播：\nhttps://live.kuaishou.com/u/xxxxx\nhttps://live.kuaishou.cn/u/xxxxx\n\n网易CC直播：\nhttps://cc.163.com/xxxxx\n\nTwitch直播：\nhttps://www.twitch.tv/xxxxx\nhttps://twitch.tv/xxxxx\n\nSOOP直播：\nhttps://www.sooplive.com/xxxxx\nhttps://sooplive.com/xxxxx\nhttps://play.sooplive.com/xxxxx\nhttps://www.sooplive.co.kr/xxxxx\nhttps://sooplive.co.kr/xxxxx\nhttps://play.sooplive.co.kr/xxxxx\n\nYY直播：\nhttps://www.yy.com/xxxxx\nhttps://yy.com/xxxxx\nhttps://www.yy.com/xxxxx/xxxxx?tempId=xxxxx\nhttps://yy.com/xxxxx/xxxxx?tempId=xxxxx\n\nAcFun直播:\nhttps://live.acfun.cn/live/123456\n\nPicarto:\nhttps://picarto.tv/ChannelName\n\nTwitCasting:\nhttps://twitcasting.tv/ChannelName\nhttps://twitcasting.tv/c:ChannelName\n\nCHZZK:\nhttps://chzzk.naver.com/live/0123456789abcdef0123456789abcdef\n\nKick:\nhttps://kick.com/ChannelName\n\n17LIVE:\nhttps://17.live/en/live/1234567';

	/// zh: '链接不能为空'
	String get emptyLink => '链接不能为空';

	/// zh: '无法解析此链接'
	String get parseFailed => '无法解析此链接';

	/// zh: '读取直链失败'
	String get getUrlFailed => '读取直链失败';

	/// zh: '选择清晰度'
	String get selectQuality => '选择清晰度';

	/// zh: '选择线路'
	String get selectLine => '选择线路';

	/// zh: '线路{index: int}'
	String line({required int index}) => '线路${index}';

	/// zh: '检测到链接'
	String get detectLink => '检测到链接';

	/// zh: '已自动填充剪贴板中的直播链接'
	String get autoFill => '已自动填充剪贴板中的直播链接';

	/// zh: '已复制直链'
	String get copySuccess => '已复制直链';
}

// Path: backup
class Translations$backup$zh {
	Translations$backup$zh.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh: '备份与恢复'
	String get title => '备份与恢复';

	/// zh: '创建备份'
	String get create => '创建备份';

	/// zh: '从文件恢复'
	String get restoreFile => '从文件恢复';

	/// zh: '已有备份'
	String get existing => '已有备份';

	/// zh: '还没有备份'
	String get none => '还没有备份';

	/// zh: '删除备份'
	String get delete => '删除备份';

	/// zh: '恢复'
	String get restore => '恢复';

	/// zh: '用「{name: String}」覆盖当前数据？应用将重启。'
	String restoreConfirm({required String name}) => '用「${name}」覆盖当前数据？应用将重启。';

	/// zh: '云端与同步'
	String get sectionCloud => '云端与同步';
}

// Path: about
class Translations$about$zh {
	Translations$about$zh.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh: '本机'
	String get native => '本机';

	/// zh: '下载文件 · {platform}'
	String downloadFilesOf({required Object platform}) => '下载文件 · ${platform}';

	/// zh: '关于'
	String get title => '关于';

	/// zh: '关于'
	String get group => '关于';

	/// zh: '检查更新'
	String get checkUpdate => '检查更新';

	/// zh: '在线更新'
	String get onlineUpdate => '在线更新';

	/// zh: '版本更新'
	String get versionUpdate => '版本更新';

	/// zh: '更新日志'
	String get updateLog => '更新日志';

	/// zh: '已是最新版本'
	String get upToDate => '已是最新版本';

	/// zh: '发现新版本'
	String get newVersion => '发现新版本';

	/// zh: '已在使用最新版本'
	String get noNewVersion => '已在使用最新版本';

	/// zh: '本软件开源免费'
	String get openSourceFree => '本软件开源免费';

	/// zh: '更新'
	String get update => '更新';

	/// zh: '刷新'
	String get refresh => '刷新';

	/// zh: '版本历史'
	String get versionHistory => '版本历史';

	/// zh: '历史版本更新记录'
	String get historyDesc => '历史版本更新记录';

	/// zh: '发布于 {date: String}'
	String publishedAt({required String date}) => '发布于 ${date}';

	/// zh: '打开发布页面'
	String get openRelease => '打开发布页面';

	/// zh: '开源许可证'
	String get licenses => '开源许可证';

	/// zh: '项目主页'
	String get project => '项目主页';

	/// zh: '项目'
	String get projectSection => '项目';

	/// zh: '项目声明'
	String get projectAlert => '项目声明';

	/// zh: '© 2026 PureLive 开源项目。本程序为纯本地客户端应用，直接请求媒体平台官方公开接口，项目本身不存储、不制作、不分发任何音视频资源。本程序登录及云同步功能由第三方基础设施服务商 Firebase 提供。开发者郑重承诺，本程序本身不收集、不处理且不留存任何用户个人隐私信息。所有运行、配置及同步数据均由用户自行留存与控制，数据所有权及隐私权益完全归属于用户。用户需自行承担使用本测试工具所产生的相关法律责任。'
	String get legalese => '© 2026 PureLive 开源项目。本程序为纯本地客户端应用，直接请求媒体平台官方公开接口，项目本身不存储、不制作、不分发任何音视频资源。本程序登录及云同步功能由第三方基础设施服务商 Firebase 提供。开发者郑重承诺，本程序本身不收集、不处理且不留存任何用户个人隐私信息。所有运行、配置及同步数据均由用户自行留存与控制，数据所有权及隐私权益完全归属于用户。用户需自行承担使用本测试工具所产生的相关法律责任。';

	/// zh: '系统浏览器未打开，请检查默认浏览器设置'
	String get browserNotOpened => '系统浏览器未打开，请检查默认浏览器设置';

	/// zh: '正在检查…'
	String get checkRunning => '正在检查…';

	/// zh: '检查失败，点此重试'
	String get checkFailed => '检查失败，点此重试';

	/// zh: '下载文件'
	String get downloadFiles => '下载文件';

	/// zh: '复制链接'
	String get copyLink => '复制链接';

	/// zh: '链接已复制'
	String get copied => '链接已复制';

	/// zh: '下载'
	String get download => '下载';

	/// zh: '{size: String} · {count: int} 次下载'
	String assetMeta({required String size, required int count}) => '${size} · ${count} 次下载';

	/// zh: '最新版本 {tag} 已发布。现在打开更新页面吗?'
	String startupUpdateBody({required Object tag}) => '最新版本 ${tag} 已发布。现在打开更新页面吗?';
}

// Path: shield
class Translations$shield$zh {
	Translations$shield$zh.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh: '弹幕屏蔽'
	String get title => '弹幕屏蔽';

	/// zh: '关键词'
	String get keywords => '关键词';

	/// zh: '用户'
	String get users => '用户';

	/// zh: '正则'
	String get regexes => '正则';

	/// zh: '添加'
	String get add => '添加';

	/// zh: '暂无'
	String get none => '暂无';

	/// zh: '输入要屏蔽的关键词'
	String get keywordHint => '输入要屏蔽的关键词';

	/// zh: '请输入关键词'
	String get emptyKeyword => '请输入关键词';
}

// Path: multiview
class Translations$multiview$zh {
	Translations$multiview$zh.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh: '多画面'
	String get title => '多画面';

	/// zh: '平台'
	String get platform => '平台';

	/// zh: '房间号'
	String get roomId => '房间号';

	/// zh: '添加格子'
	String get add => '添加格子';

	/// zh: '布局'
	String get layout => '布局';

	/// zh: '选择房间'
	String get pickRoom => '选择房间';

	/// zh: '粘贴房间链接，或从关注列表选择'
	String get pickHint => '粘贴房间链接，或从关注列表选择';

	/// zh: '点击选择房间'
	String get emptyCell => '点击选择房间';

	/// zh: '静音'
	String get mute => '静音';

	/// zh: '取消静音'
	String get unmute => '取消静音';

	/// zh: '全部静音'
	String get muteAll => '全部静音';

	/// zh: '取消全部静音'
	String get unmuteAll => '取消全部静音';

	/// zh: '正在播放声音'
	String get audioFocus => '正在播放声音';

	/// zh: '移除格子'
	String get removeCell => '移除格子';

	/// zh: '还没有关注或历史房间'
	String get noPick => '还没有关注或历史房间';
}

// Path: search
class Translations$search$zh {
	Translations$search$zh.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh: '输入关键词搜索房间'
	String get hint => '输入关键词搜索房间';

	/// zh: '房间'
	String get rooms => '房间';

	/// zh: '主播'
	String get anchors => '主播';

	/// zh: '分区'
	String get areas => '分区';

	/// zh: '全部'
	String get allSites => '全部';

	/// zh: '搜索历史'
	String get historyTitle => '搜索历史';

	/// zh: '删除该搜索'
	String get historyRemove => '删除该搜索';
}

// Path: room
class Translations$room$zh {
	Translations$room$zh.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh: '默认排序'
	String get sortPlatform => '默认排序';

	/// zh: '人气优先'
	String get sortViewers => '人气优先';

	/// zh: '弹幕连接失败'
	String get danmakuFailed => '弹幕连接失败';

	/// zh: '清晰度'
	String get quality => '清晰度';

	/// zh: '线路'
	String get line => '线路';

	/// zh: '播放'
	String get play => '播放';

	/// zh: '暂停'
	String get pause => '暂停';

	/// zh: '播放失败，请重试'
	String get failed => '播放失败，请重试';

	/// zh: '回放'
	String get replay => '回放';

	/// zh: '未开播'
	String get offline => '未开播';

	/// zh: '房间打开失败'
	String get entryFailed => '房间打开失败';

	/// zh: '聊天'
	String get chat => '聊天';

	/// zh: '醒目留言'
	String get superChat => '醒目留言';

	/// zh: '礼物'
	String get gifts => '礼物';

	/// zh: '弹幕屏蔽'
	String get shield => '弹幕屏蔽';

	/// zh: '弹幕连接已断开'
	String get danmakuEnded => '弹幕连接已断开';

	/// zh: '弹幕重连中…'
	String get reconnecting => '弹幕重连中…';

	/// zh: '发个弹幕吧…'
	String get sendPlaceholder => '发个弹幕吧…';

	/// zh: '发送弹幕需要登录平台账号（暂未接入）'
	String get sendUnavailable => '发送弹幕需要登录平台账号（暂未接入）';

	/// zh: '回到底部'
	String get backToLive => '回到底部';

	/// zh: '{count} 条新消息'
	String newMessages({required Object count}) => '${count} 条新消息';

	/// zh: '暂无醒目留言'
	String get superChatEmpty => '暂无醒目留言';

	/// zh: '观众的付费高亮消息会显示在这里'
	String get superChatEmptyHint => '观众的付费高亮消息会显示在这里';

	/// zh: '暂无礼物'
	String get giftsEmpty => '暂无礼物';

	/// zh: '直播间收到的礼物会显示在这里'
	String get giftsEmptyHint => '直播间收到的礼物会显示在这里';

	/// zh: '关注'
	String get follow => '关注';

	/// zh: '已关注'
	String get followed => '已关注';

	/// zh: '{count} 粉丝'
	String followers({required Object count}) => '${count} 粉丝';

	/// zh: '人气'
	String get popularity => '人气';

	/// zh: '在线'
	String get online => '在线';

	/// zh: '线路 {n}'
	String lineN({required Object n}) => '线路 ${n}';

	/// zh: '全屏'
	String get fullscreen => '全屏';

	/// zh: '锁定屏幕'
	String get lock => '锁定屏幕';

	/// zh: '解锁屏幕'
	String get unlock => '解锁屏幕';

	/// zh: '画面比例'
	String get videoFit => '画面比例';

	/// zh: '适配'
	String get fitContain => '适配';

	/// zh: '填满'
	String get fitCover => '填满';

	/// zh: '拉伸'
	String get fitFill => '拉伸';

	/// zh: '退出全屏'
	String get exitFullscreen => '退出全屏';

	/// zh: '显示弹幕'
	String get barrageOn => '显示弹幕';

	/// zh: '关闭弹幕'
	String get barrageOff => '关闭弹幕';

	/// zh: '工具箱'
	String get toolbox => '工具箱';

	/// zh: '复制房间链接'
	String get copyLink => '复制房间链接';

	/// zh: '已复制'
	String get linkCopied => '已复制';

	/// zh: '录制'
	String get record => '录制';

	/// zh: '停止录制'
	String get stopRecording => '停止录制';

	/// zh: '原速'
	String get rateNormal => '原速';

	/// zh: '等待观众数据'
	String get audienceWaiting => '等待观众数据';

	/// zh: '静音'
	String get mute => '静音';

	/// zh: '取消静音'
	String get unmute => '取消静音';

	/// zh: '弹幕已开'
	String get danmakuOn => '弹幕已开';

	/// zh: '睡眠定时'
	String get sleepTimer => '睡眠定时';

	/// zh: '睡眠定时（已开启）'
	String get sleepTimerOn => '睡眠定时（已开启）';

	/// zh: '启用播放定时'
	String get sleepTimerEnable => '启用播放定时';

	/// zh: '到时后暂停当前房间的播放'
	String get sleepTimerDesc => '到时后暂停当前房间的播放';

	/// zh: '定时时长'
	String get timerDuration => '定时时长';

	/// zh: '1 - 525600 分钟'
	String get timerDurationHint => '1 - 525600 分钟';

	/// zh: '请输入 1 到 525600 之间的分钟数'
	String get timerInvalid => '请输入 1 到 525600 之间的分钟数';

	/// zh: '播放定时已结束，已暂停'
	String get timerFinished => '播放定时已结束，已暂停';

	/// zh: '分钟'
	String get minutesUnit => '分钟';

	/// zh: '{minutes} 分钟'
	String minutesN({required Object minutes}) => '${minutes} 分钟';

	/// zh: '房间音量'
	String get roomVolume => '房间音量';

	/// zh: '设置静音与手机、桌面各自的默认音量'
	String get roomVolumeDesc => '设置静音与手机、桌面各自的默认音量';

	/// zh: '全局静音'
	String get globalMute => '全局静音';

	/// zh: '所有房间以静音开始，音量数值保留'
	String get globalMuteSubtitle => '所有房间以静音开始，音量数值保留';

	/// zh: '手机默认音量'
	String get mobileDefaultVolume => '手机默认音量';

	/// zh: '桌面默认音量'
	String get desktopDefaultVolume => '桌面默认音量';

	/// zh: '恢复默认'
	String get resetDefault => '恢复默认';

	/// zh: '当前房间无法应用音量，请确认后重试'
	String get volumeApplyFailed => '当前房间无法应用音量，请确认后重试';

	/// zh: '发送'
	String get send => '发送';

	/// zh: '我'
	String get localMe => '我';

	/// zh: '弹幕设置'
	String get barrageSettings => '弹幕设置';

	/// zh: '关键词屏蔽'
	String get keywordBlock => '关键词屏蔽';

	/// zh: '弹幕已全局关闭'
	String get barrageHiddenHint => '弹幕已全局关闭';

	/// zh: '在画面上叠加滚动弹幕'
	String get barrageOnSubtitle => '在画面上叠加滚动弹幕';

	/// zh: '弹幕字号'
	String get barrageFontSize => '弹幕字号';

	/// zh: '弹幕透明度'
	String get barrageOpacity => '弹幕透明度';

	/// zh: '这些设置即时生效，并作为新房间的默认值'
	String get barrageSettingsNote => '这些设置即时生效，并作为新房间的默认值';

	/// zh: '横屏全屏'
	String get enterLandscapeFullscreen => '横屏全屏';

	/// zh: '继续下滑进入竖屏全屏'
	String get enterPortraitFullscreenHint => '继续下滑进入竖屏全屏';

	/// zh: '面板高度'
	String get portraitPanelResize => '面板高度';

	/// zh: '拖动调整面板高度'
	String get portraitPanelResizeHint => '拖动调整面板高度';
}

// Path: areas
class Translations$areas$zh {
	Translations$areas$zh.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh: '暂无分区'
	String get empty => '暂无分区';
}

// Path: popular
class Translations$popular$zh {
	Translations$popular$zh.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh: '全部平台'
	String get allPlatforms => '全部平台';

	/// zh: '点按切换平台；平台显示设置可隐藏或排序。'
	String get allPlatformsHint => '点按切换平台；平台显示设置可隐藏或排序。';

	/// zh: '没有可显示的平台'
	String get noPlatforms => '没有可显示的平台';

	/// zh: '在平台显示设置里至少开启一个平台。'
	String get noPlatformsHint => '在平台显示设置里至少开启一个平台。';

	/// zh: '暂时没有热门直播'
	String get empty => '暂时没有热门直播';
}

// Path: remoteSync
class Translations$remoteSync$zh {
	Translations$remoteSync$zh.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh: '设备同步'
	String get title => '设备同步';

	/// zh: '在同一网络下的设备间同步关注与历史'
	String get tileSubtitle => '在同一网络下的设备间同步关注与历史';

	/// zh: '我的设备'
	String get myDevice => '我的设备';

	/// zh: '未找到局域网地址'
	String get noAddress => '未找到局域网地址';

	/// zh: '让另一台设备扫描此二维码，或在对方输入本机地址'
	String get scanHint => '让另一台设备扫描此二维码，或在对方输入本机地址';

	/// zh: '同步服务运行中'
	String get running => '同步服务运行中';

	/// zh: '同步服务未运行'
	String get notRunning => '同步服务未运行';

	/// zh: '启动'
	String get start => '启动';

	/// zh: '停止'
	String get stop => '停止';

	/// zh: '发现的设备'
	String get devices => '发现的设备';

	/// zh: '未发现其他设备'
	String get noDevices => '未发现其他设备';

	/// zh: '手动输入'
	String get manual => '手动输入';

	/// zh: '发送配置'
	String get send => '发送配置';

	/// zh: '接收配置'
	String get receive => '接收配置';

	/// zh: '发送成功'
	String get sendSuccess => '发送成功';

	/// zh: '发送失败——请检查地址，并确认对方已同意'
	String get sendFailed => '发送失败——请检查地址，并确认对方已同意';

	/// zh: '接收并应用成功'
	String get receiveSuccess => '接收并应用成功';

	/// zh: '接收失败'
	String get receiveFailed => '接收失败';

	/// zh: '请先输入对方设备地址'
	String get enterAddress => '请先输入对方设备地址';

	/// zh: '地址格式不正确'
	String get invalidAddress => '地址格式不正确';

	/// zh: '{address: String} 想要覆盖本机的关注、历史与弹幕屏蔽，是否允许？'
	String incomingImport({required String address}) => '${address} 想要覆盖本机的关注、历史与弹幕屏蔽，是否允许？';

	/// zh: '{address: String} 想要读取本机的关注、历史与弹幕屏蔽，是否允许？'
	String incomingExport({required String address}) => '${address} 想要读取本机的关注、历史与弹幕屏蔽，是否允许？';

	/// zh: '关注列表'
	String get sectionFavorite => '关注列表';

	/// zh: '观看历史'
	String get sectionHistory => '观看历史';

	/// zh: '关注分组'
	String get sectionGroups => '关注分组';

	/// zh: '请连接 Wi-Fi 或有线网络；Android 需要允许"附近设备 / 局域网"权限，然后点右上角开始'
	String get noAddressHint => '请连接 Wi-Fi 或有线网络；Android 需要允许"附近设备 / 局域网"权限，然后点右上角开始';

	/// zh: '请确保两台设备连接到同一个局域网'
	String get description => '请确保两台设备连接到同一个局域网';

	/// zh: '正在搜索局域网设备...'
	String get searching => '正在搜索局域网设备...';

	/// zh: '正在搜索'
	String get searchingShort => '正在搜索';

	/// zh: '输入对方设备的地址，或粘贴对方二维码里的同步链接'
	String get manualHint => '输入对方设备的地址，或粘贴对方二维码里的同步链接';

	/// zh: '复制地址'
	String get copyAddress => '复制地址';

	/// zh: '地址已复制'
	String get addressCopied => '地址已复制';

	/// zh: '来自 {name: String}'
	String fromName({required String name}) => '来自 ${name}';

	/// zh: '3.x 版本的设备'
	String get legacyDevice => '3.x 版本的设备';

	/// zh: '允许'
	String get allow => '允许';

	/// zh: '拒绝'
	String get reject => '拒绝';

	/// zh: '设备 {address}（{name}）请求用它的设置覆盖本机设置，是否允许？'
	String incomingImportNamed({required Object address, required Object name}) => '设备 ${address}（${name}）请求用它的设置覆盖本机设置，是否允许？';

	/// zh: '设备 {address}（{name}）请求读取本机设置，是否允许？'
	String incomingExportNamed({required Object address, required Object name}) => '设备 ${address}（${name}）请求读取本机设置，是否允许？';
}

// Path: errors
class Translations$errors$zh {
	Translations$errors$zh.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh: '出了点问题，请稍后再试。'
	String get generic => '出了点问题，请稍后再试。';

	/// zh: '网络连接不可用，请检查网络后重试。'
	String get network => '网络连接不可用，请检查网络后重试。';

	/// zh: '没有找到相关内容。'
	String get notFound => '没有找到相关内容。';

	/// zh: '已取消。'
	String get cancelled => '已取消。';

	/// zh: '当前来源不支持该功能。'
	String get unsupported => '当前来源不支持该功能。';
}

// Path: tabs
class Translations$tabs$zh {
	Translations$tabs$zh.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh: '首页'
	String get home => '首页';

	/// zh: '关注'
	String get favorites => '关注';

	/// zh: '关注'
	String get follow => '关注';

	/// zh: '历史'
	String get history => '历史';

	/// zh: '热门'
	String get popular => '热门';

	/// zh: '分区'
	String get areas => '分区';

	/// zh: '搜索'
	String get search => '搜索';

	/// zh: '设置'
	String get settings => '设置';

	/// zh: '录制中心'
	String get record => '录制中心';
}

// Path: window
class Translations$window$zh {
	Translations$window$zh.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh: '最小化'
	String get minimize => '最小化';

	/// zh: '最大化'
	String get maximize => '最大化';

	/// zh: '还原'
	String get restore => '还原';

	/// zh: '关闭'
	String get close => '关闭';
}

// Path: closePrompt
class Translations$closePrompt$zh {
	Translations$closePrompt$zh.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh: '关闭窗口时要执行什么？'
	String get title => '关闭窗口时要执行什么？';

	/// zh: '隐藏到托盘，保留播放'
	String get toTray => '隐藏到托盘，保留播放';

	/// zh: '退出 Pure Live'
	String get quit => '退出 Pure Live';

	/// zh: '记住我的选择，不再询问'
	String get remember => '记住我的选择，不再询问';
}

// Path: shellSettings
class Translations$shellSettings$zh {
	Translations$shellSettings$zh.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh: '窗口'
	String get sectionWindow => '窗口';

	/// zh: '窗口标题栏'
	String get titleBar => '窗口标题栏';

	/// zh: '自动（按系统版本）'
	String get titleBarAuto => '自动（按系统版本）';

	/// zh: '应用标题栏'
	String get titleBarApp => '应用标题栏';

	/// zh: '系统标题栏'
	String get titleBarSystem => '系统标题栏';

	/// zh: '自动：Windows 11 用应用标题栏，Windows 10 用系统标题栏。应用标题栏由 Pure Live 绘制，系统标题栏使用 Windows 原生样式。切换在重启应用后生效。'
	String get titleBarHint => '自动：Windows 11 用应用标题栏，Windows 10 用系统标题栏。应用标题栏由 Pure Live 绘制，系统标题栏使用 Windows 原生样式。切换在重启应用后生效。';
}

// Path: webdav
class Translations$webdav$zh {
	Translations$webdav$zh.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh: 'WebDAV 云备份'
	String get title => 'WebDAV 云备份';

	/// zh: 'WebDAV 云同步'
	String get entryTitle => 'WebDAV 云同步';

	/// zh: '备份到你自己的 WebDAV 服务器'
	String get entrySubtitle => '备份到你自己的 WebDAV 服务器';

	/// zh: '服务器'
	String get sectionConfig => '服务器';

	/// zh: 'https://dav.jianguoyun.com/dav/'
	String get addressHint => 'https://dav.jianguoyun.com/dav/';

	/// zh: '请输入有效的 http(s) 地址'
	String get addressInvalid => '请输入有效的 http(s) 地址';

	/// zh: '账户'
	String get username => '账户';

	/// zh: '应用密码'
	String get password => '应用密码';

	/// zh: '目录（可选）'
	String get directory => '目录（可选）';

	/// zh: '测试连接'
	String get testConnection => '测试连接';

	/// zh: '正在连接…'
	String get testing => '正在连接…';

	/// zh: '连接成功，地址、账户和密码均有效。'
	String get testOk => '连接成功，地址、账户和密码均有效。';

	/// zh: '连接失败'
	String get testFailed => '连接失败';

	/// zh: '立即备份'
	String get backupNow => '立即备份';

	/// zh: '正在上传备份…'
	String get backingUp => '正在上传备份…';

	/// zh: '备份已上传'
	String get backupDone => '备份已上传';

	/// zh: '请先填写服务器地址、账户和应用密码'
	String get configIncomplete => '请先填写服务器地址、账户和应用密码';

	/// zh: '上次备份'
	String get lastBackup => '上次备份';

	/// zh: '上次恢复'
	String get lastRestore => '上次恢复';

	/// zh: '从未'
	String get never => '从未';

	/// zh: '云端备份'
	String get remote => '云端备份';

	/// zh: '还没有云端备份'
	String get remoteEmpty => '还没有云端备份';

	/// zh: '恢复'
	String get restore => '恢复';

	/// zh: '下载该备份并覆盖当前数据？应用将重启。'
	String get restoreConfirm => '下载该备份并覆盖当前数据？应用将重启。';

	/// zh: '删除'
	String get delete => '删除';

	/// zh: '从服务器删除该备份？'
	String get deleteConfirm => '从服务器删除该备份？';

	/// zh: '配置说明'
	String get helpTitle => '配置说明';

	/// zh: '云备份把与本地备份相同的压缩包上传到你自己的 WebDAV 服务器，让关注、历史和设置在重装后依然可用。任何 WebDAV 服务都可以，下面以坚果云为例。'
	String get helpIntro => '云备份把与本地备份相同的压缩包上传到你自己的 WebDAV 服务器，让关注、历史和设置在重装后依然可用。任何 WebDAV 服务都可以，下面以坚果云为例。';

	/// zh: '1. 在 www.jianguoyun.com 注册并登录。 2. 打开「选项 → 安全选项」，生成应用密码。 3. 在上方填写服务器地址、账户和该应用密码。'
	String get helpSteps => '1. 在 www.jianguoyun.com 注册并登录。\n2. 打开「选项 → 安全选项」，生成应用密码。\n3. 在上方填写服务器地址、账户和该应用密码。';

	/// zh: '服务器：坚果云的 WebDAV 地址为 https://dav.jianguoyun.com/dav/'
	String get helpServer => '服务器：坚果云的 WebDAV 地址为 https://dav.jianguoyun.com/dav/';

	/// zh: '账户：坚果云的登录名（通常是手机号或邮箱）。'
	String get helpAccount => '账户：坚果云的登录名（通常是手机号或邮箱）。';

	/// zh: '密码：不是登录密码 —— WebDAV 使用「选项 → 安全选项」中生成的应用密码。'
	String get helpPassword => '密码：不是登录密码 —— WebDAV 使用「选项 → 安全选项」中生成的应用密码。';

	/// zh: '连接失败？检查地址是否以 /dav/ 结尾、是否使用应用密码而非登录密码，以及网络是否屏蔽了 WebDAV 端口。'
	String get helpIssues => '连接失败？检查地址是否以 /dav/ 结尾、是否使用应用密码而非登录密码，以及网络是否屏蔽了 WebDAV 端口。';

	/// zh: '打开坚果云官方帮助'
	String get openOfficialHelp => '打开坚果云官方帮助';

	/// zh: '无法打开浏览器'
	String get helpOpenFailed => '无法打开浏览器';
}

// Path: wallpaper
class Translations$wallpaper$zh {
	Translations$wallpaper$zh.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh: '背景壁纸'
	String get title => '背景壁纸';

	/// zh: '纯色、渐变或本地图片'
	String get entrySubtitle => '纯色、渐变或本地图片';

	/// zh: '跟随主题'
	String get currentNone => '跟随主题';

	/// zh: '纯色'
	String get currentSolid => '纯色';

	/// zh: '渐变'
	String get currentGradient => '渐变';

	/// zh: '图片'
	String get currentImage => '图片';

	/// zh: '预设'
	String get groupPresets => '预设';

	/// zh: '纯色'
	String get groupSolid => '纯色';

	/// zh: '渐变'
	String get groupGradient => '渐变';

	/// zh: '本机图片'
	String get groupDevice => '本机图片';

	/// zh: '图片显示'
	String get groupDisplay => '图片显示';

	/// zh: '无背景'
	String get none => '无背景';

	/// zh: '保留主题表面'
	String get noneSubtitle => '保留主题表面';

	/// zh: '选择图片'
	String get pickImage => '选择图片';

	/// zh: '从本机选择一张图片'
	String get pickImageSubtitle => '从本机选择一张图片';

	/// zh: '图片路径'
	String get imagePath => '图片路径';

	/// zh: '输入图片的绝对路径'
	String get imagePathHint => '输入图片的绝对路径';

	/// zh: '压暗图片'
	String get scrim => '压暗图片';

	/// zh: '在图片上加一层暗色，保证文字可读'
	String get scrimSubtitle => '在图片上加一层暗色，保证文字可读';

	/// zh: '模糊图片'
	String get blur => '模糊图片';

	/// zh: '关闭'
	String get blurOff => '关闭';

	/// zh: '填充方式'
	String get fit => '填充方式';

	/// zh: '裁剪填充'
	String get fitCover => '裁剪填充';

	/// zh: '完整显示'
	String get fitContain => '完整显示';

	/// zh: '拉伸'
	String get fitFill => '拉伸';

	/// zh: '找不到图片，请检查路径'
	String get imageMissing => '找不到图片，请检查路径';
}

/// The flat map containing all translations for locale <zh>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on Translations {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'app.title' => 'Pure Live',
			'splash.welcome' => '欢迎使用',
			'home.recommended' => '推荐流',
			'common.confirm' => '确定',
			'common.cancel' => '取消',
			'common.restartNow' => '立即重启',
			'common.restartLater' => '稍后',
			'common.retry' => '重试',
			'common.close' => '关闭',
			'common.save' => '保存',
			'common.clear' => '清空',
			'common.loading' => '加载中',
			'common.empty' => '暂无内容',
			'common.pageOf' => ({required int page, required int total}) => '第 ${page} / ${total} 页',
			'common.back' => '返回',
			'common.menu' => '菜单',
			'common.more' => '更多',
			'common.off' => '关闭',
			'common.refresh' => '刷新',
			'common.prevPage' => '上一页',
			'common.nextPage' => '下一页',
			'common.perPage' => '每页',
			'common.goTo' => '跳转至',
			'common.pageUnit' => '页',
			'common.toTop' => '回到顶部',
			'common.toBottom' => '到底部',
			'common.addOne' => '添加',
			'tray.show' => '显示主界面',
			'tray.quit' => '退出',
			'login.title' => '扫码登录',
			'login.generating' => '生成二维码中',
			'login.waitingScan' => '等待扫描',
			'login.scanHint' => '打开 bilibili App 扫描二维码并确认登录',
			'login.success' => '登录成功',
			'login.welcome' => ({required String name}) => '欢迎，${name}',
			'login.expired' => '二维码已过期',
			'login.refreshQr' => '刷新二维码',
			'login.failed' => '登录未能完成',
			'login.done' => '完成',
			'login.unsupported' => '当前构建未启用 bilibili 登录',
			'login.platformBilibili' => 'bilibili 扫码',
			'login.platformDouyu' => '斗鱼 Cookie',
			'login.platformHuya' => '虎牙 Cookie',
			'login.cookiePlaceholder' => 'Cookie: a=b; c=d ...',
			'login.verify' => '验证并登录',
			'login.douyuCookieHint' => '在浏览器网络面板中复制已登录 www.douyu.com 请求的 Cookie 头，粘贴到此处。',
			'login.huyaCookieHint' => '在浏览器网络面板中复制已登录 www.huya.com 请求的 Cookie 头，粘贴到此处。',
			'login.unsupportedSite' => ({required String site}) => '当前构建未启用 ${site} 登录',
			'account.title' => '账号',
			'account.notSignedIn' => '未登录',
			'account.notSignedInHint' => '登录后，直播相关请求将携带你的账号信息。',
			'account.signOut' => '退出登录',
			'account.signOutConfirm' => ({required String site}) => '退出 ${site} 登录？',
			'account.signOutHint' => '本机保存的登录凭据将被移除。',
			'account.userId' => ({required String id}) => 'ID ${id}',
			'account.platformBilibili' => 'bilibili 账号',
			'account.platformDouyu' => '斗鱼账号',
			'account.platformHuya' => '虎牙账号',
			'account.noAuthSites' => '这个构建还没有可登录的平台',
			'account.clearAllAccounts' => '清除全部账号',
			'account.clearAllAccountsHint' => '退出所有平台并删除已存的登录信息',
			'settings.appearance' => '外观',
			'settings.fonts' => '字体管理',
			'settings.themeMode' => '主题模式',
			'settings.designLanguage' => '设计语言',
			'settings.accent' => '强调色',
			'settings.pureBlack' => '纯黑模式',
			'settings.density' => '密度',
			'settings.fontScale' => '字体大小',
			'settings.transparency' => '透明度',
			'settings.reduceTransparency' => '减少透明效果',
			'settings.animations' => '动画',
			'settings.focusOutline' => '焦点轮廓',
			'settings.sectionTheme' => '主题与外观',
			'settings.sectionIptv' => 'IPTV',
			'settings.sectionDanmaku' => '弹幕',
			'settings.sectionData' => '数据',
			'settings.sectionBackup' => '备份',
			'settings.appearanceSubtitle' => '主题模式、色彩、密度与动效',
			'settings.fontsSubtitle' => '下载并应用云端字体',
			'settings.iptvSubtitle' => '管理播放源与频道',
			'settings.shieldSubtitle' => '按关键词、用户或正则屏蔽弹幕',
			'settings.sectionAccount' => '账号',
			'settings.scanToLogin' => '登录平台账号',
			'settings.accountSubtitle' => '平台账号与登录态',
			'settings.cacheAndData' => '缓存与数据',
			'settings.cacheAndDataSubtitle' => '观看历史与本地数据',
			'settings.backupSubtitle' => '备份与恢复本地数据',
			'settings.groupTheme' => '主题',
			'settings.groupFontFamily' => '字体',
			'settings.groupTextSize' => '文字大小',
			'settings.themeModeSubtitle' => '跟随系统，或始终浅色、始终深色',
			'settings.designLanguageSubtitle' => '整个应用绘制所用的设计语言',
			'settings.designLanguageRestartTitle' => '切换设计语言',
			'settings.designLanguageRestartConfirm' => ({required String current}) => '设计语言决定应用使用哪套宿主，只在下次启动生效。本次仍使用「${current}」绘制。现在重启应用？',
			'settings.designLanguagePending' => ({required String name}) => '重启后切换为 ${name}',
			'settings.accentSubtitle' => '控件着色所用的颜色',
			'settings.densitySubtitle' => '布局的紧凑程度',
			'settings.pureBlackSubtitle' => '深色表面绘制为纯黑，适合 OLED 屏幕',
			'settings.transparencySubtitle' => '玻璃与遮罩透明度的倍率',
			'settings.reduceTransparencySubtitle' => '强制不透明表面并禁用模糊',
			'settings.animationsSubtitle' => '是否开启动效',
			'settings.focusOutlineSubtitle' => '聚焦控件显示可见轮廓',
			'settings.fontScaleSubtitle' => '所有字体大小的倍率',
			'settings.previewText' => '千里之行，始于足下',
			'settings.fontFamilyCurrent' => ({required String name}) => '当前：${name}',
			'settings.defaultOption' => '默认',
			'settings.historyEntry' => '观看历史',
			'settings.historyCount' => ({required int count}) => '${count} 条记录',
			'settings.clearHistory' => '清空观看历史',
			'settings.clearHistorySubtitle' => '删除本机全部观看记录',
			'settings.historyCleared' => '观看历史已清空',
			'settings.general' => '通用',
			'settings.generalSubtitle' => '刷新、启动、倒计时关闭与窗口',
			'settings.sectionGeneral' => '通用',
			'settings.refreshSettings' => '刷新',
			'settings.refreshSettingsSubtitle' => '前台刷新间隔与恢复阈值',
			'settings.pageSettings' => '页面设置',
			'settings.pageSettingsSubtitle' => '显示哪些页签及其顺序',
			'settings.navigationSettings' => '导航',
			'settings.navigationSettingsSubtitle' => '应用启动位置',
			'settings.sectionFeedDisplay' => '列表显示',
			'settings.loadingStyle' => '加载样式',
			'settings.loadingStyleSubtitle' => '加载占位的呈现方式',
			'settings.roomCardSettings' => '房间卡片',
			'settings.roomCardSettingsSubtitle' => '圆角、封面比例与信息行',
			'settings.sectionNetwork' => '网络',
			'settings.proxySettings' => '网络代理',
			'settings.proxySettingsSubtitle' => '通过代理转发请求',
			'settings.refreshOnResume' => '回到前台时刷新',
			'settings.refreshOnResumeSubtitle' => '离开足够久后回到应用时刷新列表',
			'settings.autoCheckUpdate' => '启动时检查更新',
			'settings.autoCheckUpdateSubtitle' => '从发布源检查新版本；关于页随时可以手动检查',
			'settings.countdownClose' => '倒计时退出',
			'settings.countdownCloseSubtitle' => '倒计时结束后退出应用',
			'settings.countdownDuration' => '倒计时时长',
			'settings.minutesValue' => ({required int minutes}) => '${minutes} 分钟',
			'settings.minutesAway' => ({required int minutes}) => '离开 ${minutes} 分钟后',
			'settings.launchPage' => '启动页',
			'settings.launchPageHint' => '应用启动所在的页签。导航设置可以让上次访问的页签优先。',
			'settings.windowSize' => '窗口大小',
			'settings.windowSizeDefault' => '启动默认',
			'settings.windowSizeHint' => '立即生效，并在下次启动时沿用。',
			'settings.groupAutoRefresh' => '自动刷新',
			'settings.autoRefreshInterval' => '前台刷新间隔',
			'settings.autoRefreshIntervalHint' => '当前列表自动刷新的间隔。默认关闭。',
			'settings.refreshResumeThreshold' => '恢复刷新阈值',
			'settings.refreshResumeThresholdHint' => '离开多久后才值得在回到前台时刷新。',
			'settings.refreshOff' => '关闭',
			'settings.refreshEveryResume' => '每次回到前台',
			'settings.groupVisibleBranches' => '显示的页签',
			'settings.groupHiddenBranches' => '隐藏的页签',
			'settings.showBranchSubtitle' => '在外壳中显示此页签',
			'settings.pageSettingsHint' => '拖动排序。至少保留一个页签。',
			'settings.atLeastOneBranch' => '至少需要保留一个页签',
			'settings.groupLaunch' => '启动',
			'settings.restoreLastTab' => '回到上次的位置',
			'settings.restoreLastTabSubtitle' => '启动时回到上次访问的页签',
			'settings.restoreLastTabOn' => ({required String branch}) => '启动时回到上次访问的页签（上次：${branch}）',
			'settings.navigationHint' => '决定启动页跳转的目标；更改在下次启动生效。',
			'settings.proxyGroup' => '代理',
			'settings.proxyEnable' => '使用代理',
			'settings.proxyEnableSubtitle' => '通过下方代理转发请求',
			'settings.proxyEndpoint' => '代理地址',
			'settings.proxyHost' => '地址',
			'settings.proxyPort' => '端口',
			'settings.proxyPortInvalid' => '端口需在 1-65535 之间',
			'settings.proxyHint' => '对新连接立即生效，无需重启。',
			'settings.loadingPreview' => '预览',
			'settings.loadingShimmer' => '微光骨架',
			'settings.loadingSpinner' => '加载圈',
			'settings.loadingNone' => '无',
			'settings.roomCardPreview' => '预览',
			'settings.roomCardAppearance' => '外观',
			'settings.roomCardRadius' => '圆角半径',
			'settings.roomCardAspect' => '封面比例',
			'settings.aspectSixteenByNine' => '16:9',
			'settings.aspectFourByThree' => '4:3',
			'settings.aspectSquare' => '1:1',
			'settings.roomCardContent' => '显示内容',
			'settings.roomCardShowPlatform' => '平台角标',
			'settings.roomCardShowPlatformSubtitle' => '封面上方的平台角标',
			'settings.roomCardShowAudience' => '人气与状态',
			'settings.roomCardShowAudienceSubtitle' => '观看人数、回放与离线角标',
			'settings.roomCardShowAnchor' => '主播行',
			'settings.roomCardShowAnchorSubtitle' => '头像与主播名',
			'settings.roomCardScopeHint' => '作用于推荐、分区、关注与搜索的卡片网格。',
			'settings.remoteSync' => '局域网同步',
			'settings.remoteSyncSubtitle' => '将播放同步到同一网络下的其他设备',
			'settings.sectionRecorder' => '录制',
			'settings.recorderSubtitle' => '监听房间，开播自动录制',
			'settings.pasteCookie' => '粘贴 Cookie 登录',
			'settings.accountSignedInCount' => ({required int count}) => '已登录 ${count} 个平台',
			'settings.sectionVideo' => '视频与弹幕',
			'settings.video' => '视频与弹幕',
			'settings.videoSubtitle' => '房间打开时的声音与弹幕',
			'settings.groupDanmaku' => '弹幕',
			'settings.groupAudio' => '声音',
			'settings.groupAppearance' => '弹幕外观',
			'settings.groupLocalInteraction' => '本地互动',
			'settings.localInteraction' => '本地互动',
			'settings.localInteractionSubtitle' => '开启后房间出现输入框，发送的弹幕只在自己画面显示',
			'settings.localInteractionName' => '本地昵称',
			'settings.danmakuVisible' => '默认显示弹幕',
			'settings.danmakuVisibleSubtitle' => '新房间打开时是否在画面上叠加弹幕',
			'settings.defaultVolume' => '默认音量',
			'settings.defaultVolumeSubtitle' => '下一个房间开始播放时的音量',
			'settings.language' => '界面语言',
			'settings.languageSubtitle' => '跟随系统，或指定一种语言',
			'settings.languageSystem' => '跟随系统',
			'settings.mpvTuning' => '播放器调校',
			'settings.mpvTuningSubtitle' => 'libmpv 的输出、解码与缓存选项',
			'settings.mpvOutputSection' => '输出',
			'settings.mpvCustomOutput' => '自定义输出驱动',
			'settings.mpvCustomOutputSubtitle' => '关闭时引擎使用平台默认输出;打开后驱动选择才会写入',
			'settings.mpvNeedsCustomOutput' => '需先打开"自定义输出驱动"',
			'settings.mpvVideoOutput' => '视频输出 (vo)',
			'settings.mpvAudioOutput' => '音频输出 (ao)',
			'settings.mpvDecodeSection' => '解码与渲染',
			'settings.mpvHardwareDecoder' => '硬件解码 (hwdec)',
			'settings.mpvDeinterlace' => '去隔行 (deinterlace)',
			'settings.mpvInterpolation' => '帧插值 (interpolation)',
			'settings.mpvInterpolationSubtitle' => '补帧更流畅,GPU 开销更高;仅桌面',
			'settings.mpvScaler' => '缩放算法 (scale)',
			'settings.mpvCacheSection' => '缓存',
			'settings.mpvCacheSeconds' => '流缓存秒数',
			'settings.mpvCacheSecondsSubtitle' => '0 表示不改引擎的默认缓存',
			'settings.mpvReset' => '恢复默认',
			'settings.mpvResetSubtitle' => '清空本页全部调校选项',
			'settings.mpvEffectiveNote' => '生效方式',
			'settings.mpvEffectiveNoteBody' => '视频/音频输出与硬件解码在下一次打开流时生效;其余选项即时应用到正在播放的房间。',
			'settings.localConfig' => '本地配置预览',
			'settings.localConfigSubtitle' => '只读展示当前保存的设置文档',
			'settings.localConfigNote' => '本页只读;要修改请回到对应的设置项。',
			'settings.localConfigCopy' => '复制该文档',
			'settings.localConfigApp' => '通用偏好',
			'settings.localConfigAppearance' => '外观',
			'settings.areaInterface' => '界面',
			'settings.areaSources' => '内容来源',
			'settings.areaPlayback' => '播放',
			'settings.areaGeneral' => '通用',
			'settings.areaData' => '数据',
			'settings.searchHint' => '搜索设置',
			'settings.searchEmpty' => '没有找到相关设置',
			'settings.searchEmptyHint' => '换个关键词试试',
			'settings.platformsTitle' => '平台',
			'settings.platformsDesc' => '平台显示、排序与账号',
			'settings.danmakuTitle' => '弹幕',
			'settings.danmakuDesc' => '弹幕显示、字号、透明度与屏蔽',
			'settings.recordingTitle' => '录制',
			'settings.recordingDesc' => '输出目录与分段时长',
			'settings.playerTitle' => '播放器',
			'settings.playerDesc' => '解码、输出与缓存调优',
			'settings.logTitle' => '日志',
			'settings.logDesc' => '日志级别与导出',
			'settings.localInteractionDesc' => '本地弹幕身份与开关',
			'settings.localInteractionColor' => '弹幕颜色',
			'settings.navigationDesc' => '导航栏显示与启动页',
			'settings.videoDesc' => '音量、清晰度与后台播放',
			'settings.refreshDesc' => '自动刷新与开播提醒',
			'settings.generalDesc' => '启动、更新与窗口',
			'settings.proxyDesc' => '应用与播放器代理',
			'settings.cacheDesc' => '缓存大小与清理',
			'settings.backupDesc' => '备份与恢复本地数据',
			'settings.iptvDesc' => '管理播放源与频道',
			'settings.pageDesc' => '分页与翻页方式',
			'settings.pagerGroup' => '分页条（电脑）',
			'settings.pageDefaultSize' => '默认每页条数',
			'settings.pageDefaultSizeHint' => '进入列表时每页显示多少条；分页条上也能临时改',
			'settings.pageSizeAuto' => '自动',
			'settings.itemsPerPage' => '条/页',
			'settings.pageSizeOptionsTitle' => '单页可选数量列表',
			'settings.pageSizeRestore' => '恢复推荐',
			'settings.pageSizeInputHint' => '输入 1–100',
			'settings.pageSizeRangeError' => '请输入 1 至 100 的整数',
			'settings.pageSizeDuplicateError' => '该单页数量已在列表中',
			'settings.pageSizeCurrent' => '当前已启用的可选项',
			'settings.pageShowScrollTop' => '显示一键置顶按钮',
			'settings.pageShowScrollTopSubtitle' => '列表滑动超过设定距离后在右下角悬浮置顶按钮',
			'settings.pageShowSizeSelector' => '显示单页数量选择器',
			'settings.pageShowSizeSelectorSubtitle' => '在列表控制条显示每页显示行数下拉选单',
			'settings.pageShowGoto' => '显示页码跳转按钮',
			'settings.pageShowGotoSubtitle' => '开启后支持手动输入页码进行快速跳转',
			'settings.configPreviewDesc' => '只读展示当前保存的设置',
			'hotAreas.title' => '平台显示',
			'hotAreas.note' => '隐藏的平台不会出现在热门、分区与搜索中。',
			'hotAreas.orderNote' => '拖动调整平台的显示顺序。',
			'hotAreas.visible' => '显示',
			'hotAreas.hidden' => '隐藏',
			'hotAreas.restore' => '恢复默认',
			'hotAreas.keepAtLeastOne' => '至少保留一个平台',
			'tags.title' => '标签管理',
			'tags.add' => '新建标签',
			'tags.name' => '标签名称',
			'tags.rename' => '重命名',
			'tags.delete' => '删除',
			'tags.deleteConfirm' => ({required Object name}) => '删除标签「${name}」？标签内的房间仍会被关注。',
			'tags.pin' => '置顶',
			'tags.unpin' => '取消置顶',
			'tags.pinned' => '已置顶',
			'tags.empty' => '还没有标签',
			'tags.emptyHint' => '在关注页长按房间可以加入标签。',
			'tags.countValue' => ({required int count}) => '${count} 个标签',
			'tags.nameEmpty' => '名称不能为空',
			'tags.nameTaken' => '已有同名标签',
			'logs.title' => '日志',
			'logs.level' => '日志级别',
			'logs.levelHint' => '级别越低记录越多；保存后每次启动都会沿用。',
			'logs.levelTrace' => '全部（trace）',
			'logs.levelDebug' => '详细（debug）',
			'logs.levelInfo' => '常规（info）',
			'logs.levelWarning' => '警告（warning）',
			'logs.levelError' => '错误（error）',
			'logs.levelFatal' => '严重（fatal）',
			'logs.levelOff' => '关闭',
			'logs.levelDefault' => '跟随构建默认值',
			'logs.export' => '导出最近日志',
			'logs.exportDone' => ({required int count}) => '已复制 ${count} 条日志到剪贴板',
			'logs.exportEmpty' => '内存里还没有日志',
			'logs.openFolder' => '打开日志目录',
			'logs.note' => '日志文件保存在数据目录的 logs 下，会滚动清理。',
			'recorder.title' => '录播',
			'recorder.addRoom' => '添加房间',
			'recorder.platform' => '平台',
			'recorder.roomId' => '房间号',
			'recorder.startWatching' => '开始监听',
			'recorder.watchStarted' => '已开始监听，开播后自动录制',
			'recorder.watchFailed' => ({required String error}) => '监听失败：${error}',
			'recorder.noSites' => '没有支持房间查询的平台',
			'recorder.openFolder' => '打开输出目录',
			'recorder.folderNotOpened' => '无法打开文件夹',
			'recorder.outputDirectory' => '输出目录',
			'recorder.outputDirectoryDefault' => '应用的录制目录',
			'recorder.chooseDirectory' => '选择录制目录',
			'recorder.segmentLength' => '分段时长',
			'recorder.minutesValue' => ({required int minutes}) => '${minutes} 分钟',
			'recorder.segmentsValue' => ({required int count}) => '${count} 个分段',
			'recorder.restoring' => '正在恢复上次未完成的录制…',
			'recorder.engineFailed' => ({required String error}) => '录制引擎启动失败：${error}',
			'recorder.filterAll' => '全部',
			'recorder.filterActive' => '进行中',
			'recorder.filterWaiting' => '等待中',
			'recorder.filterSaved' => '已保存',
			'recorder.filterFailed' => '失败',
			'recorder.recordSettings' => '录制设置',
			'recorder.filterFinished' => '已结束',
			'recorder.emptyTitle' => '还没有监听的房间',
			'recorder.emptySubtitle' => '添加一个房间，开播后自动录制',
			'recorder.nothingToJoin' => '没有待合并的分段',
			'recorder.actionStop' => '停止',
			'recorder.actionFinishNow' => '立即合并',
			'recorder.actionRestart' => '重新录制',
			'recorder.statusQueued' => '排队中',
			'recorder.statusResolving' => '解析中',
			'recorder.statusRecording' => '录制中',
			'recorder.statusRetrying' => '重连中',
			'recorder.statusMerging' => '合并中',
			'recorder.statusCompleted' => '已完成',
			'recorder.statusFailed' => '失败',
			'recorder.statusStopped' => '已停止',
			'recorder.statusInterrupted' => '已中断',
			'recorder.roomUnknown' => '未查询',
			'recorder.roomWaiting' => '等待开播',
			'recorder.roomLive' => '正在直播',
			'recorder.roomEnded' => '直播已结束',
			'recorder.roomStalled' => '信号停滞',
			'recorder.roomUnavailable' => '房间不可用',
			'theme.system' => '跟随系统',
			'theme.dark' => '深色',
			'theme.light' => '浅色',
			'design.defaultLanguage' => '默认（Fluent）',
			'history.countOfLimit' => ({required int count, required int limit}) => '${count} / ${limit} 条',
			'history.countUnlimited' => ({required int count}) => '${count} 条记录',
			'history.filterOpen' => '筛选',
			'history.filterClose' => '关闭筛选',
			'history.filterHint' => '按标题或主播筛选',
			'history.filterMatches' => ({required int count}) => '${count} 条匹配',
			'history.filterEmpty' => '没有匹配的观看记录',
			'history.refreshStatus' => '刷新观看状态',
			'history.refreshDone' => ({required int count}) => '已刷新 ${count} 条记录',
			'history.refreshPartial' => ({required int failed, required int count}) => '${failed} 条刷新失败（共 ${count} 条）',
			'history.refreshSaveFailed' => '刷新结果保存失败',
			'history.limitTitle' => '记录上限',
			'history.limitHint' => '0 表示不限制；超出的旧记录会被删除。',
			'history.removed' => '已移除该记录',
			'history.cleared' => ({required int count}) => '已清空 ${count} 条记录',
			'history.clear' => '清空记录',
			'history.resume' => '继续播放',
			'history.clearConfirm' => '清空全部观看记录？此操作不可撤销。',
			'history.empty' => '还没有观看记录',
			'history.today' => '今天',
			'history.yesterday' => '昨天',
			'history.thisWeek' => '本周',
			'history.thisMonth' => '本月',
			'history.earlier' => '更早',
			'history.remove' => '删除记录',
			'history.removeConfirm' => '删除这条观看记录？',
			'iptv.epgTitle' => '节目单',
			'iptv.title' => 'IPTV',
			'iptv.addSource' => '添加源',
			'iptv.sourceName' => '源名称',
			'iptv.sourceUrl' => '播放列表地址（M3U/TXT）',
			'iptv.deleteSource' => '删除该源？频道一并移除',
			'iptv.imported' => ({required int count}) => '已导入 ${count} 个频道',
			'iptv.allGroups' => '全部分组',
			'iptv.favorite' => '收藏',
			'iptv.empty' => '还没有导入任何源',
			'iptv.search' => '搜索频道',
			'iptv.favoritesOnly' => '只看收藏',
			'iptv.noMatch' => '没有匹配的频道',
			'iptv.channels' => '频道列表',
			'iptv.switchChannel' => '切换频道',
			'iptv.dialPad' => '数字选台',
			'iptv.noNumber' => ({required int number}) => '没有 ${number} 号频道',
			'iptv.importFromFile' => '从文件导入',
			'iptv.importFailed' => '导入失败',
			'iptv.lineOf' => ({required int index, required int total}) => '线路 ${index}/${total}',
			'iptv.kindPlaylist' => 'M3U / TXT',
			'iptv.kindXtream' => 'Xtream',
			'iptv.xtreamServer' => '服务器地址（http://host:port）',
			'iptv.xtreamUsername' => '用户名',
			'iptv.xtreamPassword' => '密码',
			'iptv.epgUrl' => 'EPG 地址（可选）',
			'iptv.xtreamAuthFailed' => '服务器拒绝了这组账号信息',
			'iptv.refreshSource' => '刷新该源',
			'iptv.epgNow' => '当前节目',
			'iptv.epgNext' => '接下来',
			'iptv.refreshEpg' => '刷新节目单',
			'iptv.hotChannels' => '热门频道',
			'iptv.viewAll' => '查看全部',
			'iptv.liveNow' => '正在直播',
			'iptv.prevChannel' => '上一频道',
			'iptv.channelList' => '频道列表',
			'iptv.playbackSettings' => '播放设置',
			'iptv.lineSelect' => '选择线路',
			'iptv.numberPad' => '数字选台',
			'iptv.refreshGuide' => '刷新节目单',
			'fonts.fonts' => '字体管理',
			'fonts.system' => '系统默认',
			'fonts.systemDesc' => '使用系统自带字体',
			'fonts.download' => '下载',
			'fonts.delete' => '删除',
			'fonts.factoryDefault' => '出厂默认',
			'fonts.cloudFonts' => '云端字体',
			'follow.all' => '全部',
			'follow.empty' => '还没有关注任何房间',
			'follow.follow' => '关注',
			'follow.unfollow' => '取消关注',
			'follow.unfollowConfirm' => ({required String name}) => '不再关注「${name}」？',
			'follow.liveRoom' => '直播',
			'follow.replayRoom' => '回放',
			'follow.offlineRoom' => '离线',
			'follow.emptyLive' => '没有正在直播的关注',
			'follow.emptyReplay' => '没有可看回放的关注',
			'follow.emptyOffline' => '没有离线的关注',
			'follow.showOffline' => '查看离线',
			'follow.refreshFailed' => ({required int count}) => '${count} 个房间刷新失败',
			'follow.newGroup' => '新建分组',
			'follow.manageGroups' => '管理分组',
			'follow.renameGroup' => '重命名分组',
			'follow.deleteGroup' => '删除分组',
			'follow.deleteGroupConfirm' => '删除分组不影响已关注的房间。确认删除？',
			'follow.assign' => '移动到分组',
			'follow.groupName' => '分组名称',
			'toolbox.title' => '工具箱',
			'toolbox.hint' => '粘贴直播间链接',
			'toolbox.readClipboard' => '读取剪贴板',
			'toolbox.resolve' => '解析',
			'toolbox.failed' => '没有平台识别该链接',
			'toolbox.openRoom' => '打开房间',
			'toolbox.roomJump' => '直播间跳转',
			'toolbox.linkJump' => '链接跳转',
			'toolbox.directLink' => '获取直链',
			'toolbox.parse' => '获取解析',
			'toolbox.inputHint' => '请在此处粘贴平台链接...',
			'toolbox.supportList' => '支持解析列表',
			'toolbox.supportContent' => '支持以下类型的链接解析：\n\n哔哩哔哩：\nhttps://live.bilibili.com/xxxxx\nhttps://www.bilibili.com/xxxxx\nhttps://b23.tv/xxxxx\n\n虎牙直播：\nhttps://www.huya.com/xxxxx\n\n斗鱼直播：\nhttps://www.douyu.com/xxxxx\n\n抖音直播/视频：\nhttps://live.douyin.com/xxxxx\nhttps://www.douyin.com/xxxxx\nhttps://v.douyin.com/xxxxx\nhttps://webcast.amemv.com/douyin/webcast/reflow/xxxxx\n\n快手直播：\nhttps://live.kuaishou.com/u/xxxxx\nhttps://live.kuaishou.cn/u/xxxxx\n\n网易CC直播：\nhttps://cc.163.com/xxxxx\n\nTwitch直播：\nhttps://www.twitch.tv/xxxxx\nhttps://twitch.tv/xxxxx\n\nSOOP直播：\nhttps://www.sooplive.com/xxxxx\nhttps://sooplive.com/xxxxx\nhttps://play.sooplive.com/xxxxx\nhttps://www.sooplive.co.kr/xxxxx\nhttps://sooplive.co.kr/xxxxx\nhttps://play.sooplive.co.kr/xxxxx\n\nYY直播：\nhttps://www.yy.com/xxxxx\nhttps://yy.com/xxxxx\nhttps://www.yy.com/xxxxx/xxxxx?tempId=xxxxx\nhttps://yy.com/xxxxx/xxxxx?tempId=xxxxx\n\nAcFun直播:\nhttps://live.acfun.cn/live/123456\n\nPicarto:\nhttps://picarto.tv/ChannelName\n\nTwitCasting:\nhttps://twitcasting.tv/ChannelName\nhttps://twitcasting.tv/c:ChannelName\n\nCHZZK:\nhttps://chzzk.naver.com/live/0123456789abcdef0123456789abcdef\n\nKick:\nhttps://kick.com/ChannelName\n\n17LIVE:\nhttps://17.live/en/live/1234567',
			'toolbox.emptyLink' => '链接不能为空',
			'toolbox.parseFailed' => '无法解析此链接',
			'toolbox.getUrlFailed' => '读取直链失败',
			'toolbox.selectQuality' => '选择清晰度',
			'toolbox.selectLine' => '选择线路',
			'toolbox.line' => ({required int index}) => '线路${index}',
			'toolbox.detectLink' => '检测到链接',
			'toolbox.autoFill' => '已自动填充剪贴板中的直播链接',
			'toolbox.copySuccess' => '已复制直链',
			'backup.title' => '备份与恢复',
			'backup.create' => '创建备份',
			'backup.restoreFile' => '从文件恢复',
			'backup.existing' => '已有备份',
			'backup.none' => '还没有备份',
			'backup.delete' => '删除备份',
			'backup.restore' => '恢复',
			'backup.restoreConfirm' => ({required String name}) => '用「${name}」覆盖当前数据？应用将重启。',
			'backup.sectionCloud' => '云端与同步',
			'about.native' => '本机',
			'about.downloadFilesOf' => ({required Object platform}) => '下载文件 · ${platform}',
			'about.title' => '关于',
			'about.group' => '关于',
			'about.checkUpdate' => '检查更新',
			'about.onlineUpdate' => '在线更新',
			'about.versionUpdate' => '版本更新',
			'about.updateLog' => '更新日志',
			'about.upToDate' => '已是最新版本',
			'about.newVersion' => '发现新版本',
			'about.noNewVersion' => '已在使用最新版本',
			'about.openSourceFree' => '本软件开源免费',
			'about.update' => '更新',
			'about.refresh' => '刷新',
			'about.versionHistory' => '版本历史',
			'about.historyDesc' => '历史版本更新记录',
			'about.publishedAt' => ({required String date}) => '发布于 ${date}',
			_ => null,
		} ?? switch (path) {
			'about.openRelease' => '打开发布页面',
			'about.licenses' => '开源许可证',
			'about.project' => '项目主页',
			'about.projectSection' => '项目',
			'about.projectAlert' => '项目声明',
			'about.legalese' => '© 2026 PureLive 开源项目。本程序为纯本地客户端应用，直接请求媒体平台官方公开接口，项目本身不存储、不制作、不分发任何音视频资源。本程序登录及云同步功能由第三方基础设施服务商 Firebase 提供。开发者郑重承诺，本程序本身不收集、不处理且不留存任何用户个人隐私信息。所有运行、配置及同步数据均由用户自行留存与控制，数据所有权及隐私权益完全归属于用户。用户需自行承担使用本测试工具所产生的相关法律责任。',
			'about.browserNotOpened' => '系统浏览器未打开，请检查默认浏览器设置',
			'about.checkRunning' => '正在检查…',
			'about.checkFailed' => '检查失败，点此重试',
			'about.downloadFiles' => '下载文件',
			'about.copyLink' => '复制链接',
			'about.copied' => '链接已复制',
			'about.download' => '下载',
			'about.assetMeta' => ({required String size, required int count}) => '${size} · ${count} 次下载',
			'about.startupUpdateBody' => ({required Object tag}) => '最新版本 ${tag} 已发布。现在打开更新页面吗?',
			'shield.title' => '弹幕屏蔽',
			'shield.keywords' => '关键词',
			'shield.users' => '用户',
			'shield.regexes' => '正则',
			'shield.add' => '添加',
			'shield.none' => '暂无',
			'shield.keywordHint' => '输入要屏蔽的关键词',
			'shield.emptyKeyword' => '请输入关键词',
			'multiview.title' => '多画面',
			'multiview.platform' => '平台',
			'multiview.roomId' => '房间号',
			'multiview.add' => '添加格子',
			'multiview.layout' => '布局',
			'multiview.pickRoom' => '选择房间',
			'multiview.pickHint' => '粘贴房间链接，或从关注列表选择',
			'multiview.emptyCell' => '点击选择房间',
			'multiview.mute' => '静音',
			'multiview.unmute' => '取消静音',
			'multiview.muteAll' => '全部静音',
			'multiview.unmuteAll' => '取消全部静音',
			'multiview.audioFocus' => '正在播放声音',
			'multiview.removeCell' => '移除格子',
			'multiview.noPick' => '还没有关注或历史房间',
			'search.hint' => '输入关键词搜索房间',
			'search.rooms' => '房间',
			'search.anchors' => '主播',
			'search.areas' => '分区',
			'search.allSites' => '全部',
			'search.historyTitle' => '搜索历史',
			'search.historyRemove' => '删除该搜索',
			'room.sortPlatform' => '默认排序',
			'room.sortViewers' => '人气优先',
			'room.danmakuFailed' => '弹幕连接失败',
			'room.quality' => '清晰度',
			'room.line' => '线路',
			'room.play' => '播放',
			'room.pause' => '暂停',
			'room.failed' => '播放失败，请重试',
			'room.replay' => '回放',
			'room.offline' => '未开播',
			'room.entryFailed' => '房间打开失败',
			'room.chat' => '聊天',
			'room.superChat' => '醒目留言',
			'room.gifts' => '礼物',
			'room.shield' => '弹幕屏蔽',
			'room.danmakuEnded' => '弹幕连接已断开',
			'room.reconnecting' => '弹幕重连中…',
			'room.sendPlaceholder' => '发个弹幕吧…',
			'room.sendUnavailable' => '发送弹幕需要登录平台账号（暂未接入）',
			'room.backToLive' => '回到底部',
			'room.newMessages' => ({required Object count}) => '${count} 条新消息',
			'room.superChatEmpty' => '暂无醒目留言',
			'room.superChatEmptyHint' => '观众的付费高亮消息会显示在这里',
			'room.giftsEmpty' => '暂无礼物',
			'room.giftsEmptyHint' => '直播间收到的礼物会显示在这里',
			'room.follow' => '关注',
			'room.followed' => '已关注',
			'room.followers' => ({required Object count}) => '${count} 粉丝',
			'room.popularity' => '人气',
			'room.online' => '在线',
			'room.lineN' => ({required Object n}) => '线路 ${n}',
			'room.fullscreen' => '全屏',
			'room.lock' => '锁定屏幕',
			'room.unlock' => '解锁屏幕',
			'room.videoFit' => '画面比例',
			'room.fitContain' => '适配',
			'room.fitCover' => '填满',
			'room.fitFill' => '拉伸',
			'room.exitFullscreen' => '退出全屏',
			'room.barrageOn' => '显示弹幕',
			'room.barrageOff' => '关闭弹幕',
			'room.toolbox' => '工具箱',
			'room.copyLink' => '复制房间链接',
			'room.linkCopied' => '已复制',
			'room.record' => '录制',
			'room.stopRecording' => '停止录制',
			'room.rateNormal' => '原速',
			'room.audienceWaiting' => '等待观众数据',
			'room.mute' => '静音',
			'room.unmute' => '取消静音',
			'room.danmakuOn' => '弹幕已开',
			'room.sleepTimer' => '睡眠定时',
			'room.sleepTimerOn' => '睡眠定时（已开启）',
			'room.sleepTimerEnable' => '启用播放定时',
			'room.sleepTimerDesc' => '到时后暂停当前房间的播放',
			'room.timerDuration' => '定时时长',
			'room.timerDurationHint' => '1 - 525600 分钟',
			'room.timerInvalid' => '请输入 1 到 525600 之间的分钟数',
			'room.timerFinished' => '播放定时已结束，已暂停',
			'room.minutesUnit' => '分钟',
			'room.minutesN' => ({required Object minutes}) => '${minutes} 分钟',
			'room.roomVolume' => '房间音量',
			'room.roomVolumeDesc' => '设置静音与手机、桌面各自的默认音量',
			'room.globalMute' => '全局静音',
			'room.globalMuteSubtitle' => '所有房间以静音开始，音量数值保留',
			'room.mobileDefaultVolume' => '手机默认音量',
			'room.desktopDefaultVolume' => '桌面默认音量',
			'room.resetDefault' => '恢复默认',
			'room.volumeApplyFailed' => '当前房间无法应用音量，请确认后重试',
			'room.send' => '发送',
			'room.localMe' => '我',
			'room.barrageSettings' => '弹幕设置',
			'room.keywordBlock' => '关键词屏蔽',
			'room.barrageHiddenHint' => '弹幕已全局关闭',
			'room.barrageOnSubtitle' => '在画面上叠加滚动弹幕',
			'room.barrageFontSize' => '弹幕字号',
			'room.barrageOpacity' => '弹幕透明度',
			'room.barrageSettingsNote' => '这些设置即时生效，并作为新房间的默认值',
			'room.enterLandscapeFullscreen' => '横屏全屏',
			'room.enterPortraitFullscreenHint' => '继续下滑进入竖屏全屏',
			'room.portraitPanelResize' => '面板高度',
			'room.portraitPanelResizeHint' => '拖动调整面板高度',
			'areas.empty' => '暂无分区',
			'popular.allPlatforms' => '全部平台',
			'popular.allPlatformsHint' => '点按切换平台；平台显示设置可隐藏或排序。',
			'popular.noPlatforms' => '没有可显示的平台',
			'popular.noPlatformsHint' => '在平台显示设置里至少开启一个平台。',
			'popular.empty' => '暂时没有热门直播',
			'remoteSync.title' => '设备同步',
			'remoteSync.tileSubtitle' => '在同一网络下的设备间同步关注与历史',
			'remoteSync.myDevice' => '我的设备',
			'remoteSync.noAddress' => '未找到局域网地址',
			'remoteSync.scanHint' => '让另一台设备扫描此二维码，或在对方输入本机地址',
			'remoteSync.running' => '同步服务运行中',
			'remoteSync.notRunning' => '同步服务未运行',
			'remoteSync.start' => '启动',
			'remoteSync.stop' => '停止',
			'remoteSync.devices' => '发现的设备',
			'remoteSync.noDevices' => '未发现其他设备',
			'remoteSync.manual' => '手动输入',
			'remoteSync.send' => '发送配置',
			'remoteSync.receive' => '接收配置',
			'remoteSync.sendSuccess' => '发送成功',
			'remoteSync.sendFailed' => '发送失败——请检查地址，并确认对方已同意',
			'remoteSync.receiveSuccess' => '接收并应用成功',
			'remoteSync.receiveFailed' => '接收失败',
			'remoteSync.enterAddress' => '请先输入对方设备地址',
			'remoteSync.invalidAddress' => '地址格式不正确',
			'remoteSync.incomingImport' => ({required String address}) => '${address} 想要覆盖本机的关注、历史与弹幕屏蔽，是否允许？',
			'remoteSync.incomingExport' => ({required String address}) => '${address} 想要读取本机的关注、历史与弹幕屏蔽，是否允许？',
			'remoteSync.sectionFavorite' => '关注列表',
			'remoteSync.sectionHistory' => '观看历史',
			'remoteSync.sectionGroups' => '关注分组',
			'remoteSync.noAddressHint' => '请连接 Wi-Fi 或有线网络；Android 需要允许"附近设备 / 局域网"权限，然后点右上角开始',
			'remoteSync.description' => '请确保两台设备连接到同一个局域网',
			'remoteSync.searching' => '正在搜索局域网设备...',
			'remoteSync.searchingShort' => '正在搜索',
			'remoteSync.manualHint' => '输入对方设备的地址，或粘贴对方二维码里的同步链接',
			'remoteSync.copyAddress' => '复制地址',
			'remoteSync.addressCopied' => '地址已复制',
			'remoteSync.fromName' => ({required String name}) => '来自 ${name}',
			'remoteSync.legacyDevice' => '3.x 版本的设备',
			'remoteSync.allow' => '允许',
			'remoteSync.reject' => '拒绝',
			'remoteSync.incomingImportNamed' => ({required Object address, required Object name}) => '设备 ${address}（${name}）请求用它的设置覆盖本机设置，是否允许？',
			'remoteSync.incomingExportNamed' => ({required Object address, required Object name}) => '设备 ${address}（${name}）请求读取本机设置，是否允许？',
			'errors.generic' => '出了点问题，请稍后再试。',
			'errors.network' => '网络连接不可用，请检查网络后重试。',
			'errors.notFound' => '没有找到相关内容。',
			'errors.cancelled' => '已取消。',
			'errors.unsupported' => '当前来源不支持该功能。',
			'tabs.home' => '首页',
			'tabs.favorites' => '关注',
			'tabs.follow' => '关注',
			'tabs.history' => '历史',
			'tabs.popular' => '热门',
			'tabs.areas' => '分区',
			'tabs.search' => '搜索',
			'tabs.settings' => '设置',
			'tabs.record' => '录制中心',
			'window.minimize' => '最小化',
			'window.maximize' => '最大化',
			'window.restore' => '还原',
			'window.close' => '关闭',
			'closePrompt.title' => '关闭窗口时要执行什么？',
			'closePrompt.toTray' => '隐藏到托盘，保留播放',
			'closePrompt.quit' => '退出 Pure Live',
			'closePrompt.remember' => '记住我的选择，不再询问',
			'shellSettings.sectionWindow' => '窗口',
			'shellSettings.titleBar' => '窗口标题栏',
			'shellSettings.titleBarAuto' => '自动（按系统版本）',
			'shellSettings.titleBarApp' => '应用标题栏',
			'shellSettings.titleBarSystem' => '系统标题栏',
			'shellSettings.titleBarHint' => '自动：Windows 11 用应用标题栏，Windows 10 用系统标题栏。应用标题栏由 Pure Live 绘制，系统标题栏使用 Windows 原生样式。切换在重启应用后生效。',
			'webdav.title' => 'WebDAV 云备份',
			'webdav.entryTitle' => 'WebDAV 云同步',
			'webdav.entrySubtitle' => '备份到你自己的 WebDAV 服务器',
			'webdav.sectionConfig' => '服务器',
			'webdav.addressHint' => 'https://dav.jianguoyun.com/dav/',
			'webdav.addressInvalid' => '请输入有效的 http(s) 地址',
			'webdav.username' => '账户',
			'webdav.password' => '应用密码',
			'webdav.directory' => '目录（可选）',
			'webdav.testConnection' => '测试连接',
			'webdav.testing' => '正在连接…',
			'webdav.testOk' => '连接成功，地址、账户和密码均有效。',
			'webdav.testFailed' => '连接失败',
			'webdav.backupNow' => '立即备份',
			'webdav.backingUp' => '正在上传备份…',
			'webdav.backupDone' => '备份已上传',
			'webdav.configIncomplete' => '请先填写服务器地址、账户和应用密码',
			'webdav.lastBackup' => '上次备份',
			'webdav.lastRestore' => '上次恢复',
			'webdav.never' => '从未',
			'webdav.remote' => '云端备份',
			'webdav.remoteEmpty' => '还没有云端备份',
			'webdav.restore' => '恢复',
			'webdav.restoreConfirm' => '下载该备份并覆盖当前数据？应用将重启。',
			'webdav.delete' => '删除',
			'webdav.deleteConfirm' => '从服务器删除该备份？',
			'webdav.helpTitle' => '配置说明',
			'webdav.helpIntro' => '云备份把与本地备份相同的压缩包上传到你自己的 WebDAV 服务器，让关注、历史和设置在重装后依然可用。任何 WebDAV 服务都可以，下面以坚果云为例。',
			'webdav.helpSteps' => '1. 在 www.jianguoyun.com 注册并登录。\n2. 打开「选项 → 安全选项」，生成应用密码。\n3. 在上方填写服务器地址、账户和该应用密码。',
			'webdav.helpServer' => '服务器：坚果云的 WebDAV 地址为 https://dav.jianguoyun.com/dav/',
			'webdav.helpAccount' => '账户：坚果云的登录名（通常是手机号或邮箱）。',
			'webdav.helpPassword' => '密码：不是登录密码 —— WebDAV 使用「选项 → 安全选项」中生成的应用密码。',
			'webdav.helpIssues' => '连接失败？检查地址是否以 /dav/ 结尾、是否使用应用密码而非登录密码，以及网络是否屏蔽了 WebDAV 端口。',
			'webdav.openOfficialHelp' => '打开坚果云官方帮助',
			'webdav.helpOpenFailed' => '无法打开浏览器',
			'wallpaper.title' => '背景壁纸',
			'wallpaper.entrySubtitle' => '纯色、渐变或本地图片',
			'wallpaper.currentNone' => '跟随主题',
			'wallpaper.currentSolid' => '纯色',
			'wallpaper.currentGradient' => '渐变',
			'wallpaper.currentImage' => '图片',
			'wallpaper.groupPresets' => '预设',
			'wallpaper.groupSolid' => '纯色',
			'wallpaper.groupGradient' => '渐变',
			'wallpaper.groupDevice' => '本机图片',
			'wallpaper.groupDisplay' => '图片显示',
			'wallpaper.none' => '无背景',
			'wallpaper.noneSubtitle' => '保留主题表面',
			'wallpaper.pickImage' => '选择图片',
			'wallpaper.pickImageSubtitle' => '从本机选择一张图片',
			'wallpaper.imagePath' => '图片路径',
			'wallpaper.imagePathHint' => '输入图片的绝对路径',
			'wallpaper.scrim' => '压暗图片',
			'wallpaper.scrimSubtitle' => '在图片上加一层暗色，保证文字可读',
			'wallpaper.blur' => '模糊图片',
			'wallpaper.blurOff' => '关闭',
			'wallpaper.fit' => '填充方式',
			'wallpaper.fitCover' => '裁剪填充',
			'wallpaper.fitContain' => '完整显示',
			'wallpaper.fitFill' => '拉伸',
			'wallpaper.imageMissing' => '找不到图片，请检查路径',
			_ => null,
		};
	}
}
