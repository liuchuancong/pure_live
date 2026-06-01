import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserItem {
  final String uid;
  final String email;
  bool canUpload;

  UserItem({required this.uid, required this.email, required this.canUpload});
}

class UserManager extends StatefulWidget {
  const UserManager({super.key});

  @override
  State<UserManager> createState() => _UserManagerState();
}

class _UserManagerState extends State<UserManager> {
  final refreshController = EasyRefreshController(controlFinishRefresh: true, controlFinishLoad: true);

  final users = <UserItem>[].obs;

  @override
  void initState() {
    super.initState();
    getCurrentUsers();
  }

  Future<void> onRefresh() async {
    await getCurrentUsers();
    refreshController.finishRefresh(IndicatorResult.success);
  }

  Future<void> getCurrentUsers() async {
    try {
      final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();

      final permissionsSnapshot = await FirebaseFirestore.instance.collection('permissions').get();

      final permissionSet = permissionsSnapshot.docs.map((e) => e.id).toSet();

      users.value = usersSnapshot.docs.map((doc) {
        final data = doc.data();

        return UserItem(uid: doc.id, email: data['email'] ?? '', canUpload: permissionSet.contains(doc.id));
      }).toList();
    } catch (e) {
      ToastUtil.show(i18n('load_failed'));
    }
  }

  Future<void> grantUser(UserItem user) async {
    try {
      await FirebaseFirestore.instance.collection('permissions').doc(user.uid).set({
        'canUpload': true,
        'role': 'user',
        'email': user.email,
      });

      user.canUpload = true;

      users.assignAll([...users]);

      ToastUtil.show(i18n('add_success'));
    } catch (e) {
      ToastUtil.show(i18n('add_failed'));
    }
  }

  Future<void> revokeUser(UserItem user) async {
    try {
      await FirebaseFirestore.instance.collection('permissions').doc(user.uid).delete();

      user.canUpload = false;

      users.assignAll([...users]);

      ToastUtil.show(i18n('delete_success'));
    } catch (e) {
      ToastUtil.show(i18n('delete_failed'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(i18n('manage_users'))),
      body: EasyRefresh(
        controller: refreshController,
        onRefresh: onRefresh,
        onLoad: () {
          refreshController.finishLoad(IndicatorResult.success);
        },
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            context.buildGroupTitle(i18n('manage_users')),

            Obx(() => context.buildGroupTitle(i18n('user_count', args: {'count': users.length.toString()}))),

            const SizedBox(height: 12),

            Obx(() {
              if (users.isEmpty) {
                return Center(
                  child: Padding(padding: const EdgeInsets.all(32), child: Text(i18n('no_data'))),
                );
              }

              return context.buildModernCard(
                users.map((user) {
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    leading: Icon(Remix.user_line, size: 20, color: theme.colorScheme.primary),
                    title: Text(user.email, style: AppTextStyles.t14.copyWith(fontWeight: FontWeight.w500)),
                    subtitle: Text(user.canUpload ? i18n('authorized') : i18n('unauthorized')),
                    trailing: user.canUpload
                        ? IconButton(
                            icon: Icon(Remix.delete_bin_6_line, color: theme.colorScheme.error),
                            onPressed: () async {
                              final confirm = await Get.dialog<bool>(
                                AlertDialog(
                                  title: Text(i18n('confirm_delete')),
                                  content: Text('${i18n("confirm_delete_user")} ${user.email} ?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context, false);
                                      },
                                      child: Text(i18n('cancel')),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context, true);
                                      },
                                      child: Text(i18n('delete')),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                await revokeUser(user);
                              }
                            },
                          )
                        : IconButton(
                            icon: Icon(Remix.user_add_line, color: theme.colorScheme.primary),
                            onPressed: () async {
                              await grantUser(user);
                            },
                          ),
                  );
                }).toList(),
              );
            }),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
