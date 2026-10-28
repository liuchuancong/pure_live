import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:file_picker/file_picker.dart' show FilePicker;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_net/live_net.dart' show ClientProfile, LiveHttpCalls;
import 'package:media_core_audio/media_core_audio.dart' as audio;
import 'package:pure_live/app/providers/network/network_providers.dart' show networkFactoryProvider;
import 'package:pure_live/app/providers/settings/download_directory_provider.dart'
    show DownloadDirectoryPaths, downloadDirectoryProvider;
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/music/controller/lx_script_runtime.dart' show lxScriptRuntimeProvider;
import 'package:pure_live/modules/music/controller/music_playback.dart' show musicPlayerProvider;
import 'package:pure_live/modules/music/controller/music_settings.dart';
import 'package:pure_live/modules/music/controller/music_source.dart' show kLxMusicSourceId;
import 'package:pure_live/modules/music/controller/music_sources.dart';

/// The music module's own settings: the source a song is asked from, the
/// rendition asked of it, and the two playback behaviours; the list page and
/// the custom-source page sit beside them, the way lx-music keeps its own
/// settings rail.
final class MusicSettingsPane extends ConsumerWidget {
  /// The pane shown under Settings → Music.
  const MusicSettingsPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final settings = ref.watch(musicSettingsProvider);
    final controller = ref.read(musicSettingsProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(t.music.settingsPlayback),
          children: [
            SettingsChoiceRow<String>(
              leading: const DsIcon(DsIcons.plugZap),
              title: t.music.defaultSource,
              description: t.music.defaultSourceDesc,
              value: kLxMusicSourceId,
              options: const [DsSelectOption(value: kLxMusicSourceId, label: 'lx-music')],
              onChanged: (id) => unawaited(controller.setDefaultSource(id)),
            ),
            SettingsChoiceRow<MusicQuality>(
              leading: const DsIcon(DsIcons.gauge),
              title: t.music.quality,
              description: t.music.qualityDesc,
              value: settings.quality,
              options: [
                for (final quality in MusicQuality.values) DsSelectOption(value: quality, label: quality.label(t)),
              ],
              onChanged: (quality) => unawaited(controller.setQuality(quality)),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.skipForward),
              title: t.music.skipOnError,
              description: t.music.skipOnErrorDesc,
              control: DsSwitch(
                value: settings.skipOnError,
                onChanged: (value) => unawaited(controller.setSkipOnError(value: value)),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.play),
              title: t.music.autoplay,
              description: t.music.autoplayDesc,
              control: DsSwitch(
                value: settings.autoplay,
                onChanged: (value) => unawaited(controller.setAutoplay(value: value)),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.history),
              title: t.music.rememberProgress,
              description: t.music.rememberProgressDesc,
              control: DsSwitch(
                value: settings.rememberProgress,
                onChanged: (value) => unawaited(controller.setRememberProgress(value: value)),
              ),
            ),
          ],
        ),
        const DsListSection(
          children: [
            SettingsChildEntry(child: SettingsSection.musicList),
            SettingsChildEntry(child: SettingsSection.musicSources),
            SettingsChildEntry(child: SettingsSection.musicDownload),
            SettingsChildEntry(child: SettingsSection.musicLyric),
            SettingsChildEntry(child: SettingsSection.musicDesktopLyric),
          ],
        ),
      ],
    );
  }
}

/// The reference's list page: where a new song lands and whether a row names
/// the source it came from.
final class MusicListPane extends ConsumerWidget {
  /// The pane shown under Settings → Music → 列表设置.
  const MusicListPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final settings = ref.watch(musicSettingsProvider);
    final controller = ref.read(musicSettingsProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          children: [
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.arrowUpToLine),
              title: t.music.addToTop,
              description: t.music.addToTopDesc,
              control: DsSwitch(
                value: settings.addToTop,
                onChanged: (value) => unawaited(controller.setAddToTop(value: value)),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.tag),
              title: t.music.showSource,
              description: t.music.showSourceDesc,
              control: DsSwitch(
                value: settings.showSource,
                onChanged: (value) => unawaited(controller.setShowSource(value: value)),
              ),
            ),
          ],
        ),
        DsListSection(
          children: [
            DsListRow(
              leading: const DsIcon(DsIcons.rotateCcw),
              title: Text(t.music.playbackReset),
              description: Text(t.music.playbackResetDesc),
              onPressed: () => unawaited(controller.reset()),
            ),
          ],
        ),
      ],
    );
  }
}

/// The custom-source page: import a lx-style script by paste or by address,
/// then enable, disable or remove it. The script is validated the way
/// lx-music validates it — a named header plus the request contract — and
/// kept verbatim for the runtime that executes it.
final class MusicSourcesPane extends ConsumerWidget {
  /// The pane shown under Settings → Music → 自定义源.
  const MusicSourcesPane({super.key});

  Future<void> _importText(BuildContext context, WidgetRef ref) async {
    final t = context.t;
    final field = TextEditingController();
    final script = await showDsDialog<String>(
      context: context,
      builder: (context) => DsDialog(
        title: Text(t.music.importTitle),
        icon: const DsIcon(DsIcons.fileCode),
        description: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s8,
          children: [
            Text(t.music.sourcesImportTextDesc),
            DsTextField.multiline(
              controller: field,
              autofocus: true,
              minLines: 6,
              maxLines: 10,
              placeholder: t.music.importScriptHint,
              semanticLabel: t.music.sourcesImportText,
            ),
          ],
        ),
        actions: [
          DsButton(
            variant: DsButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.common.cancel),
          ),
          DsButton(onPressed: () => Navigator.of(context).pop(field.text), child: Text(t.common.confirm)),
        ],
      ),
    );
    field.dispose();
    if (script == null || !context.mounted) return;
    if (script.trim().isEmpty) {
      showDsToast(context: context, title: t.music.importMissing, status: DsStatus.danger);
      return;
    }
    await _import(context, ref, () => ref.read(musicSourcesProvider.notifier).importScript(script));
  }

  Future<void> _importUrl(BuildContext context, WidgetRef ref) async {
    final t = context.t;
    final field = TextEditingController();
    final address = await showDsDialog<String>(
      context: context,
      builder: (context) => DsDialog(
        title: Text(t.music.sourcesImportUrl),
        icon: const DsIcon(DsIcons.link),
        description: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s8,
          children: [
            Text(t.music.sourcesImportUrlDesc),
            DsTextField(
              controller: field,
              autofocus: true,
              clearable: true,
              placeholder: t.music.importUrlHint,
              semanticLabel: t.music.sourcesImportUrl,
            ),
          ],
        ),
        actions: [
          DsButton(
            variant: DsButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.common.cancel),
          ),
          DsButton(onPressed: () => Navigator.of(context).pop(field.text), child: Text(t.common.confirm)),
        ],
      ),
    );
    field.dispose();
    if (address == null || !context.mounted) return;
    final uri = Uri.tryParse(address.trim());
    if (uri == null || !uri.isScheme('http') && !uri.isScheme('https')) {
      showDsToast(context: context, title: t.music.importMissing, status: DsStatus.danger);
      return;
    }
    String? script;
    String? failure;
    try {
      script = await ref
          .read(networkFactoryProvider)
          .create(profile: ClientProfile.plugin)
          .getText(uri, timeout: const Duration(seconds: 20));
    } on Object catch (error) {
      failure = '$error';
    }
    if (!context.mounted) return;
    if (script == null) {
      showDsToast(
        context: context,
        title: t.music.importDownloadFailed(error: failure ?? ''),
        status: DsStatus.danger,
      );
      return;
    }
    await _import(context, ref, () => ref.read(musicSourcesProvider.notifier).importScript(script!));
  }

  /// Runs an import and words its outcome — the script's own name on
  /// success, the reason on rejection.
  Future<void> _import(BuildContext context, WidgetRef ref, Future<MusicSourceImport> Function() work) async {
    final t = context.t;
    try {
      final result = await work();
      if (!context.mounted) return;
      showDsToast(
        context: context,
        title: switch (result.outcome) {
          MusicSourceImportOutcome.added => t.music.importDone(name: result.source.name),
          MusicSourceImportOutcome.updated => t.music.importUpdated(name: result.source.name),
        },
        status: DsStatus.success,
      );
    } on MusicSourceFailure catch (failure) {
      if (!context.mounted) return;
      showDsToast(
        context: context,
        title: switch (failure.reason) {
          MusicSourceFailureReason.empty => t.music.importMissing,
          MusicSourceFailureReason.notASource => t.music.importNotASource,
          MusicSourceFailureReason.duplicate => t.music.importDuplicate,
          MusicSourceFailureReason.limit => t.music.importLimit(count: kMusicSourceLimit),
        },
        status: DsStatus.danger,
      );
    }
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, MusicCustomSource source) async {
    final t = context.t;
    final confirmed = await showDsConfirm(
      context: context,
      title: t.music.sourceDeleteTitle(name: source.name),
      description: t.music.sourceDeleteDesc,
      confirmLabel: t.common.delete,
      cancelLabel: t.common.cancel,
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await ref.read(musicSourcesProvider.notifier).remove(source.id);
    if (ref.read(musicSettingsProvider).defaultSourceId == source.id) {
      await ref.read(musicSettingsProvider.notifier).setDefaultSource('');
    }
    if (context.mounted) {
      showDsToast(
        context: context,
        title: t.music.sourceDeleted(name: source.name),
        status: DsStatus.success,
      );
    }
  }

  Future<void> _reload(BuildContext context, WidgetRef ref) async {
    final t = context.t;
    final runtime = ref.read(lxScriptRuntimeProvider);
    await runtime.load(ref.read(musicSourcesProvider));
    if (!context.mounted) return;
    final errors = runtime.errors;
    showDsToast(
      context: context,
      title: errors.isEmpty
          ? t.music.sourcesReloaded(count: runtime.instances.length)
          : t.music.sourcesReloadedErrors(count: errors.length),
      status: errors.isEmpty ? DsStatus.success : DsStatus.warning,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final sources = ref.watch(musicSourcesProvider);
    String describe(MusicCustomSource source) {
      if (source.description.isNotEmpty) return source.description;
      final meta = [source.author, source.version].where((part) => part.isNotEmpty).join(' · ');
      return meta.isEmpty ? t.music.sourceNoDescription : meta;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        SettingsHint(t.music.sourcesHint),
        DsListSection(
          header: Text(t.music.sourcesSection),
          children: [
            DsListRow(
              leading: const DsIcon(DsIcons.clipboardPaste),
              title: Text(t.music.sourcesImportText),
              description: Text(t.music.sourcesImportTextDesc),
              showChevron: true,
              onPressed: () => unawaited(_importText(context, ref)),
            ),
            DsListRow(
              leading: const DsIcon(DsIcons.link),
              title: Text(t.music.sourcesImportUrl),
              description: Text(t.music.sourcesImportUrlDesc),
              showChevron: true,
              onPressed: () => unawaited(_importUrl(context, ref)),
            ),
            DsListRow(
              leading: const DsIcon(DsIcons.refreshCw),
              title: Text(t.music.sourcesReload),
              description: Text(t.music.sourcesReloadDesc),
              onPressed: () => unawaited(_reload(context, ref)),
            ),
          ],
        ),
        if (sources.isEmpty)
          DsListSection(
            children: [
              DsListRow(
                leading: const DsIcon(DsIcons.fileMusic),
                title: Text(t.music.sourcesEmpty),
                description: Text(t.music.sourcesEmptyDesc),
              ),
            ],
          )
        else
          DsListSection(
            children: [
              for (final source in sources)
                DsListRow(
                  leading: const DsIcon(DsIcons.fileCode),
                  title: Text(source.name),
                  description: Text(describe(source), maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: DsButton.icon(
                    variant: DsButtonVariant.ghost,
                    size: DsSize.sm,
                    semanticLabel: t.music.sourceDelete,
                    onPressed: () => unawaited(_remove(context, ref, source)),
                    icon: const DsIcon(DsIcons.trash2, size: 16),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s12),
                child: Text(
                  t.music.sourcesCount(count: sources.length),
                  style: theme.typography.caption.copyWith(color: colors.textSubtle),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// The download page: where files land, the container, the file name, and the
/// post-processing lx-music offers — cover art, tags, a sidecar lyric and the
/// skip-if-present rule.
final class MusicDownloadPane extends ConsumerWidget {
  /// The pane shown under Settings → Music → 下载.
  const MusicDownloadPane({super.key});

  Future<void> _pickDirectory(BuildContext context, WidgetRef ref) async {
    final t = context.t;
    try {
      final selected = await FilePicker.getDirectoryPath(dialogTitle: t.music.downloadDirectory);
      if (selected == null || selected.trim().isEmpty) return;
      final saved = await ref.read(downloadDirectoryProvider.notifier).setDirectory(selected);
      if (!context.mounted) return;
      showDsToast(
        context: context,
        title: saved ? t.music.downloadDirectoryUpdated : t.music.downloadDirectoryFailed,
        status: saved ? DsStatus.success : DsStatus.danger,
      );
    } on Object {
      if (context.mounted) {
        showDsToast(context: context, title: t.music.downloadDirectoryFailed, status: DsStatus.danger);
      }
    }
  }

  Future<void> _editPattern(BuildContext context, WidgetRef ref) async {
    final t = context.t;
    final settings = ref.read(musicSettingsProvider);
    final field = TextEditingController(text: settings.downloadPattern);
    final pattern = await showDsDialog<String>(
      context: context,
      builder: (context) => DsDialog(
        title: Text(t.music.downloadPattern),
        icon: const DsIcon(DsIcons.fileCode),
        description: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s8,
          children: [
            Text(t.music.downloadPatternHint),
            DsTextField(controller: field, autofocus: true, clearable: true, semanticLabel: t.music.downloadPattern),
          ],
        ),
        actions: [
          DsButton(
            variant: DsButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.common.cancel),
          ),
          DsButton(onPressed: () => Navigator.of(context).pop(field.text), child: Text(t.common.confirm)),
        ],
      ),
    );
    field.dispose();
    if (pattern == null) return;
    await ref.read(musicSettingsProvider.notifier).setDownloadPattern(pattern);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final settings = ref.watch(musicSettingsProvider);
    final controller = ref.read(musicSettingsProvider.notifier);
    final directory = ref.watch(downloadDirectoryProvider).effectivePath;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        SettingsHint(t.music.downloadHint),
        DsListSection(
          header: Text(t.music.downloadDirectory),
          children: [
            DsListRow(
              leading: const DsIcon(DsIcons.folderOpen),
              title: Text(t.music.downloadDirectory),
              description: Text(directory, maxLines: 2, overflow: TextOverflow.ellipsis),
              showChevron: true,
              onPressed: () => unawaited(_pickDirectory(context, ref)),
            ),
            DsListRow(
              leading: const DsIcon(DsIcons.rotateCcw),
              title: Text(t.music.downloadDirectoryDefault),
              description: Text(t.music.downloadDirectoryDefaultDesc),
              onPressed: () => unawaited(ref.read(downloadDirectoryProvider.notifier).reset()),
            ),
          ],
        ),
        DsListSection(
          children: [
            SettingsChoiceRow<MusicDownloadType>(
              leading: const DsIcon(DsIcons.disc3),
              title: t.music.downloadType,
              description: t.music.downloadTypeDesc,
              value: settings.downloadType,
              options: [for (final type in MusicDownloadType.values) DsSelectOption(value: type, label: type.label(t))],
              onChanged: (type) => unawaited(controller.setDownloadType(type)),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.fileCode),
              title: t.music.downloadPattern,
              description: settings.downloadPattern,
              control: DsButton(
                variant: DsButtonVariant.secondary,
                size: DsSize.sm,
                onPressed: () => unawaited(_editPattern(context, ref)),
                child: Text(t.music.downloadPatternEdit),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.image),
              title: t.music.downloadEmbedCover,
              description: t.music.downloadEmbedCoverDesc,
              control: DsSwitch(
                value: settings.downloadEmbedCover,
                onChanged: (value) => unawaited(controller.setDownloadEmbedCover(value: value)),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.tag),
              title: t.music.downloadEmbedLyric,
              description: t.music.downloadEmbedLyricDesc,
              control: DsSwitch(
                value: settings.downloadEmbedLyric,
                onChanged: (value) => unawaited(controller.setDownloadEmbedLyric(value: value)),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.fileText),
              title: t.music.downloadWriteLyric,
              description: t.music.downloadWriteLyricDesc,
              control: DsSwitch(
                value: settings.downloadWriteLyric,
                onChanged: (value) => unawaited(controller.setDownloadWriteLyric(value: value)),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.fileCheck),
              title: t.music.downloadSkipExisting,
              description: t.music.downloadSkipExistingDesc,
              control: DsSwitch(
                value: settings.downloadSkipExisting,
                onChanged: (value) => unawaited(controller.setDownloadSkipExisting(value: value)),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.folderTree),
              title: t.music.downloadGroupByList,
              description: t.music.downloadGroupByListDesc,
              control: DsSwitch(
                value: settings.downloadGroupByList,
                onChanged: (value) => unawaited(controller.setDownloadGroupByList(value: value)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The lyric page: which secondary tracks a line shows, and the viewer's
/// delay — lx-music's 歌词设置.
final class MusicLyricPane extends ConsumerWidget {
  /// The pane shown under Settings → Music → 歌词.
  const MusicLyricPane({super.key});

  static const List<int> _offsets = [-2000, -1500, -1000, -500, 0, 500, 1000, 1500, 2000];

  String _offsetLabel(Translations t, int ms) {
    if (ms == 0) return t.music.lyricOffsetReset;
    final seconds = (ms / 1000).toStringAsFixed(1);
    return ms > 0 ? '+${seconds}s' : '${seconds}s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final settings = ref.watch(musicSettingsProvider);
    final controller = ref.read(musicSettingsProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        SettingsHint(t.music.lyricHint),
        DsListSection(
          children: [
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.languages),
              title: t.music.lyricTranslation,
              description: t.music.lyricTranslationDesc,
              control: DsSwitch(
                value: settings.showTranslation,
                onChanged: (value) => unawaited(controller.setShowTranslation(value: value)),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.audioLines),
              title: t.music.lyricRomanization,
              description: t.music.lyricRomanizationDesc,
              control: DsSwitch(
                value: settings.showRomanization,
                onChanged: (value) => unawaited(controller.setShowRomanization(value: value)),
              ),
            ),
            SettingsChoiceRow<int>(
              leading: const DsIcon(DsIcons.clock),
              title: t.music.lyricOffset,
              description: t.music.lyricOffsetDesc,
              value: settings.lyricOffsetMs,
              options: [for (final offset in _offsets) DsSelectOption(value: offset, label: _offsetLabel(t, offset))],
              onChanged: (offset) => unawaited(controller.setLyricOffsetMs(offset)),
            ),
          ],
        ),
      ],
    );
  }
}

/// The desktop lyric page: show/lock the native overlay and its type — the
/// reference's 桌面歌词 settings.
final class MusicDesktopLyricPane extends ConsumerWidget {
  /// The pane shown under Settings → Music → 桌面歌词.
  const MusicDesktopLyricPane({super.key});

  static const List<double> _sizes = [24, 32, 40, 48, 56, 64];
  static const List<double> _opacities = [1, 0.9, 0.8, 0.7, 0.6, 0.5];
  static const List<double> _strokeWidths = [0, 1, 2, 3, 4];
  static const List<int> _colors = [0xFFFFFFFF, 0xFFFFE066, 0xFF67E8F9, 0xFFF9A8D4, 0xFF86EFAC, 0xFFFDBA74];
  static const List<int> _strokeColors = [0xFF000000, 0xFFFFFFFF, 0xFF9CA3AF];

  String _alignmentLabel(Translations t, audio.DesktopLyricAlignment alignment) => switch (alignment) {
    audio.DesktopLyricAlignment.left => t.music.desktopLyricAlignLeft,
    audio.DesktopLyricAlignment.center => t.music.desktopLyricAlignCenter,
    audio.DesktopLyricAlignment.right => t.music.desktopLyricAlignRight,
  };

  String _colorLabel(Translations t, int color) => switch (color) {
    0xFFFFFFFF => t.music.desktopLyricColorWhite,
    0xFFFFE066 => t.music.desktopLyricColorYellow,
    0xFF67E8F9 => t.music.desktopLyricColorCyan,
    0xFFF9A8D4 => t.music.desktopLyricColorPink,
    0xFF86EFAC => t.music.desktopLyricColorGreen,
    0xFF000000 => t.music.desktopLyricColorBlack,
    0xFF9CA3AF => t.music.desktopLyricColorGray,
    _ => t.music.desktopLyricColorOrange,
  };

  Future<void> _setEnabled(BuildContext context, WidgetRef ref, bool value) async {
    final t = context.t;
    final ok = await ref.read(musicPlayerProvider.notifier).setDesktopLyricVisible(visible: value);
    if (!context.mounted) return;
    if (value && !ok) {
      showDsToast(context: context, title: t.music.desktopLyricsUnavailable, status: DsStatus.warning);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final settings = ref.watch(musicSettingsProvider);
    final controller = ref.read(musicSettingsProvider.notifier);
    final player = ref.read(musicPlayerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        SettingsHint(t.music.desktopLyricHint),
        DsListSection(
          children: [
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.monitor),
              title: t.music.desktopLyrics,
              description: t.music.desktopLyricEnableDesc,
              control: DsSwitch(
                value: settings.desktopLyrics,
                onChanged: (value) => unawaited(_setEnabled(context, ref, value)),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.lock),
              title: t.music.desktopLyricLock,
              description: t.music.desktopLyricLockDesc,
              control: DsSwitch(
                value: settings.desktopLyricLocked,
                onChanged: (value) => unawaited(player.setDesktopLyricLocked(locked: value)),
              ),
            ),
          ],
        ),
        DsListSection(
          header: Text(t.music.desktopLyricStyleSection),
          children: [
            SettingsChoiceRow<double>(
              leading: const DsIcon(DsIcons.type),
              title: t.music.desktopLyricFontSize,
              description: t.music.desktopLyricFontSizeDesc,
              value: settings.desktopLyricFontSize,
              options: [for (final size in _sizes) DsSelectOption(value: size, label: '${size.round()}')],
              onChanged: (value) => unawaited(controller.setDesktopLyricFontSize(value)),
            ),
            SettingsChoiceRow<double>(
              leading: const DsIcon(DsIcons.droplet),
              title: t.music.desktopLyricOpacity,
              description: t.music.desktopLyricOpacityDesc,
              value: settings.desktopLyricOpacity,
              options: [
                for (final value in _opacities) DsSelectOption(value: value, label: '${(value * 100).round()}%'),
              ],
              onChanged: (value) => unawaited(controller.setDesktopLyricOpacity(value)),
            ),
            SettingsChoiceRow<int>(
              leading: const DsIcon(DsIcons.palette),
              title: t.music.desktopLyricTextColor,
              description: t.music.desktopLyricTextColorDesc,
              value: settings.desktopLyricTextColor,
              options: [
                for (final color in _colors)
                  DsSelectOption(
                    value: color,
                    label: _colorLabel(t, color),
                    leading: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Color(color),
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.border),
                      ),
                    ),
                  ),
              ],
              onChanged: (value) => unawaited(controller.setDesktopLyricTextColor(value)),
            ),
            SettingsChoiceRow<double>(
              leading: const DsIcon(DsIcons.contrast),
              title: t.music.desktopLyricStrokeWidth,
              description: t.music.desktopLyricStrokeWidthDesc,
              value: settings.desktopLyricStrokeWidth,
              options: [
                for (final width in _strokeWidths)
                  DsSelectOption(value: width, label: width == 0 ? t.music.desktopLyricStrokeNone : '${width.round()}'),
              ],
              onChanged: (value) => unawaited(controller.setDesktopLyricStrokeWidth(value)),
            ),
            SettingsChoiceRow<int>(
              leading: const DsIcon(DsIcons.palette),
              title: t.music.desktopLyricStrokeColor,
              description: t.music.desktopLyricStrokeColorDesc,
              value: settings.desktopLyricStrokeColor,
              options: [
                for (final color in _strokeColors)
                  DsSelectOption(
                    value: color,
                    label: _colorLabel(t, color),
                    leading: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Color(color),
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.border),
                      ),
                    ),
                  ),
              ],
              onChanged: (value) => unawaited(controller.setDesktopLyricStrokeColor(value)),
            ),
            SettingsChoiceRow<audio.DesktopLyricAlignment>(
              leading: const DsIcon(DsIcons.alignLeft),
              title: t.music.desktopLyricAlignment,
              description: t.music.desktopLyricAlignmentDesc,
              value: settings.desktopLyricAlignment,
              options: [
                for (final alignment in audio.DesktopLyricAlignment.values)
                  DsSelectOption(value: alignment, label: _alignmentLabel(t, alignment)),
              ],
              onChanged: (value) => unawaited(controller.setDesktopLyricAlignment(value)),
            ),
          ],
        ),
      ],
    );
  }
}
