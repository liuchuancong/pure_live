import 'package:flutter/material.dart';
import 'package:pure_live/common/widgets/app_style.dart';
import 'package:pure_live/plugins/extension/list_extension.dart';

class SettingsCardV2 extends StatelessWidget {
  final List<Widget> children;

  final EdgeInsetsGeometry? padding;
  const SettingsCardV2({required this.children, super.key, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: padding ?? AppStyle.edgeInsetsA12,
        decoration: BoxDecoration(
          borderRadius: AppStyle.radius8,
        ),
        child: Material(
          color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.withValues(alpha: 0.2) : Colors.white70,
          shape: RoundedRectangleBorder(
            borderRadius: AppStyle.radius8,
            side: BorderSide(
              color: Colors.grey.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            children: children.joinItem(AppStyle.divider),
          ),
        ));
  }
}
