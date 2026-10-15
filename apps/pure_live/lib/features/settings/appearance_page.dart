import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_platform/live_platform.dart' show PlatformKind, PlatformRuntimeInfo;
import 'package:live_shell/live_shell.dart' show CloseAction, CommandStartupRegistration;
import 'package:live_uikit/styling.dart';

import 'package:pure_live/app/appearance_mapping.dart';
import 'package:pure_live/app/providers.dart';
import 'package:pure_live/storage/services.dart';
import 'package:pure_live/user_data/preferences/preferences.dart' show DesktopPreferences, Preferences;

/// The appearance editor: every [UiConfig] choice, persisted through
/// [AppServices.preferences]. The root `LiveConfigProvider` watches the same
/// stream, so one change here re-skins the whole app at once.
class AppearancePage extends ConsumerWidget {
  /// The appearance editor.
  const new({super.key});

  void _apply(AppServices services, UiConfig config) =>
      unawaited(services.preferences.updateAppearance((_) => appearanceFromUiConfig(config)));

  /// Persists one desktop-shell choice.
  ///
  /// Everything else in this page only writes, because the widgets reading the
  /// value live in this process. `launchAtLogin` is the exception: its effect is
  /// on the next sign-in, from outside the process, so writing the preference
  /// alone would leave a checkbox that lies. Registration failures are not
  /// rolled back — the entry is then absent and the next toggle retries, which is
  /// the same thing a user does anyway when a system setting refuses to take.
  void _applyDesktop(AppServices services, DesktopPreferences Function(DesktopPreferences) change) {
    final before = services.preferences.value.desktop;
    final after = change(before);
    unawaited(services.preferences.updateDesktop(change));
    if (after.launchAtLogin != before.launchAtLogin ||
        (after.launchAtLogin && after.startHidden != before.startHidden)) {
      unawaited(_syncLaunchAtLogin(services, after));
    }
  }

  Future<void> _syncLaunchAtLogin(AppServices services, DesktopPreferences preferences) async {
    await CommandStartupRegistration(
      platform: _platform,
      executablePath: Platform.resolvedExecutable,
      registryValueName: 'PureLive',
      displayName: 'Pure Live',
      // A sign-in launch that shows a window over whatever the viewer was doing
      // is the complaint this setting exists to avoid, so "start hidden" travels
      // with the entry rather than being remembered by nothing.
      arguments: preferences.startHidden ? const ['--hidden'] : const [],
    ).setLaunchAtLogin(enabled: preferences.launchAtLogin, hidden: preferences.startHidden);
  }

  static PlatformKind get _platform => PlatformRuntimeInfo.inferKind();

  static bool get _hasDesktop =>
      _platform == PlatformKind.windows || _platform == PlatformKind.macos || _platform == PlatformKind.linux;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(appServicesProvider);
    return StreamBuilder<Preferences>(
      stream: services.preferences.changes,
      initialData: services.preferences.value,
      builder: (context, snapshot) {
        final theme = LiveTheme.of(context);
        final config = uiConfigFromAppearance(snapshot.data!.appearance);
        final desktop = snapshot.data!.desktop;
        return Scaffold(
          backgroundColor: theme.colors.bgLayout,
          appBar: AppBar(
            title: const Text('外观'),
            backgroundColor: theme.colors.bgContainer,
            foregroundColor: theme.colors.text,
          ),
          body: ListView(
            padding: EdgeInsets.all(theme.card.padding),
            children: [
              _SettingsSection(
                title: '设计语言',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final language in LiveDesignLanguage.values)
                      LiveButton(
                        label: language.name,
                        variant: config.language == language ? ButtonVariant.primary : ButtonVariant.secondary,
                        onPressed: () => _apply(services, config.copyWith(language: language)),
                      ),
                  ],
                ),
              ),
              _SettingsSection(
                title: '明暗',
                child: LiveSegmented(
                  labels: const ['跟随', '浅色', '深色'],
                  index: switch (config.brightness) {
                    UiBrightnessMode.system => 0,
                    UiBrightnessMode.light => 1,
                    UiBrightnessMode.dark => 2,
                  },
                  onChanged: (i) => _apply(
                    services,
                    config.copyWith(
                      brightness: const [UiBrightnessMode.system, UiBrightnessMode.light, UiBrightnessMode.dark][i],
                    ),
                  ),
                ),
              ),
              _SettingsSection(
                title: '密度',
                child: LiveSegmented(
                  labels: const ['紧凑', '标准', '宽松'],
                  index: switch (config.density) {
                    UiDensity.compact => 0,
                    UiDensity.comfortable => 1,
                    UiDensity.spacious => 2,
                  },
                  onChanged: (i) => _apply(
                    services,
                    config.copyWith(density: const [UiDensity.compact, UiDensity.comfortable, UiDensity.spacious][i]),
                  ),
                ),
              ),
              _SettingsSection(
                title: '字号',
                child: LiveSlider(
                  value: config.fontScale,
                  min: 0.8,
                  max: 1.6,
                  onChanged: (v) => _apply(services, config.copyWith(fontScale: v)),
                ),
              ),
              _SettingsSection(
                title: '透明度',
                child: LiveSlider(
                  value: config.transparency,
                  onChanged: (v) => _apply(services, config.copyWith(transparency: v)),
                ),
              ),
              _SettingsSection(
                title: '强调色',
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final accent in _accentSwatches)
                      _Swatch(
                        color: accent,
                        selected: accent == config.accent || (accent != null && accent == config.accent),
                        onTap: () => _apply(services, config.copyWith(accent: accent)),
                      ),
                  ],
                ),
              ),
              _SettingsSection(
                title: '选项',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ToggleRow(
                      label: '纯黑背景（OLED）',
                      value: config.pureBlack,
                      onChanged: (v) => _apply(services, config.copyWith(pureBlack: v)),
                    ),
                    _ToggleRow(
                      label: '降低透明度',
                      value: config.reduceTransparency,
                      onChanged: (v) => _apply(services, config.copyWith(reduceTransparency: v)),
                    ),
                    _ToggleRow(
                      label: '动画',
                      value: config.animations,
                      onChanged: (v) => _apply(services, config.copyWith(animations: v)),
                    ),
                    _ToggleRow(
                      label: '焦点描边',
                      value: config.focusOutline,
                      onChanged: (v) => _apply(services, config.copyWith(focusOutline: v)),
                    ),
                  ],
                ),
              ),
              if (_hasDesktop)
                _SettingsSection(
                  title: '桌面',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SettingsLabel(label: '关闭按钮的行为'),
                      LiveSegmented(
                        labels: const ['隐藏到托盘', '最小化', '退出'],
                        index: switch (desktop.closeAction) {
                          CloseAction.hideToTray => 0,
                          CloseAction.minimise => 1,
                          CloseAction.quit => 2,
                        },
                        onChanged: (i) => _applyDesktop(
                          services,
                          (p) => p.copyWith(
                            closeAction: const [CloseAction.hideToTray, CloseAction.minimise, CloseAction.quit][i],
                          ),
                        ),
                      ),
                      _ToggleRow(
                        label: '托盘图标',
                        value: desktop.showTrayIcon,
                        onChanged: (v) => _applyDesktop(services, (p) => p.copyWith(showTrayIcon: v)),
                      ),
                      _ToggleRow(
                        label: '记住窗口位置',
                        value: desktop.rememberWindowBounds,
                        onChanged: (v) => _applyDesktop(services, (p) => p.copyWith(rememberWindowBounds: v)),
                      ),
                      _ToggleRow(
                        label: '启动时不显示窗口',
                        value: desktop.startHidden,
                        onChanged: (v) => _applyDesktop(services, (p) => p.copyWith(startHidden: v)),
                      ),
                      _ToggleRow(
                        label: '登录时自动启动',
                        value: desktop.launchAtLogin,
                        onChanged: (v) => _applyDesktop(services, (p) => p.copyWith(launchAtLogin: v)),
                      ),
                      _ToggleRow(
                        label: '空闲时释放界面内存',
                        value: desktop.reclaimWhenIdle,
                        onChanged: (v) => _applyDesktop(services, (p) => p.copyWith(reclaimWhenIdle: v)),
                      ),
                      if (desktop.reclaimWhenIdle) ...[
                        const _SettingsLabel(label: '多久无操作后释放'),
                        LiveSegmented(
                          labels: const ['5 分钟', '15 分钟', '30 分钟', '1 小时'],
                          index: _reclaimChoices.indexOf(desktop.idleReclaimAfter).clamp(0, _reclaimChoices.length - 1),
                          onChanged: (i) =>
                              _applyDesktop(services, (p) => p.copyWith(idleReclaimAfter: _reclaimChoices[i])),
                        ),
                      ],
                      // The two escape hatches, labelled as such: neither is a taste
                      // and one of them cannot take effect until the next start, which
                      // has to be said here or the user concludes the switch is broken.
                      const _SettingsLabel(label: '显示异常时的开关'),
                      _ToggleRow(
                        label: '半透明窗口效果（圆角发黑或留残影时可关）',
                        value: desktop.effects,
                        onChanged: (v) => _applyDesktop(services, (p) => p.copyWith(effects: v)),
                      ),
                      _ToggleRow(
                        label: '显卡绘制（画面错乱时可关，下次启动生效）',
                        value: desktop.hardwareAcceleration,
                        onChanged: (v) => _applyDesktop(services, (p) => p.copyWith(hardwareAcceleration: v)),
                      ),
                      _ToggleRow(
                        label: '允许系统通知',
                        value: desktop.systemNotifications,
                        onChanged: (v) => _applyDesktop(services, (p) => p.copyWith(systemNotifications: v)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The threshold choices offered, in the order the segmented control shows them.
const List<Duration> _reclaimChoices = [
  Duration(minutes: 5),
  Duration(minutes: 15),
  Duration(minutes: 30),
  Duration(hours: 1),
];

/// The accent choices: the first (null) means "no override, keep the seed".
const List<Color?> _accentSwatches = <Color?>[
  null,
  Color(0xFF1677FF),
  Color(0xFF722ED1),
  Color(0xFF52C41A),
  Color(0xFFFA8C16),
  Color(0xFFEB2F96),
];

class _SettingsSection extends StatelessWidget {
  const new({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: theme.card.padding),
      child: LiveCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.text.title.copyWith(color: theme.colors.text)),
            SizedBox(height: theme.card.padding * 0.5),
            child,
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const new({required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: theme.token.scale.sizes.sm),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.text.body)),
          LiveSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// A heading for a run of related controls inside one [_SettingsSection].
class _SettingsLabel extends StatelessWidget {
  const new({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    return Padding(
      padding: EdgeInsets.only(top: theme.card.padding * 0.5, bottom: theme.card.padding * 0.25),
      child: Text(label, style: theme.text.body),
    );
  }
}

class _Swatch extends StatelessWidget {
  const new({required this.color, required this.selected, required this.onTap});

  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color ?? theme.colors.bgContainer,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? theme.colors.text : theme.colors.border,
            width: selected ? theme.token.motion.lineWidthBold : theme.token.motion.lineWidth,
          ),
        ),
        // The "no override" swatch shows a slash so it reads as a choice, not a blank.
        child: color == null
            ? Center(
                child: Text('Ø', style: theme.text.caption.copyWith(color: theme.colors.text)),
              )
            : null,
      ),
    );
  }
}
