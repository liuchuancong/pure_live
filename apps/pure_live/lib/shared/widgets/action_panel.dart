import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';

/// Opens a set of verbs as a panel: on a phone the 更多 is a 弹窗, not a
/// drop-down menu.
Future<void> showActionsPanel(BuildContext context, {required String title, required List<Widget> children}) =>
    showDsPanel<void>(
      context: context,
      builder: (context) => DsPanel(
        title: Text(title),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: DsSpace.s12, children: children),
      ),
    );
