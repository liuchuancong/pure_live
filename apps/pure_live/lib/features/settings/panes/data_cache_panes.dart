import 'dart:async' show unawaited;
import 'dart:io' show Directory;

import 'package:desen_ui/desen_ui.dart';
import 'package:file_picker/file_picker.dart' show FilePicker;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/browse/sites_display_provider.dart' show decodeFollows, encodeFollows;
import 'package:pure_live/features/settings/surface/settings_child_entry.dart' show SettingsChildEntry;
import 'package:pure_live/features/settings/surface/settings_sections.dart' show SettingsSection;
import 'package:pure_live/features/settings/surface/settings_widgets.dart' show SettingsChoiceRow;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/favorites/data/follow_repository.dart'
    show followRepositoryProvider, followsProvider;
import 'package:pure_live/modules/live/history/history_repository.dart' show historyProvider;
import 'package:pure_live/modules/live/recorder/engine/recorder_engine.dart' show recorderEngineProvider;
import 'package:pure_live/shared/shared.dart';

/// The folders every kind of file lives in: one row per movable folder with
/// its resolved path, and the data tree beneath them as the one row that does
/// not move. A row's buttons pick a folder or drop the choice, so "default"
/// is always the device's own answer rather than a copied path.
final class StorageFoldersSection extends ConsumerWidget {
  const StorageFoldersSection({super.key});

  static String _label(Translations t, StorageFolder folder) => switch (folder) {
    StorageFolder.videos => t.settings.storageFolderVideos,
    StorageFolder.recordings => t.settings.storageFolderRecordings,
    StorageFolder.screenshots => t.settings.storageFolderScreenshots,
    StorageFolder.music => t.settings.storageFolderMusic,
    StorageFolder.wallpapers => t.settings.storageFolderWallpapers,
    StorageFolder.videoWallpapers => t.settings.storageFolderVideoWallpapers,
    StorageFolder.lyrics => t.settings.storageFolderLyrics,
    StorageFolder.updates => t.settings.storageFolderUpdates,
    StorageFolder.backgrounds => t.settings.storageFolderBackgrounds,
    StorageFolder.fonts => t.settings.storageFolderFonts,
    StorageFolder.logs => t.settings.storageFolderLogs,
    StorageFolder.cache => t.settings.storageFolderCache,
  };

  static Directory _pathOf(AppFolders folders, StorageFolder folder) => switch (folder) {
    StorageFolder.videos => folders.videos,
    StorageFolder.recordings => folders.recordings,
    StorageFolder.screenshots => folders.screenshots,
    StorageFolder.music => folders.music,
    StorageFolder.wallpapers => folders.wallpapers,
    StorageFolder.videoWallpapers => folders.videoWallpapers,
    StorageFolder.lyrics => folders.lyrics,
    StorageFolder.updates => folders.updates,
    StorageFolder.backgrounds => folders.backgrounds,
    StorageFolder.fonts => folders.fonts,
    StorageFolder.logs => folders.logs,
    StorageFolder.cache => folders.imageCache,
  };

  Future<void> _pick(BuildContext context, WidgetRef ref, StorageFolder folder) async {
    final t = context.t;
    try {
      final selected = await FilePicker.getDirectoryPath(dialogTitle: t.settings.storageFolderPick);
      if (selected == null || selected.trim().isEmpty) return;
      if (!context.mounted) return;
      final active = folder == StorageFolder.recordings ? ref.read(recorderEngineProvider).activeRecordingCount : 0;
      if (active > 0) {
        final confirmed = await showDsConfirm(
          context: context,
          title: t.recorder.folderInUseTitle,
          description: t.recorder.folderInUseBody(count: active),
          confirmLabel: t.recorder.folderInUseConfirm,
          cancelLabel: t.common.cancel,
          icon: const DsIcon(DsIcons.folderVideo),
        );
        if (!confirmed || !context.mounted) return;
      }
      final saved = await ref.read(storageFolderOverridesProvider.notifier).set(folder, selected);
      if (!context.mounted) return;
      if (!saved) {
        showDsToast(context: context, title: t.settings.storageFolderPermissionHint, status: DsStatus.danger);
        return;
      }
      showDsToast(
        context: context,
        title: active > 0
            ? t.recorder.folderChangedActive
            : folder.needsRestart
            ? '${t.settings.storageFoldersUpdated} · ${t.settings.storageFolderRestart}'
            : t.settings.storageFoldersUpdated,
      );
    } on Object {
      if (context.mounted) {
        showDsToast(context: context, title: t.settings.storageFolderPickFailed, status: DsStatus.danger);
      }
    }
  }

  Future<void> _reset(BuildContext context, WidgetRef ref, StorageFolder folder) async {
    await ref.read(storageFolderOverridesProvider.notifier).reset(folder);
    if (!context.mounted) return;
    showDsToast(context: context, title: context.t.settings.storageFoldersUpdated);
  }

  Future<void> _resetAll(BuildContext context, WidgetRef ref) async {
    // The cache override only lands on the next start, so dropping one says
    // so instead of promising an instant move.
    final restart = ref.read(storageFolderOverridesProvider).containsKey(StorageFolder.cache);
    await ref.read(storageFolderOverridesProvider.notifier).resetAll();
    if (!context.mounted) return;
    showDsToast(
      context: context,
      title: restart
          ? '${context.t.settings.storageFoldersUpdated} · ${context.t.settings.storageFolderRestart}'
          : context.t.settings.storageFoldersUpdated,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final folders = ref.watch(appPathsProvider);
    final overrides = ref.watch(storageFolderOverridesProvider);
    return DsListSection(
      header: Text(t.settings.storageFolders),
      children: [
        for (final folder in StorageFolder.values)
          () {
            final directory = _pathOf(folders, folder).path;
            final custom = overrides.containsKey(folder);
            return DsListRow(
              leading: DsIcon(folder.icon),
              title: Text(_label(t, folder)),
              description: DsTooltip(
                message: directory,
                child: Text(directory, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              detail: Text(custom ? t.settings.storageFolderCustomLabel : t.settings.storageFolderDefaultLabel),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DsButton(
                    variant: DsButtonVariant.ghost,
                    size: DsSize.sm,
                    onPressed: () => unawaited(_pick(context, ref, folder)),
                    child: Text(t.settings.storageFolderPick),
                  ),
                  if (custom)
                    DsButton(
                      variant: DsButtonVariant.ghost,
                      size: DsSize.sm,
                      onPressed: () => unawaited(_reset(context, ref, folder)),
                      child: Text(t.settings.storageFolderReset),
                    ),
                ],
              ),
            );
          }(),
        DsListRow(
          leading: const DsIcon(DsIcons.database),
          title: Text(t.settings.storageFolderData),
          description: DsTooltip(
            message: '${folders.data.path} · ${t.settings.storageFolderDataDesc}',
            child: Text(folders.data.path, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.rotateCcw),
          title: Text(t.settings.storageFoldersResetAll),
          description: Text(t.settings.storageFoldersResetAllDesc),
          trailing: DsButton(
            variant: DsButtonVariant.ghost,
            size: DsSize.sm,
            onPressed: overrides.isEmpty ? null : () => unawaited(_resetAll(context, ref)),
            child: Text(t.settings.storageFolderReset),
          ),
        ),
      ],
    );
  }
}

/// The data-and-cache page: where every kind of file lives, what the app
/// keeps on this machine — the watch history and the follow list's clipboard
/// round trip — and the cover image cache's size, clearing and cap. One page
/// because moving, clearing and capping local data are one task.
final class DataCachePane extends ConsumerWidget {
  const DataCachePane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        const DataPane(),
        const FollowsDataPane(),
        const CachePane(),
        // The folders are their own page: twelve rows with two actions each
        // did not belong in this scroll.
        SettingsChildEntry(
          child: SettingsSection.storageFolders,
          detail: Text(
            ref.watch(storageFolderOverridesProvider).isEmpty
                ? context.t.settings.storageFolderDefaultLabel
                : context.t.settings.storageFolderCustomLabel,
          ),
        ),
        // The local media page: where 本地音乐 and the file cache keep their
        // answers, beside the folders those files live in.
        const SettingsChildEntry(child: SettingsSection.localMedia),
      ],
    );
  }
}

/// The live data pane: the watch history's cap, clearing the watch history
/// behind a confirm, and the follow list as a JSON round trip through the
/// clipboard. Backups, restores and WebDAV sync are their own app-wide
/// section, so the video and IPTV modules can reach them without carrying
/// the live history.
final class DataPane extends ConsumerWidget {
  const DataPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final historyLimit = ref.watch(historyLimitProvider);
    // A cap imported from outside the choices still shows as chosen.
    final limits = {...HistoryLimitController.choices, historyLimit}.toList()..sort();
    void toast(String message) {
      showDsToast(context: context, title: message);
    }

    return DsListSection(
      header: Text(t.settings.navData),
      children: [
        SettingsChoiceRow<int>(
          leading: const DsIcon(DsIcons.clock),
          title: t.settings.historyLimit,
          description: t.settings.historyLimitDesc,
          value: historyLimit,
          options: [for (final limit in limits) DsSelectOption(value: limit, label: '$limit')],
          onChanged: (value) => unawaited(ref.read(historyLimitProvider.notifier).setLimit(value)),
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.history),
          title: Text(t.settings.dataClearHistory),
          description: Text(t.settings.dataClearHistoryDesc),
          destructive: true,
          onPressed: () async {
            final confirmed = await showDsConfirm(
              context: context,
              title: t.settings.confirmClearTitle,
              description: t.settings.confirmClearDesc,
              confirmLabel: t.settings.confirm,
              destructive: true,
            );
            if (!confirmed || !context.mounted) return;
            await ref.read(historyProvider.notifier).clear();
            if (!context.mounted) return;
            toast(t.settings.dataDone);
          },
        ),
      ],
    );
  }
}

/// The follows' own card: the list as one JSON round trip through the
/// clipboard — a different subject from the watch history above it.
final class FollowsDataPane extends ConsumerWidget {
  const FollowsDataPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    void toast(String message) {
      showDsToast(context: context, title: message);
    }

    return DsListSection(
      header: Text(t.settings.followDataGroup),
      children: [
        DsListRow(
          leading: const DsIcon(DsIcons.upload),
          title: Text(t.settings.dataExportFollows),
          description: Text(t.settings.dataExportFollowsDesc),
          onPressed: () async {
            final rooms = ref.read(followsProvider).rooms;
            if (rooms.isEmpty) {
              toast(t.settings.dataEmpty);
              return;
            }
            await Clipboard.setData(ClipboardData(text: encodeFollows(rooms)));
            toast(t.settings.dataDone);
          },
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.download),
          title: Text(t.settings.dataImportFollows),
          description: Text(t.settings.dataImportFollowsDesc),
          onPressed: () async {
            final raw = await Clipboard.getData(Clipboard.kTextPlain).then((data) => data?.text);
            final rooms = raw == null ? null : decodeFollows(raw);
            if (rooms == null) {
              toast(t.settings.dataBadData);
              return;
            }
            final repository = ref.read(followRepositoryProvider).value;
            if (repository != null) {
              for (final room in rooms) {
                await repository.add(room);
              }
            }
            toast(t.settings.dataDone);
          },
        ),
      ],
    );
  }
}

/// The cache pane: the cover/avatar disk cache the network images live in —
/// its size, a manual clear, and the automatic cap the boot prunes to.
final class CachePane extends ConsumerStatefulWidget {
  const CachePane({super.key});

  @override
  ConsumerState<CachePane> createState() => CachePaneState();
}

final class CachePaneState extends ConsumerState<CachePane> {
  int? _bytes;
  int _limitMb = imageCacheLimitMb();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_measure());
  }

  Future<void> _measure() async {
    final bytes = await imageCacheBytes();
    if (mounted) {
      setState(() => _bytes = bytes);
    }
  }

  Future<void> _clear() async {
    final t = context.t;
    final confirmed = await showDsConfirm(
      context: context,
      title: t.settings.cacheClear,
      description: t.settings.cacheClearDesc,
      confirmLabel: t.common.confirm,
      cancelLabel: t.common.cancel,
      destructive: true,
      icon: const DsIcon(DsIcons.trash2),
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await clearImageCache();
      await _measure();
      if (mounted) {
        showDsToast(context: context, title: context.t.settings.cacheCleared);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _refreshThumbnails() async {
    setState(() => _busy = true);
    try {
      await ref.read(thumbnailRefreshProvider.notifier).refreshNow();
      await _measure();
      if (mounted) {
        showDsToast(context: context, title: context.t.settings.cacheRefreshThumbnailsDone);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _setLimit(int? value) async {
    if (value == null) {
      return;
    }
    setState(() => _limitMb = value);
    await storeImageCacheLimitMb(value);
    // Applying the cap at once makes the setting honest on the spot.
    if (value > 0) {
      await enforceImageCacheLimit(value * 1024 * 1024);
      await _measure();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return DsListSection(
      header: Text(t.settings.navCache),
      children: [
        // The policy first, then what it holds and the two ways to act on it.
        SettingsChoiceRow<int>(
          leading: const DsIcon(DsIcons.database),
          title: t.settings.cacheLimit,
          description: t.settings.cacheLimitDesc,
          value: _limitMb,
          options: [
            DsSelectOption(value: 0, label: t.settings.cacheLimitOff),
            for (final mb in const [100, 200, 500, 1024, 2048]) DsSelectOption(value: mb, label: '$mb MB'),
          ],
          onChanged: (value) => unawaited(_setLimit(value)),
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.archive),
          title: Text(t.settings.cacheSize),
          detail: Text(_bytes == null ? '…' : formatCacheSize(_bytes!)),
          trailing: DsButton(
            variant: DsButtonVariant.ghost,
            size: DsSize.sm,
            leading: const DsIcon(DsIcons.refreshCw, size: 16),
            onPressed: _busy ? null : () => unawaited(_measure()),
            child: Text(t.settings.cacheRefresh),
          ),
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.image),
          title: Text(t.settings.cacheRefreshThumbnails),
          description: Text(t.settings.cacheRefreshThumbnailsDesc),
          trailing: DsButton(
            variant: DsButtonVariant.secondary,
            size: DsSize.sm,
            onPressed: _busy ? null : () => unawaited(_refreshThumbnails()),
            child: Text(t.settings.cacheRefreshThumbnails),
          ),
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.trash2),
          title: Text(t.settings.cacheClear),
          description: Text(t.settings.cacheClearDesc),
          trailing: DsButton(
            variant: DsButtonVariant.dangerSoft,
            size: DsSize.sm,
            onPressed: _busy ? null : () => unawaited(_clear()),
            child: Text(t.settings.cacheClear),
          ),
        ),
      ],
    );
  }
}
