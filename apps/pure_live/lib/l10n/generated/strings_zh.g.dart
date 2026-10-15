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
	late final Translations$search$zh search = Translations$search$zh.internal(_root);
	late final Translations$errors$zh errors = Translations$errors$zh.internal(_root);
	late final Translations$tabs$zh tabs = Translations$tabs$zh.internal(_root);
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

// Path: search
class Translations$search$zh {
	Translations$search$zh.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh: '输入关键词搜索房间'
	String get hint => '输入关键词搜索房间';
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
			'search.hint' => '输入关键词搜索房间',
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
			_ => null,
		};
	}
}
