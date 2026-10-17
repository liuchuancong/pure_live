import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/preferences/app_preferences.dart';
import 'package:pure_live/app/preferences/app_preferences_providers.dart';
import 'package:pure_live/features/settings/widgets/settings_sections.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/widgets/list_loading.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The loading style settings page (3.x `LoadingStyleSettingsPage`, scoped
/// to what this build's placeholder can draw): how a list feed's first-load
/// placeholder presents — the shimmering bone grid, a centred spinner, or
/// nothing at all.
///
/// The preview under each choice draws the real placeholder widget the
/// feeds use, so what you pick is what a cold feed shows. The reference's
/// per-animation colour has no backing here and stays out.
final class LoadingStyleSettingsPage extends ConsumerWidget {
  /// The loading style settings page.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = PureTheme.of(context);
    final current = ref.watch(loadingStyleProvider);
    final update = ref.read(appPreferencesProvider.notifier).update;
    final options = [
      (LoadingStyle.shimmer, t.settings.loadingShimmer),
      (LoadingStyle.spinner, t.settings.loadingSpinner),
      (LoadingStyle.none, t.settings.loadingNone),
    ];
    return PureScaffold(
      appBar: PureAppBar(title: t.settings.loadingStyle),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          SettingsSection(
            label: t.settings.loadingPreview,
            children: [
              PureCard(
                padding: EdgeInsets.zero,
                child: SizedBox(
                  height: 132,
                  child: FeedLoadingPlaceholder(
                    delegateBuilder: (width) => const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      mainAxisExtent: 92,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SettingsSectionGap(),
          SettingsSection.card(
            label: t.settings.loadingStyle,
            tiles: [
              for (var i = 0; i < options.length; i++)
                PureListRow(
                  leading: Icon(
                    options[i].$1 == current ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: options[i].$1 == current ? theme.colors.primary : null,
                  ),
                  title: options[i].$2,
                  selected: options[i].$1 == current,
                  onTap: () => update((p) => p.copyWith(loadingStyle: options[i].$1)),
                  divided: i < options.length - 1,
                ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
