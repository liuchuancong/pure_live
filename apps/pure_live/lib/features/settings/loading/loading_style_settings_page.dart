import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/preferences/app_preferences.dart';
import 'package:pure_live/app/preferences/app_preferences_providers.dart';
import 'package:pure_live/features/settings/widgets/settings_rows.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/widgets/list_loading.dart';
import 'package:pure_settings_ui/pure_settings_ui.dart';
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
      body: SettingsList(
        sections: [
          SettingsSection(
            title: Text(t.settings.loadingPreview),
            tiles: [
              CustomSettingsTile(
                child: PureCard(
                  padding: EdgeInsets.zero,
                  // One row, measured from the width it is given: the bone is a
                  // 16:9 cover over a 32-point caption row, so any fixed extent
                  // either clipped the caption or left the grid scrolling inside
                  // a box that cannot scroll.
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const spacing = 8.0;
                      final itemWidth = (constraints.maxWidth - spacing * 2) / 3;
                      // Ceiled: the cover's ratio lands on a fraction of a pixel,
                      // and a grid box one hair too short reports an overflow.
                      final itemHeight = (itemWidth * 9 / 16 + 52).ceilToDouble();
                      return SizedBox(
                        height: itemHeight,
                        child: FeedLoadingPlaceholder(
                          rows: 1,
                          delegateBuilder: (width) => SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: spacing,
                            mainAxisSpacing: spacing,
                            mainAxisExtent: itemHeight,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          // A radio list is the reference's shape and the kit has no radio tile,
          // so the rows stay the uikit's own — inside the section's card.
          SettingsSection(
            title: Text(t.settings.loadingStyle),
            tiles: [
              for (var i = 0; i < options.length; i++)
                SettingsRowTile(
                  row: PureListRow(
                    leading: Icon(
                      options[i].$1 == current ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: options[i].$1 == current ? theme.colors.primary : null,
                    ),
                    title: options[i].$2,
                    selected: options[i].$1 == current,
                    onTap: () => update((p) => p.copyWith(loadingStyle: options[i].$1)),
                    divided: i < options.length - 1,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
