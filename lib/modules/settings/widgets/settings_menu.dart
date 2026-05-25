import 'package:pure_live/common/index.dart';

class SettingsMenu<T> extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Map<T, String> valueMap;
  final T value;

  final Function(T)? onChanged;
  const SettingsMenu({
    required this.title,
    required this.value,
    required this.valueMap,
    this.subtitle,
    this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      visualDensity: VisualDensity.compact,
      title: Text(title, style: Theme.of(context).textTheme.bodyLarge),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: EdgeInsets.only(left: 16).copyWith(right: 8),
      subtitle: subtitle == null ? null : Text(subtitle!, style: Get.textTheme.bodySmall!.copyWith(color: Colors.grey)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(valueMap[value]!.tr, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Colors.grey)),
          SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
      onTap: () => openMenu(context),
    );
  }

  void openMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      useSafeArea: true, //useSafeArea似乎无效
      builder: (_) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: RadioGroup<T>(
            // 绑定组值
            groupValue: value,
            // 处理值变化
            onChanged: (T? newValue) {
              if (newValue != null) {
                Navigator.of(Get.context!).pop();
                onChanged?.call(newValue);
              }
            },
            // 内容区域
            child: Padding(
              padding: const EdgeInsets.only(top: 0, bottom: 10, left: 16, right: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                // 遍历选项
                children: valueMap.keys.map<Widget>((e) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 单选按钮
                      Radio<T>(value: e, activeColor: Theme.of(Get.context!).colorScheme.primary),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(Get.context!).pop();
                          onChanged?.call(e);
                        },
                        child: Text((valueMap[e]?.tr) ?? "???", style: Get.textTheme.bodyMedium),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
