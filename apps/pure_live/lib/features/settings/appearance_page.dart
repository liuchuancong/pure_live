import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/app/theme/appearance_preferences/appearance_preferences.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/widgets/settings_entry_button.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The appearance page: every control writes straight into the persisted
/// appearance — the store applies in memory before it is durable, so the
/// app re-skins under the viewer's finger.
final class AppearancePage extends ConsumerWidget {
  /// The appearance page.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearancePreferencesProvider);
    final update = ref.read(appearancePreferencesProvider.notifier).update;
    return PureScaffold(
      appBar: PureAppBar(title: context.t.settings.appearance, actions: const [SettingsEntryButton()]),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _Row(title: context.t.settings.themeMode, child: _themeMode(context, appearance, update)),
          _Row(title: context.t.settings.designLanguage, child: _designLanguage(context, appearance, update)),
          _Row(title: context.t.settings.accent, child: _accent(context, appearance, update)),
          _Row(
            title: context.t.settings.pureBlack,
            child: PureSwitch(
              value: appearance.pureBlack,
              onChanged: (value) => update((a) => a.copyWith(pureBlack: value)),
            ),
          ),
          _Row(title: context.t.settings.density, child: _density(context, appearance, update)),
          _Row(
            title: context.t.settings.fontScale,
            child: PureSlider(
              value: appearance.fontScale,
              min: 0.8,
              max: 1.4,
              onChanged: (value) => update((a) => a.copyWith(fontScale: value)),
            ),
          ),
          _Row(
            title: context.t.settings.transparency,
            child: PureSlider(
              value: appearance.transparency,
              onChanged: (value) => update((a) => a.copyWith(transparency: value)),
            ),
          ),
          _Row(
            title: context.t.settings.reduceTransparency,
            child: PureSwitch(
              value: appearance.reduceTransparency,
              onChanged: (value) => update((a) => a.copyWith(reduceTransparency: value)),
            ),
          ),
          _Row(
            title: context.t.settings.animations,
            child: PureSwitch(
              value: appearance.animations,
              onChanged: (value) => update((a) => a.copyWith(animations: value)),
            ),
          ),
          _Row(
            title: context.t.settings.focusOutline,
            child: PureSwitch(
              value: appearance.focusOutline,
              onChanged: (value) => update((a) => a.copyWith(focusOutline: value)),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _themeMode(
    BuildContext context,
    AppearancePreferences appearance,
    Future<void> Function(AppearancePreferences Function(AppearancePreferences)) update,
  ) => PureSegmented(
    labels: [context.t.theme.system, context.t.theme.dark, context.t.theme.light],
    index: switch (appearance.themeMode) {
      AppThemeMode.system => 0,
      AppThemeMode.dark => 1,
      AppThemeMode.light => 2,
    },
    onChanged: (index) => update(
      (a) => a.copyWith(
        themeMode: switch (index) {
          0 => AppThemeMode.system,
          1 => AppThemeMode.dark,
          _ => AppThemeMode.light,
        },
      ),
    ),
    expand: true,
  );

  static Widget _designLanguage(
    BuildContext context,
    AppearancePreferences appearance,
    Future<void> Function(AppearancePreferences Function(AppearancePreferences)) update,
  ) {
    final registered = PureDesignLanguage.values.map((language) => language.name).toList()..sort();
    final ids = ['', ...registered];
    String label(String id) =>
        id.isEmpty ? context.t.design.defaultLanguage : PureDesignLanguage.values.byName(id).name;
    return PureSelect<String>(
      items: ids,
      value: appearance.designLanguageId,
      itemLabel: label,
      onChanged: (id) => update((a) => a.copyWith(designLanguageId: id)),
    );
  }

  static Widget _density(
    BuildContext context,
    AppearancePreferences appearance,
    Future<void> Function(AppearancePreferences Function(AppearancePreferences)) update,
  ) {
    final ids = UiDensity.values.map((density) => density.name).toList();
    return PureSelect<String>(
      items: ids,
      value: appearance.densityId,
      itemLabel: (id) => id,
      onChanged: (id) => update((a) => a.copyWith(densityId: id)),
    );
  }

  static Widget _accent(
    BuildContext context,
    AppearancePreferences appearance,
    Future<void> Function(AppearancePreferences Function(AppearancePreferences)) update,
  ) {
    const presets = <int?>[null, 0xFF0A84FF, 0xFF30D158, 0xFFFF9F0A, 0xFFFF375F, 0xFFBF5AF2, 0xFF64D2FF];
    return Wrap(
      spacing: 10,
      children: [
        for (final argb in presets)
          GestureDetector(
            onTap: () => update((a) => a.copyWith(accentColor: argb)),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: argb == null ? const Color(0xFF888888) : Color(argb),
                shape: BoxShape.circle,
                border: Border.all(
                  color: appearance.accentColor == argb ? Colors.white : Colors.white24,
                  width: appearance.accentColor == argb ? 3 : 1,
                ),
              ),
              child: argb == null ? const Icon(Icons.block_outlined, size: 16, color: Colors.white70) : null,
            ),
          ),
      ],
    );
  }
}

/// One labelled row: the setting's name above its control.
final class _Row extends StatelessWidget {
  const new({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: PureCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: PureTheme.of(context).text.title),
          const SizedBox(height: 10),
          child,
        ],
      ),
    ),
  );
}
