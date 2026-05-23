import 'package:flutter/material.dart';
import 'package:pure_live/common/widgets/app_status_view.dart';

class EmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const EmptyView({super.key, required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return AppStatusView(type: AppStatusType.empty, icon: icon, title: title, subtitle: subtitle);
  }
}
