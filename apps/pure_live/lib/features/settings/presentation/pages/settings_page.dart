import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/theme/app_theme_mode.dart' show AppThemeMode;
import 'package:pure_live/app/theme/theme_preferences.dart' show themePreferencesProvider;
import 'package:pure_live/i18n/translations.g.dart';

/// The settings branch: the preference groups, each pointing at the phase
/// that fills it in.
///
/// The light/dark segmented control is the first working row; storage-backed
/// preferences and the remaining groups arrive with the storage phase.
final class SettingsPage extends ConsumerWidget {
  /// The settings page.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(themePreferencesProvider);
    return Align(
      alignment: Alignment.topLeft,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(t.nav.settings, style: DsTheme.of(context).typography.title),
          const SizedBox(height: 12),
          DsSegmentedControl<AppThemeMode>(
            value: preferences.mode,
            onChanged: (mode) => ref.read(themePreferencesProvider.notifier).setMode(mode),
            segments: const [
              DsSegment(value: AppThemeMode.system, label: Text('跟随系统')),
              DsSegment(value: AppThemeMode.light, label: Text('浅色')),
              DsSegment(value: AppThemeMode.dark, label: Text('深色')),
            ],
          ),
        ],
      ),
    );
  }
}
