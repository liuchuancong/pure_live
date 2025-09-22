import 'package:flutter/material.dart';
import 'package:pure_live/common/widgets/app_style.dart';

class SettingsCard extends StatelessWidget {
  final Widget child;
  const SettingsCard({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).brightness == Brightness.dark
          ? Colors.grey.withValues(alpha: 0.2)
          : Colors.white70,
      shape: RoundedRectangleBorder(
        borderRadius: AppStyle.radius8,
        side: BorderSide(
          color: Colors.grey.withValues(alpha: 0.1),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppStyle.radius8,
        ),
        child: child,
      ),
    );
  }
}
