import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/features/settings/settings.dart'
    show SettingsConfigRow, danmakuRepeatProvider, kDanmakuRepeatWindowMax, kDanmakuRepeatWindowMin;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/shield/danmaku_filter_settings.dart';
import 'package:pure_live/modules/live/shield/room_shield_count.dart';
import 'package:pure_live/modules/live/shield/shield_entry_wall.dart';
import 'package:pure_live/modules/live/shield/shield_repository.dart';

/// The shield inside the room's chat column: a status card over an accordion.
/// The card answers, in one glance, whether the shield is on and what it has
/// hidden this visit; each rule group below folds into one summary row — how
/// many words, which rules on — and opens only the group being edited. The
/// column is narrow, and the old wall of seven cards made every rule a
/// scroll away from every other; the folds keep the whole map on one screen.
///
/// Every edit lands in the settings providers, so the settings page and the
/// pipeline both see it at once; the groups share the entry wall the settings
/// page's sections draw, so a keyword added here reads the same there.
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
    final masterOn = rules.enabled;
    // The content group's count: a rule is on when its switch is, and the two
    // level floors count as on once they name a level at all — "0 级" is the
    // off state the slider itself offers.
    const contentTotal = 6;
    final contentOn = [
      filter.blockEmoteOnly,
      filter.blockLong,
      filter.douyuSuspectedAutomated,
      filter.coloredOnly,
      filter.minUserLevel > 0,
      filter.minFansLevel > 0,
    ].where((on) => on).length;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(DsSpace.s16, DsSpace.s12, DsSpace.s16, DsSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s12,
        children: [
          _ShieldStatusCard(
            enabled: masterOn,
            hidden: hidden,
            onChanged: (value) => unawaited(rulesController.setEnabled(value: value)),
          ),
          // One accordion, one group open at a time — the settings pane's own
          // one-group-a-time pace, kept so an open fold never pushes the
          // others off the column.
          DsAccordion<String>(
            semanticLabel: t.shield.title,
            items: [
              DsAccordionItem(
                value: 'keywords',
                title: _ShieldGroupHeader(
                  icon: DsIcons.filter,
                  title: t.shield.keywordsTitle,
                  summary: masterOn ? t.shield.entriesCount(count: rules.keywords.length) : t.shield.paused,
                  lit: masterOn,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ShieldEntryWall(
                      entries: rules.keywords,
                      fieldHint: t.shield.keywordFieldHint,
                      acceptsPatterns: true,
                      onAdd: rulesController.addKeyword,
                      hasRoom: () async => ref.read(shieldRulesProvider.notifier).keywordsHaveRoom,
                      onRemove: rulesController.removeKeyword,
                      onClear: rulesController.clearKeywords,
                    ),
                    if (rules.keywords.isEmpty) _ShieldEmptyLine(text: t.shield.keywordsEmpty),
                  ],
                ),
              ),
              DsAccordionItem(
                value: 'users',
                title: _ShieldGroupHeader(
                  icon: DsIcons.users,
                  title: t.shield.usersTitle,
                  summary: masterOn ? t.shield.usersCount(count: rules.users.length) : t.shield.paused,
                  lit: masterOn,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ShieldEntryWall(
                      entries: rules.users,
                      fieldHint: t.shield.userFieldHint,
                      onAdd: rulesController.addUser,
                      hasRoom: () async => ref.read(shieldRulesProvider.notifier).usersHaveRoom,
                      onRemove: rulesController.removeUser,
                      onClear: rulesController.clearUsers,
                    ),
                    if (rules.users.isEmpty) _ShieldEmptyLine(text: t.shield.usersEmpty),
                  ],
                ),
              ),
              DsAccordionItem(
                value: 'content',
                title: _ShieldGroupHeader(
                  icon: DsIcons.fileText,
                  title: t.shield.contentTitle,
                  summary: masterOn ? t.shield.rulesEnabled(enabled: contentOn, total: contentTotal) : t.shield.paused,
                  lit: masterOn && contentOn > 0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
              ),
              DsAccordionItem(
                value: 'similarity',
                title: _ShieldGroupHeader(
                  icon: DsIcons.scanText,
                  title: t.shield.similarityTitle,
                  summary: !masterOn
                      ? t.shield.paused
                      : !filter.similarityEnabled
                      ? t.shield.levelOff
                      : '${filter.similarityThreshold}% · ${t.shield.similaritySeconds(seconds: '${filter.similarityCacheSeconds}')}',
                  lit: masterOn && filter.similarityEnabled,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
              ),
              DsAccordionItem(
                value: 'repeat',
                title: _ShieldGroupHeader(
                  icon: DsIcons.repeat,
                  title: t.shield.repeatTitle,
                  summary: !masterOn
                      ? t.shield.paused
                      : !repeat.enabled
                      ? t.shield.levelOff
                      : t.shield.similaritySeconds(seconds: '${repeat.windowSeconds}'),
                  lit: masterOn && repeat.enabled,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The shield's own card: the master switch on the title line, and under it
/// the visit's number — what the viewer's rules hid while they watched, the
/// count the folds under it explain. Off, the number gives way to the one
/// sentence that says what an off shield means.
final class _ShieldStatusCard extends StatelessWidget {
  const _ShieldStatusCard({required this.enabled, required this.hidden, required this.onChanged});

  final bool enabled;
  final int hidden;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final number = theme.typography.numeric(theme.typography.display.copyWith(color: colors.text, height: 1.1));
    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: DsSpace.s12,
        children: [
          Row(
            spacing: DsSpace.s8,
            children: [
              DsIcon(DsIcons.shield, size: 18, color: enabled ? colors.accent : colors.textSubtle),
              Expanded(child: Text(t.shield.title, style: theme.typography.heading.copyWith(color: colors.text))),
              DsSwitch(value: enabled, onChanged: onChanged),
            ],
          ),
          if (enabled)
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              spacing: DsSpace.s8,
              children: [
                Text('$hidden', style: number),
                Text(t.shield.blockedLabel, style: theme.typography.caption.copyWith(color: colors.textMuted)),
              ],
            )
          else
            Text(t.shield.enabledDescription, style: theme.typography.small.copyWith(color: colors.textMuted)),
        ],
      ),
    );
  }
}

/// One folded group's line: the group's glyph and name, and at its end the
/// state — a summary word ("12 条", "2/6 项") and the dot that carries on/off
/// without reading. The accordion draws the chevron after this row.
final class _ShieldGroupHeader extends StatelessWidget {
  const _ShieldGroupHeader({required this.icon, required this.title, required this.summary, required this.lit});

  final DsIconData icon;
  final String title;
  final String summary;

  /// Whether the group's rules are in force — the dot's answer.
  final bool lit;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return Row(
      spacing: DsSpace.s8,
      children: [
        DsIcon(icon, size: 16, color: colors.textSubtle),
        Expanded(child: Text(title)),
        Text(summary, style: theme.typography.caption.copyWith(color: colors.textMuted)),
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: lit ? colors.status(DsStatus.success).signal : colors.border,
          ),
        ),
      ],
    );
  }
}

/// An empty group's word, under the field that fills it — the same sentence
/// the settings page's section carries, at the fold's own measure.
final class _ShieldEmptyLine extends StatelessWidget {
  const _ShieldEmptyLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s4, DsSpace.s3, DsSpace.s4, DsSpace.s12),
      child: Text(text, style: theme.typography.caption.copyWith(color: colors.textMuted)),
    );
  }
}
