import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/features/settings/settings.dart'
    show SettingsConfigRow, danmakuRepeatProvider, kDanmakuRepeatWindowMax, kDanmakuRepeatWindowMin;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/shield/danmaku_filter_settings.dart';
import 'package:pure_live/modules/live/shield/room_shield_count.dart';
import 'package:pure_live/modules/live/shield/shield_entry_list.dart';
import 'package:pure_live/modules/live/shield/shield_repository.dart';

/// The shield inside the room's chat column: the same rules the settings
/// page edits, drawn as the same cards laid out for the column's width —
/// one section per rule group, one [SettingsConfigRow] per rule. The column
/// is narrow enough that a slider drops under its label and a description
/// reads under its title, so nothing here depends on a pointer; where the
/// line can still spare it, the slider rides beside its label as on the
/// settings page.
///
/// Every edit lands in the settings providers, so the settings page and the
/// pipeline both see it at once.
final class RoomShieldPanel extends ConsumerWidget {
  /// The panel.
  const RoomShieldPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final rules = ref.watch(shieldRulesProvider);
    final rulesController = ref.read(shieldRulesProvider.notifier);
    final filter = ref.watch(danmakuFilterProvider);
    final filterController = ref.read(danmakuFilterProvider.notifier);
    final repeat = ref.watch(danmakuRepeatProvider);
    final repeatController = ref.read(danmakuRepeatProvider.notifier);
    final hidden = ref.watch(roomShieldCountProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(DsSpace.s16, DsSpace.s12, DsSpace.s16, DsSpace.s16),
      // One gutter between the cards; the sections carry their own rhythm
      // inside, so the column never reads as a wall of bare switches.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s16,
        children: [
          // The room's own number comes first, so the rules under it read as
          // the reason it moved.
          _ShieldSessionCount(count: hidden),
          // The master switch governs every group, so it stays above them
          // rather than inside one.
          DsListSection(
            header: Text(t.shield.masterTitle),
            children: [
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.shield),
                title: t.shield.enabled,
                description: t.shield.enabledDescription,
                control: DsSwitch(
                  value: rules.enabled,
                  onChanged: (value) => unawaited(rulesController.setEnabled(value: value)),
                ),
              ),
            ],
          ),
          ShieldEntryList(
            icon: DsIcons.filter,
            title: t.shield.keywordsTitle,
            entries: rules.keywords,
            emptyText: t.shield.keywordsEmpty,
            fieldHint: t.shield.keywordFieldHint,
            acceptsPatterns: true,
            onAdd: rulesController.addKeyword,
            onRemove: rulesController.removeKeyword,
            onClear: rulesController.clearKeywords,
          ),
          ShieldEntryList(
            icon: DsIcons.users,
            title: t.shield.usersTitle,
            entries: rules.users,
            emptyText: t.shield.usersEmpty,
            fieldHint: t.shield.userFieldHint,
            onAdd: rulesController.addUser,
            onRemove: rulesController.removeUser,
            onClear: rulesController.clearUsers,
          ),
          // The rules that judge a line's own words.
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
                        (value / DanmakuFilterRange.blockLongLengthStep).round() *
                            DanmakuFilterRange.blockLongLengthStep,
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
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.palette),
                title: t.shield.coloredOnly,
                description: t.shield.coloredOnlyDescription,
                control: DsSwitch(
                  value: filter.coloredOnly,
                  onChanged: (value) => unawaited(filterController.setColoredOnly(value: value)),
                ),
              ),
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.users),
                title: t.shield.minUserLevel,
                description: t.shield.minUserLevelDescription,
                detail: Text(
                  filter.minUserLevel == 0 ? t.shield.levelOff : t.shield.levelValue(count: filter.minUserLevel),
                ),
                controlWidth: 220,
                control: DsSlider(
                  value: filter.minUserLevel.toDouble(),
                  max: DanmakuFilterRange.levelMax.toDouble(),
                  divisions: DanmakuFilterRange.levelMax,
                  onChanged: (value) => unawaited(filterController.setMinUserLevel(value.round())),
                  semanticLabel: t.shield.minUserLevel,
                ),
              ),
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.users),
                title: t.shield.minFansLevel,
                description: t.shield.minFansLevelDescription,
                detail: Text(
                  filter.minFansLevel == 0 ? t.shield.levelOff : t.shield.levelValue(count: filter.minFansLevel),
                ),
                controlWidth: 220,
                control: DsSlider(
                  value: filter.minFansLevel.toDouble(),
                  max: DanmakuFilterRange.levelMax.toDouble(),
                  divisions: DanmakuFilterRange.levelMax,
                  onChanged: (value) => unawaited(filterController.setMinFansLevel(value.round())),
                  semanticLabel: t.shield.minFansLevel,
                ),
              ),
            ],
          ),
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
                  onChanged: (value) => unawaited(repeatController.setEnabled(value: value)),
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
                    onChanged: (value) => unawaited(repeatController.setWindowSeconds(value.round())),
                    semanticLabel: t.shield.repeatWindow,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 「本场已屏蔽 N 条」: what the viewer's own shield hid during this
/// visit — a blocked name or word, an emoticon-only line, one over the length
/// limit. A duplicate or a collapsed repeat is not in it, or the line would
/// measure the room rather than the shield.
///
/// Counted and never stored: the next room starts at zero, because the number
/// answers a question about what was just watched.
final class _ShieldSessionCount extends StatelessWidget {
  const _ShieldSessionCount({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    return Text(
      context.t.shield.blockedThisStream(count: count),
      style: theme.typography.numeric(theme.typography.caption.copyWith(color: colors.textSubtle)),
    );
  }
}
