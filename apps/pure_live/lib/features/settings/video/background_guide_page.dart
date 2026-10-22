import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/features/settings/video/background_guide.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// "后台播放设置": what this phone's system does to an app playing in the
/// background, read where Android lets an app read it, and a row per switch
/// that has to be set — tapping one opens the system page (the app's details
/// where the vendor's page is missing).
///
/// The read happens again whenever the app comes back from a system page, so
/// the states follow what the viewer just changed.
final class BackgroundGuidePage extends ConsumerStatefulWidget {
  /// The page.
  const new({super.key});

  @override
  ConsumerState<BackgroundGuidePage> createState() => _BackgroundGuidePageState();
}

final class _BackgroundGuidePageState extends ConsumerState<BackgroundGuidePage> {
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
        PureToast.show(context, context.t.settings.backgroundGuideOpenFailed, type: PureToastType.warning);
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
    final theme = PureTheme.of(context);
    final status = ref.watch(backgroundStatusProvider);
    return PureScaffold(
      appBar: PureAppBar(title: t.settings.backgroundGuide),
      body: status.when(
        loading: () => const Center(child: PureSpinner()),
        error: (_, _) => PureEmpty(title: t.settings.backgroundGuideUnavailable, icon: Icons.battery_alert_outlined),
        data: (value) => value == null
            ? PureEmpty(title: t.settings.backgroundGuideUnavailable, icon: Icons.battery_alert_outlined)
            : ListView(
                key: const ValueKey('background-guide-scroll'),
                padding: const EdgeInsets.all(12),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          PureCard(
                            padding: EdgeInsets.zero,
                            child: PureListRow(
                              key: const ValueKey('background-guide-device'),
                              leading: Icon(Icons.smartphone_outlined, color: theme.colors.primary),
                              title: _device(value),
                              subtitle: _system(value),
                              divided: false,
                            ),
                          ),
                          if (value.powerSave) ...[
                            const SizedBox(height: 8),
                            _note(theme, t.settings.backgroundGuidePowerSave),
                          ],
                          const SizedBox(height: 8),
                          PureCard(
                            padding: EdgeInsets.zero,
                            child: Column(
                              key: const ValueKey('background-guide-steps'),
                              children: _rows(context, value, theme),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  List<Widget> _rows(BuildContext context, BackgroundStatus status, PureTheme theme) {
    final t = context.t;
    final steps = guideSteps(status);
    final manualNoteAt = steps.indexWhere((step) => step.check == GuideCheck.manual);
    final rows = <Widget>[];
    for (var index = 0; index < steps.length; index++) {
      final step = steps[index];
      if (index == manualNoteAt) {
        rows.add(_note(theme, t.settings.backgroundGuideManualNote(rom: status.rom.romLabel), padded: true));
      }
      final (title, how) = _texts(context, step.id);
      rows.add(
        PureListRow(
          key: ValueKey('background-guide-${step.id.name}'),
          leading: Icon(_icon(step.id), color: theme.colors.primary),
          title: title,
          subtitle: how,
          trailing: Text(
            switch (step.check) {
              GuideCheck.ok => t.settings.backgroundGuideStateOk,
              GuideCheck.todo => t.settings.backgroundGuideStateTodo,
              GuideCheck.manual => t.settings.backgroundGuideStateManual,
            },
            style: theme.text.caption.copyWith(
              color: switch (step.check) {
                GuideCheck.ok => theme.colors.primary,
                GuideCheck.todo => theme.colors.error,
                GuideCheck.manual => theme.colors.textSecondary,
              },
            ),
          ),
          onTap: step.action == GuideAction.none ? null : () => unawaited(_open(step)),
          divided: index < steps.length - 1,
        ),
      );
    }
    return rows;
  }

  Widget _note(PureTheme theme, String text, {bool padded = false}) => Padding(
    padding: EdgeInsets.fromLTRB(padded ? 16 : 4, 8, padded ? 16 : 4, padded ? 12 : 0),
    child: Text(text, style: theme.text.caption.copyWith(color: theme.colors.textSecondary)),
  );

  static String _device(BackgroundStatus status) {
    final name = [status.rom.manufacturer, status.rom.model].where((part) => part.isNotEmpty).join(' ');
    return name.isEmpty ? status.rom.romLabel : name;
  }

  static String _system(BackgroundStatus status) => [
    if (status.rom.romLabel.isNotEmpty) status.rom.romLabel,
    if (status.rom.androidVersion.isNotEmpty) 'Android ${status.rom.androidVersion}',
  ].join(' · ');

  static IconData _icon(GuideStepId id) => switch (id) {
    GuideStepId.notifications => Icons.notifications_active_outlined,
    GuideStepId.battery => Icons.battery_alert_outlined,
    GuideStepId.restricted => Icons.block_outlined,
    GuideStepId.dataSaver => Icons.data_saver_on_outlined,
    GuideStepId.xiaomiAutostart ||
    GuideStepId.oppoAutostart ||
    GuideStepId.vivoAutostart => Icons.rocket_launch_outlined,
    GuideStepId.xiaomiBattery ||
    GuideStepId.oppoBattery ||
    GuideStepId.vivoPower ||
    GuideStepId.samsungBattery => Icons.battery_saver_outlined,
    GuideStepId.huaweiLaunch => Icons.app_settings_alt_outlined,
    GuideStepId.samsungSleeping => Icons.bedtime_outlined,
    GuideStepId.meizuBackground => Icons.settings_applications_outlined,
    GuideStepId.lockRecents => Icons.lock_outline,
  };

  static (String, String) _texts(BuildContext context, GuideStepId id) {
    final t = context.t.settings;
    return switch (id) {
      GuideStepId.notifications => (t.backgroundGuideNotifications, t.backgroundGuideNotificationsHow),
      GuideStepId.battery => (t.backgroundGuideBattery, t.backgroundGuideBatteryHow),
      GuideStepId.restricted => (t.backgroundGuideRestricted, t.backgroundGuideRestrictedHow),
      GuideStepId.dataSaver => (t.backgroundGuideDataSaver, t.backgroundGuideDataSaverHow),
      GuideStepId.xiaomiAutostart => (t.backgroundGuideXiaomiAutostart, t.backgroundGuideXiaomiAutostartHow),
      GuideStepId.oppoAutostart => (t.backgroundGuideOppoAutostart, t.backgroundGuideOppoAutostartHow),
      GuideStepId.vivoAutostart => (t.backgroundGuideVivoAutostart, t.backgroundGuideVivoAutostartHow),
      GuideStepId.xiaomiBattery => (t.backgroundGuideXiaomiBattery, t.backgroundGuideXiaomiBatteryHow),
      GuideStepId.oppoBattery => (t.backgroundGuideOppoBattery, t.backgroundGuideOppoBatteryHow),
      GuideStepId.vivoPower => (t.backgroundGuideVivoPower, t.backgroundGuideVivoPowerHow),
      GuideStepId.huaweiLaunch => (t.backgroundGuideHuaweiLaunch, t.backgroundGuideHuaweiLaunchHow),
      GuideStepId.samsungBattery => (t.backgroundGuideSamsungBattery, t.backgroundGuideSamsungBatteryHow),
      GuideStepId.samsungSleeping => (t.backgroundGuideSamsungSleeping, t.backgroundGuideSamsungSleepingHow),
      GuideStepId.meizuBackground => (t.backgroundGuideMeizuBackground, t.backgroundGuideMeizuBackgroundHow),
      GuideStepId.lockRecents => (t.backgroundGuideLockRecents, t.backgroundGuideLockRecentsHow),
    };
  }
}
