import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pure_live/modules/auth/auth_controller.dart';
import 'package:pure_live/modules/auth/models/user_item.dart';
import 'package:pure_live/modules/auth/utils/firebase_manager.dart';

class UserManager extends StatefulWidget {
  const UserManager({super.key});

  @override
  State<UserManager> createState() => _UserManagerState();
}

class _UserManagerState extends State<UserManager> {
  final refreshController = EasyRefreshController(controlFinishRefresh: true, controlFinishLoad: true);
  final allUsers = <UserItem>[].obs;
  final filteredUsers = <UserItem>[].obs;
  final searchController = TextEditingController();

  bool isSuperAdmin = false;
  String searchQuery = "";

  @override
  void initState() {
    super.initState();
    isSuperAdmin = FirebaseManager.getInstance().isAdmin();
    fetchAllData();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> onRefresh() async {
    await fetchAllData();
    refreshController.finishRefresh(IndicatorResult.success);
  }

  Future<void> deleteUserComplete(UserItem user) async {
    if (!isSuperAdmin) {
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
      await fetchAllData();
    } catch (e) {
      ToastUtil.show(i18n('delete_failed'));
    }
  }

  Future<void> fetchAllData() async {
    try {
      final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
      final permissionsSnapshot = await FirebaseFirestore.instance.collection('permissions').get();

      final permissionRoleMap = {for (var doc in permissionsSnapshot.docs) doc.id: doc.data()['role'] ?? 'user'};

      final List<UserItem> tempAll = [];
      final currentUserUid = Get.find<AuthController>().user!.uid;

      for (var doc in usersSnapshot.docs) {
        final String uid = doc.id;

        if (uid == currentUserUid) continue;

        final data = doc.data();
        final String email = data['email'] ?? '';
        final bool userCanUpload = data['canUpload'] != false;

        final String currentRole = permissionRoleMap[uid] ?? 'user';

        if (!FirebaseManager.getInstance().canVisible(currentRole)) {
          continue;
        }

        tempAll.add(UserItem(uid: uid, email: email, canUpload: userCanUpload, role: currentRole));
      }

      tempAll.sort((a, b) {
        int weightA = FirebaseManager.roleWeights[a.role] ?? 2;
        int weightB = FirebaseManager.roleWeights[b.role] ?? 2;

        int compare = weightA.compareTo(weightB);
        if (compare == 0) return a.email.compareTo(b.email);
        return compare;
      });

      allUsers.value = List.from(tempAll);
      _applySearchFilter();
    } catch (e) {
      ToastUtil.show(i18n('load_failed'));
    }
  }

  void _applySearchFilter() {
    if (searchQuery.isEmpty) {
      filteredUsers.value = allUsers;
    } else {
      filteredUsers.value = allUsers.where((u) => u.email.toLowerCase().contains(searchQuery.toLowerCase())).toList();
    }
  }

  Future<void> promoteToManager(UserItem user) async {
    if (!isSuperAdmin) {
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
      await fetchAllData();
    } catch (e) {
      ToastUtil.show(i18n('add_failed'));
    }
  }

  Future<void> demoteManager(UserItem user) async {
    if (!isSuperAdmin) {
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
      await fetchAllData();
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
      await fetchAllData();
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
      await fetchAllData();
    } catch (e) {
      ToastUtil.show(i18n('unban_failed'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(i18n('manage_users'), style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: Obx(() {
        final adminCount = filteredUsers.where((e) => (FirebaseManager.roleWeights[e.role] ?? 2) == 0).length;
        final managerCount = filteredUsers.where((e) => (FirebaseManager.roleWeights[e.role] ?? 2) == 1).length;
        final userCount = filteredUsers.where((e) => (FirebaseManager.roleWeights[e.role] ?? 2) == 2).length;

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // 统计卡片
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverToBoxAdapter(child: _buildStatsCard(theme, adminCount, managerCount, userCount)),
            ),

            // 搜索框
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              sliver: SliverToBoxAdapter(child: _buildSearchField(theme)),
            ),

            // 标题
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              sliver: SliverToBoxAdapter(child: _buildSectionTitle(theme, i18n('user_list'), Remix.user_3_line)),
            ),

            // 用户列表
            if (filteredUsers.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: Text(i18n('no_data'), style: TextStyle(color: Colors.grey.shade500)),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.builder(
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, idx) => _buildUserCard(idx, filteredUsers[idx], theme),
                ),
              ),

            const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
          ],
        );
      }),
    );
  }

  // 统计卡片（和IPTV管理页完全同款）
  Widget _buildStatsCard(ThemeData theme, int admin, int manager, int user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(colors: [theme.colorScheme.primary.withValues(alpha: 0.12), theme.cardColor]),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(theme, i18n('role_admin'), admin.toString(), Remix.shield_user_line),
          _buildStatItem(theme, i18n('role_manager'), manager.toString(), Remix.user_star_line),
          _buildStatItem(theme, i18n('role_user'), user.toString(), Remix.user_line),
        ],
      ),
    );
  }

  Widget _buildStatItem(ThemeData theme, String title, String value, IconData icon) {
    return Column(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: theme.colorScheme.primary),
        ),
        const SizedBox(height: 10),
        Text(value, style: AppTextStyles.t12.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(title, style: AppTextStyles.t11.copyWith(color: theme.hintColor)),
      ],
    );
  }

  // 搜索框（同款样式）
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
      onChanged: (val) {
        searchQuery = val;
        _applySearchFilter();
      },
    );
  }

  // 章节标题（同款）
  Widget _buildSectionTitle(ThemeData theme, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(title, style: AppTextStyles.t14.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }

  // 用户卡片（完全复刻 IPTV 卡片样式）
  Widget _buildUserCard(int index, UserItem user, ThemeData theme) {
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                // 序号 + 头像
                _buildLeadingIconWithBadge(theme, user, roleColor, roleIcon, index),
                const SizedBox(width: 14),

                // 邮箱 + 角色
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

            // 操作按钮（同款布局）
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth <= 680;
                if (compact) {
                  return Column(children: [Row(children: _buildActionButtons(user, theme))]);
                }
                return Row(children: _buildActionButtons(user, theme));
              },
            ),
          ],
        ),
      ),
    );
  }

  // 头像 + 序号角标（同款风格）
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
          right: -6,
          top: -6,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle),
            child: Text('${index + 1}', style: AppTextStyles.t11Bold.copyWith(color: Colors.white)),
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

  // 操作按钮（和IPTV完全同款）
  List<Widget> _buildActionButtons(UserItem user, ThemeData theme) {
    final list = <Widget>[];
    if ((FirebaseManager.roleWeights[user.role] ?? 2) == 0) return list;

    if (isSuperAdmin) {
      if (user.role == 'user') {
        list.add(
          Expanded(
            child: _buildActionBtn(
              theme,
              icon: Remix.user_star_line,
              label: i18n('action_promote'),
              color: Colors.teal,
              onTap: () async {
                bool confirm = await _showConfirm(i18n('action_promote'), user.email);
                if (confirm) await promoteToManager(user);
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
                bool confirm = await _showConfirm(i18n('action_demote'), user.email);
                if (confirm) await demoteManager(user);
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
              bool confirm =
                  await Get.dialog<bool>(
                    AlertDialog(
                      title: Text(i18n('confirm_title')),
                      content: Text(i18n('delete_confirm_content').replaceAll('{}', user.email)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(i18n('cancel'))),
                        TextButton(onPressed: () => Navigator.pop(context, true), child: Text(i18n('confirm'))),
                      ],
                    ),
                  ) ??
                  false;
              if (confirm) await deleteUserComplete(user);
            },
          ),
        ),
      );
    }

    if (user.role == 'user' || isSuperAdmin) {
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
                bool confirm = await _showConfirm(i18n('action_ban'), user.email);
                if (confirm) await banUserUpload(user);
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
                bool confirm = await _showConfirm(i18n('action_unban'), user.email);
                if (confirm) await unbanUserUpload(user);
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

  Future _showConfirm(String actionName, String targetEmail) async {
    String formattedContent = i18n('confirm_content').replaceAll('{}', targetEmail).replaceAll('[{}]', '[$actionName]');
    return await Get.dialog(
          AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(i18n('confirm_title')),
            content: Text(formattedContent),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text(i18n('cancel'))),
              TextButton(onPressed: () => Navigator.pop(context, true), child: Text(i18n('confirm'))),
            ],
          ),
        ) ??
        false;
  }
}
