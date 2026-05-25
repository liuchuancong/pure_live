import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';

class KeywordBlockPage extends StatefulWidget {
  const KeywordBlockPage({super.key});

  @override
  State<KeywordBlockPage> createState() => _KeywordBlockPageState();
}

class _KeywordBlockPageState extends State<KeywordBlockPage> {
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
    textEditingController.clear();
  }

  void remove(int itemIndex) {
    controller.removeShieldList(itemIndex);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Wrap(
        runSpacing: 16,
        children: [
          TextField(
            keyboardType: TextInputType.text,
            controller: textEditingController,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => add(),
            style: theme.textTheme.bodyMedium,
            decoration: InputDecoration(
              hintText: i18n("please_enter_keyword"),
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: IconButton(
                  onPressed: add,
                  icon: Icon(Remix.add_circle_line, color: theme.colorScheme.primary),
                  tooltip: i18n('add'),
                ),
              ),
            ),
          ),
          Obx(() {
            if (controller.shieldList.isEmpty) {
              return const SizedBox.shrink();
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${i18n("keyword_added_count", args: {"count": controller.shieldList.length.toString()})} · ${i18n("click_to_remove_suffix")}",
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  runSpacing: 8,
                  spacing: 8,
                  children: controller.shieldList.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;

                    return Tooltip(
                      message: i18n("click_to_remove"),
                      child: InputChip(
                        label: Text(item),
                        deleteIcon: const Icon(Remix.close_circle_fill, size: 14),
                        onDeleted: () => remove(index),
                        onPressed: () => remove(index),
                        labelStyle: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface),
                        backgroundColor: theme.colorScheme.surfaceContainerLow,
                        deleteIconColor: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.08), width: 1),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}
