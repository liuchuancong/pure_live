import 'package:flutter/material.dart';
import 'package:pure_live/common/widgets/app_style.dart';

class SettingsListItem extends StatelessWidget {
  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final Function()? onTap;
  final bool selected;
  const SettingsListItem({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.selected = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    var tmpTrailing = trailing ?? const Icon(
        Icons.chevron_right,
        color: Colors.grey,
      );
    TextStyle titleStyle = Theme.of(context).textTheme.titleMedium!;
    TextStyle subTitleStyle = Theme.of(context)
        .textTheme
        .labelMedium!
        .copyWith(color: Theme.of(context).colorScheme.outline);
    return ListTile(
      enableFeedback: true,
      onTap: onTap,
      selected: selected,
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
      trailing: tmpTrailing,
    );
  }
}
