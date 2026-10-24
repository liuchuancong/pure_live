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

	/// zh-CN: '还没有节目单源，导入一个后频道卡就会显示正在播的节目。'
	String get epgEmpty => '还没有节目单源，导入一个后频道卡就会显示正在播的节目。';

	/// zh-CN: '选择用于节目单的指南源；同一时间只使用一个。'
	String get activeGuideDescription => '选择用于节目单的指南源；同一时间只使用一个。';

	/// zh-CN: '未选择'
	String get activeGuideNone => '未选择';

	/// zh-CN: '使用中的指南'
	String get activeGuideTitle => '使用中的指南';

	/// zh-CN: '自动更新'
	String get autoUpdate => '自动更新';

	/// zh-CN: '打开后按间隔自动重新拉取订阅源。'
	String get autoUpdateHint => '打开后按间隔自动重新拉取订阅源。';

	/// zh-CN: '{count: int} 个频道'
	String channelCount({required int count}) => '${count} 个频道';

	/// zh-CN: '选择指南源'
	String get chooseGuide => '选择指南源';

	/// zh-CN: '删除'
	String get delete => '删除';

	/// zh-CN: '这是正在使用的指南，删除后将改用其他来源。'
	String get deleteActiveGuideNote => '这是正在使用的指南，删除后将改用其他来源。';

	/// zh-CN: '删除指南源“{name: String}”？已下载的节目单会一并移除。'
	String deleteGuideMessage({required String name}) => '删除指南源“${name}”？已下载的节目单会一并移除。';

	/// zh-CN: '删除指南源？'
	String get deleteGuideTitle => '删除指南源？';

	/// zh-CN: '删除“{name: String}”及其 {count: int} 个频道？'
	String deletePlaylistMessage({required String name, required int count}) => '删除“${name}”及其 ${count} 个频道？';

	/// zh-CN: '删除播放列表？'
	String get deletePlaylistTitle => '删除播放列表？';

	/// zh-CN: '已删除“{name: String}”'
	String deleted({required String name}) => '已删除“${name}”';

	/// zh-CN: '指南名称'
	String get guideName => '指南名称';

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

	/// zh-CN: '导入指南'
	String get importGuide => '导入指南';

	/// zh-CN: '支持 XMLTV 地址或文件；导入后会下载节目单。'
	String get importGuideDescription => '支持 XMLTV 地址或文件；导入后会下载节目单。';

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

	/// zh-CN: '还没有指南源'
	String get noGuidesTitle => '还没有指南源';

	/// zh-CN: '从订阅地址、文件或粘贴的文本导入播放列表。'
	String get noPlaylistsDescription => '从订阅地址、文件或粘贴的文本导入播放列表。';

	/// zh-CN: '还没有播放列表'
	String get noPlaylistsTitle => '还没有播放列表';

	/// zh-CN: '选择播放列表文件'
	String get pickPlaylistFile => '选择播放列表文件';

	/// zh-CN: '播放列表名称'
	String get playlistName => '播放列表名称';

	/// zh-CN: '例如：我的频道'
	String get playlistNameHint => '例如：我的频道';

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

	/// zh-CN: '频道'
	String get statChannels => '频道';

	/// zh-CN: '指南'
	String get statGuides => '指南';

	/// zh-CN: '播放列表'
	String get statPlaylists => '播放列表';

	/// zh-CN: '同步'
	String get sync => '同步';

	/// zh-CN: '全部同步'
	String get syncAll => '全部同步';

	/// zh-CN: '已同步 {count: int} 个播放列表'
	String syncAllDone({required int count}) => '已同步 ${count} 个播放列表';

	/// zh-CN: '没有可同步的播放列表'
	String get syncAllNone => '没有可同步的播放列表';

	/// zh-CN: '{failed: int} / {count: int} 个播放列表同步失败'
	String syncAllPartial({required int failed, required int count}) => '${failed} / ${count} 个播放列表同步失败';

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

	/// zh-CN: '播放列表'
	String get viewSources => '播放列表';
}

// Path: multiview
class Translations$multiview$zh_CN {
	Translations$multiview$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '布局'
	String get layoutLabel => '布局';

	/// zh-CN: '多画面播放将随播放器内核接入，现在可先排布格子并挑选房间。'
	String get videoComingSoon => '多画面播放将随播放器内核接入，现在可先排布格子并挑选房间。';

	/// zh-CN: '选择房间'
	String get pickRoom => '选择房间';

	/// zh-CN: '清空这一格'
	String get clearPane => '清空这一格';

	/// zh-CN: '交换格子'
	String get swapPane => '交换格子';

	/// zh-CN: '换到这格'
	String get swapHere => '换到这格';

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

	/// zh-CN: '历史'
	String get history => '历史';

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

	/// zh-CN: '搜索'
	String get search => '搜索';

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

	/// zh-CN: '录制功能将随播放器内核一起接入：到时可在直播间里点录制，任务会出现在这里。'
	String get emptyDescription => '录制功能将随播放器内核一起接入：到时可在直播间里点录制，任务会出现在这里。';

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

	/// zh-CN: '可用日期、时间、平台、房间号与标题占位符，播放器接入后生效。'
	String get namingDescription => '可用日期、时间、平台、房间号与标题占位符，播放器接入后生效。';

	/// zh-CN: '输入录制文件的命名模板'
	String get namingDialogHint => '输入录制文件的命名模板';

	/// zh-CN: '单文件大小上限'
	String get maxSizeTitle => '单文件大小上限';

	/// zh-CN: '录制超过上限后分卷保存，播放器接入后生效。'
	String get maxSizeDescription => '录制超过上限后分卷保存，播放器接入后生效。';

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
}

// Path: settings
class Translations$settings$zh_CN {
	Translations$settings$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '设置'
	String get title => '设置';

	/// zh-CN: '通用'
	String get navGeneral => '通用';

	/// zh-CN: '外观'
	String get navAppearance => '外观';

	/// zh-CN: '播放'
	String get navPlayback => '播放';

	/// zh-CN: '站点'
	String get navSites => '站点';

	/// zh-CN: '数据'
	String get navData => '数据';

	/// zh-CN: '关于'
	String get navAbout => '关于';

	/// zh-CN: '基础设置'
	String get groupBasics => '基础设置';

	/// zh-CN: '站点'
	String get groupContent => '站点';

	/// zh-CN: '数据'
	String get groupData => '数据';

	/// zh-CN: '关于'
	String get groupAbout => '关于';

	/// zh-CN: '默认站点、卡片宽度与每页数量。'
	String get generalDescription => '默认站点、卡片宽度与每页数量。';

	/// zh-CN: '主题模式：跟随系统、浅色或深色。'
	String get appearanceDescription => '主题模式：跟随系统、浅色或深色。';

	/// zh-CN: '画质、比例与播放器行为。'
	String get playbackDescription => '画质、比例与播放器行为。';

	/// zh-CN: '浏览站点与登录账号。'
	String get sitesDescription => '浏览站点与登录账号。';

	/// zh-CN: '收藏、历史与本地存储。'
	String get dataDescription => '收藏、历史与本地存储。';

	/// zh-CN: '版本、开源许可与项目链接。'
	String get aboutDescription => '版本、开源许可与项目链接。';

	/// zh-CN: '播放设置将在播放器接入后开放。'
	String get playbackComingSoon => '播放设置将在播放器接入后开放。';

	/// zh-CN: '站点管理与账号登录即将接入。'
	String get sitesComingSoon => '站点管理与账号登录即将接入。';

	/// zh-CN: '数据管理即将接入。'
	String get dataComingSoon => '数据管理即将接入。';

	/// zh-CN: '关于页即将接入。'
	String get aboutComingSoon => '关于页即将接入。';

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

	/// zh-CN: '每页数量'
	String get pageSize => '每页数量';

	/// zh-CN: '一次向站点请求多少个房间。'
	String get pageSizeDescription => '一次向站点请求多少个房间。';

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

	/// zh-CN: '窗口'
	String get windowGroup => '窗口';

	/// zh-CN: '关闭窗口时'
	String get closeAction => '关闭窗口时';

	/// zh-CN: '退出应用'
	String get closeQuit => '退出应用';

	/// zh-CN: '最小化到任务栏'
	String get closeMinimise => '最小化到任务栏';

	/// zh-CN: '隐藏到托盘(需托盘,暂未接入)'
	String get closeTrayUnavailable => '隐藏到托盘(需托盘,暂未接入)';

	/// zh-CN: '字体'
	String get font => '字体';

	/// zh-CN: '界面字体：跟随平台官方字体，或选一款内置官方字体。'
	String get fontDescription => '界面字体：跟随平台官方字体，或选一款内置官方字体。';

	/// zh-CN: '跟随平台（系统字体）'
	String get fontPlatform => '跟随平台（系统字体）';

	/// zh-CN: '返回应用'
	String get backHome => '返回应用';

	/// zh-CN: '纯黑（OLED）'
	String get pureBlack => '纯黑（OLED）';

	/// zh-CN: '深色模式下把背景收成纯黑，OLED 屏更省电。'
	String get pureBlackDesc => '深色模式下把背景收成纯黑，OLED 屏更省电。';

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

	/// zh-CN: '屏蔽在直播间弹幕管道中生效；该管道将随播放器接入后启用。'
	String get effectNote => '屏蔽在直播间弹幕管道中生效；该管道将随播放器接入后启用。';
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

	/// zh-CN: '网络诊断'
	String get toolNetworkTitle => '网络诊断';

	/// zh-CN: '检测站点接口是否可达，并测量响应时间。'
	String get toolNetworkDescription => '检测站点接口是否可达，并测量响应时间。';

	/// zh-CN: '缓存清理'
	String get toolCacheTitle => '缓存清理';

	/// zh-CN: '查看并清理图片占用的内存缓存。'
	String get toolCacheDescription => '查看并清理图片占用的内存缓存。';

	/// zh-CN: '日志查看'
	String get toolLogsTitle => '日志查看';

	/// zh-CN: '浏览应用运行日志，排查播放与网络问题。'
	String get toolLogsDescription => '浏览应用运行日志，排查播放与网络问题。';

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

	/// zh-CN: '输入关键词搜索 Bilibili 的视频；分区与排行榜此源暂未提供。'
	String get idleDescription => '输入关键词搜索 Bilibili 的视频；分区与排行榜此源暂未提供。';

	/// zh-CN: '没有找到视频'
	String get noResultsTitle => '没有找到视频';

	/// zh-CN: '换个关键词再试试。'
	String get noResultsDescription => '换个关键词再试试。';

	/// zh-CN: '视频没有加载出来'
	String get errorTitle => '视频没有加载出来';

	/// zh-CN: '重试'
	String get retry => '重试';
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
			'iptv.epgEmpty' => '还没有节目单源，导入一个后频道卡就会显示正在播的节目。',
			'iptv.activeGuideDescription' => '选择用于节目单的指南源；同一时间只使用一个。',
			'iptv.activeGuideNone' => '未选择',
			'iptv.activeGuideTitle' => '使用中的指南',
			'iptv.autoUpdate' => '自动更新',
			'iptv.autoUpdateHint' => '打开后按间隔自动重新拉取订阅源。',
			'iptv.channelCount' => ({required int count}) => '${count} 个频道',
			'iptv.chooseGuide' => '选择指南源',
			'iptv.delete' => '删除',
			'iptv.deleteActiveGuideNote' => '这是正在使用的指南，删除后将改用其他来源。',
			'iptv.deleteGuideMessage' => ({required String name}) => '删除指南源“${name}”？已下载的节目单会一并移除。',
			'iptv.deleteGuideTitle' => '删除指南源？',
			'iptv.deletePlaylistMessage' => ({required String name, required int count}) => '删除“${name}”及其 ${count} 个频道？',
			'iptv.deletePlaylistTitle' => '删除播放列表？',
			'iptv.deleted' => ({required String name}) => '已删除“${name}”',
			'iptv.guideName' => '指南名称',
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
			'iptv.importGuide' => '导入指南',
			'iptv.importGuideDescription' => '支持 XMLTV 地址或文件；导入后会下载节目单。',
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
			'iptv.noGuidesTitle' => '还没有指南源',
			'iptv.noPlaylistsDescription' => '从订阅地址、文件或粘贴的文本导入播放列表。',
			'iptv.noPlaylistsTitle' => '还没有播放列表',
			'iptv.pickPlaylistFile' => '选择播放列表文件',
			'iptv.playlistName' => '播放列表名称',
			'iptv.playlistNameHint' => '例如：我的频道',
			'iptv.playlistText' => '播放列表内容',
			'iptv.playlistTextHint' => '粘贴 M3U/M3U8/TXT 内容',
			'iptv.playlistUrl' => '订阅地址',
			'iptv.playlistUrlHint' => 'https://example.com/playlist.m3u',
			'iptv.playlistsTitle' => '播放列表',
			'iptv.replaceMessage' => '同名播放列表已存在，导入内容将替换它。',
			'iptv.replaceTitle' => ({required String name}) => '替换“${name}”？',
			'iptv.sourceChanged' => '订阅源已变化，已更新缓存',
			'iptv.statChannels' => '频道',
			'iptv.statGuides' => '指南',
			'iptv.statPlaylists' => '播放列表',
			'iptv.sync' => '同步',
			'iptv.syncAll' => '全部同步',
			'iptv.syncAllDone' => ({required int count}) => '已同步 ${count} 个播放列表',
			'iptv.syncAllNone' => '没有可同步的播放列表',
			'iptv.syncAllPartial' => ({required int failed, required int count}) => '${failed} / ${count} 个播放列表同步失败',
			'iptv.syncAllRunning' => ({required int done, required int total}) => '正在同步 ${done} / ${total}',
			'iptv.syncFailed' => ({required String name}) => '“${name}”同步失败',
			'iptv.synced' => ({required String name}) => '已同步“${name}”',
			'iptv.viewChannels' => '频道',
			'iptv.viewLabel' => '视图',
			'iptv.viewSources' => '播放列表',
			'multiview.layoutLabel' => '布局',
			'multiview.videoComingSoon' => '多画面播放将随播放器内核接入，现在可先排布格子并挑选房间。',
			'multiview.pickRoom' => '选择房间',
			'multiview.clearPane' => '清空这一格',
			'multiview.swapPane' => '交换格子',
			'multiview.swapHere' => '换到这格',
			'multiview.pickerTitle' => ({required Object index}) => '为第 ${index} 格选择房间',
			'multiview.pickerEmptyTitle' => '还没有关注的房间',
			'multiview.pickerEmptyHint' => '先到直播间点关注，再回到这里挑选，房间会出现在列表里。',
			'multiview.alreadyShown' => ({required Object index}) => '已在第 ${index} 格',
			'multiview.shownIn' => ({required Object index}) => '第 ${index} 格',
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
			'navigation.history' => '历史',
			'navigation.groupContent' => '内容与工具',
			'navigation.multiview' => '多画面',
			'navigation.favorites' => '关注',
			'navigation.hot' => '热门',
			'navigation.zones' => '分区',
			'navigation.search' => '搜索',
			'navigation.toolbox' => '工具箱',
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
			'recorder.tabRunning' => '进行中',
			'recorder.tabFinished' => '已完成',
			'recorder.clearFinished' => '清空已完成',
			'recorder.removeTask' => '删除这条任务',
			'recorder.emptyTitle' => '还没有录制任务',
			'recorder.emptyFinishedTitle' => '已完成的录制会出现在这里',
			'recorder.emptyDescription' => '录制功能将随播放器内核一起接入：到时可在直播间里点录制，任务会出现在这里。',
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
			'recorder.namingDescription' => '可用日期、时间、平台、房间号与标题占位符，播放器接入后生效。',
			'recorder.namingDialogHint' => '输入录制文件的命名模板',
			'recorder.maxSizeTitle' => '单文件大小上限',
			'recorder.maxSizeDescription' => '录制超过上限后分卷保存，播放器接入后生效。',
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
			'settings.title' => '设置',
			'settings.navGeneral' => '通用',
			'settings.navAppearance' => '外观',
			'settings.navPlayback' => '播放',
			'settings.navSites' => '站点',
			'settings.navData' => '数据',
			'settings.navAbout' => '关于',
			'settings.groupBasics' => '基础设置',
			'settings.groupContent' => '站点',
			'settings.groupData' => '数据',
			'settings.groupAbout' => '关于',
			'settings.generalDescription' => '默认站点、卡片宽度与每页数量。',
			'settings.appearanceDescription' => '主题模式：跟随系统、浅色或深色。',
			'settings.playbackDescription' => '画质、比例与播放器行为。',
			'settings.sitesDescription' => '浏览站点与登录账号。',
			'settings.dataDescription' => '收藏、历史与本地存储。',
			'settings.aboutDescription' => '版本、开源许可与项目链接。',
			'settings.playbackComingSoon' => '播放设置将在播放器接入后开放。',
			'settings.sitesComingSoon' => '站点管理与账号登录即将接入。',
			'settings.dataComingSoon' => '数据管理即将接入。',
			'settings.aboutComingSoon' => '关于页即将接入。',
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
			'settings.pageSize' => '每页数量',
			'settings.pageSizeDescription' => '一次向站点请求多少个房间。',
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
			'settings.windowGroup' => '窗口',
			'settings.closeAction' => '关闭窗口时',
			'settings.closeQuit' => '退出应用',
			'settings.closeMinimise' => '最小化到任务栏',
			'settings.closeTrayUnavailable' => '隐藏到托盘(需托盘,暂未接入)',
			'settings.font' => '字体',
			'settings.fontDescription' => '界面字体：跟随平台官方字体，或选一款内置官方字体。',
			'settings.fontPlatform' => '跟随平台（系统字体）',
			'settings.backHome' => '返回应用',
			'settings.pureBlack' => '纯黑（OLED）',
			'settings.pureBlackDesc' => '深色模式下把背景收成纯黑，OLED 屏更省电。',
			'settings.navCache' => '缓存',
			'settings.cacheDescription' => '封面与头像的磁盘缓存、清理上限。',
			'settings.cacheSize' => '当前缓存大小',
			'settings.cacheRefresh' => '刷新',
			'settings.cacheClear' => '清除缓存',
			'settings.cacheClearDesc' => '删除所有已缓存的封面、头像与站点图标。',
			'settings.cacheCleared' => '缓存已清除',
			_ => null,
		} ?? switch (path) {
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
			'shield.effectNote' => '屏蔽在直播间弹幕管道中生效；该管道将随播放器接入后启用。',
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
			'toolbox.toolNetworkTitle' => '网络诊断',
			'toolbox.toolNetworkDescription' => '检测站点接口是否可达，并测量响应时间。',
			'toolbox.toolCacheTitle' => '缓存清理',
			'toolbox.toolCacheDescription' => '查看并清理图片占用的内存缓存。',
			'toolbox.toolLogsTitle' => '日志查看',
			'toolbox.toolLogsDescription' => '浏览应用运行日志，排查播放与网络问题。',
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
			'vod.searchHint' => '搜索 Bilibili 视频',
			'vod.idleTitle' => '搜索点播视频',
			'vod.idleDescription' => '输入关键词搜索 Bilibili 的视频；分区与排行榜此源暂未提供。',
			'vod.noResultsTitle' => '没有找到视频',
			'vod.noResultsDescription' => '换个关键词再试试。',
			'vod.errorTitle' => '视频没有加载出来',
			'vod.retry' => '重试',
			_ => null,
		};
	}
}
