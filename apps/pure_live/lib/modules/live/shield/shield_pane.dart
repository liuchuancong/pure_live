import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/shield/danmaku_filter_settings.dart';
import 'package:pure_live/modules/live/shield/shield_add_field.dart';
import 'package:pure_live/modules/live/shield/shield_repository.dart';

/// The danmaku filter's settings pane (the reference's video → danmaku
/// filter page): the shield's master switch, then its rules one group at a
/// time — what a line may contain, the blocked keywords, the blocked users.
/// Every rule applies in the live room's danmaku pipeline through the
/// settings providers.
final class ShieldPane extends ConsumerStatefulWidget {
  /// The pane.
  const ShieldPane({super.key});

  @override
  ConsumerState<ShieldPane> createState() => _ShieldPaneState();
}

/// The rule groups the segmented control switches between.
enum _ShieldGroup { content, keywords, users }

final class _ShieldPaneState extends ConsumerState<ShieldPane> {
  _ShieldGroup _group = _ShieldGroup.content;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final rules = ref.watch(shieldRulesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: DsSpace.s16,
      children: [
        // The master switch governs every group, so it stays above the
        // control rather than inside one of them.
        DsListSection(
          header: Text(t.shield.masterTitle),
          children: [
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.shield),
              title: t.shield.enabled,
              description: t.shield.enabledDescription,
              control: DsSwitch(
                value: rules.enabled,
                onChanged: (value) => unawaited(ref.read(shieldRulesProvider.notifier).setEnabled(value: value)),
              ),
            ),
            SettingsHint(t.shield.effectNote),
          ],
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: DsSegmentedControl<_ShieldGroup>(
            value: _group,
            semanticLabel: t.shield.title,
            segments: [
              DsSegment(
                value: _ShieldGroup.content,
                label: Text(t.shield.contentTitle),
                icon: const DsIcon(DsIcons.fileText, size: 16),
              ),
              DsSegment(
                value: _ShieldGroup.keywords,
                label: Text(t.shield.keywordsTitle),
                icon: const DsIcon(DsIcons.filter, size: 16),
              ),
              DsSegment(
                value: _ShieldGroup.users,
                label: Text(t.shield.usersTitle),
                icon: const DsIcon(DsIcons.users, size: 16),
              ),
            ],
            onChanged: (value) => setState(() => _group = value),
          ),
        ),
        switch (_group) {
          _ShieldGroup.content => _content(context),
          _ShieldGroup.keywords => _ShieldList(
            icon: DsIcons.filter,
            title: t.shield.keywordsTitle,
            entries: rules.keywords,
            fieldHint: t.shield.keywordFieldHint,
            emptyText: t.shield.keywordsEmpty,
            onAdd: (value) => ref.read(shieldRulesProvider.notifier).addKeyword(value),
            onRemove: (value) => ref.read(shieldRulesProvider.notifier).removeKeyword(value),
            onClear: () => ref.read(shieldRulesProvider.notifier).clearKeywords(),
          ),
          _ShieldGroup.users => _ShieldList(
            icon: DsIcons.users,
            title: t.shield.usersTitle,
            entries: rules.users,
            fieldHint: t.shield.userFieldHint,
            emptyText: t.shield.usersEmpty,
            onAdd: (value) => ref.read(shieldRulesProvider.notifier).addUser(value),
            onRemove: (value) => ref.read(shieldRulesProvider.notifier).removeUser(value),
            onClear: () => ref.read(shieldRulesProvider.notifier).clearUsers(),
          ),
        },
      ],
    );
  }

  /// The rules that judge a line's own words: the similarity filter, the
  /// repeat filter, and the block switches.
  Widget _content(BuildContext context) {
    final t = context.t;
    final filter = ref.watch(danmakuFilterProvider);
    final filterController = ref.read(danmakuFilterProvider.notifier);
    final repeat = ref.watch(danmakuRepeatProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(t.shield.similarityTitle),
          children: [
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.scanText),
              title: t.shield.similarityEnabled,
              description: t.shield.similarityEnabledDescription,
              control: DsSwitch(
                value: filter.similarityEnabled,
                onChanged: (value) => unawaited(filterController.setSimilarityEnabled(value: value)),
              ),
            ),
            if (filter.similarityEnabled) ...[
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.percent),
                title: t.shield.similarityThreshold,
                description: t.shield.similarityThresholdDescription,
                detail: Text('${filter.similarityThreshold}%'),
                controlWidth: 220,
                control: DsSlider(
                  value: filter.similarityThreshold.toDouble(),
                  min: DanmakuFilterRange.thresholdMin.toDouble(),
                  max: DanmakuFilterRange.thresholdMax.toDouble(),
                  divisions: DanmakuFilterRange.thresholdMax - DanmakuFilterRange.thresholdMin,
                  onChanged: (value) => unawaited(filterController.setSimilarityThreshold(value.round())),
                  semanticLabel: t.shield.similarityThreshold,
                ),
              ),
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.timer),
                title: t.shield.similarityCacheDuration,
                description: t.shield.similarityCacheDurationDescription,
                detail: Text(t.shield.similaritySeconds(seconds: '${filter.similarityCacheSeconds}')),
                controlWidth: 220,
                control: DsSlider(
                  value: filter.similarityCacheSeconds.toDouble(),
                  min: DanmakuFilterRange.cacheSecondsMin.toDouble(),
                  max: DanmakuFilterRange.cacheSecondsMax.toDouble(),
                  divisions: DanmakuFilterRange.cacheSecondsMax - DanmakuFilterRange.cacheSecondsMin,
                  onChanged: (value) => unawaited(filterController.setSimilarityCacheSeconds(value.round())),
                  semanticLabel: t.shield.similarityCacheDuration,
                ),
              ),
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.database),
                title: t.shield.similarityMaxCacheSize,
                description: t.shield.similarityMaxCacheSizeDescription,
                detail: Text('${filter.similarityMaxCacheSize}'),
                controlWidth: 220,
                control: DsSlider(
                  value: filter.similarityMaxCacheSize.toDouble(),
                  min: DanmakuFilterRange.maxCacheSizeMin.toDouble(),
                  max: DanmakuFilterRange.maxCacheSizeMax.toDouble(),
                  divisions:
                      (DanmakuFilterRange.maxCacheSizeMax - DanmakuFilterRange.maxCacheSizeMin) ~/
                      DanmakuFilterRange.maxCacheSizeStep,
                  onChanged: (value) => unawaited(
                    filterController.setSimilarityMaxCacheSize(
                      (value / DanmakuFilterRange.maxCacheSizeStep).round() * DanmakuFilterRange.maxCacheSizeStep,
                    ),
                  ),
                  semanticLabel: t.shield.similarityMaxCacheSize,
                ),
              ),
            ],
          ],
        ),
        DsListSection(
          header: Text(t.shield.repeatTitle),
          children: [
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.repeat),
              title: t.shield.repeatEnabled,
              description: t.shield.repeatEnabledDescription,
              control: DsSwitch(
                value: repeat.enabled,
                onChanged: (value) => unawaited(ref.read(danmakuRepeatProvider.notifier).setEnabled(value: value)),
              ),
            ),
            if (repeat.enabled)
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.timer),
                title: t.shield.repeatWindow,
                detail: Text(t.shield.similaritySeconds(seconds: '${repeat.windowSeconds}')),
                controlWidth: 220,
                control: DsSlider(
                  value: repeat.windowSeconds.toDouble(),
                  min: kDanmakuRepeatWindowMin.toDouble(),
                  max: kDanmakuRepeatWindowMax.toDouble(),
                  divisions: kDanmakuRepeatWindowMax - kDanmakuRepeatWindowMin,
                  onChanged: (value) =>
                      unawaited(ref.read(danmakuRepeatProvider.notifier).setWindowSeconds(value.round())),
                  semanticLabel: t.shield.repeatWindow,
                ),
              ),
          ],
        ),
        DsListSection(
          header: Text(t.shield.contentTitle),
          children: [
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.smile),
              title: t.shield.blockEmoteOnly,
              description: t.shield.blockEmoteOnlyDescription,
              control: DsSwitch(
                value: filter.blockEmoteOnly,
                onChanged: (value) => unawaited(filterController.setBlockEmoteOnly(value: value)),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.fileText),
              title: t.shield.blockLong,
              description: t.shield.blockLongDescription,
              control: DsSwitch(
                value: filter.blockLong,
                onChanged: (value) => unawaited(filterController.setBlockLong(value: value)),
              ),
            ),
            if (filter.blockLong)
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.fileText),
                title: t.shield.blockLongLength,
                description: t.shield.blockLongLengthDescription,
                detail: Text(t.shield.blockLongLengthValue(count: filter.blockLongLength)),
                controlWidth: 220,
                control: DsSlider(
                  value: filter.blockLongLength.toDouble(),
                  min: DanmakuFilterRange.blockLongLengthMin.toDouble(),
                  max: DanmakuFilterRange.blockLongLengthMax.toDouble(),
                  divisions:
                      (DanmakuFilterRange.blockLongLengthMax - DanmakuFilterRange.blockLongLengthMin) ~/
                      DanmakuFilterRange.blockLongLengthStep,
                  onChanged: (value) => unawaited(
                    filterController.setBlockLongLength(
                      (value / DanmakuFilterRange.blockLongLengthStep).round() * DanmakuFilterRange.blockLongLengthStep,
                    ),
                  ),
                  semanticLabel: t.shield.blockLongLength,
                ),
              ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.bot),
              title: t.shield.douyuSuspected,
              description: t.shield.douyuSuspectedDescription,
              control: DsSwitch(
                value: filter.douyuSuspectedAutomated,
                onChanged: (value) => unawaited(filterController.setDouyuSuspectedAutomated(value: value)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// One managed list's section: the entries as removable rows, an inline
/// add row under them and the destructive clear behind a confirm.
final class _ShieldList extends ConsumerWidget {
  const _ShieldList({
    required this.icon,
    required this.title,
    required this.entries,
    required this.fieldHint,
    required this.emptyText,
    required this.onAdd,
    required this.onRemove,
    required this.onClear,
  });

  /// The list's icon (a keyword's funnel, a user's person).
  final DsIconData icon;

  /// The section header's words.
  final String title;

  /// The entries, in stored order.
  final List<String> entries;

  /// The add field's placeholder.
  final String fieldHint;

  /// What an empty list says.
  final String emptyText;

  /// Adds an entry; answers false when it is empty or a duplicate.
  final Future<bool> Function(String value) onAdd;

  /// Removes one entry.
  final Future<void> Function(String value) onRemove;

  /// Drops every entry.
  final Future<void> Function() onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    return DsListSection(
      header: Text(title),
      children: [
        if (entries.isEmpty) DsListRow(leading: DsIcon(icon), title: Text(emptyText)),
        for (final entry in entries)
          DsListRow(
            leading: DsIcon(icon),
            title: Text(entry),
            trailing: _RemoveButton(onPressed: () => unawaited(_remove(context, ref, entry))),
          ),
        ShieldAddField(
          fieldHint: fieldHint,
          onAdd: onAdd,
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s8, DsSpace.s20, DsSpace.s8),
        ),
        if (entries.isNotEmpty)
          DsListRow(
            leading: const DsIcon(DsIcons.delete),
            title: Text(t.shield.clear),
            destructive: true,
            onPressed: () => unawaited(_clear(context, ref)),
          ),
      ],
    );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, String value) async {
    await onRemove(value);
    if (!context.mounted) return;
    showDsToast(context: context, title: context.t.shield.removed);
  }

  Future<void> _clear(BuildContext context, WidgetRef ref) async {
    final t = context.t;
    final confirmed = await showDsConfirm(
      context: context,
      title: t.shield.clear,
      description: t.shield.clearConfirmDesc,
      confirmLabel: t.common.confirm,
      destructive: true,
    );
    if (!confirmed) return;
    await onClear();
    if (!context.mounted) return;
    showDsToast(context: context, title: t.shield.cleared);
  }
}

/// The x at a list entry's end: an icon button that removes the entry.
final class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.onPressed});

  /// Fired when the button is pressed.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DsButton.icon(
      variant: DsButtonVariant.ghost,
      onPressed: onPressed,
      icon: const DsIcon(DsIcons.close),
      semanticLabel: context.t.shield.removeEntry,
    );
  }
}
