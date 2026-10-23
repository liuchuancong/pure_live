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
class TranslationsEn extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsEn({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.en,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		_meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <en>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	/// Access flat map
	@override dynamic operator[](String key) => _meta.getTranslation(key) ?? super[key];

	late final TranslationsEn _root = this; // ignore: unused_field

	@override 
	TranslationsEn $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsEn(meta: meta ?? this.$meta);

	// Translations
	@override late final _Translations$common$en common = _Translations$common$en._(_root);
	@override late final _Translations$navigation$en navigation = _Translations$navigation$en._(_root);
	@override late final _Translations$player$en player = _Translations$player$en._(_root);
	@override late final _Translations$settings$en settings = _Translations$settings$en._(_root);
	@override late final _Translations$sites$en sites = _Translations$sites$en._(_root);
}

// Path: common
class _Translations$common$en extends Translations$common$zh_CN {
	_Translations$common$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get appTitle => 'Pure Live';
	@override String get empty => 'Nothing here yet';
	@override String get comingSoon => 'Coming soon';
	@override String get close => 'Close';
	@override String get cancel => 'Cancel';
	@override String get confirm => 'Confirm';
	@override String get minimize => 'Minimize';
	@override String get maximize => 'Maximize';
	@override String get restore => 'Restore';
	@override String get toggleSidebar => 'Toggle sidebar';
	@override String get back => 'Back';
	@override String get forward => 'Forward';
	@override String get searchHint => 'Search rooms, streamers or sites';
}

// Path: navigation
class _Translations$navigation$en extends Translations$navigation$zh_CN {
	_Translations$navigation$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get groupPrimary => 'Top pages';
	@override String get home => 'Home';
	@override String get live => 'Live';
	@override String get channels => 'Channels';
	@override String get discover => 'Discover';
	@override String get history => 'History';
	@override String get groupContent => 'Content & tools';
	@override String get multiview => 'Multi-view';
	@override String get favorites => 'Favorites';
	@override String get hot => 'Hot';
	@override String get zones => 'Zones';
	@override String get search => 'Search';
	@override String get toolbox => 'Toolbox';
	@override String get groupPersonal => 'Personal & system';
	@override String get record => 'Recording';
	@override String get settings => 'Settings';
	@override String get appearance => 'Appearance';
	@override String get proxy => 'Network proxy';
	@override String get user => 'User';
}

// Path: player
class _Translations$player$en extends Translations$player$zh_CN {
	_Translations$player$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get title => 'Player';
	@override String get back => 'Back';
	@override String get quality => 'Quality';
	@override String get line => 'Line';
	@override String get fullscreen => 'Fullscreen';
	@override String get danmaku => 'Danmaku';
}

// Path: settings
class _Translations$settings$en extends Translations$settings$zh_CN {
	_Translations$settings$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get title => 'Settings';
	@override String get appearance => 'Appearance';
	@override String get themeMode => 'Theme';
	@override String get themeModeSystem => 'Follow system';
	@override String get themeModeLight => 'Light';
	@override String get themeModeDark => 'Dark';
	@override String get language => 'Language';
	@override String get about => 'About';
}

// Path: sites
class _Translations$sites$en extends Translations$sites$zh_CN {
	_Translations$sites$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get title => 'Sites';
	@override String get live => 'Live';
	@override String get search => 'Search';
	@override String get rooms => 'Rooms';
}

/// The flat map containing all translations for locale <en>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsEn {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'common.appTitle' => 'Pure Live',
			'common.empty' => 'Nothing here yet',
			'common.comingSoon' => 'Coming soon',
			'common.close' => 'Close',
			'common.cancel' => 'Cancel',
			'common.confirm' => 'Confirm',
			'common.minimize' => 'Minimize',
			'common.maximize' => 'Maximize',
			'common.restore' => 'Restore',
			'common.toggleSidebar' => 'Toggle sidebar',
			'common.back' => 'Back',
			'common.forward' => 'Forward',
			'common.searchHint' => 'Search rooms, streamers or sites',
			'navigation.groupPrimary' => 'Top pages',
			'navigation.home' => 'Home',
			'navigation.live' => 'Live',
			'navigation.channels' => 'Channels',
			'navigation.discover' => 'Discover',
			'navigation.history' => 'History',
			'navigation.groupContent' => 'Content & tools',
			'navigation.multiview' => 'Multi-view',
			'navigation.favorites' => 'Favorites',
			'navigation.hot' => 'Hot',
			'navigation.zones' => 'Zones',
			'navigation.search' => 'Search',
			'navigation.toolbox' => 'Toolbox',
			'navigation.groupPersonal' => 'Personal & system',
			'navigation.record' => 'Recording',
			'navigation.settings' => 'Settings',
			'navigation.appearance' => 'Appearance',
			'navigation.proxy' => 'Network proxy',
			'navigation.user' => 'User',
			'player.title' => 'Player',
			'player.back' => 'Back',
			'player.quality' => 'Quality',
			'player.line' => 'Line',
			'player.fullscreen' => 'Fullscreen',
			'player.danmaku' => 'Danmaku',
			'settings.title' => 'Settings',
			'settings.appearance' => 'Appearance',
			'settings.themeMode' => 'Theme',
			'settings.themeModeSystem' => 'Follow system',
			'settings.themeModeLight' => 'Light',
			'settings.themeModeDark' => 'Dark',
			'settings.language' => 'Language',
			'settings.about' => 'About',
			'sites.title' => 'Sites',
			'sites.live' => 'Live',
			'sites.search' => 'Search',
			'sites.rooms' => 'Rooms',
			_ => null,
		};
	}
}
