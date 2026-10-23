///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:slang/generated.dart';
import 'translations.g.dart';

// Path: <root>
class TranslationsJaJp extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsJaJp({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.jaJp,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		_meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <ja-JP>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	/// Access flat map
	@override dynamic operator[](String key) => _meta.getTranslation(key) ?? super[key];

	late final TranslationsJaJp _root = this; // ignore: unused_field

	@override 
	TranslationsJaJp $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsJaJp(meta: meta ?? this.$meta);

	// Translations
	@override late final _Translations$app$ja_JP app = _Translations$app$ja_JP._(_root);
	@override late final _Translations$nav$ja_JP nav = _Translations$nav$ja_JP._(_root);
	@override late final _Translations$window$ja_JP window = _Translations$window$ja_JP._(_root);
	@override late final _Translations$home$ja_JP home = _Translations$home$ja_JP._(_root);
	@override late final _Translations$live$ja_JP live = _Translations$live$ja_JP._(_root);
	@override late final _Translations$search$ja_JP search = _Translations$search$ja_JP._(_root);
	@override late final _Translations$generic$ja_JP generic = _Translations$generic$ja_JP._(_root);
}

// Path: app
class _Translations$app$ja_JP extends Translations$app$zh_CN {
	_Translations$app$ja_JP._(TranslationsJaJp root) : this._root = root, super.internal(root);

	final TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => 'Pure Live';
}

// Path: nav
class _Translations$nav$ja_JP extends Translations$nav$zh_CN {
	_Translations$nav$ja_JP._(TranslationsJaJp root) : this._root = root, super.internal(root);

	final TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get home => 'ホーム';
	@override String get live => 'ライブ';
	@override String get favorites => 'お気に入り';
	@override String get history => '履歴';
	@override String get search => '検索';
	@override String get playlist => 'プレイリスト';
	@override String get settings => '設定';
}

// Path: window
class _Translations$window$ja_JP extends Translations$window$zh_CN {
	_Translations$window$ja_JP._(TranslationsJaJp root) : this._root = root, super.internal(root);

	final TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get minimize => '最小化';
	@override String get maximize => '最大化';
	@override String get restore => '元に戻す';
	@override String get close => '閉じる';
}

// Path: home
class _Translations$home$ja_JP extends Translations$home$zh_CN {
	_Translations$home$ja_JP._(TranslationsJaJp root) : this._root = root, super.internal(root);

	final TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get welcome => 'Pure Live へようこそ';
	@override String get welcomeHint => 'サイドバーからセクションを選択してください。サイト接続後にライブが視聴できます。';
}

// Path: live
class _Translations$live$ja_JP extends Translations$live$zh_CN {
	_Translations$live$ja_JP._(TranslationsJaJp root) : this._root = root, super.internal(root);

	final TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get empty => 'サイト接続後、ここでライブが視聴できます。';
}

// Path: search
class _Translations$search$ja_JP extends Translations$search$zh_CN {
	_Translations$search$ja_JP._(TranslationsJaJp root) : this._root = root, super.internal(root);

	final TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get hint => '部屋・配信者・サイトを検索';
	@override String get empty => 'キーワードを入力して検索を開始します。';
}

// Path: generic
class _Translations$generic$ja_JP extends Translations$generic$zh_CN {
	_Translations$generic$ja_JP._(TranslationsJaJp root) : this._root = root, super.internal(root);

	final TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get empty => 'まだ何もありません';
	@override String get comingSoon => '近日公開';
}

/// The flat map containing all translations for locale <ja-JP>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsJaJp {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'app.title' => 'Pure Live',
			'nav.home' => 'ホーム',
			'nav.live' => 'ライブ',
			'nav.favorites' => 'お気に入り',
			'nav.history' => '履歴',
			'nav.search' => '検索',
			'nav.playlist' => 'プレイリスト',
			'nav.settings' => '設定',
			'window.minimize' => '最小化',
			'window.maximize' => '最大化',
			'window.restore' => '元に戻す',
			'window.close' => '閉じる',
			'home.welcome' => 'Pure Live へようこそ',
			'home.welcomeHint' => 'サイドバーからセクションを選択してください。サイト接続後にライブが視聴できます。',
			'live.empty' => 'サイト接続後、ここでライブが視聴できます。',
			'search.hint' => '部屋・配信者・サイトを検索',
			'search.empty' => 'キーワードを入力して検索を開始します。',
			'generic.empty' => 'まだ何もありません',
			'generic.comingSoon' => '近日公開',
			_ => null,
		};
	}
}
