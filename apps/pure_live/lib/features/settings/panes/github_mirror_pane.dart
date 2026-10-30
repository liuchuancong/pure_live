import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/surface/settings_widgets.dart' show SettingsChoiceRow, SettingsConfigRow;
import 'package:pure_live/l10n/translations.dart';

/// The value the route picker uses for "the viewer's own endpoint".
const String _kCustomOption = 'custom';

/// The GitHub acceleration card and the mirror list under it.
///
/// The card picks the route (direct, a listed mirror, or the viewer's own
/// domain); the list shows every address the app knows — the built-in
/// presets, the published list and the viewer's additions — with a refresh
/// from the project's feed and a delete per row.
final class GithubMirrorSection extends ConsumerStatefulWidget {
  /// Creates the section.
  const GithubMirrorSection({super.key});

  @override
  ConsumerState<GithubMirrorSection> createState() => _GithubMirrorSectionState();
}

final class _GithubMirrorSectionState extends ConsumerState<GithubMirrorSection> {
  @override
  void initState() {
    super.initState();
    // The published list is fetched once, the first time the page is opened;
    // after that the refresh row is the viewer's call.
    final state = ref.read(githubMirrorProvider);
    if (state.remote.isEmpty && state.updatedAt == null && !state.loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(ref.read(githubMirrorProvider.notifier).refresh());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final state = ref.watch(githubMirrorProvider);
    final controller = ref.read(githubMirrorProvider.notifier);
    final mirrors = state.mirrors;
    final value = switch (state.mode) {
      GithubMirrorMode.direct => '',
      GithubMirrorMode.custom => _kCustomOption,
      GithubMirrorMode.mirror => mirrors.any((mirror) => mirror.url == state.mirrorUrl) ? state.mirrorUrl : '',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(t.settings.githubMirrorTitle),
          children: [
            SettingsChoiceRow<String>(
              leading: const DsIcon(DsIcons.download),
              title: t.settings.githubMirrorMode,
              description: t.settings.githubMirrorModeDesc,
              value: value,
              options: [
                DsSelectOption(value: '', label: t.settings.githubMirrorOff, detail: t.settings.githubMirrorOfficial),
                for (final mirror in mirrors)
                  DsSelectOption(value: mirror.url, label: mirror.url, detail: _sourceLabel(t, mirror.source)),
                DsSelectOption(
                  value: _kCustomOption,
                  label: t.settings.githubMirrorCustom,
                  detail: t.settings.githubMirrorCustomDetail,
                ),
              ],
              onChanged: (next) {
                if (next.isEmpty) {
                  controller.useDirect();
                  return;
                }
                if (next == _kCustomOption) {
                  controller.useCustom();
                  return;
                }
                controller.useMirror(next);
              },
            ),
            if (state.mode == GithubMirrorMode.custom)
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.link2),
                title: t.settings.githubMirrorCustomDomain,
                description: t.settings.githubMirrorCustomDesc,
                controlWidth: 260,
                control: DsTextField(
                  initialValue: state.customUrl,
                  clearable: true,
                  placeholder: 'https://your-proxy.example/',
                  semanticLabel: t.settings.githubMirrorCustomDomain,
                  onChanged: controller.setCustomUrl,
                ),
              ),
          ],
        ),
        DsListSection(
          header: Text(t.settings.githubMirrorList),
          children: [
            DsListRow(
              leading: const DsIcon(DsIcons.refreshCw),
              title: Text(t.settings.githubMirrorRefresh),
              description: Text(_statusText(t, state)),
              trailing: state.loading ? const SizedBox.square(dimension: 16, child: DsSpinner()) : null,
              onPressed: state.loading ? null : () => unawaited(controller.refresh()),
            ),
            for (final mirror in mirrors)
              DsListRow(
                leading: const DsIcon(DsIcons.link2),
                title: Text(mirror.url),
                description: Text('${_sourceLabel(t, mirror.source)} · ${_strategyLabel(t, mirror.strategy)}'),
                trailing: DsButton(
                  variant: DsButtonVariant.ghost,
                  size: DsSize.sm,
                  leading: const DsIcon(DsIcons.trash2, size: 14),
                  onPressed: () => controller.removeMirror(mirror.url),
                  child: Text(t.common.delete),
                ),
              ),
            if (mirrors.isEmpty)
              DsListRow(leading: const DsIcon(DsIcons.info), title: Text(t.settings.githubMirrorEmpty)),
            DsListRow(
              leading: const DsIcon(DsIcons.plus),
              title: Text(t.settings.githubMirrorAdd),
              showChevron: true,
              onPressed: () => unawaited(_addMirror()),
            ),
            if (kBuiltinGithubMirrors.any((mirror) => state.hidden.contains(mirror.url)))
              DsListRow(
                leading: const DsIcon(DsIcons.rotateCcw),
                title: Text(t.settings.githubMirrorRestore),
                onPressed: controller.restoreBuiltins,
              ),
          ],
        ),
      ],
    );
  }

  /// The refresh row's second line: progress, failure, or when the list
  /// last landed.
  String _statusText(Translations t, GithubMirrorState state) {
    if (state.loading) return t.settings.githubMirrorRefreshing;
    final error = state.error;
    if (error != null) return t.settings.githubMirrorFailed(error: error);
    final updated = state.updatedAt;
    if (updated == null) return t.settings.githubMirrorNever;
    return t.settings.githubMirrorUpdated(time: _formatTime(updated));
  }

  static String _formatTime(DateTime time) =>
      '${time.year}-${_pad(time.month)}-${_pad(time.day)} ${_pad(time.hour)}:${_pad(time.minute)}';

  static String _pad(int value) => value.toString().padLeft(2, '0');

  static String _sourceLabel(Translations t, GithubMirrorSource source) => switch (source) {
    GithubMirrorSource.builtin => t.settings.githubMirrorSourceBuiltin,
    GithubMirrorSource.remote => t.settings.githubMirrorSourceRemote,
    GithubMirrorSource.custom => t.settings.githubMirrorSourceCustom,
  };

  static String _strategyLabel(Translations t, GithubMirrorStrategy strategy) => switch (strategy) {
    GithubMirrorStrategy.prefix => t.settings.githubMirrorStrategyPrefix,
    GithubMirrorStrategy.replaceRawPrefix => t.settings.githubMirrorStrategyRaw,
    GithubMirrorStrategy.jsdelivrGh => t.settings.githubMirrorStrategyJsdelivr,
  };

  /// Asks for an endpoint and adds it to the list.
  Future<void> _addMirror() async {
    final t = context.t;
    final field = TextEditingController();
    final value = await showDsDialog<String>(
      context: context,
      builder: (dialogContext) => DsDialog(
        title: Text(t.settings.githubMirrorAddTitle),
        description: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s8,
          children: [
            Text(t.settings.githubMirrorAddDesc),
            DsTextField(
              controller: field,
              autofocus: true,
              placeholder: 'https://your-proxy.example/',
              semanticLabel: t.settings.githubMirrorAddTitle,
            ),
          ],
        ),
        style: const DsDialogStyle(width: 480),
        actions: [
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
    if (value == null || value.trim().isEmpty) return;
    final added = ref.read(githubMirrorProvider.notifier).addMirror(value);
    if (!added && mounted) {
      showDsToast(context: context, title: t.settings.githubMirrorAddInvalid, status: DsStatus.danger);
    }
  }
}
