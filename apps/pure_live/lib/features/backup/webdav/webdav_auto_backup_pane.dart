import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/features/backup/panes/backup_actions.dart' show formatBackupTime, includeSecretsAllowed;
import 'package:pure_live/features/backup/webdav/webdav_accounts.dart';
import 'package:pure_live/features/backup/webdav/webdav_auto_backup.dart';
import 'package:pure_live/features/backup/webdav/webdav_auto_backup_scheduler.dart'
    show WebDavAutoBackupResult, webDavAutoFailureText, webdavAutoBackupServiceProvider;
import 'package:pure_live/features/settings/surface/settings_widgets.dart';
import 'package:pure_live/l10n/translations.dart';

/// The scheduled WebDAV backup's own page: the switch and its schedule, the
/// contents, and what the last runs left behind.
///
/// The schedule always uploads through the account the drive page has
/// selected — one place to point at a server, not two — and the retention
/// only ever touches the files this schedule named itself. Nothing here
/// runs in the background: the check happens while the app is in use, and
/// the page says so.
///
/// Public for the settings surface to embed.
final class WebDavAutoBackupPane extends ConsumerStatefulWidget {
  /// The scheduled backup's page.
  const WebDavAutoBackupPane({super.key});

  @override
  ConsumerState<WebDavAutoBackupPane> createState() => _WebDavAutoBackupPaneState();
}

final class _WebDavAutoBackupPaneState extends ConsumerState<WebDavAutoBackupPane> {
  String? _folderError;
  bool _running = false;

  WebDavAutoBackupSettings get _settings => ref.watch(webdavAutoBackupSettingsProvider);
  WebDavAutoBackupSettingsController get _controller => ref.read(webdavAutoBackupSettingsProvider.notifier);

  /// The label for an interval in hours: hours up to a day, days above it.
  String _intervalLabel(Translations t, int hours) =>
      hours <= 24 ? t.backup.webdavAutoIntervalHours(hours: hours) : t.backup.webdavAutoIntervalDays(days: hours ~/ 24);

  /// The text the next-check row shows: off, due at the next foreground
  /// tick, or the earliest moment the rules name.
  String _nextCheckText(Translations t) {
    if (!_settings.enabled) return t.backup.webdavAutoOff;
    final now = DateTime.now();
    if (ref.read(webdavAutoBackupServiceProvider).isDue(now: now)) return t.backup.webdavAutoDueNow;
    final due = WebDavAutoBackupRules.nextDue(now: now.toUtc(), interval: _settings.interval, meta: ref.read(
      webdavAutoBackupMetaProvider,
    ));
    return due == null ? t.backup.webdavAutoDueNow : formatBackupTime(due.toLocal());
  }

  Future<void> _runNow() async {
    if (_running) return;
    setState(() => _running = true);
    final WebDavAutoBackupResult result;
    try {
      result = await ref.read(webdavAutoBackupServiceProvider).runIfDue(force: true);
    } finally {
      if (mounted) setState(() => _running = false);
    }
    if (!mounted) return;
    final t = context.t;
    switch (result) {
      case WebDavAutoBackupResult(:final fileName?):
        showDsToast(context: context, title: t.backup.webdavAutoUploaded(file: fileName), status: DsStatus.success);
      case WebDavAutoBackupResult(:final error?):
        showDsToast(
          context: context,
          title: t.backup.webdavAutoFailed(reason: webDavAutoFailureText(error)),
          status: DsStatus.danger,
        );
      case WebDavAutoBackupResult(:final empty) when empty:
        showDsToast(context: context, title: t.backup.webdavAutoNothing);
      default:
        showDsToast(context: context, title: t.backup.webdavAutoAccountNone);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final meta = ref.watch(webdavAutoBackupMetaProvider);
    // The account the drive page has selected; null when none is saved.
    final stored = ref.watch(webdavAccountsProvider);
    WebDavAccount? account;
    for (final candidate in stored.accounts) {
      if (candidate.id == stored.selected) account = candidate;
    }
    account ??= stored.accounts.isEmpty ? null : stored.accounts.first;
    final enabled = _settings.enabled;
    final secretsAllowedHere = _settings.scope == WebDavAutoBackupScope.all && includeSecretsAllowed();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(t.backup.webdavAutoScheduleSection),
          children: [
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.calendarClock),
              title: t.backup.webdavAutoEnabled,
              description: t.backup.webdavAutoEnabledDesc,
              control: DsSwitch(value: enabled, onChanged: (value) => unawaited(_controller.setEnabled(enabled: value))),
            ),
            SettingsChoiceRow<int>(
              leading: const DsIcon(DsIcons.clock),
              title: t.backup.webdavAutoInterval,
              value: _settings.hours,
              options: [
                for (final hours in WebDavAutoBackupSettings.hourChoices)
                  DsSelectOption(value: hours, label: _intervalLabel(t, hours)),
              ],
              onChanged: enabled ? (hours) => unawaited(_controller.setHours(hours)) : null,
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.folder),
              title: t.backup.webdavAutoFolder,
              description: _folderError ?? t.backup.webdavAutoFolderDesc,
              control: DsTextField(
                initialValue: _settings.folder,
                clearable: true,
                enabled: enabled,
                placeholder: WebDavAutoBackupSettings.defaultFolder,
                error: _folderError != null,
                semanticLabel: t.backup.webdavAutoFolder,
                onChanged: (value) async {
                  final ok = await _controller.setFolder(value);
                  if (!mounted) return;
                  setState(() => _folderError = ok ? null : t.backup.webdavAutoFolderInvalid);
                },
              ),
            ),
            SettingsChoiceRow<int>(
              leading: const DsIcon(DsIcons.archive),
              title: t.backup.webdavAutoKeep,
              description: t.backup.webdavAutoKeepDesc,
              value: _settings.keep,
              options: [
                for (final keep in WebDavAutoBackupSettings.keepChoices)
                  DsSelectOption(value: keep, label: t.backup.webdavAutoKeepValue(count: keep)),
              ],
              onChanged: enabled ? (keep) => unawaited(_controller.setKeep(keep)) : null,
            ),
          ],
        ),
        DsListSection(
          header: Text(t.backup.webdavAutoContentSection),
          children: [
            SettingsSegmentedRow<WebDavAutoBackupScope>(
              leading: const DsIcon(DsIcons.databaseBackup),
              title: t.backup.webdavAutoScope,
              value: _settings.scope,
              options: [
                (value: WebDavAutoBackupScope.all, label: t.backup.webdavAutoScopeAll),
                (value: WebDavAutoBackupScope.follows, label: t.backup.webdavAutoScopeFollows),
              ],
              onChanged: enabled ? (scope) => unawaited(_controller.setScope(scope)) : null,
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.keyRound),
              title: t.backup.webdavAutoSecrets,
              description: switch ((secretsAllowedHere, _settings.scope)) {
                (true, _) => t.backup.webdavAutoSecretsDesc,
                (_, WebDavAutoBackupScope.follows) => t.backup.webdavAutoSecretsFollows,
                (_, _) => t.backup.webdavAutoSecretsGated,
              },
              control: DsSwitch(
                value: secretsAllowedHere && _settings.includeSecrets,
                onChanged: secretsAllowedHere && enabled
                    ? (value) => unawaited(_controller.setIncludeSecrets(include: value))
                    : null,
              ),
            ),
          ],
        ),
        DsListSection(
          header: Text(t.backup.webdavAutoStatusSection),
          children: [
            DsListRow(
              leading: const DsIcon(DsIcons.server),
              title: Text(t.backup.webdavAutoAccount),
              description: Text(t.backup.webdavAutoAccountDesc),
              detail: Text(account == null ? t.backup.webdavAutoAccountNone : account.name),
            ),
            DsListRow(
              leading: const DsIcon(DsIcons.calendarCheck),
              title: Text(t.backup.webdavAutoLastSuccess),
              detail: Text(
                meta.lastSuccess == null ? t.backup.webdavAutoNever : formatBackupTime(meta.lastSuccess!.toLocal()),
              ),
            ),
            DsListRow(
              leading: const DsIcon(DsIcons.clock),
              title: Text(t.backup.webdavAutoNextDue),
              detail: Text(_nextCheckText(t)),
            ),
            if (meta.failures > 0 && meta.lastAttempt != null)
              DsListRow(
                leading: DsIcon(DsIcons.triangleAlert, color: DsTheme.colorsOf(context).danger.text),
                title: Text(t.backup.webdavAutoFailures(count: meta.failures, time: _retryText(meta))),
              ),
            DsListRow(
              leading: const DsIcon(DsIcons.cloudUpload),
              title: Text(t.backup.webdavAutoRunNow),
              description: Text(_running ? t.backup.webdavAutoRunning : t.backup.webdavAutoRunNowDesc),
              trailing: DsButton(
                size: DsSize.sm,
                loading: _running,
                onPressed: enabled && account != null && !_running ? () => unawaited(_runNow()) : null,
                child: Text(t.backup.webdavAutoRunNow),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// When the backoff lets the next try go, in local time.
  String _retryText(WebDavAutoBackupMeta meta) {
    final retryAt = meta.lastAttempt!.toUtc().add(
      WebDavAutoBackupRules.backoff(meta.failures, _settings.interval),
    );
    return formatBackupTime(retryAt.toLocal());
  }
}
