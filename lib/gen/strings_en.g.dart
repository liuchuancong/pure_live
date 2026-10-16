///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

part of 'strings.g.dart';

// Path: <root>
typedef TranslationsEn = Translations; // ignore: unused_element
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
		    locale: AppLocale.en,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ) {
		_meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <en>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	/// Access flat map
	dynamic operator[](String key) => _meta.getTranslation(key);

	late final Translations _root = this; // ignore: unused_field

	Translations $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => Translations(meta: meta ?? this.$meta);

	// Translations
	late final Translations$app$en app = Translations$app$en._(_root);
	late final Translations$home$en home = Translations$home$en._(_root);
	late final Translations$common$en common = Translations$common$en._(_root);
	late final Translations$tray$en tray = Translations$tray$en._(_root);
	late final Translations$settings$en settings = Translations$settings$en._(_root);
	late final Translations$theme$en theme = Translations$theme$en._(_root);
	late final Translations$design$en design = Translations$design$en._(_root);
	late final Translations$room$en room = Translations$room$en._(_root);
	late final Translations$history$en history = Translations$history$en._(_root);
	late final Translations$iptv$en iptv = Translations$iptv$en._(_root);
	late final Translations$fonts$en fonts = Translations$fonts$en._(_root);
	late final Translations$follow$en follow = Translations$follow$en._(_root);
	late final Translations$toolbox$en toolbox = Translations$toolbox$en._(_root);
	late final Translations$backup$en backup = Translations$backup$en._(_root);
	late final Translations$about$en about = Translations$about$en._(_root);
	late final Translations$shield$en shield = Translations$shield$en._(_root);
	late final Translations$multiview$en multiview = Translations$multiview$en._(_root);
	late final Translations$search$en search = Translations$search$en._(_root);
	late final Translations$errors$en errors = Translations$errors$en._(_root);
	late final Translations$tabs$en tabs = Translations$tabs$en._(_root);
	late final Translations$window$en window = Translations$window$en._(_root);
	late final Translations$closePrompt$en closePrompt = Translations$closePrompt$en._(_root);
	late final Translations$shellSettings$en shellSettings = Translations$shellSettings$en._(_root);
}

// Path: app
class Translations$app$en {
	Translations$app$en._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Pure Live'
	String get title => 'Pure Live';
}

// Path: home
class Translations$home$en {
	Translations$home$en._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Recommendations'
	String get recommended => 'Recommendations';
}

// Path: common
class Translations$common$en {
	Translations$common$en._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'OK'
	String get confirm => 'OK';

	/// en: 'Cancel'
	String get cancel => 'Cancel';

	/// en: 'Retry'
	String get retry => 'Retry';

	/// en: 'Close'
	String get close => 'Close';

	/// en: 'Save'
	String get save => 'Save';

	/// en: 'Loading'
	String get loading => 'Loading';

	/// en: 'Nothing here yet'
	String get empty => 'Nothing here yet';

	/// en: 'Page {page: int} of {total: int}'
	String get pageOf => 'Page {page: int} of {total: int}';
}

// Path: tray
class Translations$tray$en {
	Translations$tray$en._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Show Pure Live'
	String get show => 'Show Pure Live';

	/// en: 'Quit'
	String get quit => 'Quit';
}

// Path: settings
class Translations$settings$en {
	Translations$settings$en._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Appearance'
	String get appearance => 'Appearance';

	/// en: 'Fonts'
	String get fonts => 'Fonts';

	/// en: 'Theme mode'
	String get themeMode => 'Theme mode';

	/// en: 'Design language'
	String get designLanguage => 'Design language';

	/// en: 'Accent'
	String get accent => 'Accent';

	/// en: 'Pure black'
	String get pureBlack => 'Pure black';

	/// en: 'Density'
	String get density => 'Density';

	/// en: 'Font size'
	String get fontScale => 'Font size';

	/// en: 'Transparency'
	String get transparency => 'Transparency';

	/// en: 'Reduce transparency'
	String get reduceTransparency => 'Reduce transparency';

	/// en: 'Animations'
	String get animations => 'Animations';

	/// en: 'Focus outline'
	String get focusOutline => 'Focus outline';
}

// Path: theme
class Translations$theme$en {
	Translations$theme$en._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'System'
	String get system => 'System';

	/// en: 'Dark'
	String get dark => 'Dark';

	/// en: 'Light'
	String get light => 'Light';
}

// Path: design
class Translations$design$en {
	Translations$design$en._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Default (Fluent)'
	String get defaultLanguage => 'Default (Fluent)';
}

// Path: room
class Translations$room$en {
	Translations$room$en._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Default'
	String get sortPlatform => 'Default';

	/// en: 'Most viewers'
	String get sortViewers => 'Most viewers';

	/// en: 'Danmaku connection failed'
	String get danmakuFailed => 'Danmaku connection failed';

	/// en: 'Quality'
	String get quality => 'Quality';

	/// en: 'Line'
	String get line => 'Line';

	/// en: 'Play'
	String get play => 'Play';

	/// en: 'Pause'
	String get pause => 'Pause';

	/// en: 'Playback failed — try again'
	String get failed => 'Playback failed — try again';
}

// Path: history
class Translations$history$en {
	Translations$history$en._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Clear history'
	String get clear => 'Clear history';

	/// en: 'Clear the whole watch history? This cannot be undone.'
	String get clearConfirm => 'Clear the whole watch history? This cannot be undone.';

	/// en: 'Nothing watched yet'
	String get empty => 'Nothing watched yet';
}

// Path: iptv
class Translations$iptv$en {
	Translations$iptv$en._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'IPTV'
	String get title => 'IPTV';

	/// en: 'Add source'
	String get addSource => 'Add source';

	/// en: 'Source name'
	String get sourceName => 'Source name';

	/// en: 'Playlist URL (M3U/TXT)'
	String get sourceUrl => 'Playlist URL (M3U/TXT)';

	/// en: 'Delete this source? Its channels go too'
	String get deleteSource => 'Delete this source? Its channels go too';

	/// en: 'Imported {count: int} channels'
	String get imported => 'Imported {count: int} channels';

	/// en: 'All groups'
	String get allGroups => 'All groups';

	/// en: 'Favorite'
	String get favorite => 'Favorite';

	/// en: 'No source imported yet'
	String get empty => 'No source imported yet';
}

// Path: fonts
class Translations$fonts$en {
	Translations$fonts$en._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Fonts'
	String get fonts => 'Fonts';

	/// en: 'System default'
	String get system => 'System default';

	/// en: 'Use the fonts the system ships'
	String get systemDesc => 'Use the fonts the system ships';

	/// en: 'Download'
	String get download => 'Download';

	/// en: 'Delete'
	String get delete => 'Delete';
}

// Path: follow
class Translations$follow$en {
	Translations$follow$en._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'All'
	String get all => 'All';

	/// en: 'No followed rooms yet'
	String get empty => 'No followed rooms yet';

	/// en: 'Follow'
	String get follow => 'Follow';

	/// en: 'Unfollow'
	String get unfollow => 'Unfollow';

	/// en: 'Unfollow "{name: String}"?'
	String get unfollowConfirm => 'Unfollow "{name: String}"?';

	/// en: 'New group'
	String get newGroup => 'New group';

	/// en: 'Group name'
	String get groupName => 'Group name';
}

// Path: toolbox
class Translations$toolbox$en {
	Translations$toolbox$en._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Toolbox'
	String get title => 'Toolbox';

	/// en: 'Paste a room link'
	String get hint => 'Paste a room link';

	/// en: 'Read clipboard'
	String get readClipboard => 'Read clipboard';

	/// en: 'Resolve'
	String get resolve => 'Resolve';

	/// en: 'No platform recognised this link'
	String get failed => 'No platform recognised this link';

	/// en: 'Open the room'
	String get openRoom => 'Open the room';
}

// Path: backup
class Translations$backup$en {
	Translations$backup$en._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Backup & restore'
	String get title => 'Backup & restore';

	/// en: 'Create backup'
	String get create => 'Create backup';

	/// en: 'Restore from file'
	String get restoreFile => 'Restore from file';

	/// en: 'Existing backups'
	String get existing => 'Existing backups';

	/// en: 'No backups yet'
	String get none => 'No backups yet';

	/// en: 'Delete backup'
	String get delete => 'Delete backup';

	/// en: 'Restore'
	String get restore => 'Restore';

	/// en: 'Overwrite current data with “{name: String}”? The app restarts.'
	String get restoreConfirm => 'Overwrite current data with “{name: String}”? The app restarts.';
}

// Path: about
class Translations$about$en {
	Translations$about$en._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'About'
	String get title => 'About';

	/// en: 'Check for updates'
	String get checkUpdate => 'Check for updates';

	/// en: 'Up to date'
	String get upToDate => 'Up to date';

	/// en: 'New version available:'
	String get newVersion => 'New version available:';

	/// en: 'Version history'
	String get versionHistory => 'Version history';

	/// en: 'Licenses'
	String get licenses => 'Licenses';

	/// en: 'Project page'
	String get project => 'Project page';

	/// en: 'Checking…'
	String get checkRunning => 'Checking…';

	/// en: 'Check failed — tap to retry'
	String get checkFailed => 'Check failed — tap to retry';
}

// Path: shield
class Translations$shield$en {
	Translations$shield$en._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Danmaku shield'
	String get title => 'Danmaku shield';

	/// en: 'Keywords'
	String get keywords => 'Keywords';

	/// en: 'Users'
	String get users => 'Users';

	/// en: 'Regexes'
	String get regexes => 'Regexes';

	/// en: 'Add'
	String get add => 'Add';

	/// en: 'Nothing here'
	String get none => 'Nothing here';
}

// Path: multiview
class Translations$multiview$en {
	Translations$multiview$en._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Multi-view'
	String get title => 'Multi-view';

	/// en: 'Platform'
	String get platform => 'Platform';

	/// en: 'Room ID'
	String get roomId => 'Room ID';

	/// en: 'Add cell'
	String get add => 'Add cell';
}

// Path: search
class Translations$search$en {
	Translations$search$en._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Search rooms by keyword'
	String get hint => 'Search rooms by keyword';

	/// en: 'Rooms'
	String get rooms => 'Rooms';

	/// en: 'Anchors'
	String get anchors => 'Anchors';
}

// Path: errors
class Translations$errors$en {
	Translations$errors$en._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Something went wrong. Please try again later.'
	String get generic => 'Something went wrong. Please try again later.';

	/// en: 'Network unavailable. Check your connection and retry.'
	String get network => 'Network unavailable. Check your connection and retry.';

	/// en: 'Nothing found.'
	String get notFound => 'Nothing found.';

	/// en: 'Cancelled.'
	String get cancelled => 'Cancelled.';

	/// en: 'This source doesn't support that.'
	String get unsupported => 'This source doesn\'t support that.';
}

// Path: tabs
class Translations$tabs$en {
	Translations$tabs$en._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Home'
	String get home => 'Home';

	/// en: 'Follow'
	String get follow => 'Follow';

	/// en: 'History'
	String get history => 'History';

	/// en: 'Popular'
	String get popular => 'Popular';

	/// en: 'Areas'
	String get areas => 'Areas';

	/// en: 'Search'
	String get search => 'Search';

	/// en: 'Settings'
	String get settings => 'Settings';
}

// Path: window
class Translations$window$en {
	Translations$window$en._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Minimize'
	String get minimize => 'Minimize';

	/// en: 'Maximize'
	String get maximize => 'Maximize';

	/// en: 'Restore'
	String get restore => 'Restore';

	/// en: 'Close'
	String get close => 'Close';
}

// Path: closePrompt
class Translations$closePrompt$en {
	Translations$closePrompt$en._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'What should closing the window do?'
	String get title => 'What should closing the window do?';

	/// en: 'Hide to tray, keep playback'
	String get toTray => 'Hide to tray, keep playback';

	/// en: 'Quit Pure Live'
	String get quit => 'Quit Pure Live';

	/// en: 'Remember my choice, stop asking'
	String get remember => 'Remember my choice, stop asking';
}

// Path: shellSettings
class Translations$shellSettings$en {
	Translations$shellSettings$en._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Window'
	String get sectionWindow => 'Window';

	/// en: 'Window title bar'
	String get titleBar => 'Window title bar';

	/// en: 'App title bar'
	String get titleBarApp => 'App title bar';

	/// en: 'System title bar'
	String get titleBarSystem => 'System title bar';

	/// en: 'The app title bar is drawn by Pure Live; the system title bar uses the native Windows style. A switch applies after the app restarts.'
	String get titleBarHint => 'The app title bar is drawn by Pure Live; the system title bar uses the native Windows style. A switch applies after the app restarts.';
}

/// The flat map containing all translations for locale <en>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on Translations {
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
			'common.pageOf' => 'Page {page: int} of {total: int}',
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
			'room.danmakuFailed' => 'Danmaku connection failed',
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
			'iptv.imported' => 'Imported {count: int} channels',
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
			'follow.unfollowConfirm' => 'Unfollow "{name: String}"?',
			'follow.newGroup' => 'New group',
			'follow.groupName' => 'Group name',
			'toolbox.title' => 'Toolbox',
			'toolbox.hint' => 'Paste a room link',
			'toolbox.readClipboard' => 'Read clipboard',
			'toolbox.resolve' => 'Resolve',
			'toolbox.failed' => 'No platform recognised this link',
			'toolbox.openRoom' => 'Open the room',
			'backup.title' => 'Backup & restore',
			'backup.create' => 'Create backup',
			'backup.restoreFile' => 'Restore from file',
			'backup.existing' => 'Existing backups',
			'backup.none' => 'No backups yet',
			'backup.delete' => 'Delete backup',
			'backup.restore' => 'Restore',
			'backup.restoreConfirm' => 'Overwrite current data with “{name: String}”? The app restarts.',
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
			'multiview.title' => 'Multi-view',
			'multiview.platform' => 'Platform',
			'multiview.roomId' => 'Room ID',
			'multiview.add' => 'Add cell',
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
