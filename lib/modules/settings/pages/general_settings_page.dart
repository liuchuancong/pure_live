import 'dart:io';

import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:stop_watch_timer/stop_watch_timer.dart';

class GeneralSettingsPage extends GetView<SettingsService> {
  const GeneralSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(i18n("general"))),
      body: ListView(
        physics: const PureLiveScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          context.buildGroupTitle(i18n("general")),
          context.buildModernCard([
            if (Platform.isAndroid)
              Obx(() {
                final info = DisplayModeService.info.value;
                final mode = SettingsService.to.app.refreshRateMode;
                final suffix = info == null
                    ? ''
                    : ' · ${info.currentRefreshRate.toStringAsFixed(0)} / ${info.maxRefreshRate.toStringAsFixed(0)} Hz';
                return context.buildTile(
                  title: i18n('refresh_rate_mode'),
                  subtitle: '${_refreshRateModeLabel(mode)} · ${_refreshRateModeDescription(mode)}$suffix',
                  icon: Remix.speed_up_line,
                  isLong: true,
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showRefreshRateModeDialog(context),
                );
              }),
            if (Platform.isWindows)
              Obx(() {
                final info = DisplayModeService.info.value;
                final mode = info == null
                    ? i18n('display_mode_detecting')
                    : '${info.width} × ${info.height} · '
                          '${info.currentRefreshRate.toStringAsFixed(0)} Hz '
                          '(${i18n('display_mode_max')} ${info.maxRefreshRate.toStringAsFixed(0)} Hz)';
                return context.buildTile(
                  title: i18n('windows_dynamic_refresh_rate'),
                  subtitle: '${i18n('windows_dynamic_refresh_rate_subtitle')}\n$mode',
                  icon: Remix.speed_up_line,
                  isLong: true,
                  trailing: const Icon(Icons.refresh_rounded),
                  onTap: () => DisplayModeService.refreshInfo(),
                );
              }),
            if (Platform.isWindows)
              context.buildSwitchTile(
                title: i18n('open_new_window'),
                subtitle: i18n("open_new_window_subtitle"),
                value: SettingsService.to.app.enableNewWindowPlay,
                icon: Icons.add_to_photos_outlined,
              ),
            context.buildSwitchTile(
              title: i18n('splash_animation'),
              subtitle: i18n("splash_animation_subtitle"),
              value: SettingsService.to.app.showSplashPage,
              icon: Remix.rocket_2_line,
            ),
            context.buildSwitchTile(
              title: i18n('enable_auto_check_update'),
              subtitle: "",
              value: SettingsService.to.app.enableAutoCheckUpdate,
              icon: Remix.refresh_line,
            ),
            context.buildSwitchTile(
              title: i18n('use_github_origin_for_updates'),
              subtitle: i18n('use_github_origin_for_updates_desc'),
              value: SettingsService.to.app.useGitHubOriginForUpdates,
              icon: Remix.github_line,
              isLong: true,
            ),
            context.buildSwitchTile(
              title: i18n('enable_countdown_close'),
              subtitle: i18n('enable_countdown_close_subtitle'),
              value: SettingsService.to.exit.enableAutoShutDownTime,
              icon: Remix.timer_line,
            ),
            Obx(() {
              final bool isEnabled = SettingsService.to.exit.enableAutoShutDownTime.v;
              final int configMinutes = SettingsService.to.exit.autoShutDownTime.v;

              return StreamBuilder<int>(
                key: ValueKey('${isEnabled}_$configMinutes'),
                stream: SettingsService.to.exit.stopWatchTimer.rawTime,
                builder: (context, snapshot) {
                  final int value = snapshot.data ?? 0;
                  String subtitleText = "";

                  if (!isEnabled || value == 0) {
                    subtitleText = "$configMinutes ${i18n('minutes')}";
                  } else {
                    final displayTime = StopWatchTimer.getDisplayTime(value, hours: true, milliSecond: false);
                    subtitleText = "${i18n('remaining_time')}: $displayTime";
                  }

                  return context.buildTile(
                    iconWidget: AnimatedTimerIcon(enabled: isEnabled, remainingMs: value, totalMinutes: configMinutes),

                    title: i18n('countdown_duration'),
                    subtitle: subtitleText,
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _showCountdownDurationDialog(context),
                  );
                },
              );
            }),

            if (Platform.isWindows) ...[
              context.buildSwitchTile(
                title: i18n("startup"),
                subtitle: "",
                value: SettingsService.to.startup.enableStartUp,
                icon: Remix.windows_line,
              ),
              context.buildTile(
                icon: Remix.aspect_ratio_line,
                title: i18n("window_size"),
                subtitle:
                    "${SettingsService.to.window.storedWidth.v.toInt()} × ${SettingsService.to.window.storedHeight.v.toInt()}",
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showWindowSizeDialog(context),
              ),
              context.buildSwitchTile(
                title: i18n("no_exit_confirm"),
                subtitle: "",
                value: SettingsService.to.exit.dontAskExit,
                icon: Remix.error_warning_line,
              ),
            ],
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _refreshRateModeLabel(AppRefreshRateMode mode) {
    return switch (mode) {
      AppRefreshRateMode.powerSaving => i18n('refresh_rate_power_saving'),
      AppRefreshRateMode.balanced => i18n('refresh_rate_balanced'),
      AppRefreshRateMode.performance => i18n('refresh_rate_performance'),
    };
  }

  String _refreshRateModeDescription(AppRefreshRateMode mode) {
    return switch (mode) {
      AppRefreshRateMode.powerSaving => i18n('refresh_rate_power_saving_desc'),
      AppRefreshRateMode.balanced => i18n('refresh_rate_balanced_desc'),
      AppRefreshRateMode.performance => i18n('refresh_rate_performance_desc'),
    };
  }

  String _refreshRateEnergyLabel(AppRefreshRateMode mode) {
    return switch (mode) {
      AppRefreshRateMode.powerSaving => i18n('refresh_rate_energy_low'),
      AppRefreshRateMode.balanced => i18n('refresh_rate_energy_medium'),
      AppRefreshRateMode.performance => i18n('refresh_rate_energy_high'),
    };
  }

  void _showRefreshRateModeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(i18n('refresh_rate_mode')),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
            child: Text(i18n('refresh_rate_mode_hint'), style: Theme.of(dialogContext).textTheme.bodySmall),
          ),
          Obx(
            () => RadioGroup<AppRefreshRateMode>(
              groupValue: SettingsService.to.app.refreshRateMode,
              onChanged: (mode) {
                if (mode == null) return;
                SettingsService.to.app.setRefreshRateMode(mode);
                Navigator.pop(dialogContext);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: AppRefreshRateMode.values
                    .map(
                      (mode) => RadioListTile<AppRefreshRateMode>(
                        value: mode,
                        title: Row(
                          children: [
                            Expanded(child: Text(_refreshRateModeLabel(mode))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Theme.of(dialogContext).colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _refreshRateEnergyLabel(mode),
                                style: Theme.of(dialogContext).textTheme.labelSmall,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(_refreshRateModeDescription(mode)),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showWindowSizeDialog(BuildContext context) {
    final widthController = TextEditingController(text: SettingsService.to.window.storedWidth.v.toInt().toString());
    final heightController = TextEditingController(text: SettingsService.to.window.storedHeight.v.toInt().toString());

    final presets = [
      {'name': '1080 × 720 (默认)', 'w': 1080.0, 'h': 720.0},
      {'name': '1280 × 720 (720P)', 'w': 1280.0, 'h': 720.0},
      {'name': '1600 × 900', 'w': 1600.0, 'h': 900.0},
      {'name': '1920 × 1080 (1080P)', 'w': 1920.0, 'h': 1080.0},
      {'name': '2560 × 1440 (2K)', 'w': 2560.0, 'h': 1440.0},
    ];

    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: Text(i18n("window_size")),
          content: SizedBox(
            width: 320,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(i18n("preset_options"), style: AppTextStyles.t13.copyWith(color: theme.hintColor)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: presets.map((preset) {
                      return ActionChip(
                        label: Text(preset['name'] as String),
                        onPressed: () {
                          widthController.text = (preset['w'] as double).toInt().toString();
                          heightController.text = (preset['h'] as double).toInt().toString();
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Text(i18n("custom_input"), style: AppTextStyles.t13.copyWith(color: theme.hintColor)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: widthController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: i18n("width"),
                            hintText: "1080",
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text("×", style: AppTextStyles.t18),
                      ),
                      Expanded(
                        child: TextField(
                          controller: heightController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: i18n("height"),
                            hintText: "720",
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(i18n("cancel"))),
            TextButton(
              onPressed: () async {
                final double? w = double.tryParse(widthController.text);
                final double? h = double.tryParse(heightController.text);
                if (w != null && h != null && w > 0 && h > 0) {
                  SettingsService.to.window.storedWidth.v = w;
                  SettingsService.to.window.storedHeight.v = h;
                  SettingsService.to.window.updateSize(Size(w, h));
                  await Future.microtask(() async {
                    await windowManager.setSize(Size(w, h), animate: true);
                    await windowManager.center();
                    SettingsService.to.window.setTracking(true);
                  });

                  Navigator.pop(Get.context!);
                  ToastUtil.show(i18n("save_success"));
                } else {
                  ToastUtil.show(i18n("invalid_input"));
                }
              },
              child: Text(
                i18n("confirm"),
                style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    ).whenComplete(() {
      widthController.dispose();
      heightController.dispose();
    });
  }

  void _showCountdownDurationDialog(BuildContext context) {
    final List<int> minutesOptions = [15, 30, 45, 60, 90, 120, 180];
    final int currentValue = SettingsService.to.exit.autoShutDownTime.v;
    final bool isCustom = !minutesOptions.contains(currentValue);

    final TextEditingController inputController = TextEditingController(text: isCustom ? currentValue.toString() : "");

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(i18n('select_countdown_duration')),
          content: Container(
            constraints: const BoxConstraints(maxWidth: 360),
            width: MediaQuery.of(context).size.width,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(i18n('app_exit_timer_explain'), style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 12),
                  Obx(() {
                    final selectedValue = SettingsService.to.exit.autoShutDownTime.v;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: minutesOptions.map<Widget>((minutes) {
                        final bool isSelected = selectedValue == minutes;
                        return ChoiceChip(
                          label: Text("$minutes ${i18n('minutes')}"),
                          selected: isSelected,
                          selectedColor: Theme.of(context).colorScheme.primaryContainer,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurface,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (bool selected) {
                            if (selected) {
                              SettingsService.to.exit.updateShutDownTime(minutes);
                              Navigator.of(context).pop();
                            }
                          },
                        );
                      }).toList(),
                    );
                  }),
                  const SizedBox(height: 20),
                  TextField(
                    controller: inputController,
                    keyboardType: TextInputType.number,
                    style: AppTextStyles.t14,
                    maxLines: 1,
                    decoration: InputDecoration(
                      labelText: i18n('custom_duration'),
                      suffixText: i18n('minutes'),
                      helperText: i18n('app_exit_timer_custom_hint'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(i18n('cancel'))),
            FilledButton(
              onPressed: () {
                final parsedValue = int.tryParse(inputController.text.trim());
                if (parsedValue == null || parsedValue < 1) {
                  ToastUtil.show(i18n('app_exit_timer_custom_hint'));
                  return;
                }
                SettingsService.to.exit.updateShutDownTime(parsedValue);
                Navigator.of(context).pop();
              },
              child: Text(i18n('save')),
            ),
          ],
        );
      },
    ).whenComplete(inputController.dispose);
  }
}

class AnimatedTimerIcon extends StatelessWidget {
  final bool enabled;
  final int remainingMs;
  final int totalMinutes;

  const AnimatedTimerIcon({super.key, required this.enabled, required this.remainingMs, required this.totalMinutes});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = theme.colorScheme.primary;

    double turns = 0.0;
    if (enabled && totalMinutes > 0 && remainingMs > 0) {
      final double totalMs = totalMinutes * 60 * 1000;
      final double passedMs = totalMs - remainingMs;
      turns = (passedMs / (60 * 1000)) * 60.0;
    }

    return SizedBox(
      width: 22,
      height: 22,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: iconColor, width: 2),
            ),
          ),
          RotationTransition(
            turns: AlwaysStoppedAnimation(turns),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 2,
                  height: 7,
                  decoration: BoxDecoration(color: iconColor, borderRadius: BorderRadius.circular(1)),
                ),
                const SizedBox(height: 7),
              ],
            ),
          ),
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }
}
