import 'package:flutter/material.dart';
import 'package:live_uikit/live_uikit.dart';

import 'package:pure_live/src/pages/discover_page.dart';
import 'package:pure_live/src/pages/follows_page.dart';
import 'package:pure_live/src/pages/iptv_page.dart';
import 'package:pure_live/src/pages/settings_page.dart';
import 'package:pure_live/src/services.dart';
import 'package:pure_live/src/ui/app_shell.dart';
import 'package:pure_live/src/ui/ui_configuration.dart';

/// The application: the scopes that make the rest of the tree render.
///
/// Two things live here and nowhere else. First, the *order*: the environment
/// scope (where the UI runs) wraps the theme scope (what it looks like),
/// which wraps the app, which wraps the shell — so a page reading either one
/// always finds it. Second, the theme *re-resolution*: the theme is rebuilt
/// from the preferences whenever they change, and that rebuild is what makes
/// "switch to Neumorphic" a one-frame change instead of a restart.
///
/// What does *not* happen here is business work. Switching a design language
/// rebuilds this widget and nothing else: no session is re-created, no
/// connection is dropped, no room is re-fetched, because the theme is derived
/// state and the services are not.
class PureLiveApp extends StatefulWidget {
  /// The application over [services].
  const new({required this.services, super.key});

  /// The built service graph.
  final PureLiveServices services;

  @override
  State<PureLiveApp> createState() => _PureLiveAppState();
}

class _PureLiveAppState extends State<PureLiveApp> with WidgetsBindingObserver {
  late final LiveComponentRegistry _registry = UiConfigurationMapper.registry();
  late final LiveThemeResolver _resolver = LiveThemeResolver(
    _registry,
    onFallback: (note) => widget.services.log.forCategory('app.theme').warning(note),
  );
  late LiveUiEnvironment _baseEnvironment;
  bool _platformDark = false;
  bool _environmentResolved = false;
  bool _initialised = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _platformDark = WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    widget.services.preferences.changes.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_environmentResolved) {
      // The window size is only known once there is a view; until then the
      // environment is built for width 0, which resolves to the mobile layout
      // and is corrected on the first frame the view reports its size.
      _baseEnvironment = UiConfigurationMapper.environmentOf(widget.services.runtime.environment);
      _environmentResolved = true;
    }
    if (!_initialised) {
      _initialised = true;
      final facts = widget.services.runtime.environment;
      widget.services.log
          .forCategory('app.theme')
          .info(
            'UI configuration resolved',
            fields: {
              'platform': UiConfigurationMapper.platformOf(facts).name,
              'layoutMode': _baseEnvironment.layoutMode.name,
            },
          );
    }
  }

  @override
  void didChangePlatformBrightness() {
    _platformDark = WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preferences = widget.services.preferences.value;
    final configuration = UiConfigurationMapper.configurationOf(preferences, platform: _baseEnvironment.platform);
    final theme = _resolver.resolve(
      configuration: configuration,
      environment: _baseEnvironment,
      platformDark: _platformDark,
    );
    final brightness = configuration.resolveBrightness(platformDark: _platformDark);
    return MaterialApp(
      title: 'Pure Live',
      debugShowCheckedModeBanner: false,
      theme: theme.materialTheme,
      darkTheme: theme.materialTheme,
      themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
      home: LiveEnvironmentScope(
        environment: _baseEnvironment,
        child: LiveThemeScope(
          theme: theme,
          child: LiveLayoutBuilder(
            baseEnvironment: _baseEnvironment,
            breakpoints: configuration.breakpoints,
            builder: (context, environment) =>
                AppShell(services: widget.services, theme: theme, destinations: _destinations(widget.services)),
          ),
        ),
      ),
    );
  }

  List<AppDestination> _destinations(PureLiveServices services) => [
    AppDestination(
      id: 'discover',
      label: 'Discover',
      icon: Icons.explore_outlined,
      selectedIcon: Icons.explore,
      pageBuilder: (context) => DiscoverPage(services: services),
    ),
    AppDestination(
      id: 'follows',
      label: 'Follows',
      icon: Icons.favorite_outline,
      selectedIcon: Icons.favorite,
      pageBuilder: (context) => FollowsPage(services: services),
    ),
    AppDestination(
      id: 'iptv',
      label: 'IPTV',
      icon: Icons.live_tv_outlined,
      selectedIcon: Icons.live_tv,
      pageBuilder: (context) => IptvPage(services: services),
    ),
    AppDestination(
      id: 'settings',
      label: 'Settings',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      pageBuilder: (context) => SettingsPage(services: services),
    ),
  ];
}
