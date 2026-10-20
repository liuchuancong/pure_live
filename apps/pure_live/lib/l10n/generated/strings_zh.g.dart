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
	late final Translations$cast$zh cast = Translations$cast$zh.internal(_root);
	late final Translations$danmaku$zh danmaku = Translations$danmaku$zh.internal(_root);
	late final Translations$clipboard$zh clipboard = Translations$clipboard$zh.internal(_root);
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

	/// zh: '删除'
	String get delete => '删除';

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

	/// zh: '忽略'
	String get ignore => '忽略';
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

	/// zh: '隐藏主界面'
	String get hide => '隐藏主界面';

	/// zh: '正在录制 {count} 个直播间'
	String recordingCount({required Object count}) => '正在录制 ${count} 个直播间';

	/// zh: 'Pure Live · 正在录制 {count} 个直播间'
	String tooltipRecording({required Object count}) => 'Pure Live · 正在录制 ${count} 个直播间';
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

	/// zh: '{name}账号'
	String editorTitle({required Object name}) => '${name}账号';

	/// zh: 'Cookie'
	String get cookieGroup => 'Cookie';

	/// zh: '粘贴'
	String get paste => '粘贴';

	/// zh: '清空'
	String get clearInput => '清空';

	/// zh: '这不像 Cookie：应为 name=value; name2=value2 的形式'
	String get cookieInvalid => '这不像 Cookie：应为 name=value; name2=value2 的形式';

	/// zh: '剪贴板里没有文字'
	String get clipboardEmpty => '剪贴板里没有文字';

	/// zh: '未设置：粘贴登录后的 Cookie'
	String get editorNoneHint => '未设置：粘贴登录后的 Cookie';

	/// zh: '已保存'
	String get saved => '已保存';

	/// zh: '已登录：{name}'
	String signedIn({required Object name}) => '已登录：${name}';

	/// zh: '已保存 · 账号 ID {uid}'
	String statusUid({required Object uid}) => '已保存 · 账号 ID ${uid}';

	/// zh: '正在核验账号…'
	String get verifying => '正在核验账号…';

	/// zh: '正在核验并保存…'
	String get savingVerifying => '正在核验并保存…';

	/// zh: '打开{name}网页'
	String openSite({required Object name}) => '打开${name}网页';

	/// zh: 'Cookie 只加密保存在本机，不会上传。'
	String get privacyNote => 'Cookie 只加密保存在本机，不会上传。';

	/// zh: '舍弃 Cookie 修改？'
	String get discardTitle => '舍弃 Cookie 修改？';

	/// zh: '编辑后的 Cookie 尚未保存。确定舍弃修改并离开此页面吗？'
	String get discardDetail => '编辑后的 Cookie 尚未保存。确定舍弃修改并离开此页面吗？';

	/// zh: '舍弃'
	String get discard => '舍弃';

	/// zh: '继续编辑'
	String get keepEditing => '继续编辑';

	/// zh: '在浏览器里登录该平台，打开开发者工具，复制请求头里的整段 Cookie 粘贴到下面。'
	String get cookieTip => '在浏览器里登录该平台，打开开发者工具，复制请求头里的整段 Cookie 粘贴到下面。';

	/// zh: '已过期，请重新粘贴 Cookie'
	String get statusExpired => '已过期，请重新粘贴 Cookie';

	/// zh: 'LTP0（长期密钥）'
	String get douyuLtp0 => 'LTP0（长期密钥）';

	/// zh: 'passport.douyu.com 请求 Cookie 里的 LTP0，粘贴上面 Cookie 后自动填入'
	String get douyuLtp0Hint => 'passport.douyu.com 请求 Cookie 里的 LTP0，粘贴上面 Cookie 后自动填入';

	/// zh: 'dy_did（设备号）'
	String get douyuDid => 'dy_did（设备号）';

	/// zh: '同一个请求 Cookie 里的 dy_did（32 位十六进制），粘贴后自动填入'
	String get douyuDidHint => '同一个请求 Cookie 里的 dy_did（32 位十六进制），粘贴后自动填入';

	/// zh: '立即续期'
	String get douyuRenew => '立即续期';

	/// zh: '续期需要 LTP0 和 dy_did：先在浏览器里登录斗鱼再粘贴一次 Cookie'
	String get douyuRenewNeedPair => '续期需要 LTP0 和 dy_did：先在浏览器里登录斗鱼再粘贴一次 Cookie';

	/// zh: '已保存，但 Cookie 里没有 acf_jwt_token：当前是游客身份，高清/超清不可用'
	String get douyuStatusGuest => '已保存，但 Cookie 里没有 acf_jwt_token：当前是游客身份，高清/超清不可用';

	/// zh: '登录有效（Cookie 未提供到期时间；如需自动续期请补上 LTP0）'
	String get douyuStatusNoExpiry => '登录有效（Cookie 未提供到期时间；如需自动续期请补上 LTP0）';

	/// zh: '登录有效（约 7 天，预计 {time} 到期）；已配置 LTP0，到期前会自动续期'
	String douyuStatusAutoRenew({required Object time}) => '登录有效（约 7 天，预计 ${time} 到期）；已配置 LTP0，到期前会自动续期';

	/// zh: '登录有效（约 7 天，预计 {time} 到期）；未配置 LTP0，到期后需要重新粘贴'
	String douyuStatusRepaste({required Object time}) => '登录有效（约 7 天，预计 ${time} 到期）；未配置 LTP0，到期后需要重新粘贴';

	/// zh: '登录态已过期（{time}）；已保存，下次播放会自动用 LTP0 续期'
	String douyuStatusRenewable({required Object time}) => '登录态已过期（${time}）；已保存，下次播放会自动用 LTP0 续期';

	/// zh: '登录态已过期（{time}），且 Cookie 里没有 LTP0，需要重新获取'
	String douyuStatusExpired({required Object time}) => '登录态已过期（${time}），且 Cookie 里没有 LTP0，需要重新获取';

	/// zh: '已记住的账号'
	String get savedAccounts => '已记住的账号';

	/// zh: '登录过的账号记在这里（最多 {count} 个），切换不用重新扫码。登录信息只加密保存在本机，退出登录或删除就会清掉。'
	String savedAccountsNote({required Object count}) => '登录过的账号记在这里（最多 ${count} 个），切换不用重新扫码。登录信息只加密保存在本机，退出登录或删除就会清掉。';

	/// zh: 'UID {uid}'
	String accountUid({required Object uid}) => 'UID ${uid}';

	/// zh: '当前账号'
	String get accountCurrent => '当前账号';

	/// zh: '切换'
	String get accountSwitch => '切换';

	/// zh: '删除这个账号'
	String get accountForget => '删除这个账号';

	/// zh: '切换到“{name}”？正在看的直播间会用这个账号重新连接弹幕。'
	String accountSwitchConfirm({required Object name}) => '切换到“${name}”？正在看的直播间会用这个账号重新连接弹幕。';

	/// zh: '从本机删除“{name}”的登录信息？以后要用这个账号需要重新登录。'
	String accountForgetConfirm({required Object name}) => '从本机删除“${name}”的登录信息？以后要用这个账号需要重新登录。';

	/// zh: '添加账号'
	String get accountAdd => '添加账号';

	/// zh: '扫码登录另一个账号，现在的账号会留在这里'
	String get accountAddHint => '扫码登录另一个账号，现在的账号会留在这里';

	/// zh: '已记住 {count} 个，再添加会删掉最久没用的那个'
	String accountAddFull({required Object count}) => '已记住 ${count} 个，再添加会删掉最久没用的那个';

	/// zh: '已切换到“{name}”'
	String accountSwitched({required Object name}) => '已切换到“${name}”';

	/// zh: '已删除“{name}”'
	String accountForgot({required Object name}) => '已删除“${name}”';

	/// zh: '“{name}”已记住'
	String accountAdded({required Object name}) => '“${name}”已记住';
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

	/// zh: '画质'
	String get groupQuality => '画质';

	/// zh: '首选清晰度'
	String get preferResolution => '首选清晰度';

	/// zh: '进入直播间时首选的视频清晰度'
	String get preferResolutionDesc => '进入直播间时首选的视频清晰度';

	/// zh: '移动网络清晰度'
	String get mobileQuality => '移动网络清晰度';

	/// zh: '使用流量时的默认画质'
	String get mobileQualityDesc => '使用流量时的默认画质';

	/// zh: '优先 H.264 编码'
	String get preferH264 => '优先 H.264 编码';

	/// zh: '同一画质有多种编码时先选兼容性最好的 H.264；HEVC 仍可在直播间手动选择'
	String get preferH264Desc => '同一画质有多种编码时先选兼容性最好的 H.264；HEVC 仍可在直播间手动选择';

	/// zh: '画面比例'
	String get videoFit => '画面比例';

	/// zh: '画面和播放区域比例不同时如何显示（房间里的画面比例菜单会记住选择）'
	String get videoFitDesc => '画面和播放区域比例不同时如何显示（房间里的画面比例菜单会记住选择）';

	/// zh: '默认比例'
	String get fitDefault => '默认比例';

	/// zh: '居中裁剪'
	String get fitCrop => '居中裁剪';

	/// zh: '填充屏幕'
	String get fitFillScreen => '填充屏幕';

	/// zh: '适应高度'
	String get fitHeight => '适应高度';

	/// zh: '适应宽度'
	String get fitWidth => '适应宽度';

	/// zh: '等比缩小'
	String get fitScaleDown => '等比缩小';

	/// zh: '播放行为'
	String get groupPlayback => '播放行为';

	/// zh: '自动全屏'
	String get autoFullscreen => '自动全屏';

	/// zh: '进入直播播放页、画面开始播放后自动进入全屏'
	String get autoFullscreenDesc => '进入直播播放页、画面开始播放后自动进入全屏';

	/// zh: '弹幕屏蔽名单'
	String get blockList => '弹幕屏蔽名单';

	/// zh: '关键词、用户名单与正则屏蔽'
	String get blockListDesc => '关键词、用户名单与正则屏蔽';

	/// zh: '观众人数'
	String get groupAudience => '观众人数';

	/// zh: '人数显示口径'
	String get audienceMode => '人数显示口径';

	/// zh: '直播间把哪个数字当作观众规模：平台的实时在线人数，还是人气热度'
	String get audienceModeDesc => '直播间把哪个数字当作观众规模：平台的实时在线人数，还是人气热度';

	/// zh: '热度（人气）'
	String get audienceModeHeat => '热度（人气）';

	/// zh: '在线人数'
	String get audienceModeOnline => '在线人数';

	/// zh: '在线人数可信的平台'
	String get audiencePlatforms => '在线人数可信的平台';

	/// zh: '其余 {count} 个平台只有热度口径'
	String audienceHeatOnlyCount({required Object count}) => '其余 ${count} 个平台只有热度口径';

	/// zh: '竖屏直播适配'
	String get portraitLiveSettings => '竖屏直播适配';

	/// zh: '自动识别直播源方向，并统一普通页、全屏和小窗的显示策略'
	String get portraitLiveSettingsDesc => '自动识别直播源方向，并统一普通页、全屏和小窗的显示策略';

	/// zh: '识别与布局'
	String get portraitGroupDetect => '识别与布局';

	/// zh: '智能识别竖屏直播源'
	String get portraitDetect => '智能识别竖屏直播源';

	/// zh: '根据解码后的真实画面尺寸识别，切换线路和画质时自动跟随'
	String get portraitDetectDesc => '根据解码后的真实画面尺寸识别，切换线路和画质时自动跟随';

	/// zh: '普通页自适应视频高度'
	String get portraitAdaptiveHeight => '普通页自适应视频高度';

	/// zh: '竖屏源增大观看区域，同时保留足够的弹幕列表空间；关闭后面板固定在中间一档'
	String get portraitAdaptiveHeightDesc => '竖屏源增大观看区域，同时保留足够的弹幕列表空间；关闭后面板固定在中间一档';

	/// zh: '普通页布局模式'
	String get portraitLayoutMode => '普通页布局模式';

	/// zh: '仅影响竖屏直播源，不改变普通横屏直播'
	String get portraitLayoutModeDesc => '仅影响竖屏直播源，不改变普通横屏直播';

	/// zh: '均衡（推荐）'
	String get portraitLayoutBalanced => '均衡（推荐）';

	/// zh: '沉浸'
	String get portraitLayoutImmersive => '沉浸';

	/// zh: '兼容 16:9'
	String get portraitLayoutCompatibility => '兼容 16:9';

	/// zh: '全屏呈现'
	String get portraitGroupPresentation => '全屏呈现';

	/// zh: '进入全屏时的方向'
	String get portraitFullscreenPolicy => '进入全屏时的方向';

	/// zh: '大屏和分屏设备自动交给系统布局，手机可跟随直播源'
	String get portraitFullscreenPolicyDesc => '大屏和分屏设备自动交给系统布局，手机可跟随直播源';

	/// zh: '跟随直播源（推荐）'
	String get portraitFollowSource => '跟随直播源（推荐）';

	/// zh: '跟随系统'
	String get portraitFollowSystem => '跟随系统';

	/// zh: '始终横屏'
	String get portraitAlwaysLandscape => '始终横屏';

	/// zh: '竖屏全屏画面模式'
	String get portraitDisplayMode => '竖屏全屏画面模式';

	/// zh: '仅影响竖屏直播的竖屏全屏，切换后立即生效，不改变横屏直播和小窗比例'
	String get portraitDisplayModeDesc => '仅影响竖屏直播的竖屏全屏，切换后立即生效，不改变横屏直播和小窗比例';

	/// zh: '完整画面'
	String get portraitDisplayComplete => '完整画面';

	/// zh: '沉浸背景（推荐）'
	String get portraitDisplayAmbient => '沉浸背景（推荐）';

	/// zh: '平衡填充'
	String get portraitDisplayBalanced => '平衡填充';

	/// zh: '铺满裁剪'
	String get portraitDisplayCover => '铺满裁剪';

	/// zh: '竖屏弹幕布局'
	String get portraitDanmakuMode => '竖屏弹幕布局';

	/// zh: '独立限制竖屏源上的弹幕覆盖区域，不修改全局样式数值'
	String get portraitDanmakuModeDesc => '独立限制竖屏源上的弹幕覆盖区域，不修改全局样式数值';

	/// zh: '跟随全局'
	String get portraitDanmakuFollowGlobal => '跟随全局';

	/// zh: '顶部 25%'
	String get portraitDanmakuUpperQuarter => '顶部 25%';

	/// zh: '精简 50%'
	String get portraitDanmakuReduced => '精简 50%';

	/// zh: '竖屏源隐藏'
	String get portraitDanmakuHidden => '竖屏源隐藏';

	/// zh: '记住单个直播间方向'
	String get portraitRemember => '记住单个直播间方向';

	/// zh: '在播放器中手动指定方向后，下次进入同一直播间继续使用'
	String get portraitRememberDesc => '在播放器中手动指定方向后，下次进入同一直播间继续使用';

	/// zh: '诊断'
	String get portraitGroupDiagnostics => '诊断';

	/// zh: '显示识别状态'
	String get portraitDiagnostics => '显示识别状态';

	/// zh: '在画面上显示原始尺寸、比例和当前生效的规则'
	String get portraitDiagnosticsDesc => '在画面上显示原始尺寸、比例和当前生效的规则';

	/// zh: '恢复竖屏适配默认设置'
	String get portraitReset => '恢复竖屏适配默认设置';

	/// zh: '包括记住的直播间方向覆盖'
	String get portraitResetDesc => '包括记住的直播间方向覆盖';

	/// zh: '把竖屏直播适配的全部设置恢复为默认值？'
	String get portraitResetConfirm => '把竖屏直播适配的全部设置恢复为默认值？';

	/// zh: '小窗始终置顶'
	String get pipOnTop => '小窗始终置顶';

	/// zh: '关闭后切换到其他应用时，小窗会按普通窗口层级被遮挡'
	String get pipOnTopDesc => '关闭后切换到其他应用时，小窗会按普通窗口层级被遮挡';

	/// zh: '记住小窗位置'
	String get miniRemember => '记住小窗位置';

	/// zh: '小窗下次打开回到上次放置的位置；关闭则每次回到右下角'
	String get miniRememberDesc => '小窗下次打开回到上次放置的位置；关闭则每次回到右下角';

	/// zh: '关闭小窗即暂停'
	String get pauseOnTileClose => '关闭小窗即暂停';

	/// zh: '窗口正作为小窗/画中画时点关闭：先恢复窗口并暂停，再执行关闭动作，不会留下藏在后台继续播放的声音'
	String get pauseOnTileCloseDesc => '窗口正作为小窗/画中画时点关闭：先恢复窗口并暂停，再执行关闭动作，不会留下藏在后台继续播放的声音';

	/// zh: '启动动画'
	String get splashAnimation => '启动动画';

	/// zh: '启动时显示 Logo'
	String get splashAnimationDesc => '启动时显示 Logo';

	/// zh: '使用 GitHub 官方更新源'
	String get githubUpdates => '使用 GitHub 官方更新源';

	/// zh: '检查更新和下载安装包只连 GitHub 官方地址，适合配了代理的用户；关闭时用镜像'
	String get githubUpdatesDesc => '检查更新和下载安装包只连 GitHub 官方地址，适合配了代理的用户；关闭时用镜像';

	/// zh: '识别剪贴板中的分享口令'
	String get clipboardRooms => '识别剪贴板中的分享口令';

	/// zh: '打开或回到应用时，剪贴板里有直播间的分享口令就询问是否进入；同一口令只问一次'
	String get clipboardRoomsDesc => '打开或回到应用时，剪贴板里有直播间的分享口令就询问是否进入；同一口令只问一次';

	/// zh: '开机启动'
	String get startup => '开机启动';

	/// zh: '登录系统后自动启动'
	String get startupDesc => '登录系统后自动启动';

	/// zh: '系统拒绝了开机启动的登记'
	String get startupFailed => '系统拒绝了开机启动的登记';

	/// zh: '关闭窗口时'
	String get closeWindow => '关闭窗口时';

	/// zh: '点窗口右上角关闭按钮时怎么做'
	String get closeWindowDesc => '点窗口右上角关闭按钮时怎么做';

	/// zh: '每次询问'
	String get closeAsk => '每次询问';

	/// zh: '隐藏到托盘'
	String get closeHide => '隐藏到托盘';

	/// zh: '最小化'
	String get closeMinimise => '最小化';

	/// zh: '退出应用'
	String get closeQuit => '退出应用';

	/// zh: '缓存'
	String get sectionCache => '缓存';

	/// zh: '当前缓存大小'
	String get currentCacheSize => '当前缓存大小';

	/// zh: '{count} MB'
	String cacheSizeValue({required Object count}) => '${count} MB';

	/// zh: '正在统计…'
	String get cacheMeasuring => '正在统计…';

	/// zh: '清除图片缓存'
	String get clearCache => '清除图片缓存';

	/// zh: '清空后立即重新拉取所有封面'
	String get clearCacheDesc => '清空后立即重新拉取所有封面';

	/// zh: '已释放 {count} MB'
	String cacheCleared({required Object count}) => '已释放 ${count} MB';

	/// zh: '自动清理图片缓存'
	String get cacheAutoClear => '自动清理图片缓存';

	/// zh: '回到前台时若缓存超过上限就清空'
	String get cacheAutoClearDesc => '回到前台时若缓存超过上限就清空';

	/// zh: '缓存上限'
	String get cacheLimit => '缓存上限';

	/// zh: '立即刷新封面'
	String get refreshCoversNow => '立即刷新封面';

	/// zh: '清空图片缓存，所有封面在下次进入时重新拉取'
	String get refreshCoversNowDesc => '清空图片缓存，所有封面在下次进入时重新拉取';

	/// zh: '{count} MB'
	String mbValue({required Object count}) => '${count} MB';

	/// zh: '封面'
	String get groupCovers => '封面';

	/// zh: '自动刷新封面'
	String get autoRefreshThumbnails => '自动刷新封面';

	/// zh: '定时让房间封面重新拉取，保持画面是最新的'
	String get autoRefreshThumbnailsDesc => '定时让房间封面重新拉取，保持画面是最新的';

	/// zh: '封面刷新间隔'
	String get thumbnailRefreshInterval => '封面刷新间隔';

	/// zh: '历史'
	String get groupHistory => '历史';

	/// zh: '历史记录条数'
	String get historyLimit => '历史记录条数';

	/// zh: '最多保留多少条观看历史；0 为不限制'
	String get historyLimitDesc => '最多保留多少条观看历史；0 为不限制';

	/// zh: '不限制'
	String get noLimit => '不限制';

	/// zh: '播放器代理'
	String get playerProxyGroup => '播放器代理';

	/// zh: '启用播放器代理'
	String get playerProxyEnable => '启用播放器代理';

	/// zh: '直播流由播放器经此代理拉取，与应用自身的网络请求分开'
	String get playerProxyEnableDesc => '直播流由播放器经此代理拉取，与应用自身的网络请求分开';

	/// zh: '对下一条直播流生效；正在播放的一路保持原样'
	String get playerProxyHint => '对下一条直播流生效；正在播放的一路保持原样';

	/// zh: '保存旧的缩略图'
	String get thumbnailKeepOldFiles => '保存旧的缩略图';

	/// zh: '刷新封面后保留旧图，由缓存策略自行清理；关闭时超过两个周期的旧图会被清除'
	String get thumbnailKeepOldFilesDesc => '刷新封面后保留旧图，由缓存策略自行清理；关闭时超过两个周期的旧图会被清除';
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

	/// zh: '录制默认'
	String get groupDefaults => '录制默认';

	/// zh: '默认录制清晰度'
	String get defaultQuality => '默认录制清晰度';

	/// zh: '房间给出多个清晰度时，录制选其中标着这一档的地址；没有标注就录最好的一路。'
	String get defaultQualityDesc => '房间给出多个清晰度时，录制选其中标着这一档的地址；没有标注就录最好的一路。';

	/// zh: '用拼音命名文件夹'
	String get usePinyinFolder => '用拼音命名文件夹';

	/// zh: '打开后主播目录名转成拼音（zhubo8891）；关闭则直接用房间号，最稳妥。'
	String get usePinyinFolderDesc => '打开后主播目录名转成拼音（zhubo8891）；关闭则直接用房间号，最稳妥。';

	/// zh: '保存弹幕'
	String get recordDanmaku => '保存弹幕';

	/// zh: '录制时在视频旁边保存一份弹幕文件；弹幕连不上不影响录制本身。'
	String get recordDanmakuDesc => '录制时在视频旁边保存一份弹幕文件；弹幕连不上不影响录制本身。';

	/// zh: '录制弹幕时包含礼物'
	String get recordDanmakuGifts => '录制弹幕时包含礼物';

	/// zh: '弹幕文件里同时写入礼物与 Super Chat。'
	String get recordDanmakuGiftsDesc => '弹幕文件里同时写入礼物与 Super Chat。';

	/// zh: '录制文件'
	String get groupFiles => '录制文件';

	/// zh: '录制大小限制'
	String get recordSizeLimit => '录制大小限制';

	/// zh: '目录超过上限时自动删除最旧的录制（一小时内的不算旧）。'
	String get recordSizeLimitDesc => '目录超过上限时自动删除最旧的录制（一小时内的不算旧）。';

	/// zh: '大小上限'
	String get recordSizeCap => '大小上限';

	/// zh: '已用空间'
	String get recordUsedSpace => '已用空间';

	/// zh: '点按重新统计录制目录占用的空间。'
	String get recordUsedSpaceDesc => '点按重新统计录制目录占用的空间。';

	/// zh: '清空全部缓存'
	String get clearAllCache => '清空全部缓存';

	/// zh: '删除录制目录里的全部视频文件；正在录制的一小时内的不删。'
	String get clearAllCacheDesc => '删除录制目录里的全部视频文件；正在录制的一小时内的不删。';

	/// zh: '已释放 {mb} MB'
	String clearFreed({required Object mb}) => '已释放 ${mb} MB';

	/// zh: '{count} MB'
	String mbValue({required Object count}) => '${count} MB';

	/// zh: '性能与画质'
	String get groupPerformance => '性能与画质';

	/// zh: '只录第一条流'
	String get preferBestStream => '只录第一条流';

	/// zh: '容器里有多条视频/音频轨时只录第一条，避免产出多音轨文件。'
	String get preferBestStreamDesc => '容器里有多条视频/音频轨时只录第一条，避免产出多音轨文件。';

	/// zh: '读写超时'
	String get rwTimeout => '读写超时';

	/// zh: '输入流超过这个时间没有响应就让读取失败，交给重连处理。'
	String get rwTimeoutDesc => '输入流超过这个时间没有响应就让读取失败，交给重连处理。';

	/// zh: '输入队列大小'
	String get queueSize => '输入队列大小';

	/// zh: '录制看重完整不看重延迟，队列比播放器大得多。'
	String get queueSizeDesc => '录制看重完整不看重延迟，队列比播放器大得多。';

	/// zh: '分段越短崩溃丢的越少，文件与开销越多。'
	String get segmentLengthDesc => '分段越短崩溃丢的越少，文件与开销越多。';

	/// zh: '最大同时录制任务数'
	String get maxRecordTasks => '最大同时录制任务数';

	/// zh: '可以同时录制的房间数；一个房间一路 FFmpeg。'
	String get maxRecordTasksDesc => '可以同时录制的房间数；一个房间一路 FFmpeg。';

	/// zh: '自动重连'
	String get groupReconnect => '自动重连';

	/// zh: '自动重连'
	String get autoReconnectSwitch => '自动重连';

	/// zh: '录制被中断时自动重试；关闭后断流即结束这一场。'
	String get autoReconnectDesc => '录制被中断时自动重试；关闭后断流即结束这一场。';

	/// zh: '最大重试次数'
	String get maxRetryCount => '最大重试次数';

	/// zh: '重试间隔'
	String get retryDelay => '重试间隔';

	/// zh: '{count: int} 次'
	String timesValue({required int count}) => '${count} 次';

	/// zh: '{count: int} 秒'
	String secondsValue({required int count}) => '${count} 秒';

	/// zh: '开播检测'
	String get groupLiveCheck => '开播检测';

	/// zh: '开启开播检测'
	String get enablePolling => '开启开播检测';

	/// zh: '定时检查还没开播的房间，主播一开播就开始录制。'
	String get enablePollingDesc => '定时检查还没开播的房间，主播一开播就开始录制。';

	/// zh: '检测间隔'
	String get checkInterval => '检测间隔';

	/// zh: '递增检测间隔'
	String get enableBackoff => '递增检测间隔';

	/// zh: '房间一直没开播时逐次翻倍检测间隔，减少接口压力。'
	String get enableBackoffDesc => '房间一直没开播时逐次翻倍检测间隔，减少接口压力。';

	/// zh: '检测间隔上限'
	String get maxCheckInterval => '检测间隔上限';

	/// zh: '应用启动时恢复录制'
	String get autoStartBoot => '应用启动时恢复录制';

	/// zh: '启动后自动恢复等待开播与被中断的录制任务。'
	String get autoStartBootDesc => '启动后自动恢复等待开播与被中断的录制任务。';

	/// zh: '减少'
	String get decrease => '减少';

	/// zh: '增加'
	String get increase => '增加';
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

	/// zh: '自定义字体'
	String get custom => '自定义字体';

	/// zh: '从本机选择 ttf、otf 或 ttc 字体文件'
	String get customDesc => '从本机选择 ttf、otf 或 ttc 字体文件';

	/// zh: '导入字体文件'
	String get import => '导入字体文件';

	/// zh: '这个文件没能导入'
	String get importFailed => '这个文件没能导入';
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

	/// zh: '云端和其他设备'
	String get devicesGroup => '云端和其他设备';

	/// zh: '本地备份'
	String get localGroup => '本地备份';

	/// zh: '保存应用数据区的整份副本（设置、关注、历史等）'
	String get createSubtitle => '保存应用数据区的整份副本（设置、关注、历史等）';

	/// zh: '从备份文件恢复，恢复后应用会重启'
	String get restoreFileSubtitle => '从备份文件恢复，恢复后应用会重启';

	/// zh: '目录中的备份'
	String get filesTitle => '目录中的备份';

	/// zh: '目录中的备份 · {count}'
	String filesCount({required Object count}) => '目录中的备份 · ${count}';

	/// zh: '还没有备份'
	String get filesEmpty => '还没有备份';

	/// zh: '在这里创建的备份会列出来；也可以把备份文件放进这个目录'
	String get filesHint => '在这里创建的备份会列出来；也可以把备份文件放进这个目录';

	/// zh: '无法读取备份目录'
	String get filesError => '无法读取备份目录';

	/// zh: '重试'
	String get retry => '重试';

	/// zh: '正在读取…'
	String get loading => '正在读取…';

	/// zh: '完整备份'
	String get kindFull => '完整备份';

	/// zh: '备份目录'
	String get directoryGroup => '备份目录';

	/// zh: '备份目录'
	String get directory => '备份目录';

	/// zh: '备份目录（默认）'
	String get directoryDefaultLabel => '备份目录（默认）';

	/// zh: '应用默认目录'
	String get directoryDefault => '应用默认目录';

	/// zh: '选择备份目录'
	String get chooseDirectory => '选择备份目录';

	/// zh: '改回默认目录'
	String get resetDirectory => '改回默认目录';

	/// zh: '打开备份目录'
	String get openDirectory => '打开备份目录';

	/// zh: '无法写入这个目录，请换一个目录'
	String get directoryUnwritable => '无法写入这个目录，请换一个目录';

	/// zh: '备份目录未更改，请重试'
	String get directoryUpdateFailed => '备份目录未更改，请重试';

	/// zh: '确定要删除备份文件“{name}”吗？'
	String deleteConfirm({required Object name}) => '确定要删除备份文件“${name}”吗？';

	/// zh: '已备份到 {name}'
	String created({required Object name}) => '已备份到 ${name}';

	/// zh: '无法读取备份文件'
	String get readFailed => '无法读取备份文件';

	/// zh: '已恢复 {name}'
	String restored({required Object name}) => '已恢复 ${name}';

	/// zh: '更多操作'
	String get moreActions => '更多操作';

	/// zh: '点一下恢复；右键或 ⋮ 有更多操作'
	String get fileTooltip => '点一下恢复；右键或 ⋮ 有更多操作';

	/// zh: '恢复预览'
	String get previewTitle => '恢复预览';

	/// zh: '关注的直播间：{current} → {incoming}'
	String previewRooms({required Object current, required Object incoming}) => '关注的直播间：${current} → ${incoming}';

	/// zh: '关注分组：{current} → {incoming}'
	String previewGroups({required Object current, required Object incoming}) => '关注分组：${current} → ${incoming}';

	/// zh: '其他数据保持不变。'
	String get previewNote => '其他数据保持不变。';

	/// zh: '立即恢复'
	String get restoreNow => '立即恢复';

	/// zh: '仅含关注的房间和分组，不影响其他设置'
	String get followsScopeHint => '仅含关注的房间和分组，不影响其他设置';

	/// zh: '仅关注列表'
	String get kindFollows => '仅关注列表';

	/// zh: '文件删除失败'
	String get deleteFailed => '文件删除失败';
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

	/// zh: '网页搜索'
	String get webSearch => '网页搜索';

	/// zh: '网页搜索当前平台'
	String get webSearchTooltip => '网页搜索当前平台';

	/// zh: '继续网页搜索'
	String get continueWeb => '继续网页搜索';

	/// zh: '请先选择一个平台'
	String get selectPlatformFirst => '请先选择一个平台';

	/// zh: '请输入关键字'
	String get needKeyword => '请输入关键字';

	/// zh: '{site} 暂无网页搜索入口。'
	String webUnavailableFor({required Object site}) => '${site} 暂无网页搜索入口。';

	/// zh: '网页搜索在系统浏览器中打开。找到想看的直播间后复制它的链接，回到搜索框粘贴即可直接进入。'
	String get webExternalTip => '网页搜索在系统浏览器中打开。找到想看的直播间后复制它的链接，回到搜索框粘贴即可直接进入。';

	/// zh: '使用系统浏览器打开'
	String get openInSystemBrowser => '使用系统浏览器打开';

	/// zh: '系统浏览器未打开，请检查默认浏览器设置'
	String get externalBrowserNotOpened => '系统浏览器未打开，请检查默认浏览器设置';

	/// zh: '这是一个直播间'
	String get webSearchRoomBanner => '这是一个直播间';

	/// zh: '房间号 {roomId: String}'
	String roomIdLabel({required String roomId}) => '房间号 ${roomId}';

	/// zh: '进入'
	String get roomEnter => '进入';

	/// zh: '不再提示这个直播间'
	String get webSearchRoomDismiss => '不再提示这个直播间';

	/// zh: '网页搜索地址无效，请返回搜索页后重试。'
	String get webSearchInvalidAddress => '网页搜索地址无效，请返回搜索页后重试。';

	/// zh: '网页加载失败，请检查网络或代理后重试。'
	String get webSearchLoadFailed => '网页加载失败，请检查网络或代理后重试。';

	/// zh: '网页搜索暂不可用'
	String get webSearchUnavailableTitle => '网页搜索暂不可用';
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

	/// zh: '画中画'
	String get pip => '画中画';

	/// zh: '退出画中画'
	String get exitPip => '退出画中画';

	/// zh: '小窗播放'
	String get miniWindow => '小窗播放';

	/// zh: '退出小窗'
	String get exitMiniWindow => '退出小窗';

	/// zh: '弹幕'
	String get messageActions => '弹幕';

	/// zh: '复制'
	String get copyMessage => '复制';

	/// zh: '已复制到剪贴板'
	String get copiedToClipboard => '已复制到剪贴板';

	/// zh: '屏蔽此用户'
	String get blockViewer => '屏蔽此用户';

	/// zh: '{name} 的弹幕都不再显示'
	String blockViewerDesc({required Object name}) => '${name} 的弹幕都不再显示';

	/// zh: '已屏蔽 {name}'
	String userBlocked({required Object name}) => '已屏蔽 ${name}';

	/// zh: '屏蔽关键词…'
	String get blockWord => '屏蔽关键词…';

	/// zh: '输入一个词，含这个词的弹幕都不再显示'
	String get blockWordDesc => '输入一个词，含这个词的弹幕都不再显示';

	/// zh: '关键词已加入弹幕屏蔽列表'
	String get keywordBlocked => '关键词已加入弹幕屏蔽列表';

	/// zh: '等级 {level}'
	String userLevel({required Object level}) => '等级 ${level}';

	/// zh: '屏蔽弹幕关键词'
	String get blockKeywordTitle => '屏蔽弹幕关键词';

	/// zh: '屏蔽'
	String get block => '屏蔽';

	/// zh: '已进入竖屏全屏 · 上滑恢复弹幕栏'
	String get portraitFullscreenRestoreHint => '已进入竖屏全屏 · 上滑恢复弹幕栏';
}

// Path: areas
class Translations$areas$zh {
	Translations$areas$zh.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh: '关注的分区'
	String get followedAreas => '关注的分区';

	/// zh: '暂无分区'
	String get empty => '暂无分区';

	/// zh: '还没有关注的分区'
	String get followEmpty => '还没有关注的分区';

	/// zh: '点进一个分区，再用右上角的按钮关注它。'
	String get followEmptyHint => '点进一个分区，再用右上角的按钮关注它。';

	/// zh: '已关注「{name: String}」'
	String followDone({required String name}) => '已关注「${name}」';

	/// zh: '已取消关注「{name: String}」'
	String unfollowDone({required String name}) => '已取消关注「${name}」';
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

	/// zh: '通过局域网在设备之间同步配置'
	String get tileSubtitle => '通过局域网在设备之间同步配置';

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

	/// zh: '输入对方设备的地址，或粘贴对方二维码里的同步链接（含配对码，不用再输入）'
	String get manualHint => '输入对方设备的地址，或粘贴对方二维码里的同步链接（含配对码，不用再输入）';

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

	/// zh: '配对码'
	String get pairingCode => '配对码';

	/// zh: '输入“{name: String}”上显示的 6 位配对码'
	String pairingCodeFor({required String name}) => '输入“${name}”上显示的 6 位配对码';

	/// zh: '配对码应为 6 位数字'
	String get pairingCodeInvalid => '配对码应为 6 位数字';

	/// zh: '全选'
	String get partsAll => '全选';

	/// zh: '对方是 3.x 或较早的版本（或者暂时没有回应），只能发送全部内容。'
	String get partsLegacy => '对方是 3.x 或较早的版本（或者暂时没有回应），只能发送全部内容。';

	/// zh: '勾选要发送到“{name: String}”的内容。对方确认后，勾选的内容会替换它原有的，没勾的保持不变。'
	String partsSendNamed({required String name}) => '勾选要发送到“${name}”的内容。对方确认后，勾选的内容会替换它原有的，没勾的保持不变。';

	/// zh: '确定要将当前设备的全部配置发送到“{name: String}”吗？对方确认后会覆盖它的配置。'
	String confirmSendNamed({required String name}) => '确定要将当前设备的全部配置发送到“${name}”吗？对方确认后会覆盖它的配置。';

	/// zh: '接收后会这样变化：'
	String get previewTitle => '接收后会这样变化：';

	/// zh: '设置：对方 {count: int} 项，其中 {changed: int} 项与本机不同'
	String previewSettings({required int count, required int changed}) => '设置：对方 ${count} 项，其中 ${changed} 项与本机不同';

	/// zh: '账号：对方没有开“同步账号 Cookie”，本机账号不变'
	String get previewNoAccounts => '账号：对方没有开“同步账号 Cookie”，本机账号不变';

	/// zh: '账号：对方没有登录信息；本机的登录按原样保留'
	String get previewAccountsEmpty => '账号：对方没有登录信息；本机的登录按原样保留';

	/// zh: '接收会合入勾选的内容，没勾的保持不变；设置项以对方为准，无法撤销，需要时先在“备份与恢复”创建一份备份。'
	String get previewWarning => '接收会合入勾选的内容，没勾的保持不变；设置项以对方为准，无法撤销，需要时先在“备份与恢复”创建一份备份。';

	/// zh: '{part: String}（{count: int}）'
	String partCount({required String part, required int count}) => '${part}（${count}）';

	/// zh: '设置'
	String get partSettings => '设置';

	/// zh: '关注列表'
	String get partFollows => '关注列表';

	/// zh: '观看历史'
	String get partHistory => '观看历史';

	/// zh: '关注分组'
	String get partGroups => '关注分组';

	/// zh: '屏蔽关键词'
	String get partKeywords => '屏蔽关键词';

	/// zh: '屏蔽用户'
	String get partUsers => '屏蔽用户';

	/// zh: 'WebDAV 服务器'
	String get partWebdav => 'WebDAV 服务器';

	/// zh: '账号 Cookie'
	String get partAccounts => '账号 Cookie';

	/// zh: '同步账号 Cookie'
	String get includeAccounts => '同步账号 Cookie';

	/// zh: '开启后会发送或提供各平台登录 Cookie 与 WebDAV 密码，只在信任的设备之间开启'
	String get includeAccountsHint => '开启后会发送或提供各平台登录 Cookie 与 WebDAV 密码，只在信任的设备之间开启';

	/// zh: '接收'
	String get receiveAction => '接收';

	/// zh: '发送'
	String get sendAction => '发送';

	/// zh: '不是纯粹直播的同步二维码'
	String get invalidQr => '不是纯粹直播的同步二维码';
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

	/// zh: '窗口边框诊断'
	String get frameDiagnosis => '窗口边框诊断';

	/// zh: '边框接管'
	String get frameTakeover => '边框接管';

	/// zh: '已开启 — 标题栏已由窗口自身移除，四边缩放由窗口的命中测试应答'
	String get frameTakeoverOn => '已开启 — 标题栏已由窗口自身移除，四边缩放由窗口的命中测试应答';

	/// zh: '未开启 — 标题栏与窗口尺寸都由系统负责'
	String get frameTakeoverOff => '未开启 — 标题栏与窗口尺寸都由系统负责';

	/// zh: '系统描边'
	String get frameEdge => '系统描边';

	/// zh: '由 Windows 绘制'
	String get frameEdgeNative => '由 Windows 绘制';

	/// zh: '当前 Windows 版本不绘制描边，接管后的边框四边都没有线'
	String get frameEdgeNone => '当前 Windows 版本不绘制描边，接管后的边框四边都没有线';

	/// zh: 'Windows 构建号'
	String get frameBuild => 'Windows 构建号';

	/// zh: '运行缩放扫描'
	String get frameSweep => '运行缩放扫描';

	/// zh: '扫描中…'
	String get frameSweepRunning => '扫描中…';

	/// zh: '会连续改变本窗口大小两轮然后还原。两行数字分别对应视图预同步关闭与打开，第二行的过期帧更少才说明边框跟上了拖动。'
	String get frameSweepHint => '会连续改变本窗口大小两轮然后还原。两行数字分别对应视图预同步关闭与打开，第二行的过期帧更少才说明边框跟上了拖动。';

	/// zh: '缩放扫描需要开启边框接管，且运行在 Windows。'
	String get frameSweepUnavailable => '缩放扫描需要开启边框接管，且运行在 Windows。';
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

	/// zh: 'WebDAV 服务器'
	String get servers => 'WebDAV 服务器';

	/// zh: '还没有服务器'
	String get noServer => '还没有服务器';

	/// zh: '暂无配置，请先创建 WebDAV 配置'
	String get noConfigCreateFirst => '暂无配置，请先创建 WebDAV 配置';

	/// zh: '添加坚果云、Nextcloud 等 WebDAV 网盘后，可以把备份上传到网盘，在其他设备上恢复。'
	String get intro => '添加坚果云、Nextcloud 等 WebDAV 网盘后，可以把备份上传到网盘，在其他设备上恢复。';

	/// zh: '创建新配置'
	String get createNew => '创建新配置';

	/// zh: '打开配置列表'
	String get openList => '打开配置列表';

	/// zh: '刷新'
	String get refresh => '刷新';

	/// zh: '更多操作'
	String get moreActions => '更多操作';

	/// zh: '仅上传关注列表'
	String get uploadFavorites => '仅上传关注列表';

	/// zh: '上传完整备份'
	String get uploadFull => '上传完整备份';

	/// zh: '使用帮助教程'
	String get helpTutorial => '使用帮助教程';

	/// zh: '配置名称已存在'
	String get nameExists => '配置名称已存在';

	/// zh: 'WebDAV 配置选择未保存，请重试'
	String get selectFailed => 'WebDAV 配置选择未保存，请重试';

	/// zh: 'WebDAV 配置未删除，请重试'
	String get configDeleteFailed => 'WebDAV 配置未删除，请重试';

	/// zh: '确定要删除配置 “{name}” 吗？'
	String confirmDeleteConfig({required Object name}) => '确定要删除配置 “${name}” 吗？';

	/// zh: '确定要从 WebDAV 删除“{name}”吗？'
	String confirmDeleteItem({required Object name}) => '确定要从 WebDAV 删除“${name}”吗？';

	/// zh: '文件删除成功'
	String get deleteSuccess => '文件删除成功';

	/// zh: '文件删除失败'
	String get deleteFailed => '文件删除失败';

	/// zh: '文件上传失败'
	String get uploadFailed => '文件上传失败';

	/// zh: '文件下载失败'
	String get downloadFailed => '文件下载失败';

	/// zh: '恢复全部设置'
	String get restoreAllSettings => '恢复全部设置';

	/// zh: '仅恢复关注列表'
	String get restoreFavorites => '仅恢复关注列表';

	/// zh: '这个目录是空的'
	String get folderEmpty => '这个目录是空的';

	/// zh: '配置名称'
	String get serverName => '配置名称';

	/// zh: '编辑配置'
	String get editServer => '编辑配置';

	/// zh: '删除配置'
	String get deleteServer => '删除配置';

	/// zh: '使用中'
	String get activeMark => '使用中';

	/// zh: '配置已保存'
	String get saved => '配置已保存';

	/// zh: '已从 {name} 恢复'
	String restored({required Object name}) => '已从 ${name} 恢复';

	/// zh: '已上传 {name}'
	String uploaded({required Object name}) => '已上传 ${name}';

	/// zh: '这台设备的安全存储不可用，密码只在本页有效'
	String get secretsNote => '这台设备的安全存储不可用，密码只在本页有效';
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

// Path: cast
class Translations$cast$zh {
	Translations$cast$zh.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh: '投屏'
	String get title => '投屏';

	/// zh: '选择同一局域网内可接收投屏的设备'
	String get hint => '选择同一局域网内可接收投屏的设备';

	/// zh: '正在搜索局域网内的投屏设备…'
	String get searching => '正在搜索局域网内的投屏设备…';

	/// zh: '暂未发现投屏设备'
	String get noDevices => '暂未发现投屏设备';

	/// zh: '正在投屏到 {name: String}'
	String castingTo({required String name}) => '正在投屏到 ${name}';

	/// zh: '停止投屏'
	String get stop => '停止投屏';

	/// zh: '投屏失败——设备可能取不到这个地址'
	String get failed => '投屏失败——设备可能取不到这个地址';

	/// zh: '播放中'
	String get statePlaying => '播放中';

	/// zh: '已暂停'
	String get statePaused => '已暂停';

	/// zh: '缓冲中'
	String get stateBuffering => '缓冲中';

	/// zh: '已停止'
	String get stateStopped => '已停止';

	/// zh: '设备无应答'
	String get stateUnreachable => '设备无应答';
}

// Path: danmaku
class Translations$danmaku$zh {
	Translations$danmaku$zh.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh: '改动立即生效'
	String get liveHint => '改动立即生效';

	/// zh: '观看模板'
	String get templateGroup => '观看模板';

	/// zh: '顶部 20% · 均衡'
	String get templateBest => '顶部 20% · 均衡';

	/// zh: '顶部 35% · 舒适'
	String get templateComfort => '顶部 35% · 舒适';

	/// zh: '顶部 55% · 高密度'
	String get templateDense => '顶部 55% · 高密度';

	/// zh: '重置'
	String get templateReset => '重置';

	/// zh: '弹幕只占画面顶部约 20%，速度与密度适中，避免遮挡主体内容。'
	String get bestDesc => '弹幕只占画面顶部约 20%，速度与密度适中，避免遮挡主体内容。';

	/// zh: '弹幕占画面顶部约 35%，字稍大、速度稍慢，看着更轻松。'
	String get comfortDesc => '弹幕占画面顶部约 35%，字稍大、速度稍慢，看着更轻松。';

	/// zh: '弹幕占画面顶部约 55%，字稍小、速度更快，弹幕多时也看得全。'
	String get denseDesc => '弹幕占画面顶部约 55%，字稍小、速度更快，弹幕多时也看得全。';

	/// zh: '恢复默认：弹幕铺满整个画面，不透明，速度和字号回到默认值。'
	String get resetDesc => '恢复默认：弹幕铺满整个画面，不透明，速度和字号回到默认值。';

	/// zh: '自定义：当前设置不属于上面任何一个模板，可以存为我的模板以后再用。'
	String get customDesc => '自定义：当前设置不属于上面任何一个模板，可以存为我的模板以后再用。';

	/// zh: '把当前设置存为我的模板'
	String get saveMine => '把当前设置存为我的模板';

	/// zh: '用我的模板'
	String get useMine => '用我的模板';

	/// zh: '弹幕模板已应用'
	String get templateApplied => '弹幕模板已应用';

	/// zh: '当前弹幕样式已保存'
	String get templateSaved => '当前弹幕样式已保存';

	/// zh: '还没有保存弹幕模板'
	String get templateEmpty => '还没有保存弹幕模板';

	/// zh: '已保存的弹幕模板损坏或数值超出范围'
	String get templateInvalid => '已保存的弹幕模板损坏或数值超出范围';

	/// zh: '显示范围'
	String get rangeGroup => '显示范围';

	/// zh: '画面顶部占用高度'
	String get area => '画面顶部占用高度';

	/// zh: '顶部留白（像素）'
	String get marginTop => '顶部留白（像素）';

	/// zh: '区域底部留白（像素）'
	String get marginBottom => '区域底部留白（像素）';

	/// zh: '暂停时的弹幕'
	String get pausedBehavior => '暂停时的弹幕';

	/// zh: '视频暂停后，弹幕跟着停住还是照常飘过'
	String get pausedBehaviorDesc => '视频暂停后，弹幕跟着停住还是照常飘过';

	/// zh: '随视频暂停'
	String get pausedPause => '随视频暂停';

	/// zh: '继续飘过'
	String get pausedFly => '继续飘过';

	/// zh: '样式'
	String get styleGroup => '样式';

	/// zh: '透明度'
	String get opacity => '透明度';

	/// zh: '滚动速度（像素/秒）'
	String get speed => '滚动速度（像素/秒）';

	/// zh: '字体大小'
	String get fontSize => '字体大小';

	/// zh: '字体粗细'
	String get fontWeight => '字体粗细';

	/// zh: '极细'
	String get weightThin => '极细';

	/// zh: '很细'
	String get weightExtraLight => '很细';

	/// zh: '偏细'
	String get weightLight => '偏细';

	/// zh: '正常'
	String get weightNormal => '正常';

	/// zh: '稍粗'
	String get weightMedium => '稍粗';

	/// zh: '中粗'
	String get weightSemiBold => '中粗';

	/// zh: '粗体'
	String get weightBold => '粗体';

	/// zh: '很粗'
	String get weightExtraBold => '很粗';

	/// zh: '特粗'
	String get weightBlack => '特粗';

	/// zh: '弹幕描边'
	String get stroke => '弹幕描边';

	/// zh: '描边宽度'
	String get strokeWidth => '描边宽度';

	/// zh: '纯文字模式（隐藏表情）'
	String get noEmoji => '纯文字模式（隐藏表情）';

	/// zh: '流畅度'
	String get smoothGroup => '流畅度';

	/// zh: '重复弹幕'
	String get repeatGroup => '重复弹幕';

	/// zh: '合并短时间内的相同弹幕'
	String get collapse => '合并短时间内的相同弹幕';

	/// zh: '不同用户发送相同内容时只保留第一条；本地弹幕和系统消息不受影响。'
	String get collapseDesc => '不同用户发送相同内容时只保留第一条；本地弹幕和系统消息不受影响。';

	/// zh: '相同内容合并时间（秒）'
	String get collapseWindow => '相同内容合并时间（秒）';

	/// zh: '弹幕帧率'
	String get fps => '弹幕帧率';

	/// zh: '{count: int} FPS'
	String fpsValue({required int count}) => '${count} FPS';

	/// zh: '同屏最大弹幕条数'
	String get maxVisible => '同屏最大弹幕条数';

	/// zh: '{count: int} 条'
	String maxVisibleValue({required int count}) => '${count} 条';

	/// zh: '画面弹幕交互'
	String get interactionGroup => '画面弹幕交互';

	/// zh: '按住飞行弹幕让它停住'
	String get holdOnPress => '按住飞行弹幕让它停住';

	/// zh: '手指按住画面上的一条弹幕时只停住这一条，其他照飞，松手继续'
	String get holdOnPressDesc => '手指按住画面上的一条弹幕时只停住这一条，其他照飞，松手继续';

	/// zh: '弹幕列表'
	String get listGroup => '弹幕列表';

	/// zh: '弹幕列表样式'
	String get listStyle => '弹幕列表样式';

	/// zh: '紧凑'
	String get listCompact => '紧凑';

	/// zh: '卡片'
	String get listCard => '卡片';

	/// zh: '列表文字大小'
	String get listFontSize => '列表文字大小';

	/// zh: '列表行距'
	String get listLineSpacing => '列表行距';

	/// zh: '显示发送者名称'
	String get showSender => '显示发送者名称';

	/// zh: '飞行弹幕显示礼物'
	String get showGifts => '飞行弹幕显示礼物';

	/// zh: '礼物消息也飞过画面'
	String get showGiftsDesc => '礼物消息也飞过画面';

	/// zh: '点击画面弹幕查看操作'
	String get tapAction => '点击画面弹幕查看操作';

	/// zh: '长按画面弹幕打开屏蔽操作'
	String get longPressAction => '长按画面弹幕打开屏蔽操作';

	/// zh: '弹幕帧率跟随界面刷新率'
	String get autoFps => '弹幕帧率跟随界面刷新率';

	/// zh: '跟随省电、均衡或最高档位；关闭后可以手动设帧率。'
	String get autoFpsDesc => '跟随省电、均衡或最高档位；关闭后可以手动设帧率。';

	/// zh: '刷新率档位'
	String get fpsMode => '刷新率档位';

	/// zh: '省电'
	String get fpsModePowerSaving => '省电';

	/// zh: '均衡'
	String get fpsModeBalanced => '均衡';

	/// zh: '最高'
	String get fpsModeHighest => '最高';

	/// zh: '弹幕字体'
	String get fontFamily => '弹幕字体';
}

// Path: clipboard
class Translations$clipboard$zh {
	Translations$clipboard$zh.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh: '剪贴板里有直播链接'
	String get title => '剪贴板里有直播链接';

	/// zh: '{site} 房间 {room}，要现在去看吗？'
	String found({required Object site, required Object room}) => '${site} 房间 ${room}，要现在去看吗？';

	/// zh: '去看看'
	String get go => '去看看';
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
			'common.delete' => '删除',
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
			'common.ignore' => '忽略',
			'tray.show' => '显示主界面',
			'tray.quit' => '退出',
			'tray.hide' => '隐藏主界面',
			'tray.recordingCount' => ({required Object count}) => '正在录制 ${count} 个直播间',
			'tray.tooltipRecording' => ({required Object count}) => 'Pure Live · 正在录制 ${count} 个直播间',
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
			'account.editorTitle' => ({required Object name}) => '${name}账号',
			'account.cookieGroup' => 'Cookie',
			'account.paste' => '粘贴',
			'account.clearInput' => '清空',
			'account.cookieInvalid' => '这不像 Cookie：应为 name=value; name2=value2 的形式',
			'account.clipboardEmpty' => '剪贴板里没有文字',
			'account.editorNoneHint' => '未设置：粘贴登录后的 Cookie',
			'account.saved' => '已保存',
			'account.signedIn' => ({required Object name}) => '已登录：${name}',
			'account.statusUid' => ({required Object uid}) => '已保存 · 账号 ID ${uid}',
			'account.verifying' => '正在核验账号…',
			'account.savingVerifying' => '正在核验并保存…',
			'account.openSite' => ({required Object name}) => '打开${name}网页',
			'account.privacyNote' => 'Cookie 只加密保存在本机，不会上传。',
			'account.discardTitle' => '舍弃 Cookie 修改？',
			'account.discardDetail' => '编辑后的 Cookie 尚未保存。确定舍弃修改并离开此页面吗？',
			'account.discard' => '舍弃',
			'account.keepEditing' => '继续编辑',
			'account.cookieTip' => '在浏览器里登录该平台，打开开发者工具，复制请求头里的整段 Cookie 粘贴到下面。',
			'account.statusExpired' => '已过期，请重新粘贴 Cookie',
			'account.douyuLtp0' => 'LTP0（长期密钥）',
			'account.douyuLtp0Hint' => 'passport.douyu.com 请求 Cookie 里的 LTP0，粘贴上面 Cookie 后自动填入',
			'account.douyuDid' => 'dy_did（设备号）',
			'account.douyuDidHint' => '同一个请求 Cookie 里的 dy_did（32 位十六进制），粘贴后自动填入',
			'account.douyuRenew' => '立即续期',
			'account.douyuRenewNeedPair' => '续期需要 LTP0 和 dy_did：先在浏览器里登录斗鱼再粘贴一次 Cookie',
			'account.douyuStatusGuest' => '已保存，但 Cookie 里没有 acf_jwt_token：当前是游客身份，高清/超清不可用',
			'account.douyuStatusNoExpiry' => '登录有效（Cookie 未提供到期时间；如需自动续期请补上 LTP0）',
			'account.douyuStatusAutoRenew' => ({required Object time}) => '登录有效（约 7 天，预计 ${time} 到期）；已配置 LTP0，到期前会自动续期',
			'account.douyuStatusRepaste' => ({required Object time}) => '登录有效（约 7 天，预计 ${time} 到期）；未配置 LTP0，到期后需要重新粘贴',
			'account.douyuStatusRenewable' => ({required Object time}) => '登录态已过期（${time}）；已保存，下次播放会自动用 LTP0 续期',
			'account.douyuStatusExpired' => ({required Object time}) => '登录态已过期（${time}），且 Cookie 里没有 LTP0，需要重新获取',
			'account.savedAccounts' => '已记住的账号',
			'account.savedAccountsNote' => ({required Object count}) => '登录过的账号记在这里（最多 ${count} 个），切换不用重新扫码。登录信息只加密保存在本机，退出登录或删除就会清掉。',
			'account.accountUid' => ({required Object uid}) => 'UID ${uid}',
			'account.accountCurrent' => '当前账号',
			'account.accountSwitch' => '切换',
			'account.accountForget' => '删除这个账号',
			'account.accountSwitchConfirm' => ({required Object name}) => '切换到“${name}”？正在看的直播间会用这个账号重新连接弹幕。',
			'account.accountForgetConfirm' => ({required Object name}) => '从本机删除“${name}”的登录信息？以后要用这个账号需要重新登录。',
			'account.accountAdd' => '添加账号',
			'account.accountAddHint' => '扫码登录另一个账号，现在的账号会留在这里',
			'account.accountAddFull' => ({required Object count}) => '已记住 ${count} 个，再添加会删掉最久没用的那个',
			'account.accountSwitched' => ({required Object name}) => '已切换到“${name}”',
			'account.accountForgot' => ({required Object name}) => '已删除“${name}”',
			'account.accountAdded' => ({required Object name}) => '“${name}”已记住',
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
			'settings.groupQuality' => '画质',
			'settings.preferResolution' => '首选清晰度',
			'settings.preferResolutionDesc' => '进入直播间时首选的视频清晰度',
			'settings.mobileQuality' => '移动网络清晰度',
			'settings.mobileQualityDesc' => '使用流量时的默认画质',
			'settings.preferH264' => '优先 H.264 编码',
			'settings.preferH264Desc' => '同一画质有多种编码时先选兼容性最好的 H.264；HEVC 仍可在直播间手动选择',
			'settings.videoFit' => '画面比例',
			'settings.videoFitDesc' => '画面和播放区域比例不同时如何显示（房间里的画面比例菜单会记住选择）',
			'settings.fitDefault' => '默认比例',
			'settings.fitCrop' => '居中裁剪',
			'settings.fitFillScreen' => '填充屏幕',
			'settings.fitHeight' => '适应高度',
			'settings.fitWidth' => '适应宽度',
			'settings.fitScaleDown' => '等比缩小',
			'settings.groupPlayback' => '播放行为',
			'settings.autoFullscreen' => '自动全屏',
			'settings.autoFullscreenDesc' => '进入直播播放页、画面开始播放后自动进入全屏',
			'settings.blockList' => '弹幕屏蔽名单',
			'settings.blockListDesc' => '关键词、用户名单与正则屏蔽',
			'settings.groupAudience' => '观众人数',
			'settings.audienceMode' => '人数显示口径',
			'settings.audienceModeDesc' => '直播间把哪个数字当作观众规模：平台的实时在线人数，还是人气热度',
			'settings.audienceModeHeat' => '热度（人气）',
			'settings.audienceModeOnline' => '在线人数',
			'settings.audiencePlatforms' => '在线人数可信的平台',
			'settings.audienceHeatOnlyCount' => ({required Object count}) => '其余 ${count} 个平台只有热度口径',
			'settings.portraitLiveSettings' => '竖屏直播适配',
			'settings.portraitLiveSettingsDesc' => '自动识别直播源方向，并统一普通页、全屏和小窗的显示策略',
			'settings.portraitGroupDetect' => '识别与布局',
			'settings.portraitDetect' => '智能识别竖屏直播源',
			'settings.portraitDetectDesc' => '根据解码后的真实画面尺寸识别，切换线路和画质时自动跟随',
			'settings.portraitAdaptiveHeight' => '普通页自适应视频高度',
			'settings.portraitAdaptiveHeightDesc' => '竖屏源增大观看区域，同时保留足够的弹幕列表空间；关闭后面板固定在中间一档',
			'settings.portraitLayoutMode' => '普通页布局模式',
			'settings.portraitLayoutModeDesc' => '仅影响竖屏直播源，不改变普通横屏直播',
			'settings.portraitLayoutBalanced' => '均衡（推荐）',
			'settings.portraitLayoutImmersive' => '沉浸',
			'settings.portraitLayoutCompatibility' => '兼容 16:9',
			'settings.portraitGroupPresentation' => '全屏呈现',
			'settings.portraitFullscreenPolicy' => '进入全屏时的方向',
			'settings.portraitFullscreenPolicyDesc' => '大屏和分屏设备自动交给系统布局，手机可跟随直播源',
			'settings.portraitFollowSource' => '跟随直播源（推荐）',
			'settings.portraitFollowSystem' => '跟随系统',
			'settings.portraitAlwaysLandscape' => '始终横屏',
			'settings.portraitDisplayMode' => '竖屏全屏画面模式',
			'settings.portraitDisplayModeDesc' => '仅影响竖屏直播的竖屏全屏，切换后立即生效，不改变横屏直播和小窗比例',
			'settings.portraitDisplayComplete' => '完整画面',
			'settings.portraitDisplayAmbient' => '沉浸背景（推荐）',
			'settings.portraitDisplayBalanced' => '平衡填充',
			'settings.portraitDisplayCover' => '铺满裁剪',
			'settings.portraitDanmakuMode' => '竖屏弹幕布局',
			'settings.portraitDanmakuModeDesc' => '独立限制竖屏源上的弹幕覆盖区域，不修改全局样式数值',
			'settings.portraitDanmakuFollowGlobal' => '跟随全局',
			'settings.portraitDanmakuUpperQuarter' => '顶部 25%',
			'settings.portraitDanmakuReduced' => '精简 50%',
			'settings.portraitDanmakuHidden' => '竖屏源隐藏',
			'settings.portraitRemember' => '记住单个直播间方向',
			'settings.portraitRememberDesc' => '在播放器中手动指定方向后，下次进入同一直播间继续使用',
			'settings.portraitGroupDiagnostics' => '诊断',
			'settings.portraitDiagnostics' => '显示识别状态',
			'settings.portraitDiagnosticsDesc' => '在画面上显示原始尺寸、比例和当前生效的规则',
			'settings.portraitReset' => '恢复竖屏适配默认设置',
			'settings.portraitResetDesc' => '包括记住的直播间方向覆盖',
			'settings.portraitResetConfirm' => '把竖屏直播适配的全部设置恢复为默认值？',
			'settings.pipOnTop' => '小窗始终置顶',
			'settings.pipOnTopDesc' => '关闭后切换到其他应用时，小窗会按普通窗口层级被遮挡',
			'settings.miniRemember' => '记住小窗位置',
			'settings.miniRememberDesc' => '小窗下次打开回到上次放置的位置；关闭则每次回到右下角',
			'settings.pauseOnTileClose' => '关闭小窗即暂停',
			'settings.pauseOnTileCloseDesc' => '窗口正作为小窗/画中画时点关闭：先恢复窗口并暂停，再执行关闭动作，不会留下藏在后台继续播放的声音',
			'settings.splashAnimation' => '启动动画',
			'settings.splashAnimationDesc' => '启动时显示 Logo',
			'settings.githubUpdates' => '使用 GitHub 官方更新源',
			'settings.githubUpdatesDesc' => '检查更新和下载安装包只连 GitHub 官方地址，适合配了代理的用户；关闭时用镜像',
			'settings.clipboardRooms' => '识别剪贴板中的分享口令',
			'settings.clipboardRoomsDesc' => '打开或回到应用时，剪贴板里有直播间的分享口令就询问是否进入；同一口令只问一次',
			'settings.startup' => '开机启动',
			'settings.startupDesc' => '登录系统后自动启动',
			'settings.startupFailed' => '系统拒绝了开机启动的登记',
			'settings.closeWindow' => '关闭窗口时',
			'settings.closeWindowDesc' => '点窗口右上角关闭按钮时怎么做',
			'settings.closeAsk' => '每次询问',
			'settings.closeHide' => '隐藏到托盘',
			'settings.closeMinimise' => '最小化',
			'settings.closeQuit' => '退出应用',
			'settings.sectionCache' => '缓存',
			'settings.currentCacheSize' => '当前缓存大小',
			'settings.cacheSizeValue' => ({required Object count}) => '${count} MB',
			'settings.cacheMeasuring' => '正在统计…',
			'settings.clearCache' => '清除图片缓存',
			'settings.clearCacheDesc' => '清空后立即重新拉取所有封面',
			'settings.cacheCleared' => ({required Object count}) => '已释放 ${count} MB',
			'settings.cacheAutoClear' => '自动清理图片缓存',
			'settings.cacheAutoClearDesc' => '回到前台时若缓存超过上限就清空',
			'settings.cacheLimit' => '缓存上限',
			'settings.refreshCoversNow' => '立即刷新封面',
			'settings.refreshCoversNowDesc' => '清空图片缓存，所有封面在下次进入时重新拉取',
			'settings.mbValue' => ({required Object count}) => '${count} MB',
			'settings.groupCovers' => '封面',
			'settings.autoRefreshThumbnails' => '自动刷新封面',
			'settings.autoRefreshThumbnailsDesc' => '定时让房间封面重新拉取，保持画面是最新的',
			'settings.thumbnailRefreshInterval' => '封面刷新间隔',
			'settings.groupHistory' => '历史',
			'settings.historyLimit' => '历史记录条数',
			'settings.historyLimitDesc' => '最多保留多少条观看历史；0 为不限制',
			'settings.noLimit' => '不限制',
			'settings.playerProxyGroup' => '播放器代理',
			'settings.playerProxyEnable' => '启用播放器代理',
			'settings.playerProxyEnableDesc' => '直播流由播放器经此代理拉取，与应用自身的网络请求分开',
			'settings.playerProxyHint' => '对下一条直播流生效；正在播放的一路保持原样',
			'settings.thumbnailKeepOldFiles' => '保存旧的缩略图',
			'settings.thumbnailKeepOldFilesDesc' => '刷新封面后保留旧图，由缓存策略自行清理；关闭时超过两个周期的旧图会被清除',
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
			_ => null,
		} ?? switch (path) {
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
			'recorder.groupDefaults' => '录制默认',
			'recorder.defaultQuality' => '默认录制清晰度',
			'recorder.defaultQualityDesc' => '房间给出多个清晰度时，录制选其中标着这一档的地址；没有标注就录最好的一路。',
			'recorder.usePinyinFolder' => '用拼音命名文件夹',
			'recorder.usePinyinFolderDesc' => '打开后主播目录名转成拼音（zhubo8891）；关闭则直接用房间号，最稳妥。',
			'recorder.recordDanmaku' => '保存弹幕',
			'recorder.recordDanmakuDesc' => '录制时在视频旁边保存一份弹幕文件；弹幕连不上不影响录制本身。',
			'recorder.recordDanmakuGifts' => '录制弹幕时包含礼物',
			'recorder.recordDanmakuGiftsDesc' => '弹幕文件里同时写入礼物与 Super Chat。',
			'recorder.groupFiles' => '录制文件',
			'recorder.recordSizeLimit' => '录制大小限制',
			'recorder.recordSizeLimitDesc' => '目录超过上限时自动删除最旧的录制（一小时内的不算旧）。',
			'recorder.recordSizeCap' => '大小上限',
			'recorder.recordUsedSpace' => '已用空间',
			'recorder.recordUsedSpaceDesc' => '点按重新统计录制目录占用的空间。',
			'recorder.clearAllCache' => '清空全部缓存',
			'recorder.clearAllCacheDesc' => '删除录制目录里的全部视频文件；正在录制的一小时内的不删。',
			'recorder.clearFreed' => ({required Object mb}) => '已释放 ${mb} MB',
			'recorder.mbValue' => ({required Object count}) => '${count} MB',
			'recorder.groupPerformance' => '性能与画质',
			'recorder.preferBestStream' => '只录第一条流',
			'recorder.preferBestStreamDesc' => '容器里有多条视频/音频轨时只录第一条，避免产出多音轨文件。',
			'recorder.rwTimeout' => '读写超时',
			'recorder.rwTimeoutDesc' => '输入流超过这个时间没有响应就让读取失败，交给重连处理。',
			'recorder.queueSize' => '输入队列大小',
			'recorder.queueSizeDesc' => '录制看重完整不看重延迟，队列比播放器大得多。',
			'recorder.segmentLengthDesc' => '分段越短崩溃丢的越少，文件与开销越多。',
			'recorder.maxRecordTasks' => '最大同时录制任务数',
			'recorder.maxRecordTasksDesc' => '可以同时录制的房间数；一个房间一路 FFmpeg。',
			'recorder.groupReconnect' => '自动重连',
			'recorder.autoReconnectSwitch' => '自动重连',
			'recorder.autoReconnectDesc' => '录制被中断时自动重试；关闭后断流即结束这一场。',
			'recorder.maxRetryCount' => '最大重试次数',
			'recorder.retryDelay' => '重试间隔',
			'recorder.timesValue' => ({required int count}) => '${count} 次',
			'recorder.secondsValue' => ({required int count}) => '${count} 秒',
			'recorder.groupLiveCheck' => '开播检测',
			'recorder.enablePolling' => '开启开播检测',
			'recorder.enablePollingDesc' => '定时检查还没开播的房间，主播一开播就开始录制。',
			'recorder.checkInterval' => '检测间隔',
			'recorder.enableBackoff' => '递增检测间隔',
			'recorder.enableBackoffDesc' => '房间一直没开播时逐次翻倍检测间隔，减少接口压力。',
			'recorder.maxCheckInterval' => '检测间隔上限',
			'recorder.autoStartBoot' => '应用启动时恢复录制',
			'recorder.autoStartBootDesc' => '启动后自动恢复等待开播与被中断的录制任务。',
			'recorder.decrease' => '减少',
			'recorder.increase' => '增加',
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
			'fonts.custom' => '自定义字体',
			'fonts.customDesc' => '从本机选择 ttf、otf 或 ttc 字体文件',
			'fonts.import' => '导入字体文件',
			'fonts.importFailed' => '这个文件没能导入',
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
			'backup.devicesGroup' => '云端和其他设备',
			'backup.localGroup' => '本地备份',
			'backup.createSubtitle' => '保存应用数据区的整份副本（设置、关注、历史等）',
			'backup.restoreFileSubtitle' => '从备份文件恢复，恢复后应用会重启',
			'backup.filesTitle' => '目录中的备份',
			'backup.filesCount' => ({required Object count}) => '目录中的备份 · ${count}',
			'backup.filesEmpty' => '还没有备份',
			'backup.filesHint' => '在这里创建的备份会列出来；也可以把备份文件放进这个目录',
			'backup.filesError' => '无法读取备份目录',
			'backup.retry' => '重试',
			'backup.loading' => '正在读取…',
			'backup.kindFull' => '完整备份',
			'backup.directoryGroup' => '备份目录',
			'backup.directory' => '备份目录',
			'backup.directoryDefaultLabel' => '备份目录（默认）',
			'backup.directoryDefault' => '应用默认目录',
			'backup.chooseDirectory' => '选择备份目录',
			'backup.resetDirectory' => '改回默认目录',
			'backup.openDirectory' => '打开备份目录',
			'backup.directoryUnwritable' => '无法写入这个目录，请换一个目录',
			'backup.directoryUpdateFailed' => '备份目录未更改，请重试',
			'backup.deleteConfirm' => ({required Object name}) => '确定要删除备份文件“${name}”吗？',
			'backup.created' => ({required Object name}) => '已备份到 ${name}',
			'backup.readFailed' => '无法读取备份文件',
			'backup.restored' => ({required Object name}) => '已恢复 ${name}',
			'backup.moreActions' => '更多操作',
			'backup.fileTooltip' => '点一下恢复；右键或 ⋮ 有更多操作',
			'backup.previewTitle' => '恢复预览',
			'backup.previewRooms' => ({required Object current, required Object incoming}) => '关注的直播间：${current} → ${incoming}',
			'backup.previewGroups' => ({required Object current, required Object incoming}) => '关注分组：${current} → ${incoming}',
			'backup.previewNote' => '其他数据保持不变。',
			'backup.restoreNow' => '立即恢复',
			'backup.followsScopeHint' => '仅含关注的房间和分组，不影响其他设置',
			'backup.kindFollows' => '仅关注列表',
			'backup.deleteFailed' => '文件删除失败',
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
			'search.webSearch' => '网页搜索',
			'search.webSearchTooltip' => '网页搜索当前平台',
			'search.continueWeb' => '继续网页搜索',
			'search.selectPlatformFirst' => '请先选择一个平台',
			'search.needKeyword' => '请输入关键字',
			'search.webUnavailableFor' => ({required Object site}) => '${site} 暂无网页搜索入口。',
			'search.webExternalTip' => '网页搜索在系统浏览器中打开。找到想看的直播间后复制它的链接，回到搜索框粘贴即可直接进入。',
			'search.openInSystemBrowser' => '使用系统浏览器打开',
			'search.externalBrowserNotOpened' => '系统浏览器未打开，请检查默认浏览器设置',
			'search.webSearchRoomBanner' => '这是一个直播间',
			'search.roomIdLabel' => ({required String roomId}) => '房间号 ${roomId}',
			'search.roomEnter' => '进入',
			'search.webSearchRoomDismiss' => '不再提示这个直播间',
			'search.webSearchInvalidAddress' => '网页搜索地址无效，请返回搜索页后重试。',
			'search.webSearchLoadFailed' => '网页加载失败，请检查网络或代理后重试。',
			'search.webSearchUnavailableTitle' => '网页搜索暂不可用',
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
			'room.pip' => '画中画',
			'room.exitPip' => '退出画中画',
			'room.miniWindow' => '小窗播放',
			'room.exitMiniWindow' => '退出小窗',
			'room.messageActions' => '弹幕',
			'room.copyMessage' => '复制',
			'room.copiedToClipboard' => '已复制到剪贴板',
			'room.blockViewer' => '屏蔽此用户',
			'room.blockViewerDesc' => ({required Object name}) => '${name} 的弹幕都不再显示',
			'room.userBlocked' => ({required Object name}) => '已屏蔽 ${name}',
			'room.blockWord' => '屏蔽关键词…',
			'room.blockWordDesc' => '输入一个词，含这个词的弹幕都不再显示',
			'room.keywordBlocked' => '关键词已加入弹幕屏蔽列表',
			'room.userLevel' => ({required Object level}) => '等级 ${level}',
			'room.blockKeywordTitle' => '屏蔽弹幕关键词',
			'room.block' => '屏蔽',
			'room.portraitFullscreenRestoreHint' => '已进入竖屏全屏 · 上滑恢复弹幕栏',
			'areas.followedAreas' => '关注的分区',
			'areas.empty' => '暂无分区',
			'areas.followEmpty' => '还没有关注的分区',
			'areas.followEmptyHint' => '点进一个分区，再用右上角的按钮关注它。',
			'areas.followDone' => ({required String name}) => '已关注「${name}」',
			'areas.unfollowDone' => ({required String name}) => '已取消关注「${name}」',
			'popular.allPlatforms' => '全部平台',
			'popular.allPlatformsHint' => '点按切换平台；平台显示设置可隐藏或排序。',
			'popular.noPlatforms' => '没有可显示的平台',
			'popular.noPlatformsHint' => '在平台显示设置里至少开启一个平台。',
			'popular.empty' => '暂时没有热门直播',
			'remoteSync.title' => '设备同步',
			'remoteSync.tileSubtitle' => '通过局域网在设备之间同步配置',
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
			'remoteSync.manualHint' => '输入对方设备的地址，或粘贴对方二维码里的同步链接（含配对码，不用再输入）',
			'remoteSync.copyAddress' => '复制地址',
			'remoteSync.addressCopied' => '地址已复制',
			'remoteSync.fromName' => ({required String name}) => '来自 ${name}',
			'remoteSync.legacyDevice' => '3.x 版本的设备',
			'remoteSync.allow' => '允许',
			'remoteSync.reject' => '拒绝',
			'remoteSync.incomingImportNamed' => ({required Object address, required Object name}) => '设备 ${address}（${name}）请求用它的设置覆盖本机设置，是否允许？',
			'remoteSync.incomingExportNamed' => ({required Object address, required Object name}) => '设备 ${address}（${name}）请求读取本机设置，是否允许？',
			'remoteSync.pairingCode' => '配对码',
			'remoteSync.pairingCodeFor' => ({required String name}) => '输入“${name}”上显示的 6 位配对码',
			'remoteSync.pairingCodeInvalid' => '配对码应为 6 位数字',
			'remoteSync.partsAll' => '全选',
			'remoteSync.partsLegacy' => '对方是 3.x 或较早的版本（或者暂时没有回应），只能发送全部内容。',
			'remoteSync.partsSendNamed' => ({required String name}) => '勾选要发送到“${name}”的内容。对方确认后，勾选的内容会替换它原有的，没勾的保持不变。',
			'remoteSync.confirmSendNamed' => ({required String name}) => '确定要将当前设备的全部配置发送到“${name}”吗？对方确认后会覆盖它的配置。',
			'remoteSync.previewTitle' => '接收后会这样变化：',
			'remoteSync.previewSettings' => ({required int count, required int changed}) => '设置：对方 ${count} 项，其中 ${changed} 项与本机不同',
			'remoteSync.previewNoAccounts' => '账号：对方没有开“同步账号 Cookie”，本机账号不变',
			'remoteSync.previewAccountsEmpty' => '账号：对方没有登录信息；本机的登录按原样保留',
			'remoteSync.previewWarning' => '接收会合入勾选的内容，没勾的保持不变；设置项以对方为准，无法撤销，需要时先在“备份与恢复”创建一份备份。',
			'remoteSync.partCount' => ({required String part, required int count}) => '${part}（${count}）',
			'remoteSync.partSettings' => '设置',
			'remoteSync.partFollows' => '关注列表',
			'remoteSync.partHistory' => '观看历史',
			'remoteSync.partGroups' => '关注分组',
			'remoteSync.partKeywords' => '屏蔽关键词',
			'remoteSync.partUsers' => '屏蔽用户',
			'remoteSync.partWebdav' => 'WebDAV 服务器',
			'remoteSync.partAccounts' => '账号 Cookie',
			'remoteSync.includeAccounts' => '同步账号 Cookie',
			'remoteSync.includeAccountsHint' => '开启后会发送或提供各平台登录 Cookie 与 WebDAV 密码，只在信任的设备之间开启',
			'remoteSync.receiveAction' => '接收',
			'remoteSync.sendAction' => '发送',
			'remoteSync.invalidQr' => '不是纯粹直播的同步二维码',
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
			_ => null,
		} ?? switch (path) {
			'shellSettings.titleBarHint' => '自动：Windows 11 用应用标题栏，Windows 10 用系统标题栏。应用标题栏由 Pure Live 绘制，系统标题栏使用 Windows 原生样式。切换在重启应用后生效。',
			'shellSettings.frameDiagnosis' => '窗口边框诊断',
			'shellSettings.frameTakeover' => '边框接管',
			'shellSettings.frameTakeoverOn' => '已开启 — 标题栏已由窗口自身移除，四边缩放由窗口的命中测试应答',
			'shellSettings.frameTakeoverOff' => '未开启 — 标题栏与窗口尺寸都由系统负责',
			'shellSettings.frameEdge' => '系统描边',
			'shellSettings.frameEdgeNative' => '由 Windows 绘制',
			'shellSettings.frameEdgeNone' => '当前 Windows 版本不绘制描边，接管后的边框四边都没有线',
			'shellSettings.frameBuild' => 'Windows 构建号',
			'shellSettings.frameSweep' => '运行缩放扫描',
			'shellSettings.frameSweepRunning' => '扫描中…',
			'shellSettings.frameSweepHint' => '会连续改变本窗口大小两轮然后还原。两行数字分别对应视图预同步关闭与打开，第二行的过期帧更少才说明边框跟上了拖动。',
			'shellSettings.frameSweepUnavailable' => '缩放扫描需要开启边框接管，且运行在 Windows。',
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
			'webdav.servers' => 'WebDAV 服务器',
			'webdav.noServer' => '还没有服务器',
			'webdav.noConfigCreateFirst' => '暂无配置，请先创建 WebDAV 配置',
			'webdav.intro' => '添加坚果云、Nextcloud 等 WebDAV 网盘后，可以把备份上传到网盘，在其他设备上恢复。',
			'webdav.createNew' => '创建新配置',
			'webdav.openList' => '打开配置列表',
			'webdav.refresh' => '刷新',
			'webdav.moreActions' => '更多操作',
			'webdav.uploadFavorites' => '仅上传关注列表',
			'webdav.uploadFull' => '上传完整备份',
			'webdav.helpTutorial' => '使用帮助教程',
			'webdav.nameExists' => '配置名称已存在',
			'webdav.selectFailed' => 'WebDAV 配置选择未保存，请重试',
			'webdav.configDeleteFailed' => 'WebDAV 配置未删除，请重试',
			'webdav.confirmDeleteConfig' => ({required Object name}) => '确定要删除配置 “${name}” 吗？',
			'webdav.confirmDeleteItem' => ({required Object name}) => '确定要从 WebDAV 删除“${name}”吗？',
			'webdav.deleteSuccess' => '文件删除成功',
			'webdav.deleteFailed' => '文件删除失败',
			'webdav.uploadFailed' => '文件上传失败',
			'webdav.downloadFailed' => '文件下载失败',
			'webdav.restoreAllSettings' => '恢复全部设置',
			'webdav.restoreFavorites' => '仅恢复关注列表',
			'webdav.folderEmpty' => '这个目录是空的',
			'webdav.serverName' => '配置名称',
			'webdav.editServer' => '编辑配置',
			'webdav.deleteServer' => '删除配置',
			'webdav.activeMark' => '使用中',
			'webdav.saved' => '配置已保存',
			'webdav.restored' => ({required Object name}) => '已从 ${name} 恢复',
			'webdav.uploaded' => ({required Object name}) => '已上传 ${name}',
			'webdav.secretsNote' => '这台设备的安全存储不可用，密码只在本页有效',
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
			'cast.title' => '投屏',
			'cast.hint' => '选择同一局域网内可接收投屏的设备',
			'cast.searching' => '正在搜索局域网内的投屏设备…',
			'cast.noDevices' => '暂未发现投屏设备',
			'cast.castingTo' => ({required String name}) => '正在投屏到 ${name}',
			'cast.stop' => '停止投屏',
			'cast.failed' => '投屏失败——设备可能取不到这个地址',
			'cast.statePlaying' => '播放中',
			'cast.statePaused' => '已暂停',
			'cast.stateBuffering' => '缓冲中',
			'cast.stateStopped' => '已停止',
			'cast.stateUnreachable' => '设备无应答',
			'danmaku.liveHint' => '改动立即生效',
			'danmaku.templateGroup' => '观看模板',
			'danmaku.templateBest' => '顶部 20% · 均衡',
			'danmaku.templateComfort' => '顶部 35% · 舒适',
			'danmaku.templateDense' => '顶部 55% · 高密度',
			'danmaku.templateReset' => '重置',
			'danmaku.bestDesc' => '弹幕只占画面顶部约 20%，速度与密度适中，避免遮挡主体内容。',
			'danmaku.comfortDesc' => '弹幕占画面顶部约 35%，字稍大、速度稍慢，看着更轻松。',
			'danmaku.denseDesc' => '弹幕占画面顶部约 55%，字稍小、速度更快，弹幕多时也看得全。',
			'danmaku.resetDesc' => '恢复默认：弹幕铺满整个画面，不透明，速度和字号回到默认值。',
			'danmaku.customDesc' => '自定义：当前设置不属于上面任何一个模板，可以存为我的模板以后再用。',
			'danmaku.saveMine' => '把当前设置存为我的模板',
			'danmaku.useMine' => '用我的模板',
			'danmaku.templateApplied' => '弹幕模板已应用',
			'danmaku.templateSaved' => '当前弹幕样式已保存',
			'danmaku.templateEmpty' => '还没有保存弹幕模板',
			'danmaku.templateInvalid' => '已保存的弹幕模板损坏或数值超出范围',
			'danmaku.rangeGroup' => '显示范围',
			'danmaku.area' => '画面顶部占用高度',
			'danmaku.marginTop' => '顶部留白（像素）',
			'danmaku.marginBottom' => '区域底部留白（像素）',
			'danmaku.pausedBehavior' => '暂停时的弹幕',
			'danmaku.pausedBehaviorDesc' => '视频暂停后，弹幕跟着停住还是照常飘过',
			'danmaku.pausedPause' => '随视频暂停',
			'danmaku.pausedFly' => '继续飘过',
			'danmaku.styleGroup' => '样式',
			'danmaku.opacity' => '透明度',
			'danmaku.speed' => '滚动速度（像素/秒）',
			'danmaku.fontSize' => '字体大小',
			'danmaku.fontWeight' => '字体粗细',
			'danmaku.weightThin' => '极细',
			'danmaku.weightExtraLight' => '很细',
			'danmaku.weightLight' => '偏细',
			'danmaku.weightNormal' => '正常',
			'danmaku.weightMedium' => '稍粗',
			'danmaku.weightSemiBold' => '中粗',
			'danmaku.weightBold' => '粗体',
			'danmaku.weightExtraBold' => '很粗',
			'danmaku.weightBlack' => '特粗',
			'danmaku.stroke' => '弹幕描边',
			'danmaku.strokeWidth' => '描边宽度',
			'danmaku.noEmoji' => '纯文字模式（隐藏表情）',
			'danmaku.smoothGroup' => '流畅度',
			'danmaku.repeatGroup' => '重复弹幕',
			'danmaku.collapse' => '合并短时间内的相同弹幕',
			'danmaku.collapseDesc' => '不同用户发送相同内容时只保留第一条；本地弹幕和系统消息不受影响。',
			'danmaku.collapseWindow' => '相同内容合并时间（秒）',
			'danmaku.fps' => '弹幕帧率',
			'danmaku.fpsValue' => ({required int count}) => '${count} FPS',
			'danmaku.maxVisible' => '同屏最大弹幕条数',
			'danmaku.maxVisibleValue' => ({required int count}) => '${count} 条',
			'danmaku.interactionGroup' => '画面弹幕交互',
			'danmaku.holdOnPress' => '按住飞行弹幕让它停住',
			'danmaku.holdOnPressDesc' => '手指按住画面上的一条弹幕时只停住这一条，其他照飞，松手继续',
			'danmaku.listGroup' => '弹幕列表',
			'danmaku.listStyle' => '弹幕列表样式',
			'danmaku.listCompact' => '紧凑',
			'danmaku.listCard' => '卡片',
			'danmaku.listFontSize' => '列表文字大小',
			'danmaku.listLineSpacing' => '列表行距',
			'danmaku.showSender' => '显示发送者名称',
			'danmaku.showGifts' => '飞行弹幕显示礼物',
			'danmaku.showGiftsDesc' => '礼物消息也飞过画面',
			'danmaku.tapAction' => '点击画面弹幕查看操作',
			'danmaku.longPressAction' => '长按画面弹幕打开屏蔽操作',
			'danmaku.autoFps' => '弹幕帧率跟随界面刷新率',
			'danmaku.autoFpsDesc' => '跟随省电、均衡或最高档位；关闭后可以手动设帧率。',
			'danmaku.fpsMode' => '刷新率档位',
			'danmaku.fpsModePowerSaving' => '省电',
			'danmaku.fpsModeBalanced' => '均衡',
			'danmaku.fpsModeHighest' => '最高',
			'danmaku.fontFamily' => '弹幕字体',
			'clipboard.title' => '剪贴板里有直播链接',
			'clipboard.found' => ({required Object site, required Object room}) => '${site} 房间 ${room}，要现在去看吗？',
			'clipboard.go' => '去看看',
			_ => null,
		};
	}
}
