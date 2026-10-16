///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:slang/generated.dart';
import 'strings.g.dart';

// Path: <root>
class TranslationsZh with BaseTranslations<AppLocale, Translations> implements Translations {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsZh({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
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
	@override dynamic operator[](String key) => _meta.getTranslation(key);

	late final TranslationsZh _root = this; // ignore: unused_field

	@override 
	TranslationsZh $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsZh(meta: meta ?? this.$meta);

	// Translations
	@override late final _Translations$app$zh app = _Translations$app$zh._(_root);
	@override late final _Translations$home$zh home = _Translations$home$zh._(_root);
	@override late final _Translations$common$zh common = _Translations$common$zh._(_root);
	@override late final _Translations$tray$zh tray = _Translations$tray$zh._(_root);
	@override late final _Translations$settings$zh settings = _Translations$settings$zh._(_root);
	@override late final _Translations$theme$zh theme = _Translations$theme$zh._(_root);
	@override late final _Translations$design$zh design = _Translations$design$zh._(_root);
	@override late final _Translations$history$zh history = _Translations$history$zh._(_root);
	@override late final _Translations$iptv$zh iptv = _Translations$iptv$zh._(_root);
	@override late final _Translations$fonts$zh fonts = _Translations$fonts$zh._(_root);
	@override late final _Translations$follow$zh follow = _Translations$follow$zh._(_root);
	@override late final _Translations$toolbox$zh toolbox = _Translations$toolbox$zh._(_root);
	@override late final _Translations$backup$zh backup = _Translations$backup$zh._(_root);
	@override late final _Translations$about$zh about = _Translations$about$zh._(_root);
	@override late final _Translations$shield$zh shield = _Translations$shield$zh._(_root);
	@override late final _Translations$multiview$zh multiview = _Translations$multiview$zh._(_root);
	@override late final _Translations$search$zh search = _Translations$search$zh._(_root);
	@override late final _Translations$room$zh room = _Translations$room$zh._(_root);
	@override late final _Translations$errors$zh errors = _Translations$errors$zh._(_root);
	@override late final _Translations$tabs$zh tabs = _Translations$tabs$zh._(_root);
	@override late final _Translations$window$zh window = _Translations$window$zh._(_root);
	@override late final _Translations$closePrompt$zh closePrompt = _Translations$closePrompt$zh._(_root);
	@override late final _Translations$shellSettings$zh shellSettings = _Translations$shellSettings$zh._(_root);
}

// Path: app
class _Translations$app$zh implements Translations$app$en {
	_Translations$app$zh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => 'Pure Live';
}

// Path: home
class _Translations$home$zh implements Translations$home$en {
	_Translations$home$zh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get recommended => '推荐流';
}

// Path: common
class _Translations$common$zh implements Translations$common$en {
	_Translations$common$zh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get confirm => '确定';
	@override String get cancel => '取消';
	@override String get retry => '重试';
	@override String get close => '关闭';
	@override String get save => '保存';
	@override String get loading => '加载中';
	@override String get empty => '暂无内容';
	@override String get pageOf => '第 {page: int} / {total: int} 页';
}

// Path: tray
class _Translations$tray$zh implements Translations$tray$en {
	_Translations$tray$zh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get show => '显示主界面';
	@override String get quit => '退出';
}

// Path: settings
class _Translations$settings$zh implements Translations$settings$en {
	_Translations$settings$zh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get appearance => '外观';
	@override String get fonts => '字体管理';
	@override String get themeMode => '主题模式';
	@override String get designLanguage => '设计语言';
	@override String get accent => '强调色';
	@override String get pureBlack => '纯黑模式';
	@override String get density => '密度';
	@override String get fontScale => '字体大小';
	@override String get transparency => '透明度';
	@override String get reduceTransparency => '减少透明效果';
	@override String get animations => '动画';
	@override String get focusOutline => '焦点轮廓';
}

// Path: theme
class _Translations$theme$zh implements Translations$theme$en {
	_Translations$theme$zh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get system => '跟随系统';
	@override String get dark => '深色';
	@override String get light => '浅色';
}

// Path: design
class _Translations$design$zh implements Translations$design$en {
	_Translations$design$zh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get defaultLanguage => '默认（Fluent）';
}

// Path: history
class _Translations$history$zh implements Translations$history$en {
	_Translations$history$zh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get clear => '清空记录';
	@override String get clearConfirm => '清空全部观看记录？此操作不可撤销。';
	@override String get empty => '还没有观看记录';
}

// Path: iptv
class _Translations$iptv$zh implements Translations$iptv$en {
	_Translations$iptv$zh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => 'IPTV';
	@override String get addSource => '添加源';
	@override String get sourceName => '源名称';
	@override String get sourceUrl => '播放列表地址（M3U/TXT）';
	@override String get deleteSource => '删除该源？频道一并移除';
	@override String get imported => '已导入 {count: int} 个频道';
	@override String get allGroups => '全部分组';
	@override String get favorite => '收藏';
	@override String get empty => '还没有导入任何源';
}

// Path: fonts
class _Translations$fonts$zh implements Translations$fonts$en {
	_Translations$fonts$zh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get fonts => '字体管理';
	@override String get system => '系统默认';
	@override String get systemDesc => '使用系统自带字体';
	@override String get download => '下载';
	@override String get delete => '删除';
}

// Path: follow
class _Translations$follow$zh implements Translations$follow$en {
	_Translations$follow$zh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get all => '全部';
	@override String get empty => '还没有关注任何房间';
	@override String get follow => '关注';
	@override String get unfollow => '取消关注';
	@override String get unfollowConfirm => '不再关注「{name: String}」？';
	@override String get newGroup => '新建分组';
	@override String get groupName => '分组名称';
}

// Path: toolbox
class _Translations$toolbox$zh implements Translations$toolbox$en {
	_Translations$toolbox$zh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '工具箱';
	@override String get hint => '粘贴直播间链接';
	@override String get readClipboard => '读取剪贴板';
	@override String get resolve => '解析';
	@override String get failed => '没有平台识别该链接';
	@override String get openRoom => '打开房间';
}

// Path: backup
class _Translations$backup$zh implements Translations$backup$en {
	_Translations$backup$zh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '备份与恢复';
	@override String get create => '创建备份';
	@override String get restoreFile => '从文件恢复';
	@override String get existing => '已有备份';
	@override String get none => '还没有备份';
	@override String get delete => '删除备份';
	@override String get restore => '恢复';
	@override String get restoreConfirm => '用「{name: String}」覆盖当前数据？应用将重启。';
}

// Path: about
class _Translations$about$zh implements Translations$about$en {
	_Translations$about$zh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '关于';
	@override String get checkUpdate => '检查更新';
	@override String get upToDate => '已是最新版本';
	@override String get newVersion => '发现新版本';
	@override String get versionHistory => '版本历史';
	@override String get licenses => '许可';
	@override String get project => '项目主页';
	@override String get checkRunning => '正在检查…';
	@override String get checkFailed => '检查失败，点此重试';
}

// Path: shield
class _Translations$shield$zh implements Translations$shield$en {
	_Translations$shield$zh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '弹幕屏蔽';
	@override String get keywords => '关键词';
	@override String get users => '用户';
	@override String get regexes => '正则';
	@override String get add => '添加';
	@override String get none => '暂无';
}

// Path: multiview
class _Translations$multiview$zh implements Translations$multiview$en {
	_Translations$multiview$zh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '多画面';
	@override String get platform => '平台';
	@override String get roomId => '房间号';
	@override String get add => '添加格子';
}

// Path: search
class _Translations$search$zh implements Translations$search$en {
	_Translations$search$zh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get hint => '输入关键词搜索房间';
	@override String get rooms => '房间';
	@override String get anchors => '主播';
}

// Path: room
class _Translations$room$zh implements Translations$room$en {
	_Translations$room$zh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get sortPlatform => '默认排序';
	@override String get sortViewers => '人气优先';
	@override String get danmakuFailed => '弹幕连接失败';
	@override String get quality => '清晰度';
	@override String get line => '线路';
	@override String get play => '播放';
	@override String get pause => '暂停';
	@override String get failed => '播放失败，请重试';
}

// Path: errors
class _Translations$errors$zh implements Translations$errors$en {
	_Translations$errors$zh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get generic => '出了点问题，请稍后再试。';
	@override String get network => '网络连接不可用，请检查网络后重试。';
	@override String get notFound => '没有找到相关内容。';
	@override String get cancelled => '已取消。';
	@override String get unsupported => '当前来源不支持该功能。';
}

// Path: tabs
class _Translations$tabs$zh implements Translations$tabs$en {
	_Translations$tabs$zh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get home => '首页';
	@override String get follow => '关注';
	@override String get history => '历史';
	@override String get popular => '热门';
	@override String get areas => '分区';
	@override String get search => '搜索';
	@override String get settings => '设置';
}

// Path: window
class _Translations$window$zh implements Translations$window$en {
	_Translations$window$zh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get minimize => '最小化';
	@override String get maximize => '最大化';
	@override String get restore => '还原';
	@override String get close => '关闭';
}

// Path: closePrompt
class _Translations$closePrompt$zh implements Translations$closePrompt$en {
	_Translations$closePrompt$zh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '关闭窗口时要执行什么？';
	@override String get toTray => '隐藏到托盘，保留播放';
	@override String get quit => '退出 Pure Live';
	@override String get remember => '记住我的选择，不再询问';
}

// Path: shellSettings
class _Translations$shellSettings$zh implements Translations$shellSettings$en {
	_Translations$shellSettings$zh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get sectionWindow => '窗口';
	@override String get titleBar => '窗口标题栏';
	@override String get titleBarApp => '应用标题栏';
	@override String get titleBarSystem => '系统标题栏';
	@override String get titleBarHint => '应用标题栏由 Pure Live 绘制，系统标题栏使用 Windows 原生样式；切换在重启应用后生效。';
}

/// The flat map containing all translations for locale <zh>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsZh {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'app.title' => 'Pure Live',
			'home.recommended' => '推荐流',
			'common.confirm' => '确定',
			'common.cancel' => '取消',
			'common.retry' => '重试',
			'common.close' => '关闭',
			'common.save' => '保存',
			'common.loading' => '加载中',
			'common.empty' => '暂无内容',
			'common.pageOf' => '第 {page: int} / {total: int} 页',
			'tray.show' => '显示主界面',
			'tray.quit' => '退出',
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
			'theme.system' => '跟随系统',
			'theme.dark' => '深色',
			'theme.light' => '浅色',
			'design.defaultLanguage' => '默认（Fluent）',
			'history.clear' => '清空记录',
			'history.clearConfirm' => '清空全部观看记录？此操作不可撤销。',
			'history.empty' => '还没有观看记录',
			'iptv.title' => 'IPTV',
			'iptv.addSource' => '添加源',
			'iptv.sourceName' => '源名称',
			'iptv.sourceUrl' => '播放列表地址（M3U/TXT）',
			'iptv.deleteSource' => '删除该源？频道一并移除',
			'iptv.imported' => '已导入 {count: int} 个频道',
			'iptv.allGroups' => '全部分组',
			'iptv.favorite' => '收藏',
			'iptv.empty' => '还没有导入任何源',
			'fonts.fonts' => '字体管理',
			'fonts.system' => '系统默认',
			'fonts.systemDesc' => '使用系统自带字体',
			'fonts.download' => '下载',
			'fonts.delete' => '删除',
			'follow.all' => '全部',
			'follow.empty' => '还没有关注任何房间',
			'follow.follow' => '关注',
			'follow.unfollow' => '取消关注',
			'follow.unfollowConfirm' => '不再关注「{name: String}」？',
			'follow.newGroup' => '新建分组',
			'follow.groupName' => '分组名称',
			'toolbox.title' => '工具箱',
			'toolbox.hint' => '粘贴直播间链接',
			'toolbox.readClipboard' => '读取剪贴板',
			'toolbox.resolve' => '解析',
			'toolbox.failed' => '没有平台识别该链接',
			'toolbox.openRoom' => '打开房间',
			'backup.title' => '备份与恢复',
			'backup.create' => '创建备份',
			'backup.restoreFile' => '从文件恢复',
			'backup.existing' => '已有备份',
			'backup.none' => '还没有备份',
			'backup.delete' => '删除备份',
			'backup.restore' => '恢复',
			'backup.restoreConfirm' => '用「{name: String}」覆盖当前数据？应用将重启。',
			'about.title' => '关于',
			'about.checkUpdate' => '检查更新',
			'about.upToDate' => '已是最新版本',
			'about.newVersion' => '发现新版本',
			'about.versionHistory' => '版本历史',
			'about.licenses' => '许可',
			'about.project' => '项目主页',
			'about.checkRunning' => '正在检查…',
			'about.checkFailed' => '检查失败，点此重试',
			'shield.title' => '弹幕屏蔽',
			'shield.keywords' => '关键词',
			'shield.users' => '用户',
			'shield.regexes' => '正则',
			'shield.add' => '添加',
			'shield.none' => '暂无',
			'multiview.title' => '多画面',
			'multiview.platform' => '平台',
			'multiview.roomId' => '房间号',
			'multiview.add' => '添加格子',
			'search.hint' => '输入关键词搜索房间',
			'search.rooms' => '房间',
			'search.anchors' => '主播',
			'room.sortPlatform' => '默认排序',
			'room.sortViewers' => '人气优先',
			'room.danmakuFailed' => '弹幕连接失败',
			'room.quality' => '清晰度',
			'room.line' => '线路',
			'room.play' => '播放',
			'room.pause' => '暂停',
			'room.failed' => '播放失败，请重试',
			'errors.generic' => '出了点问题，请稍后再试。',
			'errors.network' => '网络连接不可用，请检查网络后重试。',
			'errors.notFound' => '没有找到相关内容。',
			'errors.cancelled' => '已取消。',
			'errors.unsupported' => '当前来源不支持该功能。',
			'tabs.home' => '首页',
			'tabs.follow' => '关注',
			'tabs.history' => '历史',
			'tabs.popular' => '热门',
			'tabs.areas' => '分区',
			'tabs.search' => '搜索',
			'tabs.settings' => '设置',
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
			'shellSettings.titleBarApp' => '应用标题栏',
			'shellSettings.titleBarSystem' => '系统标题栏',
			'shellSettings.titleBarHint' => '应用标题栏由 Pure Live 绘制，系统标题栏使用 Windows 原生样式；切换在重启应用后生效。',
			_ => null,
		};
	}
}
