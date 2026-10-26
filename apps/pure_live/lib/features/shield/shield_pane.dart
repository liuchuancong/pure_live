import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/features/settings/danmaku_repeat_provider.dart'
    show danmakuRepeatProvider, kDanmakuRepeatWindowMax, kDanmakuRepeatWindowMin;
import 'package:pure_live/features/settings/settings_widgets.dart' show SettingsConfigRow;
import 'package:pure_live/features/shield/danmaku_filter_settings.dart';
import 'package:pure_live/features/shield/shield_repository.dart';
import 'package:pure_live/l10n/translations.dart';

/// The danmaku filter's settings pane (the reference's video → danmaku
/// filter page): the shield's master switch and its two managed lists —
/// blocked keywords and blocked users — plus the similar-text filter and
/// its threshold, cache window and cache size. Every rule applies in the
/// live room's danmaku pipeline through the settings providers.
final class ShieldPane extends ConsumerWidget {
  /// The pane.
  const ShieldPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final rules = ref.watch(shieldRulesProvider);
    final filter = ref.watch(danmakuFilterProvider);
    final filterController = ref.read(danmakuFilterProvider.notifier);
    final repeat = ref.watch(danmakuRepeatProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(t.shield.masterTitle),
          children: [
            DsSwitch(
              value: rules.enabled,
              onChanged: (value) => unawaited(ref.read(shieldRulesProvider.notifier).setEnabled(value: value)),
              label: Text(t.shield.enabled),
              description: Text(t.shield.enabledDescription),
            ),
            Padding(
              padding: const EdgeInsets.all(DsSpace.s12),
              child: Text(t.shield.effectNote, style: theme.typography.small.copyWith(color: colors.textSubtle)),
            ),
          ],
        ),
        DsListSection(
          header: Text(t.shield.similarityTitle),
          children: [
            DsSwitch(
              value: filter.similarityEnabled,
              onChanged: (value) => unawaited(filterController.setSimilarityEnabled(value: value)),
              label: Text(t.shield.similarityEnabled),
              description: Text(t.shield.similarityEnabledDescription),
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
                      (value / DanmakuFilterRange.maxCacheSizeStep).round() *
                          DanmakuFilterRange.maxCacheSizeStep,
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
            DsSwitch(
              value: repeat.enabled,
              onChanged: (value) => unawaited(ref.read(danmakuRepeatProvider.notifier).setEnabled(value: value)),
              label: Text(t.shield.repeatEnabled),
              description: Text(t.shield.repeatEnabledDescription),
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
            DsSwitch(
              value: filter.blockEmoteOnly,
              onChanged: (value) => unawaited(filterController.setBlockEmoteOnly(value: value)),
              label: Text(t.shield.blockEmoteOnly),
              description: Text(t.shield.blockEmoteOnlyDescription),
            ),
            DsSwitch(
              value: filter.blockLong,
              onChanged: (value) => unawaited(filterController.setBlockLong(value: value)),
              label: Text(t.shield.blockLong),
              description: Text(t.shield.blockLongDescription),
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
                      (value / DanmakuFilterRange.blockLongLengthStep).round() *
                          DanmakuFilterRange.blockLongLengthStep,
                    ),
                  ),
                  semanticLabel: t.shield.blockLongLength,
                ),
              ),
            DsSwitch(
              value: filter.douyuSuspectedAutomated,
              onChanged: (value) => unawaited(filterController.setDouyuSuspectedAutomated(value: value)),
              label: Text(t.shield.douyuSuspected),
              description: Text(t.shield.douyuSuspectedDescription),
            ),
          ],
        ),
        _ShieldList(
          icon: DsIcons.filter,
          title: t.shield.keywordsTitle,
          entries: rules.keywords,
          fieldHint: t.shield.keywordFieldHint,
          emptyText: t.shield.keywordsEmpty,
          onAdd: (value) => ref.read(shieldRulesProvider.notifier).addKeyword(value),
          onRemove: (value) => ref.read(shieldRulesProvider.notifier).removeKeyword(value),
          onClear: () => ref.read(shieldRulesProvider.notifier).clearKeywords(),
        ),
        _ShieldList(
          icon: DsIcons.users,
          title: t.shield.usersTitle,
          entries: rules.users,
          fieldHint: t.shield.userFieldHint,
          emptyText: t.shield.usersEmpty,
          onAdd: (value) => ref.read(shieldRulesProvider.notifier).addUser(value),
          onRemove: (value) => ref.read(shieldRulesProvider.notifier).removeUser(value),
          onClear: () => ref.read(shieldRulesProvider.notifier).clearUsers(),
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
        _ShieldAddField(fieldHint: fieldHint, onAdd: onAdd),
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

/// The inline add row: a text field plus the add button; submitting from
/// the field commits the same way.
final class _ShieldAddField extends ConsumerStatefulWidget {
  const _ShieldAddField({required this.fieldHint, required this.onAdd});

  /// The field's placeholder.
  final String fieldHint;

  /// Adds the entry; answers false when it is empty or a duplicate.
  final Future<bool> Function(String value) onAdd;

  @override
  ConsumerState<_ShieldAddField> createState() => _ShieldAddFieldState();
}

final class _ShieldAddFieldState extends ConsumerState<_ShieldAddField> {
  final TextEditingController _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Padding(
      padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s8, DsSpace.s20, DsSpace.s8),
      child: Row(
        spacing: DsSpace.s8,
        children: [
          Expanded(
            child: DsTextField(
              controller: _field,
              clearable: true,
              placeholder: widget.fieldHint,
              onSubmitted: (value) => unawaited(_commit()),
              semanticLabel: widget.fieldHint,
            ),
          ),
          DsButton(onPressed: () => unawaited(_commit()), child: Text(t.shield.add)),
        ],
      ),
    );
  }

  Future<void> _commit() async {
    final t = context.t;
    final value = _field.text;
    final added = await widget.onAdd(value);
    if (!mounted) return;
    if (value.trim().isEmpty) {
      showDsToast(context: context, title: t.shield.invalidEntry);
      return;
    }
    if (!added) {
      showDsToast(context: context, title: t.shield.duplicateEntry);
      return;
    }
    _field.clear();
    showDsToast(context: context, title: t.shield.added);
  }
}
