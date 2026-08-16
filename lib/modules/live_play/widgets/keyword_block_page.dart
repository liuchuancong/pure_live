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
  final FocusNode _focusNode = FocusNode();
  final RxBool _isFocused = false.obs;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      _isFocused.value = _focusNode.hasFocus;
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    textEditingController.dispose();
    _isFocused.close();
    super.dispose();
  }

  void add() {
    final keyword = textEditingController.text.trim();
    if (keyword.isEmpty) {
      ToastUtil.show(i18n("please_enter_keyword"));
      return;
    }
    SettingsService.to.fav.addShieldList(keyword);
    textEditingController.clear();
    _focusNode.requestFocus();
  }

  void remove(int itemIndex) {
    SettingsService.to.fav.removeShieldList(itemIndex);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Wrap(
        runSpacing: 16,
        children: [
          // 优化后的输入框，带边框和焦点状态
          Obx(() {
            final isFocused = _isFocused.value;
            return TextField(
              keyboardType: TextInputType.text,
              controller: textEditingController,
              focusNode: _focusNode,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => add(),
              style: theme.textTheme.bodyMedium,
              cursorColor: theme.colorScheme.primary,
              decoration: InputDecoration(
                hintText: i18n("please_enter_keyword"),
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
                // 添加边框
                filled: true,
                fillColor: isFocused
                    ? theme.colorScheme.primary.withValues(alpha: 0.04)
                    : theme.colorScheme.surfaceContainerLow,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                // 圆角边框
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                ),
                // 启用状态边框
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                ),
                // 聚焦状态边框
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                ),
                // 错误状态边框（可选）
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.colorScheme.error, width: 1.5),
                ),
                // 聚焦错误状态边框（可选）
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.colorScheme.error, width: 2),
                ),
                suffixIcon: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: IconButton(
                    onPressed: add,
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Remix.add_circle_line, color: theme.colorScheme.primary, size: 20),
                    ),
                    tooltip: i18n('add'),
                  ),
                ),
              ),
            );
          }),
          Obx(() {
            if (SettingsService.to.fav.shieldList.v.isEmpty) {
              return const SizedBox.shrink();
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${i18n("keyword_added_count", args: {"count": SettingsService.to.fav.shieldList.v.length.toString()})} · ${i18n("click_to_remove_suffix")}",
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  runSpacing: 8,
                  spacing: 8,
                  children: SettingsService.to.fav.shieldList.v.asMap().entries.map((entry) {
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
          Obx(() {
            final users = SettingsService.to.fav.blockedDanmakuUsers;
            if (users.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  i18n('blocked_danmaku_users', args: {'count': '${users.length}'}),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: users
                      .asMap()
                      .entries
                      .map((entry) {
                        return InputChip(
                          avatar: const Icon(Icons.person_off_rounded, size: 16),
                          label: Text(entry.value),
                          onDeleted: () => SettingsService.to.fav.removeBlockedDanmakuUser(entry.key),
                        );
                      })
                      .toList(growable: false),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}
