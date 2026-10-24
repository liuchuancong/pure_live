import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/routing/app_router.dart' show appRouterProvider;
import 'package:pure_live/app/theme/system_accent_color.dart' show readSystemAccentColor;
import 'package:pure_live/app/theme/theme_persistence.dart';
import 'package:pure_live/app/theme/theme_settings.dart' show AppThemeScope, AppThemeSettings;
import 'package:pure_live/l10n/translations.dart';

/// The root: `DsApp` over the viewer's theme settings — the seed from the
/// platform accent or the appearance pane's named tone, light/dark, density
/// and corners all persisted and read back on boot — and the language the
/// appearance pane pins (null = follow the system), both flowing through
/// scopes every page can read.
class PureLiveApp extends ConsumerStatefulWidget {
  const PureLiveApp({super.key});

  @override
  ConsumerState<PureLiveApp> createState() => _PureLiveAppState();
}

final class _PureLiveAppState extends ConsumerState<PureLiveApp> {
  late AppThemeSettings _settings;

  /// The pinned locale's code ('zh-CN', 'en'), or null to follow the
  /// system; the appearance pane writes through here.
  String? _localeCode;

  @override
  void initState() {
    super.initState();
    // The stored choices land before the first frame builds, so the boot
    // never flashes the defaults. The settings' own builder hook supplies
    // the defaults; the store only overrides what the viewer pinned.
    _settings = AppThemeSettings((b) {
      final accent = readSystemAccentColor();
      if (accent != null) b.seed = DsSeed.color(accent);
      final seedName = ThemePersistence.readSeedName();
      if (seedName != null) {
        for (final (name, seed) in kNamedSeeds) {
          if (name == seedName) b.seed = seed;
        }
      }
      final mode = ThemePersistence.readMode();
      if (mode != null) b.mode = mode;
      final corners = ThemePersistence.readCorners();
      if (corners != null) b.cornerStyle = corners;
      b.density = ThemePersistence.readDensity();
    });
    _localeCode = ThemePersistence.readLocale();
    if (_localeCode != null) {
      LocaleSettings.setLocaleRawSync(_localeCode!);
    }
  }

  void _updateSettings(AppThemeSettings settings) {
    setState(() => _settings = settings);
    // The pane writes every change the moment it happens; the root reads
    // them back on the next boot.
    unawaited(ThemePersistence.storeMode(settings.mode));
    unawaited(ThemePersistence.storeCorners(settings.cornerStyle));
    unawaited(ThemePersistence.storeDensity(settings.density));
    // Only a named tone persists; the platform accent is re-read at boot
    // (the machine may have changed it), so it stores as "no seed".
    String? named;
    for (final (name, seed) in kNamedSeeds) {
      if (seed == settings.seed) named = name;
    }
    unawaited(ThemePersistence.storeSeedName(named));
  }

  /// Pins the language the appearance pane chose; null follows the system.
  void _updateLocale(String? code) {
    setState(() => _localeCode = code);
    if (code == null) {
      unawaited(LocaleSettings.useDeviceLocale());
    } else {
      unawaited(LocaleSettings.setLocaleRaw(code));
    }
    unawaited(ThemePersistence.storeLocale(code));
  }

  @override
  Widget build(BuildContext context) {
    return TranslationProvider(
      child: DsApp.router(
        routerConfig: ref.watch(appRouterProvider),
        onGenerateTitle: (context) => context.t.common.appTitle,
        locale: LocaleSettings.currentLocale.flutterLocale,
        debugShowCheckedModeBanner: false,
        themeMode: _settings.mode,
        theme: _settings.theme(),
        builder: (context, child) => AppThemeScope(
          settings: _settings,
          onChanged: _updateSettings,
          child: AppLocaleScope(localeCode: _localeCode, onChanged: _updateLocale, child: child!),
        ),
      ),
    );
  }
}

/// The pinned language and a way to change it, above the whole tree: the
/// appearance pane writes through [onChanged], the root applies it at once.
class AppLocaleScope extends InheritedWidget {
  /// Exposes [localeCode] with [onChanged] to [child].
  const AppLocaleScope({
    required this.localeCode,
    required this.onChanged,
    required super.child,
    super.key,
  });

  /// The pinned locale's code, or null to follow the system.
  final String? localeCode;

  /// Applies a new pin.
  final ValueChanged<String?> onChanged;

  /// The nearest scope.
  static AppLocaleScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppLocaleScope>()!;

  @override
  bool updateShouldNotify(AppLocaleScope old) => old.localeCode != localeCode;
}
