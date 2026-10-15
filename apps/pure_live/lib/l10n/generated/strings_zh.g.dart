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
	late final Translations$home$zh home = Translations$home$zh.internal(_root);
	late final Translations$common$zh common = Translations$common$zh.internal(_root);
	late final Translations$tray$zh tray = Translations$tray$zh.internal(_root);
	late final Translations$settings$zh settings = Translations$settings$zh.internal(_root);
	late final Translations$theme$zh theme = Translations$theme$zh.internal(_root);
	late final Translations$design$zh design = Translations$design$zh.internal(_root);
	late final Translations$history$zh history = Translations$history$zh.internal(_root);
	late final Translations$follow$zh follow = Translations$follow$zh.internal(_root);
	late final Translations$toolbox$zh toolbox = Translations$toolbox$zh.internal(_root);
	late final Translations$about$zh about = Translations$about$zh.internal(_root);
	late final Translations$search$zh search = Translations$search$zh.internal(_root);
	late final Translations$room$zh room = Translations$room$zh.internal(_root);
	late final Translations$errors$zh errors = Translations$errors$zh.internal(_root);
	late final Translations$tabs$zh tabs = Translations$tabs$zh.internal(_root);
	late final Translations$window$zh window = Translations$window$zh.internal(_root);
	late final Translations$closePrompt$zh closePrompt = Translations$closePrompt$zh.internal(_root);
	late final Translations$shellSettings$zh shellSettings = Translations$shellSettings$zh.internal(_root);
}

// Path: app
class Translations$app$zh {
	Translations$app$zh.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh: 'Pure Live'
	String get title => 'Pure Live';
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

	/// zh: '重试'
	String get retry => '重试';

	/// zh: '关闭'
	String get close => '关闭';

	/// zh: '保存'
	String get save => '保存';

	/// zh: '加载中'
	String get loading => '加载中';

	/// zh: '暂无内容'
	String get empty => '暂无内容';

	/// zh: '第 {page: int} / {total: int} 页'
	String pageOf({required int page, required int total}) => '第 ${page} / ${total} 页';
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

// Path: settings
class Translations$settings$zh {
	Translations$settings$zh.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh: '外观'
	String get appearance => '外观';

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

	/// zh: '清空记录'
	String get clear => '清空记录';

	/// zh: '清空全部观看记录？此操作不可撤销。'
	String get clearConfirm => '清空全部观看记录？此操作不可撤销。';

	/// zh: '还没有观看记录'
	String get empty => '还没有观看记录';
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

	/// zh: '新建分组'
	String get newGroup => '新建分组';

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
}

// Path: about
class Translations$about$zh {
	Translations$about$zh.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh: '关于'
	String get title => '关于';

	/// zh: '检查更新'
	String get checkUpdate => '检查更新';

	/// zh: '已是最新版本'
	String get upToDate => '已是最新版本';

	/// zh: '发现新版本'
	String get newVersion => '发现新版本';

	/// zh: '版本历史'
	String get versionHistory => '版本历史';

	/// zh: '许可'
	String get licenses => '许可';

	/// zh: '项目主页'
	String get project => '项目主页';

	/// zh: '正在检查…'
	String get checkRunning => '正在检查…';

	/// zh: '检查失败，点此重试'
	String get checkFailed => '检查失败，点此重试';
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

	/// zh: '应用标题栏'
	String get titleBarApp => '应用标题栏';

	/// zh: '系统标题栏'
	String get titleBarSystem => '系统标题栏';

	/// zh: '应用标题栏由 Pure Live 绘制，系统标题栏使用 Windows 原生样式；切换在重启应用后生效。'
	String get titleBarHint => '应用标题栏由 Pure Live 绘制，系统标题栏使用 Windows 原生样式；切换在重启应用后生效。';
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
			'home.recommended' => '推荐流',
			'common.confirm' => '确定',
			'common.cancel' => '取消',
			'common.retry' => '重试',
			'common.close' => '关闭',
			'common.save' => '保存',
			'common.loading' => '加载中',
			'common.empty' => '暂无内容',
			'common.pageOf' => ({required int page, required int total}) => '第 ${page} / ${total} 页',
			'tray.show' => '显示主界面',
			'tray.quit' => '退出',
			'settings.appearance' => '外观',
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
			'follow.all' => '全部',
			'follow.empty' => '还没有关注任何房间',
			'follow.follow' => '关注',
			'follow.unfollow' => '取消关注',
			'follow.unfollowConfirm' => ({required String name}) => '不再关注「${name}」？',
			'follow.newGroup' => '新建分组',
			'follow.groupName' => '分组名称',
			'toolbox.title' => '工具箱',
			'toolbox.hint' => '粘贴直播间链接',
			'toolbox.readClipboard' => '读取剪贴板',
			'toolbox.resolve' => '解析',
			'toolbox.failed' => '没有平台识别该链接',
			'toolbox.openRoom' => '打开房间',
			'about.title' => '关于',
			'about.checkUpdate' => '检查更新',
			'about.upToDate' => '已是最新版本',
			'about.newVersion' => '发现新版本',
			'about.versionHistory' => '版本历史',
			'about.licenses' => '许可',
			'about.project' => '项目主页',
			'about.checkRunning' => '正在检查…',
			'about.checkFailed' => '检查失败，点此重试',
			'search.hint' => '输入关键词搜索房间',
			'search.rooms' => '房间',
			'search.anchors' => '主播',
			'room.sortPlatform' => '默认排序',
			'room.sortViewers' => '人气优先',
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
