import 'package:pure_live/common/index.dart';

class KeywordBlockPage extends StatefulWidget {
  const KeywordBlockPage({super.key});

  @override
  State<KeywordBlockPage> createState() => _KeywordBlockPageState();
}

class _KeywordBlockPageState extends State<KeywordBlockPage> {
  // 确保 SettingsService 在应用启动时已经被 Get.put() 注册
  SettingsService get controller => Get.find<SettingsService>();

  final TextEditingController textEditingController = TextEditingController();

  @override
  void dispose() {
    textEditingController.dispose();
    super.dispose();
  }

  void add() {
    final keyword = textEditingController.text.trim();
    if (keyword.isEmpty) {
      ToastUtil.show(i18n("please_enter_keyword"));
      return;
    }

    controller.addShieldList(keyword);
    textEditingController.text = ""; // 清空输入框
  }

  void remove(int itemIndex) {
    controller.removeShieldList(itemIndex);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12.0),
      children: [
        TextField(
          keyboardType: TextInputType.text,
          controller: textEditingController,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.all(12.0),
            border: OutlineInputBorder(borderSide: BorderSide(color: Theme.of(context).primaryColor)),
            hintText: i18n("please_enter_keyword"),
            suffixIcon: TextButton.icon(onPressed: add, icon: const Icon(Icons.add), label: Text(i18n('add'))),
          ),
          onSubmitted: (e) {
            add();
          },
        ),
        // 使用 SizedBox 代替假设的 spacer 函数
        const SizedBox(height: 12.0),
        Obx(
          () => Text(
            i18n("keyword_added_count", args: {"count": controller.shieldList.length.toString()}) +
                i18n("click_to_remove_suffix"),
            style: Get.textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 12.0),
        Obx(
          () => Wrap(
            runSpacing: 12,
            spacing: 12,
            children: controller.shieldList.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return InkWell(
                borderRadius: const BorderRadius.all(Radius.circular(5.0)),
                onTap: () {
                  // 直接使用当前循环的索引来移除
                  remove(index);
                },
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).primaryColor),
                    borderRadius: const BorderRadius.all(Radius.circular(5.0)),
                  ),
                  padding: const EdgeInsets.only(top: 10, bottom: 10, left: 8, right: 8),
                  child: Text(item, style: Get.textTheme.bodyMedium),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
