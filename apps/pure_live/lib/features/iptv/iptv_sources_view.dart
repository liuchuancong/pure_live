import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_iptv/live_iptv.dart';
import 'package:pure_live/features/iptv/iptv_controller.dart' show iptvPlaylistIsRemote;
import 'package:pure_live/features/iptv/iptv_epg_controller.dart';
import 'package:pure_live/features/iptv/iptv_import_dialog.dart';
import 'package:pure_live/features/iptv/iptv_sources_controller.dart';
import 'package:pure_live/l10n/translations.dart';

/// The IPTV source manager: the library's counts, the network sources'
/// "sync all" round with its progress, one card per playlist and per guide
/// — each with its format, origin, channel count, last refresh, a sync (for
/// the network ones), a delete behind a confirm and, for guides, its
/// automatic-update switch — plus the row that chooses the guide in use.
///
/// The two import rows take a playlist from an address, a local file or
/// pasted text, and a guide from an address. Everything here writes through
/// `IptvImporter`, so a name clash is asked about and a sync keeps the
/// viewer's favourites and order.
final class IptvSourcesView extends ConsumerStatefulWidget {
  /// The source manager shown on the IPTV page's sources tab.
  const IptvSourcesView({super.key});

  @override
  ConsumerState<IptvSourcesView> createState() => _IptvSourcesViewState();
}

final class _IptvSourcesViewState extends ConsumerState<IptvSourcesView> {
  void _toast(String title, {String? description, bool danger = false}) {
    showDsToast(
      context: context,
      title: title,
      description: description,
      status: danger ? DsStatus.danger : DsStatus.success,
    );
  }

  // -- Sync ----------------------------------------------------------------

  Future<void> _syncAll() async {
    final report = await ref.read(iptvSourcesProvider.notifier).syncAll();
    if (!mounted) return;
    final t = context.t;
    if (report.total == 0) {
      _toast(t.iptv.syncAllNone, danger: true);
    } else if (report.failed == 0) {
      _toast(t.iptv.syncAllDone(count: report.total));
    } else {
      _toast(t.iptv.syncAllPartial(failed: report.failed, count: report.total), danger: true);
    }
  }

  Future<void> _syncPlaylist(IptvPlaylist playlist) async {
    final result = await ref.read(iptvSourcesProvider.notifier).syncPlaylist(playlist);
    if (!mounted || result == null) return;
    final t = context.t;
    if (result.isImported) {
      _toast(t.iptv.synced(name: playlist.name));
    } else {
      _toast(t.iptv.syncFailed(name: playlist.name), description: iptvImportFailureText(result, t), danger: true);
    }
  }

  Future<void> _syncGuide(EpgSource source) async {
    final result = await ref.read(iptvEpgProvider.notifier).syncSource(source);
    if (!mounted || result == null) return;
    final t = context.t;
    if (result.isImported) {
      _toast(t.iptv.synced(name: source.name));
    } else {
      _toast(t.iptv.syncFailed(name: source.name), description: iptvImportFailureText(result, t), danger: true);
    }
  }

  // -- Delete --------------------------------------------------------------

  Future<void> _deletePlaylist(IptvPlaylist playlist) async {
    final t = context.t;
    final confirmed = await showDsConfirm(
      context: context,
      title: t.iptv.deletePlaylistTitle,
      description: t.iptv.deletePlaylistMessage(name: playlist.name, count: playlist.channelCount),
      confirmLabel: t.iptv.delete,
      cancelLabel: t.common.cancel,
      destructive: true,
      icon: const DsIcon(DsIcons.trash),
    );
    if (!confirmed || !mounted) return;
    final deleted = await ref.read(iptvSourcesProvider.notifier).deletePlaylist(playlist);
    if (!mounted) return;
    _toast(deleted ? t.iptv.deleted(name: playlist.name) : t.iptv.sourceChanged, danger: !deleted);
  }

  Future<void> _deleteGuide(EpgSource source) async {
    final t = context.t;
    final inUse = ref.read(iptvEpgProvider).activeId == source.id;
    final confirmed = await showDsConfirm(
      context: context,
      title: t.iptv.deleteGuideTitle,
      description: [t.iptv.deleteGuideMessage(name: source.name), if (inUse) t.iptv.deleteActiveGuideNote].join('\n'),
      confirmLabel: t.iptv.delete,
      cancelLabel: t.common.cancel,
      destructive: true,
      icon: const DsIcon(DsIcons.trash),
    );
    if (!confirmed || !mounted) return;
    final deleted = await ref.read(iptvEpgProvider.notifier).deleteSource(source);
    if (!mounted) return;
    _toast(deleted ? t.iptv.deleted(name: source.name) : t.iptv.sourceChanged, danger: !deleted);
  }

  // -- Guide selection -----------------------------------------------------

  Future<void> _chooseGuide() async {
    final t = context.t;
    final epg = ref.read(iptvEpgProvider);
    final chosen = await showDsDialog<EpgSource>(
      context: context,
      builder: (dialogContext) => DsDialog(
        title: Text(t.iptv.chooseGuide),
        style: const DsDialogStyle(width: 480),
        description: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s8,
          children: [
            Text(t.iptv.activeGuideDescription),
            for (final source in epg.sources)
              DsListRow(
                leading: const DsIcon(DsIcons.calendarClock),
                title: Text(source.name),
                description: Text(source.source),
                selected: source.id == epg.activeId,
                trailing: source.id == epg.activeId ? const DsIcon(DsIcons.check, size: 16) : null,
                onPressed: () => Navigator.of(dialogContext).pop(source),
              ),
          ],
        ),
        actions: [
          DsButton(
            variant: DsButtonVariant.secondary,
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(t.common.cancel),
          ),
        ],
      ),
    );
    if (chosen == null || !mounted) return;
    await ref.read(iptvEpgProvider.notifier).selectGuide(chosen);
    if (!mounted) return;
    _toast(context.t.iptv.guideSelected(name: chosen.name));
  }

  Future<void> _setAutoUpdate(EpgSource source, bool value) =>
      ref.read(iptvEpgProvider.notifier).setAutoUpdate(source, value: value);

  // -- Build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final sources = ref.watch(iptvSourcesProvider);
    final epg = ref.watch(iptvEpgProvider);
    final active = _activeOf(epg);
    final importBusy = sources.importing || epg.importing;
    final roundBusy = sources.syncAll != null;
    // Nothing can be written before the library opened: its importer does
    // not exist yet, and the cards would only fail.
    final blocked = importBusy || roundBusy || !sources.ready || !epg.ready;
    final hasRemote = sources.playlists.any(iptvPlaylistIsRemote) || epg.sources.any((source) => source.isRemote);
    return ListView(
      padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s28),
      children: [
        if (sources.syncAll case final progress?)
          _SyncProgress(done: progress.done, total: progress.total)
        else
          _Header(
            playlists: sources.playlists.length,
            channels: sources.channelCount,
            guides: epg.sources.length,
            syncEnabled: !blocked && hasRemote,
            onSyncAll: _syncAll,
          ),
        const SizedBox(height: DsSpace.s20),
        DsListSection(
          header: Text(t.iptv.playlistsTitle),
          children: [
            DsListRow(
              leading: const DsIcon(DsIcons.plus),
              title: Text(t.iptv.importPlaylist),
              description: Text(t.iptv.importPlaylistDescription),
              showChevron: true,
              onPressed: blocked ? null : () => unawaited(runIptvPlaylistImport(context)),
            ),
          ],
        ),
        const SizedBox(height: DsSpace.s12),
        if (sources.playlists.isEmpty)
          _EmptySection(
            icon: DsIcons.list,
            title: t.iptv.noPlaylistsTitle,
            description: t.iptv.noPlaylistsDescription,
            action: t.iptv.importPlaylist,
            onPressed: blocked ? null : () => unawaited(runIptvPlaylistImport(context)),
          )
        else
          for (final playlist in sources.playlists)
            _SourceCard(
              icon: DsIcons.list,
              name: playlist.name,
              address: playlist.url ?? '',
              badge: _playlistBadge(playlist),
              remote: iptvPlaylistIsRemote(playlist),
              detail: _detailText(
                context,
                channels: playlist.channelCount,
                updated: playlist.importedAt,
                remote: iptvPlaylistIsRemote(playlist),
              ),
              inUse: false,
              busy: sources.busy.contains('p:${playlist.id}'),
              blocked: blocked || sources.busy.contains('p:${playlist.id}'),
              onSync: iptvPlaylistIsRemote(playlist) ? () => unawaited(_syncPlaylist(playlist)) : null,
              onDelete: () => unawaited(_deletePlaylist(playlist)),
            ),
        const SizedBox(height: DsSpace.s12),
        DsListSection(
          header: Text(t.iptv.epgSourceTitle),
          children: [
            DsListRow(
              leading: const DsIcon(DsIcons.plus),
              title: Text(t.iptv.importGuide),
              description: Text(t.iptv.importGuideDescription),
              showChevron: true,
              onPressed: blocked ? null : () => unawaited(runIptvGuideImport(context)),
            ),
            DsListRow(
              leading: const DsIcon(DsIcons.calendarClock),
              title: Text(t.iptv.activeGuideTitle),
              description: Text(active?.name ?? t.iptv.activeGuideNone),
              showChevron: true,
              onPressed: epg.sources.isEmpty || blocked ? null : () => unawaited(_chooseGuide()),
            ),
          ],
        ),
        const SizedBox(height: DsSpace.s12),
        if (epg.sources.isEmpty)
          _EmptySection(
            icon: DsIcons.calendarClock,
            title: t.iptv.noGuidesTitle,
            description: t.iptv.epgEmpty,
            action: t.iptv.importGuide,
            onPressed: blocked ? null : () => unawaited(runIptvGuideImport(context)),
          )
        else
          for (final source in epg.sources)
            _SourceCard(
              icon: DsIcons.calendarClock,
              name: source.name,
              address: source.source,
              badge: _guideBadge(source),
              remote: source.isRemote,
              detail: _detailText(
                context,
                channels: epg.channelCounts[source.id] ?? 0,
                updated: source.lastRefresh,
                remote: source.isRemote,
              ),
              inUse: source.id == epg.activeId,
              busy: epg.busy.contains('g:${source.id}'),
              blocked: blocked || epg.busy.contains('g:${source.id}'),
              onSync: source.isRemote ? () => unawaited(_syncGuide(source)) : null,
              onDelete: () => unawaited(_deleteGuide(source)),
              autoUpdate: source.autoUpdate,
              onAutoUpdate: (value) => unawaited(_setAutoUpdate(source, value)),
            ),
      ],
    );
  }

  static EpgSource? _activeOf(IptvEpgState epg) {
    for (final source in epg.sources) {
      if (source.id == epg.activeId) return source;
    }
    return null;
  }
}

/// The counts and the "sync all" action: numbers stay in the header's
/// place while a round runs, and the progress takes its place.
final class _Header extends StatelessWidget {
  const _Header({
    required this.playlists,
    required this.channels,
    required this.guides,
    required this.syncEnabled,
    required this.onSyncAll,
  });

  final int playlists;
  final int channels;
  final int guides;
  final bool syncEnabled;
  final VoidCallback onSyncAll;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final stats = _Stats(playlists: playlists, channels: channels, guides: guides);
    final sync = DsButton(
      variant: DsButtonVariant.secondary,
      onPressed: syncEnabled ? onSyncAll : null,
      leading: const DsIcon(DsIcons.refreshCw, size: 15),
      child: Text(t.iptv.syncAll),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 480) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s12,
            children: [
              stats,
              Align(alignment: AlignmentDirectional.centerEnd, child: sync),
            ],
          );
        }
        return Row(
          spacing: DsSpace.s12,
          children: [
            Expanded(child: stats),
            sync,
          ],
        );
      },
    );
  }
}

/// Playlists, channels and guides, as three numbers over their labels.
final class _Stats extends StatelessWidget {
  const _Stats({required this.playlists, required this.channels, required this.guides});

  final int playlists;
  final int channels;
  final int guides;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    Widget stat(int value, String label) => Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: DsSpace.s4,
        children: [
          Text(
            _groupDigits(value),
            style: theme.typography.numeric(
              theme.typography.heading.copyWith(fontWeight: FontWeight.w600, color: colors.text),
            ),
          ),
          Text(label, style: theme.typography.caption.copyWith(color: colors.textMuted)),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.s8, vertical: DsSpace.s16),
      decoration: DsBoxDecoration(color: colors.control, borderRadius: BorderRadius.circular(theme.radii.card)),
      child: Row(
        children: [
          stat(playlists, t.iptv.statPlaylists),
          stat(channels, t.iptv.statChannels),
          stat(guides, t.iptv.statGuides),
        ],
      ),
    );
  }
}

/// "正在同步 1 / 3" and its bar, in the counts' place while a round runs.
final class _SyncProgress extends StatelessWidget {
  const _SyncProgress({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return Container(
      padding: const EdgeInsets.all(DsSpace.s16),
      decoration: DsBoxDecoration(color: colors.control, borderRadius: BorderRadius.circular(theme.radii.card)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s8,
        children: [
          Text(
            t.iptv.syncAllRunning(done: done, total: total),
            style: theme.typography.body.copyWith(color: colors.text),
          ),
          DsProgressBar(value: total == 0 ? null : done / total, semanticLabel: t.iptv.syncAll),
        ],
      ),
    );
  }
}

/// One playlist or guide source: what it is, where it came from, how many
/// channels it carries, when it last refreshed, and the operations that
/// apply to it.
final class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.icon,
    required this.name,
    required this.address,
    required this.badge,
    required this.remote,
    required this.detail,
    required this.inUse,
    required this.busy,
    required this.blocked,
    required this.onSync,
    required this.onDelete,
    this.autoUpdate,
    this.onAutoUpdate,
  });

  final DsIconData icon;
  final String name;
  final String address;
  final String badge;
  final bool remote;
  final String detail;
  final bool inUse;
  final bool busy;
  final bool blocked;
  final VoidCallback? onSync;
  final VoidCallback onDelete;
  final bool? autoUpdate;
  final ValueChanged<bool>? onAutoUpdate;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final auto = autoUpdate;
    return Container(
      margin: const EdgeInsets.only(bottom: DsSpace.s12),
      padding: const EdgeInsets.all(DsSpace.s16),
      decoration: DsBoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(theme.radii.card),
        shadows: [...theme.shadows.surface, if (inUse) DsShadow.innerRing(colors.accent, width: 1.5)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s12,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: DsSpace.s12,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: DsBoxDecoration(color: colors.accentTint, borderRadius: BorderRadius.circular(12)),
                child: Center(child: DsIcon(icon, size: 20, color: colors.accentText)),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: DsSpace.s4,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.body.copyWith(fontWeight: FontWeight.w600, color: colors.text),
                    ),
                    Wrap(
                      spacing: DsSpace.s6,
                      runSpacing: DsSpace.s4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        DsBadge(label: Text(badge), dot: false),
                        DsBadge(
                          label: Text(remote ? t.iptv.networkTag : t.iptv.localTag),
                          dot: false,
                          icon: DsIcon(remote ? DsIcons.globe : DsIcons.fileText, size: 12),
                        ),
                        if (inUse) DsBadge(label: Text(t.iptv.inUse), status: DsStatus.info, dot: false),
                      ],
                    ),
                    Text(detail, style: theme.typography.small.copyWith(color: colors.textMuted)),
                    if (address.isNotEmpty)
                      Text(
                        address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.caption.copyWith(color: colors.textSubtle),
                      ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            spacing: DsSpace.s8,
            children: [
              if (onSync case final sync?)
                DsButton(
                  variant: DsButtonVariant.tinted,
                  size: DsSize.sm,
                  loading: busy,
                  onPressed: blocked ? null : sync,
                  leading: const DsIcon(DsIcons.refreshCw, size: 15),
                  child: Text(t.iptv.sync),
                ),
              const Spacer(),
              DsButton(
                variant: DsButtonVariant.dangerSoft,
                size: DsSize.sm,
                onPressed: blocked ? null : onDelete,
                leading: const DsIcon(DsIcons.delete, size: 15),
                child: Text(t.iptv.delete),
              ),
            ],
          ),
          if (auto != null)
            DsSwitch(
              value: auto,
              onChanged: blocked ? null : onAutoUpdate,
              label: Text(t.iptv.autoUpdate),
              description: Text(t.iptv.autoUpdateHint),
            ),
        ],
      ),
    );
  }
}

/// The empty state of one source section: what is missing, and the import
/// that fills it.
final class _EmptySection extends StatelessWidget {
  const _EmptySection({
    required this.icon,
    required this.title,
    required this.description,
    required this.action,
    required this.onPressed,
  });

  final DsIconData icon;
  final String title;
  final String description;
  final String action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DsCard(
      style: const DsCardStyle(padding: EdgeInsets.zero),
      child: DsEmptyState(
        icon: DsIcon(icon),
        title: Text(title),
        description: Text(description),
        actions: [DsButton(onPressed: onPressed, leading: const DsIcon(DsIcons.plus, size: 16), child: Text(action))],
      ),
    );
  }
}

/// A card's channel count and last refresh: "1,024 个频道 · 今天 08:00 更新",
/// "… · 今天 08:00 导入" for a local source, "尚未更新" when it has no
/// refresh yet.
String _detailText(BuildContext context, {required int channels, required DateTime? updated, required bool remote}) {
  final t = context.t;
  final stamp = _stamp(updated);
  final refreshed = stamp == null
      ? t.iptv.neverUpdated
      : remote
      ? t.iptv.lastRefresh(time: stamp)
      : t.iptv.importedAt(time: stamp);
  return '${t.iptv.channelCount(count: channels)} · $refreshed';
}

/// A local time as "08:00" today, "09-30 12:05" this year, or a full date
/// before that; null when there is no time to show.
String? _stamp(DateTime? time) {
  if (time == null) return null;
  final local = time.toLocal();
  final now = DateTime.now();
  String two(int value) => value.toString().padLeft(2, '0');
  final clock = '${two(local.hour)}:${two(local.minute)}';
  if (local.year == now.year && local.month == now.month && local.day == now.day) return clock;
  if (local.year == now.year) return '${two(local.month)}-${two(local.day)} $clock';
  return '${local.year}-${two(local.month)}-${two(local.day)} $clock';
}

/// The format badge of [playlist], read from the address it was imported
/// from; pasted text and local files record no address, so they show M3U —
/// the format the importer reads first.
String _playlistBadge(IptvPlaylist playlist) {
  final path = (Uri.tryParse(playlist.url ?? '')?.path ?? '').toLowerCase();
  if (path.endsWith('.m3u8')) return 'M3U8';
  if (path.endsWith('.txt')) return 'TXT';
  return 'M3U';
}

/// The format badge of [source], by its address; the importer reads the
/// content, so this is only a hint.
String _guideBadge(EpgSource source) {
  final path = (Uri.tryParse(source.source)?.path ?? source.source).toLowerCase();
  if (path.endsWith('.gz')) return 'XML.GZ';
  if (path.endsWith('.json')) return 'JSON';
  return 'XML';
}

/// [value] with thousands separators ("1,024").
String _groupDigits(int value) {
  final digits = value.abs().toString();
  final out = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}
