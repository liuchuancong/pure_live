///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:slang/generated.dart';
import 'strings.g.dart';

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
	@override late final _Translations$app$en app = _Translations$app$en._(_root);
	@override late final _Translations$home$en home = _Translations$home$en._(_root);
	@override late final _Translations$common$en common = _Translations$common$en._(_root);
	@override late final _Translations$tray$en tray = _Translations$tray$en._(_root);
	@override late final _Translations$settings$en settings = _Translations$settings$en._(_root);
	@override late final _Translations$theme$en theme = _Translations$theme$en._(_root);
	@override late final _Translations$design$en design = _Translations$design$en._(_root);
	@override late final _Translations$room$en room = _Translations$room$en._(_root);
	@override late final _Translations$history$en history = _Translations$history$en._(_root);
	@override late final _Translations$iptv$en iptv = _Translations$iptv$en._(_root);
	@override late final _Translations$fonts$en fonts = _Translations$fonts$en._(_root);
	@override late final _Translations$follow$en follow = _Translations$follow$en._(_root);
	@override late final _Translations$toolbox$en toolbox = _Translations$toolbox$en._(_root);
	@override late final _Translations$about$en about = _Translations$about$en._(_root);
	@override late final _Translations$shield$en shield = _Translations$shield$en._(_root);
	@override late final _Translations$search$en search = _Translations$search$en._(_root);
	@override late final _Translations$errors$en errors = _Translations$errors$en._(_root);
	@override late final _Translations$tabs$en tabs = _Translations$tabs$en._(_root);
	@override late final _Translations$window$en window = _Translations$window$en._(_root);
	@override late final _Translations$closePrompt$en closePrompt = _Translations$closePrompt$en._(_root);
	@override late final _Translations$shellSettings$en shellSettings = _Translations$shellSettings$en._(_root);
}

// Path: app
class _Translations$app$en extends Translations$app$zh {
	_Translations$app$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get title => 'Pure Live';
}

// Path: home
class _Translations$home$en extends Translations$home$zh {
	_Translations$home$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get recommended => 'Recommendations';
}

// Path: common
class _Translations$common$en extends Translations$common$zh {
	_Translations$common$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get confirm => 'OK';
	@override String get cancel => 'Cancel';
	@override String get retry => 'Retry';
	@override String get close => 'Close';
	@override String get save => 'Save';
	@override String get loading => 'Loading';
	@override String get empty => 'Nothing here yet';
	@override String pageOf({required int page, required int total}) => 'Page ${page} of ${total}';
}

// Path: tray
class _Translations$tray$en extends Translations$tray$zh {
	_Translations$tray$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get show => 'Show Pure Live';
	@override String get quit => 'Quit';
}

// Path: settings
class _Translations$settings$en extends Translations$settings$zh {
	_Translations$settings$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get appearance => 'Appearance';
	@override String get fonts => 'Fonts';
	@override String get themeMode => 'Theme mode';
	@override String get designLanguage => 'Design language';
	@override String get accent => 'Accent';
	@override String get pureBlack => 'Pure black';
	@override String get density => 'Density';
	@override String get fontScale => 'Font size';
	@override String get transparency => 'Transparency';
	@override String get reduceTransparency => 'Reduce transparency';
	@override String get animations => 'Animations';
	@override String get focusOutline => 'Focus outline';
}

// Path: theme
class _Translations$theme$en extends Translations$theme$zh {
	_Translations$theme$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get system => 'System';
	@override String get dark => 'Dark';
	@override String get light => 'Light';
}

// Path: design
class _Translations$design$en extends Translations$design$zh {
	_Translations$design$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get defaultLanguage => 'Default (Fluent)';
}

// Path: room
class _Translations$room$en extends Translations$room$zh {
	_Translations$room$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get sortPlatform => 'Default';
	@override String get sortViewers => 'Most viewers';
	@override String get quality => 'Quality';
	@override String get line => 'Line';
	@override String get play => 'Play';
	@override String get pause => 'Pause';
	@override String get failed => 'Playback failed — try again';
}

// Path: history
class _Translations$history$en extends Translations$history$zh {
	_Translations$history$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get clear => 'Clear history';
	@override String get clearConfirm => 'Clear the whole watch history? This cannot be undone.';
	@override String get empty => 'Nothing watched yet';
}

// Path: iptv
class _Translations$iptv$en extends Translations$iptv$zh {
	_Translations$iptv$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get title => 'IPTV';
	@override String get addSource => 'Add source';
	@override String get sourceName => 'Source name';
	@override String get sourceUrl => 'Playlist URL (M3U/TXT)';
	@override String get deleteSource => 'Delete this source? Its channels go too';
	@override String imported({required int count}) => 'Imported ${count} channels';
	@override String get allGroups => 'All groups';
	@override String get favorite => 'Favorite';
	@override String get empty => 'No source imported yet';
}

// Path: fonts
class _Translations$fonts$en extends Translations$fonts$zh {
	_Translations$fonts$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get fonts => 'Fonts';
	@override String get system => 'System default';
	@override String get systemDesc => 'Use the fonts the system ships';
	@override String get download => 'Download';
	@override String get delete => 'Delete';
}

// Path: follow
class _Translations$follow$en extends Translations$follow$zh {
	_Translations$follow$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get all => 'All';
	@override String get empty => 'No followed rooms yet';
	@override String get follow => 'Follow';
	@override String get unfollow => 'Unfollow';
	@override String unfollowConfirm({required String name}) => 'Unfollow "${name}"?';
	@override String get newGroup => 'New group';
	@override String get groupName => 'Group name';
}

// Path: toolbox
class _Translations$toolbox$en extends Translations$toolbox$zh {
	_Translations$toolbox$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get title => 'Toolbox';
	@override String get hint => 'Paste a room link';
	@override String get readClipboard => 'Read clipboard';
	@override String get resolve => 'Resolve';
	@override String get failed => 'No platform recognised this link';
	@override String get openRoom => 'Open the room';
}

// Path: about
class _Translations$about$en extends Translations$about$zh {
	_Translations$about$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get title => 'About';
	@override String get checkUpdate => 'Check for updates';
	@override String get upToDate => 'Up to date';
	@override String get newVersion => 'New version available:';
	@override String get versionHistory => 'Version history';
	@override String get licenses => 'Licenses';
	@override String get project => 'Project page';
	@override String get checkRunning => 'Checking…';
	@override String get checkFailed => 'Check failed — tap to retry';
}

// Path: shield
class _Translations$shield$en extends Translations$shield$zh {
	_Translations$shield$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get title => 'Danmaku shield';
	@override String get keywords => 'Keywords';
	@override String get users => 'Users';
	@override String get regexes => 'Regexes';
	@override String get add => 'Add';
	@override String get none => 'Nothing here';
}

// Path: search
class _Translations$search$en extends Translations$search$zh {
	_Translations$search$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get hint => 'Search rooms by keyword';
	@override String get rooms => 'Rooms';
	@override String get anchors => 'Anchors';
}

// Path: errors
class _Translations$errors$en extends Translations$errors$zh {
	_Translations$errors$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get generic => 'Something went wrong. Please try again later.';
	@override String get network => 'Network unavailable. Check your connection and retry.';
	@override String get notFound => 'Nothing found.';
	@override String get cancelled => 'Cancelled.';
	@override String get unsupported => 'This source doesn\'t support that.';
}

// Path: tabs
class _Translations$tabs$en extends Translations$tabs$zh {
	_Translations$tabs$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get home => 'Home';
	@override String get follow => 'Follow';
	@override String get history => 'History';
	@override String get popular => 'Popular';
	@override String get areas => 'Areas';
	@override String get search => 'Search';
	@override String get settings => 'Settings';
}

// Path: window
class _Translations$window$en extends Translations$window$zh {
	_Translations$window$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get minimize => 'Minimize';
	@override String get maximize => 'Maximize';
	@override String get restore => 'Restore';
	@override String get close => 'Close';
}

// Path: closePrompt
class _Translations$closePrompt$en extends Translations$closePrompt$zh {
	_Translations$closePrompt$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get title => 'What should closing the window do?';
	@override String get toTray => 'Hide to tray, keep playback';
	@override String get quit => 'Quit Pure Live';
	@override String get remember => 'Remember my choice, stop asking';
}

// Path: shellSettings
class _Translations$shellSettings$en extends Translations$shellSettings$zh {
	_Translations$shellSettings$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get sectionWindow => 'Window';
	@override String get titleBar => 'Window title bar';
	@override String get titleBarApp => 'App title bar';
	@override String get titleBarSystem => 'System title bar';
	@override String get titleBarHint => 'The app title bar is drawn by Pure Live; the system title bar uses the native Windows style. A switch applies after the app restarts.';
}

/// The flat map containing all translations for locale <en>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsEn {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'app.title' => 'Pure Live',
			'home.recommended' => 'Recommendations',
			'common.confirm' => 'OK',
			'common.cancel' => 'Cancel',
			'common.retry' => 'Retry',
			'common.close' => 'Close',
			'common.save' => 'Save',
			'common.loading' => 'Loading',
			'common.empty' => 'Nothing here yet',
			'common.pageOf' => ({required int page, required int total}) => 'Page ${page} of ${total}',
			'tray.show' => 'Show Pure Live',
			'tray.quit' => 'Quit',
			'settings.appearance' => 'Appearance',
			'settings.fonts' => 'Fonts',
			'settings.themeMode' => 'Theme mode',
			'settings.designLanguage' => 'Design language',
			'settings.accent' => 'Accent',
			'settings.pureBlack' => 'Pure black',
			'settings.density' => 'Density',
			'settings.fontScale' => 'Font size',
			'settings.transparency' => 'Transparency',
			'settings.reduceTransparency' => 'Reduce transparency',
			'settings.animations' => 'Animations',
			'settings.focusOutline' => 'Focus outline',
			'theme.system' => 'System',
			'theme.dark' => 'Dark',
			'theme.light' => 'Light',
			'design.defaultLanguage' => 'Default (Fluent)',
			'room.sortPlatform' => 'Default',
			'room.sortViewers' => 'Most viewers',
			'room.quality' => 'Quality',
			'room.line' => 'Line',
			'room.play' => 'Play',
			'room.pause' => 'Pause',
			'room.failed' => 'Playback failed — try again',
			'history.clear' => 'Clear history',
			'history.clearConfirm' => 'Clear the whole watch history? This cannot be undone.',
			'history.empty' => 'Nothing watched yet',
			'iptv.title' => 'IPTV',
			'iptv.addSource' => 'Add source',
			'iptv.sourceName' => 'Source name',
			'iptv.sourceUrl' => 'Playlist URL (M3U/TXT)',
			'iptv.deleteSource' => 'Delete this source? Its channels go too',
			'iptv.imported' => ({required int count}) => 'Imported ${count} channels',
			'iptv.allGroups' => 'All groups',
			'iptv.favorite' => 'Favorite',
			'iptv.empty' => 'No source imported yet',
			'fonts.fonts' => 'Fonts',
			'fonts.system' => 'System default',
			'fonts.systemDesc' => 'Use the fonts the system ships',
			'fonts.download' => 'Download',
			'fonts.delete' => 'Delete',
			'follow.all' => 'All',
			'follow.empty' => 'No followed rooms yet',
			'follow.follow' => 'Follow',
			'follow.unfollow' => 'Unfollow',
			'follow.unfollowConfirm' => ({required String name}) => 'Unfollow "${name}"?',
			'follow.newGroup' => 'New group',
			'follow.groupName' => 'Group name',
			'toolbox.title' => 'Toolbox',
			'toolbox.hint' => 'Paste a room link',
			'toolbox.readClipboard' => 'Read clipboard',
			'toolbox.resolve' => 'Resolve',
			'toolbox.failed' => 'No platform recognised this link',
			'toolbox.openRoom' => 'Open the room',
			'about.title' => 'About',
			'about.checkUpdate' => 'Check for updates',
			'about.upToDate' => 'Up to date',
			'about.newVersion' => 'New version available:',
			'about.versionHistory' => 'Version history',
			'about.licenses' => 'Licenses',
			'about.project' => 'Project page',
			'about.checkRunning' => 'Checking…',
			'about.checkFailed' => 'Check failed — tap to retry',
			'shield.title' => 'Danmaku shield',
			'shield.keywords' => 'Keywords',
			'shield.users' => 'Users',
			'shield.regexes' => 'Regexes',
			'shield.add' => 'Add',
			'shield.none' => 'Nothing here',
			'search.hint' => 'Search rooms by keyword',
			'search.rooms' => 'Rooms',
			'search.anchors' => 'Anchors',
			'errors.generic' => 'Something went wrong. Please try again later.',
			'errors.network' => 'Network unavailable. Check your connection and retry.',
			'errors.notFound' => 'Nothing found.',
			'errors.cancelled' => 'Cancelled.',
			'errors.unsupported' => 'This source doesn\'t support that.',
			'tabs.home' => 'Home',
			'tabs.follow' => 'Follow',
			'tabs.history' => 'History',
			'tabs.popular' => 'Popular',
			'tabs.areas' => 'Areas',
			'tabs.search' => 'Search',
			'tabs.settings' => 'Settings',
			'window.minimize' => 'Minimize',
			'window.maximize' => 'Maximize',
			'window.restore' => 'Restore',
			'window.close' => 'Close',
			'closePrompt.title' => 'What should closing the window do?',
			'closePrompt.toTray' => 'Hide to tray, keep playback',
			'closePrompt.quit' => 'Quit Pure Live',
			'closePrompt.remember' => 'Remember my choice, stop asking',
			'shellSettings.sectionWindow' => 'Window',
			'shellSettings.titleBar' => 'Window title bar',
			'shellSettings.titleBarApp' => 'App title bar',
			'shellSettings.titleBarSystem' => 'System title bar',
			'shellSettings.titleBarHint' => 'The app title bar is drawn by Pure Live; the system title bar uses the native Windows style. A switch applies after the app restarts.',
			_ => null,
		};
	}
}
