import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_iptv/live_iptv.dart' show EpgSourceX;
import 'package:pure_live/features/iptv/controllers/iptv_auto_update.dart';
import 'package:pure_live/features/iptv/controllers/iptv_controller.dart' show iptvPlaylistIsRemote;
import 'package:pure_live/features/iptv/controllers/iptv_epg_controller.dart';
import 'package:pure_live/features/iptv/controllers/iptv_sources_controller.dart';
import 'package:pure_live/features/iptv/controllers/iptv_user_agent.dart' show iptvUserAgentProvider;
import 'package:pure_live/features/iptv/views/iptv_panels.dart' show syncAllIptvSources;
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';

/// The IPTV module's own settings: the guide-update interval, the bulk
/// automatic-update switch and the manual sync round. The source manager
/// (playlists, guides, their order) lives on the IPTV page itself; this
/// pane carries the schedule those pages read.
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
    return DsListSection(
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
            options: [for (final value in IptvUpdateInterval.values) DsSelectOption(value: value, label: value.label(t))],
            onChanged: ref.read(iptvUpdateIntervalProvider.notifier).select,
          ),
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
  }
}
