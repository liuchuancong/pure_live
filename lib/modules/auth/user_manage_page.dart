import 'package:pure_live/common/index.dart';
import 'package:email_validator/email_validator.dart';
import 'package:pure_live/modules/auth/utils/constants.dart';

class UserManager extends StatefulWidget {
  const UserManager({super.key});

  @override
  State<UserManager> createState() => _UserManagerState();
}

class _UserManagerState extends State<UserManager> {
  final TextEditingController textEditingController = TextEditingController();
  final SettingsService settingsController = Get.find<SettingsService>();
  Color get themeColor => HexColor(settingsController.themeColorSwitch.value);
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
    return Scaffold(
      appBar: AppBar(title: Text(i18n('manage_users'))),
      body: EasyRefresh(
        controller: refreshController,
        onRefresh: onRefresh,
        onLoad: () {
          refreshController.finishLoad(IndicatorResult.success);
        },
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            TextField(
              keyboardType: TextInputType.emailAddress,
              controller: textEditingController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.email),
                contentPadding: const EdgeInsets.all(12.0),
                border: OutlineInputBorder(borderSide: BorderSide(color: themeColor)),
                hintText: i18n('hint_text'),
                suffixIcon: TextButton.icon(
                  onPressed: addUser,
                  icon: const Icon(Icons.add),
                  label: Text(i18n('add_btn')),
                ),
              ),
              onSubmitted: (e) => addUser(),
            ),
            spacer(12.0),
            // Using your custom helper with named parameters here
            Obx(
              () =>
                  Text(i18n('user_count', args: {'count': users.length.toString()}), style: Get.textTheme.titleMedium),
            ),
            spacer(12.0),
            Obx(
              () => Wrap(
                runSpacing: 12,
                spacing: 12,
                children: users.asMap().entries.map((entry) {
                  int index = entry.key;
                  String email = entry.value;
                  return InkWell(
                    borderRadius: const BorderRadius.all(Radius.circular(5.0)),
                    onTap: () => removeUser(email, index),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).primaryColor),
                        borderRadius: const BorderRadius.all(Radius.circular(5.0)),
                      ),
                      padding: const EdgeInsets.only(top: 10, bottom: 10, left: 8, right: 8),
                      child: Text(email, style: Get.textTheme.bodyMedium),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
