import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_net/live_net.dart' show ClientProfile, LiveHttpCalls;
import 'package:pure_live/app/providers/network/network_providers.dart' show networkFactoryProvider;
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/music/controller/music_settings.dart';
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
    final sources = ref.watch(musicSourcesProvider);
    final controller = ref.read(musicSettingsProvider.notifier);
    final selected = sources.any((source) => source.id == settings.defaultSourceId) ? settings.defaultSourceId : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(t.music.settingsPlayback),
          children: [
            if (sources.isEmpty)
              DsListRow(
                leading: const DsIcon(DsIcons.plugZap),
                title: Text(t.music.defaultSource),
                description: Text(t.music.defaultSourceEmpty),
              )
            else
              SettingsChoiceRow<String>(
                leading: const DsIcon(DsIcons.plugZap),
                title: t.music.defaultSource,
                description: t.music.defaultSourceDesc,
                value: selected,
                options: [for (final source in sources) DsSelectOption(value: source.id, label: source.name)],
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
          ],
        ),
        const DsListSection(
          children: [
            SettingsChildEntry(child: SettingsSection.musicList),
            SettingsChildEntry(child: SettingsSection.musicSources),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final sources = ref.watch(musicSourcesProvider);
    final active = ref.watch(musicSettingsProvider).defaultSourceId;
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
                  leading: DsIcon(source.id == active ? DsIcons.circleCheck : DsIcons.fileCode),
                  title: Text(source.name),
                  description: Text(describe(source), maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: DsSpace.s4,
                    children: [
                      if (source.id != active)
                        DsButton.icon(
                          variant: DsButtonVariant.ghost,
                          size: DsSize.sm,
                          semanticLabel: t.music.sourceUse,
                          onPressed: () =>
                              unawaited(ref.read(musicSettingsProvider.notifier).setDefaultSource(source.id)),
                          icon: const DsIcon(DsIcons.circleCheck, size: 16),
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
      ],
    );
  }
}
