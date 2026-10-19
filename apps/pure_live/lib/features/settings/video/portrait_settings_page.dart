import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/preferences/app_preferences.dart';
import 'package:pure_live/app/preferences/app_preferences_providers.dart';
import 'package:pure_live/features/settings/widgets/settings_chooser.dart';
import 'package:pure_live/features/settings/widgets/settings_chrome.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_settings_ui/pure_settings_ui.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// Writes the picked answer of a chooser row onto the stored preferences.
typedef _ApplyFn<T> = AppPreferences Function(AppPreferences preferences, T picked);

/// The portrait-stream adaptation page (the reference's `SettingsSubpage.portrait`
/// — 竖屏直播适配): the shape a vertical source gets on the normal page, the
/// direction and canvas a fullscreen entry takes over it, the barrage bound
/// for its picture, and the room-override memory the whole group reads.
///
/// Every answer is decided in `portrait_rules.dart` and consumed by the phone
/// room layout and the controller's presentation entry — detection off leaves
/// every stream in the plain stack, the layout mode picks the sheet shape,
/// the policy picks the direction, the display mode picks the canvas, and the
/// barrage rule bounds the flying band without touching the global style.
final class PortraitSettingsPage extends ConsumerWidget {
  /// The portrait adaptation settings.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final preferences = ref.watch(appPreferencesProvider);
    final update = ref.read(appPreferencesProvider.notifier).update;
    return SettingsChrome(
      title: t.settings.portraitLiveSettings,
      body: SettingsList(
        sections: [
          SettingsSection(
            title: Text(t.settings.portraitGroupDetect),
            tiles: [
              SettingsTile.switchTile(
                key: const ValueKey('portrait-detect'),
                leading: const Icon(Icons.screen_lock_rotation_outlined),
                title: Text(t.settings.portraitDetect),
                description: Text(t.settings.portraitDetectDesc),
                initialValue: preferences.portraitAdapt,
                onToggle: (value) => unawaited(update((p) => p.copyWith(portraitAdapt: value))),
              ),
              SettingsTile.switchTile(
                key: const ValueKey('portrait-height'),
                leading: const Icon(Icons.swap_vert_outlined),
                title: Text(t.settings.portraitAdaptiveHeight),
                description: Text(t.settings.portraitAdaptiveHeightDesc),
                initialValue: preferences.portraitAdaptiveHeight,
                enabled: preferences.portraitAdapt,
                onToggle: (value) => unawaited(update((p) => p.copyWith(portraitAdaptiveHeight: value))),
              ),
              SettingsTile.navigation(
                key: const ValueKey('portrait-layout-mode'),
                leading: const Icon(Icons.view_quilt_outlined),
                title: Text(t.settings.portraitLayoutMode),
                description: Text(t.settings.portraitLayoutModeDesc),
                value: Text(_layoutName(context, preferences.portraitLayoutMode)),
                enabled: preferences.portraitAdapt,
                onPressed: (tileContext) => unawaited(
                  _choose<String>(
                    tileContext,
                    ref,
                    title: t.settings.portraitLayoutMode,
                    current: preferences.portraitLayoutMode,
                    options: [
                      ('balanced', t.settings.portraitLayoutBalanced),
                      ('immersive', t.settings.portraitLayoutImmersive),
                      ('compatibility', t.settings.portraitLayoutCompatibility),
                    ],
                    apply: (p, picked) => p.copyWith(portraitLayoutMode: picked),
                  ),
                ),
              ),
            ],
          ),
          SettingsSection(
            title: Text(t.settings.portraitGroupPresentation),
            tiles: [
              SettingsTile.navigation(
                key: const ValueKey('portrait-fullscreen-policy'),
                leading: const Icon(Icons.screen_rotation_outlined),
                title: Text(t.settings.portraitFullscreenPolicy),
                description: Text(t.settings.portraitFullscreenPolicyDesc),
                value: Text(_policyName(context, preferences.portraitFullscreenPolicy)),
                onPressed: (tileContext) => unawaited(
                  _choose<String>(
                    tileContext,
                    ref,
                    title: t.settings.portraitFullscreenPolicy,
                    current: preferences.portraitFullscreenPolicy,
                    options: [
                      ('followSource', t.settings.portraitFollowSource),
                      ('followSystem', t.settings.portraitFollowSystem),
                      ('landscape', t.settings.portraitAlwaysLandscape),
                    ],
                    apply: (p, picked) => p.copyWith(portraitFullscreenPolicy: picked),
                  ),
                ),
              ),
              SettingsTile.navigation(
                key: const ValueKey('portrait-display-mode'),
                leading: const Icon(Icons.wallpaper_outlined),
                title: Text(t.settings.portraitDisplayMode),
                description: Text(t.settings.portraitDisplayModeDesc),
                value: Text(_displayName(context, preferences.portraitDisplayMode)),
                onPressed: (tileContext) => unawaited(
                  _choose<String>(
                    tileContext,
                    ref,
                    title: t.settings.portraitDisplayMode,
                    current: preferences.portraitDisplayMode,
                    options: [
                      ('complete', t.settings.portraitDisplayComplete),
                      ('ambient', t.settings.portraitDisplayAmbient),
                      ('balanced', t.settings.portraitDisplayBalanced),
                      ('cover', t.settings.portraitDisplayCover),
                    ],
                    apply: (p, picked) => p.copyWith(portraitDisplayMode: picked),
                  ),
                ),
              ),
              SettingsTile.navigation(
                key: const ValueKey('portrait-danmaku-mode'),
                leading: const Icon(Icons.subtitles_outlined),
                title: Text(t.settings.portraitDanmakuMode),
                description: Text(t.settings.portraitDanmakuModeDesc),
                value: Text(_danmakuName(context, preferences.portraitDanmakuMode)),
                onPressed: (tileContext) => unawaited(
                  _choose<String>(
                    tileContext,
                    ref,
                    title: t.settings.portraitDanmakuMode,
                    current: preferences.portraitDanmakuMode,
                    options: [
                      ('followGlobal', t.settings.portraitDanmakuFollowGlobal),
                      ('upperQuarter', t.settings.portraitDanmakuUpperQuarter),
                      ('reduced', t.settings.portraitDanmakuReduced),
                      ('hidden', t.settings.portraitDanmakuHidden),
                    ],
                    apply: (p, picked) => p.copyWith(portraitDanmakuMode: picked),
                  ),
                ),
              ),
              SettingsTile.switchTile(
                key: const ValueKey('portrait-remember'),
                leading: const Icon(Icons.bookmark_added_outlined),
                title: Text(t.settings.portraitRemember),
                description: Text(t.settings.portraitRememberDesc),
                initialValue: preferences.rememberPortraitRoomOverride,
                onToggle: (value) => unawaited(update((p) => p.copyWith(rememberPortraitRoomOverride: value))),
              ),
            ],
          ),
          SettingsSection(
            title: Text(t.settings.portraitGroupDiagnostics),
            tiles: [
              SettingsTile.switchTile(
                key: const ValueKey('portrait-diagnostics'),
                leading: const Icon(Icons.science_outlined),
                title: Text(t.settings.portraitDiagnostics),
                description: Text(t.settings.portraitDiagnosticsDesc),
                initialValue: preferences.showPortraitDiagnostics,
                onToggle: (value) => unawaited(update((p) => p.copyWith(showPortraitDiagnostics: value))),
              ),
              SettingsTile(
                key: const ValueKey('portrait-reset'),
                leading: const Icon(Icons.restore_outlined),
                title: Text(t.settings.portraitReset),
                description: Text(t.settings.portraitResetDesc),
                onPressed: (tileContext) => unawaited(_reset(tileContext, ref)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Future<void> _choose<T>(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required T current,
    required List<(T, String)> options,
    required _ApplyFn<T> apply,
  }) async {
    final picked = await showSettingsChooser<T>(context, ref, title: title, current: current, options: options);
    if (picked != null) {
      await ref.read(appPreferencesProvider.notifier).update((p) => apply(p, picked));
    }
  }

  /// 恢复竖屏适配默认设置: the group's own defaults, overrides included — a
  /// remembered room is part of what this page handed out.
  static Future<void> _reset(BuildContext context, WidgetRef ref) async {
    final t = context.t;
    final confirmed = await showPureDialog<bool>(
      context: context,
      title: t.settings.portraitReset,
      child: Text(t.settings.portraitResetConfirm),
      actions: (dialogContext) => [
        PureButton(
          label: dialogContext.t.common.cancel,
          variant: ButtonVariant.ghost,
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
        PureButton(label: dialogContext.t.common.confirm, onPressed: () => Navigator.of(dialogContext).pop(true)),
      ],
    );
    if (confirmed == true) {
      await ref
          .read(appPreferencesProvider.notifier)
          .update(
            (p) => p.copyWith(
              portraitAdapt: true,
              portraitAdaptiveHeight: true,
              portraitLayoutMode: 'balanced',
              portraitFullscreenPolicy: 'followSource',
              portraitDisplayMode: 'ambient',
              portraitDanmakuMode: 'followGlobal',
              rememberPortraitRoomOverride: true,
              showPortraitDiagnostics: false,
              portraitRoomOverrides: const <String, String>{},
            ),
          );
    }
  }

  static String _layoutName(BuildContext context, String mode) => switch (mode) {
    'immersive' => context.t.settings.portraitLayoutImmersive,
    'compatibility' => context.t.settings.portraitLayoutCompatibility,
    _ => context.t.settings.portraitLayoutBalanced,
  };

  static String _policyName(BuildContext context, String policy) => switch (policy) {
    'followSystem' => context.t.settings.portraitFollowSystem,
    'landscape' => context.t.settings.portraitAlwaysLandscape,
    _ => context.t.settings.portraitFollowSource,
  };

  static String _displayName(BuildContext context, String mode) => switch (mode) {
    'complete' => context.t.settings.portraitDisplayComplete,
    'balanced' => context.t.settings.portraitDisplayBalanced,
    'cover' => context.t.settings.portraitDisplayCover,
    _ => context.t.settings.portraitDisplayAmbient,
  };

  static String _danmakuName(BuildContext context, String mode) => switch (mode) {
    'upperQuarter' => context.t.settings.portraitDanmakuUpperQuarter,
    'reduced' => context.t.settings.portraitDanmakuReduced,
    'hidden' => context.t.settings.portraitDanmakuHidden,
    _ => context.t.settings.portraitDanmakuFollowGlobal,
  };
}
