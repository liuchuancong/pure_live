import 'dart:async';
import 'dart:io' show exit;

import 'package:flutter/material.dart';
import 'package:live_preferences/live_preferences.dart' show Preferences;
import 'package:live_uikit/styling.dart';
import 'package:live_uikit_cupertino_ui/live_uikit_cupertino_ui.dart';
import 'package:live_uikit_fluent/live_uikit_fluent.dart';
import 'package:live_uikit_glass/live_uikit_glass.dart';
import 'package:live_uikit_macos/live_uikit_macos.dart';
import 'package:live_uikit_material_ui/live_uikit_material_ui.dart';
import 'package:live_uikit_neumorphic/live_uikit_neumorphic.dart';
import 'package:live_uikit_wind/live_uikit_wind.dart';
import 'package:pure_live/appearance_mapping.dart';
import 'package:pure_live/background_demo_page.dart';
import 'package:pure_live/desktop_boot.dart';
import 'package:pure_live/services.dart';
import 'package:pure_live/settings_page.dart';

/// PureLive — the application entry.
///
/// `main` boots [AppServices] (storage, preferences and the site registry) and
/// runs [PureLiveApp]. The active [UiConfig] is derived from the persisted
/// appearance and fed to a root `LiveConfigProvider`, so every screen — and any
/// route pushed on the navigator — reads the same resolved [LiveTheme].
Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  // The lock before anything is drawn: a second copy of this app must reach the
  // instance that is already running instead of opening a window nobody asked
  // for. On a phone this says nothing and costs nothing.
  final claim = await DesktopBootstrap.claimInstance(arguments);
  if (claim.shouldExit) {
    // Returning from `main` does not end a desktop Flutter process: the runner's
    // message loop is already going and keeps going, which is how "the app is
    // already running" turns into a second silent process in the task list. The
    // handoff has been delivered by now, so leave immediately.
    exit(0);
  }
  final services = await AppServices.boot();
  // The shell comes up before the tree: it restores the window's remembered place
  // and decides whether this start shows a window at all, and neither question
  // wants to be answered after the first frame has already been painted in the
  // wrong place.
  final desktop = await DesktopBootstrap.start(services: services, arguments: arguments, claim: claim);
  runApp(PureLiveApp(services: services, desktop: desktop));
}

/// The root application: watches preferences and re-skins the whole app —
/// including pushed routes — whenever the saved appearance changes.
class PureLiveApp extends StatelessWidget {
  /// The root app, over the booted [services] and the [desktop] shell handle.
  const new({required this.services, this.desktop, super.key});

  /// The application's booted services.
  final AppServices services;

  /// The desktop shell this process runs under, null on a platform with none.
  ///
  /// Held by the tree rather than by a global, so a hot restart rebuilds it and
  /// the settings screen can reach it without the app inventing a second one.
  final DesktopBootstrap? desktop;

  @override
  Widget build(BuildContext context) => StreamBuilder<Preferences>(
    stream: services.preferences.changes,
    initialData: services.preferences.value,
    builder: (context, snapshot) => LiveConfigProvider(
      config: uiConfigFromAppearance(snapshot.data!.appearance),
      // Report, never silently swallow, a language whose adapter isn't registered
      // — the core hands the event here; the app owns the logging (§3.10).
      diagnostics: (diagnostic) => debugPrint('[live_uikit] $diagnostic'),
      // The composition root registers every third-party adapter; the core
      // itself never depends on a UI library. The shared token base serves the
      // `material`/`cupertino` languages (the `material` language is the default
      // fallback); the `materialUi`/`cupertinoUi` forks are separate native
      // adapters registered below.
      registry: const LanguageRegistry(
        adapters: {
          LiveDesignLanguage.macos: macosUiAdapter,
          LiveDesignLanguage.fluent: fluentUiAdapter,
          LiveDesignLanguage.neumorphic: neumorphicUiAdapter,
          LiveDesignLanguage.glass: glassUiAdapter,
          LiveDesignLanguage.wind: windUiAdapter,
          LiveDesignLanguage.cupertinoUi: cupertinoUiAdapter,
          LiveDesignLanguage.materialUi: materialUiAdapter,
        },
        fallback: SharedLanguageAdapter(),
      ),
      child: MaterialApp(
        title: 'Pure Live',
        debugShowCheckedModeBanner: false,
        // Install every design language's localizations up front, so switching
        // UiConfig.language (Cupertino / macOS / fluent) never crashes on a
        // missing delegate further down the tree.
        localizationsDelegates: const [
          ...liveLocalizationsDelegates,
          ...fluentLocalizationsDelegates,
          ...cupertinoUiLocalizationsDelegates,
          ...materialUiLocalizationsDelegates,
        ],
        supportedLocales: const [Locale('en'), Locale('zh')],
        home: HomePage(services: services),
      ),
    ),
  );
}

/// The demo home page: a language/theme switcher over a component gallery.
class HomePage extends StatefulWidget {
  /// The home page, reading and writing the theme through [services].
  const new({required this.services, super.key});

  /// The booted services backing theme persistence and the site registry.
  final AppServices services;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _field = TextEditingController();
  double _slider = 0.4;
  bool _switch = true;
  bool _check = true;
  int _segment = 0;
  int _tab = 0;
  String _quality = 'hd';

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  /// Persists a new config; the root provider rebuilds from the change stream.
  void _apply(UiConfig config) =>
      unawaited(widget.services.preferences.updateAppearance((_) => appearanceFromUiConfig(config)));

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    final config = theme.config;
    return Scaffold(
      backgroundColor: theme.colors.bgLayout,
      appBar: AppBar(
        title: const Text('Pure Live UI Kit'),
        backgroundColor: theme.colors.bgContainer,
        foregroundColor: theme.colors.text,
      ),
      body: ListView(
        padding: EdgeInsets.all(theme.card.padding),
        children: [
          _Section(
            title: 'Design language',
            child: Wrap(
              spacing: theme.card.padding * 0.5,
              runSpacing: theme.card.padding * 0.5,
              children: [
                for (final language in LiveDesignLanguage.values)
                  LiveButton(
                    label: language.name,
                    variant: config.language == language ? ButtonVariant.primary : ButtonVariant.secondary,
                    onPressed: () => _apply(config.copyWith(language: language)),
                  ),
              ],
            ),
          ),
          _Section(
            title: 'Appearance',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LiveSegmented(
                  labels: const ['System', 'Light', 'Dark'],
                  index: switch (config.brightness) {
                    UiBrightnessMode.system => 0,
                    UiBrightnessMode.light => 1,
                    UiBrightnessMode.dark => 2,
                  },
                  onChanged: (i) => _apply(
                    config.copyWith(
                      brightness: const [UiBrightnessMode.system, UiBrightnessMode.light, UiBrightnessMode.dark][i],
                    ),
                  ),
                ),
                SizedBox(height: theme.card.padding * 0.5),
                Text('Text scale', style: theme.text.body.copyWith(color: theme.colors.text)),
                LiveSlider(
                  value: config.fontScale,
                  min: 0.8,
                  max: 1.6,
                  onChanged: (v) => _apply(config.copyWith(fontScale: v)),
                ),
              ],
            ),
          ),
          _Section(
            title: 'Pages',
            child: Wrap(
              spacing: theme.card.padding * 0.5,
              runSpacing: theme.card.padding * 0.5,
              children: [
                LiveButton(
                  label: 'Settings',
                  onPressed: () =>
                      Navigator.of(context)
                          .push(MaterialPageRoute<void>(builder: (_) => SettingsPage(services: widget.services))),
                ),
                LiveButton(
                  label: 'Background demo',
                  onPressed: () =>
                      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const BackgroundDemoPage())),
                ),
              ],
            ),
          ),
          _Section(
            title: 'Controls',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: theme.card.padding * 0.5,
                  runSpacing: theme.card.padding * 0.5,
                  children: [
                    LiveButton(label: 'Primary', onPressed: () {}),
                    LiveButton(label: 'Secondary', variant: ButtonVariant.secondary, onPressed: () {}),
                    LiveButton(label: 'Ghost', variant: ButtonVariant.ghost, onPressed: () {}),
                    LiveButton(label: 'Danger', variant: ButtonVariant.danger, onPressed: () {}),
                    LiveButton(label: 'Loading', loading: true, onPressed: () {}),
                    LiveIconButton(icon: Icons.favorite, tooltip: 'Favourite', onPressed: () {}),
                  ],
                ),
                SizedBox(height: theme.card.padding * 0.5),
                LiveTextField(controller: _field, placeholder: 'Search rooms…'),
                SizedBox(height: theme.card.padding * 0.5),
                Row(
                  children: [
                    LiveSwitch(value: _switch, onChanged: (v) => setState(() => _switch = v)),
                    SizedBox(width: theme.card.padding),
                    LiveCheckbox(value: _check, label: 'Auto-play', onChanged: (v) => setState(() => _check = v)),
                  ],
                ),
                SizedBox(height: theme.card.padding * 0.5),
                LiveSlider(value: _slider, onChanged: (v) => setState(() => _slider = v)),
                SizedBox(height: theme.card.padding * 0.5),
                LiveSegmented(
                  labels: const ['Live', 'Follows', 'IPTV'],
                  index: _segment,
                  onChanged: (i) => setState(() => _segment = i),
                ),
                SizedBox(height: theme.card.padding * 0.5),
                LiveProgress(value: _slider, showLabel: true),
                SizedBox(height: theme.card.padding * 0.5),
                LiveTabs(
                  tabs: const [
                    LiveTab(label: 'Home'),
                    LiveTab(label: 'Sports'),
                    LiveTab(label: 'News'),
                  ],
                  index: _tab,
                  onChanged: (i) => setState(() => _tab = i),
                ),
                SizedBox(height: theme.card.padding * 0.5),
                LiveSelect<String>(
                  items: const ['hd', 'sd', 'audio'],
                  itemLabel: (v) => v.toUpperCase(),
                  value: _quality,
                  placeholder: 'Quality',
                  onChanged: (v) => setState(() => _quality = v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A titled group over the gallery's sections.
class _Section extends StatelessWidget {
  const new({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: theme.card.padding),
      child: LiveCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.text.title.copyWith(color: theme.colors.text)),
            SizedBox(height: theme.card.padding * 0.5),
            child,
          ],
        ),
      ),
    );
  }
}
