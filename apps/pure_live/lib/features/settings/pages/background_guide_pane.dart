import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/features/settings/pages/background_guide.dart';
import 'package:pure_live/l10n/translations.dart';

/// 「后台播放引导」: what this phone's system does to an app playing in the
/// background, read where Android lets an app read it, and a row per switch
/// that has to be set — tapping one opens the system page (the app's details
/// where the vendor's page is missing).
///
/// The read happens again whenever the app comes back from a system page, so
/// the states follow what the viewer just changed. Off Android the pane says
/// there is nothing to guide.
final class BackgroundGuidePane extends ConsumerStatefulWidget {
  /// The pane.
  const BackgroundGuidePane({super.key});

  @override
  ConsumerState<BackgroundGuidePane> createState() => _BackgroundGuidePaneState();
}

final class _BackgroundGuidePaneState extends ConsumerState<BackgroundGuidePane> {
  AppLifecycleListener? _lifecycle;

  /// The step whose system page is opening; a second tap waits.
  GuideStepId? _opening;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () => ref.invalidate(backgroundStatusProvider));
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  Future<void> _open(GuideStep step) async {
    if (_opening != null || step.action == GuideAction.none) {
      return;
    }
    setState(() => _opening = step.id);
    try {
      final opened = await ref.read(backgroundGuideChannelProvider).open(step.pages);
      if (opened < 0 && mounted) {
        showDsToast(context: context, title: context.t.settings.backgroundGuideOpenFailed);
      }
    } finally {
      if (mounted) {
        setState(() => _opening = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final status = ref.watch(backgroundStatusProvider);
    return status.when(
      loading: () => const Center(),
      error: (_, _) => _Unavailable(text: t.settings.backgroundGuideUnavailable),
      data: (value) => value == null
          ? _Unavailable(text: t.settings.backgroundGuideUnavailable)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: DsSpace.s16,
              children: [
                DsListSection(
                  children: [
                    DsListRow(
                      leading: const DsIcon(DsIcons.smartphone),
                      title: Text(_device(value)),
                      description: Text(_system(value)),
                    ),
                  ],
                ),
                if (value.powerSave)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: DsSpace.s4),
                    child: Text(
                      t.settings.backgroundGuidePowerSave,
                      style: DsTheme.of(context).typography.caption.copyWith(color: colors.textMuted),
                    ),
                  ),
                _steps(context, value),
              ],
            ),
    );
  }

  Widget _steps(BuildContext context, BackgroundStatus status) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final steps = guideSteps(status);
    final manualNoteAt = steps.indexWhere((step) => step.check == GuideCheck.manual);
    final rows = <Widget>[];
    for (var index = 0; index < steps.length; index++) {
      final step = steps[index];
      if (index == manualNoteAt) {
        rows.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(DsSpace.s16, DsSpace.s4, DsSpace.s16, DsSpace.s4),
            child: Text(
              t.settings.backgroundGuideManualNote(rom: status.rom.romLabel),
              style: theme.typography.caption.copyWith(color: colors.textMuted),
            ),
          ),
        );
      }
      final (title, how) = _texts(t, step.id);
      rows.add(
        DsListRow(
          leading: DsIcon(
            _icon(step.id),
            color: switch (step.check) {
              GuideCheck.todo => colors.danger.text,
              _ => colors.textMuted,
            },
          ),
          title: Text(title),
          description: Text(how),
          trailing: Text(
            switch (step.check) {
              GuideCheck.ok => t.settings.backgroundGuideStateOk,
              GuideCheck.todo => t.settings.backgroundGuideStateTodo,
              GuideCheck.manual => t.settings.backgroundGuideStateManual,
            },
            style: theme.typography.caption.copyWith(
              color: switch (step.check) {
                GuideCheck.ok => colors.accent,
                GuideCheck.todo => colors.danger.text,
                GuideCheck.manual => colors.textMuted,
              },
            ),
          ),
          onPressed: step.action == GuideAction.none ? null : () => unawaited(_open(step)),
          showChevron: step.action == GuideAction.pages,
        ),
      );
    }
    return DsListSection(children: rows);
  }

  static String _device(BackgroundStatus status) {
    final name = [status.rom.manufacturer, status.rom.model].where((part) => part.isNotEmpty).join(' ');
    return name.isEmpty ? status.rom.romLabel : name;
  }

  static String _system(BackgroundStatus status) => [
    if (status.rom.romLabel.isNotEmpty) status.rom.romLabel,
    if (status.rom.androidVersion.isNotEmpty) 'Android ${status.rom.androidVersion}',
  ].join(' · ');

  static DsIconData _icon(GuideStepId id) => switch (id) {
    GuideStepId.notifications => DsIcons.bell,
    GuideStepId.battery => DsIcons.batteryWarning,
    GuideStepId.restricted => DsIcons.ban,
    GuideStepId.dataSaver => DsIcons.gauge,
    GuideStepId.xiaomiAutostart || GuideStepId.oppoAutostart || GuideStepId.vivoAutostart => DsIcons.rocket,
    GuideStepId.xiaomiBattery ||
    GuideStepId.oppoBattery ||
    GuideStepId.vivoPower ||
    GuideStepId.samsungBattery => DsIcons.batteryCharging,
    GuideStepId.huaweiLaunch => DsIcons.gear,
    GuideStepId.samsungSleeping => DsIcons.bed,
    GuideStepId.meizuBackground => DsIcons.appWindow,
    GuideStepId.lockRecents => DsIcons.lock,
  };

  static (String, String) _texts(Translations t, GuideStepId id) {
    final s = t.settings;
    return switch (id) {
      GuideStepId.notifications => (s.backgroundGuideNotifications, s.backgroundGuideNotificationsHow),
      GuideStepId.battery => (s.backgroundGuideBattery, s.backgroundGuideBatteryHow),
      GuideStepId.restricted => (s.backgroundGuideRestricted, s.backgroundGuideRestrictedHow),
      GuideStepId.dataSaver => (s.backgroundGuideDataSaver, s.backgroundGuideDataSaverHow),
      GuideStepId.xiaomiAutostart => (s.backgroundGuideXiaomiAutostart, s.backgroundGuideXiaomiAutostartHow),
      GuideStepId.oppoAutostart => (s.backgroundGuideOppoAutostart, s.backgroundGuideOppoAutostartHow),
      GuideStepId.vivoAutostart => (s.backgroundGuideVivoAutostart, s.backgroundGuideVivoAutostartHow),
      GuideStepId.xiaomiBattery => (s.backgroundGuideXiaomiBattery, s.backgroundGuideXiaomiBatteryHow),
      GuideStepId.oppoBattery => (s.backgroundGuideOppoBattery, s.backgroundGuideOppoBatteryHow),
      GuideStepId.vivoPower => (s.backgroundGuideVivoPower, s.backgroundGuideVivoPowerHow),
      GuideStepId.huaweiLaunch => (s.backgroundGuideHuaweiLaunch, s.backgroundGuideHuaweiLaunchHow),
      GuideStepId.samsungBattery => (s.backgroundGuideSamsungBattery, s.backgroundGuideSamsungBatteryHow),
      GuideStepId.samsungSleeping => (s.backgroundGuideSamsungSleeping, s.backgroundGuideSamsungSleepingHow),
      GuideStepId.meizuBackground => (s.backgroundGuideMeizuBackground, s.backgroundGuideMeizuBackgroundHow),
      GuideStepId.lockRecents => (s.backgroundGuideLockRecents, s.backgroundGuideLockRecentsHow),
    };
  }
}

/// What a pane with nothing to say shows: not Android, or the native side
/// failed to read.
final class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    return Padding(
      padding: const EdgeInsets.all(DsSpace.s16),
      child: Text(text, style: theme.typography.body.copyWith(color: colors.textMuted)),
    );
  }
}
