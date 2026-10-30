import 'dart:async' show Timer, unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/services.dart' show HardwareKeyboard, KeyDownEvent, KeyEvent, LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_platform/live_platform.dart' show FormFactor;
import 'package:live_shell/live_shell.dart' show WindowRole;
import 'package:pure_live/app/background/glass/app_component_glass.dart' show AppComponentGlass;
import 'package:pure_live/app/background/settings/background_settings.dart' show backgroundSettingsProvider;
import 'package:pure_live/app/background/tone/background_tone.dart' show backgroundToneProvider;
import 'package:pure_live/app/background/wallpaper/app_background.dart' show AppBackground;
import 'package:pure_live/app/bootstrap/live_scroll_behavior.dart' show LiveScrollBehavior;
import 'package:pure_live/app/bootstrap/proxy_http_overrides.dart' show appProxyLookup;
import 'package:pure_live/app/logging/app_log.dart' show appLog;
import 'package:pure_live/app/providers/providers.dart';
import 'package:pure_live/app/routing/router/app_router.dart' show appRouterProvider;
import 'package:pure_live/app/theme/fonts/font_defaults.dart' show loadGoogleFont;
import 'package:pure_live/app/theme/fonts/free_font_store.dart' show freeFontStoreProvider;
import 'package:pure_live/app/theme/settings/stored_theme.dart' show readStoredAppThemeSettings;
import 'package:pure_live/app/theme/settings/theme_persistence.dart';
import 'package:pure_live/app/theme/settings/theme_settings.dart' show AppThemeScope, AppThemeSettings;
import 'package:pure_live/app/windows/context/refresh_rate_interaction_scope.dart' show RefreshRateInteractionScope;
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/features/version/version.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/layouts/layouts.dart';
import 'package:pure_live/modules/iptv/iptv.dart';
import 'package:pure_live/modules/live/favorites/favorites.dart';
import 'package:pure_live/modules/live/recorder/recorder.dart';
import 'package:pure_live/modules/music/controller/music_deeplink_binding.dart';
import 'package:pure_live/shared/shared.dart';
import 'package:pure_uikit_background/pure_uikit_background.dart' show AppVisibilityObserver;

/// The root: `DsApp` over the viewer's theme settings — the seed from the
/// platform accent or the appearance pane's named tone, light/dark, density
/// and corners all persisted and read back on boot — and the language the
/// appearance pane pins (null = follow the system), both flowing through
/// scopes every page can read.
class PureLiveApp extends ConsumerStatefulWidget {
  const PureLiveApp({this.showStartupSplash = true, super.key});

  /// Whether this window draws the one-shot startup mark. Only the primary
  /// window shows it; a room window that opens later must not flash it.
  final bool showStartupSplash;

  @override
  ConsumerState<PureLiveApp> createState() => _PureLiveAppState();
}

final class _PureLiveAppState extends ConsumerState<PureLiveApp> {
  late AppThemeSettings _settings;

  /// The arbitrary accent colour in force; null for a named tone or the
  /// platform accent. The stored seed string carries the same distinction
  /// across restarts.
  Color? _customSeedColor;

  /// The pinned locale's code ('zh-CN', 'en'), or null to follow the
  /// system; the appearance pane writes through here.
  String? _localeCode;

  /// The startup mark is shown once per process, before the shell settles.
  bool _showSplash = false;

  @override
  void initState() {
    super.initState();
    // The process-wide proxy hook: a client created by any package asks here
    // which route is in force at the moment it opens its connection.
    appProxyLookup = () => ref.read(appProxyRouteProvider);
    // The stored choices land before the first frame builds, so the boot
    // never flashes the defaults. The settings' own builder hook supplies
    // the defaults; the store only overrides what the viewer pinned.
    _settings = readStoredAppThemeSettings();
    _customSeedColor = _readStoredCustomSeedColor();
    _ensureFontLoaded();
    _showSplash = widget.showStartupSplash && ref.read(splashSettingsProvider);
    // The image cache's configured cap is applied once per start, off the
    // first frame so a big tree never waits on the disk walk.
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(enforceConfiguredImageCacheLimit()));
    // The emoticon atlas is one sheet decode for every platform's emoticons;
    // the flying danmaku renders them as text until it lands.
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(loadEmojiAtlas()));
    // The display-rate preference is process-wide: read the monitor and
    // apply the stored mode after the first frame, then keep the reading
    // live while the app runs. All platform calls stay in live_device.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(displayRefreshRateProvider.notifier).start());
    });
    // The cellular quality choice and its settings row both read this live
    // network-interface snapshot; the platform work stays in live_device.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(networkTypeProvider.notifier).start());
    });
    // Every window has its own image cache, so every window arms the cover
    // cache clock; they all read the same persisted choice.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(thumbnailRefreshProvider.notifier).start();
    });
    // One silent release check per process when the viewer left it on. Its
    // result is already rendered by the About pane; a failure stays quiet.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!ref.read(updateSettingsProvider)) return;
      final check = ref.read(versionCheckProvider);
      if (check.checked || check.checking) return;
      unawaited(ref.read(versionCheckProvider.notifier).check());
    });
    ref
      // A running scheduled shutdown belongs to the process, not to the
      // settings pane that offered it.
      ..read(autoShutdownProvider)
      // The guide updater belongs to the process, not to the IPTV page: it
      // starts here and keeps the schedule across tabs and pages.
      ..read(iptvAutoUpdaterProvider);
    // Waiting recording tasks keep checking after their room page closes.
    // Only the primary polls: a clone shares the task store, and two
    // windows starting the same task would capture it twice.
    if (ref.read(isPrimaryWindowProvider)) ref.read(recordingLiveMonitorProvider);
    // lxmusic:// links: one listener per process, started with the root so a
    // cold-start link is caught as soon as the dispatcher's dependencies read.
    if (ref.read(isPrimaryWindowProvider)) ref.read(musicDeeplinkBindingProvider).start();
    // iOS's system picture-in-picture window keeps the picture alive while
    // the app is away and hands it back on return; the kernel's own
    // background pause is off there, so this guard owns the rule.
    if (isSystemPipHost) ref.read(systemPipLifecycleProvider);
    // The primary's stored frame belongs to its main window; every other
    // window was born at a size its opener chose and leaves its size row
    // hidden. There is nothing to read or remember there.
    if (ref.read(platformRuntimeProvider).environment.runtime.formFactor == FormFactor.desktop) {
      HardwareKeyboard.instance.addHandler(_handleNewWindowKey);
      if (ref.read(isPrimaryWindowProvider)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(ref.read(windowSizeProvider.notifier).start());
        });
      }
    }
    _localeCode = ThemePersistence.readLocale();
    if (_localeCode != null) {
      LocaleSettings.setLocaleRawSync(_localeCode!);
    }
  }

  /// Arms the faces the theme and the flying danmaku name: a downloaded
  /// free-font file is registered with the engine from its cached copy, and a
  /// Google family is fetched and registered the first time (then cached on
  /// the device, so later boots are offline). The bundled MiSans and the
  /// system face need nothing.
  void _ensureFontLoaded() {
    unawaited(_armFonts());
  }

  /// Waits for a Google file the theme names: the first build draws with the
  /// fallback face, so the tree lays out once more when the file lands.
  Future<void> _armFonts() async {
    final store = ref.read(freeFontStoreProvider.notifier);
    var fetched = false;
    for (final family in [_settings.fontFamily, ref.read(danmakuStyleProvider).fontFamily]) {
      if (family == null) continue;
      unawaited(store.register(family));
      fetched = await loadGoogleFont(family) || fetched;
    }
    if (fetched && mounted) setState(() {});
  }

  void _updateSettings(AppThemeSettings settings) {
    // The seed is written only when the viewer changed it: boot's platform
    // accent and restored colours already describe the store, and rewriting
    // them on every theme tweak would freeze a system accent.
    final seedChanged = settings.seed != _settings.seed;
    // Picking a theme is the viewer saying "this brightness, not the
    // wallpaper's": stop following the background so the pick takes effect.
    final modeChanged = settings.mode != _settings.mode;
    if (modeChanged) {
      ref.read(backgroundSettingsProvider.notifier).setFollowTone(value: false);
    }
    String? storedSeed;
    Color? customSeed;
    if (seedChanged) {
      for (final (name, seed) in kNamedSeeds) {
        if (seed == settings.seed) storedSeed = name;
      }
      if (storedSeed == null && settings.seed != null) {
        final seed = settings.seed!;
        customSeed = DsOklch(seed.l, seed.c, seed.h).toColor();
        storedSeed = ThemePersistence.encodeSeedColor(customSeed);
      }
    }
    setState(() {
      _settings = settings;
      if (seedChanged) _customSeedColor = customSeed;
    });
    // A preset applied in the font manager (here or projected from another
    // window) is armed the same way the boot arms it.
    _ensureFontLoaded();
    // The pane writes every change the moment it happens; the root reads
    // them back on the next boot.
    unawaited(ThemePersistence.storeMode(settings.mode));
    unawaited(ThemePersistence.storeCorners(settings.cornerStyle));
    unawaited(ThemePersistence.storeContrast(settings.contrast));
    unawaited(ThemePersistence.storeSelectionStyle(settings.selectionStyle));
    unawaited(ThemePersistence.storeAutoClashRule(value: settings.autoClashRule));
    unawaited(ThemePersistence.storeDensity(settings.density));
    unawaited(ThemePersistence.storeFont(settings.fontFamily));
    // Named tone, custom hex, or empty for the platform accent.
    if (seedChanged) unawaited(ThemePersistence.storeSeed(storedSeed));
  }

  /// The custom seed the store holds, or null for a named tone or the
  /// platform accent.
  Color? _readStoredCustomSeedColor() {
    final stored = ThemePersistence.readSeed();
    if (stored == null) return null;
    for (final (name, _) in kNamedSeeds) {
      if (name == stored) return null;
    }
    return ThemePersistence.parseSeedColor(stored);
  }

  /// Pins the language the appearance pane chose; null follows the system.
  void _updateLocale(String? code) {
    final normalized = ThemePersistence.normalizeLocaleCode(code);
    setState(() => _localeCode = normalized);
    if (normalized == null) {
      unawaited(LocaleSettings.useDeviceLocale());
    } else {
      unawaited(LocaleSettings.setLocaleRaw(normalized));
    }
    unawaited(ThemePersistence.storeLocale(normalized));
  }

  bool _handleNewWindowKey(KeyEvent event) {
    if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.keyN) return false;
    final keyboard = HardwareKeyboard.instance;
    final mac = defaultTargetPlatform == TargetPlatform.macOS;
    final modifier = mac ? keyboard.isMetaPressed : keyboard.isControlPressed;
    if (!modifier) return false;
    unawaited(_openNewWindow());
    return true;
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleNewWindowKey);
    super.dispose();
  }

  Future<void> _openNewWindow() async {
    final windows = ref.read(secondaryWindowsProvider);
    if (windows == null) return;
    try {
      await windows.open(role: WindowRole.panel);
    } on Object catch (error, stackTrace) {
      // A window that could not be created simply does not appear.
      appLog
          .forCategory('window')
          .warning('a new window could not be opened', fields: {'error': '$error', 'stack': '$stackTrace'});
    }
  }

  @override
  Widget build(BuildContext context) {
    // A setting changed in another window or through a restore: the store
    // already holds the value, so only the root reads need to run again.
    ref.listen<int>(settingsRevisionProvider, (previous, next) {
      if (!mounted) return;
      final code = ThemePersistence.readLocale();
      if (code != null) {
        LocaleSettings.setLocaleRawSync(code);
      } else {
        unawaited(LocaleSettings.useDeviceLocale());
      }
      // A restore or another window replaced the choice; re-arm the timer.
      ref.read(thumbnailRefreshProvider.notifier).start();
      // A restore or another window replaced the theme: read it again and
      // arm the face it names.
      setState(() {
        _settings = readStoredAppThemeSettings();
        _customSeedColor = _readStoredCustomSeedColor();
        _showSplash = widget.showStartupSplash && ref.read(splashSettingsProvider);
        _localeCode = code;
      });
      _ensureFontLoaded();
    });
    // A desktop list row is a row a pointer can rest on: the extra 12 px
    // over the compact default and the larger leading icon are the
    // reference's density. Phones keep the touch default.
    final desktop = ref.watch(platformRuntimeProvider).environment.runtime.formFactor == FormFactor.desktop;
    // The palette resolves asynchronously and stays null where the platform
    // has none; an enabled switch without one keeps the stored accent.
    final dynamicSeed = ref.watch(dynamicColorSeedProvider).value;
    final activeDynamicSeed = ref.watch(dynamicColorProvider) ? dynamicSeed : null;
    final textScale = ref.watch(textScaleFactorProvider);
    final themeSettings = activeDynamicSeed == null
        ? _settings
        : _settings.rebuild((b) => b..seed = DsSeed.color(activeDynamicSeed));
    // The glass turns the theme's own surface transparent, so cards, lists
    // and hand-painted panels read the wallpaper too — not just the floating
    // layers below.
    final glass = ref.watch<(bool, double)>(
      backgroundSettingsProvider.select((state) => (state.glass, state.glassFill)),
    );
    // The wallpaper picks the ink: with one painting behind the pages, its
    // measured brightness decides whether the app wears its light or dark
    // palette, so text never sits dark-on-dark. The viewer can turn this off
    // and keep their own choice; no tone (no wallpaper, or a measurement
    // still on its way) does the same.
    final followTone = ref.watch(backgroundSettingsProvider.select((settings) => settings.followTone));
    final tone = followTone ? ref.watch(backgroundToneProvider) : null;
    // The translation provider is one per process, above every window (see
    // the entry points): slang keys it with a process-wide GlobalKey, so a
    // second copy inside a second window's tree is a duplicate key.
    return DsApp.router(
      routerConfig: ref.watch(appRouterProvider),
      onGenerateTitle: (context) => context.t.common.appTitle,
      // Every list drags with the mouse and the trackpad, which Flutter's
      // own behavior leaves to the wheel alone.
      scrollBehavior: const LiveScrollBehavior(),
      locale: LocaleSettings.currentLocale.flutterLocale,
      // Material's own strings (an AppBar's back tooltip, a
      // RefreshIndicator's semantics) need MaterialLocalizations; DsApp
      // supplies only the widgets-level ones. Desen's own strings stay —
      // they live under their own type and DsApp appends its delegate.
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      debugShowCheckedModeBanner: false,
      themeMode: tone == null ? _settings.mode : (tone.dark ? DsThemeMode.dark : DsThemeMode.light),
      theme: AppComponentGlass.themeOf(themeSettings.theme(), glass: glass.$1, fill: glass.$2),
      builder: (context, child) {
        final core = AppComponentGlass(
          child: LiveAlertWatcher(
            child: ClipboardRoomWatcher(
              child: AppVisibilityObserver(
                // The wallpaper is the bottom layer of the app: every route
                // sits over it, and the shell's own fill turns translucent
                // while one is set. The observer feeds the video's pause
                // signal.
                child: AppBackground(
                  child: FocusAutoScroll(
                    // A remote or keyboard moves focus by geometry; this
                    // reveals the stop in whichever sidebar, list or settings
                    // column holds it.
                    child: AppThemeScope(
                      settings: _settings,
                      seedColor: _customSeedColor,
                      dynamicSeedColor: activeDynamicSeed,
                      onChanged: _updateSettings,
                      child: AppLocaleScope(localeCode: _localeCode, onChanged: _updateLocale, child: child!),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        // No bar in the app draws step marks: `divisions` still quantizes the
        // value a setting stores, it only stops painting the dots on the
        // track. One theme layer reaches every slider at once — the settings
        // pages and the dialogs they open, the room's danmaku column, the
        // player's own bars.
        final app = DsSliderTheme(
          data: const DsSliderThemeData(style: DsSliderStyle(tickSize: 0)),
          child: core,
        );
        final content = desktop
            ? CallbackShortcuts(
                bindings: {
                  SingleActivator(
                    LogicalKeyboardKey.keyN,
                    control: defaultTargetPlatform != TargetPlatform.macOS,
                    meta: defaultTargetPlatform == TargetPlatform.macOS,
                  ): () =>
                      unawaited(_openNewWindow()),
                },
                child: DsListRowTheme(
                  data: const DsListRowThemeData(style: DsListRowStyle(height: 60, iconSize: 18, gap: 16)),
                  child: DsListSectionTheme(
                    data: const DsListSectionThemeData(style: DsListSectionStyle(padding: EdgeInsets.all(8))),
                    child: app,
                  ),
                ),
              )
            : app;
        // Android's balanced rate follows real interaction in the
        // reference; wrapping the live tree is the only way to see every
        // pointer and scroll without touching individual pages. The scope
        // stays at index 0 while the splash comes and goes, so dismissing
        // the splash never releases and re-requests the selected rate.
        // The text-size preference multiplies the platform's own scale for
        // every route at once, the splash overlay included.
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: AppTextScaler(MediaQuery.textScalerOf(context), textScale)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (defaultTargetPlatform == TargetPlatform.android)
                RefreshRateInteractionScope(child: content)
              else
                content,
              if (_showSplash)
                StartupSplash(
                  onDone: () {
                    if (mounted) setState(() => _showSplash = false);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The one-shot startup mark: held briefly, faded, then removed by the root.
final class StartupSplash extends StatefulWidget {
  /// Creates the overlay.
  const StartupSplash({required this.onDone, super.key});

  /// Called after the fade; the root removes the overlay.
  final VoidCallback onDone;

  @override
  State<StartupSplash> createState() => _StartupSplashState();
}

final class _StartupSplashState extends State<StartupSplash> with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    value: 1,
  );
  Timer? _hold;

  @override
  void initState() {
    super.initState();
    _hold = Timer(const Duration(milliseconds: 900), () async {
      await _fade.reverse();
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _hold?.cancel();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    return FadeTransition(
      opacity: _fade,
      child: ColoredBox(
        color: colors.surface,
        child: const Center(child: AppMark(size: 72)),
      ),
    );
  }
}

/// The pinned language and a way to change it, above the whole tree: the
/// appearance pane writes through [onChanged], the root applies it at once.
class AppLocaleScope extends InheritedWidget {
  /// Exposes [localeCode] with [onChanged] to [child].
  const AppLocaleScope({required this.localeCode, required this.onChanged, required super.child, super.key});

  /// The pinned locale's code, or null to follow the system.
  final String? localeCode;

  /// Applies a new pin.
  final ValueChanged<String?> onChanged;

  /// The nearest scope.
  static AppLocaleScope of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppLocaleScope>()!;

  @override
  bool updateShouldNotify(AppLocaleScope old) => old.localeCode != localeCode;
}
