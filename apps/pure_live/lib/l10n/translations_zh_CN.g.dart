///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

part of 'translations.g.dart';

// Path: <root>
typedef TranslationsZhCn = Translations; // ignore: unused_element
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
		    locale: AppLocale.zhCn,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ) {
		_meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <zh-CN>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	/// Access flat map
	dynamic operator[](String key) => _meta.getTranslation(key);

	late final Translations _root = this; // ignore: unused_field

	Translations $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => Translations(meta: meta ?? this.$meta);

	// Translations
	late final Translations$account$zh_CN account = Translations$account$zh_CN.internal(_root);
	late final Translations$areas$zh_CN areas = Translations$areas$zh_CN.internal(_root);
	late final Translations$backup$zh_CN backup = Translations$backup$zh_CN.internal(_root);
	late final Translations$common$zh_CN common = Translations$common$zh_CN.internal(_root);
	late final Translations$favorites$zh_CN favorites = Translations$favorites$zh_CN.internal(_root);
	late final Translations$history$zh_CN history = Translations$history$zh_CN.internal(_root);
	late final Translations$hongguo$zh_CN hongguo = Translations$hongguo$zh_CN.internal(_root);
	late final Translations$iptv$zh_CN iptv = Translations$iptv$zh_CN.internal(_root);
	late final Translations$multiview$zh_CN multiview = Translations$multiview$zh_CN.internal(_root);
	late final Translations$music$zh_CN music = Translations$music$zh_CN.internal(_root);
	late final Translations$navigation$zh_CN navigation = Translations$navigation$zh_CN.internal(_root);
	late final Translations$player$zh_CN player = Translations$player$zh_CN.internal(_root);
	late final Translations$popular$zh_CN popular = Translations$popular$zh_CN.internal(_root);
	late final Translations$recorder$zh_CN recorder = Translations$recorder$zh_CN.internal(_root);
	late final Translations$room$zh_CN room = Translations$room$zh_CN.internal(_root);
	late final Translations$search$zh_CN search = Translations$search$zh_CN.internal(_root);
	late final Translations$settings$zh_CN settings = Translations$settings$zh_CN.internal(_root);
	late final Translations$shield$zh_CN shield = Translations$shield$zh_CN.internal(_root);
	late final Translations$sites$zh_CN sites = Translations$sites$zh_CN.internal(_root);
	late final Translations$toolbox$zh_CN toolbox = Translations$toolbox$zh_CN.internal(_root);
	late final Translations$vod$zh_CN vod = Translations$vod$zh_CN.internal(_root);
	late final Translations$wallpaper$zh_CN wallpaper = Translations$wallpaper$zh_CN.internal(_root);
}

// Path: account
class Translations$account$zh_CN {
	Translations$account$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '账号'
	String get title => '账号';

	/// zh-CN: '各直播平台的登录状态，凭证只保存在本机安全存储中。'
	String get description => '各直播平台的登录状态，凭证只保存在本机安全存储中。';

	/// zh-CN: '登录状态'
	String get sectionHeader => '登录状态';

	/// zh-CN: '三方认证'
	String get thirdPartyAuth => '三方认证';

	/// zh-CN: '管理主流平台的绑定授权'
	String get thirdPartyAuthDesc => '管理主流平台的绑定授权';

	/// zh-CN: '暂无支持登录的平台'
	String get empty => '暂无支持登录的平台';

	/// zh-CN: '未登录'
	String get notSignedIn => '未登录';

	/// zh-CN: '已登录：{name}'
	String signedInAs({required Object name}) => '已登录：${name}';

	/// zh-CN: '扫码登录'
	String get qrLogin => '扫码登录';

	/// zh-CN: '导入 Cookie'
	String get cookieLogin => '导入 Cookie';

	/// zh-CN: '退出登录'
	String get signOut => '退出登录';

	/// zh-CN: '{site} 扫码登录'
	String qrDialogTitle({required Object site}) => '${site} 扫码登录';

	/// zh-CN: '打开{site}的手机客户端，扫描二维码并确认登录。'
	String qrHint({required Object site}) => '打开${site}的手机客户端，扫描二维码并确认登录。';

	/// zh-CN: '二维码已过期'
	String get qrExpired => '二维码已过期';

	/// zh-CN: '重新获取'
	String get qrRetry => '重新获取';

	/// zh-CN: '连接失败，正在重试…'
	String get qrPollingFailed => '连接失败，正在重试…';

	/// zh-CN: '{site} 导入 Cookie'
	String cookieDialogTitle({required Object site}) => '${site} 导入 Cookie';

	/// zh-CN: '在已登录的浏览器复制 Cookie 粘贴进来（形如 name=value; name2=value2）。'
	String get cookieDialogHint => '在已登录的浏览器复制 Cookie 粘贴进来（形如 name=value; name2=value2）。';

	/// zh-CN: '粘贴 Cookie 内容'
	String get cookieFieldHint => '粘贴 Cookie 内容';

	/// zh-CN: '登录成功'
	String get loginSuccess => '登录成功';

	/// zh-CN: '登录失败：{message}'
	String loginFailed({required Object message}) => '登录失败：${message}';

	/// zh-CN: '将清除本机保存的{site}登录凭证。'
	String signOutConfirmDesc({required Object site}) => '将清除本机保存的${site}登录凭证。';

	/// zh-CN: '已退出登录'
	String get signOutSuccess => '已退出登录';

	/// zh-CN: '退出登录失败'
	String get signOutFailed => '退出登录失败';

	/// zh-CN: '国内平台'
	String get groupDomestic => '国内平台';

	/// zh-CN: '海外平台'
	String get groupOverseas => '海外平台';

	/// zh-CN: '未设置'
	String get statusNone => '未设置';

	/// zh-CN: '无法读取，请重新粘贴 Cookie'
	String get statusUnreadable => '无法读取，请重新粘贴 Cookie';

	/// zh-CN: '正在核验…'
	String get verifying => '正在核验…';

	/// zh-CN: '登录已失效，请重新登录或更换 Cookie'
	String get statusRejected => '登录已失效，请重新登录或更换 Cookie';

	/// zh-CN: '已保存，暂时无法核验账号'
	String get statusCheckFailed => '已保存，暂时无法核验账号';

	/// zh-CN: '已保存'
	String get statusSaved => '已保存';

	/// zh-CN: '已保存，暂未用于请求'
	String get statusStoredUnused => '已保存，暂未用于请求';

	/// zh-CN: '未设置：Cookie 中没有会话令牌'
	String get statusDouyuNoSession => '未设置：Cookie 中没有会话令牌';

	/// zh-CN: '登录已过期，请重新粘贴 Cookie'
	String get statusDouyuExpired => '登录已过期，请重新粘贴 Cookie';

	/// zh-CN: '预计 {time} 到期'
	String statusDouyuUntil({required Object time}) => '预计 ${time} 到期';

	/// zh-CN: '登录有效，到期前自动续期'
	String get statusDouyuAutoRenew => '登录有效，到期前自动续期';

	/// zh-CN: '登录态已过期，播放时自动续期'
	String get statusDouyuRenewsOnPlay => '登录态已过期，播放时自动续期';

	/// zh-CN: '登录态已失效，点按重新粘贴 Cookie'
	String get statusDouyuRepaste => '登录态已失效，点按重新粘贴 Cookie';

	/// zh-CN: '已清除：没有保存斗鱼登录'
	String get douyuCookieCleared => '已清除：没有保存斗鱼登录';

	/// zh-CN: '游客：Cookie 中没有会话令牌，点按重新粘贴'
	String get douyuCookieGuest => '游客：Cookie 中没有会话令牌，点按重新粘贴';

	/// zh-CN: '已保存续期凭据，还没有登录 Cookie'
	String get douyuPairOnly => '已保存续期凭据，还没有登录 Cookie';

	/// zh-CN: '登录有效'
	String get douyuCookieValidNoExpiry => '登录有效';

	/// zh-CN: '登录有效，凭 LTP0 到期前自动续期（预计 {time}）'
	String douyuCookieValidAutoRenew({required Object time}) => '登录有效，凭 LTP0 到期前自动续期（预计 ${time}）';

	/// zh-CN: '登录有效（预计 {time}），但未保存续期凭据'
	String douyuCookieValidRepaste({required Object time}) => '登录有效（预计 ${time}），但未保存续期凭据';

	/// zh-CN: '登录已过期，可在播放时自动续期（凭据到期于 {time}）'
	String douyuCookieRenewable({required Object time}) => '登录已过期，可在播放时自动续期（凭据到期于 ${time}）';

	/// zh-CN: '登录已失效（{time}），请重新粘贴 Cookie'
	String douyuCookieExpired({required Object time}) => '登录已失效（${time}），请重新粘贴 Cookie';

	/// zh-CN: '续期凭据'
	String get douyuRenewalTitle => '续期凭据';

	/// zh-CN: 'LTP0（长期密钥）'
	String get douyuLtp0Label => 'LTP0（长期密钥）';

	/// zh-CN: '粘贴 passport.douyu.com 请求里的 LTP0'
	String get douyuLtp0Hint => '粘贴 passport.douyu.com 请求里的 LTP0';

	/// zh-CN: 'dy_did（设备号）'
	String get douyuDidLabel => 'dy_did（设备号）';

	/// zh-CN: '登录所属设备的 dy_did'
	String get douyuDidHint => '登录所属设备的 dy_did';

	/// zh-CN: '立即续期'
	String get douyuRenewNow => '立即续期';

	/// zh-CN: '用当前凭据立刻换一次会话，验证续期是否可用，无需等到临近到期。'
	String get douyuRenewNowDesc => '用当前凭据立刻换一次会话，验证续期是否可用，无需等到临近到期。';

	/// zh-CN: '已抽出续期凭据，保留原有登录'
	String get douyuCredentialsAbsorbed => '已抽出续期凭据，保留原有登录';

	/// zh-CN: '已保存续期凭据（斗鱼登录 Cookie 仍需单独粘贴）'
	String get douyuCredentialsOnly => '已保存续期凭据（斗鱼登录 Cookie 仍需单独粘贴）';

	/// zh-CN: '请先填写带登录的 Cookie 再续期'
	String get douyuRenewNoCookie => '请先填写带登录的 Cookie 再续期';

	/// zh-CN: '缺少 LTP0 或 dy_did，无法续期'
	String get douyuRenewNoCredentials => '缺少 LTP0 或 dy_did，无法续期';

	/// zh-CN: '这段 Cookie 里没有会话令牌，无法续期'
	String get douyuRenewNoSession => '这段 Cookie 里没有会话令牌，无法续期';

	/// zh-CN: '续期未返回新会话，登录保持不变'
	String get douyuRenewNoChange => '续期未返回新会话，登录保持不变';

	/// zh-CN: '已续期，预计 {time} 到期'
	String douyuRenewOk({required Object time}) => '已续期，预计 ${time} 到期';

	/// zh-CN: '续期失败，请稍后再试'
	String get douyuRenewFailed => '续期失败，请稍后再试';

	/// zh-CN: '聊天身份：{login}'
	String statusTwitchChat({required Object login}) => '聊天身份：${login}';

	/// zh-CN: '已保存，但 Cookie 里没有聊天身份'
	String get statusTwitchNoChat => '已保存，但 Cookie 里没有聊天身份';

	/// zh-CN: '账号 ID：{uid}'
	String statusHuyaUid({required Object uid}) => '账号 ID：${uid}';

	/// zh-CN: '已保存，但 Cookie 里没有账号 ID'
	String get statusHuyaNoUid => '已保存，但 Cookie 里没有账号 ID';

	/// zh-CN: 'B 站登录已失效，已自动退出登录'
	String get bilibiliLoginExpired => 'B 站登录已失效，已自动退出登录';

	/// zh-CN: '已记住的账号'
	String get savedAccounts => '已记住的账号';

	/// zh-CN: '最多记住 {count} 个账号，切换不用重新扫码；只加密存在本机，退出或删除即清除。'
	String savedAccountsNote({required Object count}) => '最多记住 ${count} 个账号，切换不用重新扫码；只加密存在本机，退出或删除即清除。';

	/// zh-CN: 'UID {uid}'
	String accountUid({required Object uid}) => 'UID ${uid}';

	/// zh-CN: '当前账号'
	String get accountCurrent => '当前账号';

	/// zh-CN: '添加账号'
	String get addAccount => '添加账号';

	/// zh-CN: '扫码登录另一个账号，现在的账号会留在这里'
	String get addAccountHint => '扫码登录另一个账号，现在的账号会留在这里';

	/// zh-CN: '已记住 {count} 个，再添加会删掉最久没用的那个'
	String addAccountFull({required Object count}) => '已记住 ${count} 个，再添加会删掉最久没用的那个';

	/// zh-CN: '已记住 {count} 个账号，再登录一个会删掉最久没用的那个。继续？'
	String addFullConfirmDesc({required Object count}) => '已记住 ${count} 个账号，再登录一个会删掉最久没用的那个。继续？';

	/// zh-CN: '切换'
	String get switchAccount => '切换';

	/// zh-CN: '切换账号'
	String get switchTitle => '切换账号';

	/// zh-CN: '切换到“{name}”？正在看的直播间会用这个账号重新连接弹幕。'
	String switchConfirmDesc({required Object name}) => '切换到“${name}”？正在看的直播间会用这个账号重新连接弹幕。';

	/// zh-CN: '已切换到“{name}”'
	String switchedSuccess({required Object name}) => '已切换到“${name}”';

	/// zh-CN: '删除这个账号'
	String get forgetAccount => '删除这个账号';

	/// zh-CN: '删除账号'
	String get forgetTitle => '删除账号';

	/// zh-CN: '从本机删除“{name}”的登录信息？以后要用这个账号需要重新登录。'
	String forgetConfirmDesc({required Object name}) => '从本机删除“${name}”的登录信息？以后要用这个账号需要重新登录。';

	/// zh-CN: '已删除“{name}”'
	String forgottenSuccess({required Object name}) => '已删除“${name}”';

	/// zh-CN: '登录信息没能保存：这台设备的加密存储出错，请重试'
	String get accountsSaveFailed => '登录信息没能保存：这台设备的加密存储出错，请重试';

	/// zh-CN: '扫不了？'
	String get qrCannotScan => '扫不了？';

	/// zh-CN: '网页登录（短信、密码）'
	String get webLogin => '网页登录（短信、密码）';

	/// zh-CN: '填写 Cookie'
	String get pasteCookieEntry => '填写 Cookie';

	/// zh-CN: '哔哩哔哩 网页登录'
	String get webLoginTitle => '哔哩哔哩 网页登录';

	/// zh-CN: '在页面里登录（短信或密码）'
	String get webLoginSignInOnPage => '在页面里登录（短信或密码）';

	/// zh-CN: '已回到主站，正在读取登录状态…'
	String get webLoginReading => '已回到主站，正在读取登录状态…';

	/// zh-CN: '网页登录未成功'
	String get webLoginFailed => '网页登录未成功';

	/// zh-CN: '这台设备没有可用的内置浏览器'
	String get webLoginUnavailable => '这台设备没有可用的内置浏览器';

	/// zh-CN: '需要内置浏览器；请改用扫码登录，或在其他浏览器登录后粘贴 Cookie。'
	String get webLoginUnavailableDesc => '需要内置浏览器；请改用扫码登录，或在其他浏览器登录后粘贴 Cookie。';

	/// zh-CN: '{site} 暂未接入登录方式'
	String noLoginMethod({required Object site}) => '${site} 暂未接入登录方式';

	/// zh-CN: '{site} Cookie'
	String cookiePageTitle({required Object site}) => '${site} Cookie';

	/// zh-CN: 'Cookie'
	String get cookieSection => 'Cookie';

	/// zh-CN: '如何获取 Cookie'
	String get cookieHowToTitle => '如何获取 Cookie';

	/// zh-CN: '打开 {site} 官网'
	String openSiteWebsite({required Object site}) => '打开 ${site} 官网';

	/// zh-CN: '没有打开系统浏览器'
	String get browserNotOpened => '没有打开系统浏览器';

	/// zh-CN: '粘贴'
	String get paste => '粘贴';

	/// zh-CN: '清空'
	String get clearInput => '清空';

	/// zh-CN: '重新核验'
	String get recheck => '重新核验';

	/// zh-CN: '粘贴的内容不像 Cookie，需要 name=value 的形式'
	String get cookieInvalid => '粘贴的内容不像 Cookie，需要 name=value 的形式';

	/// zh-CN: '这段 Cookie 没有登录或已失效，未保存'
	String get cookieRejected => '这段 Cookie 没有登录或已失效，未保存';

	/// zh-CN: 'Cookie 已保存在本机'
	String get cookieSavedLocal => 'Cookie 已保存在本机';

	/// zh-CN: '已保存，登录为 {name}'
	String cookieSavedAs({required Object name}) => '已保存，登录为 ${name}';

	/// zh-CN: '剪贴板是空的'
	String get clipboardEmpty => '剪贴板是空的';

	/// zh-CN: '舍弃 Cookie 修改？'
	String get discardTitle => '舍弃 Cookie 修改？';

	/// zh-CN: '这些修改还没有保存，离开后会丢失。'
	String get discardDesc => '这些修改还没有保存，离开后会丢失。';

	/// zh-CN: '舍弃'
	String get discard => '舍弃';

	/// zh-CN: '继续编辑'
	String get keepEditing => '继续编辑';

	/// zh-CN: 'Cookie 只加密保存在本机，不会上传；在公用设备上请在离开前退出登录。'
	String get cookiePrivacy => 'Cookie 只加密保存在本机，不会上传；在公用设备上请在离开前退出登录。';

	/// zh-CN: '保存：Ctrl + S（macOS 为 ⌘ + S）'
	String get cookieSaveShortcut => '保存：Ctrl + S（macOS 为 ⌘ + S）';
}

// Path: areas
class Translations$areas$zh_CN {
	Translations$areas$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '全部分区'
	String get allAreas => '全部分区';

	/// zh-CN: '该平台没有分区'
	String get noAreas => '该平台没有分区';

	/// zh-CN: '平台分区'
	String get viewPlatform => '平台分区';

	/// zh-CN: '关注分区'
	String get viewFollowed => '关注分区';

	/// zh-CN: '还没有关注的分区'
	String get followedEmpty => '还没有关注的分区';

	/// zh-CN: '在分区卡片上右键或长按，选择关注即可'
	String get followedEmptyHint => '在分区卡片上右键或长按，选择关注即可';

	/// zh-CN: '没有可浏览的平台'
	String get noPlatforms => '没有可浏览的平台';

	/// zh-CN: '取消关注'
	String get unfollow => '取消关注';

	/// zh-CN: '全部分类'
	String get categoryAll => '全部分类';

	/// zh-CN: '图标在上'
	String get iconTop => '图标在上';

	/// zh-CN: '图标在左'
	String get iconLeft => '图标在左';

	/// zh-CN: '进入分区'
	String get open => '进入分区';

	/// zh-CN: '关注分区'
	String get follow => '关注分区';

	/// zh-CN: '搜索分区'
	String get searchHint => '搜索分区';

	/// zh-CN: '搜索'
	String get search => '搜索';

	/// zh-CN: '在 {platform} 中搜索分区“{query}”'
	String searchAt({required Object platform, required Object query}) => '在 ${platform} 中搜索分区“${query}”';

	/// zh-CN: '没有匹配的分区'
	String get searchEmpty => '没有匹配的分区';

	/// zh-CN: '返回浏览'
	String get backToBrowse => '返回浏览';

	/// zh-CN: '已隐藏 {count: int} 个不能播放的直播（付费、加密、仅限 App 等）'
	String hiddenUnplayable({required int count}) => '已隐藏 ${count} 个不能播放的直播（付费、加密、仅限 App 等）';
}

// Path: backup
class Translations$backup$zh_CN {
	Translations$backup$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '备份与恢复'
	String get title => '备份与恢复';

	/// zh-CN: '本地备份'
	String get localSection => '本地备份';

	/// zh-CN: '当前数据'
	String get summaryTitle => '当前数据';

	/// zh-CN: '还没有可备份的数据'
	String get summaryEmpty => '还没有可备份的数据';

	/// zh-CN: '导出备份'
	String get exportTitle => '导出备份';

	/// zh-CN: '把关注、历史、分区与设置打包为 JSON，经系统分享保存。'
	String get exportDescription => '把关注、历史、分区与设置打包为 JSON，经系统分享保存。';

	/// zh-CN: '没有可备份的数据'
	String get exportEmpty => '没有可备份的数据';

	/// zh-CN: '备份文件已生成'
	String get exportDone => '备份文件已生成';

	/// zh-CN: '导出失败'
	String get exportFailed => '导出失败';

	/// zh-CN: '导入备份'
	String get importTitle => '导入备份';

	/// zh-CN: '粘贴备份 JSON，确认后覆盖当前数据；也可从 WebDAV 恢复。'
	String get importDescription => '粘贴备份 JSON，确认后覆盖当前数据；也可从 WebDAV 恢复。';

	/// zh-CN: '粘贴备份 JSON'
	String get importHint => '粘贴备份 JSON';

	/// zh-CN: '直接选择本地文件要等文件选择器依赖接入；目前可粘贴内容或走 WebDAV。'
	String get importFileNote => '直接选择本地文件要等文件选择器依赖接入；目前可粘贴内容或走 WebDAV。';

	/// zh-CN: '覆盖当前数据？'
	String get importConfirmTitle => '覆盖当前数据？';

	/// zh-CN: '导入会先清空再写入关注、观看历史、关注分区与设置，当前数据无法找回。'
	String get importConfirmDesc => '导入会先清空再写入关注、观看历史、关注分区与设置，当前数据无法找回。';

	/// zh-CN: '恢复完成，重启应用后全部生效'
	String get importDone => '恢复完成，重启应用后全部生效';

	/// zh-CN: '这不是有效的备份内容'
	String get importBadData => '这不是有效的备份内容';

	/// zh-CN: '导入失败'
	String get importFailed => '导入失败';

	/// zh-CN: '关注 {follows} · 历史 {history} · 分区 {areas} · 设置 {settings} 项'
	String summary({required Object follows, required Object history, required Object areas, required Object settings}) => '关注 ${follows} · 历史 ${history} · 分区 ${areas} · 设置 ${settings} 项';

	/// zh-CN: 'WebDAV 同步'
	String get webdavSection => 'WebDAV 同步';

	/// zh-CN: 'WebDAV 账号'
	String get webdavAccounts => 'WebDAV 账号';

	/// zh-CN: '点选即切换并打开它的文件夹；铅笔可修改或删除。'
	String get webdavAccountsHint => '点选即切换并打开它的文件夹；铅笔可修改或删除。';

	/// zh-CN: '添加账号'
	String get webdavAddAccount => '添加账号';

	/// zh-CN: '编辑账号'
	String get webdavEditAccount => '编辑账号';

	/// zh-CN: '账号名称'
	String get webdavAccountName => '账号名称';

	/// zh-CN: '留空则使用服务器主机名'
	String get webdavAccountNameHint => '留空则使用服务器主机名';

	/// zh-CN: '当前'
	String get webdavCurrent => '当前';

	/// zh-CN: '还没有 WebDAV 账号'
	String get webdavNoAccounts => '还没有 WebDAV 账号';

	/// zh-CN: '添加一个服务器后才能上传备份或从这里恢复。'
	String get webdavNoAccountsDesc => '添加一个服务器后才能上传备份或从这里恢复。';

	/// zh-CN: '删除“{name}”账号？'
	String webdavAccountDeleteTitle({required Object name}) => '删除“${name}”账号？';

	/// zh-CN: '只删除本机保存的地址与密码，服务器上的文件不受影响。'
	String get webdavAccountDeleteDesc => '只删除本机保存的地址与密码，服务器上的文件不受影响。';

	/// zh-CN: '账号已删除'
	String get webdavAccountDeleted => '账号已删除';

	/// zh-CN: '刷新'
	String get webdavRefresh => '刷新';

	/// zh-CN: '根目录'
	String get webdavRoot => '根目录';

	/// zh-CN: '新建文件夹'
	String get webdavNewFolder => '新建文件夹';

	/// zh-CN: '文件夹名称'
	String get webdavNewFolderName => '文件夹名称';

	/// zh-CN: '文件夹已创建'
	String get webdavFolderCreated => '文件夹已创建';

	/// zh-CN: '打开文件夹'
	String get webdavEnterFolder => '打开文件夹';

	/// zh-CN: '删除服务器上的这个文件夹及其中的全部内容。'
	String get webdavDeleteFolderDesc => '删除服务器上的这个文件夹及其中的全部内容。';

	/// zh-CN: '确认地址与密码可用，不传输任何数据。'
	String get webdavTestDesc => '确认地址与密码可用，不传输任何数据。';

	/// zh-CN: '把本机数据写成备份文件上传到当前账号根目录，覆盖同名文件。'
	String get webdavUploadDesc => '把本机数据写成备份文件上传到当前账号根目录，覆盖同名文件。';

	/// zh-CN: '读取当前账号根目录的备份文件并覆盖本机数据。'
	String get webdavDownloadDesc => '读取当前账号根目录的备份文件并覆盖本机数据。';

	/// zh-CN: '像文件夹一样浏览服务器：进入目录、新建文件夹、上传或恢复任意文件。'
	String get webdavBrowseDesc => '像文件夹一样浏览服务器：进入目录、新建文件夹、上传或恢复任意文件。';

	/// zh-CN: '备份以 {file} 存放在服务器目录，上传覆盖、下载恢复。'
	String webdavDescription({required Object file}) => '备份以 ${file} 存放在服务器目录，上传覆盖、下载恢复。';

	/// zh-CN: '服务器配置'
	String get webdavConfigTitle => '服务器配置';

	/// zh-CN: '填服务器地址与账号；密码只存系统安全存储，不进备份。'
	String get webdavConfigDescription => '填服务器地址与账号；密码只存系统安全存储，不进备份。';

	/// zh-CN: '服务器地址'
	String get webdavUrl => '服务器地址';

	/// zh-CN: 'https://dav.jianguoyun.com/dav/'
	String get webdavUrlHint => 'https://dav.jianguoyun.com/dav/';

	/// zh-CN: '用户名'
	String get webdavUser => '用户名';

	/// zh-CN: '账号，可留空'
	String get webdavUserHint => '账号，可留空';

	/// zh-CN: '密码'
	String get webdavPassword => '密码';

	/// zh-CN: '留空则保持不变'
	String get webdavPasswordHint => '留空则保持不变';

	/// zh-CN: '已保存在安全存储'
	String get webdavPasswordKeep => '已保存在安全存储';

	/// zh-CN: '未设置'
	String get webdavPasswordEmpty => '未设置';

	/// zh-CN: '请先填写服务器地址'
	String get webdavUrlMissing => '请先填写服务器地址';

	/// zh-CN: 'WebDAV 配置已保存'
	String get webdavSaved => 'WebDAV 配置已保存';

	/// zh-CN: '测试连接'
	String get webdavTest => '测试连接';

	/// zh-CN: '连接成功'
	String get webdavTestOk => '连接成功';

	/// zh-CN: '上传备份'
	String get webdavUpload => '上传备份';

	/// zh-CN: '已上传 {file}'
	String webdavUploadDone({required Object file}) => '已上传 ${file}';

	/// zh-CN: '下载并恢复'
	String get webdavDownload => '下载并恢复';

	/// zh-CN: '下载并覆盖当前数据？'
	String get webdavDownloadConfirmTitle => '下载并覆盖当前数据？';

	/// zh-CN: '将用服务器上的 {file} 覆盖本机的关注、历史、分区与设置。'
	String webdavDownloadConfirmDesc({required Object file}) => '将用服务器上的 ${file} 覆盖本机的关注、历史、分区与设置。';

	/// zh-CN: '认证失败，请检查用户名或密码'
	String get webdavAuthFailed => '认证失败，请检查用户名或密码';

	/// zh-CN: '服务器上还没有备份文件'
	String get webdavNotFound => '服务器上还没有备份文件';

	/// zh-CN: '网络错误，请检查地址或代理'
	String get webdavNetworkFailed => '网络错误，请检查地址或代理';

	/// zh-CN: '服务器返回错误（{status}）'
	String webdavServerFailed({required Object status}) => '服务器返回错误（${status}）';

	/// zh-CN: '操作失败'
	String get webdavFailed => '操作失败';

	/// zh-CN: '另一项操作正在进行'
	String get busy => '另一项操作正在进行';

	/// zh-CN: '选择备份文件夹'
	String get folderPickTitle => '选择备份文件夹';

	/// zh-CN: '备份文件夹'
	String get folderTitle => '备份文件夹';

	/// zh-CN: '默认文件夹'
	String get folderDefault => '默认文件夹';

	/// zh-CN: '正在获取…'
	String get folderLoading => '正在获取…';

	/// zh-CN: '恢复默认文件夹'
	String get folderReset => '恢复默认文件夹';

	/// zh-CN: '打开备份文件夹'
	String get folderOpen => '打开备份文件夹';

	/// zh-CN: '备份文件夹不可写，请换一个'
	String get folderUnwritable => '备份文件夹不可写，请换一个';

	/// zh-CN: '保存备份文件夹失败'
	String get folderSaveFailed => '保存备份文件夹失败';

	/// zh-CN: '无法打开备份文件夹'
	String get openFolderFailed => '无法打开备份文件夹';

	/// zh-CN: '创建备份'
	String get createTitle => '创建备份';

	/// zh-CN: '把关注、观看历史、关注分区与设置写入备份文件夹。'
	String get createDescription => '把关注、观看历史、关注分区与设置写入备份文件夹。';

	/// zh-CN: '创建关注备份'
	String get createFollowsTitle => '创建关注备份';

	/// zh-CN: '只备份关注的房间与分区。'
	String get createFollowsDescription => '只备份关注的房间与分区。';

	/// zh-CN: '已创建 {name: String}'
	String createDone({required String name}) => '已创建 ${name}';

	/// zh-CN: '创建备份失败'
	String get createFailed => '创建备份失败';

	/// zh-CN: '备份文件'
	String get filesSection => '备份文件';

	/// zh-CN: '{count: int} 个备份文件'
	String filesCount({required int count}) => '${count} 个备份文件';

	/// zh-CN: '文件夹里还没有备份文件'
	String get filesEmpty => '文件夹里还没有备份文件';

	/// zh-CN: '读取备份文件夹失败'
	String get filesFailed => '读取备份文件夹失败';

	/// zh-CN: '检查文件夹是否存在且可读，点击重试。'
	String get filesFailedHint => '检查文件夹是否存在且可读，点击重试。';

	/// zh-CN: '{time: String} · {size: String} · {kind: String}'
	String fileMeta({required String time, required String size, required String kind}) => '${time} · ${size} · ${kind}';

	/// zh-CN: '完整备份'
	String get kindFull => '完整备份';

	/// zh-CN: '仅关注'
	String get kindFollows => '仅关注';

	/// zh-CN: '删除备份文件'
	String get fileDelete => '删除备份文件';

	/// zh-CN: '恢复这个备份？'
	String get restoreConfirmTitle => '恢复这个备份？';

	/// zh-CN: '将用 {name: String} 覆盖本机的关注、历史、分区与设置，无法找回。'
	String restoreConfirmDesc({required String name}) => '将用 ${name} 覆盖本机的关注、历史、分区与设置，无法找回。';

	/// zh-CN: '将用 {name: String} 覆盖关注与分区，其他数据不变。'
	String restoreFollowsConfirmDesc({required String name}) => '将用 ${name} 覆盖关注与分区，其他数据不变。';

	/// zh-CN: '恢复失败'
	String get restoreFailed => '恢复失败';

	/// zh-CN: '删除这个备份文件？'
	String get deleteConfirmTitle => '删除这个备份文件？';

	/// zh-CN: '{name: String} 将被永久删除。'
	String deleteConfirmDesc({required String name}) => '${name} 将被永久删除。';

	/// zh-CN: '备份文件已删除'
	String get deleteDone => '备份文件已删除';

	/// zh-CN: '删除备份文件失败'
	String get deleteFileFailed => '删除备份文件失败';

	/// zh-CN: '关注 {follows: int} · 分区 {areas: int}'
	String summaryFollows({required int follows, required int areas}) => '关注 ${follows} · 分区 ${areas}';

	/// zh-CN: '浏览服务器'
	String get webdavBrowse => '浏览服务器';

	/// zh-CN: '上一级'
	String get webdavUp => '上一级';

	/// zh-CN: '这个目录没有文件'
	String get webdavEmpty => '这个目录没有文件';

	/// zh-CN: '无法读取服务器目录'
	String get webdavLoadFailed => '无法读取服务器目录';

	/// zh-CN: '恢复'
	String get webdavRestore => '恢复';

	/// zh-CN: '恢复“{name: String}”？'
	String webdavRestoreTitle({required String name}) => '恢复“${name}”？';

	/// zh-CN: '将用服务器文件覆盖本机的关注、历史、分区与设置。'
	String get webdavRestoreDesc => '将用服务器文件覆盖本机的关注、历史、分区与设置。';

	/// zh-CN: '已恢复服务器备份'
	String get webdavRestored => '已恢复服务器备份';

	/// zh-CN: '删除服务器文件'
	String get webdavFileDelete => '删除服务器文件';

	/// zh-CN: '删除服务器文件“{name: String}”？'
	String webdavDeleteTitle({required String name}) => '删除服务器文件“${name}”？';

	/// zh-CN: '只删除服务器上的这个文件，本机数据不受影响。'
	String get webdavDeleteDesc => '只删除服务器上的这个文件，本机数据不受影响。';

	/// zh-CN: '已删除服务器文件'
	String get webdavDeleted => '已删除服务器文件';

	/// zh-CN: '上传当前备份'
	String get webdavUploadHere => '上传当前备份';

	/// zh-CN: '文件名'
	String get webdavUploadName => '文件名';

	/// zh-CN: '文件名不能为空'
	String get webdavUploadInvalid => '文件名不能为空';

	/// zh-CN: '请先配置服务器地址'
	String get webdavNoServer => '请先配置服务器地址';

	/// zh-CN: '切换账号'
	String get webdavSwitchAccount => '切换账号';

	/// zh-CN: '管理账号'
	String get webdavManageAccounts => '管理账号';

	/// zh-CN: '上传文件'
	String get webdavUploadFile => '上传文件';

	/// zh-CN: '已上传 {count: int} 个文件'
	String webdavUploadFilesDone({required int count}) => '已上传 ${count} 个文件';

	/// zh-CN: '上传关注备份'
	String get webdavUploadFollows => '上传关注备份';

	/// zh-CN: '下载到本机'
	String get webdavDownloadToLocal => '下载到本机';

	/// zh-CN: '已保存 {file: String}'
	String webdavSavedToDevice({required String file}) => '已保存 ${file}';

	/// zh-CN: '重命名'
	String get webdavRename => '重命名';

	/// zh-CN: '重命名“{name: String}”'
	String webdavRenameTitle({required String name}) => '重命名“${name}”';

	/// zh-CN: '已重命名'
	String get webdavRenamed => '已重命名';

	/// zh-CN: '移动到…'
	String get webdavMove => '移动到…';

	/// zh-CN: '移动“{name: String}”'
	String webdavMoveTitle({required String name}) => '移动“${name}”';

	/// zh-CN: '移到此处'
	String get webdavMoveHere => '移到此处';

	/// zh-CN: '已移动'
	String get webdavMoved => '已移动';

	/// zh-CN: '不能把文件夹移动到自己里面'
	String get webdavMoveIntoItself => '不能把文件夹移动到自己里面';

	/// zh-CN: '已用 {used: String} · 共 {total: String}'
	String webdavQuota({required String used, required String total}) => '已用 ${used} · 共 ${total}';
}

// Path: common
class Translations$common$zh_CN {
	Translations$common$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: 'Pure Live'
	String get appTitle => 'Pure Live';

	/// zh-CN: '这里还没有内容'
	String get empty => '这里还没有内容';

	/// zh-CN: '即将推出'
	String get comingSoon => '即将推出';

	/// zh-CN: '关闭'
	String get close => '关闭';

	/// zh-CN: '取消'
	String get cancel => '取消';

	/// zh-CN: '确定'
	String get confirm => '确定';

	/// zh-CN: '最小化'
	String get minimize => '最小化';

	/// zh-CN: '最大化'
	String get maximize => '最大化';

	/// zh-CN: '还原'
	String get restore => '还原';

	/// zh-CN: '切换侧栏'
	String get toggleSidebar => '切换侧栏';

	/// zh-CN: '直播'
	String get moduleLive => '直播';

	/// zh-CN: 'IPTV'
	String get moduleIptv => 'IPTV';

	/// zh-CN: 'Bilibili视频站'
	String get moduleVod => 'Bilibili视频站';

	/// zh-CN: '音乐'
	String get moduleMusic => '音乐';

	/// zh-CN: '重试'
	String get retry => '重试';

	/// zh-CN: '这个模块还在路上'
	String get moduleComingSoon => '这个模块还在路上';

	/// zh-CN: '后退'
	String get back => '后退';

	/// zh-CN: '前进'
	String get forward => '前进';

	/// zh-CN: '搜索房间、主播或站点'
	String get searchHint => '搜索房间、主播或站点';

	/// zh-CN: '切换内容类型'
	String get switchModule => '切换内容类型';

	/// zh-CN: '打开导航'
	String get openNavigation => '打开导航';

	/// zh-CN: '刷新失败'
	String get refreshFailed => '刷新失败';

	/// zh-CN: '切换排版'
	String get layout => '切换排版';

	/// zh-CN: '卡片排版'
	String get layoutGrid => '卡片排版';

	/// zh-CN: '列表排版'
	String get layoutList => '列表排版';

	/// zh-CN: '切换到深色'
	String get switchToDark => '切换到深色';

	/// zh-CN: '切换到浅色'
	String get switchToLight => '切换到浅色';

	/// zh-CN: '回到顶部'
	String get backToTop => '回到顶部';

	/// zh-CN: '回到底部'
	String get backToBottom => '回到底部';

	/// zh-CN: '更多'
	String get more => '更多';

	/// zh-CN: '切换平台'
	String get switchPlatform => '切换平台';

	/// zh-CN: '删除'
	String get delete => '删除';

	/// zh-CN: '新建窗口'
	String get newWindow => '新建窗口';

	/// zh-CN: '显示'
	String get show => '显示';

	/// zh-CN: '保存'
	String get save => '保存';

	/// zh-CN: '已复制'
	String get copied => '已复制';

	/// zh-CN: '当前设备或播放内核无法进入画中画。'
	String get pipUnavailable => '当前设备或播放内核无法进入画中画。';

	/// zh-CN: '红果短剧'
	String get moduleHongguo => '红果短剧';
}

// Path: favorites
class Translations$favorites$zh_CN {
	Translations$favorites$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '还没有关注的房间'
	String get emptyTitle => '还没有关注的房间';

	/// zh-CN: '在房间里点关注，就会出现在这里。'
	String get emptyDescription => '在房间里点关注，就会出现在这里。';

	/// zh-CN: '取消关注'
	String get unfollow => '取消关注';

	/// zh-CN: '全部'
	String get statusAll => '全部';

	/// zh-CN: '直播中'
	String get statusLive => '直播中';

	/// zh-CN: '离线'
	String get statusOffline => '离线';

	/// zh-CN: '刷新'
	String get refresh => '刷新';

	/// zh-CN: '关注列表打不开'
	String get openFailedTitle => '关注列表打不开';

	/// zh-CN: '录播'
	String get statusReplay => '录播';

	/// zh-CN: '搜索直播'
	String get searchLive => '搜索直播';

	/// zh-CN: '当前筛选暂无已开播直播'
	String get emptyLiveTitle => '当前筛选暂无已开播直播';

	/// zh-CN: '当前筛选暂无录播'
	String get emptyReplayTitle => '当前筛选暂无录播';

	/// zh-CN: '当前筛选暂无未开播直播'
	String get emptyOfflineTitle => '当前筛选暂无未开播直播';

	/// zh-CN: '有未开播的关注，切换到「未开播」即可查看。'
	String get emptyOfflineHint => '有未开播的关注，切换到「未开播」即可查看。';

	/// zh-CN: '换个分组或平台，或刷新重新获取状态。'
	String get emptyGroupHint => '换个分组或平台，或刷新重新获取状态。';

	/// zh-CN: '查看未开播'
	String get showOffline => '查看未开播';

	/// zh-CN: '{count: int} 个直播间刷新失败'
	String refreshFailed({required int count}) => '${count} 个直播间刷新失败';

	/// zh-CN: '已开播'
	String get statusLiveNow => '已开播';

	/// zh-CN: '未开播'
	String get statusOfflineNow => '未开播';

	/// zh-CN: '刚刚开播'
	String get justStarted => '刚刚开播';

	/// zh-CN: '已播 {duration}'
	String liveFor({required Object duration}) => '已播 ${duration}';

	/// zh-CN: '{m} 分钟'
	String durationMinutes({required Object m}) => '${m} 分钟';

	/// zh-CN: '{h} 小时 {m} 分'
	String durationHours({required Object h, required Object m}) => '${h} 小时 ${m} 分';

	/// zh-CN: '{d} 天 {h} 小时'
	String durationDays({required Object d, required Object h}) => '${d} 天 ${h} 小时';

	/// zh-CN: '设置标签'
	String get setTags => '设置标签';

	/// zh-CN: '标签'
	String get tagsTitle => '标签';

	/// zh-CN: '标签筛选'
	String get tagsFilter => '标签筛选';

	/// zh-CN: '全部标签'
	String get allTags => '全部标签';

	/// zh-CN: '还没有标签'
	String get tagsEmpty => '还没有标签';

	/// zh-CN: '新建标签'
	String get newTag => '新建标签';

	/// zh-CN: '新标签名称'
	String get tagFieldHint => '新标签名称';

	/// zh-CN: '添加标签'
	String get addTag => '添加标签';

	/// zh-CN: '删除标签“{name: String}”？'
	String deleteTagTitle({required String name}) => '删除标签“${name}”？';

	/// zh-CN: '所有直播间都会移出这个标签，直播间本身不会被取消关注。'
	String get deleteTagBody => '所有直播间都会移出这个标签，直播间本身不会被取消关注。';

	/// zh-CN: '先关注再设置标签'
	String get tagFollowTitle => '先关注再设置标签';

	/// zh-CN: '标签只属于关注的房间。先关注这个直播间，之后可以为它设置任意多个标签。'
	String get tagFollowBody => '标签只属于关注的房间。先关注这个直播间，之后可以为它设置任意多个标签。';

	/// zh-CN: '这个标签已经存在'
	String get tagExists => '这个标签已经存在';

	/// zh-CN: '标签名称不能为空'
	String get tagInvalid => '标签名称不能为空';

	/// zh-CN: '删除'
	String get deleteTag => '删除';
}

// Path: history
class Translations$history$zh_CN {
	Translations$history$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '还没有观看记录'
	String get emptyTitle => '还没有观看记录';

	/// zh-CN: '看过一场直播后，就会出现在这里。'
	String get emptyDescription => '看过一场直播后，就会出现在这里。';

	/// zh-CN: '清空记录'
	String get clear => '清空记录';

	/// zh-CN: '删除这条记录'
	String get remove => '删除这条记录';

	/// zh-CN: '今天'
	String get today => '今天';

	/// zh-CN: '昨天'
	String get yesterday => '昨天';

	/// zh-CN: '更早'
	String get earlier => '更早';

	/// zh-CN: '历史记录打不开'
	String get openFailedTitle => '历史记录打不开';

	/// zh-CN: '已记录 {count: int} / 上限 {limit: int} 条'
	String recordCount({required int count, required int limit}) => '已记录 ${count} / 上限 ${limit} 条';

	/// zh-CN: '筛选'
	String get filter => '筛选';

	/// zh-CN: '筛选观看记录'
	String get filterPanelTitle => '筛选观看记录';

	/// zh-CN: '关键词'
	String get filterKeyword => '关键词';

	/// zh-CN: '按标题、主播、房间号或平台筛选'
	String get filterHint => '按标题、主播、房间号或平台筛选';

	/// zh-CN: '开始时间'
	String get filterStart => '开始时间';

	/// zh-CN: '结束时间'
	String get filterEnd => '结束时间';

	/// zh-CN: '不限'
	String get filterAnyDay => '不限';

	/// zh-CN: '完成'
	String get filterDone => '完成';

	/// zh-CN: '{count: int} 条匹配'
	String filterMatches({required int count}) => '${count} 条匹配';

	/// zh-CN: '清除筛选'
	String get filterReset => '清除筛选';

	/// zh-CN: '没有符合条件的观看记录'
	String get filterEmptyTitle => '没有符合条件的观看记录';

	/// zh-CN: '换个关键词，或清除筛选试试。'
	String get filterEmptyDescription => '换个关键词，或清除筛选试试。';

	/// zh-CN: '删除观看记录？'
	String get deleteConfirmTitle => '删除观看记录？';

	/// zh-CN: '要从观看记录中删除“{title: String}”吗？仅删除这一条记录。'
	String deleteConfirmDesc({required String title}) => '要从观看记录中删除“${title}”吗？仅删除这一条记录。';

	/// zh-CN: '删除'
	String get deleteAction => '删除';

	/// zh-CN: '已从观看记录删除'
	String get deleteDone => '已从观看记录删除';

	/// zh-CN: '清空观看记录？'
	String get clearConfirmTitle => '清空观看记录？';

	/// zh-CN: '清空这 {count: int} 条观看记录？不可撤销。'
	String clearConfirmDesc({required int count}) => '清空这 ${count} 条观看记录？不可撤销。';

	/// zh-CN: '删除筛选出的 {count: int} 条观看记录？不可撤销。'
	String clearFilteredConfirmDesc({required int count}) => '删除筛选出的 ${count} 条观看记录？不可撤销。';

	/// zh-CN: '已清空 {count: int} 条观看记录'
	String clearDone({required int count}) => '已清空 ${count} 条观看记录';

	/// zh-CN: '观看记录更改未保存，请重试。'
	String get changeFailed => '观看记录更改未保存，请重试。';

	/// zh-CN: '调整上限'
	String get limitAction => '调整上限';

	/// zh-CN: '观看记录保留数量'
	String get limitTitle => '观看记录保留数量';

	/// zh-CN: '超出上限后，最早的记录会被移除。'
	String get limitDescription => '超出上限后，最早的记录会被移除。';

	/// zh-CN: '预设数量'
	String get limitPresetsLabel => '预设数量';

	/// zh-CN: '自定义数量'
	String get limitCustomLabel => '自定义数量';

	/// zh-CN: '请输入 {min: int} 到 {max: int} 之间的整数。'
	String limitInvalid({required int min, required int max}) => '请输入 ${min} 到 ${max} 之间的整数。';

	/// zh-CN: '上限已设为 {limit: int} 条'
	String limitSaved({required int limit}) => '上限已设为 ${limit} 条';

	/// zh-CN: '刷新'
	String get refresh => '刷新';

	/// zh-CN: '{count: int} 条记录刷新失败'
	String refreshFailed({required int count}) => '${count} 条记录刷新失败';
}

// Path: hongguo
class Translations$hongguo$zh_CN {
	Translations$hongguo$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '红果短剧'
	String get title => '红果短剧';

	/// zh-CN: '短剧 · 漫剧 · AI 短剧，由红果伴侣服务提供'
	String get tagline => '短剧 · 漫剧 · AI 短剧，由红果伴侣服务提供';

	/// zh-CN: '榜单'
	String get navRank => '榜单';

	/// zh-CN: '搜索'
	String get navSearch => '搜索';

	/// zh-CN: '短剧'
	String get genreShortPlay => '短剧';

	/// zh-CN: '漫剧'
	String get genreComicSeries => '漫剧';

	/// zh-CN: 'AI短剧'
	String get genreAiSeries => 'AI短剧';

	/// zh-CN: '全部'
	String get filterAll => '全部';

	/// zh-CN: '搜索'
	String get search => '搜索';

	/// zh-CN: '搜索短剧'
	String get searchHint => '搜索短剧';

	/// zh-CN: '搜索短剧'
	String get searchIdleTitle => '搜索短剧';

	/// zh-CN: '输入剧名搜索红果的短剧、漫剧和 AI 短剧。'
	String get searchIdleDescription => '输入剧名搜索红果的短剧、漫剧和 AI 短剧。';

	/// zh-CN: '换个条件再试试。'
	String get noResultsDescription => '换个条件再试试。';

	/// zh-CN: '红果接口没有应答；请检查网络后重试。'
	String get serverHint => '红果接口没有应答；请检查网络后重试。';

	/// zh-CN: '红果设置'
	String get openSettings => '红果设置';

	/// zh-CN: '剧集'
	String get episodes => '剧集';

	/// zh-CN: '第{index}集'
	String episodeLabel({required Object index}) => '第${index}集';

	/// zh-CN: '{count}集'
	String episodesCount({required Object count}) => '${count}集';

	/// zh-CN: '跳转集数'
	String get episodesJump => '跳转集数';

	/// zh-CN: '上一组'
	String get episodesPrevious => '上一组';

	/// zh-CN: '下一组'
	String get episodesNext => '下一组';

	/// zh-CN: '播放'
	String get plays => '播放';

	/// zh-CN: '追剧'
	String get followers => '追剧';

	/// zh-CN: '今日'
	String get todayTag => '今日';

	/// zh-CN: '剧集没有加载出来'
	String get loadFailed => '剧集没有加载出来';

	/// zh-CN: '正在打开…'
	String get opening => '正在打开…';

	/// zh-CN: '播放'
	String get play => '播放';

	/// zh-CN: '继续观看'
	String get continueWatching => '继续观看';

	/// zh-CN: '从头播放'
	String get playFromStart => '从头播放';

	/// zh-CN: '还没看过'
	String get notWatchedYet => '还没看过';

	/// zh-CN: '暂停'
	String get pause => '暂停';

	/// zh-CN: '静音'
	String get mute => '静音';

	/// zh-CN: '取消静音'
	String get unmute => '取消静音';

	/// zh-CN: '音量'
	String get volume => '音量';

	/// zh-CN: '播放进度'
	String get progress => '播放进度';

	/// zh-CN: '倍速'
	String get speed => '倍速';

	/// zh-CN: '清晰度'
	String get quality => '清晰度';

	/// zh-CN: '2.0x 快进中 · 上滑锁定'
	String get speedHolding => '2.0x 快进中 · 上滑锁定';

	/// zh-CN: '已锁定 2.0x · 长按下滑解除'
	String get speedLocked => '已锁定 2.0x · 长按下滑解除';

	/// zh-CN: '已锁定 2.0 倍速'
	String get speedLockedToast => '已锁定 2.0 倍速';

	/// zh-CN: '已解除倍速'
	String get speedUnlockedToast => '已解除倍速';

	/// zh-CN: '已经是第一集'
	String get firstEpisode => '已经是第一集';

	/// zh-CN: '已经是最后一集'
	String get lastEpisode => '已经是最后一集';

	/// zh-CN: '下一集'
	String get nextEpisode => '下一集';

	/// zh-CN: '全屏'
	String get fullscreen => '全屏';

	/// zh-CN: '退出全屏'
	String get exitFullscreen => '退出全屏';

	/// zh-CN: '展开'
	String get expand => '展开';

	/// zh-CN: '收起'
	String get collapse => '收起';

	/// zh-CN: '综合榜'
	String get boardAll => '综合榜';

	/// zh-CN: '真人剧榜'
	String get boardReal => '真人剧榜';

	/// zh-CN: '漫剧榜'
	String get boardComic => '漫剧榜';

	/// zh-CN: 'AI剧榜'
	String get boardAi => 'AI剧榜';

	/// zh-CN: '首页'
	String get navHome => '首页';

	/// zh-CN: '找剧'
	String get navFind => '找剧';

	/// zh-CN: '收藏'
	String get navFavorites => '收藏';

	/// zh-CN: '观看历史'
	String get navHistory => '观看历史';

	/// zh-CN: '账户预约'
	String get navReservations => '账户预约';

	/// zh-CN: '账户'
	String get navAccount => '账户';

	/// zh-CN: '推荐'
	String get homeTabAll => '推荐';

	/// zh-CN: '本机'
	String get localTab => '本机';

	/// zh-CN: '账户'
	String get accountTab => '账户';

	/// zh-CN: '在剧集详情中加入本机收藏，喜欢的剧就会出现在这里'
	String get favoritesLocalEmpty => '在剧集详情中加入本机收藏，喜欢的剧就会出现在这里';

	/// zh-CN: '尚未读取账户收藏'
	String get favoritesAccountEmpty => '尚未读取账户收藏';

	/// zh-CN: '登录红果账号后，在这里同步手机收藏'
	String get favoritesAccountOff => '登录红果账号后，在这里同步手机收藏';

	/// zh-CN: '看过的剧和进度会出现在这里'
	String get historyLocalEmpty => '看过的剧和进度会出现在这里';

	/// zh-CN: '尚未读取账户观看历史'
	String get historyAccountEmpty => '尚未读取账户观看历史';

	/// zh-CN: '登录红果账号后，在这里同步手机观看历史'
	String get historyAccountOff => '登录红果账号后，在这里同步手机观看历史';

	/// zh-CN: '清空历史'
	String get historyClear => '清空历史';

	/// zh-CN: '只清空这台设备的观看进度，账户历史和收藏保留'
	String get historyClearDesc => '只清空这台设备的观看进度，账户历史和收藏保留';

	/// zh-CN: '已清空这台设备的观看记录'
	String get historyCleared => '已清空这台设备的观看记录';

	/// zh-CN: '删除记录'
	String get historyRemove => '删除记录';

	/// zh-CN: '只删除这部剧的观看进度'
	String get historyRemoveDesc => '只删除这部剧的观看进度';

	/// zh-CN: '管理'
	String get historyManage => '管理';

	/// zh-CN: '完成'
	String get historyManageDone => '完成';

	/// zh-CN: '删除选中的记录'
	String get historyManageDelete => '删除选中的记录';

	/// zh-CN: '删除选中（{count}）'
	String historyManageDeleteCount({required Object count}) => '删除选中（${count}）';

	/// zh-CN: '续播'
	String get resumeAt => '续播';

	/// zh-CN: '已看完'
	String get watchedBadge => '已看完';

	/// zh-CN: '{index}集/{total}集'
	String historyEpisodeProgress({required Object index, required Object total}) => '${index}集/${total}集';

	/// zh-CN: '已上线'
	String get reservationsOnline => '已上线';

	/// zh-CN: '待上线'
	String get reservationsUpcoming => '待上线';

	/// zh-CN: '当前没有已上线的预约'
	String get reservationsOnlineEmpty => '当前没有已上线的预约';

	/// zh-CN: '当前没有待上线的预约'
	String get reservationsUpcomingEmpty => '当前没有待上线的预约';

	/// zh-CN: '刷新预约'
	String get reservationsRefresh => '刷新预约';

	/// zh-CN: '登录红果账号后，在这里同步手机预约'
	String get reservationsOff => '登录红果账号后，在这里同步手机预约';

	/// zh-CN: '扫码登录红果'
	String get accountSignInTitle => '扫码登录红果';

	/// zh-CN: '用手机红果 App 扫二维码确认登录；账户收藏、历史与预约随账号同步'
	String get accountSignInDesc => '用手机红果 App 扫二维码确认登录；账户收藏、历史与预约随账号同步';

	/// zh-CN: '刷新二维码'
	String get accountQrRefresh => '刷新二维码';

	/// zh-CN: '已登录'
	String get accountSignedInAs => '已登录';

	/// zh-CN: '退出登录'
	String get accountSignOut => '退出登录';

	/// zh-CN: '只退出红果账号，本机收藏与历史保留'
	String get accountSignOutDesc => '只退出红果账号，本机收藏与历史保留';

	/// zh-CN: '刷新账户数据'
	String get accountRefresh => '刷新账户数据';

	/// zh-CN: '刷新收藏'
	String get accountFavoritesRefresh => '刷新收藏';

	/// zh-CN: '刷新历史'
	String get accountHistoryRefresh => '刷新历史';

	/// zh-CN: '收藏'
	String get favorite => '收藏';

	/// zh-CN: '已收藏'
	String get favorited => '已收藏';

	/// zh-CN: '取消收藏'
	String get unfavorite => '取消收藏';

	/// zh-CN: '点赞'
	String get likes => '点赞';

	/// zh-CN: '已加入本机收藏'
	String get favoriteToggleOn => '已加入本机收藏';

	/// zh-CN: '已取消本机收藏'
	String get favoriteToggleOff => '已取消本机收藏';

	/// zh-CN: '已加入账户收藏'
	String get cloudFavoriteOn => '已加入账户收藏';

	/// zh-CN: '已取消账户收藏'
	String get cloudFavoriteOff => '已取消账户收藏';

	/// zh-CN: '相关作品'
	String get related => '相关作品';

	/// zh-CN: '暂无相关剧集'
	String get relatedNone => '暂无相关剧集';

	/// zh-CN: '已上线 · 看剧集'
	String get relatedLive => '已上线 · 看剧集';

	/// zh-CN: '预约'
	String get relatedReserve => '预约';

	/// zh-CN: '已预约'
	String get reserved => '已预约';

	/// zh-CN: '评论'
	String get comments => '评论';

	/// zh-CN: '还没有评论'
	String get commentsEmpty => '还没有评论';

	/// zh-CN: '加载更多'
	String get commentsLoadMore => '加载更多';

	/// zh-CN: '弹幕'
	String get danmaku => '弹幕';

	/// zh-CN: '弹幕开'
	String get danmakuOn => '弹幕开';

	/// zh-CN: '弹幕关'
	String get danmakuOff => '弹幕关';

	/// zh-CN: '在画面上飞行显示本集评论'
	String get danmakuEnabledDesc => '在画面上飞行显示本集评论';

	/// zh-CN: '弹幕字号'
	String get danmakuFontSize => '弹幕字号';

	/// zh-CN: '评论文字的大小'
	String get danmakuFontSizeDesc => '评论文字的大小';

	/// zh-CN: '弹幕不透明度'
	String get danmakuOpacity => '弹幕不透明度';

	/// zh-CN: '文字越亮越不透明'
	String get danmakuOpacityDesc => '文字越亮越不透明';

	/// zh-CN: '弹幕速度'
	String get danmakuSpeed => '弹幕速度';

	/// zh-CN: '评论横穿画面的快慢'
	String get danmakuSpeedDesc => '评论横穿画面的快慢';

	/// zh-CN: '弹幕密度'
	String get danmakuDensity => '弹幕密度';

	/// zh-CN: '同时最多占几行画面'
	String get danmakuDensityDesc => '同时最多占几行画面';

	/// zh-CN: '少'
	String get danmakuDensitySparse => '少';

	/// zh-CN: '中'
	String get danmakuDensityNormal => '中';

	/// zh-CN: '多'
	String get danmakuDensityDense => '多';

	/// zh-CN: '手机号登录'
	String get phoneLogin => '手机号登录';

	/// zh-CN: '手机号，如 138…（境外 +区号 号码）'
	String get phonePlaceholder => '手机号，如 138…（境外 +区号 号码）';

	/// zh-CN: '发送验证码'
	String get phoneSend => '发送验证码';

	/// zh-CN: '验证码'
	String get phoneCodePlaceholder => '验证码';

	/// zh-CN: '登录'
	String get phoneVerify => '登录';

	/// zh-CN: '验证码已发送到'
	String get phoneSent => '验证码已发送到';

	/// zh-CN: '用手机号登录'
	String get accountPhoneToggle => '用手机号登录';

	/// zh-CN: '扫码登录'
	String get accountQrToggle => '扫码登录';

	/// zh-CN: '评论没有加载出来'
	String get commentsFailed => '评论没有加载出来';

	/// zh-CN: '为你推荐'
	String get shelfForYou => '为你推荐';

	/// zh-CN: '换一批'
	String get shelfChangeBatch => '换一批';

	/// zh-CN: '正在热播'
	String get shelfHot => '正在热播';

	/// zh-CN: '新剧'
	String get shelfNew => '新剧';

	/// zh-CN: '分类'
	String get shelfCategory => '分类';

	/// zh-CN: '上新'
	String get newArrivals => '上新';

	/// zh-CN: '查看完整榜单'
	String get openFullBoard => '查看完整榜单';

	/// zh-CN: '更多'
	String get seeMore => '更多';

	/// zh-CN: '刷新片单'
	String get refreshShelf => '刷新片单';

	/// zh-CN: '全{count}集'
	String allEpisodesCount({required Object count}) => '全${count}集';

	/// zh-CN: '重置'
	String get filterReset => '重置';

	/// zh-CN: '全部条件'
	String get filterNone => '全部条件';

	/// zh-CN: '红果官网热播榜'
	String get rankSource => '红果官网热播榜';

	/// zh-CN: '全部题材'
	String get rankTopicAll => '全部题材';

	/// zh-CN: '保留原榜名次'
	String get rankKeepsPlaces => '保留原榜名次';

	/// zh-CN: '正在后台更新…'
	String get rankRenewing => '正在后台更新…';

	/// zh-CN: '读取中…'
	String get rankReading => '读取中…';

	/// zh-CN: '本榜暂无符合条件的作品，可切换题材'
	String get rankEmptyTopic => '本榜暂无符合条件的作品，可切换题材';

	/// zh-CN: '{count} 部'
	String rankSeriesCount({required Object count}) => '${count} 部';

	/// zh-CN: '刷新'
	String get refresh => '刷新';

	/// zh-CN: '联想暂不可用，可直接按搜索'
	String get suggestOff => '联想暂不可用，可直接按搜索';

	/// zh-CN: '最近搜索'
	String get searchHistory => '最近搜索';

	/// zh-CN: '清空历史'
	String get searchHistoryClear => '清空历史';

	/// zh-CN: '搜过的剧名会留在本机，最多 20 条'
	String get searchHistoryHint => '搜过的剧名会留在本机，最多 20 条';

	/// zh-CN: '筛选'
	String get filter => '筛选';

	/// zh-CN: '筛选条件'
	String get filterPanelTitle => '筛选条件';

	/// zh-CN: '完成'
	String get filterDone => '完成';

	/// zh-CN: '红果号'
	String get accountId => '红果号';

	/// zh-CN: '复制'
	String get copyAccountId => '复制';

	/// zh-CN: '已复制'
	String get copied => '已复制';

	/// zh-CN: '分享'
	String get share => '分享';

	/// zh-CN: '链接已复制'
	String get shareCopied => '链接已复制';

	/// zh-CN: '正在读取…'
	String get accountReading => '正在读取…';

	/// zh-CN: '尚未读取'
	String get accountNotRead => '尚未读取';

	/// zh-CN: '已读取 {count} 部'
	String accountReadCount({required Object count}) => '已读取 ${count} 部';

	/// zh-CN: '已看完'
	String get historyFilterWatched => '已看完';

	/// zh-CN: '未看完'
	String get historyFilterUnwatched => '未看完';

	/// zh-CN: '定时停止'
	String get sleep => '定时停止';

	/// zh-CN: '关闭定时停止'
	String get sleepOff => '关闭定时停止';

	/// zh-CN: '{minutes} 分钟后'
	String sleepAfter({required Object minutes}) => '${minutes} 分钟后';

	/// zh-CN: '{count} 分钟后'
	String sleepMinutes({required Object count}) => '${count} 分钟后';

	/// zh-CN: '本集播完'
	String get sleepThisEpisode => '本集播完';

	/// zh-CN: '再播完 {count} 集'
	String sleepAfterEpisodes({required Object count}) => '再播完 ${count} 集';

	/// zh-CN: '再播完 {count} 集'
	String sleepEpisodes({required Object count}) => '再播完 ${count} 集';

	/// zh-CN: '定时停止已生效 · 观看位置已保存 · 按播放可继续'
	String get sleepStopped => '定时停止已生效 · 观看位置已保存 · 按播放可继续';

	/// zh-CN: '立即重试'
	String get retryNow => '立即重试';

	/// zh-CN: '尝试 {height}P'
	String retryLower({required Object height}) => '尝试 ${height}P';

	/// zh-CN: '返回选集'
	String get backToEpisodes => '返回选集';

	/// zh-CN: '停止自动重试'
	String get stopAutoRetry => '停止自动重试';

	/// zh-CN: '即将重试 {attempt}/3 · {seconds} 秒后'
	String autoRetry({required Object attempt, required Object seconds}) => '即将重试 ${attempt}/3 · ${seconds} 秒后';

	/// zh-CN: '已自动重试 3 次，仍无法播放。可手动重试或切换清晰度。'
	String get retryExhausted => '已自动重试 3 次，仍无法播放。可手动重试或切换清晰度。';

	/// zh-CN: '当前没有网络 · 联网后会自动接着播'
	String get waitingForNetwork => '当前没有网络 · 联网后会自动接着播';

	/// zh-CN: '设备解码记录'
	String get decoderLessons => '设备解码记录';

	/// zh-CN: '已记住 {count} 条解码失败，选流时会跳过它们'
	String decoderLessonsCount({required Object count}) => '已记住 ${count} 条解码失败，选流时会跳过它们';

	/// zh-CN: '还没有解码失败记录，选流按平台声明'
	String get decoderLessonsEmpty => '还没有解码失败记录，选流按平台声明';

	/// zh-CN: '已清除 {count} 条设备解码记录'
	String decoderResetDone({required Object count}) => '已清除 ${count} 条设备解码记录';

	/// zh-CN: '检查更新'
	String get favoriteCheck => '检查更新';

	/// zh-CN: '检查更新 {done}/{total}…'
	String favoriteChecking({required Object done, required Object total}) => '检查更新 ${done}/${total}…';

	/// zh-CN: '已检查 {done}/{total} 部 · 检查完成'
	String favoriteChecked({required Object done, required Object total}) => '已检查 ${done}/${total} 部 · 检查完成';

	/// zh-CN: '已检查 {done}/{total} 部 · {failures} 部失败，稍后可重试'
	String favoriteCheckedSome({required Object done, required Object total, required Object failures}) => '已检查 ${done}/${total} 部 · ${failures} 部失败，稍后可重试';

	/// zh-CN: '最近一小时已检查，可手动刷新'
	String get favoriteRecentCheck => '最近一小时已检查，可手动刷新';

	/// zh-CN: '收藏后可检查新集'
	String get favoriteNoFavorites => '收藏后可检查新集';

	/// zh-CN: '新增 {count} 集'
	String favoriteAdded({required Object count}) => '新增 ${count} 集';

	/// zh-CN: '共 {total} 集'
	String favoriteTotal({required Object total}) => '共 ${total} 集';

	/// zh-CN: '共 {total} 集（+{added}）'
	String favoriteTotalAdded({required Object total, required Object added}) => '共 ${total} 集（+${added}）';

	/// zh-CN: '总集数待更新'
	String get favoriteTotalPending => '总集数待更新';

	/// zh-CN: '看到第 {index} 集'
	String favoriteWatchedTo({required Object index}) => '看到第 ${index} 集';

	/// zh-CN: '{count} 部有新集'
	String favoriteBadge({required Object count}) => '${count} 部有新集';

	/// zh-CN: '剧评'
	String get reviews => '剧评';

	/// zh-CN: '本集评论'
	String get reviewsEpisode => '本集评论';

	/// zh-CN: '整剧剧评'
	String get reviewsSeries => '整剧剧评';

	/// zh-CN: '还没有剧评'
	String get reviewsEmpty => '还没有剧评';

	/// zh-CN: '评分 {score}'
	String rating({required Object score}) => '评分 ${score}';

	/// zh-CN: '{count} 人评分'
	String ratingCount({required Object count}) => '${count} 人评分';
}

// Path: iptv
class Translations$iptv$zh_CN {
	Translations$iptv$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '全部'
	String get tabAll => '全部';

	/// zh-CN: '直播'
	String get live => '直播';

	/// zh-CN: '频道范围'
	String get scopeLabel => '频道范围';

	/// zh-CN: '全部频道'
	String get scopeAll => '全部频道';

	/// zh-CN: '收藏频道'
	String get scopeFavourites => '收藏频道';

	/// zh-CN: '频道分组'
	String get groupsLabel => '频道分组';

	/// zh-CN: '未分组'
	String get ungrouped => '未分组';

	/// zh-CN: '还没有频道'
	String get emptyTitle => '还没有频道';

	/// zh-CN: '导入 M3U/TXT 播放列表后，频道就会出现在这里。'
	String get emptyDescription => '导入 M3U/TXT 播放列表后，频道就会出现在这里。';

	/// zh-CN: '频道库打开失败。'
	String get openFailedDescription => '频道库打开失败。';

	/// zh-CN: '还没有收藏的频道'
	String get noFavoritesTitle => '还没有收藏的频道';

	/// zh-CN: '点一下频道卡片上的心形，频道就会留在这里。'
	String get noFavoritesDescription => '点一下频道卡片上的心形，频道就会留在这里。';

	/// zh-CN: '正在播出'
	String get onAir => '正在播出';

	/// zh-CN: '接下来'
	String get upNext => '接下来';

	/// zh-CN: '暂无节目单'
	String get noGuide => '暂无节目单';

	/// zh-CN: '收藏频道'
	String get favouriteAction => '收藏频道';

	/// zh-CN: '取消收藏'
	String get unfavouriteAction => '取消收藏';

	/// zh-CN: '节目单源'
	String get epgSourceTitle => '节目单源';

	/// zh-CN: 'XMLTV 或 JSON 节目单地址'
	String get epgSourceHint => 'XMLTV 或 JSON 节目单地址';

	/// zh-CN: '导入'
	String get epgImport => '导入';

	/// zh-CN: '节目单已导入'
	String get epgImported => '节目单已导入';

	/// zh-CN: '节目单导入失败'
	String get epgFailed => '节目单导入失败';

	/// zh-CN: '删除此节目单源'
	String get epgRemove => '删除此节目单源';

	/// zh-CN: '还没有节目单来源；导入一个后，频道就会显示正在播的节目。'
	String get epgEmpty => '还没有节目单来源；导入一个后，频道就会显示正在播的节目。';

	/// zh-CN: '选择用于频道节目的节目单来源；同一时间只使用一个。'
	String get activeGuideDescription => '选择用于频道节目的节目单来源；同一时间只使用一个。';

	/// zh-CN: '未选择'
	String get activeGuideNone => '未选择';

	/// zh-CN: '当前节目单'
	String get activeGuideTitle => '当前节目单';

	/// zh-CN: '频道的正在播出与进度都按这份节目单显示。'
	String get activeGuideCardHint => '频道的正在播出与进度都按这份节目单显示。';

	/// zh-CN: '自动更新'
	String get autoUpdate => '自动更新';

	/// zh-CN: '应用会按此间隔在后台检查，并重新拉取已开启自动更新的节目单。'
	String get autoUpdateHint => '应用会按此间隔在后台检查，并重新拉取已开启自动更新的节目单。';

	/// zh-CN: '自定义 User-Agent'
	String get customUserAgent => '自定义 User-Agent';

	/// zh-CN: '导入与播放请求使用的 User-Agent；留空用应用默认，播放列表自带优先。'
	String get customUserAgentDesc => '导入与播放请求使用的 User-Agent；留空用应用默认，播放列表自带优先。';

	/// zh-CN: '更新间隔'
	String get updateInterval => '更新间隔';

	/// zh-CN: '{hours: int} 小时'
	String updateIntervalHours({required int hours}) => '${hours} 小时';

	/// zh-CN: '{days: int} 天'
	String updateIntervalDays({required int days}) => '${days} 天';

	/// zh-CN: '{count: int} 个节目单会按此间隔自动刷新'
	String autoUpdateStatusOn({required int count}) => '${count} 个节目单会按此间隔自动刷新';

	/// zh-CN: '还没有节目单开启自动更新。'
	String get autoUpdateStatusNone => '还没有节目单开启自动更新。';

	/// zh-CN: '还没有网络节目单'
	String get autoUpdateNoRemote => '还没有网络节目单';

	/// zh-CN: '选择'
	String get select => '选择';

	/// zh-CN: '还没有节目单'
	String get selectGuideUnavailable => '还没有节目单';

	/// zh-CN: '{count: int} 个频道'
	String channelCount({required int count}) => '${count} 个频道';

	/// zh-CN: '选择节目单'
	String get chooseGuide => '选择节目单';

	/// zh-CN: '删除'
	String get delete => '删除';

	/// zh-CN: '这是正在使用的节目单，删除后将改用其他来源。'
	String get deleteActiveGuideNote => '这是正在使用的节目单，删除后将改用其他来源。';

	/// zh-CN: '删除节目单“{name: String}”？已下载的节目会一并移除。'
	String deleteGuideMessage({required String name}) => '删除节目单“${name}”？已下载的节目会一并移除。';

	/// zh-CN: '删除节目单？'
	String get deleteGuideTitle => '删除节目单？';

	/// zh-CN: '删除“{name: String}”及其 {count: int} 个频道？'
	String deletePlaylistMessage({required String name, required int count}) => '删除“${name}”及其 ${count} 个频道？';

	/// zh-CN: '删除播放列表？'
	String get deletePlaylistTitle => '删除播放列表？';

	/// zh-CN: '已删除“{name: String}”'
	String deleted({required String name}) => '已删除“${name}”';

	/// zh-CN: '节目单名称'
	String get guideName => '节目单名称';

	/// zh-CN: '例如：我的 EPG'
	String get guideNameHint => '例如：我的 EPG';

	/// zh-CN: '已切换到“{name: String}”'
	String guideSelected({required String name}) => '已切换到“${name}”';

	/// zh-CN: '导入'
	String get importAction => '导入';

	/// zh-CN: '请输入有效的订阅地址'
	String get importAddressInvalid => '请输入有效的订阅地址';

	/// zh-CN: '请先输入订阅地址'
	String get importAddressRequired => '请先输入订阅地址';

	/// zh-CN: '导入失败'
	String get importFailed => '导入失败';

	/// zh-CN: '不支持的文件格式'
	String get importFormat => '不支持的文件格式';

	/// zh-CN: '从文件'
	String get importFromFile => '从文件';

	/// zh-CN: '粘贴文本'
	String get importFromText => '粘贴文本';

	/// zh-CN: '订阅地址'
	String get importFromUrl => '订阅地址';

	/// zh-CN: '导入节目单'
	String get importGuide => '导入节目单';

	/// zh-CN: '支持 XMLTV 地址或文件；导入后会下载节目。'
	String get importGuideDescription => '支持 XMLTV 地址或文件；导入后会下载节目。';

	/// zh-CN: '内容不是有效的播放列表'
	String get importInvalid => '内容不是有效的播放列表';

	/// zh-CN: '请输入播放列表名称'
	String get importNameRequired => '请输入播放列表名称';

	/// zh-CN: '网络请求失败，请检查地址或代理'
	String get importNetworkFailed => '网络请求失败，请检查地址或代理';

	/// zh-CN: '导入播放列表'
	String get importPlaylist => '导入播放列表';

	/// zh-CN: '支持 M3U/M3U8/TXT 地址、文件或粘贴的文本。'
	String get importPlaylistDescription => '支持 M3U/M3U8/TXT 地址、文件或粘贴的文本。';

	/// zh-CN: '已导入“{name: String}”，跳过 {count: int} 项'
	String importSkipped({required String name, required int count}) => '已导入“${name}”，跳过 ${count} 项';

	/// zh-CN: '请粘贴播放列表内容'
	String get importTextRequired => '请粘贴播放列表内容';

	/// zh-CN: '已导入“{name: String}”'
	String imported({required String name}) => '已导入“${name}”';

	/// zh-CN: '导入于 {time: String}'
	String importedAt({required String time}) => '导入于 ${time}';

	/// zh-CN: '使用中'
	String get inUse => '使用中';

	/// zh-CN: '更新于 {time: String}'
	String lastRefresh({required String time}) => '更新于 ${time}';

	/// zh-CN: '本地'
	String get localTag => '本地';

	/// zh-CN: '网络'
	String get networkTag => '网络';

	/// zh-CN: '尚未更新'
	String get neverUpdated => '尚未更新';

	/// zh-CN: '还没有节目单'
	String get noGuidesTitle => '还没有节目单';

	/// zh-CN: '还没有来源'
	String get noSourcesTitle => '还没有来源';

	/// zh-CN: '导入播放列表或节目单后，它们会出现在这里。'
	String get noSourcesDescription => '导入播放列表或节目单后，它们会出现在这里。';

	/// zh-CN: '从订阅地址、文件或粘贴的文本导入播放列表。'
	String get noPlaylistsDescription => '从订阅地址、文件或粘贴的文本导入播放列表。';

	/// zh-CN: '还没有播放列表'
	String get noPlaylistsTitle => '还没有播放列表';

	/// zh-CN: '选择播放列表文件'
	String get pickPlaylistFile => '选择播放列表文件';

	/// zh-CN: '播放列表名称'
	String get playlistName => '播放列表名称';

	/// zh-CN: '留空则按来源自动命名'
	String get playlistNameHint => '留空则按来源自动命名';

	/// zh-CN: '播放列表内容'
	String get playlistText => '播放列表内容';

	/// zh-CN: '粘贴 M3U/M3U8/TXT 内容'
	String get playlistTextHint => '粘贴 M3U/M3U8/TXT 内容';

	/// zh-CN: '订阅地址'
	String get playlistUrl => '订阅地址';

	/// zh-CN: 'https://example.com/playlist.m3u'
	String get playlistUrlHint => 'https://example.com/playlist.m3u';

	/// zh-CN: '播放列表'
	String get playlistsTitle => '播放列表';

	/// zh-CN: '同名播放列表已存在，导入内容将替换它。'
	String get replaceMessage => '同名播放列表已存在，导入内容将替换它。';

	/// zh-CN: '替换“{name: String}”？'
	String replaceTitle({required String name}) => '替换“${name}”？';

	/// zh-CN: '订阅源已变化，已更新缓存'
	String get sourceChanged => '订阅源已变化，已更新缓存';

	/// zh-CN: '共 {count: int} 个频道 · {groups: int} 个分组'
	String summaryChannels({required int count, required int groups}) => '共 ${count} 个频道 · ${groups} 个分组';

	/// zh-CN: '找到 {count: int} 个频道'
	String summaryChannelSearch({required int count}) => '找到 ${count} 个频道';

	/// zh-CN: '{playlists: int} 个播放列表 · {guides: int} 个节目单 · {channels: int} 个频道'
	String summarySources({required int playlists, required int guides, required int channels}) => '${playlists} 个播放列表 · ${guides} 个节目单 · ${channels} 个频道';

	/// zh-CN: '全部'
	String get filterAll => '全部';

	/// zh-CN: '播放列表'
	String get filterPlaylists => '播放列表';

	/// zh-CN: '节目单'
	String get filterGuides => '节目单';

	/// zh-CN: '搜索频道…'
	String get searchChannels => '搜索频道…';

	/// zh-CN: '搜索名称或地址…'
	String get searchSources => '搜索名称或地址…';

	/// zh-CN: '没有匹配的频道'
	String get noChannelMatch => '没有匹配的频道';

	/// zh-CN: '没有匹配的来源'
	String get noSourceMatch => '没有匹配的来源';

	/// zh-CN: '共 {count: int} 项'
	String sourceCount({required int count}) => '共 ${count} 项';

	/// zh-CN: '频道'
	String get colChannel => '频道';

	/// zh-CN: '分组'
	String get colGroup => '分组';

	/// zh-CN: '正在播出'
	String get colNow => '正在播出';

	/// zh-CN: '收藏'
	String get colFavorite => '收藏';

	/// zh-CN: '操作'
	String get colActions => '操作';

	/// zh-CN: '名称'
	String get colName => '名称';

	/// zh-CN: '类型'
	String get colFormat => '类型';

	/// zh-CN: '更新于'
	String get colUpdated => '更新于';

	/// zh-CN: '自动更新'
	String get colAutoUpdate => '自动更新';

	/// zh-CN: '编辑顺序'
	String get editOrder => '编辑顺序';

	/// zh-CN: '来源顺序'
	String get orderTitle => '来源顺序';

	/// zh-CN: '拖动左侧手柄，或用箭头调整；保存后按此顺序显示。'
	String get orderHint => '拖动左侧手柄，或用箭头调整；保存后按此顺序显示。';

	/// zh-CN: '未保存的排序草稿'
	String get orderDraft => '未保存的排序草稿';

	/// zh-CN: '保存顺序'
	String get saveOrder => '保存顺序';

	/// zh-CN: '顺序已保存'
	String get orderSaved => '顺序已保存';

	/// zh-CN: '上移'
	String get moveUp => '上移';

	/// zh-CN: '移到顶部'
	String get moveToTop => '移到顶部';

	/// zh-CN: '下移'
	String get moveDown => '下移';

	/// zh-CN: '移到底部'
	String get moveToBottom => '移到底部';

	/// zh-CN: '播放频道'
	String get openChannel => '播放频道';

	/// zh-CN: '频道'
	String get statChannels => '频道';

	/// zh-CN: '节目单'
	String get statGuides => '节目单';

	/// zh-CN: '播放列表'
	String get statPlaylists => '播放列表';

	/// zh-CN: '同步'
	String get sync => '同步';

	/// zh-CN: '全部同步'
	String get syncAll => '全部同步';

	/// zh-CN: '已同步 {count: int} 个来源'
	String syncAllDone({required int count}) => '已同步 ${count} 个来源';

	/// zh-CN: '没有可同步的网络来源'
	String get syncAllNone => '没有可同步的网络来源';

	/// zh-CN: '{failed: int} / {count: int} 个来源同步失败'
	String syncAllPartial({required int failed, required int count}) => '${failed} / ${count} 个来源同步失败';

	/// zh-CN: '正在同步 {done: int} / {total: int}'
	String syncAllRunning({required int done, required int total}) => '正在同步 ${done} / ${total}';

	/// zh-CN: '“{name: String}”同步失败'
	String syncFailed({required String name}) => '“${name}”同步失败';

	/// zh-CN: '已同步“{name: String}”'
	String synced({required String name}) => '已同步“${name}”';

	/// zh-CN: '频道'
	String get viewChannels => '频道';

	/// zh-CN: '视图'
	String get viewLabel => '视图';

	/// zh-CN: '来源'
	String get viewSources => '来源';

	/// zh-CN: '正在打开频道'
	String get playerOpening => '正在打开频道';

	/// zh-CN: '这个频道没有播放地址'
	String get playerNoStream => '这个频道没有播放地址';

	/// zh-CN: '频道不存在或已被删除'
	String get playerChannelMissing => '频道不存在或已被删除';

	/// zh-CN: '频道播放失败'
	String get playerOpenFailed => '频道播放失败';

	/// zh-CN: '节目单'
	String get guideTitle => '节目单';

	/// zh-CN: '这一天没有节目'
	String get guideEmpty => '这一天没有节目';

	/// zh-CN: '今天'
	String get today => '今天';

	/// zh-CN: '昨天'
	String get yesterday => '昨天';

	/// zh-CN: '前一天'
	String get previousDay => '前一天';

	/// zh-CN: '后一天'
	String get nextDay => '后一天';

	/// zh-CN: '回到直播'
	String get backToLive => '回到直播';

	/// zh-CN: '回看'
	String get catchup => '回看';

	/// zh-CN: '不可回看'
	String get catchupUnavailable => '不可回看';

	/// zh-CN: '正在回看'
	String get playingCatchup => '正在回看';

	/// zh-CN: '无法生成这个节目的回看地址'
	String get catchupFailed => '无法生成这个节目的回看地址';

	/// zh-CN: '导入的播放列表'
	String get importDefaultName => '导入的播放列表';

	/// zh-CN: '复制源地址'
	String get copySourceAddress => '复制源地址';

	/// zh-CN: '打开源地址'
	String get openSourceAddress => '打开源地址';

	/// zh-CN: '源地址已复制'
	String get sourceAddressCopied => '源地址已复制';

	/// zh-CN: '无法打开源地址'
	String get sourceAddressOpenFailed => '无法打开源地址';

	/// zh-CN: '启动时全自动同步'
	String get autoSyncTitle => '启动时全自动同步';

	/// zh-CN: '应用冷启动时自动在后台静默检查并更新网络资源。'
	String get autoSyncDesc => '应用冷启动时自动在后台静默检查并更新网络资源。';

	/// zh-CN: '换台时显示频道号'
	String get browseChannelNumber => '换台时显示频道号';

	/// zh-CN: '在频道名旁边一起显示它的号码。'
	String get browseChannelNumberDesc => '在频道名旁边一起显示它的号码。';

	/// zh-CN: '换台反转'
	String get browseReverse => '换台反转';

	/// zh-CN: '让上键向下走、下键向上走。'
	String get browseReverseDesc => '让上键向下走、下键向上走。';

	/// zh-CN: '显示时间'
	String get browseClock => '显示时间';

	/// zh-CN: '播放时在标题旁显示当前时间。'
	String get browseClockDesc => '播放时在标题旁显示当前时间。';

	/// zh-CN: '显示当前节目'
	String get browseProgrammeLine => '显示当前节目';

	/// zh-CN: '在频道名下方写出正在播出或接下来播出的节目。'
	String get browseProgrammeLineDesc => '在频道名下方写出正在播出或接下来播出的节目。';

	/// zh-CN: '恢复默认的换台显示'
	String get browseReset => '恢复默认的换台显示';

	/// zh-CN: '还没有分组：先导入一份播放列表。'
	String get groupsEmpty => '还没有分组：先导入一份播放列表。';

	/// zh-CN: '关掉的分组从频道列表和换台里消失；重开即恢复。'
	String get groupsHint => '关掉的分组从频道列表和换台里消失；重开即恢复。';

	/// zh-CN: '最近观看'
	String get recentTitle => '最近观看';

	/// zh-CN: '共 {count} 个频道'
	String recentCount({required Object count}) => '共 ${count} 个频道';

	/// zh-CN: '上次观看 {time}'
	String recentWatched({required Object time}) => '上次观看 ${time}';

	/// zh-CN: '从最近观看中移除'
	String get recentRemove => '从最近观看中移除';

	/// zh-CN: '清空最近观看'
	String get recentClear => '清空最近观看';

	/// zh-CN: '清空最近观看？'
	String get recentClearTitle => '清空最近观看？';

	/// zh-CN: '只删除本机的观看记录，收藏和频道本身不受影响。'
	String get recentClearDesc => '只删除本机的观看记录，收藏和频道本身不受影响。';

	/// zh-CN: '还没有看过的频道'
	String get recentEmptyTitle => '还没有看过的频道';

	/// zh-CN: '播放过的频道会出现在这里，方便快速回到上次看的内容。'
	String get recentEmptyDescription => '播放过的频道会出现在这里，方便快速回到上次看的内容。';

	/// zh-CN: '收藏频道'
	String get favouritesTitle => '收藏频道';

	/// zh-CN: '共 {count} 个收藏'
	String favouritesCount({required Object count}) => '共 ${count} 个收藏';

	/// zh-CN: '还没有收藏频道'
	String get favouritesEmptyTitle => '还没有收藏频道';

	/// zh-CN: '在频道列表里点收藏，频道会出现在这里。'
	String get favouritesEmptyDescription => '在频道列表里点收藏，频道会出现在这里。';

	/// zh-CN: '换台'
	String get zapperTitle => '换台';

	/// zh-CN: '换台面板'
	String get zapperOpen => '换台面板';

	/// zh-CN: '分组'
	String get zapperGroups => '分组';

	/// zh-CN: '频道'
	String get zapperChannels => '频道';

	/// zh-CN: '节目'
	String get zapperProgrammes => '节目';

	/// zh-CN: '方向键选择，确认键播放或回看，返回键收起。'
	String get zapperHint => '方向键选择，确认键播放或回看，返回键收起。';

	/// zh-CN: '这个分组没有频道'
	String get zapperEmptyGroup => '这个分组没有频道';

	/// zh-CN: '线路 {current}/{total}'
	String lineCount({required Object current, required Object total}) => '线路 ${current}/${total}';

	/// zh-CN: '画面比例'
	String get aspectLabel => '画面比例';

	/// zh-CN: '默认'
	String get aspectAuto => '默认';

	/// zh-CN: '16:9'
	String get aspect16x9 => '16:9';

	/// zh-CN: '4:3'
	String get aspect4x3 => '4:3';

	/// zh-CN: '铺满'
	String get aspectFill => '铺满';

	/// zh-CN: '裁剪'
	String get aspectZoom => '裁剪';

	/// zh-CN: '输入频道号跳转'
	String get digitHint => '输入频道号跳转';

	/// zh-CN: '没有频道号 {number}'
	String digitNoChannel({required Object number}) => '没有频道号 ${number}';

	/// zh-CN: '预约'
	String get reminderAction => '预约';

	/// zh-CN: '取消预约'
	String get reminderCancelAction => '取消预约';

	/// zh-CN: '已预约「{title}」'
	String reminderSet({required Object title}) => '已预约「${title}」';

	/// zh-CN: '已取消预约'
	String get reminderRemoved => '已取消预约';

	/// zh-CN: '预约节目开始：{title}'
	String reminderStarted({required Object title}) => '预约节目开始：${title}';
}

// Path: multiview
class Translations$multiview$zh_CN {
	Translations$multiview$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '布局'
	String get layoutLabel => '布局';

	/// zh-CN: '点击格子选中，只有选中的格子有声音'
	String get selectHint => '点击格子选中，只有选中的格子有声音';

	/// zh-CN: '第 {index} 格 · 有声'
	String selectedPane({required Object index}) => '第 ${index} 格 · 有声';

	/// zh-CN: '选择房间'
	String get pickRoom => '选择房间';

	/// zh-CN: '进入直播间'
	String get openRoom => '进入直播间';

	/// zh-CN: '清空这一格'
	String get clearPane => '清空这一格';

	/// zh-CN: '交换格子'
	String get swapPane => '交换格子';

	/// zh-CN: '换到这格'
	String get swapHere => '换到这格';

	/// zh-CN: '这一格无法播放'
	String get paneFailed => '这一格无法播放';

	/// zh-CN: '重试这一格'
	String get retryPane => '重试这一格';

	/// zh-CN: '为第 {index} 格选择房间'
	String pickerTitle({required Object index}) => '为第 ${index} 格选择房间';

	/// zh-CN: '还没有关注的房间'
	String get pickerEmptyTitle => '还没有关注的房间';

	/// zh-CN: '先到直播间点关注，再回到这里挑选，房间会出现在列表里。'
	String get pickerEmptyHint => '先到直播间点关注，再回到这里挑选，房间会出现在列表里。';

	/// zh-CN: '已在第 {index} 格'
	String alreadyShown({required Object index}) => '已在第 ${index} 格';

	/// zh-CN: '第 {index} 格'
	String shownIn({required Object index}) => '第 ${index} 格';

	/// zh-CN: '已暂停'
	String get panePaused => '已暂停';

	/// zh-CN: '画质'
	String get paneQuality => '画质';

	/// zh-CN: '暂停这一格'
	String get pausePane => '暂停这一格';

	/// zh-CN: '播放这一格'
	String get playPane => '播放这一格';

	/// zh-CN: '全部暂停'
	String get pauseAll => '全部暂停';

	/// zh-CN: '全部继续'
	String get resumeAll => '全部继续';

	/// zh-CN: '全部静音'
	String get muteAll => '全部静音';

	/// zh-CN: '取消全部静音'
	String get unmuteAll => '取消全部静音';

	/// zh-CN: '画质切换失败'
	String get qualityFailed => '画质切换失败';

	/// zh-CN: '搜索关注或历史房间…'
	String get pickerSearch => '搜索关注或历史房间…';

	/// zh-CN: '点直播间放进这一格'
	String get pickerHint => '点直播间放进这一格';

	/// zh-CN: '关注'
	String get pickerTabFollows => '关注';

	/// zh-CN: '历史记录'
	String get pickerTabHistory => '历史记录';

	/// zh-CN: '搜索主播或标题'
	String get pickerSearchShort => '搜索主播或标题';

	/// zh-CN: '点击选台'
	String get paneEmpty => '点击选台';

	/// zh-CN: '正在为这一格选台'
	String get panePicking => '正在为这一格选台';

	/// zh-CN: '无法读取多画面记录'
	String get wallFailed => '无法读取多画面记录';

	/// zh-CN: '没有匹配的房间'
	String get pickerNoMatch => '没有匹配的房间';
}

// Path: music
class Translations$music$zh_CN {
	Translations$music$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '音乐'
	String get title => '音乐';

	/// zh-CN: '搜索歌曲，在线收听'
	String get tagline => '搜索歌曲，在线收听';

	/// zh-CN: '音乐视图'
	String get viewsLabel => '音乐视图';

	/// zh-CN: '搜索'
	String get search => '搜索';

	/// zh-CN: '乐库'
	String get tabLibrary => '乐库';

	/// zh-CN: '歌单'
	String get tabPlaylists => '歌单';

	/// zh-CN: '榜单'
	String get tabCharts => '榜单';

	/// zh-CN: '我的列表'
	String get tabMine => '我的列表';

	/// zh-CN: '还没有你自己的列表'
	String get myListsEmptyTitle => '还没有你自己的列表';

	/// zh-CN: '收藏的歌曲和你自建的歌单会出现在这里；歌单与排行榜要先有音源。'
	String get myListsEmptyDescription => '收藏的歌曲和你自建的歌单会出现在这里；歌单与排行榜要先有音源。';

	/// zh-CN: '曲库还在路上'
	String get libraryEmptyTitle => '曲库还在路上';

	/// zh-CN: '音乐源接入后，歌曲会以瀑布流卡片在这里分页呈现。'
	String get libraryEmptyDescription => '音乐源接入后，歌曲会以瀑布流卡片在这里分页呈现。';

	/// zh-CN: '歌单还在路上'
	String get playlistsEmptyTitle => '歌单还在路上';

	/// zh-CN: '整理与收藏的歌单会出现在这里。'
	String get playlistsEmptyDescription => '整理与收藏的歌单会出现在这里。';

	/// zh-CN: '榜单还在路上'
	String get chartsEmptyTitle => '榜单还在路上';

	/// zh-CN: '来自各音乐源的热门榜单会出现在这里。'
	String get chartsEmptyDescription => '来自各音乐源的热门榜单会出现在这里。';

	/// zh-CN: '已就绪 {count} 个自定义源'
	String sourcesReady({required Object count}) => '已就绪 ${count} 个自定义源';

	/// zh-CN: '音源与播放'
	String get settingsPlayback => '音源与播放';

	/// zh-CN: '列表'
	String get settingsList => '列表';

	/// zh-CN: '歌曲'
	String get searchTypeSongs => '歌曲';

	/// zh-CN: '歌单'
	String get searchTypeSonglists => '歌单';

	/// zh-CN: '全部音源'
	String get searchSourceAll => '全部音源';

	/// zh-CN: '音源名显示'
	String get sourceNameType => '音源名显示';

	/// zh-CN: '列表里的平台叫什么：别名是参考应用的化名，原名是平台自己的名字。'
	String get sourceNameTypeDesc => '列表里的平台叫什么：别名是参考应用的化名，原名是平台自己的名字。';

	/// zh-CN: '别名'
	String get sourceNameTypeAlias => '别名';

	/// zh-CN: '原名'
	String get sourceNameTypeReal => '原名';

	/// zh-CN: '聚合大会'
	String get sourceAliasAll => '聚合大会';

	/// zh-CN: '小蜗音乐'
	String get sourceAliasKw => '小蜗音乐';

	/// zh-CN: '小枸音乐'
	String get sourceAliasKg => '小枸音乐';

	/// zh-CN: '小秋音乐'
	String get sourceAliasTx => '小秋音乐';

	/// zh-CN: '小芸音乐'
	String get sourceAliasWy => '小芸音乐';

	/// zh-CN: '小蜜音乐'
	String get sourceAliasMg => '小蜜音乐';

	/// zh-CN: '热门'
	String get playlistHotTags => '热门';

	/// zh-CN: '推荐'
	String get sortRecommend => '推荐';

	/// zh-CN: '最热'
	String get sortHot => '最热';

	/// zh-CN: '最新'
	String get sortNew => '最新';

	/// zh-CN: '热藏'
	String get sortHotCollect => '热藏';

	/// zh-CN: '飙升'
	String get sortRise => '飙升';

	/// zh-CN: '打开歌单'
	String get openPlaylistTitle => '打开歌单';

	/// zh-CN: '歌单链接或 ID'
	String get openPlaylistHint => '歌单链接或 ID';

	/// zh-CN: '仅支持当前音源的链接或 ID；粘贴内容会先解析成歌单 ID 再打开。'
	String get openPlaylistTip => '仅支持当前音源的链接或 ID；粘贴内容会先解析成歌单 ID 再打开。';

	/// zh-CN: '更新在线歌单'
	String get playlistUpdateOnline => '更新在线歌单';

	/// zh-CN: '你之前已收藏过「{name}」，是否拉取最新并覆盖里面的歌曲？'
	String duplicateListTip({required Object name}) => '你之前已收藏过「${name}」，是否拉取最新并覆盖里面的歌曲？';

	/// zh-CN: '已更新「{name}」：{count} 首。'
	String onlineUpdatedToast({required Object name, required Object count}) => '已更新「${name}」：${count} 首。';

	/// zh-CN: '更新失败，请稍后再试。'
	String get onlineUpdateFailed => '更新失败，请稍后再试。';

	/// zh-CN: '收藏榜单'
	String get boardCollect => '收藏榜单';

	/// zh-CN: '调整位置'
	String get selectionReposition => '调整位置';

	/// zh-CN: '将已选的 {count} 首歌曲的位置调整到：'
	String repositionTitle({required Object count}) => '将已选的 ${count} 首歌曲的位置调整到：';

	/// zh-CN: '请输入要调整到第几个位置'
	String get repositionHint => '请输入要调整到第几个位置';

	/// zh-CN: '移动到'
	String get selectionMoveTo => '移动到';

	/// zh-CN: '已移动 {count} 首到「{name}」。'
	String moveDoneCount({required Object count, required Object name}) => '已移动 ${count} 首到「${name}」。';

	/// zh-CN: '当前音源暂不支持歌单搜索。'
	String get songlistSearchUnsupported => '当前音源暂不支持歌单搜索。';

	/// zh-CN: '默认音源'
	String get defaultSource => '默认音源';

	/// zh-CN: '歌曲从哪个音源获取；自定义源脚本负责解析播放地址。'
	String get defaultSourceDesc => '歌曲从哪个音源获取；自定义源脚本负责解析播放地址。';

	/// zh-CN: '还没有可用的音源；先在下方「自定义源」里导入脚本。'
	String get defaultSourceEmpty => '还没有可用的音源；先在下方「自定义源」里导入脚本。';

	/// zh-CN: '播放品质'
	String get quality => '播放品质';

	/// zh-CN: '向音源请求的音质；音源没有这一档时会给出它能提供的最高档。'
	String get qualityDesc => '向音源请求的音质；音源没有这一档时会给出它能提供的最高档。';

	/// zh-CN: '128K'
	String get qualityStandard => '128K';

	/// zh-CN: '320K'
	String get qualityHigh => '320K';

	/// zh-CN: '无损'
	String get qualityLossless => '无损';

	/// zh-CN: 'Hi-Res 无损'
	String get qualityHiRes => 'Hi-Res 无损';

	/// zh-CN: '出错自动跳过'
	String get skipOnError => '出错自动跳过';

	/// zh-CN: '某个音源取不到地址时换下一个，而不是停下。'
	String get skipOnErrorDesc => '某个音源取不到地址时换下一个，而不是停下。';

	/// zh-CN: '打开时继续播放'
	String get autoplay => '打开时继续播放';

	/// zh-CN: '打开音乐模块时继续上次的播放队列。'
	String get autoplayDesc => '打开音乐模块时继续上次的播放队列。';

	/// zh-CN: '记住播放进度'
	String get rememberProgress => '记住播放进度';

	/// zh-CN: '再次打开同一首歌时，从上一次停止的位置继续。'
	String get rememberProgressDesc => '再次打开同一首歌时，从上一次停止的位置继续。';

	/// zh-CN: '新歌加到列表顶部'
	String get addToTop => '新歌加到列表顶部';

	/// zh-CN: '关闭时新歌排在列表末尾。'
	String get addToTopDesc => '关闭时新歌排在列表末尾。';

	/// zh-CN: '列表显示音源'
	String get showSource => '列表显示音源';

	/// zh-CN: '在歌曲行旁标出它来自哪个音源。'
	String get showSourceDesc => '在歌曲行旁标出它来自哪个音源。';

	/// zh-CN: '恢复默认'
	String get playbackReset => '恢复默认';

	/// zh-CN: '自动选源、320K、出错跳过、新歌排在末尾。'
	String get playbackResetDesc => '自动选源、320K、出错跳过、新歌排在末尾。';

	/// zh-CN: '自定义源'
	String get sourcesSection => '自定义源';

	/// zh-CN: '自定义源是 JavaScript 脚本，在 fjs（QuickJS）中执行；导入后初始化并接管播放地址解析。'
	String get sourcesHint => '自定义源是 JavaScript 脚本，在 fjs（QuickJS）中执行；导入后初始化并接管播放地址解析。';

	/// zh-CN: '粘贴脚本导入'
	String get sourcesImportText => '粘贴脚本导入';

	/// zh-CN: '把 lx-music 自定义源脚本的全文粘贴进来。'
	String get sourcesImportTextDesc => '把 lx-music 自定义源脚本的全文粘贴进来。';

	/// zh-CN: '从链接导入'
	String get sourcesImportUrl => '从链接导入';

	/// zh-CN: '下载链接指向的 .js 内容并导入。'
	String get sourcesImportUrlDesc => '下载链接指向的 .js 内容并导入。';

	/// zh-CN: '导入自定义源'
	String get importTitle => '导入自定义源';

	/// zh-CN: '在此粘贴脚本全文…'
	String get importScriptHint => '在此粘贴脚本全文…';

	/// zh-CN: 'https://…/source.js'
	String get importUrlHint => 'https://…/source.js';

	/// zh-CN: '先粘贴脚本或填写链接。'
	String get importMissing => '先粘贴脚本或填写链接。';

	/// zh-CN: '这段内容不是 lx-music 自定义源：脚本开头没有带 @name 的头注释。'
	String get importNotASource => '这段内容不是 lx-music 自定义源：脚本开头没有带 @name 的头注释。';

	/// zh-CN: '脚本内容与已导入的音源相同，无需重复导入。'
	String get importDuplicate => '脚本内容与已导入的音源相同，无需重复导入。';

	/// zh-CN: '最多导入 {count} 个自定义源，先移除一个再试。'
	String importLimit({required Object count}) => '最多导入 ${count} 个自定义源，先移除一个再试。';

	/// zh-CN: '脚本下载失败：{error}'
	String importDownloadFailed({required Object error}) => '脚本下载失败：${error}';

	/// zh-CN: '已导入「{name}」'
	String importDone({required Object name}) => '已导入「${name}」';

	/// zh-CN: '已更新「{name}」'
	String importUpdated({required Object name}) => '已更新「${name}」';

	/// zh-CN: '还没有自定义源'
	String get sourcesEmpty => '还没有自定义源';

	/// zh-CN: '导入 lx-music 自定义源脚本后，它会出现在这里。'
	String get sourcesEmptyDesc => '导入 lx-music 自定义源脚本后，它会出现在这里。';

	/// zh-CN: '脚本没有提供说明。'
	String get sourceNoDescription => '脚本没有提供说明。';

	/// zh-CN: '已停用'
	String get sourceDisabled => '已停用';

	/// zh-CN: '使用此音源'
	String get sourceUse => '使用此音源';

	/// zh-CN: '移除源'
	String get sourceDelete => '移除源';

	/// zh-CN: '移除「{name}」？'
	String sourceDeleteTitle({required Object name}) => '移除「${name}」？';

	/// zh-CN: '脚本会一并删除；重新导入即可恢复。'
	String get sourceDeleteDesc => '脚本会一并删除；重新导入即可恢复。';

	/// zh-CN: '已移除「{name}」'
	String sourceDeleted({required Object name}) => '已移除「${name}」';

	/// zh-CN: '共导入 {count} 个'
	String sourcesCount({required Object count}) => '共导入 ${count} 个';

	/// zh-CN: '重新加载脚本'
	String get sourcesReload => '重新加载脚本';

	/// zh-CN: '重新初始化所有已导入的 lx 脚本。'
	String get sourcesReloadDesc => '重新初始化所有已导入的 lx 脚本。';

	/// zh-CN: '已加载 {count} 个脚本'
	String sourcesReloaded({required Object count}) => '已加载 ${count} 个脚本';

	/// zh-CN: '有 {count} 个脚本加载失败'
	String sourcesReloadedErrors({required Object count}) => '有 ${count} 个脚本加载失败';

	/// zh-CN: '搜索歌曲、歌手或专辑…'
	String get searchHint => '搜索歌曲、歌手或专辑…';

	/// zh-CN: '搜一首歌'
	String get searchIdleTitle => '搜一首歌';

	/// zh-CN: '输入歌名、歌手或专辑，按回车开始搜索。'
	String get searchIdleDescription => '输入歌名、歌手或专辑，按回车开始搜索。';

	/// zh-CN: '没有找到歌曲'
	String get noResultsTitle => '没有找到歌曲';

	/// zh-CN: '换个关键词试试。'
	String get noResultsDescription => '换个关键词试试。';

	/// zh-CN: '搜索失败'
	String get searchFailed => '搜索失败';

	/// zh-CN: '{count} 首'
	String songsCount({required Object count}) => '${count} 首';

	/// zh-CN: '播放'
	String get play => '播放';

	/// zh-CN: '暂停'
	String get pause => '暂停';

	/// zh-CN: '下一首'
	String get next => '下一首';

	/// zh-CN: '上一首'
	String get previous => '上一首';

	/// zh-CN: '顺序播放'
	String get modeList => '顺序播放';

	/// zh-CN: '列表循环'
	String get modeListLoop => '列表循环';

	/// zh-CN: '单曲循环'
	String get modeSingleLoop => '单曲循环';

	/// zh-CN: '随机播放'
	String get modeRandom => '随机播放';

	/// zh-CN: '收藏歌曲'
	String get favourite => '收藏歌曲';

	/// zh-CN: '取消收藏'
	String get unfavourite => '取消收藏';

	/// zh-CN: '收藏'
	String get mineFavourites => '收藏';

	/// zh-CN: '最近播放'
	String get mineRecent => '最近播放';

	/// zh-CN: '还没有歌曲'
	String get mineEmptyTitle => '还没有歌曲';

	/// zh-CN: '收藏或播放过的歌曲会出现在这里。'
	String get mineEmptyDescription => '收藏或播放过的歌曲会出现在这里。';

	/// zh-CN: '移除'
	String get removeSong => '移除';

	/// zh-CN: '榜单加载失败'
	String get chartsFailed => '榜单加载失败';

	/// zh-CN: '队列为空'
	String get queueEmpty => '队列为空';

	/// zh-CN: '播放队列'
	String get queueTitle => '播放队列';

	/// zh-CN: '正在播放'
	String get nowPlaying => '正在播放';

	/// zh-CN: '音量'
	String get volume => '音量';

	/// zh-CN: '播放进度'
	String get progress => '播放进度';

	/// zh-CN: '歌词'
	String get lyrics => '歌词';

	/// zh-CN: '这首歌还没有歌词。'
	String get lyricsEmpty => '这首歌还没有歌词。';

	/// zh-CN: '打开播放页'
	String get openPlayer => '打开播放页';

	/// zh-CN: '来自 {source}'
	String playingSource({required Object source}) => '来自 ${source}';

	/// zh-CN: '加载更多'
	String get loadMore => '加载更多';

	/// zh-CN: '清空最近播放'
	String get clearRecent => '清空最近播放';

	/// zh-CN: '更多操作'
	String get moreActions => '更多操作';

	/// zh-CN: '下一首播放'
	String get playNext => '下一首播放';

	/// zh-CN: '加入歌单'
	String get addToPlaylist => '加入歌单';

	/// zh-CN: '下载'
	String get download => '下载';

	/// zh-CN: '歌曲详情'
	String get songDetails => '歌曲详情';

	/// zh-CN: '复制歌名'
	String get copySongName => '复制歌名';

	/// zh-CN: '已复制歌名'
	String get copiedSongName => '已复制歌名';

	/// zh-CN: '歌名'
	String get songDetailTitle => '歌名';

	/// zh-CN: '歌手'
	String get songDetailArtist => '歌手';

	/// zh-CN: '专辑'
	String get songDetailAlbum => '专辑';

	/// zh-CN: '时长'
	String get songDetailDuration => '时长';

	/// zh-CN: '来源'
	String get songDetailSource => '来源';

	/// zh-CN: '文件'
	String get songDetailPath => '文件';

	/// zh-CN: '—'
	String get songDetailEmpty => '—';

	/// zh-CN: '不喜欢'
	String get dislike => '不喜欢';

	/// zh-CN: '取消不喜欢'
	String get undislike => '取消不喜欢';

	/// zh-CN: '已加入不喜欢规则，以后自动跳过'
	String get disliked => '已加入不喜欢规则，以后自动跳过';

	/// zh-CN: '已取消不喜欢'
	String get undisliked => '已取消不喜欢';

	/// zh-CN: '不喜欢规则 · {count} 条'
	String dislikeRules({required Object count}) => '不喜欢规则 · ${count} 条';

	/// zh-CN: '这些歌曲出现在播放队列里时会自动跳过。'
	String get dislikeRulesDesc => '这些歌曲出现在播放队列里时会自动跳过。';

	/// zh-CN: '清除规则'
	String get dislikeRulesClear => '清除规则';

	/// zh-CN: '已清除不喜欢规则'
	String get dislikeRulesCleared => '已清除不喜欢规则';

	/// zh-CN: '下载全部'
	String get downloadAll => '下载全部';

	/// zh-CN: '已加入 {count} 首到下载队列'
	String downloadAllQueued({required Object count}) => '已加入 ${count} 首到下载队列';

	/// zh-CN: '上移'
	String get moveUp => '上移';

	/// zh-CN: '下移'
	String get moveDown => '下移';

	/// zh-CN: '全部播放'
	String get playAll => '全部播放';

	/// zh-CN: '最近搜索'
	String get searchHistory => '最近搜索';

	/// zh-CN: '清空'
	String get searchHistoryClear => '清空';

	/// zh-CN: '删除这条搜索'
	String get searchHistoryRemove => '删除这条搜索';

	/// zh-CN: '热门搜索'
	String get searchHot => '热门搜索';

	/// zh-CN: '搜索页为空时显示音源提供的热门搜索词。'
	String get searchHotDesc => '搜索页为空时显示音源提供的热门搜索词。';

	/// zh-CN: '热门搜索加载失败'
	String get searchHotFailed => '热门搜索加载失败';

	/// zh-CN: '新建歌单'
	String get playlistCreate => '新建歌单';

	/// zh-CN: '新建歌单'
	String get playlistCreateTitle => '新建歌单';

	/// zh-CN: '添加本地歌曲'
	String get playlistAddLocal => '添加本地歌曲';

	/// zh-CN: '选择歌曲文件'
	String get playlistAddLocalDesc => '选择歌曲文件';

	/// zh-CN: '已添加 {count} 首歌曲'
	String playlistAddLocalDone({required Object count}) => '已添加 ${count} 首歌曲';

	/// zh-CN: '所选歌曲都已在列表中'
	String get playlistAddLocalNone => '所选歌曲都已在列表中';

	/// zh-CN: '歌单名称'
	String get playlistName => '歌单名称';

	/// zh-CN: '给歌单起个名字'
	String get playlistNameHint => '给歌单起个名字';

	/// zh-CN: '重命名'
	String get playlistRename => '重命名';

	/// zh-CN: '重命名歌单'
	String get playlistRenameTitle => '重命名歌单';

	/// zh-CN: '删除歌单'
	String get playlistDelete => '删除歌单';

	/// zh-CN: '删除「{name}」？'
	String playlistDeleteTitle({required Object name}) => '删除「${name}」？';

	/// zh-CN: '歌单会从列表里移除，歌曲本身不会删除。'
	String get playlistDeleteDesc => '歌单会从列表里移除，歌曲本身不会删除。';

	/// zh-CN: '清空歌单'
	String get playlistClear => '清空歌单';

	/// zh-CN: '歌单还是空的'
	String get playlistEmptyTitle => '歌单还是空的';

	/// zh-CN: '在歌曲行的「更多」里把歌加进来。'
	String get playlistEmptyDescription => '在歌曲行的「更多」里把歌加进来。';

	/// zh-CN: '已加入「{name}」'
	String playlistAdded({required Object name}) => '已加入「${name}」';

	/// zh-CN: '已加入 {count} 首到「{name}」'
	String playlistAddedCount({required Object count, required Object name}) => '已加入 ${count} 首到「${name}」';

	/// zh-CN: '「{name}」里已经有这首歌'
	String playlistAlreadyIn({required Object name}) => '「${name}」里已经有这首歌';

	/// zh-CN: '{count} 个歌单'
	String playlistsCount({required Object count}) => '${count} 个歌单';

	/// zh-CN: '导入歌单'
	String get playlistImport => '导入歌单';

	/// zh-CN: '已导入「{name}」'
	String playlistImportDone({required Object name}) => '已导入「${name}」';

	/// zh-CN: '导入失败：{error}'
	String playlistImportFailed({required Object error}) => '导入失败：${error}';

	/// zh-CN: '文件里没有可用的歌曲'
	String get playlistImportInvalid => '文件里没有可用的歌曲';

	/// zh-CN: '导出歌单'
	String get playlistExport => '导出歌单';

	/// zh-CN: '已导出到 {path}'
	String playlistExportDone({required Object path}) => '已导出到 ${path}';

	/// zh-CN: '导出失败：{error}'
	String playlistExportFailed({required Object error}) => '导出失败：${error}';

	/// zh-CN: '排序'
	String get playlistSort => '排序';

	/// zh-CN: '按歌名'
	String get sortByTitle => '按歌名';

	/// zh-CN: '按歌手'
	String get sortByArtist => '按歌手';

	/// zh-CN: '按专辑'
	String get sortByAlbum => '按专辑';

	/// zh-CN: '按时长'
	String get sortByDuration => '按时长';

	/// zh-CN: '随机排序'
	String get sortByShuffle => '随机排序';

	/// zh-CN: '选择'
	String get selectionStart => '选择';

	/// zh-CN: '取消选择'
	String get selectionCancel => '取消选择';

	/// zh-CN: '已选 {count} 首'
	String selectionCount({required Object count}) => '已选 ${count} 首';

	/// zh-CN: '全选'
	String get selectionAll => '全选';

	/// zh-CN: '单选'
	String get selectionSingle => '单选';

	/// zh-CN: '区间'
	String get selectionRange => '区间';

	/// zh-CN: '反选'
	String get selectionInvert => '反选';

	/// zh-CN: '下载'
	String get selectionDownload => '下载';

	/// zh-CN: '移除'
	String get selectionRemove => '移除';

	/// zh-CN: '已移除 {count} 首'
	String selectionRemoveDone({required Object count}) => '已移除 ${count} 首';

	/// zh-CN: '正在下载 {count} 首'
	String downloadsActive({required Object count}) => '正在下载 ${count} 首';

	/// zh-CN: '已加入下载：{title}'
	String downloadQueued({required Object title}) => '已加入下载：${title}';

	/// zh-CN: '这首歌已经在下载队列里'
	String get downloadDuplicate => '这首歌已经在下载队列里';

	/// zh-CN: '这首歌没有可下载的音源（本地文件或当前音源未覆盖）'
	String get downloadUnsupported => '这首歌没有可下载的音源（本地文件或当前音源未覆盖）';

	/// zh-CN: '下载失败：{error}'
	String downloadFailed({required Object error}) => '下载失败：${error}';

	/// zh-CN: '下载文件保存在共享下载目录；队列支持暂停、续传和失败重试。'
	String get downloadHint => '下载文件保存在共享下载目录；队列支持暂停、续传和失败重试。';

	/// zh-CN: '下载目录'
	String get downloadDirectory => '下载目录';

	/// zh-CN: '使用默认目录'
	String get downloadDirectoryDefault => '使用默认目录';

	/// zh-CN: '回到应用默认的下载文件夹。'
	String get downloadDirectoryDefaultDesc => '回到应用默认的下载文件夹。';

	/// zh-CN: '下载目录已更新'
	String get downloadDirectoryUpdated => '下载目录已更新';

	/// zh-CN: '无法写入这个目录'
	String get downloadDirectoryFailed => '无法写入这个目录';

	/// zh-CN: '下载格式'
	String get downloadType => '下载格式';

	/// zh-CN: '原格式会尽量保留音源容器；转码需要 ffmpeg。'
	String get downloadTypeDesc => '原格式会尽量保留音源容器；转码需要 ffmpeg。';

	/// zh-CN: '原格式'
	String get downloadTypeOriginal => '原格式';

	/// zh-CN: 'MP3'
	String get downloadTypeMp3 => 'MP3';

	/// zh-CN: 'M4A'
	String get downloadTypeM4a => 'M4A';

	/// zh-CN: 'FLAC'
	String get downloadTypeFlac => 'FLAC';

	/// zh-CN: 'OGG'
	String get downloadTypeOgg => 'OGG';

	/// zh-CN: 'WAV'
	String get downloadTypeWav => 'WAV';

	/// zh-CN: '文件名格式'
	String get downloadPattern => '文件名格式';

	/// zh-CN: '占位符（花括号）：title、artist、album、quality、source、list、index。'
	String get downloadPatternHint => '占位符（花括号）：title、artist、album、quality、source、list、index。';

	/// zh-CN: '编辑'
	String get downloadPatternEdit => '编辑';

	/// zh-CN: '嵌入封面'
	String get downloadEmbedCover => '嵌入封面';

	/// zh-CN: '把歌曲封面写入音频标签。'
	String get downloadEmbedCoverDesc => '把歌曲封面写入音频标签。';

	/// zh-CN: '嵌入歌词'
	String get downloadEmbedLyric => '嵌入歌词';

	/// zh-CN: '把歌词写入音频标签，随文件一起播放。'
	String get downloadEmbedLyricDesc => '把歌词写入音频标签，随文件一起播放。';

	/// zh-CN: '歌词包含翻译'
	String get downloadIncludeTranslation => '歌词包含翻译';

	/// zh-CN: '下载的歌词文件与内嵌歌词一并写入翻译。'
	String get downloadIncludeTranslationDesc => '下载的歌词文件与内嵌歌词一并写入翻译。';

	/// zh-CN: '歌词包含音译'
	String get downloadIncludeRomanization => '歌词包含音译';

	/// zh-CN: '下载的歌词文件与内嵌歌词一并写入音译。'
	String get downloadIncludeRomanizationDesc => '下载的歌词文件与内嵌歌词一并写入音译。';

	/// zh-CN: '保存歌词文件'
	String get downloadWriteLyric => '保存歌词文件';

	/// zh-CN: '在音频文件旁写一个同名 .lrc。'
	String get downloadWriteLyricDesc => '在音频文件旁写一个同名 .lrc。';

	/// zh-CN: '跳过已存在文件'
	String get downloadSkipExisting => '跳过已存在文件';

	/// zh-CN: '目标文件已存在时不再下载。'
	String get downloadSkipExistingDesc => '目标文件已存在时不再下载。';

	/// zh-CN: '按歌单分文件夹'
	String get downloadGroupByList => '按歌单分文件夹';

	/// zh-CN: '从歌单下载时，文件保存到以歌单命名的子文件夹。'
	String get downloadGroupByListDesc => '从歌单下载时，文件保存到以歌单命名的子文件夹。';

	/// zh-CN: '同时下载数'
	String get downloadMaxConcurrent => '同时下载数';

	/// zh-CN: '同时进行的下载任务数量（1–5），修改后立即生效。'
	String get downloadMaxConcurrentDesc => '同时进行的下载任务数量（1–5），修改后立即生效。';

	/// zh-CN: '排队中'
	String get downloadStatusQueued => '排队中';

	/// zh-CN: '下载中'
	String get downloadStatusRunning => '下载中';

	/// zh-CN: '已暂停'
	String get downloadStatusPaused => '已暂停';

	/// zh-CN: '写入标签'
	String get downloadStatusProcessing => '写入标签';

	/// zh-CN: '已完成'
	String get downloadStatusCompleted => '已完成';

	/// zh-CN: '已跳过'
	String get downloadStatusSkipped => '已跳过';

	/// zh-CN: '下载失败'
	String get downloadStatusFailed => '下载失败';

	/// zh-CN: '已取消'
	String get downloadStatusCancelled => '已取消';

	/// zh-CN: '全部暂停'
	String get downloadPauseAll => '全部暂停';

	/// zh-CN: '全部继续'
	String get downloadResumeAll => '全部继续';

	/// zh-CN: '清除已完成'
	String get downloadClearFinished => '清除已完成';

	/// zh-CN: '下载进度'
	String get downloadProgress => '下载进度';

	/// zh-CN: '重试'
	String get downloadRetry => '重试';

	/// zh-CN: '移除记录'
	String get downloadRemove => '移除记录';

	/// zh-CN: '继续'
	String get downloadResume => '继续';

	/// zh-CN: '暂停'
	String get downloadPause => '暂停';

	/// zh-CN: '取消'
	String get downloadCancel => '取消';

	/// zh-CN: '还没有下载任务'
	String get downloadsEmptyTitle => '还没有下载任务';

	/// zh-CN: '在歌曲行的「更多」里下载，文件会保存到 {directory}。'
	String downloadsEmptyDescription({required Object directory}) => '在歌曲行的「更多」里下载，文件会保存到 ${directory}。';

	/// zh-CN: '添加文件夹'
	String get localAddFolder => '添加文件夹';

	/// zh-CN: '添加本机音乐文件夹，扫描后会像在线歌曲一样播放。'
	String get localHint => '添加本机音乐文件夹，扫描后会像在线歌曲一样播放。';

	/// zh-CN: '{count} 个文件'
	String localFiles({required Object count}) => '${count} 个文件';

	/// zh-CN: '重新扫描'
	String get localRescan => '重新扫描';

	/// zh-CN: '音乐文件夹'
	String get localFolders => '音乐文件夹';

	/// zh-CN: '移除文件夹'
	String get localRemoveFolder => '移除文件夹';

	/// zh-CN: '扫描失败'
	String get localFailed => '扫描失败';

	/// zh-CN: '还没有本地音乐'
	String get localEmptyTitle => '还没有本地音乐';

	/// zh-CN: '添加一个存放音频文件的文件夹开始扫描。'
	String get localEmptyDescription => '添加一个存放音频文件的文件夹开始扫描。';

	/// zh-CN: '无法添加文件夹：{error}'
	String localFolderFailed({required Object error}) => '无法添加文件夹：${error}';

	/// zh-CN: '播放速度'
	String get playbackRate => '播放速度';

	/// zh-CN: '音调补偿'
	String get preservesPitch => '音调补偿';

	/// zh-CN: '睡眠定时'
	String get sleepTimer => '睡眠定时';

	/// zh-CN: '关闭'
	String get sleepOff => '关闭';

	/// zh-CN: '{count} 分钟'
	String sleepMinutes({required Object count}) => '${count} 分钟';

	/// zh-CN: '播完当前歌曲'
	String get sleepAfterCurrent => '播完当前歌曲';

	/// zh-CN: '{value} 后暂停'
	String sleepRemaining({required Object value}) => '${value} 后暂停';

	/// zh-CN: '歌词延迟'
	String get lyricOffset => '歌词延迟';

	/// zh-CN: '正值让歌词更晚出现。'
	String get lyricOffsetDesc => '正值让歌词更晚出现。';

	/// zh-CN: '不偏移'
	String get lyricOffsetReset => '不偏移';

	/// zh-CN: '显示翻译'
	String get lyricTranslation => '显示翻译';

	/// zh-CN: '歌词带翻译时一并显示。'
	String get lyricTranslationDesc => '歌词带翻译时一并显示。';

	/// zh-CN: '显示音译'
	String get lyricRomanization => '显示音译';

	/// zh-CN: '歌词带音译或罗马音时一并显示。'
	String get lyricRomanizationDesc => '歌词带音译或罗马音时一并显示。';

	/// zh-CN: '翻译/音译顺序'
	String get lyricSwapSecondary => '翻译/音译顺序';

	/// zh-CN: '交换翻译与音译在歌词行中的先后顺序。'
	String get lyricSwapSecondaryDesc => '交换翻译与音译在歌词行中的先后顺序。';

	/// zh-CN: '简体转繁体'
	String get lyricTraditionalize => '简体转繁体';

	/// zh-CN: '把歌词文本改写为繁体中文。'
	String get lyricTraditionalizeDesc => '把歌词文本改写为繁体中文。';

	/// zh-CN: '逐字歌词'
	String get lyricWordTimed => '逐字歌词';

	/// zh-CN: '平台提供逐字时间轴时按字高亮演唱。'
	String get lyricWordTimedDesc => '平台提供逐字时间轴时按字高亮演唱。';

	/// zh-CN: '歌词字号'
	String get lyricFontScale => '歌词字号';

	/// zh-CN: '播放页歌词的缩放比例（100%–200%）。'
	String get lyricFontScaleDesc => '播放页歌词的缩放比例（100%–200%）。';

	/// zh-CN: '缩小字号'
	String get lyricFontSmaller => '缩小字号';

	/// zh-CN: '放大字号'
	String get lyricFontLarger => '放大字号';

	/// zh-CN: '重置字号'
	String get lyricFontReset => '重置字号';

	/// zh-CN: '歌词对齐'
	String get lyricAlignment => '歌词对齐';

	/// zh-CN: '播放页歌词在面板内的对齐方式。'
	String get lyricAlignmentDesc => '播放页歌词在面板内的对齐方式。';

	/// zh-CN: '放大当前行'
	String get lyricZoomActive => '放大当前行';

	/// zh-CN: '正在唱的一句歌词略大，便于跟唱。'
	String get lyricZoomActiveDesc => '正在唱的一句歌词略大，便于跟唱。';

	/// zh-CN: '显示播放进度'
	String get lyricProgress => '显示播放进度';

	/// zh-CN: '在歌词面板上方显示歌曲的播放进度。'
	String get lyricProgressDesc => '在歌词面板上方显示歌曲的播放进度。';

	/// zh-CN: '拖拽歌词调整进度'
	String get lyricDragSeek => '拖拽歌词调整进度';

	/// zh-CN: '拖动歌词面板选句，三秒无操作回到当前句。'
	String get lyricDragSeekDesc => '拖动歌词面板选句，三秒无操作回到当前句。';

	/// zh-CN: '从此句播放'
	String get lyricScrubPlay => '从此句播放';

	/// zh-CN: '歌词显示与延迟全局生效；桌面歌词在设置或播放页菜单打开。'
	String get lyricHint => '歌词显示与延迟全局生效；桌面歌词在设置或播放页菜单打开。';

	/// zh-CN: '桌面歌词'
	String get desktopLyrics => '桌面歌词';

	/// zh-CN: '桌面歌词已开启'
	String get desktopLyricsOn => '桌面歌词已开启';

	/// zh-CN: '桌面歌词已关闭'
	String get desktopLyricsOff => '桌面歌词已关闭';

	/// zh-CN: '当前平台没有桌面歌词窗口或未授权'
	String get desktopLyricsUnavailable => '当前平台没有桌面歌词窗口或未授权';

	/// zh-CN: '桌面歌词是可拖动、可锁定的悬浮窗；Android 需悬浮窗权限。'
	String get desktopLyricHint => '桌面歌词是可拖动、可锁定的悬浮窗；Android 需悬浮窗权限。';

	/// zh-CN: '在桌面上悬浮显示当前歌词；关闭后保留下面的样式。'
	String get desktopLyricEnableDesc => '在桌面上悬浮显示当前歌词；关闭后保留下面的样式。';

	/// zh-CN: '锁定歌词'
	String get desktopLyricLock => '锁定歌词';

	/// zh-CN: '锁定后鼠标点击穿过歌词窗口，不会挡住下面的程序。'
	String get desktopLyricLockDesc => '锁定后鼠标点击穿过歌词窗口，不会挡住下面的程序。';

	/// zh-CN: '样式'
	String get desktopLyricStyleSection => '样式';

	/// zh-CN: '字号'
	String get desktopLyricFontSize => '字号';

	/// zh-CN: '桌面歌词的字体大小。'
	String get desktopLyricFontSizeDesc => '桌面歌词的字体大小。';

	/// zh-CN: '不透明度'
	String get desktopLyricOpacity => '不透明度';

	/// zh-CN: '桌面歌词窗口的整体不透明度。'
	String get desktopLyricOpacityDesc => '桌面歌词窗口的整体不透明度。';

	/// zh-CN: '文字颜色'
	String get desktopLyricTextColor => '文字颜色';

	/// zh-CN: '桌面歌词的主文字颜色。'
	String get desktopLyricTextColorDesc => '桌面歌词的主文字颜色。';

	/// zh-CN: '描边颜色'
	String get desktopLyricStrokeColor => '描边颜色';

	/// zh-CN: '文字描边的颜色；描边宽度为 0 时不起作用。'
	String get desktopLyricStrokeColorDesc => '文字描边的颜色；描边宽度为 0 时不起作用。';

	/// zh-CN: '描边宽度'
	String get desktopLyricStrokeWidth => '描边宽度';

	/// zh-CN: '文字描边的粗细，0 表示不描边。'
	String get desktopLyricStrokeWidthDesc => '文字描边的粗细，0 表示不描边。';

	/// zh-CN: '无'
	String get desktopLyricStrokeNone => '无';

	/// zh-CN: '黑色'
	String get desktopLyricColorBlack => '黑色';

	/// zh-CN: '灰色'
	String get desktopLyricColorGray => '灰色';

	/// zh-CN: '对齐方式'
	String get desktopLyricAlignment => '对齐方式';

	/// zh-CN: '歌词在窗口内的水平对齐。'
	String get desktopLyricAlignmentDesc => '歌词在窗口内的水平对齐。';

	/// zh-CN: '左对齐'
	String get desktopLyricAlignLeft => '左对齐';

	/// zh-CN: '居中'
	String get desktopLyricAlignCenter => '居中';

	/// zh-CN: '右对齐'
	String get desktopLyricAlignRight => '右对齐';

	/// zh-CN: '白色'
	String get desktopLyricColorWhite => '白色';

	/// zh-CN: '黄色'
	String get desktopLyricColorYellow => '黄色';

	/// zh-CN: '青色'
	String get desktopLyricColorCyan => '青色';

	/// zh-CN: '粉色'
	String get desktopLyricColorPink => '粉色';

	/// zh-CN: '绿色'
	String get desktopLyricColorGreen => '绿色';

	/// zh-CN: '橙色'
	String get desktopLyricColorOrange => '橙色';

	/// zh-CN: '清空播放队列'
	String get clearQueue => '清空播放队列';

	/// zh-CN: '导出歌词'
	String get exportLyric => '导出歌词';

	/// zh-CN: '关联本地歌词'
	String get associateLyric => '关联本地歌词';

	/// zh-CN: '已关联歌词'
	String get associateLyricDone => '已关联歌词';

	/// zh-CN: '关联失败：文件里没有可用的歌词'
	String get associateLyricFailed => '关联失败：文件里没有可用的歌词';

	/// zh-CN: '取消关联歌词'
	String get lyricOverrideRemove => '取消关联歌词';

	/// zh-CN: '在线搜索歌词'
	String get lyricSearch => '在线搜索歌词';

	/// zh-CN: '为「{title}」搜索歌词'
	String lyricSearchFor({required Object title}) => '为「${title}」搜索歌词';

	/// zh-CN: '输入歌名，或「歌手 - 歌名」'
	String get lyricSearchHint => '输入歌名，或「歌手 - 歌名」';

	/// zh-CN: '搜索'
	String get lyricSearchAction => '搜索';

	/// zh-CN: '没有找到匹配的歌曲'
	String get lyricSearchEmpty => '没有找到匹配的歌曲';

	/// zh-CN: '搜索失败：{error}'
	String lyricSearchFailed({required Object error}) => '搜索失败：${error}';

	/// zh-CN: '这首歌没有可用的歌词'
	String get lyricSearchNoLyric => '这首歌没有可用的歌词';

	/// zh-CN: '已应用「{title}」的歌词'
	String lyricSearchApplied({required Object title}) => '已应用「${title}」的歌词';

	/// zh-CN: '评论'
	String get comments => '评论';

	/// zh-CN: '热门'
	String get commentsHot => '热门';

	/// zh-CN: '最新'
	String get commentsNew => '最新';

	/// zh-CN: '还没有评论'
	String get commentsEmpty => '还没有评论';

	/// zh-CN: '评论加载失败：{error}'
	String commentsFailed({required Object error}) => '评论加载失败：${error}';

	/// zh-CN: '{count} 条评论'
	String commentsCount({required Object count}) => '${count} 条评论';

	/// zh-CN: '{count} 条回复'
	String commentsReplies({required Object count}) => '${count} 条回复';

	/// zh-CN: '歌词已保存到 {path}'
	String exportLyricDone({required Object path}) => '歌词已保存到 ${path}';

	/// zh-CN: '歌词导出失败：{error}'
	String exportLyricFailed({required Object error}) => '歌词导出失败：${error}';

	/// zh-CN: '音效'
	String get eqSection => '音效';

	/// zh-CN: '启用音效'
	String get eqEnabled => '启用音效';

	/// zh-CN: '关闭时音频完全不经过处理，频段参数保持不变。'
	String get eqEnabledDesc => '关闭时音频完全不经过处理，频段参数保持不变。';

	/// zh-CN: '音效预设'
	String get eqPreset => '音效预设';

	/// zh-CN: '预设代表目标听感，不保证不同耳机音箱上效果一致。'
	String get eqPresetDesc => '预设代表目标听感，不保证不同耳机音箱上效果一致。';

	/// zh-CN: '自定义'
	String get eqPresetCustom => '自定义';

	/// zh-CN: '预放增益'
	String get eqPreamp => '预放增益';

	/// zh-CN: '作用于频段之前；曲线削波时先降这里。'
	String get eqPreampDesc => '作用于频段之前；曲线削波时先降这里。';

	/// zh-CN: '启用快捷键'
	String get hkEnable => '启用快捷键';

	/// zh-CN: '应用窗口内的传输与音量快捷键。'
	String get hkEnableDesc => '应用窗口内的传输与音量快捷键。';

	/// zh-CN: '未设置'
	String get hkUnset => '未设置';

	/// zh-CN: '按下新组合，Esc 取消'
	String get hkPressNew => '按下新组合，Esc 取消';

	/// zh-CN: '恢复默认'
	String get hkReset => '恢复默认';

	/// zh-CN: '还原默认组合。'
	String get hkResetDesc => '还原默认组合。';

	/// zh-CN: '重置'
	String get eqReset => '重置';

	/// zh-CN: '仅应用窗口内生效；系统级全局注册需平台层支持，尚未接入。'
	String get hkNote => '仅应用窗口内生效；系统级全局注册需平台层支持，尚未接入。';

	/// zh-CN: '播放 / 暂停'
	String get hkTogglePlay => '播放 / 暂停';

	/// zh-CN: '下一首'
	String get hkNext => '下一首';

	/// zh-CN: '上一首'
	String get hkPrev => '上一首';

	/// zh-CN: '快退 5 秒'
	String get hkSeekBackward => '快退 5 秒';

	/// zh-CN: '快进 5 秒'
	String get hkSeekForward => '快进 5 秒';

	/// zh-CN: '音量加'
	String get hkVolumeUp => '音量加';

	/// zh-CN: '音量减'
	String get hkVolumeDown => '音量减';

	/// zh-CN: '静音'
	String get hkVolumeMute => '静音';

	/// zh-CN: '收藏'
	String get hkMusicLove => '收藏';

	/// zh-CN: '取消收藏'
	String get hkMusicUnlove => '取消收藏';

	/// zh-CN: '不喜欢'
	String get hkMusicDislike => '不喜欢';

	/// zh-CN: '所有频段与预放增益归零。'
	String get eqResetDesc => '所有频段与预放增益归零。';

	/// zh-CN: '十段均衡器'
	String get eqEditorTitle => '十段均衡器';

	/// zh-CN: '拖动滑块调整频段；曲线实时更新并即时应用到播放。'
	String get eqHint => '拖动滑块调整频段；曲线实时更新并即时应用到播放。';

	/// zh-CN: '频响曲线为理论预测；实际音频以这组参数生成的 FFmpeg 滤镜链为准。'
	String get eqChainNote => '频响曲线为理论预测；实际音频以这组参数生成的 FFmpeg 滤镜链为准。';

	/// zh-CN: '流行'
	String get eqPresetPop => '流行';

	/// zh-CN: '摇滚'
	String get eqPresetRock => '摇滚';

	/// zh-CN: '古典'
	String get eqPresetClassical => '古典';

	/// zh-CN: '爵士'
	String get eqPresetJazz => '爵士';

	/// zh-CN: '电子'
	String get eqPresetElectronic => '电子';

	/// zh-CN: '重低音'
	String get eqPresetBass => '重低音';

	/// zh-CN: '清晰人声'
	String get eqPresetVocal => '清晰人声';

	/// zh-CN: '现场感'
	String get eqPresetLive => '现场感';

	/// zh-CN: '平直响应'
	String get eqPresetFlat => '平直响应';

	/// zh-CN: '引擎拒绝了当前音效链——声音未经过处理。请先关闭效果再尝试较小的组合。'
	String get eqApplyFailed => '引擎拒绝了当前音效链——声音未经过处理。请先关闭效果再尝试较小的组合。';

	/// zh-CN: '增强音效'
	String get eqFxSection => '增强音效';

	/// zh-CN: '注意：'
	String get eqFxCostPrefix => '注意：';

	/// zh-CN: '增加延迟'
	String get eqFxCostLatency => '增加延迟';

	/// zh-CN: '仅立体声输出有效'
	String get eqFxCostStereo => '仅立体声输出有效';

	/// zh-CN: '音量均衡'
	String get eqFxLoudness => '音量均衡';

	/// zh-CN: 'loudnorm 让不同曲目与来源的响度保持一致。'
	String get eqFxLoudnessDesc => 'loudnorm 让不同曲目与来源的响度保持一致。';

	/// zh-CN: '低音增强'
	String get eqFxBass => '低音增强';

	/// zh-CN: 'bass 低架滤波，105 Hz 以下最多 +8 dB。'
	String get eqFxBassDesc => 'bass 低架滤波，105 Hz 以下最多 +8 dB。';

	/// zh-CN: '人声增强'
	String get eqFxVocal => '人声增强';

	/// zh-CN: '3 kHz 人声凸起，同时收 300 Hz 浑浊段。'
	String get eqFxVocalDesc => '3 kHz 人声凸起，同时收 300 Hz 浑浊段。';

	/// zh-CN: '立体声拓宽'
	String get eqFxWidth => '立体声拓宽';

	/// zh-CN: 'stereotools 抬高侧声道电平，中央声像不动。'
	String get eqFxWidthDesc => 'stereotools 抬高侧声道电平，中央声像不动。';

	/// zh-CN: '环境声场'
	String get eqFxSurround => '环境声场';

	/// zh-CN: 'haas 交叉延迟伪环绕。'
	String get eqFxSurroundDesc => 'haas 交叉延迟伪环绕。';

	/// zh-CN: '动态压缩与限幅'
	String get eqFxDynamics => '动态压缩与限幅';

	/// zh-CN: 'acompressor 平滑峰值，alimiter 守住输出上限。'
	String get eqFxDynamicsDesc => 'acompressor 平滑峰值，alimiter 守住输出上限。';

	/// zh-CN: '混响'
	String get eqFxReverb => '混响';

	/// zh-CN: 'aecho 回声叠加，铺出房间混响尾音。'
	String get eqFxReverbDesc => 'aecho 回声叠加，铺出房间混响尾音。';

	/// zh-CN: '3D 环绕'
	String get eqFxPanner => '3D 环绕';

	/// zh-CN: 'apulsator 声像绕场旋转，模拟现场包围感。'
	String get eqFxPannerDesc => 'apulsator 声像绕场旋转，模拟现场包围感。';

	/// zh-CN: '环绕速度'
	String get eqFxPannerSpeed => '环绕速度';

	/// zh-CN: '升降调'
	String get eqFxPitch => '升降调';

	/// zh-CN: 'asetrate 升降音高，atempo 补回节奏。'
	String get eqFxPitchDesc => 'asetrate 升降音高，atempo 补回节奏。';

	/// zh-CN: '响度电平表'
	String get eqMeterTitle => '响度电平表';

	/// zh-CN: '响度探针'
	String get eqAnalysis => '响度探针';

	/// zh-CN: '在链路中运行 EBU R128 探针，不改变声音本身'
	String get eqAnalysisDesc => '在链路中运行 EBU R128 探针，不改变声音本身';

	/// zh-CN: '响度表（M=400ms 瞬时，S=3s 短期），不是 FFT 频谱——mpv 不提供原始频谱。'
	String get eqMeterNote => '响度表（M=400ms 瞬时，S=3s 短期），不是 FFT 频谱——mpv 不提供原始频谱。';

	/// zh-CN: '参数均衡器'
	String get eqNodesTitle => '参数均衡器';

	/// zh-CN: '添加节点'
	String get eqNodesAdd => '添加节点';

	/// zh-CN: '频率'
	String get eqNodeFrequency => '频率';

	/// zh-CN: 'Q 值'
	String get eqNodeQ => 'Q 值';

	/// zh-CN: '增益'
	String get eqNodeGain => '增益';

	/// zh-CN: 'A/B 对比'
	String get eqCompareTitle => 'A/B 对比';

	/// zh-CN: '按住试听原始声音'
	String get eqCompare => '按住试听原始声音';

	/// zh-CN: '正在播放原始声音——松开恢复'
	String get eqCompareHeld => '正在播放原始声音——松开恢复';

	/// zh-CN: '我的歌单'
	String get songlistTabMine => '我的歌单';

	/// zh-CN: '在线歌单'
	String get songlistTabOnline => '在线歌单';

	/// zh-CN: '当前音乐源不支持在线歌单'
	String get onlineUnsupported => '当前音乐源不支持在线歌单';

	/// zh-CN: '该分类下暂无歌单'
	String get onlineEmpty => '该分类下暂无歌单';

	/// zh-CN: '加载更多'
	String get onlineLoadMore => '加载更多';

	/// zh-CN: '歌单加载失败'
	String get onlineLoadFailed => '歌单加载失败';

	/// zh-CN: '导入歌单'
	String get onlineImport => '导入歌单';

	/// zh-CN: '已导入 {count} 首到「{name}」'
	String onlineImported({required Object count, required Object name}) => '已导入 ${count} 首到「${name}」';

	/// zh-CN: '同步服务端'
	String get syncHost => '同步服务端';

	/// zh-CN: 'lx-music 同步服务地址，例如 http://192.168.1.10:23332'
	String get syncHostHint => 'lx-music 同步服务地址，例如 http://192.168.1.10:23332';

	/// zh-CN: '修改'
	String get syncEdit => '修改';

	/// zh-CN: '连接码'
	String get syncAuthCode => '连接码';

	/// zh-CN: '服务端显示的连接码'
	String get syncAuthCodeHint => '服务端显示的连接码';

	/// zh-CN: '同步模式'
	String get syncMode => '同步模式';

	/// zh-CN: '连接'
	String get syncConnect => '连接';

	/// zh-CN: '断开'
	String get syncDisconnect => '断开';

	/// zh-CN: '已连接'
	String get syncStatusConnected => '已连接';

	/// zh-CN: '连接中'
	String get syncStatusConnecting => '连接中';

	/// zh-CN: '连接失败'
	String get syncStatusFailed => '连接失败';

	/// zh-CN: '未连接'
	String get syncStatusIdle => '未连接';

	/// zh-CN: '连接后拉取服务端歌单并推送本地改动。'
	String get syncStatusHint => '连接后拉取服务端歌单并推送本地改动。';

	/// zh-CN: '清除授权'
	String get syncForgetKey => '清除授权';

	/// zh-CN: '删除已保存的密钥，下次连接用连接码重新授权。'
	String get syncForgetKeyDesc => '删除已保存的密钥，下次连接用连接码重新授权。';

	/// zh-CN: '与 lx-music 桌面端同步：试听、收藏与自建歌单，服务端按所选模式合并。'
	String get syncNote => '与 lx-music 桌面端同步：试听、收藏与自建歌单，服务端按所选模式合并。';

	/// zh-CN: '合并（本地优先）'
	String get syncModeMergeLocalRemote => '合并（本地优先）';

	/// zh-CN: '合并（远端优先）'
	String get syncModeMergeRemoteLocal => '合并（远端优先）';

	/// zh-CN: '以本地覆盖远端'
	String get syncModeOverwriteLocalRemote => '以本地覆盖远端';

	/// zh-CN: '以远端覆盖本地'
	String get syncModeOverwriteRemoteLocal => '以远端覆盖本地';

	/// zh-CN: '仅保留本地'
	String get syncModeOverwriteLocalRemoteFull => '仅保留本地';

	/// zh-CN: '仅保留远端'
	String get syncModeOverwriteRemoteLocalFull => '仅保留远端';

	/// zh-CN: '内置音源库'
	String get catalogSection => '内置音源库';

	/// zh-CN: '来自社区合集 pdone/lx-music-source，一键拉取最新脚本，走设置的 GitHub 加速。'
	String get catalogHint => '来自社区合集 pdone/lx-music-source，一键拉取最新脚本，走设置的 GitHub 加速。';

	/// zh-CN: '导入'
	String get catalogImport => '导入';

	/// zh-CN: '已导入'
	String get catalogImported => '已导入';

	/// zh-CN: '音源脚本下载失败：raw 源与镜像都不可达'
	String get catalogFetchFailed => '音源脚本下载失败：raw 源与镜像都不可达';

	/// zh-CN: '重复歌曲'
	String get duplicateTracks => '重复歌曲';

	/// zh-CN: '发现 {count} 首重复歌曲'
	String duplicatesFound({required Object count}) => '发现 ${count} 首重复歌曲';

	/// zh-CN: '没有发现重复的歌曲'
	String get duplicatesNone => '没有发现重复的歌曲';

	/// zh-CN: '移除重复（保留第一首）'
	String get duplicatesRemoveAll => '移除重复（保留第一首）';

	/// zh-CN: '搜索列表内歌曲'
	String get listSearch => '搜索列表内歌曲';

	/// zh-CN: '没有找到匹配的歌曲'
	String get listSearchEmpty => '没有找到匹配的歌曲';

	/// zh-CN: '歌曲换源'
	String get toggleSource => '歌曲换源';

	/// zh-CN: '已换源，之后都用新源播放这首歌'
	String get toggleSourceDone => '已换源，之后都用新源播放这首歌';

	/// zh-CN: '没有找到候选歌曲'
	String get toggleSourceEmpty => '没有找到候选歌曲';

	/// zh-CN: '候选搜索失败'
	String get toggleSourceFailed => '候选搜索失败';

	/// zh-CN: '编辑标签'
	String get editTags => '编辑标签';

	/// zh-CN: '编辑歌曲标签'
	String get tagEditTitle => '编辑歌曲标签';

	/// zh-CN: '文件名'
	String get tagEditFileName => '文件名';

	/// zh-CN: '歌曲名'
	String get tagEditName => '歌曲名';

	/// zh-CN: '艺术家'
	String get tagEditSinger => '艺术家';

	/// zh-CN: '专辑名'
	String get tagEditAlbum => '专辑名';

	/// zh-CN: 'LRC 歌词'
	String get tagEditLyric => 'LRC 歌词';

	/// zh-CN: '歌曲专辑封面'
	String get tagEditPic => '歌曲专辑封面';

	/// zh-CN: '从文件名解析歌曲名、艺术家'
	String get tagEditParseName => '从文件名解析歌曲名、艺术家';

	/// zh-CN: '歌曲名 - 艺术家'
	String get tagParseNameSinger => '歌曲名 - 艺术家';

	/// zh-CN: '艺术家 - 歌曲名'
	String get tagParseSingerName => '艺术家 - 歌曲名';

	/// zh-CN: '选择图片'
	String get tagEditSelectPic => '选择图片';

	/// zh-CN: '图片读取失败'
	String get tagEditSelectPicFailed => '图片读取失败';

	/// zh-CN: '移除图片'
	String get tagEditRemovePic => '移除图片';

	/// zh-CN: '清空'
	String get tagEditClearLyric => '清空';

	/// zh-CN: '在线匹配'
	String get tagEditMatchOnline => '在线匹配';

	/// zh-CN: '歌词匹配成功'
	String get tagEditMatchLyricDone => '歌词匹配成功';

	/// zh-CN: '封面匹配成功'
	String get tagEditMatchPicDone => '封面匹配成功';

	/// zh-CN: '在线歌词匹配失败'
	String get tagEditMatchLyricFailed => '在线歌词匹配失败';

	/// zh-CN: '在线匹配封面失败'
	String get tagEditMatchPicFailed => '在线匹配封面失败';

	/// zh-CN: '保存'
	String get tagEditConfirm => '保存';

	/// zh-CN: '保存成功'
	String get tagEditSaved => '保存成功';

	/// zh-CN: '保存失败：{error}'
	String tagEditFailed({required Object error}) => '保存失败：${error}';

	/// zh-CN: '该格式暂不支持写入标签'
	String get tagEditUnsupportedFormat => '该格式暂不支持写入标签';

	/// zh-CN: '读取文件标签失败'
	String get tagEditReadFailed => '读取文件标签失败';
}

// Path: navigation
class Translations$navigation$zh_CN {
	Translations$navigation$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '高频页面'
	String get groupPrimary => '高频页面';

	/// zh-CN: '首页'
	String get home => '首页';

	/// zh-CN: '直播'
	String get live => '直播';

	/// zh-CN: '频道'
	String get channels => '频道';

	/// zh-CN: '发现'
	String get discover => '发现';

	/// zh-CN: '观看记录'
	String get history => '观看记录';

	/// zh-CN: '内容与工具'
	String get groupContent => '内容与工具';

	/// zh-CN: '多画面'
	String get multiview => '多画面';

	/// zh-CN: '关注'
	String get favorites => '关注';

	/// zh-CN: '热门'
	String get hot => '热门';

	/// zh-CN: '分区'
	String get zones => '分区';

	/// zh-CN: '搜索直播'
	String get search => '搜索直播';

	/// zh-CN: '工具箱'
	String get toolbox => '工具箱';

	/// zh-CN: '个人与系统'
	String get groupPersonal => '个人与系统';

	/// zh-CN: '录制中心'
	String get record => '录制中心';

	/// zh-CN: '设置'
	String get settings => '设置';

	/// zh-CN: '外观'
	String get appearance => '外观';

	/// zh-CN: '网络代理'
	String get proxy => '网络代理';

	/// zh-CN: '用户'
	String get user => '用户';

	/// zh-CN: '分区'
	String get vodRegions => '分区';

	/// zh-CN: '订阅源'
	String get iptvSources => '订阅源';

	/// zh-CN: '节目单'
	String get iptvGuide => '节目单';

	/// zh-CN: '歌单'
	String get musicSonglist => '歌单';

	/// zh-CN: '排行榜'
	String get musicToplist => '排行榜';

	/// zh-CN: '我的列表'
	String get musicLibrary => '我的列表';

	/// zh-CN: '本地音乐'
	String get musicLocal => '本地音乐';

	/// zh-CN: '下载管理'
	String get musicDownloads => '下载管理';
}

// Path: player
class Translations$player$zh_CN {
	Translations$player$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '播放'
	String get title => '播放';

	/// zh-CN: '返回'
	String get back => '返回';

	/// zh-CN: '清晰度'
	String get quality => '清晰度';

	/// zh-CN: '线路'
	String get line => '线路';

	/// zh-CN: '全屏'
	String get fullscreen => '全屏';

	/// zh-CN: '弹幕'
	String get danmaku => '弹幕';
}

// Path: popular
class Translations$popular$zh_CN {
	Translations$popular$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '全部平台'
	String get allPlatforms => '全部平台';

	/// zh-CN: '点一个直接切过去；在「平台显示」里隐藏和排序。'
	String get allPlatformsHint => '点一个直接切过去；在「平台显示」里隐藏和排序。';

	/// zh-CN: '第 {page: int} 页，共 {total: int} 页'
	String page({required int page, required int total}) => '第 ${page} 页，共 ${total} 页';

	/// zh-CN: '上一页'
	String get prevPage => '上一页';

	/// zh-CN: '下一页'
	String get nextPage => '下一页';

	/// zh-CN: '在 {platform} 中搜索“{query}”'
	String inlineAt({required Object platform, required Object query}) => '在 ${platform} 中搜索“${query}”';

	/// zh-CN: '返回浏览'
	String get backToBrowse => '返回浏览';

	/// zh-CN: '排序'
	String get sortLabel => '排序';

	/// zh-CN: '平台推荐'
	String get sortPlatform => '平台推荐';

	/// zh-CN: '按观众'
	String get sortAudience => '按观众';

	/// zh-CN: '已隐藏 {count: int} 个暂时不能播放的直播（付费、加锁、仅限 App 等）'
	String hiddenUnplayable({required int count}) => '已隐藏 ${count} 个暂时不能播放的直播（付费、加锁、仅限 App 等）';
}

// Path: recorder
class Translations$recorder$zh_CN {
	Translations$recorder$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '进行中'
	String get tabRunning => '进行中';

	/// zh-CN: '已完成'
	String get tabFinished => '已完成';

	/// zh-CN: '清空已完成'
	String get clearFinished => '清空已完成';

	/// zh-CN: '删除这条任务'
	String get removeTask => '删除这条任务';

	/// zh-CN: '还没有录制任务'
	String get emptyTitle => '还没有录制任务';

	/// zh-CN: '已完成的录制会出现在这里'
	String get emptyFinishedTitle => '已完成的录制会出现在这里';

	/// zh-CN: '在直播间点击录制，任务会出现在这里。'
	String get emptyDescription => '在直播间点击录制，任务会出现在这里。';

	/// zh-CN: '最佳画质'
	String get qualityBest => '最佳画质';

	/// zh-CN: '开始于 {time}'
	String startedAt({required Object time}) => '开始于 ${time}';

	/// zh-CN: '录制中'
	String get stateRecording => '录制中';

	/// zh-CN: '已停止'
	String get stateStopped => '已停止';

	/// zh-CN: '失败'
	String get stateFailed => '失败';

	/// zh-CN: '录制'
	String get settingsTitle => '录制';

	/// zh-CN: '保存目录'
	String get saveDirTitle => '保存目录';

	/// zh-CN: '跟随引擎默认目录'
	String get saveDirDefault => '跟随引擎默认目录';

	/// zh-CN: '输入保存录制文件的文件夹路径'
	String get saveDirDialogHint => '输入保存录制文件的文件夹路径';

	/// zh-CN: '文件命名模板'
	String get namingTitle => '文件命名模板';

	/// zh-CN: '可用日期、时间、平台、房间号与标题占位符。'
	String get namingDescription => '可用日期、时间、平台、房间号与标题占位符。';

	/// zh-CN: '输入录制文件的命名模板'
	String get namingDialogHint => '输入录制文件的命名模板';

	/// zh-CN: '单次录制大小上限'
	String get maxSizeTitle => '单次录制大小上限';

	/// zh-CN: '录制达到上限后自动结束并保存；按 MB 计。'
	String get maxSizeDescription => '录制达到上限后自动结束并保存；按 MB 计。';

	/// zh-CN: '筛选'
	String get filterLabel => '筛选';

	/// zh-CN: '全部'
	String get filterAll => '全部';

	/// zh-CN: '录制中'
	String get filterRecording => '录制中';

	/// zh-CN: '等待'
	String get filterWaiting => '等待';

	/// zh-CN: '已保存'
	String get filterSaved => '已保存';

	/// zh-CN: '失败'
	String get filterFailed => '失败';

	/// zh-CN: '“{status: String}”里还没有任务'
	String emptyFilterTitle({required String status}) => '“${status}”里还没有任务';

	/// zh-CN: '等待开播'
	String get stateWaiting => '等待开播';

	/// zh-CN: '已保存'
	String get stateSaved => '已保存';

	/// zh-CN: '更多操作'
	String get menuMore => '更多操作';

	/// zh-CN: '进入直播间'
	String get openRoom => '进入直播间';

	/// zh-CN: '打开文件夹'
	String get openFolder => '打开文件夹';

	/// zh-CN: '无法打开文件夹'
	String get openFolderFailed => '无法打开文件夹';

	/// zh-CN: '删除'
	String get delete => '删除';

	/// zh-CN: '删除“{name: String}”？'
	String deleteTitle({required String name}) => '删除“${name}”？';

	/// zh-CN: '只删除这条录制任务记录，已保存的视频文件不会被删除。'
	String get deleteBody => '只删除这条录制任务记录，已保存的视频文件不会被删除。';

	/// zh-CN: '录制设置'
	String get settingsOpen => '录制设置';

	/// zh-CN: '停止录制'
	String get stop => '停止录制';

	/// zh-CN: '文件与位置'
	String get settingsFiles => '文件与位置';

	/// zh-CN: '分段与恢复'
	String get settingsRecovery => '分段与恢复';

	/// zh-CN: '后台与上限'
	String get settingsRuntime => '后台与上限';

	/// zh-CN: '分段时长'
	String get segmentTitle => '分段时长';

	/// zh-CN: '每段录制的长度；段文件在崩溃后仍可播放。'
	String get segmentDescription => '每段录制的长度；段文件在崩溃后仍可播放。';

	/// zh-CN: '{count: int} 分钟'
	String segmentMinutes({required int count}) => '${count} 分钟';

	/// zh-CN: '读取超时'
	String get readTimeoutTitle => '读取超时';

	/// zh-CN: '直播流停止供流后等待多久判定失败。'
	String get readTimeoutDescription => '直播流停止供流后等待多久判定失败。';

	/// zh-CN: '{count: int} 秒'
	String seconds({required int count}) => '${count} 秒';

	/// zh-CN: '输入队列'
	String get queueTitle => '输入队列';

	/// zh-CN: 'FFmpeg 输入包队列大小；直播突发时越大越不容易丢包。'
	String get queueDescription => 'FFmpeg 输入包队列大小；直播突发时越大越不容易丢包。';

	/// zh-CN: '只录首路音视频'
	String get preferBestTitle => '只录首路音视频';

	/// zh-CN: '开启时只映射首个视频和音频流，避免多码率文件变成多轨。'
	String get preferBestDescription => '开启时只映射首个视频和音频流，避免多码率文件变成多轨。';

	/// zh-CN: '后台保持录制'
	String get keepAliveTitle => '后台保持录制';

	/// zh-CN: '录制期间持有后台会话与唤醒锁（Android 前台服务/通知）。'
	String get keepAliveDescription => '录制期间持有后台会话与唤醒锁（Android 前台服务/通知）。';

	/// zh-CN: '结束时校验文件'
	String get verifyTitle => '结束时校验文件';

	/// zh-CN: '结束前检查分段是否可播放。'
	String get verifyDescription => '结束前检查分段是否可播放。';

	/// zh-CN: '断流重试次数'
	String get restartTitle => '断流重试次数';

	/// zh-CN: '流中断后 FFmpeg 自动重开的次数；0 表示不重试。'
	String get restartDescription => '流中断后 FFmpeg 自动重开的次数；0 表示不重试。';

	/// zh-CN: '{count: int} 次'
	String restartCount({required int count}) => '${count} 次';

	/// zh-CN: '重试间隔'
	String get backoffTitle => '重试间隔';

	/// zh-CN: '两次重开之间的等待。'
	String get backoffDescription => '两次重开之间的等待。';

	/// zh-CN: '卡流判定'
	String get stallTitle => '卡流判定';

	/// zh-CN: '多久没有新数据就判定为卡流并重开。'
	String get stallDescription => '多久没有新数据就判定为卡流并重开。';

	/// zh-CN: '磁盘余量保护'
	String get watermarkTitle => '磁盘余量保护';

	/// zh-CN: '剩余空间低于该值时停止录制。'
	String get watermarkDescription => '剩余空间低于该值时停止录制。';

	/// zh-CN: '同时录制任务上限'
	String get maxTasksTitle => '同时录制任务上限';

	/// zh-CN: '达到上限后新的录制请求会被拒绝。'
	String get maxTasksDescription => '达到上限后新的录制请求会被拒绝。';

	/// zh-CN: '{count: int} 个'
	String maxTasksCount({required int count}) => '${count} 个';

	/// zh-CN: '分段格式'
	String get containerTitle => '分段格式';

	/// zh-CN: 'TS 更耐中断，MP4 更易被普通播放器打开。'
	String get containerDescription => 'TS 更耐中断，MP4 更易被普通播放器打开。';

	/// zh-CN: 'MPEG-TS'
	String get containerTs => 'MPEG-TS';

	/// zh-CN: '分段 MP4'
	String get containerMp4 => '分段 MP4';

	/// zh-CN: '同时录制弹幕'
	String get recordChatTitle => '同时录制弹幕';

	/// zh-CN: '在录像旁存同名弹幕文件，格式见「弹幕 → 弹幕文件」；平台需已接入弹幕'
	String get recordChatDescription => '在录像旁存同名弹幕文件，格式见「弹幕 → 弹幕文件」；平台需已接入弹幕';

	/// zh-CN: '默认录制画质'
	String get defaultQualityTitle => '默认录制画质';

	/// zh-CN: '开始录制时优先请求这个清晰度；平台不提供时使用当前播放线路。'
	String get defaultQualityDesc => '开始录制时优先请求这个清晰度；平台不提供时使用当前播放线路。';

	/// zh-CN: '录制缓存'
	String get cacheTitle => '录制缓存';

	/// zh-CN: '开播检测'
	String get liveCheckGroup => '开播检测';

	/// zh-CN: '启用开播检测'
	String get enablePolling => '启用开播检测';

	/// zh-CN: '主播未开播时自动轮询；在直播间菜单里选「开播自动录」加入。'
	String get enablePollingDesc => '主播未开播时自动轮询；在直播间菜单里选「开播自动录」加入。';

	/// zh-CN: '「开播检测」关着，等待开播的任务不会自动开始。'
	String get pollingOff => '「开播检测」关着，等待开播的任务不会自动开始。';

	/// zh-CN: '打开'
	String get pollingEnable => '打开';

	/// zh-CN: '已打开开播检测（每 {seconds} 秒检查一次）'
	String pollingEnabledToast({required Object seconds}) => '已打开开播检测（每 ${seconds} 秒检查一次）';

	/// zh-CN: '限制录制缓存'
	String get cacheLimitEnabled => '限制录制缓存';

	/// zh-CN: '超过上限时自动删除最旧的已完成录制；正在录制的文件不会被删除。'
	String get cacheLimitEnabledDesc => '超过上限时自动删除最旧的已完成录制；正在录制的文件不会被删除。';

	/// zh-CN: '缓存上限'
	String get cacheLimit => '缓存上限';

	/// zh-CN: '超过上限从最旧的已完成录像删起；正在录制的不动。'
	String get cacheLimitDesc => '超过上限从最旧的已完成录像删起；正在录制的不动。';

	/// zh-CN: '当前录制缓存'
	String get cacheSize => '当前录制缓存';

	/// zh-CN: '录制目录中已完成与正在录制的文件总大小。'
	String get cacheSizeDesc => '录制目录中已完成与正在录制的文件总大小。';

	/// zh-CN: '刷新'
	String get cacheRefresh => '刷新';

	/// zh-CN: '清理录制缓存'
	String get cacheClear => '清理录制缓存';

	/// zh-CN: '删除全部已完成的录制文件与弹幕 XML，正在录制的保留。'
	String get cacheClearDesc => '删除全部已完成的录制文件与弹幕 XML，正在录制的保留。';

	/// zh-CN: '清理全部已完成录制？'
	String get cacheClearConfirm => '清理全部已完成录制？';

	/// zh-CN: '删除目录中已完成的视频、分段与弹幕文件，无法恢复；正在录制的跳过。'
	String get cacheClearConfirmDesc => '删除目录中已完成的视频、分段与弹幕文件，无法恢复；正在录制的跳过。';

	/// zh-CN: '录制缓存已清理'
	String get cacheCleared => '录制缓存已清理';

	/// zh-CN: '缓存操作失败，请重试'
	String get cacheFailed => '缓存操作失败，请重试';

	/// zh-CN: '自定义目录下只创建并管理 PureLiveRecords 子目录。'
	String get cacheManagedHint => '自定义目录下只创建并管理 PureLiveRecords 子目录。';

	/// zh-CN: '检测间隔（秒）'
	String get liveCheckSecondsTitle => '检测间隔（秒）';

	/// zh-CN: '每个等待开播的任务多久检查一次，10–300 秒。'
	String get liveCheckSecondsDesc => '每个等待开播的任务多久检查一次，10–300 秒。';

	/// zh-CN: '启用指数退避'
	String get checkBackoff => '启用指数退避';

	/// zh-CN: '连续失败越多，下一次检测间隔越长，避免频繁请求平台。'
	String get checkBackoffDesc => '连续失败越多，下一次检测间隔越长，避免频繁请求平台。';

	/// zh-CN: '最大检测间隔（秒）'
	String get maxCheckSecondsTitle => '最大检测间隔（秒）';

	/// zh-CN: '退避后的间隔上限，60–3600 秒。'
	String get maxCheckSecondsDesc => '退避后的间隔上限，60–3600 秒。';

	/// zh-CN: '应用启动时恢复待录任务'
	String get autoStartOnBoot => '应用启动时恢复待录任务';

	/// zh-CN: '把中断时仍在录制的任务恢复为等待开播；已停止的保持原状。'
	String get autoStartOnBootDesc => '把中断时仍在录制的任务恢复为等待开播；已停止的保持原状。';

	/// zh-CN: '有录制任务正在进行（可能在另一个窗口），缓存不会被清理或自动裁剪。'
	String get cacheBusy => '有录制任务正在进行（可能在另一个窗口），缓存不会被清理或自动裁剪。';
}

// Path: room
class Translations$room$zh_CN {
	Translations$room$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '正在打开房间'
	String get opening => '正在打开房间';

	/// zh-CN: '关注'
	String get follow => '关注';

	/// zh-CN: '已关注'
	String get unfollow => '已关注';

	/// zh-CN: '画质'
	String get quality => '画质';

	/// zh-CN: '线路'
	String get lineLabel => '线路';

	/// zh-CN: '线路 {n}'
	String line({required Object n}) => '线路 ${n}';

	/// zh-CN: '播放'
	String get play => '播放';

	/// zh-CN: '暂停'
	String get pause => '暂停';

	/// zh-CN: '还没有弹幕'
	String get noChat => '还没有弹幕';

	/// zh-CN: '系统'
	String get system => '系统';

	/// zh-CN: '静音'
	String get mute => '静音';

	/// zh-CN: '取消静音'
	String get unmute => '取消静音';

	/// zh-CN: '音量'
	String get volume => '音量';

	/// zh-CN: '定时关闭'
	String get sleep => '定时关闭';

	/// zh-CN: '关闭定时'
	String get sleepOff => '关闭定时';

	/// zh-CN: '发个弹幕见证当下'
	String get sendHint => '发个弹幕见证当下';

	/// zh-CN: '发送'
	String get send => '发送';

	/// zh-CN: '发送失败'
	String get sendFailed => '发送失败';

	/// zh-CN: '进入全屏'
	String get fullscreenOn => '进入全屏';

	/// zh-CN: '退出全屏'
	String get fullscreenOff => '退出全屏';

	/// zh-CN: '聊天'
	String get chatTitle => '聊天';

	/// zh-CN: '显示弹幕'
	String get danmakuOn => '显示弹幕';

	/// zh-CN: '隐藏弹幕'
	String get danmakuOff => '隐藏弹幕';

	/// zh-CN: '窗口全屏'
	String get windowFullscreenOn => '窗口全屏';

	/// zh-CN: '退出窗口全屏'
	String get windowFullscreenOff => '退出窗口全屏';

	/// zh-CN: '画中画'
	String get pipOn => '画中画';

	/// zh-CN: '退出画中画'
	String get pipOff => '退出画中画';

	/// zh-CN: '投屏'
	String get cast => '投屏';

	/// zh-CN: '投屏到设备'
	String get castTitle => '投屏到设备';

	/// zh-CN: '正在搜索附近的设备'
	String get castSearching => '正在搜索附近的设备';

	/// zh-CN: '请确认电视与电脑在同一局域网。'
	String get castSearchingHint => '请确认电视与电脑在同一局域网。';

	/// zh-CN: '可用设备'
	String get castDevices => '可用设备';

	/// zh-CN: '正在投屏'
	String get casting => '正在投屏';

	/// zh-CN: '停止投屏'
	String get castStop => '停止投屏';

	/// zh-CN: '已开始投屏'
	String get castStarted => '已开始投屏';

	/// zh-CN: '投屏失败，设备可能无法访问这条线路'
	String get castFailed => '投屏失败，设备可能无法访问这条线路';

	/// zh-CN: '睡眠定时已到，播放已暂停'
	String get sleepDone => '睡眠定时已到，播放已暂停';

	/// zh-CN: '音频模式'
	String get audioOnlyMode => '音频模式';

	/// zh-CN: '恢复视频'
	String get restoreVideo => '恢复视频';

	/// zh-CN: '返回直播间'
	String get backToRoom => '返回直播间';

	/// zh-CN: '正在打开房间'
	String get openingRoom => '正在打开房间';

	/// zh-CN: '播放失败'
	String get playbackFailed => '播放失败';

	/// zh-CN: '缓冲中'
	String get buffering => '缓冲中';

	/// zh-CN: '正在连接直播流'
	String get connecting => '正在连接直播流';

	/// zh-CN: '时间有点长，线路可能不稳定'
	String get slowReason => '时间有点长，线路可能不稳定';

	/// zh-CN: '已暂停'
	String get paused => '已暂停';

	/// zh-CN: '回放已结束'
	String get replayEnded => '回放已结束';

	/// zh-CN: '该直播间已被封禁'
	String get banned => '该直播间已被封禁';

	/// zh-CN: '轮播中'
	String get carousel => '轮播中';

	/// zh-CN: '主播暂时不在，平台正在播放轮播内容'
	String get carouselReason => '主播暂时不在，平台正在播放轮播内容';

	/// zh-CN: '主播暂时不在'
	String get offlineTitle => '主播暂时不在';

	/// zh-CN: '有回放可看，回到列表后可从卡片进入'
	String get offlineReplayReason => '有回放可看，回到列表后可从卡片进入';

	/// zh-CN: '开播后这里会看到直播画面'
	String get offlineReason => '开播后这里会看到直播画面';

	/// zh-CN: '房间信息加载失败'
	String get detailFailed => '房间信息加载失败';

	/// zh-CN: '进入直播间'
	String get openRoom => '进入直播间';

	/// zh-CN: '复制房间链接'
	String get copyLink => '复制房间链接';

	/// zh-CN: '链接已复制'
	String get linkCopied => '链接已复制';

	/// zh-CN: '录制'
	String get record => '录制';

	/// zh-CN: '停止录制'
	String get stopRecording => '停止录制';

	/// zh-CN: '开始录制'
	String get recordStarted => '开始录制';

	/// zh-CN: '录制已停止'
	String get recordStopped => '录制已停止';

	/// zh-CN: '录制操作失败'
	String get recordFailed => '录制操作失败';

	/// zh-CN: '开播自动录'
	String get autoRecordOn => '开播自动录';

	/// zh-CN: '取消开播自动录'
	String get autoRecordOff => '取消开播自动录';

	/// zh-CN: '已打开开播检测（每 {seconds} 秒检查一次）；开播后自动录制'
	String autoRecordArmed({required Object seconds}) => '已打开开播检测（每 ${seconds} 秒检查一次）；开播后自动录制';

	/// zh-CN: '已取消开播自动录制'
	String get autoRecordRemoved => '已取消开播自动录制';

	/// zh-CN: '无法加入开播检测，请稍后重试'
	String get autoRecordFailed => '无法加入开播检测，请稍后重试';

	/// zh-CN: '直播间详情'
	String get details => '直播间详情';

	/// zh-CN: '查看直播间详情'
	String get detailsHint => '查看直播间详情';

	/// zh-CN: '公告'
	String get notice => '公告';

	/// zh-CN: '简介'
	String get introduction => '简介';

	/// zh-CN: '房间号'
	String get roomNumber => '房间号';

	/// zh-CN: '链接'
	String get link => '链接';

	/// zh-CN: '复制'
	String get copy => '复制';

	/// zh-CN: '已复制'
	String get copied => '已复制';

	/// zh-CN: '之前发的'
	String get replayed => '之前发的';

	/// zh-CN: '分享'
	String get share => '分享';

	/// zh-CN: '分享失败'
	String get shareFailed => '分享失败';

	/// zh-CN: '在 {platform} 打开'
	String openIn({required Object platform}) => '在 ${platform} 打开';

	/// zh-CN: '该平台没有提供可打开的链接'
	String get openUnavailable => '该平台没有提供可打开的链接';

	/// zh-CN: '无法打开链接'
	String get openFailed => '无法打开链接';

	/// zh-CN: '刷新房间信息'
	String get refreshRoom => '刷新房间信息';

	/// zh-CN: '弹幕操作'
	String get messageActions => '弹幕操作';

	/// zh-CN: '屏蔽此用户'
	String get blockUser => '屏蔽此用户';

	/// zh-CN: '屏蔽关键词…'
	String get blockKeyword => '屏蔽关键词…';

	/// zh-CN: '输入要屏蔽的关键词'
	String get blockKeywordHint => '输入要屏蔽的关键词';

	/// zh-CN: '已屏蔽该用户'
	String get userBlocked => '已屏蔽该用户';

	/// zh-CN: '已屏蔽该关键词'
	String get keywordBlocked => '已屏蔽该关键词';

	/// zh-CN: '弹幕设置'
	String get danmakuSettings => '弹幕设置';

	/// zh-CN: '屏蔽列表'
	String get blockList => '屏蔽列表';

	/// zh-CN: '超级聊天'
	String get superChats => '超级聊天';

	/// zh-CN: '暂无超级聊天'
	String get superChatEmpty => '暂无超级聊天';

	/// zh-CN: '超级聊天加载失败'
	String get superChatFailed => '超级聊天加载失败';

	/// zh-CN: '会员'
	String get superChatCardMembership => '会员';

	/// zh-CN: '订阅'
	String get superChatCardSubscription => '订阅';

	/// zh-CN: '在线'
	String get onlineViewers => '在线';

	/// zh-CN: '热度'
	String get popularity => '热度';

	/// zh-CN: '累计观看'
	String get totalViewers => '累计观看';

	/// zh-CN: '{time} 开播'
	String startedAt({required Object time}) => '${time} 开播';

	/// zh-CN: '弹幕'
	String get danmakuList => '弹幕';

	/// zh-CN: '控制飞行弹幕的显示、字号、速度与区域。'
	String get danmakuSettingsDesc => '控制飞行弹幕的显示、字号、速度与区域。';

	/// zh-CN: '屏蔽'
	String get block => '屏蔽';

	/// zh-CN: '在平台打开'
	String get openExternal => '在平台打开';

	/// zh-CN: '需要登录'
	String get restrictionNeedsLogin => '需要登录';

	/// zh-CN: '需要付费'
	String get restrictionPaid => '需要付费';

	/// zh-CN: '仅限会员'
	String get restrictionSubscribersOnly => '仅限会员';

	/// zh-CN: '私密房间'
	String get restrictionPrivate => '私密房间';

	/// zh-CN: '需要在官方 App 观看'
	String get restrictionAppOnly => '需要在官方 App 观看';

	/// zh-CN: '当前地区不可观看'
	String get restrictionRegionBlocked => '当前地区不可观看';

	/// zh-CN: '需要密码'
	String get restrictionPassword => '需要密码';

	/// zh-CN: '年龄限制'
	String get restrictionAdult => '年龄限制';

	/// zh-CN: '暂时无法播放'
	String get restrictionUnplayable => '暂时无法播放';

	/// zh-CN: '画面方向'
	String get orientation => '画面方向';

	/// zh-CN: '默认跟随画面本身的比例；也可以为这个直播间固定为竖屏或横屏。'
	String get orientationHint => '默认跟随画面本身的比例；也可以为这个直播间固定为竖屏或横屏。';

	/// zh-CN: '自动'
	String get orientationAutomatic => '自动';

	/// zh-CN: '竖屏'
	String get orientationPortrait => '竖屏';

	/// zh-CN: '横屏'
	String get orientationLandscape => '横屏';

	/// zh-CN: '画面方向已更新'
	String get orientationUpdated => '画面方向已更新';

	/// zh-CN: '竖屏全屏'
	String get portraitFullscreen => '竖屏全屏';

	/// zh-CN: '退出竖屏全屏'
	String get portraitFullscreenExit => '退出竖屏全屏';

	/// zh-CN: '画面模式'
	String get portraitFullscreenDisplay => '画面模式';

	/// zh-CN: '完整'
	String get portraitDisplayComplete => '完整';

	/// zh-CN: '沉浸'
	String get portraitDisplayAmbient => '沉浸';

	/// zh-CN: '均衡'
	String get portraitDisplayBalanced => '均衡';

	/// zh-CN: '铺满'
	String get portraitDisplayCover => '铺满';

	/// zh-CN: '弹幕区域'
	String get portraitDanmakuTitle => '弹幕区域';

	/// zh-CN: '跟随全局'
	String get portraitDanmakuFollow => '跟随全局';

	/// zh-CN: '上部 1/4'
	String get portraitDanmakuUpper => '上部 1/4';

	/// zh-CN: '减半'
	String get portraitDanmakuReduced => '减半';

	/// zh-CN: '隐藏'
	String get portraitDanmakuHidden => '隐藏';

	/// zh-CN: '竖屏诊断'
	String get portraitDiagnostics => '竖屏诊断';

	/// zh-CN: '送出'
	String get giftLineSent => '送出';

	/// zh-CN: '送给 {name}'
	String giftLineSentTo({required Object name}) => '送给 ${name}';

	/// zh-CN: '赠送'
	String get giftLineGifted => '赠送';

	/// zh-CN: '打赏'
	String get giftLineTipped => '打赏';

	/// zh-CN: '×{count}'
	String giftLineCount({required Object count}) => '×${count}';

	/// zh-CN: '×{count} 个月'
	String giftLineMonths({required Object count}) => '×${count} 个月';

	/// zh-CN: '礼物'
	String get giftLineUnnamed => '礼物';

	/// zh-CN: '礼物 {id}'
	String giftLineNumbered({required Object id}) => '礼物 ${id}';

	/// zh-CN: '{value} 元'
	String giftValueYuan({required Object value}) => '${value} 元';

	/// zh-CN: '{value} 金瓜子'
	String giftValueGoldSeed({required Object value}) => '${value} 金瓜子';

	/// zh-CN: '{value} 钻石'
	String giftValueDiamond({required Object value}) => '${value} 钻石';

	/// zh-CN: '{value} 红豆'
	String giftValueRedBean({required Object value}) => '${value} 红豆';

	/// zh-CN: '{value} 点'
	String giftValuePoint({required Object value}) => '${value} 点';

	/// zh-CN: '{value} Bits'
	String giftValueBits({required Object value}) => '${value} Bits';

	/// zh-CN: '{value} Kicks'
	String giftValueKicks({required Object value}) => '${value} Kicks';

	/// zh-CN: '{value} 奶酪'
	String giftValueCheese({required Object value}) => '${value} 奶酪';

	/// zh-CN: '{value} 星气球'
	String giftValueStarBalloon({required Object value}) => '${value} 星气球';

	/// zh-CN: '{value} 抖币'
	String giftValueDouyinCoin({required Object value}) => '${value} 抖币';

	/// zh-CN: '{value} 六币'
	String giftValueSixCoin({required Object value}) => '${value} 六币';

	/// zh-CN: '{value} AC币'
	String giftValueAcCoin({required Object value}) => '${value} AC币';

	/// zh-CN: '{value} 星币'
	String giftValueStarCoin({required Object value}) => '${value} 星币';

	/// zh-CN: '{value} 爱心'
	String giftValueHeart({required Object value}) => '${value} 爱心';

	/// zh-CN: '{value} 音符'
	String giftValueNote({required Object value}) => '${value} 音符';

	/// zh-CN: '收起聊天'
	String get collapseChat => '收起聊天';

	/// zh-CN: '展开聊天'
	String get expandChat => '展开聊天';

	/// zh-CN: '切换直播间'
	String get switchRoom => '切换直播间';

	/// zh-CN: '关注在播'
	String get switchOnAir => '关注在播';

	/// zh-CN: '观看记录'
	String get switchHistory => '观看记录';

	/// zh-CN: '关注回放'
	String get switchReplays => '关注回放';

	/// zh-CN: '没有可切换的直播间'
	String get switchEmpty => '没有可切换的直播间';

	/// zh-CN: '直播中'
	String get switchLive => '直播中';

	/// zh-CN: '切换为网格'
	String get switchShowGrid => '切换为网格';

	/// zh-CN: '切换为列表'
	String get switchShowList => '切换为列表';

	/// zh-CN: 'Twitch Cookie 已失效，弹幕改为匿名接收；请重新填写。'
	String get twitchCookieExpired => 'Twitch Cookie 已失效，弹幕改为匿名接收；请重新填写。';

	/// zh-CN: '当前以访客身份连接，B 站弹幕不会显示完整昵称'
	String get bilibiliGuestNames => '当前以访客身份连接，B 站弹幕不会显示完整昵称';

	/// zh-CN: 'B 站登录似乎已失效：昵称全部被打码，请重新登录'
	String get bilibiliLoginExpired => 'B 站登录似乎已失效：昵称全部被打码，请重新登录';

	/// zh-CN: '弹幕连接失败（{reason}），直播画面不受影响'
	String danmakuConnectFailed({required Object reason}) => '弹幕连接失败（${reason}），直播画面不受影响';
}

// Path: search
class Translations$search$zh_CN {
	Translations$search$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '搜索'
	String get idleTitle => '搜索';

	/// zh-CN: '输入关键词，搜索房间、主播或分区。'
	String get idleDescription => '输入关键词，搜索房间、主播或分区。';

	/// zh-CN: '搜索建议'
	String get suggestionsTitle => '搜索建议';

	/// zh-CN: '搜索目标'
	String get targetsLabel => '搜索目标';

	/// zh-CN: '房间'
	String get tabRooms => '房间';

	/// zh-CN: '主播'
	String get tabAnchors => '主播';

	/// zh-CN: '分区'
	String get tabAreas => '分区';

	/// zh-CN: '没有找到相关结果'
	String get noResultsTitle => '没有找到相关结果';

	/// zh-CN: '换个关键词，或切换到其他搜索目标。'
	String get noResultsDescription => '换个关键词，或切换到其他搜索目标。';

	/// zh-CN: '该平台不支持搜索'
	String get unsupportedTitle => '该平台不支持搜索';

	/// zh-CN: '请切换到其他平台再试。'
	String get unsupportedDescription => '请切换到其他平台再试。';

	/// zh-CN: '直播中'
	String get liveBadge => '直播中';

	/// zh-CN: '全部'
	String get scopeAll => '全部';

	/// zh-CN: '搜索历史'
	String get historyTitle => '搜索历史';

	/// zh-CN: '清空'
	String get clearHistory => '清空';

	/// zh-CN: '网页搜索'
	String get webSearch => '网页搜索';

	/// zh-CN: '网页搜索'
	String get webSearchTitle => '网页搜索';

	/// zh-CN: '先选择一个平台再网页搜索'
	String get webSearchSelectPlatform => '先选择一个平台再网页搜索';

	/// zh-CN: '该平台没有网页搜索'
	String get webSearchUnavailable => '该平台没有网页搜索';

	/// zh-CN: '当前平台不支持内嵌网页'
	String get webSearchUnsupportedTitle => '当前平台不支持内嵌网页';

	/// zh-CN: '可以在系统浏览器中打开这个搜索页。'
	String get webSearchUnsupportedDescription => '可以在系统浏览器中打开这个搜索页。';

	/// zh-CN: '在浏览器中打开'
	String get webSearchOpenExternal => '在浏览器中打开';

	/// zh-CN: '无法打开系统浏览器'
	String get webSearchExternalFailed => '无法打开系统浏览器';

	/// zh-CN: '页面加载失败'
	String get webSearchFailed => '页面加载失败';

	/// zh-CN: '排序'
	String get sort => '排序';

	/// zh-CN: '综合'
	String get sortSmart => '综合';

	/// zh-CN: '按平台'
	String get sortPlatform => '按平台';

	/// zh-CN: '按人气'
	String get sortAudience => '按人气';

	/// zh-CN: '按关注'
	String get sortFollowers => '按关注';

	/// zh-CN: '显示离线'
	String get includeOffline => '显示离线';

	/// zh-CN: '筛选'
	String get filterTitle => '筛选';

	/// zh-CN: '重置'
	String get filterReset => '重置';

	/// zh-CN: '检测到直播间链接'
	String get linkDetected => '检测到直播间链接';

	/// zh-CN: '打开直播间'
	String get linkOpen => '打开直播间';

	/// zh-CN: '正在解析链接…'
	String get linkResolving => '正在解析链接…';

	/// zh-CN: '没有解析到直播间'
	String get linkFailed => '没有解析到直播间';
}

// Path: settings
class Translations$settings$zh_CN {
	Translations$settings$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '设置'
	String get title => '设置';

	/// zh-CN: '浏览与窗口'
	String get navGeneral => '浏览与窗口';

	/// zh-CN: '个性化'
	String get navPersonalization => '个性化';

	/// zh-CN: '直播'
	String get navLive => '直播';

	/// zh-CN: '直播资源'
	String get navLiveSources => '直播资源';

	/// zh-CN: '播放偏好'
	String get navPlaybackPreferences => '播放偏好';

	/// zh-CN: '系统'
	String get navSystem => '系统';

	/// zh-CN: '数据与缓存'
	String get navDataCache => '数据与缓存';

	/// zh-CN: '外观'
	String get navAppearance => '外观';

	/// zh-CN: '播放'
	String get navPlayback => '播放';

	/// zh-CN: '站点'
	String get navSites => '站点';

	/// zh-CN: '节目单与更新'
	String get navIptv => '节目单与更新';

	/// zh-CN: '账号与清晰度'
	String get navVod => '账号与清晰度';

	/// zh-CN: '观看数据'
	String get navData => '观看数据';

	/// zh-CN: '备份与恢复'
	String get navBackup => '备份与恢复';

	/// zh-CN: '版本与许可'
	String get navAbout => '版本与许可';

	/// zh-CN: '浏览'
	String get navBrowsing => '浏览';

	/// zh-CN: '窗口'
	String get navWindow => '窗口';

	/// zh-CN: '启动与退出'
	String get navStartup => '启动与退出';

	/// zh-CN: '账号'
	String get navAccounts => '账号';

	/// zh-CN: '主题与颜色'
	String get navTheme => '主题与颜色';

	/// zh-CN: '字体与字号'
	String get navTypography => '字体与字号';

	/// zh-CN: '画质与声音'
	String get qualityAudioTitle => '画质与声音';

	/// zh-CN: '默认清晰度、音量与后台播放。'
	String get qualityAudioDescription => '默认清晰度、音量与后台播放。';

	/// zh-CN: '内核高级参数'
	String get kernelAdvancedTitle => '内核高级参数';

	/// zh-CN: '输出驱动、同步、缩放与解码高级项，仅 mpv 内核生效。'
	String get kernelAdvancedDescription => '输出驱动、同步、缩放与解码高级项，仅 mpv 内核生效。';

	/// zh-CN: 'WebDAV 网盘'
	String get webdavSyncTitle => 'WebDAV 网盘';

	/// zh-CN: '多个 WebDAV 账号的文件管理：浏览目录、上传下载、重命名移动，以及备份的发送与恢复。'
	String get webdavSyncDescription => '多个 WebDAV 账号的文件管理：浏览目录、上传下载、重命名移动，以及备份的发送与恢复。';

	/// zh-CN: '关闭与退出'
	String get closeExitGroup => '关闭与退出';

	/// zh-CN: '画质'
	String get navQuality => '画质';

	/// zh-CN: '音频与音量'
	String get navAudio => '音频与音量';

	/// zh-CN: '画面与浮窗'
	String get navPicture => '画面与浮窗';

	/// zh-CN: '小窗与画中画'
	String get navFloatingWindow => '小窗与画中画';

	/// zh-CN: '基础设置'
	String get groupBasics => '基础设置';

	/// zh-CN: '站点'
	String get groupContent => '站点';

	/// zh-CN: '数据'
	String get groupData => '数据';

	/// zh-CN: '关于'
	String get groupAbout => '关于';

	/// zh-CN: 'IPTV'
	String get groupIptv => 'IPTV';

	/// zh-CN: 'Bilibili 视频'
	String get groupVod => 'Bilibili 视频';

	/// zh-CN: '浏览、窗口与启动设置。'
	String get generalDescription => '浏览、窗口与启动设置。';

	/// zh-CN: '主题、字体与配色。'
	String get appearanceDescription => '主题、字体与配色。';

	/// zh-CN: '主题、外观、背景与导航。'
	String get personalizationDescription => '主题、外观、背景与导航。';

	/// zh-CN: '直播资源、弹幕与录制。'
	String get liveSettingsDescription => '直播资源、弹幕与录制。';

	/// zh-CN: '平台、账号与自动刷新。'
	String get liveSourcesDescription => '平台、账号与自动刷新。';

	/// zh-CN: '播放偏好与播放器内核。'
	String get playbackSettingsDescription => '播放偏好与播放器内核。';

	/// zh-CN: '浏览、网络、诊断、数据与备份。'
	String get systemDescription => '浏览、网络、诊断、数据与备份。';

	/// zh-CN: '观看数据与封面缓存。'
	String get dataCacheDescription => '观看数据与封面缓存。';

	/// zh-CN: '选择要应用的主题'
	String get personalizationChooseTheme => '选择要应用的主题';

	/// zh-CN: '个性化设置'
	String get personalizationSettings => '个性化设置';

	/// zh-CN: '画质、音频、画面与播放器行为。'
	String get playbackDescription => '画质、音频、画面与播放器行为。';

	/// zh-CN: '默认站点与首选平台；平台显示、排序与账号登录在子页。'
	String get sitesDescription => '默认站点与首选平台；平台显示、排序与账号登录在子页。';

	/// zh-CN: '节目单自动更新与来源同步。'
	String get iptvDescription => '节目单自动更新与来源同步。';

	/// zh-CN: 'Bilibili 账号、默认清晰度与视频站行为。'
	String get vodDescription => 'Bilibili 账号、默认清晰度与视频站行为。';

	/// zh-CN: '直播观看历史与关注数据。'
	String get dataDescription => '直播观看历史与关注数据。';

	/// zh-CN: '本地备份、恢复与 WebDAV 同步。'
	String get backupDescription => '本地备份、恢复与 WebDAV 同步。';

	/// zh-CN: '版本、开源许可与项目链接。'
	String get aboutDescription => '版本、开源许可与项目链接。';

	/// zh-CN: '卡片间距、关注页密度与房间卡片。'
	String get browsingPageDescription => '卡片间距、关注页密度与房间卡片。';

	/// zh-CN: '标题栏、直播间窗口、关闭行为、窗口尺寸与显示刷新率。'
	String get windowPageDescription => '标题栏、直播间窗口、关闭行为、窗口尺寸与显示刷新率。';

	/// zh-CN: '开机启动、启动动画、关闭窗口行为与定时关机。'
	String get startupPageDescription => '开机启动、启动动画、关闭窗口行为与定时关机。';

	/// zh-CN: '各平台账号与授权。'
	String get accountsPageDescription => '各平台账号与授权。';

	/// zh-CN: '主题模式、配色、对比度、字体与字号、语言。'
	String get themePageDescription => '主题模式、配色、对比度、字体与字号、语言。';

	/// zh-CN: '字体、文本缩放与各级字号。'
	String get typographyPageDescription => '字体、文本缩放与各级字号。';

	/// zh-CN: 'Wi-Fi 与移动网络下的默认清晰度。'
	String get qualityPageDescription => 'Wi-Fi 与移动网络下的默认清晰度。';

	/// zh-CN: '默认音量、静音与后台音频。'
	String get audioPageDescription => '默认音量、静音与后台音频。';

	/// zh-CN: '画面比例、悬浮窗与画中画。'
	String get picturePageDescription => '画面比例、悬浮窗与画中画。';

	/// zh-CN: '应用内悬浮窗与系统画中画的大小、位置与置顶。'
	String get floatingWindowPageDescription => '应用内悬浮窗与系统画中画的大小、位置与置顶。';

	/// zh-CN: '画面显示'
	String get pictureDisplayGroup => '画面显示';

	/// zh-CN: '应用内悬浮窗'
	String get floatWindowGroup => '应用内悬浮窗';

	/// zh-CN: '系统画中画'
	String get pipGroup => '系统画中画';

	/// zh-CN: '播放设置将在播放器接入后开放。'
	String get playbackComingSoon => '播放设置将在播放器接入后开放。';

	/// zh-CN: '站点管理与账号登录即将接入。'
	String get sitesComingSoon => '站点管理与账号登录即将接入。';

	/// zh-CN: '数据管理即将接入。'
	String get dataComingSoon => '数据管理即将接入。';

	/// zh-CN: '外观'
	String get appearance => '外观';

	/// zh-CN: '主题'
	String get themeMode => '主题';

	/// zh-CN: '跟随系统'
	String get themeModeSystem => '跟随系统';

	/// zh-CN: '浅色'
	String get themeModeLight => '浅色';

	/// zh-CN: '深色'
	String get themeModeDark => '深色';

	/// zh-CN: '跟随背景明暗'
	String get followBackgroundTone => '跟随背景明暗';

	/// zh-CN: '有背景时按壁纸明暗自动选择浅色或深色主题；手动选择主题会自动关闭此跟随。'
	String get followBackgroundToneDescription => '有背景时按壁纸明暗自动选择浅色或深色主题；手动选择主题会自动关闭此跟随。';

	/// zh-CN: '语言'
	String get language => '语言';

	/// zh-CN: '关于'
	String get about => '关于';

	/// zh-CN: '显示'
	String get refreshRateGroup => '显示';

	/// zh-CN: '刷新率'
	String get refreshRateDisplay => '刷新率';

	/// zh-CN: '重新读取刷新率'
	String get refreshRateRefresh => '重新读取刷新率';

	/// zh-CN: '当前 {current} · 最高 {max}'
	String refreshRateCurrentMax({required Object current, required Object max}) => '当前 ${current} · 最高 ${max}';

	/// zh-CN: '未知'
	String get refreshRateUnknown => '未知';

	/// zh-CN: '低电量模式'
	String get refreshRateLowPower => '低电量模式';

	/// zh-CN: '刷新率模式'
	String get refreshRateMode => '刷新率模式';

	/// zh-CN: '节能交给系统自动调；均衡只在触摸或滚动时升频，停手 1.5 秒后释放；性能恒定最高。平台不支持的选项不显示。'
	String get refreshRateModeDesc => '节能交给系统自动调；均衡只在触摸或滚动时升频，停手 1.5 秒后释放；性能恒定最高。平台不支持的选项不显示。';

	/// zh-CN: '节能'
	String get refreshRatePowerSaving => '节能';

	/// zh-CN: '均衡（交互自适应）'
	String get refreshRateBalanced => '均衡（交互自适应）';

	/// zh-CN: '性能（最高刷新率）'
	String get refreshRatePerformance => '性能（最高刷新率）';

	/// zh-CN: '此平台只支持读取刷新率'
	String get refreshRateReadOnly => '此平台只支持读取刷新率';

	/// zh-CN: '系统未开放刷新率接口；显示的是显示器实际值。'
	String get refreshRateReadOnlyDesc => '系统未开放刷新率接口；显示的是显示器实际值。';

	/// zh-CN: '播放时匹配视频帧率'
	String get refreshRateMatchVideo => '播放时匹配视频帧率';

	/// zh-CN: '刷新率取视频帧率的整数倍，画面更匀；只在不会闪屏时切换，源未声明帧率则不动。'
	String get refreshRateMatchVideoDesc => '刷新率取视频帧率的整数倍，画面更匀；只在不会闪屏时切换，源未声明帧率则不动。';

	/// zh-CN: '这台设备只有 {rate} Hz，用不上'
	String refreshRateMatchVideoSingle({required Object rate}) => '这台设备只有 ${rate} Hz，用不上';

	/// zh-CN: '此设备的系统接口不支持按视频内容切换刷新率'
	String get refreshRateMatchVideoUnsupported => '此设备的系统接口不支持按视频内容切换刷新率';

	/// zh-CN: '更新'
	String get updateGroup => '更新';

	/// zh-CN: '启动时自动检查更新'
	String get autoCheckUpdate => '启动时自动检查更新';

	/// zh-CN: '每次启动静默读取一次发布源；结果在“关于”里显示，失败不打扰。'
	String get autoCheckUpdateDesc => '每次启动静默读取一次发布源；结果在“关于”里显示，失败不打扰。';

	/// zh-CN: '窗口尺寸'
	String get windowSize => '窗口尺寸';

	/// zh-CN: '启动时使用的窗口大小；应用后立即居中并记住。'
	String get windowSizeDesc => '启动时使用的窗口大小；应用后立即居中并记住。';

	/// zh-CN: '宽度'
	String get windowWidth => '宽度';

	/// zh-CN: '高度'
	String get windowHeight => '高度';

	/// zh-CN: '宽度 400–16384，高度 300–16384（逻辑像素）。'
	String get windowSizeRangeHint => '宽度 400–16384，高度 300–16384（逻辑像素）。';

	/// zh-CN: '尺寸超出范围：宽 400–16384，高 300–16384。'
	String get windowSizeOutOfRange => '尺寸超出范围：宽 400–16384，高 300–16384。';

	/// zh-CN: '窗口尺寸应用失败。'
	String get windowSizeApplyFailed => '窗口尺寸应用失败。';

	/// zh-CN: '窗口尺寸已应用。'
	String get windowSizeApplied => '窗口尺寸已应用。';

	/// zh-CN: '开机启动'
	String get startup => '开机启动';

	/// zh-CN: '登录系统后自动打开 Pure Live；开关读取真实启动项。'
	String get startupDesc => '登录系统后自动打开 Pure Live；开关读取真实启动项。';

	/// zh-CN: '开机启动设置失败'
	String get startupFailed => '开机启动设置失败';

	/// zh-CN: '启动动画'
	String get splashAnimation => '启动动画';

	/// zh-CN: '启动时先显示应用标记，再进入主界面；下次启动生效。'
	String get splashAnimationDesc => '启动时先显示应用标记，再进入主界面；下次启动生效。';

	/// zh-CN: '配置预览'
	String get configPreview => '配置预览';

	/// zh-CN: '备份所携带的设置项，只读；JSON 格式，可复制。'
	String get configPreviewDesc => '备份所携带的设置项，只读；JSON 格式，可复制。';

	/// zh-CN: '复制'
	String get configPreviewCopy => '复制';

	/// zh-CN: '配置已复制'
	String get configPreviewCopied => '配置已复制';

	/// zh-CN: '定时关机'
	String get autoShutdownGroup => '定时关机';

	/// zh-CN: '启用定时关机'
	String get autoShutdown => '启用定时关机';

	/// zh-CN: '倒计时结束后自动退出应用；关闭后立即取消。'
	String get autoShutdownDesc => '倒计时结束后自动退出应用；关闭后立即取消。';

	/// zh-CN: '关机倒计时'
	String get autoShutdownDuration => '关机倒计时';

	/// zh-CN: '剩余 {time}'
	String autoShutdownRemaining({required Object time}) => '剩余 ${time}';

	/// zh-CN: '{count} 分钟'
	String autoShutdownMinutes({required Object count}) => '${count} 分钟';

	/// zh-CN: '{minutes} 分钟'
	String autoShutdownPreset({required Object minutes}) => '${minutes} 分钟';

	/// zh-CN: '自定义分钟数'
	String get autoShutdownCustom => '自定义分钟数';

	/// zh-CN: '范围 1–525600 分钟。'
	String get autoShutdownRange => '范围 1–525600 分钟。';

	/// zh-CN: '请输入 1–525600 之间的分钟数。'
	String get autoShutdownInvalid => '请输入 1–525600 之间的分钟数。';

	/// zh-CN: '关机时长已设置。'
	String get autoShutdownSaved => '关机时长已设置。';

	/// zh-CN: '刷新率读取失败'
	String get refreshRateFailed => '刷新率读取失败';

	/// zh-CN: '刷新率请求未生效'
	String get refreshRateApplyFailed => '刷新率请求未生效';

	/// zh-CN: '检测到 {count} 台显示器'
	String refreshRateMultiMonitor({required Object count}) => '检测到 ${count} 台显示器';

	/// zh-CN: '刷新率读数来自当前窗口所在的那一台显示器。'
	String get refreshRateMultiMonitorDesc => '刷新率读数来自当前窗口所在的那一台显示器。';

	/// zh-CN: '平台显示'
	String get sitesDisplay => '平台显示';

	/// zh-CN: '关闭的平台不再出现在热门、分区、关注与搜索的平台列表里。'
	String get sitesDisplayDesc => '关闭的平台不再出现在热门、分区、关注与搜索的平台列表里。';

	/// zh-CN: '全部平台都在显示中。'
	String get sitesAllShown => '全部平台都在显示中。';

	/// zh-CN: '全部显示'
	String get sitesShowAll => '全部显示';

	/// zh-CN: '把关闭的平台全部打开。'
	String get sitesShowAllDesc => '把关闭的平台全部打开。';

	/// zh-CN: '清空观看历史'
	String get dataClearHistory => '清空观看历史';

	/// zh-CN: '删除全部观看记录，不可恢复。'
	String get dataClearHistoryDesc => '删除全部观看记录，不可恢复。';

	/// zh-CN: '导出关注'
	String get dataExportFollows => '导出关注';

	/// zh-CN: '把关注列表复制到剪贴板（JSON）。'
	String get dataExportFollowsDesc => '把关注列表复制到剪贴板（JSON）。';

	/// zh-CN: '导入关注'
	String get dataImportFollows => '导入关注';

	/// zh-CN: '从剪贴板读取此前导出的关注（JSON）。'
	String get dataImportFollowsDesc => '从剪贴板读取此前导出的关注（JSON）。';

	/// zh-CN: '已完成'
	String get dataDone => '已完成';

	/// zh-CN: '剪贴板内容无法识别'
	String get dataBadData => '剪贴板内容无法识别';

	/// zh-CN: '没有可导出的关注'
	String get dataEmpty => '没有可导出的关注';

	/// zh-CN: '清空观看历史？'
	String get confirmClearTitle => '清空观看历史？';

	/// zh-CN: '全部观看记录将被删除，此操作不可恢复。'
	String get confirmClearDesc => '全部观看记录将被删除，此操作不可恢复。';

	/// zh-CN: '清空'
	String get confirm => '清空';

	/// zh-CN: '版本'
	String get aboutVersion => '版本';

	/// zh-CN: '项目主页'
	String get aboutProject => '项目主页';

	/// zh-CN: '开源许可'
	String get aboutLicense => '开源许可';

	/// zh-CN: '查看本应用使用的开源组件。'
	String get aboutLicenseDesc => '查看本应用使用的开源组件。';

	/// zh-CN: '主题色'
	String get themeSeed => '主题色';

	/// zh-CN: '跟随系统取色'
	String get themeSeedSystem => '跟随系统取色';

	/// zh-CN: '用于按钮、选中态和强调色。'
	String get themeSeedDescription => '用于按钮、选中态和强调色。';

	/// zh-CN: '跟随系统动态取色'
	String get themeSeedDynamic => '跟随系统动态取色';

	/// zh-CN: '动态取色开启时由系统决定；关闭后可自选主题色。'
	String get themeSeedDynamicDescription => '动态取色开启时由系统决定；关闭后可自选主题色。';

	/// zh-CN: '动态取色'
	String get dynamicColor => '动态取色';

	/// zh-CN: '使用系统壁纸或强调色生成主题，覆盖当前主题色。'
	String get dynamicColorDescription => '使用系统壁纸或强调色生成主题，覆盖当前主题色。';

	/// zh-CN: '液体玻璃'
	String get liquidGlass => '液体玻璃';

	/// zh-CN: '首页底栏悬浮成毛玻璃；4 GB 以下机型只半透明不模糊。'
	String get liquidGlassDescription => '首页底栏悬浮成毛玻璃；4 GB 以下机型只半透明不模糊。';

	/// zh-CN: '主题色'
	String get themeColorTitle => '主题色';

	/// zh-CN: '预设颜色'
	String get themeColorPresets => '预设颜色';

	/// zh-CN: '自定义颜色'
	String get themeColorCustom => '自定义颜色';

	/// zh-CN: '十六进制颜色'
	String get themeColorHex => '十六进制颜色';

	/// zh-CN: '请输入 6 位或 8 位十六进制颜色，例如 #2196F3。'
	String get themeColorHexInvalid => '请输入 6 位或 8 位十六进制颜色，例如 #2196F3。';

	/// zh-CN: '色相'
	String get themeColorHue => '色相';

	/// zh-CN: '饱和度与明度'
	String get themeColorSaturation => '饱和度与明度';

	/// zh-CN: '蓝'
	String get seedBlue => '蓝';

	/// zh-CN: '藏青'
	String get seedNavy => '藏青';

	/// zh-CN: '石墨'
	String get seedGraphite => '石墨';

	/// zh-CN: '绛红'
	String get seedOxblood => '绛红';

	/// zh-CN: '森绿'
	String get seedForest => '森绿';

	/// zh-CN: '靛蓝'
	String get seedIndigo => '靛蓝';

	/// zh-CN: '圆角'
	String get corners => '圆角';

	/// zh-CN: '标准'
	String get cornersStandard => '标准';

	/// zh-CN: '锐利'
	String get cornersSharp => '锐利';

	/// zh-CN: '柔和'
	String get cornersSoft => '柔和';

	/// zh-CN: '胶囊'
	String get cornersPill => '胶囊';

	/// zh-CN: '控件密度'
	String get density => '控件密度';

	/// zh-CN: '跟随平台'
	String get densitySystem => '跟随平台';

	/// zh-CN: '紧凑'
	String get densityCompact => '紧凑';

	/// zh-CN: '触控'
	String get densityTouch => '触控';

	/// zh-CN: '跟随系统'
	String get languageSystem => '跟随系统';

	/// zh-CN: '简体中文'
	String get languageSimplifiedChinese => '简体中文';

	/// zh-CN: 'English'
	String get languageEnglish => 'English';

	/// zh-CN: '刷新'
	String get refreshGroup => '刷新';

	/// zh-CN: '关注自动刷新'
	String get followsAutoRefresh => '关注自动刷新';

	/// zh-CN: '停留在关注页时按间隔刷新关注列表。'
	String get followsAutoRefreshDesc => '停留在关注页时按间隔刷新关注列表。';

	/// zh-CN: '开播提醒'
	String get liveAlert => '开播提醒';

	/// zh-CN: '关注的主播开播时发系统通知；运行时每 15 分钟检查。'
	String get liveAlertDesc => '关注的主播开播时发系统通知；运行时每 15 分钟检查。';

	/// zh-CN: '提醒标签'
	String get liveAlertTags => '提醒标签';

	/// zh-CN: '只提醒带有所选标签的关注；不选则覆盖全部关注。'
	String get liveAlertTagsDesc => '只提醒带有所选标签的关注；不选则覆盖全部关注。';

	/// zh-CN: '全部关注'
	String get liveAlertTagsAll => '全部关注';

	/// zh-CN: '还没有标签；提醒将覆盖全部关注。'
	String get liveAlertTagsNone => '还没有标签；提醒将覆盖全部关注。';

	/// zh-CN: '已选 {selected} 个'
	String liveAlertTagCount({required Object selected}) => '已选 ${selected} 个';

	/// zh-CN: '{platform} 房间 {roomId}'
	String liveAlertFallbackTitle({required Object platform, required Object roomId}) => '${platform} 房间 ${roomId}';

	/// zh-CN: '正在 {platform} 直播'
	String liveAlertNotificationBody({required Object platform}) => '正在 ${platform} 直播';

	/// zh-CN: '刷新间隔'
	String get refreshInterval => '刷新间隔';

	/// zh-CN: '观看历史上限'
	String get historyLimit => '观看历史上限';

	/// zh-CN: '超过上限的最早记录会被删除。'
	String get historyLimitDesc => '超过上限的最早记录会被删除。';

	/// zh-CN: '网络'
	String get navNetwork => '网络';

	/// zh-CN: '应用代理与传输行为。'
	String get networkDescription => '应用代理与传输行为。';

	/// zh-CN: '应用代理'
	String get proxy => '应用代理';

	/// zh-CN: '主机'
	String get proxyHost => '主机';

	/// zh-CN: '代理服务器的主机名或地址。'
	String get proxyHostDesc => '代理服务器的主机名或地址。';

	/// zh-CN: '端口'
	String get proxyPort => '端口';

	/// zh-CN: '代理服务器监听的端口。'
	String get proxyPortDesc => '代理服务器监听的端口。';

	/// zh-CN: '不使用代理'
	String get proxyModeOff => '不使用代理';

	/// zh-CN: '点播、节目单与备份的请求都直连。'
	String get proxyModeOffDesc => '点播、节目单与备份的请求都直连。';

	/// zh-CN: '跟随系统代理'
	String get proxyModeSystem => '跟随系统代理';

	/// zh-CN: '使用操作系统自己配置的 HTTP 代理，没有配置时直连。'
	String get proxyModeSystemDesc => '使用操作系统自己配置的 HTTP 代理，没有配置时直连。';

	/// zh-CN: '手动代理'
	String get proxyModeManual => '手动代理';

	/// zh-CN: '使用下方填写的主机与端口。'
	String get proxyModeManualDesc => '使用下方填写的主机与端口。';

	/// zh-CN: '正在检测系统代理…'
	String get proxySystemProbing => '正在检测系统代理…';

	/// zh-CN: '系统代理：{host}'
	String proxySystemResolved({required Object host}) => '系统代理：${host}';

	/// zh-CN: '未检测到系统代理，当前直连。'
	String get proxySystemNone => '未检测到系统代理，当前直连。';

	/// zh-CN: '系统代理是 PAC 脚本或非 HTTP 代理，无法自动套用；请改用手动代理。'
	String get proxySystemNotExpressible => '系统代理是 PAC 脚本或非 HTTP 代理，无法自动套用；请改用手动代理。';

	/// zh-CN: '当前平台没有可读的系统代理设置；请改用手动代理。'
	String get proxySystemUnsupported => '当前平台没有可读的系统代理设置；请改用手动代理。';

	/// zh-CN: '系统代理检测失败，当前直连。'
	String get proxySystemFailed => '系统代理检测失败，当前直连。';

	/// zh-CN: '重新检测系统代理'
	String get proxySystemRecheck => '重新检测系统代理';

	/// zh-CN: '代理客户端在启动后才开启或关闭时，不必重启应用。'
	String get proxySystemRecheckDesc => '代理客户端在启动后才开启或关闭时，不必重启应用。';

	/// zh-CN: 'GitHub 加速'
	String get githubMirrorTitle => 'GitHub 加速';

	/// zh-CN: '下载方式'
	String get githubMirrorMode => '下载方式';

	/// zh-CN: '字体等 GitHub 资源从哪个地址下载。'
	String get githubMirrorModeDesc => '字体等 GitHub 资源从哪个地址下载。';

	/// zh-CN: '默认（不加速）'
	String get githubMirrorOff => '默认（不加速）';

	/// zh-CN: '官方源 · 可能较慢'
	String get githubMirrorOfficial => '官方源 · 可能较慢';

	/// zh-CN: '自定义…'
	String get githubMirrorCustom => '自定义…';

	/// zh-CN: '自填镜像域名'
	String get githubMirrorCustomDetail => '自填镜像域名';

	/// zh-CN: '自定义加速域名'
	String get githubMirrorCustomDomain => '自定义加速域名';

	/// zh-CN: '以 https:// 开头，直接拼在原始地址前面。'
	String get githubMirrorCustomDesc => '以 https:// 开头，直接拼在原始地址前面。';

	/// zh-CN: '留空回退直连：下载失败自动回退直连兜底。'
	String get githubMirrorHint => '留空回退直连：下载失败自动回退直连兜底。';

	/// zh-CN: '镜像地址'
	String get githubMirrorList => '镜像地址';

	/// zh-CN: '从远程更新'
	String get githubMirrorRefresh => '从远程更新';

	/// zh-CN: '正在获取远程镜像…'
	String get githubMirrorRefreshing => '正在获取远程镜像…';

	/// zh-CN: '尚未获取远程镜像。'
	String get githubMirrorNever => '尚未获取远程镜像。';

	/// zh-CN: '远程更新于 {time}'
	String githubMirrorUpdated({required Object time}) => '远程更新于 ${time}';

	/// zh-CN: '远程获取失败：{error}'
	String githubMirrorFailed({required Object error}) => '远程获取失败：${error}';

	/// zh-CN: '添加镜像地址'
	String get githubMirrorAdd => '添加镜像地址';

	/// zh-CN: '添加镜像地址'
	String get githubMirrorAddTitle => '添加镜像地址';

	/// zh-CN: '填一个 https:// 开头的镜像域名，作为下载前缀。'
	String get githubMirrorAddDesc => '填一个 https:// 开头的镜像域名，作为下载前缀。';

	/// zh-CN: '地址无效：需要以 https:// 开头'
	String get githubMirrorAddInvalid => '地址无效：需要以 https:// 开头';

	/// zh-CN: '没有可用的镜像地址。'
	String get githubMirrorEmpty => '没有可用的镜像地址。';

	/// zh-CN: '恢复内置镜像'
	String get githubMirrorRestore => '恢复内置镜像';

	/// zh-CN: '内置'
	String get githubMirrorSourceBuiltin => '内置';

	/// zh-CN: '远程'
	String get githubMirrorSourceRemote => '远程';

	/// zh-CN: '自定义'
	String get githubMirrorSourceCustom => '自定义';

	/// zh-CN: '前缀代理'
	String get githubMirrorStrategyPrefix => '前缀代理';

	/// zh-CN: '替换 Raw 域名'
	String get githubMirrorStrategyRaw => '替换 Raw 域名';

	/// zh-CN: 'jsDelivr 路径'
	String get githubMirrorStrategyJsdelivr => 'jsDelivr 路径';

	/// zh-CN: '工具区排序'
	String get toolsOrder => '工具区排序';

	/// zh-CN: '侧栏分区线下方工具的显示顺序。'
	String get toolsOrderDesc => '侧栏分区线下方工具的显示顺序。';

	/// zh-CN: '上移'
	String get moveUp => '上移';

	/// zh-CN: '下移'
	String get moveDown => '下移';

	/// zh-CN: '弹幕屏蔽'
	String get navShield => '弹幕屏蔽';

	/// zh-CN: '屏蔽关键词、用户与相似弹幕，直播间弹幕按此过滤。'
	String get shieldDescription => '屏蔽关键词、用户与相似弹幕，直播间弹幕按此过滤。';

	/// zh-CN: '弹幕过滤'
	String get danmakuFilter => '弹幕过滤';

	/// zh-CN: '关键词、用户与相似弹幕过滤。'
	String get danmakuFilterDesc => '关键词、用户与相似弹幕过滤。';

	/// zh-CN: '弹幕显示'
	String get danmakuDisplayGroup => '弹幕显示';

	/// zh-CN: '弹幕列表'
	String get danmakuList => '弹幕列表';

	/// zh-CN: '在画面上显示飞行弹幕'
	String get showFlyingDanmaku => '在画面上显示飞行弹幕';

	/// zh-CN: '关闭后弹幕只在聊天列表里显示。'
	String get showFlyingDanmakuDesc => '关闭后弹幕只在聊天列表里显示。';

	/// zh-CN: '画面弹幕交互'
	String get danmakuInteractionGroup => '画面弹幕交互';

	/// zh-CN: '点击画面弹幕查看操作'
	String get styleTapInteraction => '点击画面弹幕查看操作';

	/// zh-CN: '点按弹幕打开面板，可复制或屏蔽；关闭后点按画面只切换控制条。'
	String get styleTapInteractionDesc => '点按弹幕打开面板，可复制或屏蔽；关闭后点按画面只切换控制条。';

	/// zh-CN: '长按画面弹幕查看操作'
	String get styleLongPressInteraction => '长按画面弹幕查看操作';

	/// zh-CN: '长按画面上的弹幕打开同一操作面板；关闭后长按不再命中弹幕。'
	String get styleLongPressInteractionDesc => '长按画面上的弹幕打开同一操作面板；关闭后长按不再命中弹幕。';

	/// zh-CN: '弹幕样式'
	String get danmakuStyleGroup => '弹幕样式';

	/// zh-CN: '弹幕的字体、大小、速度、区域、描边与帧率。'
	String get danmakuStyleDescription => '弹幕的字体、大小、速度、区域、描边与帧率。';

	/// zh-CN: '聊天列表显示谁、显示什么、怎么排。'
	String get danmakuDisplayDescription => '聊天列表显示谁、显示什么、怎么排。';

	/// zh-CN: '弹幕预设已应用'
	String get danmakuPresetApplied => '弹幕预设已应用';

	/// zh-CN: '这是真实弹幕引擎按当前设置画的样例；改动会立刻反映在这里。'
	String get danmakuPreviewHint => '这是真实弹幕引擎按当前设置画的样例；改动会立刻反映在这里。';

	/// zh-CN: '弹幕预览'
	String get danmakuPreview => '弹幕预览';

	/// zh-CN: '聊天列表内容'
	String get chatListGroup => '聊天列表内容';

	/// zh-CN: '聊天列表排版'
	String get chatListLayoutGroup => '聊天列表排版';

	/// zh-CN: '弹幕字体'
	String get danmakuFont => '弹幕字体';

	/// zh-CN: '画面飞行弹幕使用的字体；聊天列表保持界面字体。'
	String get danmakuFontDescription => '画面飞行弹幕使用的字体；聊天列表保持界面字体。';

	/// zh-CN: 'MiSans 随应用提供；国内字体来自免费商用库，国外来自 Google Fonts，选中即应用于飞行弹幕。'
	String get danmakuFontManagerDescription => 'MiSans 随应用提供；国内字体来自免费商用库，国外来自 Google Fonts，选中即应用于飞行弹幕。';

	/// zh-CN: '字体大小'
	String get styleFontSize => '字体大小';

	/// zh-CN: '画面飞行弹幕字形的高度，单位像素。'
	String get styleFontSizeDesc => '画面飞行弹幕字形的高度，单位像素。';

	/// zh-CN: '字体粗细'
	String get styleFontWeight => '字体粗细';

	/// zh-CN: '字形的粗细；400 为常规，700 为加粗。'
	String get styleFontWeightDesc => '字形的粗细；400 为常规，700 为加粗。';

	/// zh-CN: '文字间距'
	String get styleLetterSpacing => '文字间距';

	/// zh-CN: '字符之间额外增加的间距，单位像素。'
	String get styleLetterSpacingDesc => '字符之间额外增加的间距，单位像素。';

	/// zh-CN: '极细'
	String get styleWeightThin => '极细';

	/// zh-CN: '很细'
	String get styleWeightExtraLight => '很细';

	/// zh-CN: '偏细'
	String get styleWeightLight => '偏细';

	/// zh-CN: '正常'
	String get styleWeightNormal => '正常';

	/// zh-CN: '稍粗'
	String get styleWeightMedium => '稍粗';

	/// zh-CN: '中粗'
	String get styleWeightSemiBold => '中粗';

	/// zh-CN: '粗体'
	String get styleWeightBold => '粗体';

	/// zh-CN: '很粗'
	String get styleWeightExtraBold => '很粗';

	/// zh-CN: '特粗'
	String get styleWeightBlack => '特粗';

	/// zh-CN: '速度'
	String get styleSpeed => '速度';

	/// zh-CN: '弹幕横穿画面的速度，单位像素每秒。'
	String get styleSpeedDesc => '弹幕横穿画面的速度，单位像素每秒。';

	/// zh-CN: '画面顶部占用高度'
	String get styleArea => '画面顶部占用高度';

	/// zh-CN: '弹幕最多占用画面高度的比例（0–100%）。'
	String get styleAreaDesc => '弹幕最多占用画面高度的比例（0–100%）。';

	/// zh-CN: '顶部固定弹幕'
	String get fixedTopTitle => '顶部固定弹幕';

	/// zh-CN: '平台的置顶弹幕停在画面上方；关闭后只在聊天列表里显示。'
	String get fixedTopDescription => '平台的置顶弹幕停在画面上方；关闭后只在聊天列表里显示。';

	/// zh-CN: '底部固定弹幕'
	String get fixedBottomTitle => '底部固定弹幕';

	/// zh-CN: '平台的置底弹幕停在画面下方；关闭后只在聊天列表里显示。'
	String get fixedBottomDescription => '平台的置底弹幕停在画面下方；关闭后只在聊天列表里显示。';

	/// zh-CN: '固定弹幕停留时长'
	String get fixedDurationTitle => '固定弹幕停留时长';

	/// zh-CN: '顶部与底部固定弹幕停留的时间，2–10 秒。'
	String get fixedDurationDescription => '顶部与底部固定弹幕停留的时间，2–10 秒。';

	/// zh-CN: '不透明度'
	String get styleOpacity => '不透明度';

	/// zh-CN: '弹幕相对画面的厚实程度；100% 时完全遮住弹幕。'
	String get styleOpacityDesc => '弹幕相对画面的厚实程度；100% 时完全遮住弹幕。';

	/// zh-CN: '描边'
	String get styleStroke => '描边';

	/// zh-CN: '给弹幕文字加描边，浅色画面上更清楚。'
	String get styleStrokeDesc => '给弹幕文字加描边，浅色画面上更清楚。';

	/// zh-CN: '描边宽度'
	String get styleStrokeWidth => '描边宽度';

	/// zh-CN: '描边开启时文字外圈的粗细（0–4 像素）。'
	String get styleStrokeWidthDesc => '描边开启时文字外圈的粗细（0–4 像素）。';

	/// zh-CN: '弹幕帧率跟随界面刷新率'
	String get styleFpsFollow => '弹幕帧率跟随界面刷新率';

	/// zh-CN: '跟随「通用」里的省电、均衡或最高档位；关闭后可以手动设帧率。'
	String get styleFpsFollowDesc => '跟随「通用」里的省电、均衡或最高档位；关闭后可以手动设帧率。';

	/// zh-CN: '弹幕帧率'
	String get styleFps => '弹幕帧率';

	/// zh-CN: '飞行层每秒重绘的次数；越高越顺滑，也更耗性能。'
	String get styleFpsDesc => '飞行层每秒重绘的次数；越高越顺滑，也更耗性能。';

	/// zh-CN: '{count} FPS'
	String styleFpsValue({required Object count}) => '${count} FPS';

	/// zh-CN: '同屏最大弹幕条数'
	String get styleMaxVisible => '同屏最大弹幕条数';

	/// zh-CN: '同屏弹幕最多几条，默认 48；少些更清楚省电。'
	String get styleMaxVisibleDesc => '同屏弹幕最多几条，默认 48；少些更清楚省电。';

	/// zh-CN: '{count} 条'
	String styleMaxVisibleValue({required Object count}) => '${count} 条';

	/// zh-CN: '海量模式'
	String get styleMassMode => '海量模式';

	/// zh-CN: '同屏上限提到 1000 条并用实时渲染，适合超密弹幕。'
	String get styleMassModeDesc => '同屏上限提到 1000 条并用实时渲染，适合超密弹幕。';

	/// zh-CN: '斜体'
	String get styleItalic => '斜体';

	/// zh-CN: '文字颜色'
	String get styleTextColor => '文字颜色';

	/// zh-CN: '描边颜色'
	String get styleStrokeColor => '描边颜色';

	/// zh-CN: '文字阴影'
	String get styleShadow => '文字阴影';

	/// zh-CN: '阴影颜色'
	String get styleShadowColor => '阴影颜色';

	/// zh-CN: '阴影模糊'
	String get styleShadowBlur => '阴影模糊';

	/// zh-CN: '阴影水平偏移'
	String get styleShadowOffsetX => '阴影水平偏移';

	/// zh-CN: '阴影垂直偏移'
	String get styleShadowOffsetY => '阴影垂直偏移';

	/// zh-CN: '轨道与安全区'
	String get danmakuLaneGroup => '轨道与安全区';

	/// zh-CN: '轨道高度'
	String get styleTrackHeight => '轨道高度';

	/// zh-CN: '表情大小'
	String get styleEmojiSize => '表情大小';

	/// zh-CN: '弹幕安全间距'
	String get styleOverlapGap => '弹幕安全间距';

	/// zh-CN: '避开屏幕安全区'
	String get styleSafeArea => '避开屏幕安全区';

	/// zh-CN: '队列与性能'
	String get danmakuQueueGroup => '队列与性能';

	/// zh-CN: '等待队列上限'
	String get styleMaxPending => '等待队列上限';

	/// zh-CN: '队列最长等待'
	String get styleMaxPendingAge => '队列最长等待';

	/// zh-CN: '发送间隔'
	String get styleEmitInterval => '发送间隔';

	/// zh-CN: '文字光栅化'
	String get styleRasterize => '文字光栅化';

	/// zh-CN: '弹幕对象池'
	String get styleBarragePool => '弹幕对象池';

	/// zh-CN: '图片缓存数量'
	String get stylePictureCache => '图片缓存数量';

	/// zh-CN: '文字缓存数量'
	String get styleTextCache => '文字缓存数量';

	/// zh-CN: '光栅缓存上限'
	String get styleRasterCache => '光栅缓存上限';

	/// zh-CN: '白色'
	String get danmakuColorWhite => '白色';

	/// zh-CN: '黑色'
	String get danmakuColorBlack => '黑色';

	/// zh-CN: '红色'
	String get danmakuColorRed => '红色';

	/// zh-CN: '橙色'
	String get danmakuColorOrange => '橙色';

	/// zh-CN: '黄色'
	String get danmakuColorYellow => '黄色';

	/// zh-CN: '绿色'
	String get danmakuColorGreen => '绿色';

	/// zh-CN: '青色'
	String get danmakuColorCyan => '青色';

	/// zh-CN: '蓝色'
	String get danmakuColorBlue => '蓝色';

	/// zh-CN: '紫色'
	String get danmakuColorPurple => '紫色';

	/// zh-CN: '粉色'
	String get danmakuColorPink => '粉色';

	/// zh-CN: '弹幕文件'
	String get danmakuSaveGroup => '弹幕文件';

	/// zh-CN: '录制与下载视频时，弹幕按所选格式各存一份同名文件；关闭全部选项时保留 XML。'
	String get danmakuSaveDescription => '录制与下载视频时，弹幕按所选格式各存一份同名文件；关闭全部选项时保留 XML。';

	/// zh-CN: '保存格式'
	String get danmakuSaveFormats => '保存格式';

	/// zh-CN: 'B站 XML'
	String get danmakuFormatXml => 'B站 XML';

	/// zh-CN: 'B站 JSON'
	String get danmakuFormatJson => 'B站 JSON';

	/// zh-CN: 'ASS 字幕'
	String get danmakuFormatAss => 'ASS 字幕';

	/// zh-CN: 'SRT 字幕'
	String get danmakuFormatSrt => 'SRT 字幕';

	/// zh-CN: '纯文本'
	String get danmakuFormatTxt => '纯文本';

	/// zh-CN: '小窗弹幕比例自动'
	String get pipDanmakuScaleAuto => '小窗弹幕比例自动';

	/// zh-CN: '按小窗宽度自动缩小弹幕，不超过主弹幕大小；关闭用下方固定比例。'
	String get pipDanmakuScaleAutoDesc => '按小窗宽度自动缩小弹幕，不超过主弹幕大小；关闭用下方固定比例。';

	/// zh-CN: '小窗弹幕比例'
	String get pipDanmakuScale => '小窗弹幕比例';

	/// zh-CN: '关闭自动小窗比例时使用的固定倍率。'
	String get pipDanmakuScaleDesc => '关闭自动小窗比例时使用的固定倍率。';

	/// zh-CN: '恢复默认'
	String get styleReset => '恢复默认';

	/// zh-CN: '顶部 20% · 均衡'
	String get danmakuPresetBest => '顶部 20% · 均衡';

	/// zh-CN: '顶部 35% · 舒适'
	String get danmakuPresetComfort => '顶部 35% · 舒适';

	/// zh-CN: '顶部 55% · 高密度'
	String get danmakuPresetDense => '顶部 55% · 高密度';

	/// zh-CN: '全屏全量'
	String get danmakuPresetFull => '全屏全量';

	/// zh-CN: '全屏全量=弹幕铺满整个画面；其它预设只占用顶部区域'
	String get danmakuPresetHint => '全屏全量=弹幕铺满整个画面；其它预设只占用顶部区域';

	/// zh-CN: '自定义'
	String get danmakuPresetCustom => '自定义';

	/// zh-CN: '预设'
	String get preset => '预设';

	/// zh-CN: '设置生效范围'
	String get prefScope => '设置生效范围';

	/// zh-CN: '选择只在本窗口生效，还是应用到主窗口与全部直播间窗口。'
	String get prefScopeDesc => '选择只在本窗口生效，还是应用到主窗口与全部直播间窗口。';

	/// zh-CN: '仅本窗口'
	String get prefScopeLocal => '仅本窗口';

	/// zh-CN: '所有窗口'
	String get prefScopeGlobal => '所有窗口';

	/// zh-CN: '窗口'
	String get windowGroup => '窗口';

	/// zh-CN: '直播间在独立窗口打开'
	String get roomWindow => '直播间在独立窗口打开';

	/// zh-CN: '每个直播间一个独立窗口；关闭后在主窗口内浏览。仅桌面端。'
	String get roomWindowDesc => '每个直播间一个独立窗口；关闭后在主窗口内浏览。仅桌面端。';

	/// zh-CN: '关闭窗口时'
	String get closeAction => '关闭窗口时';

	/// zh-CN: '隐藏到托盘时应用保持运行，点托盘图标恢复窗口。'
	String get closeActionDesc => '隐藏到托盘时应用保持运行，点托盘图标恢复窗口。';

	/// zh-CN: '退出应用'
	String get closeQuit => '退出应用';

	/// zh-CN: '最小化到任务栏'
	String get closeMinimise => '最小化到任务栏';

	/// zh-CN: '隐藏到托盘'
	String get closeHideToTray => '隐藏到托盘';

	/// zh-CN: '退出不再询问'
	String get noExitConfirm => '退出不再询问';

	/// zh-CN: '开启后点关闭直接执行上面的行为；关闭则每次先确认。'
	String get noExitConfirmDescription => '开启后点关闭直接执行上面的行为；关闭则每次先确认。';

	/// zh-CN: '关闭窗口'
	String get closeWindowTitle => '关闭窗口';

	/// zh-CN: '要退出应用，还是最小化后继续运行？'
	String get closeWindowQuestion => '要退出应用，还是最小化后继续运行？';

	/// zh-CN: '不再询问'
	String get closeDontAskAgain => '不再询问';

	/// zh-CN: '显示主窗口'
	String get trayShow => '显示主窗口';

	/// zh-CN: '隐藏到托盘'
	String get trayHide => '隐藏到托盘';

	/// zh-CN: '截图'
	String get trayScreenshot => '截图';

	/// zh-CN: '打开声音'
	String get traySoundOn => '打开声音';

	/// zh-CN: '关闭声音'
	String get traySoundOff => '关闭声音';

	/// zh-CN: '已保存到 {path}'
	String trayScreenshotSaved({required Object path}) => '已保存到 ${path}';

	/// zh-CN: '截图失败：没有正在播放的房间或引擎不支持'
	String get trayScreenshotFailed => '截图失败：没有正在播放的房间或引擎不支持';

	/// zh-CN: '字体'
	String get font => '字体';

	/// zh-CN: 'MiSans 随应用打包并默认使用，也可换国内或国外字体。'
	String get fontDescription => 'MiSans 随应用打包并默认使用，也可换国内或国外字体。';

	/// zh-CN: 'MiSans（默认）'
	String get fontDefault => 'MiSans（默认）';

	/// zh-CN: '系统字体'
	String get fontSystemChinese => '系统字体';

	/// zh-CN: '国内'
	String get fontRegionDomestic => '国内';

	/// zh-CN: '国外'
	String get fontRegionOverseas => '国外';

	/// zh-CN: '字体管理'
	String get fontManagerTitle => '字体管理';

	/// zh-CN: '选择你喜欢的字体，让界面更符合你的审美。'
	String get fontManagerSubtitle => '选择你喜欢的字体，让界面更符合你的审美。';

	/// zh-CN: '纯粹直播'
	String get fontManagerSample => '纯粹直播';

	/// zh-CN: '本地字体'
	String get fontManagerLocal => '本地字体';

	/// zh-CN: '下载更多字体'
	String get fontManagerMore => '下载更多字体';

	/// zh-CN: '字体预览'
	String get fontManagerPreviewTitle => '字体预览';

	/// zh-CN: '预览'
	String get fontManagerPreviewAction => '预览';

	/// zh-CN: '下载后可预览'
	String get fontManagerPreviewPending => '下载后可预览';

	/// zh-CN: 'Google 字体'
	String get fontManagerGoogle => 'Google 字体';

	/// zh-CN: 'MiSans 随应用提供；国内字体来自免费商用库，国外来自 Google Fonts，选中即应用于全部界面。'
	String get fontManagerDescription => 'MiSans 随应用提供；国内字体来自免费商用库，国外来自 Google Fonts，选中即应用于全部界面。';

	/// zh-CN: '由系统提供，本机使用 {face}。'
	String fontManagerSystemDescription({required Object face}) => '由系统提供，本机使用 ${face}。';

	/// zh-CN: '随应用打包，所有平台默认使用。'
	String get fontManagerBundledNote => '随应用打包，所有平台默认使用。';

	/// zh-CN: '首次选择时从 Google Fonts 获取并缓存在本机，之后离线可用。'
	String get fontManagerGoogleNote => '首次选择时从 Google Fonts 获取并缓存在本机，之后离线可用。';

	/// zh-CN: '来自免费商用字体库，首次使用时下载并保存在本机。'
	String get fontManagerFreeFontNote => '来自免费商用字体库，首次使用时下载并保存在本机。';

	/// zh-CN: '使用中'
	String get fontManagerInUse => '使用中';

	/// zh-CN: '默认'
	String get fontManagerDefaultBadge => '默认';

	/// zh-CN: '当前字体'
	String get fontManagerCurrent => '当前字体';

	/// zh-CN: '恢复默认'
	String get fontManagerReset => '恢复默认';

	/// zh-CN: '全部'
	String get fontManagerFilterAll => '全部';

	/// zh-CN: '分类'
	String get fontManagerCategory => '分类';

	/// zh-CN: '共 {count} 款字体'
	String fontManagerCount({required Object count}) => '共 ${count} 款字体';

	/// zh-CN: '随应用打包'
	String get fontManagerTagBundled => '随应用打包';

	/// zh-CN: '免费字体库'
	String get fontManagerSourceFreeFont => '免费字体库';

	/// zh-CN: '使用'
	String get fontManagerUse => '使用';

	/// zh-CN: '下载并使用'
	String get fontManagerDownloadAndUse => '下载并使用';

	/// zh-CN: '下载中 {percent}%'
	String fontManagerDownloading({required Object percent}) => '下载中 ${percent}%';

	/// zh-CN: '下载失败'
	String get fontManagerDownloadFailed => '下载失败';

	/// zh-CN: '已下载'
	String get fontManagerDownloaded => '已下载';

	/// zh-CN: '未下载'
	String get fontManagerNotDownloaded => '未下载';

	/// zh-CN: '删除已下载的字体'
	String get fontManagerDeleteFont => '删除已下载的字体';

	/// zh-CN: '删除「{name}」在本机的字体文件？之后可再次下载。'
	String fontManagerDeleteQuestion({required Object name}) => '删除「${name}」在本机的字体文件？之后可再次下载。';

	/// zh-CN: '没有找到匹配的字体。'
	String get fontManagerNoResults => '没有找到匹配的字体。';

	/// zh-CN: '筛选字体'
	String get fontManagerFilterLabel => '筛选字体';

	/// zh-CN: '搜索字体名称'
	String get fontManagerSearchPlaceholder => '搜索字体名称';

	/// zh-CN: '字体列表翻页'
	String get fontManagerPageLabel => '字体列表翻页';

	/// zh-CN: '来源'
	String get fontManagerColumnSource => '来源';

	/// zh-CN: '大小'
	String get fontManagerColumnSize => '大小';

	/// zh-CN: '字体'
	String get fontManagerColumnFont => '字体';

	/// zh-CN: '状态'
	String get fontManagerColumnState => '状态';

	/// zh-CN: '操作'
	String get fontManagerColumnActions => '操作';

	/// zh-CN: '中文字体'
	String get fontManagerScriptChinese => '中文字体';

	/// zh-CN: '复制字体名称'
	String get fontManagerCopyName => '复制字体名称';

	/// zh-CN: '下载'
	String get fontManagerDownload => '下载';

	/// zh-CN: '下载中'
	String get fontManagerDownloadingShort => '下载中';

	/// zh-CN: '显示与设置'
	String get fontManagerDetails => '显示与设置';

	/// zh-CN: '已加载 {shown} / {total}'
	String fontManagerLoadedCount({required Object shown, required Object total}) => '已加载 ${shown} / ${total}';

	/// zh-CN: '正在加载更多…'
	String get fontManagerLoadingMore => '正在加载更多…';

	/// zh-CN: '黑体'
	String get fontCategoryHeiti => '黑体';

	/// zh-CN: '宋体'
	String get fontCategorySongti => '宋体';

	/// zh-CN: '楷体'
	String get fontCategoryKaiti => '楷体';

	/// zh-CN: '艺术体'
	String get fontCategoryArt => '艺术体';

	/// zh-CN: '手绘体'
	String get fontCategoryHandwriting => '手绘体';

	/// zh-CN: '英文'
	String get fontCategoryEnglish => '英文';

	/// zh-CN: '衬线'
	String get fontCategorySerif => '衬线';

	/// zh-CN: '无衬线'
	String get fontCategorySansSerif => '无衬线';

	/// zh-CN: '展示'
	String get fontCategoryDisplay => '展示';

	/// zh-CN: '等宽'
	String get fontCategoryMonospace => '等宽';

	/// zh-CN: '其他'
	String get fontCategoryOther => '其他';

	/// zh-CN: '文本缩放'
	String get textScale => '文本缩放';

	/// zh-CN: '按比例放大或缩小整个应用的文字；100% 为平台原始大小。'
	String get textScaleDescription => '按比例放大或缩小整个应用的文字；100% 为平台原始大小。';

	/// zh-CN: '返回应用'
	String get backHome => '返回应用';

	/// zh-CN: '缓存'
	String get navCache => '缓存';

	/// zh-CN: '封面与头像的磁盘缓存、清理上限。'
	String get cacheDescription => '封面与头像的磁盘缓存、清理上限。';

	/// zh-CN: '当前缓存大小'
	String get cacheSize => '当前缓存大小';

	/// zh-CN: '刷新'
	String get cacheRefresh => '刷新';

	/// zh-CN: '清除缓存'
	String get cacheClear => '清除缓存';

	/// zh-CN: '删除所有已缓存的封面、头像与站点图标。'
	String get cacheClearDesc => '删除所有已缓存的封面、头像与站点图标。';

	/// zh-CN: '缓存已清除'
	String get cacheCleared => '缓存已清除';

	/// zh-CN: '自动清理上限'
	String get cacheLimit => '自动清理上限';

	/// zh-CN: '超过上限时按最旧优先删除；关闭则只清理过期项。'
	String get cacheLimitDesc => '超过上限时按最旧优先删除；关闭则只清理过期项。';

	/// zh-CN: '不自动清理'
	String get cacheLimitOff => '不自动清理';

	/// zh-CN: '封面与头像会在本机缓存 30 天，过期或超限时自动清理。'
	String get cacheHint => '封面与头像会在本机缓存 30 天，过期或超限时自动清理。';

	/// zh-CN: '首选平台'
	String get preferPlatform => '首选平台';

	/// zh-CN: '热门与分区的优先平台，也是分区列表与搜索的起始平台。'
	String get preferPlatformDesc => '热门与分区的优先平台，也是分区列表与搜索的起始平台。';

	/// zh-CN: '搜索平台'
	String get preferPlatformFilterHint => '搜索平台';

	/// zh-CN: '没有匹配的平台'
	String get preferPlatformFilterEmpty => '没有匹配的平台';

	/// zh-CN: '恢复默认顺序'
	String get sitesOrderReset => '恢复默认顺序';

	/// zh-CN: '平台回到内置的排列顺序；显示开关不受影响。'
	String get sitesOrderResetDesc => '平台回到内置的排列顺序；显示开关不受影响。';

	/// zh-CN: '界面'
	String get groupInterface => '界面';

	/// zh-CN: '直播来源'
	String get groupSources => '直播来源';

	/// zh-CN: '播放'
	String get groupPlayback => '播放';

	/// zh-CN: '通用'
	String get groupGeneral => '通用';

	/// zh-CN: '应用'
	String get groupApp => '应用';

	/// zh-CN: '直播'
	String get groupLive => '直播';

	/// zh-CN: '导航栏'
	String get navNavigation => '导航栏';

	/// zh-CN: '自动刷新'
	String get navRefresh => '自动刷新';

	/// zh-CN: '网络代理'
	String get navProxy => '网络代理';

	/// zh-CN: '平台与账号'
	String get navPlatforms => '平台与账号';

	/// zh-CN: '首页菜单与工具区各自的显示与排序。'
	String get navigationDescription => '首页菜单与工具区各自的显示与排序。';

	/// zh-CN: '关注列表与直播缩略图的自动刷新。'
	String get refreshDescription => '关注列表与直播缩略图的自动刷新。';

	/// zh-CN: '应用级网络代理，所有站点请求都走它。'
	String get proxyDescription => '应用级网络代理，所有站点请求都走它。';

	/// zh-CN: '平台显示、排列顺序与账号登录。'
	String get platformsDescription => '平台显示、排列顺序与账号登录。';

	/// zh-CN: '搜索设置'
	String get searchSettings => '搜索设置';

	/// zh-CN: '没有匹配的设置'
	String get searchNoResults => '没有匹配的设置';

	/// zh-CN: '搜索结果'
	String get searchResults => '搜索结果';

	/// zh-CN: '卡片布局'
	String get browseLayoutGroup => '卡片布局';

	/// zh-CN: '每行卡片数'
	String get browseColumns => '每行卡片数';

	/// zh-CN: '自动'
	String get browseAuto => '自动';

	/// zh-CN: '列间距'
	String get crossSpacing => '列间距';

	/// zh-CN: '卡片网格里左右两张卡片之间的距离。'
	String get crossSpacingDescription => '卡片网格里左右两张卡片之间的距离。';

	/// zh-CN: '行间距'
	String get mainSpacing => '行间距';

	/// zh-CN: '卡片网格里上下两行之间的距离。'
	String get mainSpacingDescription => '卡片网格里上下两行之间的距离。';

	/// zh-CN: '视频'
	String get navVideo => '视频';

	/// zh-CN: '视频播放'
	String get vodPlayback => '视频播放';

	/// zh-CN: '播放设置'
	String get navVodPlayback => '播放设置';

	/// zh-CN: '界面设置'
	String get navVodInterface => '界面设置';

	/// zh-CN: '视频页显示哪些内容：详情区的开关。'
	String get vodInterfaceDescription => '视频页显示哪些内容：详情区的开关。';

	/// zh-CN: '默认倍速、一集播完后的动作，以及播放器下方显示的详情。'
	String get vodPlaybackDescription => '默认倍速、一集播完后的动作，以及播放器下方显示的详情。';

	/// zh-CN: '音乐'
	String get groupMusic => '音乐';

	/// zh-CN: '音乐'
	String get navMusic => '音乐';

	/// zh-CN: '播放、歌词、桌面歌词、下载、音源、快捷键与同步。'
	String get musicSettingsDescription => '播放、歌词、桌面歌词、下载、音源、快捷键与同步。';

	/// zh-CN: '播放'
	String get navMusicPlay => '播放';

	/// zh-CN: '音源、音质与播放、列表行为。'
	String get musicPlaybackDescription => '音源、音质与播放、列表行为。';

	/// zh-CN: '自定义源'
	String get navMusicSources => '自定义源';

	/// zh-CN: '导入并管理 lx 风格的自定义音源脚本。'
	String get musicSourcesDescription => '导入并管理 lx 风格的自定义音源脚本。';

	/// zh-CN: '下载'
	String get navMusicDownload => '下载';

	/// zh-CN: '下载目录、文件格式、命名与标签处理。'
	String get musicDownloadDescription => '下载目录、文件格式、命名与标签处理。';

	/// zh-CN: '歌词'
	String get navMusicLyric => '歌词';

	/// zh-CN: '歌词的翻译、音译与延迟。'
	String get musicLyricDescription => '歌词的翻译、音译与延迟。';

	/// zh-CN: '桌面歌词'
	String get navMusicDesktopLyric => '桌面歌词';

	/// zh-CN: '快捷键'
	String get navMusicHotkeys => '快捷键';

	/// zh-CN: '同步'
	String get navMusicSync => '同步';

	/// zh-CN: '音效'
	String get navMusicEq => '音效';

	/// zh-CN: '播放、音量与收藏的快捷键。'
	String get musicHotkeysDescription => '播放、音量与收藏的快捷键。';

	/// zh-CN: '与 lx-music 桌面端服务端同步歌单。'
	String get musicSyncDescription => '与 lx-music 桌面端服务端同步歌单。';

	/// zh-CN: '音效总开关、内置预设、十段均衡器与预放增益。'
	String get musicEqDescription => '音效总开关、内置预设、十段均衡器与预放增益。';

	/// zh-CN: '悬浮歌词的开关、锁定、字号、颜色与对齐。'
	String get musicDesktopLyricDescription => '悬浮歌词的开关、锁定、字号、颜色与对齐。';

	/// zh-CN: '默认清晰度'
	String get vodQuality => '默认清晰度';

	/// zh-CN: '打开视频优先请求的清晰度；未登录 B 站可能只有 720P。'
	String get vodQualityDesc => '打开视频优先请求的清晰度；未登录 B 站可能只有 720P。';

	/// zh-CN: '720P'
	String get vodQuality720 => '720P';

	/// zh-CN: '1080P'
	String get vodQuality1080 => '1080P';

	/// zh-CN: '1080P+'
	String get vodQuality1080Plus => '1080P+';

	/// zh-CN: '4K'
	String get vodQuality4K => '4K';

	/// zh-CN: '节目单更新'
	String get iptvGuideUpdates => '节目单更新';

	/// zh-CN: '换台与显示'
	String get navIptvBrowse => '换台与显示';

	/// zh-CN: '频道号、换台方向、时间和当前节目行怎么显示。'
	String get iptvBrowseDescription => '频道号、换台方向、时间和当前节目行怎么显示。';

	/// zh-CN: '分组显示'
	String get navIptvGroups => '分组显示';

	/// zh-CN: '决定哪些分组出现在频道列表和换台里。'
	String get iptvGroupsDescription => '决定哪些分组出现在频道列表和换台里。';

	/// zh-CN: '重新下载网络播放列表与节目单；本地来源不受影响。'
	String get iptvSyncDesc => '重新下载网络播放列表与节目单；本地来源不受影响。';

	/// zh-CN: '弹幕'
	String get navDanmaku => '弹幕';

	/// zh-CN: '小窗弹幕'
	String get navMiniDanmaku => '小窗弹幕';

	/// zh-CN: '播放器内核'
	String get navKernel => '播放器内核';

	/// zh-CN: '录制'
	String get navRecording => '录制';

	/// zh-CN: '画质、音量与画面比例。'
	String get videoDescription => '画质、音量与画面比例。';

	/// zh-CN: '弹幕显示、样式与屏蔽。'
	String get danmakuDescription => '弹幕显示、样式与屏蔽。';

	/// zh-CN: '画中画小窗里的弹幕。'
	String get miniDanmakuDescription => '画中画小窗里的弹幕。';

	/// zh-CN: '内核、代理、硬件解码、预设与画质增强。'
	String get kernelDescription => '内核、代理、硬件解码、预设与画质增强。';

	/// zh-CN: '当前内核'
	String get kernelCurrent => '当前内核';

	/// zh-CN: '当前平台只有 mpv 内核。'
	String get kernelOnlyOne => '当前平台只有 mpv 内核。';

	/// zh-CN: '切换后新打开的播放器使用该内核。'
	String get kernelSwitchHint => '切换后新打开的播放器使用该内核。';

	/// zh-CN: '超分辨率 (Anime4K)'
	String get superResolutionGroup => '超分辨率 (Anime4K)';

	/// zh-CN: '播放预设'
	String get playerPresets => '播放预设';

	/// zh-CN: '一键切换解码、输出与缓冲策略；只影响播放器。'
	String get playerPresetsHint => '一键切换解码、输出与缓冲策略；只影响播放器。';

	/// zh-CN: '一键推荐配置'
	String get playerOneClick => '一键推荐配置';

	/// zh-CN: '恢复「标准」预设，撤销手动调优；正在播放的立即重应用，其余下次打开生效。'
	String get playerOneClickDesc => '恢复「标准」预设，撤销手动调优；正在播放的立即重应用，其余下次打开生效。';

	/// zh-CN: '应用推荐配置？'
	String get playerOneClickConfirmTitle => '应用推荐配置？';

	/// zh-CN: '将把播放内核设为「{preset}」，撤销手动输出与解码器选择；正在播放的直播会短暂重建画面。'
	String playerOneClickConfirmBody({required Object preset}) => '将把播放内核设为「${preset}」，撤销手动输出与解码器选择；正在播放的直播会短暂重建画面。';

	/// zh-CN: '已应用「{preset}」'
	String playerOneClickApplied({required Object preset}) => '已应用「${preset}」';

	/// zh-CN: '花屏 / 绿屏修复'
	String get playerCompatFix => '花屏 / 绿屏修复';

	/// zh-CN: 'mediacodec_embed 直出表面并强制硬解，仅 Android；音画不同步或画面撕裂时先试这个。'
	String get playerCompatFixDesc => 'mediacodec_embed 直出表面并强制硬解，仅 Android；音画不同步或画面撕裂时先试这个。';

	/// zh-CN: '标准（引擎默认）'
	String get presetBalanced => '标准（引擎默认）';

	/// zh-CN: '全部交给引擎决定，仅附加直播所需的缓冲调优；大多数设备最稳，也是其它预设的基线。'
	String get presetBalancedDesc => '全部交给引擎决定，仅附加直播所需的缓冲调优；大多数设备最稳，也是其它预设的基线。';

	/// zh-CN: 'Android 硬解兼容'
	String get presetCompat => 'Android 硬解兼容';

	/// zh-CN: 'Android 专用：mediacodec_embed 直出表面并强制硬解。默认路径花屏、绿屏或音画不同步时使用。'
	String get presetCompatDesc => 'Android 专用：mediacodec_embed 直出表面并强制硬解。默认路径花屏、绿屏或音画不同步时使用。';

	/// zh-CN: 'RTX 视频超分辨率'
	String get presetRtxVsr => 'RTX 视频超分辨率';

	/// zh-CN: 'Windows + NVIDIA 专用：d3d11va 硬解叠加 RTX Video Super Resolution，把低清源放大到高分屏。'
	String get presetRtxVsrDesc => 'Windows + NVIDIA 专用：d3d11va 硬解叠加 RTX Video Super Resolution，把低清源放大到高分屏。';

	/// zh-CN: '低配流畅'
	String get presetLowEnd => '低配流畅';

	/// zh-CN: '软解线程上限 2、lowres 降采样、跳过环路滤波、小缓冲；核显或老机器用。'
	String get presetLowEndDesc => '软解线程上限 2、lowres 降采样、跳过环路滤波、小缓冲；核显或老机器用。';

	/// zh-CN: '弱网稳定'
	String get presetStableNetwork => '弱网稳定';

	/// zh-CN: '加大缓冲与预读、开启强制可拖动与重连退避；用内存换流畅，适合跨网或信号边缘的源。'
	String get presetStableNetworkDesc => '加大缓冲与预读、开启强制可拖动与重连退避；用内存换流畅，适合跨网或信号边缘的源。';

	/// zh-CN: '低延迟'
	String get presetLowLatency => '低延迟';

	/// zh-CN: '最小缓冲 + 解码/渲染双端丢帧，牺牲抗抖动换低延迟。适合赛事直播、连麦互动等时效优先的场景。'
	String get presetLowLatencyDesc => '最小缓冲 + 解码/渲染双端丢帧，牺牲抗抖动换低延迟。适合赛事直播、连麦互动等时效优先的场景。';

	/// zh-CN: '已应用预设'
	String get playerPresetApplied => '已应用预设';

	/// zh-CN: '已由当前预设固定'
	String get playerOutputLockedByPreset => '已由当前预设固定';

	/// zh-CN: '播放器代理'
	String get playerProxy => '播放器代理';

	/// zh-CN: '只影响播放器请求；可以跟随上面的应用代理。'
	String get playerProxyDesc => '只影响播放器请求；可以跟随上面的应用代理。';

	/// zh-CN: '请填写有效的主机和端口（1–65535）。'
	String get playerProxyInvalid => '请填写有效的主机和端口（1–65535）。';

	/// zh-CN: '代理方式'
	String get playerProxyMode => '代理方式';

	/// zh-CN: '跟随应用代理'
	String get playerProxyFollow => '跟随应用代理';

	/// zh-CN: '单独设置'
	String get playerProxyManual => '单独设置';

	/// zh-CN: '硬件解码器 (--hwdec)'
	String get hardwareDecoder => '硬件解码器 (--hwdec)';

	/// zh-CN: '选择 mpv 的 hwdec 解码器（自定义输出开启时生效）。'
	String get hardwareDecoderDesc => '选择 mpv 的 hwdec 解码器（自定义输出开启时生效）。';

	/// zh-CN: '未开启自定义输出时由 mpv 自动选择（auto-safe）；要指定请在「高级设置」开启自定义驱动。'
	String get hardwareDecoderAutoHint => '未开启自定义输出时由 mpv 自动选择（auto-safe）；要指定请在「高级设置」开启自定义驱动。';

	/// zh-CN: 'no（软件解码，兼容性最好）'
	String get hardwareDecoderSoftware => 'no（软件解码，兼容性最好）';

	/// zh-CN: 'auto（任意硬解路径，兼容性有风险）'
	String get hardwareDecoderAuto => 'auto（任意硬解路径，兼容性有风险）';

	/// zh-CN: 'auto-safe（白名单内安全硬解，推荐）'
	String get hardwareDecoderAutoSafe => 'auto-safe（白名单内安全硬解，推荐）';

	/// zh-CN: 'auto-unsafe（不做安全校验）'
	String get hardwareDecoderAutoUnsafe => 'auto-unsafe（不做安全校验）';

	/// zh-CN: 'yes（强制硬解，失败即报错）'
	String get hardwareDecoderYes => 'yes（强制硬解，失败即报错）';

	/// zh-CN: 'auto-copy（安全硬解 + 拷回内存，滤镜/截图可用）'
	String get hardwareDecoderAutoCopy => 'auto-copy（安全硬解 + 拷回内存，滤镜/截图可用）';

	/// zh-CN: 'd3d11va（Direct3D 11 直通，Windows 8+）'
	String get hardwareDecoderD3d11va => 'd3d11va（Direct3D 11 直通，Windows 8+）';

	/// zh-CN: 'd3d11va-copy（D3D11 + 拷回内存）'
	String get hardwareDecoderD3d11vaCopy => 'd3d11va-copy（D3D11 + 拷回内存）';

	/// zh-CN: 'nvdec（NVIDIA 直通，低开销）'
	String get hardwareDecoderNvdec => 'nvdec（NVIDIA 直通，低开销）';

	/// zh-CN: 'nvdec-copy（NVIDIA + 拷回内存）'
	String get hardwareDecoderNvdecCopy => 'nvdec-copy（NVIDIA + 拷回内存）';

	/// zh-CN: 'videotoolbox（Apple 直通，推荐）'
	String get hardwareDecoderVideotoolbox => 'videotoolbox（Apple 直通，推荐）';

	/// zh-CN: 'videotoolbox-copy（Apple + 拷回内存）'
	String get hardwareDecoderVideotoolboxCopy => 'videotoolbox-copy（Apple + 拷回内存）';

	/// zh-CN: 'vaapi（Intel/AMD Linux 直通）'
	String get hardwareDecoderVaapi => 'vaapi（Intel/AMD Linux 直通）';

	/// zh-CN: 'vaapi-copy（vaapi + 拷回内存）'
	String get hardwareDecoderVaapiCopy => 'vaapi-copy（vaapi + 拷回内存）';

	/// zh-CN: 'vdpau（NVIDIA Linux 旧接口）'
	String get hardwareDecoderVdpau => 'vdpau（NVIDIA Linux 旧接口）';

	/// zh-CN: 'vdpau-copy（VDPAU + 拷回内存）'
	String get hardwareDecoderVdpauCopy => 'vdpau-copy（VDPAU + 拷回内存）';

	/// zh-CN: 'mediacodec（Android 直通，推荐）'
	String get hardwareDecoderMediacodec => 'mediacodec（Android 直通，推荐）';

	/// zh-CN: 'mediacodec-copy（Android + 拷回内存）'
	String get hardwareDecoderMediacodecCopy => 'mediacodec-copy（Android + 拷回内存）';

	/// zh-CN: '自定义驱动与硬件加速'
	String get customOutput => '自定义驱动与硬件加速';

	/// zh-CN: '开启后用所选输出与解码器，代替「硬件解码」开关。'
	String get customOutputDesc => '开启后用所选输出与解码器，代替「硬件解码」开关。';

	/// zh-CN: '已由「自定义驱动与硬件加速」接管，解码器在下方选择。'
	String get customOutputHardwareTakeover => '已由「自定义驱动与硬件加速」接管，解码器在下方选择。';

	/// zh-CN: '视频输出'
	String get videoOutput => '视频输出';

	/// zh-CN: 'gpu / gpu-next / direct3d 可能另开 mpv 窗口；嵌入画面保持 libmpv 或 auto。'
	String get videoOutputHint => 'gpu / gpu-next / direct3d 可能另开 mpv 窗口；嵌入画面保持 libmpv 或 auto。';

	/// zh-CN: 'auto（跟随 mpv 默认，推荐）'
	String get videoOutputAuto => 'auto（跟随 mpv 默认，推荐）';

	/// zh-CN: 'libmpv（内嵌 Flutter 纹理）'
	String get videoOutputLibmpv => 'libmpv（内嵌 Flutter 纹理）';

	/// zh-CN: 'gpu（独立 mpv 窗口，完整着色器）'
	String get videoOutputGpu => 'gpu（独立 mpv 窗口，完整着色器）';

	/// zh-CN: 'gpu-next（独立窗口，libplacebo 新管线，支持 HDR）'
	String get videoOutputGpuNext => 'gpu-next（独立窗口，libplacebo 新管线，支持 HDR）';

	/// zh-CN: 'direct3d（独立窗口，旧 D3D9 兼容）'
	String get videoOutputDirect3d => 'direct3d（独立窗口，旧 D3D9 兼容）';

	/// zh-CN: 'null（不渲染画面，只有声音）'
	String get videoOutputNull => 'null（不渲染画面，只有声音）';

	/// zh-CN: 'MediaCodec Embed（仅 Android，直通 Surface）'
	String get videoOutputMediacodecEmbed => 'MediaCodec Embed（仅 Android，直通 Surface）';

	/// zh-CN: '音频输出驱动（--ao）'
	String get audioOutput => '音频输出驱动（--ao）';

	/// zh-CN: '自动（引擎按平台挑选，推荐）'
	String get audioOutputAuto => '自动（引擎按平台挑选，推荐）';

	/// zh-CN: 'AudioTrack（Android 系统混音器，推荐）'
	String get audioOutputAudiotrack => 'AudioTrack（Android 系统混音器，推荐）';

	/// zh-CN: 'AAudio（Android 8.0+，低延迟）'
	String get audioOutputAaudio => 'AAudio（Android 8.0+，低延迟）';

	/// zh-CN: 'OpenSL ES（Android 旧通道，兼容用）'
	String get audioOutputOpensles => 'OpenSL ES（Android 旧通道，兼容用）';

	/// zh-CN: 'AudioUnit（iOS / macOS）'
	String get audioOutputAudiounit => 'AudioUnit（iOS / macOS）';

	/// zh-CN: 'WASAPI（Windows 默认通道，推荐）'
	String get audioOutputWasapi => 'WASAPI（Windows 默认通道，推荐）';

	/// zh-CN: 'win32（waveOut 旧通道）'
	String get audioOutputWin32 => 'win32（waveOut 旧通道）';

	/// zh-CN: 'SDL（跨平台兜底）'
	String get audioOutputSdl => 'SDL（跨平台兜底）';

	/// zh-CN: 'PCM（原始数据转储到文件，调试用）'
	String get audioOutputPcm => 'PCM（原始数据转储到文件，调试用）';

	/// zh-CN: 'ALSA（Linux 直通，可能独占声卡）'
	String get audioOutputAlsa => 'ALSA（Linux 直通，可能独占声卡）';

	/// zh-CN: 'PipeWire（Linux 新声音栈）'
	String get audioOutputPipewire => 'PipeWire（Linux 新声音栈）';

	/// zh-CN: 'null（不输出声音，静音调试）'
	String get audioOutputNull => 'null（不输出声音，静音调试）';

	/// zh-CN: '视频同步模式 (--video-sync)'
	String get videoSync => '视频同步模式 (--video-sync)';

	/// zh-CN: '画面跟随音频时钟还是显示刷新；显示重采样最平滑，但更吃 GPU。'
	String get videoSyncDesc => '画面跟随音频时钟还是显示刷新；显示重采样最平滑，但更吃 GPU。';

	/// zh-CN: '音频时钟（mpv 默认）'
	String get videoSyncAudio => '音频时钟（mpv 默认）';

	/// zh-CN: '显示重采样（最平滑，吃 GPU）'
	String get videoSyncDisplayResample => '显示重采样（最平滑，吃 GPU）';

	/// zh-CN: '显示重采样 + 视频丢帧'
	String get videoSyncDisplayResampleVdrop => '显示重采样 + 视频丢帧';

	/// zh-CN: '显示重采样 + 整帧丢弃'
	String get videoSyncDisplayResampleDrop => '显示重采样 + 整帧丢弃';

	/// zh-CN: '显示时钟 + 音频丢样'
	String get videoSyncDisplayAdrop => '显示时钟 + 音频丢样';

	/// zh-CN: '显示时钟 + 视频丢帧'
	String get videoSyncDisplayVdrop => '显示时钟 + 视频丢帧';

	/// zh-CN: '显示时钟 + 不同步'
	String get videoSyncDisplayDesync => '显示时钟 + 不同步';

	/// zh-CN: '完全不同步（调试）'
	String get videoSyncDesync => '完全不同步（调试）';

	/// zh-CN: '运动插帧 (--interpolation)'
	String get interpolation => '运动插帧 (--interpolation)';

	/// zh-CN: '需配合「显示重采样」；平移画面更顺滑，消耗 GPU。'
	String get interpolationDesc => '需配合「显示重采样」；平移画面更顺滑，消耗 GPU。';

	/// zh-CN: '缩放算法'
	String get scaleKernel => '缩放算法';

	/// zh-CN: '放大画面时的重采样算法。'
	String get scaleKernelDesc => '放大画面时的重采样算法。';

	/// zh-CN: 'Lanczos（均衡推荐）'
	String get scaleLanczos => 'Lanczos（均衡推荐）';

	/// zh-CN: 'EWA Lanczos Sharp（锐利，吃 GPU）'
	String get scaleEwaLanczosSharp => 'EWA Lanczos Sharp（锐利，吃 GPU）';

	/// zh-CN: 'EWA Lanczos 4 Sharpest（配合插帧）'
	String get scaleEwaLanczos4Sharpest => 'EWA Lanczos 4 Sharpest（配合插帧）';

	/// zh-CN: 'EWA Lanczos'
	String get scaleEwaLanczos => 'EWA Lanczos';

	/// zh-CN: 'Spline36'
	String get scaleSpline36 => 'Spline36';

	/// zh-CN: 'Spline16（快）'
	String get scaleSpline16 => 'Spline16（快）';

	/// zh-CN: 'Catmull-Rom'
	String get scaleCatmullRom => 'Catmull-Rom';

	/// zh-CN: 'Mitchell'
	String get scaleMitchell => 'Mitchell';

	/// zh-CN: 'Hermite（柔和）'
	String get scaleHermite => 'Hermite（柔和）';

	/// zh-CN: 'Bicubic Fast（快）'
	String get scaleBicubicFast => 'Bicubic Fast（快）';

	/// zh-CN: '双线性（最快，最糊）'
	String get scaleBilinear => '双线性（最快，最糊）';

	/// zh-CN: '最近邻（块状）'
	String get scaleNearest => '最近邻（块状）';

	/// zh-CN: '反交错 (--deinterlace)'
	String get deinterlace => '反交错 (--deinterlace)';

	/// zh-CN: '直播源基本都是逐行的，保持自动；老电视信号或采集卡才需要。'
	String get deinterlaceDesc => '直播源基本都是逐行的，保持自动；老电视信号或采集卡才需要。';

	/// zh-CN: '自动'
	String get deinterlaceAuto => '自动';

	/// zh-CN: '关闭'
	String get deinterlaceOff => '关闭';

	/// zh-CN: '开启（隔行源才需要）'
	String get deinterlaceOn => '开启（隔行源才需要）';

	/// zh-CN: '硬解编码范围 (--hwdec-codecs)'
	String get hwdecCodecs => '硬解编码范围 (--hwdec-codecs)';

	/// zh-CN: '某编码黑屏或花屏时把它移出列表，即可回退软解。'
	String get hwdecCodecsDesc => '某编码黑屏或花屏时把它移出列表，即可回退软解。';

	/// zh-CN: '全部编码格式'
	String get hwdecCodecsAll => '全部编码格式';

	/// zh-CN: 'H264 + HEVC'
	String get hwdecCodecsH264Hevc => 'H264 + HEVC';

	/// zh-CN: 'H264 + HEVC + VP9'
	String get hwdecCodecsH264HevcVp9 => 'H264 + HEVC + VP9';

	/// zh-CN: 'H264 + HEVC + VP9 + AV1'
	String get hwdecCodecsH264HevcVp9Av1 => 'H264 + HEVC + VP9 + AV1';

	/// zh-CN: '音频独占 (--audio-exclusive)'
	String get audioExclusive => '音频独占 (--audio-exclusive)';

	/// zh-CN: '独占 WASAPI 设备，其他应用将无法出声。'
	String get audioExclusiveDesc => '独占 WASAPI 设备，其他应用将无法出声。';

	/// zh-CN: '播放器强制销毁'
	String get forceDestroy => '播放器强制销毁';

	/// zh-CN: '退出房间后立即销毁播放器；关闭时保留已停止的播放器，供下个房间复用。'
	String get forceDestroyDesc => '退出房间后立即销毁播放器；关闭时保留已停止的播放器，供下个房间复用。';

	/// zh-CN: 'mpv 高级设置'
	String get mpvAdvanced => 'mpv 高级设置';

	/// zh-CN: '恢复播放内核默认设置'
	String get mpvReset => '恢复播放内核默认设置';

	/// zh-CN: '恢复本页的设置；视频设置里的首选清晰度不受影响。'
	String get mpvResetDesc => '恢复本页的设置；视频设置里的首选清晰度不受影响。';

	/// zh-CN: '下面这些恢复默认值： • 开启硬解码：开 • 兼容模式、RTX VSR、播放器强制销毁：关 • 自定义驱动与硬件加速：关；三个驱动：默认 视频设置里的首选清晰度不变。'
	String get mpvResetConfirm => '下面这些恢复默认值：\n• 开启硬解码：开\n• 兼容模式、RTX VSR、播放器强制销毁：关\n• 自定义驱动与硬件加速：关；三个驱动：默认\n视频设置里的首选清晰度不变。';

	/// zh-CN: '已恢复默认设置'
	String get mpvResetDone => '已恢复默认设置';

	/// zh-CN: '打开 mpv 官方文档'
	String get mpvDocs => '打开 mpv 官方文档';

	/// zh-CN: '每个属性的完整说明。'
	String get mpvDocsDesc => '每个属性的完整说明。';

	/// zh-CN: '播放器指南'
	String get playerGuide => '播放器指南';

	/// zh-CN: '预设、调参与常见问题的说明。'
	String get playerGuideDesc => '预设、调参与常见问题的说明。';

	/// zh-CN: '播放搭配指南'
	String get playerGuideTitle => '播放搭配指南';

	/// zh-CN: '名词解释 · 各平台推荐搭配 · 症状对照'
	String get playerGuideSubtitle => '名词解释 · 各平台推荐搭配 · 症状对照';

	/// zh-CN: '指南中的内核选项仅对 mpv 内核生效；先用一键预设覆盖大多数场景，仍不正常时再改高级选项。'
	String get playerGuideIntro => '指南中的内核选项仅对 mpv 内核生效；先用一键预设覆盖大多数场景，仍不正常时再改高级选项。';

	/// zh-CN: '播放手册：mpv 官方文档'
	String get playerGuideManualTitle => '播放手册：mpv 官方文档';

	/// zh-CN: '遇到问题先看「症状对照」；想理解某个设置是什么，在「基础概念」和各章里查。'
	String get playerGuideManualHint => '遇到问题先看「症状对照」；想理解某个设置是什么，在「基础概念」和各章里查。';

	/// zh-CN: '基础概念'
	String get playerGuideChapterConcepts => '基础概念';

	/// zh-CN: '一键播放方案'
	String get playerGuideChapterPresets => '一键播放方案';

	/// zh-CN: '画面与同步'
	String get playerGuideChapterPictureSync => '画面与同步';

	/// zh-CN: '画质增强'
	String get playerGuideChapterQuality => '画质增强';

	/// zh-CN: '声音'
	String get playerGuideChapterAudio => '声音';

	/// zh-CN: '症状对照'
	String get playerGuideChapterSymptoms => '症状对照';

	/// zh-CN: 'hwdec'
	String get playerGuideBadgeHwdec => 'hwdec';

	/// zh-CN: 'vo'
	String get playerGuideBadgeVo => 'vo';

	/// zh-CN: 'ao'
	String get playerGuideBadgeAo => 'ao';

	/// zh-CN: 'Android'
	String get playerGuidePlatformAndroid => 'Android';

	/// zh-CN: 'Windows'
	String get playerGuidePlatformWindows => 'Windows';

	/// zh-CN: '硬解码开关'
	String get playerGuideEntryHardwareSwitchTitle => '硬解码开关';

	/// zh-CN: '让显卡代替 CPU 解码视频。开启后 CPU 占用低、发热小；关闭则走软解，兼容性最好，老机器反而可能更流畅。'
	String get playerGuideEntryHardwareSwitchBody => '让显卡代替 CPU 解码视频。开启后 CPU 占用低、发热小；关闭则走软解，兼容性最好，老机器反而可能更流畅。';

	/// zh-CN: '--hwdec'
	String get playerGuideEntryHwdecTitle => '--hwdec';

	/// zh-CN: '具体用哪种硬解路径。auto 全部尝试（个别机型可能花屏）；auto-safe 只用白名单内的安全路径（推荐）；带 -copy 的变体把解码结果拷回内存，滤镜和截图需要它。'
	String get playerGuideEntryHwdecBody => '具体用哪种硬解路径。auto 全部尝试（个别机型可能花屏）；auto-safe 只用白名单内的安全路径（推荐）；带 -copy 的变体把解码结果拷回内存，滤镜和截图需要它。';

	/// zh-CN: '--vo'
	String get playerGuideEntryVoTitle => '--vo';

	/// zh-CN: 'mpv 把画面画到哪里。libmpv 画进 Flutter 纹理（内嵌播放器，默认）；gpu/gpu-next/direct3d 会打开独立的 mpv 原生窗口（不在应用画面内）；null 不渲染画面。'
	String get playerGuideEntryVoBody => 'mpv 把画面画到哪里。libmpv 画进 Flutter 纹理（内嵌播放器，默认）；gpu/gpu-next/direct3d 会打开独立的 mpv 原生窗口（不在应用画面内）；null 不渲染画面。';

	/// zh-CN: '--ao'
	String get playerGuideEntryAoTitle => '--ao';

	/// zh-CN: 'mpv 把声音送到哪个系统通道。Windows 用 wasapi，Android 用 audiotrack/aaudio/opensles；null 表示静音。'
	String get playerGuideEntryAoBody => 'mpv 把声音送到哪个系统通道。Windows 用 wasapi，Android 用 audiotrack/aaudio/opensles；null 表示静音。';

	/// zh-CN: '均衡（推荐起点）'
	String get playerGuideEntryPresetDefaultTitle => '均衡（推荐起点）';

	/// zh-CN: '清除自定义输出与解码器选择，交给 mpv 自动决定。大多数设备和网络的首选。'
	String get playerGuideEntryPresetDefaultBody => '清除自定义输出与解码器选择，交给 mpv 自动决定。大多数设备和网络的首选。';

	/// zh-CN: 'Android 硬解兼容'
	String get playerGuideEntryPresetAndroidCompatTitle => 'Android 硬解兼容';

	/// zh-CN: '改用 mediacodec_embed 直通表面并强制 mediacodec 硬解，花屏、绿屏或音画不同步时使用。仅 Android 显示。'
	String get playerGuideEntryPresetAndroidCompatBody => '改用 mediacodec_embed 直通表面并强制 mediacodec 硬解，花屏、绿屏或音画不同步时使用。仅 Android 显示。';

	/// zh-CN: 'NVIDIA RTX 视频超分'
	String get playerGuideEntryPresetRtxSrTitle => 'NVIDIA RTX 视频超分';

	/// zh-CN: '使用 d3d11va 硬解并叠加 RTX Video Super Resolution 滤镜，把低清源放大观看；会锁定解码器为 d3d11va。仅 Windows 显示。'
	String get playerGuideEntryPresetRtxSrBody => '使用 d3d11va 硬解并叠加 RTX Video Super Resolution 滤镜，把低清源放大观看；会锁定解码器为 d3d11va。仅 Windows 显示。';

	/// zh-CN: '低配流畅'
	String get playerGuideEntryPresetLowEndTitle => '低配流畅';

	/// zh-CN: '软解 + 线程上限 2 + lowres 降采样 + 小缓冲。把 CPU 让给画面本身，核显或老机器使用。'
	String get playerGuideEntryPresetLowEndBody => '软解 + 线程上限 2 + lowres 降采样 + 小缓冲。把 CPU 让给画面本身，核显或老机器使用。';

	/// zh-CN: '弱网稳定'
	String get playerGuideEntryPresetWeakNetworkTitle => '弱网稳定';

	/// zh-CN: '加大缓冲与预读、开启重连退避。用内存换卡顿，跨网或信号边缘时使用。'
	String get playerGuideEntryPresetWeakNetworkBody => '加大缓冲与预读、开启重连退避。用内存换卡顿，跨网或信号边缘时使用。';

	/// zh-CN: '低延迟'
	String get playerGuideEntryPresetLowLatencyTitle => '低延迟';

	/// zh-CN: '最小缓冲 + 双端丢帧。时效优先，代价是更容易卡。'
	String get playerGuideEntryPresetLowLatencyBody => '最小缓冲 + 双端丢帧。时效优先，代价是更容易卡。';

	/// zh-CN: '--video-sync'
	String get playerGuideEntryVideoSyncTitle => '--video-sync';

	/// zh-CN: '音画时钟对齐方式。audio 是 mpv 默认；display-resample 最平滑但吃 GPU，配合运动插帧使用；带 vdrop/drop 的变体在节奏对不上时丢帧。仅桌面显示。'
	String get playerGuideEntryVideoSyncBody => '音画时钟对齐方式。audio 是 mpv 默认；display-resample 最平滑但吃 GPU，配合运动插帧使用；带 vdrop/drop 的变体在节奏对不上时丢帧。仅桌面显示。';

	/// zh-CN: '--interpolation'
	String get playerGuideEntryInterpolationTitle => '--interpolation';

	/// zh-CN: '运动插帧。平移画面时按帧间计算补帧，显著更顺滑；必须配合 display-resample 同步模式，GPU 消耗明显。仅桌面显示。'
	String get playerGuideEntryInterpolationBody => '运动插帧。平移画面时按帧间计算补帧，显著更顺滑；必须配合 display-resample 同步模式，GPU 消耗明显。仅桌面显示。';

	/// zh-CN: '--scale'
	String get playerGuideEntryScaleTitle => '--scale';

	/// zh-CN: '画面放大算法。lanczos 均衡推荐；ewa_lanczossharp 最锐利；ewa_lanczos4sharpest 专为插帧设计；bilinear/nearest 最快但糊或块状。移动端只提供 lanczos 与 bilinear。'
	String get playerGuideEntryScaleBody => '画面放大算法。lanczos 均衡推荐；ewa_lanczossharp 最锐利；ewa_lanczos4sharpest 专为插帧设计；bilinear/nearest 最快但糊或块状。移动端只提供 lanczos 与 bilinear。';

	/// zh-CN: '--deinterlace'
	String get playerGuideEntryDeinterlaceTitle => '--deinterlace';

	/// zh-CN: '反交错处理。直播源基本都是逐行的，保持自动即可；只有老电视信号或采集卡源才需要开启。'
	String get playerGuideEntryDeinterlaceBody => '反交错处理。直播源基本都是逐行的，保持自动即可；只有老电视信号或采集卡源才需要开启。';

	/// zh-CN: '超分辨率（Anime4K）'
	String get playerGuideEntryRtxSuperResolutionTitle => '超分辨率（Anime4K）';

	/// zh-CN: '设置 → 播放内核 → 超分辨率：效率档或质量档。仅 Windows 桌面 GPU 可实时运行，把低清源放大到高分屏仍然清晰。'
	String get playerGuideEntryRtxSuperResolutionBody => '设置 → 播放内核 → 超分辨率：效率档或质量档。仅 Windows 桌面 GPU 可实时运行，把低清源放大到高分屏仍然清晰。';

	/// zh-CN: '弹幕较多时减轻负担'
	String get playerGuideEntryDanmakuLoadTitle => '弹幕较多时减轻负担';

	/// zh-CN: '在设置 → 弹幕样式里调低字号、速度或不透明度，或关闭画面飞行弹幕，可显著减轻低配设备的负担。'
	String get playerGuideEntryDanmakuLoadBody => '在设置 → 弹幕样式里调低字号、速度或不透明度，或关闭画面飞行弹幕，可显著减轻低配设备的负担。';

	/// zh-CN: '--hwdec-codecs'
	String get playerGuideEntryHwdecCodecsTitle => '--hwdec-codecs';

	/// zh-CN: '限制哪些编码格式走硬解。默认全部编码格式；某编码黑屏或花屏时，把范围收窄到不含它的档位（回退软解）。'
	String get playerGuideEntryHwdecCodecsBody => '限制哪些编码格式走硬解。默认全部编码格式；某编码黑屏或花屏时，把范围收窄到不含它的档位（回退软解）。';

	/// zh-CN: '--audio-exclusive'
	String get playerGuideEntryAudioExclusiveTitle => '--audio-exclusive';

	/// zh-CN: '仅 Windows。独占 WASAPI 设备，绕过系统混音器，可能有更好的音质；代价是其他应用无法出声。'
	String get playerGuideEntryAudioExclusiveBody => '仅 Windows。独占 WASAPI 设备，绕过系统混音器，可能有更好的音质；代价是其他应用无法出声。';

	/// zh-CN: '--ao 选择建议'
	String get playerGuideEntryAoAdviceTitle => '--ao 选择建议';

	/// zh-CN: '不确定就用 auto。声音断续时 Windows 换 win32，Android 换 opensles；蓝牙耳机延迟大时可尝试不同通道对比。'
	String get playerGuideEntryAoAdviceBody => '不确定就用 auto。声音断续时 Windows 换 win32，Android 换 opensles；蓝牙耳机延迟大时可尝试不同通道对比。';

	/// zh-CN: '花屏 / 绿屏 / 音画不同步'
	String get playerGuideEntrySymGlitchTitle => '花屏 / 绿屏 / 音画不同步';

	/// zh-CN: 'Android：一键方案切「安卓兼容」。其它平台：关闭硬解开关走软解，或在自定义驱动与硬件加速里把解码器改 auto-safe。'
	String get playerGuideEntrySymGlitchBody => 'Android：一键方案切「安卓兼容」。其它平台：关闭硬解开关走软解，或在自定义驱动与硬件加速里把解码器改 auto-safe。';

	/// zh-CN: '低清源在高分屏发糊'
	String get playerGuideEntrySymBlurryTitle => '低清源在高分屏发糊';

	/// zh-CN: 'Windows + NVIDIA：选「RTX VSR」预设；其它 GPU：放大算法改 ewa_lanczossharp，或在播放内核里开启 Anime4K 超分辨率（仅 Windows）。'
	String get playerGuideEntrySymBlurryBody => 'Windows + NVIDIA：选「RTX VSR」预设；其它 GPU：放大算法改 ewa_lanczossharp，或在播放内核里开启 Anime4K 超分辨率（仅 Windows）。';

	/// zh-CN: '风扇狂转 / 掉帧'
	String get playerGuideEntrySymFanTitle => '风扇狂转 / 掉帧';

	/// zh-CN: '选「低配流畅」方案；仍不行就关闭硬解码开关（老设备软解反而快）。'
	String get playerGuideEntrySymFanBody => '选「低配流畅」方案；仍不行就关闭硬解码开关（老设备软解反而快）。';

	/// zh-CN: '频繁缓冲'
	String get playerGuideEntrySymBufferingTitle => '频繁缓冲';

	/// zh-CN: '选「弱网稳定」；同时检查播放器代理设置——代理是直播卡顿的常见来源。'
	String get playerGuideEntrySymBufferingBody => '选「弱网稳定」；同时检查播放器代理设置——代理是直播卡顿的常见来源。';

	/// zh-CN: '延迟高（连麦 / 赛事情景）'
	String get playerGuideEntrySymLatencyTitle => '延迟高（连麦 / 赛事情景）';

	/// zh-CN: '选「低延迟」方案，并调低缓冲相关属性。'
	String get playerGuideEntrySymLatencyBody => '选「低延迟」方案，并调低缓冲相关属性。';

	/// zh-CN: '有声音没画面'
	String get playerGuideEntrySymNoVideoTitle => '有声音没画面';

	/// zh-CN: '检查视频输出驱动是否被改过（null = 不渲染画面）；恢复「自动」即可。恢复播放内核默认设置也能解决。'
	String get playerGuideEntrySymNoVideoBody => '检查视频输出驱动是否被改过（null = 不渲染画面）；恢复「自动」即可。恢复播放内核默认设置也能解决。';

	/// zh-CN: '自动'
	String get optionAuto => '自动';

	/// zh-CN: '关闭'
	String get optionOff => '关闭';

	/// zh-CN: '开启'
	String get optionOn => '开启';

	/// zh-CN: '无输出'
	String get optionNoOutput => '无输出';

	/// zh-CN: '默认渲染，不挂载任何超分滤镜。'
	String get superResolutionOffDesc => '默认渲染，不挂载任何超分滤镜。';

	/// zh-CN: '轻量 Anime4K 卷积链，GPU 负担小，适合核显或高刷屏。'
	String get superResolutionEfficiencyDesc => '轻量 Anime4K 卷积链，GPU 负担小，适合核显或高刷屏。';

	/// zh-CN: '完整 Anime4K 卷积链，效果最好，需要独立显卡。'
	String get superResolutionQualityDesc => '完整 Anime4K 卷积链，效果最好，需要独立显卡。';

	/// zh-CN: '这些选项只对 mpv 内核生效。'
	String get playerAdvancedRequiresMpv => '这些选项只对 mpv 内核生效。';

	/// zh-CN: '超分辨率'
	String get superResolution => '超分辨率';

	/// zh-CN: '用 Anime4K 着色器实时放大画面；需要桌面 GPU。'
	String get superResolutionDescription => '用 Anime4K 着色器实时放大画面；需要桌面 GPU。';

	/// zh-CN: '基于 Anime4K 的实时超分，仅 Windows 桌面 GPU 可实时运行。'
	String get superResolutionHint => '基于 Anime4K 的实时超分，仅 Windows 桌面 GPU 可实时运行。';

	/// zh-CN: '关闭'
	String get superResolutionOff => '关闭';

	/// zh-CN: '效率档'
	String get superResolutionEfficiency => '效率档';

	/// zh-CN: '质量档'
	String get superResolutionQuality => '质量档';

	/// zh-CN: '录制目录、文件命名与容量上限。'
	String get recordingDescription => '录制目录、文件命名与容量上限。';

	/// zh-CN: '首选画质'
	String get preferredQuality => '首选画质';

	/// zh-CN: '进入房间优先选用的清晰度；没有同名画质时按档位就近选择。'
	String get preferredQualityDesc => '进入房间优先选用的清晰度；没有同名画质时按档位就近选择。';

	/// zh-CN: '蜂窝网络首选画质'
	String get preferredQualityCellular => '蜂窝网络首选画质';

	/// zh-CN: '使用移动数据时优先选用的清晰度档位；Wi-Fi 与有线仍使用上面的首选画质。'
	String get preferredQualityCellularDesc => '使用移动数据时优先选用的清晰度档位；Wi-Fi 与有线仍使用上面的首选画质。';

	/// zh-CN: '自动（站点默认）'
	String get qualityAuto => '自动（站点默认）';

	/// zh-CN: '原画'
	String get qualityOriginal => '原画';

	/// zh-CN: '蓝光 8M'
	String get qualityBluRay8M => '蓝光 8M';

	/// zh-CN: '蓝光 4M'
	String get qualityBluRay4M => '蓝光 4M';

	/// zh-CN: '蓝光'
	String get qualityBluRay => '蓝光';

	/// zh-CN: '超清'
	String get qualityUltra => '超清';

	/// zh-CN: '高清'
	String get qualityHigh => '高清';

	/// zh-CN: '标清'
	String get qualityStandard => '标清';

	/// zh-CN: '流畅'
	String get qualitySmooth => '流畅';

	/// zh-CN: '默认静音'
	String get defaultMuted => '默认静音';

	/// zh-CN: '每个新房间打开时保持静音。'
	String get defaultMutedDesc => '每个新房间打开时保持静音。';

	/// zh-CN: '默认音量'
	String get defaultVolume => '默认音量';

	/// zh-CN: '移动端新播放器默认 50%，桌面 100%；滑杆只调当前平台。'
	String get defaultVolumeDesc => '移动端新播放器默认 50%，桌面 100%；滑杆只调当前平台。';

	/// zh-CN: '滚轮音量步长'
	String get volumeWheelStep => '滚轮音量步长';

	/// zh-CN: '鼠标滚轮与方向键每次调节的音量幅度。'
	String get volumeWheelStepDesc => '鼠标滚轮与方向键每次调节的音量幅度。';

	/// zh-CN: '{percent: int}%'
	String volumeWheelStepValue({required int percent}) => '${percent}%';

	/// zh-CN: '全局静音'
	String get globalMute => '全局静音';

	/// zh-CN: '静音所有正在播放与之后打开的房间、频道和视频；关闭后各自恢复。'
	String get globalMuteDesc => '静音所有正在播放与之后打开的房间、频道和视频；关闭后各自恢复。';

	/// zh-CN: '后台播放'
	String get backgroundPlay => '后台播放';

	/// zh-CN: '离开应用后继续出声；关闭则切后台即暂停。'
	String get backgroundPlayDesc => '离开应用后继续出声；关闭则切后台即暂停。';

	/// zh-CN: 'ASMR 睡眠模式'
	String get asmrSleepMode => 'ASMR 睡眠模式';

	/// zh-CN: '进直播间自动切音频模式，到时暂停。仅 Android。'
	String get asmrSleepModeDesc => '进直播间自动切音频模式，到时暂停。仅 Android。';

	/// zh-CN: 'ASMR 睡眠时长'
	String get asmrSleepTimer => 'ASMR 睡眠时长';

	/// zh-CN: '音频模式自动停止前的分钟数，范围 15–1440。'
	String get asmrSleepTimerDesc => '音频模式自动停止前的分钟数，范围 15–1440。';

	/// zh-CN: '自定义分钟数'
	String get asmrSleepCustomMinutes => '自定义分钟数';

	/// zh-CN: '15–1440 分钟'
	String get asmrSleepRange => '15–1440 分钟';

	/// zh-CN: '画面比例'
	String get fit => '画面比例';

	/// zh-CN: '画面在播放区域里的铺法。'
	String get fitDesc => '画面在播放区域里的铺法。';

	/// zh-CN: '默认比例'
	String get fitContain => '默认比例';

	/// zh-CN: '居中裁剪'
	String get fitCover => '居中裁剪';

	/// zh-CN: '填充屏幕'
	String get fitFill => '填充屏幕';

	/// zh-CN: '画中画中显示弹幕'
	String get miniDanmakuVisible => '画中画中显示弹幕';

	/// zh-CN: '缩成小窗时是否继续显示飞行弹幕。'
	String get miniDanmakuVisibleDesc => '缩成小窗时是否继续显示飞行弹幕。';

	/// zh-CN: '弹幕样式与「弹幕」页共用。'
	String get miniDanmakuHint => '弹幕样式与「弹幕」页共用。';

	/// zh-CN: '播放内核'
	String get engineTitle => '播放内核';

	/// zh-CN: '直播与视频的播放内核；mpv 为默认，移动端另可选 IJK 或 BetterPlayer。'
	String get engineDesc => '直播与视频的播放内核；mpv 为默认，移动端另可选 IJK 或 BetterPlayer。';

	/// zh-CN: 'mpv 播放器'
	String get playerEngineMpv => 'mpv 播放器';

	/// zh-CN: 'IJK 播放器'
	String get playerEngineIjk => 'IJK 播放器';

	/// zh-CN: 'BetterPlayer'
	String get playerEngineBetterPlayer => 'BetterPlayer';

	/// zh-CN: '硬件解码'
	String get hardwareDecoding => '硬件解码';

	/// zh-CN: '用 GPU 解码视频，关闭则交给 CPU。'
	String get hardwareDecodingDesc => '用 GPU 解码视频，关闭则交给 CPU。';

	/// zh-CN: '对当前与之后打开的播放器生效。'
	String get hardwareDecodingHint => '对当前与之后打开的播放器生效。';

	/// zh-CN: '返回应用时刷新关注'
	String get refreshOnResume => '返回应用时刷新关注';

	/// zh-CN: '切回应用时刷新一遍关注列表的状态。'
	String get refreshOnResumeDesc => '切回应用时刷新一遍关注列表的状态。';

	/// zh-CN: '最大并发刷新'
	String get maxConcurrentRefresh => '最大并发刷新';

	/// zh-CN: '同时向平台查询的房间数，参考推荐 4，范围 1–20。'
	String get maxConcurrentRefreshDesc => '同时向平台查询的房间数，参考推荐 4，范围 1–20。';

	/// zh-CN: '推荐'
	String get recommended => '推荐';

	/// zh-CN: '自动刷新封面'
	String get refreshThumbnails => '自动刷新封面';

	/// zh-CN: '定期清空图片缓存，封面、头像和台标重新下载；不影响历史与关注。'
	String get refreshThumbnailsDesc => '定期清空图片缓存，封面、头像和台标重新下载；不影响历史与关注。';

	/// zh-CN: '封面刷新间隔'
	String get thumbnailRefreshInterval => '封面刷新间隔';

	/// zh-CN: '首页菜单'
	String get navHomeMenuTitle => '首页菜单';

	/// zh-CN: '侧栏、抽屉与底栏显示的首页入口，以及它们的顺序。'
	String get navHomeMenuDescription => '侧栏、抽屉与底栏显示的首页入口，以及它们的顺序。';

	/// zh-CN: '编辑顺序'
	String get editOrder => '编辑顺序';

	/// zh-CN: '保存顺序'
	String get saveOrder => '保存顺序';

	/// zh-CN: '未保存的排序草稿'
	String get unsavedOrderDraft => '未保存的排序草稿';

	/// zh-CN: '置顶'
	String get moveToTop => '置顶';

	/// zh-CN: '置底'
	String get moveToBottom => '置底';

	/// zh-CN: '至少保留一个菜单'
	String get navMenuKeepOne => '至少保留一个菜单';

	/// zh-CN: '主题'
	String get groupTheme => '主题';

	/// zh-CN: '卡片与列表'
	String get groupCards => '卡片与列表';

	/// zh-CN: '语言'
	String get groupLanguage => '语言';

	/// zh-CN: '对比度'
	String get contrast => '对比度';

	/// zh-CN: '控件边界与文字的对比强度。'
	String get contrastDescription => '控件边界与文字的对比强度。';

	/// zh-CN: '柔和'
	String get contrastSoft => '柔和';

	/// zh-CN: '标准'
	String get contrastStandard => '标准';

	/// zh-CN: '选中样式'
	String get selectionStyle => '选中样式';

	/// zh-CN: '选中行与控件的高亮方式。'
	String get selectionDescription => '选中行与控件的高亮方式。';

	/// zh-CN: '柔和'
	String get selectionSoft => '柔和';

	/// zh-CN: '强烈'
	String get selectionStrong => '强烈';

	/// zh-CN: '自动避让状态色'
	String get autoClash => '自动避让状态色';

	/// zh-CN: '主题色接近危险或成功色时自动调整，避免选中状态被误读。'
	String get autoClashDesc => '主题色接近危险或成功色时自动调整，避免选中状态被误读。';

	/// zh-CN: '背景'
	String get navBackground => '背景';

	/// zh-CN: '用图片或视频铺在应用后面，可上传本地文件或填写地址。'
	String get backgroundDescription => '用图片或视频铺在应用后面，可上传本地文件或填写地址。';

	/// zh-CN: '在线图片'
	String get backgroundImagesTitle => '在线图片';

	/// zh-CN: '官方、Wallhaven、Bing 与 deepin 图源，先预览再应用。'
	String get backgroundImagesDescription => '官方、Wallhaven、Bing 与 deepin 图源，先预览再应用。';

	/// zh-CN: '在线视频'
	String get backgroundVideosTitle => '在线视频';

	/// zh-CN: '随机图源'
	String get navRandomWallpaper => '随机图源';

	/// zh-CN: '按分组从公开随机接口取图，预览后再应用。'
	String get randomWallpaperDescription => '按分组从公开随机接口取图，预览后再应用。';

	/// zh-CN: 'iTab 动态壁纸，选中后预览再应用。'
	String get backgroundVideosDescription => 'iTab 动态壁纸，选中后预览再应用。';

	/// zh-CN: '纯色与渐变'
	String get backgroundColorsTitle => '纯色与渐变';

	/// zh-CN: '调色板与渐变预设。'
	String get backgroundColorsDescription => '调色板与渐变预设。';

	/// zh-CN: '从设备'
	String get backgroundDeviceTitle => '从设备';

	/// zh-CN: '上传图片或视频，或填写网络地址。'
	String get backgroundDeviceDescription => '上传图片或视频，或填写网络地址。';

	/// zh-CN: '当前背景'
	String get backgroundPreview => '当前背景';

	/// zh-CN: '图片与视频'
	String get backgroundPreviewKind => '图片与视频';

	/// zh-CN: '上一张'
	String get backgroundPreviewPrevious => '上一张';

	/// zh-CN: '下一张'
	String get backgroundPreviewNext => '下一张';

	/// zh-CN: '壁纸预览'
	String get backgroundPreviewTitle => '壁纸预览';

	/// zh-CN: '更换背景'
	String get backgroundChange => '更换背景';

	/// zh-CN: '背景来源'
	String get backgroundSource => '背景来源';

	/// zh-CN: '无'
	String get backgroundNone => '无';

	/// zh-CN: '图片'
	String get backgroundImage => '图片';

	/// zh-CN: '视频'
	String get backgroundVideo => '视频';

	/// zh-CN: '图片地址'
	String get backgroundImageAddress => '图片地址';

	/// zh-CN: '视频地址'
	String get backgroundVideoAddress => '视频地址';

	/// zh-CN: '当前使用'
	String get backgroundAddressInUse => '当前使用';

	/// zh-CN: 'https://…'
	String get backgroundAddressHint => 'https://…';

	/// zh-CN: '应用'
	String get backgroundApply => '应用';

	/// zh-CN: '选择图片'
	String get backgroundUploadImage => '选择图片';

	/// zh-CN: '选择视频'
	String get backgroundUploadVideo => '选择视频';

	/// zh-CN: '地址需要是 http(s) 链接'
	String get backgroundInvalidUrl => '地址需要是 http(s) 链接';

	/// zh-CN: '导入失败'
	String get backgroundImportFailed => '导入失败';

	/// zh-CN: '拖入的文件类型不支持'
	String get backgroundDropUnsupported => '拖入的文件类型不支持';

	/// zh-CN: '正在复制文件…'
	String get backgroundBusy => '正在复制文件…';

	/// zh-CN: '显示'
	String get backgroundDisplay => '显示';

	/// zh-CN: '填充方式'
	String get backgroundFit => '填充方式';

	/// zh-CN: '把图片或视频铺到窗口时的方式；纯色与渐变没有可填充的对象。'
	String get backgroundFitDescription => '把图片或视频铺到窗口时的方式；纯色与渐变没有可填充的对象。';

	/// zh-CN: '裁切填满'
	String get backgroundFitCover => '裁切填满';

	/// zh-CN: '完整显示'
	String get backgroundFitContain => '完整显示';

	/// zh-CN: '拉伸填满'
	String get backgroundFitFill => '拉伸填满';

	/// zh-CN: '适应宽度'
	String get backgroundFitWidth => '适应宽度';

	/// zh-CN: '适应高度'
	String get backgroundFitHeight => '适应高度';

	/// zh-CN: '原始大小'
	String get backgroundFitNone => '原始大小';

	/// zh-CN: '缩小'
	String get backgroundFitScaleDown => '缩小';

	/// zh-CN: '蒙层浓度'
	String get backgroundMask => '蒙层浓度';

	/// zh-CN: '在壁纸上盖一层压暗或提亮的蒙层；浓度越高文字越清楚，壁纸越淡。'
	String get backgroundMaskDescription => '在壁纸上盖一层压暗或提亮的蒙层；浓度越高文字越清楚，壁纸越淡。';

	/// zh-CN: '蒙层模式'
	String get backgroundScrimMode => '蒙层模式';

	/// zh-CN: '自动按文字清晰度加深蒙层，至少使用下方浓度；自定义只用下方浓度；关闭则完全不加蒙层。'
	String get backgroundScrimModeDescription => '自动按文字清晰度加深蒙层，至少使用下方浓度；自定义只用下方浓度；关闭则完全不加蒙层。';

	/// zh-CN: '自动'
	String get backgroundScrimAuto => '自动';

	/// zh-CN: '自定义'
	String get backgroundScrimCustom => '自定义';

	/// zh-CN: '关闭'
	String get backgroundScrimOff => '关闭';

	/// zh-CN: '背景模糊'
	String get backgroundOverlayBlur => '背景模糊';

	/// zh-CN: '模糊壁纸本身，图片、视频、纯色、渐变都生效；0 保持清晰。'
	String get backgroundOverlayBlurDescription => '模糊壁纸本身，图片、视频、纯色、渐变都生效；0 保持清晰。';

	/// zh-CN: '回到主题自身的底色，已保存的媒体仍保留，随时可再次选择。'
	String get backgroundClearDescription => '回到主题自身的底色，已保存的媒体仍保留，随时可再次选择。';

	/// zh-CN: '清除背景'
	String get backgroundClear => '清除背景';

	/// zh-CN: '界面玻璃'
	String get backgroundGlass => '界面玻璃';

	/// zh-CN: '启用'
	String get backgroundGlassEnable => '启用';

	/// zh-CN: '卡片、列表与浮层底色变半透明，浮层再模糊背后内容，让壁纸透出来。'
	String get backgroundGlassDescription => '卡片、列表与浮层底色变半透明，浮层再模糊背后内容，让壁纸透出来。';

	/// zh-CN: '面板填充'
	String get backgroundGlassFill => '面板填充';

	/// zh-CN: '卡片、列表和浮层底色的不透明度；越低壁纸透得越多，文字对比越弱。'
	String get backgroundGlassFillDescription => '卡片、列表和浮层底色的不透明度；越低壁纸透得越多，文字对比越弱。';

	/// zh-CN: '浮层模糊'
	String get backgroundGlassBlur => '浮层模糊';

	/// zh-CN: '浮层背后内容的模糊半径；0 只半透明不模糊。'
	String get backgroundGlassBlurDescription => '浮层背后内容的模糊半径；0 只半透明不模糊。';

	/// zh-CN: '检查更新'
	String get checkUpdate => '检查更新';

	/// zh-CN: '从项目的发行页读取最新版本。'
	String get checkUpdateDesc => '从项目的发行页读取最新版本。';

	/// zh-CN: '正在检查更新…'
	String get checkingUpdate => '正在检查更新…';

	/// zh-CN: '可更新到 {version}'
	String updateAvailable({required Object version}) => '可更新到 ${version}';

	/// zh-CN: '已是最新版本'
	String get upToDate => '已是最新版本';

	/// zh-CN: '检查更新失败'
	String get updateCheckFailed => '检查更新失败';

	/// zh-CN: '查看更新'
	String get viewUpdate => '查看更新';

	/// zh-CN: '版本更新'
	String get updatePanelTitle => '版本更新';

	/// zh-CN: '构建 {build}'
	String updateBuild({required Object build}) => '构建 ${build}';

	/// zh-CN: '打开下载页'
	String get openDownload => '打开下载页';

	/// zh-CN: '版本记录'
	String get releaseHistory => '版本记录';

	/// zh-CN: '查看项目历次发布与更新内容。'
	String get releaseHistoryDesc => '查看项目历次发布与更新内容。';

	/// zh-CN: '暂无发布记录'
	String get releaseHistoryEmpty => '暂无发布记录';

	/// zh-CN: '发行记录加载失败'
	String get releaseHistoryFailed => '发行记录加载失败';

	/// zh-CN: '发布于 {date}'
	String releasedOn({required Object date}) => '发布于 ${date}';

	/// zh-CN: '预览版'
	String get prerelease => '预览版';

	/// zh-CN: '稍后再说'
	String get updateLater => '稍后再说';

	/// zh-CN: '下载安装包'
	String get downloadInstaller => '下载安装包';

	/// zh-CN: '其他构建'
	String get downloadOtherBuilds => '其他构建';

	/// zh-CN: '获取安装包'
	String get downloadTitle => '获取安装包';

	/// zh-CN: '最新版本'
	String get downloadLatest => '最新版本';

	/// zh-CN: '选择与本机匹配的包；下载保存到「数据与缓存」里的下载目录。'
	String get downloadHint => '选择与本机匹配的包；下载保存到「数据与缓存」里的下载目录。';

	/// zh-CN: '下载'
	String get downloadAction => '下载';

	/// zh-CN: '{count} 次下载'
	String downloadCount({required Object count}) => '${count} 次下载';

	/// zh-CN: '无法读取发布文件列表'
	String get downloadFailed => '无法读取发布文件列表';

	/// zh-CN: '这个发布没有可下载的文件'
	String get downloadEmpty => '这个发布没有可下载的文件';

	/// zh-CN: '这个发布没有匹配本机的安装包，已打开发布页。'
	String get downloadNoBuild => '这个发布没有匹配本机的安装包，已打开发布页。';

	/// zh-CN: '{received} / {total}'
	String downloadProgress({required Object received, required Object total}) => '${received} / ${total}';

	/// zh-CN: '已下载 {received}'
	String downloadProgressUnknown({required Object received}) => '已下载 ${received}';

	/// zh-CN: '已保存到 {path}'
	String downloadSavedTo({required Object path}) => '已保存到 ${path}';

	/// zh-CN: '下载已取消，未保留部分文件。'
	String get downloadCancelled => '下载已取消，未保留部分文件。';

	/// zh-CN: '打开文件'
	String get downloadOpenFile => '打开文件';

	/// zh-CN: '打开所在文件夹'
	String get downloadOpenFolder => '打开所在文件夹';

	/// zh-CN: '无法打开该文件'
	String get downloadOpenFailed => '无法打开该文件';

	/// zh-CN: '已加入下载：{title}'
	String downloadQueued({required Object title}) => '已加入下载：${title}';

	/// zh-CN: '查看'
	String get downloadManagerView => '查看';

	/// zh-CN: '下载管理'
	String get downloadManagerTitle => '下载管理';

	/// zh-CN: '壁纸的下载任务、记录与保存目录。'
	String get downloadManagerDesc => '壁纸的下载任务、记录与保存目录。';

	/// zh-CN: '还没有下载记录'
	String get downloadManagerEmpty => '还没有下载记录';

	/// zh-CN: '在预览或图库点「下载」，任务会出现在这里。'
	String get downloadManagerEmptyDesc => '在预览或图库点「下载」，任务会出现在这里。';

	/// zh-CN: '下载中'
	String get downloadStatusRunning => '下载中';

	/// zh-CN: '已完成'
	String get downloadStatusDone => '已完成';

	/// zh-CN: '下载失败'
	String get downloadStatusFailed => '下载失败';

	/// zh-CN: '开始于 {time}'
	String downloadStartedAt({required Object time}) => '开始于 ${time}';

	/// zh-CN: '完成于 {time}'
	String downloadFinishedAt({required Object time}) => '完成于 ${time}';

	/// zh-CN: '移除记录'
	String get downloadRemove => '移除记录';

	/// zh-CN: '只移除这条记录，不会删除已保存的文件。'
	String get downloadRemoveBody => '只移除这条记录，不会删除已保存的文件。';

	/// zh-CN: '清除已完成'
	String get downloadClearFinished => '清除已完成';

	/// zh-CN: '这个文件正在下载'
	String get downloadDuplicateRunning => '这个文件正在下载';

	/// zh-CN: '这个文件已经下载过了'
	String get downloadDuplicateDone => '这个文件已经下载过了';

	/// zh-CN: '打开文件夹'
	String get downloadManagerOpenFolder => '打开文件夹';

	/// zh-CN: '全部'
	String get downloadFilterAll => '全部';

	/// zh-CN: '没有符合这个状态的记录'
	String get downloadFilterEmpty => '没有符合这个状态的记录';

	/// zh-CN: '按类型筛选'
	String get downloadKindFilter => '按类型筛选';

	/// zh-CN: '文件'
	String get downloadColumnFile => '文件';

	/// zh-CN: '大小'
	String get downloadColumnSize => '大小';

	/// zh-CN: '时间'
	String get downloadColumnTime => '时间';

	/// zh-CN: '操作'
	String get downloadColumnActions => '操作';

	/// zh-CN: '搜索下载记录'
	String get downloadSearchPlaceholder => '搜索下载记录';

	/// zh-CN: '下载中 {percent}%'
	String downloadPercent({required Object percent}) => '下载中 ${percent}%';

	/// zh-CN: '已暂停'
	String get downloadStatusPaused => '已暂停';

	/// zh-CN: '已加载 {shown} / {total}'
	String downloadLoadedCount({required Object shown, required Object total}) => '已加载 ${shown} / ${total}';

	/// zh-CN: '正在加载更多…'
	String get downloadLoadingMore => '正在加载更多…';

	/// zh-CN: '下载设置'
	String get downloadSettings => '下载设置';

	/// zh-CN: '点击进入预览'
	String get downloadDetailPreview => '点击进入预览';

	/// zh-CN: '下载详情'
	String get downloadDetailTitle => '下载详情';

	/// zh-CN: '保存路径'
	String get downloadInfoPath => '保存路径';

	/// zh-CN: '文件大小'
	String get downloadInfoSize => '文件大小';

	/// zh-CN: '下载时间'
	String get downloadInfoTime => '下载时间';

	/// zh-CN: '全选'
	String get downloadSelectAll => '全选';

	/// zh-CN: '已选 {count} 项'
	String downloadSelectedCount({required Object count}) => '已选 ${count} 项';

	/// zh-CN: '删除所选（{count}）'
	String downloadDeleteSelected({required Object count}) => '删除所选（${count}）';

	/// zh-CN: '全部删除'
	String get downloadDeleteAll => '全部删除';

	/// zh-CN: '全部类型'
	String get downloadTypeAll => '全部类型';

	/// zh-CN: '暂停'
	String get downloadPause => '暂停';

	/// zh-CN: '继续下载'
	String get downloadResume => '继续下载';

	/// zh-CN: '已暂停 · 点击继续'
	String get downloadPausedHint => '已暂停 · 点击继续';

	/// zh-CN: '预计还需 {seconds} 秒'
	String downloadEtaSeconds({required Object seconds}) => '预计还需 ${seconds} 秒';

	/// zh-CN: '预计还需 {minutes} 分钟'
	String downloadEtaMinutes({required Object minutes}) => '预计还需 ${minutes} 分钟';

	/// zh-CN: '预计还需 {hours} 小时'
	String downloadEtaHours({required Object hours}) => '预计还需 ${hours} 小时';

	/// zh-CN: '共 {total} 项'
	String downloadSummary({required Object total}) => '共 ${total} 项';

	/// zh-CN: '共 {total} 个任务 · {running} 个正在下载'
	String downloadSummaryMoving({required Object total, required Object running}) => '共 ${total} 个任务 · ${running} 个正在下载';

	/// zh-CN: '共 {total} 个任务 · 第 {page}/{count} 页'
	String downloadPageSummary({required Object total, required Object page, required Object count}) => '共 ${total} 个任务 · 第 ${page}/${count} 页';

	/// zh-CN: '发布页'
	String get openReleasePage => '发布页';

	/// zh-CN: '展开更新内容'
	String get releaseExpand => '展开更新内容';

	/// zh-CN: '收起更新内容'
	String get releaseCollapse => '收起更新内容';

	/// zh-CN: '安卓'
	String get releaseOsAndroid => '安卓';

	/// zh-CN: 'iOS'
	String get releaseOsIos => 'iOS';

	/// zh-CN: 'Windows'
	String get releaseOsWindows => 'Windows';

	/// zh-CN: 'macOS'
	String get releaseOsMacos => 'macOS';

	/// zh-CN: 'Linux'
	String get releaseOsLinux => 'Linux';

	/// zh-CN: '其他平台'
	String get releaseOsOther => '其他平台';

	/// zh-CN: 'APK 安装包'
	String get releaseKindApk => 'APK 安装包';

	/// zh-CN: 'IPA'
	String get releaseKindIpa => 'IPA';

	/// zh-CN: '安装程序'
	String get releaseKindInstaller => '安装程序';

	/// zh-CN: 'DMG 磁盘映像'
	String get releaseKindDmg => 'DMG 磁盘映像';

	/// zh-CN: 'MSIX 应用包'
	String get releaseKindMsix => 'MSIX 应用包';

	/// zh-CN: 'DEB 软件包'
	String get releaseKindDeb => 'DEB 软件包';

	/// zh-CN: 'tar.gz 归档'
	String get releaseKindTarGz => 'tar.gz 归档';

	/// zh-CN: '便携版压缩包'
	String get releaseKindPortable => '便携版压缩包';

	/// zh-CN: '文件'
	String get releaseKindOther => '文件';

	/// zh-CN: '至少保留一个平台'
	String get sitesKeepOne => '至少保留一个平台';

	/// zh-CN: '离开应用时自动小窗'
	String get autoPip => '离开应用时自动小窗';

	/// zh-CN: '播放中离开应用时把画面留在系统小窗；需要悬浮窗权限。'
	String get autoPipDesc => '播放中离开应用时把画面留在系统小窗；需要悬浮窗权限。';

	/// zh-CN: '返回时悬浮播放'
	String get floatPlay => '返回时悬浮播放';

	/// zh-CN: '离开直播间时把画面留在可拖动的小窗；关闭小窗即停止播放。'
	String get floatPlayDesc => '离开直播间时把画面留在可拖动的小窗；关闭小窗即停止播放。';

	/// zh-CN: '小窗始终置顶'
	String get windowsPipAlwaysOnTop => '小窗始终置顶';

	/// zh-CN: '小窗保持在其他窗口之上；正在播放的小窗立即应用。'
	String get windowsPipAlwaysOnTopDesc => '小窗保持在其他窗口之上；正在播放的小窗立即应用。';

	/// zh-CN: '记住小窗位置'
	String get rememberPipPosition => '记住小窗位置';

	/// zh-CN: '再次进入小窗时回到上次的尺寸、位置和显示器；关闭后每次使用默认位置。'
	String get rememberPipPositionDesc => '再次进入小窗时回到上次的尺寸、位置和显示器；关闭后每次使用默认位置。';

	/// zh-CN: '小窗基准尺寸'
	String get windowsPipBaseSize => '小窗基准尺寸';

	/// zh-CN: '横向视频的长边；竖向视频时作为高。范围 200–720。'
	String get windowsPipBaseSizeDesc => '横向视频的长边；竖向视频时作为高。范围 200–720。';

	/// zh-CN: '小窗最小宽度'
	String get windowsPipMinWidth => '小窗最小宽度';

	/// zh-CN: '小窗最小宽度，100–320；离开小窗后恢复常规下限。'
	String get windowsPipMinWidthDesc => '小窗最小宽度，100–320；离开小窗后恢复常规下限。';

	/// zh-CN: '小窗最小高度'
	String get windowsPipMinHeight => '小窗最小高度';

	/// zh-CN: '小窗最小高度，60–240；离开小窗后恢复常规下限。'
	String get windowsPipMinHeightDesc => '小窗最小高度，60–240；离开小窗后恢复常规下限。';

	/// zh-CN: '自动全屏'
	String get fullscreenDefault => '自动全屏';

	/// zh-CN: '当进入直播播放页，自动进入全屏'
	String get fullscreenDefaultDesc => '当进入直播播放页，自动进入全屏';

	/// zh-CN: '播放时保持屏幕常亮'
	String get keepScreenOn => '播放时保持屏幕常亮';

	/// zh-CN: '房间或频道播放时阻止屏幕自动熄灭；暂停后恢复系统休眠。'
	String get keepScreenOnDesc => '房间或频道播放时阻止屏幕自动熄灭；暂停后恢复系统休眠。';

	/// zh-CN: '控制条自动隐藏'
	String get controlsAutoHide => '控制条自动隐藏';

	/// zh-CN: '播放时经过该秒数后隐藏画面控制条；暂停时保持显示。'
	String get controlsAutoHideDesc => '播放时经过该秒数后隐藏画面控制条；暂停时保持显示。';

	/// zh-CN: '{count: int} 秒'
	String controlsAutoHideValue({required int count}) => '${count} 秒';

	/// zh-CN: '竖屏直播适配'
	String get navPortrait => '竖屏直播适配';

	/// zh-CN: '自动识别直播源方向，并调整普通页的观看区域与布局。'
	String get portraitPageDescription => '自动识别直播源方向，并调整普通页的观看区域与布局。';

	/// zh-CN: '观众指标'
	String get navAudience => '观众指标';

	/// zh-CN: '卡片人数口径、真实在线优先与平台开关。'
	String get audiencePageDescription => '卡片人数口径、真实在线优先与平台开关。';

	/// zh-CN: '已关闭'
	String get portraitEntryOff => '已关闭';

	/// zh-CN: '识别与普通页布局'
	String get portraitDetectionGroup => '识别与普通页布局';

	/// zh-CN: '智能识别竖屏直播源'
	String get portraitSmartDetection => '智能识别竖屏直播源';

	/// zh-CN: '按解码后的真实画面尺寸识别竖屏；关闭后竖屏源按横屏显示。'
	String get portraitSmartDetectionDesc => '按解码后的真实画面尺寸识别竖屏；关闭后竖屏源按横屏显示。';

	/// zh-CN: '普通页自适应视频高度'
	String get portraitAdaptiveHeight => '普通页自适应视频高度';

	/// zh-CN: '竖屏源增大观看区域，同时保留足够的聊天与弹幕列表空间。'
	String get portraitAdaptiveHeightDesc => '竖屏源增大观看区域，同时保留足够的聊天与弹幕列表空间。';

	/// zh-CN: '普通页布局模式'
	String get portraitLayoutMode => '普通页布局模式';

	/// zh-CN: '仅影响竖屏直播源，不改变普通横屏直播。'
	String get portraitLayoutModeDesc => '仅影响竖屏直播源，不改变普通横屏直播。';

	/// zh-CN: '均衡（推荐）'
	String get portraitLayoutBalanced => '均衡（推荐）';

	/// zh-CN: '沉浸'
	String get portraitLayoutImmersive => '沉浸';

	/// zh-CN: '兼容 16:9'
	String get portraitLayoutCompatibility => '兼容 16:9';

	/// zh-CN: '开启智能识别后才能调整高度与布局。'
	String get portraitDetectionOff => '开启智能识别后才能调整高度与布局。';

	/// zh-CN: '分区'
	String get searchSections => '分区';

	/// zh-CN: '具体设置'
	String get searchRows => '具体设置';

	/// zh-CN: '匹配：{items: String}'
	String searchRowMatches({required String items}) => '匹配：${items}';

	/// zh-CN: '观众数显示'
	String get audienceMetric => '观众数显示';

	/// zh-CN: '热门、关注等卡片优先展示的观众指标。'
	String get audienceMetricDesc => '热门、关注等卡片优先展示的观众指标。';

	/// zh-CN: '跟随平台'
	String get audienceAutomatic => '跟随平台';

	/// zh-CN: '在线观众'
	String get audienceOnline => '在线观众';

	/// zh-CN: '热度'
	String get audiencePopularity => '热度';

	/// zh-CN: '累计观看'
	String get audienceTotal => '累计观看';

	/// zh-CN: '卡片显示与排行方式'
	String get audienceDisplayGroup => '卡片显示与排行方式';

	/// zh-CN: '排序用卡片显示的数值；「真实在线」仅在跟随平台下、已开启的平台生效。'
	String get audienceRankingNote => '排序用卡片显示的数值；「真实在线」仅在跟随平台下、已开启的平台生效。';

	/// zh-CN: '真实在线人数'
	String get audienceRealOnlineGroup => '真实在线人数';

	/// zh-CN: '真实在线人数优先'
	String get audienceRealOnline => '真实在线人数优先';

	/// zh-CN: '跟随平台显示时，已开启的平台优先用同时在线人数，其余保留热度或累计。'
	String get audienceRealOnlineDesc => '跟随平台显示时，已开启的平台优先用同时在线人数，其余保留热度或累计。';

	/// zh-CN: '先在「观众数显示」中选择「跟随平台」，真实在线优先才会生效。'
	String get audienceNeedsAutomaticMode => '先在「观众数显示」中选择「跟随平台」，真实在线优先才会生效。';

	/// zh-CN: '真实在线平台'
	String get audiencePlatformsGroup => '真实在线平台';

	/// zh-CN: '只有公开返回并发人数的平台会出现；关闭后该平台仍按热度显示。'
	String get audiencePlatformsDesc => '只有公开返回并发人数的平台会出现；关闭后该平台仍按热度显示。';

	/// zh-CN: '来源：房间列表/详情，可直接排行'
	String get audienceSourceRoomList => '来源：房间列表/详情，可直接排行';

	/// zh-CN: '来源：进入直播间后的实时消息'
	String get audienceSourceRoomRealtime => '来源：进入直播间后的实时消息';

	/// zh-CN: '先开启「真实在线人数优先」'
	String get audiencePlatformNeedsOnline => '先开启「真实在线人数优先」';

	/// zh-CN: '仅热度或累计观看的平台'
	String get audienceHeatOnlyGroup => '仅热度或累计观看的平台';

	/// zh-CN: '这些平台的接口没有并发人数，卡片照常标明热度或累计观看。'
	String get audienceHeatOnlyDesc => '这些平台的接口没有并发人数，卡片照常标明热度或累计观看。';

	/// zh-CN: '纯色'
	String get backgroundSolid => '纯色';

	/// zh-CN: '渐变'
	String get backgroundGradient => '渐变';

	/// zh-CN: '预设'
	String get backgroundPresets => '预设';

	/// zh-CN: '壁纸图库'
	String get backgroundLibraryTitle => '壁纸图库';

	/// zh-CN: '没有可用的壁纸'
	String get backgroundLibraryEmpty => '没有可用的壁纸';

	/// zh-CN: '图库加载失败'
	String get backgroundLibraryFailed => '图库加载失败';

	/// zh-CN: '已应用为背景'
	String get backgroundLibraryApplied => '已应用为背景';

	/// zh-CN: '官方壁纸'
	String get wallpaperSourceOfficial => '官方壁纸';

	/// zh-CN: 'Wallhaven'
	String get wallpaperSourceWallhaven => 'Wallhaven';

	/// zh-CN: '必应壁纸'
	String get wallpaperSourceBing => '必应壁纸';

	/// zh-CN: 'deepin'
	String get wallpaperSourceDeepin => 'deepin';

	/// zh-CN: '动态壁纸'
	String get wallpaperSourceVideo => '动态壁纸';

	/// zh-CN: '自然'
	String get wallpaperCategoryNature => '自然';

	/// zh-CN: '动漫'
	String get wallpaperCategoryAnime => '动漫';

	/// zh-CN: '艺术'
	String get wallpaperCategoryArt => '艺术';

	/// zh-CN: '建筑'
	String get wallpaperCategoryArchitecture => '建筑';

	/// zh-CN: '生命'
	String get wallpaperCategoryLife => '生命';

	/// zh-CN: '纹理'
	String get wallpaperCategoryTexture => '纹理';

	/// zh-CN: '其他'
	String get wallpaperCategoryOther => '其他';

	/// zh-CN: '热门'
	String get wallpaperCategoryPopular => '热门';

	/// zh-CN: '极简主义'
	String get wallpaperCategoryMinimalism => '极简主义';

	/// zh-CN: '图案'
	String get wallpaperCategoryPatterns => '图案';

	/// zh-CN: '风景'
	String get wallpaperCategoryLandscape => '风景';

	/// zh-CN: 'Cosplay'
	String get wallpaperCategoryCosplay => 'Cosplay';

	/// zh-CN: '蜘蛛侠'
	String get wallpaperCategorySpiderMan => '蜘蛛侠';

	/// zh-CN: '吉卜力'
	String get wallpaperCategoryGhibli => '吉卜力';

	/// zh-CN: '火影忍者'
	String get wallpaperCategoryNaruto => '火影忍者';

	/// zh-CN: '科幻'
	String get wallpaperCategorySciFi => '科幻';

	/// zh-CN: '日漫'
	String get wallpaperCategoryAnimeWallhaven => '日漫';

	/// zh-CN: '动漫女孩'
	String get wallpaperCategoryAnimeGirls => '动漫女孩';

	/// zh-CN: '赛博朋克'
	String get wallpaperCategoryCyberpunk => '赛博朋克';

	/// zh-CN: '像素艺术'
	String get wallpaperCategoryPixelArt => '像素艺术';

	/// zh-CN: '艺术画'
	String get wallpaperCategoryArtwork => '艺术画';

	/// zh-CN: '城市景观'
	String get wallpaperCategoryCityscape => '城市景观';

	/// zh-CN: '数字艺术'
	String get wallpaperCategoryDigitalArt => '数字艺术';

	/// zh-CN: '奇幻艺术'
	String get wallpaperCategoryFantasyArt => '奇幻艺术';

	/// zh-CN: '最终幻想'
	String get wallpaperCategoryFinalFantasy => '最终幻想';

	/// zh-CN: '标签管理'
	String get tagManagement => '标签管理';

	/// zh-CN: '自定义和管理直播间的过滤标签'
	String get tagManagementDesc => '自定义和管理直播间的过滤标签';

	/// zh-CN: '添加标签'
	String get tagAdd => '添加标签';

	/// zh-CN: '编辑标签'
	String get tagEdit => '编辑标签';

	/// zh-CN: '移到最前'
	String get tagPin => '移到最前';

	/// zh-CN: '保存'
	String get tagSaveAction => '保存';

	/// zh-CN: '标签名称'
	String get tagNameLabel => '标签名称';

	/// zh-CN: '例如“常看”“睡前听”'
	String get tagNameHint => '例如“常看”“睡前听”';

	/// zh-CN: '备注描述（可选）'
	String get tagNoteLabel => '备注描述（可选）';

	/// zh-CN: '给这个标签写一句备注'
	String get tagNoteHint => '给这个标签写一句备注';

	/// zh-CN: '标签名称不能为空'
	String get tagNameEmpty => '标签名称不能为空';

	/// zh-CN: '已存在同名标签'
	String get tagNameDuplicate => '已存在同名标签';

	/// zh-CN: '标签更改未保存，请重试'
	String get tagSaveFailed => '标签更改未保存，请重试';

	/// zh-CN: '这个标签已在别处被删除或修改'
	String get tagStale => '这个标签已在别处被删除或修改';

	/// zh-CN: '已添加标签“{name: String}”'
	String tagAddedToast({required String name}) => '已添加标签“${name}”';

	/// zh-CN: '已保存标签“{name: String}”'
	String tagSavedToast({required String name}) => '已保存标签“${name}”';

	/// zh-CN: '已删除标签“{name: String}”'
	String tagDeletedToast({required String name}) => '已删除标签“${name}”';

	/// zh-CN: '确定要永久删除标签“{name: String}”吗？'
	String tagDeleteTitle({required String name}) => '确定要永久删除标签“${name}”吗？';

	/// zh-CN: '{count: int} 个直播间会移出该标签，不会被取消关注。'
	String tagDeleteRoomsHint({required int count}) => '${count} 个直播间会移出该标签，不会被取消关注。';

	/// zh-CN: '该标签还没有直播间在使用。'
	String get tagDeleteBody => '该标签还没有直播间在使用。';

	/// zh-CN: '暂无自定义标签'
	String get tagEmptyTitle => '暂无自定义标签';

	/// zh-CN: '在关注页的卡片菜单里给直播间加标签，即可按标签筛选。'
	String get tagEmptyHint => '在关注页的卡片菜单里给直播间加标签，即可按标签筛选。';

	/// zh-CN: '拖动左侧把手调整顺序，关注页的标签栏按这个顺序显示。'
	String get tagSortTip => '拖动左侧把手调整顺序，关注页的标签栏按这个顺序显示。';

	/// zh-CN: '{count: int} 个直播间'
	String tagRooms({required int count}) => '${count} 个直播间';

	/// zh-CN: '显示不能直接播放的直播'
	String get showUnplayableTitle => '显示不能直接播放的直播';

	/// zh-CN: '付费、加锁、仅限 App 的直播也显示在热门与分区；关注和搜索始终显示。'
	String get showUnplayableDesc => '付费、加锁、仅限 App 的直播也显示在热门与分区；关注和搜索始终显示。';

	/// zh-CN: '小窗自由比例'
	String get windowsPipFreeAspect => '小窗自由比例';

	/// zh-CN: '可单独压小高度或拉宽窗口，不符的一侧留黑边；关闭时窗口始终等于视频形状。'
	String get windowsPipFreeAspectDesc => '可单独压小高度或拉宽窗口，不符的一侧留黑边；关闭时窗口始终等于视频形状。';

	/// zh-CN: '重置小窗位置和大小'
	String get windowsPipResetPosition => '重置小窗位置和大小';

	/// zh-CN: '清除已存的小窗尺寸与位置，下次从右下角打开。'
	String get windowsPipResetPositionDesc => '清除已存的小窗尺寸与位置，下次从右下角打开。';

	/// zh-CN: '确定要清除已保存的小窗位置和大小吗？'
	String get windowsPipResetPositionConfirm => '确定要清除已保存的小窗位置和大小吗？';

	/// zh-CN: '重置'
	String get windowsPipResetAction => '重置';

	/// zh-CN: '已清除保存的小窗位置和大小'
	String get windowsPipResetPositionSuccess => '已清除保存的小窗位置和大小';

	/// zh-CN: '适应高度'
	String get fitHeight => '适应高度';

	/// zh-CN: '适应宽度'
	String get fitWidth => '适应宽度';

	/// zh-CN: '等比缩小'
	String get fitScaleDown => '等比缩小';

	/// zh-CN: '纯文字模式（隐藏表情）'
	String get styleNoEmoji => '纯文字模式（隐藏表情）';

	/// zh-CN: '画面飞行弹幕只画文字，表情图片跳过；聊天列表不受影响。'
	String get styleNoEmojiDesc => '画面飞行弹幕只画文字，表情图片跳过；聊天列表不受影响。';

	/// zh-CN: '全屏呈现'
	String get portraitPresentationGroup => '全屏呈现';

	/// zh-CN: '进入全屏时的方向'
	String get portraitFullscreenPolicy => '进入全屏时的方向';

	/// zh-CN: '大屏和分屏设备自动交给系统布局，手机可跟随直播源'
	String get portraitFullscreenPolicyDesc => '大屏和分屏设备自动交给系统布局，手机可跟随直播源';

	/// zh-CN: '跟随直播源（推荐）'
	String get portraitFullscreenFollowSource => '跟随直播源（推荐）';

	/// zh-CN: '跟随系统'
	String get portraitFullscreenFollowSystem => '跟随系统';

	/// zh-CN: '始终横屏'
	String get portraitFullscreenLandscape => '始终横屏';

	/// zh-CN: '恢复竖屏适配默认设置'
	String get portraitReset => '恢复竖屏适配默认设置';

	/// zh-CN: '把识别、自适应高度、布局模式与全屏方向恢复为默认值。'
	String get portraitResetDesc => '把识别、自适应高度、布局模式与全屏方向恢复为默认值。';

	/// zh-CN: '本页的竖屏设置将恢复默认值；普通横屏直播不受影响。'
	String get portraitResetConfirm => '本页的竖屏设置将恢复默认值；普通横屏直播不受影响。';

	/// zh-CN: '顶部留白（像素）'
	String get styleTopMargin => '顶部留白（像素）';

	/// zh-CN: '画面顶部不显示弹幕的高度，0–300。'
	String get styleTopMarginDesc => '画面顶部不显示弹幕的高度，0–300。';

	/// zh-CN: '底部留白（像素）'
	String get styleBottomMargin => '底部留白（像素）';

	/// zh-CN: '画面底部不显示弹幕的高度，避免挡住字幕，0–300。'
	String get styleBottomMarginDesc => '画面底部不显示弹幕的高度，避免挡住字幕，0–300。';

	/// zh-CN: '房间卡片'
	String get roomCardSettingsTitle => '房间卡片';

	/// zh-CN: '版式固定，这里只选显示哪些信息；所有设备共用这一套。'
	String get roomCardSettingsDescription => '版式固定，这里只选显示哪些信息；所有设备共用这一套。';

	/// zh-CN: '卡片预览'
	String get roomCardPreview => '卡片预览';

	/// zh-CN: '今晚八点，一起聊聊新番和游戏'
	String get roomCardPreviewTitle => '今晚八点，一起聊聊新番和游戏';

	/// zh-CN: '夜色电台'
	String get roomCardPreviewAnchor => '夜色电台';

	/// zh-CN: '游戏分区'
	String get roomCardPreviewArea => '游戏分区';

	/// zh-CN: '这是实际使用的卡片与列表，改动会立刻反映在这里。'
	String get roomCardPreviewHint => '这是实际使用的卡片与列表，改动会立刻反映在这里。';

	/// zh-CN: '快捷预设'
	String get roomCardPresets => '快捷预设';

	/// zh-CN: '标准'
	String get roomCardPresetStandard => '标准';

	/// zh-CN: '详细'
	String get roomCardPresetDetailed => '详细';

	/// zh-CN: '自定义'
	String get roomCardPresetCustom => '自定义';

	/// zh-CN: '显示内容'
	String get roomCardVisibleContent => '显示内容';

	/// zh-CN: '标题'
	String get roomCardShowTitle => '标题';

	/// zh-CN: '房间分区'
	String get roomCardShowCoverTitle => '房间分区';

	/// zh-CN: '直播状态'
	String get roomCardShowStatus => '直播状态';

	/// zh-CN: '主播头像'
	String get roomCardShowAvatar => '主播头像';

	/// zh-CN: '主播名称'
	String get roomCardShowAnchor => '主播名称';

	/// zh-CN: '平台显示'
	String get roomCardShowPlatform => '平台显示';

	/// zh-CN: '热度'
	String get roomCardShowAudience => '热度';

	/// zh-CN: '回放'
	String get roomCardReplay => '回放';

	/// zh-CN: '恢复默认显示'
	String get roomCardResetCurrent => '恢复默认显示';

	/// zh-CN: '恢复默认显示？'
	String get roomCardResetConfirmTitle => '恢复默认显示？';

	/// zh-CN: '所有显示项回到默认，当前选择会丢失。'
	String get roomCardResetConfirmBody => '所有显示项回到默认，当前选择会丢失。';

	/// zh-CN: '预览'
	String get backgroundPreviewMedia => '预览';

	/// zh-CN: '复制色值'
	String get backgroundCopyColor => '复制色值';

	/// zh-CN: '复制渐变'
	String get backgroundCopyGradient => '复制渐变';

	/// zh-CN: '复制地址'
	String get backgroundCopyAddress => '复制地址';

	/// zh-CN: '下载失败'
	String get backgroundDownloadFailed => '下载失败';

	/// zh-CN: '播放控制仅用于本次预览；应用的动态壁纸始终静音循环。'
	String get backgroundPreviewVideoHint => '播放控制仅用于本次预览；应用的动态壁纸始终静音循环。';

	/// zh-CN: '刷新缩略图'
	String get cacheRefreshThumbnails => '刷新缩略图';

	/// zh-CN: '清空封面、头像与图标缓存，下一次显示时重新下载。'
	String get cacheRefreshThumbnailsDesc => '清空封面、头像与图标缓存，下一次显示时重新下载。';

	/// zh-CN: '缩略图已刷新'
	String get cacheRefreshThumbnailsDone => '缩略图已刷新';

	/// zh-CN: '下载目录'
	String get downloadDirectory => '下载目录';

	/// zh-CN: '默认'
	String get downloadDirectoryDefaultLabel => '默认';

	/// zh-CN: '自定义'
	String get downloadDirectoryCustomLabel => '自定义';

	/// zh-CN: '恢复默认目录'
	String get downloadDirectoryReset => '恢复默认目录';

	/// zh-CN: '下载目录已更新'
	String get downloadDirectoryUpdated => '下载目录已更新';

	/// zh-CN: '无法选择下载目录'
	String get downloadDirectoryPickFailed => '无法选择下载目录';

	/// zh-CN: '所选目录无法写入：请授予存储权限，或改用默认目录。'
	String get downloadDirectoryPermissionHint => '所选目录无法写入：请授予存储权限，或改用默认目录。';

	/// zh-CN: '更改目录'
	String get downloadDirectoryChange => '更改目录';

	/// zh-CN: '竖屏全屏'
	String get portraitFullscreenGroup => '竖屏全屏';

	/// zh-CN: '画面模式'
	String get portraitDisplayMode => '画面模式';

	/// zh-CN: '完整=原样；沉浸=原样配柔和背景；均衡=轻微裁切；铺满=裁两侧填满。'
	String get portraitDisplayModeDesc => '完整=原样；沉浸=原样配柔和背景；均衡=轻微裁切；铺满=裁两侧填满。';

	/// zh-CN: '弹幕区域'
	String get portraitDanmakuMode => '弹幕区域';

	/// zh-CN: '竖屏全屏中飞行弹幕可占用的区域。'
	String get portraitDanmakuModeDesc => '竖屏全屏中飞行弹幕可占用的区域。';

	/// zh-CN: '记住每个房间的选择'
	String get portraitRememberRoom => '记住每个房间的选择';

	/// zh-CN: '竖屏全屏里的画面/弹幕切换按房间记住；关闭即清除。'
	String get portraitRememberRoomDesc => '竖屏全屏里的画面/弹幕切换按房间记住；关闭即清除。';

	/// zh-CN: '竖屏全屏上下滑换台'
	String get portraitSwipeSwitch => '竖屏全屏上下滑换台';

	/// zh-CN: '竖屏全屏时上滑看下一场、下滑看上一场。'
	String get portraitSwipeSwitchDesc => '竖屏全屏时上滑看下一场、下滑看上一场。';

	/// zh-CN: '显示竖屏诊断'
	String get portraitDiagnostics => '显示竖屏诊断';

	/// zh-CN: '在竖屏全屏左下角显示分辨率、宽高比、画面与弹幕模式。'
	String get portraitDiagnosticsDesc => '在竖屏全屏左下角显示分辨率、宽高比、画面与弹幕模式。';

	/// zh-CN: '清除房间覆盖'
	String get portraitClearOverrides => '清除房间覆盖';

	/// zh-CN: '删除所有按房间保存的竖屏画面与弹幕选择，保留全局默认。'
	String get portraitClearOverridesDesc => '删除所有按房间保存的竖屏画面与弹幕选择，保留全局默认。';

	/// zh-CN: '房间覆盖已清除'
	String get portraitOverridesCleared => '房间覆盖已清除';

	/// zh-CN: '已保存 {count: int} 个房间'
	String portraitOverridesCount({required int count}) => '已保存 ${count} 个房间';

	/// zh-CN: '显示聊天用户名'
	String get chatShowNames => '显示聊天用户名';

	/// zh-CN: '关闭后聊天列表只显示内容；长按操作仍知道发送者。'
	String get chatShowNamesDesc => '关闭后聊天列表只显示内容；长按操作仍知道发送者。';

	/// zh-CN: '列表文字大小'
	String get chatListFontSize => '列表文字大小';

	/// zh-CN: '聊天列表的文字大小；跟随主题时与界面保持一致。'
	String get chatListFontSizeDesc => '聊天列表的文字大小；跟随主题时与界面保持一致。';

	/// zh-CN: '跟随主题'
	String get chatListFollowTheme => '跟随主题';

	/// zh-CN: '{size: int} px'
	String chatListFontSizeValue({required int size}) => '${size} px';

	/// zh-CN: '列表行距'
	String get chatListLineSpacing => '列表行距';

	/// zh-CN: '聊天列表两行之间的留白。'
	String get chatListLineSpacingDesc => '聊天列表两行之间的留白。';

	/// zh-CN: '紧凑'
	String get chatListSpacingCompact => '紧凑';

	/// zh-CN: '标准'
	String get chatListSpacingStandard => '标准';

	/// zh-CN: '宽松'
	String get chatListSpacingLoose => '宽松';

	/// zh-CN: '聊天栏宽度'
	String get chatPanelWidth => '聊天栏宽度';

	/// zh-CN: '桌面宽布局下右侧聊天栏的宽度。'
	String get chatPanelWidthDesc => '桌面宽布局下右侧聊天栏的宽度。';

	/// zh-CN: '暂停时的弹幕'
	String get danmakuPausedBehavior => '暂停时的弹幕';

	/// zh-CN: '视频暂停后，弹幕跟着停住还是照常飘过。'
	String get danmakuPausedBehaviorDesc => '视频暂停后，弹幕跟着停住还是照常飘过。';

	/// zh-CN: '随视频暂停'
	String get danmakuPausedPause => '随视频暂停';

	/// zh-CN: '继续飘过'
	String get danmakuPausedFly => '继续飘过';

	/// zh-CN: 'Twitch 目录语言'
	String get twitchLanguages => 'Twitch 目录语言';

	/// zh-CN: '只显示所选语言的直播；不选则显示全部。'
	String get twitchLanguagesDesc => '只显示所选语言的直播；不选则显示全部。';

	/// zh-CN: '全部语言'
	String get twitchAllLanguages => '全部语言';

	/// zh-CN: '中文 + 韩语'
	String get twitchLegacyLanguages => '中文 + 韩语';

	/// zh-CN: '按主播语言过滤 Twitch 热门与分区目录。'
	String get twitchLanguagesHint => '按主播语言过滤 Twitch 热门与分区目录。';

	/// zh-CN: '中文'
	String get twitchLanguage_zh => '中文';

	/// zh-CN: '英语'
	String get twitchLanguage_en => '英语';

	/// zh-CN: '韩语'
	String get twitchLanguage_ko => '韩语';

	/// zh-CN: '日语'
	String get twitchLanguage_ja => '日语';

	/// zh-CN: '西班牙语'
	String get twitchLanguage_es => '西班牙语';

	/// zh-CN: '葡萄牙语'
	String get twitchLanguage_pt => '葡萄牙语';

	/// zh-CN: '德语'
	String get twitchLanguage_de => '德语';

	/// zh-CN: '法语'
	String get twitchLanguage_fr => '法语';

	/// zh-CN: '俄语'
	String get twitchLanguage_ru => '俄语';

	/// zh-CN: '意大利语'
	String get twitchLanguage_it => '意大利语';

	/// zh-CN: '泰语'
	String get twitchLanguage_th => '泰语';

	/// zh-CN: '越南语'
	String get twitchLanguage_vi => '越南语';

	/// zh-CN: '印度尼西亚语'
	String get twitchLanguage_id => '印度尼西亚语';

	/// zh-CN: '土耳其语'
	String get twitchLanguage_tr => '土耳其语';

	/// zh-CN: '波兰语'
	String get twitchLanguage_pl => '波兰语';

	/// zh-CN: '按住时冻结弹幕'
	String get holdDanmakuOnPress => '按住时冻结弹幕';

	/// zh-CN: '按住弹幕先冻结，便于点按；关闭后按住期间弹幕照常飞过。'
	String get holdDanmakuOnPressDesc => '按住弹幕先冻结，便于点按；关闭后按住期间弹幕照常飞过。';

	/// zh-CN: 'YouTube 显示全部聊天'
	String get youtubeAllChat => 'YouTube 显示全部聊天';

	/// zh-CN: '关闭时使用网页默认的 Top chat；开启后请求全部直播聊天。'
	String get youtubeAllChatDesc => '关闭时使用网页默认的 Top chat；开启后请求全部直播聊天。';

	/// zh-CN: '虎牙优先 H.264'
	String get preferH264 => '虎牙优先 H.264';

	/// zh-CN: '平台同时提供多种编码时优先选择 H.264，兼容性更好。'
	String get preferH264Desc => '平台同时提供多种编码时优先选择 H.264，兼容性更好。';

	/// zh-CN: '打开剪贴板中的直播间？'
	String get clipboardRoomTitle => '打开剪贴板中的直播间？';

	/// zh-CN: '检测到 {platform} 的直播间 {roomId}，是否打开？'
	String clipboardRoomDesc({required Object platform, required Object roomId}) => '检测到 ${platform} 的直播间 ${roomId}，是否打开？';

	/// zh-CN: '打开直播间'
	String get clipboardRoomOpen => '打开直播间';

	/// zh-CN: '后台仅音频'
	String get backgroundAudioOnly => '后台仅音频';

	/// zh-CN: '后台播放时关闭视频解码，只保留声音；回到前台恢复画面。'
	String get backgroundAudioOnlyDesc => '后台播放时关闭视频解码，只保留声音；回到前台恢复画面。';

	/// zh-CN: '关闭画中画时暂停'
	String get pauseOnPipClose => '关闭画中画时暂停';

	/// zh-CN: '开着后台播放时，关小窗即暂停；回应用再继续。'
	String get pauseOnPipCloseDesc => '开着后台播放时，关小窗即暂停；回应用再继续。';

	/// zh-CN: '在聊天列表显示礼物'
	String get chatShowGifts => '在聊天列表显示礼物';

	/// zh-CN: '礼物显示为聊天里的礼物行；关闭后立即移除已有礼物行。'
	String get chatShowGiftsDesc => '礼物显示为聊天里的礼物行；关闭后立即移除已有礼物行。';

	/// zh-CN: '只显示值钱的礼物'
	String get chatGiftsAboveTier => '只显示值钱的礼物';

	/// zh-CN: '免费和便宜的礼物不进聊天列表；连击加起来够了再显示。'
	String get chatGiftsAboveTierDesc => '免费和便宜的礼物不进聊天列表；连击加起来够了再显示。';

	/// zh-CN: '礼物价值换算成元'
	String get chatGiftValueInYuan => '礼物价值换算成元';

	/// zh-CN: '金瓜子、钻石、抖币按平台的固定比例写成元；海外的币种不换算。'
	String get chatGiftValueInYuanDesc => '金瓜子、钻石、抖币按平台的固定比例写成元；海外的币种不换算。';

	/// zh-CN: '上舰和开会员进醒目留言'
	String get superChatIncludesMembership => '上舰和开会员进醒目留言';

	/// zh-CN: 'B 站上舰、YouTube 会员等订阅也在醒目留言里出卡；聊天列表照旧。'
	String get superChatIncludesMembershipDesc => 'B 站上舰、YouTube 会员等订阅也在醒目留言里出卡；聊天列表照旧。';

	/// zh-CN: '飞行弹幕显示礼物'
	String get danmakuShowGifts => '飞行弹幕显示礼物';

	/// zh-CN: '值钱礼物飞过画面，更值钱的在顶部停 4 秒；连击只显示开头和总数。'
	String get danmakuShowGiftsDesc => '值钱礼物飞过画面，更值钱的在顶部停 4 秒；连击只显示开头和总数。';

	/// zh-CN: '小窗大小'
	String get floatWindowSize => '小窗大小';

	/// zh-CN: '应用内悬浮窗的基础大小；拖动缩放会按横屏/竖屏分别记住。'
	String get floatWindowSizeDesc => '应用内悬浮窗的基础大小；拖动缩放会按横屏/竖屏分别记住。';

	/// zh-CN: '小'
	String get floatWindowSmall => '小';

	/// zh-CN: '中'
	String get floatWindowMedium => '中';

	/// zh-CN: '大'
	String get floatWindowLarge => '大';

	/// zh-CN: '后台暂停弹幕连接'
	String get backgroundPauseDanmaku => '后台暂停弹幕连接';

	/// zh-CN: '进入后台时断开平台弹幕连接，回到前台重新连接；聊天记录保留。'
	String get backgroundPauseDanmakuDesc => '进入后台时断开平台弹幕连接，回到前台重新连接；聊天记录保留。';

	/// zh-CN: '斗鱼每 5 分钟自动续期'
	String get douyuForceRenew => '斗鱼每 5 分钟自动续期';

	/// zh-CN: '登录后定期续期 Cookie，降低长时间观看掉登录的概率。'
	String get douyuForceRenewDesc => '登录后定期续期 Cookie，降低长时间观看掉登录的概率。';

	/// zh-CN: '焦点放大'
	String get tvFocusZoom => '焦点放大';

	/// zh-CN: '焦点卡片与控件略微放大；盒子卡顿时可关掉只留描边。'
	String get tvFocusZoomDesc => '焦点卡片与控件略微放大；盒子卡顿时可关掉只留描边。';

	/// zh-CN: 'TV 侧栏始终展开'
	String get tvMenuExpanded => 'TV 侧栏始终展开';

	/// zh-CN: '保持侧栏显示名称；关闭后可用图标轨并在聚焦时展开。'
	String get tvMenuExpandedDesc => '保持侧栏显示名称；关闭后可用图标轨并在聚焦时展开。';

	/// zh-CN: '播放设置'
	String get backgroundPreviewSettingsTitle => '播放设置';

	/// zh-CN: '更多图片'
	String get backgroundMoreImages => '更多图片';

	/// zh-CN: '更多视频'
	String get backgroundMoreVideos => '更多视频';

	/// zh-CN: '显示模式'
	String get backgroundDisplayMode => '显示模式';

	/// zh-CN: '自动播放'
	String get backgroundAutoPlay => '自动播放';

	/// zh-CN: '播放间隔'
	String get backgroundPlayInterval => '播放间隔';

	/// zh-CN: '{count} 秒'
	String backgroundIntervalSeconds({required Object count}) => '${count} 秒';

	/// zh-CN: '循环播放'
	String get backgroundPreviewLooping => '循环播放';

	/// zh-CN: '红果短剧'
	String get navHongguo => '红果短剧';

	/// zh-CN: '红果伴侣服务与播放偏好。'
	String get hongguoDescription => '红果伴侣服务与播放偏好。';

	/// zh-CN: '默认清晰度'
	String get hongguoQuality => '默认清晰度';

	/// zh-CN: '打开剧集时优先请求的清晰度；不存在时自动取更低一档。'
	String get hongguoQualityDesc => '打开剧集时优先请求的清晰度；不存在时自动取更低一档。';

	/// zh-CN: '最高'
	String get hongguoQualityBest => '最高';

	/// zh-CN: '1080P'
	String get hongguoQuality1080 => '1080P';

	/// zh-CN: '720P'
	String get hongguoQuality720 => '720P';

	/// zh-CN: '540P'
	String get hongguoQuality540 => '540P';

	/// zh-CN: '480P'
	String get hongguoQuality480 => '480P';

	/// zh-CN: '360P'
	String get hongguoQuality360 => '360P';

	/// zh-CN: '重置设备身份'
	String get hongguoDeviceReset => '重置设备身份';

	/// zh-CN: '忘记当前匿名设备身份，下次播放时重新向平台注册。'
	String get hongguoDeviceResetDesc => '忘记当前匿名设备身份，下次播放时重新向平台注册。';
}

// Path: shield
class Translations$shield$zh_CN {
	Translations$shield$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '弹幕屏蔽'
	String get title => '弹幕屏蔽';

	/// zh-CN: '按关键词、用户与相似度过滤直播间弹幕，规则保存在本机。'
	String get description => '按关键词、用户与相似度过滤直播间弹幕，规则保存在本机。';

	/// zh-CN: '总开关'
	String get masterTitle => '总开关';

	/// zh-CN: '启用弹幕屏蔽'
	String get enabled => '启用弹幕屏蔽';

	/// zh-CN: '关闭后所有屏蔽规则临时失效'
	String get enabledDescription => '关闭后所有屏蔽规则临时失效';

	/// zh-CN: '相似弹幕过滤'
	String get similarityTitle => '相似弹幕过滤';

	/// zh-CN: '启用相似弹幕过滤'
	String get similarityEnabled => '启用相似弹幕过滤';

	/// zh-CN: '自动过滤短时间内高度相似的弹幕，仅作用于平台消息。'
	String get similarityEnabledDescription => '自动过滤短时间内高度相似的弹幕，仅作用于平台消息。';

	/// zh-CN: '相似度阈值'
	String get similarityThreshold => '相似度阈值';

	/// zh-CN: '相似度越高，过滤越严格'
	String get similarityThresholdDescription => '相似度越高，过滤越严格';

	/// zh-CN: '缓存时间'
	String get similarityCacheDuration => '缓存时间';

	/// zh-CN: '相同或相似的弹幕在这段时间内不会重复显示'
	String get similarityCacheDurationDescription => '相同或相似的弹幕在这段时间内不会重复显示';

	/// zh-CN: '最大缓存数量'
	String get similarityMaxCacheSize => '最大缓存数量';

	/// zh-CN: '限制相似弹幕缓存占用的内存'
	String get similarityMaxCacheSizeDescription => '限制相似弹幕缓存占用的内存';

	/// zh-CN: '{seconds} 秒'
	String similaritySeconds({required Object seconds}) => '${seconds} 秒';

	/// zh-CN: '重复弹幕过滤'
	String get repeatTitle => '重复弹幕过滤';

	/// zh-CN: '合并短时间内的相同弹幕'
	String get repeatEnabled => '合并短时间内的相同弹幕';

	/// zh-CN: '不同用户发送相同内容时只保留第一条；本地弹幕和系统消息不受影响。'
	String get repeatEnabledDescription => '不同用户发送相同内容时只保留第一条；本地弹幕和系统消息不受影响。';

	/// zh-CN: '相同内容合并时间（秒）'
	String get repeatWindow => '相同内容合并时间（秒）';

	/// zh-CN: '关键词'
	String get keywordsTitle => '关键词';

	/// zh-CN: '用户'
	String get usersTitle => '用户';

	/// zh-CN: '输入要屏蔽的关键词'
	String get keywordFieldHint => '输入要屏蔽的关键词';

	/// zh-CN: '输入要屏蔽的用户名'
	String get userFieldHint => '输入要屏蔽的用户名';

	/// zh-CN: '添加'
	String get add => '添加';

	/// zh-CN: '还没有屏蔽关键词'
	String get keywordsEmpty => '还没有屏蔽关键词';

	/// zh-CN: '还没有屏蔽的用户'
	String get usersEmpty => '还没有屏蔽的用户';

	/// zh-CN: '清空全部'
	String get clear => '清空全部';

	/// zh-CN: '列表将被清空，需要时再重新添加。'
	String get clearConfirmDesc => '列表将被清空，需要时再重新添加。';

	/// zh-CN: '该条目已在屏蔽列表中'
	String get duplicateEntry => '该条目已在屏蔽列表中';

	/// zh-CN: '内容不能为空'
	String get invalidEntry => '内容不能为空';

	/// zh-CN: '已添加屏蔽'
	String get added => '已添加屏蔽';

	/// zh-CN: '已移除'
	String get removed => '已移除';

	/// zh-CN: '已清空'
	String get cleared => '已清空';

	/// zh-CN: '移除这条屏蔽规则'
	String get removeEntry => '移除这条屏蔽规则';

	/// zh-CN: '屏蔽在直播间弹幕中立即生效。'
	String get effectNote => '屏蔽在直播间弹幕中立即生效。';

	/// zh-CN: '内容屏蔽'
	String get contentTitle => '内容屏蔽';

	/// zh-CN: '屏蔽只有表情的弹幕'
	String get blockEmoteOnly => '屏蔽只有表情的弹幕';

	/// zh-CN: '只有表情、没有文字的弹幕不显示；自己发送的弹幕不会被屏蔽。'
	String get blockEmoteOnlyDescription => '只有表情、没有文字的弹幕不显示；自己发送的弹幕不会被屏蔽。';

	/// zh-CN: '屏蔽超长弹幕'
	String get blockLong => '屏蔽超长弹幕';

	/// zh-CN: '超过设定字数的弹幕不显示（一个表情算一个字）。'
	String get blockLongDescription => '超过设定字数的弹幕不显示（一个表情算一个字）。';

	/// zh-CN: '最多字数'
	String get blockLongLength => '最多字数';

	/// zh-CN: '允许显示的最大字数，范围 10–100（一个表情算一个字）。'
	String get blockLongLengthDescription => '允许显示的最大字数，范围 10–100（一个表情算一个字）。';

	/// zh-CN: '{count: int} 字'
	String blockLongLengthValue({required int count}) => '${count} 字';

	/// zh-CN: '过滤斗鱼疑似自动弹幕'
	String get douyuSuspected => '过滤斗鱼疑似自动弹幕';

	/// zh-CN: '开启后按启发式标记隐藏疑似自动或活动弹幕，也可能隐藏普通聊天'
	String get douyuSuspectedDescription => '开启后按启发式标记隐藏疑似自动或活动弹幕，也可能隐藏普通聊天';
}

// Path: sites
class Translations$sites$zh_CN {
	Translations$sites$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '站点'
	String get title => '站点';

	/// zh-CN: '直播'
	String get live => '直播';

	/// zh-CN: '搜索'
	String get search => '搜索';

	/// zh-CN: '房间'
	String get rooms => '房间';
}

// Path: toolbox
class Translations$toolbox$zh_CN {
	Translations$toolbox$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '工具箱'
	String get title => '工具箱';

	/// zh-CN: '链接工具'
	String get groupLinks => '链接工具';

	/// zh-CN: '网络'
	String get groupNetwork => '网络';

	/// zh-CN: '数据'
	String get groupData => '数据';

	/// zh-CN: '平台节点'
	String get toolNetworkTitle => '平台节点';

	/// zh-CN: '测试各平台接口的连通性与延迟。'
	String get toolNetworkDescription => '测试各平台接口的连通性与延迟。';

	/// zh-CN: '缓存清理'
	String get toolCacheTitle => '缓存清理';

	/// zh-CN: '查看并清理图片占用的内存缓存。'
	String get toolCacheDescription => '查看并清理图片占用的内存缓存。';

	/// zh-CN: '日志'
	String get toolLogsTitle => '日志';

	/// zh-CN: '查看应用运行日志与诊断信息。'
	String get toolLogsDescription => '查看应用运行日志与诊断信息。';

	/// zh-CN: '返回'
	String get back => '返回';

	/// zh-CN: '确认'
	String get confirm => '确认';

	/// zh-CN: '取消'
	String get cancel => '取消';

	/// zh-CN: '平台链接'
	String get linkFieldLabel => '平台链接';

	/// zh-CN: '粘贴直播间链接或分享文字'
	String get linkFieldHint => '粘贴直播间链接或分享文字';

	/// zh-CN: '打开直播间'
	String get linkOpen => '打开直播间';

	/// zh-CN: '复制房间链接'
	String get linkCopy => '复制房间链接';

	/// zh-CN: '粘贴'
	String get linkPaste => '粘贴';

	/// zh-CN: '清空'
	String get linkClear => '清空';

	/// zh-CN: '剪贴板'
	String get linkClipboardGroup => '剪贴板';

	/// zh-CN: '识别剪贴板直播间链接'
	String get linkClipboardRooms => '识别剪贴板直播间链接';

	/// zh-CN: '回应用时读取剪贴板，发现直播链接会询问是否打开；不自动跳转。'
	String get linkClipboardRoomsDesc => '回应用时读取剪贴板，发现直播链接会询问是否打开；不自动跳转。';

	/// zh-CN: '正在解析链接…'
	String get linkResolving => '正在解析链接…';

	/// zh-CN: '解析结果'
	String get linkResolvedTitle => '解析结果';

	/// zh-CN: '平台'
	String get linkPlatform => '平台';

	/// zh-CN: '房间号'
	String get linkRoom => '房间号';

	/// zh-CN: '请先粘贴链接'
	String get linkEmpty => '请先粘贴链接';

	/// zh-CN: '无法识别该链接，暂不支持此平台。'
	String get linkUnsupported => '无法识别该链接，暂不支持此平台。';

	/// zh-CN: '解析超时，请检查网络后重试。'
	String get linkTimeout => '解析超时，请检查网络后重试。';

	/// zh-CN: '解析失败，请稍后重试。'
	String get linkFailed => '解析失败，请稍后重试。';

	/// zh-CN: '已复制房间链接'
	String get linkCopyDone => '已复制房间链接';

	/// zh-CN: '复制失败'
	String get linkCopyFailed => '复制失败';

	/// zh-CN: '支持解析的平台'
	String get linkSupportTitle => '支持解析的平台';

	/// zh-CN: '以下平台的直播间链接可以直接解析并打开。'
	String get linkSupportHint => '以下平台的直播间链接可以直接解析并打开。';

	/// zh-CN: '选择平台'
	String get networkSiteLabel => '选择平台';

	/// zh-CN: '开始检测'
	String get networkRun => '开始检测';

	/// zh-CN: '检测结果'
	String get networkResultTitle => '检测结果';

	/// zh-CN: '探测接口'
	String get networkTarget => '探测接口';

	/// zh-CN: '推荐房间接口'
	String get networkTargetDesc => '推荐房间接口';

	/// zh-CN: '响应时间'
	String get networkLatency => '响应时间';

	/// zh-CN: '返回房间'
	String get networkRooms => '返回房间';

	/// zh-CN: '连接正常'
	String get networkSuccess => '连接正常';

	/// zh-CN: '连接失败'
	String get networkFailure => '连接失败';

	/// zh-CN: '正在检测…'
	String get networkBusy => '正在检测…';

	/// zh-CN: '该平台暂不支持探测。'
	String get networkUnsupported => '该平台暂不支持探测。';

	/// zh-CN: '图片缓存'
	String get cacheSection => '图片缓存';

	/// zh-CN: '缓存图片'
	String get cacheEntries => '缓存图片';

	/// zh-CN: '占用内存'
	String get cacheSize => '占用内存';

	/// zh-CN: '清理缓存'
	String get cacheClear => '清理缓存';

	/// zh-CN: '释放图片缓存占用的内存，不影响收藏与历史。'
	String get cacheClearDesc => '释放图片缓存占用的内存，不影响收藏与历史。';

	/// zh-CN: '清理图片缓存？'
	String get cacheConfirmTitle => '清理图片缓存？';

	/// zh-CN: '已加载的图片会重新下载，收藏与历史不受影响。'
	String get cacheConfirmDesc => '已加载的图片会重新下载，收藏与历史不受影响。';

	/// zh-CN: '缓存已清理'
	String get cacheDone => '缓存已清理';

	/// zh-CN: '暂无缓存'
	String get cacheEmpty => '暂无缓存';

	/// zh-CN: '即将推出'
	String get comingSoonTitle => '即将推出';

	/// zh-CN: '这个工具还没有完成，敬请期待。'
	String get comingSoonDesc => '这个工具还没有完成，敬请期待。';

	/// zh-CN: '获取直链'
	String get linkDirect => '获取直链';

	/// zh-CN: '直链地址'
	String get linkDirectTitle => '直链地址';

	/// zh-CN: '画质'
	String get linkDirectQuality => '画质';

	/// zh-CN: '播放地址'
	String get linkDirectLines => '播放地址';

	/// zh-CN: '复制'
	String get linkDirectCopy => '复制';

	/// zh-CN: '直链已复制'
	String get linkDirectCopyDone => '直链已复制';

	/// zh-CN: '这个房间暂时没有可用的直链'
	String get linkDirectEmpty => '这个房间暂时没有可用的直链';

	/// zh-CN: '直链读取失败'
	String get linkDirectFailed => '直链读取失败';

	/// zh-CN: '全部测速'
	String get nodeTestAll => '全部测速';

	/// zh-CN: '测速'
	String get nodeTest => '测速';

	/// zh-CN: '测速中'
	String get nodeTesting => '测速中';

	/// zh-CN: '未测速'
	String get nodeUntested => '未测速';

	/// zh-CN: '正常'
	String get nodeReachable => '正常';

	/// zh-CN: '失败'
	String get nodeFailed => '失败';

	/// zh-CN: '没有可测速的平台'
	String get nodeNoSites => '没有可测速的平台';

	/// zh-CN: '点「测速」检查这个平台。'
	String get nodeHint => '点「测速」检查这个平台。';

	/// zh-CN: '返回 {count: int} 个房间'
	String nodeAnswer({required int count}) => '返回 ${count} 个房间';

	/// zh-CN: '推荐接口'
	String get nodeSourceRecommended => '推荐接口';

	/// zh-CN: '热门接口'
	String get nodeSourceHot => '热门接口';

	/// zh-CN: '{ok} / {tested} 可用 · 共 {total} 个平台'
	String nodeSummary({required Object ok, required Object tested, required Object total}) => '${ok} / ${tested} 可用 · 共 ${total} 个平台';

	/// zh-CN: '尚未测速 · 共 {total} 个平台'
	String nodeUntestedSummary({required Object total}) => '尚未测速 · 共 ${total} 个平台';

	/// zh-CN: '日志与诊断'
	String get logsSection => '日志与诊断';

	/// zh-CN: '日志级别'
	String get logsLevel => '日志级别';

	/// zh-CN: '写入日志文件'
	String get logsFile => '写入日志文件';

	/// zh-CN: '在应用数据目录保存轮转日志 pure_live.log；关闭只留内存日志。'
	String get logsFileDesc => '在应用数据目录保存轮转日志 pure_live.log；关闭只留内存日志。';

	/// zh-CN: '复制日志'
	String get logsExport => '复制日志';

	/// zh-CN: '把内存中的日志复制到剪贴板。'
	String get logsExportDesc => '把内存中的日志复制到剪贴板。';

	/// zh-CN: '清空日志'
	String get logsClear => '清空日志';

	/// zh-CN: '只清除内存中的日志，已写入的文件保留。'
	String get logsClearDesc => '只清除内存中的日志，已写入的文件保留。';

	/// zh-CN: '清空内存日志？'
	String get logsClearConfirm => '清空内存日志？';

	/// zh-CN: '内存中的日志会被删除，日志文件不受影响。'
	String get logsClearConfirmDesc => '内存中的日志会被删除，日志文件不受影响。';

	/// zh-CN: '搜索日志…'
	String get logsSearch => '搜索日志…';

	/// zh-CN: '还没有日志'
	String get logsEmptyTitle => '还没有日志';

	/// zh-CN: '应用启动、网络请求与错误会记录在这里。'
	String get logsEmptyDescription => '应用启动、网络请求与错误会记录在这里。';

	/// zh-CN: '自动滚动已开启'
	String get logsAutoOn => '自动滚动已开启';

	/// zh-CN: '自动滚动已关闭（滚动到底部可开启）'
	String get logsAutoOff => '自动滚动已关闭（滚动到底部可开启）';

	/// zh-CN: '{count: int} 行'
	String logsLines({required int count}) => '${count} 行';

	/// zh-CN: '滚动到底部'
	String get logsScrollBottom => '滚动到底部';

	/// zh-CN: '日志已复制'
	String get logsCopied => '日志已复制';

	/// zh-CN: '没有可复制的日志'
	String get logsCopyEmpty => '没有可复制的日志';

	/// zh-CN: '日志文件尚未就绪。'
	String get logsDirectoryDefault => '日志文件尚未就绪。';

	/// zh-CN: '日志文件'
	String get logsFileTitle => '日志文件';

	/// zh-CN: '打开所在文件夹'
	String get logsOpenFolder => '打开所在文件夹';

	/// zh-CN: '复制路径'
	String get logsCopyPath => '复制路径';

	/// zh-CN: '路径已复制到剪贴板'
	String get logsPathCopied => '路径已复制到剪贴板';

	/// zh-CN: '无法打开日志目录'
	String get logsOpenFailed => '无法打开日志目录';
}

// Path: vod
class Translations$vod$zh_CN {
	Translations$vod$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '搜索 Bilibili 视频'
	String get searchHint => '搜索 Bilibili 视频';

	/// zh-CN: '搜索点播视频'
	String get idleTitle => '搜索点播视频';

	/// zh-CN: '输入关键词搜索 Bilibili 的视频。'
	String get idleDescription => '输入关键词搜索 Bilibili 的视频。';

	/// zh-CN: '没有找到视频'
	String get noResultsTitle => '没有找到视频';

	/// zh-CN: '换个关键词再试试。'
	String get noResultsDescription => '换个关键词再试试。';

	/// zh-CN: '视频没有加载出来'
	String get errorTitle => '视频没有加载出来';

	/// zh-CN: '重试'
	String get retry => '重试';

	/// zh-CN: '推荐'
	String get tabRecommend => '推荐';

	/// zh-CN: '热门'
	String get tabPopular => '热门';

	/// zh-CN: '动态'
	String get tabDynamics => '动态';

	/// zh-CN: '登录后查看动态'
	String get dynamicsLoginTitle => '登录后查看动态';

	/// zh-CN: '动态来自你关注的 UP 主，需要一个 Bilibili 登录。'
	String get dynamicsLoginDescription => '动态来自你关注的 UP 主，需要一个 Bilibili 登录。';

	/// zh-CN: '登录 Bilibili'
	String get signIn => '登录 Bilibili';

	/// zh-CN: '动态没有加载出来'
	String get dynamicsFailed => '动态没有加载出来';

	/// zh-CN: '还没有动态'
	String get dynamicsEmptyTitle => '还没有动态';

	/// zh-CN: '关注的 UP 主更新后会出现在这里。'
	String get dynamicsEmptyDescription => '关注的 UP 主更新后会出现在这里。';

	/// zh-CN: '加载更多'
	String get loadMore => '加载更多';

	/// zh-CN: '分区'
	String get regions => '分区';

	/// zh-CN: '搜索'
	String get search => '搜索';

	/// zh-CN: '主页'
	String get home => '主页';

	/// zh-CN: '个人'
	String get personal => '个人';

	/// zh-CN: '直播'
	String get live => '直播';

	/// zh-CN: '视频'
	String get searchKindVideo => '视频';

	/// zh-CN: '番剧'
	String get searchKindBangumi => '番剧';

	/// zh-CN: '影视'
	String get searchKindCinema => '影视';

	/// zh-CN: '用户'
	String get searchKindUser => '用户';

	/// zh-CN: '直播间'
	String get searchKindLiveRoom => '直播间';

	/// zh-CN: '直播中'
	String get living => '直播中';

	/// zh-CN: '粉丝'
	String get fans => '粉丝';

	/// zh-CN: '视频'
	String get videoCount => '视频';

	/// zh-CN: '我的关注'
	String get liveFollowTitle => '我的关注';

	/// zh-CN: '推荐分区'
	String get liveAreasTitle => '推荐分区';

	/// zh-CN: '推荐直播'
	String get liveRecommendTitle => '推荐直播';

	/// zh-CN: '没有推荐的直播'
	String get liveEmptyTitle => '没有推荐的直播';

	/// zh-CN: '稍后刷新再看看。'
	String get liveEmptyDescription => '稍后刷新再看看。';

	/// zh-CN: '刷新'
	String get refresh => '刷新';

	/// zh-CN: '这个分区暂时没有推荐视频。'
	String get regionEmptyDescription => '这个分区暂时没有推荐视频。';

	/// zh-CN: '影视'
	String get pgcTitle => '影视';

	/// zh-CN: '番剧'
	String get pgcAnime => '番剧';

	/// zh-CN: '电影'
	String get pgcMovie => '电影';

	/// zh-CN: '纪录片'
	String get pgcDocumentary => '纪录片';

	/// zh-CN: '国创'
	String get pgcGuochuang => '国创';

	/// zh-CN: '电视剧'
	String get pgcTv => '电视剧';

	/// zh-CN: '综艺'
	String get pgcVariety => '综艺';

	/// zh-CN: '这个分类暂时没有内容。'
	String get pgcEmptyDescription => '这个分类暂时没有内容。';

	/// zh-CN: '选集'
	String get episodes => '选集';

	/// zh-CN: '已追'
	String get following => '已追';

	/// zh-CN: '仅画面'
	String get pictureOnly => '仅画面';

	/// zh-CN: '排序'
	String get sort => '排序';

	/// zh-CN: '综合'
	String get sortTotalrank => '综合';

	/// zh-CN: '播放多'
	String get sortClick => '播放多';

	/// zh-CN: '最新'
	String get sortPubdate => '最新';

	/// zh-CN: '弹幕多'
	String get sortDm => '弹幕多';

	/// zh-CN: '收藏多'
	String get sortStow => '收藏多';

	/// zh-CN: '时长'
	String get duration => '时长';

	/// zh-CN: '全部时长'
	String get durationAny => '全部时长';

	/// zh-CN: '10 分钟以下'
	String get durationUnder10 => '10 分钟以下';

	/// zh-CN: '10–30 分钟'
	String get duration10to30 => '10–30 分钟';

	/// zh-CN: '30–60 分钟'
	String get duration30to60 => '30–60 分钟';

	/// zh-CN: '60 分钟以上'
	String get durationOver60 => '60 分钟以上';

	/// zh-CN: '相关推荐'
	String get related => '相关推荐';

	/// zh-CN: '换一换'
	String get changeRelated => '换一换';

	/// zh-CN: '展开'
	String get expand => '展开';

	/// zh-CN: '收起'
	String get collapse => '收起';

	/// zh-CN: '分P'
	String get parts => '分P';

	/// zh-CN: '播放'
	String get views => '播放';

	/// zh-CN: '显示弹幕'
	String get danmakuOn => '显示弹幕';

	/// zh-CN: '隐藏弹幕'
	String get danmakuOff => '隐藏弹幕';

	/// zh-CN: '弹幕'
	String get danmaku => '弹幕';

	/// zh-CN: '点赞'
	String get likes => '点赞';

	/// zh-CN: '投币'
	String get coins => '投币';

	/// zh-CN: '收藏'
	String get favorites => '收藏';

	/// zh-CN: '简介'
	String get description => '简介';

	/// zh-CN: '这个视频没有简介。'
	String get noDescription => '这个视频没有简介。';

	/// zh-CN: '播放'
	String get play => '播放';

	/// zh-CN: '暂停'
	String get pause => '暂停';

	/// zh-CN: '静音'
	String get mute => '静音';

	/// zh-CN: '取消静音'
	String get unmute => '取消静音';

	/// zh-CN: '音量'
	String get volume => '音量';

	/// zh-CN: '清晰度'
	String get quality => '清晰度';

	/// zh-CN: '倍速'
	String get speed => '倍速';

	/// zh-CN: '全屏'
	String get fullscreen => '全屏';

	/// zh-CN: '退出全屏'
	String get exitFullscreen => '退出全屏';

	/// zh-CN: '小窗播放'
	String get pip => '小窗播放';

	/// zh-CN: '退出小窗'
	String get exitPip => '退出小窗';

	/// zh-CN: '这个清晰度只有画面，没有声音；换一个清晰度试试。'
	String get silentNotice => '这个清晰度只有画面，没有声音；换一个清晰度试试。';

	/// zh-CN: '正在打开视频…'
	String get opening => '正在打开视频…';

	/// zh-CN: '视频信息加载失败'
	String get loadFailed => '视频信息加载失败';

	/// zh-CN: '视频打开失败'
	String get openFailed => '视频打开失败';

	/// zh-CN: '播放进度'
	String get progress => '播放进度';

	/// zh-CN: 'UP主'
	String get up => 'UP主';

	/// zh-CN: '默认倍速'
	String get openingSpeed => '默认倍速';

	/// zh-CN: '打开视频时使用的播放速度；播放器里的倍速菜单只影响当前视频。'
	String get openingSpeedDesc => '打开视频时使用的播放速度；播放器里的倍速菜单只影响当前视频。';

	/// zh-CN: '播放结束动作'
	String get finishAction => '播放结束动作';

	/// zh-CN: '一集播完之后做什么。'
	String get finishActionDesc => '一集播完之后做什么。';

	/// zh-CN: '停在最后一帧'
	String get finishPause => '停在最后一帧';

	/// zh-CN: '播放下一分P'
	String get finishNextPart => '播放下一分P';

	/// zh-CN: '退出播放'
	String get finishExit => '退出播放';

	/// zh-CN: '播放相关推荐'
	String get finishRelated => '播放相关推荐';

	/// zh-CN: '显示视频详情'
	String get showDetails => '显示视频详情';

	/// zh-CN: '关闭后只看播放器、分P和相关推荐，隐藏UP主、数据和简介。'
	String get showDetailsDesc => '关闭后只看播放器、分P和相关推荐，隐藏UP主、数据和简介。';

	/// zh-CN: '恢复默认播放行为'
	String get playbackReset => '恢复默认播放行为';

	/// zh-CN: '默认倍速、播完下一分P、显示详情。'
	String get playbackResetDesc => '默认倍速、播完下一分P、显示详情。';

	/// zh-CN: '我的视频'
	String get personalTitle => '我的视频';

	/// zh-CN: '稍后再看'
	String get personalToView => '稍后再看';

	/// zh-CN: '历史'
	String get personalHistory => '历史';

	/// zh-CN: '收藏'
	String get personalFavourites => '收藏';

	/// zh-CN: '追番'
	String get personalFollowing => '追番';

	/// zh-CN: '番剧'
	String get followingBangumi => '番剧';

	/// zh-CN: '影视'
	String get followingCinema => '影视';

	/// zh-CN: '共 {count} 个'
	String personalCount({required Object count}) => '共 ${count} 个';

	/// zh-CN: '登录后可见'
	String get signInNeededTitle => '登录后可见';

	/// zh-CN: '这个列表在你登录的 Bilibili 账号上。'
	String get signInNeededDescription => '这个列表在你登录的 Bilibili 账号上。';

	/// zh-CN: '稍后再看是空的'
	String get toViewEmptyTitle => '稍后再看是空的';

	/// zh-CN: '在 Bilibili 上标记「稍后再看」的视频会出现在这里。'
	String get toViewEmptyDescription => '在 Bilibili 上标记「稍后再看」的视频会出现在这里。';

	/// zh-CN: '还没有追番'
	String get followingEmptyTitle => '还没有追番';

	/// zh-CN: '在 Bilibili 上追的番剧和影视会出现在这里。'
	String get followingEmptyDescription => '在 Bilibili 上追的番剧和影视会出现在这里。';

	/// zh-CN: '评论'
	String get comments => '评论';

	/// zh-CN: '最热'
	String get commentsHot => '最热';

	/// zh-CN: '最新'
	String get commentsNew => '最新';

	/// zh-CN: '还没有评论。'
	String get commentsEmpty => '还没有评论。';

	/// zh-CN: '评论没有加载出来'
	String get commentsFailed => '评论没有加载出来';

	/// zh-CN: '还没有观看记录'
	String get historyEmptyTitle => '还没有观看记录';

	/// zh-CN: '看过的视频会出现在这里，并保留上次的播放位置。'
	String get historyEmptyDescription => '看过的视频会出现在这里，并保留上次的播放位置。';

	/// zh-CN: '已看完'
	String get historyCompleted => '已看完';

	/// zh-CN: '{position} / {total}'
	String historyProgress({required Object position, required Object total}) => '${position} / ${total}';

	/// zh-CN: '从历史中移除'
	String get historyRemove => '从历史中移除';

	/// zh-CN: '清空历史'
	String get clearHistory => '清空历史';

	/// zh-CN: '清空观看历史？'
	String get clearHistoryTitle => '清空观看历史？';

	/// zh-CN: '只删除本机的观看记录，不影响 Bilibili 上的进度。'
	String get clearHistoryDesc => '只删除本机的观看记录，不影响 Bilibili 上的进度。';

	/// zh-CN: '还没有收藏的视频'
	String get favouritesEmptyTitle => '还没有收藏的视频';

	/// zh-CN: '在视频页点收藏，视频会出现在这里。'
	String get favouritesEmptyDescription => '在视频页点收藏，视频会出现在这里。';

	/// zh-CN: '取消收藏'
	String get favouriteRemove => '取消收藏';

	/// zh-CN: '收藏'
	String get saveVideo => '收藏';

	/// zh-CN: '已收藏'
	String get savedVideo => '已收藏';

	/// zh-CN: '已加入收藏'
	String get saveAdded => '已加入收藏';

	/// zh-CN: '已取消收藏'
	String get saveRemoved => '已取消收藏';

	/// zh-CN: '下载视频'
	String get download => '下载视频';

	/// zh-CN: '下载中 {percent: int}%'
	String downloading({required int percent}) => '下载中 ${percent}%';

	/// zh-CN: '下载中…'
	String get downloadingUnknown => '下载中…';

	/// zh-CN: '已下载到 {name: String}'
	String downloadDone({required String name}) => '已下载到 ${name}';

	/// zh-CN: '下载失败'
	String get downloadFailed => '下载失败';

	/// zh-CN: '已取消下载'
	String get downloadCancelled => '已取消下载';

	/// zh-CN: '取消下载'
	String get downloadCancel => '取消下载';
}

// Path: wallpaper
class Translations$wallpaper$zh_CN {
	Translations$wallpaper$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '随机图源'
	String get title => '随机图源';

	/// zh-CN: '按分组从公开随机接口取图，预览后再应用。'
	String get description => '按分组从公开随机接口取图，预览后再应用。';

	/// zh-CN: '{count} 个来源'
	String sourceCount({required Object count}) => '${count} 个来源';

	/// zh-CN: '换一张'
	String get another => '换一张';

	/// zh-CN: '正在取图…'
	String get fetching => '正在取图…';

	/// zh-CN: '这张图没有取到'
	String get fetchFailed => '这张图没有取到';

	/// zh-CN: '图源返回了无法显示的图片格式'
	String get unsupported => '图源返回了无法显示的图片格式';

	/// zh-CN: '显示设置'
	String get previewDisplay => '显示设置';

	/// zh-CN: '应用后壁纸仍静音循环；这里的播放、暂停与声音只用于预览。'
	String get previewVideoNote => '应用后壁纸仍静音循环；这里的播放、暂停与声音只用于预览。';

	/// zh-CN: '随机图片预览'
	String get previewTitle => '随机图片预览';

	/// zh-CN: '已应用为背景'
	String get applied => '已应用为背景';

	/// zh-CN: '来源'
	String get sourceLabel => '来源';

	/// zh-CN: '重试'
	String get retry => '重试';

	/// zh-CN: '必应壁纸'
	String get groupBing => '必应壁纸';

	/// zh-CN: '必应随机Biturl'
	String get sourceBingBiturl => '必应随机Biturl';

	/// zh-CN: '必应随机Jason Zeng'
	String get sourceBingJasonZeng => '必应随机Jason Zeng';

	/// zh-CN: '必应随机UAPI'
	String get sourceBingUapi => '必应随机UAPI';

	/// zh-CN: '必应随机YingJoy'
	String get sourceBingYingJoy => '必应随机YingJoy';

	/// zh-CN: '必应W3H5'
	String get sourceBingW3h5 => '必应W3H5';

	/// zh-CN: '无铭必应每日壁纸'
	String get sourceBingWumingDaily => '无铭必应每日壁纸';

	/// zh-CN: '栗次元'
	String get groupAlcy => '栗次元';

	/// zh-CN: '栗次元 · 随机'
	String get sourceAlcyRandom => '栗次元 · 随机';

	/// zh-CN: '栗次元 · ycy'
	String get sourceAlcyYcy => '栗次元 · ycy';

	/// zh-CN: '栗次元 · moez'
	String get sourceAlcyMoez => '栗次元 · moez';

	/// zh-CN: '栗次元 · ysz'
	String get sourceAlcyYsz => '栗次元 · ysz';

	/// zh-CN: '栗次元 · ys'
	String get sourceAlcyYs => '栗次元 · ys';

	/// zh-CN: '栗次元 · mp'
	String get sourceAlcyMp => '栗次元 · mp';

	/// zh-CN: '栗次元 · moemp'
	String get sourceAlcyMoemp => '栗次元 · moemp';

	/// zh-CN: '栗次元 · ysmp'
	String get sourceAlcyYsmp => '栗次元 · ysmp';

	/// zh-CN: '栗次元 · tx'
	String get sourceAlcyTx => '栗次元 · tx';

	/// zh-CN: '栗次元 · lai'
	String get sourceAlcyLai => '栗次元 · lai';

	/// zh-CN: '栗次元 · xhl'
	String get sourceAlcyXhl => '栗次元 · xhl';

	/// zh-CN: '栗次元 · bd'
	String get sourceAlcyBd => '栗次元 · bd';

	/// zh-CN: '无铭 API'
	String get groupWuming => '无铭 API';

	/// zh-CN: '无铭随机美囡图片'
	String get sourceWumingGirl => '无铭随机美囡图片';

	/// zh-CN: '无铭随机黑丝图片'
	String get sourceWumingBlackStocking => '无铭随机黑丝图片';

	/// zh-CN: '抖音美女·无铭API'
	String get sourceWumingDouyinGirl => '抖音美女·无铭API';

	/// zh-CN: '无铭随机白丝图片'
	String get sourceWumingWhiteStocking => '无铭随机白丝图片';

	/// zh-CN: '无铭随机抖音美女图片'
	String get sourceWumingDouyinGirlAlt => '无铭随机抖音美女图片';

	/// zh-CN: '无铭半次元cosplay'
	String get sourceWumingBcyCos => '无铭半次元cosplay';

	/// zh-CN: '无铭动漫壁纸'
	String get sourceWumingAnimeWallpaper => '无铭动漫壁纸';

	/// zh-CN: '无铭随机唯美女生图片'
	String get sourceWumingAestheticGirl => '无铭随机唯美女生图片';

	/// zh-CN: 'UAPI 随机图'
	String get groupUapi => 'UAPI 随机图';

	/// zh-CN: 'UAPI全部随机'
	String get sourceUapiAll => 'UAPI全部随机';

	/// zh-CN: 'UAPI二次元动漫'
	String get sourceUapiAcg => 'UAPI二次元动漫';

	/// zh-CN: 'UAPI二次元·电脑'
	String get sourceUapiAcgPc => 'UAPI二次元·电脑';

	/// zh-CN: 'UAPI二次元·手机'
	String get sourceUapiAcgMobile => 'UAPI二次元·手机';

	/// zh-CN: 'UAPI风景图'
	String get sourceUapiLandscape => 'UAPI风景图';

	/// zh-CN: 'UAPI混合动漫'
	String get sourceUapiAnime => 'UAPI混合动漫';

	/// zh-CN: 'UAPI电脑壁纸'
	String get sourceUapiPcWallpaper => 'UAPI电脑壁纸';

	/// zh-CN: 'UAPI手机壁纸'
	String get sourceUapiMobileWallpaper => 'UAPI手机壁纸';

	/// zh-CN: 'UAPI动漫图'
	String get sourceUapiGeneralAnime => 'UAPI动漫图';

	/// zh-CN: 'UAPI福瑞'
	String get sourceUapiFurry => 'UAPI福瑞';

	/// zh-CN: 'UAPI福瑞·z4k'
	String get sourceUapiFurryZ4k => 'UAPI福瑞·z4k';

	/// zh-CN: 'UAPI福瑞·szs8k'
	String get sourceUapiFurrySzs8k => 'UAPI福瑞·szs8k';

	/// zh-CN: 'UAPI福瑞·s4k'
	String get sourceUapiFurryS4k => 'UAPI福瑞·s4k';

	/// zh-CN: 'UAPI福瑞·4k'
	String get sourceUapiFurry4k => 'UAPI福瑞·4k';

	/// zh-CN: '360壁纸'
	String get group360 => '360壁纸';

	/// zh-CN: '360壁纸美女'
	String get source360Beauty => '360壁纸美女';

	/// zh-CN: '360壁纸风景'
	String get source360Landscape => '360壁纸风景';

	/// zh-CN: '360壁纸游戏'
	String get source360Game => '360壁纸游戏';

	/// zh-CN: '360壁纸影视'
	String get source360Movie => '360壁纸影视';

	/// zh-CN: '360壁纸时尚'
	String get source360Fashion => '360壁纸时尚';

	/// zh-CN: '360壁纸明星'
	String get source360Star => '360壁纸明星';

	/// zh-CN: '360壁纸汽车'
	String get source360Car => '360壁纸汽车';

	/// zh-CN: '360壁纸萌宠'
	String get source360Pet => '360壁纸萌宠';

	/// zh-CN: '360壁纸清新'
	String get source360Fresh => '360壁纸清新';

	/// zh-CN: '360壁纸体育'
	String get source360Sport => '360壁纸体育';

	/// zh-CN: '360壁纸萌娃'
	String get source360Child => '360壁纸萌娃';

	/// zh-CN: '360壁纸军事'
	String get source360Military => '360壁纸军事';

	/// zh-CN: '360壁纸动漫'
	String get source360Anime => '360壁纸动漫';

	/// zh-CN: '360壁纸日历'
	String get source360Calendar => '360壁纸日历';

	/// zh-CN: '360壁纸爱情'
	String get source360Love => '360壁纸爱情';

	/// zh-CN: '360壁纸格言'
	String get source360Motto => '360壁纸格言';

	/// zh-CN: '其他图源'
	String get groupMisc => '其他图源';

	/// zh-CN: '小晓API'
	String get sourceXxapi => '小晓API';

	/// zh-CN: 'mtyqx'
	String get sourceMtyqx => 'mtyqx';

	/// zh-CN: 'picsum'
	String get sourcePicsum => 'picsum';

	/// zh-CN: 'dmoe'
	String get sourceDmoe => 'dmoe';

	/// zh-CN: 'loliApi'
	String get sourceLoliapi => 'loliApi';

	/// zh-CN: 'catvod'
	String get sourceCatvod => 'catvod';

	/// zh-CN: '性感美女'
	String get groupSexy => '性感美女';

	/// zh-CN: '随机黑丝·小小API'
	String get sourceSexyBlackStockingXxapi => '随机黑丝·小小API';

	/// zh-CN: '随机白丝·小小API'
	String get sourceSexyWhiteStockingXxapi => '随机白丝·小小API';

	/// zh-CN: '随机JK·小小API'
	String get sourceSexyJkXxapi => '随机JK·小小API';

	/// zh-CN: '随机小姐姐·素颜API'
	String get sourceSexyGirlSuyan => '随机小姐姐·素颜API';

	/// zh-CN: '随机美女·素颜API'
	String get sourceSexyBeautySuyan => '随机美女·素颜API';

	/// zh-CN: '随机妹子·素颜API'
	String get sourceSexyMeiziSuyan => '随机妹子·素颜API';

	/// zh-CN: '随机黑丝·素颜API'
	String get sourceSexyBlackStockingSuyan => '随机黑丝·素颜API';

	/// zh-CN: '随机妹子·小渡API'
	String get sourceSexyMeiziXiaodu => '随机妹子·小渡API';

	/// zh-CN: '随机丝袜·Nonebot'
	String get sourceSexyStockingNonebot => '随机丝袜·Nonebot';

	/// zh-CN: 'PC美女壁纸·Ltywl'
	String get sourceSexyPcLtywl => 'PC美女壁纸·Ltywl';

	/// zh-CN: 'PE美女壁纸·Ltywl'
	String get sourceSexyPeLtywl => 'PE美女壁纸·Ltywl';

	/// zh-CN: '美女壁纸·极数本源'
	String get sourceSexyBeautyApizero => '美女壁纸·极数本源';

	/// zh-CN: '电脑端小姐姐·Nsuuu'
	String get sourceSexyPcNsuuu => '电脑端小姐姐·Nsuuu';

	/// zh-CN: '随机白丝·Nsuuu'
	String get sourceSexyWhiteStockingNsuuu => '随机白丝·Nsuuu';

	/// zh-CN: '随机美女·搏天API'
	String get sourceSexyBeautyBtstu => '随机美女·搏天API';

	/// zh-CN: '随机二次元·搏天API'
	String get sourceSexyAnimeBtstu => '随机二次元·搏天API';

	/// zh-CN: '随机小姐姐·快手'
	String get sourceSexyGirlKuaishou => '随机小姐姐·快手';

	/// zh-CN: '随机Cos·Nonebot'
	String get sourceSexyCosNonebot => '随机Cos·Nonebot';

	/// zh-CN: '随机美女·CZL'
	String get sourceSexyBeautyCzl => '随机美女·CZL';

	/// zh-CN: '随机美女·Mioical'
	String get sourceSexyBeautyMioical => '随机美女·Mioical';
}

/// The flat map containing all translations for locale <zh-CN>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on Translations {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'account.title' => '账号',
			'account.description' => '各直播平台的登录状态，凭证只保存在本机安全存储中。',
			'account.sectionHeader' => '登录状态',
			'account.thirdPartyAuth' => '三方认证',
			'account.thirdPartyAuthDesc' => '管理主流平台的绑定授权',
			'account.empty' => '暂无支持登录的平台',
			'account.notSignedIn' => '未登录',
			'account.signedInAs' => ({required Object name}) => '已登录：${name}',
			'account.qrLogin' => '扫码登录',
			'account.cookieLogin' => '导入 Cookie',
			'account.signOut' => '退出登录',
			'account.qrDialogTitle' => ({required Object site}) => '${site} 扫码登录',
			'account.qrHint' => ({required Object site}) => '打开${site}的手机客户端，扫描二维码并确认登录。',
			'account.qrExpired' => '二维码已过期',
			'account.qrRetry' => '重新获取',
			'account.qrPollingFailed' => '连接失败，正在重试…',
			'account.cookieDialogTitle' => ({required Object site}) => '${site} 导入 Cookie',
			'account.cookieDialogHint' => '在已登录的浏览器复制 Cookie 粘贴进来（形如 name=value; name2=value2）。',
			'account.cookieFieldHint' => '粘贴 Cookie 内容',
			'account.loginSuccess' => '登录成功',
			'account.loginFailed' => ({required Object message}) => '登录失败：${message}',
			'account.signOutConfirmDesc' => ({required Object site}) => '将清除本机保存的${site}登录凭证。',
			'account.signOutSuccess' => '已退出登录',
			'account.signOutFailed' => '退出登录失败',
			'account.groupDomestic' => '国内平台',
			'account.groupOverseas' => '海外平台',
			'account.statusNone' => '未设置',
			'account.statusUnreadable' => '无法读取，请重新粘贴 Cookie',
			'account.verifying' => '正在核验…',
			'account.statusRejected' => '登录已失效，请重新登录或更换 Cookie',
			'account.statusCheckFailed' => '已保存，暂时无法核验账号',
			'account.statusSaved' => '已保存',
			'account.statusStoredUnused' => '已保存，暂未用于请求',
			'account.statusDouyuNoSession' => '未设置：Cookie 中没有会话令牌',
			'account.statusDouyuExpired' => '登录已过期，请重新粘贴 Cookie',
			'account.statusDouyuUntil' => ({required Object time}) => '预计 ${time} 到期',
			'account.statusDouyuAutoRenew' => '登录有效，到期前自动续期',
			'account.statusDouyuRenewsOnPlay' => '登录态已过期，播放时自动续期',
			'account.statusDouyuRepaste' => '登录态已失效，点按重新粘贴 Cookie',
			'account.douyuCookieCleared' => '已清除：没有保存斗鱼登录',
			'account.douyuCookieGuest' => '游客：Cookie 中没有会话令牌，点按重新粘贴',
			'account.douyuPairOnly' => '已保存续期凭据，还没有登录 Cookie',
			'account.douyuCookieValidNoExpiry' => '登录有效',
			'account.douyuCookieValidAutoRenew' => ({required Object time}) => '登录有效，凭 LTP0 到期前自动续期（预计 ${time}）',
			'account.douyuCookieValidRepaste' => ({required Object time}) => '登录有效（预计 ${time}），但未保存续期凭据',
			'account.douyuCookieRenewable' => ({required Object time}) => '登录已过期，可在播放时自动续期（凭据到期于 ${time}）',
			'account.douyuCookieExpired' => ({required Object time}) => '登录已失效（${time}），请重新粘贴 Cookie',
			'account.douyuRenewalTitle' => '续期凭据',
			'account.douyuLtp0Label' => 'LTP0（长期密钥）',
			'account.douyuLtp0Hint' => '粘贴 passport.douyu.com 请求里的 LTP0',
			'account.douyuDidLabel' => 'dy_did（设备号）',
			'account.douyuDidHint' => '登录所属设备的 dy_did',
			'account.douyuRenewNow' => '立即续期',
			'account.douyuRenewNowDesc' => '用当前凭据立刻换一次会话，验证续期是否可用，无需等到临近到期。',
			'account.douyuCredentialsAbsorbed' => '已抽出续期凭据，保留原有登录',
			'account.douyuCredentialsOnly' => '已保存续期凭据（斗鱼登录 Cookie 仍需单独粘贴）',
			'account.douyuRenewNoCookie' => '请先填写带登录的 Cookie 再续期',
			'account.douyuRenewNoCredentials' => '缺少 LTP0 或 dy_did，无法续期',
			'account.douyuRenewNoSession' => '这段 Cookie 里没有会话令牌，无法续期',
			'account.douyuRenewNoChange' => '续期未返回新会话，登录保持不变',
			'account.douyuRenewOk' => ({required Object time}) => '已续期，预计 ${time} 到期',
			'account.douyuRenewFailed' => '续期失败，请稍后再试',
			'account.statusTwitchChat' => ({required Object login}) => '聊天身份：${login}',
			'account.statusTwitchNoChat' => '已保存，但 Cookie 里没有聊天身份',
			'account.statusHuyaUid' => ({required Object uid}) => '账号 ID：${uid}',
			'account.statusHuyaNoUid' => '已保存，但 Cookie 里没有账号 ID',
			'account.bilibiliLoginExpired' => 'B 站登录已失效，已自动退出登录',
			'account.savedAccounts' => '已记住的账号',
			'account.savedAccountsNote' => ({required Object count}) => '最多记住 ${count} 个账号，切换不用重新扫码；只加密存在本机，退出或删除即清除。',
			'account.accountUid' => ({required Object uid}) => 'UID ${uid}',
			'account.accountCurrent' => '当前账号',
			'account.addAccount' => '添加账号',
			'account.addAccountHint' => '扫码登录另一个账号，现在的账号会留在这里',
			'account.addAccountFull' => ({required Object count}) => '已记住 ${count} 个，再添加会删掉最久没用的那个',
			'account.addFullConfirmDesc' => ({required Object count}) => '已记住 ${count} 个账号，再登录一个会删掉最久没用的那个。继续？',
			'account.switchAccount' => '切换',
			'account.switchTitle' => '切换账号',
			'account.switchConfirmDesc' => ({required Object name}) => '切换到“${name}”？正在看的直播间会用这个账号重新连接弹幕。',
			'account.switchedSuccess' => ({required Object name}) => '已切换到“${name}”',
			'account.forgetAccount' => '删除这个账号',
			'account.forgetTitle' => '删除账号',
			'account.forgetConfirmDesc' => ({required Object name}) => '从本机删除“${name}”的登录信息？以后要用这个账号需要重新登录。',
			'account.forgottenSuccess' => ({required Object name}) => '已删除“${name}”',
			'account.accountsSaveFailed' => '登录信息没能保存：这台设备的加密存储出错，请重试',
			'account.qrCannotScan' => '扫不了？',
			'account.webLogin' => '网页登录（短信、密码）',
			'account.pasteCookieEntry' => '填写 Cookie',
			'account.webLoginTitle' => '哔哩哔哩 网页登录',
			'account.webLoginSignInOnPage' => '在页面里登录（短信或密码）',
			'account.webLoginReading' => '已回到主站，正在读取登录状态…',
			'account.webLoginFailed' => '网页登录未成功',
			'account.webLoginUnavailable' => '这台设备没有可用的内置浏览器',
			'account.webLoginUnavailableDesc' => '需要内置浏览器；请改用扫码登录，或在其他浏览器登录后粘贴 Cookie。',
			'account.noLoginMethod' => ({required Object site}) => '${site} 暂未接入登录方式',
			'account.cookiePageTitle' => ({required Object site}) => '${site} Cookie',
			'account.cookieSection' => 'Cookie',
			'account.cookieHowToTitle' => '如何获取 Cookie',
			'account.openSiteWebsite' => ({required Object site}) => '打开 ${site} 官网',
			'account.browserNotOpened' => '没有打开系统浏览器',
			'account.paste' => '粘贴',
			'account.clearInput' => '清空',
			'account.recheck' => '重新核验',
			'account.cookieInvalid' => '粘贴的内容不像 Cookie，需要 name=value 的形式',
			'account.cookieRejected' => '这段 Cookie 没有登录或已失效，未保存',
			'account.cookieSavedLocal' => 'Cookie 已保存在本机',
			'account.cookieSavedAs' => ({required Object name}) => '已保存，登录为 ${name}',
			'account.clipboardEmpty' => '剪贴板是空的',
			'account.discardTitle' => '舍弃 Cookie 修改？',
			'account.discardDesc' => '这些修改还没有保存，离开后会丢失。',
			'account.discard' => '舍弃',
			'account.keepEditing' => '继续编辑',
			'account.cookiePrivacy' => 'Cookie 只加密保存在本机，不会上传；在公用设备上请在离开前退出登录。',
			'account.cookieSaveShortcut' => '保存：Ctrl + S（macOS 为 ⌘ + S）',
			'areas.allAreas' => '全部分区',
			'areas.noAreas' => '该平台没有分区',
			'areas.viewPlatform' => '平台分区',
			'areas.viewFollowed' => '关注分区',
			'areas.followedEmpty' => '还没有关注的分区',
			'areas.followedEmptyHint' => '在分区卡片上右键或长按，选择关注即可',
			'areas.noPlatforms' => '没有可浏览的平台',
			'areas.unfollow' => '取消关注',
			'areas.categoryAll' => '全部分类',
			'areas.iconTop' => '图标在上',
			'areas.iconLeft' => '图标在左',
			'areas.open' => '进入分区',
			'areas.follow' => '关注分区',
			'areas.searchHint' => '搜索分区',
			'areas.search' => '搜索',
			'areas.searchAt' => ({required Object platform, required Object query}) => '在 ${platform} 中搜索分区“${query}”',
			'areas.searchEmpty' => '没有匹配的分区',
			'areas.backToBrowse' => '返回浏览',
			'areas.hiddenUnplayable' => ({required int count}) => '已隐藏 ${count} 个不能播放的直播（付费、加密、仅限 App 等）',
			'backup.title' => '备份与恢复',
			'backup.localSection' => '本地备份',
			'backup.summaryTitle' => '当前数据',
			'backup.summaryEmpty' => '还没有可备份的数据',
			'backup.exportTitle' => '导出备份',
			'backup.exportDescription' => '把关注、历史、分区与设置打包为 JSON，经系统分享保存。',
			'backup.exportEmpty' => '没有可备份的数据',
			'backup.exportDone' => '备份文件已生成',
			'backup.exportFailed' => '导出失败',
			'backup.importTitle' => '导入备份',
			'backup.importDescription' => '粘贴备份 JSON，确认后覆盖当前数据；也可从 WebDAV 恢复。',
			'backup.importHint' => '粘贴备份 JSON',
			'backup.importFileNote' => '直接选择本地文件要等文件选择器依赖接入；目前可粘贴内容或走 WebDAV。',
			'backup.importConfirmTitle' => '覆盖当前数据？',
			'backup.importConfirmDesc' => '导入会先清空再写入关注、观看历史、关注分区与设置，当前数据无法找回。',
			'backup.importDone' => '恢复完成，重启应用后全部生效',
			'backup.importBadData' => '这不是有效的备份内容',
			'backup.importFailed' => '导入失败',
			'backup.summary' => ({required Object follows, required Object history, required Object areas, required Object settings}) => '关注 ${follows} · 历史 ${history} · 分区 ${areas} · 设置 ${settings} 项',
			'backup.webdavSection' => 'WebDAV 同步',
			'backup.webdavAccounts' => 'WebDAV 账号',
			'backup.webdavAccountsHint' => '点选即切换并打开它的文件夹；铅笔可修改或删除。',
			'backup.webdavAddAccount' => '添加账号',
			'backup.webdavEditAccount' => '编辑账号',
			'backup.webdavAccountName' => '账号名称',
			'backup.webdavAccountNameHint' => '留空则使用服务器主机名',
			'backup.webdavCurrent' => '当前',
			'backup.webdavNoAccounts' => '还没有 WebDAV 账号',
			'backup.webdavNoAccountsDesc' => '添加一个服务器后才能上传备份或从这里恢复。',
			'backup.webdavAccountDeleteTitle' => ({required Object name}) => '删除“${name}”账号？',
			'backup.webdavAccountDeleteDesc' => '只删除本机保存的地址与密码，服务器上的文件不受影响。',
			'backup.webdavAccountDeleted' => '账号已删除',
			'backup.webdavRefresh' => '刷新',
			'backup.webdavRoot' => '根目录',
			'backup.webdavNewFolder' => '新建文件夹',
			'backup.webdavNewFolderName' => '文件夹名称',
			'backup.webdavFolderCreated' => '文件夹已创建',
			'backup.webdavEnterFolder' => '打开文件夹',
			'backup.webdavDeleteFolderDesc' => '删除服务器上的这个文件夹及其中的全部内容。',
			'backup.webdavTestDesc' => '确认地址与密码可用，不传输任何数据。',
			'backup.webdavUploadDesc' => '把本机数据写成备份文件上传到当前账号根目录，覆盖同名文件。',
			'backup.webdavDownloadDesc' => '读取当前账号根目录的备份文件并覆盖本机数据。',
			'backup.webdavBrowseDesc' => '像文件夹一样浏览服务器：进入目录、新建文件夹、上传或恢复任意文件。',
			'backup.webdavDescription' => ({required Object file}) => '备份以 ${file} 存放在服务器目录，上传覆盖、下载恢复。',
			'backup.webdavConfigTitle' => '服务器配置',
			'backup.webdavConfigDescription' => '填服务器地址与账号；密码只存系统安全存储，不进备份。',
			'backup.webdavUrl' => '服务器地址',
			'backup.webdavUrlHint' => 'https://dav.jianguoyun.com/dav/',
			'backup.webdavUser' => '用户名',
			'backup.webdavUserHint' => '账号，可留空',
			'backup.webdavPassword' => '密码',
			'backup.webdavPasswordHint' => '留空则保持不变',
			'backup.webdavPasswordKeep' => '已保存在安全存储',
			'backup.webdavPasswordEmpty' => '未设置',
			'backup.webdavUrlMissing' => '请先填写服务器地址',
			'backup.webdavSaved' => 'WebDAV 配置已保存',
			'backup.webdavTest' => '测试连接',
			'backup.webdavTestOk' => '连接成功',
			'backup.webdavUpload' => '上传备份',
			'backup.webdavUploadDone' => ({required Object file}) => '已上传 ${file}',
			'backup.webdavDownload' => '下载并恢复',
			'backup.webdavDownloadConfirmTitle' => '下载并覆盖当前数据？',
			'backup.webdavDownloadConfirmDesc' => ({required Object file}) => '将用服务器上的 ${file} 覆盖本机的关注、历史、分区与设置。',
			'backup.webdavAuthFailed' => '认证失败，请检查用户名或密码',
			'backup.webdavNotFound' => '服务器上还没有备份文件',
			'backup.webdavNetworkFailed' => '网络错误，请检查地址或代理',
			'backup.webdavServerFailed' => ({required Object status}) => '服务器返回错误（${status}）',
			'backup.webdavFailed' => '操作失败',
			'backup.busy' => '另一项操作正在进行',
			'backup.folderPickTitle' => '选择备份文件夹',
			'backup.folderTitle' => '备份文件夹',
			'backup.folderDefault' => '默认文件夹',
			'backup.folderLoading' => '正在获取…',
			'backup.folderReset' => '恢复默认文件夹',
			'backup.folderOpen' => '打开备份文件夹',
			'backup.folderUnwritable' => '备份文件夹不可写，请换一个',
			'backup.folderSaveFailed' => '保存备份文件夹失败',
			'backup.openFolderFailed' => '无法打开备份文件夹',
			'backup.createTitle' => '创建备份',
			'backup.createDescription' => '把关注、观看历史、关注分区与设置写入备份文件夹。',
			'backup.createFollowsTitle' => '创建关注备份',
			'backup.createFollowsDescription' => '只备份关注的房间与分区。',
			'backup.createDone' => ({required String name}) => '已创建 ${name}',
			'backup.createFailed' => '创建备份失败',
			'backup.filesSection' => '备份文件',
			'backup.filesCount' => ({required int count}) => '${count} 个备份文件',
			'backup.filesEmpty' => '文件夹里还没有备份文件',
			'backup.filesFailed' => '读取备份文件夹失败',
			'backup.filesFailedHint' => '检查文件夹是否存在且可读，点击重试。',
			'backup.fileMeta' => ({required String time, required String size, required String kind}) => '${time} · ${size} · ${kind}',
			'backup.kindFull' => '完整备份',
			'backup.kindFollows' => '仅关注',
			'backup.fileDelete' => '删除备份文件',
			'backup.restoreConfirmTitle' => '恢复这个备份？',
			'backup.restoreConfirmDesc' => ({required String name}) => '将用 ${name} 覆盖本机的关注、历史、分区与设置，无法找回。',
			'backup.restoreFollowsConfirmDesc' => ({required String name}) => '将用 ${name} 覆盖关注与分区，其他数据不变。',
			'backup.restoreFailed' => '恢复失败',
			'backup.deleteConfirmTitle' => '删除这个备份文件？',
			'backup.deleteConfirmDesc' => ({required String name}) => '${name} 将被永久删除。',
			'backup.deleteDone' => '备份文件已删除',
			'backup.deleteFileFailed' => '删除备份文件失败',
			'backup.summaryFollows' => ({required int follows, required int areas}) => '关注 ${follows} · 分区 ${areas}',
			'backup.webdavBrowse' => '浏览服务器',
			'backup.webdavUp' => '上一级',
			'backup.webdavEmpty' => '这个目录没有文件',
			'backup.webdavLoadFailed' => '无法读取服务器目录',
			'backup.webdavRestore' => '恢复',
			'backup.webdavRestoreTitle' => ({required String name}) => '恢复“${name}”？',
			'backup.webdavRestoreDesc' => '将用服务器文件覆盖本机的关注、历史、分区与设置。',
			'backup.webdavRestored' => '已恢复服务器备份',
			'backup.webdavFileDelete' => '删除服务器文件',
			'backup.webdavDeleteTitle' => ({required String name}) => '删除服务器文件“${name}”？',
			'backup.webdavDeleteDesc' => '只删除服务器上的这个文件，本机数据不受影响。',
			'backup.webdavDeleted' => '已删除服务器文件',
			'backup.webdavUploadHere' => '上传当前备份',
			'backup.webdavUploadName' => '文件名',
			'backup.webdavUploadInvalid' => '文件名不能为空',
			'backup.webdavNoServer' => '请先配置服务器地址',
			'backup.webdavSwitchAccount' => '切换账号',
			'backup.webdavManageAccounts' => '管理账号',
			'backup.webdavUploadFile' => '上传文件',
			'backup.webdavUploadFilesDone' => ({required int count}) => '已上传 ${count} 个文件',
			'backup.webdavUploadFollows' => '上传关注备份',
			'backup.webdavDownloadToLocal' => '下载到本机',
			'backup.webdavSavedToDevice' => ({required String file}) => '已保存 ${file}',
			'backup.webdavRename' => '重命名',
			'backup.webdavRenameTitle' => ({required String name}) => '重命名“${name}”',
			'backup.webdavRenamed' => '已重命名',
			'backup.webdavMove' => '移动到…',
			'backup.webdavMoveTitle' => ({required String name}) => '移动“${name}”',
			'backup.webdavMoveHere' => '移到此处',
			'backup.webdavMoved' => '已移动',
			'backup.webdavMoveIntoItself' => '不能把文件夹移动到自己里面',
			'backup.webdavQuota' => ({required String used, required String total}) => '已用 ${used} · 共 ${total}',
			'common.appTitle' => 'Pure Live',
			'common.empty' => '这里还没有内容',
			'common.comingSoon' => '即将推出',
			'common.close' => '关闭',
			'common.cancel' => '取消',
			'common.confirm' => '确定',
			'common.minimize' => '最小化',
			'common.maximize' => '最大化',
			'common.restore' => '还原',
			'common.toggleSidebar' => '切换侧栏',
			'common.moduleLive' => '直播',
			'common.moduleIptv' => 'IPTV',
			'common.moduleVod' => 'Bilibili视频站',
			'common.moduleMusic' => '音乐',
			'common.retry' => '重试',
			'common.moduleComingSoon' => '这个模块还在路上',
			'common.back' => '后退',
			'common.forward' => '前进',
			'common.searchHint' => '搜索房间、主播或站点',
			'common.switchModule' => '切换内容类型',
			'common.openNavigation' => '打开导航',
			'common.refreshFailed' => '刷新失败',
			'common.layout' => '切换排版',
			'common.layoutGrid' => '卡片排版',
			'common.layoutList' => '列表排版',
			'common.switchToDark' => '切换到深色',
			'common.switchToLight' => '切换到浅色',
			'common.backToTop' => '回到顶部',
			'common.backToBottom' => '回到底部',
			'common.more' => '更多',
			'common.switchPlatform' => '切换平台',
			'common.delete' => '删除',
			'common.newWindow' => '新建窗口',
			'common.show' => '显示',
			'common.save' => '保存',
			'common.copied' => '已复制',
			'common.pipUnavailable' => '当前设备或播放内核无法进入画中画。',
			'common.moduleHongguo' => '红果短剧',
			'favorites.emptyTitle' => '还没有关注的房间',
			'favorites.emptyDescription' => '在房间里点关注，就会出现在这里。',
			'favorites.unfollow' => '取消关注',
			'favorites.statusAll' => '全部',
			'favorites.statusLive' => '直播中',
			'favorites.statusOffline' => '离线',
			'favorites.refresh' => '刷新',
			'favorites.openFailedTitle' => '关注列表打不开',
			'favorites.statusReplay' => '录播',
			'favorites.searchLive' => '搜索直播',
			'favorites.emptyLiveTitle' => '当前筛选暂无已开播直播',
			'favorites.emptyReplayTitle' => '当前筛选暂无录播',
			'favorites.emptyOfflineTitle' => '当前筛选暂无未开播直播',
			'favorites.emptyOfflineHint' => '有未开播的关注，切换到「未开播」即可查看。',
			'favorites.emptyGroupHint' => '换个分组或平台，或刷新重新获取状态。',
			'favorites.showOffline' => '查看未开播',
			'favorites.refreshFailed' => ({required int count}) => '${count} 个直播间刷新失败',
			'favorites.statusLiveNow' => '已开播',
			'favorites.statusOfflineNow' => '未开播',
			'favorites.justStarted' => '刚刚开播',
			'favorites.liveFor' => ({required Object duration}) => '已播 ${duration}',
			'favorites.durationMinutes' => ({required Object m}) => '${m} 分钟',
			'favorites.durationHours' => ({required Object h, required Object m}) => '${h} 小时 ${m} 分',
			'favorites.durationDays' => ({required Object d, required Object h}) => '${d} 天 ${h} 小时',
			'favorites.setTags' => '设置标签',
			'favorites.tagsTitle' => '标签',
			'favorites.tagsFilter' => '标签筛选',
			'favorites.allTags' => '全部标签',
			'favorites.tagsEmpty' => '还没有标签',
			'favorites.newTag' => '新建标签',
			'favorites.tagFieldHint' => '新标签名称',
			'favorites.addTag' => '添加标签',
			'favorites.deleteTagTitle' => ({required String name}) => '删除标签“${name}”？',
			'favorites.deleteTagBody' => '所有直播间都会移出这个标签，直播间本身不会被取消关注。',
			'favorites.tagFollowTitle' => '先关注再设置标签',
			'favorites.tagFollowBody' => '标签只属于关注的房间。先关注这个直播间，之后可以为它设置任意多个标签。',
			'favorites.tagExists' => '这个标签已经存在',
			'favorites.tagInvalid' => '标签名称不能为空',
			'favorites.deleteTag' => '删除',
			'history.emptyTitle' => '还没有观看记录',
			'history.emptyDescription' => '看过一场直播后，就会出现在这里。',
			'history.clear' => '清空记录',
			'history.remove' => '删除这条记录',
			'history.today' => '今天',
			'history.yesterday' => '昨天',
			'history.earlier' => '更早',
			'history.openFailedTitle' => '历史记录打不开',
			'history.recordCount' => ({required int count, required int limit}) => '已记录 ${count} / 上限 ${limit} 条',
			'history.filter' => '筛选',
			'history.filterPanelTitle' => '筛选观看记录',
			'history.filterKeyword' => '关键词',
			'history.filterHint' => '按标题、主播、房间号或平台筛选',
			'history.filterStart' => '开始时间',
			'history.filterEnd' => '结束时间',
			'history.filterAnyDay' => '不限',
			'history.filterDone' => '完成',
			'history.filterMatches' => ({required int count}) => '${count} 条匹配',
			'history.filterReset' => '清除筛选',
			'history.filterEmptyTitle' => '没有符合条件的观看记录',
			'history.filterEmptyDescription' => '换个关键词，或清除筛选试试。',
			'history.deleteConfirmTitle' => '删除观看记录？',
			'history.deleteConfirmDesc' => ({required String title}) => '要从观看记录中删除“${title}”吗？仅删除这一条记录。',
			'history.deleteAction' => '删除',
			'history.deleteDone' => '已从观看记录删除',
			'history.clearConfirmTitle' => '清空观看记录？',
			'history.clearConfirmDesc' => ({required int count}) => '清空这 ${count} 条观看记录？不可撤销。',
			'history.clearFilteredConfirmDesc' => ({required int count}) => '删除筛选出的 ${count} 条观看记录？不可撤销。',
			'history.clearDone' => ({required int count}) => '已清空 ${count} 条观看记录',
			'history.changeFailed' => '观看记录更改未保存，请重试。',
			'history.limitAction' => '调整上限',
			'history.limitTitle' => '观看记录保留数量',
			'history.limitDescription' => '超出上限后，最早的记录会被移除。',
			'history.limitPresetsLabel' => '预设数量',
			'history.limitCustomLabel' => '自定义数量',
			'history.limitInvalid' => ({required int min, required int max}) => '请输入 ${min} 到 ${max} 之间的整数。',
			'history.limitSaved' => ({required int limit}) => '上限已设为 ${limit} 条',
			'history.refresh' => '刷新',
			'history.refreshFailed' => ({required int count}) => '${count} 条记录刷新失败',
			'hongguo.title' => '红果短剧',
			'hongguo.tagline' => '短剧 · 漫剧 · AI 短剧，由红果伴侣服务提供',
			'hongguo.navRank' => '榜单',
			'hongguo.navSearch' => '搜索',
			'hongguo.genreShortPlay' => '短剧',
			'hongguo.genreComicSeries' => '漫剧',
			'hongguo.genreAiSeries' => 'AI短剧',
			'hongguo.filterAll' => '全部',
			'hongguo.search' => '搜索',
			'hongguo.searchHint' => '搜索短剧',
			'hongguo.searchIdleTitle' => '搜索短剧',
			'hongguo.searchIdleDescription' => '输入剧名搜索红果的短剧、漫剧和 AI 短剧。',
			'hongguo.noResultsDescription' => '换个条件再试试。',
			'hongguo.serverHint' => '红果接口没有应答；请检查网络后重试。',
			'hongguo.openSettings' => '红果设置',
			'hongguo.episodes' => '剧集',
			'hongguo.episodeLabel' => ({required Object index}) => '第${index}集',
			'hongguo.episodesCount' => ({required Object count}) => '${count}集',
			'hongguo.episodesJump' => '跳转集数',
			'hongguo.episodesPrevious' => '上一组',
			'hongguo.episodesNext' => '下一组',
			'hongguo.plays' => '播放',
			'hongguo.followers' => '追剧',
			'hongguo.todayTag' => '今日',
			'hongguo.loadFailed' => '剧集没有加载出来',
			'hongguo.opening' => '正在打开…',
			'hongguo.play' => '播放',
			'hongguo.continueWatching' => '继续观看',
			'hongguo.playFromStart' => '从头播放',
			'hongguo.notWatchedYet' => '还没看过',
			'hongguo.pause' => '暂停',
			'hongguo.mute' => '静音',
			'hongguo.unmute' => '取消静音',
			'hongguo.volume' => '音量',
			'hongguo.progress' => '播放进度',
			'hongguo.speed' => '倍速',
			'hongguo.quality' => '清晰度',
			'hongguo.speedHolding' => '2.0x 快进中 · 上滑锁定',
			'hongguo.speedLocked' => '已锁定 2.0x · 长按下滑解除',
			'hongguo.speedLockedToast' => '已锁定 2.0 倍速',
			'hongguo.speedUnlockedToast' => '已解除倍速',
			'hongguo.firstEpisode' => '已经是第一集',
			'hongguo.lastEpisode' => '已经是最后一集',
			'hongguo.nextEpisode' => '下一集',
			'hongguo.fullscreen' => '全屏',
			'hongguo.exitFullscreen' => '退出全屏',
			'hongguo.expand' => '展开',
			'hongguo.collapse' => '收起',
			'hongguo.boardAll' => '综合榜',
			'hongguo.boardReal' => '真人剧榜',
			'hongguo.boardComic' => '漫剧榜',
			'hongguo.boardAi' => 'AI剧榜',
			'hongguo.navHome' => '首页',
			'hongguo.navFind' => '找剧',
			'hongguo.navFavorites' => '收藏',
			'hongguo.navHistory' => '观看历史',
			'hongguo.navReservations' => '账户预约',
			'hongguo.navAccount' => '账户',
			'hongguo.homeTabAll' => '推荐',
			'hongguo.localTab' => '本机',
			'hongguo.accountTab' => '账户',
			'hongguo.favoritesLocalEmpty' => '在剧集详情中加入本机收藏，喜欢的剧就会出现在这里',
			'hongguo.favoritesAccountEmpty' => '尚未读取账户收藏',
			'hongguo.favoritesAccountOff' => '登录红果账号后，在这里同步手机收藏',
			'hongguo.historyLocalEmpty' => '看过的剧和进度会出现在这里',
			'hongguo.historyAccountEmpty' => '尚未读取账户观看历史',
			'hongguo.historyAccountOff' => '登录红果账号后，在这里同步手机观看历史',
			'hongguo.historyClear' => '清空历史',
			'hongguo.historyClearDesc' => '只清空这台设备的观看进度，账户历史和收藏保留',
			'hongguo.historyCleared' => '已清空这台设备的观看记录',
			'hongguo.historyRemove' => '删除记录',
			'hongguo.historyRemoveDesc' => '只删除这部剧的观看进度',
			'hongguo.historyManage' => '管理',
			'hongguo.historyManageDone' => '完成',
			'hongguo.historyManageDelete' => '删除选中的记录',
			'hongguo.historyManageDeleteCount' => ({required Object count}) => '删除选中（${count}）',
			'hongguo.resumeAt' => '续播',
			'hongguo.watchedBadge' => '已看完',
			'hongguo.historyEpisodeProgress' => ({required Object index, required Object total}) => '${index}集/${total}集',
			'hongguo.reservationsOnline' => '已上线',
			'hongguo.reservationsUpcoming' => '待上线',
			'hongguo.reservationsOnlineEmpty' => '当前没有已上线的预约',
			'hongguo.reservationsUpcomingEmpty' => '当前没有待上线的预约',
			'hongguo.reservationsRefresh' => '刷新预约',
			'hongguo.reservationsOff' => '登录红果账号后，在这里同步手机预约',
			'hongguo.accountSignInTitle' => '扫码登录红果',
			'hongguo.accountSignInDesc' => '用手机红果 App 扫二维码确认登录；账户收藏、历史与预约随账号同步',
			'hongguo.accountQrRefresh' => '刷新二维码',
			'hongguo.accountSignedInAs' => '已登录',
			'hongguo.accountSignOut' => '退出登录',
			'hongguo.accountSignOutDesc' => '只退出红果账号，本机收藏与历史保留',
			'hongguo.accountRefresh' => '刷新账户数据',
			'hongguo.accountFavoritesRefresh' => '刷新收藏',
			'hongguo.accountHistoryRefresh' => '刷新历史',
			'hongguo.favorite' => '收藏',
			'hongguo.favorited' => '已收藏',
			'hongguo.unfavorite' => '取消收藏',
			'hongguo.likes' => '点赞',
			'hongguo.favoriteToggleOn' => '已加入本机收藏',
			'hongguo.favoriteToggleOff' => '已取消本机收藏',
			'hongguo.cloudFavoriteOn' => '已加入账户收藏',
			'hongguo.cloudFavoriteOff' => '已取消账户收藏',
			'hongguo.related' => '相关作品',
			'hongguo.relatedNone' => '暂无相关剧集',
			'hongguo.relatedLive' => '已上线 · 看剧集',
			'hongguo.relatedReserve' => '预约',
			'hongguo.reserved' => '已预约',
			'hongguo.comments' => '评论',
			'hongguo.commentsEmpty' => '还没有评论',
			'hongguo.commentsLoadMore' => '加载更多',
			'hongguo.danmaku' => '弹幕',
			'hongguo.danmakuOn' => '弹幕开',
			'hongguo.danmakuOff' => '弹幕关',
			'hongguo.danmakuEnabledDesc' => '在画面上飞行显示本集评论',
			'hongguo.danmakuFontSize' => '弹幕字号',
			'hongguo.danmakuFontSizeDesc' => '评论文字的大小',
			'hongguo.danmakuOpacity' => '弹幕不透明度',
			'hongguo.danmakuOpacityDesc' => '文字越亮越不透明',
			'hongguo.danmakuSpeed' => '弹幕速度',
			'hongguo.danmakuSpeedDesc' => '评论横穿画面的快慢',
			'hongguo.danmakuDensity' => '弹幕密度',
			'hongguo.danmakuDensityDesc' => '同时最多占几行画面',
			'hongguo.danmakuDensitySparse' => '少',
			'hongguo.danmakuDensityNormal' => '中',
			'hongguo.danmakuDensityDense' => '多',
			'hongguo.phoneLogin' => '手机号登录',
			'hongguo.phonePlaceholder' => '手机号，如 138…（境外 +区号 号码）',
			'hongguo.phoneSend' => '发送验证码',
			'hongguo.phoneCodePlaceholder' => '验证码',
			'hongguo.phoneVerify' => '登录',
			_ => null,
		} ?? switch (path) {
			'hongguo.phoneSent' => '验证码已发送到',
			'hongguo.accountPhoneToggle' => '用手机号登录',
			'hongguo.accountQrToggle' => '扫码登录',
			'hongguo.commentsFailed' => '评论没有加载出来',
			'hongguo.shelfForYou' => '为你推荐',
			'hongguo.shelfChangeBatch' => '换一批',
			'hongguo.shelfHot' => '正在热播',
			'hongguo.shelfNew' => '新剧',
			'hongguo.shelfCategory' => '分类',
			'hongguo.newArrivals' => '上新',
			'hongguo.openFullBoard' => '查看完整榜单',
			'hongguo.seeMore' => '更多',
			'hongguo.refreshShelf' => '刷新片单',
			'hongguo.allEpisodesCount' => ({required Object count}) => '全${count}集',
			'hongguo.filterReset' => '重置',
			'hongguo.filterNone' => '全部条件',
			'hongguo.rankSource' => '红果官网热播榜',
			'hongguo.rankTopicAll' => '全部题材',
			'hongguo.rankKeepsPlaces' => '保留原榜名次',
			'hongguo.rankRenewing' => '正在后台更新…',
			'hongguo.rankReading' => '读取中…',
			'hongguo.rankEmptyTopic' => '本榜暂无符合条件的作品，可切换题材',
			'hongguo.rankSeriesCount' => ({required Object count}) => '${count} 部',
			'hongguo.refresh' => '刷新',
			'hongguo.suggestOff' => '联想暂不可用，可直接按搜索',
			'hongguo.searchHistory' => '最近搜索',
			'hongguo.searchHistoryClear' => '清空历史',
			'hongguo.searchHistoryHint' => '搜过的剧名会留在本机，最多 20 条',
			'hongguo.filter' => '筛选',
			'hongguo.filterPanelTitle' => '筛选条件',
			'hongguo.filterDone' => '完成',
			'hongguo.accountId' => '红果号',
			'hongguo.copyAccountId' => '复制',
			'hongguo.copied' => '已复制',
			'hongguo.share' => '分享',
			'hongguo.shareCopied' => '链接已复制',
			'hongguo.accountReading' => '正在读取…',
			'hongguo.accountNotRead' => '尚未读取',
			'hongguo.accountReadCount' => ({required Object count}) => '已读取 ${count} 部',
			'hongguo.historyFilterWatched' => '已看完',
			'hongguo.historyFilterUnwatched' => '未看完',
			'hongguo.sleep' => '定时停止',
			'hongguo.sleepOff' => '关闭定时停止',
			'hongguo.sleepAfter' => ({required Object minutes}) => '${minutes} 分钟后',
			'hongguo.sleepMinutes' => ({required Object count}) => '${count} 分钟后',
			'hongguo.sleepThisEpisode' => '本集播完',
			'hongguo.sleepAfterEpisodes' => ({required Object count}) => '再播完 ${count} 集',
			'hongguo.sleepEpisodes' => ({required Object count}) => '再播完 ${count} 集',
			'hongguo.sleepStopped' => '定时停止已生效 · 观看位置已保存 · 按播放可继续',
			'hongguo.retryNow' => '立即重试',
			'hongguo.retryLower' => ({required Object height}) => '尝试 ${height}P',
			'hongguo.backToEpisodes' => '返回选集',
			'hongguo.stopAutoRetry' => '停止自动重试',
			'hongguo.autoRetry' => ({required Object attempt, required Object seconds}) => '即将重试 ${attempt}/3 · ${seconds} 秒后',
			'hongguo.retryExhausted' => '已自动重试 3 次，仍无法播放。可手动重试或切换清晰度。',
			'hongguo.waitingForNetwork' => '当前没有网络 · 联网后会自动接着播',
			'hongguo.decoderLessons' => '设备解码记录',
			'hongguo.decoderLessonsCount' => ({required Object count}) => '已记住 ${count} 条解码失败，选流时会跳过它们',
			'hongguo.decoderLessonsEmpty' => '还没有解码失败记录，选流按平台声明',
			'hongguo.decoderResetDone' => ({required Object count}) => '已清除 ${count} 条设备解码记录',
			'hongguo.favoriteCheck' => '检查更新',
			'hongguo.favoriteChecking' => ({required Object done, required Object total}) => '检查更新 ${done}/${total}…',
			'hongguo.favoriteChecked' => ({required Object done, required Object total}) => '已检查 ${done}/${total} 部 · 检查完成',
			'hongguo.favoriteCheckedSome' => ({required Object done, required Object total, required Object failures}) => '已检查 ${done}/${total} 部 · ${failures} 部失败，稍后可重试',
			'hongguo.favoriteRecentCheck' => '最近一小时已检查，可手动刷新',
			'hongguo.favoriteNoFavorites' => '收藏后可检查新集',
			'hongguo.favoriteAdded' => ({required Object count}) => '新增 ${count} 集',
			'hongguo.favoriteTotal' => ({required Object total}) => '共 ${total} 集',
			'hongguo.favoriteTotalAdded' => ({required Object total, required Object added}) => '共 ${total} 集（+${added}）',
			'hongguo.favoriteTotalPending' => '总集数待更新',
			'hongguo.favoriteWatchedTo' => ({required Object index}) => '看到第 ${index} 集',
			'hongguo.favoriteBadge' => ({required Object count}) => '${count} 部有新集',
			'hongguo.reviews' => '剧评',
			'hongguo.reviewsEpisode' => '本集评论',
			'hongguo.reviewsSeries' => '整剧剧评',
			'hongguo.reviewsEmpty' => '还没有剧评',
			'hongguo.rating' => ({required Object score}) => '评分 ${score}',
			'hongguo.ratingCount' => ({required Object count}) => '${count} 人评分',
			'iptv.tabAll' => '全部',
			'iptv.live' => '直播',
			'iptv.scopeLabel' => '频道范围',
			'iptv.scopeAll' => '全部频道',
			'iptv.scopeFavourites' => '收藏频道',
			'iptv.groupsLabel' => '频道分组',
			'iptv.ungrouped' => '未分组',
			'iptv.emptyTitle' => '还没有频道',
			'iptv.emptyDescription' => '导入 M3U/TXT 播放列表后，频道就会出现在这里。',
			'iptv.openFailedDescription' => '频道库打开失败。',
			'iptv.noFavoritesTitle' => '还没有收藏的频道',
			'iptv.noFavoritesDescription' => '点一下频道卡片上的心形，频道就会留在这里。',
			'iptv.onAir' => '正在播出',
			'iptv.upNext' => '接下来',
			'iptv.noGuide' => '暂无节目单',
			'iptv.favouriteAction' => '收藏频道',
			'iptv.unfavouriteAction' => '取消收藏',
			'iptv.epgSourceTitle' => '节目单源',
			'iptv.epgSourceHint' => 'XMLTV 或 JSON 节目单地址',
			'iptv.epgImport' => '导入',
			'iptv.epgImported' => '节目单已导入',
			'iptv.epgFailed' => '节目单导入失败',
			'iptv.epgRemove' => '删除此节目单源',
			'iptv.epgEmpty' => '还没有节目单来源；导入一个后，频道就会显示正在播的节目。',
			'iptv.activeGuideDescription' => '选择用于频道节目的节目单来源；同一时间只使用一个。',
			'iptv.activeGuideNone' => '未选择',
			'iptv.activeGuideTitle' => '当前节目单',
			'iptv.activeGuideCardHint' => '频道的正在播出与进度都按这份节目单显示。',
			'iptv.autoUpdate' => '自动更新',
			'iptv.autoUpdateHint' => '应用会按此间隔在后台检查，并重新拉取已开启自动更新的节目单。',
			'iptv.customUserAgent' => '自定义 User-Agent',
			'iptv.customUserAgentDesc' => '导入与播放请求使用的 User-Agent；留空用应用默认，播放列表自带优先。',
			'iptv.updateInterval' => '更新间隔',
			'iptv.updateIntervalHours' => ({required int hours}) => '${hours} 小时',
			'iptv.updateIntervalDays' => ({required int days}) => '${days} 天',
			'iptv.autoUpdateStatusOn' => ({required int count}) => '${count} 个节目单会按此间隔自动刷新',
			'iptv.autoUpdateStatusNone' => '还没有节目单开启自动更新。',
			'iptv.autoUpdateNoRemote' => '还没有网络节目单',
			'iptv.select' => '选择',
			'iptv.selectGuideUnavailable' => '还没有节目单',
			'iptv.channelCount' => ({required int count}) => '${count} 个频道',
			'iptv.chooseGuide' => '选择节目单',
			'iptv.delete' => '删除',
			'iptv.deleteActiveGuideNote' => '这是正在使用的节目单，删除后将改用其他来源。',
			'iptv.deleteGuideMessage' => ({required String name}) => '删除节目单“${name}”？已下载的节目会一并移除。',
			'iptv.deleteGuideTitle' => '删除节目单？',
			'iptv.deletePlaylistMessage' => ({required String name, required int count}) => '删除“${name}”及其 ${count} 个频道？',
			'iptv.deletePlaylistTitle' => '删除播放列表？',
			'iptv.deleted' => ({required String name}) => '已删除“${name}”',
			'iptv.guideName' => '节目单名称',
			'iptv.guideNameHint' => '例如：我的 EPG',
			'iptv.guideSelected' => ({required String name}) => '已切换到“${name}”',
			'iptv.importAction' => '导入',
			'iptv.importAddressInvalid' => '请输入有效的订阅地址',
			'iptv.importAddressRequired' => '请先输入订阅地址',
			'iptv.importFailed' => '导入失败',
			'iptv.importFormat' => '不支持的文件格式',
			'iptv.importFromFile' => '从文件',
			'iptv.importFromText' => '粘贴文本',
			'iptv.importFromUrl' => '订阅地址',
			'iptv.importGuide' => '导入节目单',
			'iptv.importGuideDescription' => '支持 XMLTV 地址或文件；导入后会下载节目。',
			'iptv.importInvalid' => '内容不是有效的播放列表',
			'iptv.importNameRequired' => '请输入播放列表名称',
			'iptv.importNetworkFailed' => '网络请求失败，请检查地址或代理',
			'iptv.importPlaylist' => '导入播放列表',
			'iptv.importPlaylistDescription' => '支持 M3U/M3U8/TXT 地址、文件或粘贴的文本。',
			'iptv.importSkipped' => ({required String name, required int count}) => '已导入“${name}”，跳过 ${count} 项',
			'iptv.importTextRequired' => '请粘贴播放列表内容',
			'iptv.imported' => ({required String name}) => '已导入“${name}”',
			'iptv.importedAt' => ({required String time}) => '导入于 ${time}',
			'iptv.inUse' => '使用中',
			'iptv.lastRefresh' => ({required String time}) => '更新于 ${time}',
			'iptv.localTag' => '本地',
			'iptv.networkTag' => '网络',
			'iptv.neverUpdated' => '尚未更新',
			'iptv.noGuidesTitle' => '还没有节目单',
			'iptv.noSourcesTitle' => '还没有来源',
			'iptv.noSourcesDescription' => '导入播放列表或节目单后，它们会出现在这里。',
			'iptv.noPlaylistsDescription' => '从订阅地址、文件或粘贴的文本导入播放列表。',
			'iptv.noPlaylistsTitle' => '还没有播放列表',
			'iptv.pickPlaylistFile' => '选择播放列表文件',
			'iptv.playlistName' => '播放列表名称',
			'iptv.playlistNameHint' => '留空则按来源自动命名',
			'iptv.playlistText' => '播放列表内容',
			'iptv.playlistTextHint' => '粘贴 M3U/M3U8/TXT 内容',
			'iptv.playlistUrl' => '订阅地址',
			'iptv.playlistUrlHint' => 'https://example.com/playlist.m3u',
			'iptv.playlistsTitle' => '播放列表',
			'iptv.replaceMessage' => '同名播放列表已存在，导入内容将替换它。',
			'iptv.replaceTitle' => ({required String name}) => '替换“${name}”？',
			'iptv.sourceChanged' => '订阅源已变化，已更新缓存',
			'iptv.summaryChannels' => ({required int count, required int groups}) => '共 ${count} 个频道 · ${groups} 个分组',
			'iptv.summaryChannelSearch' => ({required int count}) => '找到 ${count} 个频道',
			'iptv.summarySources' => ({required int playlists, required int guides, required int channels}) => '${playlists} 个播放列表 · ${guides} 个节目单 · ${channels} 个频道',
			'iptv.filterAll' => '全部',
			'iptv.filterPlaylists' => '播放列表',
			'iptv.filterGuides' => '节目单',
			'iptv.searchChannels' => '搜索频道…',
			'iptv.searchSources' => '搜索名称或地址…',
			'iptv.noChannelMatch' => '没有匹配的频道',
			'iptv.noSourceMatch' => '没有匹配的来源',
			'iptv.sourceCount' => ({required int count}) => '共 ${count} 项',
			'iptv.colChannel' => '频道',
			'iptv.colGroup' => '分组',
			'iptv.colNow' => '正在播出',
			'iptv.colFavorite' => '收藏',
			'iptv.colActions' => '操作',
			'iptv.colName' => '名称',
			'iptv.colFormat' => '类型',
			'iptv.colUpdated' => '更新于',
			'iptv.colAutoUpdate' => '自动更新',
			'iptv.editOrder' => '编辑顺序',
			'iptv.orderTitle' => '来源顺序',
			'iptv.orderHint' => '拖动左侧手柄，或用箭头调整；保存后按此顺序显示。',
			'iptv.orderDraft' => '未保存的排序草稿',
			'iptv.saveOrder' => '保存顺序',
			'iptv.orderSaved' => '顺序已保存',
			'iptv.moveUp' => '上移',
			'iptv.moveToTop' => '移到顶部',
			'iptv.moveDown' => '下移',
			'iptv.moveToBottom' => '移到底部',
			'iptv.openChannel' => '播放频道',
			'iptv.statChannels' => '频道',
			'iptv.statGuides' => '节目单',
			'iptv.statPlaylists' => '播放列表',
			'iptv.sync' => '同步',
			'iptv.syncAll' => '全部同步',
			'iptv.syncAllDone' => ({required int count}) => '已同步 ${count} 个来源',
			'iptv.syncAllNone' => '没有可同步的网络来源',
			'iptv.syncAllPartial' => ({required int failed, required int count}) => '${failed} / ${count} 个来源同步失败',
			'iptv.syncAllRunning' => ({required int done, required int total}) => '正在同步 ${done} / ${total}',
			'iptv.syncFailed' => ({required String name}) => '“${name}”同步失败',
			'iptv.synced' => ({required String name}) => '已同步“${name}”',
			'iptv.viewChannels' => '频道',
			'iptv.viewLabel' => '视图',
			'iptv.viewSources' => '来源',
			'iptv.playerOpening' => '正在打开频道',
			'iptv.playerNoStream' => '这个频道没有播放地址',
			'iptv.playerChannelMissing' => '频道不存在或已被删除',
			'iptv.playerOpenFailed' => '频道播放失败',
			'iptv.guideTitle' => '节目单',
			'iptv.guideEmpty' => '这一天没有节目',
			'iptv.today' => '今天',
			'iptv.yesterday' => '昨天',
			'iptv.previousDay' => '前一天',
			'iptv.nextDay' => '后一天',
			'iptv.backToLive' => '回到直播',
			'iptv.catchup' => '回看',
			'iptv.catchupUnavailable' => '不可回看',
			'iptv.playingCatchup' => '正在回看',
			'iptv.catchupFailed' => '无法生成这个节目的回看地址',
			'iptv.importDefaultName' => '导入的播放列表',
			'iptv.copySourceAddress' => '复制源地址',
			'iptv.openSourceAddress' => '打开源地址',
			'iptv.sourceAddressCopied' => '源地址已复制',
			'iptv.sourceAddressOpenFailed' => '无法打开源地址',
			'iptv.autoSyncTitle' => '启动时全自动同步',
			'iptv.autoSyncDesc' => '应用冷启动时自动在后台静默检查并更新网络资源。',
			'iptv.browseChannelNumber' => '换台时显示频道号',
			'iptv.browseChannelNumberDesc' => '在频道名旁边一起显示它的号码。',
			'iptv.browseReverse' => '换台反转',
			'iptv.browseReverseDesc' => '让上键向下走、下键向上走。',
			'iptv.browseClock' => '显示时间',
			'iptv.browseClockDesc' => '播放时在标题旁显示当前时间。',
			'iptv.browseProgrammeLine' => '显示当前节目',
			'iptv.browseProgrammeLineDesc' => '在频道名下方写出正在播出或接下来播出的节目。',
			'iptv.browseReset' => '恢复默认的换台显示',
			'iptv.groupsEmpty' => '还没有分组：先导入一份播放列表。',
			'iptv.groupsHint' => '关掉的分组从频道列表和换台里消失；重开即恢复。',
			'iptv.recentTitle' => '最近观看',
			'iptv.recentCount' => ({required Object count}) => '共 ${count} 个频道',
			'iptv.recentWatched' => ({required Object time}) => '上次观看 ${time}',
			'iptv.recentRemove' => '从最近观看中移除',
			'iptv.recentClear' => '清空最近观看',
			'iptv.recentClearTitle' => '清空最近观看？',
			'iptv.recentClearDesc' => '只删除本机的观看记录，收藏和频道本身不受影响。',
			'iptv.recentEmptyTitle' => '还没有看过的频道',
			'iptv.recentEmptyDescription' => '播放过的频道会出现在这里，方便快速回到上次看的内容。',
			'iptv.favouritesTitle' => '收藏频道',
			'iptv.favouritesCount' => ({required Object count}) => '共 ${count} 个收藏',
			'iptv.favouritesEmptyTitle' => '还没有收藏频道',
			'iptv.favouritesEmptyDescription' => '在频道列表里点收藏，频道会出现在这里。',
			'iptv.zapperTitle' => '换台',
			'iptv.zapperOpen' => '换台面板',
			'iptv.zapperGroups' => '分组',
			'iptv.zapperChannels' => '频道',
			'iptv.zapperProgrammes' => '节目',
			'iptv.zapperHint' => '方向键选择，确认键播放或回看，返回键收起。',
			'iptv.zapperEmptyGroup' => '这个分组没有频道',
			'iptv.lineCount' => ({required Object current, required Object total}) => '线路 ${current}/${total}',
			'iptv.aspectLabel' => '画面比例',
			'iptv.aspectAuto' => '默认',
			'iptv.aspect16x9' => '16:9',
			'iptv.aspect4x3' => '4:3',
			'iptv.aspectFill' => '铺满',
			'iptv.aspectZoom' => '裁剪',
			'iptv.digitHint' => '输入频道号跳转',
			'iptv.digitNoChannel' => ({required Object number}) => '没有频道号 ${number}',
			'iptv.reminderAction' => '预约',
			'iptv.reminderCancelAction' => '取消预约',
			'iptv.reminderSet' => ({required Object title}) => '已预约「${title}」',
			'iptv.reminderRemoved' => '已取消预约',
			'iptv.reminderStarted' => ({required Object title}) => '预约节目开始：${title}',
			'multiview.layoutLabel' => '布局',
			'multiview.selectHint' => '点击格子选中，只有选中的格子有声音',
			'multiview.selectedPane' => ({required Object index}) => '第 ${index} 格 · 有声',
			'multiview.pickRoom' => '选择房间',
			'multiview.openRoom' => '进入直播间',
			'multiview.clearPane' => '清空这一格',
			'multiview.swapPane' => '交换格子',
			'multiview.swapHere' => '换到这格',
			'multiview.paneFailed' => '这一格无法播放',
			'multiview.retryPane' => '重试这一格',
			'multiview.pickerTitle' => ({required Object index}) => '为第 ${index} 格选择房间',
			'multiview.pickerEmptyTitle' => '还没有关注的房间',
			'multiview.pickerEmptyHint' => '先到直播间点关注，再回到这里挑选，房间会出现在列表里。',
			'multiview.alreadyShown' => ({required Object index}) => '已在第 ${index} 格',
			'multiview.shownIn' => ({required Object index}) => '第 ${index} 格',
			'multiview.panePaused' => '已暂停',
			'multiview.paneQuality' => '画质',
			'multiview.pausePane' => '暂停这一格',
			'multiview.playPane' => '播放这一格',
			'multiview.pauseAll' => '全部暂停',
			'multiview.resumeAll' => '全部继续',
			'multiview.muteAll' => '全部静音',
			'multiview.unmuteAll' => '取消全部静音',
			'multiview.qualityFailed' => '画质切换失败',
			'multiview.pickerSearch' => '搜索关注或历史房间…',
			'multiview.pickerHint' => '点直播间放进这一格',
			'multiview.pickerTabFollows' => '关注',
			'multiview.pickerTabHistory' => '历史记录',
			'multiview.pickerSearchShort' => '搜索主播或标题',
			'multiview.paneEmpty' => '点击选台',
			'multiview.panePicking' => '正在为这一格选台',
			'multiview.wallFailed' => '无法读取多画面记录',
			'multiview.pickerNoMatch' => '没有匹配的房间',
			'music.title' => '音乐',
			'music.tagline' => '搜索歌曲，在线收听',
			'music.viewsLabel' => '音乐视图',
			'music.search' => '搜索',
			'music.tabLibrary' => '乐库',
			'music.tabPlaylists' => '歌单',
			'music.tabCharts' => '榜单',
			'music.tabMine' => '我的列表',
			'music.myListsEmptyTitle' => '还没有你自己的列表',
			'music.myListsEmptyDescription' => '收藏的歌曲和你自建的歌单会出现在这里；歌单与排行榜要先有音源。',
			'music.libraryEmptyTitle' => '曲库还在路上',
			'music.libraryEmptyDescription' => '音乐源接入后，歌曲会以瀑布流卡片在这里分页呈现。',
			'music.playlistsEmptyTitle' => '歌单还在路上',
			'music.playlistsEmptyDescription' => '整理与收藏的歌单会出现在这里。',
			'music.chartsEmptyTitle' => '榜单还在路上',
			'music.chartsEmptyDescription' => '来自各音乐源的热门榜单会出现在这里。',
			'music.sourcesReady' => ({required Object count}) => '已就绪 ${count} 个自定义源',
			'music.settingsPlayback' => '音源与播放',
			'music.settingsList' => '列表',
			'music.searchTypeSongs' => '歌曲',
			'music.searchTypeSonglists' => '歌单',
			'music.searchSourceAll' => '全部音源',
			'music.sourceNameType' => '音源名显示',
			'music.sourceNameTypeDesc' => '列表里的平台叫什么：别名是参考应用的化名，原名是平台自己的名字。',
			'music.sourceNameTypeAlias' => '别名',
			'music.sourceNameTypeReal' => '原名',
			'music.sourceAliasAll' => '聚合大会',
			'music.sourceAliasKw' => '小蜗音乐',
			'music.sourceAliasKg' => '小枸音乐',
			'music.sourceAliasTx' => '小秋音乐',
			'music.sourceAliasWy' => '小芸音乐',
			'music.sourceAliasMg' => '小蜜音乐',
			'music.playlistHotTags' => '热门',
			'music.sortRecommend' => '推荐',
			'music.sortHot' => '最热',
			'music.sortNew' => '最新',
			'music.sortHotCollect' => '热藏',
			'music.sortRise' => '飙升',
			'music.openPlaylistTitle' => '打开歌单',
			'music.openPlaylistHint' => '歌单链接或 ID',
			'music.openPlaylistTip' => '仅支持当前音源的链接或 ID；粘贴内容会先解析成歌单 ID 再打开。',
			'music.playlistUpdateOnline' => '更新在线歌单',
			'music.duplicateListTip' => ({required Object name}) => '你之前已收藏过「${name}」，是否拉取最新并覆盖里面的歌曲？',
			'music.onlineUpdatedToast' => ({required Object name, required Object count}) => '已更新「${name}」：${count} 首。',
			'music.onlineUpdateFailed' => '更新失败，请稍后再试。',
			'music.boardCollect' => '收藏榜单',
			'music.selectionReposition' => '调整位置',
			'music.repositionTitle' => ({required Object count}) => '将已选的 ${count} 首歌曲的位置调整到：',
			'music.repositionHint' => '请输入要调整到第几个位置',
			'music.selectionMoveTo' => '移动到',
			'music.moveDoneCount' => ({required Object count, required Object name}) => '已移动 ${count} 首到「${name}」。',
			'music.songlistSearchUnsupported' => '当前音源暂不支持歌单搜索。',
			'music.defaultSource' => '默认音源',
			'music.defaultSourceDesc' => '歌曲从哪个音源获取；自定义源脚本负责解析播放地址。',
			'music.defaultSourceEmpty' => '还没有可用的音源；先在下方「自定义源」里导入脚本。',
			'music.quality' => '播放品质',
			'music.qualityDesc' => '向音源请求的音质；音源没有这一档时会给出它能提供的最高档。',
			'music.qualityStandard' => '128K',
			'music.qualityHigh' => '320K',
			'music.qualityLossless' => '无损',
			'music.qualityHiRes' => 'Hi-Res 无损',
			'music.skipOnError' => '出错自动跳过',
			'music.skipOnErrorDesc' => '某个音源取不到地址时换下一个，而不是停下。',
			'music.autoplay' => '打开时继续播放',
			'music.autoplayDesc' => '打开音乐模块时继续上次的播放队列。',
			'music.rememberProgress' => '记住播放进度',
			'music.rememberProgressDesc' => '再次打开同一首歌时，从上一次停止的位置继续。',
			'music.addToTop' => '新歌加到列表顶部',
			'music.addToTopDesc' => '关闭时新歌排在列表末尾。',
			'music.showSource' => '列表显示音源',
			'music.showSourceDesc' => '在歌曲行旁标出它来自哪个音源。',
			'music.playbackReset' => '恢复默认',
			'music.playbackResetDesc' => '自动选源、320K、出错跳过、新歌排在末尾。',
			'music.sourcesSection' => '自定义源',
			'music.sourcesHint' => '自定义源是 JavaScript 脚本，在 fjs（QuickJS）中执行；导入后初始化并接管播放地址解析。',
			'music.sourcesImportText' => '粘贴脚本导入',
			'music.sourcesImportTextDesc' => '把 lx-music 自定义源脚本的全文粘贴进来。',
			'music.sourcesImportUrl' => '从链接导入',
			'music.sourcesImportUrlDesc' => '下载链接指向的 .js 内容并导入。',
			'music.importTitle' => '导入自定义源',
			'music.importScriptHint' => '在此粘贴脚本全文…',
			'music.importUrlHint' => 'https://…/source.js',
			'music.importMissing' => '先粘贴脚本或填写链接。',
			'music.importNotASource' => '这段内容不是 lx-music 自定义源：脚本开头没有带 @name 的头注释。',
			'music.importDuplicate' => '脚本内容与已导入的音源相同，无需重复导入。',
			'music.importLimit' => ({required Object count}) => '最多导入 ${count} 个自定义源，先移除一个再试。',
			'music.importDownloadFailed' => ({required Object error}) => '脚本下载失败：${error}',
			'music.importDone' => ({required Object name}) => '已导入「${name}」',
			'music.importUpdated' => ({required Object name}) => '已更新「${name}」',
			'music.sourcesEmpty' => '还没有自定义源',
			'music.sourcesEmptyDesc' => '导入 lx-music 自定义源脚本后，它会出现在这里。',
			'music.sourceNoDescription' => '脚本没有提供说明。',
			'music.sourceDisabled' => '已停用',
			'music.sourceUse' => '使用此音源',
			'music.sourceDelete' => '移除源',
			'music.sourceDeleteTitle' => ({required Object name}) => '移除「${name}」？',
			'music.sourceDeleteDesc' => '脚本会一并删除；重新导入即可恢复。',
			'music.sourceDeleted' => ({required Object name}) => '已移除「${name}」',
			'music.sourcesCount' => ({required Object count}) => '共导入 ${count} 个',
			'music.sourcesReload' => '重新加载脚本',
			'music.sourcesReloadDesc' => '重新初始化所有已导入的 lx 脚本。',
			'music.sourcesReloaded' => ({required Object count}) => '已加载 ${count} 个脚本',
			'music.sourcesReloadedErrors' => ({required Object count}) => '有 ${count} 个脚本加载失败',
			'music.searchHint' => '搜索歌曲、歌手或专辑…',
			'music.searchIdleTitle' => '搜一首歌',
			'music.searchIdleDescription' => '输入歌名、歌手或专辑，按回车开始搜索。',
			'music.noResultsTitle' => '没有找到歌曲',
			'music.noResultsDescription' => '换个关键词试试。',
			'music.searchFailed' => '搜索失败',
			'music.songsCount' => ({required Object count}) => '${count} 首',
			'music.play' => '播放',
			'music.pause' => '暂停',
			'music.next' => '下一首',
			'music.previous' => '上一首',
			'music.modeList' => '顺序播放',
			'music.modeListLoop' => '列表循环',
			'music.modeSingleLoop' => '单曲循环',
			'music.modeRandom' => '随机播放',
			'music.favourite' => '收藏歌曲',
			'music.unfavourite' => '取消收藏',
			'music.mineFavourites' => '收藏',
			'music.mineRecent' => '最近播放',
			'music.mineEmptyTitle' => '还没有歌曲',
			'music.mineEmptyDescription' => '收藏或播放过的歌曲会出现在这里。',
			'music.removeSong' => '移除',
			'music.chartsFailed' => '榜单加载失败',
			'music.queueEmpty' => '队列为空',
			'music.queueTitle' => '播放队列',
			'music.nowPlaying' => '正在播放',
			'music.volume' => '音量',
			'music.progress' => '播放进度',
			'music.lyrics' => '歌词',
			'music.lyricsEmpty' => '这首歌还没有歌词。',
			'music.openPlayer' => '打开播放页',
			'music.playingSource' => ({required Object source}) => '来自 ${source}',
			'music.loadMore' => '加载更多',
			'music.clearRecent' => '清空最近播放',
			'music.moreActions' => '更多操作',
			'music.playNext' => '下一首播放',
			'music.addToPlaylist' => '加入歌单',
			'music.download' => '下载',
			'music.songDetails' => '歌曲详情',
			'music.copySongName' => '复制歌名',
			'music.copiedSongName' => '已复制歌名',
			'music.songDetailTitle' => '歌名',
			'music.songDetailArtist' => '歌手',
			'music.songDetailAlbum' => '专辑',
			'music.songDetailDuration' => '时长',
			'music.songDetailSource' => '来源',
			'music.songDetailPath' => '文件',
			'music.songDetailEmpty' => '—',
			'music.dislike' => '不喜欢',
			'music.undislike' => '取消不喜欢',
			'music.disliked' => '已加入不喜欢规则，以后自动跳过',
			'music.undisliked' => '已取消不喜欢',
			'music.dislikeRules' => ({required Object count}) => '不喜欢规则 · ${count} 条',
			'music.dislikeRulesDesc' => '这些歌曲出现在播放队列里时会自动跳过。',
			'music.dislikeRulesClear' => '清除规则',
			'music.dislikeRulesCleared' => '已清除不喜欢规则',
			'music.downloadAll' => '下载全部',
			'music.downloadAllQueued' => ({required Object count}) => '已加入 ${count} 首到下载队列',
			'music.moveUp' => '上移',
			'music.moveDown' => '下移',
			'music.playAll' => '全部播放',
			'music.searchHistory' => '最近搜索',
			'music.searchHistoryClear' => '清空',
			'music.searchHistoryRemove' => '删除这条搜索',
			'music.searchHot' => '热门搜索',
			'music.searchHotDesc' => '搜索页为空时显示音源提供的热门搜索词。',
			'music.searchHotFailed' => '热门搜索加载失败',
			'music.playlistCreate' => '新建歌单',
			'music.playlistCreateTitle' => '新建歌单',
			'music.playlistAddLocal' => '添加本地歌曲',
			'music.playlistAddLocalDesc' => '选择歌曲文件',
			'music.playlistAddLocalDone' => ({required Object count}) => '已添加 ${count} 首歌曲',
			'music.playlistAddLocalNone' => '所选歌曲都已在列表中',
			'music.playlistName' => '歌单名称',
			'music.playlistNameHint' => '给歌单起个名字',
			'music.playlistRename' => '重命名',
			'music.playlistRenameTitle' => '重命名歌单',
			'music.playlistDelete' => '删除歌单',
			'music.playlistDeleteTitle' => ({required Object name}) => '删除「${name}」？',
			'music.playlistDeleteDesc' => '歌单会从列表里移除，歌曲本身不会删除。',
			'music.playlistClear' => '清空歌单',
			'music.playlistEmptyTitle' => '歌单还是空的',
			'music.playlistEmptyDescription' => '在歌曲行的「更多」里把歌加进来。',
			'music.playlistAdded' => ({required Object name}) => '已加入「${name}」',
			'music.playlistAddedCount' => ({required Object count, required Object name}) => '已加入 ${count} 首到「${name}」',
			'music.playlistAlreadyIn' => ({required Object name}) => '「${name}」里已经有这首歌',
			'music.playlistsCount' => ({required Object count}) => '${count} 个歌单',
			'music.playlistImport' => '导入歌单',
			'music.playlistImportDone' => ({required Object name}) => '已导入「${name}」',
			'music.playlistImportFailed' => ({required Object error}) => '导入失败：${error}',
			'music.playlistImportInvalid' => '文件里没有可用的歌曲',
			'music.playlistExport' => '导出歌单',
			'music.playlistExportDone' => ({required Object path}) => '已导出到 ${path}',
			'music.playlistExportFailed' => ({required Object error}) => '导出失败：${error}',
			_ => null,
		} ?? switch (path) {
			'music.playlistSort' => '排序',
			'music.sortByTitle' => '按歌名',
			'music.sortByArtist' => '按歌手',
			'music.sortByAlbum' => '按专辑',
			'music.sortByDuration' => '按时长',
			'music.sortByShuffle' => '随机排序',
			'music.selectionStart' => '选择',
			'music.selectionCancel' => '取消选择',
			'music.selectionCount' => ({required Object count}) => '已选 ${count} 首',
			'music.selectionAll' => '全选',
			'music.selectionSingle' => '单选',
			'music.selectionRange' => '区间',
			'music.selectionInvert' => '反选',
			'music.selectionDownload' => '下载',
			'music.selectionRemove' => '移除',
			'music.selectionRemoveDone' => ({required Object count}) => '已移除 ${count} 首',
			'music.downloadsActive' => ({required Object count}) => '正在下载 ${count} 首',
			'music.downloadQueued' => ({required Object title}) => '已加入下载：${title}',
			'music.downloadDuplicate' => '这首歌已经在下载队列里',
			'music.downloadUnsupported' => '这首歌没有可下载的音源（本地文件或当前音源未覆盖）',
			'music.downloadFailed' => ({required Object error}) => '下载失败：${error}',
			'music.downloadHint' => '下载文件保存在共享下载目录；队列支持暂停、续传和失败重试。',
			'music.downloadDirectory' => '下载目录',
			'music.downloadDirectoryDefault' => '使用默认目录',
			'music.downloadDirectoryDefaultDesc' => '回到应用默认的下载文件夹。',
			'music.downloadDirectoryUpdated' => '下载目录已更新',
			'music.downloadDirectoryFailed' => '无法写入这个目录',
			'music.downloadType' => '下载格式',
			'music.downloadTypeDesc' => '原格式会尽量保留音源容器；转码需要 ffmpeg。',
			'music.downloadTypeOriginal' => '原格式',
			'music.downloadTypeMp3' => 'MP3',
			'music.downloadTypeM4a' => 'M4A',
			'music.downloadTypeFlac' => 'FLAC',
			'music.downloadTypeOgg' => 'OGG',
			'music.downloadTypeWav' => 'WAV',
			'music.downloadPattern' => '文件名格式',
			'music.downloadPatternHint' => '占位符（花括号）：title、artist、album、quality、source、list、index。',
			'music.downloadPatternEdit' => '编辑',
			'music.downloadEmbedCover' => '嵌入封面',
			'music.downloadEmbedCoverDesc' => '把歌曲封面写入音频标签。',
			'music.downloadEmbedLyric' => '嵌入歌词',
			'music.downloadEmbedLyricDesc' => '把歌词写入音频标签，随文件一起播放。',
			'music.downloadIncludeTranslation' => '歌词包含翻译',
			'music.downloadIncludeTranslationDesc' => '下载的歌词文件与内嵌歌词一并写入翻译。',
			'music.downloadIncludeRomanization' => '歌词包含音译',
			'music.downloadIncludeRomanizationDesc' => '下载的歌词文件与内嵌歌词一并写入音译。',
			'music.downloadWriteLyric' => '保存歌词文件',
			'music.downloadWriteLyricDesc' => '在音频文件旁写一个同名 .lrc。',
			'music.downloadSkipExisting' => '跳过已存在文件',
			'music.downloadSkipExistingDesc' => '目标文件已存在时不再下载。',
			'music.downloadGroupByList' => '按歌单分文件夹',
			'music.downloadGroupByListDesc' => '从歌单下载时，文件保存到以歌单命名的子文件夹。',
			'music.downloadMaxConcurrent' => '同时下载数',
			'music.downloadMaxConcurrentDesc' => '同时进行的下载任务数量（1–5），修改后立即生效。',
			'music.downloadStatusQueued' => '排队中',
			'music.downloadStatusRunning' => '下载中',
			'music.downloadStatusPaused' => '已暂停',
			'music.downloadStatusProcessing' => '写入标签',
			'music.downloadStatusCompleted' => '已完成',
			'music.downloadStatusSkipped' => '已跳过',
			'music.downloadStatusFailed' => '下载失败',
			'music.downloadStatusCancelled' => '已取消',
			'music.downloadPauseAll' => '全部暂停',
			'music.downloadResumeAll' => '全部继续',
			'music.downloadClearFinished' => '清除已完成',
			'music.downloadProgress' => '下载进度',
			'music.downloadRetry' => '重试',
			'music.downloadRemove' => '移除记录',
			'music.downloadResume' => '继续',
			'music.downloadPause' => '暂停',
			'music.downloadCancel' => '取消',
			'music.downloadsEmptyTitle' => '还没有下载任务',
			'music.downloadsEmptyDescription' => ({required Object directory}) => '在歌曲行的「更多」里下载，文件会保存到 ${directory}。',
			'music.localAddFolder' => '添加文件夹',
			'music.localHint' => '添加本机音乐文件夹，扫描后会像在线歌曲一样播放。',
			'music.localFiles' => ({required Object count}) => '${count} 个文件',
			'music.localRescan' => '重新扫描',
			'music.localFolders' => '音乐文件夹',
			'music.localRemoveFolder' => '移除文件夹',
			'music.localFailed' => '扫描失败',
			'music.localEmptyTitle' => '还没有本地音乐',
			'music.localEmptyDescription' => '添加一个存放音频文件的文件夹开始扫描。',
			'music.localFolderFailed' => ({required Object error}) => '无法添加文件夹：${error}',
			'music.playbackRate' => '播放速度',
			'music.preservesPitch' => '音调补偿',
			'music.sleepTimer' => '睡眠定时',
			'music.sleepOff' => '关闭',
			'music.sleepMinutes' => ({required Object count}) => '${count} 分钟',
			'music.sleepAfterCurrent' => '播完当前歌曲',
			'music.sleepRemaining' => ({required Object value}) => '${value} 后暂停',
			'music.lyricOffset' => '歌词延迟',
			'music.lyricOffsetDesc' => '正值让歌词更晚出现。',
			'music.lyricOffsetReset' => '不偏移',
			'music.lyricTranslation' => '显示翻译',
			'music.lyricTranslationDesc' => '歌词带翻译时一并显示。',
			'music.lyricRomanization' => '显示音译',
			'music.lyricRomanizationDesc' => '歌词带音译或罗马音时一并显示。',
			'music.lyricSwapSecondary' => '翻译/音译顺序',
			'music.lyricSwapSecondaryDesc' => '交换翻译与音译在歌词行中的先后顺序。',
			'music.lyricTraditionalize' => '简体转繁体',
			'music.lyricTraditionalizeDesc' => '把歌词文本改写为繁体中文。',
			'music.lyricWordTimed' => '逐字歌词',
			'music.lyricWordTimedDesc' => '平台提供逐字时间轴时按字高亮演唱。',
			'music.lyricFontScale' => '歌词字号',
			'music.lyricFontScaleDesc' => '播放页歌词的缩放比例（100%–200%）。',
			'music.lyricFontSmaller' => '缩小字号',
			'music.lyricFontLarger' => '放大字号',
			'music.lyricFontReset' => '重置字号',
			'music.lyricAlignment' => '歌词对齐',
			'music.lyricAlignmentDesc' => '播放页歌词在面板内的对齐方式。',
			'music.lyricZoomActive' => '放大当前行',
			'music.lyricZoomActiveDesc' => '正在唱的一句歌词略大，便于跟唱。',
			'music.lyricProgress' => '显示播放进度',
			'music.lyricProgressDesc' => '在歌词面板上方显示歌曲的播放进度。',
			'music.lyricDragSeek' => '拖拽歌词调整进度',
			'music.lyricDragSeekDesc' => '拖动歌词面板选句，三秒无操作回到当前句。',
			'music.lyricScrubPlay' => '从此句播放',
			'music.lyricHint' => '歌词显示与延迟全局生效；桌面歌词在设置或播放页菜单打开。',
			'music.desktopLyrics' => '桌面歌词',
			'music.desktopLyricsOn' => '桌面歌词已开启',
			'music.desktopLyricsOff' => '桌面歌词已关闭',
			'music.desktopLyricsUnavailable' => '当前平台没有桌面歌词窗口或未授权',
			'music.desktopLyricHint' => '桌面歌词是可拖动、可锁定的悬浮窗；Android 需悬浮窗权限。',
			'music.desktopLyricEnableDesc' => '在桌面上悬浮显示当前歌词；关闭后保留下面的样式。',
			'music.desktopLyricLock' => '锁定歌词',
			'music.desktopLyricLockDesc' => '锁定后鼠标点击穿过歌词窗口，不会挡住下面的程序。',
			'music.desktopLyricStyleSection' => '样式',
			'music.desktopLyricFontSize' => '字号',
			'music.desktopLyricFontSizeDesc' => '桌面歌词的字体大小。',
			'music.desktopLyricOpacity' => '不透明度',
			'music.desktopLyricOpacityDesc' => '桌面歌词窗口的整体不透明度。',
			'music.desktopLyricTextColor' => '文字颜色',
			'music.desktopLyricTextColorDesc' => '桌面歌词的主文字颜色。',
			'music.desktopLyricStrokeColor' => '描边颜色',
			'music.desktopLyricStrokeColorDesc' => '文字描边的颜色；描边宽度为 0 时不起作用。',
			'music.desktopLyricStrokeWidth' => '描边宽度',
			'music.desktopLyricStrokeWidthDesc' => '文字描边的粗细，0 表示不描边。',
			'music.desktopLyricStrokeNone' => '无',
			'music.desktopLyricColorBlack' => '黑色',
			'music.desktopLyricColorGray' => '灰色',
			'music.desktopLyricAlignment' => '对齐方式',
			'music.desktopLyricAlignmentDesc' => '歌词在窗口内的水平对齐。',
			'music.desktopLyricAlignLeft' => '左对齐',
			'music.desktopLyricAlignCenter' => '居中',
			'music.desktopLyricAlignRight' => '右对齐',
			'music.desktopLyricColorWhite' => '白色',
			'music.desktopLyricColorYellow' => '黄色',
			'music.desktopLyricColorCyan' => '青色',
			'music.desktopLyricColorPink' => '粉色',
			'music.desktopLyricColorGreen' => '绿色',
			'music.desktopLyricColorOrange' => '橙色',
			'music.clearQueue' => '清空播放队列',
			'music.exportLyric' => '导出歌词',
			'music.associateLyric' => '关联本地歌词',
			'music.associateLyricDone' => '已关联歌词',
			'music.associateLyricFailed' => '关联失败：文件里没有可用的歌词',
			'music.lyricOverrideRemove' => '取消关联歌词',
			'music.lyricSearch' => '在线搜索歌词',
			'music.lyricSearchFor' => ({required Object title}) => '为「${title}」搜索歌词',
			'music.lyricSearchHint' => '输入歌名，或「歌手 - 歌名」',
			'music.lyricSearchAction' => '搜索',
			'music.lyricSearchEmpty' => '没有找到匹配的歌曲',
			'music.lyricSearchFailed' => ({required Object error}) => '搜索失败：${error}',
			'music.lyricSearchNoLyric' => '这首歌没有可用的歌词',
			'music.lyricSearchApplied' => ({required Object title}) => '已应用「${title}」的歌词',
			'music.comments' => '评论',
			'music.commentsHot' => '热门',
			'music.commentsNew' => '最新',
			'music.commentsEmpty' => '还没有评论',
			'music.commentsFailed' => ({required Object error}) => '评论加载失败：${error}',
			'music.commentsCount' => ({required Object count}) => '${count} 条评论',
			'music.commentsReplies' => ({required Object count}) => '${count} 条回复',
			'music.exportLyricDone' => ({required Object path}) => '歌词已保存到 ${path}',
			'music.exportLyricFailed' => ({required Object error}) => '歌词导出失败：${error}',
			'music.eqSection' => '音效',
			'music.eqEnabled' => '启用音效',
			'music.eqEnabledDesc' => '关闭时音频完全不经过处理，频段参数保持不变。',
			'music.eqPreset' => '音效预设',
			'music.eqPresetDesc' => '预设代表目标听感，不保证不同耳机音箱上效果一致。',
			'music.eqPresetCustom' => '自定义',
			'music.eqPreamp' => '预放增益',
			'music.eqPreampDesc' => '作用于频段之前；曲线削波时先降这里。',
			'music.hkEnable' => '启用快捷键',
			'music.hkEnableDesc' => '应用窗口内的传输与音量快捷键。',
			'music.hkUnset' => '未设置',
			'music.hkPressNew' => '按下新组合，Esc 取消',
			'music.hkReset' => '恢复默认',
			'music.hkResetDesc' => '还原默认组合。',
			'music.eqReset' => '重置',
			'music.hkNote' => '仅应用窗口内生效；系统级全局注册需平台层支持，尚未接入。',
			'music.hkTogglePlay' => '播放 / 暂停',
			'music.hkNext' => '下一首',
			'music.hkPrev' => '上一首',
			'music.hkSeekBackward' => '快退 5 秒',
			'music.hkSeekForward' => '快进 5 秒',
			'music.hkVolumeUp' => '音量加',
			'music.hkVolumeDown' => '音量减',
			'music.hkVolumeMute' => '静音',
			'music.hkMusicLove' => '收藏',
			'music.hkMusicUnlove' => '取消收藏',
			'music.hkMusicDislike' => '不喜欢',
			'music.eqResetDesc' => '所有频段与预放增益归零。',
			'music.eqEditorTitle' => '十段均衡器',
			'music.eqHint' => '拖动滑块调整频段；曲线实时更新并即时应用到播放。',
			'music.eqChainNote' => '频响曲线为理论预测；实际音频以这组参数生成的 FFmpeg 滤镜链为准。',
			'music.eqPresetPop' => '流行',
			'music.eqPresetRock' => '摇滚',
			'music.eqPresetClassical' => '古典',
			'music.eqPresetJazz' => '爵士',
			'music.eqPresetElectronic' => '电子',
			'music.eqPresetBass' => '重低音',
			'music.eqPresetVocal' => '清晰人声',
			'music.eqPresetLive' => '现场感',
			'music.eqPresetFlat' => '平直响应',
			'music.eqApplyFailed' => '引擎拒绝了当前音效链——声音未经过处理。请先关闭效果再尝试较小的组合。',
			'music.eqFxSection' => '增强音效',
			'music.eqFxCostPrefix' => '注意：',
			'music.eqFxCostLatency' => '增加延迟',
			'music.eqFxCostStereo' => '仅立体声输出有效',
			'music.eqFxLoudness' => '音量均衡',
			'music.eqFxLoudnessDesc' => 'loudnorm 让不同曲目与来源的响度保持一致。',
			'music.eqFxBass' => '低音增强',
			'music.eqFxBassDesc' => 'bass 低架滤波，105 Hz 以下最多 +8 dB。',
			'music.eqFxVocal' => '人声增强',
			'music.eqFxVocalDesc' => '3 kHz 人声凸起，同时收 300 Hz 浑浊段。',
			'music.eqFxWidth' => '立体声拓宽',
			'music.eqFxWidthDesc' => 'stereotools 抬高侧声道电平，中央声像不动。',
			'music.eqFxSurround' => '环境声场',
			'music.eqFxSurroundDesc' => 'haas 交叉延迟伪环绕。',
			'music.eqFxDynamics' => '动态压缩与限幅',
			'music.eqFxDynamicsDesc' => 'acompressor 平滑峰值，alimiter 守住输出上限。',
			'music.eqFxReverb' => '混响',
			'music.eqFxReverbDesc' => 'aecho 回声叠加，铺出房间混响尾音。',
			'music.eqFxPanner' => '3D 环绕',
			'music.eqFxPannerDesc' => 'apulsator 声像绕场旋转，模拟现场包围感。',
			'music.eqFxPannerSpeed' => '环绕速度',
			'music.eqFxPitch' => '升降调',
			'music.eqFxPitchDesc' => 'asetrate 升降音高，atempo 补回节奏。',
			'music.eqMeterTitle' => '响度电平表',
			'music.eqAnalysis' => '响度探针',
			'music.eqAnalysisDesc' => '在链路中运行 EBU R128 探针，不改变声音本身',
			'music.eqMeterNote' => '响度表（M=400ms 瞬时，S=3s 短期），不是 FFT 频谱——mpv 不提供原始频谱。',
			'music.eqNodesTitle' => '参数均衡器',
			'music.eqNodesAdd' => '添加节点',
			'music.eqNodeFrequency' => '频率',
			'music.eqNodeQ' => 'Q 值',
			'music.eqNodeGain' => '增益',
			'music.eqCompareTitle' => 'A/B 对比',
			'music.eqCompare' => '按住试听原始声音',
			'music.eqCompareHeld' => '正在播放原始声音——松开恢复',
			'music.songlistTabMine' => '我的歌单',
			'music.songlistTabOnline' => '在线歌单',
			'music.onlineUnsupported' => '当前音乐源不支持在线歌单',
			'music.onlineEmpty' => '该分类下暂无歌单',
			'music.onlineLoadMore' => '加载更多',
			'music.onlineLoadFailed' => '歌单加载失败',
			'music.onlineImport' => '导入歌单',
			'music.onlineImported' => ({required Object count, required Object name}) => '已导入 ${count} 首到「${name}」',
			'music.syncHost' => '同步服务端',
			'music.syncHostHint' => 'lx-music 同步服务地址，例如 http://192.168.1.10:23332',
			'music.syncEdit' => '修改',
			'music.syncAuthCode' => '连接码',
			'music.syncAuthCodeHint' => '服务端显示的连接码',
			'music.syncMode' => '同步模式',
			'music.syncConnect' => '连接',
			'music.syncDisconnect' => '断开',
			'music.syncStatusConnected' => '已连接',
			'music.syncStatusConnecting' => '连接中',
			'music.syncStatusFailed' => '连接失败',
			'music.syncStatusIdle' => '未连接',
			'music.syncStatusHint' => '连接后拉取服务端歌单并推送本地改动。',
			'music.syncForgetKey' => '清除授权',
			'music.syncForgetKeyDesc' => '删除已保存的密钥，下次连接用连接码重新授权。',
			'music.syncNote' => '与 lx-music 桌面端同步：试听、收藏与自建歌单，服务端按所选模式合并。',
			'music.syncModeMergeLocalRemote' => '合并（本地优先）',
			'music.syncModeMergeRemoteLocal' => '合并（远端优先）',
			'music.syncModeOverwriteLocalRemote' => '以本地覆盖远端',
			'music.syncModeOverwriteRemoteLocal' => '以远端覆盖本地',
			'music.syncModeOverwriteLocalRemoteFull' => '仅保留本地',
			'music.syncModeOverwriteRemoteLocalFull' => '仅保留远端',
			'music.catalogSection' => '内置音源库',
			'music.catalogHint' => '来自社区合集 pdone/lx-music-source，一键拉取最新脚本，走设置的 GitHub 加速。',
			'music.catalogImport' => '导入',
			'music.catalogImported' => '已导入',
			'music.catalogFetchFailed' => '音源脚本下载失败：raw 源与镜像都不可达',
			'music.duplicateTracks' => '重复歌曲',
			'music.duplicatesFound' => ({required Object count}) => '发现 ${count} 首重复歌曲',
			'music.duplicatesNone' => '没有发现重复的歌曲',
			'music.duplicatesRemoveAll' => '移除重复（保留第一首）',
			'music.listSearch' => '搜索列表内歌曲',
			'music.listSearchEmpty' => '没有找到匹配的歌曲',
			'music.toggleSource' => '歌曲换源',
			'music.toggleSourceDone' => '已换源，之后都用新源播放这首歌',
			'music.toggleSourceEmpty' => '没有找到候选歌曲',
			'music.toggleSourceFailed' => '候选搜索失败',
			'music.editTags' => '编辑标签',
			'music.tagEditTitle' => '编辑歌曲标签',
			'music.tagEditFileName' => '文件名',
			'music.tagEditName' => '歌曲名',
			'music.tagEditSinger' => '艺术家',
			'music.tagEditAlbum' => '专辑名',
			'music.tagEditLyric' => 'LRC 歌词',
			'music.tagEditPic' => '歌曲专辑封面',
			'music.tagEditParseName' => '从文件名解析歌曲名、艺术家',
			'music.tagParseNameSinger' => '歌曲名 - 艺术家',
			'music.tagParseSingerName' => '艺术家 - 歌曲名',
			'music.tagEditSelectPic' => '选择图片',
			'music.tagEditSelectPicFailed' => '图片读取失败',
			'music.tagEditRemovePic' => '移除图片',
			'music.tagEditClearLyric' => '清空',
			'music.tagEditMatchOnline' => '在线匹配',
			'music.tagEditMatchLyricDone' => '歌词匹配成功',
			'music.tagEditMatchPicDone' => '封面匹配成功',
			'music.tagEditMatchLyricFailed' => '在线歌词匹配失败',
			'music.tagEditMatchPicFailed' => '在线匹配封面失败',
			'music.tagEditConfirm' => '保存',
			'music.tagEditSaved' => '保存成功',
			'music.tagEditFailed' => ({required Object error}) => '保存失败：${error}',
			'music.tagEditUnsupportedFormat' => '该格式暂不支持写入标签',
			'music.tagEditReadFailed' => '读取文件标签失败',
			'navigation.groupPrimary' => '高频页面',
			'navigation.home' => '首页',
			'navigation.live' => '直播',
			'navigation.channels' => '频道',
			'navigation.discover' => '发现',
			'navigation.history' => '观看记录',
			'navigation.groupContent' => '内容与工具',
			'navigation.multiview' => '多画面',
			'navigation.favorites' => '关注',
			'navigation.hot' => '热门',
			'navigation.zones' => '分区',
			'navigation.search' => '搜索直播',
			'navigation.toolbox' => '工具箱',
			'navigation.groupPersonal' => '个人与系统',
			'navigation.record' => '录制中心',
			'navigation.settings' => '设置',
			'navigation.appearance' => '外观',
			'navigation.proxy' => '网络代理',
			'navigation.user' => '用户',
			'navigation.vodRegions' => '分区',
			'navigation.iptvSources' => '订阅源',
			'navigation.iptvGuide' => '节目单',
			'navigation.musicSonglist' => '歌单',
			'navigation.musicToplist' => '排行榜',
			'navigation.musicLibrary' => '我的列表',
			'navigation.musicLocal' => '本地音乐',
			'navigation.musicDownloads' => '下载管理',
			'player.title' => '播放',
			'player.back' => '返回',
			'player.quality' => '清晰度',
			'player.line' => '线路',
			'player.fullscreen' => '全屏',
			'player.danmaku' => '弹幕',
			'popular.allPlatforms' => '全部平台',
			'popular.allPlatformsHint' => '点一个直接切过去；在「平台显示」里隐藏和排序。',
			'popular.page' => ({required int page, required int total}) => '第 ${page} 页，共 ${total} 页',
			'popular.prevPage' => '上一页',
			'popular.nextPage' => '下一页',
			'popular.inlineAt' => ({required Object platform, required Object query}) => '在 ${platform} 中搜索“${query}”',
			'popular.backToBrowse' => '返回浏览',
			'popular.sortLabel' => '排序',
			'popular.sortPlatform' => '平台推荐',
			'popular.sortAudience' => '按观众',
			'popular.hiddenUnplayable' => ({required int count}) => '已隐藏 ${count} 个暂时不能播放的直播（付费、加锁、仅限 App 等）',
			'recorder.tabRunning' => '进行中',
			'recorder.tabFinished' => '已完成',
			'recorder.clearFinished' => '清空已完成',
			'recorder.removeTask' => '删除这条任务',
			'recorder.emptyTitle' => '还没有录制任务',
			'recorder.emptyFinishedTitle' => '已完成的录制会出现在这里',
			'recorder.emptyDescription' => '在直播间点击录制，任务会出现在这里。',
			'recorder.qualityBest' => '最佳画质',
			'recorder.startedAt' => ({required Object time}) => '开始于 ${time}',
			'recorder.stateRecording' => '录制中',
			'recorder.stateStopped' => '已停止',
			'recorder.stateFailed' => '失败',
			'recorder.settingsTitle' => '录制',
			'recorder.saveDirTitle' => '保存目录',
			'recorder.saveDirDefault' => '跟随引擎默认目录',
			'recorder.saveDirDialogHint' => '输入保存录制文件的文件夹路径',
			'recorder.namingTitle' => '文件命名模板',
			'recorder.namingDescription' => '可用日期、时间、平台、房间号与标题占位符。',
			'recorder.namingDialogHint' => '输入录制文件的命名模板',
			'recorder.maxSizeTitle' => '单次录制大小上限',
			'recorder.maxSizeDescription' => '录制达到上限后自动结束并保存；按 MB 计。',
			'recorder.filterLabel' => '筛选',
			'recorder.filterAll' => '全部',
			'recorder.filterRecording' => '录制中',
			'recorder.filterWaiting' => '等待',
			'recorder.filterSaved' => '已保存',
			'recorder.filterFailed' => '失败',
			'recorder.emptyFilterTitle' => ({required String status}) => '“${status}”里还没有任务',
			'recorder.stateWaiting' => '等待开播',
			'recorder.stateSaved' => '已保存',
			'recorder.menuMore' => '更多操作',
			'recorder.openRoom' => '进入直播间',
			'recorder.openFolder' => '打开文件夹',
			'recorder.openFolderFailed' => '无法打开文件夹',
			'recorder.delete' => '删除',
			'recorder.deleteTitle' => ({required String name}) => '删除“${name}”？',
			'recorder.deleteBody' => '只删除这条录制任务记录，已保存的视频文件不会被删除。',
			'recorder.settingsOpen' => '录制设置',
			'recorder.stop' => '停止录制',
			'recorder.settingsFiles' => '文件与位置',
			'recorder.settingsRecovery' => '分段与恢复',
			'recorder.settingsRuntime' => '后台与上限',
			'recorder.segmentTitle' => '分段时长',
			'recorder.segmentDescription' => '每段录制的长度；段文件在崩溃后仍可播放。',
			'recorder.segmentMinutes' => ({required int count}) => '${count} 分钟',
			'recorder.readTimeoutTitle' => '读取超时',
			'recorder.readTimeoutDescription' => '直播流停止供流后等待多久判定失败。',
			'recorder.seconds' => ({required int count}) => '${count} 秒',
			'recorder.queueTitle' => '输入队列',
			'recorder.queueDescription' => 'FFmpeg 输入包队列大小；直播突发时越大越不容易丢包。',
			'recorder.preferBestTitle' => '只录首路音视频',
			'recorder.preferBestDescription' => '开启时只映射首个视频和音频流，避免多码率文件变成多轨。',
			'recorder.keepAliveTitle' => '后台保持录制',
			'recorder.keepAliveDescription' => '录制期间持有后台会话与唤醒锁（Android 前台服务/通知）。',
			'recorder.verifyTitle' => '结束时校验文件',
			'recorder.verifyDescription' => '结束前检查分段是否可播放。',
			'recorder.restartTitle' => '断流重试次数',
			'recorder.restartDescription' => '流中断后 FFmpeg 自动重开的次数；0 表示不重试。',
			'recorder.restartCount' => ({required int count}) => '${count} 次',
			'recorder.backoffTitle' => '重试间隔',
			'recorder.backoffDescription' => '两次重开之间的等待。',
			'recorder.stallTitle' => '卡流判定',
			'recorder.stallDescription' => '多久没有新数据就判定为卡流并重开。',
			'recorder.watermarkTitle' => '磁盘余量保护',
			'recorder.watermarkDescription' => '剩余空间低于该值时停止录制。',
			'recorder.maxTasksTitle' => '同时录制任务上限',
			'recorder.maxTasksDescription' => '达到上限后新的录制请求会被拒绝。',
			'recorder.maxTasksCount' => ({required int count}) => '${count} 个',
			'recorder.containerTitle' => '分段格式',
			'recorder.containerDescription' => 'TS 更耐中断，MP4 更易被普通播放器打开。',
			'recorder.containerTs' => 'MPEG-TS',
			'recorder.containerMp4' => '分段 MP4',
			'recorder.recordChatTitle' => '同时录制弹幕',
			'recorder.recordChatDescription' => '在录像旁存同名弹幕文件，格式见「弹幕 → 弹幕文件」；平台需已接入弹幕',
			'recorder.defaultQualityTitle' => '默认录制画质',
			'recorder.defaultQualityDesc' => '开始录制时优先请求这个清晰度；平台不提供时使用当前播放线路。',
			'recorder.cacheTitle' => '录制缓存',
			'recorder.liveCheckGroup' => '开播检测',
			'recorder.enablePolling' => '启用开播检测',
			'recorder.enablePollingDesc' => '主播未开播时自动轮询；在直播间菜单里选「开播自动录」加入。',
			'recorder.pollingOff' => '「开播检测」关着，等待开播的任务不会自动开始。',
			'recorder.pollingEnable' => '打开',
			'recorder.pollingEnabledToast' => ({required Object seconds}) => '已打开开播检测（每 ${seconds} 秒检查一次）',
			'recorder.cacheLimitEnabled' => '限制录制缓存',
			'recorder.cacheLimitEnabledDesc' => '超过上限时自动删除最旧的已完成录制；正在录制的文件不会被删除。',
			'recorder.cacheLimit' => '缓存上限',
			'recorder.cacheLimitDesc' => '超过上限从最旧的已完成录像删起；正在录制的不动。',
			'recorder.cacheSize' => '当前录制缓存',
			'recorder.cacheSizeDesc' => '录制目录中已完成与正在录制的文件总大小。',
			'recorder.cacheRefresh' => '刷新',
			'recorder.cacheClear' => '清理录制缓存',
			'recorder.cacheClearDesc' => '删除全部已完成的录制文件与弹幕 XML，正在录制的保留。',
			'recorder.cacheClearConfirm' => '清理全部已完成录制？',
			'recorder.cacheClearConfirmDesc' => '删除目录中已完成的视频、分段与弹幕文件，无法恢复；正在录制的跳过。',
			'recorder.cacheCleared' => '录制缓存已清理',
			'recorder.cacheFailed' => '缓存操作失败，请重试',
			'recorder.cacheManagedHint' => '自定义目录下只创建并管理 PureLiveRecords 子目录。',
			'recorder.liveCheckSecondsTitle' => '检测间隔（秒）',
			'recorder.liveCheckSecondsDesc' => '每个等待开播的任务多久检查一次，10–300 秒。',
			'recorder.checkBackoff' => '启用指数退避',
			'recorder.checkBackoffDesc' => '连续失败越多，下一次检测间隔越长，避免频繁请求平台。',
			'recorder.maxCheckSecondsTitle' => '最大检测间隔（秒）',
			'recorder.maxCheckSecondsDesc' => '退避后的间隔上限，60–3600 秒。',
			'recorder.autoStartOnBoot' => '应用启动时恢复待录任务',
			'recorder.autoStartOnBootDesc' => '把中断时仍在录制的任务恢复为等待开播；已停止的保持原状。',
			'recorder.cacheBusy' => '有录制任务正在进行（可能在另一个窗口），缓存不会被清理或自动裁剪。',
			'room.opening' => '正在打开房间',
			'room.follow' => '关注',
			'room.unfollow' => '已关注',
			'room.quality' => '画质',
			'room.lineLabel' => '线路',
			'room.line' => ({required Object n}) => '线路 ${n}',
			'room.play' => '播放',
			'room.pause' => '暂停',
			'room.noChat' => '还没有弹幕',
			'room.system' => '系统',
			'room.mute' => '静音',
			'room.unmute' => '取消静音',
			'room.volume' => '音量',
			'room.sleep' => '定时关闭',
			'room.sleepOff' => '关闭定时',
			'room.sendHint' => '发个弹幕见证当下',
			'room.send' => '发送',
			'room.sendFailed' => '发送失败',
			'room.fullscreenOn' => '进入全屏',
			'room.fullscreenOff' => '退出全屏',
			'room.chatTitle' => '聊天',
			'room.danmakuOn' => '显示弹幕',
			'room.danmakuOff' => '隐藏弹幕',
			'room.windowFullscreenOn' => '窗口全屏',
			'room.windowFullscreenOff' => '退出窗口全屏',
			'room.pipOn' => '画中画',
			'room.pipOff' => '退出画中画',
			'room.cast' => '投屏',
			'room.castTitle' => '投屏到设备',
			'room.castSearching' => '正在搜索附近的设备',
			'room.castSearchingHint' => '请确认电视与电脑在同一局域网。',
			'room.castDevices' => '可用设备',
			'room.casting' => '正在投屏',
			'room.castStop' => '停止投屏',
			'room.castStarted' => '已开始投屏',
			'room.castFailed' => '投屏失败，设备可能无法访问这条线路',
			'room.sleepDone' => '睡眠定时已到，播放已暂停',
			'room.audioOnlyMode' => '音频模式',
			'room.restoreVideo' => '恢复视频',
			'room.backToRoom' => '返回直播间',
			'room.openingRoom' => '正在打开房间',
			'room.playbackFailed' => '播放失败',
			'room.buffering' => '缓冲中',
			'room.connecting' => '正在连接直播流',
			'room.slowReason' => '时间有点长，线路可能不稳定',
			'room.paused' => '已暂停',
			'room.replayEnded' => '回放已结束',
			'room.banned' => '该直播间已被封禁',
			'room.carousel' => '轮播中',
			'room.carouselReason' => '主播暂时不在，平台正在播放轮播内容',
			_ => null,
		} ?? switch (path) {
			'room.offlineTitle' => '主播暂时不在',
			'room.offlineReplayReason' => '有回放可看，回到列表后可从卡片进入',
			'room.offlineReason' => '开播后这里会看到直播画面',
			'room.detailFailed' => '房间信息加载失败',
			'room.openRoom' => '进入直播间',
			'room.copyLink' => '复制房间链接',
			'room.linkCopied' => '链接已复制',
			'room.record' => '录制',
			'room.stopRecording' => '停止录制',
			'room.recordStarted' => '开始录制',
			'room.recordStopped' => '录制已停止',
			'room.recordFailed' => '录制操作失败',
			'room.autoRecordOn' => '开播自动录',
			'room.autoRecordOff' => '取消开播自动录',
			'room.autoRecordArmed' => ({required Object seconds}) => '已打开开播检测（每 ${seconds} 秒检查一次）；开播后自动录制',
			'room.autoRecordRemoved' => '已取消开播自动录制',
			'room.autoRecordFailed' => '无法加入开播检测，请稍后重试',
			'room.details' => '直播间详情',
			'room.detailsHint' => '查看直播间详情',
			'room.notice' => '公告',
			'room.introduction' => '简介',
			'room.roomNumber' => '房间号',
			'room.link' => '链接',
			'room.copy' => '复制',
			'room.copied' => '已复制',
			'room.replayed' => '之前发的',
			'room.share' => '分享',
			'room.shareFailed' => '分享失败',
			'room.openIn' => ({required Object platform}) => '在 ${platform} 打开',
			'room.openUnavailable' => '该平台没有提供可打开的链接',
			'room.openFailed' => '无法打开链接',
			'room.refreshRoom' => '刷新房间信息',
			'room.messageActions' => '弹幕操作',
			'room.blockUser' => '屏蔽此用户',
			'room.blockKeyword' => '屏蔽关键词…',
			'room.blockKeywordHint' => '输入要屏蔽的关键词',
			'room.userBlocked' => '已屏蔽该用户',
			'room.keywordBlocked' => '已屏蔽该关键词',
			'room.danmakuSettings' => '弹幕设置',
			'room.blockList' => '屏蔽列表',
			'room.superChats' => '超级聊天',
			'room.superChatEmpty' => '暂无超级聊天',
			'room.superChatFailed' => '超级聊天加载失败',
			'room.superChatCardMembership' => '会员',
			'room.superChatCardSubscription' => '订阅',
			'room.onlineViewers' => '在线',
			'room.popularity' => '热度',
			'room.totalViewers' => '累计观看',
			'room.startedAt' => ({required Object time}) => '${time} 开播',
			'room.danmakuList' => '弹幕',
			'room.danmakuSettingsDesc' => '控制飞行弹幕的显示、字号、速度与区域。',
			'room.block' => '屏蔽',
			'room.openExternal' => '在平台打开',
			'room.restrictionNeedsLogin' => '需要登录',
			'room.restrictionPaid' => '需要付费',
			'room.restrictionSubscribersOnly' => '仅限会员',
			'room.restrictionPrivate' => '私密房间',
			'room.restrictionAppOnly' => '需要在官方 App 观看',
			'room.restrictionRegionBlocked' => '当前地区不可观看',
			'room.restrictionPassword' => '需要密码',
			'room.restrictionAdult' => '年龄限制',
			'room.restrictionUnplayable' => '暂时无法播放',
			'room.orientation' => '画面方向',
			'room.orientationHint' => '默认跟随画面本身的比例；也可以为这个直播间固定为竖屏或横屏。',
			'room.orientationAutomatic' => '自动',
			'room.orientationPortrait' => '竖屏',
			'room.orientationLandscape' => '横屏',
			'room.orientationUpdated' => '画面方向已更新',
			'room.portraitFullscreen' => '竖屏全屏',
			'room.portraitFullscreenExit' => '退出竖屏全屏',
			'room.portraitFullscreenDisplay' => '画面模式',
			'room.portraitDisplayComplete' => '完整',
			'room.portraitDisplayAmbient' => '沉浸',
			'room.portraitDisplayBalanced' => '均衡',
			'room.portraitDisplayCover' => '铺满',
			'room.portraitDanmakuTitle' => '弹幕区域',
			'room.portraitDanmakuFollow' => '跟随全局',
			'room.portraitDanmakuUpper' => '上部 1/4',
			'room.portraitDanmakuReduced' => '减半',
			'room.portraitDanmakuHidden' => '隐藏',
			'room.portraitDiagnostics' => '竖屏诊断',
			'room.giftLineSent' => '送出',
			'room.giftLineSentTo' => ({required Object name}) => '送给 ${name}',
			'room.giftLineGifted' => '赠送',
			'room.giftLineTipped' => '打赏',
			'room.giftLineCount' => ({required Object count}) => '×${count}',
			'room.giftLineMonths' => ({required Object count}) => '×${count} 个月',
			'room.giftLineUnnamed' => '礼物',
			'room.giftLineNumbered' => ({required Object id}) => '礼物 ${id}',
			'room.giftValueYuan' => ({required Object value}) => '${value} 元',
			'room.giftValueGoldSeed' => ({required Object value}) => '${value} 金瓜子',
			'room.giftValueDiamond' => ({required Object value}) => '${value} 钻石',
			'room.giftValueRedBean' => ({required Object value}) => '${value} 红豆',
			'room.giftValuePoint' => ({required Object value}) => '${value} 点',
			'room.giftValueBits' => ({required Object value}) => '${value} Bits',
			'room.giftValueKicks' => ({required Object value}) => '${value} Kicks',
			'room.giftValueCheese' => ({required Object value}) => '${value} 奶酪',
			'room.giftValueStarBalloon' => ({required Object value}) => '${value} 星气球',
			'room.giftValueDouyinCoin' => ({required Object value}) => '${value} 抖币',
			'room.giftValueSixCoin' => ({required Object value}) => '${value} 六币',
			'room.giftValueAcCoin' => ({required Object value}) => '${value} AC币',
			'room.giftValueStarCoin' => ({required Object value}) => '${value} 星币',
			'room.giftValueHeart' => ({required Object value}) => '${value} 爱心',
			'room.giftValueNote' => ({required Object value}) => '${value} 音符',
			'room.collapseChat' => '收起聊天',
			'room.expandChat' => '展开聊天',
			'room.switchRoom' => '切换直播间',
			'room.switchOnAir' => '关注在播',
			'room.switchHistory' => '观看记录',
			'room.switchReplays' => '关注回放',
			'room.switchEmpty' => '没有可切换的直播间',
			'room.switchLive' => '直播中',
			'room.switchShowGrid' => '切换为网格',
			'room.switchShowList' => '切换为列表',
			'room.twitchCookieExpired' => 'Twitch Cookie 已失效，弹幕改为匿名接收；请重新填写。',
			'room.bilibiliGuestNames' => '当前以访客身份连接，B 站弹幕不会显示完整昵称',
			'room.bilibiliLoginExpired' => 'B 站登录似乎已失效：昵称全部被打码，请重新登录',
			'room.danmakuConnectFailed' => ({required Object reason}) => '弹幕连接失败（${reason}），直播画面不受影响',
			'search.idleTitle' => '搜索',
			'search.idleDescription' => '输入关键词，搜索房间、主播或分区。',
			'search.suggestionsTitle' => '搜索建议',
			'search.targetsLabel' => '搜索目标',
			'search.tabRooms' => '房间',
			'search.tabAnchors' => '主播',
			'search.tabAreas' => '分区',
			'search.noResultsTitle' => '没有找到相关结果',
			'search.noResultsDescription' => '换个关键词，或切换到其他搜索目标。',
			'search.unsupportedTitle' => '该平台不支持搜索',
			'search.unsupportedDescription' => '请切换到其他平台再试。',
			'search.liveBadge' => '直播中',
			'search.scopeAll' => '全部',
			'search.historyTitle' => '搜索历史',
			'search.clearHistory' => '清空',
			'search.webSearch' => '网页搜索',
			'search.webSearchTitle' => '网页搜索',
			'search.webSearchSelectPlatform' => '先选择一个平台再网页搜索',
			'search.webSearchUnavailable' => '该平台没有网页搜索',
			'search.webSearchUnsupportedTitle' => '当前平台不支持内嵌网页',
			'search.webSearchUnsupportedDescription' => '可以在系统浏览器中打开这个搜索页。',
			'search.webSearchOpenExternal' => '在浏览器中打开',
			'search.webSearchExternalFailed' => '无法打开系统浏览器',
			'search.webSearchFailed' => '页面加载失败',
			'search.sort' => '排序',
			'search.sortSmart' => '综合',
			'search.sortPlatform' => '按平台',
			'search.sortAudience' => '按人气',
			'search.sortFollowers' => '按关注',
			'search.includeOffline' => '显示离线',
			'search.filterTitle' => '筛选',
			'search.filterReset' => '重置',
			'search.linkDetected' => '检测到直播间链接',
			'search.linkOpen' => '打开直播间',
			'search.linkResolving' => '正在解析链接…',
			'search.linkFailed' => '没有解析到直播间',
			'settings.title' => '设置',
			'settings.navGeneral' => '浏览与窗口',
			'settings.navPersonalization' => '个性化',
			'settings.navLive' => '直播',
			'settings.navLiveSources' => '直播资源',
			'settings.navPlaybackPreferences' => '播放偏好',
			'settings.navSystem' => '系统',
			'settings.navDataCache' => '数据与缓存',
			'settings.navAppearance' => '外观',
			'settings.navPlayback' => '播放',
			'settings.navSites' => '站点',
			'settings.navIptv' => '节目单与更新',
			'settings.navVod' => '账号与清晰度',
			'settings.navData' => '观看数据',
			'settings.navBackup' => '备份与恢复',
			'settings.navAbout' => '版本与许可',
			'settings.navBrowsing' => '浏览',
			'settings.navWindow' => '窗口',
			'settings.navStartup' => '启动与退出',
			'settings.navAccounts' => '账号',
			'settings.navTheme' => '主题与颜色',
			'settings.navTypography' => '字体与字号',
			'settings.qualityAudioTitle' => '画质与声音',
			'settings.qualityAudioDescription' => '默认清晰度、音量与后台播放。',
			'settings.kernelAdvancedTitle' => '内核高级参数',
			'settings.kernelAdvancedDescription' => '输出驱动、同步、缩放与解码高级项，仅 mpv 内核生效。',
			'settings.webdavSyncTitle' => 'WebDAV 网盘',
			'settings.webdavSyncDescription' => '多个 WebDAV 账号的文件管理：浏览目录、上传下载、重命名移动，以及备份的发送与恢复。',
			'settings.closeExitGroup' => '关闭与退出',
			'settings.navQuality' => '画质',
			'settings.navAudio' => '音频与音量',
			'settings.navPicture' => '画面与浮窗',
			'settings.navFloatingWindow' => '小窗与画中画',
			'settings.groupBasics' => '基础设置',
			'settings.groupContent' => '站点',
			'settings.groupData' => '数据',
			'settings.groupAbout' => '关于',
			'settings.groupIptv' => 'IPTV',
			'settings.groupVod' => 'Bilibili 视频',
			'settings.generalDescription' => '浏览、窗口与启动设置。',
			'settings.appearanceDescription' => '主题、字体与配色。',
			'settings.personalizationDescription' => '主题、外观、背景与导航。',
			'settings.liveSettingsDescription' => '直播资源、弹幕与录制。',
			'settings.liveSourcesDescription' => '平台、账号与自动刷新。',
			'settings.playbackSettingsDescription' => '播放偏好与播放器内核。',
			'settings.systemDescription' => '浏览、网络、诊断、数据与备份。',
			'settings.dataCacheDescription' => '观看数据与封面缓存。',
			'settings.personalizationChooseTheme' => '选择要应用的主题',
			'settings.personalizationSettings' => '个性化设置',
			'settings.playbackDescription' => '画质、音频、画面与播放器行为。',
			'settings.sitesDescription' => '默认站点与首选平台；平台显示、排序与账号登录在子页。',
			'settings.iptvDescription' => '节目单自动更新与来源同步。',
			'settings.vodDescription' => 'Bilibili 账号、默认清晰度与视频站行为。',
			'settings.dataDescription' => '直播观看历史与关注数据。',
			'settings.backupDescription' => '本地备份、恢复与 WebDAV 同步。',
			'settings.aboutDescription' => '版本、开源许可与项目链接。',
			'settings.browsingPageDescription' => '卡片间距、关注页密度与房间卡片。',
			'settings.windowPageDescription' => '标题栏、直播间窗口、关闭行为、窗口尺寸与显示刷新率。',
			'settings.startupPageDescription' => '开机启动、启动动画、关闭窗口行为与定时关机。',
			'settings.accountsPageDescription' => '各平台账号与授权。',
			'settings.themePageDescription' => '主题模式、配色、对比度、字体与字号、语言。',
			'settings.typographyPageDescription' => '字体、文本缩放与各级字号。',
			'settings.qualityPageDescription' => 'Wi-Fi 与移动网络下的默认清晰度。',
			'settings.audioPageDescription' => '默认音量、静音与后台音频。',
			'settings.picturePageDescription' => '画面比例、悬浮窗与画中画。',
			'settings.floatingWindowPageDescription' => '应用内悬浮窗与系统画中画的大小、位置与置顶。',
			'settings.pictureDisplayGroup' => '画面显示',
			'settings.floatWindowGroup' => '应用内悬浮窗',
			'settings.pipGroup' => '系统画中画',
			'settings.playbackComingSoon' => '播放设置将在播放器接入后开放。',
			'settings.sitesComingSoon' => '站点管理与账号登录即将接入。',
			'settings.dataComingSoon' => '数据管理即将接入。',
			'settings.appearance' => '外观',
			'settings.themeMode' => '主题',
			'settings.themeModeSystem' => '跟随系统',
			'settings.themeModeLight' => '浅色',
			'settings.themeModeDark' => '深色',
			'settings.followBackgroundTone' => '跟随背景明暗',
			'settings.followBackgroundToneDescription' => '有背景时按壁纸明暗自动选择浅色或深色主题；手动选择主题会自动关闭此跟随。',
			'settings.language' => '语言',
			'settings.about' => '关于',
			'settings.refreshRateGroup' => '显示',
			'settings.refreshRateDisplay' => '刷新率',
			'settings.refreshRateRefresh' => '重新读取刷新率',
			'settings.refreshRateCurrentMax' => ({required Object current, required Object max}) => '当前 ${current} · 最高 ${max}',
			'settings.refreshRateUnknown' => '未知',
			'settings.refreshRateLowPower' => '低电量模式',
			'settings.refreshRateMode' => '刷新率模式',
			'settings.refreshRateModeDesc' => '节能交给系统自动调；均衡只在触摸或滚动时升频，停手 1.5 秒后释放；性能恒定最高。平台不支持的选项不显示。',
			'settings.refreshRatePowerSaving' => '节能',
			'settings.refreshRateBalanced' => '均衡（交互自适应）',
			'settings.refreshRatePerformance' => '性能（最高刷新率）',
			'settings.refreshRateReadOnly' => '此平台只支持读取刷新率',
			'settings.refreshRateReadOnlyDesc' => '系统未开放刷新率接口；显示的是显示器实际值。',
			'settings.refreshRateMatchVideo' => '播放时匹配视频帧率',
			'settings.refreshRateMatchVideoDesc' => '刷新率取视频帧率的整数倍，画面更匀；只在不会闪屏时切换，源未声明帧率则不动。',
			'settings.refreshRateMatchVideoSingle' => ({required Object rate}) => '这台设备只有 ${rate} Hz，用不上',
			'settings.refreshRateMatchVideoUnsupported' => '此设备的系统接口不支持按视频内容切换刷新率',
			'settings.updateGroup' => '更新',
			'settings.autoCheckUpdate' => '启动时自动检查更新',
			'settings.autoCheckUpdateDesc' => '每次启动静默读取一次发布源；结果在“关于”里显示，失败不打扰。',
			'settings.windowSize' => '窗口尺寸',
			'settings.windowSizeDesc' => '启动时使用的窗口大小；应用后立即居中并记住。',
			'settings.windowWidth' => '宽度',
			'settings.windowHeight' => '高度',
			'settings.windowSizeRangeHint' => '宽度 400–16384，高度 300–16384（逻辑像素）。',
			'settings.windowSizeOutOfRange' => '尺寸超出范围：宽 400–16384，高 300–16384。',
			'settings.windowSizeApplyFailed' => '窗口尺寸应用失败。',
			'settings.windowSizeApplied' => '窗口尺寸已应用。',
			'settings.startup' => '开机启动',
			'settings.startupDesc' => '登录系统后自动打开 Pure Live；开关读取真实启动项。',
			'settings.startupFailed' => '开机启动设置失败',
			'settings.splashAnimation' => '启动动画',
			'settings.splashAnimationDesc' => '启动时先显示应用标记，再进入主界面；下次启动生效。',
			'settings.configPreview' => '配置预览',
			'settings.configPreviewDesc' => '备份所携带的设置项，只读；JSON 格式，可复制。',
			'settings.configPreviewCopy' => '复制',
			'settings.configPreviewCopied' => '配置已复制',
			'settings.autoShutdownGroup' => '定时关机',
			'settings.autoShutdown' => '启用定时关机',
			'settings.autoShutdownDesc' => '倒计时结束后自动退出应用；关闭后立即取消。',
			'settings.autoShutdownDuration' => '关机倒计时',
			'settings.autoShutdownRemaining' => ({required Object time}) => '剩余 ${time}',
			'settings.autoShutdownMinutes' => ({required Object count}) => '${count} 分钟',
			'settings.autoShutdownPreset' => ({required Object minutes}) => '${minutes} 分钟',
			'settings.autoShutdownCustom' => '自定义分钟数',
			'settings.autoShutdownRange' => '范围 1–525600 分钟。',
			'settings.autoShutdownInvalid' => '请输入 1–525600 之间的分钟数。',
			'settings.autoShutdownSaved' => '关机时长已设置。',
			'settings.refreshRateFailed' => '刷新率读取失败',
			'settings.refreshRateApplyFailed' => '刷新率请求未生效',
			'settings.refreshRateMultiMonitor' => ({required Object count}) => '检测到 ${count} 台显示器',
			'settings.refreshRateMultiMonitorDesc' => '刷新率读数来自当前窗口所在的那一台显示器。',
			'settings.sitesDisplay' => '平台显示',
			'settings.sitesDisplayDesc' => '关闭的平台不再出现在热门、分区、关注与搜索的平台列表里。',
			'settings.sitesAllShown' => '全部平台都在显示中。',
			'settings.sitesShowAll' => '全部显示',
			'settings.sitesShowAllDesc' => '把关闭的平台全部打开。',
			'settings.dataClearHistory' => '清空观看历史',
			'settings.dataClearHistoryDesc' => '删除全部观看记录，不可恢复。',
			'settings.dataExportFollows' => '导出关注',
			'settings.dataExportFollowsDesc' => '把关注列表复制到剪贴板（JSON）。',
			'settings.dataImportFollows' => '导入关注',
			'settings.dataImportFollowsDesc' => '从剪贴板读取此前导出的关注（JSON）。',
			'settings.dataDone' => '已完成',
			'settings.dataBadData' => '剪贴板内容无法识别',
			'settings.dataEmpty' => '没有可导出的关注',
			'settings.confirmClearTitle' => '清空观看历史？',
			'settings.confirmClearDesc' => '全部观看记录将被删除，此操作不可恢复。',
			'settings.confirm' => '清空',
			'settings.aboutVersion' => '版本',
			'settings.aboutProject' => '项目主页',
			'settings.aboutLicense' => '开源许可',
			'settings.aboutLicenseDesc' => '查看本应用使用的开源组件。',
			'settings.themeSeed' => '主题色',
			'settings.themeSeedSystem' => '跟随系统取色',
			'settings.themeSeedDescription' => '用于按钮、选中态和强调色。',
			'settings.themeSeedDynamic' => '跟随系统动态取色',
			'settings.themeSeedDynamicDescription' => '动态取色开启时由系统决定；关闭后可自选主题色。',
			'settings.dynamicColor' => '动态取色',
			'settings.dynamicColorDescription' => '使用系统壁纸或强调色生成主题，覆盖当前主题色。',
			'settings.liquidGlass' => '液体玻璃',
			'settings.liquidGlassDescription' => '首页底栏悬浮成毛玻璃；4 GB 以下机型只半透明不模糊。',
			'settings.themeColorTitle' => '主题色',
			'settings.themeColorPresets' => '预设颜色',
			'settings.themeColorCustom' => '自定义颜色',
			'settings.themeColorHex' => '十六进制颜色',
			'settings.themeColorHexInvalid' => '请输入 6 位或 8 位十六进制颜色，例如 #2196F3。',
			'settings.themeColorHue' => '色相',
			'settings.themeColorSaturation' => '饱和度与明度',
			'settings.seedBlue' => '蓝',
			'settings.seedNavy' => '藏青',
			'settings.seedGraphite' => '石墨',
			'settings.seedOxblood' => '绛红',
			'settings.seedForest' => '森绿',
			'settings.seedIndigo' => '靛蓝',
			'settings.corners' => '圆角',
			'settings.cornersStandard' => '标准',
			'settings.cornersSharp' => '锐利',
			'settings.cornersSoft' => '柔和',
			'settings.cornersPill' => '胶囊',
			'settings.density' => '控件密度',
			'settings.densitySystem' => '跟随平台',
			'settings.densityCompact' => '紧凑',
			'settings.densityTouch' => '触控',
			'settings.languageSystem' => '跟随系统',
			'settings.languageSimplifiedChinese' => '简体中文',
			'settings.languageEnglish' => 'English',
			'settings.refreshGroup' => '刷新',
			'settings.followsAutoRefresh' => '关注自动刷新',
			'settings.followsAutoRefreshDesc' => '停留在关注页时按间隔刷新关注列表。',
			'settings.liveAlert' => '开播提醒',
			'settings.liveAlertDesc' => '关注的主播开播时发系统通知；运行时每 15 分钟检查。',
			'settings.liveAlertTags' => '提醒标签',
			'settings.liveAlertTagsDesc' => '只提醒带有所选标签的关注；不选则覆盖全部关注。',
			'settings.liveAlertTagsAll' => '全部关注',
			'settings.liveAlertTagsNone' => '还没有标签；提醒将覆盖全部关注。',
			'settings.liveAlertTagCount' => ({required Object selected}) => '已选 ${selected} 个',
			'settings.liveAlertFallbackTitle' => ({required Object platform, required Object roomId}) => '${platform} 房间 ${roomId}',
			'settings.liveAlertNotificationBody' => ({required Object platform}) => '正在 ${platform} 直播',
			'settings.refreshInterval' => '刷新间隔',
			'settings.historyLimit' => '观看历史上限',
			'settings.historyLimitDesc' => '超过上限的最早记录会被删除。',
			'settings.navNetwork' => '网络',
			'settings.networkDescription' => '应用代理与传输行为。',
			'settings.proxy' => '应用代理',
			'settings.proxyHost' => '主机',
			'settings.proxyHostDesc' => '代理服务器的主机名或地址。',
			'settings.proxyPort' => '端口',
			'settings.proxyPortDesc' => '代理服务器监听的端口。',
			'settings.proxyModeOff' => '不使用代理',
			'settings.proxyModeOffDesc' => '点播、节目单与备份的请求都直连。',
			'settings.proxyModeSystem' => '跟随系统代理',
			'settings.proxyModeSystemDesc' => '使用操作系统自己配置的 HTTP 代理，没有配置时直连。',
			'settings.proxyModeManual' => '手动代理',
			'settings.proxyModeManualDesc' => '使用下方填写的主机与端口。',
			'settings.proxySystemProbing' => '正在检测系统代理…',
			'settings.proxySystemResolved' => ({required Object host}) => '系统代理：${host}',
			'settings.proxySystemNone' => '未检测到系统代理，当前直连。',
			'settings.proxySystemNotExpressible' => '系统代理是 PAC 脚本或非 HTTP 代理，无法自动套用；请改用手动代理。',
			'settings.proxySystemUnsupported' => '当前平台没有可读的系统代理设置；请改用手动代理。',
			'settings.proxySystemFailed' => '系统代理检测失败，当前直连。',
			'settings.proxySystemRecheck' => '重新检测系统代理',
			'settings.proxySystemRecheckDesc' => '代理客户端在启动后才开启或关闭时，不必重启应用。',
			'settings.githubMirrorTitle' => 'GitHub 加速',
			'settings.githubMirrorMode' => '下载方式',
			'settings.githubMirrorModeDesc' => '字体等 GitHub 资源从哪个地址下载。',
			'settings.githubMirrorOff' => '默认（不加速）',
			'settings.githubMirrorOfficial' => '官方源 · 可能较慢',
			'settings.githubMirrorCustom' => '自定义…',
			'settings.githubMirrorCustomDetail' => '自填镜像域名',
			'settings.githubMirrorCustomDomain' => '自定义加速域名',
			'settings.githubMirrorCustomDesc' => '以 https:// 开头，直接拼在原始地址前面。',
			'settings.githubMirrorHint' => '留空回退直连：下载失败自动回退直连兜底。',
			'settings.githubMirrorList' => '镜像地址',
			'settings.githubMirrorRefresh' => '从远程更新',
			'settings.githubMirrorRefreshing' => '正在获取远程镜像…',
			'settings.githubMirrorNever' => '尚未获取远程镜像。',
			'settings.githubMirrorUpdated' => ({required Object time}) => '远程更新于 ${time}',
			'settings.githubMirrorFailed' => ({required Object error}) => '远程获取失败：${error}',
			'settings.githubMirrorAdd' => '添加镜像地址',
			'settings.githubMirrorAddTitle' => '添加镜像地址',
			'settings.githubMirrorAddDesc' => '填一个 https:// 开头的镜像域名，作为下载前缀。',
			'settings.githubMirrorAddInvalid' => '地址无效：需要以 https:// 开头',
			'settings.githubMirrorEmpty' => '没有可用的镜像地址。',
			'settings.githubMirrorRestore' => '恢复内置镜像',
			'settings.githubMirrorSourceBuiltin' => '内置',
			'settings.githubMirrorSourceRemote' => '远程',
			'settings.githubMirrorSourceCustom' => '自定义',
			'settings.githubMirrorStrategyPrefix' => '前缀代理',
			'settings.githubMirrorStrategyRaw' => '替换 Raw 域名',
			'settings.githubMirrorStrategyJsdelivr' => 'jsDelivr 路径',
			'settings.toolsOrder' => '工具区排序',
			'settings.toolsOrderDesc' => '侧栏分区线下方工具的显示顺序。',
			'settings.moveUp' => '上移',
			'settings.moveDown' => '下移',
			'settings.navShield' => '弹幕屏蔽',
			'settings.shieldDescription' => '屏蔽关键词、用户与相似弹幕，直播间弹幕按此过滤。',
			'settings.danmakuFilter' => '弹幕过滤',
			'settings.danmakuFilterDesc' => '关键词、用户与相似弹幕过滤。',
			'settings.danmakuDisplayGroup' => '弹幕显示',
			'settings.danmakuList' => '弹幕列表',
			'settings.showFlyingDanmaku' => '在画面上显示飞行弹幕',
			'settings.showFlyingDanmakuDesc' => '关闭后弹幕只在聊天列表里显示。',
			'settings.danmakuInteractionGroup' => '画面弹幕交互',
			'settings.styleTapInteraction' => '点击画面弹幕查看操作',
			'settings.styleTapInteractionDesc' => '点按弹幕打开面板，可复制或屏蔽；关闭后点按画面只切换控制条。',
			'settings.styleLongPressInteraction' => '长按画面弹幕查看操作',
			'settings.styleLongPressInteractionDesc' => '长按画面上的弹幕打开同一操作面板；关闭后长按不再命中弹幕。',
			'settings.danmakuStyleGroup' => '弹幕样式',
			'settings.danmakuStyleDescription' => '弹幕的字体、大小、速度、区域、描边与帧率。',
			'settings.danmakuDisplayDescription' => '聊天列表显示谁、显示什么、怎么排。',
			'settings.danmakuPresetApplied' => '弹幕预设已应用',
			'settings.danmakuPreviewHint' => '这是真实弹幕引擎按当前设置画的样例；改动会立刻反映在这里。',
			'settings.danmakuPreview' => '弹幕预览',
			'settings.chatListGroup' => '聊天列表内容',
			'settings.chatListLayoutGroup' => '聊天列表排版',
			'settings.danmakuFont' => '弹幕字体',
			'settings.danmakuFontDescription' => '画面飞行弹幕使用的字体；聊天列表保持界面字体。',
			'settings.danmakuFontManagerDescription' => 'MiSans 随应用提供；国内字体来自免费商用库，国外来自 Google Fonts，选中即应用于飞行弹幕。',
			'settings.styleFontSize' => '字体大小',
			'settings.styleFontSizeDesc' => '画面飞行弹幕字形的高度，单位像素。',
			'settings.styleFontWeight' => '字体粗细',
			'settings.styleFontWeightDesc' => '字形的粗细；400 为常规，700 为加粗。',
			'settings.styleLetterSpacing' => '文字间距',
			'settings.styleLetterSpacingDesc' => '字符之间额外增加的间距，单位像素。',
			'settings.styleWeightThin' => '极细',
			'settings.styleWeightExtraLight' => '很细',
			'settings.styleWeightLight' => '偏细',
			'settings.styleWeightNormal' => '正常',
			'settings.styleWeightMedium' => '稍粗',
			'settings.styleWeightSemiBold' => '中粗',
			'settings.styleWeightBold' => '粗体',
			'settings.styleWeightExtraBold' => '很粗',
			'settings.styleWeightBlack' => '特粗',
			'settings.styleSpeed' => '速度',
			'settings.styleSpeedDesc' => '弹幕横穿画面的速度，单位像素每秒。',
			'settings.styleArea' => '画面顶部占用高度',
			'settings.styleAreaDesc' => '弹幕最多占用画面高度的比例（0–100%）。',
			'settings.fixedTopTitle' => '顶部固定弹幕',
			'settings.fixedTopDescription' => '平台的置顶弹幕停在画面上方；关闭后只在聊天列表里显示。',
			'settings.fixedBottomTitle' => '底部固定弹幕',
			'settings.fixedBottomDescription' => '平台的置底弹幕停在画面下方；关闭后只在聊天列表里显示。',
			'settings.fixedDurationTitle' => '固定弹幕停留时长',
			'settings.fixedDurationDescription' => '顶部与底部固定弹幕停留的时间，2–10 秒。',
			'settings.styleOpacity' => '不透明度',
			'settings.styleOpacityDesc' => '弹幕相对画面的厚实程度；100% 时完全遮住弹幕。',
			'settings.styleStroke' => '描边',
			'settings.styleStrokeDesc' => '给弹幕文字加描边，浅色画面上更清楚。',
			'settings.styleStrokeWidth' => '描边宽度',
			'settings.styleStrokeWidthDesc' => '描边开启时文字外圈的粗细（0–4 像素）。',
			'settings.styleFpsFollow' => '弹幕帧率跟随界面刷新率',
			'settings.styleFpsFollowDesc' => '跟随「通用」里的省电、均衡或最高档位；关闭后可以手动设帧率。',
			'settings.styleFps' => '弹幕帧率',
			'settings.styleFpsDesc' => '飞行层每秒重绘的次数；越高越顺滑，也更耗性能。',
			'settings.styleFpsValue' => ({required Object count}) => '${count} FPS',
			'settings.styleMaxVisible' => '同屏最大弹幕条数',
			'settings.styleMaxVisibleDesc' => '同屏弹幕最多几条，默认 48；少些更清楚省电。',
			'settings.styleMaxVisibleValue' => ({required Object count}) => '${count} 条',
			'settings.styleMassMode' => '海量模式',
			'settings.styleMassModeDesc' => '同屏上限提到 1000 条并用实时渲染，适合超密弹幕。',
			'settings.styleItalic' => '斜体',
			'settings.styleTextColor' => '文字颜色',
			'settings.styleStrokeColor' => '描边颜色',
			'settings.styleShadow' => '文字阴影',
			'settings.styleShadowColor' => '阴影颜色',
			'settings.styleShadowBlur' => '阴影模糊',
			'settings.styleShadowOffsetX' => '阴影水平偏移',
			'settings.styleShadowOffsetY' => '阴影垂直偏移',
			'settings.danmakuLaneGroup' => '轨道与安全区',
			'settings.styleTrackHeight' => '轨道高度',
			'settings.styleEmojiSize' => '表情大小',
			'settings.styleOverlapGap' => '弹幕安全间距',
			'settings.styleSafeArea' => '避开屏幕安全区',
			'settings.danmakuQueueGroup' => '队列与性能',
			'settings.styleMaxPending' => '等待队列上限',
			'settings.styleMaxPendingAge' => '队列最长等待',
			'settings.styleEmitInterval' => '发送间隔',
			'settings.styleRasterize' => '文字光栅化',
			'settings.styleBarragePool' => '弹幕对象池',
			'settings.stylePictureCache' => '图片缓存数量',
			'settings.styleTextCache' => '文字缓存数量',
			'settings.styleRasterCache' => '光栅缓存上限',
			'settings.danmakuColorWhite' => '白色',
			'settings.danmakuColorBlack' => '黑色',
			'settings.danmakuColorRed' => '红色',
			'settings.danmakuColorOrange' => '橙色',
			'settings.danmakuColorYellow' => '黄色',
			'settings.danmakuColorGreen' => '绿色',
			'settings.danmakuColorCyan' => '青色',
			'settings.danmakuColorBlue' => '蓝色',
			'settings.danmakuColorPurple' => '紫色',
			'settings.danmakuColorPink' => '粉色',
			'settings.danmakuSaveGroup' => '弹幕文件',
			'settings.danmakuSaveDescription' => '录制与下载视频时，弹幕按所选格式各存一份同名文件；关闭全部选项时保留 XML。',
			'settings.danmakuSaveFormats' => '保存格式',
			'settings.danmakuFormatXml' => 'B站 XML',
			'settings.danmakuFormatJson' => 'B站 JSON',
			_ => null,
		} ?? switch (path) {
			'settings.danmakuFormatAss' => 'ASS 字幕',
			'settings.danmakuFormatSrt' => 'SRT 字幕',
			'settings.danmakuFormatTxt' => '纯文本',
			'settings.pipDanmakuScaleAuto' => '小窗弹幕比例自动',
			'settings.pipDanmakuScaleAutoDesc' => '按小窗宽度自动缩小弹幕，不超过主弹幕大小；关闭用下方固定比例。',
			'settings.pipDanmakuScale' => '小窗弹幕比例',
			'settings.pipDanmakuScaleDesc' => '关闭自动小窗比例时使用的固定倍率。',
			'settings.styleReset' => '恢复默认',
			'settings.danmakuPresetBest' => '顶部 20% · 均衡',
			'settings.danmakuPresetComfort' => '顶部 35% · 舒适',
			'settings.danmakuPresetDense' => '顶部 55% · 高密度',
			'settings.danmakuPresetFull' => '全屏全量',
			'settings.danmakuPresetHint' => '全屏全量=弹幕铺满整个画面；其它预设只占用顶部区域',
			'settings.danmakuPresetCustom' => '自定义',
			'settings.preset' => '预设',
			'settings.prefScope' => '设置生效范围',
			'settings.prefScopeDesc' => '选择只在本窗口生效，还是应用到主窗口与全部直播间窗口。',
			'settings.prefScopeLocal' => '仅本窗口',
			'settings.prefScopeGlobal' => '所有窗口',
			'settings.windowGroup' => '窗口',
			'settings.roomWindow' => '直播间在独立窗口打开',
			'settings.roomWindowDesc' => '每个直播间一个独立窗口；关闭后在主窗口内浏览。仅桌面端。',
			'settings.closeAction' => '关闭窗口时',
			'settings.closeActionDesc' => '隐藏到托盘时应用保持运行，点托盘图标恢复窗口。',
			'settings.closeQuit' => '退出应用',
			'settings.closeMinimise' => '最小化到任务栏',
			'settings.closeHideToTray' => '隐藏到托盘',
			'settings.noExitConfirm' => '退出不再询问',
			'settings.noExitConfirmDescription' => '开启后点关闭直接执行上面的行为；关闭则每次先确认。',
			'settings.closeWindowTitle' => '关闭窗口',
			'settings.closeWindowQuestion' => '要退出应用，还是最小化后继续运行？',
			'settings.closeDontAskAgain' => '不再询问',
			'settings.trayShow' => '显示主窗口',
			'settings.trayHide' => '隐藏到托盘',
			'settings.trayScreenshot' => '截图',
			'settings.traySoundOn' => '打开声音',
			'settings.traySoundOff' => '关闭声音',
			'settings.trayScreenshotSaved' => ({required Object path}) => '已保存到 ${path}',
			'settings.trayScreenshotFailed' => '截图失败：没有正在播放的房间或引擎不支持',
			'settings.font' => '字体',
			'settings.fontDescription' => 'MiSans 随应用打包并默认使用，也可换国内或国外字体。',
			'settings.fontDefault' => 'MiSans（默认）',
			'settings.fontSystemChinese' => '系统字体',
			'settings.fontRegionDomestic' => '国内',
			'settings.fontRegionOverseas' => '国外',
			'settings.fontManagerTitle' => '字体管理',
			'settings.fontManagerSubtitle' => '选择你喜欢的字体，让界面更符合你的审美。',
			'settings.fontManagerSample' => '纯粹直播',
			'settings.fontManagerLocal' => '本地字体',
			'settings.fontManagerMore' => '下载更多字体',
			'settings.fontManagerPreviewTitle' => '字体预览',
			'settings.fontManagerPreviewAction' => '预览',
			'settings.fontManagerPreviewPending' => '下载后可预览',
			'settings.fontManagerGoogle' => 'Google 字体',
			'settings.fontManagerDescription' => 'MiSans 随应用提供；国内字体来自免费商用库，国外来自 Google Fonts，选中即应用于全部界面。',
			'settings.fontManagerSystemDescription' => ({required Object face}) => '由系统提供，本机使用 ${face}。',
			'settings.fontManagerBundledNote' => '随应用打包，所有平台默认使用。',
			'settings.fontManagerGoogleNote' => '首次选择时从 Google Fonts 获取并缓存在本机，之后离线可用。',
			'settings.fontManagerFreeFontNote' => '来自免费商用字体库，首次使用时下载并保存在本机。',
			'settings.fontManagerInUse' => '使用中',
			'settings.fontManagerDefaultBadge' => '默认',
			'settings.fontManagerCurrent' => '当前字体',
			'settings.fontManagerReset' => '恢复默认',
			'settings.fontManagerFilterAll' => '全部',
			'settings.fontManagerCategory' => '分类',
			'settings.fontManagerCount' => ({required Object count}) => '共 ${count} 款字体',
			'settings.fontManagerTagBundled' => '随应用打包',
			'settings.fontManagerSourceFreeFont' => '免费字体库',
			'settings.fontManagerUse' => '使用',
			'settings.fontManagerDownloadAndUse' => '下载并使用',
			'settings.fontManagerDownloading' => ({required Object percent}) => '下载中 ${percent}%',
			'settings.fontManagerDownloadFailed' => '下载失败',
			'settings.fontManagerDownloaded' => '已下载',
			'settings.fontManagerNotDownloaded' => '未下载',
			'settings.fontManagerDeleteFont' => '删除已下载的字体',
			'settings.fontManagerDeleteQuestion' => ({required Object name}) => '删除「${name}」在本机的字体文件？之后可再次下载。',
			'settings.fontManagerNoResults' => '没有找到匹配的字体。',
			'settings.fontManagerFilterLabel' => '筛选字体',
			'settings.fontManagerSearchPlaceholder' => '搜索字体名称',
			'settings.fontManagerPageLabel' => '字体列表翻页',
			'settings.fontManagerColumnSource' => '来源',
			'settings.fontManagerColumnSize' => '大小',
			'settings.fontManagerColumnFont' => '字体',
			'settings.fontManagerColumnState' => '状态',
			'settings.fontManagerColumnActions' => '操作',
			'settings.fontManagerScriptChinese' => '中文字体',
			'settings.fontManagerCopyName' => '复制字体名称',
			'settings.fontManagerDownload' => '下载',
			'settings.fontManagerDownloadingShort' => '下载中',
			'settings.fontManagerDetails' => '显示与设置',
			'settings.fontManagerLoadedCount' => ({required Object shown, required Object total}) => '已加载 ${shown} / ${total}',
			'settings.fontManagerLoadingMore' => '正在加载更多…',
			'settings.fontCategoryHeiti' => '黑体',
			'settings.fontCategorySongti' => '宋体',
			'settings.fontCategoryKaiti' => '楷体',
			'settings.fontCategoryArt' => '艺术体',
			'settings.fontCategoryHandwriting' => '手绘体',
			'settings.fontCategoryEnglish' => '英文',
			'settings.fontCategorySerif' => '衬线',
			'settings.fontCategorySansSerif' => '无衬线',
			'settings.fontCategoryDisplay' => '展示',
			'settings.fontCategoryMonospace' => '等宽',
			'settings.fontCategoryOther' => '其他',
			'settings.textScale' => '文本缩放',
			'settings.textScaleDescription' => '按比例放大或缩小整个应用的文字；100% 为平台原始大小。',
			'settings.backHome' => '返回应用',
			'settings.navCache' => '缓存',
			'settings.cacheDescription' => '封面与头像的磁盘缓存、清理上限。',
			'settings.cacheSize' => '当前缓存大小',
			'settings.cacheRefresh' => '刷新',
			'settings.cacheClear' => '清除缓存',
			'settings.cacheClearDesc' => '删除所有已缓存的封面、头像与站点图标。',
			'settings.cacheCleared' => '缓存已清除',
			'settings.cacheLimit' => '自动清理上限',
			'settings.cacheLimitDesc' => '超过上限时按最旧优先删除；关闭则只清理过期项。',
			'settings.cacheLimitOff' => '不自动清理',
			'settings.cacheHint' => '封面与头像会在本机缓存 30 天，过期或超限时自动清理。',
			'settings.preferPlatform' => '首选平台',
			'settings.preferPlatformDesc' => '热门与分区的优先平台，也是分区列表与搜索的起始平台。',
			'settings.preferPlatformFilterHint' => '搜索平台',
			'settings.preferPlatformFilterEmpty' => '没有匹配的平台',
			'settings.sitesOrderReset' => '恢复默认顺序',
			'settings.sitesOrderResetDesc' => '平台回到内置的排列顺序；显示开关不受影响。',
			'settings.groupInterface' => '界面',
			'settings.groupSources' => '直播来源',
			'settings.groupPlayback' => '播放',
			'settings.groupGeneral' => '通用',
			'settings.groupApp' => '应用',
			'settings.groupLive' => '直播',
			'settings.navNavigation' => '导航栏',
			'settings.navRefresh' => '自动刷新',
			'settings.navProxy' => '网络代理',
			'settings.navPlatforms' => '平台与账号',
			'settings.navigationDescription' => '首页菜单与工具区各自的显示与排序。',
			'settings.refreshDescription' => '关注列表与直播缩略图的自动刷新。',
			'settings.proxyDescription' => '应用级网络代理，所有站点请求都走它。',
			'settings.platformsDescription' => '平台显示、排列顺序与账号登录。',
			'settings.searchSettings' => '搜索设置',
			'settings.searchNoResults' => '没有匹配的设置',
			'settings.searchResults' => '搜索结果',
			'settings.browseLayoutGroup' => '卡片布局',
			'settings.browseColumns' => '每行卡片数',
			'settings.browseAuto' => '自动',
			'settings.crossSpacing' => '列间距',
			'settings.crossSpacingDescription' => '卡片网格里左右两张卡片之间的距离。',
			'settings.mainSpacing' => '行间距',
			'settings.mainSpacingDescription' => '卡片网格里上下两行之间的距离。',
			'settings.navVideo' => '视频',
			'settings.vodPlayback' => '视频播放',
			'settings.navVodPlayback' => '播放设置',
			'settings.navVodInterface' => '界面设置',
			'settings.vodInterfaceDescription' => '视频页显示哪些内容：详情区的开关。',
			'settings.vodPlaybackDescription' => '默认倍速、一集播完后的动作，以及播放器下方显示的详情。',
			'settings.groupMusic' => '音乐',
			'settings.navMusic' => '音乐',
			'settings.musicSettingsDescription' => '播放、歌词、桌面歌词、下载、音源、快捷键与同步。',
			'settings.navMusicPlay' => '播放',
			'settings.musicPlaybackDescription' => '音源、音质与播放、列表行为。',
			'settings.navMusicSources' => '自定义源',
			'settings.musicSourcesDescription' => '导入并管理 lx 风格的自定义音源脚本。',
			'settings.navMusicDownload' => '下载',
			'settings.musicDownloadDescription' => '下载目录、文件格式、命名与标签处理。',
			'settings.navMusicLyric' => '歌词',
			'settings.musicLyricDescription' => '歌词的翻译、音译与延迟。',
			'settings.navMusicDesktopLyric' => '桌面歌词',
			'settings.navMusicHotkeys' => '快捷键',
			'settings.navMusicSync' => '同步',
			'settings.navMusicEq' => '音效',
			'settings.musicHotkeysDescription' => '播放、音量与收藏的快捷键。',
			'settings.musicSyncDescription' => '与 lx-music 桌面端服务端同步歌单。',
			'settings.musicEqDescription' => '音效总开关、内置预设、十段均衡器与预放增益。',
			'settings.musicDesktopLyricDescription' => '悬浮歌词的开关、锁定、字号、颜色与对齐。',
			'settings.vodQuality' => '默认清晰度',
			'settings.vodQualityDesc' => '打开视频优先请求的清晰度；未登录 B 站可能只有 720P。',
			'settings.vodQuality720' => '720P',
			'settings.vodQuality1080' => '1080P',
			'settings.vodQuality1080Plus' => '1080P+',
			'settings.vodQuality4K' => '4K',
			'settings.iptvGuideUpdates' => '节目单更新',
			'settings.navIptvBrowse' => '换台与显示',
			'settings.iptvBrowseDescription' => '频道号、换台方向、时间和当前节目行怎么显示。',
			'settings.navIptvGroups' => '分组显示',
			'settings.iptvGroupsDescription' => '决定哪些分组出现在频道列表和换台里。',
			'settings.iptvSyncDesc' => '重新下载网络播放列表与节目单；本地来源不受影响。',
			'settings.navDanmaku' => '弹幕',
			'settings.navMiniDanmaku' => '小窗弹幕',
			'settings.navKernel' => '播放器内核',
			'settings.navRecording' => '录制',
			'settings.videoDescription' => '画质、音量与画面比例。',
			'settings.danmakuDescription' => '弹幕显示、样式与屏蔽。',
			'settings.miniDanmakuDescription' => '画中画小窗里的弹幕。',
			'settings.kernelDescription' => '内核、代理、硬件解码、预设与画质增强。',
			'settings.kernelCurrent' => '当前内核',
			'settings.kernelOnlyOne' => '当前平台只有 mpv 内核。',
			'settings.kernelSwitchHint' => '切换后新打开的播放器使用该内核。',
			'settings.superResolutionGroup' => '超分辨率 (Anime4K)',
			'settings.playerPresets' => '播放预设',
			'settings.playerPresetsHint' => '一键切换解码、输出与缓冲策略；只影响播放器。',
			'settings.playerOneClick' => '一键推荐配置',
			'settings.playerOneClickDesc' => '恢复「标准」预设，撤销手动调优；正在播放的立即重应用，其余下次打开生效。',
			'settings.playerOneClickConfirmTitle' => '应用推荐配置？',
			'settings.playerOneClickConfirmBody' => ({required Object preset}) => '将把播放内核设为「${preset}」，撤销手动输出与解码器选择；正在播放的直播会短暂重建画面。',
			'settings.playerOneClickApplied' => ({required Object preset}) => '已应用「${preset}」',
			'settings.playerCompatFix' => '花屏 / 绿屏修复',
			'settings.playerCompatFixDesc' => 'mediacodec_embed 直出表面并强制硬解，仅 Android；音画不同步或画面撕裂时先试这个。',
			'settings.presetBalanced' => '标准（引擎默认）',
			'settings.presetBalancedDesc' => '全部交给引擎决定，仅附加直播所需的缓冲调优；大多数设备最稳，也是其它预设的基线。',
			'settings.presetCompat' => 'Android 硬解兼容',
			'settings.presetCompatDesc' => 'Android 专用：mediacodec_embed 直出表面并强制硬解。默认路径花屏、绿屏或音画不同步时使用。',
			'settings.presetRtxVsr' => 'RTX 视频超分辨率',
			'settings.presetRtxVsrDesc' => 'Windows + NVIDIA 专用：d3d11va 硬解叠加 RTX Video Super Resolution，把低清源放大到高分屏。',
			'settings.presetLowEnd' => '低配流畅',
			'settings.presetLowEndDesc' => '软解线程上限 2、lowres 降采样、跳过环路滤波、小缓冲；核显或老机器用。',
			'settings.presetStableNetwork' => '弱网稳定',
			'settings.presetStableNetworkDesc' => '加大缓冲与预读、开启强制可拖动与重连退避；用内存换流畅，适合跨网或信号边缘的源。',
			'settings.presetLowLatency' => '低延迟',
			'settings.presetLowLatencyDesc' => '最小缓冲 + 解码/渲染双端丢帧，牺牲抗抖动换低延迟。适合赛事直播、连麦互动等时效优先的场景。',
			'settings.playerPresetApplied' => '已应用预设',
			'settings.playerOutputLockedByPreset' => '已由当前预设固定',
			'settings.playerProxy' => '播放器代理',
			'settings.playerProxyDesc' => '只影响播放器请求；可以跟随上面的应用代理。',
			'settings.playerProxyInvalid' => '请填写有效的主机和端口（1–65535）。',
			'settings.playerProxyMode' => '代理方式',
			'settings.playerProxyFollow' => '跟随应用代理',
			'settings.playerProxyManual' => '单独设置',
			'settings.hardwareDecoder' => '硬件解码器 (--hwdec)',
			'settings.hardwareDecoderDesc' => '选择 mpv 的 hwdec 解码器（自定义输出开启时生效）。',
			'settings.hardwareDecoderAutoHint' => '未开启自定义输出时由 mpv 自动选择（auto-safe）；要指定请在「高级设置」开启自定义驱动。',
			'settings.hardwareDecoderSoftware' => 'no（软件解码，兼容性最好）',
			'settings.hardwareDecoderAuto' => 'auto（任意硬解路径，兼容性有风险）',
			'settings.hardwareDecoderAutoSafe' => 'auto-safe（白名单内安全硬解，推荐）',
			'settings.hardwareDecoderAutoUnsafe' => 'auto-unsafe（不做安全校验）',
			'settings.hardwareDecoderYes' => 'yes（强制硬解，失败即报错）',
			'settings.hardwareDecoderAutoCopy' => 'auto-copy（安全硬解 + 拷回内存，滤镜/截图可用）',
			'settings.hardwareDecoderD3d11va' => 'd3d11va（Direct3D 11 直通，Windows 8+）',
			'settings.hardwareDecoderD3d11vaCopy' => 'd3d11va-copy（D3D11 + 拷回内存）',
			'settings.hardwareDecoderNvdec' => 'nvdec（NVIDIA 直通，低开销）',
			'settings.hardwareDecoderNvdecCopy' => 'nvdec-copy（NVIDIA + 拷回内存）',
			'settings.hardwareDecoderVideotoolbox' => 'videotoolbox（Apple 直通，推荐）',
			'settings.hardwareDecoderVideotoolboxCopy' => 'videotoolbox-copy（Apple + 拷回内存）',
			'settings.hardwareDecoderVaapi' => 'vaapi（Intel/AMD Linux 直通）',
			'settings.hardwareDecoderVaapiCopy' => 'vaapi-copy（vaapi + 拷回内存）',
			'settings.hardwareDecoderVdpau' => 'vdpau（NVIDIA Linux 旧接口）',
			'settings.hardwareDecoderVdpauCopy' => 'vdpau-copy（VDPAU + 拷回内存）',
			'settings.hardwareDecoderMediacodec' => 'mediacodec（Android 直通，推荐）',
			'settings.hardwareDecoderMediacodecCopy' => 'mediacodec-copy（Android + 拷回内存）',
			'settings.customOutput' => '自定义驱动与硬件加速',
			'settings.customOutputDesc' => '开启后用所选输出与解码器，代替「硬件解码」开关。',
			'settings.customOutputHardwareTakeover' => '已由「自定义驱动与硬件加速」接管，解码器在下方选择。',
			'settings.videoOutput' => '视频输出',
			'settings.videoOutputHint' => 'gpu / gpu-next / direct3d 可能另开 mpv 窗口；嵌入画面保持 libmpv 或 auto。',
			'settings.videoOutputAuto' => 'auto（跟随 mpv 默认，推荐）',
			'settings.videoOutputLibmpv' => 'libmpv（内嵌 Flutter 纹理）',
			'settings.videoOutputGpu' => 'gpu（独立 mpv 窗口，完整着色器）',
			'settings.videoOutputGpuNext' => 'gpu-next（独立窗口，libplacebo 新管线，支持 HDR）',
			'settings.videoOutputDirect3d' => 'direct3d（独立窗口，旧 D3D9 兼容）',
			'settings.videoOutputNull' => 'null（不渲染画面，只有声音）',
			'settings.videoOutputMediacodecEmbed' => 'MediaCodec Embed（仅 Android，直通 Surface）',
			'settings.audioOutput' => '音频输出驱动（--ao）',
			'settings.audioOutputAuto' => '自动（引擎按平台挑选，推荐）',
			'settings.audioOutputAudiotrack' => 'AudioTrack（Android 系统混音器，推荐）',
			'settings.audioOutputAaudio' => 'AAudio（Android 8.0+，低延迟）',
			'settings.audioOutputOpensles' => 'OpenSL ES（Android 旧通道，兼容用）',
			'settings.audioOutputAudiounit' => 'AudioUnit（iOS / macOS）',
			'settings.audioOutputWasapi' => 'WASAPI（Windows 默认通道，推荐）',
			'settings.audioOutputWin32' => 'win32（waveOut 旧通道）',
			'settings.audioOutputSdl' => 'SDL（跨平台兜底）',
			'settings.audioOutputPcm' => 'PCM（原始数据转储到文件，调试用）',
			'settings.audioOutputAlsa' => 'ALSA（Linux 直通，可能独占声卡）',
			'settings.audioOutputPipewire' => 'PipeWire（Linux 新声音栈）',
			'settings.audioOutputNull' => 'null（不输出声音，静音调试）',
			'settings.videoSync' => '视频同步模式 (--video-sync)',
			'settings.videoSyncDesc' => '画面跟随音频时钟还是显示刷新；显示重采样最平滑，但更吃 GPU。',
			'settings.videoSyncAudio' => '音频时钟（mpv 默认）',
			'settings.videoSyncDisplayResample' => '显示重采样（最平滑，吃 GPU）',
			'settings.videoSyncDisplayResampleVdrop' => '显示重采样 + 视频丢帧',
			'settings.videoSyncDisplayResampleDrop' => '显示重采样 + 整帧丢弃',
			'settings.videoSyncDisplayAdrop' => '显示时钟 + 音频丢样',
			'settings.videoSyncDisplayVdrop' => '显示时钟 + 视频丢帧',
			'settings.videoSyncDisplayDesync' => '显示时钟 + 不同步',
			'settings.videoSyncDesync' => '完全不同步（调试）',
			'settings.interpolation' => '运动插帧 (--interpolation)',
			'settings.interpolationDesc' => '需配合「显示重采样」；平移画面更顺滑，消耗 GPU。',
			'settings.scaleKernel' => '缩放算法',
			'settings.scaleKernelDesc' => '放大画面时的重采样算法。',
			'settings.scaleLanczos' => 'Lanczos（均衡推荐）',
			'settings.scaleEwaLanczosSharp' => 'EWA Lanczos Sharp（锐利，吃 GPU）',
			'settings.scaleEwaLanczos4Sharpest' => 'EWA Lanczos 4 Sharpest（配合插帧）',
			'settings.scaleEwaLanczos' => 'EWA Lanczos',
			'settings.scaleSpline36' => 'Spline36',
			'settings.scaleSpline16' => 'Spline16（快）',
			'settings.scaleCatmullRom' => 'Catmull-Rom',
			'settings.scaleMitchell' => 'Mitchell',
			'settings.scaleHermite' => 'Hermite（柔和）',
			'settings.scaleBicubicFast' => 'Bicubic Fast（快）',
			'settings.scaleBilinear' => '双线性（最快，最糊）',
			'settings.scaleNearest' => '最近邻（块状）',
			'settings.deinterlace' => '反交错 (--deinterlace)',
			'settings.deinterlaceDesc' => '直播源基本都是逐行的，保持自动；老电视信号或采集卡才需要。',
			'settings.deinterlaceAuto' => '自动',
			'settings.deinterlaceOff' => '关闭',
			'settings.deinterlaceOn' => '开启（隔行源才需要）',
			'settings.hwdecCodecs' => '硬解编码范围 (--hwdec-codecs)',
			'settings.hwdecCodecsDesc' => '某编码黑屏或花屏时把它移出列表，即可回退软解。',
			'settings.hwdecCodecsAll' => '全部编码格式',
			'settings.hwdecCodecsH264Hevc' => 'H264 + HEVC',
			'settings.hwdecCodecsH264HevcVp9' => 'H264 + HEVC + VP9',
			'settings.hwdecCodecsH264HevcVp9Av1' => 'H264 + HEVC + VP9 + AV1',
			'settings.audioExclusive' => '音频独占 (--audio-exclusive)',
			'settings.audioExclusiveDesc' => '独占 WASAPI 设备，其他应用将无法出声。',
			'settings.forceDestroy' => '播放器强制销毁',
			'settings.forceDestroyDesc' => '退出房间后立即销毁播放器；关闭时保留已停止的播放器，供下个房间复用。',
			'settings.mpvAdvanced' => 'mpv 高级设置',
			'settings.mpvReset' => '恢复播放内核默认设置',
			'settings.mpvResetDesc' => '恢复本页的设置；视频设置里的首选清晰度不受影响。',
			'settings.mpvResetConfirm' => '下面这些恢复默认值：\n• 开启硬解码：开\n• 兼容模式、RTX VSR、播放器强制销毁：关\n• 自定义驱动与硬件加速：关；三个驱动：默认\n视频设置里的首选清晰度不变。',
			'settings.mpvResetDone' => '已恢复默认设置',
			'settings.mpvDocs' => '打开 mpv 官方文档',
			'settings.mpvDocsDesc' => '每个属性的完整说明。',
			'settings.playerGuide' => '播放器指南',
			'settings.playerGuideDesc' => '预设、调参与常见问题的说明。',
			'settings.playerGuideTitle' => '播放搭配指南',
			'settings.playerGuideSubtitle' => '名词解释 · 各平台推荐搭配 · 症状对照',
			'settings.playerGuideIntro' => '指南中的内核选项仅对 mpv 内核生效；先用一键预设覆盖大多数场景，仍不正常时再改高级选项。',
			'settings.playerGuideManualTitle' => '播放手册：mpv 官方文档',
			'settings.playerGuideManualHint' => '遇到问题先看「症状对照」；想理解某个设置是什么，在「基础概念」和各章里查。',
			'settings.playerGuideChapterConcepts' => '基础概念',
			'settings.playerGuideChapterPresets' => '一键播放方案',
			'settings.playerGuideChapterPictureSync' => '画面与同步',
			'settings.playerGuideChapterQuality' => '画质增强',
			'settings.playerGuideChapterAudio' => '声音',
			'settings.playerGuideChapterSymptoms' => '症状对照',
			'settings.playerGuideBadgeHwdec' => 'hwdec',
			'settings.playerGuideBadgeVo' => 'vo',
			'settings.playerGuideBadgeAo' => 'ao',
			'settings.playerGuidePlatformAndroid' => 'Android',
			'settings.playerGuidePlatformWindows' => 'Windows',
			'settings.playerGuideEntryHardwareSwitchTitle' => '硬解码开关',
			'settings.playerGuideEntryHardwareSwitchBody' => '让显卡代替 CPU 解码视频。开启后 CPU 占用低、发热小；关闭则走软解，兼容性最好，老机器反而可能更流畅。',
			'settings.playerGuideEntryHwdecTitle' => '--hwdec',
			'settings.playerGuideEntryHwdecBody' => '具体用哪种硬解路径。auto 全部尝试（个别机型可能花屏）；auto-safe 只用白名单内的安全路径（推荐）；带 -copy 的变体把解码结果拷回内存，滤镜和截图需要它。',
			'settings.playerGuideEntryVoTitle' => '--vo',
			'settings.playerGuideEntryVoBody' => 'mpv 把画面画到哪里。libmpv 画进 Flutter 纹理（内嵌播放器，默认）；gpu/gpu-next/direct3d 会打开独立的 mpv 原生窗口（不在应用画面内）；null 不渲染画面。',
			'settings.playerGuideEntryAoTitle' => '--ao',
			'settings.playerGuideEntryAoBody' => 'mpv 把声音送到哪个系统通道。Windows 用 wasapi，Android 用 audiotrack/aaudio/opensles；null 表示静音。',
			'settings.playerGuideEntryPresetDefaultTitle' => '均衡（推荐起点）',
			'settings.playerGuideEntryPresetDefaultBody' => '清除自定义输出与解码器选择，交给 mpv 自动决定。大多数设备和网络的首选。',
			'settings.playerGuideEntryPresetAndroidCompatTitle' => 'Android 硬解兼容',
			'settings.playerGuideEntryPresetAndroidCompatBody' => '改用 mediacodec_embed 直通表面并强制 mediacodec 硬解，花屏、绿屏或音画不同步时使用。仅 Android 显示。',
			'settings.playerGuideEntryPresetRtxSrTitle' => 'NVIDIA RTX 视频超分',
			'settings.playerGuideEntryPresetRtxSrBody' => '使用 d3d11va 硬解并叠加 RTX Video Super Resolution 滤镜，把低清源放大观看；会锁定解码器为 d3d11va。仅 Windows 显示。',
			'settings.playerGuideEntryPresetLowEndTitle' => '低配流畅',
			'settings.playerGuideEntryPresetLowEndBody' => '软解 + 线程上限 2 + lowres 降采样 + 小缓冲。把 CPU 让给画面本身，核显或老机器使用。',
			'settings.playerGuideEntryPresetWeakNetworkTitle' => '弱网稳定',
			'settings.playerGuideEntryPresetWeakNetworkBody' => '加大缓冲与预读、开启重连退避。用内存换卡顿，跨网或信号边缘时使用。',
			'settings.playerGuideEntryPresetLowLatencyTitle' => '低延迟',
			'settings.playerGuideEntryPresetLowLatencyBody' => '最小缓冲 + 双端丢帧。时效优先，代价是更容易卡。',
			'settings.playerGuideEntryVideoSyncTitle' => '--video-sync',
			'settings.playerGuideEntryVideoSyncBody' => '音画时钟对齐方式。audio 是 mpv 默认；display-resample 最平滑但吃 GPU，配合运动插帧使用；带 vdrop/drop 的变体在节奏对不上时丢帧。仅桌面显示。',
			'settings.playerGuideEntryInterpolationTitle' => '--interpolation',
			'settings.playerGuideEntryInterpolationBody' => '运动插帧。平移画面时按帧间计算补帧，显著更顺滑；必须配合 display-resample 同步模式，GPU 消耗明显。仅桌面显示。',
			'settings.playerGuideEntryScaleTitle' => '--scale',
			'settings.playerGuideEntryScaleBody' => '画面放大算法。lanczos 均衡推荐；ewa_lanczossharp 最锐利；ewa_lanczos4sharpest 专为插帧设计；bilinear/nearest 最快但糊或块状。移动端只提供 lanczos 与 bilinear。',
			'settings.playerGuideEntryDeinterlaceTitle' => '--deinterlace',
			'settings.playerGuideEntryDeinterlaceBody' => '反交错处理。直播源基本都是逐行的，保持自动即可；只有老电视信号或采集卡源才需要开启。',
			'settings.playerGuideEntryRtxSuperResolutionTitle' => '超分辨率（Anime4K）',
			'settings.playerGuideEntryRtxSuperResolutionBody' => '设置 → 播放内核 → 超分辨率：效率档或质量档。仅 Windows 桌面 GPU 可实时运行，把低清源放大到高分屏仍然清晰。',
			'settings.playerGuideEntryDanmakuLoadTitle' => '弹幕较多时减轻负担',
			'settings.playerGuideEntryDanmakuLoadBody' => '在设置 → 弹幕样式里调低字号、速度或不透明度，或关闭画面飞行弹幕，可显著减轻低配设备的负担。',
			'settings.playerGuideEntryHwdecCodecsTitle' => '--hwdec-codecs',
			'settings.playerGuideEntryHwdecCodecsBody' => '限制哪些编码格式走硬解。默认全部编码格式；某编码黑屏或花屏时，把范围收窄到不含它的档位（回退软解）。',
			'settings.playerGuideEntryAudioExclusiveTitle' => '--audio-exclusive',
			'settings.playerGuideEntryAudioExclusiveBody' => '仅 Windows。独占 WASAPI 设备，绕过系统混音器，可能有更好的音质；代价是其他应用无法出声。',
			'settings.playerGuideEntryAoAdviceTitle' => '--ao 选择建议',
			'settings.playerGuideEntryAoAdviceBody' => '不确定就用 auto。声音断续时 Windows 换 win32，Android 换 opensles；蓝牙耳机延迟大时可尝试不同通道对比。',
			'settings.playerGuideEntrySymGlitchTitle' => '花屏 / 绿屏 / 音画不同步',
			'settings.playerGuideEntrySymGlitchBody' => 'Android：一键方案切「安卓兼容」。其它平台：关闭硬解开关走软解，或在自定义驱动与硬件加速里把解码器改 auto-safe。',
			'settings.playerGuideEntrySymBlurryTitle' => '低清源在高分屏发糊',
			'settings.playerGuideEntrySymBlurryBody' => 'Windows + NVIDIA：选「RTX VSR」预设；其它 GPU：放大算法改 ewa_lanczossharp，或在播放内核里开启 Anime4K 超分辨率（仅 Windows）。',
			'settings.playerGuideEntrySymFanTitle' => '风扇狂转 / 掉帧',
			'settings.playerGuideEntrySymFanBody' => '选「低配流畅」方案；仍不行就关闭硬解码开关（老设备软解反而快）。',
			'settings.playerGuideEntrySymBufferingTitle' => '频繁缓冲',
			'settings.playerGuideEntrySymBufferingBody' => '选「弱网稳定」；同时检查播放器代理设置——代理是直播卡顿的常见来源。',
			'settings.playerGuideEntrySymLatencyTitle' => '延迟高（连麦 / 赛事情景）',
			'settings.playerGuideEntrySymLatencyBody' => '选「低延迟」方案，并调低缓冲相关属性。',
			'settings.playerGuideEntrySymNoVideoTitle' => '有声音没画面',
			'settings.playerGuideEntrySymNoVideoBody' => '检查视频输出驱动是否被改过（null = 不渲染画面）；恢复「自动」即可。恢复播放内核默认设置也能解决。',
			'settings.optionAuto' => '自动',
			'settings.optionOff' => '关闭',
			'settings.optionOn' => '开启',
			'settings.optionNoOutput' => '无输出',
			'settings.superResolutionOffDesc' => '默认渲染，不挂载任何超分滤镜。',
			'settings.superResolutionEfficiencyDesc' => '轻量 Anime4K 卷积链，GPU 负担小，适合核显或高刷屏。',
			'settings.superResolutionQualityDesc' => '完整 Anime4K 卷积链，效果最好，需要独立显卡。',
			'settings.playerAdvancedRequiresMpv' => '这些选项只对 mpv 内核生效。',
			'settings.superResolution' => '超分辨率',
			'settings.superResolutionDescription' => '用 Anime4K 着色器实时放大画面；需要桌面 GPU。',
			'settings.superResolutionHint' => '基于 Anime4K 的实时超分，仅 Windows 桌面 GPU 可实时运行。',
			'settings.superResolutionOff' => '关闭',
			'settings.superResolutionEfficiency' => '效率档',
			'settings.superResolutionQuality' => '质量档',
			'settings.recordingDescription' => '录制目录、文件命名与容量上限。',
			'settings.preferredQuality' => '首选画质',
			'settings.preferredQualityDesc' => '进入房间优先选用的清晰度；没有同名画质时按档位就近选择。',
			'settings.preferredQualityCellular' => '蜂窝网络首选画质',
			'settings.preferredQualityCellularDesc' => '使用移动数据时优先选用的清晰度档位；Wi-Fi 与有线仍使用上面的首选画质。',
			'settings.qualityAuto' => '自动（站点默认）',
			'settings.qualityOriginal' => '原画',
			'settings.qualityBluRay8M' => '蓝光 8M',
			'settings.qualityBluRay4M' => '蓝光 4M',
			'settings.qualityBluRay' => '蓝光',
			'settings.qualityUltra' => '超清',
			'settings.qualityHigh' => '高清',
			'settings.qualityStandard' => '标清',
			'settings.qualitySmooth' => '流畅',
			'settings.defaultMuted' => '默认静音',
			'settings.defaultMutedDesc' => '每个新房间打开时保持静音。',
			'settings.defaultVolume' => '默认音量',
			'settings.defaultVolumeDesc' => '移动端新播放器默认 50%，桌面 100%；滑杆只调当前平台。',
			'settings.volumeWheelStep' => '滚轮音量步长',
			'settings.volumeWheelStepDesc' => '鼠标滚轮与方向键每次调节的音量幅度。',
			'settings.volumeWheelStepValue' => ({required int percent}) => '${percent}%',
			'settings.globalMute' => '全局静音',
			'settings.globalMuteDesc' => '静音所有正在播放与之后打开的房间、频道和视频；关闭后各自恢复。',
			'settings.backgroundPlay' => '后台播放',
			'settings.backgroundPlayDesc' => '离开应用后继续出声；关闭则切后台即暂停。',
			'settings.asmrSleepMode' => 'ASMR 睡眠模式',
			'settings.asmrSleepModeDesc' => '进直播间自动切音频模式，到时暂停。仅 Android。',
			'settings.asmrSleepTimer' => 'ASMR 睡眠时长',
			'settings.asmrSleepTimerDesc' => '音频模式自动停止前的分钟数，范围 15–1440。',
			'settings.asmrSleepCustomMinutes' => '自定义分钟数',
			'settings.asmrSleepRange' => '15–1440 分钟',
			'settings.fit' => '画面比例',
			'settings.fitDesc' => '画面在播放区域里的铺法。',
			'settings.fitContain' => '默认比例',
			'settings.fitCover' => '居中裁剪',
			'settings.fitFill' => '填充屏幕',
			'settings.miniDanmakuVisible' => '画中画中显示弹幕',
			'settings.miniDanmakuVisibleDesc' => '缩成小窗时是否继续显示飞行弹幕。',
			'settings.miniDanmakuHint' => '弹幕样式与「弹幕」页共用。',
			'settings.engineTitle' => '播放内核',
			'settings.engineDesc' => '直播与视频的播放内核；mpv 为默认，移动端另可选 IJK 或 BetterPlayer。',
			'settings.playerEngineMpv' => 'mpv 播放器',
			'settings.playerEngineIjk' => 'IJK 播放器',
			'settings.playerEngineBetterPlayer' => 'BetterPlayer',
			'settings.hardwareDecoding' => '硬件解码',
			'settings.hardwareDecodingDesc' => '用 GPU 解码视频，关闭则交给 CPU。',
			'settings.hardwareDecodingHint' => '对当前与之后打开的播放器生效。',
			'settings.refreshOnResume' => '返回应用时刷新关注',
			'settings.refreshOnResumeDesc' => '切回应用时刷新一遍关注列表的状态。',
			'settings.maxConcurrentRefresh' => '最大并发刷新',
			'settings.maxConcurrentRefreshDesc' => '同时向平台查询的房间数，参考推荐 4，范围 1–20。',
			'settings.recommended' => '推荐',
			'settings.refreshThumbnails' => '自动刷新封面',
			'settings.refreshThumbnailsDesc' => '定期清空图片缓存，封面、头像和台标重新下载；不影响历史与关注。',
			'settings.thumbnailRefreshInterval' => '封面刷新间隔',
			'settings.navHomeMenuTitle' => '首页菜单',
			'settings.navHomeMenuDescription' => '侧栏、抽屉与底栏显示的首页入口，以及它们的顺序。',
			'settings.editOrder' => '编辑顺序',
			'settings.saveOrder' => '保存顺序',
			'settings.unsavedOrderDraft' => '未保存的排序草稿',
			'settings.moveToTop' => '置顶',
			'settings.moveToBottom' => '置底',
			'settings.navMenuKeepOne' => '至少保留一个菜单',
			'settings.groupTheme' => '主题',
			'settings.groupCards' => '卡片与列表',
			'settings.groupLanguage' => '语言',
			'settings.contrast' => '对比度',
			'settings.contrastDescription' => '控件边界与文字的对比强度。',
			'settings.contrastSoft' => '柔和',
			'settings.contrastStandard' => '标准',
			'settings.selectionStyle' => '选中样式',
			'settings.selectionDescription' => '选中行与控件的高亮方式。',
			'settings.selectionSoft' => '柔和',
			'settings.selectionStrong' => '强烈',
			'settings.autoClash' => '自动避让状态色',
			'settings.autoClashDesc' => '主题色接近危险或成功色时自动调整，避免选中状态被误读。',
			'settings.navBackground' => '背景',
			'settings.backgroundDescription' => '用图片或视频铺在应用后面，可上传本地文件或填写地址。',
			'settings.backgroundImagesTitle' => '在线图片',
			'settings.backgroundImagesDescription' => '官方、Wallhaven、Bing 与 deepin 图源，先预览再应用。',
			'settings.backgroundVideosTitle' => '在线视频',
			'settings.navRandomWallpaper' => '随机图源',
			'settings.randomWallpaperDescription' => '按分组从公开随机接口取图，预览后再应用。',
			'settings.backgroundVideosDescription' => 'iTab 动态壁纸，选中后预览再应用。',
			'settings.backgroundColorsTitle' => '纯色与渐变',
			'settings.backgroundColorsDescription' => '调色板与渐变预设。',
			'settings.backgroundDeviceTitle' => '从设备',
			'settings.backgroundDeviceDescription' => '上传图片或视频，或填写网络地址。',
			'settings.backgroundPreview' => '当前背景',
			'settings.backgroundPreviewKind' => '图片与视频',
			'settings.backgroundPreviewPrevious' => '上一张',
			'settings.backgroundPreviewNext' => '下一张',
			'settings.backgroundPreviewTitle' => '壁纸预览',
			'settings.backgroundChange' => '更换背景',
			'settings.backgroundSource' => '背景来源',
			'settings.backgroundNone' => '无',
			'settings.backgroundImage' => '图片',
			'settings.backgroundVideo' => '视频',
			'settings.backgroundImageAddress' => '图片地址',
			'settings.backgroundVideoAddress' => '视频地址',
			'settings.backgroundAddressInUse' => '当前使用',
			'settings.backgroundAddressHint' => 'https://…',
			'settings.backgroundApply' => '应用',
			'settings.backgroundUploadImage' => '选择图片',
			'settings.backgroundUploadVideo' => '选择视频',
			'settings.backgroundInvalidUrl' => '地址需要是 http(s) 链接',
			'settings.backgroundImportFailed' => '导入失败',
			'settings.backgroundDropUnsupported' => '拖入的文件类型不支持',
			'settings.backgroundBusy' => '正在复制文件…',
			'settings.backgroundDisplay' => '显示',
			'settings.backgroundFit' => '填充方式',
			_ => null,
		} ?? switch (path) {
			'settings.backgroundFitDescription' => '把图片或视频铺到窗口时的方式；纯色与渐变没有可填充的对象。',
			'settings.backgroundFitCover' => '裁切填满',
			'settings.backgroundFitContain' => '完整显示',
			'settings.backgroundFitFill' => '拉伸填满',
			'settings.backgroundFitWidth' => '适应宽度',
			'settings.backgroundFitHeight' => '适应高度',
			'settings.backgroundFitNone' => '原始大小',
			'settings.backgroundFitScaleDown' => '缩小',
			'settings.backgroundMask' => '蒙层浓度',
			'settings.backgroundMaskDescription' => '在壁纸上盖一层压暗或提亮的蒙层；浓度越高文字越清楚，壁纸越淡。',
			'settings.backgroundScrimMode' => '蒙层模式',
			'settings.backgroundScrimModeDescription' => '自动按文字清晰度加深蒙层，至少使用下方浓度；自定义只用下方浓度；关闭则完全不加蒙层。',
			'settings.backgroundScrimAuto' => '自动',
			'settings.backgroundScrimCustom' => '自定义',
			'settings.backgroundScrimOff' => '关闭',
			'settings.backgroundOverlayBlur' => '背景模糊',
			'settings.backgroundOverlayBlurDescription' => '模糊壁纸本身，图片、视频、纯色、渐变都生效；0 保持清晰。',
			'settings.backgroundClearDescription' => '回到主题自身的底色，已保存的媒体仍保留，随时可再次选择。',
			'settings.backgroundClear' => '清除背景',
			'settings.backgroundGlass' => '界面玻璃',
			'settings.backgroundGlassEnable' => '启用',
			'settings.backgroundGlassDescription' => '卡片、列表与浮层底色变半透明，浮层再模糊背后内容，让壁纸透出来。',
			'settings.backgroundGlassFill' => '面板填充',
			'settings.backgroundGlassFillDescription' => '卡片、列表和浮层底色的不透明度；越低壁纸透得越多，文字对比越弱。',
			'settings.backgroundGlassBlur' => '浮层模糊',
			'settings.backgroundGlassBlurDescription' => '浮层背后内容的模糊半径；0 只半透明不模糊。',
			'settings.checkUpdate' => '检查更新',
			'settings.checkUpdateDesc' => '从项目的发行页读取最新版本。',
			'settings.checkingUpdate' => '正在检查更新…',
			'settings.updateAvailable' => ({required Object version}) => '可更新到 ${version}',
			'settings.upToDate' => '已是最新版本',
			'settings.updateCheckFailed' => '检查更新失败',
			'settings.viewUpdate' => '查看更新',
			'settings.updatePanelTitle' => '版本更新',
			'settings.updateBuild' => ({required Object build}) => '构建 ${build}',
			'settings.openDownload' => '打开下载页',
			'settings.releaseHistory' => '版本记录',
			'settings.releaseHistoryDesc' => '查看项目历次发布与更新内容。',
			'settings.releaseHistoryEmpty' => '暂无发布记录',
			'settings.releaseHistoryFailed' => '发行记录加载失败',
			'settings.releasedOn' => ({required Object date}) => '发布于 ${date}',
			'settings.prerelease' => '预览版',
			'settings.updateLater' => '稍后再说',
			'settings.downloadInstaller' => '下载安装包',
			'settings.downloadOtherBuilds' => '其他构建',
			'settings.downloadTitle' => '获取安装包',
			'settings.downloadLatest' => '最新版本',
			'settings.downloadHint' => '选择与本机匹配的包；下载保存到「数据与缓存」里的下载目录。',
			'settings.downloadAction' => '下载',
			'settings.downloadCount' => ({required Object count}) => '${count} 次下载',
			'settings.downloadFailed' => '无法读取发布文件列表',
			'settings.downloadEmpty' => '这个发布没有可下载的文件',
			'settings.downloadNoBuild' => '这个发布没有匹配本机的安装包，已打开发布页。',
			'settings.downloadProgress' => ({required Object received, required Object total}) => '${received} / ${total}',
			'settings.downloadProgressUnknown' => ({required Object received}) => '已下载 ${received}',
			'settings.downloadSavedTo' => ({required Object path}) => '已保存到 ${path}',
			'settings.downloadCancelled' => '下载已取消，未保留部分文件。',
			'settings.downloadOpenFile' => '打开文件',
			'settings.downloadOpenFolder' => '打开所在文件夹',
			'settings.downloadOpenFailed' => '无法打开该文件',
			'settings.downloadQueued' => ({required Object title}) => '已加入下载：${title}',
			'settings.downloadManagerView' => '查看',
			'settings.downloadManagerTitle' => '下载管理',
			'settings.downloadManagerDesc' => '壁纸的下载任务、记录与保存目录。',
			'settings.downloadManagerEmpty' => '还没有下载记录',
			'settings.downloadManagerEmptyDesc' => '在预览或图库点「下载」，任务会出现在这里。',
			'settings.downloadStatusRunning' => '下载中',
			'settings.downloadStatusDone' => '已完成',
			'settings.downloadStatusFailed' => '下载失败',
			'settings.downloadStartedAt' => ({required Object time}) => '开始于 ${time}',
			'settings.downloadFinishedAt' => ({required Object time}) => '完成于 ${time}',
			'settings.downloadRemove' => '移除记录',
			'settings.downloadRemoveBody' => '只移除这条记录，不会删除已保存的文件。',
			'settings.downloadClearFinished' => '清除已完成',
			'settings.downloadDuplicateRunning' => '这个文件正在下载',
			'settings.downloadDuplicateDone' => '这个文件已经下载过了',
			'settings.downloadManagerOpenFolder' => '打开文件夹',
			'settings.downloadFilterAll' => '全部',
			'settings.downloadFilterEmpty' => '没有符合这个状态的记录',
			'settings.downloadKindFilter' => '按类型筛选',
			'settings.downloadColumnFile' => '文件',
			'settings.downloadColumnSize' => '大小',
			'settings.downloadColumnTime' => '时间',
			'settings.downloadColumnActions' => '操作',
			'settings.downloadSearchPlaceholder' => '搜索下载记录',
			'settings.downloadPercent' => ({required Object percent}) => '下载中 ${percent}%',
			'settings.downloadStatusPaused' => '已暂停',
			'settings.downloadLoadedCount' => ({required Object shown, required Object total}) => '已加载 ${shown} / ${total}',
			'settings.downloadLoadingMore' => '正在加载更多…',
			'settings.downloadSettings' => '下载设置',
			'settings.downloadDetailPreview' => '点击进入预览',
			'settings.downloadDetailTitle' => '下载详情',
			'settings.downloadInfoPath' => '保存路径',
			'settings.downloadInfoSize' => '文件大小',
			'settings.downloadInfoTime' => '下载时间',
			'settings.downloadSelectAll' => '全选',
			'settings.downloadSelectedCount' => ({required Object count}) => '已选 ${count} 项',
			'settings.downloadDeleteSelected' => ({required Object count}) => '删除所选（${count}）',
			'settings.downloadDeleteAll' => '全部删除',
			'settings.downloadTypeAll' => '全部类型',
			'settings.downloadPause' => '暂停',
			'settings.downloadResume' => '继续下载',
			'settings.downloadPausedHint' => '已暂停 · 点击继续',
			'settings.downloadEtaSeconds' => ({required Object seconds}) => '预计还需 ${seconds} 秒',
			'settings.downloadEtaMinutes' => ({required Object minutes}) => '预计还需 ${minutes} 分钟',
			'settings.downloadEtaHours' => ({required Object hours}) => '预计还需 ${hours} 小时',
			'settings.downloadSummary' => ({required Object total}) => '共 ${total} 项',
			'settings.downloadSummaryMoving' => ({required Object total, required Object running}) => '共 ${total} 个任务 · ${running} 个正在下载',
			'settings.downloadPageSummary' => ({required Object total, required Object page, required Object count}) => '共 ${total} 个任务 · 第 ${page}/${count} 页',
			'settings.openReleasePage' => '发布页',
			'settings.releaseExpand' => '展开更新内容',
			'settings.releaseCollapse' => '收起更新内容',
			'settings.releaseOsAndroid' => '安卓',
			'settings.releaseOsIos' => 'iOS',
			'settings.releaseOsWindows' => 'Windows',
			'settings.releaseOsMacos' => 'macOS',
			'settings.releaseOsLinux' => 'Linux',
			'settings.releaseOsOther' => '其他平台',
			'settings.releaseKindApk' => 'APK 安装包',
			'settings.releaseKindIpa' => 'IPA',
			'settings.releaseKindInstaller' => '安装程序',
			'settings.releaseKindDmg' => 'DMG 磁盘映像',
			'settings.releaseKindMsix' => 'MSIX 应用包',
			'settings.releaseKindDeb' => 'DEB 软件包',
			'settings.releaseKindTarGz' => 'tar.gz 归档',
			'settings.releaseKindPortable' => '便携版压缩包',
			'settings.releaseKindOther' => '文件',
			'settings.sitesKeepOne' => '至少保留一个平台',
			'settings.autoPip' => '离开应用时自动小窗',
			'settings.autoPipDesc' => '播放中离开应用时把画面留在系统小窗；需要悬浮窗权限。',
			'settings.floatPlay' => '返回时悬浮播放',
			'settings.floatPlayDesc' => '离开直播间时把画面留在可拖动的小窗；关闭小窗即停止播放。',
			'settings.windowsPipAlwaysOnTop' => '小窗始终置顶',
			'settings.windowsPipAlwaysOnTopDesc' => '小窗保持在其他窗口之上；正在播放的小窗立即应用。',
			'settings.rememberPipPosition' => '记住小窗位置',
			'settings.rememberPipPositionDesc' => '再次进入小窗时回到上次的尺寸、位置和显示器；关闭后每次使用默认位置。',
			'settings.windowsPipBaseSize' => '小窗基准尺寸',
			'settings.windowsPipBaseSizeDesc' => '横向视频的长边；竖向视频时作为高。范围 200–720。',
			'settings.windowsPipMinWidth' => '小窗最小宽度',
			'settings.windowsPipMinWidthDesc' => '小窗最小宽度，100–320；离开小窗后恢复常规下限。',
			'settings.windowsPipMinHeight' => '小窗最小高度',
			'settings.windowsPipMinHeightDesc' => '小窗最小高度，60–240；离开小窗后恢复常规下限。',
			'settings.fullscreenDefault' => '自动全屏',
			'settings.fullscreenDefaultDesc' => '当进入直播播放页，自动进入全屏',
			'settings.keepScreenOn' => '播放时保持屏幕常亮',
			'settings.keepScreenOnDesc' => '房间或频道播放时阻止屏幕自动熄灭；暂停后恢复系统休眠。',
			'settings.controlsAutoHide' => '控制条自动隐藏',
			'settings.controlsAutoHideDesc' => '播放时经过该秒数后隐藏画面控制条；暂停时保持显示。',
			'settings.controlsAutoHideValue' => ({required int count}) => '${count} 秒',
			'settings.navPortrait' => '竖屏直播适配',
			'settings.portraitPageDescription' => '自动识别直播源方向，并调整普通页的观看区域与布局。',
			'settings.navAudience' => '观众指标',
			'settings.audiencePageDescription' => '卡片人数口径、真实在线优先与平台开关。',
			'settings.portraitEntryOff' => '已关闭',
			'settings.portraitDetectionGroup' => '识别与普通页布局',
			'settings.portraitSmartDetection' => '智能识别竖屏直播源',
			'settings.portraitSmartDetectionDesc' => '按解码后的真实画面尺寸识别竖屏；关闭后竖屏源按横屏显示。',
			'settings.portraitAdaptiveHeight' => '普通页自适应视频高度',
			'settings.portraitAdaptiveHeightDesc' => '竖屏源增大观看区域，同时保留足够的聊天与弹幕列表空间。',
			'settings.portraitLayoutMode' => '普通页布局模式',
			'settings.portraitLayoutModeDesc' => '仅影响竖屏直播源，不改变普通横屏直播。',
			'settings.portraitLayoutBalanced' => '均衡（推荐）',
			'settings.portraitLayoutImmersive' => '沉浸',
			'settings.portraitLayoutCompatibility' => '兼容 16:9',
			'settings.portraitDetectionOff' => '开启智能识别后才能调整高度与布局。',
			'settings.searchSections' => '分区',
			'settings.searchRows' => '具体设置',
			'settings.searchRowMatches' => ({required String items}) => '匹配：${items}',
			'settings.audienceMetric' => '观众数显示',
			'settings.audienceMetricDesc' => '热门、关注等卡片优先展示的观众指标。',
			'settings.audienceAutomatic' => '跟随平台',
			'settings.audienceOnline' => '在线观众',
			'settings.audiencePopularity' => '热度',
			'settings.audienceTotal' => '累计观看',
			'settings.audienceDisplayGroup' => '卡片显示与排行方式',
			'settings.audienceRankingNote' => '排序用卡片显示的数值；「真实在线」仅在跟随平台下、已开启的平台生效。',
			'settings.audienceRealOnlineGroup' => '真实在线人数',
			'settings.audienceRealOnline' => '真实在线人数优先',
			'settings.audienceRealOnlineDesc' => '跟随平台显示时，已开启的平台优先用同时在线人数，其余保留热度或累计。',
			'settings.audienceNeedsAutomaticMode' => '先在「观众数显示」中选择「跟随平台」，真实在线优先才会生效。',
			'settings.audiencePlatformsGroup' => '真实在线平台',
			'settings.audiencePlatformsDesc' => '只有公开返回并发人数的平台会出现；关闭后该平台仍按热度显示。',
			'settings.audienceSourceRoomList' => '来源：房间列表/详情，可直接排行',
			'settings.audienceSourceRoomRealtime' => '来源：进入直播间后的实时消息',
			'settings.audiencePlatformNeedsOnline' => '先开启「真实在线人数优先」',
			'settings.audienceHeatOnlyGroup' => '仅热度或累计观看的平台',
			'settings.audienceHeatOnlyDesc' => '这些平台的接口没有并发人数，卡片照常标明热度或累计观看。',
			'settings.backgroundSolid' => '纯色',
			'settings.backgroundGradient' => '渐变',
			'settings.backgroundPresets' => '预设',
			'settings.backgroundLibraryTitle' => '壁纸图库',
			'settings.backgroundLibraryEmpty' => '没有可用的壁纸',
			'settings.backgroundLibraryFailed' => '图库加载失败',
			'settings.backgroundLibraryApplied' => '已应用为背景',
			'settings.wallpaperSourceOfficial' => '官方壁纸',
			'settings.wallpaperSourceWallhaven' => 'Wallhaven',
			'settings.wallpaperSourceBing' => '必应壁纸',
			'settings.wallpaperSourceDeepin' => 'deepin',
			'settings.wallpaperSourceVideo' => '动态壁纸',
			'settings.wallpaperCategoryNature' => '自然',
			'settings.wallpaperCategoryAnime' => '动漫',
			'settings.wallpaperCategoryArt' => '艺术',
			'settings.wallpaperCategoryArchitecture' => '建筑',
			'settings.wallpaperCategoryLife' => '生命',
			'settings.wallpaperCategoryTexture' => '纹理',
			'settings.wallpaperCategoryOther' => '其他',
			'settings.wallpaperCategoryPopular' => '热门',
			'settings.wallpaperCategoryMinimalism' => '极简主义',
			'settings.wallpaperCategoryPatterns' => '图案',
			'settings.wallpaperCategoryLandscape' => '风景',
			'settings.wallpaperCategoryCosplay' => 'Cosplay',
			'settings.wallpaperCategorySpiderMan' => '蜘蛛侠',
			'settings.wallpaperCategoryGhibli' => '吉卜力',
			'settings.wallpaperCategoryNaruto' => '火影忍者',
			'settings.wallpaperCategorySciFi' => '科幻',
			'settings.wallpaperCategoryAnimeWallhaven' => '日漫',
			'settings.wallpaperCategoryAnimeGirls' => '动漫女孩',
			'settings.wallpaperCategoryCyberpunk' => '赛博朋克',
			'settings.wallpaperCategoryPixelArt' => '像素艺术',
			'settings.wallpaperCategoryArtwork' => '艺术画',
			'settings.wallpaperCategoryCityscape' => '城市景观',
			'settings.wallpaperCategoryDigitalArt' => '数字艺术',
			'settings.wallpaperCategoryFantasyArt' => '奇幻艺术',
			'settings.wallpaperCategoryFinalFantasy' => '最终幻想',
			'settings.tagManagement' => '标签管理',
			'settings.tagManagementDesc' => '自定义和管理直播间的过滤标签',
			'settings.tagAdd' => '添加标签',
			'settings.tagEdit' => '编辑标签',
			'settings.tagPin' => '移到最前',
			'settings.tagSaveAction' => '保存',
			'settings.tagNameLabel' => '标签名称',
			'settings.tagNameHint' => '例如“常看”“睡前听”',
			'settings.tagNoteLabel' => '备注描述（可选）',
			'settings.tagNoteHint' => '给这个标签写一句备注',
			'settings.tagNameEmpty' => '标签名称不能为空',
			'settings.tagNameDuplicate' => '已存在同名标签',
			'settings.tagSaveFailed' => '标签更改未保存，请重试',
			'settings.tagStale' => '这个标签已在别处被删除或修改',
			'settings.tagAddedToast' => ({required String name}) => '已添加标签“${name}”',
			'settings.tagSavedToast' => ({required String name}) => '已保存标签“${name}”',
			'settings.tagDeletedToast' => ({required String name}) => '已删除标签“${name}”',
			'settings.tagDeleteTitle' => ({required String name}) => '确定要永久删除标签“${name}”吗？',
			'settings.tagDeleteRoomsHint' => ({required int count}) => '${count} 个直播间会移出该标签，不会被取消关注。',
			'settings.tagDeleteBody' => '该标签还没有直播间在使用。',
			'settings.tagEmptyTitle' => '暂无自定义标签',
			'settings.tagEmptyHint' => '在关注页的卡片菜单里给直播间加标签，即可按标签筛选。',
			'settings.tagSortTip' => '拖动左侧把手调整顺序，关注页的标签栏按这个顺序显示。',
			'settings.tagRooms' => ({required int count}) => '${count} 个直播间',
			'settings.showUnplayableTitle' => '显示不能直接播放的直播',
			'settings.showUnplayableDesc' => '付费、加锁、仅限 App 的直播也显示在热门与分区；关注和搜索始终显示。',
			'settings.windowsPipFreeAspect' => '小窗自由比例',
			'settings.windowsPipFreeAspectDesc' => '可单独压小高度或拉宽窗口，不符的一侧留黑边；关闭时窗口始终等于视频形状。',
			'settings.windowsPipResetPosition' => '重置小窗位置和大小',
			'settings.windowsPipResetPositionDesc' => '清除已存的小窗尺寸与位置，下次从右下角打开。',
			'settings.windowsPipResetPositionConfirm' => '确定要清除已保存的小窗位置和大小吗？',
			'settings.windowsPipResetAction' => '重置',
			'settings.windowsPipResetPositionSuccess' => '已清除保存的小窗位置和大小',
			'settings.fitHeight' => '适应高度',
			'settings.fitWidth' => '适应宽度',
			'settings.fitScaleDown' => '等比缩小',
			'settings.styleNoEmoji' => '纯文字模式（隐藏表情）',
			'settings.styleNoEmojiDesc' => '画面飞行弹幕只画文字，表情图片跳过；聊天列表不受影响。',
			'settings.portraitPresentationGroup' => '全屏呈现',
			'settings.portraitFullscreenPolicy' => '进入全屏时的方向',
			'settings.portraitFullscreenPolicyDesc' => '大屏和分屏设备自动交给系统布局，手机可跟随直播源',
			'settings.portraitFullscreenFollowSource' => '跟随直播源（推荐）',
			'settings.portraitFullscreenFollowSystem' => '跟随系统',
			'settings.portraitFullscreenLandscape' => '始终横屏',
			'settings.portraitReset' => '恢复竖屏适配默认设置',
			'settings.portraitResetDesc' => '把识别、自适应高度、布局模式与全屏方向恢复为默认值。',
			'settings.portraitResetConfirm' => '本页的竖屏设置将恢复默认值；普通横屏直播不受影响。',
			'settings.styleTopMargin' => '顶部留白（像素）',
			'settings.styleTopMarginDesc' => '画面顶部不显示弹幕的高度，0–300。',
			'settings.styleBottomMargin' => '底部留白（像素）',
			'settings.styleBottomMarginDesc' => '画面底部不显示弹幕的高度，避免挡住字幕，0–300。',
			'settings.roomCardSettingsTitle' => '房间卡片',
			'settings.roomCardSettingsDescription' => '版式固定，这里只选显示哪些信息；所有设备共用这一套。',
			'settings.roomCardPreview' => '卡片预览',
			'settings.roomCardPreviewTitle' => '今晚八点，一起聊聊新番和游戏',
			'settings.roomCardPreviewAnchor' => '夜色电台',
			'settings.roomCardPreviewArea' => '游戏分区',
			'settings.roomCardPreviewHint' => '这是实际使用的卡片与列表，改动会立刻反映在这里。',
			'settings.roomCardPresets' => '快捷预设',
			'settings.roomCardPresetStandard' => '标准',
			'settings.roomCardPresetDetailed' => '详细',
			'settings.roomCardPresetCustom' => '自定义',
			'settings.roomCardVisibleContent' => '显示内容',
			'settings.roomCardShowTitle' => '标题',
			'settings.roomCardShowCoverTitle' => '房间分区',
			'settings.roomCardShowStatus' => '直播状态',
			'settings.roomCardShowAvatar' => '主播头像',
			'settings.roomCardShowAnchor' => '主播名称',
			'settings.roomCardShowPlatform' => '平台显示',
			'settings.roomCardShowAudience' => '热度',
			'settings.roomCardReplay' => '回放',
			'settings.roomCardResetCurrent' => '恢复默认显示',
			'settings.roomCardResetConfirmTitle' => '恢复默认显示？',
			'settings.roomCardResetConfirmBody' => '所有显示项回到默认，当前选择会丢失。',
			'settings.backgroundPreviewMedia' => '预览',
			'settings.backgroundCopyColor' => '复制色值',
			'settings.backgroundCopyGradient' => '复制渐变',
			'settings.backgroundCopyAddress' => '复制地址',
			'settings.backgroundDownloadFailed' => '下载失败',
			'settings.backgroundPreviewVideoHint' => '播放控制仅用于本次预览；应用的动态壁纸始终静音循环。',
			'settings.cacheRefreshThumbnails' => '刷新缩略图',
			'settings.cacheRefreshThumbnailsDesc' => '清空封面、头像与图标缓存，下一次显示时重新下载。',
			'settings.cacheRefreshThumbnailsDone' => '缩略图已刷新',
			'settings.downloadDirectory' => '下载目录',
			'settings.downloadDirectoryDefaultLabel' => '默认',
			'settings.downloadDirectoryCustomLabel' => '自定义',
			'settings.downloadDirectoryReset' => '恢复默认目录',
			'settings.downloadDirectoryUpdated' => '下载目录已更新',
			'settings.downloadDirectoryPickFailed' => '无法选择下载目录',
			'settings.downloadDirectoryPermissionHint' => '所选目录无法写入：请授予存储权限，或改用默认目录。',
			'settings.downloadDirectoryChange' => '更改目录',
			'settings.portraitFullscreenGroup' => '竖屏全屏',
			'settings.portraitDisplayMode' => '画面模式',
			'settings.portraitDisplayModeDesc' => '完整=原样；沉浸=原样配柔和背景；均衡=轻微裁切；铺满=裁两侧填满。',
			'settings.portraitDanmakuMode' => '弹幕区域',
			'settings.portraitDanmakuModeDesc' => '竖屏全屏中飞行弹幕可占用的区域。',
			'settings.portraitRememberRoom' => '记住每个房间的选择',
			'settings.portraitRememberRoomDesc' => '竖屏全屏里的画面/弹幕切换按房间记住；关闭即清除。',
			'settings.portraitSwipeSwitch' => '竖屏全屏上下滑换台',
			'settings.portraitSwipeSwitchDesc' => '竖屏全屏时上滑看下一场、下滑看上一场。',
			'settings.portraitDiagnostics' => '显示竖屏诊断',
			'settings.portraitDiagnosticsDesc' => '在竖屏全屏左下角显示分辨率、宽高比、画面与弹幕模式。',
			'settings.portraitClearOverrides' => '清除房间覆盖',
			'settings.portraitClearOverridesDesc' => '删除所有按房间保存的竖屏画面与弹幕选择，保留全局默认。',
			'settings.portraitOverridesCleared' => '房间覆盖已清除',
			'settings.portraitOverridesCount' => ({required int count}) => '已保存 ${count} 个房间',
			'settings.chatShowNames' => '显示聊天用户名',
			'settings.chatShowNamesDesc' => '关闭后聊天列表只显示内容；长按操作仍知道发送者。',
			'settings.chatListFontSize' => '列表文字大小',
			'settings.chatListFontSizeDesc' => '聊天列表的文字大小；跟随主题时与界面保持一致。',
			'settings.chatListFollowTheme' => '跟随主题',
			'settings.chatListFontSizeValue' => ({required int size}) => '${size} px',
			'settings.chatListLineSpacing' => '列表行距',
			'settings.chatListLineSpacingDesc' => '聊天列表两行之间的留白。',
			'settings.chatListSpacingCompact' => '紧凑',
			'settings.chatListSpacingStandard' => '标准',
			'settings.chatListSpacingLoose' => '宽松',
			'settings.chatPanelWidth' => '聊天栏宽度',
			'settings.chatPanelWidthDesc' => '桌面宽布局下右侧聊天栏的宽度。',
			'settings.danmakuPausedBehavior' => '暂停时的弹幕',
			'settings.danmakuPausedBehaviorDesc' => '视频暂停后，弹幕跟着停住还是照常飘过。',
			'settings.danmakuPausedPause' => '随视频暂停',
			'settings.danmakuPausedFly' => '继续飘过',
			'settings.twitchLanguages' => 'Twitch 目录语言',
			'settings.twitchLanguagesDesc' => '只显示所选语言的直播；不选则显示全部。',
			'settings.twitchAllLanguages' => '全部语言',
			'settings.twitchLegacyLanguages' => '中文 + 韩语',
			'settings.twitchLanguagesHint' => '按主播语言过滤 Twitch 热门与分区目录。',
			'settings.twitchLanguage_zh' => '中文',
			'settings.twitchLanguage_en' => '英语',
			'settings.twitchLanguage_ko' => '韩语',
			'settings.twitchLanguage_ja' => '日语',
			'settings.twitchLanguage_es' => '西班牙语',
			'settings.twitchLanguage_pt' => '葡萄牙语',
			'settings.twitchLanguage_de' => '德语',
			'settings.twitchLanguage_fr' => '法语',
			'settings.twitchLanguage_ru' => '俄语',
			'settings.twitchLanguage_it' => '意大利语',
			'settings.twitchLanguage_th' => '泰语',
			'settings.twitchLanguage_vi' => '越南语',
			'settings.twitchLanguage_id' => '印度尼西亚语',
			'settings.twitchLanguage_tr' => '土耳其语',
			'settings.twitchLanguage_pl' => '波兰语',
			'settings.holdDanmakuOnPress' => '按住时冻结弹幕',
			'settings.holdDanmakuOnPressDesc' => '按住弹幕先冻结，便于点按；关闭后按住期间弹幕照常飞过。',
			'settings.youtubeAllChat' => 'YouTube 显示全部聊天',
			'settings.youtubeAllChatDesc' => '关闭时使用网页默认的 Top chat；开启后请求全部直播聊天。',
			'settings.preferH264' => '虎牙优先 H.264',
			'settings.preferH264Desc' => '平台同时提供多种编码时优先选择 H.264，兼容性更好。',
			'settings.clipboardRoomTitle' => '打开剪贴板中的直播间？',
			'settings.clipboardRoomDesc' => ({required Object platform, required Object roomId}) => '检测到 ${platform} 的直播间 ${roomId}，是否打开？',
			'settings.clipboardRoomOpen' => '打开直播间',
			'settings.backgroundAudioOnly' => '后台仅音频',
			'settings.backgroundAudioOnlyDesc' => '后台播放时关闭视频解码，只保留声音；回到前台恢复画面。',
			'settings.pauseOnPipClose' => '关闭画中画时暂停',
			'settings.pauseOnPipCloseDesc' => '开着后台播放时，关小窗即暂停；回应用再继续。',
			'settings.chatShowGifts' => '在聊天列表显示礼物',
			'settings.chatShowGiftsDesc' => '礼物显示为聊天里的礼物行；关闭后立即移除已有礼物行。',
			'settings.chatGiftsAboveTier' => '只显示值钱的礼物',
			'settings.chatGiftsAboveTierDesc' => '免费和便宜的礼物不进聊天列表；连击加起来够了再显示。',
			'settings.chatGiftValueInYuan' => '礼物价值换算成元',
			'settings.chatGiftValueInYuanDesc' => '金瓜子、钻石、抖币按平台的固定比例写成元；海外的币种不换算。',
			'settings.superChatIncludesMembership' => '上舰和开会员进醒目留言',
			'settings.superChatIncludesMembershipDesc' => 'B 站上舰、YouTube 会员等订阅也在醒目留言里出卡；聊天列表照旧。',
			'settings.danmakuShowGifts' => '飞行弹幕显示礼物',
			'settings.danmakuShowGiftsDesc' => '值钱礼物飞过画面，更值钱的在顶部停 4 秒；连击只显示开头和总数。',
			'settings.floatWindowSize' => '小窗大小',
			'settings.floatWindowSizeDesc' => '应用内悬浮窗的基础大小；拖动缩放会按横屏/竖屏分别记住。',
			'settings.floatWindowSmall' => '小',
			'settings.floatWindowMedium' => '中',
			'settings.floatWindowLarge' => '大',
			'settings.backgroundPauseDanmaku' => '后台暂停弹幕连接',
			'settings.backgroundPauseDanmakuDesc' => '进入后台时断开平台弹幕连接，回到前台重新连接；聊天记录保留。',
			'settings.douyuForceRenew' => '斗鱼每 5 分钟自动续期',
			'settings.douyuForceRenewDesc' => '登录后定期续期 Cookie，降低长时间观看掉登录的概率。',
			'settings.tvFocusZoom' => '焦点放大',
			'settings.tvFocusZoomDesc' => '焦点卡片与控件略微放大；盒子卡顿时可关掉只留描边。',
			'settings.tvMenuExpanded' => 'TV 侧栏始终展开',
			'settings.tvMenuExpandedDesc' => '保持侧栏显示名称；关闭后可用图标轨并在聚焦时展开。',
			'settings.backgroundPreviewSettingsTitle' => '播放设置',
			'settings.backgroundMoreImages' => '更多图片',
			'settings.backgroundMoreVideos' => '更多视频',
			'settings.backgroundDisplayMode' => '显示模式',
			'settings.backgroundAutoPlay' => '自动播放',
			'settings.backgroundPlayInterval' => '播放间隔',
			'settings.backgroundIntervalSeconds' => ({required Object count}) => '${count} 秒',
			'settings.backgroundPreviewLooping' => '循环播放',
			'settings.navHongguo' => '红果短剧',
			'settings.hongguoDescription' => '红果伴侣服务与播放偏好。',
			'settings.hongguoQuality' => '默认清晰度',
			'settings.hongguoQualityDesc' => '打开剧集时优先请求的清晰度；不存在时自动取更低一档。',
			'settings.hongguoQualityBest' => '最高',
			'settings.hongguoQuality1080' => '1080P',
			'settings.hongguoQuality720' => '720P',
			'settings.hongguoQuality540' => '540P',
			'settings.hongguoQuality480' => '480P',
			'settings.hongguoQuality360' => '360P',
			'settings.hongguoDeviceReset' => '重置设备身份',
			'settings.hongguoDeviceResetDesc' => '忘记当前匿名设备身份，下次播放时重新向平台注册。',
			'shield.title' => '弹幕屏蔽',
			'shield.description' => '按关键词、用户与相似度过滤直播间弹幕，规则保存在本机。',
			'shield.masterTitle' => '总开关',
			'shield.enabled' => '启用弹幕屏蔽',
			'shield.enabledDescription' => '关闭后所有屏蔽规则临时失效',
			'shield.similarityTitle' => '相似弹幕过滤',
			'shield.similarityEnabled' => '启用相似弹幕过滤',
			'shield.similarityEnabledDescription' => '自动过滤短时间内高度相似的弹幕，仅作用于平台消息。',
			'shield.similarityThreshold' => '相似度阈值',
			'shield.similarityThresholdDescription' => '相似度越高，过滤越严格',
			'shield.similarityCacheDuration' => '缓存时间',
			'shield.similarityCacheDurationDescription' => '相同或相似的弹幕在这段时间内不会重复显示',
			'shield.similarityMaxCacheSize' => '最大缓存数量',
			'shield.similarityMaxCacheSizeDescription' => '限制相似弹幕缓存占用的内存',
			'shield.similaritySeconds' => ({required Object seconds}) => '${seconds} 秒',
			'shield.repeatTitle' => '重复弹幕过滤',
			'shield.repeatEnabled' => '合并短时间内的相同弹幕',
			'shield.repeatEnabledDescription' => '不同用户发送相同内容时只保留第一条；本地弹幕和系统消息不受影响。',
			'shield.repeatWindow' => '相同内容合并时间（秒）',
			'shield.keywordsTitle' => '关键词',
			'shield.usersTitle' => '用户',
			'shield.keywordFieldHint' => '输入要屏蔽的关键词',
			'shield.userFieldHint' => '输入要屏蔽的用户名',
			'shield.add' => '添加',
			'shield.keywordsEmpty' => '还没有屏蔽关键词',
			'shield.usersEmpty' => '还没有屏蔽的用户',
			'shield.clear' => '清空全部',
			'shield.clearConfirmDesc' => '列表将被清空，需要时再重新添加。',
			'shield.duplicateEntry' => '该条目已在屏蔽列表中',
			'shield.invalidEntry' => '内容不能为空',
			'shield.added' => '已添加屏蔽',
			'shield.removed' => '已移除',
			'shield.cleared' => '已清空',
			'shield.removeEntry' => '移除这条屏蔽规则',
			'shield.effectNote' => '屏蔽在直播间弹幕中立即生效。',
			'shield.contentTitle' => '内容屏蔽',
			'shield.blockEmoteOnly' => '屏蔽只有表情的弹幕',
			'shield.blockEmoteOnlyDescription' => '只有表情、没有文字的弹幕不显示；自己发送的弹幕不会被屏蔽。',
			'shield.blockLong' => '屏蔽超长弹幕',
			'shield.blockLongDescription' => '超过设定字数的弹幕不显示（一个表情算一个字）。',
			'shield.blockLongLength' => '最多字数',
			'shield.blockLongLengthDescription' => '允许显示的最大字数，范围 10–100（一个表情算一个字）。',
			'shield.blockLongLengthValue' => ({required int count}) => '${count} 字',
			'shield.douyuSuspected' => '过滤斗鱼疑似自动弹幕',
			'shield.douyuSuspectedDescription' => '开启后按启发式标记隐藏疑似自动或活动弹幕，也可能隐藏普通聊天',
			'sites.title' => '站点',
			'sites.live' => '直播',
			'sites.search' => '搜索',
			'sites.rooms' => '房间',
			'toolbox.title' => '工具箱',
			'toolbox.groupLinks' => '链接工具',
			'toolbox.groupNetwork' => '网络',
			'toolbox.groupData' => '数据',
			'toolbox.toolNetworkTitle' => '平台节点',
			'toolbox.toolNetworkDescription' => '测试各平台接口的连通性与延迟。',
			'toolbox.toolCacheTitle' => '缓存清理',
			'toolbox.toolCacheDescription' => '查看并清理图片占用的内存缓存。',
			'toolbox.toolLogsTitle' => '日志',
			'toolbox.toolLogsDescription' => '查看应用运行日志与诊断信息。',
			'toolbox.back' => '返回',
			'toolbox.confirm' => '确认',
			'toolbox.cancel' => '取消',
			'toolbox.linkFieldLabel' => '平台链接',
			'toolbox.linkFieldHint' => '粘贴直播间链接或分享文字',
			'toolbox.linkOpen' => '打开直播间',
			'toolbox.linkCopy' => '复制房间链接',
			'toolbox.linkPaste' => '粘贴',
			'toolbox.linkClear' => '清空',
			'toolbox.linkClipboardGroup' => '剪贴板',
			'toolbox.linkClipboardRooms' => '识别剪贴板直播间链接',
			'toolbox.linkClipboardRoomsDesc' => '回应用时读取剪贴板，发现直播链接会询问是否打开；不自动跳转。',
			'toolbox.linkResolving' => '正在解析链接…',
			'toolbox.linkResolvedTitle' => '解析结果',
			'toolbox.linkPlatform' => '平台',
			'toolbox.linkRoom' => '房间号',
			'toolbox.linkEmpty' => '请先粘贴链接',
			'toolbox.linkUnsupported' => '无法识别该链接，暂不支持此平台。',
			'toolbox.linkTimeout' => '解析超时，请检查网络后重试。',
			'toolbox.linkFailed' => '解析失败，请稍后重试。',
			'toolbox.linkCopyDone' => '已复制房间链接',
			'toolbox.linkCopyFailed' => '复制失败',
			'toolbox.linkSupportTitle' => '支持解析的平台',
			'toolbox.linkSupportHint' => '以下平台的直播间链接可以直接解析并打开。',
			'toolbox.networkSiteLabel' => '选择平台',
			'toolbox.networkRun' => '开始检测',
			'toolbox.networkResultTitle' => '检测结果',
			'toolbox.networkTarget' => '探测接口',
			'toolbox.networkTargetDesc' => '推荐房间接口',
			'toolbox.networkLatency' => '响应时间',
			_ => null,
		} ?? switch (path) {
			'toolbox.networkRooms' => '返回房间',
			'toolbox.networkSuccess' => '连接正常',
			'toolbox.networkFailure' => '连接失败',
			'toolbox.networkBusy' => '正在检测…',
			'toolbox.networkUnsupported' => '该平台暂不支持探测。',
			'toolbox.cacheSection' => '图片缓存',
			'toolbox.cacheEntries' => '缓存图片',
			'toolbox.cacheSize' => '占用内存',
			'toolbox.cacheClear' => '清理缓存',
			'toolbox.cacheClearDesc' => '释放图片缓存占用的内存，不影响收藏与历史。',
			'toolbox.cacheConfirmTitle' => '清理图片缓存？',
			'toolbox.cacheConfirmDesc' => '已加载的图片会重新下载，收藏与历史不受影响。',
			'toolbox.cacheDone' => '缓存已清理',
			'toolbox.cacheEmpty' => '暂无缓存',
			'toolbox.comingSoonTitle' => '即将推出',
			'toolbox.comingSoonDesc' => '这个工具还没有完成，敬请期待。',
			'toolbox.linkDirect' => '获取直链',
			'toolbox.linkDirectTitle' => '直链地址',
			'toolbox.linkDirectQuality' => '画质',
			'toolbox.linkDirectLines' => '播放地址',
			'toolbox.linkDirectCopy' => '复制',
			'toolbox.linkDirectCopyDone' => '直链已复制',
			'toolbox.linkDirectEmpty' => '这个房间暂时没有可用的直链',
			'toolbox.linkDirectFailed' => '直链读取失败',
			'toolbox.nodeTestAll' => '全部测速',
			'toolbox.nodeTest' => '测速',
			'toolbox.nodeTesting' => '测速中',
			'toolbox.nodeUntested' => '未测速',
			'toolbox.nodeReachable' => '正常',
			'toolbox.nodeFailed' => '失败',
			'toolbox.nodeNoSites' => '没有可测速的平台',
			'toolbox.nodeHint' => '点「测速」检查这个平台。',
			'toolbox.nodeAnswer' => ({required int count}) => '返回 ${count} 个房间',
			'toolbox.nodeSourceRecommended' => '推荐接口',
			'toolbox.nodeSourceHot' => '热门接口',
			'toolbox.nodeSummary' => ({required Object ok, required Object tested, required Object total}) => '${ok} / ${tested} 可用 · 共 ${total} 个平台',
			'toolbox.nodeUntestedSummary' => ({required Object total}) => '尚未测速 · 共 ${total} 个平台',
			'toolbox.logsSection' => '日志与诊断',
			'toolbox.logsLevel' => '日志级别',
			'toolbox.logsFile' => '写入日志文件',
			'toolbox.logsFileDesc' => '在应用数据目录保存轮转日志 pure_live.log；关闭只留内存日志。',
			'toolbox.logsExport' => '复制日志',
			'toolbox.logsExportDesc' => '把内存中的日志复制到剪贴板。',
			'toolbox.logsClear' => '清空日志',
			'toolbox.logsClearDesc' => '只清除内存中的日志，已写入的文件保留。',
			'toolbox.logsClearConfirm' => '清空内存日志？',
			'toolbox.logsClearConfirmDesc' => '内存中的日志会被删除，日志文件不受影响。',
			'toolbox.logsSearch' => '搜索日志…',
			'toolbox.logsEmptyTitle' => '还没有日志',
			'toolbox.logsEmptyDescription' => '应用启动、网络请求与错误会记录在这里。',
			'toolbox.logsAutoOn' => '自动滚动已开启',
			'toolbox.logsAutoOff' => '自动滚动已关闭（滚动到底部可开启）',
			'toolbox.logsLines' => ({required int count}) => '${count} 行',
			'toolbox.logsScrollBottom' => '滚动到底部',
			'toolbox.logsCopied' => '日志已复制',
			'toolbox.logsCopyEmpty' => '没有可复制的日志',
			'toolbox.logsDirectoryDefault' => '日志文件尚未就绪。',
			'toolbox.logsFileTitle' => '日志文件',
			'toolbox.logsOpenFolder' => '打开所在文件夹',
			'toolbox.logsCopyPath' => '复制路径',
			'toolbox.logsPathCopied' => '路径已复制到剪贴板',
			'toolbox.logsOpenFailed' => '无法打开日志目录',
			'vod.searchHint' => '搜索 Bilibili 视频',
			'vod.idleTitle' => '搜索点播视频',
			'vod.idleDescription' => '输入关键词搜索 Bilibili 的视频。',
			'vod.noResultsTitle' => '没有找到视频',
			'vod.noResultsDescription' => '换个关键词再试试。',
			'vod.errorTitle' => '视频没有加载出来',
			'vod.retry' => '重试',
			'vod.tabRecommend' => '推荐',
			'vod.tabPopular' => '热门',
			'vod.tabDynamics' => '动态',
			'vod.dynamicsLoginTitle' => '登录后查看动态',
			'vod.dynamicsLoginDescription' => '动态来自你关注的 UP 主，需要一个 Bilibili 登录。',
			'vod.signIn' => '登录 Bilibili',
			'vod.dynamicsFailed' => '动态没有加载出来',
			'vod.dynamicsEmptyTitle' => '还没有动态',
			'vod.dynamicsEmptyDescription' => '关注的 UP 主更新后会出现在这里。',
			'vod.loadMore' => '加载更多',
			'vod.regions' => '分区',
			'vod.search' => '搜索',
			'vod.home' => '主页',
			'vod.personal' => '个人',
			'vod.live' => '直播',
			'vod.searchKindVideo' => '视频',
			'vod.searchKindBangumi' => '番剧',
			'vod.searchKindCinema' => '影视',
			'vod.searchKindUser' => '用户',
			'vod.searchKindLiveRoom' => '直播间',
			'vod.living' => '直播中',
			'vod.fans' => '粉丝',
			'vod.videoCount' => '视频',
			'vod.liveFollowTitle' => '我的关注',
			'vod.liveAreasTitle' => '推荐分区',
			'vod.liveRecommendTitle' => '推荐直播',
			'vod.liveEmptyTitle' => '没有推荐的直播',
			'vod.liveEmptyDescription' => '稍后刷新再看看。',
			'vod.refresh' => '刷新',
			'vod.regionEmptyDescription' => '这个分区暂时没有推荐视频。',
			'vod.pgcTitle' => '影视',
			'vod.pgcAnime' => '番剧',
			'vod.pgcMovie' => '电影',
			'vod.pgcDocumentary' => '纪录片',
			'vod.pgcGuochuang' => '国创',
			'vod.pgcTv' => '电视剧',
			'vod.pgcVariety' => '综艺',
			'vod.pgcEmptyDescription' => '这个分类暂时没有内容。',
			'vod.episodes' => '选集',
			'vod.following' => '已追',
			'vod.pictureOnly' => '仅画面',
			'vod.sort' => '排序',
			'vod.sortTotalrank' => '综合',
			'vod.sortClick' => '播放多',
			'vod.sortPubdate' => '最新',
			'vod.sortDm' => '弹幕多',
			'vod.sortStow' => '收藏多',
			'vod.duration' => '时长',
			'vod.durationAny' => '全部时长',
			'vod.durationUnder10' => '10 分钟以下',
			'vod.duration10to30' => '10–30 分钟',
			'vod.duration30to60' => '30–60 分钟',
			'vod.durationOver60' => '60 分钟以上',
			'vod.related' => '相关推荐',
			'vod.changeRelated' => '换一换',
			'vod.expand' => '展开',
			'vod.collapse' => '收起',
			'vod.parts' => '分P',
			'vod.views' => '播放',
			'vod.danmakuOn' => '显示弹幕',
			'vod.danmakuOff' => '隐藏弹幕',
			'vod.danmaku' => '弹幕',
			'vod.likes' => '点赞',
			'vod.coins' => '投币',
			'vod.favorites' => '收藏',
			'vod.description' => '简介',
			'vod.noDescription' => '这个视频没有简介。',
			'vod.play' => '播放',
			'vod.pause' => '暂停',
			'vod.mute' => '静音',
			'vod.unmute' => '取消静音',
			'vod.volume' => '音量',
			'vod.quality' => '清晰度',
			'vod.speed' => '倍速',
			'vod.fullscreen' => '全屏',
			'vod.exitFullscreen' => '退出全屏',
			'vod.pip' => '小窗播放',
			'vod.exitPip' => '退出小窗',
			'vod.silentNotice' => '这个清晰度只有画面，没有声音；换一个清晰度试试。',
			'vod.opening' => '正在打开视频…',
			'vod.loadFailed' => '视频信息加载失败',
			'vod.openFailed' => '视频打开失败',
			'vod.progress' => '播放进度',
			'vod.up' => 'UP主',
			'vod.openingSpeed' => '默认倍速',
			'vod.openingSpeedDesc' => '打开视频时使用的播放速度；播放器里的倍速菜单只影响当前视频。',
			'vod.finishAction' => '播放结束动作',
			'vod.finishActionDesc' => '一集播完之后做什么。',
			'vod.finishPause' => '停在最后一帧',
			'vod.finishNextPart' => '播放下一分P',
			'vod.finishExit' => '退出播放',
			'vod.finishRelated' => '播放相关推荐',
			'vod.showDetails' => '显示视频详情',
			'vod.showDetailsDesc' => '关闭后只看播放器、分P和相关推荐，隐藏UP主、数据和简介。',
			'vod.playbackReset' => '恢复默认播放行为',
			'vod.playbackResetDesc' => '默认倍速、播完下一分P、显示详情。',
			'vod.personalTitle' => '我的视频',
			'vod.personalToView' => '稍后再看',
			'vod.personalHistory' => '历史',
			'vod.personalFavourites' => '收藏',
			'vod.personalFollowing' => '追番',
			'vod.followingBangumi' => '番剧',
			'vod.followingCinema' => '影视',
			'vod.personalCount' => ({required Object count}) => '共 ${count} 个',
			'vod.signInNeededTitle' => '登录后可见',
			'vod.signInNeededDescription' => '这个列表在你登录的 Bilibili 账号上。',
			'vod.toViewEmptyTitle' => '稍后再看是空的',
			'vod.toViewEmptyDescription' => '在 Bilibili 上标记「稍后再看」的视频会出现在这里。',
			'vod.followingEmptyTitle' => '还没有追番',
			'vod.followingEmptyDescription' => '在 Bilibili 上追的番剧和影视会出现在这里。',
			'vod.comments' => '评论',
			'vod.commentsHot' => '最热',
			'vod.commentsNew' => '最新',
			'vod.commentsEmpty' => '还没有评论。',
			'vod.commentsFailed' => '评论没有加载出来',
			'vod.historyEmptyTitle' => '还没有观看记录',
			'vod.historyEmptyDescription' => '看过的视频会出现在这里，并保留上次的播放位置。',
			'vod.historyCompleted' => '已看完',
			'vod.historyProgress' => ({required Object position, required Object total}) => '${position} / ${total}',
			'vod.historyRemove' => '从历史中移除',
			'vod.clearHistory' => '清空历史',
			'vod.clearHistoryTitle' => '清空观看历史？',
			'vod.clearHistoryDesc' => '只删除本机的观看记录，不影响 Bilibili 上的进度。',
			'vod.favouritesEmptyTitle' => '还没有收藏的视频',
			'vod.favouritesEmptyDescription' => '在视频页点收藏，视频会出现在这里。',
			'vod.favouriteRemove' => '取消收藏',
			'vod.saveVideo' => '收藏',
			'vod.savedVideo' => '已收藏',
			'vod.saveAdded' => '已加入收藏',
			'vod.saveRemoved' => '已取消收藏',
			'vod.download' => '下载视频',
			'vod.downloading' => ({required int percent}) => '下载中 ${percent}%',
			'vod.downloadingUnknown' => '下载中…',
			'vod.downloadDone' => ({required String name}) => '已下载到 ${name}',
			'vod.downloadFailed' => '下载失败',
			'vod.downloadCancelled' => '已取消下载',
			'vod.downloadCancel' => '取消下载',
			'wallpaper.title' => '随机图源',
			'wallpaper.description' => '按分组从公开随机接口取图，预览后再应用。',
			'wallpaper.sourceCount' => ({required Object count}) => '${count} 个来源',
			'wallpaper.another' => '换一张',
			'wallpaper.fetching' => '正在取图…',
			'wallpaper.fetchFailed' => '这张图没有取到',
			'wallpaper.unsupported' => '图源返回了无法显示的图片格式',
			'wallpaper.previewDisplay' => '显示设置',
			'wallpaper.previewVideoNote' => '应用后壁纸仍静音循环；这里的播放、暂停与声音只用于预览。',
			'wallpaper.previewTitle' => '随机图片预览',
			'wallpaper.applied' => '已应用为背景',
			'wallpaper.sourceLabel' => '来源',
			'wallpaper.retry' => '重试',
			'wallpaper.groupBing' => '必应壁纸',
			'wallpaper.sourceBingBiturl' => '必应随机Biturl',
			'wallpaper.sourceBingJasonZeng' => '必应随机Jason Zeng',
			'wallpaper.sourceBingUapi' => '必应随机UAPI',
			'wallpaper.sourceBingYingJoy' => '必应随机YingJoy',
			'wallpaper.sourceBingW3h5' => '必应W3H5',
			'wallpaper.sourceBingWumingDaily' => '无铭必应每日壁纸',
			'wallpaper.groupAlcy' => '栗次元',
			'wallpaper.sourceAlcyRandom' => '栗次元 · 随机',
			'wallpaper.sourceAlcyYcy' => '栗次元 · ycy',
			'wallpaper.sourceAlcyMoez' => '栗次元 · moez',
			'wallpaper.sourceAlcyYsz' => '栗次元 · ysz',
			'wallpaper.sourceAlcyYs' => '栗次元 · ys',
			'wallpaper.sourceAlcyMp' => '栗次元 · mp',
			'wallpaper.sourceAlcyMoemp' => '栗次元 · moemp',
			'wallpaper.sourceAlcyYsmp' => '栗次元 · ysmp',
			'wallpaper.sourceAlcyTx' => '栗次元 · tx',
			'wallpaper.sourceAlcyLai' => '栗次元 · lai',
			'wallpaper.sourceAlcyXhl' => '栗次元 · xhl',
			'wallpaper.sourceAlcyBd' => '栗次元 · bd',
			'wallpaper.groupWuming' => '无铭 API',
			'wallpaper.sourceWumingGirl' => '无铭随机美囡图片',
			'wallpaper.sourceWumingBlackStocking' => '无铭随机黑丝图片',
			'wallpaper.sourceWumingDouyinGirl' => '抖音美女·无铭API',
			'wallpaper.sourceWumingWhiteStocking' => '无铭随机白丝图片',
			'wallpaper.sourceWumingDouyinGirlAlt' => '无铭随机抖音美女图片',
			'wallpaper.sourceWumingBcyCos' => '无铭半次元cosplay',
			'wallpaper.sourceWumingAnimeWallpaper' => '无铭动漫壁纸',
			'wallpaper.sourceWumingAestheticGirl' => '无铭随机唯美女生图片',
			'wallpaper.groupUapi' => 'UAPI 随机图',
			'wallpaper.sourceUapiAll' => 'UAPI全部随机',
			'wallpaper.sourceUapiAcg' => 'UAPI二次元动漫',
			'wallpaper.sourceUapiAcgPc' => 'UAPI二次元·电脑',
			'wallpaper.sourceUapiAcgMobile' => 'UAPI二次元·手机',
			'wallpaper.sourceUapiLandscape' => 'UAPI风景图',
			'wallpaper.sourceUapiAnime' => 'UAPI混合动漫',
			'wallpaper.sourceUapiPcWallpaper' => 'UAPI电脑壁纸',
			'wallpaper.sourceUapiMobileWallpaper' => 'UAPI手机壁纸',
			'wallpaper.sourceUapiGeneralAnime' => 'UAPI动漫图',
			'wallpaper.sourceUapiFurry' => 'UAPI福瑞',
			'wallpaper.sourceUapiFurryZ4k' => 'UAPI福瑞·z4k',
			'wallpaper.sourceUapiFurrySzs8k' => 'UAPI福瑞·szs8k',
			'wallpaper.sourceUapiFurryS4k' => 'UAPI福瑞·s4k',
			'wallpaper.sourceUapiFurry4k' => 'UAPI福瑞·4k',
			'wallpaper.group360' => '360壁纸',
			'wallpaper.source360Beauty' => '360壁纸美女',
			'wallpaper.source360Landscape' => '360壁纸风景',
			'wallpaper.source360Game' => '360壁纸游戏',
			'wallpaper.source360Movie' => '360壁纸影视',
			'wallpaper.source360Fashion' => '360壁纸时尚',
			'wallpaper.source360Star' => '360壁纸明星',
			'wallpaper.source360Car' => '360壁纸汽车',
			'wallpaper.source360Pet' => '360壁纸萌宠',
			'wallpaper.source360Fresh' => '360壁纸清新',
			'wallpaper.source360Sport' => '360壁纸体育',
			'wallpaper.source360Child' => '360壁纸萌娃',
			'wallpaper.source360Military' => '360壁纸军事',
			'wallpaper.source360Anime' => '360壁纸动漫',
			'wallpaper.source360Calendar' => '360壁纸日历',
			'wallpaper.source360Love' => '360壁纸爱情',
			'wallpaper.source360Motto' => '360壁纸格言',
			'wallpaper.groupMisc' => '其他图源',
			'wallpaper.sourceXxapi' => '小晓API',
			'wallpaper.sourceMtyqx' => 'mtyqx',
			'wallpaper.sourcePicsum' => 'picsum',
			'wallpaper.sourceDmoe' => 'dmoe',
			'wallpaper.sourceLoliapi' => 'loliApi',
			'wallpaper.sourceCatvod' => 'catvod',
			'wallpaper.groupSexy' => '性感美女',
			'wallpaper.sourceSexyBlackStockingXxapi' => '随机黑丝·小小API',
			'wallpaper.sourceSexyWhiteStockingXxapi' => '随机白丝·小小API',
			'wallpaper.sourceSexyJkXxapi' => '随机JK·小小API',
			'wallpaper.sourceSexyGirlSuyan' => '随机小姐姐·素颜API',
			'wallpaper.sourceSexyBeautySuyan' => '随机美女·素颜API',
			'wallpaper.sourceSexyMeiziSuyan' => '随机妹子·素颜API',
			'wallpaper.sourceSexyBlackStockingSuyan' => '随机黑丝·素颜API',
			'wallpaper.sourceSexyMeiziXiaodu' => '随机妹子·小渡API',
			'wallpaper.sourceSexyStockingNonebot' => '随机丝袜·Nonebot',
			'wallpaper.sourceSexyPcLtywl' => 'PC美女壁纸·Ltywl',
			'wallpaper.sourceSexyPeLtywl' => 'PE美女壁纸·Ltywl',
			'wallpaper.sourceSexyBeautyApizero' => '美女壁纸·极数本源',
			'wallpaper.sourceSexyPcNsuuu' => '电脑端小姐姐·Nsuuu',
			'wallpaper.sourceSexyWhiteStockingNsuuu' => '随机白丝·Nsuuu',
			'wallpaper.sourceSexyBeautyBtstu' => '随机美女·搏天API',
			'wallpaper.sourceSexyAnimeBtstu' => '随机二次元·搏天API',
			'wallpaper.sourceSexyGirlKuaishou' => '随机小姐姐·快手',
			'wallpaper.sourceSexyCosNonebot' => '随机Cos·Nonebot',
			'wallpaper.sourceSexyBeautyCzl' => '随机美女·CZL',
			'wallpaper.sourceSexyBeautyMioical' => '随机美女·Mioical',
			_ => null,
		};
	}
}
