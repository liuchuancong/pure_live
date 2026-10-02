import 'dart:async';

import 'package:remixicon/remixicon.dart';
import 'package:pure_live/core/index.dart';
import 'package:pure_live/domains/account/presentation/auth/utils/firebase_manager.dart';
import 'package:pure_live/domains/account/presentation/auth/components/user_detail_main_page.dart';

class FirebaseProfileActions {
  const FirebaseProfileActions();

  String? get userId => FirebaseManager.getInstance().auth.currentUser?.uid;

  bool get hasManagementPower => FirebaseManager.getInstance().hasManagementPower();

  Future<void> uploadConfig() => FirebaseManager.getInstance().uploadConfig();

  Future<void> downloadConfig() => FirebaseManager.getInstance().downloadConfig();

  Future<void> signOut() => FirebaseManager.getInstance().signOut();

  Future<void> openConfigPreview(String documentId) async {
    await Get.to<void>(() => UserDetailConfigMainPage(documentId: documentId));
  }

  Future<void> openUserManagement() async {
    await Get.toNamed<void>(RoutePath.kUserManage);
  }
}

class MinePage extends StatefulWidget {
  const MinePage({super.key, this.actions = const FirebaseProfileActions()});

  final FirebaseProfileActions actions;

  @override
  State<MinePage> createState() => _MinePageState();
}

class _MinePageState extends State<MinePage> {
  static const _previewAction = 'preview';
  static const _managementAction = 'management';
  static const _downloadAction = 'download';
  static const _uploadAction = 'upload';
  static const _signOutAction = 'sign-out';

  String? _busyAction;
  bool _isConfirming = false;

  bool get _actionsBlocked => _busyAction != null || _isConfirming;

  Future<void> _runAction(String actionKey, Future<void> Function() action) async {
    if (_actionsBlocked) return;
    setState(() => _busyAction = actionKey);
    try {
      await action();
    } catch (error, stackTrace) {
      debugPrint('[MinePage] Cloud profile action "$actionKey" failed: $error\n$stackTrace');
      ToastUtil.show(i18n('firebase_action_failed'));
    } finally {
      if (mounted && _busyAction == actionKey) {
        setState(() => _busyAction = null);
      }
    }
  }

  Future<void> _openConfigPreview() async {
    final userId = widget.actions.userId?.trim();
    if (userId == null || userId.isEmpty) {
      ToastUtil.show(i18n('firebase_account_unauthorized'));
      return;
    }
    await _runAction(_previewAction, () => widget.actions.openConfigPreview(userId));
  }

  Future<void> _confirmAndRun({
    required String titleKey,
    required String messageKey,
    required String actionKey,
    required Future<void> Function() action,
  }) async {
    if (_actionsBlocked) return;
    setState(() => _isConfirming = true);
    var confirmed = false;
    try {
      confirmed =
          await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              scrollable: true,
              insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
              title: Text(i18n(titleKey)),
              content: Text(i18n(messageKey)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(i18n('cancel'))),
                FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(i18n('confirm'))),
              ],
            ),
          ) ??
          false;
    } catch (error, stackTrace) {
      debugPrint('[MinePage] Confirmation "$actionKey" failed: $error\n$stackTrace');
      ToastUtil.show(i18n('firebase_action_failed'));
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
    if (!mounted) return;
    if (confirmed) await _runAction(actionKey, action);
  }

  Widget? _actionProgress(String actionKey, Color color) {
    if (_busyAction != actionKey) return null;
    return SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: color));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progressColor = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: Text(i18n('firebase_mine'))),
      body: ListView(
        physics: const PureLiveScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          context.buildGroupTitle(i18n('firebase_mine')),
          context.buildModernCard([
            context.buildTile(
              icon: Remix.file_text_line,
              title: i18n('config_preview'),
              subtitle: i18n('firebase_config_preview_subtitle'),
              isLong: true,
              trailing: _actionProgress(_previewAction, progressColor),
              stackTrailingOnNarrow: true,
              onTap: _actionsBlocked ? null : () => unawaited(_openConfigPreview()),
            ),
            if (widget.actions.hasManagementPower)
              context.buildTile(
                icon: Remix.shield_user_line,
                title: i18n('manage_users'),
                subtitle: i18n('allow_user_uploads'),
                isLong: true,
                trailing: _actionProgress(_managementAction, progressColor),
                stackTrailingOnNarrow: true,
                onTap: _actionsBlocked
                    ? null
                    : () => unawaited(_runAction(_managementAction, widget.actions.openUserManagement)),
              ),
            context.buildTile(
              icon: Remix.download_cloud_line,
              title: i18n('download_user_configs'),
              subtitle: i18n('firebase_download_subtitle'),
              isLong: true,
              trailing: _actionProgress(_downloadAction, progressColor),
              stackTrailingOnNarrow: true,
              onTap: _actionsBlocked
                  ? null
                  : () => unawaited(
                      _confirmAndRun(
                        titleKey: 'firebase_download_confirm_title',
                        messageKey: 'firebase_download_confirm_message',
                        actionKey: _downloadAction,
                        action: widget.actions.downloadConfig,
                      ),
                    ),
            ),
            context.buildTile(
              icon: Remix.upload_cloud_line,
              title: i18n('firebase_mine_profiles'),
              subtitle: i18n('firebase_upload_subtitle'),
              isLong: true,
              trailing: _actionProgress(_uploadAction, progressColor),
              stackTrailingOnNarrow: true,
              onTap: _actionsBlocked ? null : () => unawaited(_runAction(_uploadAction, widget.actions.uploadConfig)),
            ),
            context.buildTile(
              icon: Remix.logout_box_r_line,
              title: i18n('firebase_log_out'),
              subtitle: i18n('firebase_sign_out_subtitle'),
              isLong: true,
              iconColor: theme.colorScheme.error.withValues(alpha: 0.8),
              trailing: _actionProgress(_signOutAction, theme.colorScheme.error),
              stackTrailingOnNarrow: true,
              onTap: _actionsBlocked
                  ? null
                  : () => unawaited(
                      _confirmAndRun(
                        titleKey: 'firebase_sign_out_confirm_title',
                        messageKey: 'firebase_sign_out_confirm_message',
                        actionKey: _signOutAction,
                        action: widget.actions.signOut,
                      ),
                    ),
            ),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
