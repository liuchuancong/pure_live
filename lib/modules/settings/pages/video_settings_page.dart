import 'package:flutter/foundation.dart';
import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/player/utils/player_consts.dart';
import 'package:pure_live/player/utils/window_helper.dart';
import 'package:pure_live/player/core/live_audio_service.dart';
import 'package:pure_live/modules/settings/pages/font_family_manager_page.dart';
import 'package:pure_live/common/services/settings/app_settings_controller.dart';
import 'package:pure_live/modules/settings/pages/pip_danmaku_settings_page.dart';
import 'package:pure_live/modules/settings/pages/portrait_live_settings_page.dart';
import 'package:pure_live/modules/settings/pages/audience_metric_settings_page.dart';

typedef SleepTimerConfigurator = Future<void> Function({required bool enabled, required int minutes});
typedef SleepPermissionRequester = Future<bool> Function();

class VideoSettingsPage extends StatefulWidget {
  const VideoSettingsPage({
    super.key,
    this.platformOverride,
    this.sleepTimerConfiguratorOverride,
    this.sleepPermissionRequesterOverride,
  });

  @visibleForTesting
  final TargetPlatform? platformOverride;

  @visibleForTesting
  final SleepTimerConfigurator? sleepTimerConfiguratorOverride;

  @visibleForTesting
  final SleepPermissionRequester? sleepPermissionRequesterOverride;

  @override
  State<VideoSettingsPage> createState() => _VideoSettingsPageState();
}

enum _ResolutionPreferenceTarget { wifi, cellular }

class _VideoSettingsPageState extends State<VideoSettingsPage> {
  bool _resolutionDialogBusy = false;
  bool _asmrDialogBusy = false;
  bool _asmrModeBusy = false;
  String? _asmrModeErrorText;

  TargetPlatform get _platform => widget.platformOverride ?? defaultTargetPlatform;
  bool get _isAndroid => _platform == TargetPlatform.android;
  bool get _isWindows => _platform == TargetPlatform.windows;
  bool get _isMobile => _platform == TargetPlatform.android || _platform == TargetPlatform.iOS;
  bool get _isDesktop => !_isMobile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(i18n("video_settings"))),
      body: ListView(
        physics: const PureLiveScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // 音频设置
          context.buildGroupTitle(i18n("audio_settings")),
          context.buildModernCard([
            context.buildSwitchTile(
              title: i18n("global_mute"),
              subtitle: i18n("global_mute_subtitle"),
              value: SettingsService.to.vol.globalVolumeMute,
              icon: SettingsService.to.vol.globalVolumeMute.v ? Remix.volume_mute_line : Remix.volume_up_line,
            ),
            if (_isMobile)
              Obx(
                () => context.buildSliderTile(
                  context,
                  icon: Remix.phone_line,
                  title: i18n("mobile_default_volume"),
                  value: SettingsService.to.vol.defaultMobileVolume.v * 100,
                  min: 0.0,
                  max: 100.0,
                  displayValue: "${(SettingsService.to.vol.defaultMobileVolume.v * 100).toStringAsFixed(0)}%",
                  onChanged: (val) =>
                      SettingsService.to.vol.defaultMobileVolume.v = double.parse((val / 100).toStringAsFixed(2)),
                ),
              ),
            if (_isDesktop)
              Obx(
                () => context.buildSliderTile(
                  context,
                  icon: Remix.computer_line,
                  title: i18n("desktop_default_volume"),
                  value: SettingsService.to.vol.defaultDesktopVolume.v * 100,
                  min: 0.0,
                  max: 100.0,
                  displayValue: "${(SettingsService.to.vol.defaultDesktopVolume.v * 100).toStringAsFixed(0)}%",
                  onChanged: (val) {
                    SettingsService.to.vol.defaultDesktopVolume.v = double.parse((val / 100).toStringAsFixed(2));
                  },
                ),
              ),
          ]),

          const SizedBox(height: 20),

          // 画质设置
          context.buildGroupTitle(i18n("video_quality_settings")),
          context.buildModernCard([
            Obx(
              () => context.buildTile(
                icon: Remix.hd_line,
                title: i18n("prefer_resolution"),
                subtitle: i18n("prefer_resolution_subtitle"),
                onTap: _resolutionDialogBusy
                    ? null
                    : () => _showPreferredResolutionSelectorDialog(_ResolutionPreferenceTarget.wifi),
                trailing: Text(
                  _preferredResolutionLabel(SettingsService.to.player.resolvedPreferResolution),
                  style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                ),
                stackTrailingOnNarrow: true,
              ),
            ),
            Obx(
              () => context.buildTile(
                icon: Remix.signal_tower_line,
                title: i18n("mobile_quality"),
                subtitle: i18n("mobile_quality_subtitle"),
                onTap: _resolutionDialogBusy
                    ? null
                    : () => _showPreferredResolutionSelectorDialog(_ResolutionPreferenceTarget.cellular),
                trailing: Text(
                  _preferredResolutionLabel(SettingsService.to.player.resolvedPreferResolutionCellular),
                  style: AppTextStyles.t13.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                ),
                stackTrailingOnNarrow: true,
              ),
            ),
          ]),

          const SizedBox(height: 20),

          // 播放行为设置
          context.buildGroupTitle(i18n("playback_behavior_settings")),
          context.buildModernCard([
            context.buildTile(
              title: i18n('portrait_live_settings'),
              subtitle: i18n('portrait_live_settings_desc'),
              icon: Icons.stay_current_portrait_rounded,
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Get.to(() => const PortraitLiveSettingsPage()),
            ),
            context.buildTile(
              title: i18n('audience_metric_settings'),
              subtitle: i18n('audience_metric_settings_desc'),
              icon: Icons.groups_2_rounded,
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Get.to(() => const AudienceMetricSettingsPage()),
            ),
            if (_isAndroid)
              context.buildSwitchTile(
                icon: Remix.music_2_line,
                title: i18n("enable_background_play"),
                subtitle: i18n("enable_background_play_subtitle"),
                value: SettingsService.to.app.enableBackgroundPlay,
                onChanged: (val) async {
                  SettingsService.to.app.enableBackgroundPlay.v = val;
                  if (val && _isAndroid) {
                    bool hasPermission = await LiveAudioService.requestPlatformPermissions();
                    SettingsService.to.app.enableBackgroundPlay.v = hasPermission;
                    await LiveAudioService.syncKeepAlive();
                  } else if (!val) {
                    if (!LiveAudioService.isSleepSessionActive) {
                      await LiveAudioService.releaseKeepAlive();
                    }
                  }
                },
              ),
            if (_isAndroid)
              context.buildSwitchTile(
                icon: Remix.moon_clear_line,
                title: i18n('asmr_sleep_mode'),
                subtitle: _asmrModeErrorText ?? i18n('asmr_sleep_mode_desc'),
                subtitleColor: _asmrModeErrorText == null ? null : theme.colorScheme.error,
                isLong: true,
                value: SettingsService.to.app.enableAsmrSleepMode,
                enabled: !_asmrModeBusy,
                autoCommit: false,
                onChanged: _changeAsmrSleepMode,
              ),
            if (_isAndroid)
              Obx(
                () => context.buildTile(
                  icon: Remix.timer_2_line,
                  title: i18n('asmr_sleep_timer'),
                  subtitle: i18n('asmr_sleep_timer_desc'),
                  trailing: Text(
                    _formatAsmrDuration(SettingsService.to.app.asmrSleepMinutes.v),
                    style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                  ),
                  onTap: _asmrDialogBusy ? null : _showAsmrSleepTimerDialog,
                ),
              ),
            context.buildSwitchTile(
              title: i18n("exit_float_window"),
              subtitle: i18n("exit_float_window_subtitle"),
              value: SettingsService.to.player.floatPlay,
              icon: Remix.picture_in_picture_2_line,
            ),
            if (_isWindows)
              context.buildSwitchTile(
                title: i18n('windows_pip_always_on_top'),
                subtitle: i18n('windows_pip_always_on_top_subtitle'),
                value: SettingsService.to.player.windowsPipAlwaysOnTop,
                icon: Remix.pushpin_line,
                onChanged: WindowHelper.instance.setPiPAlwaysOnTop,
              ),
            if (_isWindows)
              context.buildSwitchTile(
                title: i18n('windows_pip_remember_position'),
                subtitle: i18n('windows_pip_remember_position_subtitle'),
                value: SettingsService.to.window.rememberPipPosition,
                icon: Remix.terminal_window_fill,
                onChanged: (value) {
                  SettingsService.to.window.rememberPipPosition.v = value;
                },
              ),
            if (_isWindows) const _WindowsPipResetTile(),

            context.buildSwitchTile(
              title: i18n('enable_fullscreen_default'),
              subtitle: i18n('enable_fullscreen_default_subtitle'),
              value: SettingsService.to.app.enableFullScreenDefault,
              icon: Remix.fullscreen_line,
            ),
            if (_isAndroid)
              context.buildSwitchTile(
                title: i18n('enable_screen_keep_on'),
                subtitle: i18n('enable_screen_keep_on_subtitle'),
                value: SettingsService.to.app.enableScreenKeepOn,
                icon: Remix.lightbulb_line,
              ),
          ]),

          const SizedBox(height: 20),

          // 弹幕设置
          context.buildGroupTitle(i18n("danmaku_settings")),
          context.buildModernCard([
            context.buildSwitchTile(
              title: i18n('show_danmaku'),
              subtitle: i18n('show_danmaku_subtitle'),
              value: SettingsService.to.danmaku.enableDanmakuDisplay,
              icon: Remix.chat_smile_2_line,
            ),
            context.buildTile(
              icon: Remix.picture_in_picture_2_line,
              title: i18n('pip_danmaku'),
              subtitle: i18n('pip_danmaku_desc'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Get.to(() => const PipDanmakuSettingsPage()),
            ),
            Obx(
              () => context.buildTile(
                icon: Remix.font_size,
                title: i18n("change_danmaku_font_family"),
                subtitle: "${i18n("current_font_prefix")}: ${SettingsService.to.danmaku.danmakuFontFamilyName.v}",
                onTap: () => Get.to(() => const FontFamilyManagerPage(isDanmakuSettings: true)),
              ),
            ),

            context.buildTile(
              icon: Remix.filter_2_line,
              title: i18n("danmaku_filter"),
              subtitle: "",
              onTap: () => Get.toNamed(RoutePath.kSettingsDanmuShield),
            ),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _showAsmrSleepTimerDialog() async {
    if (_asmrDialogBusy || !mounted) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    final app = SettingsService.to.app;
    final configureSleepTimer = widget.sleepTimerConfiguratorOverride ?? LiveAudioService.configureSleepTimer;
    setState(() => _asmrDialogBusy = true);
    try {
      await showDialog<void>(
        context: context,
        useRootNavigator: true,
        builder: (_) => _AsmrSleepTimerDialog(
          initialMinutes: app.asmrSleepMinutes.v,
          onSave: (minutes) async {
            if (!mounted || app.isClosed || ModalRoute.of(context)?.isActive != true) return false;
            await configureSleepTimer(enabled: LiveAudioService.isSleepSessionActive, minutes: minutes);
            if (!mounted || app.isClosed || ModalRoute.of(context)?.isActive != true) return false;
            app.asmrSleepMinutes.v = minutes;
            return true;
          },
        ),
      );
    } finally {
      if (mounted) setState(() => _asmrDialogBusy = false);
    }
  }

  Future<void> _changeAsmrSleepMode(bool enabled) async {
    if (_asmrModeBusy || !mounted) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    final app = SettingsService.to.app;
    if (app.isClosed || app.enableAsmrSleepMode.v == enabled) return;
    final requestPermission = widget.sleepPermissionRequesterOverride ?? LiveAudioService.requestPlatformPermissions;
    final configureSleepTimer = widget.sleepTimerConfiguratorOverride ?? LiveAudioService.configureSleepTimer;
    setState(() {
      _asmrModeBusy = true;
      _asmrModeErrorText = null;
    });
    try {
      if (enabled) {
        final granted = await requestPermission();
        if (!_canCommitAsmrMode(app) || !granted) return;
      } else {
        await configureSleepTimer(enabled: false, minutes: app.asmrSleepMinutes.v);
        if (!_canCommitAsmrMode(app)) return;
      }
      app.enableAsmrSleepMode.v = enabled;
    } catch (_) {
      if (_canCommitAsmrMode(app)) {
        setState(() => _asmrModeErrorText = i18n('asmr_sleep_mode_apply_failed'));
      }
    } finally {
      if (mounted) setState(() => _asmrModeBusy = false);
    }
  }

  bool _canCommitAsmrMode(AppSettingsController app) {
    return mounted && !app.isClosed && ModalRoute.of(context)?.isActive == true;
  }

  Future<void> _showPreferredResolutionSelectorDialog(_ResolutionPreferenceTarget target) async {
    if (_resolutionDialogBusy || !mounted) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    final player = SettingsService.to.player;
    final title = i18n(target == _ResolutionPreferenceTarget.wifi ? 'prefer_resolution' : 'prefer_resolution_cellular');
    final selected = target == _ResolutionPreferenceTarget.wifi
        ? player.resolvedPreferResolution
        : player.resolvedPreferResolutionCellular;
    setState(() => _resolutionDialogBusy = true);
    try {
      final result = await showDialog<String>(
        context: context,
        useRootNavigator: true,
        builder: (dialogContext) {
          void select(String value) => Navigator.of(dialogContext, rootNavigator: true).pop(value);

          return AlertDialog(
            key: const ValueKey('resolution-preference-dialog'),
            scrollable: true,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            title: Text(title, style: AppTextStyles.t16Bold),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: RadioGroup<String>(
                groupValue: selected,
                onChanged: (value) {
                  if (value != null) select(value);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: PlayerConsts.resolutions
                      .map(
                        (value) => SimpleDialogOption(
                          onPressed: () => select(value),
                          child: Row(
                            children: [
                              Radio<String>(value: value, activeColor: Theme.of(dialogContext).colorScheme.primary),
                              const SizedBox(width: 4),
                              Expanded(child: Text(_preferredResolutionLabel(value))),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            actionsOverflowDirection: VerticalDirection.down,
            actionsOverflowButtonSpacing: 8,
            actions: [
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () => Navigator.of(dialogContext, rootNavigator: true).pop(),
                child: Text(i18n('cancel'), style: AppTextStyles.t14Muted),
              ),
            ],
          );
        },
      );
      if (result == null || !mounted || player.isClosed || ModalRoute.of(context)?.isCurrent != true) return;
      if (target == _ResolutionPreferenceTarget.wifi) {
        player.changePreferResolution(result);
      } else {
        player.changePreferResolutionCellular(result);
      }
    } finally {
      if (mounted) setState(() => _resolutionDialogBusy = false);
    }
  }

  String _preferredResolutionLabel(String value) {
    final key = PlayerConsts.resolutionLabelKey(value);
    return key == null ? value : i18n(key);
  }
}

class _WindowsPipResetTile extends StatefulWidget {
  const _WindowsPipResetTile();

  @override
  State<_WindowsPipResetTile> createState() => _WindowsPipResetTileState();
}

class _WindowsPipResetTileState extends State<_WindowsPipResetTile> {
  bool _resetBusy = false;

  Future<void> _confirmReset() async {
    if (_resetBusy || !mounted) return;
    final window = SettingsService.to.window;
    setState(() => _resetBusy = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        useRootNavigator: true,
        builder: (dialogContext) => AlertDialog(
          key: const ValueKey('windows-pip-reset-dialog'),
          scrollable: true,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          title: Text(i18n('windows_pip_reset_position'), style: AppTextStyles.t16Bold),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(i18n('windows_pip_reset_position_confirm'), style: AppTextStyles.t14),
          ),
          actionsOverflowDirection: VerticalDirection.down,
          actionsOverflowButtonSpacing: 8,
          actions: [
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => Navigator.of(dialogContext, rootNavigator: true).pop(false),
              child: Text(i18n('cancel'), style: AppTextStyles.t14Muted),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(48, 48),
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
                foregroundColor: Theme.of(dialogContext).colorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext, rootNavigator: true).pop(true),
              child: Text(i18n('reset')),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted || window.isClosed) return;
      window.clearWindowsPipGeometry();
      ToastUtil.show(i18n('windows_pip_reset_position_success'));
    } finally {
      if (mounted) setState(() => _resetBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return context.buildTile(
      icon: Remix.reserved_line,
      title: i18n('windows_pip_reset_position'),
      subtitle: i18n('windows_pip_reset_position_subtitle'),
      onTap: _resetBusy ? null : _confirmReset,
    );
  }
}

class _AsmrSleepTimerDialog extends StatefulWidget {
  const _AsmrSleepTimerDialog({required this.initialMinutes, required this.onSave});

  final int initialMinutes;
  final Future<bool> Function(int minutes) onSave;

  @override
  State<_AsmrSleepTimerDialog> createState() => _AsmrSleepTimerDialogState();
}

class _AsmrSleepTimerDialogState extends State<_AsmrSleepTimerDialog> {
  static const _options = [15, 30, 45, 60, 90, 120, 240, 480, 720, 1440];

  late final TextEditingController _customController;
  bool _saving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _customController = TextEditingController(text: widget.initialMinutes.toString());
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final minutes = int.tryParse(_customController.text.trim());
    if (minutes == null || minutes < 1 || minutes > AppSettingsController.maxSleepMinutes) {
      setState(() => _errorText = i18n('custom_sleep_minutes_range'));
      return;
    }

    setState(() {
      _saving = true;
      _errorText = null;
    });
    try {
      final saved = await widget.onSave(minutes);
      if (!mounted) return;
      if (!saved) {
        setState(() {
          _saving = false;
          _errorText = i18n('asmr_sleep_timer_save_failed');
        });
        return;
      }
      setState(() => _saving = false);
      Navigator.of(context, rootNavigator: true).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorText = i18n('asmr_sleep_timer_save_failed');
      });
    }
  }

  void _setMinutes(int minutes) {
    if (_saving) return;
    setState(() {
      _customController.text = minutes.toString();
      _errorText = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        key: const ValueKey('asmr-sleep-timer-dialog'),
        scrollable: true,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        title: Text(i18n('asmr_sleep_timer'), style: AppTextStyles.t16Bold),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(i18n('asmr_sleep_timer_explain'), style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _options
                    .map(
                      (minutes) => ActionChip(
                        label: Text(_formatAsmrDuration(minutes)),
                        onPressed: _saving ? null : () => _setMinutes(minutes),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _customController,
                enabled: !_saving,
                keyboardType: TextInputType.number,
                onChanged: (_) {
                  if (_errorText != null) setState(() => _errorText = null);
                },
                decoration: InputDecoration(
                  labelText: i18n('custom_sleep_minutes'),
                  helperText: _errorText == null ? i18n('custom_sleep_minutes_range') : null,
                  errorText: _errorText,
                  suffixText: i18n('minutes'),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actionsOverflowDirection: VerticalDirection.down,
        actionsOverflowButtonSpacing: 8,
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: _saving ? null : () => Navigator.of(context, rootNavigator: true).pop(),
            child: Text(i18n('cancel'), style: AppTextStyles.t14Muted),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(i18n('save')),
          ),
        ],
      ),
    );
  }
}

String _formatAsmrDuration(int minutes) {
  if (minutes % 1440 == 0) return '${minutes ~/ 1440} ${i18n('day')}';
  if (minutes % 60 == 0) return '${minutes ~/ 60} ${i18n('hour')}';
  return '$minutes ${i18n('minute')}';
}
