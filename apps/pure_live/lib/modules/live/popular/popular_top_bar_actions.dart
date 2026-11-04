import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/popular/popular_controller.dart';
import 'package:pure_live/shared/shared.dart';

/// The popular feed's verbs in the phone's top bar: the refresh and the more
/// menu, drawn as the outlined buttons the follows page uses.
///
/// The page keeps its platform tabs line alone on a phone; these two ride up
/// here (after the bar's search) so the verbs are offered once.
final class PopularTopBarActions extends ConsumerWidget {
  /// Creates the actions.
  const PopularTopBarActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final platform = ref.watch(popularSiteProvider);
    // The platform list and its order are settings this bar follows live.
    ref
      ..watch(sitesDisplayProvider)
      ..watch(sitesOrderProvider);
    final ids = ref.watch(popularCatalogProvider.notifier).platformIds();
    final loading = ref.watch(popularCatalogProvider.select((catalog) => catalog[platform]?.loading ?? false));
    final names = {for (final site in ref.watch(sitesProvider).all) site.manifest.id: localizedSiteName(site)};
    String nameOf(String id) => names[id] ?? id;

    void choose(String id) {
      ref.read(popularSiteProvider.notifier).selected = id;
      unawaited(ref.read(popularCatalogProvider.notifier).open(id));
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: DsSpace.s8,
      children: [
        DsButton.icon(
          variant: DsButtonVariant.secondary,
          size: DsSize.sm,
          semanticLabel: t.common.refresh,
          loading: loading,
          onPressed: loading ? null : () => unawaited(ref.read(popularCatalogProvider.notifier).refresh(platform)),
          icon: const DsIcon(DsIcons.refreshCw, size: 16),
        ),
        PlatformToolbarMore(
          platforms: ids,
          current: platform,
          nameOf: nameOf,
          onChanged: choose,
          onManagePlatforms: () => unawaited(
            context.push(SettingsSectionRoute(section: SettingsSection.sitesDisplay.name).location),
          ),
          triggerVariant: DsButtonVariant.secondary,
        ),
      ],
    );
  }
}
