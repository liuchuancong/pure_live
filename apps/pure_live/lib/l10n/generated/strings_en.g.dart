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
	@override late final _Translations$splash$en splash = _Translations$splash$en._(_root);
	@override late final _Translations$home$en home = _Translations$home$en._(_root);
	@override late final _Translations$common$en common = _Translations$common$en._(_root);
	@override late final _Translations$tray$en tray = _Translations$tray$en._(_root);
	@override late final _Translations$login$en login = _Translations$login$en._(_root);
	@override late final _Translations$account$en account = _Translations$account$en._(_root);
	@override late final _Translations$settings$en settings = _Translations$settings$en._(_root);
	@override late final _Translations$hotAreas$en hotAreas = _Translations$hotAreas$en._(_root);
	@override late final _Translations$tags$en tags = _Translations$tags$en._(_root);
	@override late final _Translations$logs$en logs = _Translations$logs$en._(_root);
	@override late final _Translations$recorder$en recorder = _Translations$recorder$en._(_root);
	@override late final _Translations$theme$en theme = _Translations$theme$en._(_root);
	@override late final _Translations$design$en design = _Translations$design$en._(_root);
	@override late final _Translations$room$en room = _Translations$room$en._(_root);
	@override late final _Translations$areas$en areas = _Translations$areas$en._(_root);
	@override late final _Translations$popular$en popular = _Translations$popular$en._(_root);
	@override late final _Translations$history$en history = _Translations$history$en._(_root);
	@override late final _Translations$iptv$en iptv = _Translations$iptv$en._(_root);
	@override late final _Translations$fonts$en fonts = _Translations$fonts$en._(_root);
	@override late final _Translations$follow$en follow = _Translations$follow$en._(_root);
	@override late final _Translations$toolbox$en toolbox = _Translations$toolbox$en._(_root);
	@override late final _Translations$backup$en backup = _Translations$backup$en._(_root);
	@override late final _Translations$about$en about = _Translations$about$en._(_root);
	@override late final _Translations$shield$en shield = _Translations$shield$en._(_root);
	@override late final _Translations$multiview$en multiview = _Translations$multiview$en._(_root);
	@override late final _Translations$search$en search = _Translations$search$en._(_root);
	@override late final _Translations$remoteSync$en remoteSync = _Translations$remoteSync$en._(_root);
	@override late final _Translations$errors$en errors = _Translations$errors$en._(_root);
	@override late final _Translations$tabs$en tabs = _Translations$tabs$en._(_root);
	@override late final _Translations$window$en window = _Translations$window$en._(_root);
	@override late final _Translations$closePrompt$en closePrompt = _Translations$closePrompt$en._(_root);
	@override late final _Translations$shellSettings$en shellSettings = _Translations$shellSettings$en._(_root);
	@override late final _Translations$webdav$en webdav = _Translations$webdav$en._(_root);
	@override late final _Translations$wallpaper$en wallpaper = _Translations$wallpaper$en._(_root);
	@override late final _Translations$cast$en cast = _Translations$cast$en._(_root);
	@override late final _Translations$danmaku$en danmaku = _Translations$danmaku$en._(_root);
	@override late final _Translations$clipboard$en clipboard = _Translations$clipboard$en._(_root);
}

// Path: app
class _Translations$app$en extends Translations$app$zh {
	_Translations$app$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get title => 'Pure Live';
}

// Path: splash
class _Translations$splash$en extends Translations$splash$zh {
	_Translations$splash$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get welcome => 'Welcome';
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
	@override String get restartNow => 'Restart now';
	@override String get restartLater => 'Later';
	@override String get retry => 'Retry';
	@override String get close => 'Close';
	@override String get save => 'Save';
	@override String get clear => 'Clear';
	@override String get delete => 'Delete';
	@override String get loading => 'Loading';
	@override String get empty => 'Nothing here yet';
	@override String pageOf({required int page, required int total}) => 'Page ${page} of ${total}';
	@override String get back => 'Back';
	@override String get menu => 'Menu';
	@override String get expandSidebar => 'Expand sidebar';
	@override String get collapseSidebar => 'Collapse sidebar';
	@override String get more => 'More';
	@override String get off => 'Off';
	@override String get refresh => 'Refresh';
	@override String get prevPage => 'Previous';
	@override String get nextPage => 'Next';
	@override String get perPage => 'Per page';
	@override String get goTo => 'Go to';
	@override String get pageUnit => 'Page';
	@override String get toTop => 'To the top';
	@override String get toBottom => 'To the bottom';
	@override String get addOne => 'Add';
	@override String get ignore => 'Ignore';
}

// Path: tray
class _Translations$tray$en extends Translations$tray$zh {
	_Translations$tray$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get show => 'Show Pure Live';
	@override String get quit => 'Quit';
	@override String get hide => 'Hide window';
	@override String recordingCount({required Object count}) => 'Recording ${count} room(s)';
	@override String tooltipRecording({required Object count}) => 'Pure Live · recording ${count} room(s)';
}

// Path: login
class _Translations$login$en extends Translations$login$zh {
	_Translations$login$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get title => 'Sign in';
	@override String get generating => 'Generating QR code';
	@override String get waitingScan => 'Waiting for scan';
	@override String get scanHint => 'Open the bilibili app and scan this code to confirm the sign-in.';
	@override String get success => 'Signed in';
	@override String welcome({required String name}) => 'Welcome, ${name}';
	@override String get expired => 'The QR code has expired';
	@override String get refreshQr => 'Refresh code';
	@override String get failed => 'The sign-in did not go through';
	@override String get done => 'Done';
	@override String get unsupported => 'This build has no bilibili sign-in capability';
	@override String get platformBilibili => 'bilibili QR';
	@override String get platformDouyu => 'douyu cookie';
	@override String get platformHuya => 'huya cookie';
	@override String get cookiePlaceholder => 'Cookie: a=b; c=d ...';
	@override String get verify => 'Verify and sign in';
	@override String get douyuCookieHint => 'Copy the Cookie header of a signed-in www.douyu.com request from the browser’s network inspector and paste it here.';
	@override String get huyaCookieHint => 'Copy the Cookie header of a signed-in www.huya.com request from the browser’s network inspector and paste it here.';
	@override String unsupportedSite({required String site}) => 'This build has no ${site} sign-in capability';
}

// Path: account
class _Translations$account$en extends Translations$account$zh {
	_Translations$account$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get title => 'Account';
	@override String get notSignedIn => 'Not signed in';
	@override String get notSignedInHint => 'Sign in and the live requests carry your account with them.';
	@override String get signOut => 'Sign out';
	@override String signOutConfirm({required String site}) => 'Sign out of ${site}?';
	@override String get signOutHint => 'The saved cookies are removed from this device.';
	@override String userId({required String id}) => 'ID ${id}';
	@override String get platformBilibili => 'bilibili account';
	@override String get platformDouyu => 'douyu account';
	@override String get platformHuya => 'huya account';
	@override String get noAuthSites => 'No platform in this build can sign in yet';
	@override String get clearAllAccounts => 'Clear all accounts';
	@override String get clearAllAccountsHint => 'Sign out of every platform and drop the stored credentials';
	@override String editorTitle({required Object name}) => '${name} account';
	@override String get cookieGroup => 'Cookie';
	@override String get paste => 'Paste';
	@override String get clearInput => 'Clear';
	@override String get cookieInvalid => 'This does not look like a cookie: expected name=value; name2=value2';
	@override String get clipboardEmpty => 'The clipboard has no text';
	@override String get editorNoneHint => 'Not set: paste the cookie of a signed-in browser';
	@override String get saved => 'Saved';
	@override String signedIn({required Object name}) => 'Signed in: ${name}';
	@override String statusUid({required Object uid}) => 'Saved · account id ${uid}';
	@override String get verifying => 'Verifying account…';
	@override String get savingVerifying => 'Checking and saving…';
	@override String openSite({required Object name}) => 'Open ${name} website';
	@override String get privacyNote => 'Cookies are stored encrypted on this device only and never uploaded.';
	@override String get discardTitle => 'Discard Cookie changes?';
	@override String get discardDetail => 'Your edited Cookie has not been saved. Discard these changes and leave this page?';
	@override String get discard => 'Discard';
	@override String get keepEditing => 'Keep editing';
	@override String get cookieTip => 'Sign in on the platform in a browser, open the developer tools and copy the whole Cookie request header below.';
	@override String get statusExpired => 'Expired — paste the cookie again';
	@override String get douyuLtp0 => 'LTP0 (long-term key)';
	@override String get douyuLtp0Hint => 'the LTP0 in the passport.douyu.com request cookie; filled automatically when you paste above';
	@override String get douyuDid => 'dy_did (device id)';
	@override String get douyuDidHint => 'the dy_did in that same request (32 hex characters); filled automatically';
	@override String get douyuRenew => 'Renew now';
	@override String get douyuRenewNeedPair => 'Renewal needs LTP0 and dy_did: sign in to Douyu in a browser and paste the cookie again';
	@override String get douyuStatusGuest => 'Saved, but there is no acf_jwt_token: this is a guest cookie, so HD/UHD are unavailable';
	@override String get douyuStatusNoExpiry => 'Signed in (the cookie carries no end time; add LTP0 to renew it automatically)';
	@override String douyuStatusAutoRenew({required Object time}) => 'Signed in (about 7 days, until ${time}); LTP0 is set, so it renews before it ends';
	@override String douyuStatusRepaste({required Object time}) => 'Signed in (about 7 days, until ${time}); no LTP0, so paste it again after that';
	@override String douyuStatusRenewable({required Object time}) => 'Session expired at ${time}; saved, and the next playback renews it with LTP0';
	@override String douyuStatusExpired({required Object time}) => 'Session expired at ${time} and the cookie has no LTP0: paste a fresh one';
	@override String get savedAccounts => 'Remembered accounts';
	@override String savedAccountsNote({required Object count}) => 'Accounts you signed in with are kept here (up to ${count}); switching needs no new scan. Sign-ins are stored encrypted on this device only and are erased when you sign out or remove them.';
	@override String accountUid({required Object uid}) => 'UID ${uid}';
	@override String get accountCurrent => 'Current';
	@override String get accountSwitch => 'Switch';
	@override String get accountForget => 'Remove this account';
	@override String accountSwitchConfirm({required Object name}) => 'Switch to “${name}”? Rooms you are watching reconnect their danmaku with this account.';
	@override String accountForgetConfirm({required Object name}) => 'Remove the sign-in of “${name}” from this device? Using that account again needs a new sign-in.';
	@override String get accountAdd => 'Add an account';
	@override String get accountAddHint => 'Sign another account in with the QR code; the current one stays here';
	@override String accountAddFull({required Object count}) => '${count} remembered; adding another forgets the one unused the longest';
	@override String accountSwitched({required Object name}) => 'Switched to “${name}”';
	@override String accountForgot({required Object name}) => 'Removed “${name}”';
	@override String accountAdded({required Object name}) => '“${name}” is remembered';
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
	@override String get sectionTheme => 'Theme & display';
	@override String get sectionIptv => 'IPTV';
	@override String get sectionDanmaku => 'Danmaku';
	@override String get sectionData => 'Data';
	@override String get sectionBackup => 'Backup';
	@override String get appearanceSubtitle => 'Theme mode, colour, density and motion';
	@override String get fontsSubtitle => 'Download and apply cloud fonts';
	@override String get iptvSubtitle => 'Manage playlists and channels';
	@override String get shieldSubtitle => 'Hide danmaku by keyword, user or regex';
	@override String get cacheAndData => 'Cache & data';
	@override String get cacheAndDataSubtitle => 'Watch history and stored data';
	@override String get backupSubtitle => 'Back up and restore your data';
	@override String get groupTheme => 'Theme';
	@override String get groupFontFamily => 'Font';
	@override String get groupTextSize => 'Text size';
	@override String get themeModeSubtitle => 'Follow the system, or stay light or dark';
	@override String get designLanguageSubtitle => 'The design language the whole app is drawn with';
	@override String get designLanguageRestartTitle => 'Change design language';
	@override String designLanguageRestartConfirm({required String current}) => 'The design language decides which app host runs, so it takes effect on the next launch. This session keeps drawing with ${current}. Restart the app now?';
	@override String designLanguagePending({required String name}) => 'Applies after restart: ${name}';
	@override String get accentSubtitle => 'The colour the controls are tinted with';
	@override String get densitySubtitle => 'How compact the layout is';
	@override String get pureBlackSubtitle => 'Draw dark surfaces pure black, for OLED screens';
	@override String get transparencySubtitle => 'A multiplier on glass and scrim opacity';
	@override String get reduceTransparencySubtitle => 'Force opaque surfaces and disable blur';
	@override String get animationsSubtitle => 'Whether motion runs';
	@override String get focusOutlineSubtitle => 'Draw a visible outline on focused controls';
	@override String get fontScaleSubtitle => 'A multiplier on every font size';
	@override String get previewText => 'The quick brown fox jumps over the lazy dog';
	@override String fontFamilyCurrent({required String name}) => 'Current: ${name}';
	@override String get defaultOption => 'Default';
	@override String get historyEntry => 'Watch history';
	@override String historyCount({required int count}) => '${count} entries';
	@override String get clearHistory => 'Clear watch history';
	@override String get clearHistorySubtitle => 'Remove every watched entry from this device';
	@override String get historyCleared => 'Watch history cleared';
	@override String get general => 'General';
	@override String get generalSubtitle => 'Refresh, launch, countdown close and window';
	@override String get sectionGeneral => 'General';
	@override String get sectionAccount => 'Account';
	@override String get scanToLogin => 'Sign in to your platforms';
	@override String get accountSubtitle => 'Platform accounts and sign-in';
	@override String get refreshSettings => 'Refresh';
	@override String get refreshSettingsSubtitle => 'Foreground interval and resume threshold';
	@override String get pageSettings => 'Page settings';
	@override String get pageSettingsSubtitle => 'Which branches show, and in what order';
	@override String get navigationSettings => 'Navigation';
	@override String get navigationSettingsSubtitle => 'Where the app starts';
	@override String get sectionFeedDisplay => 'Feed display';
	@override String get loadingStyle => 'Loading style';
	@override String get loadingStyleSubtitle => 'How loading placeholders present';
	@override String get roomCardSettings => 'Room card';
	@override String get roomCardSettingsSubtitle => 'Radius, cover shape and info lines';
	@override String get sectionNetwork => 'Network';
	@override String get proxySettings => 'Network proxy';
	@override String get proxySettingsSubtitle => 'Route requests through a proxy';
	@override String get refreshOnResume => 'Refresh on resume';
	@override String get refreshOnResumeSubtitle => 'Refresh feeds when you come back, if you were away long enough';
	@override String get showUnplayable => 'Show unplayable rooms';
	@override String get showUnplayableDesc => 'List carousel, sign-in-required and members-only rooms in feeds and search';
	@override String get autoCheckUpdate => 'Check for updates at start';
	@override String get autoCheckUpdateSubtitle => 'Ask about new versions from the release feed; the About page can always check manually';
	@override String get countdownClose => 'Countdown close';
	@override String get countdownCloseSubtitle => 'Exit the app when the countdown runs out';
	@override String get countdownDuration => 'Countdown duration';
	@override String minutesValue({required int minutes}) => '${minutes} min';
	@override String minutesAway({required int minutes}) => 'After ${minutes} min away';
	@override String get launchPage => 'Launch page';
	@override String get launchPageHint => 'The branch the app starts on. The navigation settings can override this with the last visited tab.';
	@override String get windowSize => 'Window size';
	@override String get windowSizeDefault => 'Launch default';
	@override String get windowSizeHint => 'Applies now, and again at the next launch.';
	@override String get groupAutoRefresh => 'Auto refresh';
	@override String get autoRefreshInterval => 'Foreground refresh interval';
	@override String get autoRefreshIntervalHint => 'How often the visible feed refreshes itself. Off by default.';
	@override String get refreshResumeThreshold => 'Resume refresh threshold';
	@override String get refreshResumeThresholdHint => 'How long away counts as worth refreshing for.';
	@override String get refreshOff => 'Off';
	@override String get refreshEveryResume => 'Every resume';
	@override String get groupVisibleBranches => 'Visible pages';
	@override String get groupHiddenBranches => 'Hidden pages';
	@override String get showBranchSubtitle => 'Show this page in the shell';
	@override String get pageSettingsHint => 'Drag to arrange. At least one page stays visible.';
	@override String get atLeastOneBranch => 'At least one page must stay visible';
	@override String get groupLaunch => 'Start-up';
	@override String get restoreLastTab => 'Resume where you left off';
	@override String get restoreLastTabSubtitle => 'Start on the branch you last visited';
	@override String restoreLastTabOn({required String branch}) => 'Start on the branch you last visited (last: ${branch})';
	@override String get navigationHint => 'Decides where the start splash hands over; a change lands at the next start.';
	@override String get proxyGroup => 'Proxy';
	@override String get proxyEnable => 'Use a proxy';
	@override String get proxyEnableSubtitle => 'Route outgoing requests through the proxy below';
	@override String get proxyEndpoint => 'Endpoint';
	@override String get proxyHost => 'Host';
	@override String get proxyPort => 'Port';
	@override String get proxyPortInvalid => 'Port must be 1-65535';
	@override String get proxyHint => 'Applied to new connections immediately; no restart needed.';
	@override String get loadingPreview => 'Preview';
	@override String get loadingShimmer => 'Shimmer';
	@override String get loadingSpinner => 'Spinner';
	@override String get loadingNone => 'Nothing';
	@override String get roomCardPreview => 'Preview';
	@override String get roomCardAppearance => 'Appearance';
	@override String get roomCardRadius => 'Corner radius';
	@override String get roomCardAspect => 'Cover shape';
	@override String get aspectSixteenByNine => '16:9';
	@override String get aspectFourByThree => '4:3';
	@override String get aspectSquare => '1:1';
	@override String get roomCardContent => 'Visible content';
	@override String get roomCardShowPlatform => 'Platform badge';
	@override String get roomCardShowPlatformSubtitle => 'The platform pill over the cover';
	@override String get roomCardShowAudience => 'Audience and status';
	@override String get roomCardShowAudienceSubtitle => 'The viewer-count, replay and offline pills';
	@override String get roomCardShowAnchor => 'Anchor line';
	@override String get roomCardShowAnchorSubtitle => 'The avatar and the anchor\'s name';
	@override String get roomCardScopeHint => 'Applies to the popular, areas, follow and search grids.';
	@override String get remoteSync => 'LAN sync';
	@override String get remoteSyncSubtitle => 'Sync playback to another device on this network';
	@override String get sectionRecorder => 'Recording';
	@override String get recorderSubtitle => 'Watch rooms and record them live';
	@override String get pasteCookie => 'Paste cookie to sign in';
	@override String accountSignedInCount({required int count}) => 'Signed in on ${count} platforms';
	@override String get sectionVideo => 'Video & danmaku';
	@override String get video => 'Video & danmaku';
	@override String get videoSubtitle => 'What a room opens with';
	@override String get groupDanmaku => 'Danmaku';
	@override String get groupAudio => 'Audio';
	@override String get danmakuVisible => 'Show danmaku by default';
	@override String get danmakuVisibleSubtitle => 'Overlay the barrage when a room opens';
	@override String get defaultVolume => 'Default volume';
	@override String get defaultVolumeSubtitle => 'The level the next stream starts at';
	@override String get language => 'Language';
	@override String get languageSubtitle => 'Follow the system, or pick one';
	@override String get languageSystem => 'Follow system';
	@override String get groupAppearance => 'Barrage look';
	@override String get groupLocalInteraction => 'Local interaction';
	@override String get localInteraction => 'Local interaction';
	@override String get localInteractionSubtitle => 'Adds the room composer; your messages show only on your screen';
	@override String get localInteractionName => 'Local display name';
	@override String get mpvTuning => 'Player tuning';
	@override String get mpvTuningSubtitle => 'libmpv output, decoding and cache options';
	@override String get mpvOutputSection => 'Output';
	@override String get mpvCustomOutput => 'Custom output drivers';
	@override String get mpvCustomOutputSubtitle => 'Off keeps the engine\'s platform defaults; on lets the drivers below be written';
	@override String get mpvNeedsCustomOutput => 'Turn on "Custom output drivers" first';
	@override String get mpvVideoOutput => 'Video output (vo)';
	@override String get mpvAudioOutput => 'Audio output (ao)';
	@override String get mpvDecodeSection => 'Decoding & rendering';
	@override String get mpvHardwareDecoder => 'Hardware decoder (hwdec)';
	@override String get mpvDeinterlace => 'Deinterlace';
	@override String get mpvInterpolation => 'Frame interpolation';
	@override String get mpvInterpolationSubtitle => 'Smoother motion at a higher GPU cost; desktop only';
	@override String get mpvScaler => 'Scaler (scale)';
	@override String get mpvCacheSection => 'Cache';
	@override String get mpvCacheSeconds => 'Stream cache seconds';
	@override String get mpvCacheSecondsSubtitle => '0 leaves the engine\'s cache alone';
	@override String get mpvReset => 'Reset defaults';
	@override String get mpvResetSubtitle => 'Clears every tuning on this page';
	@override String get mpvEffectiveNote => 'How it takes effect';
	@override String get mpvEffectiveNoteBody => 'Video/audio output and the hardware decoder land on the next stream open; the rest apply to the playing room immediately.';
	@override String get localConfig => 'Local configuration';
	@override String get localConfigSubtitle => 'A read-only view of the documents this device stores';
	@override String get localConfigNote => 'This page writes nothing; edit the settings it mirrors instead.';
	@override String get localConfigCopy => 'Copy this document';
	@override String get localConfigApp => 'General preferences';
	@override String get localConfigAppearance => 'Appearance';
	@override String get areaInterface => 'Interface';
	@override String get areaSources => 'Sources';
	@override String get areaPlayback => 'Playback';
	@override String get areaGeneral => 'General';
	@override String get areaData => 'Data';
	@override String get searchHint => 'Search settings';
	@override String get searchEmpty => 'No matching settings';
	@override String get searchEmptyHint => 'Try a different keyword';
	@override String get platformsTitle => 'Platforms';
	@override String get platformsDesc => 'Visibility, order and accounts';
	@override String get danmakuTitle => 'Danmaku';
	@override String get danmakuDesc => 'Display, size, opacity and blocking';
	@override String get recordingTitle => 'Recording';
	@override String get recordingDesc => 'Output folder and segment length';
	@override String get playerTitle => 'Player';
	@override String get playerDesc => 'Decoding, output and cache tuning';
	@override String get logTitle => 'Logs';
	@override String get logDesc => 'Log level and export';
	@override String get localInteractionDesc => 'Local danmaku identity and switch';
	@override String get localInteractionColor => 'Danmaku colour';
	@override String get navigationDesc => 'Navigation bar and start page';
	@override String get videoDesc => 'Volume, quality and background play';
	@override String get refreshDesc => 'Auto refresh and live alerts';
	@override String get generalDesc => 'Startup, updates and window';
	@override String get proxyDesc => 'App and player proxies';
	@override String get cacheDesc => 'Cache size and cleanup';
	@override String get backupDesc => 'Back up and restore local data';
	@override String get iptvDesc => 'Manage playlists and channels';
	@override String get pageDesc => 'Paging and scrolling';
	@override String get pagerGroup => 'Pager (computers)';
	@override String get pageDefaultSize => 'Default page size';
	@override String get pageDefaultSizeHint => 'Rooms per page when a list opens; the pager can change it for now';
	@override String get pageSizeAuto => 'Automatic';
	@override String get itemsPerPage => 'items/page';
	@override String get pageSizeOptionsTitle => 'Page Size Options';
	@override String get pageSizeRestore => 'Restore recommended';
	@override String get pageSizeInputHint => '1–100';
	@override String get pageSizeRangeError => 'Enter a whole number from 1 to 100';
	@override String get pageSizeDuplicateError => 'That page size is already listed';
	@override String get pageSizeCurrent => 'Current active options';
	@override String get pageShowScrollTop => 'Show Scroll-to-Top Button';
	@override String get pageShowScrollTopSubtitle => 'Displays a floating button in the corner after scrolling a distance';
	@override String get pageShowSizeSelector => 'Show Page Size Selector';
	@override String get pageShowSizeSelectorSubtitle => 'Displays a dropdown menu for items per page in the control bar';
	@override String get pageShowGoto => 'Show Go-To Page Button';
	@override String get pageShowGotoSubtitle => 'Enables manual page number input for quick jumping';
	@override String get configPreviewDesc => 'Read-only view of the saved document';
	@override String get groupQuality => 'Quality';
	@override String get preferResolution => 'Preferred quality';
	@override String get preferResolutionDesc => 'The quality a room opens with';
	@override String get mobileQuality => 'Cellular quality';
	@override String get mobileQualityDesc => 'The default picture quality on mobile data';
	@override String get preferH264 => 'Prefer H.264';
	@override String get preferH264Desc => 'When a quality ships several codecs, start with the most compatible H.264; HEVC stays one manual tap away';
	@override String get videoFit => 'Picture fit';
	@override String get videoFitDesc => 'How the picture fills a box of another ratio (the in-room menu remembers its choice)';
	@override String get fitDefault => 'Default';
	@override String get fitCrop => 'Crop to fill';
	@override String get fitFillScreen => 'Stretch to screen';
	@override String get fitHeight => 'Fit height';
	@override String get fitWidth => 'Fit width';
	@override String get fitScaleDown => 'Scale down';
	@override String get groupPlayback => 'Playback behaviour';
	@override String get autoFullscreen => 'Auto fullscreen';
	@override String get autoFullscreenDesc => 'Enter fullscreen once the stream starts playing';
	@override String get blockList => 'Danmaku block list';
	@override String get blockListDesc => 'Keyword, user and regex blocks';
	@override String get groupAudience => 'Viewer counts';
	@override String get audienceMode => 'Which figure leads';
	@override String get audienceModeDesc => 'Whether the room shows the platform’s concurrent-online number or its heat';
	@override String get audienceModeHeat => 'Heat (popularity)';
	@override String get audienceModeOnline => 'Online viewers';
	@override String get audiencePlatforms => 'Platforms with a trusted online count';
	@override String audienceHeatOnlyCount({required Object count}) => 'The other ${count} platforms report heat only';
	@override String get portraitLiveSettings => 'Portrait stream adaptation';
	@override String get portraitLiveSettingsDesc => 'Detect the source orientation and shape the normal page, fullscreen and mini window alike';
	@override String get portraitGroupDetect => 'Detection & layout';
	@override String get portraitDetect => 'Detect portrait live sources';
	@override String get portraitDetectDesc => 'Recognised from the decoded frame size, and re-decided when the line or quality switches';
	@override String get portraitAdaptiveHeight => 'Adaptive height on the normal page';
	@override String get portraitAdaptiveHeightDesc => 'A tall source keeps the bigger watch area while the chat list keeps its room; off pins the panel at the middle stop';
	@override String get portraitLayoutMode => 'Normal-page layout';
	@override String get portraitLayoutModeDesc => 'Applies to portrait sources only; landscape rooms are untouched';
	@override String get portraitLayoutBalanced => 'Balanced (recommended)';
	@override String get portraitLayoutImmersive => 'Immersive';
	@override String get portraitLayoutCompatibility => 'Compatibility 16:9';
	@override String get portraitGroupPresentation => 'Fullscreen presentation';
	@override String get portraitFullscreenPolicy => 'Direction on entering fullscreen';
	@override String get portraitFullscreenPolicyDesc => 'Big and split-screen devices hand this to the system; a phone may follow the source';
	@override String get portraitFollowSource => 'Follow the source (recommended)';
	@override String get portraitFollowSystem => 'Follow the system';
	@override String get portraitAlwaysLandscape => 'Always landscape';
	@override String get portraitDisplayMode => 'Portrait-fullscreen canvas';
	@override String get portraitDisplayModeDesc => 'Only the upright fullscreen of a portrait stream; applies at once';
	@override String get portraitDisplayComplete => 'Complete picture';
	@override String get portraitDisplayAmbient => 'Ambient backdrop (recommended)';
	@override String get portraitDisplayBalanced => 'Balanced fill';
	@override String get portraitDisplayCover => 'Crop to fill';
	@override String get portraitDanmakuMode => 'Portrait danmaku band';
	@override String get portraitDanmakuModeDesc => 'Bounds the flying danmaku over a portrait picture without touching the global style numbers';
	@override String get portraitDanmakuFollowGlobal => 'Follow global';
	@override String get portraitDanmakuUpperQuarter => 'Top 25%';
	@override String get portraitDanmakuReduced => 'Reduced 50%';
	@override String get portraitDanmakuHidden => 'Hidden on portrait';
	@override String get portraitRemember => 'Remember a room’s direction';
	@override String get portraitRememberDesc => 'A direction picked by hand in the player is kept for the next visit to the same room';
	@override String get portraitGroupDiagnostics => 'Diagnostics';
	@override String get portraitDiagnostics => 'Show the detection state';
	@override String get portraitDiagnosticsDesc => 'Draw the raw size, ratio and the rule in force over the picture';
	@override String get portraitReset => 'Restore portrait defaults';
	@override String get portraitResetDesc => 'Including the remembered per-room direction overrides';
	@override String get portraitResetConfirm => 'Reset every portrait-adaptation setting to its default?';
	@override String get pipOnTop => 'Keep the mini player on top';
	@override String get pipOnTopDesc => 'When off, other applications can cover the mini player';
	@override String get miniRemember => 'Remember the mini window position';
	@override String get miniRememberDesc => 'The tile re-opens where it was left; off returns it to the corner each time';
	@override String get pauseOnTileClose => 'Pause when the tile closes';
	@override String get pauseOnTileCloseDesc => 'Closing the window while it is a PiP/mini tile restores and pauses the stream first — no audio left running behind a hidden window';
	@override String get splashAnimation => 'Start-up animation';
	@override String get splashAnimationDesc => 'Show the logo while the app starts';
	@override String get githubUpdates => 'Use the official GitHub update source';
	@override String get githubUpdatesDesc => 'Checks and downloads go straight to GitHub — for runs behind a proxy; off uses the mirrors';
	@override String get clipboardRooms => 'Recognise room links on the clipboard';
	@override String get clipboardRoomsDesc => 'When the app opens or resumes and the clipboard holds a room link, ask before entering; one link is asked once';
	@override String get startup => 'Start at sign-in';
	@override String get startupDesc => 'Launch automatically when you sign in';
	@override String get startupFailed => 'The system refused the autostart entry';
	@override String get closeWindow => 'When closing the window';
	@override String get closeWindowDesc => 'What the window\'s close button does';
	@override String get closeAsk => 'Ask every time';
	@override String get closeHide => 'Hide to the tray';
	@override String get closeMinimise => 'Minimise';
	@override String get closeQuit => 'Quit the app';
	@override String get sectionCache => 'Cache';
	@override String get currentCacheSize => 'Current cache size';
	@override String cacheSizeValue({required Object count}) => '${count} MB';
	@override String get cacheMeasuring => 'Measuring…';
	@override String get clearCache => 'Clear the picture cache';
	@override String get clearCacheDesc => 'Covers re-pull right after the clear';
	@override String cacheCleared({required Object count}) => 'Freed ${count} MB';
	@override String get cacheAutoClear => 'Auto-clear the picture cache';
	@override String get cacheAutoClearDesc => 'Empty the cache when a resume finds it past the cap';
	@override String get cacheLimit => 'Cache cap';
	@override String get refreshCoversNow => 'Refresh covers now';
	@override String get refreshCoversNowDesc => 'Empty the picture cache so every cover re-pulls on the next pass';
	@override String mbValue({required Object count}) => '${count} MB';
	@override String get groupCovers => 'Covers';
	@override String get autoRefreshThumbnails => 'Refresh covers automatically';
	@override String get autoRefreshThumbnailsDesc => 'Re-pull room covers on a timer so the pictures stay current';
	@override String get thumbnailRefreshInterval => 'Cover refresh interval';
	@override String get groupHistory => 'History';
	@override String get historyLimit => 'History size';
	@override String get historyLimitDesc => 'How many watched rooms are kept; 0 is no limit';
	@override String get noLimit => 'No limit';
	@override String get playerProxyGroup => 'Player proxy';
	@override String get playerProxyEnable => 'Enable the player proxy';
	@override String get playerProxyEnableDesc => 'Live streams are pulled through this proxy by the player, apart from the app\'s own requests';
	@override String get playerProxyHint => 'Applies to the next stream; a running one keeps what it started with';
	@override String get thumbnailKeepOldFiles => 'Keep old thumbnails';
	@override String get thumbnailKeepOldFilesDesc => 'Superseded covers stay until the cache policy drops them; off clears what is past two intervals';
	@override String get localPreset => 'Line style';
	@override String get localPresetClean => 'Clean';
	@override String get localPresetHighlight => 'Highlight';
	@override String get localPresetNeon => 'Neon';
	@override String get localPresetMinimal => 'Minimal';
	@override String localLevel({required int level, required int into, required int total}) => 'Level ${level} · ${into}/${total}';
	@override String get localGiftBanner => 'Gift banner';
	@override String get localGiftBannerDesc => 'Raise a gift card over the picture when you send one';
	@override String get backgroundPlay => 'Background playback';
	@override String get backgroundPlayDesc => 'Keep playing in the background; off pauses on the way out and resumes on return';
	@override String get liveAlertScope => 'Alert scope';
	@override String get liveAlertScopeDesc => 'Alert only for follows carrying a chosen tag; none chosen alerts every follow';
	@override String get liveAlertAll => 'All follows';
	@override String get refreshConcurrency => 'Parallel refresh jobs';
	@override String get refreshConcurrencyHint => 'How many followed rooms refresh at once';
	@override String get screenKeepOn => 'Keep the screen on';
	@override String get screenKeepOnDesc => 'Stop the screen from sleeping while a room plays';
	@override String get preferredPlatform => 'Preferred platform';
	@override String get preferredPlatformDesc => 'Popular, areas and search open on this platform';
	@override String get preferredPlatformNone => 'Platform order';
}

// Path: hotAreas
class _Translations$hotAreas$en extends Translations$hotAreas$zh {
	_Translations$hotAreas$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get title => 'Platform visibility';
	@override String get note => 'Hidden platforms are left out of popular, areas and search.';
	@override String get orderNote => 'Drag to reorder the platforms.';
	@override String get visible => 'Visible';
	@override String get hidden => 'Hidden';
	@override String get restore => 'Restore defaults';
	@override String get keepAtLeastOne => 'Keep at least one platform';
}

// Path: tags
class _Translations$tags$en extends Translations$tags$zh {
	_Translations$tags$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get title => 'Tags';
	@override String get add => 'New tag';
	@override String get name => 'Tag name';
	@override String get rename => 'Rename';
	@override String get delete => 'Delete';
	@override String deleteConfirm({required Object name}) => 'Delete "${name}"? Its rooms stay followed.';
	@override String get pin => 'Pin to top';
	@override String get unpin => 'Unpin';
	@override String get pinned => 'Pinned';
	@override String get empty => 'No tags yet';
	@override String get emptyHint => 'Long-press a followed room to add it to a tag.';
	@override String countValue({required int count}) => '${count} tags';
	@override String get nameEmpty => 'Name cannot be empty';
	@override String get nameTaken => 'A tag with this name already exists';
}

// Path: logs
class _Translations$logs$en extends Translations$logs$zh {
	_Translations$logs$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get title => 'Logs';
	@override String get level => 'Log level';
	@override String get levelHint => 'Lower levels record more; the choice persists across launches.';
	@override String get levelTrace => 'Everything (trace)';
	@override String get levelDebug => 'Detailed (debug)';
	@override String get levelInfo => 'Regular (info)';
	@override String get levelWarning => 'Warnings (warning)';
	@override String get levelError => 'Errors (error)';
	@override String get levelFatal => 'Fatal only';
	@override String get levelOff => 'Off';
	@override String get levelDefault => 'Follow build default';
	@override String get export => 'Export recent logs';
	@override String exportDone({required int count}) => 'Copied ${count} log lines to the clipboard';
	@override String get exportEmpty => 'No logs in memory yet';
	@override String get openFolder => 'Open log folder';
	@override String get note => 'Log files live under the logs directory and rotate.';
}

// Path: recorder
class _Translations$recorder$en extends Translations$recorder$zh {
	_Translations$recorder$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get title => 'Recorder';
	@override String get addRoom => 'Add room';
	@override String get platform => 'Platform';
	@override String get roomId => 'Room ID';
	@override String get startWatching => 'Start watching';
	@override String get watchStarted => 'Watching; recording starts when the room goes live';
	@override String watchFailed({required String error}) => 'Watching failed: ${error}';
	@override String get noSites => 'No platform here can look rooms up';
	@override String get openFolder => 'Open output folder';
	@override String get folderNotOpened => 'The folder could not be opened';
	@override String get outputDirectory => 'Output directory';
	@override String get outputDirectoryDefault => 'The app\'s recordings folder';
	@override String get chooseDirectory => 'Choose the recordings folder';
	@override String get segmentLength => 'Segment length';
	@override String minutesValue({required int minutes}) => '${minutes} min';
	@override String segmentsValue({required int count}) => '${count} segments';
	@override String get restoring => 'Finishing the previous run’s recordings…';
	@override String engineFailed({required String error}) => 'The recording engine failed to start: ${error}';
	@override String get filterAll => 'All';
	@override String get filterActive => 'Active';
	@override String get filterWaiting => 'Waiting';
	@override String get filterSaved => 'Saved';
	@override String get filterFailed => 'Failed';
	@override String get recordSettings => 'Recording settings';
	@override String get filterFinished => 'Finished';
	@override String get emptyTitle => 'No rooms watched yet';
	@override String get emptySubtitle => 'Add a room and it is recorded once it goes live';
	@override String get nothingToJoin => 'Nothing to join yet';
	@override String get actionStop => 'Stop';
	@override String get actionFinishNow => 'Join now';
	@override String get actionRestart => 'Record again';
	@override String get statusQueued => 'Queued';
	@override String get statusResolving => 'Resolving';
	@override String get statusRecording => 'Recording';
	@override String get statusRetrying => 'Reconnecting';
	@override String get statusMerging => 'Joining';
	@override String get statusCompleted => 'Completed';
	@override String get statusFailed => 'Failed';
	@override String get statusStopped => 'Stopped';
	@override String get statusInterrupted => 'Interrupted';
	@override String get roomUnknown => 'Not asked yet';
	@override String get roomWaiting => 'Waiting for the stream';
	@override String get roomLive => 'Live now';
	@override String get roomEnded => 'Broadcast ended';
	@override String get roomStalled => 'Signal stalled';
	@override String get roomUnavailable => 'Room unavailable';
	@override String get groupDefaults => 'Recording defaults';
	@override String get defaultQuality => 'Default recording quality';
	@override String get defaultQualityDesc => 'When the room offers several qualities, record the address labelled with it; the best line when none is labelled.';
	@override String get usePinyinFolder => 'Name folders in pinyin';
	@override String get usePinyinFolderDesc => 'On: the anchor folder is pinyin (zhubo8891). Off: the room id, the safest component.';
	@override String get recordDanmaku => 'Save the chat';
	@override String get recordDanmakuDesc => 'Writes a chat file beside each recording; a chat that cannot connect never costs the recording.';
	@override String get recordDanmakuGifts => 'Include gifts in the saved chat';
	@override String get recordDanmakuGiftsDesc => 'The chat file also carries gifts and super chats.';
	@override String get groupFiles => 'Recording files';
	@override String get recordSizeLimit => 'Recording size limit';
	@override String get recordSizeLimitDesc => 'Delete the oldest recordings (older than an hour) when the folder passes the cap.';
	@override String get recordSizeCap => 'Size cap';
	@override String get recordUsedSpace => 'Used space';
	@override String get recordUsedSpaceDesc => 'Tap to re-measure the recordings folder.';
	@override String get clearAllCache => 'Clear all recordings';
	@override String get clearAllCacheDesc => 'Delete every video file in the recordings folder; the hour’s newest stay.';
	@override String clearFreed({required Object mb}) => 'Freed ${mb} MB';
	@override String mbValue({required Object count}) => '${count} MB';
	@override String get groupPerformance => 'Performance & quality';
	@override String get preferBestStream => 'Record the first stream only';
	@override String get preferBestStreamDesc => 'Map only the first video and audio track of a multi-track container.';
	@override String get rwTimeout => 'Read/write timeout';
	@override String get rwTimeoutDesc => 'A silent input fails the read after this long and the retry path takes over.';
	@override String get queueSize => 'Input queue size';
	@override String get queueSizeDesc => 'Recording favours completeness over latency, so the queue is much larger than a player’s.';
	@override String get segmentLengthDesc => 'Shorter segments lose less to a crash and cost more overhead.';
	@override String get maxRecordTasks => 'Concurrent recording tasks';
	@override String get maxRecordTasksDesc => 'How many rooms may record at once; each is one FFmpeg process.';
	@override String get groupReconnect => 'Auto reconnect';
	@override String get autoReconnectSwitch => 'Auto reconnect';
	@override String get autoReconnectDesc => 'Retry an interrupted capture; off ends the session at the drop.';
	@override String get maxRetryCount => 'Max retries';
	@override String get retryDelay => 'Retry delay';
	@override String timesValue({required int count}) => '${count} times';
	@override String secondsValue({required int count}) => '${count} s';
	@override String get groupLiveCheck => 'Live check';
	@override String get enablePolling => 'Check for the first broadcast';
	@override String get enablePollingDesc => 'Re-check rooms that are not up yet and start recording the moment they are.';
	@override String get checkInterval => 'Check interval';
	@override String get enableBackoff => 'Grow the interval';
	@override String get enableBackoffDesc => 'Double the wait after each still-offline answer to spare the API.';
	@override String get maxCheckInterval => 'Interval ceiling';
	@override String get autoStartBoot => 'Resume recordings when the app starts';
	@override String get autoStartBootDesc => 'Waiting and interrupted tasks re-arm themselves on launch.';
	@override String get decrease => 'Decrease';
	@override String get increase => 'Increase';
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
	@override String get danmakuFailed => 'Danmaku connection failed';
	@override String get quality => 'Quality';
	@override String get line => 'Line';
	@override String get play => 'Play';
	@override String get pause => 'Pause';
	@override String get failed => 'Playback failed — try again';
	@override String get replay => 'Replay';
	@override String get offline => 'Offline';
	@override String get entryFailed => 'Could not open this room';
	@override String get chat => 'Chat';
	@override String get superChat => 'Super Chat';
	@override String get gifts => 'Gifts';
	@override String get shield => 'Danmaku shield';
	@override String get danmakuEnded => 'Danmaku connection closed';
	@override String get reconnecting => 'Danmaku reconnecting…';
	@override String get sendPlaceholder => 'Say something…';
	@override String get sendUnavailable => 'Sending needs a signed-in platform account (not wired up yet)';
	@override String get backToLive => 'Back to live';
	@override String newMessages({required Object count}) => '${count} new messages';
	@override String get superChatEmpty => 'No super chats yet';
	@override String get superChatEmptyHint => 'Highlighted paid messages land here while viewers cheer';
	@override String get giftsEmpty => 'No gifts yet';
	@override String get giftsEmptyHint => 'Gift events from the room\'s stream appear here';
	@override String get follow => 'Follow';
	@override String get followed => 'Following';
	@override String followers({required Object count}) => '${count} followers';
	@override String get popularity => 'Popularity';
	@override String get online => 'Online';
	@override String lineN({required Object n}) => 'Line ${n}';
	@override String get fullscreen => 'Fullscreen';
	@override String get lock => 'Lock screen';
	@override String get unlock => 'Unlock screen';
	@override String get videoFit => 'Aspect ratio';
	@override String get fitContain => 'Fit';
	@override String get fitCover => 'Cover';
	@override String get fitFill => 'Stretch';
	@override String get exitFullscreen => 'Exit fullscreen';
	@override String get barrageOn => 'Show danmaku';
	@override String get barrageOff => 'Hide danmaku';
	@override String get toolbox => 'Toolbox';
	@override String get copyLink => 'Copy room link';
	@override String get linkCopied => 'Copied';
	@override String get shareCode => 'Copy share code';
	@override String get shareCodeCopied => 'Share code copied — paste it back to open this room';
	@override String get shareCodeFailed => 'The room is not named well enough to share by code';
	@override String get record => 'Record';
	@override String get stopRecording => 'Stop recording';
	@override String get rateNormal => 'Normal speed';
	@override String get audienceWaiting => 'Waiting for audience data';
	@override String get mute => 'Mute';
	@override String get unmute => 'Unmute';
	@override String get danmakuOn => 'Danmaku on';
	@override String get sleepTimer => 'Sleep timer';
	@override String get sleepTimerOn => 'Sleep timer (on)';
	@override String get sleepTimerEnable => 'Enable the playback timer';
	@override String get sleepTimerDesc => 'Pauses this room\'s playback when it runs out';
	@override String get timerDuration => 'Timer duration';
	@override String get timerDurationHint => '1 - 525600 minutes';
	@override String get timerInvalid => 'Enter minutes between 1 and 525600';
	@override String get timerFinished => 'Playback timer finished — paused';
	@override String get minutesUnit => 'min';
	@override String minutesN({required Object minutes}) => '${minutes} min';
	@override String get roomVolume => 'Room volume';
	@override String get roomVolumeDesc => 'The mute and the per-device default levels';
	@override String get globalMute => 'Global mute';
	@override String get globalMuteSubtitle => 'Rooms open silenced; the level is kept';
	@override String get mobileDefaultVolume => 'Phone default volume';
	@override String get desktopDefaultVolume => 'Desktop default volume';
	@override String get resetDefault => 'Reset defaults';
	@override String get volumeApplyFailed => 'The active room refused the volume update';
	@override String get send => 'Send';
	@override String get localMe => 'Me';
	@override String get barrageSettings => 'Barrage settings';
	@override String get keywordBlock => 'Keyword block';
	@override String get barrageHiddenHint => 'Barrage is globally off';
	@override String get barrageOnSubtitle => 'Scroll the barrage over the picture';
	@override String get barrageFontSize => 'Barrage text size';
	@override String get barrageOpacity => 'Barrage opacity';
	@override String get barrageSettingsNote => 'Applies immediately and is the default for new rooms';
	@override String get enterLandscapeFullscreen => 'Landscape fullscreen';
	@override String get enterPortraitFullscreenHint => 'Drag down to enter portrait fullscreen';
	@override String get portraitPanelResize => 'Panel height';
	@override String get portraitPanelResizeHint => 'Drag to resize the panel';
	@override String get pip => 'Picture-in-picture';
	@override String get exitPip => 'Exit picture-in-picture';
	@override String get miniWindow => 'Floating mini window';
	@override String get exitMiniWindow => 'Exit the mini window';
	@override String get messageActions => 'Danmaku';
	@override String get copyMessage => 'Copy';
	@override String get copiedToClipboard => 'Copied to clipboard';
	@override String get blockViewer => 'Block this viewer';
	@override String blockViewerDesc({required Object name}) => 'Messages from ${name} are no longer shown';
	@override String userBlocked({required Object name}) => 'Blocked ${name}';
	@override String get blockWord => 'Block a keyword…';
	@override String get blockWordDesc => 'Enter a word; messages containing it are no longer shown';
	@override String get keywordBlocked => 'Keyword added to the danmaku block list';
	@override String userLevel({required Object level}) => 'Level ${level}';
	@override String get blockKeywordTitle => 'Block a danmaku keyword';
	@override String get block => 'Block';
	@override String get portraitFullscreenRestoreHint => 'Portrait fullscreen — swipe up to bring the danmaku bar back';
	@override String get gift => 'Send a gift';
	@override String get sentGift => 'sent';
	@override String autoReconnecting({required int count}) => 'Reconnecting (attempt ${count})';
}

// Path: areas
class _Translations$areas$en extends Translations$areas$zh {
	_Translations$areas$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get followedAreas => 'Followed areas';
	@override String get empty => 'No areas here';
	@override String get followEmpty => 'No followed areas yet';
	@override String get followEmptyHint => 'Open an area and follow it with the button in its top-right corner.';
	@override String followDone({required String name}) => 'Following ${name}';
	@override String unfollowDone({required String name}) => 'Unfollowed ${name}';
}

// Path: popular
class _Translations$popular$en extends Translations$popular$zh {
	_Translations$popular$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get allPlatforms => 'All platforms';
	@override String get allPlatformsHint => 'Tap to switch; platform settings hide and order them.';
	@override String get noPlatforms => 'No platforms to show';
	@override String get noPlatformsHint => 'Enable at least one platform in platform settings.';
	@override String get empty => 'Nothing live right now';
}

// Path: history
class _Translations$history$en extends Translations$history$zh {
	_Translations$history$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String countOfLimit({required int count, required int limit}) => '${count} / ${limit} entries';
	@override String countUnlimited({required int count}) => '${count} entries';
	@override String get filterOpen => 'Filter';
	@override String get filterClose => 'Close filter';
	@override String get filterHint => 'Filter by title or streamer';
	@override String filterMatches({required int count}) => '${count} matches';
	@override String get filterEmpty => 'No history entries match';
	@override String get refreshStatus => 'Refresh watch status';
	@override String refreshDone({required int count}) => 'Refreshed ${count} entries';
	@override String refreshPartial({required int failed, required int count}) => '${failed} of ${count} failed to refresh';
	@override String get refreshSaveFailed => 'Saving the refreshed history failed';
	@override String get limitTitle => 'History limit';
	@override String get limitHint => '0 keeps everything; older entries beyond the limit are deleted.';
	@override String get removed => 'Entry removed';
	@override String cleared({required int count}) => 'Cleared ${count} entries';
	@override String get clear => 'Clear history';
	@override String get resume => 'Resume';
	@override String get clearConfirm => 'Clear the whole watch history? This cannot be undone.';
	@override String get empty => 'Nothing watched yet';
	@override String get today => 'Today';
	@override String get yesterday => 'Yesterday';
	@override String get thisWeek => 'This week';
	@override String get thisMonth => 'This month';
	@override String get earlier => 'Earlier';
	@override String get remove => 'Remove entry';
	@override String get removeConfirm => 'Remove this watch record?';
}

// Path: iptv
class _Translations$iptv$en extends Translations$iptv$zh {
	_Translations$iptv$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get epgTitle => 'Guides';
	@override String get title => 'IPTV';
	@override String get addSource => 'Add source';
	@override String get sourceName => 'Source name';
	@override String get sourceUrl => 'Playlist URL (M3U/TXT)';
	@override String get deleteSource => 'Delete this source? Its channels go too';
	@override String imported({required int count}) => 'Imported ${count} channels';
	@override String get allGroups => 'All groups';
	@override String get favorite => 'Favorite';
	@override String get empty => 'No source imported yet';
	@override String get search => 'Search channels';
	@override String get favoritesOnly => 'Favorites only';
	@override String get noMatch => 'No channels match';
	@override String get channels => 'Channel list';
	@override String get switchChannel => 'Switch channel';
	@override String get dialPad => 'Number pad';
	@override String noNumber({required int number}) => 'No channel ${number}';
	@override String get importFromFile => 'Import from file';
	@override String get importFailed => 'Import failed';
	@override String lineOf({required int index, required int total}) => 'Line ${index}/${total}';
	@override String get kindPlaylist => 'M3U / TXT';
	@override String get kindXtream => 'Xtream';
	@override String get xtreamServer => 'Server URL (http://host:port)';
	@override String get xtreamUsername => 'Username';
	@override String get xtreamPassword => 'Password';
	@override String get epgUrl => 'EPG URL (optional)';
	@override String get xtreamAuthFailed => 'The server rejected these credentials';
	@override String get refreshSource => 'Refresh this source';
	@override String get epgNow => 'Now';
	@override String get epgNext => 'Next';
	@override String get refreshEpg => 'Refresh programme guide';
	@override String get hotChannels => 'Hot channels';
	@override String get viewAll => 'View all';
	@override String get liveNow => 'Live';
	@override String get prevChannel => 'Previous channel';
	@override String get channelList => 'Channel list';
	@override String get playbackSettings => 'Playback settings';
	@override String get lineSelect => 'Select line';
	@override String get numberPad => 'Number pad';
	@override String get refreshGuide => 'Refresh guide';
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
	@override String get factoryDefault => 'Factory default';
	@override String get cloudFonts => 'Cloud fonts';
	@override String get custom => 'Custom fonts';
	@override String get customDesc => 'Pick a ttf, otf or ttc font file from this device';
	@override String get import => 'Import a font file';
	@override String get importFailed => 'That file could not be imported';
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
	@override String get liveRoom => 'Live';
	@override String get replayRoom => 'Replays';
	@override String get offlineRoom => 'Offline';
	@override String get emptyLive => 'No followed rooms are live';
	@override String get emptyReplay => 'No replay follows';
	@override String get emptyOffline => 'No offline follows';
	@override String get showOffline => 'View offline';
	@override String refreshFailed({required int count}) => '${count} rooms failed to refresh';
	@override String get newGroup => 'New group';
	@override String get manageGroups => 'Manage groups';
	@override String get renameGroup => 'Rename group';
	@override String get deleteGroup => 'Delete group';
	@override String get deleteGroupConfirm => 'Deleting a group leaves followed rooms untouched. Delete?';
	@override String get assign => 'Move to groups';
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
	@override String get roomJump => 'Jump to Room';
	@override String get linkJump => 'Open Link';
	@override String get directLink => 'Get Direct Link';
	@override String get parse => 'Parse Link';
	@override String get inputHint => 'Paste platform link here...';
	@override String get supportList => 'Supported Platforms';
	@override String get supportContent => 'Supported link formats:\n\nBilibili:\nhttps://live.bilibili.com/xxxxx\nhttps://www.bilibili.com/xxxxx\nhttps://b23.tv/xxxxx\n\nHuya:\nhttps://www.huya.com/xxxxx\n\nDouyu:\nhttps://www.douyu.com/xxxxx\n\nDouyin Live/Video:\nhttps://live.douyin.com/xxxxx\nhttps://www.douyin.com/xxxxx\nhttps://v.douyin.com/xxxxx\nhttps://webcast.amemv.com/douyin/webcast/reflow/xxxxx\n\nKuaishou Live:\nhttps://live.kuaishou.com/u/xxxxx\nhttps://live.kuaishou.cn/u/xxxxx\n\nNetEase CC:\nhttps://cc.163.com/xxxxx\n\nTwitch:\nhttps://www.twitch.tv/xxxxx\nhttps://twitch.tv/xxxxx\n\nSOOP Live:\nhttps://www.sooplive.com/xxxxx\nhttps://sooplive.com/xxxxx\nhttps://play.sooplive.com/xxxxx\nhttps://www.sooplive.co.kr/xxxxx\nhttps://sooplive.co.kr/xxxxx\nhttps://play.sooplive.co.kr/xxxxx\n\nYY Live:\nhttps://www.yy.com/xxxxx\nhttps://yy.com/xxxxx\nhttps://www.yy.com/xxxxx/xxxxx?tempId=xxxxx\nhttps://yy.com/xxxxx/xxxxx?tempId=xxxxx\n\nAcFun Live:\nhttps://live.acfun.cn/live/123456\n\nPicarto:\nhttps://picarto.tv/ChannelName\n\nTwitCasting:\nhttps://twitcasting.tv/ChannelName\nhttps://twitcasting.tv/c:ChannelName\n\nCHZZK:\nhttps://chzzk.naver.com/live/0123456789abcdef0123456789abcdef\n\nKick:\nhttps://kick.com/ChannelName\n\n17LIVE:\nhttps://17.live/en/live/1234567';
	@override String get emptyLink => 'Link cannot be empty';
	@override String get parseFailed => 'Unable to parse this link';
	@override String get getUrlFailed => 'Failed to get direct link';
	@override String get selectQuality => 'Select Quality';
	@override String get selectLine => 'Select Line';
	@override String line({required int index}) => 'Line ${index}';
	@override String get detectLink => 'Link Detected';
	@override String get autoFill => 'Live link from clipboard has been auto-filled';
	@override String get copySuccess => 'Direct link copied';
}

// Path: backup
class _Translations$backup$en extends Translations$backup$zh {
	_Translations$backup$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get title => 'Backup & restore';
	@override String get create => 'Create backup';
	@override String get restoreFile => 'Restore from file';
	@override String get existing => 'Existing backups';
	@override String get none => 'No backups yet';
	@override String get delete => 'Delete backup';
	@override String get restore => 'Restore';
	@override String restoreConfirm({required String name}) => 'Overwrite current data with “${name}”? The app restarts.';
	@override String get sectionCloud => 'Cloud & sync';
	@override String get devicesGroup => 'Cloud and other devices';
	@override String get localGroup => 'Local backup';
	@override String get createSubtitle => 'Saves a full copy of the app data (settings, follows, history and more)';
	@override String get restoreFileSubtitle => 'Restore from a backup file; the app restarts afterwards';
	@override String get filesTitle => 'Backups in the folder';
	@override String filesCount({required Object count}) => 'Backups in the folder · ${count}';
	@override String get filesEmpty => 'No backups yet';
	@override String get filesHint => 'Backups made here are listed; you can also drop backup files into this folder';
	@override String get filesError => 'The backup folder cannot be read';
	@override String get retry => 'Retry';
	@override String get loading => 'Reading…';
	@override String get kindFull => 'Full backup';
	@override String get directoryGroup => 'Backup Directory';
	@override String get directory => 'Backup directory';
	@override String get directoryDefaultLabel => 'Backup folder (default)';
	@override String get directoryDefault => 'The app\'s default folder';
	@override String get chooseDirectory => 'Choose the backup folder';
	@override String get resetDirectory => 'Use the default folder';
	@override String get openDirectory => 'Open the backup folder';
	@override String get directoryUnwritable => 'This folder cannot be written; pick another one';
	@override String get directoryUpdateFailed => 'The backup directory was not changed. Try again.';
	@override String deleteConfirm({required Object name}) => 'Delete the backup file "${name}"?';
	@override String created({required Object name}) => 'Backed up to ${name}';
	@override String get readFailed => 'The backup file cannot be read';
	@override String restored({required Object name}) => 'Restored ${name}';
	@override String get moreActions => 'More actions';
	@override String get fileTooltip => 'Click to restore; right-click or ⋮ for more';
	@override String get previewTitle => 'Restore preview';
	@override String previewRooms({required Object current, required Object incoming}) => 'Followed rooms: ${current} → ${incoming}';
	@override String previewGroups({required Object current, required Object incoming}) => 'Follow groups: ${current} → ${incoming}';
	@override String get previewNote => 'Everything else stays as it is.';
	@override String get restoreNow => 'Restore now';
	@override String get followsScopeHint => 'Followed rooms and groups only; other settings stay unchanged';
	@override String get kindFollows => 'Follows only';
	@override String get deleteFailed => 'The file could not be deleted';
}

// Path: about
class _Translations$about$en extends Translations$about$zh {
	_Translations$about$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get native => 'This device';
	@override String downloadFilesOf({required Object platform}) => 'Downloads · ${platform}';
	@override String get title => 'About';
	@override String get group => 'About';
	@override String get checkUpdate => 'Check for updates';
	@override String get onlineUpdate => 'Online Update';
	@override String get versionUpdate => 'Version Update';
	@override String get updateLog => 'Update Log';
	@override String get upToDate => 'Up to date';
	@override String get newVersion => 'New version available:';
	@override String get noNewVersion => 'You are using the latest version.';
	@override String get openSourceFree => 'This app is open source and free';
	@override String get update => 'Update';
	@override String get refresh => 'Refresh';
	@override String get versionHistory => 'Version history';
	@override String get historyDesc => 'Update history records';
	@override String publishedAt({required String date}) => 'Published at ${date}';
	@override String get openRelease => 'Open release page';
	@override String get licenses => 'License';
	@override String get project => 'Project page';
	@override String get projectSection => 'Project';
	@override String get projectAlert => 'Project Alert';
	@override String get legalese => '© 2026 PureLive Open-Source Project. This program is a pure local client application that directly requests the official public APIs of media platforms. The project itself does not store, host, reproduce, or distribute any audio/video resources. The developer solemnly pledges that this application does not collect, process, or retain any user personal data or privacy information. All operational parameters, local configurations, and synchronized metadata are exclusively retained and controlled by the end-user. Users shall assume all legal responsibilities arising from the use of this testing tool.';
	@override String get browserNotOpened => 'The system browser did not open. Check the default browser settings.';
	@override String get checkRunning => 'Checking…';
	@override String get checkFailed => 'Check failed — tap to retry';
	@override String get downloadFiles => 'Download files';
	@override String get copyLink => 'Copy link';
	@override String get copied => 'Link copied';
	@override String get download => 'Download';
	@override String assetMeta({required String size, required int count}) => '${size} · ${count} downloads';
	@override String startupUpdateBody({required Object tag}) => 'Version ${tag} is out. Open the update page now?';
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
	@override String get keywordHint => 'Keyword to block';
	@override String get emptyKeyword => 'Type a keyword first';
}

// Path: multiview
class _Translations$multiview$en extends Translations$multiview$zh {
	_Translations$multiview$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get title => 'Multi-view';
	@override String get platform => 'Platform';
	@override String get roomId => 'Room ID';
	@override String get add => 'Add cell';
	@override String get layout => 'Layout';
	@override String get pickRoom => 'Choose a room';
	@override String get pickHint => 'Paste a room link or pick a followed room';
	@override String get emptyCell => 'Tap to choose a room';
	@override String get mute => 'Mute';
	@override String get unmute => 'Unmute';
	@override String get muteAll => 'Mute all';
	@override String get unmuteAll => 'Unmute all';
	@override String get audioFocus => 'Playing sound';
	@override String get removeCell => 'Remove cell';
	@override String get noPick => 'No followed rooms or history yet';
}

// Path: search
class _Translations$search$en extends Translations$search$zh {
	_Translations$search$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get hint => 'Search rooms by keyword';
	@override String get rooms => 'Rooms';
	@override String get anchors => 'Anchors';
	@override String get areas => 'Categories';
	@override String get allSites => 'All';
	@override String get historyTitle => 'Recent searches';
	@override String get historyRemove => 'Remove this search';
	@override String get webSearch => 'Web search';
	@override String get webSearchTooltip => 'Web-search the current platform';
	@override String get continueWeb => 'Continue in web search';
	@override String get selectPlatformFirst => 'Pick a platform first';
	@override String get needKeyword => 'Type a keyword first';
	@override String webUnavailableFor({required Object site}) => '${site} has no web search page.';
	@override String get webExternalTip => 'The web search opens in the system browser. Find the live room you want, copy its link, and paste it into the search box to open it here.';
	@override String get openInSystemBrowser => 'Open in system browser';
	@override String get externalBrowserNotOpened => 'The system browser did not open; check the default-browser settings';
	@override String get webSearchRoomBanner => 'This is a live room';
	@override String roomIdLabel({required String roomId}) => 'room ${roomId}';
	@override String get roomEnter => 'Enter';
	@override String get webSearchRoomDismiss => 'Stop offering this room';
	@override String get webSearchInvalidAddress => 'The web-search address is invalid; go back to the search page and try again.';
	@override String get webSearchLoadFailed => 'The page failed to load; check the network or proxy and retry.';
	@override String get webSearchUnavailableTitle => 'Web search unavailable';
	@override String get sortMode => 'Sort';
	@override String get sortSmart => 'Smart';
	@override String get sortPlatform => 'By platform';
	@override String get sortAudience => 'By viewers';
	@override String get sortFollowers => 'By followers';
	@override String get includeOffline => 'Show offline';
}

// Path: remoteSync
class _Translations$remoteSync$en extends Translations$remoteSync$zh {
	_Translations$remoteSync$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get title => 'Device Sync';
	@override String get tileSubtitle => 'Sync configurations between devices over the LAN';
	@override String get myDevice => 'My Device';
	@override String get noAddress => 'No LAN address found';
	@override String get scanHint => 'Let the other device scan this code, or type this device’s address there';
	@override String get running => 'Sync service running';
	@override String get notRunning => 'Sync service is not running';
	@override String get start => 'Start';
	@override String get stop => 'Stop';
	@override String get devices => 'Discovered Devices';
	@override String get noDevices => 'No other devices found';
	@override String get manual => 'Manual Input';
	@override String get send => 'Send Settings';
	@override String get receive => 'Receive Settings';
	@override String get sendSuccess => 'Sent';
	@override String get sendFailed => 'Send failed — check the address and whether the other device confirmed';
	@override String get receiveSuccess => 'Received and applied';
	@override String get receiveFailed => 'Receive failed';
	@override String get enterAddress => 'Enter the other device’s address first';
	@override String get invalidAddress => 'That is not a valid address';
	@override String incomingImport({required String address}) => '${address} wants to overwrite this device’s follows, history and shield. Allow?';
	@override String incomingExport({required String address}) => '${address} wants to read this device’s follows, history and shield. Allow?';
	@override String get sectionFavorite => 'Followed rooms';
	@override String get sectionHistory => 'Watch history';
	@override String get sectionGroups => 'Follow groups';
	@override String get noAddressHint => 'Connect to Wi-Fi or a wired network; on Android allow the "Nearby devices / local network" permission, then tap Start at the top right';
	@override String get description => 'Make sure both devices are connected to the same local network';
	@override String get searching => 'Searching for devices on the local network...';
	@override String get searchingShort => 'Searching';
	@override String get manualHint => 'Type the other device\'s address, or paste its QR code\'s sync link (it carries the pairing code)';
	@override String get copyAddress => 'Copy Address';
	@override String get addressCopied => 'Address copied';
	@override String fromName({required String name}) => 'From ${name}';
	@override String get legacyDevice => 'Pure Live 3.x device';
	@override String get allow => 'Allow';
	@override String get reject => 'Reject';
	@override String incomingImportNamed({required Object address, required Object name}) => '${address} (${name}) asks to replace this device’s settings with its own. Allow?';
	@override String incomingExportNamed({required Object address, required Object name}) => '${address} (${name}) asks to read this device’s settings. Allow?';
	@override String get pairingCode => 'Pairing code';
	@override String pairingCodeFor({required String name}) => 'Enter the 6-digit pairing code shown on “${name}”';
	@override String get pairingCodeInvalid => 'The pairing code should be 6 digits';
	@override String get partsAll => 'Select all';
	@override String get partsLegacy => 'The other device is version 3.x or earlier (or did not answer), so it can only receive everything.';
	@override String partsSendNamed({required String name}) => 'Tick what to send to “${name}”. After it confirms, the ticked parts replace its own; unticked parts stay.';
	@override String confirmSendNamed({required String name}) => 'Send this device\'s full configuration to “${name}”? Its user confirms, and it replaces the other device\'s.';
	@override String get previewTitle => 'Receiving would change this:';
	@override String previewSettings({required int count, required int changed}) => 'Settings: ${count} items, ${changed} differ from this device';
	@override String get previewNoAccounts => 'Accounts: the other device left “Sync account cookies” off; this device\'s sign-ins stay';
	@override String get previewAccountsEmpty => 'Accounts: the other device has no sign-ins; this device\'s stay as they are';
	@override String get previewWarning => 'Receiving merges the ticked parts; unticked ones stay. Settings follow the other device and cannot be undone — create a backup under “Backup & restore” first if needed.';
	@override String partCount({required String part, required int count}) => '${part} (${count})';
	@override String get partSettings => 'Settings';
	@override String get partFollows => 'Follow list';
	@override String get partHistory => 'Watch history';
	@override String get partGroups => 'Follow groups';
	@override String get partKeywords => 'Blocked keywords';
	@override String get partUsers => 'Blocked users';
	@override String get partWebdav => 'WebDAV servers';
	@override String get partAccounts => 'Account cookies';
	@override String get includeAccounts => 'Sync account cookies';
	@override String get includeAccountsHint => 'Sends or serves the platform login cookies and WebDAV passwords; turn it on only between devices you trust';
	@override String get receiveAction => 'Receive';
	@override String get sendAction => 'Send';
	@override String get invalidQr => 'Not a PureLive sync QR code';
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
	@override String get favorites => 'Favorites';
	@override String get follow => 'Follow';
	@override String get history => 'History';
	@override String get popular => 'Popular';
	@override String get areas => 'Areas';
	@override String get search => 'Search';
	@override String get settings => 'Settings';
	@override String get record => 'Recordings';
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
	@override String get titleBarAuto => 'Auto (by Windows version)';
	@override String get titleBarApp => 'App title bar';
	@override String get titleBarSystem => 'System title bar';
	@override String get titleBarHint => 'Auto: the app title bar on Windows 11, the system title bar on Windows 10. The app title bar is drawn by Pure Live; the system title bar is the native Windows one. A switch applies after the app restarts.';
	@override String get frameDiagnosis => 'Window frame diagnosis';
	@override String get frameTakeover => 'Frame takeover';
	@override String get frameTakeoverOn => 'On — the caption is gone and the window\'s own hit-test answers the four edges';
	@override String get frameTakeoverOff => 'Off — the system draws the caption and sizes the window';
	@override String get frameEdge => 'Frame edge';
	@override String get frameEdgeNative => 'Windows draws it';
	@override String get frameEdgeNone => 'This Windows version draws none, so a taken-over window has no line on any side';
	@override String get frameBuild => 'Windows build';
	@override String get frameSweep => 'Run the resize sweep';
	@override String get frameSweepRunning => 'Sweeping…';
	@override String get frameSweepHint => 'Resizes this window repeatedly, twice, then puts it back. The two lines compare the plugin\'s view pre-sync off and on — fewer stale frames on the second line is the frame keeping up with the drag.';
	@override String get frameSweepUnavailable => 'The sweep needs the frame takeover on, on Windows.';
}

// Path: webdav
class _Translations$webdav$en extends Translations$webdav$zh {
	_Translations$webdav$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get title => 'WebDAV cloud backup';
	@override String get entryTitle => 'WebDAV cloud sync';
	@override String get entrySubtitle => 'Back up to your own WebDAV server';
	@override String get sectionConfig => 'Server';
	@override String get addressHint => 'https://dav.jianguoyun.com/dav/';
	@override String get addressInvalid => 'Enter a valid http(s) address';
	@override String get username => 'Account';
	@override String get password => 'App password';
	@override String get directory => 'Directory (optional)';
	@override String get testConnection => 'Test connection';
	@override String get testing => 'Connecting…';
	@override String get testOk => 'Connected. The address, account and password all work.';
	@override String get testFailed => 'Connection failed';
	@override String get backupNow => 'Back up now';
	@override String get backingUp => 'Uploading backup…';
	@override String get backupDone => 'Backup uploaded';
	@override String get configIncomplete => 'Fill in the server address, account and app password first';
	@override String get lastBackup => 'Last backup';
	@override String get lastRestore => 'Last restore';
	@override String get never => 'Never';
	@override String get remote => 'Remote backups';
	@override String get remoteEmpty => 'No remote backups yet';
	@override String get restore => 'Restore';
	@override String get restoreConfirm => 'Download this backup and overwrite the current data? The app restarts.';
	@override String get delete => 'Delete';
	@override String get deleteConfirm => 'Delete this backup from the server?';
	@override String get helpTitle => 'How to configure';
	@override String get helpIntro => 'Cloud backup sends the same archive the local backups use to your own WebDAV server, so your follows, history and settings survive a reinstall. Any WebDAV service works; the steps below use Jianguoyun (Nutstore) as the example.';
	@override String get helpSteps => '1. Register and log in at www.jianguoyun.com.\n2. Open Options → Security and generate an app password.\n3. Enter the server address, your account and that app password above.';
	@override String get helpServer => 'Server: Jianguoyun\'s WebDAV address is https://dav.jianguoyun.com/dav/';
	@override String get helpAccount => 'Account: your Jianguoyun login name (usually a phone number or an e-mail).';
	@override String get helpPassword => 'Password: not your login password — WebDAV needs the app password generated under Options → Security.';
	@override String get helpIssues => 'Connection failed? Check that the address ends with /dav/, that you used the app password rather than the login password, and that your network does not block WebDAV ports.';
	@override String get openOfficialHelp => 'Open the official Jianguoyun help';
	@override String get helpOpenFailed => 'Could not open the browser';
	@override String get servers => 'WebDAV servers';
	@override String get noServer => 'No server yet';
	@override String get noConfigCreateFirst => 'No configs yet — create a WebDAV config first';
	@override String get intro => 'Add a WebDAV drive (Jianguoyun, Nextcloud…) to upload backups and restore them on other devices.';
	@override String get createNew => 'Create a config';
	@override String get openList => 'Open the config list';
	@override String get refresh => 'Refresh';
	@override String get moreActions => 'More actions';
	@override String get uploadFavorites => 'Upload the follows list only';
	@override String get uploadFull => 'Upload the full backup';
	@override String get helpTutorial => 'Help tutorial';
	@override String get nameExists => 'That config name already exists';
	@override String get selectFailed => 'The WebDAV selection was not saved. Try again.';
	@override String get configDeleteFailed => 'The WebDAV config was not deleted. Try again.';
	@override String confirmDeleteConfig({required Object name}) => 'Delete the config “${name}”?';
	@override String confirmDeleteItem({required Object name}) => 'Delete “${name}” from WebDAV?';
	@override String get deleteSuccess => 'File deleted successfully';
	@override String get deleteFailed => 'File deletion failed';
	@override String get uploadFailed => 'File upload failed';
	@override String get downloadFailed => 'File download failed';
	@override String get restoreAllSettings => 'Restore all settings';
	@override String get restoreFavorites => 'Restore the follows list only';
	@override String get folderEmpty => 'This folder is empty';
	@override String get serverName => 'Config name';
	@override String get editServer => 'Edit config';
	@override String get deleteServer => 'Delete config';
	@override String get activeMark => 'In use';
	@override String get saved => 'Config saved';
	@override String restored({required Object name}) => 'Restored from ${name}';
	@override String uploaded({required Object name}) => 'Uploaded ${name}';
	@override String get secretsNote => 'This device cannot open its secret vault — the password lives only in this page';
}

// Path: wallpaper
class _Translations$wallpaper$en extends Translations$wallpaper$zh {
	_Translations$wallpaper$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get title => 'Wallpaper';
	@override String get entrySubtitle => 'Solid colours, gradients or a picture';
	@override String get currentNone => 'Theme default';
	@override String get currentSolid => 'Solid colour';
	@override String get currentGradient => 'Gradient';
	@override String get currentImage => 'Picture';
	@override String get groupPresets => 'Presets';
	@override String get groupSolid => 'Solid colours';
	@override String get groupGradient => 'Gradients';
	@override String get groupDevice => 'From this device';
	@override String get groupDisplay => 'Picture display';
	@override String get none => 'No wallpaper';
	@override String get noneSubtitle => 'Keep the themed surfaces';
	@override String get pickImage => 'Pick a picture';
	@override String get pickImageSubtitle => 'Choose an image stored on this device';
	@override String get imagePath => 'Image path';
	@override String get imagePathHint => 'Enter an absolute image path';
	@override String get scrim => 'Dim picture';
	@override String get scrimSubtitle => 'A wash over the picture so text stays readable';
	@override String get blur => 'Blur picture';
	@override String get blurOff => 'Off';
	@override String get fit => 'Fill mode';
	@override String get fitCover => 'Cover';
	@override String get fitContain => 'Contain';
	@override String get fitFill => 'Stretch';
	@override String get imageMissing => 'Picture not found; check the path';
}

// Path: cast
class _Translations$cast$en extends Translations$cast$zh {
	_Translations$cast$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get title => 'Cast';
	@override String get hint => 'Pick a device on this network that can receive the cast';
	@override String get searching => 'Searching for cast devices on the network…';
	@override String get noDevices => 'No cast devices yet';
	@override String castingTo({required String name}) => 'Casting to ${name}';
	@override String get stop => 'Stop casting';
	@override String get failed => 'Cast failed — the device may not be able to reach this URL';
	@override String get statePlaying => 'Playing';
	@override String get statePaused => 'Paused';
	@override String get stateBuffering => 'Buffering';
	@override String get stateStopped => 'Stopped';
	@override String get stateUnreachable => 'Device not answering';
}

// Path: danmaku
class _Translations$danmaku$en extends Translations$danmaku$zh {
	_Translations$danmaku$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get liveHint => 'Changes apply at once';
	@override String get templateGroup => 'Viewing template';
	@override String get templateBest => 'Top 20% · Balanced';
	@override String get templateComfort => 'Top 35% · Comfortable';
	@override String get templateDense => 'Top 55% · Dense';
	@override String get templateReset => 'Reset';
	@override String get bestDesc => 'Barrage stays in the top 20% of the picture at a middle speed and density, clear of the subject.';
	@override String get comfortDesc => 'Barrage takes the top 35%; a slightly larger font and slower lines, easier to read.';
	@override String get denseDesc => 'Barrage takes the top 55%; a smaller font and faster lines keep up with a busy room.';
	@override String get resetDesc => 'Back to the defaults: full height, opaque, default speed and size.';
	@override String get customDesc => 'Custom: the current answers match none of the templates — save them as yours.';
	@override String get saveMine => 'Save the current look as my template';
	@override String get useMine => 'Use my template';
	@override String get templateApplied => 'Danmaku template applied';
	@override String get templateSaved => 'Current danmaku look saved';
	@override String get templateEmpty => 'No saved danmaku template yet';
	@override String get templateInvalid => 'The saved danmaku template is broken or out of range';
	@override String get rangeGroup => 'Display area';
	@override String get area => 'Height used at the top';
	@override String get marginTop => 'Top margin (px)';
	@override String get marginBottom => 'Bottom margin (px)';
	@override String get pausedBehavior => 'Barrage while paused';
	@override String get pausedBehaviorDesc => 'When the video pauses, the barrage holds or keeps flying';
	@override String get pausedPause => 'Pause with the video';
	@override String get pausedFly => 'Keep flying';
	@override String get styleGroup => 'Style';
	@override String get opacity => 'Opacity';
	@override String get speed => 'Speed (px/s)';
	@override String get fontSize => 'Font size';
	@override String get fontWeight => 'Font weight';
	@override String get weightThin => 'Thin';
	@override String get weightExtraLight => 'Extra light';
	@override String get weightLight => 'Light';
	@override String get weightNormal => 'Normal';
	@override String get weightMedium => 'Medium';
	@override String get weightSemiBold => 'Semibold';
	@override String get weightBold => 'Bold';
	@override String get weightExtraBold => 'Extra bold';
	@override String get weightBlack => 'Black';
	@override String get stroke => 'Barrage outline';
	@override String get strokeWidth => 'Outline width';
	@override String get noEmoji => 'Pure text mode (hide emoji)';
	@override String get smoothGroup => 'Smoothness';
	@override String get repeatGroup => 'Repeated danmaku';
	@override String get collapse => 'Collapse identical danmaku bursts';
	@override String get collapseDesc => 'Keep the first copy when different users send the same text. Local and system messages are unaffected.';
	@override String get collapseWindow => 'Identical-text window (seconds)';
	@override String get fps => 'Barrage frame rate';
	@override String fpsValue({required int count}) => '${count} FPS';
	@override String get maxVisible => 'Most lines on screen';
	@override String maxVisibleValue({required int count}) => '${count} lines';
	@override String get interactionGroup => 'Touch interaction';
	@override String get holdOnPress => 'Hold a line to stop it';
	@override String get holdOnPressDesc => 'Pressing a flying line holds only that line; the rest keep flying, and it resumes on release.';
	@override String get listGroup => 'Chat list';
	@override String get listStyle => 'Chat list style';
	@override String get listCompact => 'Compact';
	@override String get listCard => 'Card';
	@override String get listFontSize => 'Chat text size';
	@override String get listLineSpacing => 'Line spacing';
	@override String get showSender => 'Show sender names';
	@override String get showGifts => 'Gifts in flying danmaku';
	@override String get showGiftsDesc => 'Gift messages fly over the picture as well';
	@override String get tapAction => 'Tap an on-screen danmaku for actions';
	@override String get longPressAction => 'Long-press an on-screen danmaku for block actions';
	@override String get autoFps => 'Danmaku frame rate follows the display';
	@override String get autoFpsDesc => 'Follows the power saving, balanced or highest level; turn it off to set the rate yourself.';
	@override String get fpsMode => 'Refresh-rate tier';
	@override String get fpsModePowerSaving => 'Power saving';
	@override String get fpsModeBalanced => 'Balanced';
	@override String get fpsModeHighest => 'Highest';
	@override String get fontFamily => 'Danmaku font';
}

// Path: clipboard
class _Translations$clipboard$en extends Translations$clipboard$zh {
	_Translations$clipboard$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get title => 'A live-room link in your clipboard';
	@override String found({required Object site, required Object room}) => '${site} room ${room} — take a look now?';
	@override String get go => 'Open';
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
			'splash.welcome' => 'Welcome',
			'home.recommended' => 'Recommendations',
			'common.confirm' => 'OK',
			'common.cancel' => 'Cancel',
			'common.restartNow' => 'Restart now',
			'common.restartLater' => 'Later',
			'common.retry' => 'Retry',
			'common.close' => 'Close',
			'common.save' => 'Save',
			'common.clear' => 'Clear',
			'common.delete' => 'Delete',
			'common.loading' => 'Loading',
			'common.empty' => 'Nothing here yet',
			'common.pageOf' => ({required int page, required int total}) => 'Page ${page} of ${total}',
			'common.back' => 'Back',
			'common.menu' => 'Menu',
			'common.expandSidebar' => 'Expand sidebar',
			'common.collapseSidebar' => 'Collapse sidebar',
			'common.more' => 'More',
			'common.off' => 'Off',
			'common.refresh' => 'Refresh',
			'common.prevPage' => 'Previous',
			'common.nextPage' => 'Next',
			'common.perPage' => 'Per page',
			'common.goTo' => 'Go to',
			'common.pageUnit' => 'Page',
			'common.toTop' => 'To the top',
			'common.toBottom' => 'To the bottom',
			'common.addOne' => 'Add',
			'common.ignore' => 'Ignore',
			'tray.show' => 'Show Pure Live',
			'tray.quit' => 'Quit',
			'tray.hide' => 'Hide window',
			'tray.recordingCount' => ({required Object count}) => 'Recording ${count} room(s)',
			'tray.tooltipRecording' => ({required Object count}) => 'Pure Live · recording ${count} room(s)',
			'login.title' => 'Sign in',
			'login.generating' => 'Generating QR code',
			'login.waitingScan' => 'Waiting for scan',
			'login.scanHint' => 'Open the bilibili app and scan this code to confirm the sign-in.',
			'login.success' => 'Signed in',
			'login.welcome' => ({required String name}) => 'Welcome, ${name}',
			'login.expired' => 'The QR code has expired',
			'login.refreshQr' => 'Refresh code',
			'login.failed' => 'The sign-in did not go through',
			'login.done' => 'Done',
			'login.unsupported' => 'This build has no bilibili sign-in capability',
			'login.platformBilibili' => 'bilibili QR',
			'login.platformDouyu' => 'douyu cookie',
			'login.platformHuya' => 'huya cookie',
			'login.cookiePlaceholder' => 'Cookie: a=b; c=d ...',
			'login.verify' => 'Verify and sign in',
			'login.douyuCookieHint' => 'Copy the Cookie header of a signed-in www.douyu.com request from the browser’s network inspector and paste it here.',
			'login.huyaCookieHint' => 'Copy the Cookie header of a signed-in www.huya.com request from the browser’s network inspector and paste it here.',
			'login.unsupportedSite' => ({required String site}) => 'This build has no ${site} sign-in capability',
			'account.title' => 'Account',
			'account.notSignedIn' => 'Not signed in',
			'account.notSignedInHint' => 'Sign in and the live requests carry your account with them.',
			'account.signOut' => 'Sign out',
			'account.signOutConfirm' => ({required String site}) => 'Sign out of ${site}?',
			'account.signOutHint' => 'The saved cookies are removed from this device.',
			'account.userId' => ({required String id}) => 'ID ${id}',
			'account.platformBilibili' => 'bilibili account',
			'account.platformDouyu' => 'douyu account',
			'account.platformHuya' => 'huya account',
			'account.noAuthSites' => 'No platform in this build can sign in yet',
			'account.clearAllAccounts' => 'Clear all accounts',
			'account.clearAllAccountsHint' => 'Sign out of every platform and drop the stored credentials',
			'account.editorTitle' => ({required Object name}) => '${name} account',
			'account.cookieGroup' => 'Cookie',
			'account.paste' => 'Paste',
			'account.clearInput' => 'Clear',
			'account.cookieInvalid' => 'This does not look like a cookie: expected name=value; name2=value2',
			'account.clipboardEmpty' => 'The clipboard has no text',
			'account.editorNoneHint' => 'Not set: paste the cookie of a signed-in browser',
			'account.saved' => 'Saved',
			'account.signedIn' => ({required Object name}) => 'Signed in: ${name}',
			'account.statusUid' => ({required Object uid}) => 'Saved · account id ${uid}',
			'account.verifying' => 'Verifying account…',
			'account.savingVerifying' => 'Checking and saving…',
			'account.openSite' => ({required Object name}) => 'Open ${name} website',
			'account.privacyNote' => 'Cookies are stored encrypted on this device only and never uploaded.',
			'account.discardTitle' => 'Discard Cookie changes?',
			'account.discardDetail' => 'Your edited Cookie has not been saved. Discard these changes and leave this page?',
			'account.discard' => 'Discard',
			'account.keepEditing' => 'Keep editing',
			'account.cookieTip' => 'Sign in on the platform in a browser, open the developer tools and copy the whole Cookie request header below.',
			'account.statusExpired' => 'Expired — paste the cookie again',
			'account.douyuLtp0' => 'LTP0 (long-term key)',
			'account.douyuLtp0Hint' => 'the LTP0 in the passport.douyu.com request cookie; filled automatically when you paste above',
			'account.douyuDid' => 'dy_did (device id)',
			'account.douyuDidHint' => 'the dy_did in that same request (32 hex characters); filled automatically',
			'account.douyuRenew' => 'Renew now',
			'account.douyuRenewNeedPair' => 'Renewal needs LTP0 and dy_did: sign in to Douyu in a browser and paste the cookie again',
			'account.douyuStatusGuest' => 'Saved, but there is no acf_jwt_token: this is a guest cookie, so HD/UHD are unavailable',
			'account.douyuStatusNoExpiry' => 'Signed in (the cookie carries no end time; add LTP0 to renew it automatically)',
			'account.douyuStatusAutoRenew' => ({required Object time}) => 'Signed in (about 7 days, until ${time}); LTP0 is set, so it renews before it ends',
			'account.douyuStatusRepaste' => ({required Object time}) => 'Signed in (about 7 days, until ${time}); no LTP0, so paste it again after that',
			'account.douyuStatusRenewable' => ({required Object time}) => 'Session expired at ${time}; saved, and the next playback renews it with LTP0',
			'account.douyuStatusExpired' => ({required Object time}) => 'Session expired at ${time} and the cookie has no LTP0: paste a fresh one',
			'account.savedAccounts' => 'Remembered accounts',
			'account.savedAccountsNote' => ({required Object count}) => 'Accounts you signed in with are kept here (up to ${count}); switching needs no new scan. Sign-ins are stored encrypted on this device only and are erased when you sign out or remove them.',
			'account.accountUid' => ({required Object uid}) => 'UID ${uid}',
			'account.accountCurrent' => 'Current',
			'account.accountSwitch' => 'Switch',
			'account.accountForget' => 'Remove this account',
			'account.accountSwitchConfirm' => ({required Object name}) => 'Switch to “${name}”? Rooms you are watching reconnect their danmaku with this account.',
			'account.accountForgetConfirm' => ({required Object name}) => 'Remove the sign-in of “${name}” from this device? Using that account again needs a new sign-in.',
			'account.accountAdd' => 'Add an account',
			'account.accountAddHint' => 'Sign another account in with the QR code; the current one stays here',
			'account.accountAddFull' => ({required Object count}) => '${count} remembered; adding another forgets the one unused the longest',
			'account.accountSwitched' => ({required Object name}) => 'Switched to “${name}”',
			'account.accountForgot' => ({required Object name}) => 'Removed “${name}”',
			'account.accountAdded' => ({required Object name}) => '“${name}” is remembered',
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
			'settings.sectionTheme' => 'Theme & display',
			'settings.sectionIptv' => 'IPTV',
			'settings.sectionDanmaku' => 'Danmaku',
			'settings.sectionData' => 'Data',
			'settings.sectionBackup' => 'Backup',
			'settings.appearanceSubtitle' => 'Theme mode, colour, density and motion',
			'settings.fontsSubtitle' => 'Download and apply cloud fonts',
			'settings.iptvSubtitle' => 'Manage playlists and channels',
			'settings.shieldSubtitle' => 'Hide danmaku by keyword, user or regex',
			'settings.cacheAndData' => 'Cache & data',
			'settings.cacheAndDataSubtitle' => 'Watch history and stored data',
			'settings.backupSubtitle' => 'Back up and restore your data',
			'settings.groupTheme' => 'Theme',
			'settings.groupFontFamily' => 'Font',
			'settings.groupTextSize' => 'Text size',
			'settings.themeModeSubtitle' => 'Follow the system, or stay light or dark',
			'settings.designLanguageSubtitle' => 'The design language the whole app is drawn with',
			'settings.designLanguageRestartTitle' => 'Change design language',
			'settings.designLanguageRestartConfirm' => ({required String current}) => 'The design language decides which app host runs, so it takes effect on the next launch. This session keeps drawing with ${current}. Restart the app now?',
			'settings.designLanguagePending' => ({required String name}) => 'Applies after restart: ${name}',
			'settings.accentSubtitle' => 'The colour the controls are tinted with',
			'settings.densitySubtitle' => 'How compact the layout is',
			'settings.pureBlackSubtitle' => 'Draw dark surfaces pure black, for OLED screens',
			'settings.transparencySubtitle' => 'A multiplier on glass and scrim opacity',
			'settings.reduceTransparencySubtitle' => 'Force opaque surfaces and disable blur',
			'settings.animationsSubtitle' => 'Whether motion runs',
			'settings.focusOutlineSubtitle' => 'Draw a visible outline on focused controls',
			'settings.fontScaleSubtitle' => 'A multiplier on every font size',
			'settings.previewText' => 'The quick brown fox jumps over the lazy dog',
			'settings.fontFamilyCurrent' => ({required String name}) => 'Current: ${name}',
			'settings.defaultOption' => 'Default',
			'settings.historyEntry' => 'Watch history',
			'settings.historyCount' => ({required int count}) => '${count} entries',
			'settings.clearHistory' => 'Clear watch history',
			'settings.clearHistorySubtitle' => 'Remove every watched entry from this device',
			'settings.historyCleared' => 'Watch history cleared',
			'settings.general' => 'General',
			'settings.generalSubtitle' => 'Refresh, launch, countdown close and window',
			'settings.sectionGeneral' => 'General',
			'settings.sectionAccount' => 'Account',
			'settings.scanToLogin' => 'Sign in to your platforms',
			'settings.accountSubtitle' => 'Platform accounts and sign-in',
			'settings.refreshSettings' => 'Refresh',
			'settings.refreshSettingsSubtitle' => 'Foreground interval and resume threshold',
			'settings.pageSettings' => 'Page settings',
			'settings.pageSettingsSubtitle' => 'Which branches show, and in what order',
			'settings.navigationSettings' => 'Navigation',
			'settings.navigationSettingsSubtitle' => 'Where the app starts',
			'settings.sectionFeedDisplay' => 'Feed display',
			'settings.loadingStyle' => 'Loading style',
			'settings.loadingStyleSubtitle' => 'How loading placeholders present',
			'settings.roomCardSettings' => 'Room card',
			'settings.roomCardSettingsSubtitle' => 'Radius, cover shape and info lines',
			'settings.sectionNetwork' => 'Network',
			'settings.proxySettings' => 'Network proxy',
			'settings.proxySettingsSubtitle' => 'Route requests through a proxy',
			'settings.refreshOnResume' => 'Refresh on resume',
			'settings.refreshOnResumeSubtitle' => 'Refresh feeds when you come back, if you were away long enough',
			'settings.showUnplayable' => 'Show unplayable rooms',
			'settings.showUnplayableDesc' => 'List carousel, sign-in-required and members-only rooms in feeds and search',
			'settings.autoCheckUpdate' => 'Check for updates at start',
			'settings.autoCheckUpdateSubtitle' => 'Ask about new versions from the release feed; the About page can always check manually',
			'settings.countdownClose' => 'Countdown close',
			'settings.countdownCloseSubtitle' => 'Exit the app when the countdown runs out',
			'settings.countdownDuration' => 'Countdown duration',
			'settings.minutesValue' => ({required int minutes}) => '${minutes} min',
			'settings.minutesAway' => ({required int minutes}) => 'After ${minutes} min away',
			'settings.launchPage' => 'Launch page',
			'settings.launchPageHint' => 'The branch the app starts on. The navigation settings can override this with the last visited tab.',
			'settings.windowSize' => 'Window size',
			'settings.windowSizeDefault' => 'Launch default',
			'settings.windowSizeHint' => 'Applies now, and again at the next launch.',
			'settings.groupAutoRefresh' => 'Auto refresh',
			'settings.autoRefreshInterval' => 'Foreground refresh interval',
			'settings.autoRefreshIntervalHint' => 'How often the visible feed refreshes itself. Off by default.',
			'settings.refreshResumeThreshold' => 'Resume refresh threshold',
			'settings.refreshResumeThresholdHint' => 'How long away counts as worth refreshing for.',
			'settings.refreshOff' => 'Off',
			'settings.refreshEveryResume' => 'Every resume',
			'settings.groupVisibleBranches' => 'Visible pages',
			'settings.groupHiddenBranches' => 'Hidden pages',
			'settings.showBranchSubtitle' => 'Show this page in the shell',
			'settings.pageSettingsHint' => 'Drag to arrange. At least one page stays visible.',
			'settings.atLeastOneBranch' => 'At least one page must stay visible',
			'settings.groupLaunch' => 'Start-up',
			'settings.restoreLastTab' => 'Resume where you left off',
			'settings.restoreLastTabSubtitle' => 'Start on the branch you last visited',
			'settings.restoreLastTabOn' => ({required String branch}) => 'Start on the branch you last visited (last: ${branch})',
			'settings.navigationHint' => 'Decides where the start splash hands over; a change lands at the next start.',
			'settings.proxyGroup' => 'Proxy',
			'settings.proxyEnable' => 'Use a proxy',
			'settings.proxyEnableSubtitle' => 'Route outgoing requests through the proxy below',
			'settings.proxyEndpoint' => 'Endpoint',
			'settings.proxyHost' => 'Host',
			'settings.proxyPort' => 'Port',
			'settings.proxyPortInvalid' => 'Port must be 1-65535',
			'settings.proxyHint' => 'Applied to new connections immediately; no restart needed.',
			'settings.loadingPreview' => 'Preview',
			'settings.loadingShimmer' => 'Shimmer',
			'settings.loadingSpinner' => 'Spinner',
			'settings.loadingNone' => 'Nothing',
			'settings.roomCardPreview' => 'Preview',
			'settings.roomCardAppearance' => 'Appearance',
			'settings.roomCardRadius' => 'Corner radius',
			'settings.roomCardAspect' => 'Cover shape',
			'settings.aspectSixteenByNine' => '16:9',
			'settings.aspectFourByThree' => '4:3',
			'settings.aspectSquare' => '1:1',
			'settings.roomCardContent' => 'Visible content',
			'settings.roomCardShowPlatform' => 'Platform badge',
			'settings.roomCardShowPlatformSubtitle' => 'The platform pill over the cover',
			'settings.roomCardShowAudience' => 'Audience and status',
			'settings.roomCardShowAudienceSubtitle' => 'The viewer-count, replay and offline pills',
			'settings.roomCardShowAnchor' => 'Anchor line',
			'settings.roomCardShowAnchorSubtitle' => 'The avatar and the anchor\'s name',
			'settings.roomCardScopeHint' => 'Applies to the popular, areas, follow and search grids.',
			'settings.remoteSync' => 'LAN sync',
			'settings.remoteSyncSubtitle' => 'Sync playback to another device on this network',
			'settings.sectionRecorder' => 'Recording',
			'settings.recorderSubtitle' => 'Watch rooms and record them live',
			'settings.pasteCookie' => 'Paste cookie to sign in',
			'settings.accountSignedInCount' => ({required int count}) => 'Signed in on ${count} platforms',
			'settings.sectionVideo' => 'Video & danmaku',
			'settings.video' => 'Video & danmaku',
			'settings.videoSubtitle' => 'What a room opens with',
			'settings.groupDanmaku' => 'Danmaku',
			'settings.groupAudio' => 'Audio',
			'settings.danmakuVisible' => 'Show danmaku by default',
			'settings.danmakuVisibleSubtitle' => 'Overlay the barrage when a room opens',
			'settings.defaultVolume' => 'Default volume',
			'settings.defaultVolumeSubtitle' => 'The level the next stream starts at',
			'settings.language' => 'Language',
			'settings.languageSubtitle' => 'Follow the system, or pick one',
			'settings.languageSystem' => 'Follow system',
			'settings.groupAppearance' => 'Barrage look',
			'settings.groupLocalInteraction' => 'Local interaction',
			'settings.localInteraction' => 'Local interaction',
			'settings.localInteractionSubtitle' => 'Adds the room composer; your messages show only on your screen',
			'settings.localInteractionName' => 'Local display name',
			'settings.mpvTuning' => 'Player tuning',
			'settings.mpvTuningSubtitle' => 'libmpv output, decoding and cache options',
			'settings.mpvOutputSection' => 'Output',
			'settings.mpvCustomOutput' => 'Custom output drivers',
			'settings.mpvCustomOutputSubtitle' => 'Off keeps the engine\'s platform defaults; on lets the drivers below be written',
			'settings.mpvNeedsCustomOutput' => 'Turn on "Custom output drivers" first',
			'settings.mpvVideoOutput' => 'Video output (vo)',
			'settings.mpvAudioOutput' => 'Audio output (ao)',
			'settings.mpvDecodeSection' => 'Decoding & rendering',
			'settings.mpvHardwareDecoder' => 'Hardware decoder (hwdec)',
			'settings.mpvDeinterlace' => 'Deinterlace',
			'settings.mpvInterpolation' => 'Frame interpolation',
			'settings.mpvInterpolationSubtitle' => 'Smoother motion at a higher GPU cost; desktop only',
			'settings.mpvScaler' => 'Scaler (scale)',
			'settings.mpvCacheSection' => 'Cache',
			'settings.mpvCacheSeconds' => 'Stream cache seconds',
			'settings.mpvCacheSecondsSubtitle' => '0 leaves the engine\'s cache alone',
			'settings.mpvReset' => 'Reset defaults',
			'settings.mpvResetSubtitle' => 'Clears every tuning on this page',
			'settings.mpvEffectiveNote' => 'How it takes effect',
			'settings.mpvEffectiveNoteBody' => 'Video/audio output and the hardware decoder land on the next stream open; the rest apply to the playing room immediately.',
			'settings.localConfig' => 'Local configuration',
			'settings.localConfigSubtitle' => 'A read-only view of the documents this device stores',
			'settings.localConfigNote' => 'This page writes nothing; edit the settings it mirrors instead.',
			'settings.localConfigCopy' => 'Copy this document',
			'settings.localConfigApp' => 'General preferences',
			'settings.localConfigAppearance' => 'Appearance',
			'settings.areaInterface' => 'Interface',
			'settings.areaSources' => 'Sources',
			'settings.areaPlayback' => 'Playback',
			'settings.areaGeneral' => 'General',
			'settings.areaData' => 'Data',
			'settings.searchHint' => 'Search settings',
			'settings.searchEmpty' => 'No matching settings',
			'settings.searchEmptyHint' => 'Try a different keyword',
			'settings.platformsTitle' => 'Platforms',
			'settings.platformsDesc' => 'Visibility, order and accounts',
			'settings.danmakuTitle' => 'Danmaku',
			'settings.danmakuDesc' => 'Display, size, opacity and blocking',
			'settings.recordingTitle' => 'Recording',
			'settings.recordingDesc' => 'Output folder and segment length',
			'settings.playerTitle' => 'Player',
			'settings.playerDesc' => 'Decoding, output and cache tuning',
			'settings.logTitle' => 'Logs',
			'settings.logDesc' => 'Log level and export',
			'settings.localInteractionDesc' => 'Local danmaku identity and switch',
			'settings.localInteractionColor' => 'Danmaku colour',
			'settings.navigationDesc' => 'Navigation bar and start page',
			'settings.videoDesc' => 'Volume, quality and background play',
			'settings.refreshDesc' => 'Auto refresh and live alerts',
			'settings.generalDesc' => 'Startup, updates and window',
			'settings.proxyDesc' => 'App and player proxies',
			'settings.cacheDesc' => 'Cache size and cleanup',
			'settings.backupDesc' => 'Back up and restore local data',
			'settings.iptvDesc' => 'Manage playlists and channels',
			'settings.pageDesc' => 'Paging and scrolling',
			'settings.pagerGroup' => 'Pager (computers)',
			'settings.pageDefaultSize' => 'Default page size',
			'settings.pageDefaultSizeHint' => 'Rooms per page when a list opens; the pager can change it for now',
			'settings.pageSizeAuto' => 'Automatic',
			'settings.itemsPerPage' => 'items/page',
			'settings.pageSizeOptionsTitle' => 'Page Size Options',
			'settings.pageSizeRestore' => 'Restore recommended',
			'settings.pageSizeInputHint' => '1–100',
			'settings.pageSizeRangeError' => 'Enter a whole number from 1 to 100',
			'settings.pageSizeDuplicateError' => 'That page size is already listed',
			'settings.pageSizeCurrent' => 'Current active options',
			'settings.pageShowScrollTop' => 'Show Scroll-to-Top Button',
			'settings.pageShowScrollTopSubtitle' => 'Displays a floating button in the corner after scrolling a distance',
			'settings.pageShowSizeSelector' => 'Show Page Size Selector',
			'settings.pageShowSizeSelectorSubtitle' => 'Displays a dropdown menu for items per page in the control bar',
			'settings.pageShowGoto' => 'Show Go-To Page Button',
			'settings.pageShowGotoSubtitle' => 'Enables manual page number input for quick jumping',
			'settings.configPreviewDesc' => 'Read-only view of the saved document',
			'settings.groupQuality' => 'Quality',
			'settings.preferResolution' => 'Preferred quality',
			'settings.preferResolutionDesc' => 'The quality a room opens with',
			'settings.mobileQuality' => 'Cellular quality',
			'settings.mobileQualityDesc' => 'The default picture quality on mobile data',
			'settings.preferH264' => 'Prefer H.264',
			'settings.preferH264Desc' => 'When a quality ships several codecs, start with the most compatible H.264; HEVC stays one manual tap away',
			'settings.videoFit' => 'Picture fit',
			'settings.videoFitDesc' => 'How the picture fills a box of another ratio (the in-room menu remembers its choice)',
			'settings.fitDefault' => 'Default',
			'settings.fitCrop' => 'Crop to fill',
			'settings.fitFillScreen' => 'Stretch to screen',
			'settings.fitHeight' => 'Fit height',
			'settings.fitWidth' => 'Fit width',
			'settings.fitScaleDown' => 'Scale down',
			'settings.groupPlayback' => 'Playback behaviour',
			'settings.autoFullscreen' => 'Auto fullscreen',
			'settings.autoFullscreenDesc' => 'Enter fullscreen once the stream starts playing',
			'settings.blockList' => 'Danmaku block list',
			'settings.blockListDesc' => 'Keyword, user and regex blocks',
			'settings.groupAudience' => 'Viewer counts',
			'settings.audienceMode' => 'Which figure leads',
			'settings.audienceModeDesc' => 'Whether the room shows the platform’s concurrent-online number or its heat',
			'settings.audienceModeHeat' => 'Heat (popularity)',
			'settings.audienceModeOnline' => 'Online viewers',
			'settings.audiencePlatforms' => 'Platforms with a trusted online count',
			'settings.audienceHeatOnlyCount' => ({required Object count}) => 'The other ${count} platforms report heat only',
			'settings.portraitLiveSettings' => 'Portrait stream adaptation',
			'settings.portraitLiveSettingsDesc' => 'Detect the source orientation and shape the normal page, fullscreen and mini window alike',
			'settings.portraitGroupDetect' => 'Detection & layout',
			'settings.portraitDetect' => 'Detect portrait live sources',
			'settings.portraitDetectDesc' => 'Recognised from the decoded frame size, and re-decided when the line or quality switches',
			'settings.portraitAdaptiveHeight' => 'Adaptive height on the normal page',
			'settings.portraitAdaptiveHeightDesc' => 'A tall source keeps the bigger watch area while the chat list keeps its room; off pins the panel at the middle stop',
			'settings.portraitLayoutMode' => 'Normal-page layout',
			'settings.portraitLayoutModeDesc' => 'Applies to portrait sources only; landscape rooms are untouched',
			'settings.portraitLayoutBalanced' => 'Balanced (recommended)',
			'settings.portraitLayoutImmersive' => 'Immersive',
			'settings.portraitLayoutCompatibility' => 'Compatibility 16:9',
			'settings.portraitGroupPresentation' => 'Fullscreen presentation',
			'settings.portraitFullscreenPolicy' => 'Direction on entering fullscreen',
			'settings.portraitFullscreenPolicyDesc' => 'Big and split-screen devices hand this to the system; a phone may follow the source',
			'settings.portraitFollowSource' => 'Follow the source (recommended)',
			'settings.portraitFollowSystem' => 'Follow the system',
			'settings.portraitAlwaysLandscape' => 'Always landscape',
			'settings.portraitDisplayMode' => 'Portrait-fullscreen canvas',
			'settings.portraitDisplayModeDesc' => 'Only the upright fullscreen of a portrait stream; applies at once',
			'settings.portraitDisplayComplete' => 'Complete picture',
			'settings.portraitDisplayAmbient' => 'Ambient backdrop (recommended)',
			'settings.portraitDisplayBalanced' => 'Balanced fill',
			'settings.portraitDisplayCover' => 'Crop to fill',
			'settings.portraitDanmakuMode' => 'Portrait danmaku band',
			'settings.portraitDanmakuModeDesc' => 'Bounds the flying danmaku over a portrait picture without touching the global style numbers',
			'settings.portraitDanmakuFollowGlobal' => 'Follow global',
			'settings.portraitDanmakuUpperQuarter' => 'Top 25%',
			'settings.portraitDanmakuReduced' => 'Reduced 50%',
			'settings.portraitDanmakuHidden' => 'Hidden on portrait',
			'settings.portraitRemember' => 'Remember a room’s direction',
			'settings.portraitRememberDesc' => 'A direction picked by hand in the player is kept for the next visit to the same room',
			'settings.portraitGroupDiagnostics' => 'Diagnostics',
			'settings.portraitDiagnostics' => 'Show the detection state',
			'settings.portraitDiagnosticsDesc' => 'Draw the raw size, ratio and the rule in force over the picture',
			'settings.portraitReset' => 'Restore portrait defaults',
			'settings.portraitResetDesc' => 'Including the remembered per-room direction overrides',
			'settings.portraitResetConfirm' => 'Reset every portrait-adaptation setting to its default?',
			'settings.pipOnTop' => 'Keep the mini player on top',
			'settings.pipOnTopDesc' => 'When off, other applications can cover the mini player',
			'settings.miniRemember' => 'Remember the mini window position',
			'settings.miniRememberDesc' => 'The tile re-opens where it was left; off returns it to the corner each time',
			'settings.pauseOnTileClose' => 'Pause when the tile closes',
			'settings.pauseOnTileCloseDesc' => 'Closing the window while it is a PiP/mini tile restores and pauses the stream first — no audio left running behind a hidden window',
			'settings.splashAnimation' => 'Start-up animation',
			'settings.splashAnimationDesc' => 'Show the logo while the app starts',
			'settings.githubUpdates' => 'Use the official GitHub update source',
			'settings.githubUpdatesDesc' => 'Checks and downloads go straight to GitHub — for runs behind a proxy; off uses the mirrors',
			'settings.clipboardRooms' => 'Recognise room links on the clipboard',
			'settings.clipboardRoomsDesc' => 'When the app opens or resumes and the clipboard holds a room link, ask before entering; one link is asked once',
			'settings.startup' => 'Start at sign-in',
			'settings.startupDesc' => 'Launch automatically when you sign in',
			'settings.startupFailed' => 'The system refused the autostart entry',
			'settings.closeWindow' => 'When closing the window',
			'settings.closeWindowDesc' => 'What the window\'s close button does',
			'settings.closeAsk' => 'Ask every time',
			'settings.closeHide' => 'Hide to the tray',
			'settings.closeMinimise' => 'Minimise',
			'settings.closeQuit' => 'Quit the app',
			'settings.sectionCache' => 'Cache',
			'settings.currentCacheSize' => 'Current cache size',
			'settings.cacheSizeValue' => ({required Object count}) => '${count} MB',
			'settings.cacheMeasuring' => 'Measuring…',
			'settings.clearCache' => 'Clear the picture cache',
			'settings.clearCacheDesc' => 'Covers re-pull right after the clear',
			'settings.cacheCleared' => ({required Object count}) => 'Freed ${count} MB',
			'settings.cacheAutoClear' => 'Auto-clear the picture cache',
			'settings.cacheAutoClearDesc' => 'Empty the cache when a resume finds it past the cap',
			'settings.cacheLimit' => 'Cache cap',
			'settings.refreshCoversNow' => 'Refresh covers now',
			'settings.refreshCoversNowDesc' => 'Empty the picture cache so every cover re-pulls on the next pass',
			'settings.mbValue' => ({required Object count}) => '${count} MB',
			'settings.groupCovers' => 'Covers',
			'settings.autoRefreshThumbnails' => 'Refresh covers automatically',
			'settings.autoRefreshThumbnailsDesc' => 'Re-pull room covers on a timer so the pictures stay current',
			'settings.thumbnailRefreshInterval' => 'Cover refresh interval',
			'settings.groupHistory' => 'History',
			'settings.historyLimit' => 'History size',
			'settings.historyLimitDesc' => 'How many watched rooms are kept; 0 is no limit',
			'settings.noLimit' => 'No limit',
			'settings.playerProxyGroup' => 'Player proxy',
			'settings.playerProxyEnable' => 'Enable the player proxy',
			'settings.playerProxyEnableDesc' => 'Live streams are pulled through this proxy by the player, apart from the app\'s own requests',
			'settings.playerProxyHint' => 'Applies to the next stream; a running one keeps what it started with',
			'settings.thumbnailKeepOldFiles' => 'Keep old thumbnails',
			'settings.thumbnailKeepOldFilesDesc' => 'Superseded covers stay until the cache policy drops them; off clears what is past two intervals',
			'settings.localPreset' => 'Line style',
			'settings.localPresetClean' => 'Clean',
			'settings.localPresetHighlight' => 'Highlight',
			'settings.localPresetNeon' => 'Neon',
			'settings.localPresetMinimal' => 'Minimal',
			'settings.localLevel' => ({required int level, required int into, required int total}) => 'Level ${level} · ${into}/${total}',
			'settings.localGiftBanner' => 'Gift banner',
			'settings.localGiftBannerDesc' => 'Raise a gift card over the picture when you send one',
			'settings.backgroundPlay' => 'Background playback',
			'settings.backgroundPlayDesc' => 'Keep playing in the background; off pauses on the way out and resumes on return',
			'settings.liveAlertScope' => 'Alert scope',
			'settings.liveAlertScopeDesc' => 'Alert only for follows carrying a chosen tag; none chosen alerts every follow',
			'settings.liveAlertAll' => 'All follows',
			'settings.refreshConcurrency' => 'Parallel refresh jobs',
			'settings.refreshConcurrencyHint' => 'How many followed rooms refresh at once',
			'settings.screenKeepOn' => 'Keep the screen on',
			'settings.screenKeepOnDesc' => 'Stop the screen from sleeping while a room plays',
			'settings.preferredPlatform' => 'Preferred platform',
			'settings.preferredPlatformDesc' => 'Popular, areas and search open on this platform',
			'settings.preferredPlatformNone' => 'Platform order',
			'hotAreas.title' => 'Platform visibility',
			'hotAreas.note' => 'Hidden platforms are left out of popular, areas and search.',
			'hotAreas.orderNote' => 'Drag to reorder the platforms.',
			'hotAreas.visible' => 'Visible',
			'hotAreas.hidden' => 'Hidden',
			'hotAreas.restore' => 'Restore defaults',
			'hotAreas.keepAtLeastOne' => 'Keep at least one platform',
			'tags.title' => 'Tags',
			'tags.add' => 'New tag',
			'tags.name' => 'Tag name',
			'tags.rename' => 'Rename',
			'tags.delete' => 'Delete',
			'tags.deleteConfirm' => ({required Object name}) => 'Delete "${name}"? Its rooms stay followed.',
			'tags.pin' => 'Pin to top',
			'tags.unpin' => 'Unpin',
			'tags.pinned' => 'Pinned',
			'tags.empty' => 'No tags yet',
			'tags.emptyHint' => 'Long-press a followed room to add it to a tag.',
			'tags.countValue' => ({required int count}) => '${count} tags',
			'tags.nameEmpty' => 'Name cannot be empty',
			'tags.nameTaken' => 'A tag with this name already exists',
			'logs.title' => 'Logs',
			'logs.level' => 'Log level',
			'logs.levelHint' => 'Lower levels record more; the choice persists across launches.',
			'logs.levelTrace' => 'Everything (trace)',
			'logs.levelDebug' => 'Detailed (debug)',
			'logs.levelInfo' => 'Regular (info)',
			'logs.levelWarning' => 'Warnings (warning)',
			'logs.levelError' => 'Errors (error)',
			'logs.levelFatal' => 'Fatal only',
			'logs.levelOff' => 'Off',
			'logs.levelDefault' => 'Follow build default',
			'logs.export' => 'Export recent logs',
			'logs.exportDone' => ({required int count}) => 'Copied ${count} log lines to the clipboard',
			'logs.exportEmpty' => 'No logs in memory yet',
			'logs.openFolder' => 'Open log folder',
			'logs.note' => 'Log files live under the logs directory and rotate.',
			'recorder.title' => 'Recorder',
			'recorder.addRoom' => 'Add room',
			'recorder.platform' => 'Platform',
			_ => null,
		} ?? switch (path) {
			'recorder.roomId' => 'Room ID',
			'recorder.startWatching' => 'Start watching',
			'recorder.watchStarted' => 'Watching; recording starts when the room goes live',
			'recorder.watchFailed' => ({required String error}) => 'Watching failed: ${error}',
			'recorder.noSites' => 'No platform here can look rooms up',
			'recorder.openFolder' => 'Open output folder',
			'recorder.folderNotOpened' => 'The folder could not be opened',
			'recorder.outputDirectory' => 'Output directory',
			'recorder.outputDirectoryDefault' => 'The app\'s recordings folder',
			'recorder.chooseDirectory' => 'Choose the recordings folder',
			'recorder.segmentLength' => 'Segment length',
			'recorder.minutesValue' => ({required int minutes}) => '${minutes} min',
			'recorder.segmentsValue' => ({required int count}) => '${count} segments',
			'recorder.restoring' => 'Finishing the previous run’s recordings…',
			'recorder.engineFailed' => ({required String error}) => 'The recording engine failed to start: ${error}',
			'recorder.filterAll' => 'All',
			'recorder.filterActive' => 'Active',
			'recorder.filterWaiting' => 'Waiting',
			'recorder.filterSaved' => 'Saved',
			'recorder.filterFailed' => 'Failed',
			'recorder.recordSettings' => 'Recording settings',
			'recorder.filterFinished' => 'Finished',
			'recorder.emptyTitle' => 'No rooms watched yet',
			'recorder.emptySubtitle' => 'Add a room and it is recorded once it goes live',
			'recorder.nothingToJoin' => 'Nothing to join yet',
			'recorder.actionStop' => 'Stop',
			'recorder.actionFinishNow' => 'Join now',
			'recorder.actionRestart' => 'Record again',
			'recorder.statusQueued' => 'Queued',
			'recorder.statusResolving' => 'Resolving',
			'recorder.statusRecording' => 'Recording',
			'recorder.statusRetrying' => 'Reconnecting',
			'recorder.statusMerging' => 'Joining',
			'recorder.statusCompleted' => 'Completed',
			'recorder.statusFailed' => 'Failed',
			'recorder.statusStopped' => 'Stopped',
			'recorder.statusInterrupted' => 'Interrupted',
			'recorder.roomUnknown' => 'Not asked yet',
			'recorder.roomWaiting' => 'Waiting for the stream',
			'recorder.roomLive' => 'Live now',
			'recorder.roomEnded' => 'Broadcast ended',
			'recorder.roomStalled' => 'Signal stalled',
			'recorder.roomUnavailable' => 'Room unavailable',
			'recorder.groupDefaults' => 'Recording defaults',
			'recorder.defaultQuality' => 'Default recording quality',
			'recorder.defaultQualityDesc' => 'When the room offers several qualities, record the address labelled with it; the best line when none is labelled.',
			'recorder.usePinyinFolder' => 'Name folders in pinyin',
			'recorder.usePinyinFolderDesc' => 'On: the anchor folder is pinyin (zhubo8891). Off: the room id, the safest component.',
			'recorder.recordDanmaku' => 'Save the chat',
			'recorder.recordDanmakuDesc' => 'Writes a chat file beside each recording; a chat that cannot connect never costs the recording.',
			'recorder.recordDanmakuGifts' => 'Include gifts in the saved chat',
			'recorder.recordDanmakuGiftsDesc' => 'The chat file also carries gifts and super chats.',
			'recorder.groupFiles' => 'Recording files',
			'recorder.recordSizeLimit' => 'Recording size limit',
			'recorder.recordSizeLimitDesc' => 'Delete the oldest recordings (older than an hour) when the folder passes the cap.',
			'recorder.recordSizeCap' => 'Size cap',
			'recorder.recordUsedSpace' => 'Used space',
			'recorder.recordUsedSpaceDesc' => 'Tap to re-measure the recordings folder.',
			'recorder.clearAllCache' => 'Clear all recordings',
			'recorder.clearAllCacheDesc' => 'Delete every video file in the recordings folder; the hour’s newest stay.',
			'recorder.clearFreed' => ({required Object mb}) => 'Freed ${mb} MB',
			'recorder.mbValue' => ({required Object count}) => '${count} MB',
			'recorder.groupPerformance' => 'Performance & quality',
			'recorder.preferBestStream' => 'Record the first stream only',
			'recorder.preferBestStreamDesc' => 'Map only the first video and audio track of a multi-track container.',
			'recorder.rwTimeout' => 'Read/write timeout',
			'recorder.rwTimeoutDesc' => 'A silent input fails the read after this long and the retry path takes over.',
			'recorder.queueSize' => 'Input queue size',
			'recorder.queueSizeDesc' => 'Recording favours completeness over latency, so the queue is much larger than a player’s.',
			'recorder.segmentLengthDesc' => 'Shorter segments lose less to a crash and cost more overhead.',
			'recorder.maxRecordTasks' => 'Concurrent recording tasks',
			'recorder.maxRecordTasksDesc' => 'How many rooms may record at once; each is one FFmpeg process.',
			'recorder.groupReconnect' => 'Auto reconnect',
			'recorder.autoReconnectSwitch' => 'Auto reconnect',
			'recorder.autoReconnectDesc' => 'Retry an interrupted capture; off ends the session at the drop.',
			'recorder.maxRetryCount' => 'Max retries',
			'recorder.retryDelay' => 'Retry delay',
			'recorder.timesValue' => ({required int count}) => '${count} times',
			'recorder.secondsValue' => ({required int count}) => '${count} s',
			'recorder.groupLiveCheck' => 'Live check',
			'recorder.enablePolling' => 'Check for the first broadcast',
			'recorder.enablePollingDesc' => 'Re-check rooms that are not up yet and start recording the moment they are.',
			'recorder.checkInterval' => 'Check interval',
			'recorder.enableBackoff' => 'Grow the interval',
			'recorder.enableBackoffDesc' => 'Double the wait after each still-offline answer to spare the API.',
			'recorder.maxCheckInterval' => 'Interval ceiling',
			'recorder.autoStartBoot' => 'Resume recordings when the app starts',
			'recorder.autoStartBootDesc' => 'Waiting and interrupted tasks re-arm themselves on launch.',
			'recorder.decrease' => 'Decrease',
			'recorder.increase' => 'Increase',
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
			'room.replay' => 'Replay',
			'room.offline' => 'Offline',
			'room.entryFailed' => 'Could not open this room',
			'room.chat' => 'Chat',
			'room.superChat' => 'Super Chat',
			'room.gifts' => 'Gifts',
			'room.shield' => 'Danmaku shield',
			'room.danmakuEnded' => 'Danmaku connection closed',
			'room.reconnecting' => 'Danmaku reconnecting…',
			'room.sendPlaceholder' => 'Say something…',
			'room.sendUnavailable' => 'Sending needs a signed-in platform account (not wired up yet)',
			'room.backToLive' => 'Back to live',
			'room.newMessages' => ({required Object count}) => '${count} new messages',
			'room.superChatEmpty' => 'No super chats yet',
			'room.superChatEmptyHint' => 'Highlighted paid messages land here while viewers cheer',
			'room.giftsEmpty' => 'No gifts yet',
			'room.giftsEmptyHint' => 'Gift events from the room\'s stream appear here',
			'room.follow' => 'Follow',
			'room.followed' => 'Following',
			'room.followers' => ({required Object count}) => '${count} followers',
			'room.popularity' => 'Popularity',
			'room.online' => 'Online',
			'room.lineN' => ({required Object n}) => 'Line ${n}',
			'room.fullscreen' => 'Fullscreen',
			'room.lock' => 'Lock screen',
			'room.unlock' => 'Unlock screen',
			'room.videoFit' => 'Aspect ratio',
			'room.fitContain' => 'Fit',
			'room.fitCover' => 'Cover',
			'room.fitFill' => 'Stretch',
			'room.exitFullscreen' => 'Exit fullscreen',
			'room.barrageOn' => 'Show danmaku',
			'room.barrageOff' => 'Hide danmaku',
			'room.toolbox' => 'Toolbox',
			'room.copyLink' => 'Copy room link',
			'room.linkCopied' => 'Copied',
			'room.shareCode' => 'Copy share code',
			'room.shareCodeCopied' => 'Share code copied — paste it back to open this room',
			'room.shareCodeFailed' => 'The room is not named well enough to share by code',
			'room.record' => 'Record',
			'room.stopRecording' => 'Stop recording',
			'room.rateNormal' => 'Normal speed',
			'room.audienceWaiting' => 'Waiting for audience data',
			'room.mute' => 'Mute',
			'room.unmute' => 'Unmute',
			'room.danmakuOn' => 'Danmaku on',
			'room.sleepTimer' => 'Sleep timer',
			'room.sleepTimerOn' => 'Sleep timer (on)',
			'room.sleepTimerEnable' => 'Enable the playback timer',
			'room.sleepTimerDesc' => 'Pauses this room\'s playback when it runs out',
			'room.timerDuration' => 'Timer duration',
			'room.timerDurationHint' => '1 - 525600 minutes',
			'room.timerInvalid' => 'Enter minutes between 1 and 525600',
			'room.timerFinished' => 'Playback timer finished — paused',
			'room.minutesUnit' => 'min',
			'room.minutesN' => ({required Object minutes}) => '${minutes} min',
			'room.roomVolume' => 'Room volume',
			'room.roomVolumeDesc' => 'The mute and the per-device default levels',
			'room.globalMute' => 'Global mute',
			'room.globalMuteSubtitle' => 'Rooms open silenced; the level is kept',
			'room.mobileDefaultVolume' => 'Phone default volume',
			'room.desktopDefaultVolume' => 'Desktop default volume',
			'room.resetDefault' => 'Reset defaults',
			'room.volumeApplyFailed' => 'The active room refused the volume update',
			'room.send' => 'Send',
			'room.localMe' => 'Me',
			'room.barrageSettings' => 'Barrage settings',
			'room.keywordBlock' => 'Keyword block',
			'room.barrageHiddenHint' => 'Barrage is globally off',
			'room.barrageOnSubtitle' => 'Scroll the barrage over the picture',
			'room.barrageFontSize' => 'Barrage text size',
			'room.barrageOpacity' => 'Barrage opacity',
			'room.barrageSettingsNote' => 'Applies immediately and is the default for new rooms',
			'room.enterLandscapeFullscreen' => 'Landscape fullscreen',
			'room.enterPortraitFullscreenHint' => 'Drag down to enter portrait fullscreen',
			'room.portraitPanelResize' => 'Panel height',
			'room.portraitPanelResizeHint' => 'Drag to resize the panel',
			'room.pip' => 'Picture-in-picture',
			'room.exitPip' => 'Exit picture-in-picture',
			'room.miniWindow' => 'Floating mini window',
			'room.exitMiniWindow' => 'Exit the mini window',
			'room.messageActions' => 'Danmaku',
			'room.copyMessage' => 'Copy',
			'room.copiedToClipboard' => 'Copied to clipboard',
			'room.blockViewer' => 'Block this viewer',
			'room.blockViewerDesc' => ({required Object name}) => 'Messages from ${name} are no longer shown',
			'room.userBlocked' => ({required Object name}) => 'Blocked ${name}',
			'room.blockWord' => 'Block a keyword…',
			'room.blockWordDesc' => 'Enter a word; messages containing it are no longer shown',
			'room.keywordBlocked' => 'Keyword added to the danmaku block list',
			'room.userLevel' => ({required Object level}) => 'Level ${level}',
			'room.blockKeywordTitle' => 'Block a danmaku keyword',
			'room.block' => 'Block',
			'room.portraitFullscreenRestoreHint' => 'Portrait fullscreen — swipe up to bring the danmaku bar back',
			'room.gift' => 'Send a gift',
			'room.sentGift' => 'sent',
			'room.autoReconnecting' => ({required int count}) => 'Reconnecting (attempt ${count})',
			'areas.followedAreas' => 'Followed areas',
			'areas.empty' => 'No areas here',
			'areas.followEmpty' => 'No followed areas yet',
			'areas.followEmptyHint' => 'Open an area and follow it with the button in its top-right corner.',
			'areas.followDone' => ({required String name}) => 'Following ${name}',
			'areas.unfollowDone' => ({required String name}) => 'Unfollowed ${name}',
			'popular.allPlatforms' => 'All platforms',
			'popular.allPlatformsHint' => 'Tap to switch; platform settings hide and order them.',
			'popular.noPlatforms' => 'No platforms to show',
			'popular.noPlatformsHint' => 'Enable at least one platform in platform settings.',
			'popular.empty' => 'Nothing live right now',
			'history.countOfLimit' => ({required int count, required int limit}) => '${count} / ${limit} entries',
			'history.countUnlimited' => ({required int count}) => '${count} entries',
			'history.filterOpen' => 'Filter',
			'history.filterClose' => 'Close filter',
			'history.filterHint' => 'Filter by title or streamer',
			'history.filterMatches' => ({required int count}) => '${count} matches',
			'history.filterEmpty' => 'No history entries match',
			'history.refreshStatus' => 'Refresh watch status',
			'history.refreshDone' => ({required int count}) => 'Refreshed ${count} entries',
			'history.refreshPartial' => ({required int failed, required int count}) => '${failed} of ${count} failed to refresh',
			'history.refreshSaveFailed' => 'Saving the refreshed history failed',
			'history.limitTitle' => 'History limit',
			'history.limitHint' => '0 keeps everything; older entries beyond the limit are deleted.',
			'history.removed' => 'Entry removed',
			'history.cleared' => ({required int count}) => 'Cleared ${count} entries',
			'history.clear' => 'Clear history',
			'history.resume' => 'Resume',
			'history.clearConfirm' => 'Clear the whole watch history? This cannot be undone.',
			'history.empty' => 'Nothing watched yet',
			'history.today' => 'Today',
			'history.yesterday' => 'Yesterday',
			'history.thisWeek' => 'This week',
			'history.thisMonth' => 'This month',
			'history.earlier' => 'Earlier',
			'history.remove' => 'Remove entry',
			'history.removeConfirm' => 'Remove this watch record?',
			'iptv.epgTitle' => 'Guides',
			'iptv.title' => 'IPTV',
			'iptv.addSource' => 'Add source',
			'iptv.sourceName' => 'Source name',
			'iptv.sourceUrl' => 'Playlist URL (M3U/TXT)',
			'iptv.deleteSource' => 'Delete this source? Its channels go too',
			'iptv.imported' => ({required int count}) => 'Imported ${count} channels',
			'iptv.allGroups' => 'All groups',
			'iptv.favorite' => 'Favorite',
			'iptv.empty' => 'No source imported yet',
			'iptv.search' => 'Search channels',
			'iptv.favoritesOnly' => 'Favorites only',
			'iptv.noMatch' => 'No channels match',
			'iptv.channels' => 'Channel list',
			'iptv.switchChannel' => 'Switch channel',
			'iptv.dialPad' => 'Number pad',
			'iptv.noNumber' => ({required int number}) => 'No channel ${number}',
			'iptv.importFromFile' => 'Import from file',
			'iptv.importFailed' => 'Import failed',
			'iptv.lineOf' => ({required int index, required int total}) => 'Line ${index}/${total}',
			'iptv.kindPlaylist' => 'M3U / TXT',
			'iptv.kindXtream' => 'Xtream',
			'iptv.xtreamServer' => 'Server URL (http://host:port)',
			'iptv.xtreamUsername' => 'Username',
			'iptv.xtreamPassword' => 'Password',
			'iptv.epgUrl' => 'EPG URL (optional)',
			'iptv.xtreamAuthFailed' => 'The server rejected these credentials',
			'iptv.refreshSource' => 'Refresh this source',
			'iptv.epgNow' => 'Now',
			'iptv.epgNext' => 'Next',
			'iptv.refreshEpg' => 'Refresh programme guide',
			'iptv.hotChannels' => 'Hot channels',
			'iptv.viewAll' => 'View all',
			'iptv.liveNow' => 'Live',
			'iptv.prevChannel' => 'Previous channel',
			'iptv.channelList' => 'Channel list',
			'iptv.playbackSettings' => 'Playback settings',
			'iptv.lineSelect' => 'Select line',
			'iptv.numberPad' => 'Number pad',
			'iptv.refreshGuide' => 'Refresh guide',
			'fonts.fonts' => 'Fonts',
			'fonts.system' => 'System default',
			'fonts.systemDesc' => 'Use the fonts the system ships',
			'fonts.download' => 'Download',
			'fonts.delete' => 'Delete',
			'fonts.factoryDefault' => 'Factory default',
			'fonts.cloudFonts' => 'Cloud fonts',
			'fonts.custom' => 'Custom fonts',
			'fonts.customDesc' => 'Pick a ttf, otf or ttc font file from this device',
			'fonts.import' => 'Import a font file',
			'fonts.importFailed' => 'That file could not be imported',
			'follow.all' => 'All',
			'follow.empty' => 'No followed rooms yet',
			'follow.follow' => 'Follow',
			'follow.unfollow' => 'Unfollow',
			'follow.unfollowConfirm' => ({required String name}) => 'Unfollow "${name}"?',
			'follow.liveRoom' => 'Live',
			'follow.replayRoom' => 'Replays',
			'follow.offlineRoom' => 'Offline',
			'follow.emptyLive' => 'No followed rooms are live',
			'follow.emptyReplay' => 'No replay follows',
			'follow.emptyOffline' => 'No offline follows',
			'follow.showOffline' => 'View offline',
			'follow.refreshFailed' => ({required int count}) => '${count} rooms failed to refresh',
			'follow.newGroup' => 'New group',
			'follow.manageGroups' => 'Manage groups',
			'follow.renameGroup' => 'Rename group',
			'follow.deleteGroup' => 'Delete group',
			'follow.deleteGroupConfirm' => 'Deleting a group leaves followed rooms untouched. Delete?',
			'follow.assign' => 'Move to groups',
			'follow.groupName' => 'Group name',
			'toolbox.title' => 'Toolbox',
			'toolbox.hint' => 'Paste a room link',
			'toolbox.readClipboard' => 'Read clipboard',
			'toolbox.resolve' => 'Resolve',
			'toolbox.failed' => 'No platform recognised this link',
			'toolbox.openRoom' => 'Open the room',
			'toolbox.roomJump' => 'Jump to Room',
			'toolbox.linkJump' => 'Open Link',
			'toolbox.directLink' => 'Get Direct Link',
			'toolbox.parse' => 'Parse Link',
			'toolbox.inputHint' => 'Paste platform link here...',
			'toolbox.supportList' => 'Supported Platforms',
			'toolbox.supportContent' => 'Supported link formats:\n\nBilibili:\nhttps://live.bilibili.com/xxxxx\nhttps://www.bilibili.com/xxxxx\nhttps://b23.tv/xxxxx\n\nHuya:\nhttps://www.huya.com/xxxxx\n\nDouyu:\nhttps://www.douyu.com/xxxxx\n\nDouyin Live/Video:\nhttps://live.douyin.com/xxxxx\nhttps://www.douyin.com/xxxxx\nhttps://v.douyin.com/xxxxx\nhttps://webcast.amemv.com/douyin/webcast/reflow/xxxxx\n\nKuaishou Live:\nhttps://live.kuaishou.com/u/xxxxx\nhttps://live.kuaishou.cn/u/xxxxx\n\nNetEase CC:\nhttps://cc.163.com/xxxxx\n\nTwitch:\nhttps://www.twitch.tv/xxxxx\nhttps://twitch.tv/xxxxx\n\nSOOP Live:\nhttps://www.sooplive.com/xxxxx\nhttps://sooplive.com/xxxxx\nhttps://play.sooplive.com/xxxxx\nhttps://www.sooplive.co.kr/xxxxx\nhttps://sooplive.co.kr/xxxxx\nhttps://play.sooplive.co.kr/xxxxx\n\nYY Live:\nhttps://www.yy.com/xxxxx\nhttps://yy.com/xxxxx\nhttps://www.yy.com/xxxxx/xxxxx?tempId=xxxxx\nhttps://yy.com/xxxxx/xxxxx?tempId=xxxxx\n\nAcFun Live:\nhttps://live.acfun.cn/live/123456\n\nPicarto:\nhttps://picarto.tv/ChannelName\n\nTwitCasting:\nhttps://twitcasting.tv/ChannelName\nhttps://twitcasting.tv/c:ChannelName\n\nCHZZK:\nhttps://chzzk.naver.com/live/0123456789abcdef0123456789abcdef\n\nKick:\nhttps://kick.com/ChannelName\n\n17LIVE:\nhttps://17.live/en/live/1234567',
			'toolbox.emptyLink' => 'Link cannot be empty',
			'toolbox.parseFailed' => 'Unable to parse this link',
			'toolbox.getUrlFailed' => 'Failed to get direct link',
			'toolbox.selectQuality' => 'Select Quality',
			'toolbox.selectLine' => 'Select Line',
			'toolbox.line' => ({required int index}) => 'Line ${index}',
			'toolbox.detectLink' => 'Link Detected',
			'toolbox.autoFill' => 'Live link from clipboard has been auto-filled',
			'toolbox.copySuccess' => 'Direct link copied',
			'backup.title' => 'Backup & restore',
			'backup.create' => 'Create backup',
			'backup.restoreFile' => 'Restore from file',
			'backup.existing' => 'Existing backups',
			'backup.none' => 'No backups yet',
			'backup.delete' => 'Delete backup',
			'backup.restore' => 'Restore',
			'backup.restoreConfirm' => ({required String name}) => 'Overwrite current data with “${name}”? The app restarts.',
			'backup.sectionCloud' => 'Cloud & sync',
			'backup.devicesGroup' => 'Cloud and other devices',
			'backup.localGroup' => 'Local backup',
			'backup.createSubtitle' => 'Saves a full copy of the app data (settings, follows, history and more)',
			'backup.restoreFileSubtitle' => 'Restore from a backup file; the app restarts afterwards',
			'backup.filesTitle' => 'Backups in the folder',
			'backup.filesCount' => ({required Object count}) => 'Backups in the folder · ${count}',
			'backup.filesEmpty' => 'No backups yet',
			'backup.filesHint' => 'Backups made here are listed; you can also drop backup files into this folder',
			'backup.filesError' => 'The backup folder cannot be read',
			'backup.retry' => 'Retry',
			'backup.loading' => 'Reading…',
			'backup.kindFull' => 'Full backup',
			'backup.directoryGroup' => 'Backup Directory',
			'backup.directory' => 'Backup directory',
			'backup.directoryDefaultLabel' => 'Backup folder (default)',
			'backup.directoryDefault' => 'The app\'s default folder',
			'backup.chooseDirectory' => 'Choose the backup folder',
			'backup.resetDirectory' => 'Use the default folder',
			'backup.openDirectory' => 'Open the backup folder',
			'backup.directoryUnwritable' => 'This folder cannot be written; pick another one',
			'backup.directoryUpdateFailed' => 'The backup directory was not changed. Try again.',
			'backup.deleteConfirm' => ({required Object name}) => 'Delete the backup file "${name}"?',
			'backup.created' => ({required Object name}) => 'Backed up to ${name}',
			'backup.readFailed' => 'The backup file cannot be read',
			'backup.restored' => ({required Object name}) => 'Restored ${name}',
			'backup.moreActions' => 'More actions',
			'backup.fileTooltip' => 'Click to restore; right-click or ⋮ for more',
			'backup.previewTitle' => 'Restore preview',
			'backup.previewRooms' => ({required Object current, required Object incoming}) => 'Followed rooms: ${current} → ${incoming}',
			'backup.previewGroups' => ({required Object current, required Object incoming}) => 'Follow groups: ${current} → ${incoming}',
			'backup.previewNote' => 'Everything else stays as it is.',
			'backup.restoreNow' => 'Restore now',
			'backup.followsScopeHint' => 'Followed rooms and groups only; other settings stay unchanged',
			'backup.kindFollows' => 'Follows only',
			'backup.deleteFailed' => 'The file could not be deleted',
			'about.native' => 'This device',
			'about.downloadFilesOf' => ({required Object platform}) => 'Downloads · ${platform}',
			'about.title' => 'About',
			'about.group' => 'About',
			'about.checkUpdate' => 'Check for updates',
			'about.onlineUpdate' => 'Online Update',
			'about.versionUpdate' => 'Version Update',
			'about.updateLog' => 'Update Log',
			'about.upToDate' => 'Up to date',
			'about.newVersion' => 'New version available:',
			'about.noNewVersion' => 'You are using the latest version.',
			'about.openSourceFree' => 'This app is open source and free',
			'about.update' => 'Update',
			'about.refresh' => 'Refresh',
			'about.versionHistory' => 'Version history',
			'about.historyDesc' => 'Update history records',
			'about.publishedAt' => ({required String date}) => 'Published at ${date}',
			'about.openRelease' => 'Open release page',
			'about.licenses' => 'License',
			'about.project' => 'Project page',
			'about.projectSection' => 'Project',
			'about.projectAlert' => 'Project Alert',
			'about.legalese' => '© 2026 PureLive Open-Source Project. This program is a pure local client application that directly requests the official public APIs of media platforms. The project itself does not store, host, reproduce, or distribute any audio/video resources. The developer solemnly pledges that this application does not collect, process, or retain any user personal data or privacy information. All operational parameters, local configurations, and synchronized metadata are exclusively retained and controlled by the end-user. Users shall assume all legal responsibilities arising from the use of this testing tool.',
			'about.browserNotOpened' => 'The system browser did not open. Check the default browser settings.',
			'about.checkRunning' => 'Checking…',
			'about.checkFailed' => 'Check failed — tap to retry',
			'about.downloadFiles' => 'Download files',
			'about.copyLink' => 'Copy link',
			'about.copied' => 'Link copied',
			'about.download' => 'Download',
			'about.assetMeta' => ({required String size, required int count}) => '${size} · ${count} downloads',
			'about.startupUpdateBody' => ({required Object tag}) => 'Version ${tag} is out. Open the update page now?',
			'shield.title' => 'Danmaku shield',
			'shield.keywords' => 'Keywords',
			'shield.users' => 'Users',
			'shield.regexes' => 'Regexes',
			'shield.add' => 'Add',
			'shield.none' => 'Nothing here',
			'shield.keywordHint' => 'Keyword to block',
			'shield.emptyKeyword' => 'Type a keyword first',
			'multiview.title' => 'Multi-view',
			'multiview.platform' => 'Platform',
			'multiview.roomId' => 'Room ID',
			'multiview.add' => 'Add cell',
			'multiview.layout' => 'Layout',
			'multiview.pickRoom' => 'Choose a room',
			'multiview.pickHint' => 'Paste a room link or pick a followed room',
			'multiview.emptyCell' => 'Tap to choose a room',
			'multiview.mute' => 'Mute',
			'multiview.unmute' => 'Unmute',
			'multiview.muteAll' => 'Mute all',
			'multiview.unmuteAll' => 'Unmute all',
			'multiview.audioFocus' => 'Playing sound',
			'multiview.removeCell' => 'Remove cell',
			'multiview.noPick' => 'No followed rooms or history yet',
			'search.hint' => 'Search rooms by keyword',
			'search.rooms' => 'Rooms',
			'search.anchors' => 'Anchors',
			'search.areas' => 'Categories',
			'search.allSites' => 'All',
			'search.historyTitle' => 'Recent searches',
			'search.historyRemove' => 'Remove this search',
			'search.webSearch' => 'Web search',
			'search.webSearchTooltip' => 'Web-search the current platform',
			'search.continueWeb' => 'Continue in web search',
			'search.selectPlatformFirst' => 'Pick a platform first',
			'search.needKeyword' => 'Type a keyword first',
			'search.webUnavailableFor' => ({required Object site}) => '${site} has no web search page.',
			'search.webExternalTip' => 'The web search opens in the system browser. Find the live room you want, copy its link, and paste it into the search box to open it here.',
			'search.openInSystemBrowser' => 'Open in system browser',
			'search.externalBrowserNotOpened' => 'The system browser did not open; check the default-browser settings',
			'search.webSearchRoomBanner' => 'This is a live room',
			'search.roomIdLabel' => ({required String roomId}) => 'room ${roomId}',
			'search.roomEnter' => 'Enter',
			'search.webSearchRoomDismiss' => 'Stop offering this room',
			'search.webSearchInvalidAddress' => 'The web-search address is invalid; go back to the search page and try again.',
			'search.webSearchLoadFailed' => 'The page failed to load; check the network or proxy and retry.',
			'search.webSearchUnavailableTitle' => 'Web search unavailable',
			'search.sortMode' => 'Sort',
			'search.sortSmart' => 'Smart',
			'search.sortPlatform' => 'By platform',
			'search.sortAudience' => 'By viewers',
			'search.sortFollowers' => 'By followers',
			'search.includeOffline' => 'Show offline',
			'remoteSync.title' => 'Device Sync',
			'remoteSync.tileSubtitle' => 'Sync configurations between devices over the LAN',
			'remoteSync.myDevice' => 'My Device',
			'remoteSync.noAddress' => 'No LAN address found',
			'remoteSync.scanHint' => 'Let the other device scan this code, or type this device’s address there',
			'remoteSync.running' => 'Sync service running',
			'remoteSync.notRunning' => 'Sync service is not running',
			'remoteSync.start' => 'Start',
			'remoteSync.stop' => 'Stop',
			'remoteSync.devices' => 'Discovered Devices',
			'remoteSync.noDevices' => 'No other devices found',
			'remoteSync.manual' => 'Manual Input',
			'remoteSync.send' => 'Send Settings',
			'remoteSync.receive' => 'Receive Settings',
			'remoteSync.sendSuccess' => 'Sent',
			'remoteSync.sendFailed' => 'Send failed — check the address and whether the other device confirmed',
			'remoteSync.receiveSuccess' => 'Received and applied',
			'remoteSync.receiveFailed' => 'Receive failed',
			'remoteSync.enterAddress' => 'Enter the other device’s address first',
			'remoteSync.invalidAddress' => 'That is not a valid address',
			'remoteSync.incomingImport' => ({required String address}) => '${address} wants to overwrite this device’s follows, history and shield. Allow?',
			'remoteSync.incomingExport' => ({required String address}) => '${address} wants to read this device’s follows, history and shield. Allow?',
			'remoteSync.sectionFavorite' => 'Followed rooms',
			'remoteSync.sectionHistory' => 'Watch history',
			'remoteSync.sectionGroups' => 'Follow groups',
			'remoteSync.noAddressHint' => 'Connect to Wi-Fi or a wired network; on Android allow the "Nearby devices / local network" permission, then tap Start at the top right',
			'remoteSync.description' => 'Make sure both devices are connected to the same local network',
			'remoteSync.searching' => 'Searching for devices on the local network...',
			'remoteSync.searchingShort' => 'Searching',
			'remoteSync.manualHint' => 'Type the other device\'s address, or paste its QR code\'s sync link (it carries the pairing code)',
			'remoteSync.copyAddress' => 'Copy Address',
			'remoteSync.addressCopied' => 'Address copied',
			'remoteSync.fromName' => ({required String name}) => 'From ${name}',
			'remoteSync.legacyDevice' => 'Pure Live 3.x device',
			'remoteSync.allow' => 'Allow',
			'remoteSync.reject' => 'Reject',
			'remoteSync.incomingImportNamed' => ({required Object address, required Object name}) => '${address} (${name}) asks to replace this device’s settings with its own. Allow?',
			'remoteSync.incomingExportNamed' => ({required Object address, required Object name}) => '${address} (${name}) asks to read this device’s settings. Allow?',
			'remoteSync.pairingCode' => 'Pairing code',
			'remoteSync.pairingCodeFor' => ({required String name}) => 'Enter the 6-digit pairing code shown on “${name}”',
			'remoteSync.pairingCodeInvalid' => 'The pairing code should be 6 digits',
			'remoteSync.partsAll' => 'Select all',
			'remoteSync.partsLegacy' => 'The other device is version 3.x or earlier (or did not answer), so it can only receive everything.',
			'remoteSync.partsSendNamed' => ({required String name}) => 'Tick what to send to “${name}”. After it confirms, the ticked parts replace its own; unticked parts stay.',
			'remoteSync.confirmSendNamed' => ({required String name}) => 'Send this device\'s full configuration to “${name}”? Its user confirms, and it replaces the other device\'s.',
			'remoteSync.previewTitle' => 'Receiving would change this:',
			'remoteSync.previewSettings' => ({required int count, required int changed}) => 'Settings: ${count} items, ${changed} differ from this device',
			'remoteSync.previewNoAccounts' => 'Accounts: the other device left “Sync account cookies” off; this device\'s sign-ins stay',
			'remoteSync.previewAccountsEmpty' => 'Accounts: the other device has no sign-ins; this device\'s stay as they are',
			'remoteSync.previewWarning' => 'Receiving merges the ticked parts; unticked ones stay. Settings follow the other device and cannot be undone — create a backup under “Backup & restore” first if needed.',
			'remoteSync.partCount' => ({required String part, required int count}) => '${part} (${count})',
			'remoteSync.partSettings' => 'Settings',
			'remoteSync.partFollows' => 'Follow list',
			'remoteSync.partHistory' => 'Watch history',
			'remoteSync.partGroups' => 'Follow groups',
			_ => null,
		} ?? switch (path) {
			'remoteSync.partKeywords' => 'Blocked keywords',
			'remoteSync.partUsers' => 'Blocked users',
			'remoteSync.partWebdav' => 'WebDAV servers',
			'remoteSync.partAccounts' => 'Account cookies',
			'remoteSync.includeAccounts' => 'Sync account cookies',
			'remoteSync.includeAccountsHint' => 'Sends or serves the platform login cookies and WebDAV passwords; turn it on only between devices you trust',
			'remoteSync.receiveAction' => 'Receive',
			'remoteSync.sendAction' => 'Send',
			'remoteSync.invalidQr' => 'Not a PureLive sync QR code',
			'errors.generic' => 'Something went wrong. Please try again later.',
			'errors.network' => 'Network unavailable. Check your connection and retry.',
			'errors.notFound' => 'Nothing found.',
			'errors.cancelled' => 'Cancelled.',
			'errors.unsupported' => 'This source doesn\'t support that.',
			'tabs.home' => 'Home',
			'tabs.favorites' => 'Favorites',
			'tabs.follow' => 'Follow',
			'tabs.history' => 'History',
			'tabs.popular' => 'Popular',
			'tabs.areas' => 'Areas',
			'tabs.search' => 'Search',
			'tabs.settings' => 'Settings',
			'tabs.record' => 'Recordings',
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
			'shellSettings.titleBarAuto' => 'Auto (by Windows version)',
			'shellSettings.titleBarApp' => 'App title bar',
			'shellSettings.titleBarSystem' => 'System title bar',
			'shellSettings.titleBarHint' => 'Auto: the app title bar on Windows 11, the system title bar on Windows 10. The app title bar is drawn by Pure Live; the system title bar is the native Windows one. A switch applies after the app restarts.',
			'shellSettings.frameDiagnosis' => 'Window frame diagnosis',
			'shellSettings.frameTakeover' => 'Frame takeover',
			'shellSettings.frameTakeoverOn' => 'On — the caption is gone and the window\'s own hit-test answers the four edges',
			'shellSettings.frameTakeoverOff' => 'Off — the system draws the caption and sizes the window',
			'shellSettings.frameEdge' => 'Frame edge',
			'shellSettings.frameEdgeNative' => 'Windows draws it',
			'shellSettings.frameEdgeNone' => 'This Windows version draws none, so a taken-over window has no line on any side',
			'shellSettings.frameBuild' => 'Windows build',
			'shellSettings.frameSweep' => 'Run the resize sweep',
			'shellSettings.frameSweepRunning' => 'Sweeping…',
			'shellSettings.frameSweepHint' => 'Resizes this window repeatedly, twice, then puts it back. The two lines compare the plugin\'s view pre-sync off and on — fewer stale frames on the second line is the frame keeping up with the drag.',
			'shellSettings.frameSweepUnavailable' => 'The sweep needs the frame takeover on, on Windows.',
			'webdav.title' => 'WebDAV cloud backup',
			'webdav.entryTitle' => 'WebDAV cloud sync',
			'webdav.entrySubtitle' => 'Back up to your own WebDAV server',
			'webdav.sectionConfig' => 'Server',
			'webdav.addressHint' => 'https://dav.jianguoyun.com/dav/',
			'webdav.addressInvalid' => 'Enter a valid http(s) address',
			'webdav.username' => 'Account',
			'webdav.password' => 'App password',
			'webdav.directory' => 'Directory (optional)',
			'webdav.testConnection' => 'Test connection',
			'webdav.testing' => 'Connecting…',
			'webdav.testOk' => 'Connected. The address, account and password all work.',
			'webdav.testFailed' => 'Connection failed',
			'webdav.backupNow' => 'Back up now',
			'webdav.backingUp' => 'Uploading backup…',
			'webdav.backupDone' => 'Backup uploaded',
			'webdav.configIncomplete' => 'Fill in the server address, account and app password first',
			'webdav.lastBackup' => 'Last backup',
			'webdav.lastRestore' => 'Last restore',
			'webdav.never' => 'Never',
			'webdav.remote' => 'Remote backups',
			'webdav.remoteEmpty' => 'No remote backups yet',
			'webdav.restore' => 'Restore',
			'webdav.restoreConfirm' => 'Download this backup and overwrite the current data? The app restarts.',
			'webdav.delete' => 'Delete',
			'webdav.deleteConfirm' => 'Delete this backup from the server?',
			'webdav.helpTitle' => 'How to configure',
			'webdav.helpIntro' => 'Cloud backup sends the same archive the local backups use to your own WebDAV server, so your follows, history and settings survive a reinstall. Any WebDAV service works; the steps below use Jianguoyun (Nutstore) as the example.',
			'webdav.helpSteps' => '1. Register and log in at www.jianguoyun.com.\n2. Open Options → Security and generate an app password.\n3. Enter the server address, your account and that app password above.',
			'webdav.helpServer' => 'Server: Jianguoyun\'s WebDAV address is https://dav.jianguoyun.com/dav/',
			'webdav.helpAccount' => 'Account: your Jianguoyun login name (usually a phone number or an e-mail).',
			'webdav.helpPassword' => 'Password: not your login password — WebDAV needs the app password generated under Options → Security.',
			'webdav.helpIssues' => 'Connection failed? Check that the address ends with /dav/, that you used the app password rather than the login password, and that your network does not block WebDAV ports.',
			'webdav.openOfficialHelp' => 'Open the official Jianguoyun help',
			'webdav.helpOpenFailed' => 'Could not open the browser',
			'webdav.servers' => 'WebDAV servers',
			'webdav.noServer' => 'No server yet',
			'webdav.noConfigCreateFirst' => 'No configs yet — create a WebDAV config first',
			'webdav.intro' => 'Add a WebDAV drive (Jianguoyun, Nextcloud…) to upload backups and restore them on other devices.',
			'webdav.createNew' => 'Create a config',
			'webdav.openList' => 'Open the config list',
			'webdav.refresh' => 'Refresh',
			'webdav.moreActions' => 'More actions',
			'webdav.uploadFavorites' => 'Upload the follows list only',
			'webdav.uploadFull' => 'Upload the full backup',
			'webdav.helpTutorial' => 'Help tutorial',
			'webdav.nameExists' => 'That config name already exists',
			'webdav.selectFailed' => 'The WebDAV selection was not saved. Try again.',
			'webdav.configDeleteFailed' => 'The WebDAV config was not deleted. Try again.',
			'webdav.confirmDeleteConfig' => ({required Object name}) => 'Delete the config “${name}”?',
			'webdav.confirmDeleteItem' => ({required Object name}) => 'Delete “${name}” from WebDAV?',
			'webdav.deleteSuccess' => 'File deleted successfully',
			'webdav.deleteFailed' => 'File deletion failed',
			'webdav.uploadFailed' => 'File upload failed',
			'webdav.downloadFailed' => 'File download failed',
			'webdav.restoreAllSettings' => 'Restore all settings',
			'webdav.restoreFavorites' => 'Restore the follows list only',
			'webdav.folderEmpty' => 'This folder is empty',
			'webdav.serverName' => 'Config name',
			'webdav.editServer' => 'Edit config',
			'webdav.deleteServer' => 'Delete config',
			'webdav.activeMark' => 'In use',
			'webdav.saved' => 'Config saved',
			'webdav.restored' => ({required Object name}) => 'Restored from ${name}',
			'webdav.uploaded' => ({required Object name}) => 'Uploaded ${name}',
			'webdav.secretsNote' => 'This device cannot open its secret vault — the password lives only in this page',
			'wallpaper.title' => 'Wallpaper',
			'wallpaper.entrySubtitle' => 'Solid colours, gradients or a picture',
			'wallpaper.currentNone' => 'Theme default',
			'wallpaper.currentSolid' => 'Solid colour',
			'wallpaper.currentGradient' => 'Gradient',
			'wallpaper.currentImage' => 'Picture',
			'wallpaper.groupPresets' => 'Presets',
			'wallpaper.groupSolid' => 'Solid colours',
			'wallpaper.groupGradient' => 'Gradients',
			'wallpaper.groupDevice' => 'From this device',
			'wallpaper.groupDisplay' => 'Picture display',
			'wallpaper.none' => 'No wallpaper',
			'wallpaper.noneSubtitle' => 'Keep the themed surfaces',
			'wallpaper.pickImage' => 'Pick a picture',
			'wallpaper.pickImageSubtitle' => 'Choose an image stored on this device',
			'wallpaper.imagePath' => 'Image path',
			'wallpaper.imagePathHint' => 'Enter an absolute image path',
			'wallpaper.scrim' => 'Dim picture',
			'wallpaper.scrimSubtitle' => 'A wash over the picture so text stays readable',
			'wallpaper.blur' => 'Blur picture',
			'wallpaper.blurOff' => 'Off',
			'wallpaper.fit' => 'Fill mode',
			'wallpaper.fitCover' => 'Cover',
			'wallpaper.fitContain' => 'Contain',
			'wallpaper.fitFill' => 'Stretch',
			'wallpaper.imageMissing' => 'Picture not found; check the path',
			'cast.title' => 'Cast',
			'cast.hint' => 'Pick a device on this network that can receive the cast',
			'cast.searching' => 'Searching for cast devices on the network…',
			'cast.noDevices' => 'No cast devices yet',
			'cast.castingTo' => ({required String name}) => 'Casting to ${name}',
			'cast.stop' => 'Stop casting',
			'cast.failed' => 'Cast failed — the device may not be able to reach this URL',
			'cast.statePlaying' => 'Playing',
			'cast.statePaused' => 'Paused',
			'cast.stateBuffering' => 'Buffering',
			'cast.stateStopped' => 'Stopped',
			'cast.stateUnreachable' => 'Device not answering',
			'danmaku.liveHint' => 'Changes apply at once',
			'danmaku.templateGroup' => 'Viewing template',
			'danmaku.templateBest' => 'Top 20% · Balanced',
			'danmaku.templateComfort' => 'Top 35% · Comfortable',
			'danmaku.templateDense' => 'Top 55% · Dense',
			'danmaku.templateReset' => 'Reset',
			'danmaku.bestDesc' => 'Barrage stays in the top 20% of the picture at a middle speed and density, clear of the subject.',
			'danmaku.comfortDesc' => 'Barrage takes the top 35%; a slightly larger font and slower lines, easier to read.',
			'danmaku.denseDesc' => 'Barrage takes the top 55%; a smaller font and faster lines keep up with a busy room.',
			'danmaku.resetDesc' => 'Back to the defaults: full height, opaque, default speed and size.',
			'danmaku.customDesc' => 'Custom: the current answers match none of the templates — save them as yours.',
			'danmaku.saveMine' => 'Save the current look as my template',
			'danmaku.useMine' => 'Use my template',
			'danmaku.templateApplied' => 'Danmaku template applied',
			'danmaku.templateSaved' => 'Current danmaku look saved',
			'danmaku.templateEmpty' => 'No saved danmaku template yet',
			'danmaku.templateInvalid' => 'The saved danmaku template is broken or out of range',
			'danmaku.rangeGroup' => 'Display area',
			'danmaku.area' => 'Height used at the top',
			'danmaku.marginTop' => 'Top margin (px)',
			'danmaku.marginBottom' => 'Bottom margin (px)',
			'danmaku.pausedBehavior' => 'Barrage while paused',
			'danmaku.pausedBehaviorDesc' => 'When the video pauses, the barrage holds or keeps flying',
			'danmaku.pausedPause' => 'Pause with the video',
			'danmaku.pausedFly' => 'Keep flying',
			'danmaku.styleGroup' => 'Style',
			'danmaku.opacity' => 'Opacity',
			'danmaku.speed' => 'Speed (px/s)',
			'danmaku.fontSize' => 'Font size',
			'danmaku.fontWeight' => 'Font weight',
			'danmaku.weightThin' => 'Thin',
			'danmaku.weightExtraLight' => 'Extra light',
			'danmaku.weightLight' => 'Light',
			'danmaku.weightNormal' => 'Normal',
			'danmaku.weightMedium' => 'Medium',
			'danmaku.weightSemiBold' => 'Semibold',
			'danmaku.weightBold' => 'Bold',
			'danmaku.weightExtraBold' => 'Extra bold',
			'danmaku.weightBlack' => 'Black',
			'danmaku.stroke' => 'Barrage outline',
			'danmaku.strokeWidth' => 'Outline width',
			'danmaku.noEmoji' => 'Pure text mode (hide emoji)',
			'danmaku.smoothGroup' => 'Smoothness',
			'danmaku.repeatGroup' => 'Repeated danmaku',
			'danmaku.collapse' => 'Collapse identical danmaku bursts',
			'danmaku.collapseDesc' => 'Keep the first copy when different users send the same text. Local and system messages are unaffected.',
			'danmaku.collapseWindow' => 'Identical-text window (seconds)',
			'danmaku.fps' => 'Barrage frame rate',
			'danmaku.fpsValue' => ({required int count}) => '${count} FPS',
			'danmaku.maxVisible' => 'Most lines on screen',
			'danmaku.maxVisibleValue' => ({required int count}) => '${count} lines',
			'danmaku.interactionGroup' => 'Touch interaction',
			'danmaku.holdOnPress' => 'Hold a line to stop it',
			'danmaku.holdOnPressDesc' => 'Pressing a flying line holds only that line; the rest keep flying, and it resumes on release.',
			'danmaku.listGroup' => 'Chat list',
			'danmaku.listStyle' => 'Chat list style',
			'danmaku.listCompact' => 'Compact',
			'danmaku.listCard' => 'Card',
			'danmaku.listFontSize' => 'Chat text size',
			'danmaku.listLineSpacing' => 'Line spacing',
			'danmaku.showSender' => 'Show sender names',
			'danmaku.showGifts' => 'Gifts in flying danmaku',
			'danmaku.showGiftsDesc' => 'Gift messages fly over the picture as well',
			'danmaku.tapAction' => 'Tap an on-screen danmaku for actions',
			'danmaku.longPressAction' => 'Long-press an on-screen danmaku for block actions',
			'danmaku.autoFps' => 'Danmaku frame rate follows the display',
			'danmaku.autoFpsDesc' => 'Follows the power saving, balanced or highest level; turn it off to set the rate yourself.',
			'danmaku.fpsMode' => 'Refresh-rate tier',
			'danmaku.fpsModePowerSaving' => 'Power saving',
			'danmaku.fpsModeBalanced' => 'Balanced',
			'danmaku.fpsModeHighest' => 'Highest',
			'danmaku.fontFamily' => 'Danmaku font',
			'clipboard.title' => 'A live-room link in your clipboard',
			'clipboard.found' => ({required Object site, required Object room}) => '${site} room ${room} — take a look now?',
			'clipboard.go' => 'Open',
			_ => null,
		};
	}
}
