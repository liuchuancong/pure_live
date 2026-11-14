import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:pure_live/shared/widgets/app_panel.dart';

/// Opens a set of verbs as a panel: on a phone the 更多 is a 弹窗, not a
/// drop-down menu.
Future<void> showActionsPanel(BuildContext context, {required String title, required List<Widget> children}) =>
    showAppPanel<void>(
      context: context,
      builder: (context) => AppPanel(
        title: Text(title),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: DsSpace.s12, children: children),
      ),
    );
