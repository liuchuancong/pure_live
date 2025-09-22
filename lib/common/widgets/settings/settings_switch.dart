import 'package:flutter/material.dart';
import 'package:pure_live/common/widgets/app_style.dart';

class SettingsSwitch extends StatelessWidget {
  final bool value;
  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Function(bool) onChanged;
  const SettingsSwitch({
    required this.value,
    required this.title,
    this.subtitle,
    this.leading,
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    TextStyle titleStyle = Theme.of(context).textTheme.titleMedium!;
    TextStyle subTitleStyle = Theme.of(context)
        .textTheme
        .labelMedium!
        .copyWith(color: Theme.of(context).colorScheme.outline);
    return ListTile(
      enableFeedback: true,
      onTap: () => onChanged(!value),
      shape: RoundedRectangleBorder(
        borderRadius: AppStyle.radius8,
      ),
      //visualDensity: VisualDensity.compact,
      contentPadding: AppStyle.edgeInsetsL16.copyWith(right: 8),
      title: title,
      titleTextStyle: titleStyle,
      subtitle: subtitle,
      subtitleTextStyle: subTitleStyle,
      leading: leading,
      trailing: Transform.scale(
        alignment: Alignment.centerRight, // 缩放Switch的大小后保持右侧对齐, 避免右侧空隙过大
        scale: 0.8,
        child: Switch(
          thumbIcon: WidgetStateProperty.resolveWith<Icon?>(
                  (Set<WidgetState> states) {
                if (states.isNotEmpty && states.first == WidgetState.selected) {
                  return const Icon(Icons.done);
                }
                return null; // All other states will use the default thumbIcon.
              }),
          value: value,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
