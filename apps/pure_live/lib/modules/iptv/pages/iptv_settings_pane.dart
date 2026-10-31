import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_iptv/live_iptv.dart' show EpgSourceX;
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/iptv/controllers/iptv_auto_update.dart';
import 'package:pure_live/modules/iptv/controllers/iptv_browse_settings.dart';
import 'package:pure_live/modules/iptv/controllers/iptv_controller.dart' show iptvPlaylistIsRemote;
import 'package:pure_live/modules/iptv/controllers/iptv_epg_controller.dart';
import 'package:pure_live/modules/iptv/controllers/iptv_sources_controller.dart';
import 'package:pure_live/modules/iptv/controllers/iptv_user_agent.dart' show iptvUserAgentProvider;
import 'package:pure_live/modules/iptv/views/iptv_panels.dart' show syncAllIptvSources;

/// The IPTV module's own settings: the guide-update interval, the bulk
/// automatic-update switch and the manual sync round, with the two subpages
/// the reference keeps beside them — how a channel is shown and zapped, and
/// which groups the module leaves out. The source manager (playlists,
/// guides, their order) lives on the IPTV page itself; this pane carries the
/// schedule those pages read.
final class IptvSettingsPane extends ConsumerWidget {
  /// The pane shown under Settings → IPTV.
  const IptvSettingsPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final epg = ref.watch(iptvEpgProvider);
    final sources = ref.watch(iptvSourcesProvider);
    final interval = ref.watch(iptvUpdateIntervalProvider);
    final autoSync = ref.watch(iptvAutoSyncProvider);
    final userAgent = ref.watch(iptvUserAgentProvider);
    final remoteGuides = [
      for (final source in epg.sources)
        if (source.isRemote) source,
    ];
    final autoOn = remoteGuides.where((source) => source.autoUpdate).length;
    final allOn = remoteGuides.isNotEmpty && autoOn == remoteGuides.length;
    final ready = epg.ready && sources.ready;
    final round = sources.syncAll;
    final blocked = !ready || sources.importing || epg.importing || round != null || epg.busy.isNotEmpty;
    final canSync =
        ready &&
        round == null &&
        !sources.importing &&
        !epg.importing &&
        sources.busy.isEmpty &&
        epg.busy.isEmpty &&
        (sources.playlists.any(iptvPlaylistIsRemote) || epg.sources.any((source) => source.isRemote));
    final status = !ready
        ? null
        : remoteGuides.isEmpty
        ? t.iptv.autoUpdateNoRemote
        : autoOn == 0
        ? t.iptv.autoUpdateStatusNone
        : t.iptv.autoUpdateStatusOn(count: autoOn);
    final guideSection = DsListSection(
      header: Text(t.settings.iptvGuideUpdates),
      children: [
        SettingsConfigRow(
          leading: const DsIcon(DsIcons.refreshCw),
          title: t.iptv.autoSyncTitle,
          description: t.iptv.autoSyncDesc,
          control: DsSwitch(
            value: autoSync,
            onChanged: (value) => unawaited(ref.read(iptvAutoSyncProvider.notifier).set(value: value)),
          ),
        ),
        if (autoSync)
          SettingsChoiceRow<IptvUpdateInterval>(
            leading: const DsIcon(DsIcons.timer),
            title: t.iptv.updateInterval,
            description: t.iptv.autoUpdateHint,
            value: interval,
            options: [
              for (final value in IptvUpdateInterval.values) DsSelectOption(value: value, label: value.label(t)),
            ],
            onChanged: ref.read(iptvUpdateIntervalProvider.notifier).select,
          ),
        if (autoSync)
          SettingsConfigRow(
            leading: const DsIcon(DsIcons.calendarClock),
            title: t.iptv.autoUpdate,
            description: status,
            control: DsSwitch(
              value: allOn,
              onChanged: remoteGuides.isEmpty || blocked
                  ? null
                  : (value) => unawaited(ref.read(iptvEpgProvider.notifier).setAllAutoUpdate(value: value)),
            ),
          ),
        DsListRow(
          leading: const DsIcon(DsIcons.cloudUpload),
          title: Text(t.iptv.syncAll),
          description: Text(
            round == null ? t.settings.iptvSyncDesc : t.iptv.syncAllRunning(done: round.done, total: round.total),
          ),
          onPressed: canSync ? () => unawaited(syncAllIptvSources(context, ref)) : null,
        ),
      ],
    );
    // The user agent travels with every remote fetch the module makes —
    // playlists as much as guides — so it stands apart from the schedule.
    final networkSection = DsListSection(
      header: Text(t.settings.iptvNetwork),
      children: [
        SettingsConfigRow(
          leading: const DsIcon(DsIcons.user),
          title: t.iptv.customUserAgent,
          description: t.iptv.customUserAgentDesc,
          controlWidth: 280,
          control: DsTextField(
            initialValue: userAgent,
            clearable: true,
            placeholder: t.iptv.customUserAgent,
            onChanged: (value) => unawaited(ref.read(iptvUserAgentProvider.notifier).set(value)),
            semanticLabel: t.iptv.customUserAgent,
          ),
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        guideSection,
        networkSection,
        DsListSection(
          header: Text(t.settings.iptvSections),
          children: const [
            SettingsChildEntry(child: SettingsSection.iptvBrowse),
            SettingsChildEntry(child: SettingsSection.iptvGroups),
          ],
        ),
      ],
    );
  }
}

/// The reference's own settings dialog, moved up into the module: the dial
/// number beside a channel, the direction the up and down keys walk, the
/// player's clock and the one line about what is on. Every switch lands on
/// the next frame — the pages read it where they paint.
final class IptvBrowsePane extends ConsumerWidget {
  /// The pane shown under Settings → IPTV → 换台与显示.
  const IptvBrowsePane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final browse = ref.watch(iptvBrowseSettingsProvider);
    final controller = ref.read(iptvBrowseSettingsProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(t.settings.navIptvBrowse),
          children: [
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.hash),
              title: t.iptv.browseChannelNumber,
              description: t.iptv.browseChannelNumberDesc,
              control: DsSwitch(
                value: browse.showChannelNumber,
                onChanged: (value) => unawaited(controller.setShowChannelNumber(value: value)),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.arrowUpDown),
              title: t.iptv.browseReverse,
              description: t.iptv.browseReverseDesc,
              control: DsSwitch(
                value: browse.reverseChannels,
                onChanged: (value) => unawaited(controller.setReverseChannels(value: value)),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.clock),
              title: t.iptv.browseClock,
              description: t.iptv.browseClockDesc,
              control: DsSwitch(
                value: browse.showClock,
                onChanged: (value) => unawaited(controller.setShowClock(value: value)),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.list),
              title: t.iptv.browseProgrammeLine,
              description: t.iptv.browseProgrammeLineDesc,
              control: DsSwitch(
                value: browse.showProgrammeLine,
                onChanged: (value) => unawaited(controller.setShowProgrammeLine(value: value)),
              ),
            ),
          ],
        ),
        DsListSection(
          header: Text(t.settings.resetGroup),
          children: [
            DsListRow(
              leading: const DsIcon(DsIcons.rotateCcw),
              title: Text(t.iptv.browseReset),
              onPressed: () => unawaited(controller.reset()),
            ),
          ],
        ),
      ],
    );
  }
}

/// Which groups the module leaves out of its lists and its zapping. The
/// library keeps the flag, so un-hiding a group gives back exactly the
/// line-up that was there before it was switched off.
final class IptvGroupsPane extends ConsumerWidget {
  /// The pane shown under Settings → IPTV → 分组显示.
  const IptvGroupsPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final groups = ref.watch(iptvGroupsProvider);
    final controller = ref.read(iptvGroupsProvider.notifier);
    if (groups.isEmpty) {
      return DsListSection(
        header: Text(t.settings.navIptvGroups),
        children: [
          Padding(
            padding: const EdgeInsets.all(DsSpace.s16),
            child: Text(t.iptv.groupsEmpty, style: theme.typography.body.copyWith(color: colors.textMuted)),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(t.settings.navIptvGroups),
          children: [
            for (final group in groups)
              SettingsConfigRow(
                leading: DsIcon(group.hidden ? DsIcons.eyeOff : DsIcons.eye),
                title: group.name.isEmpty ? t.iptv.ungrouped : group.name,
                detail: Text(t.iptv.channelCount(count: group.channels)),
                control: DsSwitch(
                  value: !group.hidden,
                  onChanged: (value) => unawaited(controller.setHidden(group.name, hidden: !value)),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
