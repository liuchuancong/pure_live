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

	/// zh-CN: '在已登录的浏览器中复制该网站的 Cookie，粘贴到下面（形如 name=value; name2=value2）。'
	String get cookieDialogHint => '在已登录的浏览器中复制该网站的 Cookie，粘贴到下面（形如 name=value; name2=value2）。';

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

	/// zh-CN: '在平台分区或直播间里点爱心即可关注'
	String get followedEmptyHint => '在平台分区或直播间里点爱心即可关注';

	/// zh-CN: '没有可浏览的平台'
	String get noPlatforms => '没有可浏览的平台';

	/// zh-CN: '取消关注'
	String get unfollow => '取消关注';

	/// zh-CN: '全部分类'
	String get categoryAll => '全部分类';

	/// zh-CN: '关注分区'
	String get follow => '关注分区';
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

	/// zh-CN: '把关注、观看历史、关注分区与设置打包为一个 JSON 文件，通过系统分享面板保存。'
	String get exportDescription => '把关注、观看历史、关注分区与设置打包为一个 JSON 文件，通过系统分享面板保存。';

	/// zh-CN: '没有可备份的数据'
	String get exportEmpty => '没有可备份的数据';

	/// zh-CN: '备份文件已生成'
	String get exportDone => '备份文件已生成';

	/// zh-CN: '导出失败'
	String get exportFailed => '导出失败';

	/// zh-CN: '导入备份'
	String get importTitle => '导入备份';

	/// zh-CN: '粘贴备份 JSON 的内容，确认后覆盖当前数据；也可以从 WebDAV 下载并恢复。'
	String get importDescription => '粘贴备份 JSON 的内容，确认后覆盖当前数据；也可以从 WebDAV 下载并恢复。';

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

	/// zh-CN: '备份以 {file} 存放在服务器目录，上传覆盖、下载恢复。'
	String webdavDescription({required Object file}) => '备份以 ${file} 存放在服务器目录，上传覆盖、下载恢复。';

	/// zh-CN: '服务器配置'
	String get webdavConfigTitle => '服务器配置';

	/// zh-CN: '填写 WebDAV 服务器地址与账号；密码保存在系统安全存储中，不进入备份。'
	String get webdavConfigDescription => '填写 WebDAV 服务器地址与账号；密码保存在系统安全存储中，不进入备份。';

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

	/// zh-CN: '将用 {name: String} 覆盖本机的关注、观看历史、关注分区与设置，当前数据无法找回。'
	String restoreConfirmDesc({required String name}) => '将用 ${name} 覆盖本机的关注、观看历史、关注分区与设置，当前数据无法找回。';

	/// zh-CN: '将用 {name: String} 覆盖本机的关注与关注分区，其他数据保持不变。'
	String restoreFollowsConfirmDesc({required String name}) => '将用 ${name} 覆盖本机的关注与关注分区，其他数据保持不变。';

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

	/// zh-CN: '更多'
	String get more => '更多';

	/// zh-CN: '删除'
	String get delete => '删除';

	/// zh-CN: '新建窗口'
	String get newWindow => '新建窗口';
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

	/// zh-CN: '每页'
	String get perPage => '每页';

	/// zh-CN: '跳转至'
	String get goTo => '跳转至';

	/// zh-CN: '页'
	String get pageUnit => '页';

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

	/// zh-CN: '新标签名称'
	String get tagFieldHint => '新标签名称';

	/// zh-CN: '添加标签'
	String get addTag => '添加标签';

	/// zh-CN: '删除标签“{name: String}”？'
	String deleteTagTitle({required String name}) => '删除标签“${name}”？';

	/// zh-CN: '所有直播间都会移出这个标签，直播间本身不会被取消关注。'
	String get deleteTagBody => '所有直播间都会移出这个标签，直播间本身不会被取消关注。';

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

	/// zh-CN: '关闭筛选'
	String get filterClose => '关闭筛选';

	/// zh-CN: '按标题、主播、房间号或平台筛选'
	String get filterHint => '按标题、主播、房间号或平台筛选';

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

	/// zh-CN: '确定清空这 {count: int} 条观看记录吗？此操作不可撤销。'
	String clearConfirmDesc({required int count}) => '确定清空这 ${count} 条观看记录吗？此操作不可撤销。';

	/// zh-CN: '确定删除筛选出的 {count: int} 条观看记录吗？其他记录不受影响，此操作不可撤销。'
	String clearFilteredConfirmDesc({required int count}) => '确定删除筛选出的 ${count} 条观看记录吗？其他记录不受影响，此操作不可撤销。';

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

	/// zh-CN: '进入直播间'
	String get openRoom => '进入直播间';
}

// Path: iptv
class Translations$iptv$zh_CN {
	Translations$iptv$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '全部'
	String get tabAll => '全部';

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

	/// zh-CN: '导入播放列表、节目单和播放请求使用的 User-Agent；留空使用应用默认值。播放列表自带的 User-Agent 优先。'
	String get customUserAgentDesc => '导入播放列表、节目单和播放请求使用的 User-Agent；留空使用应用默认值。播放列表自带的 User-Agent 优先。';

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

	/// zh-CN: '歌曲、歌单与榜单正在路上'
	String get tagline => '歌曲、歌单与榜单正在路上';

	/// zh-CN: '音乐视图'
	String get viewsLabel => '音乐视图';

	/// zh-CN: '乐库'
	String get tabLibrary => '乐库';

	/// zh-CN: '歌单'
	String get tabPlaylists => '歌单';

	/// zh-CN: '榜单'
	String get tabCharts => '榜单';

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

	/// zh-CN: '链接解析'
	String get toolbox => '链接解析';

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

	/// zh-CN: '每页'
	String get perPage => '每页';

	/// zh-CN: '每页 {size: int} 个'
	String pageSize({required int size}) => '每页 ${size} 个';
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

	/// zh-CN: '卡片宽度、每页数量与窗口行为。'
	String get generalDescription => '卡片宽度、每页数量与窗口行为。';

	/// zh-CN: '主题模式、对比度、圆角与字体。'
	String get appearanceDescription => '主题模式、对比度、圆角与字体。';

	/// zh-CN: '主题、外观、背景与导航。'
	String get personalizationDescription => '主题、外观、背景与导航。';

	/// zh-CN: '直播资源、弹幕与录制。'
	String get liveSettingsDescription => '直播资源、弹幕与录制。';

	/// zh-CN: '平台显示、排序与关注自动刷新。'
	String get liveSourcesDescription => '平台显示、排序与关注自动刷新。';

	/// zh-CN: '播放偏好与播放器内核。'
	String get playbackSettingsDescription => '播放偏好与播放器内核。';

	/// zh-CN: '常规、网络、诊断、数据与备份。'
	String get systemDescription => '常规、网络、诊断、数据与备份。';

	/// zh-CN: '观看历史、关注导入导出与封面缓存。'
	String get dataCacheDescription => '观看历史、关注导入导出与封面缓存。';

	/// zh-CN: '选择要应用的主题'
	String get personalizationChooseTheme => '选择要应用的主题';

	/// zh-CN: '个性化设置'
	String get personalizationSettings => '个性化设置';

	/// zh-CN: '画质、比例与播放器行为。'
	String get playbackDescription => '画质、比例与播放器行为。';

	/// zh-CN: '浏览站点与登录账号。'
	String get sitesDescription => '浏览站点与登录账号。';

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

	/// zh-CN: '语言'
	String get language => '语言';

	/// zh-CN: '关于'
	String get about => '关于';

	/// zh-CN: '浏览偏好'
	String get browsingTitle => '浏览偏好';

	/// zh-CN: '默认站点'
	String get site => '默认站点';

	/// zh-CN: '卡片宽度'
	String get cardExtent => '卡片宽度';

	/// zh-CN: '首页与分区流里一张卡片的宽度；越小一排越多。'
	String get cardExtentDescription => '首页与分区流里一张卡片的宽度；越小一排越多。';

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

	/// zh-CN: '节能把刷新率交给系统（支持内容匹配的平台固定 60 Hz）；均衡在 Android 上只在触摸或滚动时升频，停手 1.5 秒后释放；性能在前台保持最高刷新率。平台不支持的选项不会出现。'
	String get refreshRateModeDesc => '节能把刷新率交给系统（支持内容匹配的平台固定 60 Hz）；均衡在 Android 上只在触摸或滚动时升频，停手 1.5 秒后释放；性能在前台保持最高刷新率。平台不支持的选项不会出现。';

	/// zh-CN: '节能'
	String get refreshRatePowerSaving => '节能';

	/// zh-CN: '均衡（交互自适应）'
	String get refreshRateBalanced => '均衡（交互自适应）';

	/// zh-CN: '性能（最高刷新率）'
	String get refreshRatePerformance => '性能（最高刷新率）';

	/// zh-CN: '此平台只支持读取刷新率'
	String get refreshRateReadOnly => '此平台只支持读取刷新率';

	/// zh-CN: '系统没有向应用开放刷新率请求接口；上面显示的是当前显示器的实际值。'
	String get refreshRateReadOnlyDesc => '系统没有向应用开放刷新率请求接口；上面显示的是当前显示器的实际值。';

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

	/// zh-CN: '登录系统后自动打开 Pure Live；开关读取的是系统里的真实启动项。'
	String get startupDesc => '登录系统后自动打开 Pure Live；开关读取的是系统里的真实启动项。';

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

	/// zh-CN: '每页显示数量'
	String get pageSize => '每页显示数量';

	/// zh-CN: '桌面分页每页显示多少个房间；站点按自己的窗口取回，应用在本地切片，换页不会跳过房间。'
	String get pageSizeDescription => '桌面分页每页显示多少个房间；站点按自己的窗口取回，应用在本地切片，换页不会跳过房间。';

	/// zh-CN: '紧凑模式'
	String get favoritesDense => '紧凑模式';

	/// zh-CN: '关注页面可显示更多直播间；关闭后改用大卡片。'
	String get favoritesDenseDescription => '关注页面可显示更多直播间；关闭后改用大卡片。';

	/// zh-CN: '平台显示'
	String get sitesDisplay => '平台显示';

	/// zh-CN: '关闭的平台不再出现在热门与分区的平台列表里。'
	String get sitesDisplayDesc => '关闭的平台不再出现在热门与分区的平台列表里。';

	/// zh-CN: '全部平台都在显示中。'
	String get sitesAllShown => '全部平台都在显示中。';

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

	/// zh-CN: '加载样式'
	String get loadingStyle => '加载样式';

	/// zh-CN: '页面、列表与播放器加载时的动画。'
	String get loadingStyleDescription => '页面、列表与播放器加载时的动画。';

	/// zh-CN: '选择加载样式'
	String get loadingStyleChoose => '选择加载样式';

	/// zh-CN: '选择后立即应用到所有加载状态。'
	String get loadingStyleChooseHint => '选择后立即应用到所有加载状态。';

	/// zh-CN: '默认圆环'
	String get loadingStyleDefault => '默认圆环';

	/// zh-CN: '脉冲水波'
	String get loadingStylePulse => '脉冲水波';

	/// zh-CN: '双重大圆'
	String get loadingStyleDoubleBounce => '双重大圆';

	/// zh-CN: '三点弹跳'
	String get loadingStyleThreeBounce => '三点弹跳';

	/// zh-CN: '波浪跳跃'
	String get loadingStyleWave => '波浪跳跃';

	/// zh-CN: '渐隐圆圈'
	String get loadingStyleFadingCircle => '渐隐圆圈';

	/// zh-CN: '九宫方格'
	String get loadingStyleCubeGrid => '九宫方格';

	/// zh-CN: '震荡涟漪'
	String get loadingStyleRipple => '震荡涟漪';

	/// zh-CN: '行星轨道'
	String get loadingStyleOrbit => '行星轨道';

	/// zh-CN: '五线谱律动'
	String get loadingStyleLineScale => '五线谱律动';

	/// zh-CN: '加载颜色'
	String get loadingColor => '加载颜色';

	/// zh-CN: '加载动画的颜色；为空时跟随主题强调色。'
	String get loadingColorDescription => '加载动画的颜色；为空时跟随主题强调色。';

	/// zh-CN: '跟随主题'
	String get loadingColorFollowTheme => '跟随主题';

	/// zh-CN: '预设颜色'
	String get loadingColorPresets => '预设颜色';

	/// zh-CN: '颜色代码'
	String get loadingColorHex => '颜色代码';

	/// zh-CN: '请输入 6 位或 8 位十六进制颜色，例如 #2196F3。'
	String get loadingColorHexInvalid => '请输入 6 位或 8 位十六进制颜色，例如 #2196F3。';

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

	/// zh-CN: '开启后，点播、节目单与备份的请求都经过该代理。'
	String get proxyDesc => '开启后，点播、节目单与备份的请求都经过该代理。';

	/// zh-CN: '主机'
	String get proxyHost => '主机';

	/// zh-CN: '端口'
	String get proxyPort => '端口';

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

	/// zh-CN: '屏蔽关键词与用户，直播间弹幕按此过滤。'
	String get shieldDescription => '屏蔽关键词与用户，直播间弹幕按此过滤。';

	/// zh-CN: '弹幕样式'
	String get danmakuStyleGroup => '弹幕样式';

	/// zh-CN: '字号'
	String get styleFontSize => '字号';

	/// zh-CN: '速度'
	String get styleSpeed => '速度';

	/// zh-CN: '显示区域'
	String get styleArea => '显示区域';

	/// zh-CN: '不透明度'
	String get styleOpacity => '不透明度';

	/// zh-CN: '描边'
	String get styleStroke => '描边';

	/// zh-CN: '恢复默认'
	String get styleReset => '恢复默认';

	/// zh-CN: '设置生效范围'
	String get prefScope => '设置生效范围';

	/// zh-CN: '选择这些更改只在本窗口生效，还是应用到主窗口和所有直播间窗口。'
	String get prefScopeDesc => '选择这些更改只在本窗口生效，还是应用到主窗口和所有直播间窗口。';

	/// zh-CN: '仅本窗口'
	String get prefScopeLocal => '仅本窗口';

	/// zh-CN: '所有窗口'
	String get prefScopeGlobal => '所有窗口';

	/// zh-CN: '窗口'
	String get windowGroup => '窗口';

	/// zh-CN: '直播间在独立窗口打开'
	String get roomWindow => '直播间在独立窗口打开';

	/// zh-CN: '每个直播间一个独立窗口，像聊天软件一样；关闭后在主窗口内浏览。仅桌面端。'
	String get roomWindowDesc => '每个直播间一个独立窗口，像聊天软件一样；关闭后在主窗口内浏览。仅桌面端。';

	/// zh-CN: '关闭窗口时'
	String get closeAction => '关闭窗口时';

	/// zh-CN: '关闭按钮的行为；隐藏到托盘时应用保持运行，点击托盘图标即可恢复窗口。'
	String get closeActionDesc => '关闭按钮的行为；隐藏到托盘时应用保持运行，点击托盘图标即可恢复窗口。';

	/// zh-CN: '退出应用'
	String get closeQuit => '退出应用';

	/// zh-CN: '最小化到任务栏'
	String get closeMinimise => '最小化到任务栏';

	/// zh-CN: '隐藏到托盘'
	String get closeHideToTray => '隐藏到托盘';

	/// zh-CN: '退出不再询问'
	String get noExitConfirm => '退出不再询问';

	/// zh-CN: '开启后，点关闭按钮直接执行上面的行为；关闭此项则每次关闭都先确认。'
	String get noExitConfirmDescription => '开启后，点关闭按钮直接执行上面的行为；关闭此项则每次关闭都先确认。';

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

	/// zh-CN: '字体'
	String get font => '字体';

	/// zh-CN: '界面字体：跟随平台官方字体，或选一款内置官方字体。'
	String get fontDescription => '界面字体：跟随平台官方字体，或选一款内置官方字体。';

	/// zh-CN: '跟随平台（系统字体）'
	String get fontPlatform => '跟随平台（系统字体）';

	/// zh-CN: '文本缩放'
	String get textScale => '文本缩放';

	/// zh-CN: '按比例放大或缩小整个应用的文字；100% 为平台原始大小。'
	String get textScaleDescription => '按比例放大或缩小整个应用的文字；100% 为平台原始大小。';

	/// zh-CN: '预览：设置会立即应用到所有界面。'
	String get textScalePreview => '预览：设置会立即应用到所有界面。';

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

	/// zh-CN: '进入热门或分区时优先显示的平台。'
	String get preferPlatformDesc => '进入热门或分区时优先显示的平台。';

	/// zh-CN: '恢复默认顺序'
	String get sitesOrderReset => '恢复默认顺序';

	/// zh-CN: '平台回到内置的排列顺序；显示开关不受影响。'
	String get sitesOrderResetDesc => '平台回到内置的排列顺序；显示开关不受影响。';

	/// zh-CN: '窗口标题栏'
	String get windowChrome => '窗口标题栏';

	/// zh-CN: '使用系统标题栏，或由应用自绘标题栏；切换后需要重启。'
	String get windowChromeDesc => '使用系统标题栏，或由应用自绘标题栏；切换后需要重启。';

	/// zh-CN: '系统标题栏'
	String get windowChromeSystem => '系统标题栏';

	/// zh-CN: '自定义标题栏'
	String get windowChromeCustom => '自定义标题栏';

	/// zh-CN: '重启以应用标题栏？'
	String get windowChromeRestartTitle => '重启以应用标题栏？';

	/// zh-CN: '标题栏样式在窗口创建时决定，重启应用后生效。'
	String get windowChromeRestartDesc => '标题栏样式在窗口创建时决定，重启应用后生效。';

	/// zh-CN: '立即重启'
	String get windowChromeRestartNow => '立即重启';

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

	/// zh-CN: '侧栏入口的显示与顺序。'
	String get navigationDescription => '侧栏入口的显示与顺序。';

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

	/// zh-CN: '默认清晰度'
	String get vodQuality => '默认清晰度';

	/// zh-CN: '打开视频时优先请求的清晰度；未登录时 Bilibili 可能只提供 720P 及以下。'
	String get vodQualityDesc => '打开视频时优先请求的清晰度；未登录时 Bilibili 可能只提供 720P 及以下。';

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

	/// zh-CN: '画质增强'
	String get superResolutionGroup => '画质增强';

	/// zh-CN: '播放预设'
	String get playerPresets => '播放预设';

	/// zh-CN: '一键切换解码、输出与缓冲策略；只影响播放器。'
	String get playerPresetsHint => '一键切换解码、输出与缓冲策略；只影响播放器。';

	/// zh-CN: '均衡'
	String get presetBalanced => '均衡';

	/// zh-CN: '引擎默认配置，兼顾画质与性能。'
	String get presetBalancedDesc => '引擎默认配置，兼顾画质与性能。';

	/// zh-CN: '安卓兼容'
	String get presetCompat => '安卓兼容';

	/// zh-CN: '使用 mediacodec 表面与解码，修复花屏。'
	String get presetCompatDesc => '使用 mediacodec 表面与解码，修复花屏。';

	/// zh-CN: 'RTX 视频超分'
	String get presetRtxVsr => 'RTX 视频超分';

	/// zh-CN: 'D3D11VA 解码加 d3d11vpp，NVIDIA 显卡适用。'
	String get presetRtxVsrDesc => 'D3D11VA 解码加 d3d11vpp，NVIDIA 显卡适用。';

	/// zh-CN: '低配设备'
	String get presetLowEnd => '低配设备';

	/// zh-CN: '软件解码、低分辨率与更小缓冲，优先流畅。'
	String get presetLowEndDesc => '软件解码、低分辨率与更小缓冲，优先流畅。';

	/// zh-CN: '弱网稳定'
	String get presetStableNetwork => '弱网稳定';

	/// zh-CN: '加大缓冲并自动重连，减少卡顿。'
	String get presetStableNetworkDesc => '加大缓冲并自动重连，减少卡顿。';

	/// zh-CN: '低延迟'
	String get presetLowLatency => '低延迟';

	/// zh-CN: '小缓冲与丢帧，适合高速网络。'
	String get presetLowLatencyDesc => '小缓冲与丢帧，适合高速网络。';

	/// zh-CN: '已应用预设'
	String get playerPresetApplied => '已应用预设';

	/// zh-CN: '播放器代理'
	String get playerProxy => '播放器代理';

	/// zh-CN: '只影响播放器请求，不改变应用接口的代理。'
	String get playerProxyDesc => '只影响播放器请求，不改变应用接口的代理。';

	/// zh-CN: '启用播放器代理'
	String get playerProxyEnable => '启用播放器代理';

	/// zh-CN: '请填写有效的主机和端口（1–65535）。'
	String get playerProxyInvalid => '请填写有效的主机和端口（1–65535）。';

	/// zh-CN: '硬件解码器'
	String get hardwareDecoder => '硬件解码器';

	/// zh-CN: '选择 mpv 的 hwdec 解码器。'
	String get hardwareDecoderDesc => '选择 mpv 的 hwdec 解码器。';

	/// zh-CN: '自定义输出'
	String get customOutput => '自定义输出';

	/// zh-CN: '手动选择视频与音频输出驱动。'
	String get customOutputDesc => '手动选择视频与音频输出驱动。';

	/// zh-CN: '视频输出'
	String get videoOutput => '视频输出';

	/// zh-CN: 'gpu / gpu-next / direct3d 可能让 mpv 另开窗口；嵌入画面通常保持 libmpv 或 auto。'
	String get videoOutputHint => 'gpu / gpu-next / direct3d 可能让 mpv 另开窗口；嵌入画面通常保持 libmpv 或 auto。';

	/// zh-CN: '音频输出'
	String get audioOutput => '音频输出';

	/// zh-CN: '视频同步'
	String get videoSync => '视频同步';

	/// zh-CN: '音画同步与显示刷新策略。'
	String get videoSyncDesc => '音画同步与显示刷新策略。';

	/// zh-CN: '插帧'
	String get interpolation => '插帧';

	/// zh-CN: '运动插值，仅桌面 GPU 建议开启。'
	String get interpolationDesc => '运动插值，仅桌面 GPU 建议开启。';

	/// zh-CN: '缩放算法'
	String get scaleKernel => '缩放算法';

	/// zh-CN: '放大画面时的重采样算法。'
	String get scaleKernelDesc => '放大画面时的重采样算法。';

	/// zh-CN: '反交错'
	String get deinterlace => '反交错';

	/// zh-CN: '处理隔行扫描视频。'
	String get deinterlaceDesc => '处理隔行扫描视频。';

	/// zh-CN: '硬件解码格式'
	String get hwdecCodecs => '硬件解码格式';

	/// zh-CN: '哪些编码交给硬件解码。'
	String get hwdecCodecsDesc => '哪些编码交给硬件解码。';

	/// zh-CN: '独占音频'
	String get audioExclusive => '独占音频';

	/// zh-CN: 'Windows WASAPI 独占模式。'
	String get audioExclusiveDesc => 'Windows WASAPI 独占模式。';

	/// zh-CN: '强制销毁播放器'
	String get forceDestroy => '强制销毁播放器';

	/// zh-CN: '退出房间时立刻销毁播放器，避免残留。'
	String get forceDestroyDesc => '退出房间时立刻销毁播放器，避免残留。';

	/// zh-CN: 'mpv 高级设置'
	String get mpvAdvanced => 'mpv 高级设置';

	/// zh-CN: '恢复 mpv 默认设置'
	String get mpvReset => '恢复 mpv 默认设置';

	/// zh-CN: '重置输出、同步、缩放与解码选项，不影响超分辨率。'
	String get mpvResetDesc => '重置输出、同步、缩放与解码选项，不影响超分辨率。';

	/// zh-CN: '打开 mpv 官方文档'
	String get mpvDocs => '打开 mpv 官方文档';

	/// zh-CN: '每个属性的完整说明。'
	String get mpvDocsDesc => '每个属性的完整说明。';

	/// zh-CN: '播放器指南'
	String get playerGuide => '播放器指南';

	/// zh-CN: '预设、调参与常见问题的说明。'
	String get playerGuideDesc => '预设、调参与常见问题的说明。';

	/// zh-CN: '播放器基于 mpv。先用预设覆盖大多数场景，仍不正常时再改高级选项。'
	String get playerGuideIntro => '播放器基于 mpv。先用预设覆盖大多数场景，仍不正常时再改高级选项。';

	/// zh-CN: '花屏或绿屏：尝试「安卓兼容」，或在高级设置里换解码器。'
	String get playerGuideTip1 => '花屏或绿屏：尝试「安卓兼容」，或在高级设置里换解码器。';

	/// zh-CN: '画面模糊：关闭低配预设，选择质量型缩放或超分辨率。'
	String get playerGuideTip2 => '画面模糊：关闭低配预设，选择质量型缩放或超分辨率。';

	/// zh-CN: '卡顿：使用「弱网稳定」；风扇狂转：关闭插帧与超分。'
	String get playerGuideTip3 => '卡顿：使用「弱网稳定」；风扇狂转：关闭插帧与超分。';

	/// zh-CN: '没有声音：检查音频输出驱动，Windows 可尝试关闭独占音频。'
	String get playerGuideTip4 => '没有声音：检查音频输出驱动，Windows 可尝试关闭独占音频。';

	/// zh-CN: '自动'
	String get optionAuto => '自动';

	/// zh-CN: '关闭'
	String get optionOff => '关闭';

	/// zh-CN: '开启'
	String get optionOn => '开启';

	/// zh-CN: '无输出'
	String get optionNoOutput => '无输出';

	/// zh-CN: '关闭着色器，保持原始画面。'
	String get superResolutionOffDesc => '关闭着色器，保持原始画面。';

	/// zh-CN: '较轻的 CNN 链，适合中端 GPU。'
	String get superResolutionEfficiencyDesc => '较轻的 CNN 链，适合中端 GPU。';

	/// zh-CN: '最重的 CNN 链，画质最好。'
	String get superResolutionQualityDesc => '最重的 CNN 链，画质最好。';

	/// zh-CN: '这些选项只对 mpv 内核生效。'
	String get playerAdvancedRequiresMpv => '这些选项只对 mpv 内核生效。';

	/// zh-CN: '超分辨率'
	String get superResolution => '超分辨率';

	/// zh-CN: '用 Anime4K 着色器实时放大画面；需要桌面 GPU。'
	String get superResolutionDescription => '用 Anime4K 着色器实时放大画面；需要桌面 GPU。';

	/// zh-CN: '仅 Windows 桌面生效；切换后应用到当前与之后的播放器。'
	String get superResolutionHint => '仅 Windows 桌面生效；切换后应用到当前与之后的播放器。';

	/// zh-CN: '关闭'
	String get superResolutionOff => '关闭';

	/// zh-CN: '效率'
	String get superResolutionEfficiency => '效率';

	/// zh-CN: '质量'
	String get superResolutionQuality => '质量';

	/// zh-CN: '录制目录、文件命名与容量上限。'
	String get recordingDescription => '录制目录、文件命名与容量上限。';

	/// zh-CN: '首选画质'
	String get preferredQuality => '首选画质';

	/// zh-CN: '进入房间时优先选用的清晰度档位；站点没有同名画质时，按档位比例选最接近的。默认原画。'
	String get preferredQualityDesc => '进入房间时优先选用的清晰度档位；站点没有同名画质时，按档位比例选最接近的。默认原画。';

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

	/// zh-CN: '手机/平板新播放器默认 50%，桌面默认 100%；滑杆调整当前平台。'
	String get defaultVolumeDesc => '手机/平板新播放器默认 50%，桌面默认 100%；滑杆调整当前平台。';

	/// zh-CN: '全局静音'
	String get globalMute => '全局静音';

	/// zh-CN: '立即静音所有正在播放和之后打开的房间、频道与视频；关闭后恢复各播放器自身的静音设置。'
	String get globalMuteDesc => '立即静音所有正在播放和之后打开的房间、频道与视频；关闭后恢复各播放器自身的静音设置。';

	/// zh-CN: '画面比例'
	String get fit => '画面比例';

	/// zh-CN: '画面在播放区域里的铺法。'
	String get fitDesc => '画面在播放区域里的铺法。';

	/// zh-CN: '适应（留黑边）'
	String get fitContain => '适应（留黑边）';

	/// zh-CN: '裁切填满'
	String get fitCover => '裁切填满';

	/// zh-CN: '拉伸'
	String get fitFill => '拉伸';

	/// zh-CN: '画中画中显示弹幕'
	String get miniDanmakuVisible => '画中画中显示弹幕';

	/// zh-CN: '缩成小窗时是否继续显示飞行弹幕。'
	String get miniDanmakuVisibleDesc => '缩成小窗时是否继续显示飞行弹幕。';

	/// zh-CN: '弹幕样式与「弹幕」页共用。'
	String get miniDanmakuHint => '弹幕样式与「弹幕」页共用。';

	/// zh-CN: '播放内核'
	String get engineTitle => '播放内核';

	/// zh-CN: '由 media_core 的内核注册表提供，当前只注册了 mpv。'
	String get engineDesc => '由 media_core 的内核注册表提供，当前只注册了 mpv。';

	/// zh-CN: '硬件解码'
	String get hardwareDecoding => '硬件解码';

	/// zh-CN: '用 GPU 解码视频，关闭则交给 CPU。'
	String get hardwareDecodingDesc => '用 GPU 解码视频，关闭则交给 CPU。';

	/// zh-CN: '在下一个播放器实例上生效。'
	String get hardwareDecodingHint => '在下一个播放器实例上生效。';

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

	/// zh-CN: '定期清空图片缓存，让封面、头像和台标重新下载；不会清空观看历史或关注。'
	String get refreshThumbnailsDesc => '定期清空图片缓存，让封面、头像和台标重新下载；不会清空观看历史或关注。';

	/// zh-CN: '封面刷新间隔'
	String get thumbnailRefreshInterval => '封面刷新间隔';

	/// zh-CN: '首页入口：多画面'
	String get multiviewVisible => '首页入口：多画面';

	/// zh-CN: '关闭后侧栏不再显示多画面入口。'
	String get multiviewVisibleDesc => '关闭后侧栏不再显示多画面入口。';

	/// zh-CN: '主题'
	String get groupTheme => '主题';

	/// zh-CN: '卡片与列表'
	String get groupCards => '卡片与列表';

	/// zh-CN: '字体和语言'
	String get groupType => '字体和语言';

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

	/// zh-CN: '官方、Wallhaven、Bing 与 deepin 图片源，选中后预览再应用。'
	String get backgroundImagesDescription => '官方、Wallhaven、Bing 与 deepin 图片源，选中后预览再应用。';

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

	/// zh-CN: '视频背景在应用界面后方播放。'
	String get backgroundPreviewVideoHint => '视频背景在应用界面后方播放。';

	/// zh-CN: '壁纸预览'
	String get backgroundPreviewTitle => '壁纸预览';

	/// zh-CN: '图片无法加载。'
	String get backgroundPreviewUnavailable => '图片无法加载。';

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

	/// zh-CN: 'https://…'
	String get backgroundAddressHint => 'https://…';

	/// zh-CN: '应用'
	String get backgroundApply => '应用';

	/// zh-CN: '上传'
	String get backgroundUpload => '上传';

	/// zh-CN: '选择图片'
	String get backgroundUploadImage => '选择图片';

	/// zh-CN: '选择视频'
	String get backgroundUploadVideo => '选择视频';

	/// zh-CN: '本地文件：{name}'
	String backgroundLocalFile({required Object name}) => '本地文件：${name}';

	/// zh-CN: '地址需要是 http(s) 链接'
	String get backgroundInvalidUrl => '地址需要是 http(s) 链接';

	/// zh-CN: '导入失败'
	String get backgroundImportFailed => '导入失败';

	/// zh-CN: '正在复制文件…'
	String get backgroundBusy => '正在复制文件…';

	/// zh-CN: '还没有设置媒体；选择图片或视频后填写地址或上传。'
	String get backgroundEmpty => '还没有设置媒体；选择图片或视频后填写地址或上传。';

	/// zh-CN: '显示'
	String get backgroundDisplay => '显示';

	/// zh-CN: '填充方式'
	String get backgroundFit => '填充方式';

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

	/// zh-CN: '原始或缩小'
	String get backgroundFitScaleDown => '原始或缩小';

	/// zh-CN: '遮罩'
	String get backgroundMask => '遮罩';

	/// zh-CN: '压暗或提亮背景，保证文字可读。'
	String get backgroundMaskDescription => '压暗或提亮背景，保证文字可读。';

	/// zh-CN: '高斯模糊'
	String get backgroundBlur => '高斯模糊';

	/// zh-CN: '对图片或视频做模糊，适合花哨的壁纸。'
	String get backgroundBlurDescription => '对图片或视频做模糊，适合花哨的壁纸。';

	/// zh-CN: '回到主题自身的底色，已保存的媒体仍保留，随时可再次选择。'
	String get backgroundClearDescription => '回到主题自身的底色，已保存的媒体仍保留，随时可再次选择。';

	/// zh-CN: '清除背景'
	String get backgroundClear => '清除背景';

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

	/// zh-CN: '至少保留一个平台'
	String get sitesKeepOne => '至少保留一个平台';

	/// zh-CN: '离开应用时自动小窗'
	String get autoPip => '离开应用时自动小窗';

	/// zh-CN: '播放中切到后台时进入画中画；系统未开启画中画时不会生效。'
	String get autoPipDesc => '播放中切到后台时进入画中画；系统未开启画中画时不会生效。';

	/// zh-CN: '播放时保持屏幕常亮'
	String get keepScreenOn => '播放时保持屏幕常亮';

	/// zh-CN: '房间或频道播放时阻止屏幕自动熄灭；暂停后恢复系统休眠。'
	String get keepScreenOnDesc => '房间或频道播放时阻止屏幕自动熄灭；暂停后恢复系统休眠。';

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

	/// zh-CN: '纯色'
	String get backgroundSolid => '纯色';

	/// zh-CN: '渐变'
	String get backgroundGradient => '渐变';

	/// zh-CN: '预设'
	String get backgroundPresets => '预设';

	/// zh-CN: '壁纸图库'
	String get backgroundLibraryTitle => '壁纸图库';

	/// zh-CN: '加载更多'
	String get backgroundLibraryLoadMore => '加载更多';

	/// zh-CN: '没有可用的壁纸'
	String get backgroundLibraryEmpty => '没有可用的壁纸';

	/// zh-CN: '图库加载失败'
	String get backgroundLibraryFailed => '图库加载失败';

	/// zh-CN: '已应用为背景'
	String get backgroundLibraryApplied => '已应用为背景';

	/// zh-CN: 'deepin 图库随应用内置，不用网络。'
	String get backgroundLibraryLocalHint => 'deepin 图库随应用内置，不用网络。';

	/// zh-CN: '图库来自公开的 iTab 接口；应用代理设置对它同样生效。'
	String get backgroundLibraryNetworkHint => '图库来自公开的 iTab 接口；应用代理设置对它同样生效。';

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
}

// Path: shield
class Translations$shield$zh_CN {
	Translations$shield$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '弹幕屏蔽'
	String get title => '弹幕屏蔽';

	/// zh-CN: '按关键词与用户屏蔽直播间弹幕，规则保存在本机。'
	String get description => '按关键词与用户屏蔽直播间弹幕，规则保存在本机。';

	/// zh-CN: '总开关'
	String get masterTitle => '总开关';

	/// zh-CN: '启用弹幕屏蔽'
	String get enabled => '启用弹幕屏蔽';

	/// zh-CN: '关闭后所有屏蔽规则临时失效'
	String get enabledDescription => '关闭后所有屏蔽规则临时失效';

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

	/// zh-CN: '链接解析'
	String get toolLinkTitle => '链接解析';

	/// zh-CN: '粘贴平台链接，打开直播间或复制房间地址。'
	String get toolLinkDescription => '粘贴平台链接，打开直播间或复制房间地址。';

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

	/// zh-CN: '在应用数据目录保存轮转日志（pure_live.log）；关闭后只保留内存日志。'
	String get logsFileDesc => '在应用数据目录保存轮转日志（pure_live.log）；关闭后只保留内存日志。';

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

	/// zh-CN: '热门'
	String get popular => '热门';

	/// zh-CN: '排行'
	String get ranking => '排行';

	/// zh-CN: '分区'
	String get regions => '分区';

	/// zh-CN: '搜索'
	String get search => '搜索';

	/// zh-CN: '刷新'
	String get refresh => '刷新';

	/// zh-CN: '全部'
	String get regionAll => '全部';

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

	/// zh-CN: '分P'
	String get parts => '分P';

	/// zh-CN: '播放'
	String get views => '播放';

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

	/// zh-CN: '随机图片预览'
	String get previewTitle => '随机图片预览';

	/// zh-CN: '已应用为背景'
	String get applied => '已应用为背景';

	/// zh-CN: '图片直接来自公开随机接口，可用性会变化；应用代理对它生效。'
	String get networkHint => '图片直接来自公开随机接口，可用性会变化；应用代理对它生效。';

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
			'account.cookieDialogHint' => '在已登录的浏览器中复制该网站的 Cookie，粘贴到下面（形如 name=value; name2=value2）。',
			'account.cookieFieldHint' => '粘贴 Cookie 内容',
			'account.loginSuccess' => '登录成功',
			'account.loginFailed' => ({required Object message}) => '登录失败：${message}',
			'account.signOutConfirmDesc' => ({required Object site}) => '将清除本机保存的${site}登录凭证。',
			'account.signOutSuccess' => '已退出登录',
			'areas.allAreas' => '全部分区',
			'areas.noAreas' => '该平台没有分区',
			'areas.viewPlatform' => '平台分区',
			'areas.viewFollowed' => '关注分区',
			'areas.followedEmpty' => '还没有关注的分区',
			'areas.followedEmptyHint' => '在平台分区或直播间里点爱心即可关注',
			'areas.noPlatforms' => '没有可浏览的平台',
			'areas.unfollow' => '取消关注',
			'areas.categoryAll' => '全部分类',
			'areas.follow' => '关注分区',
			'backup.title' => '备份与恢复',
			'backup.localSection' => '本地备份',
			'backup.summaryTitle' => '当前数据',
			'backup.summaryEmpty' => '还没有可备份的数据',
			'backup.exportTitle' => '导出备份',
			'backup.exportDescription' => '把关注、观看历史、关注分区与设置打包为一个 JSON 文件，通过系统分享面板保存。',
			'backup.exportEmpty' => '没有可备份的数据',
			'backup.exportDone' => '备份文件已生成',
			'backup.exportFailed' => '导出失败',
			'backup.importTitle' => '导入备份',
			'backup.importDescription' => '粘贴备份 JSON 的内容，确认后覆盖当前数据；也可以从 WebDAV 下载并恢复。',
			'backup.importHint' => '粘贴备份 JSON',
			'backup.importFileNote' => '直接选择本地文件要等文件选择器依赖接入；目前可粘贴内容或走 WebDAV。',
			'backup.importConfirmTitle' => '覆盖当前数据？',
			'backup.importConfirmDesc' => '导入会先清空再写入关注、观看历史、关注分区与设置，当前数据无法找回。',
			'backup.importDone' => '恢复完成，重启应用后全部生效',
			'backup.importBadData' => '这不是有效的备份内容',
			'backup.importFailed' => '导入失败',
			'backup.summary' => ({required Object follows, required Object history, required Object areas, required Object settings}) => '关注 ${follows} · 历史 ${history} · 分区 ${areas} · 设置 ${settings} 项',
			'backup.webdavSection' => 'WebDAV 同步',
			'backup.webdavDescription' => ({required Object file}) => '备份以 ${file} 存放在服务器目录，上传覆盖、下载恢复。',
			'backup.webdavConfigTitle' => '服务器配置',
			'backup.webdavConfigDescription' => '填写 WebDAV 服务器地址与账号；密码保存在系统安全存储中，不进入备份。',
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
			'backup.restoreConfirmDesc' => ({required String name}) => '将用 ${name} 覆盖本机的关注、观看历史、关注分区与设置，当前数据无法找回。',
			'backup.restoreFollowsConfirmDesc' => ({required String name}) => '将用 ${name} 覆盖本机的关注与关注分区，其他数据保持不变。',
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
			'common.more' => '更多',
			'common.delete' => '删除',
			'common.newWindow' => '新建窗口',
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
			'favorites.perPage' => '每页',
			'favorites.goTo' => '跳转至',
			'favorites.pageUnit' => '页',
			'favorites.setTags' => '设置标签',
			'favorites.tagsTitle' => '标签',
			'favorites.tagsFilter' => '标签筛选',
			'favorites.allTags' => '全部标签',
			'favorites.tagsEmpty' => '还没有标签',
			'favorites.tagFieldHint' => '新标签名称',
			'favorites.addTag' => '添加标签',
			'favorites.deleteTagTitle' => ({required String name}) => '删除标签“${name}”？',
			'favorites.deleteTagBody' => '所有直播间都会移出这个标签，直播间本身不会被取消关注。',
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
			'history.filterClose' => '关闭筛选',
			'history.filterHint' => '按标题、主播、房间号或平台筛选',
			'history.filterMatches' => ({required int count}) => '${count} 条匹配',
			'history.filterReset' => '清除筛选',
			'history.filterEmptyTitle' => '没有符合条件的观看记录',
			'history.filterEmptyDescription' => '换个关键词，或清除筛选试试。',
			'history.deleteConfirmTitle' => '删除观看记录？',
			'history.deleteConfirmDesc' => ({required String title}) => '要从观看记录中删除“${title}”吗？仅删除这一条记录。',
			'history.deleteAction' => '删除',
			'history.deleteDone' => '已从观看记录删除',
			'history.clearConfirmTitle' => '清空观看记录？',
			'history.clearConfirmDesc' => ({required int count}) => '确定清空这 ${count} 条观看记录吗？此操作不可撤销。',
			'history.clearFilteredConfirmDesc' => ({required int count}) => '确定删除筛选出的 ${count} 条观看记录吗？其他记录不受影响，此操作不可撤销。',
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
			'history.openRoom' => '进入直播间',
			'iptv.tabAll' => '全部',
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
			'iptv.customUserAgentDesc' => '导入播放列表、节目单和播放请求使用的 User-Agent；留空使用应用默认值。播放列表自带的 User-Agent 优先。',
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
			'multiview.pickerNoMatch' => '没有匹配的房间',
			'music.title' => '音乐',
			'music.tagline' => '歌曲、歌单与榜单正在路上',
			'music.viewsLabel' => '音乐视图',
			'music.tabLibrary' => '乐库',
			'music.tabPlaylists' => '歌单',
			'music.tabCharts' => '榜单',
			'music.libraryEmptyTitle' => '曲库还在路上',
			'music.libraryEmptyDescription' => '音乐源接入后，歌曲会以瀑布流卡片在这里分页呈现。',
			'music.playlistsEmptyTitle' => '歌单还在路上',
			'music.playlistsEmptyDescription' => '整理与收藏的歌单会出现在这里。',
			'music.chartsEmptyTitle' => '榜单还在路上',
			'music.chartsEmptyDescription' => '来自各音乐源的热门榜单会出现在这里。',
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
			'navigation.toolbox' => '链接解析',
			'navigation.groupPersonal' => '个人与系统',
			'navigation.record' => '录制中心',
			'navigation.settings' => '设置',
			'navigation.appearance' => '外观',
			'navigation.proxy' => '网络代理',
			'navigation.user' => '用户',
			'player.title' => '播放',
			'player.back' => '返回',
			'player.quality' => '清晰度',
			'player.line' => '线路',
			'player.fullscreen' => '全屏',
			'player.danmaku' => '弹幕',
			'popular.allPlatforms' => '全部平台',
			'popular.page' => ({required int page, required int total}) => '第 ${page} 页，共 ${total} 页',
			'popular.prevPage' => '上一页',
			'popular.nextPage' => '下一页',
			'popular.inlineAt' => ({required Object platform, required Object query}) => '在 ${platform} 中搜索“${query}”',
			'popular.backToBrowse' => '返回浏览',
			'popular.sortLabel' => '排序',
			'popular.sortPlatform' => '平台推荐',
			'popular.sortAudience' => '按观众',
			'popular.perPage' => '每页',
			'popular.pageSize' => ({required int size}) => '每页 ${size} 个',
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
			_ => null,
		} ?? switch (path) {
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
			'room.offlineTitle' => '主播暂时不在',
			'room.offlineReplayReason' => '有回放可看，回到列表后可从卡片进入',
			'room.offlineReason' => '开播后这里会看到直播画面',
			'room.detailFailed' => '房间信息加载失败',
			'room.copyLink' => '复制房间链接',
			'room.linkCopied' => '链接已复制',
			'room.record' => '录制',
			'room.stopRecording' => '停止录制',
			'room.recordStarted' => '开始录制',
			'room.recordStopped' => '录制已停止',
			'room.recordFailed' => '录制操作失败',
			'room.details' => '直播间详情',
			'room.detailsHint' => '查看直播间详情',
			'room.notice' => '公告',
			'room.introduction' => '简介',
			'room.roomNumber' => '房间号',
			'room.link' => '链接',
			'room.copy' => '复制',
			'room.copied' => '已复制',
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
			'settings.groupBasics' => '基础设置',
			'settings.groupContent' => '站点',
			'settings.groupData' => '数据',
			'settings.groupAbout' => '关于',
			'settings.groupIptv' => 'IPTV',
			'settings.groupVod' => 'Bilibili 视频',
			'settings.generalDescription' => '卡片宽度、每页数量与窗口行为。',
			'settings.appearanceDescription' => '主题模式、对比度、圆角与字体。',
			'settings.personalizationDescription' => '主题、外观、背景与导航。',
			'settings.liveSettingsDescription' => '直播资源、弹幕与录制。',
			'settings.liveSourcesDescription' => '平台显示、排序与关注自动刷新。',
			'settings.playbackSettingsDescription' => '播放偏好与播放器内核。',
			'settings.systemDescription' => '常规、网络、诊断、数据与备份。',
			'settings.dataCacheDescription' => '观看历史、关注导入导出与封面缓存。',
			'settings.personalizationChooseTheme' => '选择要应用的主题',
			'settings.personalizationSettings' => '个性化设置',
			'settings.playbackDescription' => '画质、比例与播放器行为。',
			'settings.sitesDescription' => '浏览站点与登录账号。',
			'settings.iptvDescription' => '节目单自动更新与来源同步。',
			'settings.vodDescription' => 'Bilibili 账号、默认清晰度与视频站行为。',
			'settings.dataDescription' => '直播观看历史与关注数据。',
			'settings.backupDescription' => '本地备份、恢复与 WebDAV 同步。',
			'settings.aboutDescription' => '版本、开源许可与项目链接。',
			'settings.playbackComingSoon' => '播放设置将在播放器接入后开放。',
			'settings.sitesComingSoon' => '站点管理与账号登录即将接入。',
			'settings.dataComingSoon' => '数据管理即将接入。',
			'settings.appearance' => '外观',
			'settings.themeMode' => '主题',
			'settings.themeModeSystem' => '跟随系统',
			'settings.themeModeLight' => '浅色',
			'settings.themeModeDark' => '深色',
			'settings.language' => '语言',
			'settings.about' => '关于',
			'settings.browsingTitle' => '浏览偏好',
			'settings.site' => '默认站点',
			'settings.cardExtent' => '卡片宽度',
			'settings.cardExtentDescription' => '首页与分区流里一张卡片的宽度；越小一排越多。',
			'settings.refreshRateGroup' => '显示',
			'settings.refreshRateDisplay' => '刷新率',
			'settings.refreshRateRefresh' => '重新读取刷新率',
			'settings.refreshRateCurrentMax' => ({required Object current, required Object max}) => '当前 ${current} · 最高 ${max}',
			'settings.refreshRateUnknown' => '未知',
			'settings.refreshRateLowPower' => '低电量模式',
			'settings.refreshRateMode' => '刷新率模式',
			'settings.refreshRateModeDesc' => '节能把刷新率交给系统（支持内容匹配的平台固定 60 Hz）；均衡在 Android 上只在触摸或滚动时升频，停手 1.5 秒后释放；性能在前台保持最高刷新率。平台不支持的选项不会出现。',
			'settings.refreshRatePowerSaving' => '节能',
			'settings.refreshRateBalanced' => '均衡（交互自适应）',
			'settings.refreshRatePerformance' => '性能（最高刷新率）',
			'settings.refreshRateReadOnly' => '此平台只支持读取刷新率',
			'settings.refreshRateReadOnlyDesc' => '系统没有向应用开放刷新率请求接口；上面显示的是当前显示器的实际值。',
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
			'settings.startupDesc' => '登录系统后自动打开 Pure Live；开关读取的是系统里的真实启动项。',
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
			'settings.pageSize' => '每页显示数量',
			'settings.pageSizeDescription' => '桌面分页每页显示多少个房间；站点按自己的窗口取回，应用在本地切片，换页不会跳过房间。',
			'settings.favoritesDense' => '紧凑模式',
			'settings.favoritesDenseDescription' => '关注页面可显示更多直播间；关闭后改用大卡片。',
			'settings.sitesDisplay' => '平台显示',
			'settings.sitesDisplayDesc' => '关闭的平台不再出现在热门与分区的平台列表里。',
			'settings.sitesAllShown' => '全部平台都在显示中。',
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
			'settings.loadingStyle' => '加载样式',
			'settings.loadingStyleDescription' => '页面、列表与播放器加载时的动画。',
			'settings.loadingStyleChoose' => '选择加载样式',
			'settings.loadingStyleChooseHint' => '选择后立即应用到所有加载状态。',
			'settings.loadingStyleDefault' => '默认圆环',
			'settings.loadingStylePulse' => '脉冲水波',
			'settings.loadingStyleDoubleBounce' => '双重大圆',
			'settings.loadingStyleThreeBounce' => '三点弹跳',
			'settings.loadingStyleWave' => '波浪跳跃',
			'settings.loadingStyleFadingCircle' => '渐隐圆圈',
			'settings.loadingStyleCubeGrid' => '九宫方格',
			'settings.loadingStyleRipple' => '震荡涟漪',
			'settings.loadingStyleOrbit' => '行星轨道',
			'settings.loadingStyleLineScale' => '五线谱律动',
			'settings.loadingColor' => '加载颜色',
			'settings.loadingColorDescription' => '加载动画的颜色；为空时跟随主题强调色。',
			'settings.loadingColorFollowTheme' => '跟随主题',
			'settings.loadingColorPresets' => '预设颜色',
			'settings.loadingColorHex' => '颜色代码',
			'settings.loadingColorHexInvalid' => '请输入 6 位或 8 位十六进制颜色，例如 #2196F3。',
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
			'settings.refreshInterval' => '刷新间隔',
			'settings.historyLimit' => '观看历史上限',
			'settings.historyLimitDesc' => '超过上限的最早记录会被删除。',
			'settings.navNetwork' => '网络',
			'settings.networkDescription' => '应用代理与传输行为。',
			'settings.proxy' => '应用代理',
			'settings.proxyDesc' => '开启后，点播、节目单与备份的请求都经过该代理。',
			'settings.proxyHost' => '主机',
			'settings.proxyPort' => '端口',
			'settings.toolsOrder' => '工具区排序',
			'settings.toolsOrderDesc' => '侧栏分区线下方工具的显示顺序。',
			'settings.moveUp' => '上移',
			'settings.moveDown' => '下移',
			'settings.navShield' => '弹幕屏蔽',
			'settings.shieldDescription' => '屏蔽关键词与用户，直播间弹幕按此过滤。',
			'settings.danmakuStyleGroup' => '弹幕样式',
			'settings.styleFontSize' => '字号',
			'settings.styleSpeed' => '速度',
			'settings.styleArea' => '显示区域',
			'settings.styleOpacity' => '不透明度',
			'settings.styleStroke' => '描边',
			'settings.styleReset' => '恢复默认',
			'settings.prefScope' => '设置生效范围',
			'settings.prefScopeDesc' => '选择这些更改只在本窗口生效，还是应用到主窗口和所有直播间窗口。',
			'settings.prefScopeLocal' => '仅本窗口',
			'settings.prefScopeGlobal' => '所有窗口',
			'settings.windowGroup' => '窗口',
			'settings.roomWindow' => '直播间在独立窗口打开',
			'settings.roomWindowDesc' => '每个直播间一个独立窗口，像聊天软件一样；关闭后在主窗口内浏览。仅桌面端。',
			'settings.closeAction' => '关闭窗口时',
			'settings.closeActionDesc' => '关闭按钮的行为；隐藏到托盘时应用保持运行，点击托盘图标即可恢复窗口。',
			'settings.closeQuit' => '退出应用',
			'settings.closeMinimise' => '最小化到任务栏',
			'settings.closeHideToTray' => '隐藏到托盘',
			'settings.noExitConfirm' => '退出不再询问',
			'settings.noExitConfirmDescription' => '开启后，点关闭按钮直接执行上面的行为；关闭此项则每次关闭都先确认。',
			'settings.closeWindowTitle' => '关闭窗口',
			'settings.closeWindowQuestion' => '要退出应用，还是最小化后继续运行？',
			'settings.closeDontAskAgain' => '不再询问',
			'settings.trayShow' => '显示主窗口',
			'settings.trayHide' => '隐藏到托盘',
			'settings.font' => '字体',
			'settings.fontDescription' => '界面字体：跟随平台官方字体，或选一款内置官方字体。',
			'settings.fontPlatform' => '跟随平台（系统字体）',
			'settings.textScale' => '文本缩放',
			'settings.textScaleDescription' => '按比例放大或缩小整个应用的文字；100% 为平台原始大小。',
			'settings.textScalePreview' => '预览：设置会立即应用到所有界面。',
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
			'settings.preferPlatformDesc' => '进入热门或分区时优先显示的平台。',
			'settings.sitesOrderReset' => '恢复默认顺序',
			'settings.sitesOrderResetDesc' => '平台回到内置的排列顺序；显示开关不受影响。',
			'settings.windowChrome' => '窗口标题栏',
			'settings.windowChromeDesc' => '使用系统标题栏，或由应用自绘标题栏；切换后需要重启。',
			'settings.windowChromeSystem' => '系统标题栏',
			'settings.windowChromeCustom' => '自定义标题栏',
			'settings.windowChromeRestartTitle' => '重启以应用标题栏？',
			'settings.windowChromeRestartDesc' => '标题栏样式在窗口创建时决定，重启应用后生效。',
			'settings.windowChromeRestartNow' => '立即重启',
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
			'settings.navigationDescription' => '侧栏入口的显示与顺序。',
			'settings.refreshDescription' => '关注列表与直播缩略图的自动刷新。',
			'settings.proxyDescription' => '应用级网络代理，所有站点请求都走它。',
			'settings.platformsDescription' => '平台显示、排列顺序与账号登录。',
			'settings.searchSettings' => '搜索设置',
			'settings.searchNoResults' => '没有匹配的设置',
			'settings.searchResults' => '搜索结果',
			'settings.crossSpacing' => '列间距',
			'settings.crossSpacingDescription' => '卡片网格里左右两张卡片之间的距离。',
			'settings.mainSpacing' => '行间距',
			'settings.mainSpacingDescription' => '卡片网格里上下两行之间的距离。',
			'settings.navVideo' => '视频',
			'settings.vodPlayback' => '视频播放',
			'settings.vodQuality' => '默认清晰度',
			'settings.vodQualityDesc' => '打开视频时优先请求的清晰度；未登录时 Bilibili 可能只提供 720P 及以下。',
			'settings.vodQuality720' => '720P',
			'settings.vodQuality1080' => '1080P',
			'settings.vodQuality1080Plus' => '1080P+',
			'settings.vodQuality4K' => '4K',
			'settings.iptvGuideUpdates' => '节目单更新',
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
			'settings.superResolutionGroup' => '画质增强',
			'settings.playerPresets' => '播放预设',
			'settings.playerPresetsHint' => '一键切换解码、输出与缓冲策略；只影响播放器。',
			'settings.presetBalanced' => '均衡',
			'settings.presetBalancedDesc' => '引擎默认配置，兼顾画质与性能。',
			'settings.presetCompat' => '安卓兼容',
			'settings.presetCompatDesc' => '使用 mediacodec 表面与解码，修复花屏。',
			'settings.presetRtxVsr' => 'RTX 视频超分',
			'settings.presetRtxVsrDesc' => 'D3D11VA 解码加 d3d11vpp，NVIDIA 显卡适用。',
			'settings.presetLowEnd' => '低配设备',
			'settings.presetLowEndDesc' => '软件解码、低分辨率与更小缓冲，优先流畅。',
			'settings.presetStableNetwork' => '弱网稳定',
			'settings.presetStableNetworkDesc' => '加大缓冲并自动重连，减少卡顿。',
			'settings.presetLowLatency' => '低延迟',
			'settings.presetLowLatencyDesc' => '小缓冲与丢帧，适合高速网络。',
			'settings.playerPresetApplied' => '已应用预设',
			'settings.playerProxy' => '播放器代理',
			'settings.playerProxyDesc' => '只影响播放器请求，不改变应用接口的代理。',
			'settings.playerProxyEnable' => '启用播放器代理',
			'settings.playerProxyInvalid' => '请填写有效的主机和端口（1–65535）。',
			'settings.hardwareDecoder' => '硬件解码器',
			'settings.hardwareDecoderDesc' => '选择 mpv 的 hwdec 解码器。',
			'settings.customOutput' => '自定义输出',
			'settings.customOutputDesc' => '手动选择视频与音频输出驱动。',
			'settings.videoOutput' => '视频输出',
			'settings.videoOutputHint' => 'gpu / gpu-next / direct3d 可能让 mpv 另开窗口；嵌入画面通常保持 libmpv 或 auto。',
			'settings.audioOutput' => '音频输出',
			'settings.videoSync' => '视频同步',
			'settings.videoSyncDesc' => '音画同步与显示刷新策略。',
			'settings.interpolation' => '插帧',
			'settings.interpolationDesc' => '运动插值，仅桌面 GPU 建议开启。',
			'settings.scaleKernel' => '缩放算法',
			'settings.scaleKernelDesc' => '放大画面时的重采样算法。',
			'settings.deinterlace' => '反交错',
			'settings.deinterlaceDesc' => '处理隔行扫描视频。',
			'settings.hwdecCodecs' => '硬件解码格式',
			'settings.hwdecCodecsDesc' => '哪些编码交给硬件解码。',
			'settings.audioExclusive' => '独占音频',
			'settings.audioExclusiveDesc' => 'Windows WASAPI 独占模式。',
			'settings.forceDestroy' => '强制销毁播放器',
			'settings.forceDestroyDesc' => '退出房间时立刻销毁播放器，避免残留。',
			'settings.mpvAdvanced' => 'mpv 高级设置',
			'settings.mpvReset' => '恢复 mpv 默认设置',
			'settings.mpvResetDesc' => '重置输出、同步、缩放与解码选项，不影响超分辨率。',
			'settings.mpvDocs' => '打开 mpv 官方文档',
			'settings.mpvDocsDesc' => '每个属性的完整说明。',
			'settings.playerGuide' => '播放器指南',
			'settings.playerGuideDesc' => '预设、调参与常见问题的说明。',
			'settings.playerGuideIntro' => '播放器基于 mpv。先用预设覆盖大多数场景，仍不正常时再改高级选项。',
			'settings.playerGuideTip1' => '花屏或绿屏：尝试「安卓兼容」，或在高级设置里换解码器。',
			'settings.playerGuideTip2' => '画面模糊：关闭低配预设，选择质量型缩放或超分辨率。',
			'settings.playerGuideTip3' => '卡顿：使用「弱网稳定」；风扇狂转：关闭插帧与超分。',
			'settings.playerGuideTip4' => '没有声音：检查音频输出驱动，Windows 可尝试关闭独占音频。',
			'settings.optionAuto' => '自动',
			'settings.optionOff' => '关闭',
			'settings.optionOn' => '开启',
			'settings.optionNoOutput' => '无输出',
			'settings.superResolutionOffDesc' => '关闭着色器，保持原始画面。',
			'settings.superResolutionEfficiencyDesc' => '较轻的 CNN 链，适合中端 GPU。',
			'settings.superResolutionQualityDesc' => '最重的 CNN 链，画质最好。',
			_ => null,
		} ?? switch (path) {
			'settings.playerAdvancedRequiresMpv' => '这些选项只对 mpv 内核生效。',
			'settings.superResolution' => '超分辨率',
			'settings.superResolutionDescription' => '用 Anime4K 着色器实时放大画面；需要桌面 GPU。',
			'settings.superResolutionHint' => '仅 Windows 桌面生效；切换后应用到当前与之后的播放器。',
			'settings.superResolutionOff' => '关闭',
			'settings.superResolutionEfficiency' => '效率',
			'settings.superResolutionQuality' => '质量',
			'settings.recordingDescription' => '录制目录、文件命名与容量上限。',
			'settings.preferredQuality' => '首选画质',
			'settings.preferredQualityDesc' => '进入房间时优先选用的清晰度档位；站点没有同名画质时，按档位比例选最接近的。默认原画。',
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
			'settings.defaultVolumeDesc' => '手机/平板新播放器默认 50%，桌面默认 100%；滑杆调整当前平台。',
			'settings.globalMute' => '全局静音',
			'settings.globalMuteDesc' => '立即静音所有正在播放和之后打开的房间、频道与视频；关闭后恢复各播放器自身的静音设置。',
			'settings.fit' => '画面比例',
			'settings.fitDesc' => '画面在播放区域里的铺法。',
			'settings.fitContain' => '适应（留黑边）',
			'settings.fitCover' => '裁切填满',
			'settings.fitFill' => '拉伸',
			'settings.miniDanmakuVisible' => '画中画中显示弹幕',
			'settings.miniDanmakuVisibleDesc' => '缩成小窗时是否继续显示飞行弹幕。',
			'settings.miniDanmakuHint' => '弹幕样式与「弹幕」页共用。',
			'settings.engineTitle' => '播放内核',
			'settings.engineDesc' => '由 media_core 的内核注册表提供，当前只注册了 mpv。',
			'settings.hardwareDecoding' => '硬件解码',
			'settings.hardwareDecodingDesc' => '用 GPU 解码视频，关闭则交给 CPU。',
			'settings.hardwareDecodingHint' => '在下一个播放器实例上生效。',
			'settings.refreshOnResume' => '返回应用时刷新关注',
			'settings.refreshOnResumeDesc' => '切回应用时刷新一遍关注列表的状态。',
			'settings.maxConcurrentRefresh' => '最大并发刷新',
			'settings.maxConcurrentRefreshDesc' => '同时向平台查询的房间数，参考推荐 4，范围 1–20。',
			'settings.recommended' => '推荐',
			'settings.refreshThumbnails' => '自动刷新封面',
			'settings.refreshThumbnailsDesc' => '定期清空图片缓存，让封面、头像和台标重新下载；不会清空观看历史或关注。',
			'settings.thumbnailRefreshInterval' => '封面刷新间隔',
			'settings.multiviewVisible' => '首页入口：多画面',
			'settings.multiviewVisibleDesc' => '关闭后侧栏不再显示多画面入口。',
			'settings.groupTheme' => '主题',
			'settings.groupCards' => '卡片与列表',
			'settings.groupType' => '字体和语言',
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
			'settings.backgroundImagesDescription' => '官方、Wallhaven、Bing 与 deepin 图片源，选中后预览再应用。',
			'settings.backgroundVideosTitle' => '在线视频',
			'settings.navRandomWallpaper' => '随机图源',
			'settings.randomWallpaperDescription' => '按分组从公开随机接口取图，预览后再应用。',
			'settings.backgroundVideosDescription' => 'iTab 动态壁纸，选中后预览再应用。',
			'settings.backgroundColorsTitle' => '纯色与渐变',
			'settings.backgroundColorsDescription' => '调色板与渐变预设。',
			'settings.backgroundDeviceTitle' => '从设备',
			'settings.backgroundDeviceDescription' => '上传图片或视频，或填写网络地址。',
			'settings.backgroundPreview' => '当前背景',
			'settings.backgroundPreviewVideoHint' => '视频背景在应用界面后方播放。',
			'settings.backgroundPreviewTitle' => '壁纸预览',
			'settings.backgroundPreviewUnavailable' => '图片无法加载。',
			'settings.backgroundChange' => '更换背景',
			'settings.backgroundSource' => '背景来源',
			'settings.backgroundNone' => '无',
			'settings.backgroundImage' => '图片',
			'settings.backgroundVideo' => '视频',
			'settings.backgroundImageAddress' => '图片地址',
			'settings.backgroundVideoAddress' => '视频地址',
			'settings.backgroundAddressHint' => 'https://…',
			'settings.backgroundApply' => '应用',
			'settings.backgroundUpload' => '上传',
			'settings.backgroundUploadImage' => '选择图片',
			'settings.backgroundUploadVideo' => '选择视频',
			'settings.backgroundLocalFile' => ({required Object name}) => '本地文件：${name}',
			'settings.backgroundInvalidUrl' => '地址需要是 http(s) 链接',
			'settings.backgroundImportFailed' => '导入失败',
			'settings.backgroundBusy' => '正在复制文件…',
			'settings.backgroundEmpty' => '还没有设置媒体；选择图片或视频后填写地址或上传。',
			'settings.backgroundDisplay' => '显示',
			'settings.backgroundFit' => '填充方式',
			'settings.backgroundFitCover' => '裁切填满',
			'settings.backgroundFitContain' => '完整显示',
			'settings.backgroundFitFill' => '拉伸填满',
			'settings.backgroundFitWidth' => '适应宽度',
			'settings.backgroundFitHeight' => '适应高度',
			'settings.backgroundFitNone' => '原始大小',
			'settings.backgroundFitScaleDown' => '原始或缩小',
			'settings.backgroundMask' => '遮罩',
			'settings.backgroundMaskDescription' => '压暗或提亮背景，保证文字可读。',
			'settings.backgroundBlur' => '高斯模糊',
			'settings.backgroundBlurDescription' => '对图片或视频做模糊，适合花哨的壁纸。',
			'settings.backgroundClearDescription' => '回到主题自身的底色，已保存的媒体仍保留，随时可再次选择。',
			'settings.backgroundClear' => '清除背景',
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
			'settings.sitesKeepOne' => '至少保留一个平台',
			'settings.autoPip' => '离开应用时自动小窗',
			'settings.autoPipDesc' => '播放中切到后台时进入画中画；系统未开启画中画时不会生效。',
			'settings.keepScreenOn' => '播放时保持屏幕常亮',
			'settings.keepScreenOnDesc' => '房间或频道播放时阻止屏幕自动熄灭；暂停后恢复系统休眠。',
			'settings.searchSections' => '分区',
			'settings.searchRows' => '具体设置',
			'settings.searchRowMatches' => ({required String items}) => '匹配：${items}',
			'settings.audienceMetric' => '观众数显示',
			'settings.audienceMetricDesc' => '热门、关注等卡片优先展示的观众指标。',
			'settings.audienceAutomatic' => '跟随平台',
			'settings.audienceOnline' => '在线观众',
			'settings.audiencePopularity' => '热度',
			'settings.audienceTotal' => '累计观看',
			'settings.backgroundSolid' => '纯色',
			'settings.backgroundGradient' => '渐变',
			'settings.backgroundPresets' => '预设',
			'settings.backgroundLibraryTitle' => '壁纸图库',
			'settings.backgroundLibraryLoadMore' => '加载更多',
			'settings.backgroundLibraryEmpty' => '没有可用的壁纸',
			'settings.backgroundLibraryFailed' => '图库加载失败',
			'settings.backgroundLibraryApplied' => '已应用为背景',
			'settings.backgroundLibraryLocalHint' => 'deepin 图库随应用内置，不用网络。',
			'settings.backgroundLibraryNetworkHint' => '图库来自公开的 iTab 接口；应用代理设置对它同样生效。',
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
			'shield.title' => '弹幕屏蔽',
			'shield.description' => '按关键词与用户屏蔽直播间弹幕，规则保存在本机。',
			'shield.masterTitle' => '总开关',
			'shield.enabled' => '启用弹幕屏蔽',
			'shield.enabledDescription' => '关闭后所有屏蔽规则临时失效',
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
			'sites.title' => '站点',
			'sites.live' => '直播',
			'sites.search' => '搜索',
			'sites.rooms' => '房间',
			'toolbox.title' => '工具箱',
			'toolbox.groupLinks' => '链接工具',
			'toolbox.groupNetwork' => '网络',
			'toolbox.groupData' => '数据',
			'toolbox.toolLinkTitle' => '链接解析',
			'toolbox.toolLinkDescription' => '粘贴平台链接，打开直播间或复制房间地址。',
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
			'toolbox.logsFileDesc' => '在应用数据目录保存轮转日志（pure_live.log）；关闭后只保留内存日志。',
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
			'vod.searchHint' => '搜索 Bilibili 视频',
			'vod.idleTitle' => '搜索点播视频',
			'vod.idleDescription' => '输入关键词搜索 Bilibili 的视频。',
			'vod.noResultsTitle' => '没有找到视频',
			'vod.noResultsDescription' => '换个关键词再试试。',
			'vod.errorTitle' => '视频没有加载出来',
			'vod.retry' => '重试',
			'vod.popular' => '热门',
			'vod.ranking' => '排行',
			'vod.regions' => '分区',
			'vod.search' => '搜索',
			'vod.refresh' => '刷新',
			'vod.regionAll' => '全部',
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
			'vod.parts' => '分P',
			'vod.views' => '播放',
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
			'wallpaper.title' => '随机图源',
			'wallpaper.description' => '按分组从公开随机接口取图，预览后再应用。',
			'wallpaper.sourceCount' => ({required Object count}) => '${count} 个来源',
			'wallpaper.another' => '换一张',
			'wallpaper.fetching' => '正在取图…',
			'wallpaper.fetchFailed' => '这张图没有取到',
			'wallpaper.unsupported' => '图源返回了无法显示的图片格式',
			'wallpaper.previewTitle' => '随机图片预览',
			'wallpaper.applied' => '已应用为背景',
			'wallpaper.networkHint' => '图片直接来自公开随机接口，可用性会变化；应用代理对它生效。',
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
