import 'dart:async' show unawaited;
import 'dart:io' show Directory;

import 'package:desen_ui/desen_ui.dart';
import 'package:file_picker/file_picker.dart' show FilePicker;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_cache/live_cache.dart' show CacheCleanupResult, CategoryCacheStatistics, LiveCacheManager;
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/surface/settings_child_entry.dart' show SettingsChildEntry;
import 'package:pure_live/features/settings/surface/settings_page_action.dart' show SettingsPageActionScope;
import 'package:pure_live/features/settings/surface/settings_sections.dart' show SettingsSection;
import 'package:pure_live/features/settings/surface/settings_widgets.dart'
    show SettingsChoiceRow, SettingsConfigRow;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/recorder/engine/recorder_engine.dart' show recorderEngineProvider;
import 'package:pure_live/shared/shared.dart';

/// The folders every kind of file lives in: one row per movable folder with
/// its resolved path, and the data tree beneath them as the one row that does
/// not move. A row's buttons pick a folder or drop the choice, so "default"
/// is always the device's own answer rather than a copied path. The reset of
/// every choice at once is the page's header action, not a row.
final class StorageFoldersSection extends ConsumerStatefulWidget {
  const StorageFoldersSection({super.key});

  @override
  ConsumerState<StorageFoldersSection> createState() => _StorageFoldersSectionState();
}

final class _StorageFoldersSectionState extends ConsumerState<StorageFoldersSection> {
  /// The pushed page's header slot, when the page has one.
  ValueNotifier<Widget?>? _slot;

  /// The reset action as last handed to the slot; null when none was.
  String? _published;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _slot = SettingsPageActionScope.maybeOf(context);
  }

  @override
  void dispose() {
    // The page outlives this pane only while this pane is gone with it: a
    // header left holding a dead action would press nothing.
    final slot = _slot;
    if (slot != null && _published != null) slot.value = null;
    super.dispose();
  }

  /// Hands [action] to the page header, once per signature; a header above
  /// this body must not be rebuilt mid-layout.
  void _publish(String? signature, Widget? action) {
    final slot = _slot;
    if (slot == null || _published == signature) return;
    _published = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) slot.value = action;
    });
  }

  static String _label(Translations t, StorageFolder folder) => switch (folder) {
    StorageFolder.videos => t.settings.storageFolderVideos,
    StorageFolder.shortDramas => t.settings.storageFolderShortDramas,
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
    StorageFolder.shortDramas => folders.shortDramas,
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
    StorageFolder.cache => folders.liveCache,
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

  /// Puts a row's resolved path on the clipboard, so a bug report or a file
  /// manager can take it without retyping.
  Future<void> _copyPath(BuildContext context, String path) async {
    await Clipboard.setData(ClipboardData(text: path));
    if (!context.mounted) return;
    showDsToast(context: context, title: context.t.common.copied);
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
  Widget build(BuildContext context) {
    final t = context.t;
    final folders = ref.watch(appPathsProvider);
    final overrides = ref.watch(storageFolderOverridesProvider);
    // The reset is a page action, not a row: a pushed page shows it at the
    // header's end, and a pane shown in place keeps it in its own corner.
    final resetAll = DsButton(
      variant: DsButtonVariant.secondary,
      size: DsSize.sm,
      leading: const DsIcon(DsIcons.rotateCcw, size: 16),
      onPressed: overrides.isEmpty ? null : () => unawaited(_resetAll(context, ref)),
      child: Text(t.settings.storageFoldersResetAll),
    );
    _publish('resetAll:${overrides.isEmpty}', resetAll);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        if (_slot == null) Align(alignment: AlignmentDirectional.centerEnd, child: resetAll),
        DsListSection(
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
                      DsButton.icon(
                        variant: DsButtonVariant.ghost,
                        size: DsSize.sm,
                        semanticLabel: t.settings.storageFolderCopyPath,
                        onPressed: () => unawaited(_copyPath(context, directory)),
                        icon: const DsIcon(DsIcons.copy, size: 16),
                      ),
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
              trailing: DsButton.icon(
                variant: DsButtonVariant.ghost,
                size: DsSize.sm,
                semanticLabel: t.settings.storageFolderCopyPath,
                onPressed: () => unawaited(_copyPath(context, folders.data.path)),
                icon: const DsIcon(DsIcons.copy, size: 16),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The data-and-cache page: where every kind of file lives, what the app
/// keeps on this machine — and the cover image cache's size, clearing and
/// cap. One page because moving, clearing and capping local data are one
/// task; the watch history's own cap and clearing live on the history page,
/// behind its gauge button.
final class DataCachePane extends ConsumerWidget {
  const DataCachePane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        // The folders are their own page: twelve rows with two actions each
        // did not belong in this scroll. Grouped under its own header so the
        // entry reads like the cache group below it.
        DsListSection(
          header: Text(context.t.settings.storageFolders),
          children: [
            SettingsChildEntry(
              child: SettingsSection.storageFolders,
              detail: Text(
                ref.watch(storageFolderOverridesProvider).isEmpty
                    ? context.t.settings.storageFolderDefaultLabel
                    : context.t.settings.storageFolderCustomLabel,
              ),
            ),
          ],
        ),
        const CachePane(),
      ],
    );
  }
}

/// The cache pane: what `live_cache` holds, the policy that decides how long
/// each kind of picture lives, and the actions that clear it.
final class CachePane extends ConsumerStatefulWidget {
  const CachePane({super.key});

  @override
  ConsumerState<CachePane> createState() => CachePaneState();
}

final class CachePaneState extends ConsumerState<CachePane> {
  bool _busy = false;
  bool _showCategories = false;

  Future<void> _refreshThumbnails() async {
    setState(() => _busy = true);
    try {
      await ref.read(thumbnailRefreshProvider.notifier).refreshNow();
      ref.invalidate(cacheStatisticsProvider);
      if (mounted) {
        showDsToast(context: context, title: context.t.settings.cacheRefreshThumbnailsDone);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _run(Future<CacheCleanupResult> Function(LiveCacheManager manager) work) async {
    final t = context.t;
    setState(() => _busy = true);
    try {
      final result = await work(ref.read(liveCacheManagerProvider));
      ref.invalidate(cacheStatisticsProvider);
      if (!mounted) {
        return;
      }
      showDsToast(
        context: context,
        title: result.failedFiles > 0
            ? t.settings.cacheClearPartial(count: result.failedFiles)
            : t.settings.cacheClearDone(size: formatCacheSize(result.freedBytes)),
      );
    } on Object {
      if (mounted) {
        showDsToast(context: context, title: t.settings.cacheClearFailed, status: DsStatus.danger);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _confirmAndRun({
    required String title,
    required String description,
    required Future<CacheCleanupResult> Function(LiveCacheManager manager) work,
  }) async {
    final t = context.t;
    final confirmed = await showDsConfirm(
      context: context,
      title: title,
      description: description,
      confirmLabel: t.common.confirm,
      cancelLabel: t.common.cancel,
      destructive: true,
      icon: const DsIcon(DsIcons.trash2),
    );
    if (!confirmed || !mounted) {
      return;
    }
    await _run(work);
  }

  Future<void> _copyPath(String path) async {
    await Clipboard.setData(ClipboardData(text: path));
    if (mounted) {
      showDsToast(context: context, title: context.t.common.copied);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final settings = ref.watch(liveCacheSettingsProvider);
    final statistics = ref.watch(cacheStatisticsProvider);
    final stats = statistics.value;
    final folders = ref.watch(appPathsProvider);
    final image = stats?.image;
    final used = image?.diskSize ?? 0;
    final limitBytes = settings.maxMb * 1024 * 1024;
    final fraction = limitBytes <= 0 ? 0.0 : (used / limitBytes).clamp(0.0, 1.0);
    final hasFiles = (image?.fileCount ?? 0) > 0;
    final groups = <CacheCategoryGroup, ({int size, int count})>{};
    for (final row in image?.categories ?? const <CategoryCacheStatistics>[]) {
      final group = cacheCategoryGroup(row.category);
      final previous = groups[group] ?? (size: 0, count: 0);
      groups[group] = (size: previous.size + row.diskSize, count: previous.count + row.fileCount);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(t.settings.navCache),
          children: [
            if (statistics.hasError)
              DsListRow(
                leading: const DsIcon(DsIcons.triangleAlert),
                title: Text(t.settings.cacheStatsFailed),
                description: Text('${statistics.error}'),
                trailing: DsButton(
                  variant: DsButtonVariant.ghost,
                  size: DsSize.sm,
                  leading: const DsIcon(DsIcons.refreshCw, size: 16),
                  onPressed: () => ref.invalidate(cacheStatisticsProvider),
                  child: Text(t.settings.cacheRefresh),
                ),
              )
            else ...[
              if (stats != null && !stats.diskAvailable)
                DsListRow(
                  leading: const DsIcon(DsIcons.triangleAlert),
                  title: Text(t.settings.cacheDiskUnavailable),
                ),
              DsListRow(
                leading: const DsIcon(DsIcons.hardDrive),
                title: Text(t.settings.cacheSize),
                detail: Text('${formatCacheSize(used)} / ${_sizeLabel(settings.maxMb)}'),
                description: Padding(
                  padding: const EdgeInsets.only(top: DsSpace.s6),
                  child: DsProgressBar(value: fraction, semanticLabel: t.settings.cacheSize),
                ),
                trailing: DsButton.icon(
                  variant: DsButtonVariant.ghost,
                  size: DsSize.sm,
                  semanticLabel: t.settings.cacheRefresh,
                  onPressed: _busy ? null : () => ref.invalidate(cacheStatisticsProvider),
                  icon: const DsIcon(DsIcons.refreshCw, size: 16),
                ),
              ),
              DsListRow(
                leading: const DsIcon(DsIcons.archive),
                title: Text(t.settings.cacheFileCount),
                detail: Text(statistics.isLoading ? '…' : '${image?.fileCount ?? 0}'),
              ),
              DsListRow(
                leading: const DsIcon(DsIcons.gauge),
                title: Text(t.settings.cacheHitRate),
                detail: Text(statistics.isLoading ? '…' : '${((image?.hitRate ?? 0) * 100).toStringAsFixed(1)}%'),
              ),
              DsListRow(
                leading: const DsIcon(DsIcons.database),
                title: Text(t.settings.cacheApiMemory),
                detail: Text(
                  statistics.isLoading
                      ? '…'
                      : '${stats?.apiMemory.entryCount ?? 0} · ${formatCacheSize(stats?.apiMemory.estimatedSize ?? 0)}',
                ),
              ),
              DsListRow(
                leading: const DsIcon(DsIcons.clock),
                title: Text(t.settings.cacheLastCleanup),
                detail: Text(
                  stats?.lastCleanupAt == null ? t.settings.cacheNever : _formatTime(stats!.lastCleanupAt!),
                ),
              ),
              DsListRow(
                leading: const DsIcon(DsIcons.image),
                title: Text(t.settings.cacheCategoryBreakdown),
                trailing: DsButton.icon(
                  variant: DsButtonVariant.ghost,
                  size: DsSize.sm,
                  semanticLabel: t.settings.cacheCategoryBreakdown,
                  onPressed: () => setState(() => _showCategories = !_showCategories),
                  icon: DsIcon(_showCategories ? DsIcons.chevronUp : DsIcons.chevronDown, size: 16),
                ),
              ),
              if (_showCategories)
                for (final group in CacheCategoryGroup.values)
                  if ((groups[group]?.size ?? 0) > 0)
                    DsListRow(
                      title: Padding(
                        padding: const EdgeInsetsDirectional.only(start: DsSpace.s28),
                        child: Text(_groupLabel(t, group)),
                      ),
                      detail: Text(
                        '${formatCacheSize(groups[group]!.size)} · ${groups[group]!.count}',
                      ),
                    ),
            ],
          ],
        ),
        DsListSection(
          header: Text(t.settings.cacheImagesSection),
          children: [
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.hardDrive),
              title: t.settings.cacheDiskEnabled,
              description: t.settings.cacheDiskEnabledDesc,
              control: DsSwitch(
                value: settings.diskCacheEnabled,
                onChanged: (value) =>
                    unawaited(ref.read(liveCacheSettingsProvider.notifier).setDiskCacheEnabled(value: value)),
              ),
            ),
            SettingsChoiceRow<int>(
              leading: const DsIcon(DsIcons.database),
              title: t.settings.cacheLimit,
              description: t.settings.cacheLimitDesc,
              value: settings.maxMb,
              options: [
                for (final mb in LiveCacheSettings.limitChoices) DsSelectOption(value: mb, label: _sizeLabel(mb)),
              ],
              onChanged: (value) => unawaited(ref.read(liveCacheSettingsProvider.notifier).setMaxMb(value)),
            ),
            SettingsChoiceRow<CacheFreshness>(
              leading: const DsIcon(DsIcons.gauge),
              title: t.settings.cacheFreshness,
              description: t.settings.cacheFreshnessDesc,
              value: settings.freshness,
              options: [
                DsSelectOption(value: CacheFreshness.fresh, label: t.settings.cacheFreshnessFresh),
                DsSelectOption(value: CacheFreshness.balanced, label: t.settings.cacheFreshnessBalanced),
                DsSelectOption(value: CacheFreshness.thrifty, label: t.settings.cacheFreshnessThrifty),
              ],
              onChanged: (value) => unawaited(ref.read(liveCacheSettingsProvider.notifier).setFreshness(value)),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.clock),
              title: t.settings.cacheAutoClean,
              description: t.settings.cacheAutoCleanDesc,
              control: DsSwitch(
                value: settings.autoClean,
                onChanged: (value) => unawaited(ref.read(liveCacheSettingsProvider.notifier).setAutoClean(value: value)),
              ),
            ),
          ],
        ),
        DsListSection(
          header: Text(t.settings.cacheClear),
          children: [
            DsListRow(
              leading: const DsIcon(DsIcons.clock),
              title: Text(t.settings.cacheClearExpired),
              description: Text(t.settings.cacheClearExpiredDesc),
              trailing: DsButton(
                variant: DsButtonVariant.secondary,
                size: DsSize.sm,
                onPressed: _busy || !hasFiles ? null : () => unawaited(_run((manager) => manager.clearExpired())),
                child: Text(t.settings.cacheClearExpired),
              ),
            ),
            DsListRow(
              leading: const DsIcon(DsIcons.refreshCw),
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
              leading: const DsIcon(DsIcons.image),
              title: Text(t.settings.cacheClearImages),
              description: Text(t.settings.cacheClearImagesDesc),
              trailing: DsButton(
                variant: DsButtonVariant.dangerSoft,
                size: DsSize.sm,
                onPressed: _busy || !hasFiles
                    ? null
                    : () => unawaited(
                        _confirmAndRun(
                          title: t.settings.cacheClearImages,
                          description: t.settings.cacheClearImagesDesc,
                          work: (manager) => manager.clearImages(),
                        ),
                      ),
                child: Text(t.settings.cacheClearImages),
              ),
            ),
            DsListRow(
              leading: const DsIcon(DsIcons.trash2),
              title: Text(t.settings.cacheClearAll),
              description: Text(t.settings.cacheClearAllDesc),
              trailing: DsButton(
                variant: DsButtonVariant.dangerSoft,
                size: DsSize.sm,
                onPressed: _busy || !hasFiles
                    ? null
                    : () => unawaited(
                        _confirmAndRun(
                          title: t.settings.cacheClearAll,
                          description: t.settings.cacheClearAllDesc,
                          work: (manager) => manager.clearAll(),
                        ),
                      ),
                child: Text(t.settings.cacheClearAll),
              ),
            ),
          ],
        ),
        DsListSection(
          header: Text(t.settings.storageFolderCache),
          children: [
            DsListRow(
              leading: const DsIcon(DsIcons.folderOpen),
              title: Text(t.settings.storageFolderCache),
              description: DsTooltip(
                message: folders.liveCache.path,
                child: Text(folders.liveCache.path, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              trailing: DsButton.icon(
                variant: DsButtonVariant.ghost,
                size: DsSize.sm,
                semanticLabel: t.settings.storageFolderCopyPath,
                onPressed: () => unawaited(_copyPath(folders.liveCache.path)),
                icon: const DsIcon(DsIcons.copy, size: 16),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _sizeLabel(int megabytes) =>
      megabytes >= 1024 ? '${megabytes ~/ 1024} GB' : '$megabytes MB';

  static String _formatTime(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }

  static String _groupLabel(Translations t, CacheCategoryGroup group) => switch (group) {
    CacheCategoryGroup.cover => t.settings.cacheCategoryCover,
    CacheCategoryGroup.avatar => t.settings.cacheCategoryAvatar,
    CacheCategoryGroup.icon => t.settings.cacheCategoryIcon,
    CacheCategoryGroup.emote => t.settings.cacheCategoryEmote,
    CacheCategoryGroup.album => t.settings.cacheCategoryAlbum,
    CacheCategoryGroup.wallpaper => t.settings.cacheCategoryWallpaper,
    CacheCategoryGroup.preview => t.settings.cacheCategoryPreview,
    CacheCategoryGroup.other => t.settings.cacheCategoryOther,
  };
}
