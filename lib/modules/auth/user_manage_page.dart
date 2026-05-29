import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:email_validator/email_validator.dart';

class UserManager extends StatefulWidget {
  const UserManager({super.key});

  @override
  State<UserManager> createState() => _UserManagerState();
}

class _UserManagerState extends State<UserManager> {
  final TextEditingController textEditingController = TextEditingController();

  final refreshController = EasyRefreshController(controlFinishRefresh: true, controlFinishLoad: true);

  final users = <String>[].obs;

  @override
  void initState() {
    getCurrentUsers();
    super.initState();
  }

  Future onRefresh() async {
    await getCurrentUsers();
    refreshController.finishRefresh(IndicatorResult.success);
  }

  Future<void> getCurrentUsers() async {
    List<dynamic> data = await SupaBaseManager().client.from(SupaBaseManager.supabasePolicy.checkTable).select();
    if (data.isNotEmpty) {
      users.value = data.map((e) => e[SupaBaseManager.supabasePolicy.email].toString()).toList();
    }
  }

  void addUser() {
    final text = textEditingController.text.trim();
    if (text.isEmpty || !EmailValidator.validate(text)) {
      ToastUtil.show(i18n('invalid_email'));
      return;
    }
    if (users.contains(text)) {
      ToastUtil.show(i18n('email_exists'));
      return;
    }
    SupaBaseManager().client
        .from(SupaBaseManager.supabasePolicy.checkTable)
        .insert({SupaBaseManager.supabasePolicy.email: text})
        .then(
          (value) {
            ToastUtil.show(i18n('add_success'));
            users.add(text);
            textEditingController.clear();
          },
          onError: (err) {
            ToastUtil.show(i18n('add_failed'));
          },
        );
  }

  void removeUser(String email, int index) {
    SupaBaseManager().client
        .from(SupaBaseManager.supabasePolicy.checkTable)
        .delete()
        .eq(SupaBaseManager.supabasePolicy.email, email)
        .then(
          (value) {
            ToastUtil.show(i18n('delete_success'));
            users.removeAt(index);
          },
          onError: (err) {
            ToastUtil.show(i18n('delete_failed'));
          },
        );
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
            context.buildModernCard([
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      keyboardType: TextInputType.emailAddress,
                      controller: textEditingController,
                      style: AppTextStyles.t14,
                      decoration: InputDecoration(
                        hintText: i18n('hint_text'),
                        hintStyle: TextStyle(color: theme.hintColor.withValues(alpha: 0.5)),
                        prefixIcon: Icon(Remix.mail_line, size: 20, color: theme.hintColor.withValues(alpha: 0.7)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerLowest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: theme.dividerColor.withValues(alpha: 0.05)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                        ),
                      ),
                      onSubmitted: (e) => addUser(),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: FilledButton.icon(
                        onPressed: addUser,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Remix.user_add_line, size: 18),
                        label: Text(i18n('add_btn'), style: AppTextStyles.t14.copyWith(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 24),
            Obx(() => context.buildGroupTitle(i18n('user_count', args: {'count': users.length.toString()}))),
            Obx(() {
              if (users.isEmpty) return const SizedBox.shrink();
              return context.buildModernCard(
                users.asMap().entries.map((entry) {
                  int index = entry.key;
                  String email = entry.value;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    leading: Icon(Remix.user_line, size: 20, color: theme.colorScheme.primary),
                    title: Text(email, style: AppTextStyles.t14.copyWith(fontWeight: FontWeight.w500)),
                    trailing: IconButton(
                      icon: Icon(
                        Remix.delete_bin_6_line,
                        size: 18,
                        color: theme.colorScheme.error.withValues(alpha: 0.7),
                      ),
                      splashRadius: 20,
                      onPressed: () async {
                        final confirm = await Get.dialog<bool>(
                          AlertDialog(
                            title: Text(i18n("confirm_delete")),
                            content: Text("${i18n("confirm_delete_user")} $email?"),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(Get.context!, false),
                                child: Text(i18n("cancel")),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(Get.context!, true),
                                child: Text(i18n("delete"), style: TextStyle(color: theme.colorScheme.error)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          removeUser(email, index);
                        }
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
