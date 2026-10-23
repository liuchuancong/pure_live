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
	late final Translations$common$zh_CN common = Translations$common$zh_CN.internal(_root);
	late final Translations$navigation$zh_CN navigation = Translations$navigation$zh_CN.internal(_root);
	late final Translations$player$zh_CN player = Translations$player$zh_CN.internal(_root);
	late final Translations$settings$zh_CN settings = Translations$settings$zh_CN.internal(_root);
	late final Translations$sites$zh_CN sites = Translations$sites$zh_CN.internal(_root);
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
}

// Path: navigation
class Translations$navigation$zh_CN {
	Translations$navigation$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '首页'
	String get home => '首页';

	/// zh-CN: '直播'
	String get live => '直播';

	/// zh-CN: '收藏'
	String get favorites => '收藏';

	/// zh-CN: '历史'
	String get history => '历史';

	/// zh-CN: '搜索'
	String get search => '搜索';

	/// zh-CN: '播放列表'
	String get playlist => '播放列表';

	/// zh-CN: '设置'
	String get settings => '设置';
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

/// The flat map containing all translations for locale <zh-CN>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on Translations {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'common.appTitle' => 'Pure Live',
			'common.empty' => '这里还没有内容',
			'common.comingSoon' => '即将推出',
			'common.close' => '关闭',
			'common.cancel' => '取消',
			'common.confirm' => '确定',
			'common.minimize' => '最小化',
			'common.maximize' => '最大化',
			'common.restore' => '还原',
			'navigation.home' => '首页',
			'navigation.live' => '直播',
			'navigation.favorites' => '收藏',
			'navigation.history' => '历史',
			'navigation.search' => '搜索',
			'navigation.playlist' => '播放列表',
			'navigation.settings' => '设置',
			'player.title' => '播放',
			'player.back' => '返回',
			'player.quality' => '清晰度',
			'player.line' => '线路',
			'player.fullscreen' => '全屏',
			'player.danmaku' => '弹幕',
			'settings.title' => '设置',
			'settings.appearance' => '外观',
			'settings.themeMode' => '主题',
			'settings.themeModeSystem' => '跟随系统',
			'settings.themeModeLight' => '浅色',
			'settings.themeModeDark' => '深色',
			'settings.language' => '语言',
			'settings.about' => '关于',
			'sites.title' => '站点',
			'sites.live' => '直播',
			'sites.search' => '搜索',
			'sites.rooms' => '房间',
			_ => null,
		};
	}
}
