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
	late final Translations$app$zh_CN app = Translations$app$zh_CN.internal(_root);
	late final Translations$nav$zh_CN nav = Translations$nav$zh_CN.internal(_root);
	late final Translations$window$zh_CN window = Translations$window$zh_CN.internal(_root);
	late final Translations$home$zh_CN home = Translations$home$zh_CN.internal(_root);
	late final Translations$live$zh_CN live = Translations$live$zh_CN.internal(_root);
	late final Translations$search$zh_CN search = Translations$search$zh_CN.internal(_root);
	late final Translations$generic$zh_CN generic = Translations$generic$zh_CN.internal(_root);
}

// Path: app
class Translations$app$zh_CN {
	Translations$app$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: 'Pure Live'
	String get title => 'Pure Live';
}

// Path: nav
class Translations$nav$zh_CN {
	Translations$nav$zh_CN.internal(this._root);

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

// Path: window
class Translations$window$zh_CN {
	Translations$window$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '最小化'
	String get minimize => '最小化';

	/// zh-CN: '最大化'
	String get maximize => '最大化';

	/// zh-CN: '还原'
	String get restore => '还原';

	/// zh-CN: '关闭'
	String get close => '关闭';
}

// Path: home
class Translations$home$zh_CN {
	Translations$home$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '欢迎使用 Pure Live'
	String get welcome => '欢迎使用 Pure Live';

	/// zh-CN: '从侧栏选择一个版块开始;站点接入后即可观看直播。'
	String get welcomeHint => '从侧栏选择一个版块开始;站点接入后即可观看直播。';
}

// Path: live
class Translations$live$zh_CN {
	Translations$live$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '站点接入后即可在此观看直播。'
	String get empty => '站点接入后即可在此观看直播。';
}

// Path: search
class Translations$search$zh_CN {
	Translations$search$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '搜索房间、主播或站点'
	String get hint => '搜索房间、主播或站点';

	/// zh-CN: '输入关键词开始搜索。'
	String get empty => '输入关键词开始搜索。';
}

// Path: generic
class Translations$generic$zh_CN {
	Translations$generic$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '这里还没有内容'
	String get empty => '这里还没有内容';

	/// zh-CN: '即将推出'
	String get comingSoon => '即将推出';
}

/// The flat map containing all translations for locale <zh-CN>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on Translations {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'app.title' => 'Pure Live',
			'nav.home' => '首页',
			'nav.live' => '直播',
			'nav.favorites' => '收藏',
			'nav.history' => '历史',
			'nav.search' => '搜索',
			'nav.playlist' => '播放列表',
			'nav.settings' => '设置',
			'window.minimize' => '最小化',
			'window.maximize' => '最大化',
			'window.restore' => '还原',
			'window.close' => '关闭',
			'home.welcome' => '欢迎使用 Pure Live',
			'home.welcomeHint' => '从侧栏选择一个版块开始;站点接入后即可观看直播。',
			'live.empty' => '站点接入后即可在此观看直播。',
			'search.hint' => '搜索房间、主播或站点',
			'search.empty' => '输入关键词开始搜索。',
			'generic.empty' => '这里还没有内容',
			'generic.comingSoon' => '即将推出',
			_ => null,
		};
	}
}
