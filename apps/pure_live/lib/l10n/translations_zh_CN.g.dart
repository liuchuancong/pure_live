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
	late final Translations$areas$zh_CN areas = Translations$areas$zh_CN.internal(_root);
	late final Translations$common$zh_CN common = Translations$common$zh_CN.internal(_root);
	late final Translations$favorites$zh_CN favorites = Translations$favorites$zh_CN.internal(_root);
	late final Translations$history$zh_CN history = Translations$history$zh_CN.internal(_root);
	late final Translations$iptv$zh_CN iptv = Translations$iptv$zh_CN.internal(_root);
	late final Translations$music$zh_CN music = Translations$music$zh_CN.internal(_root);
	late final Translations$navigation$zh_CN navigation = Translations$navigation$zh_CN.internal(_root);
	late final Translations$player$zh_CN player = Translations$player$zh_CN.internal(_root);
	late final Translations$search$zh_CN search = Translations$search$zh_CN.internal(_root);
	late final Translations$settings$zh_CN settings = Translations$settings$zh_CN.internal(_root);
	late final Translations$sites$zh_CN sites = Translations$sites$zh_CN.internal(_root);
	late final Translations$vod$zh_CN vod = Translations$vod$zh_CN.internal(_root);
}

// Path: areas
class Translations$areas$zh_CN {
	Translations$areas$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '全部分区'
	String get allAreas => '全部分区';

	/// zh-CN: '该站点没有分区'
	String get noAreas => '该站点没有分区';
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

	/// zh-CN: '点播'
	String get moduleVod => '点播';

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

// Path: search
class Translations$search$zh_CN {
	Translations$search$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '搜索当前站点'
	String get idleTitle => '搜索当前站点';

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

	/// zh-CN: '该站点不支持搜索'
	String get unsupportedTitle => '该站点不支持搜索';

	/// zh-CN: '请先回到首页选择其他站点。'
	String get unsupportedDescription => '请先回到首页选择其他站点。';

	/// zh-CN: '直播中'
	String get liveBadge => '直播中';
}

// Path: settings
class Translations$settings$zh_CN {
	Translations$settings$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '设置'
	String get title => '设置';

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
			'areas.allAreas' => '全部分区',
			'areas.noAreas' => '该站点没有分区',
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
			'common.moduleVod' => '点播',
			'common.moduleMusic' => '音乐',
			'common.retry' => '重试',
			'common.moduleComingSoon' => '这个模块还在路上',
			'common.back' => '后退',
			'common.forward' => '前进',
			'common.searchHint' => '搜索房间、主播或站点',
			'favorites.emptyTitle' => '还没有关注的房间',
			'favorites.emptyDescription' => '在房间里点关注，就会出现在这里。',
			'favorites.unfollow' => '取消关注',
			'history.emptyTitle' => '还没有观看记录',
			'history.emptyDescription' => '看过一场直播后，就会出现在这里。',
			'history.clear' => '清空记录',
			'history.remove' => '删除这条记录',
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
			'search.idleTitle' => '搜索当前站点',
			'search.idleDescription' => '输入关键词，搜索房间、主播或分区。',
			'search.suggestionsTitle' => '搜索建议',
			'search.targetsLabel' => '搜索目标',
			'search.tabRooms' => '房间',
			'search.tabAnchors' => '主播',
			'search.tabAreas' => '分区',
			'search.noResultsTitle' => '没有找到相关结果',
			'search.noResultsDescription' => '换个关键词，或切换到其他搜索目标。',
			'search.unsupportedTitle' => '该站点不支持搜索',
			'search.unsupportedDescription' => '请先回到首页选择其他站点。',
			'search.liveBadge' => '直播中',
			'settings.title' => '设置',
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
			'sites.title' => '站点',
			'sites.live' => '直播',
			'sites.search' => '搜索',
			'sites.rooms' => '房间',
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
