import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:waterfall_flow/waterfall_flow.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pure_live/modules/auth/models/user_item.dart';
import 'package:pure_live/modules/auth/utils/firebase_manager.dart';
import 'package:pure_live/modules/auth/user_server_remote_controller.dart';
import 'package:pure_live/modules/auth/components/user_detail_main_page.dart';

class UserManager extends GetView<UserServerRemoteController> {
  UserManager({super.key}) {
    Get.put(UserServerRemoteController());
  }

  final TextEditingController searchController = TextEditingController();

  Future<void> deleteUserComplete(UserItem user) async {
    if (!controller.isSuperAdmin) {
      ToastUtil.show(i18n('operation_denied'));
      return;
    }
    final targetWeight = FirebaseManager.roleWeights[user.role] ?? 2;
    if (targetWeight == 0) {
      ToastUtil.show(i18n('operation_denied'));
      return;
    }
    try {
      if (targetWeight == 1) {
        await FirebaseFirestore.instance.collection('permissions').doc(user.uid).delete();
      }
      await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();
      ToastUtil.show(i18n('delete_success'));
      await controller.refreshData();
    } catch (e) {
      ToastUtil.show(i18n('delete_failed'));
    }
  }

  Future<void> promoteToManager(UserItem user) async {
    if (!controller.isSuperAdmin) {
      ToastUtil.show(i18n('operation_denied'));
      return;
    }
    try {
      await FirebaseFirestore.instance.collection('permissions').doc(user.uid).set({
        'canUpload': true,
        'role': 'manager',
        'email': user.email,
      });
      ToastUtil.show(i18n('add_success'));
      await controller.refreshData();
    } catch (e) {
      ToastUtil.show(i18n('add_failed'));
    }
  }

  Future<void> demoteManager(UserItem user) async {
    if (!controller.isSuperAdmin) {
      ToastUtil.show(i18n('operation_denied'));
      return;
    }
    if (user.role == 'admin') {
      ToastUtil.show(i18n('operation_denied'));
      return;
    }
    try {
      await FirebaseFirestore.instance.collection('permissions').doc(user.uid).delete();
      ToastUtil.show(i18n('delete_success'));
      await controller.refreshData();
    } catch (e) {
      ToastUtil.show(i18n('delete_failed'));
    }
  }

  Future<void> banUserUpload(UserItem user) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'canUpload': false,
      }, SetOptions(merge: true));
      ToastUtil.show(i18n('ban_success'));
      await controller.refreshData();
    } catch (e) {
      ToastUtil.show(i18n('ban_failed'));
    }
  }

  Future<void> unbanUserUpload(UserItem user) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'canUpload': true,
      }, SetOptions(merge: true));
      ToastUtil.show(i18n('unban_success'));
      await controller.refreshData();
    } catch (e) {
      ToastUtil.show(i18n('unban_failed'));
    }
  }

  Future<bool> _showConfirm(String actionName, String targetEmail) async {
    String formattedContent = i18n('confirm_content').replaceAll('{}', targetEmail).replaceAll('[{}]', '[$actionName]');
    return await Get.dialog<bool>(
          AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(i18n('confirm_title')),
            content: Text(formattedContent),
            actions: [
              TextButton(onPressed: () => Navigator.pop(Get.context!, false), child: Text(i18n('cancel'))),
              TextButton(onPressed: () => Navigator.pop(Get.context!, true), child: Text(i18n('confirm'))),
            ],
          ),
        ) ??
        false;
  }

  Widget _buildListUserCard(List<UserItem> userList, ScrollController scrollController) {
    return LayoutBuilder(
      builder: (context, constraint) {
        return WaterfallFlow.builder(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 10),
          controller: scrollController,
          gridDelegate: SliverWaterfallFlowDelegateWithFixedCrossAxisCount(
            lastChildLayoutTypeBuilder: (index) => LastChildLayoutType.none,
            crossAxisCount: 1,
            crossAxisSpacing: SettingsService.to.theme.crossAxisSpacing.v,
            mainAxisSpacing: SettingsService.to.theme.mainAxisSpacing.v,
          ),
          itemCount: userList.length,
          itemBuilder: (context, index) {
            return _buildUserCard(index, userList[index]);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(i18n('manage_users'))),
      body: Column(
        children: [
          Obx(
            () => Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _buildStatsCard(
                theme,
                controller.adminCount.value,
                controller.managerCount.value,
                controller.userCount.value,
              ),
            ),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(16, 20, 16, 12), child: _buildSearchField(theme)),
          Expanded(
            child: BasePageView<UserServerRemoteController, UserItem>(
              controller: controller,
              enableRefresh: true,
              enableLoadMore: true,
              emptyBuilder: (ctx) =>
                  AppStatusView(type: AppStatusType.empty, icon: Remix.user_3_line, title: i18n('no_data')),
              showScrollToTopBtn: SettingsService.to.page.showScrollToTopBtn.v,
              showPageSizeSelector: SettingsService.to.page.showPageSizeSelector.v,
              pageSizeOptions: SettingsService.to.page.pageSizeOptions,
              contentBuilder: (context, userList, scrollController) {
                return _buildListUserCard(userList, scrollController);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(ThemeData theme, int admin, int manager, int user) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.06), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            theme,
            i18n('role_admin'),
            admin.toString(),
            Remix.shield_user_fill,
            theme.colorScheme.primary,
          ),
          _buildStatItem(theme, i18n('role_manager'), manager.toString(), Remix.user_star_fill, Colors.amber.shade700),
          _buildStatItem(theme, i18n('role_user'), user.toString(), Remix.user_3_fill, theme.colorScheme.outline),
        ],
      ),
    );
  }

  Widget _buildStatItem(ThemeData theme, String title, String value, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: value,
                style: AppTextStyles.t12.copyWith(fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: AppTextStyles.t11.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField(ThemeData theme) {
    return TextField(
      controller: searchController,
      style: AppTextStyles.t14,
      decoration: InputDecoration(
        hintText: i18n('search_user_hint'),
        prefixIcon: const Icon(Remix.search_line, size: 18),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
      onChanged: (val) => controller.refreshByKeyword(val),
    );
  }

  Widget _buildUserCard(int index, UserItem user) {
    final theme = Theme.of(Get.context!);
    final int roleWeight = FirebaseManager.roleWeights[user.role] ?? 2;
    Color roleColor = theme.colorScheme.primary;
    String roleText = i18n('role_user');
    IconData roleIcon = Remix.user_line;

    if (roleWeight == 0) {
      roleColor = Colors.amber.shade700;
      roleText = i18n('role_admin');
      roleIcon = Remix.shield_user_line;
    } else if (roleWeight == 1) {
      roleColor = Colors.teal;
      roleText = i18n('role_manager');
      roleIcon = Remix.user_star_line;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(color: theme.shadowColor.withValues(alpha: 0.03), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Get.to(() => UserDetailConfigMainPage(documentId: user.uid));
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildLeadingIconWithBadge(theme, user, roleColor, roleIcon, index),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.t15.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                _buildBadge(roleText, roleColor),
                                const SizedBox(width: 6),
                                if (user.role != 'admin')
                                  _buildBadge(
                                    user.canUpload ? i18n('status_normal') : i18n('status_banned'),
                                    user.canUpload ? Colors.green : theme.colorScheme.error,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (ctx, constraints) {
                      bool compact = constraints.maxWidth <= 680;
                      List<Widget> btns = _buildActionButtons(user, theme);
                      return compact ? Column(children: [Row(children: btns)]) : Row(children: btns);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeadingIconWithBadge(ThemeData theme, UserItem user, Color color, IconData icon, int index) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
          child: Icon(icon, color: color),
        ),
        Positioned(
          left: -6,
          top: -6,
          child: Container(
            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(10)),
            child: Text(
              '${index + 1}',
              style: AppTextStyles.t11Bold.copyWith(color: Colors.white, fontSize: 10, height: 1.1),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: AppTextStyles.t11Medium.copyWith(color: color)),
    );
  }

  List<Widget> _buildActionButtons(UserItem user, ThemeData theme) {
    List<Widget> list = [];
    int weight = FirebaseManager.roleWeights[user.role] ?? 2;
    if (weight == 0) return list;

    if (controller.isSuperAdmin) {
      if (user.role == 'user') {
        list.add(
          Expanded(
            child: _buildActionBtn(
              theme,
              icon: Remix.user_star_line,
              label: i18n('action_promote'),
              color: Colors.teal,
              onTap: () async {
                bool ok = await _showConfirm(i18n('action_promote'), user.email);
                if (ok) await promoteToManager(user);
              },
            ),
          ),
        );
      } else if (user.role == 'manager') {
        list.add(
          Expanded(
            child: _buildActionBtn(
              theme,
              icon: Remix.user_received_line,
              label: i18n('action_demote'),
              color: Colors.orange,
              onTap: () async {
                bool ok = await _showConfirm(i18n('action_demote'), user.email);
                if (ok) await demoteManager(user);
              },
            ),
          ),
        );
      }
      list.add(const SizedBox(width: 10));
      list.add(
        Expanded(
          child: _buildActionBtn(
            theme,
            icon: Remix.delete_bin_6_line,
            label: i18n('action_delete_account'),
            color: theme.colorScheme.error,
            onTap: () async {
              bool ok =
                  await Get.dialog<bool>(
                    AlertDialog(
                      title: Text(i18n('confirm_title')),
                      content: Text(i18n('delete_confirm_content').replaceAll('{}', user.email)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(Get.context!, false), child: Text(i18n('cancel'))),
                        TextButton(onPressed: () => Navigator.pop(Get.context!, true), child: Text(i18n('confirm'))),
                      ],
                    ),
                  ) ??
                  false;
              if (ok) await deleteUserComplete(user);
            },
          ),
        ),
      );
    }

    if (user.role == 'user' || controller.isSuperAdmin) {
      if (list.isNotEmpty) list.add(const SizedBox(width: 10));
      if (user.canUpload) {
        list.add(
          Expanded(
            child: _buildActionBtn(
              theme,
              icon: Remix.close_circle_line,
              label: i18n('action_ban'),
              color: theme.colorScheme.error,
              onTap: () async {
                bool ok = await _showConfirm(i18n('action_ban'), user.email);
                if (ok) await banUserUpload(user);
              },
            ),
          ),
        );
      } else {
        list.add(
          Expanded(
            child: _buildActionBtn(
              theme,
              icon: Remix.check_line,
              label: i18n('action_unban'),
              color: Colors.green,
              onTap: () async {
                bool ok = await _showConfirm(i18n('action_unban'), user.email);
                if (ok) await unbanUserUpload(user);
              },
            ),
          ),
        );
      }
    }
    return list;
  }

  Widget _buildActionBtn(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 46,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
