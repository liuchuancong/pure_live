import 'dart:async' show StreamSubscription, unawaited;
import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:file_picker/file_picker.dart' show FilePicker;
import 'package:flutter/services.dart'
    show Clipboard, ClipboardData, HardwareKeyboard, KeyDownEvent, LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_net/live_net.dart' show ClientProfile, LiveHttpCalls;
import 'package:media_core_audio/media_core_audio.dart' as audio;
import 'package:pure_live/app/providers/network/github_mirror_provider.dart' show githubMirrorProvider;
import 'package:pure_live/app/providers/network/network_providers.dart' show networkFactoryProvider;
import 'package:pure_live/app/providers/settings/download_directory_provider.dart'
    show DownloadDirectoryPaths, downloadDirectoryProvider;
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/music/controller/eq/music_eq_config.dart'
    show
        MusicEqConfig,
        MusicEqController,
        MusicEqNode,
        MusicEqPreset,
        kMusicEqMaxGain,
        kMusicEqMaxNodes,
        kMusicEqMinGain,
        kMusicEqNodeMinQ,
        kMusicEqPresets,
        kMusicFxOrder,
        kMusicFxSpatialOrder,
        musicEqApplyFailedProvider,
        musicEqProvider;
import 'package:pure_live/modules/music/controller/eq/music_eq_dsp.dart' show kMusicFxCosts;
import 'package:pure_live/modules/music/controller/lx_script_runtime.dart' show lxScriptRuntimeProvider;
import 'package:pure_live/modules/music/controller/music_dislikes.dart' show musicDislikesProvider;
import 'package:pure_live/modules/music/controller/music_hotkeys.dart'
    show MusicHotkeyAction, MusicHotkeyCombo, musicHotkeysProvider;
import 'package:pure_live/modules/music/controller/music_open_api.dart'
    show musicOpenApiGateProvider, musicOpenApiLanProvider, musicOpenApiPortProvider, musicOpenApiProvider;
import 'package:pure_live/modules/music/controller/music_playback.dart' show MusicPlayerController, musicPlayerProvider;
import 'package:pure_live/modules/music/controller/music_settings.dart';
import 'package:pure_live/modules/music/controller/music_source.dart' show kLxMusicSourceId, musicSourceListProvider;
import 'package:pure_live/modules/music/controller/music_source_catalog.dart'
    show MusicCatalogEntry, fetchCatalogScript, kMusicSourceCatalog;
import 'package:pure_live/modules/music/controller/music_sources.dart';
import 'package:pure_live/modules/music/controller/music_sync.dart'
    show MusicSyncStatus, kMusicSyncModes, musicSyncProvider;
import 'package:pure_live/modules/music/controller/music_sync_server.dart'
    show
        musicSyncServerAuthCodeProvider,
        musicSyncServerGateProvider,
        musicSyncServerLanProvider,
        musicSyncServerPortProvider,
        musicSyncServerProvider,
        musicSyncServerStatusProvider;
import 'package:pure_live/modules/music/pages/music_eq_editor.dart' show MusicEqEditor;

/// The music module's own settings, the way lx-music lays its rail out:
/// the source a song is asked from, the rendition asked of it, the list
/// behaviours and the reset; the other pages (sources, download, lyrics…)
/// sit beside it as their own rows.
final class MusicSettingsPane extends ConsumerWidget {
  /// The pane shown under Settings → Music.
  const MusicSettingsPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final settings = ref.watch(musicSettingsProvider);
    final controller = ref.read(musicSettingsProvider.notifier);
    final dislikes = ref.watch(musicDislikesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(t.music.settingsPlayback),
          children: [
            SettingsChoiceRow<String>(
              leading: const DsIcon(DsIcons.disc3),
              title: t.music.defaultSource,
              description: t.music.defaultSourceDesc,
              value: settings.defaultSourceId.isEmpty ? kLxMusicSourceId : settings.defaultSourceId,
              options: [
                for (final source in ref.watch(musicSourceListProvider))
                  DsSelectOption(
                    value: source.id,
                    label: musicSourceDisplayName(t, settings.sourceNameType, source.id, source.name),
                  ),
              ],
              onChanged: (id) => unawaited(controller.setDefaultSource(id)),
            ),
            SettingsChoiceRow<MusicSourceNameType>(
              leading: const DsIcon(DsIcons.tag),
              title: t.music.sourceNameType,
              description: t.music.sourceNameTypeDesc,
              value: settings.sourceNameType,
              options: [
                for (final type in MusicSourceNameType.values) DsSelectOption(value: type, label: type.label(t)),
              ],
              onChanged: (type) => unawaited(controller.setSourceNameType(type)),
            ),
            SettingsChoiceRow<MusicQuality>(
              leading: const DsIcon(DsIcons.slidersHorizontal),
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
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.shuffle),
              title: t.music.autoCleanPlayedList,
              description: t.music.autoCleanPlayedListDesc,
              control: DsSwitch(
                value: settings.autoCleanPlayedList,
                onChanged: (value) => unawaited(controller.setAutoCleanPlayedList(value: value)),
              ),
            ),
          ],
        ),
        DsListSection(
          header: Text(t.music.settingsList),
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
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.search),
              title: t.music.searchHot,
              description: t.music.searchHotDesc,
              control: DsSwitch(
                value: settings.showHotSearches,
                onChanged: (value) => unawaited(controller.setShowHotSearches(value: value)),
              ),
            ),
          ],
        ),
        DsListSection(
          children: [
            DsListRow(
              leading: const DsIcon(DsIcons.ban),
              title: Text(t.music.dislikeRules(count: dislikes.length)),
              description: Text(t.music.dislikeRulesDesc),
              trailing: DsButton(
                variant: DsButtonVariant.secondary,
                size: DsSize.sm,
                onPressed: dislikes.isEmpty ? null : () => unawaited(_clearDislikes(context, ref)),
                child: Text(t.music.dislikeRulesClear),
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

  Future<void> _clearDislikes(BuildContext context, WidgetRef ref) async {
    await ref.read(musicDislikesProvider.notifier).clear();
    if (!context.mounted) return;
    showDsToast(context: context, title: context.t.music.dislikeRulesCleared, status: DsStatus.success);
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
    // A pasted address is fetched, the way lx-music's one import box takes
    // both a script and the page it lives at.
    final pasted = Uri.tryParse(script.trim());
    if (pasted != null && (pasted.isScheme('http') || pasted.isScheme('https')) && pasted.host.isNotEmpty) {
      final body = await _downloadScript(context, ref, pasted);
      if (body == null || !context.mounted) return;
      await _runImport(context, ref, () => ref.read(musicSourcesProvider.notifier).importScript(body));
      return;
    }
    await _runImport(context, ref, () => ref.read(musicSourcesProvider.notifier).importScript(script));
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
    final script = await _downloadScript(context, ref, uri);
    if (script == null || !context.mounted) return;
    await _runImport(context, ref, () => ref.read(musicSourcesProvider.notifier).importScript(script));
  }

  /// Fetches a script body over the plugin network profile, wording a
  /// failure; null means the toast already showed.
  Future<String?> _downloadScript(BuildContext context, WidgetRef ref, Uri uri) async {
    final t = context.t;
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
    if (!context.mounted) return null;
    if (script == null) {
      showDsToast(
        context: context,
        title: t.music.importDownloadFailed(error: failure ?? ''),
        status: DsStatus.danger,
      );
    }
    return script;
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
                  description: Text(
                    source.enabled ? describe(source) : '${t.music.sourceDisabled} · ${describe(source)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: DsSpace.s4,
                    children: [
                      DsSwitch(
                        value: source.enabled,
                        onChanged: (value) =>
                            unawaited(ref.read(musicSourcesProvider.notifier).setEnabled(source.id, enabled: value)),
                      ),
                      DsButton.icon(
                        variant: DsButtonVariant.ghost,
                        size: DsSize.sm,
                        semanticLabel: t.music.sourceDelete,
                        onPressed: () => unawaited(_remove(context, ref, source)),
                        icon: const DsIcon(DsIcons.trash2, size: 16),
                      ),
                    ],
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
        MusicSourceCatalogSection(sources: sources),
      ],
    );
  }
}

/// Runs an import and words its outcome — the script's own name on
/// success, the reason on rejection.
Future<void> _runImport(BuildContext context, WidgetRef ref, Future<MusicSourceImport> Function() work) async {
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

/// The built-in catalog: the community sources the app ships names for, one
/// tap each to download the latest script and import it. An entry whose
/// script (or display) name is already among [sources] shows imported.
final class MusicSourceCatalogSection extends ConsumerStatefulWidget {
  /// The section under the imported-source list.
  const MusicSourceCatalogSection({required this.sources, super.key});

  /// The scripts already imported, matched by name.
  final List<MusicCustomSource> sources;

  @override
  ConsumerState<MusicSourceCatalogSection> createState() => _MusicSourceCatalogSectionState();
}

final class _MusicSourceCatalogSectionState extends ConsumerState<MusicSourceCatalogSection> {
  final Set<String> _inFlight = <String>{};

  Future<void> _import(MusicCatalogEntry entry) async {
    if (_inFlight.contains(entry.id)) return;
    setState(() => _inFlight.add(entry.id));
    try {
      final script = await fetchCatalogScript(
        entry,
        (uri) => ref
            .read(networkFactoryProvider)
            .create(profile: ClientProfile.plugin)
            .getText(uri, timeout: const Duration(seconds: 20)),
        // The app's GitHub-acceleration setting orders the routes — the
        // chosen mirror first, the raw address as the fallback.
        routes: (raw) => [
          for (final candidate in ref.read(githubMirrorProvider).candidates(raw.toString())) Uri.parse(candidate),
        ],
      );
      if (!mounted) return;
      await _runImport(context, ref, () => ref.read(musicSourcesProvider.notifier).importScript(script));
    } on Object {
      if (!mounted) return;
      showDsToast(context: context, title: context.t.music.catalogFetchFailed, status: DsStatus.danger);
    } finally {
      if (mounted) setState(() => _inFlight.remove(entry.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        SettingsHint(t.music.catalogHint),
        DsListSection(
          header: Text(t.music.catalogSection),
          children: [
            for (final entry in kMusicSourceCatalog)
              DsListRow(
                leading: const DsIcon(DsIcons.download),
                title: Text(entry.name),
                description: Text(entry.scriptName),
                trailing: _trailing(context, entry),
              ),
          ],
        ),
      ],
    );
  }

  Widget _trailing(BuildContext context, MusicCatalogEntry entry) {
    final t = context.t;
    if (_inFlight.contains(entry.id)) {
      return const Padding(
        padding: EdgeInsets.all(DsSpace.s8),
        child: SizedBox(width: 16, height: 16, child: DsSpinner()),
      );
    }
    final imported = widget.sources.any((source) => entry.names.contains(source.name));
    return DsButton(
      variant: imported ? DsButtonVariant.ghost : DsButtonVariant.secondary,
      size: DsSize.sm,
      onPressed: imported ? null : () => unawaited(_import(entry)),
      child: Text(imported ? t.music.catalogImported : t.music.catalogImport),
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
              leading: const DsIcon(DsIcons.fileCog),
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
              leading: const DsIcon(DsIcons.languages),
              title: t.music.downloadIncludeTranslation,
              description: t.music.downloadIncludeTranslationDesc,
              control: DsSwitch(
                value: settings.downloadIncludeTranslation,
                onChanged: (value) => unawaited(controller.setDownloadIncludeTranslation(value: value)),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.audioLines),
              title: t.music.downloadIncludeRomanization,
              description: t.music.downloadIncludeRomanizationDesc,
              control: DsSwitch(
                value: settings.downloadIncludeRomanization,
                onChanged: (value) => unawaited(controller.setDownloadIncludeRomanization(value: value)),
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
            SettingsChoiceRow<int>(
              leading: const DsIcon(DsIcons.download),
              title: t.music.downloadMaxConcurrent,
              description: t.music.downloadMaxConcurrentDesc,
              value: settings.downloadMaxConcurrent,
              options: [for (var count = 1; count <= 5; count++) DsSelectOption(value: count, label: '$count')],
              onChanged: (value) => unawaited(controller.setDownloadMaxConcurrent(value)),
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
  static const List<int> _fontScales = [100, 120, 140, 160, 180, 200];

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
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.arrowUpDown),
              title: t.music.lyricSwapSecondary,
              description: t.music.lyricSwapSecondaryDesc,
              control: DsSwitch(
                value: settings.swapLyricSecondary,
                onChanged: (value) => unawaited(controller.setSwapLyricSecondary(value: value)),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.circleLanguage),
              title: t.music.lyricTraditionalize,
              description: t.music.lyricTraditionalizeDesc,
              control: DsSwitch(
                value: settings.traditionalizeLyric,
                onChanged: (value) => unawaited(controller.setTraditionalizeLyric(value: value)),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.audioLines),
              title: t.music.lyricWordTimed,
              description: t.music.lyricWordTimedDesc,
              control: DsSwitch(
                value: settings.playWordLyrics,
                onChanged: (value) => unawaited(controller.setPlayWordLyrics(value: value)),
              ),
            ),
            SettingsChoiceRow<int>(
              leading: const DsIcon(DsIcons.fontSize),
              title: t.music.lyricFontScale,
              description: t.music.lyricFontScaleDesc,
              value: settings.lyricFontScale,
              options: [for (final scale in _fontScales) DsSelectOption(value: scale, label: '$scale%')],
              onChanged: (value) => unawaited(controller.setLyricFontScale(value)),
            ),
            SettingsChoiceRow<MusicLyricAlignment>(
              leading: const DsIcon(DsIcons.alignLeft),
              title: t.music.lyricAlignment,
              description: t.music.lyricAlignmentDesc,
              value: settings.lyricAlignment,
              options: [
                for (final alignment in MusicLyricAlignment.values)
                  DsSelectOption(value: alignment, label: alignment.label(t)),
              ],
              onChanged: (value) => unawaited(controller.setLyricAlignment(value)),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.maximize2),
              title: t.music.lyricZoomActive,
              description: t.music.lyricZoomActiveDesc,
              control: DsSwitch(
                value: settings.lyricZoomActive,
                onChanged: (value) => unawaited(controller.setLyricZoomActive(value: value)),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.percent),
              title: t.music.lyricProgress,
              description: t.music.lyricProgressDesc,
              control: DsSwitch(
                value: settings.lyricProgress,
                onChanged: (value) => unawaited(controller.setLyricProgress(value: value)),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.arrowUpDown),
              title: t.music.lyricDragSeek,
              description: t.music.lyricDragSeekDesc,
              control: DsSwitch(
                value: settings.lyricDragSeek,
                onChanged: (value) => unawaited(controller.setLyricDragSeek(value: value)),
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
  static const List<int> _lineGaps = [0, 5, 10, 15, 20, 25];
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
            SettingsChoiceRow<int>(
              leading: const DsIcon(DsIcons.arrowUpDown),
              title: t.music.desktopLyricLineGap,
              description: t.music.desktopLyricLineGapDesc,
              value: settings.desktopLyricLineGap,
              options: [for (final gap in _lineGaps) DsSelectOption(value: gap, label: '$gap')],
              onChanged: (value) => unawaited(controller.setDesktopLyricLineGap(value)),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.bold),
              title: t.music.desktopLyricBoldLine,
              description: t.music.desktopLyricBoldLineDesc,
              control: DsSwitch(
                value: settings.desktopLyricBoldLine,
                onChanged: (value) => unawaited(controller.setDesktopLyricBoldLine(value: value)),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.languages),
              title: t.music.desktopLyricBoldExtended,
              description: t.music.desktopLyricBoldExtendedDesc,
              control: DsSwitch(
                value: settings.desktopLyricBoldExtended,
                onChanged: (value) => unawaited(controller.setDesktopLyricBoldExtended(value: value)),
              ),
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

/// The sound-effect page: the master bypass, the built-in presets, the
/// preamp and the ten-band graphic equalizer with its predicted response.
///
/// The page edits the stored configuration; the player controller watches it
/// and speaks the derived `af` chain to this instance's engine, so nothing
/// here knows what mpv spells the filters as.
final class MusicEqPane extends ConsumerWidget {
  /// The pane shown under Settings → Music → 音效.
  const MusicEqPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final eq = ref.watch(musicEqProvider);
    final applyFailed = ref.watch(musicEqApplyFailedProvider);
    final controller = ref.read(musicEqProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(t.music.eqSection),
          children: [
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.audioLines),
              title: t.music.eqEnabled,
              description: t.music.eqEnabledDesc,
              control: DsSwitch(
                value: eq.enabled,
                onChanged: (value) => unawaited(controller.update(eq.copyWith(enabled: value))),
              ),
            ),
            SettingsChoiceRow<String>(
              leading: const DsIcon(DsIcons.waves),
              title: t.music.eqPreset,
              description: t.music.eqPresetDesc,
              value: eq.presetId ?? (eq.isFlat ? 'flat' : 'custom'),
              options: [
                for (final preset in kMusicEqPresets) DsSelectOption(value: preset.id, label: presetLabel(t, preset)),
                DsSelectOption(value: 'custom', label: t.music.eqPresetCustom),
              ],
              onChanged: (id) {
                for (final preset in kMusicEqPresets) {
                  if (preset.id == id) {
                    unawaited(controller.applyPreset(preset));
                    return;
                  }
                }
                if (id == 'flat') unawaited(controller.reset());
              },
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.slidersVertical),
              title: t.music.eqPreamp,
              description: t.music.eqPreampDesc,
              control: _PreampField(eq: eq, controller: controller),
            ),
            DsListRow(
              leading: const DsIcon(DsIcons.rotateCcw),
              title: Text(t.music.eqReset),
              description: Text(t.music.eqResetDesc),
              onPressed: () => unawaited(controller.reset()),
            ),
          ],
        ),
        if (applyFailed)
          Padding(
            padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, 0),
            child: Text(t.music.eqApplyFailed, style: theme.typography.caption.copyWith(color: colors.danger.fill)),
          ),
        DsListSection(
          header: Text(t.music.eqFxSection),
          children: [
            for (final id in kMusicFxOrder) _MusicFxRow(id: id, eq: eq, controller: controller),
            for (final id in kMusicFxSpatialOrder) _MusicFxRow(id: id, eq: eq, controller: controller),
          ],
        ),
        DsListSection(
          header: Text(t.music.eqCompareTitle),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s8, DsSpace.s20, DsSpace.s12),
              child: _CompareButton(player: ref.read(musicPlayerProvider.notifier)),
            ),
          ],
        ),
        DsListSection(
          header: Text(t.music.eqNodesTitle),
          children: [
            for (final node in eq.nodes) _EqNodeRow(node: node, eq: eq, controller: controller),
            DsListRow(
              leading: const DsIcon(DsIcons.plus),
              title: Text(t.music.eqNodesAdd),
              description: Text('${eq.nodes.length} / $kMusicEqMaxNodes'),
              onPressed: eq.nodes.length >= kMusicEqMaxNodes ? null : () => unawaited(controller.addNode()),
            ),
          ],
        ),
        DsListSection(
          header: Text(t.music.eqMeterTitle),
          children: [
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.activity),
              title: t.music.eqAnalysis,
              description: t.music.eqAnalysisDesc,
              control: DsSwitch(
                value: eq.analysis,
                onChanged: (value) => unawaited(controller.setAnalysis(value: value)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s8),
              child: _LoudnessMeter(active: eq.analysis),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s12),
              child: Text(t.music.eqMeterNote, style: theme.typography.caption.copyWith(color: colors.textMuted)),
            ),
          ],
        ),
        DsListSection(
          header: Text(t.music.eqEditorTitle),
          children: const [
            Padding(
              padding: EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s12),
              child: MusicEqEditor(),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s12),
          child: Text(t.music.eqChainNote, style: theme.typography.caption.copyWith(color: colors.textMuted)),
        ),
      ],
    );
  }

  /// The preset's display name; the ids are the model's, the words are the
  /// listener's.
  static String presetLabel(Translations t, MusicEqPreset preset) => switch (preset.id) {
    'pop' => t.music.eqPresetPop,
    'rock' => t.music.eqPresetRock,
    'classical' => t.music.eqPresetClassical,
    'jazz' => t.music.eqPresetJazz,
    'electronic' => t.music.eqPresetElectronic,
    'bass' => t.music.eqPresetBass,
    'vocal' => t.music.eqPresetVocal,
    'live' => t.music.eqPresetLive,
    _ => t.music.eqPresetFlat,
  };
}

/// The preamp control: a slider plus the exact dB figure beside it, dragging
/// throttled by the controller's own persistence round-trip.
final class _PreampField extends ConsumerWidget {
  const _PreampField({required this.eq, required this.controller});

  final MusicEqConfig eq;
  final MusicEqController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    return SizedBox(
      width: 220,
      child: Row(
        spacing: DsSpace.s8,
        children: [
          Expanded(
            child: DsSlider(
              value: (eq.preampDb - -12) / 18,
              semanticLabel: t.music.eqPreamp,
              onChanged: eq.enabled ? (value) => unawaited(controller.setPreamp(-12 + value * 18)) : null,
            ),
          ),
          Text('${eq.preampDb >= 0 ? '+' : ''}${eq.preampDb.toStringAsFixed(1)} dB'),
        ],
      ),
    );
  }
}

/// One enhancement effect's row: its switch, its strength slider (shown
/// while on), and the declared cost — the spec's honesty rule, in words the
/// listener reads before enabling, not after.
final class _MusicFxRow extends ConsumerWidget {
  const _MusicFxRow({required this.id, required this.eq, required this.controller});

  final String id;
  final MusicEqConfig eq;
  final MusicEqController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final node = eq.effectOf(id);
    final on = eq.effectOn(id);

    final title = switch (id) {
      'loudness' => t.music.eqFxLoudness,
      'bass' => t.music.eqFxBass,
      'vocal' => t.music.eqFxVocal,
      'width' => t.music.eqFxWidth,
      'surround' => t.music.eqFxSurround,
      'reverb' => t.music.eqFxReverb,
      'panner' => t.music.eqFxPanner,
      'pitch' => t.music.eqFxPitch,
      _ => t.music.eqFxDynamics,
    };
    final description = switch (id) {
      'loudness' => t.music.eqFxLoudnessDesc,
      'bass' => t.music.eqFxBassDesc,
      'vocal' => t.music.eqFxVocalDesc,
      'width' => t.music.eqFxWidthDesc,
      'surround' => t.music.eqFxSurroundDesc,
      'reverb' => t.music.eqFxReverbDesc,
      'panner' => t.music.eqFxPannerDesc,
      'pitch' => t.music.eqFxPitchDesc,
      _ => t.music.eqFxDynamicsDesc,
    };

    return DsListRow(
      leading: const DsIcon(DsIcons.audioLines),
      title: Text(title),
      description: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: DsSpace.s4,
        children: [
          Text(description),
          if (on)
            SizedBox(
              width: 200,
              child: DsSlider(
                value: node.amount,
                semanticLabel: title,
                onChanged: (value) => unawaited(controller.setEffect(id, amount: value)),
              ),
            ),
          if (on && id == 'panner')
            Text(t.music.eqFxPannerSpeed, style: theme.typography.caption.copyWith(color: colors.textMuted)),
          if (on && id == 'panner')
            SizedBox(
              width: 200,
              child: DsSlider(
                value: node.detail,
                semanticLabel: t.music.eqFxPannerSpeed,
                onChanged: (value) => unawaited(controller.setEffect(id, detail: value)),
              ),
            ),
          if (on && kMusicFxCosts[id] != null)
            Text(
              '${t.music.eqFxCostPrefix}${costText(t, kMusicFxCosts[id]!)}',
              style: theme.typography.caption.copyWith(color: colors.textMuted),
            ),
        ],
      ),
      trailing: DsSwitch(
        value: node.enabled,
        onChanged: (value) => unawaited(controller.setEffect(id, enabled: value)),
      ),
    );
  }

  /// The declared cost's words: which effects mention latency, and which
  /// only make sense on stereo output.
  static String costText(Translations t, String cost) {
    final parts = <String>[];
    if (cost.contains('latency')) parts.add(t.music.eqFxCostLatency);
    if (cost.contains('stereoOnly')) parts.add(t.music.eqFxCostStereo);
    return parts.join(' · ');
  }
}

/// The loudness meter fed by the engine's analysis branch.
///
/// Two bars — momentary (400 ms) and short-term (3 s) — scaled over the
/// meter's -60…0 LUFS window. When the probe is off, the bars rest and
/// the caption says why: this is a loudness meter, not a spectrum.
final class _LoudnessMeter extends ConsumerStatefulWidget {
  /// Creates the meter.
  const _LoudnessMeter({required this.active});

  /// Whether the probe filter is in the chain right now.
  final bool active;

  @override
  ConsumerState<_LoudnessMeter> createState() => _LoudnessMeterState();
}

final class _LoudnessMeterState extends ConsumerState<_LoudnessMeter> {
  StreamSubscription<audio.AudioLoudness>? _sub;
  audio.AudioLoudness? _levels;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(_LoudnessMeter old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) _listen();
  }

  void _listen() {
    unawaited(_sub?.cancel());
    _sub = null;
    if (!widget.active) {
      if (mounted) setState(() => _levels = null);
      return;
    }
    _sub = ref.read(musicPlayerProvider.notifier).audioEngine.loudnessStream.listen((levels) {
      if (mounted) setState(() => _levels = levels);
    });
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  /// -60…0 LUFS on the bar; quieter than -60 paints as empty.
  double _fraction(double lufs) => ((lufs + 60) / 60).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final momentary = _levels == null ? 0.0 : _fraction(_levels!.momentary);
    final shortTerm = _levels == null ? 0.0 : _fraction(_levels!.shortTerm);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        _LoudnessBar(label: 'M', fraction: momentary, accent: colors.accent, track: colors.border),
        _LoudnessBar(label: 'S', fraction: shortTerm, accent: colors.accent, track: colors.border),
      ],
    );
  }
}

final class _LoudnessBar extends StatelessWidget {
  const _LoudnessBar({required this.label, required this.fraction, required this.accent, required this.track});

  final String label;
  final double fraction;
  final Color accent;
  final Color track;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    return Row(
      spacing: DsSpace.s8,
      children: [
        SizedBox(
          width: 16,
          child: Text(label, style: theme.typography.caption.copyWith(color: theme.colors.textMuted)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: Stack(
                children: [
                  ColoredBox(color: track),
                  FractionallySizedBox(
                    widthFactor: fraction,
                    child: ColoredBox(color: accent),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(
          width: 56,
          child: Text(
            '${(fraction * 60 - 60).round()} LUFS',
            style: theme.typography.caption.copyWith(color: theme.colors.textMuted),
          ),
        ),
      ],
    );
  }
}

/// One parametric node's editor: switch and delete on the header row,
/// then frequency, Q and gain sliders — log-scaled where the ear is.
final class _EqNodeRow extends ConsumerWidget {
  const _EqNodeRow({required this.node, required this.eq, required this.controller});

  final MusicEqNode node;
  final MusicEqConfig eq;
  final MusicEqController controller;

  static String _frequencyLabel(double frequency) =>
      frequency >= 1000 ? '${(frequency / 1000).toStringAsFixed(1)} kHz' : '${frequency.round()} Hz';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s8, DsSpace.s20, DsSpace.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s8,
        children: [
          Row(
            spacing: DsSpace.s8,
            children: [
              DsSwitch(
                value: node.enabled,
                onChanged: (value) => unawaited(controller.updateNode(node.id, enabled: value)),
              ),
              Expanded(
                child: Text(
                  _frequencyLabel(node.frequency),
                  style: theme.typography.body.copyWith(color: node.enabled ? colors.text : colors.textMuted),
                ),
              ),
              GestureDetector(
                onTap: () => unawaited(controller.removeNode(node.id)),
                child: DsIcon(DsIcons.trash2, size: 16, color: colors.textMuted),
              ),
            ],
          ),
          DsSlider(
            value: ((math.log(node.frequency / 20) / math.ln10) / 3).clamp(0.0, 1.0),
            semanticLabel: t.music.eqNodeFrequency,
            onChanged: (value) {
              final frequency = 20 * math.pow(10, value * 3).toDouble();
              unawaited(controller.updateNode(node.id, frequency: frequency));
            },
          ),
          Row(
            spacing: DsSpace.s8,
            children: [
              Expanded(
                child: DsSlider(
                  value: ((math.log(node.q / kMusicEqNodeMinQ) / math.ln10) / 2).clamp(0.0, 1.0),
                  semanticLabel: t.music.eqNodeQ,
                  onChanged: (value) {
                    final q = kMusicEqNodeMinQ * math.pow(10, value * 2).toDouble();
                    unawaited(controller.updateNode(node.id, q: q));
                  },
                ),
              ),
              SizedBox(
                width: 64,
                child: Text(
                  'Q ${node.q.toStringAsFixed(1)}',
                  textAlign: TextAlign.end,
                  style: theme.typography.caption.copyWith(color: colors.textMuted),
                ),
              ),
            ],
          ),
          Row(
            spacing: DsSpace.s8,
            children: [
              Expanded(
                child: DsSlider(
                  min: kMusicEqMinGain,
                  max: kMusicEqMaxGain,
                  value: node.gainDb,
                  semanticLabel: t.music.eqNodeGain,
                  onChanged: (value) => unawaited(controller.updateNode(node.id, gainDb: value)),
                ),
              ),
              SizedBox(
                width: 64,
                child: Text(
                  '${node.gainDb >= 0 ? '+' : ''}${node.gainDb.toStringAsFixed(1)} dB',
                  textAlign: TextAlign.end,
                  style: theme.typography.caption.copyWith(color: colors.textMuted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The A/B compare button: hold it and the whole chain steps aside, so the
/// ear hears the untouched mix; release restores the configuration at once.
/// The instant switch-back is the whole point — a toggle with a delay
/// cannot be compared reliably.
final class _CompareButton extends ConsumerStatefulWidget {
  /// Creates the button.
  const _CompareButton({required this.player});

  final MusicPlayerController player;

  @override
  ConsumerState<_CompareButton> createState() => _CompareButtonState();
}

final class _CompareButtonState extends ConsumerState<_CompareButton> {
  bool _held = false;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _held = true);
        widget.player.setCompareBypass(bypass: true);
      },
      onTapUp: (_) {
        if (!_held) return;
        setState(() => _held = false);
        widget.player.setCompareBypass(bypass: false);
      },
      onTapCancel: () {
        if (!_held) return;
        setState(() => _held = false);
        widget.player.setCompareBypass(bypass: false);
      },
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: _held ? colors.accent : colors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.border),
        ),
        alignment: Alignment.center,
        child: Text(
          _held ? t.music.eqCompareHeld : t.music.eqCompare,
          style: theme.typography.body.copyWith(color: _held ? colors.onAccent : colors.text),
        ),
      ),
    );
  }
}

/// The pane shown under Settings → Music → 快捷键: the module's shortcut
/// table, captured straight from the keyboard the way the reference's
/// setting records them.
final class MusicHotkeysPane extends ConsumerWidget {
  const MusicHotkeysPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final config = ref.watch(musicHotkeysProvider);
    final controller = ref.read(musicHotkeysProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(t.settings.navMusicHotkeys),
          children: [
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.keyboard),
              title: t.music.hkEnable,
              description: t.music.hkEnableDesc,
              control: DsSwitch(
                value: config.enabled,
                onChanged: (value) => unawaited(controller.setEnabled(value: value)),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.monitor),
              title: t.music.hkGlobal,
              description: t.music.hkGlobalDesc,
              control: DsSwitch(
                value: config.globalEnabled,
                onChanged: (value) => unawaited(controller.setGlobalEnabled(value: value)),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.rotateCcw),
              title: t.music.hkReset,
              description: t.music.hkResetDesc,
              control: DsButton(
                variant: DsButtonVariant.secondary,
                size: DsSize.sm,
                onPressed: () => unawaited(controller.reset()),
                child: Text(t.music.eqReset),
              ),
            ),
          ],
        ),
        DsListSection(
          children: [
            for (final action in MusicHotkeyAction.values)
              SettingsConfigRow(
                title: musicHotkeyActionLabel(t, action),
                control: _HotkeyCaptureButton(action: action),
                controlWidth: 260,
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.s4),
          child: Text(
            t.music.hkNote,
            style: DsTheme.typographyOf(context).caption.copyWith(color: DsTheme.colorsOf(context).textSubtle),
          ),
        ),
      ],
    );
  }
}

/// One action's name in words.
String musicHotkeyActionLabel(Translations t, MusicHotkeyAction action) => switch (action) {
  MusicHotkeyAction.togglePlay => t.music.hkTogglePlay,
  MusicHotkeyAction.next => t.music.hkNext,
  MusicHotkeyAction.prev => t.music.hkPrev,
  MusicHotkeyAction.seekBackward => t.music.hkSeekBackward,
  MusicHotkeyAction.seekForward => t.music.hkSeekForward,
  MusicHotkeyAction.volumeUp => t.music.hkVolumeUp,
  MusicHotkeyAction.volumeDown => t.music.hkVolumeDown,
  MusicHotkeyAction.volumeMute => t.music.hkVolumeMute,
  MusicHotkeyAction.musicLove => t.music.hkMusicLove,
  MusicHotkeyAction.musicUnlove => t.music.hkMusicUnlove,
  MusicHotkeyAction.musicDislike => t.music.hkMusicDislike,
};

/// The combo button: idle it names the stored combination, focused it
/// captures the next key press — Esc cancels, modifiers alone wait.
final class _HotkeyCaptureButton extends ConsumerStatefulWidget {
  const _HotkeyCaptureButton({required this.action});

  final MusicHotkeyAction action;

  @override
  ConsumerState<_HotkeyCaptureButton> createState() => _HotkeyCaptureButtonState();
}

final class _HotkeyCaptureButtonState extends ConsumerState<_HotkeyCaptureButton> {
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _focus.unfocus();
      return KeyEventResult.handled;
    }
    final name = _hotkeyKeyName(event.logicalKey);
    if (name == null) return KeyEventResult.handled; // a bare modifier; keep waiting
    final keyboard = HardwareKeyboard.instance;
    final modifiers = <String>{
      if (keyboard.isControlPressed || keyboard.isMetaPressed) 'mod',
      if (keyboard.isAltPressed) 'alt',
      if (keyboard.isShiftPressed) 'shift',
    };
    final combo = MusicHotkeyCombo(modifiers: modifiers, key: name);
    unawaited(ref.read(musicHotkeysProvider.notifier).assign(widget.action, combo));
    _focus.unfocus();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final config = ref.watch(musicHotkeysProvider);
    final captured = config.assignments[widget.action];
    final capturing = _focus.hasFocus;
    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: DsButton(
        variant: capturing ? DsButtonVariant.primary : DsButtonVariant.secondary,
        size: DsSize.sm,
        onPressed: () => capturing ? _focus.unfocus() : _focus.requestFocus(),
        child: Text(
          capturing
              ? t.music.hkPressNew
              : captured == null
              ? t.music.hkUnset
              : captured.display(),
          style: capturing
              ? null
              : captured == null
              ? TextStyle(color: colors.textSubtle)
              : null,
        ),
      ),
    );
  }
}

/// The pressed key's LX-style name, or null for a bare modifier.
String? _hotkeyKeyName(LogicalKeyboardKey key) {
  // identity keys, so not const
  final special = <LogicalKeyboardKey, String>{
    LogicalKeyboardKey.arrowLeft: 'arrowleft',
    LogicalKeyboardKey.arrowRight: 'arrowright',
    LogicalKeyboardKey.arrowUp: 'arrowup',
    LogicalKeyboardKey.arrowDown: 'arrowdown',
    LogicalKeyboardKey.space: 'space',
    LogicalKeyboardKey.enter: 'enter',
    LogicalKeyboardKey.escape: 'escape',
    LogicalKeyboardKey.tab: 'tab',
    LogicalKeyboardKey.backspace: 'backspace',
    LogicalKeyboardKey.delete: 'delete',
    LogicalKeyboardKey.home: 'home',
    LogicalKeyboardKey.end: 'end',
    LogicalKeyboardKey.pageUp: 'pageup',
    LogicalKeyboardKey.pageDown: 'pagedown',
  };
  if (special[key] case final name?) return name;
  final fIndex = key.keyId - LogicalKeyboardKey.f1.keyId;
  if (fIndex >= 0 && fIndex < 19) return 'f${fIndex + 1}';
  final letterIndex = key.keyId - LogicalKeyboardKey.keyA.keyId;
  if (letterIndex >= 0 && letterIndex < 26) return String.fromCharCode(0x61 + letterIndex);
  final digitIndex = key.keyId - LogicalKeyboardKey.digit0.keyId;
  if (digitIndex >= 0 && digitIndex < 10) return '$digitIndex';
  final label = key.keyLabel;
  return label.length == 1 ? label.toLowerCase() : null;
}

/// The 同步 pane: a lx-music desktop sync server's address and auth code,
/// the sync-mode answer the server merges with, and the connection itself.
final class MusicSyncPane extends ConsumerWidget {
  const MusicSyncPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final state = ref.watch(musicSyncProvider);
    final controller = ref.read(musicSyncProvider.notifier);
    final api = ref.watch(musicOpenApiProvider);
    final apiPort = ref.watch(musicOpenApiPortProvider);
    final server = ref.watch(musicSyncServerProvider);
    final serverPort = ref.watch(musicSyncServerPortProvider);
    final serverAuthCode = ref.watch(musicSyncServerAuthCodeProvider);
    final serverStatus = ref.watch(musicSyncServerStatusProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          children: [
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.link),
              title: t.music.syncHost,
              description: state.host.isEmpty ? t.music.syncHostHint : state.host,
              control: DsButton(
                variant: DsButtonVariant.secondary,
                size: DsSize.sm,
                onPressed: () => unawaited(_editHost(context, ref)),
                child: Text(t.music.syncEdit),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.history),
              title: t.music.syncHistory,
              description: state.hostHistory.isEmpty ? t.music.syncHistoryEmpty : t.music.syncHistoryDesc,
              control: DsButton(
                variant: DsButtonVariant.secondary,
                size: DsSize.sm,
                onPressed: () => unawaited(_pickHistory(context, ref)),
                child: Text(t.music.syncChoose),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.lock),
              title: t.music.syncAuthCode,
              description: state.authCode.isEmpty ? t.music.syncAuthCodeHint : '••••••',
              control: DsButton(
                variant: DsButtonVariant.secondary,
                size: DsSize.sm,
                onPressed: () => unawaited(_editAuthCode(context, ref)),
                child: Text(t.music.syncEdit),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.gitMerge),
              title: t.music.syncMode,
              description: musicSyncModeLabel(t, state.syncMode),
              control: DsSelect<String>(
                value: state.syncMode,
                options: [
                  for (final mode in kMusicSyncModes) DsSelectOption(value: mode, label: musicSyncModeLabel(t, mode)),
                ],
                onChanged: (mode) {
                  if (mode != null) unawaited(controller.setSyncMode(mode));
                },
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.cable),
              title: switch (state.status) {
                MusicSyncStatus.connected => t.music.syncStatusConnected,
                MusicSyncStatus.connecting || MusicSyncStatus.authing => t.music.syncStatusConnecting,
                MusicSyncStatus.failed => t.music.syncStatusFailed,
                MusicSyncStatus.idle => t.music.syncStatusIdle,
              },
              description: state.message ?? state.serverName ?? t.music.syncStatusHint,
              control: DsButton(
                variant: state.status == MusicSyncStatus.connected
                    ? DsButtonVariant.secondary
                    : DsButtonVariant.primary,
                size: DsSize.sm,
                onPressed: () => unawaited(
                  state.status == MusicSyncStatus.connected ? controller.disconnect() : controller.connect(),
                ),
                child: Text(state.status == MusicSyncStatus.connected ? t.music.syncDisconnect : t.music.syncConnect),
              ),
            ),
            if (state.serverName != null)
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.keyRound),
                title: t.music.syncForgetKey,
                description: t.music.syncForgetKeyDesc,
                control: DsButton(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  onPressed: () => unawaited(controller.forgetKey()),
                  child: Text(t.music.syncForgetKey),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(DsSpace.s16, DsSpace.s4, DsSpace.s16, DsSpace.s8),
              child: Text(t.music.syncNote, style: theme.typography.caption.copyWith(color: colors.textSubtle)),
            ),
          ],
        ),
        DsListSection(
          header: Text(t.music.syncServer),
          children: [
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.server),
              title: t.music.syncServerEnable,
              description: t.music.syncServerTip,
              control: DsSwitch(
                value: ref.watch(musicSyncServerGateProvider),
                onChanged: (value) => unawaited(ref.read(musicSyncServerGateProvider.notifier).set(enabled: value)),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.plug),
              title: t.music.syncServerPort,
              description: !serverStatus.running && serverStatus.error != null
                  ? t.music.syncServerErrorPort
                  : '$serverPort',
              control: DsButton(
                variant: DsButtonVariant.secondary,
                size: DsSize.sm,
                onPressed: () => unawaited(_editServerPort(context, ref)),
                child: Text(t.music.syncEdit),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.wifi),
              title: t.music.syncServerLan,
              control: DsSwitch(
                value: ref.watch(musicSyncServerLanProvider),
                onChanged: (value) => unawaited(ref.read(musicSyncServerLanProvider.notifier).set(lan: value)),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.keyRound),
              title: t.music.syncServerAuthCode,
              description: serverAuthCode,
              control: DsButton(
                variant: DsButtonVariant.secondary,
                size: DsSize.sm,
                onPressed: () => unawaited(_editServerAuthCode(context, ref)),
                child: Text(t.music.syncEdit),
              ),
            ),
            if (serverStatus.running)
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.monitor),
                title: t.music.syncServerAddress,
                description: server.address(serverPort),
                control: DsButton(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  onPressed: () =>
                      unawaited(Clipboard.setData(ClipboardData(text: server.address(serverPort)))),
                  child: Text(t.music.syncServerCopy),
                ),
              ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.smartphone),
              title: t.music.syncServerDevices,
              description: serverStatus.devices.isEmpty
                  ? t.music.syncServerDevicesEmpty
                  : serverStatus.devices.map((device) => device.deviceName).join('、'),
              control: DsButton(
                variant: DsButtonVariant.secondary,
                size: DsSize.sm,
                onPressed: serverStatus.devices.isEmpty ? null : () => unawaited(_showServerDevices(context, ref)),
                child: Text(t.music.syncServerDevicesView),
              ),
            ),
          ],
        ),
        DsListSection(
          header: Text(t.music.openApi),
          children: [
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.globe),
              title: t.music.openApiEnable,
              control: DsSwitch(
                value: ref.watch(musicOpenApiGateProvider),
                onChanged: (value) => unawaited(ref.read(musicOpenApiGateProvider.notifier).set(enabled: value)),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.plug),
              title: t.music.openApiPort,
              description: '$apiPort',
              control: DsButton(
                variant: DsButtonVariant.secondary,
                size: DsSize.sm,
                onPressed: () => unawaited(_editPort(context, ref)),
                child: Text(t.music.syncEdit),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.wifi),
              title: t.music.openApiLan,
              control: DsSwitch(
                value: ref.watch(musicOpenApiLanProvider),
                onChanged: (value) => unawaited(ref.read(musicOpenApiLanProvider.notifier).set(lan: value)),
              ),
            ),
            if (api.running)
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.monitor),
                title: t.music.openApiAddress,
                description: api.address(apiPort),
                control: DsButton(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  onPressed: () => unawaited(Clipboard.setData(ClipboardData(text: api.address(apiPort)))),
                  child: Text(t.music.openApiCopy),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _editHost(BuildContext context, WidgetRef ref) async {
    final t = context.t;
    final current = ref.read(musicSyncProvider).host;
    final value = await _editField(context, t.music.syncHost, t.music.syncHostHint, current);
    if (value != null) await ref.read(musicSyncProvider.notifier).setHost(value);
  }

  /// The reference's port input: a number field saved through the port
  /// provider; an unusable value leaves the previous port.
  Future<void> _editPort(BuildContext context, WidgetRef ref) async {
    final t = context.t;
    final current = '${ref.read(musicOpenApiPortProvider)}';
    final value = await _editField(context, t.music.openApiPort, t.music.openApiPortHint, current);
    if (value == null) return;
    final port = int.tryParse(value.trim());
    if (port != null) await ref.read(musicOpenApiPortProvider.notifier).set(port);
  }

  Future<void> _editServerPort(BuildContext context, WidgetRef ref) async {
    final t = context.t;
    final current = '${ref.read(musicSyncServerPortProvider)}';
    final value = await _editField(context, t.music.syncServerPort, t.music.syncServerPortHint, current);
    if (value == null) return;
    final port = int.tryParse(value.trim());
    if (port != null) await ref.read(musicSyncServerPortProvider.notifier).set(port);
  }

  /// The connection code dialog: an extra action refreshes the code, the
  /// reference's `刷新连接码`.
  Future<void> _editServerAuthCode(BuildContext context, WidgetRef ref) async {
    final t = context.t;
    final provider = ref.read(musicSyncServerAuthCodeProvider.notifier);
    final field = TextEditingController(text: ref.read(musicSyncServerAuthCodeProvider));
    final edited = await showDsDialog<String>(
      context: context,
      builder: (dialogContext) => DsDialog(
        title: Text(t.music.syncServerAuthCode),
        icon: const DsIcon(DsIcons.keyRound),
        description: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s8,
          children: [
            Text(t.music.syncServerAuthCodeHint),
            DsTextField(controller: field, autofocus: true, semanticLabel: t.music.syncServerAuthCode),
          ],
        ),
        actions: [
          DsButton(
            variant: DsButtonVariant.secondary,
            onPressed: () => unawaited(
              provider.refresh().then((_) => field.text = ref.read(musicSyncServerAuthCodeProvider)),
            ),
            child: Text(t.music.syncServerRefreshCode),
          ),
          DsButton(
            variant: DsButtonVariant.secondary,
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(t.common.cancel),
          ),
          DsButton(onPressed: () => Navigator.of(dialogContext).pop(field.text), child: Text(t.common.confirm)),
        ],
      ),
    );
    field.dispose();
    if (edited != null && edited.trim().isNotEmpty) await provider.set(edited);
  }

  /// The reference's certified-device list: one row per device with its
  /// last connection time, the trailing button revokes the key.
  Future<void> _showServerDevices(BuildContext context, WidgetRef ref) async {
    final t = context.t;
    final server = ref.read(musicSyncServerProvider);
    var devices = server.deviceView();
    await showDsDialog<Object?>(
      context: context,
      builder: (dialogContext) => DsDialog(
        title: Text(t.music.syncServerDevices),
        icon: const DsIcon(DsIcons.smartphone),
        description: StatefulBuilder(
          builder: (context, setState) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: DsSpace.s8,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    final connected = DateTime.fromMillisecondsSinceEpoch(device.lastConnectDate);
                    String two(int value) => value.toString().padLeft(2, '0');
                    final time =
                        '${connected.year}-${two(connected.month)}-${two(connected.day)} ${two(connected.hour)}:${two(connected.minute)}';
                    return Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                device.deviceName.isEmpty
                                    ? (device.isMobile ? t.music.syncServerMobile : t.music.syncServerDesktop)
                                    : device.deviceName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${t.music.syncServerLastConnect} $time',
                                style: DsTheme.of(context).typography.caption.copyWith(
                                  color: DsTheme.colorsOf(context).textSubtle,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () async {
                            await server.removeDevice(device.clientId);
                            setState(() => devices = server.deviceView());
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(DsSpace.s4),
                            child: DsIcon(DsIcons.trash2, size: 16),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Text(t.music.syncServerDevicesTip, style: DsTheme.of(context).typography.caption),
            ],
          ),
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
  }

  /// The reference's History popup: tap an address to fill the host field,
  /// the trailing button removes the row; the list edits in place while the
  /// dialog is open.
  Future<void> _pickHistory(BuildContext context, WidgetRef ref) async {
    final t = context.t;
    final controller = ref.read(musicSyncProvider.notifier);
    var hosts = ref.read(musicSyncProvider).hostHistory;
    final selected = await showDsDialog<String>(
      context: context,
      builder: (dialogContext) => DsDialog(
        title: Text(t.music.syncHistoryTitle),
        icon: const DsIcon(DsIcons.history),
        description: StatefulBuilder(
          builder: (context, setState) => hosts.isEmpty
              ? Text(t.music.syncHistoryEmpty)
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: hosts.length,
                    itemBuilder: (context, index) {
                      final host = hosts[index];
                      return Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => Navigator.of(dialogContext).pop(host),
                              behavior: HitTestBehavior.opaque,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: DsSpace.s8, horizontal: DsSpace.s4),
                                child: Text(host, maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() => hosts = [...hosts]..removeAt(index));
                              unawaited(controller.removeHostHistory(index));
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(DsSpace.s4),
                              child: DsIcon(DsIcons.trash2, size: 16),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
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
    if (selected != null && hosts.contains(selected)) {
      await controller.setHost(selected);
    }
  }

  Future<void> _editAuthCode(BuildContext context, WidgetRef ref) async {
    final t = context.t;
    final value = await _editField(context, t.music.syncAuthCode, t.music.syncAuthCodeHint, '');
    if (value != null && value.isNotEmpty) await ref.read(musicSyncProvider.notifier).setAuthCode(value);
  }

  Future<String?> _editField(BuildContext context, String title, String hint, String initial) async {
    final t = context.t;
    final field = TextEditingController(text: initial);
    final value = await showDsDialog<String>(
      context: context,
      builder: (context) => DsDialog(
        title: Text(title),
        icon: const DsIcon(DsIcons.link),
        description: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s8,
          children: [
            Text(hint),
            DsTextField(controller: field, autofocus: true, clearable: initial.isEmpty, semanticLabel: title),
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
    return value;
  }
}

/// The sync mode in words.
String musicSyncModeLabel(Translations t, String mode) => switch (mode) {
  'merge_local_remote' => t.music.syncModeMergeLocalRemote,
  'merge_remote_local' => t.music.syncModeMergeRemoteLocal,
  'overwrite_local_remote' => t.music.syncModeOverwriteLocalRemote,
  'overwrite_remote_local' => t.music.syncModeOverwriteRemoteLocal,
  'overwrite_local_remote_full' => t.music.syncModeOverwriteLocalRemoteFull,
  'overwrite_remote_local_full' => t.music.syncModeOverwriteRemoteLocalFull,
  _ => mode,
};
