import 'package:flutter/material.dart';
import 'package:pure_live/common/widgets/app_status_view.dart';

class EmptyView extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final IconData? icon;
  final String? buttonText;
  final VoidCallback? onButtonPressed;
  final bool isMini;
  final Color? iconColor;
  final Color? titleColor;
  final Color? subtitleColor;

  const EmptyView({
    super.key,
    this.title,
    this.subtitle,
    this.icon,
    this.buttonText,
    this.onButtonPressed,
    this.isMini = false,
    this.iconColor,
    this.titleColor,
    this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    return AppStatusView(
      type: AppStatusType.empty,
      title: title,
      subtitle: subtitle,
      icon: icon,
      buttonText: buttonText,
      onButtonPressed: onButtonPressed,
      isMini: isMini,
      iconColor: iconColor,
      titleColor: titleColor,
      subtitleColor: subtitleColor,
    );
  }
}
