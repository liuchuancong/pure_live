import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_iptv/live_iptv.dart' show EpgSourceX;
import 'package:pure_live/features/iptv/iptv_auto_update.dart';
import 'package:pure_live/features/iptv/iptv_controller.dart' show iptvPlaylistIsRemote;
import 'package:pure_live/features/iptv/iptv_epg_controller.dart';
import 'package:pure_live/features/iptv/iptv_panels.dart' show syncAllIptvSources;
import 'package:pure_live/features/iptv/iptv_sources_controller.dart';
import 'package:pure_live/features/settings/settings_widgets.dart' show SettingsConfigRow;
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
          leading: const DsIcon(DsIcons.timer),
          title: t.iptv.updateInterval,
          description: t.iptv.autoUpdateHint,
          controlWidth: 170,
          control: DsSelect<IptvUpdateInterval>(
            value: interval,
            onChanged: (value) {
              if (value != null) ref.read(iptvUpdateIntervalProvider.notifier).select(value);
            },
            options: [
              for (final value in IptvUpdateInterval.values) DsSelectOption(value: value, label: value.label(t)),
            ],
            semanticLabel: t.iptv.updateInterval,
          ),
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.calendarClock),
          title: Text(t.iptv.autoUpdate),
          description: status == null ? null : Text(status),
          trailing: DsSwitch(
            value: allOn,
            onChanged: remoteGuides.isEmpty || blocked
                ? null
                : (value) => unawaited(ref.read(iptvEpgProvider.notifier).setAllAutoUpdate(value: value)),
          ),
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.refreshCw),
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
