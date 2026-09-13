import 'package:flutter/material.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/core/sites.dart';
import 'package:pure_live/plugins/locale_helper.dart';
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

  Widget buildPlatformTag(String platform, {bool mini = false}) {
    final theme = Theme.of(this);
    final colorScheme = theme.colorScheme;
    final id = platform.trim().toLowerCase();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: mini ? 6 : 8, vertical: mini ? 2 : 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Text(
        i18n('site_$id'),
        style: AppTextStyles.t11.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontSize: mini ? 10 : 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
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
    bool stackTrailingOnNarrow = false,
    bool showNavigationChevronWhenStacked = true,
  }) {
    final theme = Theme.of(this);

    Widget? leadingWidget;
    if (iconWidget != null) {
      leadingWidget = Column(
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
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
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, color: iconColor ?? theme.colorScheme.primary, size: 22),
          ),
        ],
      );
    }

    final titleWidget = Text(title, style: AppTextStyles.t15.copyWith(fontWeight: FontWeight.w600));
    final subtitleWidget = subtitle != null && subtitle.isNotEmpty
        ? Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              subtitle,
              style: AppTextStyles.t12.copyWith(color: subtitleColor ?? theme.hintColor.withValues(alpha: 0.75)),
              maxLines: isLong ? null : 1,
              overflow: isLong ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
          )
        : null;

    Widget standardTile() => ListTile(
      horizontalTitleGap: 12,
      minLeadingWidth: 0,
      minVerticalPadding: 0,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: leadingWidget,
      title: titleWidget,
      subtitle: subtitleWidget,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child:
                trailing ??
                (onTap != null
                    ? Icon(Icons.chevron_right_rounded, color: theme.hintColor.withValues(alpha: 0.4), size: 20)
                    : null),
          ),
        ],
      ),
      onTap: onTap,
    );

    if (!stackTrailingOnNarrow || trailing == null) return standardTile();
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        if (constraints.maxWidth >= 360 && textScale <= 1.5) return standardTile();
        return ListTile(
          horizontalTitleGap: 12,
          minLeadingWidth: 0,
          minVerticalPadding: 0,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: leadingWidget,
          title: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [titleWidget, ?subtitleWidget, const SizedBox(height: 8), trailing],
          ),
          trailing: onTap != null && showNavigationChevronWhenStacked
              ? Icon(Icons.chevron_right_rounded, color: theme.hintColor.withValues(alpha: 0.4), size: 20)
              : null,
          onTap: onTap,
        );
      },
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
      stackTrailingOnNarrow: true,
      showNavigationChevronWhenStacked: false,
      trailing: Wrap(
        spacing: 4,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            displayValue,
            style: AppTextStyles.t14.copyWith(
              color: theme.hintColor.withValues(alpha: 0.75),
              fontWeight: FontWeight.w500,
            ),
          ),
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
          scrollable: true,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          titlePadding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 8),
          contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          title: Text(title, style: AppTextStyles.t18.copyWith(fontWeight: FontWeight.bold)),
          content: RadioGroup<T>(
            groupValue: value,
            onChanged: (T? newValue) {
              if (newValue != null) {
                Navigator.of(dialogContext).pop();
                onChanged.call(newValue);
              }
            },
            child: buildModernCard(
              valueMap.entries.map<Widget>((entry) {
                final itemDisplayText = (entry.value).tr;
                final isSelected = entry.key == value;
                return RadioListTile<T>(
                  value: entry.key,
                  activeColor: innerTheme.colorScheme.primary,
                  title: Text(
                    itemDisplayText,
                    style: AppTextStyles.t15.copyWith(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? innerTheme.colorScheme.primary : innerTheme.textTheme.bodyLarge?.color,
                    ),
                  ),
                );
              }).toList(),
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
    String? subtitle,
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
                LayoutBuilder(
                  builder: (context, constraints) {
                    final titleStyle = AppTextStyles.t16.copyWith(fontWeight: FontWeight.w600);
                    final valueStyle = AppTextStyles.t13.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    );
                    final scaler = MediaQuery.textScalerOf(context);
                    final titlePainter = TextPainter(
                      text: TextSpan(text: title, style: titleStyle),
                      textDirection: Directionality.of(context),
                      textScaler: scaler,
                      maxLines: 1,
                    )..layout();
                    final valuePainter = TextPainter(
                      text: TextSpan(text: displayValue, style: valueStyle),
                      textDirection: Directionality.of(context),
                      textScaler: scaler,
                      maxLines: 1,
                    )..layout();
                    final valueBadge = Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(displayValue, style: valueStyle),
                    );
                    final useRow = titlePainter.width + valuePainter.width + 28 <= constraints.maxWidth;
                    if (useRow) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: Text(title, style: titleStyle)),
                          const SizedBox(width: 12),
                          valueBadge,
                        ],
                      );
                    }
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: titleStyle),
                        const SizedBox(height: 6),
                        valueBadge,
                      ],
                    );
                  },
                ),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(subtitle, style: AppTextStyles.t12.copyWith(color: theme.hintColor.withValues(alpha: 0.75))),
                ],
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
