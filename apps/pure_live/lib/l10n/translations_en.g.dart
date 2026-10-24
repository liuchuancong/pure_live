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
	@override late final _Translations$account$en account = _Translations$account$en._(_root);
	@override late final _Translations$areas$en areas = _Translations$areas$en._(_root);
	@override late final _Translations$backup$en backup = _Translations$backup$en._(_root);
	@override late final _Translations$common$en common = _Translations$common$en._(_root);
	@override late final _Translations$favorites$en favorites = _Translations$favorites$en._(_root);
	@override late final _Translations$history$en history = _Translations$history$en._(_root);
	@override late final _Translations$iptv$en iptv = _Translations$iptv$en._(_root);
	@override late final _Translations$multiview$en multiview = _Translations$multiview$en._(_root);
	@override late final _Translations$music$en music = _Translations$music$en._(_root);
	@override late final _Translations$navigation$en navigation = _Translations$navigation$en._(_root);
	@override late final _Translations$player$en player = _Translations$player$en._(_root);
	@override late final _Translations$popular$en popular = _Translations$popular$en._(_root);
	@override late final _Translations$recorder$en recorder = _Translations$recorder$en._(_root);
	@override late final _Translations$room$en room = _Translations$room$en._(_root);
	@override late final _Translations$search$en search = _Translations$search$en._(_root);
	@override late final _Translations$settings$en settings = _Translations$settings$en._(_root);
	@override late final _Translations$shield$en shield = _Translations$shield$en._(_root);
	@override late final _Translations$sites$en sites = _Translations$sites$en._(_root);
	@override late final _Translations$toolbox$en toolbox = _Translations$toolbox$en._(_root);
	@override late final _Translations$vod$en vod = _Translations$vod$en._(_root);
}

// Path: account
class _Translations$account$en extends Translations$account$zh_CN {
	_Translations$account$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get title => 'Accounts';
	@override String get description => 'The platforms\' sign-in state; credentials live only in this device\'s secure storage.';
	@override String get sectionHeader => 'Sign-in state';
	@override String get empty => 'No platform supports signing in yet';
	@override String get notSignedIn => 'Not signed in';
	@override String signedInAs({required Object name}) => 'Signed in as ${name}';
	@override String get qrLogin => 'Scan QR code';
	@override String get cookieLogin => 'Import cookie';
	@override String get signOut => 'Sign out';
	@override String qrDialogTitle({required Object site}) => 'Sign in to ${site} with a QR code';
	@override String qrHint({required Object site}) => 'Open the ${site} mobile app, scan the code and confirm the sign-in.';
	@override String get qrExpired => 'The QR code expired';
	@override String get qrRetry => 'Fetch a new code';
	@override String get qrPollingFailed => 'Connection failed, retrying…';
	@override String cookieDialogTitle({required Object site}) => 'Import the ${site} cookie';
	@override String get cookieDialogHint => 'Copy the site\'s cookie from a signed-in browser and paste it below (name=value; name2=value2).';
	@override String get cookieFieldHint => 'Paste the cookie here';
	@override String get loginSuccess => 'Signed in';
	@override String loginFailed({required Object message}) => 'Sign-in failed: ${message}';
	@override String signOutConfirmDesc({required Object site}) => 'The stored ${site} credential leaves this device.';
	@override String get signOutSuccess => 'Signed out';
}

// Path: areas
class _Translations$areas$en extends Translations$areas$zh_CN {
	_Translations$areas$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get allAreas => 'All areas';
	@override String get noAreas => 'This platform has no areas';
	@override String get viewPlatform => 'Platform areas';
	@override String get viewFollowed => 'Followed areas';
	@override String get followedEmpty => 'No followed areas yet';
	@override String get followedEmptyHint => 'Tap the heart on an area or in a room to follow it';
	@override String get noPlatforms => 'No platform to browse';
	@override String get unfollow => 'Unfollow';
}

// Path: backup
class _Translations$backup$en extends Translations$backup$zh_CN {
	_Translations$backup$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get title => 'Backup & restore';
	@override String get localSection => 'Local backup';
	@override String get summaryTitle => 'Current data';
	@override String get summaryEmpty => 'Nothing to back up yet';
	@override String get exportTitle => 'Export backup';
	@override String get exportDescription => 'Bundle follows, watch history, followed areas and settings into one JSON file and save it through the system share sheet.';
	@override String get exportEmpty => 'Nothing to back up yet';
	@override String get exportDone => 'Backup file created';
	@override String get exportFailed => 'Export failed';
	@override String get importTitle => 'Import backup';
	@override String get importDescription => 'Paste the backup JSON and confirm to overwrite the current data; WebDAV can download and restore too.';
	@override String get importHint => 'Paste the backup JSON';
	@override String get importFileNote => 'Picking a local file arrives with the file picker dependency; paste the content or use WebDAV for now.';
	@override String get importConfirmTitle => 'Overwrite the current data?';
	@override String get importConfirmDesc => 'Importing clears and rewrites follows, watch history, followed areas and settings. The current data cannot be recovered.';
	@override String get importDone => 'Restored; restart the app to apply everything';
	@override String get importBadData => 'This is not a valid backup';
	@override String get importFailed => 'Import failed';
	@override String summary({required Object follows, required Object history, required Object areas, required Object settings}) => 'Follows ${follows} · History ${history} · Areas ${areas} · Settings ${settings}';
	@override String get webdavSection => 'WebDAV sync';
	@override String webdavDescription({required Object file}) => 'The backup lives on the server as ${file}: upload overwrites it, download restores it.';
	@override String get webdavConfigTitle => 'Server';
	@override String get webdavConfigDescription => 'Fill in the WebDAV server address and account; the password is kept in the system\'s secure storage and never enters a backup.';
	@override String get webdavUrl => 'Server URL';
	@override String get webdavUrlHint => 'https://dav.jianguoyun.com/dav/';
	@override String get webdavUser => 'Username';
	@override String get webdavUserHint => 'Account, may be empty';
	@override String get webdavPassword => 'Password';
	@override String get webdavPasswordHint => 'Leave empty to keep the stored one';
	@override String get webdavPasswordKeep => 'Saved in secure storage';
	@override String get webdavPasswordEmpty => 'Not set';
	@override String get webdavUrlMissing => 'Fill in the server URL first';
	@override String get webdavSaved => 'WebDAV settings saved';
	@override String get webdavTest => 'Test connection';
	@override String get webdavTestOk => 'Connected';
	@override String get webdavUpload => 'Upload backup';
	@override String webdavUploadDone({required Object file}) => 'Uploaded ${file}';
	@override String get webdavDownload => 'Download and restore';
	@override String get webdavDownloadConfirmTitle => 'Download and overwrite the current data?';
	@override String webdavDownloadConfirmDesc({required Object file}) => 'The server\'s ${file} will overwrite this device\'s follows, history, areas and settings.';
	@override String get webdavAuthFailed => 'Authentication failed; check the username or password';
	@override String get webdavNotFound => 'No backup file on the server yet';
	@override String get webdavNetworkFailed => 'Network error; check the URL or the proxy';
	@override String webdavServerFailed({required Object status}) => 'The server answered with an error (${status})';
	@override String get webdavFailed => 'The operation failed';
	@override String get busy => 'Another operation is running';
	@override String get folderPickTitle => 'Choose backup folder';
	@override String get folderTitle => 'Backup folder';
	@override String get folderDefault => 'Default folder';
	@override String get folderLoading => 'Loading…';
	@override String get folderReset => 'Reset to default folder';
	@override String get folderOpen => 'Open backup folder';
	@override String get folderUnwritable => 'The backup folder is not writable; pick another';
	@override String get folderSaveFailed => 'Could not save the backup folder';
	@override String get openFolderFailed => 'Could not open the backup folder';
	@override String get createTitle => 'Create backup';
	@override String get createDescription => 'Bundles follows, watch history, followed areas and settings into a file in the backup folder.';
	@override String get createFollowsTitle => 'Create follows-only backup';
	@override String get createFollowsDescription => 'Backs up followed rooms and areas only.';
	@override String createDone({required String name}) => 'Created ${name}';
	@override String get createFailed => 'Could not create the backup';
	@override String get filesSection => 'Backup files';
	@override String filesCount({required int count}) => '${count} backup files';
	@override String get filesEmpty => 'No backup files in this folder yet';
	@override String get filesFailed => 'Could not read the backup folder';
	@override String get filesFailedHint => 'Check that the folder exists and is readable, then tap to retry.';
	@override String fileMeta({required String time, required String size, required String kind}) => '${time} · ${size} · ${kind}';
	@override String get kindFull => 'Full backup';
	@override String get kindFollows => 'Follows only';
	@override String get fileDelete => 'Delete backup file';
	@override String get restoreConfirmTitle => 'Restore this backup?';
	@override String restoreConfirmDesc({required String name}) => 'Restoring ${name} overwrites this device\'s follows, watch history, followed areas and settings. The current data cannot be recovered.';
	@override String restoreFollowsConfirmDesc({required String name}) => 'Restoring ${name} overwrites this device\'s follows and followed areas; other data stays as it is.';
	@override String get restoreFailed => 'Restore failed';
	@override String get deleteConfirmTitle => 'Delete this backup file?';
	@override String deleteConfirmDesc({required String name}) => '${name} will be permanently deleted.';
	@override String get deleteDone => 'Backup file deleted';
	@override String get deleteFileFailed => 'Could not delete the backup file';
	@override String summaryFollows({required int follows, required int areas}) => 'Follows ${follows} · Areas ${areas}';
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
	@override String get moduleVod => 'Bilibili';
	@override String get moduleMusic => 'Music';
	@override String get retry => 'Retry';
	@override String get moduleComingSoon => 'This module is on its way';
	@override String get back => 'Back';
	@override String get forward => 'Forward';
	@override String get searchHint => 'Search rooms, streamers or sites';
	@override String get switchModule => 'Switch content type';
	@override String get openNavigation => 'Open navigation';
	@override String get refreshFailed => 'Refresh failed';
}

// Path: favorites
class _Translations$favorites$en extends Translations$favorites$zh_CN {
	_Translations$favorites$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get emptyTitle => 'No followed rooms yet';
	@override String get emptyDescription => 'Follow a room and it shows up here.';
	@override String get unfollow => 'Unfollow';
	@override String get statusAll => 'All';
	@override String get statusLive => 'Live';
	@override String get statusOffline => 'Offline';
	@override String get refresh => 'Refresh';
	@override String get openFailedTitle => 'The follow list could not open';
	@override String get statusReplay => 'Recording';
	@override String get searchLive => 'Search Live';
	@override String get emptyLiveTitle => 'No followed rooms are live in this filter';
	@override String get emptyReplayTitle => 'No recordings in this filter';
	@override String get emptyOfflineTitle => 'No offline rooms in this filter';
	@override String get emptyOfflineHint => 'Some follows are offline; switch to Offline to see them.';
	@override String get emptyGroupHint => 'Try another group or platform, or refresh to fetch their status.';
	@override String get showOffline => 'View offline';
	@override String refreshFailed({required int count}) => '${count} rooms could not be refreshed';
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
	@override String get today => 'Today';
	@override String get yesterday => 'Yesterday';
	@override String get earlier => 'Earlier';
	@override String get openFailedTitle => 'The history could not open';
	@override String recordCount({required int count, required int limit}) => 'Recorded ${count} / limit ${limit}';
	@override String get filter => 'Filter';
	@override String get filterClose => 'Close filter';
	@override String get filterHint => 'Filter by title, streamer, room ID or platform';
	@override String filterMatches({required int count}) => '${count} found';
	@override String get filterReset => 'Clear filter';
	@override String get filterEmptyTitle => 'No history entries match';
	@override String get filterEmptyDescription => 'Try another keyword, or clear the filter.';
	@override String get deleteConfirmTitle => 'Delete watch record?';
	@override String deleteConfirmDesc({required String title}) => 'Remove “${title}” from watch history? This only removes this saved entry.';
	@override String get deleteAction => 'Delete';
	@override String get deleteDone => 'Removed from history';
	@override String get clearConfirmTitle => 'Clear watch history?';
	@override String clearConfirmDesc({required int count}) => 'Clear all ${count} history entries? This action cannot be undone.';
	@override String clearFilteredConfirmDesc({required int count}) => 'Remove the ${count} entries that match the filter? Other entries stay. This cannot be undone.';
	@override String clearDone({required int count}) => 'Cleared ${count} history entries';
	@override String get changeFailed => 'The history changes were not saved. Try again.';
	@override String get limitAction => 'Change limit';
	@override String get limitTitle => 'Watch History Retention';
	@override String get limitDescription => 'The oldest records are dropped past the limit.';
	@override String get limitPresetsLabel => 'Preset Limits';
	@override String get limitCustomLabel => 'Custom Limit';
	@override String limitInvalid({required int min, required int max}) => 'Enter a whole number from ${min} to ${max}.';
	@override String limitSaved({required int limit}) => 'History limit set to ${limit}';
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
	@override String get epgSourceTitle => 'Guide sources';
	@override String get epgSourceHint => 'An XMLTV or JSON guide URL';
	@override String get epgImport => 'Import';
	@override String get epgImported => 'Guide imported';
	@override String get epgFailed => 'The guide failed to import';
	@override String get epgRemove => 'Remove this guide source';
	@override String get epgEmpty => 'No guide sources yet; import one and the channel cards show what is on.';
	@override String get activeGuideDescription => 'The guide source used for the channel list; one at a time.';
	@override String get activeGuideNone => 'None selected';
	@override String get activeGuideTitle => 'Active guide';
	@override String get autoUpdate => 'Auto update';
	@override String get autoUpdateHint => 'Re-fetches the source at an interval when on.';
	@override String channelCount({required int count}) => '${count} channels';
	@override String get chooseGuide => 'Choose guide source';
	@override String get delete => 'Delete';
	@override String get deleteActiveGuideNote => 'This guide is in use; another source takes over after deletion.';
	@override String deleteGuideMessage({required String name}) => 'Delete the guide “${name}”? Its downloaded guide data is removed too.';
	@override String get deleteGuideTitle => 'Delete guide source?';
	@override String deletePlaylistMessage({required String name, required int count}) => 'Delete “${name}” and its ${count} channels?';
	@override String get deletePlaylistTitle => 'Delete playlist?';
	@override String deleted({required String name}) => 'Deleted “${name}”';
	@override String get guideName => 'Guide name';
	@override String get guideNameHint => 'e.g. My EPG';
	@override String guideSelected({required String name}) => 'Switched to “${name}”';
	@override String get importAction => 'Import';
	@override String get importAddressInvalid => 'Enter a valid subscription address';
	@override String get importAddressRequired => 'Enter the subscription address first';
	@override String get importFailed => 'Import failed';
	@override String get importFormat => 'Unsupported file format';
	@override String get importFromFile => 'From file';
	@override String get importFromText => 'Paste text';
	@override String get importFromUrl => 'From URL';
	@override String get importGuide => 'Import guide';
	@override String get importGuideDescription => 'XMLTV URLs or files; the guide is downloaded after import.';
	@override String get importInvalid => 'The content is not a valid playlist';
	@override String get importNameRequired => 'Enter a playlist name';
	@override String get importNetworkFailed => 'The network request failed; check the address or proxy';
	@override String get importPlaylist => 'Import playlist';
	@override String get importPlaylistDescription => 'M3U/M3U8/TXT from a URL, a file or pasted text.';
	@override String importSkipped({required String name, required int count}) => 'Imported “${name}”, skipped ${count}';
	@override String get importTextRequired => 'Paste the playlist content first';
	@override String imported({required String name}) => 'Imported “${name}”';
	@override String importedAt({required String time}) => 'Imported ${time}';
	@override String get inUse => 'In use';
	@override String lastRefresh({required String time}) => 'Updated ${time}';
	@override String get localTag => 'Local';
	@override String get networkTag => 'Network';
	@override String get neverUpdated => 'Never updated';
	@override String get noGuidesTitle => 'No guide sources yet';
	@override String get noPlaylistsDescription => 'Import a playlist from a URL, a file or pasted text.';
	@override String get noPlaylistsTitle => 'No playlists yet';
	@override String get pickPlaylistFile => 'Choose a playlist file';
	@override String get playlistName => 'Playlist name';
	@override String get playlistNameHint => 'e.g. My channels';
	@override String get playlistText => 'Playlist content';
	@override String get playlistTextHint => 'Paste M3U/M3U8/TXT content';
	@override String get playlistUrl => 'Subscription URL';
	@override String get playlistUrlHint => 'https://example.com/playlist.m3u';
	@override String get playlistsTitle => 'Playlists';
	@override String get replaceMessage => 'A playlist with this name exists; the imported content replaces it.';
	@override String replaceTitle({required String name}) => 'Replace “${name}”?';
	@override String get sourceChanged => 'The source changed; the cache was updated';
	@override String get statChannels => 'Channels';
	@override String get statGuides => 'Guides';
	@override String get statPlaylists => 'Playlists';
	@override String get sync => 'Sync';
	@override String get syncAll => 'Sync all';
	@override String syncAllDone({required int count}) => 'Synced ${count} playlists';
	@override String get syncAllNone => 'No playlists to sync';
	@override String syncAllPartial({required int failed, required int count}) => '${failed} of ${count} playlists failed';
	@override String syncAllRunning({required int done, required int total}) => 'Syncing ${done} / ${total}';
	@override String syncFailed({required String name}) => 'Could not sync “${name}”';
	@override String synced({required String name}) => 'Synced “${name}”';
	@override String get viewChannels => 'Channels';
	@override String get viewLabel => 'View';
	@override String get viewSources => 'Playlists';
}

// Path: multiview
class _Translations$multiview$en extends Translations$multiview$zh_CN {
	_Translations$multiview$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get layoutLabel => 'Layout';
	@override String get videoComingSoon => 'Multi-view playback arrives with the player stack; arrange the panes and pick rooms meanwhile.';
	@override String get pickRoom => 'Pick a room';
	@override String get clearPane => 'Clear this pane';
	@override String get swapPane => 'Swap panes';
	@override String get swapHere => 'Move here';
	@override String pickerTitle({required Object index}) => 'Pick a room for pane ${index}';
	@override String get pickerEmptyTitle => 'No followed rooms yet';
	@override String get pickerEmptyHint => 'Follow a room from its live page first; followed rooms show up in this list.';
	@override String alreadyShown({required Object index}) => 'Already on pane ${index}';
	@override String shownIn({required Object index}) => 'Pane ${index}';
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

// Path: popular
class _Translations$popular$en extends Translations$popular$zh_CN {
	_Translations$popular$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get allPlatforms => 'All platforms';
	@override String page({required int page, required int total}) => 'Page ${page} of ${total}';
	@override String get prevPage => 'Previous page';
	@override String get nextPage => 'Next page';
	@override String inlineAt({required Object query, required Object platform}) => 'Searching “${query}” on ${platform}';
	@override String get backToBrowse => 'Back to browsing';
}

// Path: recorder
class _Translations$recorder$en extends Translations$recorder$zh_CN {
	_Translations$recorder$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get tabRunning => 'Recording';
	@override String get tabFinished => 'Finished';
	@override String get clearFinished => 'Clear finished';
	@override String get removeTask => 'Remove this task';
	@override String get emptyTitle => 'No recording tasks yet';
	@override String get emptyFinishedTitle => 'Finished recordings will show up here';
	@override String get emptyDescription => 'Recording arrives with the player stack: once it is in, start a recording from a live room and its task will show up here.';
	@override String get qualityBest => 'Best quality';
	@override String startedAt({required Object time}) => 'Started at ${time}';
	@override String get stateRecording => 'Recording';
	@override String get stateStopped => 'Stopped';
	@override String get stateFailed => 'Failed';
	@override String get settingsTitle => 'Recording';
	@override String get saveDirTitle => 'Save directory';
	@override String get saveDirDefault => 'Follow the engine\'s default directory';
	@override String get saveDirDialogHint => 'Enter the folder recordings are saved to';
	@override String get namingTitle => 'File naming template';
	@override String get namingDescription => 'Placeholders for date, time, platform, room id and title; takes effect with the player stack.';
	@override String get namingDialogHint => 'Enter the naming template for recording files';
	@override String get maxSizeTitle => 'Single-file size cap';
	@override String get maxSizeDescription => 'Recordings split once a file reaches the cap; takes effect with the player stack.';
	@override String get filterLabel => 'Filter';
	@override String get filterAll => 'All';
	@override String get filterRecording => 'Recording';
	@override String get filterWaiting => 'Waiting';
	@override String get filterSaved => 'Saved';
	@override String get filterFailed => 'Failed';
	@override String emptyFilterTitle({required String status}) => 'No tasks in “${status}” yet';
	@override String get stateWaiting => 'Waiting for live';
	@override String get stateSaved => 'Saved';
	@override String get menuMore => 'More actions';
	@override String get openRoom => 'Open live room';
	@override String get openFolder => 'Open folder';
	@override String get openFolderFailed => 'Could not open the folder';
	@override String get delete => 'Delete';
	@override String deleteTitle({required String name}) => 'Delete “${name}”?';
	@override String get deleteBody => 'This removes the task only; files already saved stay on disk.';
	@override String get settingsOpen => 'Recording settings';
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
	@override String get sendHint => 'Say something';
	@override String get send => 'Send';
	@override String get sendFailed => 'The message failed to send';
	@override String get fullscreenOn => 'Enter fullscreen';
	@override String get fullscreenOff => 'Leave fullscreen';
}

// Path: search
class _Translations$search$en extends Translations$search$zh_CN {
	_Translations$search$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get idleTitle => 'Search';
	@override String get idleDescription => 'Type to search rooms, streamers or areas.';
	@override String get suggestionsTitle => 'Suggestions';
	@override String get targetsLabel => 'Search targets';
	@override String get tabRooms => 'Rooms';
	@override String get tabAnchors => 'Streamers';
	@override String get tabAreas => 'Areas';
	@override String get noResultsTitle => 'No results';
	@override String get noResultsDescription => 'Try other words, or another target.';
	@override String get unsupportedTitle => 'This platform cannot search';
	@override String get unsupportedDescription => 'Switch to another platform and try again.';
	@override String get liveBadge => 'Live';
	@override String get scopeAll => 'All';
	@override String get historyTitle => 'Search history';
	@override String get clearHistory => 'Clear';
}

// Path: settings
class _Translations$settings$en extends Translations$settings$zh_CN {
	_Translations$settings$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get title => 'Settings';
	@override String get navGeneral => 'General';
	@override String get navAppearance => 'Appearance';
	@override String get navPlayback => 'Playback';
	@override String get navSites => 'Sites';
	@override String get navData => 'Data';
	@override String get navAbout => 'About';
	@override String get groupBasics => 'Basics';
	@override String get groupContent => 'Sites';
	@override String get groupData => 'Data';
	@override String get groupAbout => 'About';
	@override String get generalDescription => 'Default site, card width and page size.';
	@override String get appearanceDescription => 'Theme mode: follow the system, light or dark.';
	@override String get playbackDescription => 'Quality, aspect ratio and player behaviour.';
	@override String get sitesDescription => 'Browsing sites and signed-in accounts.';
	@override String get dataDescription => 'Follows, history and local storage.';
	@override String get aboutDescription => 'Version, licences and project links.';
	@override String get playbackComingSoon => 'Playback settings arrive with the player.';
	@override String get sitesComingSoon => 'Site management and accounts are on the way.';
	@override String get dataComingSoon => 'Data management is on the way.';
	@override String get aboutComingSoon => 'The about page is on the way.';
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
	@override String get cardExtentDescription => 'How wide one feed card gets; smaller means more per row.';
	@override String get pageSize => 'Page size';
	@override String get pageSizeDescription => 'How many rooms one page asks the site for.';
	@override String get sitesDisplay => 'Platforms shown';
	@override String get sitesDisplayDesc => 'Switched-off platforms leave the popular and areas tab lists.';
	@override String get sitesAllShown => 'Every platform is shown.';
	@override String get dataClearHistory => 'Clear watch history';
	@override String get dataClearHistoryDesc => 'Deletes every watch record, for good.';
	@override String get dataExportFollows => 'Export follows';
	@override String get dataExportFollowsDesc => 'Copies the follow list to the clipboard (JSON).';
	@override String get dataImportFollows => 'Import follows';
	@override String get dataImportFollowsDesc => 'Reads previously exported follows from the clipboard (JSON).';
	@override String get dataDone => 'Done';
	@override String get dataBadData => 'The clipboard could not be read as follows';
	@override String get dataEmpty => 'Nothing to export yet';
	@override String get confirmClearTitle => 'Clear watch history?';
	@override String get confirmClearDesc => 'Every watch record will be deleted, for good.';
	@override String get confirm => 'Clear';
	@override String get aboutVersion => 'Version';
	@override String get aboutProject => 'Project home';
	@override String get aboutLicense => 'Licences';
	@override String get aboutLicenseDesc => 'The open-source packages this app builds on.';
	@override String get themeSeed => 'Accent colour';
	@override String get themeSeedSystem => 'Follow the system accent';
	@override String get seedBlue => 'Blue';
	@override String get seedNavy => 'Navy';
	@override String get seedGraphite => 'Graphite';
	@override String get seedOxblood => 'Oxblood';
	@override String get seedForest => 'Forest';
	@override String get seedIndigo => 'Indigo';
	@override String get corners => 'Corners';
	@override String get cornersStandard => 'Standard';
	@override String get cornersSharp => 'Sharp';
	@override String get cornersSoft => 'Soft';
	@override String get cornersPill => 'Pill';
	@override String get density => 'Control density';
	@override String get densitySystem => 'Follow the platform';
	@override String get densityCompact => 'Compact';
	@override String get densityTouch => 'Touch';
	@override String get languageSystem => 'Follow the system';
	@override String get refreshGroup => 'Refresh';
	@override String get followsAutoRefresh => 'Refresh follows automatically';
	@override String get followsAutoRefreshDesc => 'Refreshes the follow list on an interval while the page is open.';
	@override String get refreshInterval => 'Interval';
	@override String get historyLimit => 'History limit';
	@override String get historyLimitDesc => 'The oldest records past the limit are dropped.';
	@override String get navNetwork => 'Network';
	@override String get networkDescription => 'The app proxy and transport behaviour.';
	@override String get proxy => 'App proxy';
	@override String get proxyDesc => 'When on, the vod, guide and backup requests all route through it.';
	@override String get proxyHost => 'Host';
	@override String get proxyPort => 'Port';
	@override String get toolsOrder => 'Tools order';
	@override String get toolsOrderDesc => 'The order of the tools under the sidebar\'s divider.';
	@override String get moveUp => 'Move up';
	@override String get moveDown => 'Move down';
	@override String get navShield => 'Danmaku shield';
	@override String get shieldDescription => 'Blocked keywords and users; the live room filters by them.';
	@override String get danmakuStyleGroup => 'Danmaku style';
	@override String get styleFontSize => 'Type size';
	@override String get styleSpeed => 'Speed';
	@override String get styleArea => 'Display area';
	@override String get styleOpacity => 'Opacity';
	@override String get styleStroke => 'Outline';
	@override String get styleReset => 'Reset to defaults';
	@override String get windowGroup => 'Window';
	@override String get closeAction => 'On window close';
	@override String get closeQuit => 'Quit the app';
	@override String get closeMinimise => 'Minimise to the taskbar';
	@override String get closeTrayUnavailable => 'Hide to tray (needs the tray, not wired yet)';
	@override String get font => 'Font';
	@override String get fontDescription => 'UI typeface: the platform\'s own face, or one of the bundled official ones.';
	@override String get fontPlatform => 'Follow the platform (system font)';
	@override String get backHome => 'Back to app';
	@override String get pureBlack => 'True black (OLED)';
	@override String get pureBlackDesc => 'Collapses dark backgrounds to true black for OLED screens.';
	@override String get navCache => 'Cache';
	@override String get cacheDescription => 'The disk cache for covers and avatars, and its cleanup cap.';
	@override String get cacheSize => 'Current cache size';
	@override String get cacheRefresh => 'Refresh';
	@override String get cacheClear => 'Clear cache';
	@override String get cacheClearDesc => 'Deletes every cached cover, avatar and site icon.';
	@override String get cacheCleared => 'Cache cleared';
	@override String get cacheLimit => 'Automatic cleanup cap';
	@override String get cacheLimitDesc => 'Oldest images are deleted past the cap; off keeps only expiry-based cleanup.';
	@override String get cacheLimitOff => 'No automatic cleanup';
	@override String get cacheHint => 'Covers and avatars are kept on this device for 30 days and pruned when they expire or pass the cap.';
	@override String get preferPlatform => 'Preferred platform';
	@override String get preferPlatformDesc => 'The platform the popular and areas pages open with.';
	@override String get sitesOrderReset => 'Restore default order';
	@override String get sitesOrderResetDesc => 'Platforms return to the built-in order; the show switches stay as they are.';
	@override String get windowChrome => 'Window title bar';
	@override String get windowChromeDesc => 'Use the system caption, or the app\'s own strip; a restart applies the change.';
	@override String get windowChromeSystem => 'System title bar';
	@override String get windowChromeCustom => 'Custom title bar';
	@override String get windowChromeRestartTitle => 'Restart to apply the title bar?';
	@override String get windowChromeRestartDesc => 'The caption style is chosen when the window is created; it applies after a restart.';
	@override String get windowChromeRestartNow => 'Restart now';
}

// Path: shield
class _Translations$shield$en extends Translations$shield$zh_CN {
	_Translations$shield$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get title => 'Danmaku shield';
	@override String get description => 'Keep live-room danmaku out by keyword or user; the rules live on this device.';
	@override String get masterTitle => 'Master switch';
	@override String get enabled => 'Enable the danmaku shield';
	@override String get enabledDescription => 'When off, every rule stands down for the moment';
	@override String get keywordsTitle => 'Keywords';
	@override String get usersTitle => 'Users';
	@override String get keywordFieldHint => 'Type a keyword to block';
	@override String get userFieldHint => 'Type a user name to block';
	@override String get add => 'Add';
	@override String get keywordsEmpty => 'No blocked keywords yet';
	@override String get usersEmpty => 'No blocked users yet';
	@override String get clear => 'Clear all';
	@override String get clearConfirmDesc => 'The list empties; add entries again whenever you need them.';
	@override String get duplicateEntry => 'This entry is already on the list';
	@override String get invalidEntry => 'The entry cannot be empty';
	@override String get added => 'Blocked';
	@override String get removed => 'Removed';
	@override String get cleared => 'Cleared';
	@override String get removeEntry => 'Remove this rule';
	@override String get effectNote => 'The rules apply in the live room\'s danmaku pipeline, which arrives with the player stack.';
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

// Path: toolbox
class _Translations$toolbox$en extends Translations$toolbox$zh_CN {
	_Translations$toolbox$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get title => 'Toolbox';
	@override String get groupLinks => 'Links';
	@override String get groupNetwork => 'Network';
	@override String get groupData => 'Data';
	@override String get toolLinkTitle => 'Link resolver';
	@override String get toolLinkDescription => 'Paste a platform link to open the room or copy its address.';
	@override String get toolNetworkTitle => 'Network check';
	@override String get toolNetworkDescription => 'Check whether a site\'s endpoint is reachable and how fast it answers.';
	@override String get toolCacheTitle => 'Cache cleanup';
	@override String get toolCacheDescription => 'Inspect and clear the memory the image cache holds.';
	@override String get toolLogsTitle => 'Log viewer';
	@override String get toolLogsDescription => 'Browse the app\'s runtime logs to debug playback and network issues.';
	@override String get back => 'Back';
	@override String get confirm => 'Confirm';
	@override String get cancel => 'Cancel';
	@override String get linkFieldLabel => 'Platform link';
	@override String get linkFieldHint => 'Paste a room link or shared text';
	@override String get linkOpen => 'Open room';
	@override String get linkCopy => 'Copy room link';
	@override String get linkPaste => 'Paste';
	@override String get linkClear => 'Clear';
	@override String get linkResolving => 'Resolving the link…';
	@override String get linkResolvedTitle => 'Resolved';
	@override String get linkPlatform => 'Platform';
	@override String get linkRoom => 'Room';
	@override String get linkEmpty => 'Paste a link first';
	@override String get linkUnsupported => 'This link is not recognised; the platform is not supported yet.';
	@override String get linkTimeout => 'The resolve timed out; check the network and try again.';
	@override String get linkFailed => 'The resolve failed; try again later.';
	@override String get linkCopyDone => 'Room link copied';
	@override String get linkCopyFailed => 'Copy failed';
	@override String get linkSupportTitle => 'Supported platforms';
	@override String get linkSupportHint => 'Room links of these platforms resolve and open directly.';
	@override String get networkSiteLabel => 'Choose a platform';
	@override String get networkRun => 'Run the check';
	@override String get networkResultTitle => 'Result';
	@override String get networkTarget => 'Probed endpoint';
	@override String get networkTargetDesc => 'The recommended-rooms endpoint';
	@override String get networkLatency => 'Response time';
	@override String get networkRooms => 'Rooms returned';
	@override String get networkSuccess => 'Reachable';
	@override String get networkFailure => 'Unreachable';
	@override String get networkBusy => 'Checking…';
	@override String get networkUnsupported => 'This platform cannot be probed yet.';
	@override String get cacheSection => 'Image cache';
	@override String get cacheEntries => 'Cached images';
	@override String get cacheSize => 'Memory held';
	@override String get cacheClear => 'Clear the cache';
	@override String get cacheClearDesc => 'Release the memory the image cache holds; favorites and history are untouched.';
	@override String get cacheConfirmTitle => 'Clear the image cache?';
	@override String get cacheConfirmDesc => 'Loaded images download again; favorites and history are untouched.';
	@override String get cacheDone => 'Cache cleared';
	@override String get cacheEmpty => 'Nothing cached';
	@override String get comingSoonTitle => 'Coming soon';
	@override String get comingSoonDesc => 'This tool is not finished yet; stay tuned.';
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
			'account.title' => 'Accounts',
			'account.description' => 'The platforms\' sign-in state; credentials live only in this device\'s secure storage.',
			'account.sectionHeader' => 'Sign-in state',
			'account.empty' => 'No platform supports signing in yet',
			'account.notSignedIn' => 'Not signed in',
			'account.signedInAs' => ({required Object name}) => 'Signed in as ${name}',
			'account.qrLogin' => 'Scan QR code',
			'account.cookieLogin' => 'Import cookie',
			'account.signOut' => 'Sign out',
			'account.qrDialogTitle' => ({required Object site}) => 'Sign in to ${site} with a QR code',
			'account.qrHint' => ({required Object site}) => 'Open the ${site} mobile app, scan the code and confirm the sign-in.',
			'account.qrExpired' => 'The QR code expired',
			'account.qrRetry' => 'Fetch a new code',
			'account.qrPollingFailed' => 'Connection failed, retrying…',
			'account.cookieDialogTitle' => ({required Object site}) => 'Import the ${site} cookie',
			'account.cookieDialogHint' => 'Copy the site\'s cookie from a signed-in browser and paste it below (name=value; name2=value2).',
			'account.cookieFieldHint' => 'Paste the cookie here',
			'account.loginSuccess' => 'Signed in',
			'account.loginFailed' => ({required Object message}) => 'Sign-in failed: ${message}',
			'account.signOutConfirmDesc' => ({required Object site}) => 'The stored ${site} credential leaves this device.',
			'account.signOutSuccess' => 'Signed out',
			'areas.allAreas' => 'All areas',
			'areas.noAreas' => 'This platform has no areas',
			'areas.viewPlatform' => 'Platform areas',
			'areas.viewFollowed' => 'Followed areas',
			'areas.followedEmpty' => 'No followed areas yet',
			'areas.followedEmptyHint' => 'Tap the heart on an area or in a room to follow it',
			'areas.noPlatforms' => 'No platform to browse',
			'areas.unfollow' => 'Unfollow',
			'backup.title' => 'Backup & restore',
			'backup.localSection' => 'Local backup',
			'backup.summaryTitle' => 'Current data',
			'backup.summaryEmpty' => 'Nothing to back up yet',
			'backup.exportTitle' => 'Export backup',
			'backup.exportDescription' => 'Bundle follows, watch history, followed areas and settings into one JSON file and save it through the system share sheet.',
			'backup.exportEmpty' => 'Nothing to back up yet',
			'backup.exportDone' => 'Backup file created',
			'backup.exportFailed' => 'Export failed',
			'backup.importTitle' => 'Import backup',
			'backup.importDescription' => 'Paste the backup JSON and confirm to overwrite the current data; WebDAV can download and restore too.',
			'backup.importHint' => 'Paste the backup JSON',
			'backup.importFileNote' => 'Picking a local file arrives with the file picker dependency; paste the content or use WebDAV for now.',
			'backup.importConfirmTitle' => 'Overwrite the current data?',
			'backup.importConfirmDesc' => 'Importing clears and rewrites follows, watch history, followed areas and settings. The current data cannot be recovered.',
			'backup.importDone' => 'Restored; restart the app to apply everything',
			'backup.importBadData' => 'This is not a valid backup',
			'backup.importFailed' => 'Import failed',
			'backup.summary' => ({required Object follows, required Object history, required Object areas, required Object settings}) => 'Follows ${follows} · History ${history} · Areas ${areas} · Settings ${settings}',
			'backup.webdavSection' => 'WebDAV sync',
			'backup.webdavDescription' => ({required Object file}) => 'The backup lives on the server as ${file}: upload overwrites it, download restores it.',
			'backup.webdavConfigTitle' => 'Server',
			'backup.webdavConfigDescription' => 'Fill in the WebDAV server address and account; the password is kept in the system\'s secure storage and never enters a backup.',
			'backup.webdavUrl' => 'Server URL',
			'backup.webdavUrlHint' => 'https://dav.jianguoyun.com/dav/',
			'backup.webdavUser' => 'Username',
			'backup.webdavUserHint' => 'Account, may be empty',
			'backup.webdavPassword' => 'Password',
			'backup.webdavPasswordHint' => 'Leave empty to keep the stored one',
			'backup.webdavPasswordKeep' => 'Saved in secure storage',
			'backup.webdavPasswordEmpty' => 'Not set',
			'backup.webdavUrlMissing' => 'Fill in the server URL first',
			'backup.webdavSaved' => 'WebDAV settings saved',
			'backup.webdavTest' => 'Test connection',
			'backup.webdavTestOk' => 'Connected',
			'backup.webdavUpload' => 'Upload backup',
			'backup.webdavUploadDone' => ({required Object file}) => 'Uploaded ${file}',
			'backup.webdavDownload' => 'Download and restore',
			'backup.webdavDownloadConfirmTitle' => 'Download and overwrite the current data?',
			'backup.webdavDownloadConfirmDesc' => ({required Object file}) => 'The server\'s ${file} will overwrite this device\'s follows, history, areas and settings.',
			'backup.webdavAuthFailed' => 'Authentication failed; check the username or password',
			'backup.webdavNotFound' => 'No backup file on the server yet',
			'backup.webdavNetworkFailed' => 'Network error; check the URL or the proxy',
			'backup.webdavServerFailed' => ({required Object status}) => 'The server answered with an error (${status})',
			'backup.webdavFailed' => 'The operation failed',
			'backup.busy' => 'Another operation is running',
			'backup.folderPickTitle' => 'Choose backup folder',
			'backup.folderTitle' => 'Backup folder',
			'backup.folderDefault' => 'Default folder',
			'backup.folderLoading' => 'Loading…',
			'backup.folderReset' => 'Reset to default folder',
			'backup.folderOpen' => 'Open backup folder',
			'backup.folderUnwritable' => 'The backup folder is not writable; pick another',
			'backup.folderSaveFailed' => 'Could not save the backup folder',
			'backup.openFolderFailed' => 'Could not open the backup folder',
			'backup.createTitle' => 'Create backup',
			'backup.createDescription' => 'Bundles follows, watch history, followed areas and settings into a file in the backup folder.',
			'backup.createFollowsTitle' => 'Create follows-only backup',
			'backup.createFollowsDescription' => 'Backs up followed rooms and areas only.',
			'backup.createDone' => ({required String name}) => 'Created ${name}',
			'backup.createFailed' => 'Could not create the backup',
			'backup.filesSection' => 'Backup files',
			'backup.filesCount' => ({required int count}) => '${count} backup files',
			'backup.filesEmpty' => 'No backup files in this folder yet',
			'backup.filesFailed' => 'Could not read the backup folder',
			'backup.filesFailedHint' => 'Check that the folder exists and is readable, then tap to retry.',
			'backup.fileMeta' => ({required String time, required String size, required String kind}) => '${time} · ${size} · ${kind}',
			'backup.kindFull' => 'Full backup',
			'backup.kindFollows' => 'Follows only',
			'backup.fileDelete' => 'Delete backup file',
			'backup.restoreConfirmTitle' => 'Restore this backup?',
			'backup.restoreConfirmDesc' => ({required String name}) => 'Restoring ${name} overwrites this device\'s follows, watch history, followed areas and settings. The current data cannot be recovered.',
			'backup.restoreFollowsConfirmDesc' => ({required String name}) => 'Restoring ${name} overwrites this device\'s follows and followed areas; other data stays as it is.',
			'backup.restoreFailed' => 'Restore failed',
			'backup.deleteConfirmTitle' => 'Delete this backup file?',
			'backup.deleteConfirmDesc' => ({required String name}) => '${name} will be permanently deleted.',
			'backup.deleteDone' => 'Backup file deleted',
			'backup.deleteFileFailed' => 'Could not delete the backup file',
			'backup.summaryFollows' => ({required int follows, required int areas}) => 'Follows ${follows} · Areas ${areas}',
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
			'common.moduleVod' => 'Bilibili',
			'common.moduleMusic' => 'Music',
			'common.retry' => 'Retry',
			'common.moduleComingSoon' => 'This module is on its way',
			'common.back' => 'Back',
			'common.forward' => 'Forward',
			'common.searchHint' => 'Search rooms, streamers or sites',
			'common.switchModule' => 'Switch content type',
			'common.openNavigation' => 'Open navigation',
			'common.refreshFailed' => 'Refresh failed',
			'favorites.emptyTitle' => 'No followed rooms yet',
			'favorites.emptyDescription' => 'Follow a room and it shows up here.',
			'favorites.unfollow' => 'Unfollow',
			'favorites.statusAll' => 'All',
			'favorites.statusLive' => 'Live',
			'favorites.statusOffline' => 'Offline',
			'favorites.refresh' => 'Refresh',
			'favorites.openFailedTitle' => 'The follow list could not open',
			'favorites.statusReplay' => 'Recording',
			'favorites.searchLive' => 'Search Live',
			'favorites.emptyLiveTitle' => 'No followed rooms are live in this filter',
			'favorites.emptyReplayTitle' => 'No recordings in this filter',
			'favorites.emptyOfflineTitle' => 'No offline rooms in this filter',
			'favorites.emptyOfflineHint' => 'Some follows are offline; switch to Offline to see them.',
			'favorites.emptyGroupHint' => 'Try another group or platform, or refresh to fetch their status.',
			'favorites.showOffline' => 'View offline',
			'favorites.refreshFailed' => ({required int count}) => '${count} rooms could not be refreshed',
			'history.emptyTitle' => 'No watch history yet',
			'history.emptyDescription' => 'Watch a stream and it lands here.',
			'history.clear' => 'Clear history',
			'history.remove' => 'Remove this record',
			'history.today' => 'Today',
			'history.yesterday' => 'Yesterday',
			'history.earlier' => 'Earlier',
			'history.openFailedTitle' => 'The history could not open',
			'history.recordCount' => ({required int count, required int limit}) => 'Recorded ${count} / limit ${limit}',
			'history.filter' => 'Filter',
			'history.filterClose' => 'Close filter',
			'history.filterHint' => 'Filter by title, streamer, room ID or platform',
			'history.filterMatches' => ({required int count}) => '${count} found',
			'history.filterReset' => 'Clear filter',
			'history.filterEmptyTitle' => 'No history entries match',
			'history.filterEmptyDescription' => 'Try another keyword, or clear the filter.',
			'history.deleteConfirmTitle' => 'Delete watch record?',
			'history.deleteConfirmDesc' => ({required String title}) => 'Remove “${title}” from watch history? This only removes this saved entry.',
			'history.deleteAction' => 'Delete',
			'history.deleteDone' => 'Removed from history',
			'history.clearConfirmTitle' => 'Clear watch history?',
			'history.clearConfirmDesc' => ({required int count}) => 'Clear all ${count} history entries? This action cannot be undone.',
			'history.clearFilteredConfirmDesc' => ({required int count}) => 'Remove the ${count} entries that match the filter? Other entries stay. This cannot be undone.',
			'history.clearDone' => ({required int count}) => 'Cleared ${count} history entries',
			'history.changeFailed' => 'The history changes were not saved. Try again.',
			'history.limitAction' => 'Change limit',
			'history.limitTitle' => 'Watch History Retention',
			'history.limitDescription' => 'The oldest records are dropped past the limit.',
			'history.limitPresetsLabel' => 'Preset Limits',
			'history.limitCustomLabel' => 'Custom Limit',
			'history.limitInvalid' => ({required int min, required int max}) => 'Enter a whole number from ${min} to ${max}.',
			'history.limitSaved' => ({required int limit}) => 'History limit set to ${limit}',
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
			'iptv.epgSourceTitle' => 'Guide sources',
			'iptv.epgSourceHint' => 'An XMLTV or JSON guide URL',
			'iptv.epgImport' => 'Import',
			'iptv.epgImported' => 'Guide imported',
			'iptv.epgFailed' => 'The guide failed to import',
			'iptv.epgRemove' => 'Remove this guide source',
			'iptv.epgEmpty' => 'No guide sources yet; import one and the channel cards show what is on.',
			'iptv.activeGuideDescription' => 'The guide source used for the channel list; one at a time.',
			'iptv.activeGuideNone' => 'None selected',
			'iptv.activeGuideTitle' => 'Active guide',
			'iptv.autoUpdate' => 'Auto update',
			'iptv.autoUpdateHint' => 'Re-fetches the source at an interval when on.',
			'iptv.channelCount' => ({required int count}) => '${count} channels',
			'iptv.chooseGuide' => 'Choose guide source',
			'iptv.delete' => 'Delete',
			'iptv.deleteActiveGuideNote' => 'This guide is in use; another source takes over after deletion.',
			'iptv.deleteGuideMessage' => ({required String name}) => 'Delete the guide “${name}”? Its downloaded guide data is removed too.',
			'iptv.deleteGuideTitle' => 'Delete guide source?',
			'iptv.deletePlaylistMessage' => ({required String name, required int count}) => 'Delete “${name}” and its ${count} channels?',
			'iptv.deletePlaylistTitle' => 'Delete playlist?',
			'iptv.deleted' => ({required String name}) => 'Deleted “${name}”',
			'iptv.guideName' => 'Guide name',
			'iptv.guideNameHint' => 'e.g. My EPG',
			'iptv.guideSelected' => ({required String name}) => 'Switched to “${name}”',
			'iptv.importAction' => 'Import',
			'iptv.importAddressInvalid' => 'Enter a valid subscription address',
			'iptv.importAddressRequired' => 'Enter the subscription address first',
			'iptv.importFailed' => 'Import failed',
			'iptv.importFormat' => 'Unsupported file format',
			'iptv.importFromFile' => 'From file',
			'iptv.importFromText' => 'Paste text',
			'iptv.importFromUrl' => 'From URL',
			'iptv.importGuide' => 'Import guide',
			'iptv.importGuideDescription' => 'XMLTV URLs or files; the guide is downloaded after import.',
			'iptv.importInvalid' => 'The content is not a valid playlist',
			'iptv.importNameRequired' => 'Enter a playlist name',
			'iptv.importNetworkFailed' => 'The network request failed; check the address or proxy',
			'iptv.importPlaylist' => 'Import playlist',
			'iptv.importPlaylistDescription' => 'M3U/M3U8/TXT from a URL, a file or pasted text.',
			'iptv.importSkipped' => ({required String name, required int count}) => 'Imported “${name}”, skipped ${count}',
			'iptv.importTextRequired' => 'Paste the playlist content first',
			'iptv.imported' => ({required String name}) => 'Imported “${name}”',
			'iptv.importedAt' => ({required String time}) => 'Imported ${time}',
			'iptv.inUse' => 'In use',
			'iptv.lastRefresh' => ({required String time}) => 'Updated ${time}',
			'iptv.localTag' => 'Local',
			'iptv.networkTag' => 'Network',
			'iptv.neverUpdated' => 'Never updated',
			'iptv.noGuidesTitle' => 'No guide sources yet',
			'iptv.noPlaylistsDescription' => 'Import a playlist from a URL, a file or pasted text.',
			'iptv.noPlaylistsTitle' => 'No playlists yet',
			'iptv.pickPlaylistFile' => 'Choose a playlist file',
			'iptv.playlistName' => 'Playlist name',
			'iptv.playlistNameHint' => 'e.g. My channels',
			'iptv.playlistText' => 'Playlist content',
			'iptv.playlistTextHint' => 'Paste M3U/M3U8/TXT content',
			'iptv.playlistUrl' => 'Subscription URL',
			'iptv.playlistUrlHint' => 'https://example.com/playlist.m3u',
			'iptv.playlistsTitle' => 'Playlists',
			'iptv.replaceMessage' => 'A playlist with this name exists; the imported content replaces it.',
			'iptv.replaceTitle' => ({required String name}) => 'Replace “${name}”?',
			'iptv.sourceChanged' => 'The source changed; the cache was updated',
			'iptv.statChannels' => 'Channels',
			'iptv.statGuides' => 'Guides',
			'iptv.statPlaylists' => 'Playlists',
			'iptv.sync' => 'Sync',
			'iptv.syncAll' => 'Sync all',
			'iptv.syncAllDone' => ({required int count}) => 'Synced ${count} playlists',
			'iptv.syncAllNone' => 'No playlists to sync',
			'iptv.syncAllPartial' => ({required int failed, required int count}) => '${failed} of ${count} playlists failed',
			'iptv.syncAllRunning' => ({required int done, required int total}) => 'Syncing ${done} / ${total}',
			'iptv.syncFailed' => ({required String name}) => 'Could not sync “${name}”',
			'iptv.synced' => ({required String name}) => 'Synced “${name}”',
			'iptv.viewChannels' => 'Channels',
			'iptv.viewLabel' => 'View',
			'iptv.viewSources' => 'Playlists',
			'multiview.layoutLabel' => 'Layout',
			'multiview.videoComingSoon' => 'Multi-view playback arrives with the player stack; arrange the panes and pick rooms meanwhile.',
			'multiview.pickRoom' => 'Pick a room',
			'multiview.clearPane' => 'Clear this pane',
			'multiview.swapPane' => 'Swap panes',
			'multiview.swapHere' => 'Move here',
			'multiview.pickerTitle' => ({required Object index}) => 'Pick a room for pane ${index}',
			'multiview.pickerEmptyTitle' => 'No followed rooms yet',
			'multiview.pickerEmptyHint' => 'Follow a room from its live page first; followed rooms show up in this list.',
			'multiview.alreadyShown' => ({required Object index}) => 'Already on pane ${index}',
			'multiview.shownIn' => ({required Object index}) => 'Pane ${index}',
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
			'popular.allPlatforms' => 'All platforms',
			'popular.page' => ({required int page, required int total}) => 'Page ${page} of ${total}',
			'popular.prevPage' => 'Previous page',
			'popular.nextPage' => 'Next page',
			'popular.inlineAt' => ({required Object query, required Object platform}) => 'Searching “${query}” on ${platform}',
			'popular.backToBrowse' => 'Back to browsing',
			'recorder.tabRunning' => 'Recording',
			'recorder.tabFinished' => 'Finished',
			'recorder.clearFinished' => 'Clear finished',
			'recorder.removeTask' => 'Remove this task',
			'recorder.emptyTitle' => 'No recording tasks yet',
			'recorder.emptyFinishedTitle' => 'Finished recordings will show up here',
			'recorder.emptyDescription' => 'Recording arrives with the player stack: once it is in, start a recording from a live room and its task will show up here.',
			'recorder.qualityBest' => 'Best quality',
			'recorder.startedAt' => ({required Object time}) => 'Started at ${time}',
			'recorder.stateRecording' => 'Recording',
			'recorder.stateStopped' => 'Stopped',
			'recorder.stateFailed' => 'Failed',
			'recorder.settingsTitle' => 'Recording',
			'recorder.saveDirTitle' => 'Save directory',
			'recorder.saveDirDefault' => 'Follow the engine\'s default directory',
			'recorder.saveDirDialogHint' => 'Enter the folder recordings are saved to',
			'recorder.namingTitle' => 'File naming template',
			'recorder.namingDescription' => 'Placeholders for date, time, platform, room id and title; takes effect with the player stack.',
			'recorder.namingDialogHint' => 'Enter the naming template for recording files',
			'recorder.maxSizeTitle' => 'Single-file size cap',
			'recorder.maxSizeDescription' => 'Recordings split once a file reaches the cap; takes effect with the player stack.',
			'recorder.filterLabel' => 'Filter',
			'recorder.filterAll' => 'All',
			'recorder.filterRecording' => 'Recording',
			'recorder.filterWaiting' => 'Waiting',
			'recorder.filterSaved' => 'Saved',
			'recorder.filterFailed' => 'Failed',
			'recorder.emptyFilterTitle' => ({required String status}) => 'No tasks in “${status}” yet',
			'recorder.stateWaiting' => 'Waiting for live',
			'recorder.stateSaved' => 'Saved',
			'recorder.menuMore' => 'More actions',
			'recorder.openRoom' => 'Open live room',
			'recorder.openFolder' => 'Open folder',
			'recorder.openFolderFailed' => 'Could not open the folder',
			'recorder.delete' => 'Delete',
			'recorder.deleteTitle' => ({required String name}) => 'Delete “${name}”?',
			'recorder.deleteBody' => 'This removes the task only; files already saved stay on disk.',
			'recorder.settingsOpen' => 'Recording settings',
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
			'room.sendHint' => 'Say something',
			'room.send' => 'Send',
			'room.sendFailed' => 'The message failed to send',
			'room.fullscreenOn' => 'Enter fullscreen',
			'room.fullscreenOff' => 'Leave fullscreen',
			'search.idleTitle' => 'Search',
			'search.idleDescription' => 'Type to search rooms, streamers or areas.',
			'search.suggestionsTitle' => 'Suggestions',
			'search.targetsLabel' => 'Search targets',
			'search.tabRooms' => 'Rooms',
			'search.tabAnchors' => 'Streamers',
			'search.tabAreas' => 'Areas',
			'search.noResultsTitle' => 'No results',
			'search.noResultsDescription' => 'Try other words, or another target.',
			'search.unsupportedTitle' => 'This platform cannot search',
			'search.unsupportedDescription' => 'Switch to another platform and try again.',
			'search.liveBadge' => 'Live',
			'search.scopeAll' => 'All',
			'search.historyTitle' => 'Search history',
			'search.clearHistory' => 'Clear',
			'settings.title' => 'Settings',
			'settings.navGeneral' => 'General',
			'settings.navAppearance' => 'Appearance',
			'settings.navPlayback' => 'Playback',
			'settings.navSites' => 'Sites',
			'settings.navData' => 'Data',
			'settings.navAbout' => 'About',
			'settings.groupBasics' => 'Basics',
			'settings.groupContent' => 'Sites',
			'settings.groupData' => 'Data',
			'settings.groupAbout' => 'About',
			'settings.generalDescription' => 'Default site, card width and page size.',
			'settings.appearanceDescription' => 'Theme mode: follow the system, light or dark.',
			'settings.playbackDescription' => 'Quality, aspect ratio and player behaviour.',
			'settings.sitesDescription' => 'Browsing sites and signed-in accounts.',
			'settings.dataDescription' => 'Follows, history and local storage.',
			'settings.aboutDescription' => 'Version, licences and project links.',
			'settings.playbackComingSoon' => 'Playback settings arrive with the player.',
			'settings.sitesComingSoon' => 'Site management and accounts are on the way.',
			'settings.dataComingSoon' => 'Data management is on the way.',
			'settings.aboutComingSoon' => 'The about page is on the way.',
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
			'settings.cardExtentDescription' => 'How wide one feed card gets; smaller means more per row.',
			'settings.pageSize' => 'Page size',
			'settings.pageSizeDescription' => 'How many rooms one page asks the site for.',
			'settings.sitesDisplay' => 'Platforms shown',
			'settings.sitesDisplayDesc' => 'Switched-off platforms leave the popular and areas tab lists.',
			'settings.sitesAllShown' => 'Every platform is shown.',
			'settings.dataClearHistory' => 'Clear watch history',
			'settings.dataClearHistoryDesc' => 'Deletes every watch record, for good.',
			'settings.dataExportFollows' => 'Export follows',
			'settings.dataExportFollowsDesc' => 'Copies the follow list to the clipboard (JSON).',
			'settings.dataImportFollows' => 'Import follows',
			'settings.dataImportFollowsDesc' => 'Reads previously exported follows from the clipboard (JSON).',
			'settings.dataDone' => 'Done',
			'settings.dataBadData' => 'The clipboard could not be read as follows',
			'settings.dataEmpty' => 'Nothing to export yet',
			'settings.confirmClearTitle' => 'Clear watch history?',
			'settings.confirmClearDesc' => 'Every watch record will be deleted, for good.',
			'settings.confirm' => 'Clear',
			'settings.aboutVersion' => 'Version',
			'settings.aboutProject' => 'Project home',
			'settings.aboutLicense' => 'Licences',
			'settings.aboutLicenseDesc' => 'The open-source packages this app builds on.',
			'settings.themeSeed' => 'Accent colour',
			'settings.themeSeedSystem' => 'Follow the system accent',
			'settings.seedBlue' => 'Blue',
			'settings.seedNavy' => 'Navy',
			'settings.seedGraphite' => 'Graphite',
			'settings.seedOxblood' => 'Oxblood',
			'settings.seedForest' => 'Forest',
			'settings.seedIndigo' => 'Indigo',
			'settings.corners' => 'Corners',
			'settings.cornersStandard' => 'Standard',
			'settings.cornersSharp' => 'Sharp',
			'settings.cornersSoft' => 'Soft',
			'settings.cornersPill' => 'Pill',
			'settings.density' => 'Control density',
			'settings.densitySystem' => 'Follow the platform',
			'settings.densityCompact' => 'Compact',
			'settings.densityTouch' => 'Touch',
			'settings.languageSystem' => 'Follow the system',
			'settings.refreshGroup' => 'Refresh',
			'settings.followsAutoRefresh' => 'Refresh follows automatically',
			'settings.followsAutoRefreshDesc' => 'Refreshes the follow list on an interval while the page is open.',
			'settings.refreshInterval' => 'Interval',
			'settings.historyLimit' => 'History limit',
			'settings.historyLimitDesc' => 'The oldest records past the limit are dropped.',
			'settings.navNetwork' => 'Network',
			'settings.networkDescription' => 'The app proxy and transport behaviour.',
			'settings.proxy' => 'App proxy',
			'settings.proxyDesc' => 'When on, the vod, guide and backup requests all route through it.',
			'settings.proxyHost' => 'Host',
			'settings.proxyPort' => 'Port',
			'settings.toolsOrder' => 'Tools order',
			'settings.toolsOrderDesc' => 'The order of the tools under the sidebar\'s divider.',
			'settings.moveUp' => 'Move up',
			'settings.moveDown' => 'Move down',
			'settings.navShield' => 'Danmaku shield',
			'settings.shieldDescription' => 'Blocked keywords and users; the live room filters by them.',
			'settings.danmakuStyleGroup' => 'Danmaku style',
			'settings.styleFontSize' => 'Type size',
			'settings.styleSpeed' => 'Speed',
			'settings.styleArea' => 'Display area',
			'settings.styleOpacity' => 'Opacity',
			'settings.styleStroke' => 'Outline',
			'settings.styleReset' => 'Reset to defaults',
			'settings.windowGroup' => 'Window',
			'settings.closeAction' => 'On window close',
			'settings.closeQuit' => 'Quit the app',
			'settings.closeMinimise' => 'Minimise to the taskbar',
			'settings.closeTrayUnavailable' => 'Hide to tray (needs the tray, not wired yet)',
			'settings.font' => 'Font',
			'settings.fontDescription' => 'UI typeface: the platform\'s own face, or one of the bundled official ones.',
			'settings.fontPlatform' => 'Follow the platform (system font)',
			'settings.backHome' => 'Back to app',
			'settings.pureBlack' => 'True black (OLED)',
			'settings.pureBlackDesc' => 'Collapses dark backgrounds to true black for OLED screens.',
			'settings.navCache' => 'Cache',
			'settings.cacheDescription' => 'The disk cache for covers and avatars, and its cleanup cap.',
			'settings.cacheSize' => 'Current cache size',
			'settings.cacheRefresh' => 'Refresh',
			'settings.cacheClear' => 'Clear cache',
			'settings.cacheClearDesc' => 'Deletes every cached cover, avatar and site icon.',
			'settings.cacheCleared' => 'Cache cleared',
			_ => null,
		} ?? switch (path) {
			'settings.cacheLimit' => 'Automatic cleanup cap',
			'settings.cacheLimitDesc' => 'Oldest images are deleted past the cap; off keeps only expiry-based cleanup.',
			'settings.cacheLimitOff' => 'No automatic cleanup',
			'settings.cacheHint' => 'Covers and avatars are kept on this device for 30 days and pruned when they expire or pass the cap.',
			'settings.preferPlatform' => 'Preferred platform',
			'settings.preferPlatformDesc' => 'The platform the popular and areas pages open with.',
			'settings.sitesOrderReset' => 'Restore default order',
			'settings.sitesOrderResetDesc' => 'Platforms return to the built-in order; the show switches stay as they are.',
			'settings.windowChrome' => 'Window title bar',
			'settings.windowChromeDesc' => 'Use the system caption, or the app\'s own strip; a restart applies the change.',
			'settings.windowChromeSystem' => 'System title bar',
			'settings.windowChromeCustom' => 'Custom title bar',
			'settings.windowChromeRestartTitle' => 'Restart to apply the title bar?',
			'settings.windowChromeRestartDesc' => 'The caption style is chosen when the window is created; it applies after a restart.',
			'settings.windowChromeRestartNow' => 'Restart now',
			'shield.title' => 'Danmaku shield',
			'shield.description' => 'Keep live-room danmaku out by keyword or user; the rules live on this device.',
			'shield.masterTitle' => 'Master switch',
			'shield.enabled' => 'Enable the danmaku shield',
			'shield.enabledDescription' => 'When off, every rule stands down for the moment',
			'shield.keywordsTitle' => 'Keywords',
			'shield.usersTitle' => 'Users',
			'shield.keywordFieldHint' => 'Type a keyword to block',
			'shield.userFieldHint' => 'Type a user name to block',
			'shield.add' => 'Add',
			'shield.keywordsEmpty' => 'No blocked keywords yet',
			'shield.usersEmpty' => 'No blocked users yet',
			'shield.clear' => 'Clear all',
			'shield.clearConfirmDesc' => 'The list empties; add entries again whenever you need them.',
			'shield.duplicateEntry' => 'This entry is already on the list',
			'shield.invalidEntry' => 'The entry cannot be empty',
			'shield.added' => 'Blocked',
			'shield.removed' => 'Removed',
			'shield.cleared' => 'Cleared',
			'shield.removeEntry' => 'Remove this rule',
			'shield.effectNote' => 'The rules apply in the live room\'s danmaku pipeline, which arrives with the player stack.',
			'sites.title' => 'Sites',
			'sites.live' => 'Live',
			'sites.search' => 'Search',
			'sites.rooms' => 'Rooms',
			'toolbox.title' => 'Toolbox',
			'toolbox.groupLinks' => 'Links',
			'toolbox.groupNetwork' => 'Network',
			'toolbox.groupData' => 'Data',
			'toolbox.toolLinkTitle' => 'Link resolver',
			'toolbox.toolLinkDescription' => 'Paste a platform link to open the room or copy its address.',
			'toolbox.toolNetworkTitle' => 'Network check',
			'toolbox.toolNetworkDescription' => 'Check whether a site\'s endpoint is reachable and how fast it answers.',
			'toolbox.toolCacheTitle' => 'Cache cleanup',
			'toolbox.toolCacheDescription' => 'Inspect and clear the memory the image cache holds.',
			'toolbox.toolLogsTitle' => 'Log viewer',
			'toolbox.toolLogsDescription' => 'Browse the app\'s runtime logs to debug playback and network issues.',
			'toolbox.back' => 'Back',
			'toolbox.confirm' => 'Confirm',
			'toolbox.cancel' => 'Cancel',
			'toolbox.linkFieldLabel' => 'Platform link',
			'toolbox.linkFieldHint' => 'Paste a room link or shared text',
			'toolbox.linkOpen' => 'Open room',
			'toolbox.linkCopy' => 'Copy room link',
			'toolbox.linkPaste' => 'Paste',
			'toolbox.linkClear' => 'Clear',
			'toolbox.linkResolving' => 'Resolving the link…',
			'toolbox.linkResolvedTitle' => 'Resolved',
			'toolbox.linkPlatform' => 'Platform',
			'toolbox.linkRoom' => 'Room',
			'toolbox.linkEmpty' => 'Paste a link first',
			'toolbox.linkUnsupported' => 'This link is not recognised; the platform is not supported yet.',
			'toolbox.linkTimeout' => 'The resolve timed out; check the network and try again.',
			'toolbox.linkFailed' => 'The resolve failed; try again later.',
			'toolbox.linkCopyDone' => 'Room link copied',
			'toolbox.linkCopyFailed' => 'Copy failed',
			'toolbox.linkSupportTitle' => 'Supported platforms',
			'toolbox.linkSupportHint' => 'Room links of these platforms resolve and open directly.',
			'toolbox.networkSiteLabel' => 'Choose a platform',
			'toolbox.networkRun' => 'Run the check',
			'toolbox.networkResultTitle' => 'Result',
			'toolbox.networkTarget' => 'Probed endpoint',
			'toolbox.networkTargetDesc' => 'The recommended-rooms endpoint',
			'toolbox.networkLatency' => 'Response time',
			'toolbox.networkRooms' => 'Rooms returned',
			'toolbox.networkSuccess' => 'Reachable',
			'toolbox.networkFailure' => 'Unreachable',
			'toolbox.networkBusy' => 'Checking…',
			'toolbox.networkUnsupported' => 'This platform cannot be probed yet.',
			'toolbox.cacheSection' => 'Image cache',
			'toolbox.cacheEntries' => 'Cached images',
			'toolbox.cacheSize' => 'Memory held',
			'toolbox.cacheClear' => 'Clear the cache',
			'toolbox.cacheClearDesc' => 'Release the memory the image cache holds; favorites and history are untouched.',
			'toolbox.cacheConfirmTitle' => 'Clear the image cache?',
			'toolbox.cacheConfirmDesc' => 'Loaded images download again; favorites and history are untouched.',
			'toolbox.cacheDone' => 'Cache cleared',
			'toolbox.cacheEmpty' => 'Nothing cached',
			'toolbox.comingSoonTitle' => 'Coming soon',
			'toolbox.comingSoonDesc' => 'This tool is not finished yet; stay tuned.',
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
