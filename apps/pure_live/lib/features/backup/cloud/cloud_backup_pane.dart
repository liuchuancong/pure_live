import 'dart:async' show unawaited;
import 'dart:io' show Platform;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_platform/live_platform.dart' show FormFactor;
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/backup/cloud/cloud_callback.dart';
import 'package:pure_live/features/backup/cloud/cloud_controller.dart';
import 'package:pure_live/features/backup/cloud/cloud_models.dart';
import 'package:pure_live/features/backup/cloud/cloud_service.dart';
import 'package:pure_live/features/backup/document/backup_document.dart';
import 'package:pure_live/features/backup/document/backup_repository.dart' show backupSummaryProvider;
import 'package:pure_live/features/backup/panes/backup_actions.dart' show captureBackupDocument, includeSecretsAllowed;
import 'package:pure_live/features/backup/panes/backup_section_picker.dart';
import 'package:pure_live/features/backup/panes/restore_preview_dialog.dart';
import 'package:pure_live/features/settings/surface/settings_child_entry.dart' show SettingsChildEntry;
import 'package:pure_live/features/settings/surface/settings_sections.dart' show SettingsSection;
import 'package:pure_live/l10n/translations.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode, launchUrl;

/// The cloud strings node; the other locales' nodes extend the base one.
typedef _CloudStrings = Translations$backup$cloud$zh_CN;

/// The failure's message in the user's language, by the controller's code.
String cloudFailureMessage(Translations t, String code) {
  final c = t.backup.cloud;
  return switch (code) {
    'invalid-email' => c.errInvalidEmail,
    'user-not-found' ||
    'wrong-password' ||
    'invalid-credential' ||
    'INVALID_LOGIN_CREDENTIALS' => c.errWrongCredentials,
    'email-already-in-use' => c.errEmailInUse,
    'weak-password' => c.errWeakPassword,
    'too-many-requests' => c.errTooMany,
    'network-request-failed' || 'unavailable' => c.errNetwork,
    'user-disabled' => c.errDisabled,
    'permission-denied' => c.errPermission,
    'upload-refused' => c.errUploadRefused,
    'nothing-stored' => c.errNothingStored,
    'not-a-backup' => c.errNotBackup,
    'callback-invalid' => c.errCallbackInvalid,
    'signed-out' => c.errSignedOut,
    'web-context-cancelled' || 'canceled' => c.errCancelled,
    // The restore's own refusals, worded as the other ways word them.
    'restore-busy' => t.backup.restoreBusy,
    'restore-recordings-busy' => t.backup.restoreRecordingsBusy,
    'restore-empty' => t.backup.restoreEmptyDocument,
    _ => c.errUnknown(code: code),
  };
}

/// The cloud backup page: the probe, the sign-in (email, GitHub), the
/// account, and the one document the cloud holds — upload what you pick,
/// download and restore what you pick, delete. Unreachable from this
/// network, it says so and leaves the other transports alone.
///
/// Public for the settings surface to embed; the page owns only its
/// fields and the dialogs it opens. Everything else is the controller's.
final class CloudBackupPane extends ConsumerStatefulWidget {
  /// The pane.
  const CloudBackupPane({super.key});

  @override
  ConsumerState<CloudBackupPane> createState() => _CloudBackupPaneState();
}

final class _CloudBackupPaneState extends ConsumerState<CloudBackupPane> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  @override
  void initState() {
    super.initState();
    // After the first frame: a provider write inside initState is a
    // modification during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(ref.read(cloudControllerProvider.notifier).ensureStarted());
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  CloudController get _controller => ref.read(cloudControllerProvider.notifier);

  void _toast(String message, {DsStatus status = DsStatus.neutral}) =>
      showDsToast(context: context, title: message, status: status);

  bool _validEmail(String email) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.trim());

  // -- Sign-in --------------------------------------------------------------

  Future<void> _signIn({required bool register}) async {
    final t = context.t.backup.cloud;
    final email = _email.text.trim();
    final password = _password.text;
    if (!_validEmail(email)) {
      _toast(t.errInvalidEmail, status: DsStatus.danger);
      return;
    }
    if (password.length < 6) {
      _toast(t.errWeakPassword, status: DsStatus.danger);
      return;
    }
    if (register) {
      await _controller.signUpWithEmail(email: email, password: password);
    } else {
      await _controller.signInWithEmail(email: email, password: password);
    }
    if (mounted && ref.read(cloudControllerProvider).error == null) _password.clear();
  }

  Future<void> _reset() async {
    final t = context.t.backup.cloud;
    final email = _email.text.trim();
    if (!_validEmail(email)) {
      _toast(t.errInvalidEmail, status: DsStatus.danger);
      return;
    }
    await _controller.sendPasswordReset(email);
    if (mounted && ref.read(cloudControllerProvider).error == null) _toast(t.resetSent, status: DsStatus.success);
  }

  /// GitHub: the platform's own browser session where the SDK has one
  /// (Android, iOS, macOS); otherwise the middle page in the system
  /// browser, whose redirect either reaches the app over `purelive://` or
  /// is pasted into the dialog that opens meanwhile.
  Future<void> _gitHub() async {
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      await _controller.signInWithGitHubProvider();
      if (!mounted || ref.read(cloudControllerProvider).error == null || !Platform.isMacOS) return;
      // macOS without a configured auth session falls through to the page.
    }
    await registerWindowsCallbackScheme();
    final url = CloudService.gitHubDesktopUrl(platform: Platform.operatingSystem);
    await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    final pasted = await _askCallback();
    if (pasted == null || !mounted) return;
    final token = gitHubTokenFromCallback(pasted);
    if (token == null) {
      _toast(context.t.backup.cloud.errCallbackInvalid, status: DsStatus.danger);
      return;
    }
    await _controller.signInWithGitHubToken(token);
  }

  Future<String?> _askCallback() {
    final field = TextEditingController();
    return showDsDialog<String>(
      context: context,
      builder: (context) {
        final t = context.t.backup.cloud;
        return DsDialog(
          title: Text(t.gitHubPasteTitle),
          description: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s12,
            children: [
              Text(t.gitHubPasteBody),
              DsTextField(controller: field, autofocus: true, placeholder: 'purelive://auth?credential=…'),
            ],
          ),
          actions: [
            DsButton(
              variant: DsButtonVariant.ghost,
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.t.common.cancel),
            ),
            DsButton(
              variant: DsButtonVariant.primary,
              onPressed: () => Navigator.of(context).pop(field.text),
              child: Text(context.t.common.confirm),
            ),
          ],
        );
      },
    ).whenComplete(field.dispose);
  }

  // -- The document ---------------------------------------------------------

  Future<void> _upload() async {
    final t = context.t;
    final sections = await showBackupSectionPicker(
      context,
      title: t.backup.pickUploadTitle,
      confirmLabel: t.backup.cloud.upload,
      available: BackupSection.values.toSet(),
      counts: ref.read(backupSummaryProvider).value ?? const {},
      secretsAllowed: includeSecretsAllowed(),
      note: t.backup.cloud.uploadNote,
    );
    if (sections == null || !mounted) return;
    final document = await captureBackupDocument(ref, sections: sections);
    if (document.isEmpty) {
      if (mounted) _toast(t.backup.exportEmpty);
      return;
    }
    await _controller.upload(document);
    if (mounted && ref.read(cloudControllerProvider).error == null) {
      _toast(t.backup.cloud.uploadDone, status: DsStatus.success);
    }
  }

  Future<void> _download() async {
    final t = context.t;
    // A restore another page started is still writing: say so before the
    // download, not after the user picked and confirmed.
    if (restoreInProgress(ref)) {
      _toast(t.backup.restoreBusy, status: DsStatus.danger);
      return;
    }
    final CloudDownload download;
    try {
      download = await _controller.download();
    } on CloudFailure catch (failure) {
      if (mounted) _toast(cloudFailureMessage(t, failure.code), status: DsStatus.danger);
      return;
    }
    if (!mounted) return;
    final BackupDocument? chosen;
    try {
      chosen = await pickAndPreviewRestore(
        context,
        ref,
        document: download.document,
        name: t.backup.cloud.title,
        title: t.backup.cloud.pickRestoreTitle,
        note: download.legacy ? t.backup.cloud.legacyNote(skipped: download.skippedLegacy.join(', ')) : null,
      );
    } on Object {
      // The stores to compare the backup with did not open: nothing was
      // written.
      if (mounted) _toast(t.backup.restoreFailed, status: DsStatus.danger);
      return;
    }
    if (chosen == null || !mounted) return;
    await _controller.restore(chosen);
    if (mounted && ref.read(cloudControllerProvider).error == null) {
      _toast(t.backup.importDone, status: DsStatus.success);
    }
  }

  Future<void> _delete() async {
    final t = context.t;
    final confirmed = await showDsConfirm(
      context: context,
      title: t.backup.cloud.deleteTitle,
      description: t.backup.cloud.deleteDesc,
      confirmLabel: t.common.confirm,
      cancelLabel: t.common.cancel,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await _controller.deleteCloudDocument();
    if (mounted && ref.read(cloudControllerProvider).error == null) _toast(t.backup.cloud.deleteDone);
  }

  // -- Build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final c = t.backup.cloud;
    final state = ref.watch(cloudControllerProvider);
    final tv = ref.watch(platformRuntimeProvider).environment.runtime.formFactor == FormFactor.tv;
    // A failure shows once, as a toast, and is then forgotten.
    ref.listen(cloudControllerProvider.select((s) => s.error), (previous, next) {
      if (next != null && next != previous) {
        _toast(cloudFailureMessage(t, next), status: DsStatus.danger);
        _controller.clearError();
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: switch (state.phase) {
        CloudPhase.probing => [_probing(c)],
        CloudPhase.unreachable => [_unreachable(c)],
        CloudPhase.signedOut => [_signInSection(c, state, tv: tv)],
        CloudPhase.signedIn => [
          _accountSection(c, state),
          _documentSection(c, state),
          if (state.permissions.hasManagementPower)
            DsListSection(
              header: Text(c.adminSection),
              children: const [SettingsChildEntry(child: SettingsSection.cloudAdmin)],
            ),
        ],
      },
    );
  }

  Widget _probing(_CloudStrings c) => DsListSection(
    header: Text(c.title),
    children: [DsListRow(leading: const DsSpinner(), title: Text(c.probing), description: Text(c.probingDesc))],
  );

  Widget _unreachable(_CloudStrings c) => DsListSection(
    header: Text(c.title),
    children: [
      DsListRow(
        leading: const DsIcon(DsIcons.cloudOff),
        title: Text(c.unreachable),
        description: Text(c.unreachableDesc),
      ),
      DsListRow(
        leading: const DsIcon(DsIcons.refreshCw),
        title: Text(c.retry),
        onPressed: () => unawaited(_controller.start()),
      ),
    ],
  );

  Widget _signInSection(_CloudStrings c, CloudState state, {required bool tv}) {
    final busy = state.busy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(c.signInSection),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: DsSpace.s16, vertical: DsSpace.s12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: DsSpace.s12,
                children: [
                  DsTextField(
                    controller: _email,
                    placeholder: c.emailHint,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    enabled: !busy,
                  ),
                  DsTextField(
                    controller: _password,
                    placeholder: c.passwordHint,
                    obscureText: true,
                    revealable: true,
                    autofillHints: const [AutofillHints.password],
                    enabled: !busy,
                    onSubmitted: (_) => unawaited(_signIn(register: false)),
                  ),
                  Wrap(
                    spacing: DsSpace.s8,
                    runSpacing: DsSpace.s8,
                    children: [
                      DsButton(
                        variant: DsButtonVariant.primary,
                        onPressed: busy ? null : () => unawaited(_signIn(register: false)),
                        child: busy ? const DsSpinner() : Text(c.signIn),
                      ),
                      DsButton(
                        variant: DsButtonVariant.secondary,
                        onPressed: busy ? null : () => unawaited(_signIn(register: true)),
                        child: Text(c.signUp),
                      ),
                      DsButton(
                        variant: DsButtonVariant.ghost,
                        onPressed: busy ? null : () => unawaited(_reset()),
                        child: Text(c.forgot),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        DsListSection(
          header: Text(c.gitHubSection),
          children: [
            if (tv)
              DsListRow(
                leading: const DsIcon(DsIcons.gitBranch),
                title: Text(c.gitHub),
                description: Text(c.gitHubTvHint),
              )
            else
              DsListRow(
                leading: const DsIcon(DsIcons.gitBranch),
                title: Text(c.gitHub),
                description: Text(Platform.isAndroid || Platform.isIOS ? c.gitHubMobileHint : c.gitHubDesktopHint),
                onPressed: busy ? null : () => unawaited(_gitHub()),
                showChevron: true,
              ),
          ],
        ),
      ],
    );
  }

  Widget _accountSection(_CloudStrings c, CloudState state) {
    final user = state.user!;
    final permissions = state.permissions;
    return DsListSection(
      header: Text(c.accountSection),
      children: [
        DsListRow(
          leading: DsIcon(user.viaGitHub ? DsIcons.gitBranch : DsIcons.mail),
          title: Text(user.email.isEmpty ? (user.displayName ?? user.uid) : user.email),
          description: Text(
            [
              if (user.viaGitHub) c.viaGitHub else c.viaEmail,
              if (permissions.role != null) c.roleLabel(role: permissions.role!),
              if (permissions.canUpload) c.uploadAllowed else c.uploadRefused,
            ].join(' · '),
          ),
          trailing: DsButton(
            variant: DsButtonVariant.ghost,
            size: DsSize.sm,
            onPressed: state.busy ? null : () => unawaited(_controller.signOut()),
            child: Text(c.signOut),
          ),
        ),
      ],
    );
  }

  Widget _documentSection(_CloudStrings c, CloudState state) {
    final busy = state.busy;
    final info = state.backup;
    return DsListSection(
      header: Text(c.documentSection),
      children: [
        DsListRow(
          leading: const DsIcon(DsIcons.cloud),
          title: Text(info.exists ? c.stored : c.nothingStored),
          description: Text(
            info.exists
                ? [
                    if (info.updatedAt != null) c.storedAt(time: info.updatedAt!),
                    if (info.appVersion != null) c.storedVersion(version: info.appVersion!),
                    if (info.legacy) c.storedLegacy,
                  ].join(' · ')
                : c.nothingStoredDesc,
          ),
          trailing: busy ? const DsSpinner() : null,
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.cloudUpload),
          title: Text(c.upload),
          description: Text(state.permissions.canUpload ? c.uploadDesc : c.errUploadRefused),
          onPressed: busy || !state.permissions.canUpload ? null : () => unawaited(_upload()),
          showChevron: true,
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.cloudDownload),
          title: Text(c.download),
          description: Text(c.downloadDesc),
          onPressed: busy || !info.exists ? null : () => unawaited(_download()),
          showChevron: true,
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.trash2),
          title: Text(c.delete),
          description: Text(c.deleteDesc),
          onPressed: busy || !info.exists ? null : () => unawaited(_delete()),
        ),
      ],
    );
  }
}
