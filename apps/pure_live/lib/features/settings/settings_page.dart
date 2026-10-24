import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/material.dart' show showLicensePage;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_shell/live_shell.dart' show CloseAction;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pure_live/app/bootstrap/pure_live_app.dart' show AppLocaleScope;
import 'package:pure_live/app/navigation/module_navigation.dart';
import 'package:pure_live/app/providers/browse_settings_providers.dart';
import 'package:pure_live/app/providers/module_providers.dart' show selectedModuleProvider;
import 'package:pure_live/app/providers/network_providers.dart' show proxySettingsProvider;
import 'package:pure_live/app/providers/refresh_settings_providers.dart';
import 'package:pure_live/app/providers/settings_section_provider.dart' show settingsSectionProvider;
import 'package:pure_live/app/providers/shell_settings_provider.dart';
import 'package:pure_live/app/providers/sites_providers.dart' show selectedSiteIdProvider, sitesProvider;
import 'package:pure_live/app/routing/app_router.dart' show SettingsSectionRoute;
import 'package:pure_live/app/theme/font_defaults.dart';
import 'package:pure_live/app/theme/theme_persistence.dart';
import 'package:pure_live/app/theme/theme_settings.dart';
import 'package:pure_live/features/account/account_pane.dart' show AccountPane;
import 'package:pure_live/features/backup/backup_pane.dart' show BackupPane;
import 'package:pure_live/features/favorites/follow_repository.dart' show followRepositoryProvider, followsProvider;
import 'package:pure_live/features/history/history_repository.dart' show historyProvider;
import 'package:pure_live/features/settings/danmaku_style_providers.dart';
import 'package:pure_live/features/settings/settings_sections.dart';
import 'package:pure_live/features/settings/sites_display_provider.dart';
import 'package:pure_live/features/shield/shield_pane.dart' show ShieldPane;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/layouts/app_switcher.dart' show AppMark;
import 'package:pure_live/shared/enums/tool_order.dart';
import 'package:pure_live/shared/images/app_image_cache.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode, launchUrl;

/// The settings surface. On a desktop window the shell's own sidebar lists
/// the sections — the same menu the module destinations live in, so
/// entering settings swaps the menu's entries rather than stacking a second
/// menu beside it — and this page is the selected section's pane alone. On
/// a phone, where there is no sidebar, the page is the grouped list whose
/// entries push their section as its own route ([SettingsSectionRoute]).
///
/// Both read and write [settingsSectionProvider]: the sidebar and the list
/// agree on which section is on screen, and the pane is always that one.
final class SettingsPage extends ConsumerWidget {
  /// The settings page.
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compact = MediaQuery.sizeOf(context).width < 768;
    if (compact) return const _SettingsMenuList();
    final section = ref.watch(settingsSectionProvider);
    return SettingsSectionPane(key: ValueKey(section), section: section);
  }
}

/// The mobile menu: the same groups as full-width rows, each pushing its
/// section as a route — the phone's way into a submenu.
final class _SettingsMenuList extends ConsumerWidget {
  const _SettingsMenuList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final rows = <Widget>[];
    // The phone list mirrors the desktop menu: the module's own settings
    // groups, from the one registry.
    for (final group in navigationOf(ref.watch(selectedModuleProvider)).settingsGroups) {
      rows.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s16, DsSpace.s20, DsSpace.s4),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              settingsGroupLabel(t, group.labelKey),
              style: theme.typography.overline.copyWith(color: colors.textSubtle),
            ),
          ),
        ),
      );
      for (final section in group.sections) {
        rows.add(
          DsListRow(
            leading: DsIcon(section.icon),
            title: Text(section.label(t)),
            description: Text(section.description(t)),
            onPressed: () {
              // The pane the route pushes is the provider's section; keeping
              // it in step also carries the last visit over to a desktop
              // window the app may be resized into.
              ref.read(settingsSectionProvider.notifier).section = section;
              unawaited(context.push(SettingsSectionRoute(section: section.name).location));
            },
            trailing: const DsIcon(DsIcons.chevronRight),
          ),
        );
      }
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: DsSpace.s24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
    );
  }
}

/// One section's content pane: the section's name as the pane's headline,
/// its description, then the section's own controls. Desktop shows it
/// beside the menu; the mobile route shows it alone.
final class SettingsSectionPane extends ConsumerWidget {
  /// The pane for [section].
  const SettingsSectionPane({required this.section, super.key});

  /// The section rendered here.
  final SettingsSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final body = switch (section) {
      SettingsSection.general => const _GeneralPane(),
      SettingsSection.appearance => const _AppearancePane(),
      SettingsSection.network => const _NetworkPane(),
      SettingsSection.playback => _ComingSoon(message: t.settings.playbackComingSoon),
      SettingsSection.shield => const _DanmakuPane(),
      SettingsSection.sites => const _SitesPane(),
      SettingsSection.data => const _DataPane(),
      SettingsSection.cache => const _CachePane(),
      SettingsSection.about => const _AboutPane(),
    };
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(DsSpace.s24, DsSpace.s20, DsSpace.s24, DsSpace.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: DsSpace.s4,
        children: [
          Text(section.label(t), style: theme.typography.display.copyWith(color: colors.text)),
          Text(section.description(t), style: theme.typography.body.copyWith(color: colors.textMuted)),
          const SizedBox(height: DsSpace.s12),
          body,
        ],
      ),
    );
  }
}

/// The general pane: the browsing preferences that already work end to
/// end — the site every surface browses, how wide a feed card gets, how
/// many rooms one page asks for — plus the follow list's auto refresh.
final class _GeneralPane extends ConsumerWidget {
  const _GeneralPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final settings = ref.watch(browseSettingsProvider);
    final sites = ref.watch(sitesProvider).all;
    final selectedId = ref.watch(selectedSiteIdProvider);
    final autoRefresh = ref.watch(followsAutoRefreshProvider);
    final window = ref.watch(shellWindowSettingsProvider);

    return DsListSection(
      header: Text(t.settings.browsingTitle),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s8, DsSpace.s20, DsSpace.s8),
          child: DsSelect<String>(
            value: selectedId,
            // The select reports null only when cleared (clearable is
            // off), so a null never reaches the site setter.
            onChanged: (id) {
              if (id != null) ref.read(selectedSiteIdProvider.notifier).selected = id;
            },
            options: [
              for (final site in sites)
                DsSelectOption(value: site.manifest.id, label: site.manifest.name['zh-CN'] ?? site.manifest.id),
            ],
            placeholder: t.settings.site,
            leading: const DsIcon(DsIcons.tv),
            semanticLabel: t.settings.site,
          ),
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.columns2),
          title: Text(t.settings.cardExtent),
          description: Text(t.settings.cardExtentDescription),
          detail: Text('${settings.homeCardExtent.round()} px'),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s8),
          child: DsSlider(
            value: settings.homeCardExtent,
            min: 160,
            max: 420,
            divisions: 26,
            onChanged: (value) => ref.read(browseSettingsProvider.notifier).homeCardExtent = value,
            semanticLabel: t.settings.cardExtent,
          ),
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.list),
          title: Text(t.settings.pageSize),
          description: Text(t.settings.pageSizeDescription),
          detail: Text('${settings.homePageSize}'),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s8),
          child: DsSlider(
            value: settings.homePageSize.toDouble(),
            min: 10,
            max: 90,
            divisions: 16,
            onChanged: (value) => ref.read(browseSettingsProvider.notifier).homePageSize = value.round(),
            semanticLabel: t.settings.pageSize,
          ),
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.heart),
          title: Text(t.settings.followsAutoRefresh),
          description: Text(t.settings.followsAutoRefreshDesc),
          trailing: DsSwitch(
            value: autoRefresh.enabled,
            onChanged: (value) => unawaited(ref.read(followsAutoRefreshProvider.notifier).setEnabled(value: value)),
          ),
        ),
        if (autoRefresh.enabled) ...[
          DsListRow(
            leading: const DsIcon(DsIcons.timer),
            title: Text(t.settings.refreshInterval),
            detail: Text('${autoRefresh.minutes} min'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s8, DsSpace.s20, DsSpace.s8),
            child: DsSelect<int>(
              value: autoRefresh.minutes,
              onChanged: (value) {
                if (value != null) unawaited(ref.read(followsAutoRefreshProvider.notifier).setMinutes(value));
              },
              options: [
                for (final minutes in kRefreshIntervalChoices) DsSelectOption(value: minutes, label: '$minutes min'),
              ],
              semanticLabel: t.settings.refreshInterval,
            ),
          ),
          DsListRow(
            leading: const DsIcon(DsIcons.panelLeftClose),
            title: Text(t.settings.closeAction),
            // The tray is not wired yet, so its choice is named but dimmed
            // rather than offered: an honest row over a lying one.
            description: Text(t.settings.closeTrayUnavailable),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s8, DsSpace.s20, DsSpace.s8),
            child: DsSelect<CloseAction>(
              value: window.closeAction == CloseAction.hideToTray ? CloseAction.quit : window.closeAction,
              onChanged: (value) {
                if (value != null) unawaited(ref.read(shellWindowSettingsProvider.notifier).setCloseAction(value));
              },
              options: [
                DsSelectOption(value: CloseAction.quit, label: t.settings.closeQuit),
                DsSelectOption(value: CloseAction.minimise, label: t.settings.closeMinimise),
              ],
              semanticLabel: t.settings.closeAction,
            ),
          ),
        ],
      ],
    );
  }
}

/// The appearance pane: the theme mode, the accent colour, the corner
/// style, the control density and the language — every choice written
/// through the theme scope (or the locale scope), so the whole app
/// restyles at once and persists to the next boot.
final class _AppearancePane extends ConsumerWidget {
  const _AppearancePane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final scope = AppThemeScope.of(context);
    final localeScope = AppLocaleScope.of(context);
    final settings = scope.settings;
    String? seedName;
    for (final (name, seed) in kNamedSeeds) {
      if (seed == settings.seed) seedName = name;
    }
    return DsListSection(
      header: Text(t.settings.appearance),
      children: [
        DsListRow(
          leading: const DsIcon(DsIcons.sun),
          title: Text(t.settings.themeMode),
          description: Text(t.settings.appearanceDescription),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s8, DsSpace.s20, DsSpace.s8),
          child: DsSelect<DsThemeMode>(
            value: settings.mode,
            onChanged: (value) {
              if (value == null) return;
              scope.onChanged(settings.rebuild((b) => b..mode = value));
            },
            options: [
              DsSelectOption(value: DsThemeMode.system, label: t.settings.themeModeSystem),
              DsSelectOption(value: DsThemeMode.light, label: t.settings.themeModeLight),
              DsSelectOption(value: DsThemeMode.dark, label: t.settings.themeModeDark),
            ],
            semanticLabel: t.settings.themeMode,
          ),
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.palette),
          title: Text(t.settings.themeSeed),
          description: Text(t.settings.themeSeedSystem),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s8, DsSpace.s20, DsSpace.s8),
          child: DsSelect<String>(
            value: seedName ?? '',
            // The empty value is the platform accent; a named tone rebuilds
            // the whole palette at once.
            onChanged: (value) {
              if (value == null) return;
              DsSeed? seed;
              for (final (name, candidate) in kNamedSeeds) {
                if (name == value) seed = candidate;
              }
              scope.onChanged(withSeed(settings, seed));
            },
            options: [
              DsSelectOption(value: '', label: t.settings.themeSeedSystem),
              for (final (name, _) in kNamedSeeds) DsSelectOption(value: name, label: _seedLabel(t, name)),
            ],
            semanticLabel: t.settings.themeSeed,
          ),
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.circle),
          title: Text(t.settings.pureBlack),
          description: Text(t.settings.pureBlackDesc),
          trailing: DsSwitch(
            value: settings.pureBlack,
            onChanged: (value) => scope.onChanged(settings.rebuild((b) => b..pureBlack = value)),
          ),
        ),
        DsListRow(leading: const DsIcon(DsIcons.cornerDownRight), title: Text(t.settings.corners)),
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s8, DsSpace.s20, DsSpace.s8),
          child: DsSelect<DsCornerStyle>(
            value: settings.cornerStyle,
            onChanged: (value) {
              if (value == null) return;
              scope.onChanged(settings.rebuild((b) => b..cornerStyle = value));
            },
            options: [
              DsSelectOption(value: DsCornerStyle.standard, label: t.settings.cornersStandard),
              DsSelectOption(value: DsCornerStyle.sharp, label: t.settings.cornersSharp),
              DsSelectOption(value: DsCornerStyle.soft, label: t.settings.cornersSoft),
              DsSelectOption(value: DsCornerStyle.pill, label: t.settings.cornersPill),
            ],
            semanticLabel: t.settings.corners,
          ),
        ),
        DsListRow(leading: const DsIcon(DsIcons.rows3), title: Text(t.settings.density)),
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s8, DsSpace.s20, DsSpace.s8),
          child: DsSelect<String>(
            value: settings.density?.name ?? '',
            onChanged: (value) {
              final density = switch (value) {
                'compact' => DsDensity.compact,
                'touch' => DsDensity.touch,
                _ => null,
              };
              scope.onChanged(settings.rebuild((b) => b..density = density));
            },
            options: [
              DsSelectOption(value: '', label: t.settings.densitySystem),
              DsSelectOption(value: 'compact', label: t.settings.densityCompact),
              DsSelectOption(value: 'touch', label: t.settings.densityTouch),
            ],
            semanticLabel: t.settings.density,
          ),
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.type),
          title: Text(t.settings.font),
          description: Text(t.settings.fontDescription),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s8, DsSpace.s20, DsSpace.s8),
          child: DsSelect<String>(
            value: settings.fontFamily ?? '',
            onChanged: (value) {
              if (value == null) return;
              scope.onChanged(
                settings.rebuild((b) {
                  // Empty is the platform's own face; a preset id is this
                  // app's bundled family, never a package one.
                  b
                    ..fontFamily = value.isEmpty ? null : value
                    ..fontPackage = null;
                }),
              );
            },
            options: [
              DsSelectOption(value: '', label: t.settings.fontPlatform),
              for (final (id, label) in kBundledFontPresets) DsSelectOption(value: id, label: label),
            ],
            semanticLabel: t.settings.font,
          ),
        ),
        DsListRow(leading: const DsIcon(DsIcons.languages), title: Text(t.settings.language)),
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s8, DsSpace.s20, DsSpace.s8),
          child: DsSelect<String>(
            value: localeScope.localeCode ?? '',
            onChanged: (value) => localeScope.onChanged(value == null || value.isEmpty ? null : value),
            options: [
              DsSelectOption(value: '', label: t.settings.languageSystem),
              const DsSelectOption(value: 'zh-CN', label: '简体中文'),
              const DsSelectOption(value: 'en', label: 'English'),
            ],
            semanticLabel: t.settings.language,
          ),
        ),
      ],
    );
  }

  String _seedLabel(Translations t, String name) => switch (name) {
    'seedBlue' => t.settings.seedBlue,
    'seedNavy' => t.settings.seedNavy,
    'seedIndigo' => t.settings.seedIndigo,
    'seedGraphite' => t.settings.seedGraphite,
    'seedOxblood' => t.settings.seedOxblood,
    'seedForest' => t.settings.seedForest,
    _ => name,
  };
}

/// The network pane: the app proxy the shared transport factory applies to
/// every module's requests — vod, the IPTV guide, backups — plus the tools
/// order the sidebar's divider block follows.
final class _NetworkPane extends ConsumerWidget {
  const _NetworkPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final proxy = ref.watch(proxySettingsProvider);
    final controller = ref.read(proxySettingsProvider.notifier);
    final toolOrder = ref.watch(toolOrderProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(t.settings.proxy),
          children: [
            DsSwitch(
              value: proxy.enabled,
              onChanged: (value) => unawaited(controller.setEnabled(value: value)),
              label: Text(t.settings.proxy),
              description: Text(t.settings.proxyDesc),
            ),
            if (proxy.enabled) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s8, DsSpace.s20, DsSpace.s4),
                child: DsTextField(
                  initialValue: proxy.host,
                  clearable: true,
                  placeholder: t.settings.proxyHost,
                  onChanged: (value) => unawaited(controller.setHost(value)),
                  semanticLabel: t.settings.proxyHost,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s8),
                child: DsTextField(
                  initialValue: '${proxy.port}',
                  placeholder: t.settings.proxyPort,
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    final port = int.tryParse(value.trim());
                    if (port != null) unawaited(controller.setPort(port));
                  },
                  semanticLabel: t.settings.proxyPort,
                ),
              ),
            ],
          ],
        ),
        DsListSection(
          header: Text(t.settings.toolsOrder),
          children: [
            for (final (index, item) in toolOrder.indexed)
              DsListRow(
                leading: DsIcon(item.icon),
                title: Text(item.label(t)),
                trailing: Row(
                  spacing: DsSpace.s4,
                  children: [
                    _OrderButton(
                      icon: DsIcons.chevronUp,
                      label: t.settings.moveUp,
                      enabled: index > 0,
                      onPressed: () => unawaited(ref.read(toolOrderProvider.notifier).move(index, index - 1)),
                    ),
                    _OrderButton(
                      icon: DsIcons.chevronDown,
                      label: t.settings.moveDown,
                      enabled: index < toolOrder.length - 1,
                      onPressed: () => unawaited(ref.read(toolOrderProvider.notifier).move(index, index + 1)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// One of the reorder buttons at a row's end: dimmed at its boundary.
final class _OrderButton extends StatelessWidget {
  const _OrderButton({required this.icon, required this.label, required this.enabled, required this.onPressed});

  final DsIconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    return DsPressable(
      semanticLabel: label,
      onPressed: enabled ? onPressed : null,
      builder: (context, states, _) {
        final hovered = states.contains(WidgetState.hovered);
        return Container(
          width: 26,
          height: 26,
          decoration: DsBoxDecoration(
            color: hovered && enabled ? colors.hover : colors.control,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(child: DsIcon(icon, size: 14, color: enabled ? colors.textMuted : colors.textSubtle)),
        );
      },
    );
  }
}

/// The danmaku pane: the shield's lists, then the flying layer's own look
/// and motion — every slider applies on the very next message.
final class _DanmakuPane extends ConsumerWidget {
  const _DanmakuPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final style = ref.watch(danmakuStyleProvider);
    final controller = ref.read(danmakuStyleProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: DsSpace.s16,
      children: [
        const ShieldPane(),
        DsListSection(
          header: Text(t.settings.danmakuStyleGroup),
          children: [
            DsListRow(
              leading: const DsIcon(DsIcons.type),
              title: Text(t.settings.styleFontSize),
              detail: Text('${style.fontSize.round()}'),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s4),
              child: DsSlider(
                value: style.fontSize,
                min: DanmakuStyleRange.fontSizeMin,
                max: DanmakuStyleRange.fontSizeMax,
                onChanged: (value) => unawaited(controller.setFontSize(value)),
                semanticLabel: t.settings.styleFontSize,
              ),
            ),
            DsListRow(
              leading: const DsIcon(DsIcons.wind),
              title: Text(t.settings.styleSpeed),
              detail: Text('${style.baseSpeed.round()}'),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s4),
              child: DsSlider(
                value: style.baseSpeed,
                min: DanmakuStyleRange.speedMin,
                max: DanmakuStyleRange.speedMax,
                onChanged: (value) => unawaited(controller.setBaseSpeed(value)),
                semanticLabel: t.settings.styleSpeed,
              ),
            ),
            DsListRow(
              leading: const DsIcon(DsIcons.moveVertical),
              title: Text(t.settings.styleArea),
              detail: Text('${(style.area * 100).round()}%'),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s4),
              child: DsSlider(
                value: style.area,
                min: DanmakuStyleRange.areaMin,
                // The ceiling is the slider's own default: the whole screen.
                onChanged: (value) => unawaited(controller.setArea(value)),
                semanticLabel: t.settings.styleArea,
              ),
            ),
            DsListRow(
              leading: const DsIcon(DsIcons.circle),
              title: Text(t.settings.styleOpacity),
              detail: Text('${(style.opacity * 100).round()}%'),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s4),
              child: DsSlider(
                value: style.opacity,
                min: DanmakuStyleRange.opacityMin,
                // The ceiling is the slider's own default: fully opaque.
                onChanged: (value) => unawaited(controller.setOpacity(value)),
                semanticLabel: t.settings.styleOpacity,
              ),
            ),
            DsSwitch(
              value: style.showStroke,
              onChanged: (value) => unawaited(controller.setShowStroke(value: value)),
              label: Text(t.settings.styleStroke),
            ),
            DsListRow(
              leading: const DsIcon(DsIcons.rotateCw),
              title: Text(t.settings.styleReset),
              onPressed: () => unawaited(controller.reset()),
            ),
          ],
        ),
      ],
    );
  }
}

/// The sites pane: the platform display (the reference's hot-areas
/// setting) — one switch per site; a switched-off platform leaves the
/// popular and areas tab lists until it is switched back on — with the
/// accounts block under it (the reference keeps accounts with platforms).
final class _SitesPane extends ConsumerWidget {
  const _SitesPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final sites = ref.watch(sitesProvider).all;
    final controller = ref.read(sitesDisplayProvider.notifier);
    final anythingHidden = ref.watch(sitesDisplayProvider.select((set) => set.isNotEmpty));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(t.settings.sitesDisplay),
          children: [
            if (!anythingHidden)
              DsListRow(leading: const DsIcon(DsIcons.antenna), title: Text(t.settings.sitesAllShown)),
            for (final site in sites)
              DsSwitch(
                value: controller.shown(site.manifest.id),
                onChanged: (value) => unawaited(controller.toggle(site.manifest.id)),
                label: Text(site.manifest.name['zh-CN'] ?? site.manifest.id),
                description: Text(site.manifest.id),
              ),
          ],
        ),
        const AccountPane(),
      ],
    );
  }
}

/// The data pane: the tools that already work — clearing the watch history
/// behind a confirm, and the follow list as a JSON round trip through the
/// clipboard — with the backup section under them (the local file round
/// trip and the WebDAV sync).
final class _DataPane extends ConsumerWidget {
  const _DataPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    void toast(String message) {
      showDsToast(context: context, title: message);
    }

    return DsListSection(
      header: Text(t.settings.navData),
      children: [
        DsListRow(
          leading: const DsIcon(DsIcons.history),
          title: Text(t.settings.dataClearHistory),
          description: Text(t.settings.dataClearHistoryDesc),
          onPressed: () async {
            final confirmed = await showDsConfirm(
              context: context,
              title: t.settings.confirmClearTitle,
              description: t.settings.confirmClearDesc,
              confirmLabel: t.settings.confirm,
              destructive: true,
            );
            if (!confirmed) return;
            await ref.read(historyProvider.notifier).clear();
            toast(t.settings.dataDone);
          },
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.upload),
          title: Text(t.settings.dataExportFollows),
          description: Text(t.settings.dataExportFollowsDesc),
          onPressed: () async {
            final rooms = ref.read(followsProvider).rooms;
            if (rooms.isEmpty) {
              toast(t.settings.dataEmpty);
              return;
            }
            await Clipboard.setData(ClipboardData(text: encodeFollows(rooms)));
            toast(t.settings.dataDone);
          },
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.download),
          title: Text(t.settings.dataImportFollows),
          description: Text(t.settings.dataImportFollowsDesc),
          onPressed: () async {
            final raw = await Clipboard.getData(Clipboard.kTextPlain).then((data) => data?.text);
            final rooms = raw == null ? null : decodeFollows(raw);
            if (rooms == null) {
              toast(t.settings.dataBadData);
              return;
            }
            final repository = ref.read(followRepositoryProvider).value;
            if (repository != null) {
              for (final room in rooms) {
                await repository.add(room);
              }
            }
            toast(t.settings.dataDone);
          },
        ),
        const BackupPane(),
      ],
    );
  }
}

/// The cache pane: the cover/avatar disk cache the network images live in —
/// its size, a manual clear, and the automatic cap the boot prunes to.
final class _CachePane extends StatefulWidget {
  const _CachePane();

  @override
  State<_CachePane> createState() => _CachePaneState();
}

final class _CachePaneState extends State<_CachePane> {
  int? _bytes;
  int _limitMb = imageCacheLimitMb();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_measure());
  }

  Future<void> _measure() async {
    final bytes = await imageCacheBytes();
    if (mounted) {
      setState(() => _bytes = bytes);
    }
  }

  Future<void> _clear() async {
    setState(() => _busy = true);
    try {
      await clearImageCache();
      await _measure();
      if (mounted) {
        showDsToast(context: context, title: context.t.settings.cacheCleared);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _setLimit(int? value) async {
    if (value == null) {
      return;
    }
    setState(() => _limitMb = value);
    await storeImageCacheLimitMb(value);
    // Applying the cap at once makes the setting honest on the spot.
    if (value > 0) {
      await enforceImageCacheLimit(value * 1024 * 1024);
      await _measure();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return DsListSection(
      header: Text(t.settings.navCache),
      children: [
        DsListRow(
          leading: const DsIcon(DsIcons.archive),
          title: Text(t.settings.cacheSize),
          detail: Text(_bytes == null ? '…' : formatCacheSize(_bytes!)),
          trailing: DsButton(
            variant: DsButtonVariant.ghost,
            size: DsSize.sm,
            leading: const DsIcon(DsIcons.refreshCw, size: 16),
            onPressed: _busy ? null : () => unawaited(_measure()),
            child: Text(t.settings.cacheRefresh),
          ),
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.trash2),
          title: Text(t.settings.cacheClear),
          description: Text(t.settings.cacheClearDesc),
          trailing: DsButton(
            variant: DsButtonVariant.secondary,
            size: DsSize.sm,
            onPressed: _busy ? null : () => unawaited(_clear()),
            child: Text(t.settings.cacheClear),
          ),
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.settings),
          title: Text(t.settings.cacheLimit),
          description: Text(t.settings.cacheLimitDesc),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s8, DsSpace.s20, DsSpace.s8),
          child: DsSelect<int>(
            value: _limitMb,
            onChanged: (value) => unawaited(_setLimit(value)),
            options: [
              DsSelectOption(value: 0, label: t.settings.cacheLimitOff),
              for (final mb in const [100, 200, 500, 1024, 2048]) DsSelectOption(value: mb, label: '$mb MB'),
            ],
            semanticLabel: t.settings.cacheLimit,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s16),
          child: Text(
            t.settings.cacheHint,
            style: theme.typography.caption.copyWith(color: colors.textMuted),
          ),
        ),
      ],
    );
  }
}

/// The about pane: the app's name and version, the project home, and the
/// open-source licences (the reference's about view, minus the update
/// check, which arrives with the version feature).
final class _AboutPane extends ConsumerWidget {
  const _AboutPane();

  static const String _projectUrl = 'https://github.com/wzgrx/PureLive';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return DsListSection(
      header: Text(t.settings.navAbout),
      children: [
        FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snapshot) {
            final info = snapshot.data;
            return DsListRow(
              leading: const DsIcon(DsIcons.info),
              title: Text(t.settings.aboutVersion),
              detail: Text(info == null ? '…' : '${info.version}+${info.buildNumber}'),
            );
          },
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.link),
          title: Text(t.settings.aboutProject),
          description: const Text(_projectUrl),
          onPressed: () => unawaited(launchUrl(Uri.parse(_projectUrl), mode: LaunchMode.externalApplication)),
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.scale),
          title: Text(t.settings.aboutLicense),
          description: Text(t.settings.aboutLicenseDesc),
          onPressed: () => showLicensePage(
            context: context,
            applicationName: t.common.appTitle,
            applicationIcon: const AppMark(size: 40),
          ),
        ),
        // The version history lands with the update feature.
        Padding(
          padding: const EdgeInsets.all(DsSpace.s12),
          child: Text(t.settings.aboutComingSoon, style: theme.typography.small.copyWith(color: colors.textSubtle)),
        ),
      ],
    );
  }
}

/// A section whose floor is not built yet: honest about the wait.
final class _ComingSoon extends StatelessWidget {
  const _ComingSoon({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpace.s32),
      child: Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.hammer),
          title: Text(context.t.settings.title),
          description: Text(message),
        ),
      ),
    );
  }
}
