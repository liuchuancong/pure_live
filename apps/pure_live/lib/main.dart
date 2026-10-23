import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';

import 'package:pure_live/app/theme/system_accent_color.dart'
    show preloadSystemAccent, readSystemAccentColor;
import 'package:pure_live/app/theme/theme_settings.dart' show AppThemeScope, AppThemeSettings;
import 'package:pure_live/i18n/translations.g.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The accent read is asynchronous and the settings below are built once,
  // so it lands before the first frame instead of recolouring afterwards.
  await preloadSystemAccent();
  runApp(const PureLiveApp());

}

/// The root: `DsApp` over the viewer's theme settings — the seed from the
/// platform accent, light/dark following the system, density following the
/// platform, everything the settings screen changes flowing through
/// [AppThemeScope].
class PureLiveApp extends StatefulWidget {
  const PureLiveApp({super.key});

  @override
  State<PureLiveApp> createState() => _PureLiveAppState();
}

final class _PureLiveAppState extends State<PureLiveApp> {
  AppThemeSettings _settings = AppThemeSettings((b) => b.seed = _defaultSeed());

  static DsSeed _defaultSeed() {
    final accent = readSystemAccentColor();
    return accent == null ? DsSeed.blue : DsSeed.color(accent);
  }

  void _updateSettings(AppThemeSettings settings) {
    setState(() => _settings = settings);
    // Persistence arrives with the storage wiring; the scope already
    // carries the change to every widget that reads it.
  }

  @override
  Widget build(BuildContext context) {
    return TranslationProvider(
      child: DsApp(
        onGenerateTitle: (context) => context.t.app.title,
        locale: LocaleSettings.currentLocale.flutterLocale,
        debugShowCheckedModeBanner: false,
        themeMode: _settings.mode,
      theme: _settings.theme(),
        builder: (context, child) => AppThemeScope(
          settings: _settings,
          onChanged: _updateSettings,
          child: child!,
        ),
        home: const _HomePlaceholder(),
      ),
    );
  }
}

/// The first screen: the canvas colour under the theme, until the real
/// shell replaces it.
class _HomePlaceholder extends StatelessWidget {
  const _HomePlaceholder();

  @override
  Widget build(BuildContext context) {
    final t = DsTheme.of(context);
    return ColoredBox(color: t.colors.canvas, child: const SizedBox.expand());
  }
}
