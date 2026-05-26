import 'package:flutter/material.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/common/style/app_text_styles.dart';

extension AppLayoutFactory on BuildContext {
  Widget buildGroupTitle(String text) {
    final theme = Theme.of(this);
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        text,
        style: AppTextStyles.t12.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary.withValues(alpha: 0.65),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget buildModernCard(List<Widget> children) {
    final theme = Theme.of(this);
    final List<Widget> autoShapedChildren = [];

    final validChildren = children.where((w) => w is! SizedBox).toList();

    for (int i = 0; i < validChildren.length; i++) {
      final child = validChildren[i];

      final String typeString = child.runtimeType.toString();
      final bool isTileElement =
          child is ListTile || typeString.contains('ListTile') || typeString.contains('SwitchListTile');

      if (isTileElement) {
        ShapeBorder effectiveShape;

        if (validChildren.length == 1) {
          effectiveShape = const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20)));
        } else if (i == 0) {
          effectiveShape = const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20)));
        } else if (i == validChildren.length - 1) {
          effectiveShape = const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
          );
        } else {
          effectiveShape = const LinearBorder();
        }

        autoShapedChildren.add(ListTileTheme.merge(shape: effectiveShape, child: child));
      } else {
        autoShapedChildren.add(child);
      }

      if (i < validChildren.length - 1 && isTileElement) {
        final nextChild = validChildren[i + 1];
        final String nextTypeString = nextChild.runtimeType.toString();
        final bool isNextTile =
            nextChild is ListTile || nextTypeString.contains('ListTile') || nextTypeString.contains('SwitchListTile');

        if (isNextTile) {
          autoShapedChildren.add(
            Divider(
              height: 0.5,
              thickness: 0.5,
              indent: 16,
              endIndent: 16,
              color: theme.dividerColor.withValues(alpha: 0.05),
            ),
          );
        }
      }
    }

    return Material(
      clipBehavior: Clip.antiAlias,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.05), width: 0.5),
      ),
      child: Column(children: autoShapedChildren),
    );
  }

  Widget buildSwitchTile({
    required String title,
    required RxBool value,
    IconData? icon,
    String? subtitle,
    Color? iconColor,
    Color? subtitleColor,
    bool isLong = false,
  }) {
    final theme = Theme.of(this);
    return Obx(
      () => SwitchListTile(
        secondary: icon != null ? Icon(icon, color: iconColor ?? theme.colorScheme.primary, size: 22) : null,
        title: Text(title, style: AppTextStyles.t15.copyWith(fontWeight: FontWeight.w600)),
        subtitle: subtitle != null && subtitle.isNotEmpty
            ? Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  subtitle,
                  style: AppTextStyles.t12.copyWith(color: subtitleColor ?? theme.hintColor.withValues(alpha: 0.75)),
                  maxLines: isLong ? null : 1,
                  overflow: isLong ? TextOverflow.visible : TextOverflow.ellipsis,
                ),
              )
            : null,
        value: value.value,
        onChanged: (val) => value.value = val,
        contentPadding: const EdgeInsets.only(left: 16, top: 2, bottom: 2, right: 8),
      ),
    );
  }

  Widget buildTile({
    required String title,
    IconData? icon,
    String? subtitle,
    VoidCallback? onTap,
    Color? iconColor,
    Color? subtitleColor,
    Widget? trailing,
    bool isLong = false,
  }) {
    final theme = Theme.of(this);
    return ListTile(
      leading: icon != null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4), // 精准像素级微调，使图标轴心与第一行标题水平对齐
                  child: Icon(icon, color: iconColor ?? theme.colorScheme.primary, size: 22),
                ),
              ],
            )
          : null,
      title: Text(title, style: AppTextStyles.t15.copyWith(fontWeight: FontWeight.w600)),
      subtitle: subtitle != null && subtitle.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                subtitle,
                style: AppTextStyles.t12.copyWith(color: subtitleColor ?? theme.hintColor.withValues(alpha: 0.75)),
                maxLines: isLong ? null : 1,
                overflow: isLong ? TextOverflow.visible : TextOverflow.ellipsis,
              ),
            )
          : null,
      trailing:
          trailing ??
          (onTap != null
              ? Icon(Icons.chevron_right_rounded, color: theme.hintColor.withValues(alpha: 0.4), size: 20)
              : null),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    );
  }
}
