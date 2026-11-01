import 'dart:async' show unawaited;
import 'dart:io' show Directory, File, FileStat, FileSystemEntity;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'package:pure_live/app/providers/boot/storage_providers.dart' show appPathsProvider;
import 'package:pure_live/app/providers/settings/storage_folder_provider.dart' show StorageFolder;
import 'package:pure_live/features/settings/pages/wallpaper_download_manager.dart' show openDownloadedPath;
import 'package:pure_live/features/settings/pages/wallpaper_video_player.dart' show WallpaperVideoPlayer;
import 'package:pure_live/features/settings/surface/settings_navigation.dart' show openSettingsSection;
import 'package:pure_live/features/settings/surface/settings_preview.dart' show SettingsPreviewTitleBar;
import 'package:pure_live/features/settings/surface/settings_sections.dart' show SettingsSection;
import 'package:pure_live/l10n/translations.dart';

/// The kinds of files the local media library lists.
enum LocalMediaKind {
  /// Videos: the VOD downloads and the live recordings.
  video,

  /// Songs: the music downloads.
  audio,
}

/// One saved file on disk: what a library row shows and the preview plays.
final class LocalMediaFile {
  /// The file at [path].
  const LocalMediaFile({
    required this.path,
    required this.kind,
    required this.sizeBytes,
    required this.modified,
    required this.source,
  });

  /// The file's absolute path on disk.
  final String path;

  /// The file's media kind, decided by its extension.
  final LocalMediaKind kind;

  /// The file's size in bytes.
  final int sizeBytes;

  /// The file's last write, for the row's caption and the ordering.
  final DateTime modified;

  /// The app folder the file was found in, for the row's caption.
  final StorageFolder source;

  /// The file's name with its extension.
  String get name => p.basename(path);
}

/// The saved files the viewer can browse and preview: the videos, recordings
/// and songs the app wrote, walked out of the folders 存储位置 decides.
///
/// The walk re-runs when a folder moves, and after a refresh or a deletion;
/// it answers newest first, so the file the viewer just saved leads the
/// list. It reads the directory tree directly rather than any download
/// task's memory, so files from every writer — the VOD page's one-shot
/// download, the recorder's takes, the music queue — meet in one place.
final class LocalMediaLibrary extends Notifier<List<LocalMediaFile>> {
  static const Set<String> _videoExtensions = {'.mp4', '.mkv', '.flv', '.ts', '.webm', '.mov', '.avi', '.m4v'};
  static const Set<String> _audioExtensions = {'.mp3', '.flac', '.m4a', '.wav', '.aac', '.ogg', '.opus'};

  /// How deep the walk goes below a folder's root: the recordings root keeps
  /// one take directory per session, so two levels reach every take's file.
  static const int _maxDepth = 2;

  @override
  List<LocalMediaFile> build() {
    // A folder move re-runs the walk, so the list follows 存储位置.
    ref.watch(appPathsProvider);
    return _scan();
  }

  /// Walks the folders again.
  void refresh() => state = _scan();

  /// Deletes [file] from disk and refreshes; false when the file refused —
  /// it may be open in a player.
  Future<bool> delete(LocalMediaFile file) async {
    try {
      await File(file.path).delete();
    } on Object {
      return false;
    }
    refresh();
    return true;
  }

  List<LocalMediaFile> _scan() {
    final folders = ref.read(appPathsProvider);
    final byPath = <String, LocalMediaFile>{
      // The same folder may serve two sources after a move; one entry wins.
      for (final file in [
        ..._walkDirectory(folders.videos, StorageFolder.videos, _maxDepth),
        ..._walkDirectory(folders.recordings, StorageFolder.recordings, _maxDepth),
        ..._walkDirectory(folders.music, StorageFolder.music, _maxDepth),
      ])
        file.path: file,
    };
    return byPath.values.toList()..sort((a, b) => b.modified.compareTo(a.modified));
  }

  Iterable<LocalMediaFile> _walkDirectory(Directory directory, StorageFolder source, int depth) sync* {
    final List<FileSystemEntity> entries;
    try {
      entries = directory.listSync(followLinks: false);
    } on Object {
      // A folder that moved or cannot be read contributes nothing.
      return;
    }
    for (final entity in entries) {
      if (p.basename(entity.path).startsWith('.')) continue;
      if (entity is File) {
        final kind = _kindOf(entity.path);
        if (kind == null) continue;
        final FileStat stat;
        try {
          stat = entity.statSync();
        } on Object {
          continue;
        }
        yield LocalMediaFile(
          path: entity.path,
          kind: kind,
          sizeBytes: stat.size,
          modified: stat.modified,
          source: source,
        );
      } else if (entity is Directory && depth > 1) {
        yield* _walkDirectory(entity, source, depth - 1);
      }
    }
  }

  LocalMediaKind? _kindOf(String path) {
    final extension = p.extension(path).toLowerCase();
    if (_videoExtensions.contains(extension)) return LocalMediaKind.video;
    if (_audioExtensions.contains(extension)) return LocalMediaKind.audio;
    return null;
  }
}

/// The library of saved files.
final localMediaLibraryProvider = NotifierProvider<LocalMediaLibrary, List<LocalMediaFile>>(LocalMediaLibrary.new);

/// Opens [path] in the built-in player, as a page over the caller — the same
/// stage the wallpaper previews use, sized for watching rather than for a
/// row. [title] names the page.
Future<void> showLocalMediaPreview(BuildContext context, {required String path, required String title}) {
  return Navigator.of(context, rootNavigator: true).push(
    DsPageRoute<void>(
      fullscreenDialog: true,
      builder: (context) => _LocalMediaPreviewPage(path: path, title: title),
    ),
  );
}

/// The preview's own page: the file's name over the way back, the player
/// filling the rest.
final class _LocalMediaPreviewPage extends StatelessWidget {
  const _LocalMediaPreviewPage({required this.path, required this.title});

  /// The file to play; a local path.
  final String path;

  /// The name the page's bar shows.
  final String title;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF000000),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsPreviewTitleBar(
              icon: DsIcons.playCircle,
              title: title,
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(DsSpace.s16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(DsSpace.s8),
                  // The player owns its transport; an audio file plays against
                  // the black stage the way a song preview would.
                  child: WallpaperVideoPlayer(uri: Uri.file(path)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _MediaFilter { all, video, audio }

/// The local media pane: the saved files as rows over a search and a kind
/// switch, with the built-in preview, the system player, the file's folder
/// and the delete behind each row.
final class LocalMediaPane extends ConsumerStatefulWidget {
  /// The local media pane.
  const LocalMediaPane({super.key});

  @override
  ConsumerState<LocalMediaPane> createState() => _LocalMediaPaneState();
}

final class _LocalMediaPaneState extends ConsumerState<LocalMediaPane> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  _MediaFilter _filter = _MediaFilter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<LocalMediaFile> _filtered(List<LocalMediaFile> files) {
    final query = _query.trim().toLowerCase();
    return [
      for (final file in files)
        if (switch (_filter) {
          _MediaFilter.all => true,
          _MediaFilter.video => file.kind == LocalMediaKind.video,
          _MediaFilter.audio => file.kind == LocalMediaKind.audio,
        })
          if (query.isEmpty || file.name.toLowerCase().contains(query)) file,
    ];
  }

  Future<void> _openWithSystem(BuildContext context, LocalMediaFile file) async {
    await openDownloadedPath(context, file.path, failedTitle: context.t.settings.localMediaOpenFailed);
  }

  Future<void> _openFolder(BuildContext context, LocalMediaFile file) async {
    await openDownloadedPath(context, p.dirname(file.path), failedTitle: context.t.settings.localMediaOpenFailed);
  }

  Future<void> _delete(BuildContext context, LocalMediaFile file) async {
    final t = context.t;
    final confirmed = await showDsConfirm(
      context: context,
      title: t.settings.localMediaDeleteTitle(name: file.name),
      description: t.settings.localMediaDeleteBody,
      confirmLabel: t.common.delete,
      cancelLabel: t.common.cancel,
      destructive: true,
      icon: const DsIcon(DsIcons.trash2),
    );
    // The tap can land after the dialog's host is gone (the list rebuilt
    // under it); a dead context must not reach the library's store callback.
    if (!confirmed || !context.mounted) return;
    final deleted = await ref.read(localMediaLibraryProvider.notifier).delete(file);
    if (!context.mounted) return;
    if (!deleted) showDsToast(context: context, title: t.settings.localMediaDeleteFailed, status: DsStatus.danger);
  }

  String _sourceLabel(Translations t, StorageFolder source) => switch (source) {
    StorageFolder.videos => t.settings.storageFolderVideos,
    StorageFolder.recordings => t.settings.storageFolderRecordings,
    StorageFolder.music => t.settings.storageFolderMusic,
    _ => source.name,
  };

  /// The row's caption: size, the file's own moment, and the folder it came
  /// from — the facts a file manager puts under a name.
  String _caption(Translations t, LocalMediaFile file) =>
      '${_formatBytes(file.sizeBytes)} · ${_stampOf(file.modified)} · ${_sourceLabel(t, file.source)}';

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final files = _filtered(ref.watch(localMediaLibraryProvider));
    final totalBytes = [for (final file in files) file.sizeBytes].fold(0, (sum, size) => sum + size);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s12,
      children: [
        Row(
          spacing: DsSpace.s8,
          children: [
            Expanded(
              child: DsSearchField(
                controller: _search,
                placeholder: t.common.searchHint,
                semanticLabel: t.common.searchHint,
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            DsSegmentedControl<_MediaFilter>(
              value: _filter,
              semanticLabel: t.settings.localMediaTitle,
              onChanged: (value) => setState(() => _filter = value),
              segments: [
                DsSegment(value: _MediaFilter.all, label: Text(t.settings.downloadFilterAll)),
                DsSegment(value: _MediaFilter.video, label: Text(t.settings.backgroundVideo)),
                DsSegment(value: _MediaFilter.audio, label: Text(t.settings.navAudio)),
              ],
            ),
            DsButton.icon(
              variant: DsButtonVariant.secondary,
              icon: const DsIcon(DsIcons.refreshCw),
              semanticLabel: t.settings.localMediaRefresh,
              onPressed: () => ref.read(localMediaLibraryProvider.notifier).refresh(),
            ),
          ],
        ),
        Text(
          t.settings.localMediaSummary(count: files.length, size: _formatBytes(totalBytes)),
          style: theme.typography.caption.copyWith(color: colors.textMuted),
        ),
        if (files.isEmpty)
          Expanded(child: _empty(context, t, colors))
        else
          Expanded(
            child: SingleChildScrollView(
              child: DsListSection(
                children: [
                  for (final file in files)
                    DsListRow(
                      leading: DsIcon(file.kind == LocalMediaKind.video ? DsIcons.film : DsIcons.music),
                      title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      description: DsTooltip(
                        message: file.path,
                        child: Text(_caption(t, file), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DsButton.icon(
                            variant: DsButtonVariant.secondary,
                            size: DsSize.sm,
                            icon: const DsIcon(DsIcons.play),
                            semanticLabel: t.settings.backgroundPreviewMedia,
                            onPressed: () =>
                                unawaited(showLocalMediaPreview(context, path: file.path, title: file.name)),
                          ),
                          DsMenuAnchor(
                            semanticLabel: t.common.more,
                            align: DsAlign.end,
                            builder: (context, controller, child) => DsPressable(
                              semanticLabel: t.common.more,
                              onPressed: controller.toggle,
                              builder: (context, states, _) {
                                final lit =
                                    states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
                                return Padding(
                                  padding: const EdgeInsets.all(DsSpace.s4),
                                  child: DsIcon(
                                    DsIcons.ellipsisVertical,
                                    size: theme.sizes.iconSm,
                                    color: lit ? colors.text : colors.textSubtle,
                                  ),
                                );
                              },
                            ),
                            items: [
                              DsMenuItem(
                                leading: const DsIcon(DsIcons.playCircle),
                                label: Text(t.settings.backgroundPreviewMedia),
                                onPressed: () =>
                                    unawaited(showLocalMediaPreview(context, path: file.path, title: file.name)),
                              ),
                              DsMenuItem(
                                leading: const DsIcon(DsIcons.externalLink),
                                label: Text(t.settings.localMediaSystemPlayer),
                                onPressed: () => unawaited(_openWithSystem(context, file)),
                              ),
                              DsMenuItem(
                                leading: const DsIcon(DsIcons.folderOpen),
                                label: Text(t.settings.downloadManagerOpenFolder),
                                onPressed: () => unawaited(_openFolder(context, file)),
                              ),
                              const DsMenuDivider(),
                              DsMenuItem(
                                leading: const DsIcon(DsIcons.trash2),
                                label: Text(t.common.delete),
                                destructive: true,
                                onPressed: () => unawaited(_delete(context, file)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _empty(BuildContext context, Translations t, DsColors colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: DsSpace.s8,
        children: [
          DsIcon(DsIcons.library, size: 28, color: colors.textSubtle),
          Text(t.settings.localMediaEmpty, style: DsTheme.of(context).typography.body),
          Text(
            t.settings.localMediaEmptyDesc,
            style: DsTheme.of(context).typography.caption.copyWith(color: colors.textMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DsSpace.s4),
          DsButton(
            variant: DsButtonVariant.secondary,
            size: DsSize.sm,
            onPressed: () => openSettingsSection(ref, SettingsSection.storageFolders),
            child: Text(t.settings.localMediaOpenStorage),
          ),
        ],
      ),
    );
  }
}

/// Renders a bytes figure the way a file manager would: the largest unit
/// that stays above one, one decimal from KB on.
String _formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return unit == 0 ? '${value.round()} B' : '${value.toStringAsFixed(1)} ${units[unit]}';
}

/// A local moment for a row: the clock on today's entries, a short date
/// with the clock otherwise.
String _stampOf(DateTime time) {
  final now = DateTime.now();
  final sameDay = now.year == time.year && now.month == time.month && now.day == time.day;
  final clock = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  return sameDay ? clock : '${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} $clock';
}
