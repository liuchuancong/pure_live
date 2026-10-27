import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/features/shield/danmaku_filter_settings.dart';
import 'package:pure_live/features/shield/shield_repository.dart';
import 'package:pure_live/l10n/translations.dart';

/// The shield inside the room's chat column: the same rules the settings
/// page edits, laid out for a narrow pane — the two block lists as
/// removable tags with an inline add field, the content blocks as plain
/// switches (their long descriptions on hover), and the fuzzy filters as
/// one-line slider rows. Every edit lands in the settings providers, so
/// the settings page and the pipeline both see it at once.
final class RoomShieldPanel extends ConsumerWidget {
  /// The panel.
  const RoomShieldPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final rules = ref.watch(shieldRulesProvider);
    final filter = ref.watch(danmakuFilterProvider);
    final filterController = ref.read(danmakuFilterProvider.notifier);
    final repeat = ref.watch(danmakuRepeatProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(DsSpace.s16, DsSpace.s12, DsSpace.s16, DsSpace.s16),
      children: [
        _ShieldSwitch(
          label: t.shield.enabled,
          description: t.shield.enabledDescription,
          value: rules.enabled,
          onChanged: (value) => unawaited(ref.read(shieldRulesProvider.notifier).setEnabled(value: value)),
        ),
        _TagList(
          icon: DsIcons.filter,
          title: t.shield.keywordsTitle,
          entries: rules.keywords,
          emptyText: t.shield.keywordsEmpty,
          fieldHint: t.shield.keywordFieldHint,
          onAdd: (value) => ref.read(shieldRulesProvider.notifier).addKeyword(value),
          onRemove: (value) => ref.read(shieldRulesProvider.notifier).removeKeyword(value),
          onClear: () => ref.read(shieldRulesProvider.notifier).clearKeywords(),
        ),
        _TagList(
          icon: DsIcons.users,
          title: t.shield.usersTitle,
          entries: rules.users,
          emptyText: t.shield.usersEmpty,
          fieldHint: t.shield.userFieldHint,
          onAdd: (value) => ref.read(shieldRulesProvider.notifier).addUser(value),
          onRemove: (value) => ref.read(shieldRulesProvider.notifier).removeUser(value),
          onClear: () => ref.read(shieldRulesProvider.notifier).clearUsers(),
        ),
        _ShieldHeader(title: t.shield.contentTitle),
        _ShieldSwitch(
          label: t.shield.blockEmoteOnly,
          description: t.shield.blockEmoteOnlyDescription,
          value: filter.blockEmoteOnly,
          onChanged: (value) => unawaited(filterController.setBlockEmoteOnly(value: value)),
        ),
        _ShieldSwitch(
          label: t.shield.blockLong,
          description: t.shield.blockLongDescription,
          value: filter.blockLong,
          onChanged: (value) => unawaited(filterController.setBlockLong(value: value)),
        ),
        if (filter.blockLong)
          _SliderRow(
            title: t.shield.blockLongLength,
            current: filter.blockLongLength.toDouble(),
            value: '${filter.blockLongLength}',
            min: DanmakuFilterRange.blockLongLengthMin.toDouble(),
            max: DanmakuFilterRange.blockLongLengthMax.toDouble(),
            divisions: (DanmakuFilterRange.blockLongLengthMax - DanmakuFilterRange.blockLongLengthMin) ~/
                DanmakuFilterRange.blockLongLengthStep,
            semanticLabel: t.shield.blockLongLength,
            onChanged: (value) => unawaited(
              filterController.setBlockLongLength(
                (value / DanmakuFilterRange.blockLongLengthStep).round() * DanmakuFilterRange.blockLongLengthStep,
              ),
            ),
          ),
        _ShieldSwitch(
          label: t.shield.douyuSuspected,
          description: t.shield.douyuSuspectedDescription,
          value: filter.douyuSuspectedAutomated,
          onChanged: (value) => unawaited(filterController.setDouyuSuspectedAutomated(value: value)),
        ),
        _ShieldHeader(title: t.shield.similarityTitle),
        _ShieldSwitch(
          label: t.shield.similarityEnabled,
          description: t.shield.similarityEnabledDescription,
          value: filter.similarityEnabled,
          onChanged: (value) => unawaited(filterController.setSimilarityEnabled(value: value)),
        ),
        if (filter.similarityEnabled) ...[
          _SliderRow(
            title: t.shield.similarityThreshold,
            current: filter.similarityThreshold.toDouble(),
            value: '${filter.similarityThreshold}%',
            min: DanmakuFilterRange.thresholdMin.toDouble(),
            max: DanmakuFilterRange.thresholdMax.toDouble(),
            divisions: DanmakuFilterRange.thresholdMax - DanmakuFilterRange.thresholdMin,
            semanticLabel: t.shield.similarityThreshold,
            onChanged: (value) => unawaited(filterController.setSimilarityThreshold(value.round())),
          ),
          _SliderRow(
            title: t.shield.similarityCacheDuration,
            current: filter.similarityCacheSeconds.toDouble(),
            value: t.shield.similaritySeconds(seconds: '${filter.similarityCacheSeconds}'),
            min: DanmakuFilterRange.cacheSecondsMin.toDouble(),
            max: DanmakuFilterRange.cacheSecondsMax.toDouble(),
            divisions: DanmakuFilterRange.cacheSecondsMax - DanmakuFilterRange.cacheSecondsMin,
            semanticLabel: t.shield.similarityCacheDuration,
            onChanged: (value) => unawaited(filterController.setSimilarityCacheSeconds(value.round())),
          ),
        ],
        _ShieldHeader(title: t.shield.repeatTitle),
        _ShieldSwitch(
          label: t.shield.repeatEnabled,
          description: t.shield.repeatEnabledDescription,
          value: repeat.enabled,
          onChanged: (value) => unawaited(ref.read(danmakuRepeatProvider.notifier).setEnabled(value: value)),
        ),
        if (repeat.enabled)
          _SliderRow(
            title: t.shield.repeatWindow,
            current: repeat.windowSeconds.toDouble(),
            value: t.shield.similaritySeconds(seconds: '${repeat.windowSeconds}'),
            min: kDanmakuRepeatWindowMin.toDouble(),
            max: kDanmakuRepeatWindowMax.toDouble(),
            divisions: kDanmakuRepeatWindowMax - kDanmakuRepeatWindowMin,
            semanticLabel: t.shield.repeatWindow,
            onChanged: (value) =>
                unawaited(ref.read(danmakuRepeatProvider.notifier).setWindowSeconds(value.round())),
          ),
      ],
    );
  }
}

/// A section's title line: the icon, the words and the entry count.
final class _ShieldHeader extends StatelessWidget {
  const _ShieldHeader({required this.title, this.icon, this.count = 0, this.trailing});

  final String title;

  /// The section's icon, when it leads the title.
  final DsIconData? icon;

  final int count;

  /// An action at the line's end (the lists' clear).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: DsSpace.s16, bottom: DsSpace.s6),
      child: Row(
        spacing: DsSpace.s6,
        children: [
          if (icon != null) DsIcon(icon!, size: theme.sizes.iconXs, color: colors.textSubtle),
          Expanded(
            child: Text(
              count > 0 ? '$title ($count)' : title,
              style: theme.typography.labelStrong.copyWith(color: colors.textMuted),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// One switch row: the label carries the description on hover, so the
/// narrow column keeps one line per rule.
final class _ShieldSwitch extends StatelessWidget {
  const _ShieldSwitch({
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    return DsSwitch(
      value: value,
      onChanged: onChanged,
      label: DsTooltip(message: description, child: Text(label, style: theme.typography.body.copyWith(color: colors.text))),
    );
  }
}

/// One slider row: title, the narrow track and the shown value on one line.
final class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.title,
    required this.current,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    required this.semanticLabel,
  });

  final String title;

  /// The stored choice the track shows.
  final double current;
  final String value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: DsSpace.s4, bottom: DsSpace.s4),
      child: Row(
        spacing: DsSpace.s8,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.caption.copyWith(color: colors.textMuted),
            ),
          ),
          Expanded(
            flex: 3,
            child: DsSlider(
              value: current.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
              semanticLabel: semanticLabel,
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.typography.numeric(theme.typography.caption.copyWith(color: colors.textSubtle)),
            ),
          ),
        ],
      ),
    );
  }
}

/// One block list: the entries as removable tags over an inline add field,
/// with the clear action on the header once there is something to clear.
final class _TagList extends ConsumerWidget {
  const _TagList({
    required this.icon,
    required this.title,
    required this.entries,
    required this.emptyText,
    required this.fieldHint,
    required this.onAdd,
    required this.onRemove,
    required this.onClear,
  });

  final DsIconData icon;
  final String title;
  final List<String> entries;
  final String emptyText;
  final String fieldHint;
  final Future<bool> Function(String value) onAdd;
  final Future<void> Function(String value) onRemove;
  final Future<void> Function() onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ShieldHeader(
          icon: icon,
          title: title,
          count: entries.length,
          trailing: entries.isEmpty
              ? null
              : DsButton.icon(
                  variant: DsButtonVariant.ghost,
                  size: DsSize.xs,
                  icon: const DsIcon(DsIcons.delete),
                  semanticLabel: t.shield.clear,
                  onPressed: () => unawaited(_clear(context)),
                ),
        ),
        if (entries.isEmpty)
          Text(emptyText, style: theme.typography.caption.copyWith(color: colors.textSubtle))
        else
          Wrap(
            spacing: DsSpace.s6,
            runSpacing: DsSpace.s6,
            children: [
              for (final entry in entries)
                _ShieldTag(
                  label: entry,
                  onRemove: () async {
                    await onRemove(entry);
                    if (!context.mounted) return;
                    showDsToast(context: context, title: t.shield.removed);
                  },
                ),
            ],
          ),
        _ShieldAddField(fieldHint: fieldHint, onAdd: onAdd),
      ],
    );
  }

  Future<void> _clear(BuildContext context) async {
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

/// One removable tag: the entry in a pill, the x inside at the end.
final class _ShieldTag extends StatelessWidget {
  const _ShieldTag({required this.label, required this.onRemove});

  final String label;
  final Future<void> Function() onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.only(start: DsSpace.s12, end: DsSpace.s4, top: DsSpace.s3, bottom: DsSpace.s3),
      decoration: BoxDecoration(
        color: colors.control,
        borderRadius: BorderRadius.circular(DsRadii.pill),
        border: Border.fromBorderSide(BorderSide(color: colors.border)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: DsSpace.s4,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.caption.copyWith(color: colors.text),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => unawaited(onRemove()),
            child: Padding(
              padding: const EdgeInsets.all(DsSpace.s3),
              child: DsIcon(DsIcons.close, size: theme.sizes.iconXs, color: colors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// The inline add row: a pill field plus the add button; submitting from
/// the field commits the same way.
final class _ShieldAddField extends ConsumerStatefulWidget {
  const _ShieldAddField({required this.fieldHint, required this.onAdd});

  final String fieldHint;
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
    final theme = DsTheme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: DsSpace.s8),
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
              style: DsTextFieldStyle(height: theme.sizes.sm),
            ),
          ),
          DsButton(size: DsSize.sm, onPressed: () => unawaited(_commit()), child: Text(t.shield.add)),
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
