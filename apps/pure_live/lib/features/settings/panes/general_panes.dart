import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/material.dart' show showLicensePage;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_platform/live_platform.dart' show FormFactor, PlatformKind;
import 'package:live_shell/live_shell.dart' show CloseAction;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/browse/live_alert_settings.dart' show liveAlertSettingsProvider;
import 'package:pure_live/features/settings/dialogs/config_preview_dialog.dart' show showConfigPreview;
import 'package:pure_live/features/settings/dialogs/live_alert_tags_dialog.dart' show showLiveAlertTagsDialog;
import 'package:pure_live/features/settings/general/auto_shutdown_section.dart' show AutoShutdownSection;
import 'package:pure_live/features/settings/general/settings_order_list.dart' show SettingsOrderList;
import 'package:pure_live/features/settings/surface/settings_child_entry.dart' show SettingsChildEntry;
import 'package:pure_live/features/settings/surface/settings_sections.dart' show SettingsSection;
import 'package:pure_live/features/settings/surface/settings_widgets.dart' show SettingsChoiceRow, SettingsConfigRow;
import 'package:pure_live/features/version/version.dart'
    show showDownloadPage, showReleaseHistory, showUpdateDialog, versionCheckProvider;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/layouts/layouts.dart' show AppMark;
import 'package:pure_live/modules/live/favorites/data/follow_tags.dart' show followTagsProvider;
import 'package:pure_live/shared/shared.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode, launchUrl;

/// The startup page (启动与退出): both ends of the process's life — launch
/// at login and the startup mark, the window's close behaviour, and
/// scheduled shutdown.
final class StartupPane extends ConsumerWidget {
  const StartupPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final startup = ref.watch(startupProvider);
    final window = ref.watch(shellWindowSettingsProvider);
    final primary = ref.watch(isPrimaryWindowProvider);
    final desktop = ref.watch(platformRuntimeProvider).environment.runtime.formFactor == FormFactor.desktop;
    final kind = ref.watch(platformRuntimeProvider).environment.runtime.kind;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(t.settings.navStartup),
          children: [
            if (primary && startup.supported)
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.rocket),
                title: t.settings.startup,
                description: startup.error.isEmpty
                    ? t.settings.startupDesc
                    : '${t.settings.startupFailed}: ${startup.error}',
                control: startup.loading
                    ? const Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: SizedBox.square(dimension: 18, child: DsSpinner()),
                      )
                    : DsSwitch(
                        value: startup.enabled,
                        onChanged: (value) => unawaited(ref.read(startupProvider.notifier).setEnabled(value: value)),
                      ),
              ),
            if (primary)
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.playCircle),
                title: t.settings.splashAnimation,
                description: t.settings.splashAnimationDesc,
                control: DsSwitch(
                  value: ref.watch(splashSettingsProvider),
                  onChanged: (value) => ref.read(splashSettingsProvider.notifier).enabled = value,
                ),
              ),
          ],
        ),
        DsListSection(
          header: Text(t.settings.closeExitGroup),
          children: [
            if (primary)
              SettingsChoiceRow<CloseAction>(
                leading: const DsIcon(DsIcons.x),
                title: t.settings.closeAction,
                description: t.settings.closeActionDesc,
                value: window.closeAction,
                options: [
                  DsSelectOption(value: CloseAction.quit, label: t.settings.closeQuit),
                  DsSelectOption(value: CloseAction.minimise, label: t.settings.closeMinimise),
                  DsSelectOption(value: CloseAction.hideToTray, label: t.settings.closeHideToTray),
                ],
                onChanged: (value) => unawaited(ref.read(shellWindowSettingsProvider.notifier).setCloseAction(value)),
              ),
            if (primary && desktop && kind != PlatformKind.macos)
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.messageCircleWarning),
                title: t.settings.noExitConfirm,
                description: t.settings.noExitConfirmDescription,
                control: DsSwitch(
                  value: window.dontAskExit,
                  onChanged: (value) =>
                      unawaited(ref.read(shellWindowSettingsProvider.notifier).setDontAskExit(value: value)),
                ),
              ),
          ],
        ),
        if (primary) const AutoShutdownSection(),
      ],
    );
  }
}

/// The refresh pane (the reference's Refresh): the follows page's periodic
/// and one-shot foreground refresh, its interval and queue bound, plus the
/// periodic cover cache refresh. The follows page owns its timers; the cover
/// timer is process-wide and re-arms from the app root.
final class RefreshPane extends ConsumerWidget {
  const RefreshPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final autoRefresh = ref.watch(followsAutoRefreshProvider);
    final maxConcurrent = ref.watch(maxConcurrentRefreshProvider);
    final thumbnails = ref.watch(thumbnailRefreshProvider);
    final liveAlerts = ref.watch(liveAlertSettingsProvider);
    final tags = ref.watch(followTagsProvider);
    // A stored interval the choices do not list still shows as chosen.
    final intervals = {...kRefreshIntervalChoices, autoRefresh.minutes}.toList()..sort();
    final thumbnailIntervals = {...kThumbnailRefreshIntervalChoices, thumbnails.minutes}.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(t.settings.refreshGroup),
          children: [
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.heart),
              title: t.settings.followsAutoRefresh,
              description: t.settings.followsAutoRefreshDesc,
              control: DsSwitch(
                value: autoRefresh.enabled,
                onChanged: (value) => unawaited(ref.read(followsAutoRefreshProvider.notifier).setEnabled(value: value)),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.rotateCcw),
              title: t.settings.refreshOnResume,
              description: t.settings.refreshOnResumeDesc,
              control: DsSwitch(
                value: autoRefresh.onResume,
                onChanged: (value) =>
                    unawaited(ref.read(followsAutoRefreshProvider.notifier).setOnResume(value: value)),
              ),
            ),
            if (autoRefresh.enabled) ...[
              SettingsChoiceRow<int>(
                leading: const DsIcon(DsIcons.timer),
                title: t.settings.refreshInterval,
                value: autoRefresh.minutes,
                options: [
                  for (final minutes in intervals) DsSelectOption(value: minutes, label: _intervalLabel(minutes)),
                ],
                onChanged: (value) => unawaited(ref.read(followsAutoRefreshProvider.notifier).setMinutes(value)),
              ),
            ],
            SettingsChoiceRow<int>(
              leading: const DsIcon(DsIcons.waypoints),
              title: t.settings.maxConcurrentRefresh,
              description: t.settings.maxConcurrentRefreshDesc,
              value: maxConcurrent,
              options: [
                for (var value = kMaxConcurrentRefreshMin; value <= kMaxConcurrentRefreshMax; value++)
                  DsSelectOption(
                    value: value,
                    label: value == kMaxConcurrentRefreshDefault ? '$value · ${t.settings.recommended}' : '$value',
                  ),
              ],
              onChanged: (value) => unawaited(ref.read(maxConcurrentRefreshProvider.notifier).set(value)),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.image),
              title: t.settings.refreshThumbnails,
              description: t.settings.refreshThumbnailsDesc,
              control: DsSwitch(
                value: thumbnails.enabled,
                onChanged: (value) => unawaited(ref.read(thumbnailRefreshProvider.notifier).setEnabled(value: value)),
              ),
            ),
            if (thumbnails.enabled)
              SettingsChoiceRow<int>(
                leading: const DsIcon(DsIcons.timer),
                title: t.settings.thumbnailRefreshInterval,
                value: thumbnails.minutes,
                options: [
                  for (final minutes in thumbnailIntervals)
                    DsSelectOption(value: minutes, label: _intervalLabel(minutes)),
                ],
                onChanged: (value) => unawaited(ref.read(thumbnailRefreshProvider.notifier).setMinutes(value)),
              ),
          ],
        ),
        // Alerts are their own concern — the switch and the tag filter it
        // enables — not part of the refresh schedule above.
        DsListSection(
          header: Text(t.settings.liveAlert),
          children: [
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.bell),
              title: t.settings.liveAlert,
              description: t.settings.liveAlertDesc,
              control: DsSwitch(
                value: liveAlerts.enabled,
                onChanged: (value) {
                  if (value) unawaited(requestUserNotificationPermission());
                  unawaited(ref.read(liveAlertSettingsProvider.notifier).setEnabled(value: value));
                },
              ),
            ),
            if (liveAlerts.enabled)
              DsListRow(
                leading: const DsIcon(DsIcons.tag),
                title: Text(t.settings.liveAlertTags),
                description: Text(tags.isEmpty ? t.settings.liveAlertTagsNone : t.settings.liveAlertTagsDesc),
                detail: Text(
                  liveAlerts.tagIds.isEmpty
                      ? t.settings.liveAlertTagsAll
                      : t.settings.liveAlertTagCount(selected: liveAlerts.tagIds.length),
                ),
                showChevron: tags.isNotEmpty,
                onPressed: tags.isEmpty ? null : () => unawaited(showLiveAlertTagsDialog(context)),
              ),
          ],
        ),
      ],
    );
  }
}

/// The navigation page: the two orders the shell reads — which home entries
/// the sidebar, drawer and bottom bar show, in what order, and the same for
/// the tools block under the sidebar's divider.
///
/// Each is its own route: the lists are long enough, and the ordering edit
/// is a mode of its own, so neither belongs flattened onto one page.
final class NavPane extends StatelessWidget {
  const NavPane({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(t.settings.navMenuOrder),
          children: const [
            SettingsChildEntry(child: SettingsSection.navHomeMenu),
            SettingsChildEntry(child: SettingsSection.navToolOrder),
          ],
        ),
      ],
    );
  }
}

/// The home menu page: the four live destinations in their saved order,
/// each row carrying its own show/hide switch.
///
/// No row ever moves for a switch — all four stay listed in place, on or
/// off, and the switch writes only the hidden set. The order key is
/// written only by the draft's save, so until the viewer reorders the menu
/// the rows keep the default order; at least one entry stays shown.
final class NavHomeMenuPane extends ConsumerWidget {
  const NavHomeMenuPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final homeOrder = ref.watch(navMenuOrderProvider);
    final visible = ref.watch(navMenuProvider).toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        SettingsOrderList<NavigationItem>(
          header: t.settings.navHomeMenuTitle,
          items: homeOrder,
          identityOf: (item) => item.name,
          labelOf: (item) => item.label(t),
          leadingOf: (item) => DsIcon(item.icon),
          trailingOf: (item) => DsSwitch(
            value: visible.contains(item),
            onChanged: (value) async {
              final changed = await ref.read(navMenuProvider.notifier).setVisible(item, value: value);
              if (!changed && context.mounted) {
                showDsToast(context: context, title: t.settings.navMenuKeepOne);
              }
            },
          ),
          onSave: (draft) => unawaited(ref.read(navMenuProvider.notifier).setOrder(draft)),
        ),
      ],
    );
  }
}

/// The tools page: the sidebar's block under its divider, in the viewer's
/// order. Every tool stays shown — the order is the only choice here.
final class NavToolOrderPane extends ConsumerWidget {
  const NavToolOrderPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    return SettingsOrderList<NavigationItem>(
      header: t.settings.toolsOrder,
      items: ref.watch(toolOrderProvider),
      identityOf: (item) => item.name,
      labelOf: (item) => item.label(t),
      leadingOf: (item) => DsIcon(item.icon),
      onSave: (draft) => unawaited(ref.read(toolOrderProvider.notifier).setOrder(draft)),
    );
  }
}

/// A refresh interval's label: minutes under an hour, whole hours above,
/// half hours as the decimal the reference shows ("1.5 h").
String _intervalLabel(int minutes) {
  if (minutes < 60) return '$minutes min';
  if (minutes % 60 == 0) return '${minutes ~/ 60} h';
  if (minutes % 30 == 0) return '${minutes / 60} h';
  return '$minutes min';
}

/// The about pane: the app's name and version, the update check, the
/// release history, the project home, and the open-source licences (the
/// reference's about view, without an in-app installer: a release opens its
/// own download page).
final class AboutPane extends ConsumerWidget {
  const AboutPane({super.key});

  static const String _projectUrl = 'https://github.com/liuchuancong/pure_live';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final check = ref.watch(versionCheckProvider);
    final latest = check.latest;
    final status = check.checking
        ? t.settings.checkingUpdate
        : check.error != null
        ? '${t.settings.updateCheckFailed} · ${check.error}'
        : latest != null
        ? t.settings.updateAvailable(version: latest.version)
        : check.checked
        ? t.settings.upToDate
        : t.settings.checkUpdateDesc;
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
          leading: const DsIcon(DsIcons.cloudDownload),
          title: Text(t.settings.checkUpdate),
          description: Text(status),
          trailing: latest != null
              ? DsButton(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  onPressed: () => unawaited(showUpdateDialog(context, latest)),
                  child: Text(t.settings.viewUpdate),
                )
              : DsButton(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  onPressed: check.checking ? null : () => unawaited(ref.read(versionCheckProvider.notifier).check()),
                  child: Text(t.settings.checkUpdate),
                ),
        ),
        SettingsConfigRow(
          leading: const DsIcon(DsIcons.refreshCw),
          title: t.settings.autoCheckUpdate,
          description: t.settings.autoCheckUpdateDesc,
          control: DsSwitch(
            value: ref.watch(updateSettingsProvider),
            onChanged: (value) => ref.read(updateSettingsProvider.notifier).enabled = value,
          ),
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.history),
          title: Text(t.settings.releaseHistory),
          description: Text(t.settings.releaseHistoryDesc),
          showChevron: true,
          onPressed: () => unawaited(showReleaseHistory(context)),
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.cloudDownload),
          // The installers are the release's own files; the page lists
          // every build so a viewer on another architecture can still
          // take the right one.
          title: Text(t.settings.downloadTitle),
          description: Text(t.settings.downloadHint),
          showChevron: true,
          onPressed: () => unawaited(showDownloadPage(context)),
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.fileText),
          title: Text(t.settings.configPreview),
          description: Text(t.settings.configPreviewDesc),
          onPressed: () => unawaited(showConfigPreview(context)),
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.link),
          title: Text(t.settings.aboutProject),
          description: const Text(_projectUrl),
          onPressed: () => unawaited(launchUrl(Uri.parse(_projectUrl), mode: LaunchMode.externalApplication)),
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.scrollText),
          title: Text(t.settings.aboutLicense),
          description: Text(t.settings.aboutLicenseDesc),
          onPressed: () => showLicensePage(
            context: context,
            applicationName: t.common.appTitle,
            applicationIcon: const AppMark(size: 40),
          ),
        ),
      ],
    );
  }
}
