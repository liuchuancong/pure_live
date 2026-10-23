///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:slang/generated.dart';
import 'package:pure_live/i18n/translations.g.dart';

// Path: <root>
class TranslationsZhTw extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsZhTw({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.zhTw,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		_meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <zh-TW>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	/// Access flat map
	@override dynamic operator[](String key) => _meta.getTranslation(key) ?? super[key];

	late final TranslationsZhTw _root = this; // ignore: unused_field

	@override 
	TranslationsZhTw $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsZhTw(meta: meta ?? this.$meta);

	// Translations
	@override late final Translations$app$zh_TW app = Translations$app$zh_TW.internal(_root);
	@override late final Translations$nav$zh_TW nav = Translations$nav$zh_TW.internal(_root);
	@override late final Translations$window$zh_TW window = Translations$window$zh_TW.internal(_root);
	@override late final Translations$home$zh_TW home = Translations$home$zh_TW.internal(_root);
	@override late final Translations$live$zh_TW live = Translations$live$zh_TW.internal(_root);
	@override late final Translations$search$zh_TW search = Translations$search$zh_TW.internal(_root);
	@override late final Translations$generic$zh_TW generic = Translations$generic$zh_TW.internal(_root);
}

// Path: app
class Translations$app$zh_TW extends Translations$app$zh_CN {
	Translations$app$zh_TW.internal(TranslationsZhTw root) : this._root = root, super.internal(root);

	final TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => 'Pure Live';
}

// Path: nav
class Translations$nav$zh_TW extends Translations$nav$zh_CN {
	Translations$nav$zh_TW.internal(TranslationsZhTw root) : this._root = root, super.internal(root);

	final TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get home => '首頁';
	@override String get live => '直播';
	@override String get favorites => '收藏';
	@override String get history => '歷史';
	@override String get search => '搜尋';
	@override String get playlist => '播放清單';
	@override String get settings => '設定';
}

// Path: window
class Translations$window$zh_TW extends Translations$window$zh_CN {
	Translations$window$zh_TW.internal(TranslationsZhTw root) : this._root = root, super.internal(root);

	final TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get minimize => '最小化';
	@override String get maximize => '最大化';
	@override String get restore => '還原';
	@override String get close => '關閉';
}

// Path: home
class Translations$home$zh_TW extends Translations$home$zh_CN {
	Translations$home$zh_TW.internal(TranslationsZhTw root) : this._root = root, super.internal(root);

	final TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get welcome => '歡迎使用 Pure Live';
	@override String get welcomeHint => '從側欄選擇一個版塊開始;站點接入後即可觀看直播。';
}

// Path: live
class Translations$live$zh_TW extends Translations$live$zh_CN {
	Translations$live$zh_TW.internal(TranslationsZhTw root) : this._root = root, super.internal(root);

	final TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get empty => '站點接入後即可在此觀看直播。';
}

// Path: search
class Translations$search$zh_TW extends Translations$search$zh_CN {
	Translations$search$zh_TW.internal(TranslationsZhTw root) : this._root = root, super.internal(root);

	final TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get hint => '搜尋房間、主播或站點';
	@override String get empty => '輸入關鍵字開始搜尋。';
}

// Path: generic
class Translations$generic$zh_TW extends Translations$generic$zh_CN {
	Translations$generic$zh_TW.internal(TranslationsZhTw root) : this._root = root, super.internal(root);

	final TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get empty => '這裡還沒有內容';
	@override String get comingSoon => '即將推出';
}

/// The flat map containing all translations for locale <zh-TW>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsZhTw {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'app.title' => 'Pure Live',
			'nav.home' => '首頁',
			'nav.live' => '直播',
			'nav.favorites' => '收藏',
			'nav.history' => '歷史',
			'nav.search' => '搜尋',
			'nav.playlist' => '播放清單',
			'nav.settings' => '設定',
			'window.minimize' => '最小化',
			'window.maximize' => '最大化',
			'window.restore' => '還原',
			'window.close' => '關閉',
			'home.welcome' => '歡迎使用 Pure Live',
			'home.welcomeHint' => '從側欄選擇一個版塊開始;站點接入後即可觀看直播。',
			'live.empty' => '站點接入後即可在此觀看直播。',
			'search.hint' => '搜尋房間、主播或站點',
			'search.empty' => '輸入關鍵字開始搜尋。',
			'generic.empty' => '這裡還沒有內容',
			'generic.comingSoon' => '即將推出',
			_ => null,
		};
	}
}
