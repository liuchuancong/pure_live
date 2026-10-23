import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/app/bootstrap/app_bootstrap.dart' show bootstrap;
import 'package:pure_live/app/bootstrap/startup_error_page.dart' show StartupErrorPage;
import 'package:pure_live/app/providers/environment_providers.dart' show platformRuntimeProvider;
import 'package:pure_live/app/providers/storage_providers.dart' show storagePathsProvider;
import 'package:pure_live/app/providers/window_providers.dart' show windowHostProvider;
import 'package:pure_live/app/theme/system_accent_color.dart' show readSystemAccentColor;
import 'package:pure_live/app/theme/theme_settings.dart' show AppThemeScope, AppThemeSettings;
import 'package:pure_live/i18n/translations.g.dart';
import 'package:pure_live/layouts/app_layout.dart' show AppLayout;

Future<void> main() async {
  final boot = await bootstrap();
  if (boot.failed) {
    runApp(StartupErrorPage(error: boot.error!));
    return;
  }
  runApp(
    ProviderScope(
      overrides: [
        platformRuntimeProvider.overrideWithValue(boot.runtime),
        windowHostProvider.overrideWithValue(boot.windowHost),
        storagePathsProvider.overrideWithValue(boot.storagePaths!),
      ],
      child: const PureLiveApp(),
    ),
  );
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
        builder: (context, child) => AppThemeScope(settings: _settings, onChanged: _updateSettings, child: child!),
        home: const AppLayout(),
      ),
    );
  }
}

/// The first screen: the canvas colour under the theme, until the real
/// shell replaces it.
class Placeholder extends StatelessWidget {
  const Placeholder({super.key});

  @override
  Widget build(BuildContext context) {
    final t = DsTheme.of(context);
    return ColoredBox(color: t.colors.canvas, child: const SizedBox.expand());
  }
}
