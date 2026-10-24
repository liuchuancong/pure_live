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
	@override late final _Translations$areas$en areas = _Translations$areas$en._(_root);
	@override late final _Translations$common$en common = _Translations$common$en._(_root);
	@override late final _Translations$favorites$en favorites = _Translations$favorites$en._(_root);
	@override late final _Translations$history$en history = _Translations$history$en._(_root);
	@override late final _Translations$iptv$en iptv = _Translations$iptv$en._(_root);
	@override late final _Translations$music$en music = _Translations$music$en._(_root);
	@override late final _Translations$navigation$en navigation = _Translations$navigation$en._(_root);
	@override late final _Translations$player$en player = _Translations$player$en._(_root);
	@override late final _Translations$room$en room = _Translations$room$en._(_root);
	@override late final _Translations$search$en search = _Translations$search$en._(_root);
	@override late final _Translations$settings$en settings = _Translations$settings$en._(_root);
	@override late final _Translations$sites$en sites = _Translations$sites$en._(_root);
	@override late final _Translations$vod$en vod = _Translations$vod$en._(_root);
}

// Path: areas
class _Translations$areas$en extends Translations$areas$zh_CN {
	_Translations$areas$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get allAreas => 'All areas';
	@override String get noAreas => 'This site has no areas';
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
	@override String get moduleLive => 'Live';
	@override String get moduleIptv => 'IPTV';
	@override String get moduleVod => 'Videos';
	@override String get moduleMusic => 'Music';
	@override String get retry => 'Retry';
	@override String get moduleComingSoon => 'This module is on its way';
	@override String get back => 'Back';
	@override String get forward => 'Forward';
	@override String get searchHint => 'Search rooms, streamers or sites';
}

// Path: favorites
class _Translations$favorites$en extends Translations$favorites$zh_CN {
	_Translations$favorites$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get emptyTitle => 'No followed rooms yet';
	@override String get emptyDescription => 'Follow a room and it lands here.';
	@override String get unfollow => 'Unfollow';
}

// Path: history
class _Translations$history$en extends Translations$history$zh_CN {
	_Translations$history$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get emptyTitle => 'No watch history yet';
	@override String get emptyDescription => 'Watch a stream and it lands here.';
	@override String get clear => 'Clear history';
	@override String get remove => 'Remove this record';
}

// Path: iptv
class _Translations$iptv$en extends Translations$iptv$zh_CN {
	_Translations$iptv$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get tabAll => 'All';
	@override String get scopeLabel => 'Channel scope';
	@override String get scopeAll => 'All channels';
	@override String get scopeFavourites => 'Favourites';
	@override String get groupsLabel => 'Channel groups';
	@override String get ungrouped => 'Ungrouped';
	@override String get emptyTitle => 'No channels yet';
	@override String get emptyDescription => 'Import an M3U or TXT playlist and its channels will appear here.';
	@override String get openFailedDescription => 'The channel library could not be opened.';
	@override String get noFavoritesTitle => 'No favourite channels';
	@override String get noFavoritesDescription => 'Tap the heart on a channel card and it stays in this list.';
	@override String get onAir => 'On air';
	@override String get upNext => 'Next';
	@override String get noGuide => 'No programme guide';
	@override String get favouriteAction => 'Favourite';
	@override String get unfavouriteAction => 'Unfavourite';
}

// Path: music
class _Translations$music$en extends Translations$music$zh_CN {
	_Translations$music$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get title => 'Music';
	@override String get tagline => 'Songs, playlists and charts are on their way';
	@override String get viewsLabel => 'Music views';
	@override String get tabLibrary => 'Library';
	@override String get tabPlaylists => 'Playlists';
	@override String get tabCharts => 'Charts';
	@override String get libraryEmptyTitle => 'The song library is on its way';
	@override String get libraryEmptyDescription => 'Once a music source lands, songs will page in here as a masonry grid of cards.';
	@override String get playlistsEmptyTitle => 'Playlists are on their way';
	@override String get playlistsEmptyDescription => 'Playlists you curate and follow will live here.';
	@override String get chartsEmptyTitle => 'Charts are on their way';
	@override String get chartsEmptyDescription => 'Popular-song charts from the music sources will live here.';
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

// Path: room
class _Translations$room$en extends Translations$room$zh_CN {
	_Translations$room$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get opening => 'Opening the room';
	@override String get follow => 'Follow';
	@override String get unfollow => 'Following';
	@override String get quality => 'Quality';
	@override String get lineLabel => 'Line';
	@override String line({required Object n}) => 'Line ${n}';
	@override String get play => 'Play';
	@override String get pause => 'Pause';
	@override String get noChat => 'No chat yet';
	@override String get system => 'System';
	@override String get mute => 'Mute';
	@override String get unmute => 'Unmute';
	@override String get volume => 'Volume';
	@override String get sleep => 'Sleep timer';
	@override String get sleepOff => 'Stop the timer';
}

// Path: search
class _Translations$search$en extends Translations$search$zh_CN {
	_Translations$search$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get idleTitle => 'Search the selected site';
	@override String get idleDescription => 'Type to search its rooms, streamers or areas.';
	@override String get suggestionsTitle => 'Suggestions';
	@override String get targetsLabel => 'Search target';
	@override String get tabRooms => 'Rooms';
	@override String get tabAnchors => 'Streamers';
	@override String get tabAreas => 'Areas';
	@override String get noResultsTitle => 'No results';
	@override String get noResultsDescription => 'Try another keyword, or switch to another target.';
	@override String get unsupportedTitle => 'This site cannot be searched';
	@override String get unsupportedDescription => 'Pick another site from the home page first.';
	@override String get liveBadge => 'Live';
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
	@override String get browsingTitle => 'Browsing';
	@override String get site => 'Default site';
	@override String get cardExtent => 'Card width';
	@override String get cardExtentDescription => 'How wide a feed card gets; smaller fits more per row.';
	@override String get pageSize => 'Page size';
	@override String get pageSizeDescription => 'How many rooms one page asks the site for.';
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

// Path: vod
class _Translations$vod$en extends Translations$vod$zh_CN {
	_Translations$vod$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get searchHint => 'Search Bilibili videos';
	@override String get idleTitle => 'Search for videos';
	@override String get idleDescription => 'Type a keyword to search Bilibili videos; region browse and rankings are not offered by this source yet.';
	@override String get noResultsTitle => 'No videos found';
	@override String get noResultsDescription => 'Try another keyword.';
	@override String get errorTitle => 'The videos did not load';
	@override String get retry => 'Retry';
}

/// The flat map containing all translations for locale <en>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsEn {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'areas.allAreas' => 'All areas',
			'areas.noAreas' => 'This site has no areas',
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
			'common.moduleLive' => 'Live',
			'common.moduleIptv' => 'IPTV',
			'common.moduleVod' => 'Videos',
			'common.moduleMusic' => 'Music',
			'common.retry' => 'Retry',
			'common.moduleComingSoon' => 'This module is on its way',
			'common.back' => 'Back',
			'common.forward' => 'Forward',
			'common.searchHint' => 'Search rooms, streamers or sites',
			'favorites.emptyTitle' => 'No followed rooms yet',
			'favorites.emptyDescription' => 'Follow a room and it lands here.',
			'favorites.unfollow' => 'Unfollow',
			'history.emptyTitle' => 'No watch history yet',
			'history.emptyDescription' => 'Watch a stream and it lands here.',
			'history.clear' => 'Clear history',
			'history.remove' => 'Remove this record',
			'iptv.tabAll' => 'All',
			'iptv.scopeLabel' => 'Channel scope',
			'iptv.scopeAll' => 'All channels',
			'iptv.scopeFavourites' => 'Favourites',
			'iptv.groupsLabel' => 'Channel groups',
			'iptv.ungrouped' => 'Ungrouped',
			'iptv.emptyTitle' => 'No channels yet',
			'iptv.emptyDescription' => 'Import an M3U or TXT playlist and its channels will appear here.',
			'iptv.openFailedDescription' => 'The channel library could not be opened.',
			'iptv.noFavoritesTitle' => 'No favourite channels',
			'iptv.noFavoritesDescription' => 'Tap the heart on a channel card and it stays in this list.',
			'iptv.onAir' => 'On air',
			'iptv.upNext' => 'Next',
			'iptv.noGuide' => 'No programme guide',
			'iptv.favouriteAction' => 'Favourite',
			'iptv.unfavouriteAction' => 'Unfavourite',
			'music.title' => 'Music',
			'music.tagline' => 'Songs, playlists and charts are on their way',
			'music.viewsLabel' => 'Music views',
			'music.tabLibrary' => 'Library',
			'music.tabPlaylists' => 'Playlists',
			'music.tabCharts' => 'Charts',
			'music.libraryEmptyTitle' => 'The song library is on its way',
			'music.libraryEmptyDescription' => 'Once a music source lands, songs will page in here as a masonry grid of cards.',
			'music.playlistsEmptyTitle' => 'Playlists are on their way',
			'music.playlistsEmptyDescription' => 'Playlists you curate and follow will live here.',
			'music.chartsEmptyTitle' => 'Charts are on their way',
			'music.chartsEmptyDescription' => 'Popular-song charts from the music sources will live here.',
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
			'room.opening' => 'Opening the room',
			'room.follow' => 'Follow',
			'room.unfollow' => 'Following',
			'room.quality' => 'Quality',
			'room.lineLabel' => 'Line',
			'room.line' => ({required Object n}) => 'Line ${n}',
			'room.play' => 'Play',
			'room.pause' => 'Pause',
			'room.noChat' => 'No chat yet',
			'room.system' => 'System',
			'room.mute' => 'Mute',
			'room.unmute' => 'Unmute',
			'room.volume' => 'Volume',
			'room.sleep' => 'Sleep timer',
			'room.sleepOff' => 'Stop the timer',
			'search.idleTitle' => 'Search the selected site',
			'search.idleDescription' => 'Type to search its rooms, streamers or areas.',
			'search.suggestionsTitle' => 'Suggestions',
			'search.targetsLabel' => 'Search target',
			'search.tabRooms' => 'Rooms',
			'search.tabAnchors' => 'Streamers',
			'search.tabAreas' => 'Areas',
			'search.noResultsTitle' => 'No results',
			'search.noResultsDescription' => 'Try another keyword, or switch to another target.',
			'search.unsupportedTitle' => 'This site cannot be searched',
			'search.unsupportedDescription' => 'Pick another site from the home page first.',
			'search.liveBadge' => 'Live',
			'settings.title' => 'Settings',
			'settings.appearance' => 'Appearance',
			'settings.themeMode' => 'Theme',
			'settings.themeModeSystem' => 'Follow system',
			'settings.themeModeLight' => 'Light',
			'settings.themeModeDark' => 'Dark',
			'settings.language' => 'Language',
			'settings.about' => 'About',
			'settings.browsingTitle' => 'Browsing',
			'settings.site' => 'Default site',
			'settings.cardExtent' => 'Card width',
			'settings.cardExtentDescription' => 'How wide a feed card gets; smaller fits more per row.',
			'settings.pageSize' => 'Page size',
			'settings.pageSizeDescription' => 'How many rooms one page asks the site for.',
			'sites.title' => 'Sites',
			'sites.live' => 'Live',
			'sites.search' => 'Search',
			'sites.rooms' => 'Rooms',
			'vod.searchHint' => 'Search Bilibili videos',
			'vod.idleTitle' => 'Search for videos',
			'vod.idleDescription' => 'Type a keyword to search Bilibili videos; region browse and rankings are not offered by this source yet.',
			'vod.noResultsTitle' => 'No videos found',
			'vod.noResultsDescription' => 'Try another keyword.',
			'vod.errorTitle' => 'The videos did not load',
			'vod.retry' => 'Retry',
			_ => null,
		};
	}
}
