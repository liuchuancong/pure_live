import 'dart:async' show unawaited;
import 'dart:io' show Directory;

import 'package:desen_ui/desen_ui.dart';
import 'package:file_picker/file_picker.dart' show FilePicker;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/surface/settings_child_entry.dart' show SettingsChildEntry;
import 'package:pure_live/features/settings/surface/settings_page_action.dart' show SettingsPageActionScope;
import 'package:pure_live/features/settings/surface/settings_sections.dart' show SettingsSection;
import 'package:pure_live/features/settings/surface/settings_widgets.dart' show SettingsChoiceRow;
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
        // entry reads like the cache group below it. The downloaded-media
        // library rides beside them — both are "where the files are, and what
        // is in them" — and it is the only door to that page.
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
            const SettingsChildEntry(child: SettingsSection.localMedia),
          ],
        ),
        const CachePane(),
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
