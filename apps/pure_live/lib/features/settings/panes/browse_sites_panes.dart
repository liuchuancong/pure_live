import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/browse/audience_metric_provider.dart' show audienceMetricProvider;
import 'package:pure_live/features/settings/browse/platform_preferences_provider.dart'
    show preferH264Provider, youtubeAllChatProvider;
import 'package:pure_live/features/settings/browse/sites_display_provider.dart'
    show sitesDisplayProvider, sitesOrderProvider;
import 'package:pure_live/features/settings/browse/twitch_languages_provider.dart' show twitchLanguagesProvider;
import 'package:pure_live/features/settings/dialogs/prefer_platform_dialog.dart' show showPreferPlatformDialog;
import 'package:pure_live/features/settings/dialogs/twitch_languages_dialog.dart'
    show showTwitchLanguagesDialog, twitchLanguagesSummary;
import 'package:pure_live/features/settings/panes/audience_settings_pane.dart' show audienceModeLabel;
import 'package:pure_live/features/settings/panes/room_card_pane.dart' show showRoomCardPreview;
import 'package:pure_live/features/settings/surface/settings_child_entry.dart' show SettingsChildEntry;
import 'package:pure_live/features/settings/surface/settings_sections.dart' show SettingsSection;
import 'package:pure_live/features/settings/surface/settings_widgets.dart' show SettingsChoiceRow, SettingsConfigRow;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/shared.dart';

/// The browsing page: what the feed grids decide for themselves — the gaps
/// between cards and the density of the follow page — plus the row that
/// opens the room-card preview, where the card itself is tuned. Card width
/// and page size are not here: both follow the window and the site's own
/// feed window now.
final class BrowsingPane extends ConsumerWidget {
  const BrowsingPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final settings = ref.watch(browseSettingsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(t.settings.groupCards),
          children: [
            // The gaps are desen_ui's spacing tokens, chosen from the same
            // dropdown the rest of the settings surface uses — not a free
            // pixel range the grids then have to guess at.
            SettingsChoiceRow<double>(
              leading: const DsIcon(DsIcons.columns2),
              title: t.settings.crossSpacing,
              description: t.settings.crossSpacingDescription,
              value: settings.crossSpacing,
              options: [
                for (final spacing in kBrowseSpacingChoices)
                  DsSelectOption(value: spacing, label: '${spacing.round()} px'),
              ],
              onChanged: (value) => ref.read(browseSettingsProvider.notifier).crossSpacing = value,
            ),
            SettingsChoiceRow<double>(
              leading: const DsIcon(DsIcons.rows3),
              title: t.settings.mainSpacing,
              description: t.settings.mainSpacingDescription,
              value: settings.mainSpacing,
              options: [
                for (final spacing in kBrowseSpacingChoices)
                  DsSelectOption(value: spacing, label: '${spacing.round()} px'),
              ],
              onChanged: (value) => ref.read(browseSettingsProvider.notifier).mainSpacing = value,
            ),
          ],
        ),
        // How many cards a screen holds: the columns are a choice now, not
        // only a consequence of the window's width; the cover's shape and
        // the title's lines decide how tall a card stands.
        DsListSection(
          header: Text(t.settings.browseLayoutGroup),
          children: [
            SettingsChoiceRow<int>(
              leading: const DsIcon(DsIcons.columns3),
              title: t.settings.browseColumns,
              value: settings.gridColumns,
              options: [
                DsSelectOption(value: 0, label: t.settings.browseAuto),
                for (final columns in kBrowseGridColumnChoices) DsSelectOption(value: columns, label: '$columns'),
              ],
              onChanged: (value) => ref.read(browseSettingsProvider.notifier).gridColumns = value,
            ),
            // A phone cannot hold two minimum-width cards, so without its own
            // count the grid would always show one wide card there.
            SettingsChoiceRow<int>(
              leading: const DsIcon(DsIcons.smartphone),
              title: t.settings.phoneColumns,
              value: settings.phoneColumns,
              options: [
                for (final columns in kBrowsePhoneColumnChoices) DsSelectOption(value: columns, label: '$columns'),
              ],
              onChanged: (value) => ref.read(browseSettingsProvider.notifier).phoneColumns = value,
            ),
          ],
        ),
        DsListSection(
          header: Text(t.settings.roomCardGroup),
          children: [
            // The row opens the card's own page — the sample at a feed's
            // size — rather than a settings list beside it.
            DsListRow(
              leading: const DsIcon(DsIcons.idCard),
              title: Text(t.settings.roomCardSettingsTitle),
              description: Text(t.settings.roomCardPreviewHint),
              showChevron: true,
              onPressed: () => unawaited(showRoomCardPreview(context)),
            ),
          ],
        ),
        // Which audience number a card leads with, and how it ranks: card
        // data, so it reads with the rest of the browsing surface.
        DsListSection(
          children: [
            SettingsChildEntry(
              child: SettingsSection.audience,
              detail: Text(audienceModeLabel(t, ref.watch(audienceMetricProvider))),
            ),
          ],
        ),
      ],
    );
  }
}

/// The sites pane, in the two groups the viewer splits it into: the platforms
/// themselves (the preferred platform, the platform display, the node probe
/// over those platforms, the unplayable filter, and beneath them the
/// account-management and tag-management pages), and the settings that only
/// one platform obeys (the codec and chat preferences and Twitch's directory
/// language). A switched-off platform leaves the popular and areas tab lists
/// until it is switched back on; the display page manages visibility and
/// order together.
final class SitesPane extends ConsumerWidget {
  const SitesPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final sites = ref.watch(sitesProvider).all;
    final hidden = ref.watch(sitesDisplayProvider);
    final order = ref.watch(sitesOrderProvider);
    final orderController = ref.read(sitesOrderProvider.notifier);
    final names = {for (final site in sites) site.manifest.id: localizedSiteName(site)};
    final sitesById = {for (final site in sites) site.manifest.id: site};
    String name(String id) => names[id] ?? id;
    // The hidden set stores the platforms switched off; an empty set shows
    // everything.
    bool shown(String id) => hidden.isEmpty || !hidden.contains(id);
    // The preferred platform is chosen among the ones browsing shows: a
    // hidden platform is not a destination for the browse surfaces.
    final visibleOrder = [
      for (final id in order.order)
        if (shown(id)) id,
    ];
    // The reference opens a filterable picker rather than a plain list: the
    // platform catalogue is long enough that finding one by name or id is
    // the point, and an empty result says so instead of showing nothing.
    Future<void> pickPreferred() async {
      final picked = await showPreferPlatformDialog(
        context: context,
        options: [
          for (final id in visibleOrder)
            DsSelectOption(value: id, label: name(id), leading: localizedSiteIcon(sitesById[id], size: 20)),
        ],
        value: visibleOrder.contains(order.preferred) ? order.preferred : null,
      );
      if (picked != null) await orderController.setPreferred(picked);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        // Where the viewer watches: the platform that leads, which of them
        // the browse pages show and how their endpoints answer, the platforms
        // switched off, and the pages that own who is signed in and how the
        // follows are tagged.
        DsListSection(
          header: Text(t.settings.sitesGroupCore),
          children: [
            DsListRow(
              leading: const DsIcon(DsIcons.pin),
              title: Text(t.settings.preferPlatform),
              description: Text(t.settings.preferPlatformDesc),
              detail: Text(order.preferred.isEmpty ? t.settings.preferPlatform : name(order.preferred)),
              showChevron: true,
              onPressed: () => unawaited(pickPreferred()),
            ),
            const SettingsChildEntry(child: SettingsSection.sitesDisplay),
            // The probe measures the platforms the row above lists, so its
            // entry follows that row rather than hiding under the proxy page.
            const SettingsChildEntry(child: SettingsSection.nodes),
            // The reference's discover filter, kept with the platforms it
            // applies to: the popular page counts what it hides and can be
            // turned over from there too.
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.circleAlert),
              title: t.settings.showUnplayableTitle,
              description: t.settings.showUnplayableDesc,
              control: DsSwitch(
                value: ref.watch(showUnplayableProvider),
                onChanged: (value) => ref.read(showUnplayableProvider.notifier).setShow(value: value),
              ),
            ),
            const SettingsChildEntry(child: SettingsSection.accounts),
            const SettingsChildEntry(child: SettingsSection.followTags),
          ],
        ),
        // Each platform's own quirks — a codec preference, YouTube's chat
        // and Twitch's language list — in one group of their own rather than
        // scattered through the platform rows.
        DsListSection(
          header: Text(t.settings.sitesGroupPlayback),
          children: [
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.video),
              title: t.settings.preferH264,
              description: t.settings.preferH264Desc,
              control: DsSwitch(
                value: ref.watch(preferH264Provider),
                onChanged: (value) => unawaited(ref.read(preferH264Provider.notifier).set(value: value)),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.messageCircle),
              title: t.settings.youtubeAllChat,
              description: t.settings.youtubeAllChatDesc,
              control: DsSwitch(
                value: ref.watch(youtubeAllChatProvider),
                onChanged: (value) => unawaited(ref.read(youtubeAllChatProvider.notifier).set(value: value)),
              ),
            ),
            DsListRow(
              leading: const DsIcon(DsIcons.languages),
              title: Text(t.settings.twitchLanguages),
              description: Text(t.settings.twitchLanguagesDesc),
              detail: Text(twitchLanguagesSummary(t, ref.watch(twitchLanguagesProvider))),
              showChevron: true,
              onPressed: () async {
                final result = await showTwitchLanguagesDialog(context, initial: ref.read(twitchLanguagesProvider));
                if (result != null) await ref.read(twitchLanguagesProvider.notifier).set(result);
              },
            ),
          ],
        ),
      ],
    );
  }
}
