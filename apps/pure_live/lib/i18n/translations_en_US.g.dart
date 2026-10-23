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
class TranslationsEnUs extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsEnUs({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.enUs,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		_meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <en-US>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	/// Access flat map
	@override dynamic operator[](String key) => _meta.getTranslation(key) ?? super[key];

	late final TranslationsEnUs _root = this; // ignore: unused_field

	@override 
	TranslationsEnUs $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsEnUs(meta: meta ?? this.$meta);

	// Translations
	@override late final _Translations$app$en_US app = _Translations$app$en_US._(_root);
	@override late final _Translations$nav$en_US nav = _Translations$nav$en_US._(_root);
	@override late final _Translations$window$en_US window = _Translations$window$en_US._(_root);
	@override late final _Translations$home$en_US home = _Translations$home$en_US._(_root);
	@override late final _Translations$live$en_US live = _Translations$live$en_US._(_root);
	@override late final _Translations$search$en_US search = _Translations$search$en_US._(_root);
	@override late final _Translations$generic$en_US generic = _Translations$generic$en_US._(_root);
}

// Path: app
class _Translations$app$en_US extends Translations$app$zh_CN {
	_Translations$app$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Pure Live';
}

// Path: nav
class _Translations$nav$en_US extends Translations$nav$zh_CN {
	_Translations$nav$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get home => 'Home';
	@override String get live => 'Live';
	@override String get favorites => 'Favorites';
	@override String get history => 'History';
	@override String get search => 'Search';
	@override String get playlist => 'Playlist';
	@override String get settings => 'Settings';
}

// Path: window
class _Translations$window$en_US extends Translations$window$zh_CN {
	_Translations$window$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get minimize => 'Minimize';
	@override String get maximize => 'Maximize';
	@override String get restore => 'Restore';
	@override String get close => 'Close';
}

// Path: home
class _Translations$home$en_US extends Translations$home$zh_CN {
	_Translations$home$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get welcome => 'Welcome to Pure Live';
	@override String get welcomeHint => 'Pick a section from the sidebar; live streams arrive once the sites are wired in.';
}

// Path: live
class _Translations$live$en_US extends Translations$live$zh_CN {
	_Translations$live$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get empty => 'Live streams appear here once the sites are wired in.';
}

// Path: search
class _Translations$search$en_US extends Translations$search$zh_CN {
	_Translations$search$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get hint => 'Search rooms, streamers or sites';
	@override String get empty => 'Type a keyword to start searching.';
}

// Path: generic
class _Translations$generic$en_US extends Translations$generic$zh_CN {
	_Translations$generic$en_US._(TranslationsEnUs root) : this._root = root, super.internal(root);

	final TranslationsEnUs _root; // ignore: unused_field

	// Translations
	@override String get empty => 'Nothing here yet';
	@override String get comingSoon => 'Coming soon';
}

/// The flat map containing all translations for locale <en-US>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsEnUs {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'app.title' => 'Pure Live',
			'nav.home' => 'Home',
			'nav.live' => 'Live',
			'nav.favorites' => 'Favorites',
			'nav.history' => 'History',
			'nav.search' => 'Search',
			'nav.playlist' => 'Playlist',
			'nav.settings' => 'Settings',
			'window.minimize' => 'Minimize',
			'window.maximize' => 'Maximize',
			'window.restore' => 'Restore',
			'window.close' => 'Close',
			'home.welcome' => 'Welcome to Pure Live',
			'home.welcomeHint' => 'Pick a section from the sidebar; live streams arrive once the sites are wired in.',
			'live.empty' => 'Live streams appear here once the sites are wired in.',
			'search.hint' => 'Search rooms, streamers or sites',
			'search.empty' => 'Type a keyword to start searching.',
			'generic.empty' => 'Nothing here yet',
			'generic.comingSoon' => 'Coming soon',
			_ => null,
		};
	}
}
