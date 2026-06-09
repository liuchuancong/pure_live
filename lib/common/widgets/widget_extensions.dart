import 'package:flutter/material.dart';
import 'package:pure_live/get/get.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart';
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

      String typeString = child.runtimeType.toString();

      // ✨ 核心修复：如果是包装组件，自动向下探测其内部子组件的实际类型
      Widget underlyingChild = child;
      if (child is StreamBuilder) {
        underlyingChild = (child).builder(Get.context!, const AsyncSnapshot.nothing());
      }

      final String underlyingType = underlyingChild.runtimeType.toString();
      final bool isTileElement =
          child is ListTile ||
          typeString.contains('ListTile') ||
          typeString.contains('SwitchListTile') ||
          typeString.contains('Obx') ||
          underlyingType.contains('ListTile') ||
          underlyingType.contains('SwitchListTile');

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
        String nextTypeString = nextChild.runtimeType.toString();

        Widget nextUnderlying = nextChild;
        if (nextChild is StreamBuilder) {
          nextUnderlying = (nextChild).builder(Get.context!, const AsyncSnapshot.nothing());
        }

        final String nextUnderlyingType = nextUnderlying.runtimeType.toString();
        final bool isNextTile =
            nextChild is ListTile ||
            nextTypeString.contains('ListTile') ||
            nextTypeString.contains('SwitchListTile') ||
            nextTypeString.contains('Obx') ||
            nextUnderlyingType.contains('ListTile') ||
            nextUnderlyingType.contains('SwitchListTile');

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
    ValueChanged<bool>? onChanged,
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
        onChanged: (val) {
          value.value = val;
          onChanged?.call(val);
        },
        contentPadding: const EdgeInsets.only(left: 16, top: 2, bottom: 2, right: 8),
      ),
    );
  }

  Widget buildTile({
    required String title,
    IconData? icon,
    Widget? iconWidget,
    String? subtitle,
    VoidCallback? onTap,
    Color? iconColor,
    Color? subtitleColor,
    Widget? trailing,
    bool isLong = false,
  }) {
    final theme = Theme.of(this);

    Widget? leadingWidget;
    if (iconWidget != null) {
      leadingWidget = Column(
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: IconTheme(
              data: IconThemeData(color: iconColor ?? theme.colorScheme.primary, size: 22),
              child: iconWidget,
            ),
          ),
        ],
      );
    } else if (icon != null) {
      leadingWidget = Column(
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Icon(icon, color: iconColor ?? theme.colorScheme.primary, size: 22),
          ),
        ],
      );
    }

    return ListTile(
      leading: leadingWidget,
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

  Widget buildMenuTile<T>({
    required String title,
    required T value,
    required Map<T, String> valueMap,
    required Function(T) onChanged,
    IconData? icon,
    String? subtitle,
    Color? iconColor,
    Color? subtitleColor,
    bool isLong = false,
  }) {
    final theme = Theme.of(this);
    final rawValueString = valueMap[value] ?? "$value";
    final displayValue = rawValueString.tr;

    return buildTile(
      title: title,
      icon: icon,
      subtitle: subtitle,
      iconColor: iconColor,
      subtitleColor: subtitleColor,
      isLong: isLong,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            displayValue,
            style: AppTextStyles.t14.copyWith(
              color: theme.hintColor.withValues(alpha: 0.75),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: theme.hintColor.withValues(alpha: 0.4), size: 20),
        ],
      ),
      onTap: () => _openMenuDialog<T>(title: title, value: value, valueMap: valueMap, onChanged: onChanged),
    );
  }

  void _openMenuDialog<T>({
    required String title,
    required T value,
    required Map<T, String> valueMap,
    required Function(T) onChanged,
  }) {
    showDialog(
      context: this,
      builder: (BuildContext dialogContext) {
        final innerTheme = Theme.of(dialogContext);

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          titlePadding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 8),
          contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          title: Text(title, style: AppTextStyles.t18.copyWith(fontWeight: FontWeight.bold)),
          content: Container(
            width: double.maxFinite,
            constraints: const BoxConstraints(maxWidth: 340, maxHeight: 400),
            child: SingleChildScrollView(
              child: RadioGroup<T>(
                groupValue: value,
                onChanged: (T? newValue) {
                  if (newValue != null) {
                    Navigator.of(dialogContext).pop();
                    onChanged.call(newValue);
                  }
                },
                child: buildModernCard(
                  valueMap.keys.map<Widget>((e) {
                    final itemRawText = valueMap[e] ?? "$e";
                    final itemDisplayText = itemRawText.tr;
                    final bool isSelected = (e == value);

                    return Material(
                      color: Colors.transparent,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(width: 8),
                          Radio<T>(value: e, activeColor: innerTheme.colorScheme.primary),
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                Navigator.of(dialogContext).pop();
                                onChanged.call(e);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                                child: Text(
                                  itemDisplayText,
                                  style: AppTextStyles.t15.copyWith(
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                    color: isSelected
                                        ? innerTheme.colorScheme.primary
                                        : innerTheme.textTheme.bodyLarge?.color,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget buildSliderTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required double value,
    required double min,
    required double max,
    required String displayValue,
    required ValueChanged<double> onChanged,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: SizedBox(width: 24, child: Icon(icon, size: 22, color: theme.colorScheme.primary)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: AppTextStyles.t16.copyWith(fontWeight: FontWeight.w600)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        displayValue,
                        style: AppTextStyles.t13.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Transform.translate(
                  offset: const Offset(-4, 0),
                  child: SizedBox(
                    width: double.infinity,
                    child: SfSlider(
                      min: min,
                      max: max,
                      value: value,
                      activeColor: theme.colorScheme.primary,
                      inactiveColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                      onChanged: (dynamic v) => onChanged(v as double),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
